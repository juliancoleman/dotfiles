#!/usr/bin/env bash
# Show calendar in a styled wofi popup
cal | wofi --dmenu --prompt "" --cache-file /dev/null -W 220 -H 280 --normal-window --style ~/.config/waybar/calendar.css 2>/dev/null
