#!/usr/bin/env bash
# Start the desktop once at login, or restore it after the Lua migration.
set -u
export PATH="$HOME/.local/bin:$PATH"
script_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")

dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP \
    HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM PATH
"$script_dir/theme.sh" apply
"$script_dir/idle.sh" _generate

start_once() {
    local process="$1"
    shift
    if ! pgrep -u "$(id -u)" -x "$process" >/dev/null; then
        setsid -f "$@" >/dev/null 2>&1
    fi
}
start_once hyprpolkitagent /usr/lib/hyprpolkitagent/hyprpolkitagent
start_once waybar waybar
start_once mako mako
makoctl reload >/dev/null 2>&1 || true
start_once nm-applet nm-applet --indicator
start_once blueman-applet blueman-applet
start_once hypridle hypridle
for media in text image; do
    if ! pgrep -u "$(id -u)" -f "^wl-paste --type $media --watch cliphist store$" >/dev/null; then
        setsid -f wl-paste --type "$media" --watch cliphist store >/dev/null 2>&1
    fi
done
hyprctl setcursor Bibata-Modern-Classic 16 >/dev/null
