#!/usr/bin/env bash
# CPU usage per-core with Tctl temperature
total=$(awk -u '/^cpu / {printf "%.0f", ($2+$4)*100/($2+$4+$5)}' /proc/stat 2>/dev/null || echo 0)

# Per-core usage
cores=""
for i in $(seq 0 15); do
    core_usage=$(awk -v n="$i" -u '
        BEGIN {getline}
        /^cpu/ {idle=$5; total=$2+$3+$4+$5+$6+$7+$8; if (NR-1 == n) printf "%.0f", (total-idle)*100/total}
    ' /proc/stat 2>/dev/null || echo 0)
    cores="${cores}Core $i: ${core_usage}%\n"
done

# CPU temp - Tctl from k10temp (hwmon1)
temp=$(cat /sys/class/hwmon/hwmon1/temp1_input 2>/dev/null || cat /sys/class/hwmon/hwmon*/temp1_input 2>/dev/null | head -1)
if [ -n "$temp" ]; then
    temp_c=$(awk "BEGIN {printf \"%.1f\", $temp/1000}")
    temp_line="Temp: ${temp_c}C\n"
else
    temp_line=""
fi

tooltip="${temp_line}Total: ${total}%\n${cores}"
tooltip=$(echo -e "$tooltip" | sed '/^$/d')

# Critical: CPU temp >= 80C or usage >= 99%
class="normal"
temp_c_int=$(awk "BEGIN {printf \"%.0f\", ${temp:-0}/1000}")
[ "$temp_c_int" -ge 80 ] && class="critical"
[ "$total" -ge 99 ] && class="critical"

# Escape for JSON
tooltip_escaped=$(echo "$tooltip" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
printf '{"text":"󰻠","tooltip":"%s","class":"%s"}' "$tooltip_escaped" "$class"
