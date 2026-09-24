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
| `SUPER + Return` | Terminal (kitty) | `SUPER + b` | Firefox |
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
- Modul waybar: satu modul network (wifi/LAN/off) dengan kecepatan download `↓`
  dan upload `↑` langsung di bar. Bluetooth hanya muncul kalau ada device
  tersambung, karena status on/off sudah kelihatan di tray. Klik-kiri buka
  manager, klik-kanan toggle on/off.
- CLI: `toggle-wifi.sh`, `toggle-bt.sh`.

## Hybrid GPU

Kompositor render di Intel (`AQ_DRM_DEVICES`). Aplikasi berat ke NVIDIA:

```sh
prime-run <app>        # cek: prime-run glxinfo | grep "OpenGL renderer"
```

## Drag file ke terminal / agent TUI

`SUPER + Return` membuka Kitty. Drag file dari Thunar ke area input terminal
untuk memasukkan path-nya, termasuk nama file yang mengandung spasi. Di input
agent TUI, path masuk sebagai teks; tekan Enter sendiri setelah pesan siap.
Menu Thunar **Open Terminal Here** juga memakai Kitty.

Di input Codex, **Shift+Enter** membuat baris baru, termasuk lewat SSH + GNU
Screen. Kitty mengirim encoding Alt+Enter yang bisa diteruskan oleh Screen.

Alacritty tetap terpasang sebagai alternatif. Versi 0.17.0 dengan backend Wayland
belum menerima drop file. Untuk memakai fitur ini, buka terminal Kitty baru;
jendela Alacritty yang sudah terbuka tetap berjalan.

Jika agent berjalan di VPS lewat SSH, path file laptop tidak otomatis tersedia
di VPS. Upload filenya terlebih dahulu dan gunakan path di VPS.

## Codex lewat SSH + GNU Screen

GNU Screen 5.0.2 bisa merusak karakter Unicode pada spinner judul Codex menjadi
kode kontrol. Gejalanya: bunyi bell berulang, teks judul menimpa input seperti
huruf ghost, dan kursor terlihat bergeser walaupun posisi edit tetap benar.

Di mesin tempat Codex berjalan, tambahkan pengaturan ini ke bagian `[tui]` dalam
`~/.codex/config.toml` (gabungkan jika bagian tersebut sudah ada):

```toml
[tui]
terminal_title = ["project"]
```

Untuk sesi yang sedang terbuka, jalankan `/title`, hilangkan centang `activity`
(spinner) dengan Space, lalu Enter untuk menyimpan. Judul tetap menampilkan nama
proyek. Pengaturan ini sudah diuji dengan Codex 0.156.1 dan GNU Screen 5.0.2.

Kalau scroll mouse malah menggerakkan input, pasang [`.screenrc`](.screenrc)
sebagai `~/.screenrc` di mesin yang menjalankan Screen (VPS untuk sesi SSH).
Konfigurasi ini mempertahankan buffer terminal biasa agar scroll tidak diubah
menjadi tombol panah, serta menyimpan hingga 10.000 baris riwayat di Screen.
Installer memasangnya untuk mesin lokal; di VPS cukup salin file tersebut.

Untuk Screen yang sudah berjalan, detach dengan **Ctrl+A, lalu D** dan attach
lagi agar pengaturan terminal dibaca ulang. Codex tetap berjalan selama detach.
Riwayat di buffer Screen juga bisa dibuka dengan **Ctrl+A, lalu Esc**; tekan Esc
lagi untuk kembali mengetik. Batas baru tidak mengembalikan baris yang sudah
dibuang oleh buffer sebelumnya.
