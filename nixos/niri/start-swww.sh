#!/bin/sh
# Start swww wallpaper daemon, wait for it, then set the wallpaper
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

swww-daemon &
DAEMON_PID=$!

# Wait up to 5 seconds for the daemon socket
for i in $(seq 1 50); do
    if [ -S "$XDG_RUNTIME_DIR/wayland-1-swww-daemon..sock" ] 2>/dev/null; then
        break
    fi
    sleep 0.1
done

swww img "$HOME/dotfiles/nixos/niri/wallpapers/tj-holowaychuk-mist-over-banff-ave.jpg" \
    --transition-type grow \
    --transition-fps 165
