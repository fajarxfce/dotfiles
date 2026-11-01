-- Float app/dialog windows while leaving normal browser and file-manager windows tiled.
hl.window_rule({
    name = "float-settings",
    match = {
        class = "^(nm-connection-editor|blueman-manager|pavucontrol|org.pulseaudio.pavucontrol)$",
    },
    float = true,
})

hl.window_rule({
    name = "float-screenshot-editor",
    match = {
        class = "^(com\\.gabm\\.satty)$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "float-video-editor",
    match = {
        class = "^(io\\.github\\.fajar\\.VideoEdit)$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "float-filedialogs",
    match = {
        title = "^(Open File|Save File|Choose Files)(.*)$",
    },
    float = true,
})

hl.window_rule({
    name = "float-modal",
    match = {
        modal = true,
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "float-thunar-dialogs",
    match = {
        class = "^(thunar|Thunar|org.xfce.Thunar)$",
        title = "^(Rename \".*\"|Rename Multiple Files|Bulk Rename( - Rename Multiple Files)?|Create New (Folder|File)|.* - Properties|File Operation Progress|Confirm to replace files|Replace the (existing file|existing folder|link) in \".*\")$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "float-scrcpy",
    match = {
        class = "^(scrcpy|Scrcpy|com.genymobile.scrcpy)$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "float-tizen-emulator",
    match = {
        title = "^(Tizen Emulator)$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "float-tizen-emmanager",
    match = {
        class = "^(org\\.tizen\\.emulator\\.manager\\.ui\\.Main)$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "float-browser-auth",
    match = {
        class = "(?i)^(firefox|org.mozilla.firefox|chromium|google-chrome|brave-browser|microsoft-edge)(-.*)?$",
        title = "^(Sign in - Google Accounts|Sign in with Google|Google Accounts|Sign in to your account|Sign in to GitHub|(Masuk|Login) - Akun Google|Login dengan Google)( (—|-|·) .*)?$",
    },
    float = true,
    center = true,
})

hl.window_rule({
    name = "term-float",
    match = {
        class = "^(alacritty-float)$",
    },
    float = true,
    size = "960 594",
    center = true,
})

hl.window_rule({
    name = "term-wall",
    match = {
        class = "^(wallpicker)$",
    },
    float = true,
    size = "1421 842",
    center = true,
})

hl.window_rule({
    name = "term-cheatsheet",
    match = {
        class = "^(alacritty-cheatsheet)$",
    },
    float = true,
    size = "1190 864",
    center = true,
})

hl.window_rule({
    name = "whatsapp-dialog",
    match = {
        class = "^(WhatsApp)$",
    },
    float = true,
    center = true,
})
