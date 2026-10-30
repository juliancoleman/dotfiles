//! Who is asking: the requester's command line, then each process name up to init.
//! The shell turns this into the prompt's title and app icon.

use std::fs;

fn parent(pid: u32) -> Option<u32> {
    let stat = fs::read_to_string(format!("/proc/{pid}/stat")).ok()?;
    // comm may contain spaces and parentheses; the fields after it start past the last ')'.
    let rest = &stat[stat.rfind(')')? + 1..];
    rest.split_whitespace().nth(1)?.parse().ok()
}

pub fn describe(pid: u32) -> String {
    let cmdline = fs::read(format!("/proc/{pid}/cmdline"))
        .map(|bytes| String::from_utf8_lossy(&bytes).replace('\0', " "))
        .unwrap_or_default();
    let mut lines = vec![cmdline.trim().to_owned()];
    let mut current = pid;
    for _ in 0..32 {
        if current <= 1 {
            break;
        }
        if let Ok(comm) = fs::read_to_string(format!("/proc/{current}/comm")) {
            lines.push(comm.trim().to_owned());
        }
        match parent(current) {
            Some(next) => current = next,
            None => break,
        }
    }
    lines.join("\n")
}
