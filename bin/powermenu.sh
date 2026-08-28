#!/usr/bin/env bash
# Minimal power menu via wofi.
options="  Lock
  Logout
  Suspend
  Reboot
  Shutdown"

choice=$(printf '%s' "$options" | wofi --dmenu --width 240 --height 260 --prompt "Power" | awk '{print $NF}')

case "$choice" in
    Lock)     hyprlock ;;
    Logout)   hyprctl dispatch exit ;;
    Suspend)  systemctl suspend ;;
    Reboot)   systemctl reboot ;;
    Shutdown) systemctl poweroff ;;
esac
