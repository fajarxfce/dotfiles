#!/usr/bin/env bash
# Usage: screenrecord.sh [toggle|area|window|screen|stop|status|folder]
# SUPER+ALT+V opens the recording menu, or stops the current recording.
# A dedicated user service owns the recorder and finalizes MP4 files with SIGINT.
set -euo pipefail
umask 077
export PATH="$HOME/.local/bin:$PATH"

unit=hypr-screenrecord.service
self="$(readlink -f "${BASH_SOURCE[0]}")"
runtime="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
state="$runtime/hypr-screenrecord.json"

note() { notify-send -a Screenrecord "$1" "${2:-}" 2>/dev/null || true; }
fail() { note "Rekaman gagal" "$1"; printf '%s\n' "$1" >&2; exit 1; }

running() {
    local status
    status=$(systemctl --user show "$unit" -p ActiveState --value 2>/dev/null) || return 1
    [[ "$status" == active || "$status" == activating || "$status" == deactivating ]]
}

recordings_dir() {
    local base="${XDG_VIDEOS_DIR:-}"
    if [[ -z "$base" ]] && command -v xdg-user-dir >/dev/null; then
        base=$(xdg-user-dir VIDEOS) || true
    fi
    printf '%s/Recordings\n' "${base:-$HOME/Videos}"
}

show_status() {
    if running && [[ -s "$state" ]]; then
        jq -c '
            ([0, (now - .started | floor)] | max) as $seconds |
            ($seconds / 60 | floor | tostring) as $minutes |
            ($seconds % 60 | tostring) as $rest |
            {text: ("REC " + $minutes + ":" + (if ($rest | length) < 2 then "0" else "" end) + $rest),
             class: "recording", tooltip: (.label + "\nKlik untuk stop · Klik kanan buka folder")}
        ' "$state" 2>/dev/null || printf '{"text":"REC","class":"recording"}\n'
    else
        printf '{"text":""}\n'
    fi
}

# ExecStopPost also runs if the encoder fails or the compositor disconnects.
finished() {
    [[ -s "$state" ]] || return 0
    local file
    file=$(jq -r .file "$state")
    rm -f "$state"
    if [[ "${SERVICE_RESULT:-}" == success && -s "$file" ]]; then
        note "Rekaman tersimpan" "$file"
    else
        [[ -s "$file" ]] || rm -f -- "$file"
        note "Rekaman gagal atau terputus" "Cek: journalctl --user -u $unit"
    fi
}

stop_recording() {
    if running; then
        systemctl --user stop "$unit" || fail "Recorder belum berhenti. Cek journalctl --user -u $unit"
    fi
}

action="${1:-toggle}"
case "$action" in
    status) show_status; exit 0 ;;
    _finished) finished; exit 0 ;;
    folder)
        dir=$(recordings_dir)
        mkdir -p "$dir"
        exec xdg-open "$dir"
        ;;
    toggle|menu|area|window|screen|stop) ;;
    *) printf 'Usage: %s [toggle|area|window|screen|stop|status|folder]\n' "$0" >&2; exit 2 ;;
esac

# Ignore repeated shortcuts while a picker is open or a stop is finalizing.
exec 9>"$runtime/hypr-screenrecord.lock"
flock -n 9 || exit 0
if [[ "$action" == stop ]]; then
    stop_recording
    exit 0
fi
if running; then
    if [[ "$action" == toggle || "$action" == menu ]]; then
        stop_recording
        exit 0
    fi
    fail "Rekaman sedang berjalan. Stop dengan Super+Alt+V."
fi

for dependency in wf-recorder hyprctl jq systemd-run; do
    command -v "$dependency" >/dev/null || fail "Program belum terpasang: $dependency"
done

# Snapshot focus BEFORE opening wofi so window mode records the intended app.
window=$(hyprctl activewindow -j) || fail "Tidak bisa membaca window aktif."
monitors=$(hyprctl monitors -j | jq '
    map(select(.disabled != true) | . + {
        logical_width: ((if (.transform % 2) == 1 then .height else .width end) / .scale | floor),
        logical_height: ((if (.transform % 2) == 1 then .width else .height end) / .scale | floor)
    })
') || fail "Tidak bisa membaca monitor."

if [[ "$action" == toggle || "$action" == menu ]]; then
    choice=$(printf '%s\n' 'Pilih area' 'Window aktif' 'Monitor penuh' 'Buka folder rekaman' |
        wofi --dmenu --prompt 'Rekam layar' --width 360 --height 240) || exit 0
    case "$choice" in
        'Pilih area') action=area ;;
        'Window aktif') action=window ;;
        'Monitor penuh') action=screen ;;
        'Buka folder rekaman') exec 9>&-; exec "$self" folder ;;
        *) exit 0 ;;
    esac
fi

geometry=''
output=''
case "$action" in
    area)
        geometry=$(slurp) || exit 0
        label='Area pilihan'
        ;;
    window)
        geometry=$(jq -er 'select(.mapped == true and .size[0] > 0 and .size[1] > 0) |
            "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' <<< "$window") || fail "Tidak ada window aktif."
        label='Window aktif (posisi tetap)'
        ;;
    screen)
        output=$(jq -er '[.[] | select(.focused == true)][0].name // empty' <<< "$monitors") || fail "Tidak ada monitor aktif."
        label="Monitor $output"
        ;;
esac

if [[ -n "$geometry" ]]; then
    if [[ "$geometry" =~ ^(-?[0-9]+),(-?[0-9]+)\ ([0-9]+)x([0-9]+)$ ]]; then
        x=${BASH_REMATCH[1]} y=${BASH_REMATCH[2]}
        width=${BASH_REMATCH[3]} height=${BASH_REMATCH[4]}
    else
        fail "Area rekaman tidak valid."
    fi
    (( width > 1 && height > 1 )) || fail "Area rekaman terlalu kecil."
    # wf-recorder captures one output. Reject a selection spanning monitors.
    output=$(jq -er --argjson x "$x" --argjson y "$y" --argjson w "$width" --argjson h "$height" '
        [.[] | select($x >= .x and $y >= .y and
            ($x + $w) <= (.x + .logical_width) and ($y + $h) <= (.y + .logical_height))][0].name // empty
    ' <<< "$monitors") || fail "Area/window harus berada sepenuhnya di satu monitor."
elif [[ "$action" != screen ]]; then
    exit 0
fi

# Let the picker disappear before the first frame is captured.
sleep 0.3
dir=$(recordings_dir)
mkdir -p "$dir"
file=$(mktemp --suffix=.mp4 "$dir/${action}-$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX")
jq -n --arg file "$file" --arg label "$label" --argjson started "$(date +%s)" \
    '{file: $file, label: $label, started: $started}' > "$state.tmp"
mv -f "$state.tmp" "$state"

# H.264/yuv420p plays in browsers and chat apps; software encoding works on either
# GPU. wf-recorder rounds odd capture dimensions down by one pixel internally.
recorder=("$(command -v wf-recorder)" -o "$output" -f "$file" -y
    -c libx264 -p preset=ultrafast -p crf=23 -x yuv420p -r 30 -D)
[[ -z "$geometry" ]] || recorder+=(-g "$geometry")

if ! systemd-run --user --quiet --collect --unit="$unit" --service-type=exec \
    --property=KillSignal=SIGINT --property=TimeoutStopSec=20s \
    --property="ExecStopPost=\"$self\" _finished" \
    --setenv="WAYLAND_DISPLAY=${WAYLAND_DISPLAY:?}" --setenv="XDG_RUNTIME_DIR=$runtime" \
    -- "${recorder[@]}"; then
    rm -f "$state" "$file"
    fail "Tidak bisa memulai recorder. Cek journalctl --user -u $unit"
fi
