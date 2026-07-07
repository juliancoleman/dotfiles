#!/usr/bin/env bash
# CPU usage per-core with temperature
# Multi-host: k10temp on AMD desktop, no CPU die sensor on Asahi (Apple Silicon
# doesn't expose CPU temp to Linux — SMC manages thermals internally).

# --- Sample /proc/stat twice with a short interval for real usage ---
# /proc/stat counters are cumulative since boot, so we need the delta
# between two samples to get instantaneous usage (same method as top/htop).
sample1=$(awk '/^cpu[0-9 ]/ {print $1, $2, $3, $4, $5, $6, $7, $8}' /proc/stat)
sleep 0.5
sample2=$(awk '/^cpu[0-9 ]/ {print $1, $2, $3, $4, $5, $6, $7, $8}' /proc/stat)

# Total CPU usage from delta
# paste gives: $1=name, $2-$8=sample1(user,nice,system,idle,iowait,irq,softirq),
# $9=name(dup), $10-$16=sample2(user,nice,system,idle,iowait,irq,softirq)
total=$(paste <(echo "$sample1" | awk '/^cpu /') <(echo "$sample2" | awk '/^cpu /') | awk '
{
    d_user=$10-$2; d_nice=$11-$3; d_sys=$12-$4; d_idle=$13-$5
    d_total=d_user+d_nice+d_sys+d_idle
    if (d_total > 0) printf "%.0f", (d_user+d_nice+d_sys)*100/d_total
    else print 0
}')

# Per-core usage from delta
cores=""
ncores=$(echo "$sample1" | grep -c '^cpu[0-9]')
for i in $(seq 0 $((ncores - 1))); do
    core_usage=$(paste <(echo "$sample1" | awk -v n="$i" '$1 == "cpu"n') \
                       <(echo "$sample2" | awk -v n="$i" '$1 == "cpu"n') | awk '
    {
        d_idle=$13-$5
        d_total=($10-$2)+($11-$3)+($12-$4)+($13-$5)
        if (d_total > 0) printf "%.0f", (d_total-d_idle)*100/d_total
        else print 0
    }')
    cores="${cores}Core $i: ${core_usage}%\n"
done

# --- CPU temperature ---
# Desktop: k10temp (AMD Tctl). Asahi: no CPU die sensor — use the highest
# macsmc_hwmon reading as a system thermal proxy, labelled honestly.
temp=""
temp_label="Temp"
k10=$(grep -l k10temp /sys/class/hwmon/hwmon*/name 2>/dev/null | head -1)
if [ -n "$k10" ]; then
    temp=$(cat "$k10/temp1_input" 2>/dev/null)
    temp_label="Tctl"
else
    # Apple Silicon: no CPU die temp. Use the warmest macsmc_hwmon sensor
    # as a rough system-thermal proxy.
    macsmc=$(grep -l macsmc_hwmon /sys/class/hwmon/hwmon*/name 2>/dev/null | head -1)
    if [ -n "$macsmc" ]; then
        temp=$(for t in "$macsmc"/temp*_input; do cat "$t" 2>/dev/null; done | sort -rn | head -1)
        temp_label="Sys"
    fi
fi

if [ -n "$temp" ] && [ "$temp" -gt 0 ] 2>/dev/null; then
    temp_c=$(awk "BEGIN {printf \"%.1f\", $temp/1000}")
    temp_line="${temp_label}: ${temp_c}C\n"
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
