#!/bin/sh
# Battery widget for waybar — MacBook only
# Returns JSON with battery icon, percentage, and time estimate in tooltip
# On systems without a battery, outputs nothing (module hidden)

BAT="/sys/class/power_supply/macsmc-battery"

if [ ! -d "$BAT" ]; then
    echo '{"text":"","class":"hidden","tooltip":""}'
    exit 0
fi

capacity=$(cat "$BAT/capacity" 2>/dev/null || echo "0")
status=$(cat "$BAT/status" 2>/dev/null || echo "Unknown")
time_to_empty=$(cat "$BAT/time_to_empty_now" 2>/dev/null || echo "0")
time_to_full=$(cat "$BAT/time_to_full_now" 2>/dev/null || echo "0")

# Battery health (max capacity vs design)
energy_full=$(cat "$BAT/energy_full" 2>/dev/null || echo "0")
energy_design=$(cat "$BAT/energy_full_design" 2>/dev/null || echo "1")
if [ "$energy_design" -gt 0 ] 2>/dev/null; then
    health=$((energy_full * 100 / energy_design))
else
    health=0
fi

# Format time estimate
format_time() {
    seconds=$1
    if [ "$seconds" -gt 0 ] 2>/dev/null; then
        hours=$((seconds / 3600))
        minutes=$(( (seconds % 3600) / 60 ))
        if [ "$hours" -gt 0 ]; then
            echo "${hours}h ${minutes}m"
        else
            echo "${minutes}m"
        fi
    else
        echo "—"
    fi
}

# Pick icon based on capacity
if [ "$capacity" -ge 90 ]; then
    icon="󰁹"
elif [ "$capacity" -ge 80 ]; then
    icon="󰂂"
elif [ "$capacity" -ge 70 ]; then
    icon="󰂁"
elif [ "$capacity" -ge 60 ]; then
    icon="󰂀"
elif [ "$capacity" -ge 50 ]; then
    icon="󰁿"
elif [ "$capacity" -ge 40 ]; then
    icon="󰁾"
elif [ "$capacity" -ge 30 ]; then
    icon="󰁽"
elif [ "$capacity" -ge 20 ]; then
    icon="󰁼"
elif [ "$capacity" -ge 10 ]; then
    icon="󰁻"
else
    icon="󰁺"
fi

# Charging icon overlay
if [ "$status" = "Charging" ]; then
    icon="󰂄"
    tooltip="Charging: ${capacity}%\nTime to full: $(format_time "$time_to_full")\nBattery health: ${health}%"
elif [ "$status" = "Full" ]; then
    icon="󰁹"
    tooltip="Full: ${capacity}%\nBattery health: ${health}%"
else
    tooltip="${capacity}%\nTime remaining: $(format_time "$time_to_empty")\nBattery health: ${health}%"
fi

# Build JSON
text="${icon}"
class=$(echo "$status" | tr '[:upper:]' '[:lower:]')

# Use printf for proper JSON escaping of newlines in tooltip
printf '{"text":"%s","class":"%s","tooltip":"%s"}' "$text" "$class" "$tooltip"
