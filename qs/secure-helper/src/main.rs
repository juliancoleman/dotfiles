//! One binary, two front ends for the shell's secure prompt:
//! `qs-askpass` (`SUDO_ASKPASS`, `SSH_ASKPASS`, `GIT_ASKPASS`) and `pinentry-qs` (gpg-agent).

mod askpass;
mod broker;
mod pinentry;
mod tty;

use std::path::Path;
use std::process::ExitCode;

fn main() -> ExitCode {
    let mut args: Vec<String> = std::env::args().collect();
    let invoked = args
        .first()
        .and_then(|arg| Path::new(arg).file_name())
        .and_then(|name| name.to_str())
        .unwrap_or("")
        .to_owned();
    args.remove(0);

    if invoked.starts_with("pinentry") {
        return pinentry::run();
    }
    match args.first().map(String::as_str) {
        Some("pinentry") => pinentry::run(),
        Some("askpass") => askpass::run(&args[1..]),
        _ => askpass::run(&args),
    }
}
