#!/bin/sh
# Bluetooth picker: continuous scan with live wofi results
# Pops wofi immediately, shows "Searching..." until devices appear

bluetoothctl power on
bluetoothctl pairable on

# Start background scan
bluetoothctl scan on > /dev/null 2>&1 &
SCAN_PID=$!

format_devices() {
    bluetoothctl devices | while read -r _ mac name; do
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

# Keep wofi open, refreshing device list every 1.5s until user picks or 30s timeout
elapsed=0
while [ $elapsed -lt 30 ]; do
    devices=$(format_devices)
    if [ -n "$devices" ]; then
        selection=$(echo "$devices" | wofi --dmenu --prompt "Select Bluetooth device" --cache-file /dev/null 2>/dev/null)
    else
        selection=$(echo "Searching..." | wofi --dmenu --prompt "Scanning for devices..." --cache-file /dev/null 2>/dev/null)
    fi
    
    # If user selected something real, break
    if [ -n "$selection" ] && [ "$selection" != "Searching..." ]; then
        break
    fi
    
    # If user closed wofi (empty selection), break
    if [ -z "$selection" ]; then
        break
    fi
    
    # wofi was closed with "Searching..." selected — wait and reopen
    sleep 1.5
    elapsed=$((elapsed + 2))
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
