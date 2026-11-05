mod config;
mod error;
mod server;
mod sysfs;

use std::{
    env, fs,
    os::{fd::FromRawFd, unix::net::UnixListener},
    path::PathBuf,
    process::{self, ExitCode},
    sync::Arc,
    thread,
};

use signal_hook::{
    consts::{SIGHUP, SIGINT, SIGTERM},
    iterator::Signals,
};

use crate::{
    error::{Error, Result},
    server::Helper,
    sysfs::{Controller, Sysfs},
};

const SYSTEMD_FIRST_FD: i32 = 3;

enum Mode {
    Serve,
    Restore,
}

struct Options {
    mode: Mode,
    socket: Option<PathBuf>,
    dev_root: Option<PathBuf>,
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("error: {error}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<()> {
    let options = parse_options()?;
    let controller = controller(&options)?;
    if matches!(options.mode, Mode::Restore) {
        return controller.restore_all();
    }

    // Whatever state a previous run left behind, start from firmware control.
    controller.restore_all_best_effort();
    if let Err(error) = controller.available() {
        eprintln!("warning: fan control is not currently available: {error}");
    }

    let listener = listener(&options)?;
    let helper = Arc::new(Helper::new(controller));

    let mut signals = Signals::new([SIGTERM, SIGINT, SIGHUP])?;
    let on_signal = Arc::clone(&helper);
    thread::spawn(move || {
        if let Some(signal) = signals.forever().next() {
            on_signal.force_auto(&format!("received signal {signal}"));
            process::exit(0);
        }
    });

    server::spawn_watchdog(Arc::clone(&helper));
    let result = server::serve(Arc::clone(&helper), listener);
    helper.controller().restore_all_best_effort();
    result
}

fn parse_options() -> Result<Options> {
    let mut options = Options {
        mode: Mode::Serve,
        socket: None,
        dev_root: None,
    };
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--restore" => options.mode = Mode::Restore,
            "--socket" => options.socket = Some(next_path(&mut args, "--socket")?),
            "--dev-root" => options.dev_root = Some(next_path(&mut args, "--dev-root")?),
            other => return Err(Error::usage(format!("unknown argument {other}"))),
        }
    }
    Ok(options)
}

fn next_path(args: &mut impl Iterator<Item = String>, flag: &str) -> Result<PathBuf> {
    args.next()
        .map(PathBuf::from)
        .ok_or_else(|| Error::usage(format!("{flag} requires a path")))
}

fn controller(options: &Options) -> Result<Controller> {
    let Some(root) = &options.dev_root else {
        return Ok(Controller::new(config::load()?, Sysfs::system()));
    };
    let state_dir = root.join("run");
    fs::create_dir_all(&state_dir)?;
    Ok(Controller::new(
        config::parse(&fs::read(root.join("policy.json"))?)?,
        Sysfs {
            hwmon: root.join("class/hwmon"),
            devices: fs::canonicalize(root.join("devices"))?,
            state_dir: Some(state_dir),
            require_root_owner: false,
        },
    ))
}

fn listener(options: &Options) -> Result<UnixListener> {
    if let Some(path) = &options.socket {
        let _ = fs::remove_file(path);
        return Ok(UnixListener::bind(path)?);
    }
    let activated = env::var("LISTEN_PID").ok() == Some(process::id().to_string())
        && env::var("LISTEN_FDS").ok().as_deref() == Some("1");
    if !activated {
        return Err(Error::unavailable(
            "expected one socket from systemd activation (or pass --socket PATH)",
        ));
    }
    // SAFETY: systemd passed exactly one listening socket at the first activation fd,
    // and nothing else in this process owns it.
    Ok(unsafe { UnixListener::from_raw_fd(SYSTEMD_FIRST_FD) })
}
