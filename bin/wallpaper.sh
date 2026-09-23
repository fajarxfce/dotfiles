#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#  Change the desktop wallpaper. Saved PER THEME and re-applied at login by
#  theme.sh (which drives swaybg). Choice is stored in ~/.config/hypr/.wall-<theme>.
#
#    wallpaper.sh                 open the image picker for the CURRENT theme
#    wallpaper.sh /path/img.jpg   set that image for the current theme
#    wallpaper.sh both /path      set the same image for BOTH dark & light
#    wallpaper.sh color           revert the current theme to its solid colour
#
#  Picker scans ~/Pictures/Wallpapers, ~/Wallpapers, gh0stzk's
#  ~/.config/bspwm/rices/*/walls, and the top level of ~/Pictures.
#
#  The picker opens in KITTY when available: alacritty implements no inline-image
#  protocol at all (neither kitty's nor sixel), so its preview can only ever be
#  chafa's coarse block mosaic. See the note in the `pick` branch.
# ════════════════════════════════════════════════════════════════════════════
set -u
CFG="$HOME/.config"
cur=$(cat "$CFG/hypr/.theme" 2>/dev/null); [ "$cur" = light ] || cur=dark

note()    { notify-send -a Wallpaper "Wallpaper" "$1" 2>/dev/null || true; printf '%s\n' "$1"; }
reapply() { "$HOME/.local/bin/theme.sh" apply; }   # re-runs swaybg for current theme
set_wall(){ printf '%s\n' "$2" > "$CFG/hypr/.wall-$1"; }

# Pick how to draw the preview. In kitty, icat blits the actual image. Anywhere
# else chafa approximates it with unicode half-blocks + truecolor — legible, but
# visibly a mosaic, so it is the fallback and not the default.
preview_cmd() {
    if [ "${TERM:-}" = xterm-kitty ] && command -v kitten >/dev/null 2>&1; then
        printf '%s' 'kitten icat --clear --transfer-mode=memory --unicode-placeholder --stdin=no --scale-up --place=${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES}@0x0 {}'
    elif command -v chafa >/dev/null 2>&1; then
        printf '%s' 'chafa --animate=off --size=${FZF_PREVIEW_COLUMNS}x${FZF_PREVIEW_LINES} -- {}'
    else
        printf '%s' 'printf "Preview butuh chafa:\n  sudo pacman -S chafa\n\n%s\n" {}'
    fi
}

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
        # Always open a floating terminal for the picker. Hyprland's keybinds
        # inherit /dev/tty1, so `-t 0` alone also succeeds outside a GUI terminal.
        # The explicit flag prevents recursion when the terminal runs us again.
        # Prefer kitty for its image preview; alacritty uses chafa as a fallback.
        if [ "${2:-}" != --in-terminal ]; then
            for t in kitty alacritty; do
                command -v "$t" >/dev/null 2>&1 && exec "$t" --class wallpicker -e "$0" pick --in-terminal
            done
            note "Butuh kitty atau alacritty buat picker-nya"; exit 1
        fi
        list=$(list_walls | sort -u)
        [ -n "$list" ] || { note "Belum ada gambar. Taruh di ~/Pictures/Wallpapers"; sleep 2; exit 0; }
        img=$(printf '%s\n' "$list" | fzf \
            --prompt "Wallpaper ($cur) > " --info=inline --layout=reverse --height=100% \
            --preview-window="right:62%" \
            --preview "$(preview_cmd)")
        [ -n "$img" ] || exit 0
        set_wall "$cur" "$img"; reapply
        note "Tema $cur: $(basename "$img")" ;;

    *)
        img="$1"; [ -f "$img" ] || { note "File nggak ada: $img"; exit 1; }
        set_wall "$cur" "$img"; reapply
        note "Tema $cur: $(basename "$img")" ;;
esac
