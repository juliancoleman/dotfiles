//! `pw-record --raw --format s16 --channels 1 --rate R - | qs-meter [--rate R] [--fps N]`
//!
//! Reads signed 16-bit little-endian mono PCM on stdin and writes one `peak rms` line per
//! window on stdout, both as linear fractions of full scale with three decimals. A window is
//! `rate / fps` samples, so the default 8000 Hz at 30 fps reports every 266 samples (~33 ms).
//! Exits when stdin closes or stdout is gone, so killing either end of the pipe ends it.

use std::io::{self, BufWriter, Read, Write};
use std::process::ExitCode;

const USAGE: &str = "usage: qs-meter [--rate HZ] [--fps N]";

struct Options {
    rate: u32,
    fps: u32,
}

fn parse_args() -> Result<Options, String> {
    let mut options = Options { rate: 8000, fps: 30 };
    let mut args = std::env::args().skip(1);
    while let Some(flag) = args.next() {
        let value = args.next().ok_or_else(|| format!("{flag} needs a value"))?;
        let parsed: u32 = value.parse().map_err(|_| format!("{flag}: not a number: {value}"))?;
        if parsed == 0 {
            return Err(format!("{flag}: must be positive"));
        }
        match flag.as_str() {
            "--rate" => options.rate = parsed,
            "--fps" => options.fps = parsed,
            _ => return Err(format!("unknown flag {flag}")),
        }
    }
    Ok(options)
}

fn main() -> ExitCode {
    let options = match parse_args() {
        Ok(options) => options,
        Err(message) => {
            eprintln!("qs-meter: {message}\n{USAGE}");
            return ExitCode::from(2);
        }
    };
    let window = (options.rate / options.fps).max(1) as usize;
    let mut stdin = io::stdin().lock();
    let mut stdout = BufWriter::new(io::stdout().lock());
    let mut buffer = vec![0u8; window * 2];

    loop {
        if let Err(error) = stdin.read_exact(&mut buffer) {
            if error.kind() == io::ErrorKind::UnexpectedEof {
                return ExitCode::SUCCESS;
            }
            eprintln!("qs-meter: stdin: {error}");
            return ExitCode::FAILURE;
        }
        let mut peak: i32 = 0;
        let mut energy: f64 = 0.0;
        for pair in buffer.chunks_exact(2) {
            let sample = i16::from_le_bytes([pair[0], pair[1]]) as i32;
            peak = peak.max(sample.abs());
            energy += (sample as f64) * (sample as f64);
        }
        let scale = i16::MAX as f64;
        let peak = peak as f64 / scale;
        let rms = (energy / window as f64).sqrt() / scale;
        if writeln!(stdout, "{peak:.3} {rms:.3}").and_then(|_| stdout.flush()).is_err() {
            // Reader went away; nothing left to report to.
            return ExitCode::SUCCESS;
        }
    }
}
