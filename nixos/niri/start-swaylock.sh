#!/bin/sh
# Lock screen on startup — frosted glass wallpaper via hyprlock
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Wait up to 5 seconds for the Wayland socket
for i in $(seq 1 50); do
    if [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
        break
    fi
    sleep 0.1
done

# Give swww 0.8s to start daemon and paint wallpaper behind lock surface
sleep 0.8

hyprlock --config /home/julian/dotfiles/nixos/niri/hyprlock.conf
