#!/usr/bin/env bash
# Toggle maximization while keeping floating windows above it (SUPER+A).
# Raise mapped floats after the transition and restore the keyboard focus.
set -euo pipefail

hyprctl eval '
local target = hl.get_active_window()
if not target or not target.workspace then return end
local workspace = target.workspace.id
hl.dispatch(hl.dsp.window.fullscreen({mode = "maximized", window = target}))
for _, window in ipairs(hl.get_windows()) do
    if window.address ~= target.address and window.mapped and not window.hidden
        and window.floating and window.fullscreen == 0 and window.workspace
        and window.workspace.id == workspace then
        hl.dispatch(hl.dsp.window.alter_zorder({mode = "top", window = window}))
    end
end
hl.dispatch(hl.dsp.focus({window = target}))
' >/dev/null
