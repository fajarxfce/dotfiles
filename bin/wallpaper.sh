#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#  Change the desktop wallpaper. Saved PER THEME and re-applied at login by
#  theme.sh (which drives swaybg). Choice is stored in ~/.config/hypr/.wall-<theme>.
#
#    wallpaper.sh                 pick an image (wofi) for the CURRENT theme
#    wallpaper.sh /path/img.jpg   set that image for the current theme
#    wallpaper.sh both /path      set the same image for BOTH dark & light
#    wallpaper.sh color           revert the current theme to its solid colour
#
#  Picker scans ~/Pictures/Wallpapers, ~/Wallpapers, gh0stzk's
#  ~/.config/bspwm/rices/*/walls, and the top level of ~/Pictures.
# ════════════════════════════════════════════════════════════════════════════
set -u
CFG="$HOME/.config"
cur=$(cat "$CFG/hypr/.theme" 2>/dev/null); [ "$cur" = light ] || cur=dark

note()    { notify-send -a Wallpaper "Wallpaper" "$1" 2>/dev/null || true; printf '%s\n' "$1"; }
reapply() { "$HOME/.local/bin/theme.sh" apply; }   # re-runs swaybg for current theme
set_wall(){ printf '%s\n' "$2" > "$CFG/hypr/.wall-$1"; }

gather() { # $1 dir, $2 optional find args (e.g. "-maxdepth 1")
    find -L "$1" ${2:-} -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        ! -iname 'preview*' 2>/dev/null
}
list_walls() {
    local d
    for d in "$HOME/Pictures/Wallpapers" "$HOME/Wallpapers" "$HOME/.config/bspwm/rices"/*/walls; do
        [ -d "$d" ] && gather "$d"
    done
    [ -d "$HOME/Pictures" ] && gather "$HOME/Pictures" "-maxdepth 1"
}

case "${1:-pick}" in
    color)
        rm -f "$CFG/hypr/.wall-$cur"; reapply
        note "Tema $cur: balik ke warna solid" ;;

    both)
        img="${2:-}"; [ -f "$img" ] || { note "File nggak ada: $img"; exit 1; }
        set_wall dark "$img"; set_wall light "$img"; reapply
        note "Wallpaper dark & light: $(basename "$img")" ;;

    pick)
        # fzf + a live image preview needs a terminal — relaunch in a floating
        # kitty (kitty-wall) if we were started without one (e.g. from a keybind).
        [ -t 0 ] || exec kitty --class kitty-wall -e "$0" pick
        list=$(list_walls | sort -u)
        [ -n "$list" ] || { note "Belum ada gambar. Taruh di ~/Pictures/Wallpapers"; sleep 2; exit 0; }
        img=$(printf '%s\n' "$list" | fzf \
            --prompt "Wallpaper ($cur) > " --info=inline --layout=reverse --height=100% \
            --preview-window="right:62%" \
            --preview 'kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no --scale-up --place=${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0 {}')
        [ -n "$img" ] || exit 0
        set_wall "$cur" "$img"; reapply
        note "Tema $cur: $(basename "$img")" ;;

    *)
        img="$1"; [ -f "$img" ] || { note "File nggak ada: $img"; exit 1; }
        set_wall "$cur" "$img"; reapply
        note "Tema $cur: $(basename "$img")" ;;
esac
