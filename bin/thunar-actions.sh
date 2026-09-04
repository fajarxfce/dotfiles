#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════════
#  Thunar custom actions — "Open Terminal Here" that actually works.
#
#  Thunar ships this action by default, but wired to
#      exo-open --working-directory %f --launch TerminalEmulator
#  which is a no-op here: exo has no TerminalEmulator helper configured and
#  xfce4-terminal isn't installed. So we do two things:
#
#    1. point the uca.xml action straight at our terminal (alacritty)
#    2. register a proper exo helper, so Thunar's *built-in* "Open Terminal"
#       entry and any other exo-based app work too
#
#  Idempotent: re-running only updates our own action, other custom actions
#  in uca.xml are left untouched.
# ════════════════════════════════════════════════════════════════════════════
set -u

TERM_BIN=""
for t in alacritty kitty foot; do command -v "$t" >/dev/null 2>&1 && { TERM_BIN="$t"; break; }; done
[ -n "$TERM_BIN" ] || { echo "Tidak ada terminal (kitty/alacritty/foot) — lewati." >&2; exit 0; }

case "$TERM_BIN" in
    kitty)     OPEN_CMD="kitty --working-directory %f";     EXEC_ARG="kitty -e %s" ;;
    alacritty) OPEN_CMD="alacritty --working-directory %f"; EXEC_ARG="alacritty -e %s" ;;
    foot)      OPEN_CMD="foot --working-directory=%f";      EXEC_ARG="foot %s" ;;
esac

# ── 1. uca.xml ──────────────────────────────────────────────────────────────
UCA="$HOME/.config/Thunar/uca.xml"
mkdir -p "$(dirname "$UCA")"

OPEN_CMD="$OPEN_CMD" python3 - "$UCA" <<'PY'
import os, sys, time
import xml.etree.ElementTree as ET

path = sys.argv[1]
cmd  = os.environ["OPEN_CMD"]
NAME = "Open Terminal Here"

if os.path.exists(path) and os.path.getsize(path) > 0:
    try:
        tree = ET.parse(path); root = tree.getroot()
    except ET.ParseError:
        root = ET.Element("actions")
else:
    root = ET.Element("actions")

def field(action, tag, text=None):
    el = action.find(tag)
    if el is None:
        el = ET.SubElement(action, tag)
    if text is not None:
        el.text = text
    return el

action = next((a for a in root.findall("action")
               if (a.findtext("name") or "").strip() == NAME), None)

created = action is None
if created:
    action = ET.SubElement(root, "action")
    field(action, "unique-id", f"{int(time.time()*1000)}-1")

field(action, "icon", "utilities-terminal")
field(action, "name", NAME)
field(action, "submenu", "")
field(action, "command", cmd)
field(action, "description", "Buka terminal di folder ini")
field(action, "range", "")
field(action, "patterns", "*")
# show for folders and for the folder background (right-click empty space)
if action.find("directories") is None:
    ET.SubElement(action, "directories")
if action.find("startup-notify") is None:
    ET.SubElement(action, "startup-notify")

out = ET.ElementTree(root)
ET.indent(out, space="\t")
out.write(path, encoding="UTF-8", xml_declaration=True)
print(("  created" if created else "  updated") + f" action → {cmd}")
PY

# ── 2. exo helper (Thunar's built-in "Open Terminal" + other exo apps) ──────
HELPER_DIR="$HOME/.local/share/xfce4/helpers"
mkdir -p "$HELPER_DIR" "$HOME/.config/xfce4"

cat > "$HELPER_DIR/custom-TerminalEmulator.desktop" <<EOF
[Desktop Entry]
Version=1.0
Encoding=UTF-8
Type=X-XFCE-Helper
NoDisplay=true
Name=$TERM_BIN
Icon=$TERM_BIN
X-XFCE-Category=TerminalEmulator
X-XFCE-Commands=$TERM_BIN
X-XFCE-CommandsWithParameter=$EXEC_ARG
EOF

RC="$HOME/.config/xfce4/helpers.rc"
touch "$RC"
if grep -q '^TerminalEmulator=' "$RC" 2>/dev/null; then
    sed -i 's|^TerminalEmulator=.*|TerminalEmulator=custom-TerminalEmulator|' "$RC"
else
    echo "TerminalEmulator=custom-TerminalEmulator" >> "$RC"
fi
echo "  exo helper → $TERM_BIN"

# ── 3. reload Thunar so the menu picks it up ────────────────────────────────
if pgrep -x thunar >/dev/null 2>&1; then
    thunar -q >/dev/null 2>&1 || true
    echo "  thunar daemon direstart"
fi

echo "✓ Thunar: 'Open Terminal Here' → $TERM_BIN"
