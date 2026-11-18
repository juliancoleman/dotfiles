#!/bin/sh
# Idle, sleep and Super+Alt+L can all ask at once; one lock screen is enough.
pidof hyprlock >/dev/null && exit 0
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
# Reads ~/.config/hypr/hyprlock.conf, which Home Manager writes from niri/hyprlock.conf.
hyprlock
