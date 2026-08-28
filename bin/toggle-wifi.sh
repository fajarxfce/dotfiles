#!/usr/bin/env bash
# Toggle Wi-Fi radio on/off.
if [ "$(nmcli -t -f WIFI radio)" = "enabled" ]; then
    nmcli radio wifi off
    notify-send "Wi-Fi" "Disabled" 2>/dev/null || true
else
    nmcli radio wifi on
    notify-send "Wi-Fi" "Enabled" 2>/dev/null || true
fi
