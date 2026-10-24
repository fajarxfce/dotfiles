#!/usr/bin/env bash
# Toggle maximization while keeping floating windows above it (SUPER+A).
# Hyprland 0.56 hides existing floats on fullscreen/maximize transitions;
# alterzorder restores both their visibility and input without pinning them.
set -euo pipefail

active=$(hyprctl activewindow -j)
address=$(jq -er '.address | select(type == "string" and test("^0x[0-9a-fA-F]+$"))' <<< "$active") || exit 0
workspace=$(jq -er '.workspace.id | numbers' <<< "$active") || exit 0

# clients is ordered from bottom to top: raising in that order preserves the
# relative order of the floats. Hidden group tabs and other workspaces stay out.
# Run one batch so the compositor finishes the transition before rendering.
# alterzorder can refocus under the mouse, so restore keyboard focus at the end.
batch=$(hyprctl clients -j | jq -r --arg address "$address" --argjson workspace "$workspace" '
    (["dispatch focuswindow address:" + $address, "dispatch fullscreen 1"] +
     [.[] | select(.mapped and (.hidden | not) and .floating and
         .fullscreen == 0 and .workspace.id == $workspace and .address != $address) |
         "dispatch alterzorder top,address:" + .address] +
     ["dispatch focuswindow address:" + $address]) | join("; ")
')
hyprctl --batch "$batch" >/dev/null
