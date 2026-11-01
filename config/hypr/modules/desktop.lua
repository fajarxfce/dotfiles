-- Hyprland 0.57+ desktop settings. Theme state is shared with theme.sh.
local root = os.getenv("HOME") .. "/.config/hypr/"
local state = io.open(root .. ".theme", "r")
local theme = state and state:read("*l") or "dark"
if state then state:close() end
local light = theme == "light"
local local_bin = os.getenv("HOME") .. "/.local/bin"
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
if not (":" .. path .. ":"):find(":" .. local_bin .. ":", 1, true) then
    hl.env("PATH", local_bin .. ":" .. path)
end

local environment = {
    LIBVA_DRIVER_NAME = "iHD", __GLX_VENDOR_LIBRARY_NAME = "mesa", NVD_BACKEND = "direct",
    XCURSOR_THEME = "Bibata-Modern-Classic", XCURSOR_SIZE = "16",
    HYPRCURSOR_THEME = "Bibata-Modern-Classic", HYPRCURSOR_SIZE = "16",
    QT_QPA_PLATFORM = "wayland;xcb", QT_QPA_PLATFORMTHEME = "qt6ct",
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1", GDK_BACKEND = "wayland,x11",
    MOZ_ENABLE_WAYLAND = "1", ELECTRON_OZONE_PLATFORM_HINT = "auto",
    _JAVA_AWT_WM_NONREPARENTING = "1",
}
for key, value in pairs(environment) do hl.env(key, value) end

hl.config({
    general = {
        gaps_in = 2, gaps_out = 4, border_size = 1,
        ["col.active_border"] = light and "rgba(d92626ff)" or "rgba(ff4d4dff)",
        ["col.inactive_border"] = light and "rgba(c2c6cfff)" or "rgba(2a2e37aa)",
        resize_on_border = true, allow_tearing = false, layout = "dwindle",
    },
    decoration = {
        rounding = 0, active_opacity = 1, inactive_opacity = 1,
        blur = { enabled = false }, shadow = { enabled = false },
    },
    animations = { enabled = false },
    dwindle = { preserve_split = true },
    master = { new_status = "master" },
    misc = {
        disable_hyprland_logo = true, disable_splash_rendering = true,
        force_default_wallpaper = 0, focus_on_activate = false,
    },
    cursor = {
        no_hardware_cursors = 2, inactive_timeout = 5,
        no_warps = true, warp_on_change_workspace = 0,
    },
    input = {
        kb_layout = "us", follow_mouse = 1, sensitivity = 0.4, accel_profile = "adaptive",
        touchpad = { natural_scroll = true, tap_to_click = true, disable_while_typing = true },
    },
})
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.on("hyprland.start", function()
    hl.exec_cmd('"$HOME/.local/bin/desktop-start.sh"')
end)
