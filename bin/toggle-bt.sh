#!/usr/bin/env bash
# Toggle Bluetooth power on/off.
if bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
    bluetoothctl power off
    notify-send "Bluetooth" "Off" 2>/dev/null || true
else
    rfkill unblock bluetooth 2>/dev/null
    bluetoothctl power on
    notify-send "Bluetooth" "On" 2>/dev/null || true
fi
