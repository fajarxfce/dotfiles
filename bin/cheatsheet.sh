#!/usr/bin/env bash
# Floating keybind cheatsheet. Bound to ALT+F1, shown in a floating alacritty
# (class alacritty-cheatsheet). Closes on ESC or q.
set -u

ESC=$'\e'
RED=$'\e[1;31m'   # section headers
KEY=$'\e[1;37m'   # key combos (bold white)
DIM=$'\e[38;5;245m'
RST=$'\e[0m'
LW=46             # left column visible width

# Rows: "§Title" = header · "" = blank · "keys|desc" = entry
left=(
  "§ APPLICATIONS  (SUPER +)"
  "Return|Terminal (alacritty)"
  "ALT Return|Floating terminal"
  "b|Firefox"
  "e|Editor (geany)"
  "f|Files (thunar)"
  "y|Files TUI (yazi)"
  "v|Neovim"
  "m|Music (ncmpcpp)"
  "p|Audio mixer"
  "t|Telegram"
  "w|WhatsApp Web"
  ""
  "§ LAUNCHER & SEARCH"
  "CTRL ALT s|App launcher (wofi)"
  "SUPER Space|App launcher"
  "SUPER SHIFT f|File search (fzf)"
  ""
  "§ WINDOW"
  "SUPER c|Close window"
  "ALT a|Toggle floating"
  "ALT f|Fullscreen"
  "SUPER a|Maximize (monocle)"
  "ALT SHIFT t|Pseudo-tile"
  "ALT s|Sticky / pin"
  "SUPER j|Flip split direction"
  "ALT Tab|Window switcher"
)
right=(
  "§ WORKSPACES  (SUPER +)"
  "1..0|Workspace 1-10"
  "|  1-5 internal · 6-10 external"
  "CTRL 1..0|Move window to ws"
  "Left / Right|Prev / next ws"
  "CTRL L / R|Move win prev / next"
  "CTRL SHIFT .|Last workspace"
  "scroll|Cycle workspace"
  "ALT o|Scratchpad (magic)"
  ""
  "§ FOCUS / MOVE / RESIZE"
  "SUPER ALT arrows|Focus window"
  "CTRL ALT arrows|Swap window"
  "SUPER SHIFT arrows|Move floating win"
  "SUPER ALT +/-|Resize window"
  "SUPER LMB / RMB|Drag move / resize"
  "CTRL SHIFT ,|Last window"
  ""
  "§ MONITORS / LOOK"
  "SUPER o|Monitor menu"
  "ALT Space|Toggle dark / light"
  "SUPER SHIFT w|Wallpaper picker"
  "SUPER ALT r|Reload Hyprland + bar"
  ""
  "§ SYSTEM   (CSA = CTRL SUPER ALT)"
  "SUPER Esc|Reload config"
  "SUPER SHIFT Esc|System monitor (btop)"
  "Print|Screenshot area"
  "CSA l|Lock screen"
  "SUPER ALT i|Sleep & idle settings"
  "CSA p/r/q|Off / reboot / exit"
  "CSA k|Kill (click window)"
  "ALT F1|This cheatsheet"
)

# render one cell (§header / blank / key|desc) to a fixed visible width
cell() {
  local row="$1" w="$2" key desc plain pad
  if [ -z "$row" ]; then printf '%*s' "$w" ""; return; fi
  if [ "${row:0:1}" = "§" ]; then
    local t="${row:1}"; t="${t# }"
    pad=$(( w - 2 - ${#t} )); [ $pad -lt 0 ] && pad=0
    printf '  %s%s%s%*s' "$RED" "$t" "$RST" "$pad" ""; return
  fi
  key="${row%%|*}"; desc="${row#*|}"
  plain="  $(printf '%-18s' "$key") ${desc}"
  pad=$(( w - ${#plain} )); [ $pad -lt 0 ] && pad=0
  printf '  %s%-18s%s %s%s%s%*s' "$KEY" "$key" "$RST" "$DIM" "$desc" "$RST" "$pad" ""
}

n=${#left[@]}; [ ${#right[@]} -gt $n ] && n=${#right[@]}

clear
printf '\e[?25l'                      # hide cursor
trap 'printf "\e[?25h"' EXIT          # restore on exit
printf '\n  %sKeybindings%s   %s· Hyprland ·%s\n\n' "$KEY" "$RST" "$DIM" "$RST"
for ((i=0;i<n;i++)); do
  printf '%s%s\n' "$(cell "${left[i]:-}" $LW)" "$(cell "${right[i]:-}" 46)"
done
printf '\n  %sESC%s / %sq%s  tutup\n' "$KEY" "$RST" "$KEY" "$RST"

# wait for ESC or q
while IFS= read -rsn1 k; do
  [ "$k" = "$ESC" ] && break
  [ "$k" = q ] && break
done
