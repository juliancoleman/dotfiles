#!/run/current-system/sw/bin/bash

generate_menu_items() {
  bluetoothctl --timeout 10 scan on
  devices=$(bluetoothctl devices | awk '{for(i=3;i<=NF;i++) printf $i " "; print $2}' | sed 's/ $//')

  # Remove duplicates using associative array in bash
  declare -A seen
  unique_devices=()

  while read -r line; do
    name=$(echo "$line" | sed -E 's/\ ([0-9A-Fa-f:]{17})$//')
    mac=$(echo "$line" | grep -oE '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}')
    if [[ -z "${seen[$mac]}" ]]; then
      seen[$mac]=1
      unique_devices+=("$name ($mac)")
    fi
  done <<< "$devices"
}

while true; do
   selection=$(generate_menu_items | wofi --dmenu --prompt "Search Bluetooth devices")
   [[ -z $selection ]] && break
   echo "You selected: $selection"
   # Optionally do something with the selection here
done
