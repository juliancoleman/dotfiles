#!/usr/bin/env bash
# Fan speeds from NCT6797D + GPU fan
# Find the nct6797 hwmon path dynamically (index can change between boots)
NCT_HWMON=$(grep -l nct6797 /sys/class/hwmon/hwmon*/name 2>/dev/null | head -1)
NCT_DIR=$(dirname "$NCT_HWMON" 2>/dev/null)

tooltip=""

# Chassis fans from NCT6797D
if [ -n "$NCT_DIR" ]; then
    for i in 1 2 3 4 5 6; do
        rpm=$(cat "${NCT_DIR}/fan${i}_input" 2>/dev/null)
        [ -z "$rpm" ] && continue
        if [ "$rpm" -eq 0 ]; then
            tooltip="${tooltip}Fan ${i}: --\n"
        else
            tooltip="${tooltip}Fan ${i}: ${rpm} RPM\n"
        fi
    done
fi

# GPU fan speed (percentage)
gpu_fan=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader,nounits 2>/dev/null)
if [ -n "$gpu_fan" ]; then
    tooltip="${tooltip}GPU: ${gpu_fan}%\n"
fi

# Trim trailing newline
tooltip=$(echo -e "$tooltip" | sed '/^$/d')

# Escape for JSON
tooltip_escaped=$(echo "$tooltip" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
printf '{"text":"󰈐","tooltip":"%s","class":"normal"}' "$tooltip_escaped"
