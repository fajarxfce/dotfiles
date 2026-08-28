#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#  Dual-monitor helper for Hyprland — extend / mirror / single output / GUI.
#  Everything is applied LIVE via `hyprctl keyword monitor` (no relogin).
#
#    monitor.sh menu              wofi menu (default)
#    monitor.sh extend [right|left|up|down]
#    monitor.sh mirror            resolution-safe mirror (forces a common mode)
#    monitor.sh internal          laptop panel only  (external off)
#    monitor.sh external          external only      (laptop off)
#    monitor.sh gui               open nwg-displays (GNOME-like: drag/rotate/scale)
#
#  For a *saved* layout (survives relogin) use the GUI — it writes monitors.conf.
# ════════════════════════════════════════════════════════════════════════════
set -u

note() { notify-send -a Monitor "Monitor" "$1" 2>/dev/null || true; printf '%s\n' "$1"; }

# All monitors incl. disabled ones (so we can re-enable them).
mons() { hyprctl monitors all -j; }

# Print "INTERNAL EXTERNAL" (external empty if only one monitor).
read_names() {
    mons | python3 -c '
import json,sys,re
d=json.load(sys.stdin)
intn=next((m["name"] for m in d if re.match(r"(eDP|LVDS|DSI)",m["name"],re.I)), None)
if intn is None and d: intn=d[0]["name"]
ext=next((m["name"] for m in d if m["name"]!=intn), "")
print(intn or "", ext)'
}

# Best resolution+refresh supported by BOTH monitors (for a clean mirror).
common_mode() { # args: INTERNAL EXTERNAL   -> "WxH@RR.RRHz" or ""
    mons | python3 -c '
import json,sys,re
d=json.load(sys.stdin); intn,ext=sys.argv[1],sys.argv[2]
def modes(name):
    r={}
    for m in d:
        if m["name"]==name:
            for s in m.get("availableModes",[]):
                mm=re.match(r"(\d+)x(\d+)@([\d.]+)Hz",s)
                if mm:
                    w,h,hz=int(mm.group(1)),int(mm.group(2)),round(float(mm.group(3)),2)
                    r.setdefault((w,h),set()).add(hz)
    return r
mi,me=modes(intn),modes(ext)
common=[k for k in mi if k in me]
if not common: sys.exit(0)
w,h=max(common,key=lambda k:k[0]*k[1])
rates=mi[(w,h)]&me[(w,h)]
rate=max(rates) if rates else max(mi[(w,h)])
print(f"{w}x{h}@{rate:.2f}Hz")' "$1" "$2"
}

apply() { hyprctl keyword monitor "$1" >/dev/null; }

read INT EXT < <(read_names)

need_external() {
    if [ -z "$EXT" ]; then
        note "Cuma 1 monitor terdeteksi ($INT). Colok monitor eksternal dulu."
        exit 0
    fi
}

case "${1:-menu}" in
    extend)
        need_external
        case "${2:-right}" in
            left)  pos="auto-left"  ;;
            up)    pos="auto-up"    ;;
            down)  pos="auto-down"  ;;
            *)     pos="auto-right" ;;
        esac
        apply "$INT, preferred, 0x0, 1"
        apply "$EXT, preferred, $pos, 1"
        note "Extend: $EXT di sebelah ${2:-right} dari $INT"
        ;;

    mirror)
        need_external
        cm="$(common_mode "$INT" "$EXT")"
        if [ -n "$cm" ]; then
            # Force the SAME mode on both so mirroring is pixel-perfect — this is
            # what fixes the different-resolution mirror/workspace bug.
            apply "$INT, $cm, 0x0, 1"
            apply "$EXT, $cm, 0x0, 1, mirror, $INT"
            note "Mirror: $INT ↔ $EXT @ $cm (resolusi disamakan)"
        else
            # No shared mode — fall back to Hyprland's scaling mirror.
            apply "$EXT, preferred, 0x0, 1, mirror, $INT"
            note "Mirror: $EXT meniru $INT (tak ada resolusi sama — di-scale)"
        fi
        ;;

    internal)
        [ -n "$EXT" ] && apply "$EXT, disable"
        apply "$INT, preferred, 0x0, 1"
        note "Laptop saja: $INT (eksternal dimatikan)"
        ;;

    external)
        need_external
        apply "$EXT, preferred, 0x0, 1"
        apply "$INT, disable"
        note "Eksternal saja: $EXT (laptop dimatikan)"
        ;;

    gui)
        if command -v nwg-displays >/dev/null; then
            exec nwg-displays -m "$HOME/.config/hypr/monitors.conf" \
                              -w "$HOME/.config/hypr/workspaces.conf"
        else
            note "nwg-displays belum terpasang. Install: yay -S nwg-displays"
        fi
        ;;

    menu)
        sel=$(printf '%s\n' \
            "Extend — eksternal di kanan" \
            "Extend — eksternal di kiri" \
            "Mirror — samakan resolusi" \
            "Laptop saja" \
            "Eksternal saja" \
            "Atur manual — drag / putar / skala (GUI)" \
            | wofi --dmenu -i -p "Monitor")
        case "$sel" in
            *kanan*)     exec "$0" extend right ;;
            *kiri*)      exec "$0" extend left ;;
            Mirror*)     exec "$0" mirror ;;
            "Laptop saja") exec "$0" internal ;;
            "Eksternal saja") exec "$0" external ;;
            *GUI*)       exec "$0" gui ;;
        esac
        ;;

    *)
        echo "usage: monitor.sh {menu|extend [right|left|up|down]|mirror|internal|external|gui}" >&2
        exit 2
        ;;
esac
