#!/bin/sh
# Bluetooth picker: continuous scan with live wofi results
# Scans in background, populates devices as discovered, pairs+connects+trusts on select

bluetoothctl power on
bluetoothctl pairable on

# Start background scan
bluetoothctl scan on > /dev/null 2>&1 &
SCAN_PID=$!

# Give scan a few seconds to populate
sleep 3

# Get devices and format for wofi
format_devices() {
    bluetoothctl devices | while read -r _ mac name; do
        # Check if already paired/connected
        info=$(bluetoothctl info "$mac" 2>/dev/null)
        if echo "$info" | grep -q "Connected: yes"; then
            echo "$name (connected) | $mac"
        elif echo "$info" | grep -q "Paired: yes"; then
            echo "$name (paired) | $mac"
        else
            echo "$name | $mac"
        fi
    done
}

# Show picker
selection=$(format_devices | wofi --dmenu --prompt "Select Bluetooth device" --cache-file /dev/null 2>/dev/null)

# Stop scan
bluetoothctl scan off > /dev/null 2>&1
kill $SCAN_PID 2>/dev/null

# If something was selected, pair+trust+connect
if [ -n "$selection" ]; then
    mac=$(echo "$selection" | grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}")
    name=$(echo "$selection" | sed "s/ |.*//")
    notify-send "Bluetooth" "Pairing with $name..." 2>/dev/null || true
    bluetoothctl pair "$mac" 2>/dev/null
    bluetoothctl trust "$mac" 2>/dev/null
    bluetoothctl connect "$mac" 2>/dev/null
    notify-send "Bluetooth" "Connected to $name" 2>/dev/null || true
fi
