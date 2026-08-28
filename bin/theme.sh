#!/usr/bin/env bash
# Switch between the dark and light theme (Hyprland borders, waybar, wofi,
# mako, GTK apps, wallpaper).
#   theme.sh dark | light   -> set that theme (live)
#   theme.sh toggle         -> flip dark <-> light (live)   [default]
#   theme.sh apply          -> re-apply saved theme at login (no compositor reload)
set -u
CFG="$HOME/.config"
STATE="$CFG/hypr/.theme"

cur=$(cat "$STATE" 2>/dev/null); [ "$cur" = light ] || cur=dark
case "${1:-toggle}" in
    dark|light) new="$1"; live=1 ;;
    apply)      new="$cur"; live=0 ;;
    *)          [ "$cur" = dark ] && new=light || new=dark; live=1 ;;
esac

# solid wallpaper colour per theme
[ "$new" = light ] && BG=eff1f5 || BG=151720

# regenerate the active files from the tracked variants
cp -f "$CFG/hypr/themes/$new.conf"  "$CFG/hypr/theme.conf"
cp -f "$CFG/waybar/styles/$new.css" "$CFG/waybar/style.css"
cp -f "$CFG/wofi/styles/$new.css"   "$CFG/wofi/style.css"
cp -f "$CFG/mako/configs/$new"      "$CFG/mako/config"
echo "$new" > "$STATE"

# kitty terminal colours: kitty.conf does `include current-theme.conf`, which we
# regenerate from the tracked color-<theme>.conf variant, then SIGUSR1 kitty
# (it reloads its config on that signal) so the terminal flips live too.
if [ -f "$CFG/kitty/color-$new.conf" ]; then
    cp -f "$CFG/kitty/color-$new.conf" "$CFG/kitty/current-theme.conf"
    pkill -SIGUSR1 -x kitty 2>/dev/null || true
fi

# alacritty: overwrite the imported rice-colors.toml; live_config_reload picks
# it up on its own (no signal needed).
if [ -f "$CFG/alacritty/colors-$new.toml" ]; then
    cp -f "$CFG/alacritty/colors-$new.toml" "$CFG/alacritty/rice-colors.toml"
fi

# wallpaper (always (re)set): a per-theme image if one was chosen via
# wallpaper.sh, otherwise the solid theme colour.
pkill -x swaybg 2>/dev/null
WALL="$CFG/hypr/.wall-$new"
if [ -s "$WALL" ] && [ -f "$(head -n1 "$WALL")" ]; then
    swaybg -m fill -i "$(head -n1 "$WALL")" >/dev/null 2>&1 &
else
    swaybg -m fill -c "$BG" >/dev/null 2>&1 &
fi

# GTK apps
if [ "$new" = light ]; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null
    gsettings set org.gnome.desktop.interface gtk-theme    'Adwaita'      2>/dev/null
else
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'  2>/dev/null
    gsettings set org.gnome.desktop.interface gtk-theme    'Adwaita-dark' 2>/dev/null
fi

# live reload the rest only when switching interactively
if [ "$live" = 1 ]; then
    hyprctl reload >/dev/null 2>&1
    pkill -x waybar 2>/dev/null; ( sleep 0.3; waybar >/dev/null 2>&1 & )
    makoctl reload 2>/dev/null
    notify-send "Theme" "Switched to $new" 2>/dev/null || true
fi
