#!/usr/bin/env bash
# Open the native GTK trim/crop editor. FFmpeg handles preview/export on CPU.
set -euo pipefail
umask 077
export PATH="$HOME/.local/bin:$PATH"

[[ $# == 0 || ( $# == 1 && -f "$1" ) ]] || {
    printf 'Usage: %s [VIDEO]\n' "$0" >&2
    exit 2
}
for dependency in python3 ffmpeg ffprobe wl-copy; do
    command -v "$dependency" >/dev/null || {
        notify-send -a Screenrecord 'Editor belum lengkap' "Program belum terpasang: $dependency" || true
        exit 1
    }
done
script_dir=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
exec env -u DISPLAY GDK_BACKEND=wayland python3 "$script_dir/video-edit.py" "$@"
