#!/bin/bash
# Bluetooth picker: interactive bluetoothctl scan, wofi with live results

bluetoothctl power on
bluetoothctl pairable on

# Start interactive bluetoothctl with coproc to keep scan alive
coproc BT { bluetoothctl; }
echo "scan on" >&${BT[1]}

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

# Pop wofi immediately with "Searching..."
printf "Searching..." | wofi --dmenu --prompt "Scanning for devices..." --cache-file /dev/null -W 400 2>/dev/null &
WOFI_PID=$!

# Wait for devices (check every 1s, max 15s)
for i in $(seq 1 15); do
    devices=$(format_devices)
    if [ -n "$devices" ]; then
        kill $WOFI_PID 2>/dev/null
        sleep 0.3
        selection=$(echo "$devices" | wofi --dmenu --prompt "Select Bluetooth device" --cache-file /dev/null -W 400 2>/dev/null)
        break
    fi
    sleep 1
done

# If no devices found, let Searching wofi stay until user closes
if [ -z "$devices" ]; then
    wait $WOFI_PID 2>/dev/null
    selection=""
fi

# Stop scan and close bluetoothctl
echo "scan off" >&${BT[1]}
echo "quit" >&${BT[1]}

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
