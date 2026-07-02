#!/usr/bin/env bash
# Clock with Japanese AM/PM (vertically split) + calendar tooltip
ampm=$(date +%p)
if [[ "$ampm" == "AM" ]]; then
    jpampm="午前"
else
    jpampm="午後"
fi
hour=$(date +%I)
min=$(date +%M)

# Split JP chars vertically using grep -o (UTF-8 safe)
jp_vertical=$(printf '%s' "$jpampm" | grep -o . | paste -sd'\n')
vertical=$(printf "%s\n%s\n%s" "$jp_vertical" "$hour" "$min")

# Calendar
calendar=$(cal)

# Build JSON manually with proper UTF-8
text_escaped=$(printf '%s' "$vertical" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
cal_escaped=$(printf '%s' "$calendar" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

printf '{"text":"%s","tooltip":"%s"}' "$text_escaped" "$cal_escaped"
