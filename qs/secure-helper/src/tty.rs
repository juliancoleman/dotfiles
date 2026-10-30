//! Fallback when the shell can't be reached: read the secret from the controlling terminal with echo off.

use std::fs::OpenOptions;
use std::io::{BufRead, BufReader, Write};
use std::os::fd::AsRawFd;

pub fn read_secret(prompt: &str) -> Option<String> {
    let tty = OpenOptions::new()
        .read(true)
        .write(true)
        .open("/dev/tty")
        .ok()?;
    let fd = tty.as_raw_fd();

    // SAFETY: termios is plain data and fd is an open terminal for the duration of this function.
    let mut saved: libc::termios = unsafe { std::mem::zeroed() };
    if unsafe { libc::tcgetattr(fd, &raw mut saved) } != 0 {
        return None;
    }
    let mut quiet = saved;
    quiet.c_lflag &= !libc::ECHO;
    quiet.c_lflag |= libc::ECHONL;
    unsafe { libc::tcsetattr(fd, libc::TCSAFLUSH, &raw const quiet) };

    let mut writer = &tty;
    let _ = writer.write_all(prompt.as_bytes());
    let _ = writer.flush();
    let mut line = String::new();
    let read = BufReader::new(&tty).read_line(&mut line);

    unsafe { libc::tcsetattr(fd, libc::TCSAFLUSH, &raw const saved) };
    read.ok().filter(|&n| n > 0)?;
    Some(line.trim_end_matches(['\r', '\n']).to_owned())
}
