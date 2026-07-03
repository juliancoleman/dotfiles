#!/usr/bin/env bash
# Screenshot: capture screen, copy to clipboard, notify
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

SCREENSHOT_PATH="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_PATH"
FILENAME="Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"
FILEPATH="$SCREENSHOT_PATH/$FILENAME"

# Capture the full screen
grim "$FILEPATH" 2>/dev/null

if [ $? -eq 0 ]; then
    # Copy to clipboard
    wl-copy < "$FILEPATH" 2>/dev/null
    # Notify
    notify-send "Screenshot" "Saved to $FILENAME and copied to clipboard" 2>/dev/null
else
    notify-send "Screenshot" "Failed to capture" 2>/dev/null
fi
