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

# kitty terminal colours (kitty.conf does `include current-theme.conf`).
# Written inline so it works even though ~/.config/kitty isn't symlinked here.
KT="$CFG/kitty/current-theme.conf"
if [ -d "$CFG/kitty" ]; then
    if [ "$new" = light ]; then
        cat > "$KT" <<'EOF'
# light theme (managed by theme.sh)
background            #eff1f5
foreground            #3a3f4b
selection_background  #cfd6e6
selection_foreground  #3a3f4b
cursor                #4d74b8
cursor_text_color     #eff1f5
url_color             #4d74b8
color0  #d7dae0
color8  #9aa0aa
color1  #d64760
color9  #b83048
color2  #4a8f3c
color10 #3a7a2c
color3  #b5891a
color11 #96700e
color4  #4d74b8
color12 #3a5f9e
color5  #8a5fc0
color13 #7048a8
color6  #2f9fb0
color14 #1f8090
color7  #4a4f5a
color15 #3a3f4b
EOF
    else
        cat > "$KT" <<'EOF'
# dark theme (managed by theme.sh)
background            #151720
foreground            #d7dae0
selection_background  #33415e
selection_foreground  #d7dae0
cursor                #8aa2c8
cursor_text_color     #151720
url_color             #8aa2c8
color0  #1b1e2b
color8  #3b4048
color1  #f7768e
color9  #ff8b98
color2  #9ece6a
color10 #b9f27c
color3  #e0af68
color11 #f0c987
color4  #7aa2f7
color12 #9bb8ff
color5  #bb9af7
color13 #d3b8ff
color6  #7dcfff
color14 #9be3ff
color7  #a9b1d6
color15 #d7dae0
EOF
    fi
    # live-reload every running kitty (kitty reloads its config on SIGUSR1)
    pkill -SIGUSR1 -x kitty 2>/dev/null || true
fi

# wallpaper (always (re)set)
pkill -x swaybg 2>/dev/null
swaybg -m fill -c "$BG" >/dev/null 2>&1 &

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
