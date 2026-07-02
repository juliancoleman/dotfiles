#!/bin/sh
# Bluetooth picker: scan, show wofi immediately, refresh as devices appear

bluetoothctl power on
bluetoothctl pairable on

# Start scan and keep it running
bluetoothctl scan on > /dev/null 2>&1 &
SCAN_PID=$!

format_devices() {
    bluetoothctl devices | while read -r _ mac rest; do
        name=$(echo "$rest" | xargs)
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

# Pop wofi immediately, refresh every 2s for 30s
for i in $(seq 1 15); do
    devices=$(format_devices)
    if [ -n "$devices" ]; then
        selection=$(echo "$devices" | wofi --dmenu --prompt "Select Bluetooth device" --cache-file /dev/null -W 400 2>/dev/null)
    else
        selection=$(printf "Searching..." | wofi --dmenu --prompt "Scanning for devices..." --cache-file /dev/null -W 400 2>/dev/null)
    fi
    
    # User closed wofi or selected a real device
    if [ -z "$selection" ] || [ "$selection" != "Searching..." ]; then
        break
    fi
    
    sleep 2
done

# Stop scan
bluetoothctl scan off > /dev/null 2>&1
kill $SCAN_PID 2>/dev/null

# Pair+trust+connect if a real device was selected
if [ -n "$selection" ] && [ "$selection" != "Searching..." ]; then
    mac=$(echo "$selection" | grep -oE "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}")
    name=$(echo "$selection" | sed "s/ |.*//")
    notify-send "Bluetooth" "Pairing with $name..." 2>/dev/null || true
    bluetoothctl pair "$mac" 2>/dev/null
    bluetoothctl trust "$mac" 2>/dev/null
    bluetoothctl connect "$mac" 2>/dev/null
    notify-send "Bluetooth" "Connected to $name" 2>/dev/null || true
fi
