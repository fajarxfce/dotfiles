# dotfiles — Minimal Hyprland (Arch · MSI Intel+NVIDIA hybrid)

Setup Hyprland minimalis untuk laptop hybrid graphics (Intel iGPU + NVIDIA dGPU).
Kompositor jalan di **Intel iGPU** biar mulus & hemat baterai; NVIDIA on-demand
via `prime-run`. Keybind di-samain dengan **sxhkd gh0stzk** biar gak perlu adaptasi.
Tema **dark + light** bisa di-toggle. Blur/shadow dimatiin → ringan.

## Pasang (fresh Arch install)

```sh
git clone https://github.com/fajarxfce/dotfiles ~/dotfiles
~/dotfiles/install.sh
```

Idempotent — aman diulang. Setelah selesai: **logout → pilih session "Hyprland"
di layar login (ly) → masuk.** (Reboot dulu biar NVIDIA early-KMS full apply.)

> Butuh AUR helper (`yay`/`paru`) untuk cursor Bibata. Kalau belum ada, paket AUR
> dilewati; sisanya tetap terpasang.

## Isi

```
install.sh            # installer idempotent (paket + symlink + nvidia + seed tema)
packages/             # daftar paket repo (pacman.txt) & AUR (aur.txt)
config/hypr/          # hyprland.conf, hyprlock, hypridle, themes/{dark,light}.conf
config/waybar/        # bar: config.jsonc + styles/{dark,light}.css
config/wofi/          # launcher: config + styles/{dark,light}.css
config/mako/          # notifikasi: configs/{dark,light}
bin/                  # theme, filesearch, prime-run, powermenu, screenshot, toggle-*
                      # idle.sh (sleep/idle), thunar-actions.sh (Open Terminal Here)
system/modprobe.d/    # nvidia_drm modeset=1
```

Config di-**symlink** ke `~/.config`, script ke `~/.local/bin`. File tema aktif
(`theme.conf`, `style.css`, `mako/config`) di-generate `theme.sh` dan di-`.gitignore`;
yang di-track cuma varian `dark`/`light`.

## Keybinding (mirror sxhkd gh0stzk · SUPER = Win)

**Aplikasi**
| Key | Aksi | Key | Aksi |
|---|---|---|---|
| `SUPER + Return` | Terminal (alacritty) | `SUPER + b` | Firefox |
| `SUPER + Alt + Return` | Terminal floating | `SUPER + e` | Geany |
| `SUPER + f` | Thunar | `SUPER + y` | Yazi |
| `SUPER + v` | Neovim | `SUPER + m` | ncmpcpp |
| `SUPER + p` | Pavucontrol | `SUPER + t` | Telegram |
| `SUPER + w` | WhatsApp Web | | |

**Launcher & search**
| Key | Aksi |
|---|---|
| `Ctrl + Alt + s` / `SUPER + Space` | App launcher (wofi) |
| `SUPER + Shift + f` | Cari file cepat (fd + fzf) |

**Applets (SUPER + Alt + …)**
| Key | Aksi | Key | Aksi |
|---|---|---|---|
| `+ n` | Network | `+ b` | Bluetooth |
| `+ c` | Clipboard | `+ s` | Screenshot |
| `+ p` | Power menu | `+ o` | Scratchpad |
| `+ i` | **Sleep & idle** (timer lock/layar/suspend) | | |
| `Alt + Space` | **Toggle tema dark/light** | | |

**Window & sistem**
| Key | Aksi | Key | Aksi |
|---|---|---|---|
| `SUPER + c` | Tutup window | `Alt + a` | Floating |
| `Alt + f` | Fullscreen | `SUPER + a` | Monocle |
| `SUPER + Alt + arrow` | Fokus window | `Ctrl + Alt + arrow` | Tukar window |
| `SUPER + Left/Right` | Ganti workspace | `SUPER + 1..0` | Ke workspace |
| `SUPER + Ctrl + 1..0` | Kirim window ke ws | `Alt + Tab` | Window switcher |
| `SUPER + Shift + Esc` | System monitor (btop) | `SUPER + Esc` | Reload config |
| `Ctrl+SUPER+Alt + p/r/l` | Poweroff/Reboot/Lock | `Print` | Screenshot area |

## Tema dark ⇄ light

`ALT + Space` (atau **klik-kanan jam** di waybar) untuk switch. Yang ikut berubah:
border Hyprland, waybar, wofi, mako, tema GTK (Adwaita), dan wallpaper solid.
Palet ada di `config/hypr/themes/`, `config/waybar/styles/`, `config/wofi/styles/`,
`config/mako/configs/`. Pilihan terakhir disimpan & auto-apply saat login.

## Search & system info

- **App**: launcher wofi (`Ctrl+Alt+s`).
- **File**: `SUPER+Shift+f` → fzf streaming (instan walau ratusan ribu file, ala
  GNOME search light), buka pakai app default.
- **System info** di waybar, dikelompokkan di **kiri** setelah workspace dan
  dipagari garis hairline:  Storage ·  CPU ·  suhu ·  RAM.
  Klik CPU/RAM/suhu buka **btop**; klik Storage buka Thunar.
- **Kalender**: hover jam (tooltip) atau klik jam → gsimplecal (enteng).
- **Clipboard**: `SUPER+Alt+c` (riwayat via cliphist).

## Network & Bluetooth (paling gampang)

- Tray applet: `nm-applet` (network) & `blueman-applet` (bluetooth) → klik langsung.
- Modul waybar: satu modul network saja (wifi/LAN/off) — throughput pindah ke
  tooltip-nya. Bluetooth hanya muncul kalau ada device tersambung, karena
  status on/off sudah kelihatan di tray. Klik-kiri buka manager, klik-kanan
  toggle on/off.
- CLI: `toggle-wifi.sh`, `toggle-bt.sh`.

## Hybrid GPU

Kompositor render di Intel (`AQ_DRM_DEVICES`). Aplikasi berat ke NVIDIA:

```sh
prime-run <app>        # cek: prime-run glxinfo | grep "OpenGL renderer"
```
