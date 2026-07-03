#!/usr/bin/env bash
# Open most recently mounted removable drive in Yazi
MOUNT=$(lsblk -o MOUNTPOINT,TRAN -n 2>/dev/null | grep -E "usb|mmc" | awk "{print \$1}" | tail -1)
if [ -z "$MOUNT" ]; then
    # Fallback: find most recent mount in /media or /run/media
    MOUNT=$(find /run/media /media -maxdepth 2 -type d 2>/dev/null | tail -1)
fi
if [ -n "$MOUNT" ]; then
    ghostty -e yazi "$MOUNT" &
else
    notify-send "USB" "No removable drive mounted"
fi
