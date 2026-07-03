#!/usr/bin/env bash
# Fan speeds from NCT6797D
tooltip=""
for i in 1 2 3 4 5 6; do
    rpm=$(cat /sys/class/hwmon/hwmon3/fan${i}_input 2>/dev/null)
    [ -z "$rpm" ] && continue
    if [ "$rpm" -eq 0 ]; then
        tooltip="${tooltip}Fan ${i}: --\n"
    else
        tooltip="${tooltip}Fan ${i}: ${rpm} RPM\n"
    fi
done

# Trim trailing newline
tooltip=$(echo -e "$tooltip" | sed '/^$/d')

# Escape for JSON
tooltip_escaped=$(echo "$tooltip" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
printf '{"text":"󰈐","tooltip":"%s","class":"normal"}' "$tooltip_escaped"
