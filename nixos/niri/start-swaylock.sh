#!/bin/sh
# Lock screen on startup — frosted glass wallpaper via hyprlock
# Wait for Wayland display to be ready before locking
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Wait up to 10 seconds for the Wayland socket
for i in $(seq 1 100); do
    if [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        break
    fi
    sleep 0.1
done

hyprlock --config /home/julian/dotfiles/nixos/niri/hyprlock.conf
