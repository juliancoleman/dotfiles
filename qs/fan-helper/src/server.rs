use std::{
    collections::BTreeSet,
    io::{BufRead, BufReader, Read, Write},
    os::unix::net::{UnixListener, UnixStream},
    sync::{Arc, Mutex, MutexGuard},
    thread,
    time::{Duration, Instant},
};

use serde::{Deserialize, Serialize};

use crate::{
    error::{Error, Result},
    sysfs::Controller,
};

const MAX_REQUEST_BYTES: u64 = 4096;
const MAX_CLIENTS: usize = 8;
const WATCHDOG_TICK: Duration = Duration::from_millis(200);

#[derive(Debug, Deserialize)]
#[serde(tag = "op", rename_all = "camelCase", deny_unknown_fields)]
enum Request {
    Status,
    Set { fan: String, percent: u8 },
    Auto { fan: String },
    Release,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct Response {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
    available: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    reason: Option<String>,
    lease_seconds: u32,
    renewal_seconds: u32,
    holding: bool,
    busy: bool,
    fans: Vec<FanStatus>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct FanStatus {
    id: String,
    label: String,
    mode: &'static str,
    percent: u8,
    minimum_percent: u8,
    rpm: u32,
}

struct Holder {
    client: u64,
    expires_at: Instant,
}

#[derive(Default)]
struct State {
    holder: Option<Holder>,
    manual: BTreeSet<String>,
    clients: usize,
    next_client: u64,
}

pub struct Helper {
    controller: Controller,
    lease: Duration,
    state: Mutex<State>,
}

impl Helper {
    pub fn new(controller: Controller) -> Self {
        let lease = Duration::from_secs(u64::from(controller.policy().lease_seconds));
        Self {
            controller,
            lease,
            state: Mutex::new(State::default()),
        }
    }

    pub fn controller(&self) -> &Controller {
        &self.controller
    }

    fn lock(&self) -> MutexGuard<'_, State> {
        self.state
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    pub fn force_auto(&self, reason: &str) {
        let mut state = self.lock();
        self.force_auto_locked(&mut state, reason);
    }

    fn force_auto_locked(&self, state: &mut State, reason: &str) {
        if state.holder.is_some() || !state.manual.is_empty() {
            eprintln!("returning every fan to firmware control: {reason}");
        }
        state.holder = None;
        state.manual.clear();
        self.controller.restore_all_best_effort();
    }

    fn connect(&self) -> Option<u64> {
        let mut state = self.lock();
        if state.clients >= MAX_CLIENTS {
            return None;
        }
        state.clients += 1;
        state.next_client += 1;
        Some(state.next_client)
    }

    fn disconnect(&self, client: u64) {
        let mut state = self.lock();
        state.clients -= 1;
        if state
            .holder
            .as_ref()
            .is_some_and(|holder| holder.client == client)
        {
            self.force_auto_locked(&mut state, "controlling client disconnected");
        }
    }

    fn watchdog_tick(&self) {
        let mut state = self.lock();
        let Some(holder) = &state.holder else {
            return;
        };
        if Instant::now() >= holder.expires_at {
            self.force_auto_locked(&mut state, "lease expired");
        } else if let Err(error) = self.controller.ensure_thermally_safe() {
            self.force_auto_locked(&mut state, &error.to_string());
        }
    }

    fn handle(&self, client: u64, line: &str) -> String {
        let mut state = self.lock();
        let holds = |state: &State| {
            state
                .holder
                .as_ref()
                .is_some_and(|holder| holder.client == client)
        };
        if holds(&state) {
            state.holder = Some(Holder {
                client,
                expires_at: Instant::now() + self.lease,
            });
        }

        let result = serde_json::from_str::<Request>(line)
            .map_err(Error::from)
            .and_then(|request| self.apply(&mut state, client, request));

        let error = result.err().map(|error| error.to_string());
        let snapshots = self.controller.snapshots();
        let policy = self.controller.policy();
        let response = Response {
            ok: error.is_none(),
            error,
            available: snapshots.is_ok(),
            reason: snapshots.as_ref().err().map(ToString::to_string),
            lease_seconds: policy.lease_seconds,
            renewal_seconds: policy.renewal_seconds,
            holding: holds(&state),
            busy: state.holder.is_some() && !holds(&state),
            fans: snapshots
                .unwrap_or_default()
                .into_iter()
                .map(|fan| FanStatus {
                    id: fan.id,
                    label: fan.label,
                    mode: fan.mode.as_str(),
                    percent: fan.percent,
                    minimum_percent: fan.minimum_percent,
                    rpm: fan.rpm,
                })
                .collect(),
        };
        serde_json::to_string(&response).expect("response serializes")
    }

    fn apply(&self, state: &mut State, client: u64, request: Request) -> Result<()> {
        let other_holder = state
            .holder
            .as_ref()
            .is_some_and(|holder| holder.client != client);
        match request {
            Request::Status => Ok(()),
            Request::Set { fan, percent } => {
                if other_holder {
                    return Err(Error::lease("another client is controlling the fans"));
                }
                if let Err(error) = self.controller.set_percent(&fan, percent) {
                    self.force_auto_locked(state, &error.to_string());
                    return Err(error);
                }
                state.manual.insert(fan);
                state.holder = Some(Holder {
                    client,
                    expires_at: Instant::now() + self.lease,
                });
                Ok(())
            }
            Request::Auto { fan } => {
                if other_holder {
                    return Err(Error::lease("another client is controlling the fans"));
                }
                self.controller.restore_fan(&fan)?;
                state.manual.remove(&fan);
                if state.manual.is_empty() {
                    state.holder = None;
                }
                Ok(())
            }
            Request::Release => {
                if !other_holder {
                    self.force_auto_locked(state, "client released control");
                }
                Ok(())
            }
        }
    }
}

pub fn spawn_watchdog(helper: Arc<Helper>) {
    thread::spawn(move || {
        loop {
            thread::sleep(WATCHDOG_TICK);
            helper.watchdog_tick();
        }
    });
}

pub fn serve(helper: Arc<Helper>, listener: UnixListener) -> Result<()> {
    for stream in listener.incoming() {
        let stream = match stream {
            Ok(stream) => stream,
            Err(error) => {
                eprintln!("error: failed to accept a client: {error}");
                continue;
            }
        };
        let Some(client) = helper.connect() else {
            continue;
        };
        let helper = Arc::clone(&helper);
        thread::spawn(move || {
            if let Err(error) = serve_client(&helper, client, stream) {
                eprintln!("client {client} ended with an error: {error}");
            }
            helper.disconnect(client);
        });
    }
    Ok(())
}

fn serve_client(helper: &Helper, client: u64, stream: UnixStream) -> Result<()> {
    let mut writer = stream.try_clone()?;
    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    loop {
        line.clear();
        let read = (&mut reader).take(MAX_REQUEST_BYTES).read_line(&mut line)?;
        if read == 0 {
            return Ok(());
        }
        if !line.ends_with('\n') {
            return Err(Error::request("request exceeds 4 KiB or is unterminated"));
        }
        let request = line.trim();
        if request.is_empty() {
            continue;
        }
        let response = helper.handle(client, request);
        writer.write_all(response.as_bytes())?;
        writer.write_all(b"\n")?;
    }
}

#[cfg(test)]
mod tests {
    use std::{thread, time::Duration};

    use serde_json::Value;

    use super::Helper;
    use crate::sysfs::tests::FakeHwmon;

    fn call(helper: &Helper, client: u64, request: &str) -> Value {
        serde_json::from_str(&helper.handle(client, request)).unwrap()
    }

    fn helper(hw: &FakeHwmon) -> Helper {
        let helper = Helper::new(hw.controller());
        helper.connect();
        helper.connect();
        helper
    }

    #[test]
    fn status_reports_fans_without_taking_the_lease() {
        let hw = FakeHwmon::new();
        let helper = helper(&hw);
        let status = call(&helper, 1, r#"{"op":"status"}"#);
        assert_eq!(status["ok"], true);
        assert_eq!(status["available"], true);
        assert_eq!(status["holding"], false);
        assert_eq!(status["fans"][0]["id"], "nct6797:pwm1");
        assert_eq!(status["fans"][0]["mode"], "auto");
        assert_eq!(status["fans"][0]["minimumPercent"], 30);
    }

    #[test]
    fn set_takes_the_lease_and_excludes_other_clients() {
        let hw = FakeHwmon::new();
        let helper = helper(&hw);
        let set = call(
            &helper,
            1,
            r#"{"op":"set","fan":"nct6797:pwm1","percent":70}"#,
        );
        assert_eq!(set["holding"], true);
        assert_eq!(set["fans"][0]["mode"], "manual");

        let other = call(
            &helper,
            2,
            r#"{"op":"set","fan":"nct6797:pwm1","percent":40}"#,
        );
        assert_eq!(other["ok"], false);
        assert_eq!(other["busy"], true);
        assert_eq!(other["fans"][0]["percent"], 70);
    }

    #[test]
    fn disconnect_restores_auto() {
        let hw = FakeHwmon::new();
        let helper = helper(&hw);
        call(
            &helper,
            1,
            r#"{"op":"set","fan":"nct6797:pwm1","percent":70}"#,
        );
        helper.disconnect(1);
        assert_eq!(hw.read("pwm1_enable"), "5");
        assert_eq!(call(&helper, 2, r#"{"op":"status"}"#)["busy"], false);
    }

    #[test]
    fn auto_on_last_manual_fan_drops_the_lease() {
        let hw = FakeHwmon::new();
        let helper = helper(&hw);
        call(
            &helper,
            1,
            r#"{"op":"set","fan":"nct6797:pwm1","percent":70}"#,
        );
        let auto = call(&helper, 1, r#"{"op":"auto","fan":"nct6797:pwm1"}"#);
        assert_eq!(auto["holding"], false);
        assert_eq!(hw.read("pwm1_enable"), "5");
    }

    #[test]
    fn lease_expiry_restores_auto() {
        let hw = FakeHwmon::new();
        let mut helper = helper(&hw);
        helper.lease = Duration::from_millis(50);
        call(
            &helper,
            1,
            r#"{"op":"set","fan":"nct6797:pwm1","percent":70}"#,
        );
        thread::sleep(Duration::from_millis(80));
        helper.watchdog_tick();
        assert_eq!(hw.read("pwm1_enable"), "5");
    }

    #[test]
    fn critical_temperature_revokes_the_lease() {
        let hw = FakeHwmon::new();
        let helper = helper(&hw);
        call(
            &helper,
            1,
            r#"{"op":"set","fan":"nct6797:pwm1","percent":70}"#,
        );
        hw.set_temperature(95_000);
        helper.watchdog_tick();
        assert_eq!(hw.read("pwm1_enable"), "5");
        assert_eq!(call(&helper, 1, r#"{"op":"status"}"#)["holding"], false);
    }

    #[test]
    fn malformed_requests_are_rejected_without_side_effects() {
        let hw = FakeHwmon::new();
        let helper = helper(&hw);
        let reply = call(
            &helper,
            1,
            r#"{"op":"set","fan":"nct6797:pwm1","percent":300}"#,
        );
        assert_eq!(reply["ok"], false);
        assert_eq!(hw.read("pwm1_enable"), "5");
    }

    #[test]
    fn rejected_set_from_the_holder_restores_auto() {
        let hw = FakeHwmon::new();
        let helper = helper(&hw);
        call(
            &helper,
            1,
            r#"{"op":"set","fan":"nct6797:pwm1","percent":70}"#,
        );
        let reply = call(
            &helper,
            1,
            r#"{"op":"set","fan":"nct6797:pwm1","percent":150}"#,
        );
        assert_eq!(reply["ok"], false);
        assert_eq!(reply["holding"], false);
        assert_eq!(hw.read("pwm1_enable"), "5");
    }
}
