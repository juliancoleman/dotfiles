//! Client side of the shell's secure prompt socket: one JSON request line, one JSON reply line.

use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;

#[derive(Serialize, Default)]
pub struct Request {
    pub source: &'static str,
    pub prompt: String,
    pub description: String,
    pub title: String,
    pub error: String,
    pub pid: u32,
    pub lineage: String,
}

#[derive(Deserialize)]
struct Reply {
    secret: Option<String>,
}

pub enum Outcome {
    Secret(String),
    Cancelled,
    Unavailable,
}

fn socket_path() -> Option<PathBuf> {
    if let Some(path) = std::env::var_os("QS_SECURE_SOCKET") {
        return Some(PathBuf::from(path));
    }
    std::env::var_os("XDG_RUNTIME_DIR").map(|dir| PathBuf::from(dir).join("qs-secure.sock"))
}

/// A secret typed on the laptop's screen is wrong for someone working over SSH.
fn remote() -> bool {
    std::env::var_os("SSH_CONNECTION").is_some() || std::env::var_os("SSH_TTY").is_some()
}

pub fn ask(request: &Request) -> Outcome {
    if remote() {
        return Outcome::Unavailable;
    }
    let Some(path) = socket_path() else {
        return Outcome::Unavailable;
    };
    let Ok(mut stream) = UnixStream::connect(path) else {
        return Outcome::Unavailable;
    };
    let Ok(mut line) = serde_json::to_string(request) else {
        return Outcome::Unavailable;
    };
    line.push('\n');
    if stream
        .write_all(line.as_bytes())
        .and_then(|()| stream.flush())
        .is_err()
    {
        return Outcome::Unavailable;
    }

    let mut reply = String::new();
    match BufReader::new(stream).read_line(&mut reply) {
        Ok(0) | Err(_) => Outcome::Cancelled,
        Ok(_) => match serde_json::from_str::<Reply>(&reply) {
            Ok(Reply {
                secret: Some(secret),
            }) => Outcome::Secret(secret),
            _ => Outcome::Cancelled,
        },
    }
}
