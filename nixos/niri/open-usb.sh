#!/usr/bin/env bash
# Open Yazi: USB drive if mounted, otherwise home directory
MOUNT=$(lsblk -o MOUNTPOINT,TRAN -n 2>/dev/null | awk '$2 ~ /usb/ && $1 != "" {print $1}' | tail -1)

if [ -z "$MOUNT" ]; then
    # Fallback: check /run/media for any mounted removable
    MOUNT=$(find /run/media/$USER -maxdepth 1 -type d 2>/dev/null | tail -1)
fi

if [ -n "$MOUNT" ]; then
    ghostty -e yazi "$MOUNT" &
    notify-send "USB" "Opened $MOUNT in Yazi" 2>/dev/null
else
    ghostty -e yazi "$HOME" &
fi
