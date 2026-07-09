#!/usr/bin/env bash
set -euo pipefail

hidden() {
  printf '{"text":"","class":"hidden","tooltip":false}\n'
}

if ! command -v nmcli >/dev/null 2>&1; then
  hidden
  exit 0
fi

if ! nmcli -t -f TYPE device status 2>/dev/null | grep -qx 'wifi'; then
  hidden
  exit 0
fi

if [ "$(nmcli -t -f WIFI general 2>/dev/null || true)" = "disabled" ]; then
  printf '{"text":"󰂲","class":"off","tooltip":"Wi-Fi disabled"}\n'
  exit 0
fi

if nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -q '^wifi:connected$'; then
  printf '{"text":"󰤨","class":"connected","tooltip":"Wi-Fi connected"}\n'
else
  printf '{"text":"󰀟","class":"disconnected","tooltip":"Wi-Fi disconnected"}\n'
fi
