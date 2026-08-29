#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  Minimal Hyprland setup for MSI (Intel iGPU + NVIDIA hybrid) on Arch.
#  Idempotent: safe to re-run. After a fresh Arch install just do:
#     git clone <repo> ~/dotfiles && ~/dotfiles/install.sh
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_SRC="$DOTFILES/config"
BIN_SRC="$DOTFILES/bin"
STAMP="$(date +%Y%m%d-%H%M%S)"

c_info() { printf '\033[1;34m::\033[0m %s\n' "$*"; }
c_ok()   { printf '\033[1;32m ✓\033[0m %s\n' "$*"; }
c_warn() { printf '\033[1;33m !\033[0m %s\n' "$*"; }

[ "$(id -u)" -ne 0 ] || { echo "Jangan jalankan sebagai root — pakai user biasa."; exit 1; }
command -v pacman >/dev/null || { echo "Ini bukan Arch Linux."; exit 1; }

# ── keep sudo alive for the whole run ─────────────────────────────
c_info "Minta akses sudo…"
sudo -v
( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE=$!
trap 'kill "$SUDO_KEEPALIVE" 2>/dev/null || true' EXIT

# ── detect AUR helper ─────────────────────────────────────────────
AUR=""
for h in yay paru; do command -v "$h" >/dev/null && { AUR="$h"; break; }; done

# ── official-repo packages ────────────────────────────────────────
c_info "Install paket dari repo resmi…"
mapfile -t PAC < <(grep -vE '^\s*#|^\s*$' "$DOTFILES/packages/pacman.txt")
sudo pacman -S --needed --noconfirm "${PAC[@]}"
c_ok "Paket repo resmi terpasang."

# ── AUR packages ──────────────────────────────────────────────────
if [ -f "$DOTFILES/packages/aur.txt" ]; then
    if [ -n "$AUR" ]; then
        c_info "Install paket AUR via $AUR…"
        mapfile -t AURP < <(grep -vE '^\s*#|^\s*$' "$DOTFILES/packages/aur.txt")
        [ "${#AURP[@]}" -gt 0 ] && "$AUR" -S --needed --noconfirm "${AURP[@]}"
        c_ok "Paket AUR terpasang."
    else
        c_warn "AUR helper (yay/paru) tidak ada — lewati: $(tr '\n' ' ' < "$DOTFILES/packages/aur.txt")"
    fi
fi

# ── symlink helper ────────────────────────────────────────────────
link() { # link <src> <dest>
    local src="$1" dest="$2"
    if [ -L "$dest" ]; then
        rm -f "$dest"
    elif [ -e "$dest" ]; then
        mv "$dest" "$dest.bak-$STAMP"
        c_warn "Backup: $dest -> $dest.bak-$STAMP"
    fi
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    c_ok "linked $(basename "$dest")"
}

# ── deploy configs ────────────────────────────────────────────────
c_info "Pasang config ke ~/.config…"
for d in "$CONFIG_SRC"/*; do
    link "$d" "$HOME/.config/$(basename "$d")"
done

# ── deploy scripts ────────────────────────────────────────────────
c_info "Pasang script ke ~/.local/bin…"
mkdir -p "$HOME/.local/bin"
chmod +x "$BIN_SRC"/*
for s in "$BIN_SRC"/*; do
    link "$s" "$HOME/.local/bin/$(basename "$s")"
done

# ── seed machine-local monitor layout (gitignored) ────────────────
c_info "Seed layout monitor…"
[ -f "$HOME/.config/hypr/monitors.conf" ]   || cp "$CONFIG_SRC/hypr/monitors.conf.default"   "$HOME/.config/hypr/monitors.conf"
[ -f "$HOME/.config/hypr/workspaces.conf" ] || cp "$CONFIG_SRC/hypr/workspaces.conf.default" "$HOME/.config/hypr/workspaces.conf"
c_ok "monitors.conf / workspaces.conf siap (atur: SUPER+O atau nwg-displays)."

# ── seed default theme (dark) if none chosen yet ──────────────────
c_info "Seed tema…"
TH="$HOME/.config"
if [ ! -f "$TH/hypr/.theme" ]; then
    cp -f "$TH/hypr/themes/dark.conf"  "$TH/hypr/theme.conf"
    cp -f "$TH/waybar/styles/dark.css" "$TH/waybar/style.css"
    cp -f "$TH/wofi/styles/dark.css"   "$TH/wofi/style.css"
    cp -f "$TH/mako/configs/dark"      "$TH/mako/config"
    [ -f "$TH/kitty/color-dark.conf" ] && cp -f "$TH/kitty/color-dark.conf" "$TH/kitty/current-theme.conf"
    [ -f "$TH/alacritty/colors-dark.toml" ] && cp -f "$TH/alacritty/colors-dark.toml" "$TH/alacritty/rice-colors.toml"
    echo dark > "$TH/hypr/.theme"
    c_ok "Tema awal: dark (ganti: ALT+Space atau klik-kanan jam)."
else
    c_ok "Tema tersimpan: $(cat "$TH/hypr/.theme")."
fi

# ── NVIDIA DRM modeset + early KMS ────────────────────────────────
c_info "Konfigurasi NVIDIA modeset…"
sudo install -Dm644 "$DOTFILES/system/modprobe.d/nvidia.conf" /etc/modprobe.d/nvidia.conf

if ! grep -q 'nvidia_drm' /etc/mkinitcpio.conf; then
    sudo cp /etc/mkinitcpio.conf "/etc/mkinitcpio.conf.bak-$STAMP"
    sudo sed -i -E 's/^MODULES=\((.*)\)/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/; s/MODULES=\( /MODULES=(/' /etc/mkinitcpio.conf
    c_info "Regenerate initramfs (early KMS)…"
    sudo mkinitcpio -P
    c_ok "initramfs diperbarui."
else
    c_ok "mkinitcpio sudah memuat modul nvidia."
fi

# ── services ──────────────────────────────────────────────────────
c_info "Enable services…"
sudo systemctl enable NetworkManager.service bluetooth.service
sudo systemctl enable ly@tty1.service 2>/dev/null || sudo systemctl enable ly.service 2>/dev/null || \
    c_warn "Display manager 'ly' belum ke-enable — cek 'systemctl enable ly@tty1'."
c_ok "Services enabled."

# ── ly session entry: Hyprland on Intel primary via the launcher ──
c_info "Pasang session 'Hyprland (hybrid)' untuk ly…"
sudo tee /usr/share/wayland-sessions/hyprland-hybrid.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Hyprland (hybrid)
Comment=Hyprland on the Intel iGPU, NVIDIA offload
Exec=$HOME/.local/bin/hyprland-hybrid
Type=Application
EOF
c_ok "Session 'Hyprland (hybrid)' terpasang (pilih ini di layar login ly)."

# ── user session niceties ─────────────────────────────────────────
command -v xdg-user-dirs-update >/dev/null && xdg-user-dirs-update || true

if command -v gsettings >/dev/null; then
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'          2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme    'Adwaita-dark'         2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size  16                     2>/dev/null || true
fi

# ── default apps: Thunar as file manager, feh for images (keep GNOME apps out) ──
if command -v xdg-mime >/dev/null; then
    command -v thunar >/dev/null && xdg-mime default thunar.desktop inode/directory 2>/dev/null || true
    command -v feh    >/dev/null && xdg-mime default feh.desktop \
        image/png image/jpeg image/gif image/webp image/bmp 2>/dev/null || true
    c_ok "Default apps: folder→Thunar, gambar→feh."
fi

# ~/.local/bin on PATH (zsh)
if [ -f "$HOME/.zshrc" ] && ! grep -qs '.local/bin' "$HOME/.zshrc"; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.zshrc"
    c_ok "PATH ~/.local/bin ditambah ke .zshrc"
fi

echo
c_ok "SELESAI."
echo    "   → Logout, di layar login (ly) pilih session 'Hyprland', lalu masuk."
echo    "   → GPU NVIDIA on-demand:  prime-run <app>"
echo    "     contoh:  prime-run glxinfo | grep 'OpenGL renderer'"
