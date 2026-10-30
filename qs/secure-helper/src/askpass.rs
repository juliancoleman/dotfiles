//! The askpass contract shared by sudo, ssh, and git: prompt in argv, secret on stdout, non-zero exit to cancel.

use crate::broker::{self, Outcome, Request};
use crate::{lineage, tty};
use std::io::Write;
use std::process::ExitCode;

pub fn run(args: &[String]) -> ExitCode {
    let prompt = args.join(" ");
    match std::env::var("SSH_ASKPASS_PROMPT").as_deref() {
        // Informational ("touch your security key"); nothing to type.
        Ok("none") => return ExitCode::SUCCESS,
        // A yes/no confirmation, which the password prompt can't express honestly.
        Ok("confirm") => {
            eprintln!("qs-askpass: confirmation prompts are not supported");
            return ExitCode::FAILURE;
        }
        _ => {}
    }

    let pid = std::os::unix::process::parent_id();
    let request = Request {
        source: "askpass",
        prompt: prompt.clone(),
        pid,
        lineage: lineage::describe(pid),
        ..Request::default()
    };
    let secret = match broker::ask(&request) {
        Outcome::Secret(secret) => secret,
        Outcome::Cancelled => return ExitCode::FAILURE,
        Outcome::Unavailable => match tty::read_secret(&prompt) {
            Some(secret) => secret,
            None => return ExitCode::FAILURE,
        },
    };

    let mut stdout = std::io::stdout().lock();
    if writeln!(stdout, "{secret}")
        .and_then(|()| stdout.flush())
        .is_err()
    {
        return ExitCode::FAILURE;
    }
    ExitCode::SUCCESS
}
