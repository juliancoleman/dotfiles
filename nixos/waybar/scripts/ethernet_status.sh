#!/usr/bin/env bash
set -euo pipefail

if command -v nmcli >/dev/null 2>&1 && nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -q '^ethernet:connected'; then
  printf '{"text":"󰈀","class":"connected","tooltip":"Wired connected"}\n'
else
  printf '{"text":"","class":"hidden","tooltip":false}\n'
fi
