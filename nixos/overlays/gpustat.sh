# Read-only GPU status for DankMaterialShell (nvidia-smi). No Coolbits / fan writes.
set -u

asahi_gpu() {
  local u
  for u in /sys/class/drm/card*/device/uevent; do
    [ -r "$u" ] || continue
    if grep -q "DRIVER=asahi" "$u" 2>/dev/null; then
      return 0
    fi
  done
  return 1
}

num() {
  local v
  v=$(printf '%s' "${1:-}" | tr -d ' ')
  case "$v" in
    ""|"[N/A]"|"N/A"|"[Not"*) printf '0' ;;
    *) printf '%s' "$v" ;;
  esac
}

json_escape() {
  printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

if asahi_gpu; then
  printf '%s\n' '{"available":false}'
  exit 0
fi

line=$(nvidia-smi --query-gpu=name,temperature.gpu,fan.speed,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw,power.limit,clocks.current.graphics,clocks.current.memory --format=csv,noheader,nounits 2>/dev/null | head -1 || true)
if [ -z "${line:-}" ]; then
  printf '%s\n' '{"available":false}'
  exit 0
fi

IFS=',' read -r name temp fan util memUtil memUsed memTotal power powerLimit coreClock memClock <<EOF
$line
EOF

printf '{"available":true,"name":"%s","temp":%s,"fan":%s,"util":%s,"memUtil":%s,"memUsed":%s,"memTotal":%s,"power":%s,"powerLimit":%s,"coreClock":%s,"memClock":%s}\n' \
  "$(json_escape "$(printf '%s' "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')")" \
  "$(num "$temp")" \
  "$(num "$fan")" \
  "$(num "$util")" \
  "$(num "$memUtil")" \
  "$(num "$memUsed")" \
  "$(num "$memTotal")" \
  "$(num "$power")" \
  "$(num "$powerLimit")" \
  "$(num "$coreClock")" \
  "$(num "$memClock")"
