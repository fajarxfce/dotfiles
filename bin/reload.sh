#!/usr/bin/env bash
# Reload the live desktop without logging out. Bound to SUPER+ALT+R.
#   - Hyprland config (monitors, workspaces, binds — everything it sources)
#   - waybar (regenerates the active stylesheet from the current theme, then
#     restarts it, since `hyprctl reload` does NOT touch waybar)
#   - mako notification daemon
set -u
CFG="$HOME/.config"

hyprctl reload >/dev/null 2>&1

cur=$(cat "$CFG/hypr/.theme" 2>/dev/null); [ "$cur" = light ] || cur=dark
[ -f "$CFG/waybar/styles/$cur.css" ] && cp -f "$CFG/waybar/styles/$cur.css" "$CFG/waybar/style.css"
pkill -x waybar 2>/dev/null
setsid -f waybar >/dev/null 2>&1

makoctl reload 2>/dev/null || true

notify-send -a Hyprland "Reloaded" "Hyprland + waybar" 2>/dev/null || true
