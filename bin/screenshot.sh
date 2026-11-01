#!/usr/bin/env bash
# Usage: screenshot.sh [area|screen]
# Save and copy a screenshot. Click the preview notification to crop/annotate
# in Satty; right-click it for Copy / Open folder. Copying in Satty also saves.
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

# Keep cancelled slurp selections separate from grim: empty geometry must never
# fall back to capturing the whole screen.
case "${1:-area}" in
    area)
        geometry=$(slurp) || exit 0
        [[ -n "$geometry" ]] || exit 0
        capture=(grim -g "$geometry")
        ;;
    screen) capture=(grim) ;;
    *) printf 'Usage: %s [area|screen]\n' "$0" >&2; exit 2 ;;
esac

base="${XDG_PICTURES_DIR:-}"
if [[ -z "$base" ]] && command -v xdg-user-dir >/dev/null; then
    base=$(xdg-user-dir PICTURES) || true
fi
dir="${base:-$HOME/Pictures}/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S_%N).png"
if ! "${capture[@]}" "$file"; then
    rm -f -- "$file"
    notify-send -a Screenshot 'Screenshot gagal' 'Tidak bisa mengambil gambar layar.' || true
    exit 1
fi
[[ -s "$file" ]] || exit 1

copy_image() { wl-copy --type image/png < "$file"; }
copy_image

open_editor() {
    if ! command -v satty >/dev/null; then
        notify-send -a Screenshot 'Editor belum terpasang' 'Pasang satty untuk crop dan anotasi.' || true
        return 1
    fi
    satty --filename "$file" --output-filename "$file" \
        --app-id com.gabm.satty --title 'Edit Screenshot' --initial-tool pointer \
        --copy-command 'wl-copy --type image/png' --save-after-copy --disable-notifications
}

open_folder() {
    if command -v thunar >/dev/null 2>&1; then
        thunar "$dir" >/dev/null 2>&1 &
    else
        xdg-open "$dir" >/dev/null 2>&1 &
    fi
}

# Mako invokes the default action on left-click; the screenshot-specific
# right-click menu exposes all three actions (see both mako theme configs).
reply=$(notify-send --app-name=Screenshot --print-id \
    --icon="$file" \
    --action='default=Edit / Crop / Coret' \
    --action='copy=Copy' \
    --action='folder=Buka folder' \
    'Screenshot tersalin ke clipboard' \
    'Klik untuk edit. Klik kanan: Copy / Buka folder.') || exit 0

# Actions imply waiting for a choice. Explicit --wait would additionally delay
# opening the editor until the toast expires. Dismiss only our selected toast.
notification_id="${reply%%$'\n'*}"
action="${reply#*$'\n'}"
case "$action" in
    default|copy|folder)
        makoctl dismiss -n "$notification_id" >/dev/null 2>&1 || true
        ;;
esac

case "$action" in
    default) open_editor ;;
    copy) copy_image ;;
    folder) open_folder ;;
esac
