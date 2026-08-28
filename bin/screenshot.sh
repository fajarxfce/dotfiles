#!/usr/bin/env bash
# Usage: screenshot.sh [area|screen]
dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "${1:-area}" in
    area)   grim -g "$(slurp)" "$file" || exit 0 ;;
    screen) grim "$file" ;;
esac

[ -f "$file" ] || exit 0
wl-copy < "$file"
notify-send "Screenshot saved" "$file" 2>/dev/null || true
