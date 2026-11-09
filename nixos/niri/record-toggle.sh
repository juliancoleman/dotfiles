#!/usr/bin/env bash
# Screen recording toggle: first press selects a region (drag with the mouse,
# Esc cancels) and starts recording; pressing again stops it. A press during
# region selection cancels the selection.
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if pgrep -x wf-recorder >/dev/null; then
    pkill -SIGINT -x wf-recorder
    exit 0
fi
if pgrep -x slurp >/dev/null; then
    pkill -x slurp
    exit 0
fi

RECORDING_PATH="$HOME/Videos/Recordings"
mkdir -p "$RECORDING_PATH"
FILENAME="Recording from $(date '+%Y-%m-%d %H-%M-%S').mp4"
FILEPATH="$RECORDING_PATH/$FILENAME"

notify-send "Recording" "Drag to select a region. Recording starts when you release." 2>/dev/null

# Cancelled selection (Esc / second press) -> slurp exits non-zero, abort.
GEOMETRY="$(slurp)" || exit 0

notify-send "Recording" "Started. Press Super+Shift+5 to stop." 2>/dev/null

# Blocks until SIGINT; wf-recorder finalizes the file on SIGINT.
wf-recorder -g "$GEOMETRY" -f "$FILEPATH" 2>/dev/null

if [ -s "$FILEPATH" ]; then
    notify-send "Recording" "Saved to $FILENAME" 2>/dev/null
fi
