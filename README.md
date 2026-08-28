# dotfiles — Minimal Hyprland (Arch · MSI Intel+NVIDIA hybrid)

Setup Hyprland minimalis untuk laptop hybrid graphics (Intel iGPU + NVIDIA dGPU).
Kompositor jalan di **Intel iGPU** biar mulus & hemat baterai; NVIDIA dipakai
on-demand lewat `prime-run`. Fokus: gampang enable/disable **network** &
**bluetooth**, tema dark minimalis (tanpa blur/shadow → ringan).

## Pasang (fresh Arch install)

```sh
git clone <URL-repo-ini> ~/dotfiles
~/dotfiles/install.sh
```

Script-nya idempotent — aman dijalanin ulang. Setelah selesai: **logout →
pilih session "Hyprland" di layar login (ly) → masuk.**

> Butuh AUR helper (`yay`/`paru`) untuk cursor Bibata. Kalau belum ada, paket
> AUR dilewati; sisanya tetap terpasang.

## Isi

```
install.sh            # installer idempotent (paket + symlink + service + nvidia)
packages/pacman.txt   # paket repo resmi
packages/aur.txt      # paket AUR (bibata cursor)
config/hypr/          # hyprland, hyprlock, hypridle
config/waybar/        # bar (config.jsonc + style.css)
config/wofi/          # launcher
config/mako/          # notifikasi
bin/                  # prime-run, powermenu, screenshot, toggle-wifi, toggle-bt
system/modprobe.d/    # nvidia_drm modeset=1
```

Config di-**symlink** ke `~/.config`, script ke `~/.local/bin`. Edit langsung
di repo ini, langsung kepakai (dan enak buat `git commit`).

## Keybinding utama (SUPER = Win)

| Kombinasi | Aksi |
|---|---|
| `SUPER + Return` | Terminal (kitty) |
| `SUPER + R` / `Space` | App launcher (wofi) |
| `SUPER + E` | File manager |
| `SUPER + Q` | Tutup window |
| `SUPER + F` | Fullscreen |
| `SUPER + V` | Toggle floating |
| `SUPER + L` | Lock |
| `SUPER + Escape` | Power menu |
| `SUPER + C` | Riwayat clipboard |
| `SUPER + 1..0` | Pindah workspace |
| `SUPER + Shift + 1..0` | Pindahkan window ke workspace |
| `Print` / `SUPER + Shift + S` | Screenshot area |
| `SUPER + Print` | Screenshot layar penuh |

Tombol volume / brightness / media otomatis aktif.

## Network & Bluetooth (yang paling gampang)

- **Tray applet** di kanan waybar: `nm-applet` (network) & `blueman-applet`
  (bluetooth) → klik langsung buat connect / enable-disable.
- **Klik modul waybar**:
  - Network: klik-kiri buka editor koneksi, klik-kanan toggle Wi-Fi on/off.
  - Bluetooth: klik-kiri buka blueman-manager, klik-kanan toggle BT on/off.
- CLI cepat: `~/.local/bin/toggle-wifi.sh`, `~/.local/bin/toggle-bt.sh`.

## Hybrid GPU

Kompositor render di Intel (`AQ_DRM_DEVICES` set Intel sebagai primary).
Jalankan aplikasi berat di NVIDIA:

```sh
prime-run <app>
# cek: prime-run glxinfo | grep "OpenGL renderer"   # harus NVIDIA
```

## Tema

Dark netral, aksen biru redup (`#8aa2c8`), tanpa blur/shadow. Warna ada di
`config/waybar/style.css`, `config/wofi/style.css`, `config/mako/config`, dan
bagian `general {}` di `config/hypr/hyprland.conf`.
