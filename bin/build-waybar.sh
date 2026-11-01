#!/usr/bin/env bash
# Build Waybar 0.15's Hyprland workspace module with native Lua click actions.
# The system package stays installed; bin/waybar launches this user-local build.
set -euo pipefail

repo=$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")
patch_file="$repo/patches/waybar-0.15.0-hyprland-lua.patch"
build_root="${DOTFILES_WAYBAR_BUILD_ROOT:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/waybar-lua}"
target="$HOME/.local/opt/waybar-lua/bin/waybar"
for dependency in python3 ninja c++ pkg-config patch; do
    command -v "$dependency" >/dev/null || {
        printf 'Missing build tool: %s. Install meson ninja gcc pkgconf patch.\n' "$dependency" >&2
        exit 1
    }
done
meson_cmd=$(command -v meson || true)
# Also allow the isolated build tools used on machines without sudo access.
meson_cmd="${meson_cmd:-$HOME/.local/opt/dotfiles-build-tools/bin/meson}"
[[ -x "$meson_cmd" ]] || { printf 'Missing build tool: meson\n' >&2; exit 1; }
mkdir -p "$build_root"
exec 9>"$build_root/build.lock"
flock 9

python3 - "$build_root" "$patch_file" <<'PY'
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import urllib.request

root, patch = map(Path, sys.argv[1:])
archive = root / "waybar-0.15.0.tar.gz"
expected = "21c2bbef88c40473c355003582f9331d2f9b8a01efdcce0935edfc5f6b023a3e"
if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
    url = "https://codeload.github.com/Alexays/Waybar/tar.gz/refs/tags/0.15.0"
    data = urllib.request.urlopen(url, timeout=60).read()
    if hashlib.sha256(data).hexdigest() != expected:
        raise SystemExit("Waybar source checksum does not match; build stopped.")
    archive.write_bytes(data)
source = root / "Waybar-0.15.0"
stamp = source / ".dotfiles-lua-patch"
fingerprint = hashlib.sha256(patch.read_bytes()).hexdigest()
if not stamp.exists() or stamp.read_text() != fingerprint:
    if source.exists():
        shutil.rmtree(source)
    with tarfile.open(archive) as tar:
        tar.extractall(root, filter="data")
    subprocess.run(["patch", "--batch", "-p1", "-i", str(patch)], cwd=source, check=True)
    stamp.write_text(fingerprint)
PY

source_dir="$build_root/Waybar-0.15.0"
setup=("$meson_cmd" setup "$source_dir/build" "$source_dir")
[[ ! -f "$source_dir/build/build.ninja" ]] || setup+=(--reconfigure)
"${setup[@]}" --wrap-mode=nofallback -Dtests=disabled -Dman-pages=disabled \
    -Dsystemd=disabled -Dcava=disabled -Dsndio=disabled -Dgps=disabled \
    -Ddbusmenu-gtk=enabled -Dlibnl=enabled -Dlibudev=enabled \
    -Dpulseaudio=enabled -Drfkill=enabled
# Limit build CPU/memory use while the desktop is running.
nice -n 10 ninja -C "$source_dir/build" -j 2 waybar
mkdir -p "$(dirname "$target")"
install -m 755 "$source_dir/build/waybar" "$target.new"
mv -f "$target.new" "$target"
printf 'Installed Waybar with Hyprland Lua support: %s\n' "$target"
