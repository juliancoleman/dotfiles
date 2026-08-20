#!/bin/sh
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
HYPRLOCK_CONF="$HOME/dotfiles/nixos/niri/hyprlock.conf"
hyprlock --config "$HYPRLOCK_CONF"
