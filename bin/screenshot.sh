#!/usr/bin/env bash
# Usage: screenshot.sh [area|screen]
# Grabs a screenshot -> saves to ~/Pictures/Screenshots, copies the PNG to the
# clipboard, and shows a toast. Click the toast to open the folder with the
# new file already selected.
set -u

dir="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "${1:-area}" in
    area)   grim -g "$(slurp)" "$file" || exit 0 ;;   # cancelled selection -> quit quietly
    screen) grim "$file" ;;
    *)      grim "$file" ;;
esac

[ -f "$file" ] || exit 0

# 1) auto-copy the image to the clipboard (typed, so paste lands as an image)
wl-copy --type image/png < "$file"

# opens the screenshots folder with THIS file selected (nautilus), else the folder
open_folder() {
    if command -v nautilus >/dev/null 2>&1; then
        nautilus --select "$file" >/dev/null 2>&1 &
    elif command -v thunar >/dev/null 2>&1; then
        thunar "$dir" >/dev/null 2>&1 &
    else
        xdg-open "$dir" >/dev/null 2>&1 &
    fi
}

# 2) toast (screenshot as its icon); left-click invokes the default action
action=$(notify-send --app-name=Screenshot --wait \
    --icon="$file" \
    --action="default=Buka folder" \
    "Screenshot tersalin ke clipboard" "$(basename "$file")")

case "$action" in
    default) open_folder ;;
esac
