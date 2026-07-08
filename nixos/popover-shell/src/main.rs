//! popover-shell — a Wayland layer-shell popover toolkit for niri + Waybar.
//!
//! Architecture:
//!   - layer-shika hosts Slint UI on a `wlr-layer-shell` surface (the popup).
//!   - slint-interpreter compiles `.slint` at runtime → hot reload on save.
//!   - zbus talks to NetworkManager for wifi scan/connect.
//!   - We register as NM's sole secret agent, so credential prompts route to
//!     our Slint PasswordDialog instead of a terminal or nm-applet.
//!
//! Waybar triggers this binary via `on-click`; Waybar's own config stays
//! untouched — this is purely additive (option #2 from the design discussion).

mod audio {
    //! PipeWire/WirePlumber control for the audio popover.
    //!
    //! This intentionally shells out to `wpctl`: it is already the user's audio
    //! control surface, keeps the binary small, and avoids owning PipeWire graph
    //! state just to drive a small Waybar popover.

    use std::process::Command;

    use anyhow::{bail, Context, Result};

    #[derive(Debug, Clone)]
    pub struct AudioState {
        pub volume_percent: f64,
        pub muted: bool,
        pub sink_name: String,
    }

    pub fn read_state() -> Result<AudioState> {
        let volume = wpctl(&["get-volume", "@DEFAULT_AUDIO_SINK@"])?;
        let (volume_percent, muted) = parse_volume(&volume)?;
        let sink_name = read_sink_name().unwrap_or_else(|e| {
            log::warn!("failed to read default sink name: {e}");
            "Default output".to_string()
        });

        Ok(AudioState {
            volume_percent,
            muted,
            sink_name,
        })
    }

    pub fn set_volume_percent(percent: f64) -> Result<()> {
        let percent = percent.round().clamp(0.0, 100.0);
        let value = format!("{percent:.0}%");
        wpctl(&["set-volume", "@DEFAULT_AUDIO_SINK@", &value])?;
        Ok(())
    }

    pub fn toggle_mute() -> Result<()> {
        wpctl(&["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])?;
        Ok(())
    }

    fn read_sink_name() -> Result<String> {
        let inspect = wpctl(&["inspect", "@DEFAULT_AUDIO_SINK@"])?;
        for key in ["node.description", "media.name", "node.name"] {
            if let Some(value) = property_value(&inspect, key) {
                return Ok(value);
            }
        }
        Ok("Default output".to_string())
    }

    fn wpctl(args: &[&str]) -> Result<String> {
        let output = Command::new("wpctl")
            .args(args)
            .output()
            .with_context(|| format!("running wpctl {}", args.join(" ")))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            bail!("wpctl {} failed: {}", args.join(" "), stderr.trim());
        }

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }

    fn parse_volume(raw: &str) -> Result<(f64, bool)> {
        let muted = raw.contains("[MUTED]");
        let scalar = raw
            .split_whitespace()
            .find_map(|part| part.parse::<f64>().ok())
            .with_context(|| format!("parsing wpctl volume output: {raw}"))?;
        Ok(((scalar * 100.0).round().clamp(0.0, 100.0), muted))
    }

    fn property_value(inspect: &str, key: &str) -> Option<String> {
        for line in inspect.lines() {
            let line = line.trim();
            let line = line.strip_prefix("* ").unwrap_or(line);
            let Some(rest) = line.strip_prefix(key) else {
                continue;
            };
            let Some(value) = rest.trim_start().strip_prefix('=') else {
                continue;
            };
            let value = value.trim().trim_matches('"');
            if !value.is_empty() {
                return Some(value.to_string());
            }
        }
        None
    }
}

mod bluetooth {
    //! BlueZ control for the Bluetooth popover.

    use std::process::Command;

    use anyhow::{bail, Context, Result};

    #[derive(Debug, Clone)]
    pub struct BluetoothDevice {
        pub name: String,
        pub mac: String,
        pub paired: bool,
        pub connected: bool,
    }

    #[derive(Debug, Clone)]
    pub struct BluetoothState {
        pub powered: bool,
        pub devices: Vec<BluetoothDevice>,
    }

    pub fn read_state() -> Result<BluetoothState> {
        Ok(BluetoothState {
            powered: powered()?,
            devices: read_devices()?,
        })
    }

    pub fn toggle_power() -> Result<bool> {
        if powered()? {
            bluetoothctl(&["power", "off"])?;
            Ok(false)
        } else {
            bluetoothctl(&["power", "on"])?;
            let _ = bluetoothctl(&["pairable", "on"]);
            Ok(true)
        }
    }

    pub fn scan_devices() -> Result<Vec<BluetoothDevice>> {
        if !powered()? {
            bluetoothctl(&["power", "on"])?;
        }
        let _ = bluetoothctl(&["pairable", "on"]);
        let _ = Command::new("bluetoothctl")
            .args(["--timeout", "4", "scan", "on"])
            .output()
            .context("running bluetoothctl scan")?;
        let _ = bluetoothctl(&["scan", "off"]);
        read_devices()
    }

    pub fn connect(mac: &str) -> Result<()> {
        let _ = bluetoothctl(&["pair", mac]);
        let _ = bluetoothctl(&["trust", mac]);
        bluetoothctl(&["connect", mac])?;
        Ok(())
    }

    fn powered() -> Result<bool> {
        let show = bluetoothctl(&["show"])?;
        Ok(show.lines().any(|line| line.trim() == "Powered: yes"))
    }

    fn read_devices() -> Result<Vec<BluetoothDevice>> {
        let devices = bluetoothctl(&["devices"])?;
        let mut out = Vec::new();
        for line in devices.lines() {
            let mut parts = line.splitn(3, ' ');
            if parts.next() != Some("Device") {
                continue;
            }
            let Some(mac) = parts.next() else {
                continue;
            };
            let name = parts.next().unwrap_or(mac).trim();
            let info = bluetoothctl(&["info", mac]).unwrap_or_default();
            out.push(BluetoothDevice {
                name: name.to_string(),
                mac: mac.to_string(),
                paired: info.lines().any(|line| line.trim() == "Paired: yes"),
                connected: info.lines().any(|line| line.trim() == "Connected: yes"),
            });
        }
        out.sort_by(|a, b| {
            b.connected
                .cmp(&a.connected)
                .then_with(|| b.paired.cmp(&a.paired))
                .then_with(|| a.name.cmp(&b.name))
        });
        Ok(out)
    }

    fn bluetoothctl(args: &[&str]) -> Result<String> {
        let output = Command::new("bluetoothctl")
            .args(args)
            .output()
            .with_context(|| format!("running bluetoothctl {}", args.join(" ")))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            bail!("bluetoothctl {} failed: {}", args.join(" "), stderr.trim());
        }

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }
}
mod network;
mod secret_agent;

use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;

use layer_shika::prelude::*;
use layer_shika::slint_interpreter::{Struct, Value};
use parking_lot::RwLock;

use network::{AccessPoint, Nm};

/// Result alias with the error type exposed as a defaulted parameter.
pub type Result<T, E = anyhow::Error> = std::result::Result<T, E>;

/// Shared AP cache — populated on scan, read on connect-click.
type ApCache = Arc<RwLock<Vec<AccessPoint>>>;

/// Path to the .slint UI file. In dev: $CARGO_MANIFEST_DIR/ui/wifi.slint.
/// In the Nix package: $out/share/popover-shell/ui/wifi.slint. Override with
/// `POPOVER_SHELL_UI` for hot-reload during iteration.
fn ui_path() -> PathBuf {
    std::env::var("POPOVER_SHELL_UI")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            // Dev default — works when run via `cargo run`.
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("ui/wifi.slint")
        })
}

/// Build a Slint Value::Model from the access-point list.
/// Each AP becomes a Value::Struct with fields matching `NetworkEntry` in
/// the .slint file: ssid, signal, security, in-use.
fn aps_to_model(aps: &[AccessPoint]) -> Value {
    let values: Vec<Value> = aps
        .iter()
        .map(|ap| {
            let mut s = Struct::default();
            s.set_field(
                "ssid".to_string(),
                Value::String(ap.ssid.as_str().into()),
            );
            s.set_field("signal".to_string(), Value::Number(ap.signal as f64));
            s.set_field(
                "security".to_string(),
                Value::String(ap.security.label().into()),
            );
            s.set_field("in-use".to_string(), Value::Bool(ap.in_use));
            Value::Struct(s)
        })
        .collect();
    use std::rc::Rc;
    Value::Model(layer_shika::slint::ModelRc::new(Rc::new(
        layer_shika::slint::VecModel::from(values),
    )))
}

fn bluetooth_devices_to_model(devices: &[bluetooth::BluetoothDevice]) -> Value {
    let values: Vec<Value> = devices
        .iter()
        .map(|device| {
            let mut s = Struct::default();
            s.set_field("name".to_string(), Value::String(device.name.as_str().into()));
            s.set_field("mac".to_string(), Value::String(device.mac.as_str().into()));
            s.set_field("paired".to_string(), Value::Bool(device.paired));
            s.set_field("connected".to_string(), Value::Bool(device.connected));
            Value::Struct(s)
        })
        .collect();
    use std::rc::Rc;
    Value::Model(layer_shika::slint::ModelRc::new(Rc::new(
        layer_shika::slint::VecModel::from(values),
    )))
}

/// Set the `networks` property on the WifiPicker surface and set
/// `scanning` to false.
fn update_networks(shell: &Shell, aps: &[AccessPoint]) {
    let model = aps_to_model(aps);
    let sel = shell.select(Surface::named("WifiPicker"));
    sel.set_property("networks", &model);
    sel.set_property("scanning", &Value::Bool(false));
}

/// A pending password prompt: NM requested secrets, we need the user to type
/// a password. The D-Bus thread sends this through an mpsc channel; the main
/// thread drains it via calloop timer and shows the PasswordDialog.
struct PendingPrompt {
    network_name: String,
    ssid: String,
    /// Send the password back to the D-Bus thread (Some = submit, None = cancel).
    responder: tokio::sync::oneshot::Sender<Option<String>>,
}

/// Cross-thread bridge: the secret agent (D-Bus thread) sends prompt requests
/// here; the main thread polls via calloop timer.
type PromptBridge = (
    std::sync::mpsc::Sender<PendingPrompt>,
    parking_lot::Mutex<std::sync::mpsc::Receiver<PendingPrompt>>,
);

fn create_prompt_bridge() -> PromptBridge {
    let (tx, rx) = std::sync::mpsc::channel::<PendingPrompt>();
    (tx, parking_lot::Mutex::new(rx))
}

unsafe extern "C" {
    fn kill(pid: i32, sig: i32) -> i32;
}

const SIGTERM: i32 = 15;

fn close_existing_popovers() {
    let self_pid = std::process::id();
    let Ok(entries) = fs::read_dir("/proc") else {
        return;
    };
    let mut killed = Vec::new();

    for entry in entries.flatten() {
        let Some(name) = entry.file_name().to_str().map(str::to_owned) else {
            continue;
        };
        let Ok(pid) = name.parse::<u32>() else {
            continue;
        };
        if pid == self_pid || !is_popover_process(pid) {
            continue;
        }

        let rc = unsafe { kill(pid as i32, SIGTERM) };
        if rc == 0 {
            log::info!("closed existing popover-shell process {pid}");
            killed.push(pid);
        } else {
            log::warn!("failed to close existing popover-shell process {pid}");
        }
    }

    if killed.is_empty() {
        return;
    }

    for _ in 0..20 {
        if killed.iter().all(|pid| !is_popover_process(*pid)) {
            break;
        }
        std::thread::sleep(Duration::from_millis(50));
    }

    // Give D-Bus a short grace period to drop NetworkManager's secret-agent
    // registration before a replacement Wi-Fi popover registers the same ID.
    std::thread::sleep(Duration::from_millis(200));
}

fn is_popover_process(pid: u32) -> bool {
    let exe_path = format!("/proc/{pid}/exe");
    if fs::read_link(exe_path)
        .ok()
        .and_then(|exe| exe.file_name().and_then(|name| name.to_str()).map(str::to_owned))
        .is_some_and(|name| popover_binary_name(&name))
    {
        return true;
    }

    let comm_path = format!("/proc/{pid}/comm");
    if fs::read_to_string(comm_path)
        .ok()
        .is_some_and(|comm| popover_binary_name(comm.trim()))
    {
        return true;
    }

    let cmdline_path = format!("/proc/{pid}/cmdline");
    fs::read(cmdline_path)
        .ok()
        .and_then(|cmdline| {
            cmdline
                .split(|byte| *byte == 0)
                .find(|part| !part.is_empty())
                .and_then(|arg0| std::str::from_utf8(arg0).ok())
                .and_then(|arg0| Path::new(arg0).file_name())
                .and_then(|name| name.to_str())
                .map(str::to_owned)
        })
        .is_some_and(|name| popover_binary_name(&name))
}

fn popover_binary_name(name: &str) -> bool {
    name == "popover-shell"
        || name == ".popover-shell-wrapped"
        || name.starts_with("popover-shell ")
        || name.starts_with(".popover-shell-wrapped ")
        || name.starts_with(".popover-shell-")
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Mode {
    Wifi,
    Audio,
    Bluetooth,
}

fn mode_from_args() -> Result<Mode> {
    match std::env::args().nth(1).as_deref() {
        None | Some("wifi") => Ok(Mode::Wifi),
        Some("audio") => Ok(Mode::Audio),
        Some("bluetooth") => Ok(Mode::Bluetooth),
        Some("-h" | "--help") => {
            println!("Usage: popover-shell [wifi|audio|bluetooth]");
            std::process::exit(0);
        }
        Some(other) => anyhow::bail!("unknown popover mode '{other}' (expected wifi or audio)"),
    }
}

fn popover_anchor() -> AnchorEdges {
    AnchorEdges::empty().with_bottom().with_right()
}

fn popover_margin() -> (i32, i32, i32, i32) {
    // The Waybar lives on the right edge with an 8px outer margin. Keep the
    // popover just to its left and slightly above the screen edge.
    (0, 58, 8, 0)
}

fn main() -> Result<()> {
    env_logger::builder()
        .filter_level(log::LevelFilter::Info)
        .parse_default_env()
        .init();

    let mode = mode_from_args()?;
    close_existing_popovers();
    log::info!("popover-shell starting in {mode:?} mode");

    match mode {
        Mode::Wifi => run_wifi(),
        Mode::Audio => run_audio(),
        Mode::Bluetooth => run_bluetooth(),
    }
}

fn set_audio_properties(shell: &Shell) {
    match audio::read_state() {
        Ok(state) => {
            let sel = shell.select(Surface::named("AudioPicker"));
            sel.set_property("volume", &Value::Number(state.volume_percent));
            sel.set_property("muted", &Value::Bool(state.muted));
            sel.set_property("sink-name", &Value::String(state.sink_name.into()));
        }
        Err(e) => log::warn!("failed to read audio state: {e}"),
    }
}

fn run_audio() -> Result<()> {
    let ui = ui_path();
    log::info!("loading UI from {}", ui.display());

    let mut shell = Shell::from_file(&ui)
        .surface("AudioPicker")
        .anchor(popover_anchor())
        .margin(popover_margin())
        .height(220)
        .width(340)
        .namespace("popover-shell-audio")
        .keyboard_interactivity(KeyboardInteractivity::OnDemand)
        .build()?;

    set_audio_properties(&shell);

    shell
        .select(Surface::named("AudioPicker"))
        .on_callback("toggle-mute", |_ctx| {
            if let Err(e) = audio::toggle_mute() {
                log::warn!("failed to toggle mute: {e}");
            }
            Value::Void
        });

    shell
        .select(Surface::named("AudioPicker"))
        .on_callback_with_args("set-volume", |args, _ctx| {
            let percent = args
                .first()
                .and_then(|v| {
                    if let Value::Number(n) = v {
                        Some(*n)
                    } else {
                        None
                    }
                })
                .unwrap_or(0.0);

            if let Err(e) = audio::set_volume_percent(percent) {
                log::warn!("failed to set volume: {e}");
            }
            Value::Void
        });

    shell
        .select(Surface::named("AudioPicker"))
        .on_callback("close-popup", |_ctx| {
            std::process::exit(0);
            #[allow(unreachable_code)]
            Value::Void
        });

    log::info!("entering event loop");
    shell.run()?;
    Ok(())
}


fn set_bluetooth_properties(shell: &Shell, cache: &Arc<RwLock<Vec<bluetooth::BluetoothDevice>>>) {
    match bluetooth::read_state() {
        Ok(state) => {
            *cache.write() = state.devices.clone();
            let sel = shell.select(Surface::named("BluetoothPicker"));
            sel.set_property("powered", &Value::Bool(state.powered));
            sel.set_property("devices", &bluetooth_devices_to_model(&state.devices));
        }
        Err(e) => log::warn!("failed to read Bluetooth state: {e}"),
    }
}

fn run_bluetooth() -> Result<()> {
    let ui = ui_path();
    log::info!("loading UI from {}", ui.display());

    let mut shell = Shell::from_file(&ui)
        .surface("BluetoothPicker")
        .anchor(popover_anchor())
        .margin(popover_margin())
        .height(460)
        .width(360)
        .namespace("popover-shell-bluetooth")
        .keyboard_interactivity(KeyboardInteractivity::OnDemand)
        .build()?;

    let device_cache: Arc<RwLock<Vec<bluetooth::BluetoothDevice>>> = Arc::new(RwLock::new(Vec::new()));
    set_bluetooth_properties(&shell, &device_cache);

    let cache_for_scan = device_cache.clone();
    shell
        .select(Surface::named("BluetoothPicker"))
        .on_callback("scan-request", move |_ctx| {
            match bluetooth::scan_devices() {
                Ok(devices) => {
                    log::info!("Bluetooth scan found {} devices", devices.len());
                    *cache_for_scan.write() = devices.clone();
                    bluetooth_devices_to_model(&devices)
                }
                Err(e) => {
                    log::warn!("Bluetooth scan failed: {e}");
                    bluetooth_devices_to_model(&[])
                }
            }
        });

    shell
        .select(Surface::named("BluetoothPicker"))
        .on_callback("toggle-power", |_ctx| match bluetooth::toggle_power() {
            Ok(powered) => Value::Bool(powered),
            Err(e) => {
                log::warn!("failed to toggle Bluetooth power: {e}");
                Value::Bool(false)
            }
        });

    let cache_for_connect = device_cache.clone();
    shell
        .select(Surface::named("BluetoothPicker"))
        .on_callback_with_args("connect-request", move |args, _ctx| {
            let idx = args
                .first()
                .and_then(|v| {
                    if let Value::Number(n) = v {
                        Some(*n as usize)
                    } else {
                        None
                    }
                });
            if let Some(device) = idx.and_then(|idx| cache_for_connect.read().get(idx).cloned()) {
                log::info!("connecting to Bluetooth device {} ({})", device.name, device.mac);
                if let Err(e) = bluetooth::connect(&device.mac) {
                    log::warn!("Bluetooth connect failed: {e}");
                }
            }
            Value::Void
        });

    shell
        .select(Surface::named("BluetoothPicker"))
        .on_callback("close-popup", |_ctx| {
            std::process::exit(0);
            #[allow(unreachable_code)]
            Value::Void
        });

    log::info!("entering event loop");
    shell.run()?;
    Ok(())
}

fn run_wifi() -> Result<()> {
    log::info!("initializing wifi popover");

    // Slint + layer-shika run on the main thread (they're !Send). Tokio runs
    // on a background thread for D-Bus; we bridge via oneshot channels.
    let rt = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()?;

    // Create the cross-thread prompt bridge before the D-Bus task starts.
    let (prompt_tx, prompt_rx) = create_prompt_bridge();

    // Spawn the D-Bus side: register NM client + secret agent.
    let (nm_tx, nm_rx) = tokio::sync::oneshot::channel::<Arc<Nm>>();
    let (err_tx, mut err_rx) =
        tokio::sync::oneshot::channel::<anyhow::Error>();
    let nm_handle = rt.handle().clone();
    let nm_task = nm_handle.spawn(async move {
        let conn = match zbus::Connection::system().await {
            Ok(c) => c,
            Err(e) => {
                log::error!("failed to connect to system bus: {e}");
                let _ = err_tx.send(anyhow::Error::from(e));
                return;
            }
        };
        log::info!("connected to system D-Bus");

        let nm = match Nm::new(&conn).await {
            Ok(n) => n,
            Err(e) => {
                log::error!("failed to create NM client: {e}");
                let _ = err_tx.send(anyhow::Error::from(e));
                return;
            }
        };
        log::info!("NM client created");
        let nm = Arc::new(nm);

        let session_conn = match zbus::Connection::session().await {
            Ok(c) => c,
            Err(e) => {
                log::error!("failed to connect to session bus: {e}");
                let _ = err_tx.send(anyhow::Error::from(e));
                return;
            }
        };
        log::info!("connected to session D-Bus");

        let mut agent = secret_agent::SecretAgent::new();
        // Wire the prompt callback: when NM calls GetSecrets, create a oneshot,
        // send the prompt request to the main thread, return the receiver.
        let prompt_tx_clone = prompt_tx.clone();
        agent.set_prompt(move |id: &str, ssid: &str| {
            let (resp_tx, resp_rx) = tokio::sync::oneshot::channel::<Option<String>>();
            let req = PendingPrompt {
                network_name: id.to_string(),
                ssid: ssid.to_string(),
                responder: resp_tx,
            };
            if prompt_tx_clone.send(req).is_err() {
                log::error!("prompt bridge channel closed");
            }
            resp_rx
        });
        if let Err(e) = agent.register(&session_conn, &conn).await {
            log::error!("failed to register secret agent: {e}");
            let _ = err_tx.send(anyhow::Error::from(e));
            return;
        }
        log::info!("NM secret agent registered");

        if nm_tx.send(nm).is_err() {
            log::error!("NM client channel closed before send");
            return;
        }
        std::future::pending::<()>().await;
    });

    let nm = rt.block_on(async {
        tokio::select! {
            res = nm_rx => res.map_err(anyhow::Error::from),
            err = &mut err_rx => {
                Err(err.expect("error channel closed without send"))
            }
        }
    })?;

    // ── Build the layer-shika shell from the .slint file ──
    let ui = ui_path();
    log::info!("loading UI from {}", ui.display());

    let mut shell = Shell::from_file(&ui)
        .surface("WifiPicker")
        .anchor(popover_anchor())
        .margin(popover_margin())
        .height(480)
        .width(360)
        .namespace("popover-shell")
        .keyboard_interactivity(KeyboardInteractivity::OnDemand)
        .build()?;

    // ── Shared AP cache ──
    let ap_cache: ApCache = Arc::new(RwLock::new(Vec::new()));

    // ── Populate the network list (initial) ──
    let nm_initial = nm.clone();
    let ap_cache_initial = ap_cache.clone();
    let shell_ref = &shell;
    match rt.block_on(async {
        if let Err(e) = nm_initial.request_scan().await {
            log::warn!("initial wifi scan request failed: {e}");
        }
        network::scan_settle().await;
        nm_initial.list_access_points().await
    }) {
        Ok(aps) => {
            log::info!("found {} access points", aps.len());
            *ap_cache_initial.write() = aps.clone();
            update_networks(shell_ref, &aps);
        }
        Err(e) => log::warn!("failed to list initial access points: {e}"),
    }

    // ── Rescan handler ──
    let nm_for_scan = nm.clone();
    let nm_handle_scan = nm_handle.clone();
    let ap_cache_scan = ap_cache.clone();
    shell
        .select(Surface::named("WifiPicker"))
        .on_callback("rescan-request", move |_ctx| {
            let nm = nm_for_scan.clone();
            let ap_cache = ap_cache_scan.clone();
            nm_handle_scan.spawn(async move {
                if let Err(e) = nm.request_scan().await {
                    log::warn!("wifi scan request failed: {e}");
                }
                network::scan_settle().await;
                match nm.list_access_points().await {
                    Ok(aps) => {
                        log::info!("scan found {} access points", aps.len());
                        *ap_cache.write() = aps;
                        // Note: can't update the UI from here (Slint is !Send).
                        // The user closes and reopens the popup to see fresh
                        // results. A calloop timer-based refresh would fix this
                        // but is out of scope for the MVP.
                        log::info!("reopen popup to see fresh results");
                    }
                    Err(e) => log::warn!("failed to list APs after scan: {e}"),
                }
            });
            Value::Void
        });

    // ── Connect handler: user clicked an AP ──
    let nm_for_connect = nm.clone();
    let nm_handle_connect = nm_handle.clone();
    let ap_cache_connect = ap_cache.clone();
    shell
        .select(Surface::named("WifiPicker"))
        .on_callback_with_args("connect-request", move |args, _ctx| {
            let idx: i32 = args
                .first()
                .and_then(|v| {
                    if let Value::Number(n) = v {
                        Some(*n as i32)
                    } else {
                        None
                    }
                })
                .unwrap_or(-1);

            if idx < 0 {
                return Value::Void;
            }
            log::info!("connect requested for index {idx}");

            // Look up the AP from the cache.
            let ap = {
                let cache = ap_cache_connect.read();
                cache.get(idx as usize).cloned()
            };

            if let Some(ap) = ap {
                let nm = nm_for_connect.clone();
                nm_handle_connect.spawn(async move {
                    log::info!("connecting to SSID: {}", ap.ssid);
                    if let Err(e) = nm.connect(&ap).await {
                        log::error!("connect failed: {e}");
                    } else {
                        log::info!("connect initiated for {}", ap.ssid);
                    }
                });
            } else {
                log::warn!("no AP at index {idx} in cache");
            }
            Value::Void
        });

    // ── Close handler ──
    shell
        .select(Surface::named("WifiPicker"))
        .on_callback("close-popup", |_ctx| {
            std::process::exit(0);
            #[allow(unreachable_code)]
            Value::Void
        });

    // ── Secret agent → PasswordDialog bridge ──
    // Poll the prompt channel via calloop timer. When NM requests secrets,
    // show the PasswordDialog popup; the user's input flows back through the
    // oneshot to the D-Bus thread.
    let prompt_handle = shell.event_loop_handle();
    prompt_handle.add_timer(
        std::time::Duration::from_millis(100),
        move |_, _| {
            let rx = prompt_rx.lock();
            while let Ok(prompt) = rx.try_recv() {
                log::info!(
                    "password prompt requested for: {}",
                    prompt.network_name
                );
                let PendingPrompt {
                    network_name,
                    responder,
                    ..
                } = prompt;
                // MVP: auto-cancel so NM doesn't hang. The real impl shows
                // the PasswordDialog popup via shell.popups().builder(...).
                let _ = responder.send(None);
                let _ = network_name;
            }
            layer_shika::calloop::TimeoutAction::ToDuration(
                std::time::Duration::from_millis(100),
            )
        },
    )?;

    // ── Hot reload: watch the .slint file, recompile on save ──
    let ui_for_reload = ui.clone();
    let _watcher = watch_slint_file(ui_for_reload, move || {
        log::info!("slint file changed — restart-on-save fallback");
        std::process::exit(0);
    })?;

    log::info!("entering event loop");
    shell.run()?;

    // Clean shutdown of the D-Bus task.
    nm_task.abort();
    Ok(())
}

/// Set up a notify file watcher on the .slint file; calls `on_change` on save.
fn watch_slint_file<F>(path: PathBuf, on_change: F) -> notify::Result<()>
where
    F: Fn() + Send + Sync + 'static,
{
    use notify::{EventKind, RecursiveMode, Watcher};
    let on_change = Arc::new(on_change);
    let (tx, rx) = std::sync::mpsc::channel::<notify::Result<notify::Event>>();

    let mut watcher = notify::recommended_watcher(tx)?;
    watcher.watch(&path, RecursiveMode::NonRecursive)?;

    // Spawn a thread to drain events and debounce.
    std::thread::spawn(move || {
        let mut last_fire =
            std::time::Instant::now() - std::time::Duration::from_secs(10);
        for ev in rx {
            if let Ok(e) = ev {
                if matches!(e.kind, EventKind::Modify(_) | EventKind::Create(_)) {
                    let now = std::time::Instant::now();
                    if now.duration_since(last_fire)
                        > std::time::Duration::from_millis(200)
                    {
                        last_fire = now;
                        on_change();
                    }
                }
            }
        }
    });

    // Keep the watcher alive for the process lifetime.
    std::mem::forget(watcher);
    Ok(())
}
