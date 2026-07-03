#!/usr/bin/env bash
# Disk usage tooltip with drive model names
tooltip=""
critical="normal"

# Get mounted real block devices, skip /boot
lines=$(df -h --output=source,used,size,pcent,target 2>/dev/null | tail -n +2 | grep '^/dev/' | grep -v '/boot')

echo "$lines" | while read -r src used size pcent target; do
    # Get the base device name (e.g. sda3 -> sda, nvme0n1p3 -> nvme0n1)
    base=$(echo "$src" | sed 's|/dev/||; s/p[0-9]*$//; s/[0-9]*$//')
    # Get model from /sys/block
    model=$(cat "/sys/block/$base/device/model" 2>/dev/null | xargs)
    [ -z "$model" ] && model=$(echo "$src" | sed 's|/dev/||')
    echo "$model: $used / $size ($pcent)"
done > /tmp/disk_tooltip.txt

tooltip=$(cat /tmp/disk_tooltip.txt)

# Check if any disk has less than 20% free (more than 80% used)
echo "$tooltip" | grep -qE '\([8-9][0-9]%\)|\(100%\)' && critical="critical"

# Escape newlines for JSON
tooltip_escaped=$(echo "$tooltip" | sed 's/\\/\\\\/g; s/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

printf '{"text":"󰋊","tooltip":"%s","class":"%s"}' "$tooltip_escaped" "$critical"
