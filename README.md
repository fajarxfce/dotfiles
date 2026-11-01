# dotfiles — Minimal Hyprland (Arch · MSI Intel+NVIDIA hybrid)

Setup Hyprland minimalis untuk laptop hybrid graphics (Intel iGPU + NVIDIA dGPU).
Kompositor jalan di **Intel iGPU** biar mulus & hemat baterai; NVIDIA on-demand
via `prime-run`. Keybind di-samain dengan **sxhkd gh0stzk** biar gak perlu adaptasi.
Tema **dark + light** bisa di-toggle. Blur/shadow dimatiin → ringan.
Konfigurasi ini memakai **Hyprland 0.57+ dengan Lua**.

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
config/hypr/          # hyprland.lua + modules/, hyprlock, hypridle
config/waybar/        # bar: config.jsonc + styles/{dark,light}.css
config/wofi/          # launcher: config + styles/{dark,light}.css
config/mako/          # notifikasi: configs/{dark,light}
bin/                  # theme, filesearch, prime-run, powermenu, screenshot, toggle-*
                      # idle.sh (sleep/idle), thunar-actions.sh (Open Terminal Here)
system/modprobe.d/    # nvidia_drm modeset=1
```

Config di-**symlink** ke `~/.config`, script ke `~/.local/bin`. File tema aktif
(`style.css`, `mako/config`, warna terminal) di-generate `theme.sh` dan di-`.gitignore`;
yang di-track cuma varian `dark`/`light`.

`hyprland.lua` memuat modul `desktop`, `displays`, `bindings`, dan `rules`.
Layout lokal `monitors.conf` / `workspaces.conf` tetap bisa dikelola
`nwg-displays`; modul Lua membacanya sebagai data. **SUPER+Esc** menerapkan
perubahan. Autostart ada di `desktop-start.sh` dan tidak menggandakan proses
saat dijalankan ulang.

Nomor workspace di Waybar bisa diklik; scroll di atas nomornya pindah ke
workspace sebelumnya/berikutnya pada monitor itu. Merah terang berarti aktif,
merah muda berarti ada app di workspace lain, dan abu-abu berarti kosong.
Workspace bernomor di `workspaces.conf` dibuat persistent saat monitornya
terhubung agar tombol workspace kosong tetap ada.

Modul `hyprland/workspaces` memakai build Waybar 0.15 dengan patch dispatcher
Lua untuk Hyprland 0.57. Installer membangunnya ke `~/.local/opt/waybar-lua/`;
launcher `~/.local/bin/waybar` memakai build tersebut. Paket Waybar sistem
tetap terpasang. Source dipatok dengan SHA-256 dan patch ada di `patches/`.
Jalankan `build-waybar.sh` untuk membangun ulang setelah pembaruan library.

## Monitor: mirror dan extend

**SUPER+O → Mirror** menampilkan layar laptop di monitor eksternal dengan
orientasi landscape. Rotasi portrait lama direset. Resolusi disamakan bila
didukung kedua layar; refresh rate dipilih dari mode yang didukung masing-masing.
**Extend** atau **Laptop/Eksternal saja** melepaskan hubungan mirror.

Preset langsung diterapkan dan disimpan ke `~/.config/hypr/monitors.conf`,
sehingga bertahan setelah reload/login. Layout sebelumnya dicadangkan ke
`~/.cache/dotfiles/backups/monitors-*.conf`. Jika monitor eksternal tidak
terhubung, memilih Mirror tidak mengubah layout tersimpan. Pengaturan drag,
rotasi, dan skala manual tetap tersedia lewat pilihan GUI.

## Keybinding (mirror sxhkd gh0stzk · SUPER = Win)

**Aplikasi**
| Key | Aksi | Key | Aksi |
|---|---|---|---|
| `SUPER + Return` | Terminal (Alacritty) | `SUPER + b` | Firefox |
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
| `+ v` | Rekam layar / stop | | |
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

**SUPER+A** memaksimalkan window sambil menjaga window floating di workspace
yang sama tetap terlihat dan bisa diklik di atasnya. Fokus keyboard tetap di
window yang dimaksimalkan. Tekan lagi untuk kembali ke ukuran/layout semula.

## Screenshot: edit, crop, dan copy

**SUPER+Alt+S** atau **Print** memilih area; **SUPER+Print** menangkap layar penuh.
Gambar disimpan ke `~/Pictures/Screenshots` (mengikuti folder Pictures dari XDG)
dan langsung tersalin ke clipboard.

- **Klik kiri preview notifikasi** membuka editor Satty dalam window floating.
- **Klik kanan notifikasi** membuka menu **Edit / Crop / Coret**, **Copy**, dan
  **Buka folder**. Klik tengah langsung copy ulang.
- Di editor, gunakan toolbar untuk crop, coretan, panah, teks, highlight, dan
  blur. **Ctrl+C** menyalin hasil edit sekaligus menyimpannya ke file screenshot;
  **Ctrl+S** menyimpan tanpa copy. **Esc** menutup editor.

Notifikasi tersedia selama 15 detik. Installer memasang Satty dari paket repo.

## Rekam layar

**SUPER+Alt+V** membuka menu untuk merekam **area pilihan**, **window aktif**,
atau **monitor penuh**. Fokuskan window/monitor yang diinginkan sebelum membuka
menu. Tekan shortcut yang sama lagi atau klik indikator merah **REC** di Waybar
untuk stop dan menyimpan video. Esc membatalkan pemilihan area/menu.

Video tersimpan sebagai **MP4 (H.264), 30 fps, tanpa audio** di
`~/Videos/Recordings` (mengikuti folder Videos dari XDG jika diubah).
Klik kanan indikator REC atau pilih **Buka folder rekaman** untuk membuka hasilnya.
Screenshot tetap lewat **SUPER+Alt+S** atau **Print**.

Setelah stop, preview notifikasi tersedia selama 15 detik:

- **Klik kiri** membuka **Edit Rekaman**, editor GTK dalam window floating.
- **Klik kanan** membuka menu **Edit / Trim / Crop**, **Putar video**,
  **Copy file**, dan **Buka folder**. Klik tengah langsung copy file.
- **Trim:** geser slider waktu lalu klik **Awal di sini** / **Akhir di sini**,
  atau isi waktu awal dan akhir dalam detik.
- **Crop:** seret persegi pada gambar preview. **Reset crop** mengembalikan area
  penuh. Ukuran hasil terlihat dalam piksel; batas mengikuti kelipatan dua
  untuk format H.264.
- **Simpan video…** mengekspor MP4 (H.264) dengan ukuran hasil crop dan durasi
  yang dipilih. Pilih nama baru; editor menolak menimpa video asli. Audio yang
  ada ikut disimpan. **Batalkan ekspor** membuang hasil sementara.
- Setelah selesai, **Copy hasil** menyalin file video yang sudah diedit.
  Copy memakai URI file untuk aplikasi yang mendukung paste file.

Menunggu notifikasi atau mengedit video tidak menghalangi rekaman berikutnya.
Editor memakai GTK melalui Wayland. Slider menampilkan frame preview; preview
dan ekspor dikerjakan FFmpeg lewat CPU. **Putar video** membuka mpv.

Mode window merekam area layar pada posisi window saat mulai: window perlu
tetap di tempat dan terlihat; window lain yang menutupinya ikut terekam.
Area/window harus berada di satu monitor.

CLI: `screenrecord.sh area`, `screenrecord.sh window`, `screenrecord.sh screen`,
dan `screenrecord.sh stop`. Installer memasang `wf-recorder`, `jq`, `ffmpeg`,
`mpv`, GTK3, dan binding Python GTK/Cairo. Recorder memakai user service `hypr-screenrecord.service`;
log error tersedia lewat `journalctl --user -u hypr-screenrecord.service`.

## Tema dark ⇄ light

`ALT + Space` (atau **klik-kanan jam** di waybar) untuk switch. Yang ikut berubah:
border Hyprland, waybar, wofi, mako, tema GTK (Adwaita), dan wallpaper solid.
Warna border ada di `config/hypr/modules/desktop.lua`; palet aplikasi ada di
`config/waybar/styles/`, `config/wofi/styles/`,
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
