# NCT6797D fan helper for DankMaterialShell.
# status | auto [id] | manual <id> <15-100> | manual-all <15-100>
set -u

find_nct() {
  local n
  n=$(grep -l '^nct6797$' /sys/class/hwmon/hwmon*/name 2>/dev/null | head -1 || true)
  if [ -n "$n" ]; then
    dirname "$n"
  fi
}

clamp_pct() {
  local pct="${1:-50}"
  if [ "$pct" -lt 15 ]; then
    pct=15
  fi
  if [ "$pct" -gt 100 ]; then
    pct=100
  fi
  printf '%s' "$pct"
}

valid_id() {
  case "${1:-}" in
    1|2|3|4|5|6) return 0 ;;
    *) return 1 ;;
  esac
}

status_json() {
  local dir mode pct i rpm pwm enable maxpwm manual_count auto_count
  dir=$(find_nct)
  if [ -z "${dir:-}" ]; then
    printf '%s\n' '{"available":false,"mode":"none","percent":0,"manualCount":0,"fans":[]}'
    return 0
  fi

  manual_count=0
  auto_count=0
  for i in 1 2 3 4 5 6; do
    [ -r "$dir/pwm${i}_enable" ] || continue
    if [ "$(cat "$dir/pwm${i}_enable")" = "1" ]; then
      manual_count=$((manual_count + 1))
    else
      auto_count=$((auto_count + 1))
    fi
  done

  if [ "$manual_count" -eq 0 ]; then
    mode="auto"
  elif [ "$auto_count" -eq 0 ]; then
    mode="manual"
  else
    mode="mixed"
  fi

  maxpwm=0
  for i in 1 2 3 4 5 6; do
    rpm=$(cat "$dir/fan${i}_input" 2>/dev/null || echo 0)
    pwm=$(cat "$dir/pwm$i" 2>/dev/null || echo 0)
    if [ "${rpm:-0}" -gt 0 ] && [ "${pwm:-0}" -gt "$maxpwm" ]; then
      maxpwm=$pwm
    fi
  done
  if [ "$maxpwm" -eq 0 ]; then
    pwm=$(cat "$dir/pwm2" 2>/dev/null || echo 0)
    maxpwm=${pwm:-0}
  fi
  pct=$(( maxpwm * 100 / 255 ))

  printf '{"available":true,"mode":"%s","percent":%s,"manualCount":%s,"fans":[' "$mode" "$pct" "$manual_count"
  local first=1
  for i in 1 2 3 4 5 6; do
    [ -e "$dir/pwm$i" ] || continue
    rpm=$(cat "$dir/fan${i}_input" 2>/dev/null || echo 0)
    pwm=$(cat "$dir/pwm$i" 2>/dev/null || echo 0)
    enable=$(cat "$dir/pwm${i}_enable" 2>/dev/null || echo 0)
    local fpct=$(( pwm * 100 / 255 ))
    if [ "$first" -eq 1 ]; then
      first=0
    else
      printf ','
    fi
    printf '{"id":%s,"rpm":%s,"pwm":%s,"percent":%s,"enable":%s}' "$i" "$rpm" "$pwm" "$fpct" "$enable"
  done
  printf ']}\n'
}

set_auto_all() {
  local dir i
  dir=$(find_nct)
  [ -n "${dir:-}" ] || return 1
  for i in 1 2 3 4 5 6; do
    [ -w "$dir/pwm${i}_enable" ] || continue
    printf '5\n' > "$dir/pwm${i}_enable"
  done
}

set_auto_one() {
  local dir id
  id="$1"
  valid_id "$id" || return 1
  dir=$(find_nct)
  [ -n "${dir:-}" ] || return 1
  [ -w "$dir/pwm${id}_enable" ] || return 1
  printf '5\n' > "$dir/pwm${id}_enable"
}

set_manual_one() {
  local dir id pct pwm
  id="$1"
  pct=$(clamp_pct "${2:-50}")
  valid_id "$id" || return 1
  pwm=$(( pct * 255 / 100 ))
  dir=$(find_nct)
  [ -n "${dir:-}" ] || return 1
  [ -w "$dir/pwm${id}_enable" ] || return 1
  printf '1\n' > "$dir/pwm${id}_enable"
  printf '%s\n' "$pwm" > "$dir/pwm$id"
  printf '1\n' > "$dir/pwm${id}_enable"
}

set_manual_all() {
  local i pct
  pct=$(clamp_pct "${1:-50}")
  for i in 1 2 3 4 5 6; do
    set_manual_one "$i" "$pct" || true
  done
}

cmd="${1:-status}"
case "$cmd" in
  status)
    status_json
    ;;
  auto)
    if [ -n "${2:-}" ]; then
      set_auto_one "$2"
    else
      set_auto_all
    fi
    status_json
    ;;
  manual)
    if [ -n "${3:-}" ]; then
      set_manual_one "$2" "$3"
    else
      set_manual_all "${2:-50}"
    fi
    status_json
    ;;
  manual-all)
    set_manual_all "${2:-50}"
    status_json
    ;;
  hold)
    shift
    for spec in "$@"; do
      [ -n "$spec" ] || continue
      set_manual_one "${spec%%=*}" "${spec#*=}" || true
    done
    status_json
    ;;
  *)
    echo "usage: dms-fanctl status|auto [id]|manual <id> <pct>|manual-all <pct>|hold id=pct..." >&2
    exit 2
    ;;
esac
