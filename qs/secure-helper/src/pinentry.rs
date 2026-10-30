//! Just enough of the Assuan pinentry protocol for gpg-agent: GETPIN goes to the shell,
//! everything else is acknowledged or declined.

use crate::broker::{self, Outcome, Request};
use crate::lineage;
use std::io::{BufRead, Write};
use std::process::ExitCode;

const CANCELLED: &str = "ERR 83886179 Operation cancelled <Pinentry>";
const UNAVAILABLE: &str = "ERR 83886360 No secure prompt available <Pinentry>";
const UNKNOWN: &str = "ERR 536871187 Unknown IPC command <User defined source 1>";

#[derive(Default)]
struct State {
    description: String,
    prompt: String,
    title: String,
    error: String,
}

fn decode(text: &str) -> String {
    let bytes = text.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let hex = std::str::from_utf8(&bytes[i + 1..i + 3]).ok();
            if let Some(byte) = hex.and_then(|hex| u8::from_str_radix(hex, 16).ok()) {
                out.push(byte);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn encode(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    for c in text.chars() {
        match c {
            '%' => out.push_str("%25"),
            '\r' => out.push_str("%0D"),
            '\n' => out.push_str("%0A"),
            _ => out.push(c),
        }
    }
    out
}

fn get_pin(state: &mut State) -> Vec<String> {
    let pid = std::os::unix::process::parent_id();
    let request = Request {
        source: "pinentry",
        prompt: std::mem::take(&mut state.prompt),
        description: state.description.clone(),
        title: state.title.clone(),
        error: std::mem::take(&mut state.error),
        pid,
        lineage: lineage::describe(pid),
    };
    match broker::ask(&request) {
        Outcome::Secret(secret) => vec![format!("D {}", encode(&secret)), "OK".into()],
        Outcome::Cancelled => vec![CANCELLED.into()],
        Outcome::Unavailable => vec![UNAVAILABLE.into()],
    }
}

pub fn run() -> ExitCode {
    let stdin = std::io::stdin();
    let mut stdout = std::io::stdout().lock();
    let mut state = State::default();
    if writeln!(stdout, "OK Pleased to meet you")
        .and_then(|()| stdout.flush())
        .is_err()
    {
        return ExitCode::FAILURE;
    }

    for line in stdin.lock().lines() {
        let Ok(line) = line else { break };
        let (command, rest) = line.split_once(' ').unwrap_or((line.as_str(), ""));
        let rest = decode(rest);
        let mut bye = false;
        let replies: Vec<String> = match command.to_ascii_uppercase().as_str() {
            "SETDESC" => {
                state.description = rest;
                vec!["OK".into()]
            }
            "SETPROMPT" => {
                state.prompt = rest;
                vec!["OK".into()]
            }
            "SETTITLE" => {
                state.title = rest;
                vec!["OK".into()]
            }
            "SETERROR" => {
                state.error = rest;
                vec!["OK".into()]
            }
            "RESET" => {
                state = State::default();
                vec!["OK".into()]
            }
            "GETPIN" => get_pin(&mut state),
            // Only a one-button CONFIRM is a plain message; a real yes/no can't be answered from a password field.
            "CONFIRM" if rest.contains("--one-button") => vec!["OK".into()],
            "CONFIRM" => vec![CANCELLED.into()],
            "GETINFO" => match rest.trim() {
                "flavor" => vec!["D qs".into(), "OK".into()],
                "version" => vec![format!("D {}", env!("CARGO_PKG_VERSION")), "OK".into()],
                "pid" => vec![format!("D {}", std::process::id()), "OK".into()],
                _ => vec!["OK".into()],
            },
            "BYE" => {
                bye = true;
                vec!["OK closing connection".into()]
            }
            "OPTION" | "MESSAGE" | "NOP" | "SETOK" | "SETCANCEL" | "SETNOTOK" | "SETKEYINFO"
            | "SETTIMEOUT" | "SETQUALITYBAR" | "SETQUALITYBAR_TT" | "SETREPEAT"
            | "SETREPEATERROR" | "SETREPEATOK" | "SETGENPIN" | "SETGENPIN_TT"
            | "CLEARPASSPHRASE" => vec!["OK".into()],
            _ => vec![UNKNOWN.into()],
        };
        for reply in replies {
            if writeln!(stdout, "{reply}").is_err() {
                return ExitCode::FAILURE;
            }
        }
        if stdout.flush().is_err() || bye {
            break;
        }
    }
    ExitCode::SUCCESS
}

#[cfg(test)]
mod tests {
    use super::{decode, encode};

    #[test]
    fn round_trips_assuan_escapes() {
        assert_eq!(decode("Line%0Atwo%25"), "Line\ntwo%");
        assert_eq!(encode("a%b\nc"), "a%25b%0Ac");
        assert_eq!(decode("trailing%"), "trailing%");
        assert_eq!(decode("%4"), "%4");
    }
}
