#!/usr/bin/env bash
# Blank screen via Niri DPMS (lighter than suspend)
export NIRI_SOCKET=$(ls /run/user/$(id -u)/niri.*.sock 2>/dev/null | head -1)
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export XDG_RUNTIME_DIR=/run/user/$(id -u)
niri msg action power-off-monitors
