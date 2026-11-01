#!/usr/bin/env python3
"""Small Wayland video trimmer/cropper. Preview and export use software decoding."""
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading


def probe_video(path):
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_streams",
         "-show_format", "-of", "json", str(path)],
        capture_output=True, text=True, check=True, timeout=15)
    data = json.loads(result.stdout)
    if not data.get("streams"):
        raise ValueError("File tidak memiliki video.")
    stream = data["streams"][0]
    width, height = int(stream["width"]), int(stream["height"])
    rotation = next((item.get("rotation", 0) for item in stream.get("side_data_list", [])
                     if "rotation" in item), 0)
    if round(float(rotation)) % 180:
        width, height = height, width
    duration = float(data.get("format", {}).get("duration") or stream.get("duration", 0))
    if min(width, height) < 2 or not math.isfinite(duration) or duration <= 0:
        raise ValueError("Ukuran atau durasi video tidak valid.")
    rate = stream.get("avg_frame_rate", "0/1")
    numerator, denominator = (float(value) for value in rate.split("/"))
    fps = numerator / denominator if denominator else 0
    return width, height, duration, fps if math.isfinite(fps) and fps > 0 else 30


def even_crop(anchor, point, width, height):
    """Align to H.264's chroma grid and keep every edge inside the source."""
    max_x, max_y = width // 2 * 2, height // 2 * 2
    # Display scaling can turn an exact pixel boundary into 39.999999999.
    epsilon = 1e-7
    x = max(0, min(max_x - 2, math.floor((min(anchor[0], point[0]) + epsilon) / 2) * 2))
    y = max(0, min(max_y - 2, math.floor((min(anchor[1], point[1]) + epsilon) / 2) * 2))
    right = max(x + 2, min(max_x, math.ceil((max(anchor[0], point[0]) - epsilon) / 2) * 2))
    bottom = max(y + 2, min(max_y, math.ceil((max(anchor[1], point[1]) - epsilon) / 2) * 2))
    return x, y, right - x, bottom - y


def export_command(source, target, start, end, crop):
    x, y, width, height = crop
    if not (math.isfinite(start) and math.isfinite(end) and 0 <= start < end):
        raise ValueError("Waktu akhir harus lebih besar dari waktu awal.")
    if min(x, y) < 0 or min(width, height) < 2 or any(v % 2 for v in crop):
        raise ValueError("Area crop tidak valid.")
    return ["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-y",
            "-hwaccel", "none", "-ss", f"{start:.6f}", "-i", str(source),
            "-t", f"{end - start:.6f}", "-map", "0:v:0", "-map", "0:a:0?",
            "-vf", f"crop={width}:{height}:{x}:{y},setsar=1",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "20",
            "-pix_fmt", "yuv420p", "-c:a", "aac", "-movflags", "+faststart",
            "-progress", "pipe:1", "-nostats", str(target)]


def run_gui(initial_file=None):
    import gi
    gi.require_version("Gtk", "3.0")
    gi.require_version("Gdk", "3.0")
    gi.require_version("GdkPixbuf", "2.0")
    from gi.repository import Gtk, Gdk, GdkPixbuf, GLib, Gio
    import cairo
    GLib.set_prgname("io.github.fajar.VideoEdit")
    GLib.set_application_name("Edit Rekaman")

    class Editor(Gtk.ApplicationWindow):
        def __init__(self, app, path):
            super().__init__(application=app, title="Edit Rekaman — Trim & Crop")
            self.set_default_size(940, 700)
            self.source = path.resolve()
            self.width, self.height, self.duration, self.fps = probe_video(self.source)
            self.crop = even_crop((0, 0), (self.width, self.height), self.width, self.height)
            self.pixbuf = None
            self.anchor = None
            self.closed = False
            self.busy = False
            self.preview_generation = 0
            self.preview_process = None
            self.export_process = None
            self.lock = threading.Lock()
            self.cancel_export = threading.Event()
            self.preview_timer = None
            self.saved_file = None
            self.connect("delete-event", self.close_editor)

            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
            box.set_border_width(14)
            self.add(box)
            title = Gtk.Label(label=self.source.name, xalign=0)
            title.set_ellipsize(3)
            box.pack_start(title, False, False, 0)
            box.pack_start(Gtk.Label(label="Geser waktu untuk melihat frame. Seret gambar untuk crop.",
                                     xalign=0), False, False, 0)
            self.preview = Gtk.DrawingArea()
            self.preview.set_size_request(320, 200)
            self.preview.add_events(Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.BUTTON_RELEASE_MASK |
                                    Gdk.EventMask.POINTER_MOTION_MASK)
            self.preview.connect("draw", self.draw_preview)
            self.preview.connect("button-press-event", self.begin_crop)
            self.preview.connect("motion-notify-event", self.drag_crop)
            self.preview.connect("button-release-event", self.end_crop)
            box.pack_start(self.preview, True, True, 0)

            self.controls = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            box.pack_start(self.controls, False, False, 0)
            self.seek = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0,
                                                 max(0.001, self.duration - 1 / self.fps), 1 / self.fps)
            self.seek.set_digits(2)
            self.seek.connect("value-changed", self.seek_changed)
            self.controls.pack_start(self.seek, False, False, 0)
            row = Gtk.Box(spacing=8)
            self.controls.pack_start(row, False, False, 0)
            self.start = Gtk.SpinButton.new_with_range(0, self.duration, 0.01)
            self.end = Gtk.SpinButton.new_with_range(0, self.duration, 0.01)
            for widget in (self.start, self.end):
                widget.set_digits(3)
                widget.set_numeric(True)
                widget.set_width_chars(9)
            self.end.set_value(self.duration)
            for label, spin in (("Awal (detik)", self.start), ("Akhir (detik)", self.end)):
                row.pack_start(Gtk.Label(label=label), False, False, 0)
                row.pack_start(spin, False, False, 0)
                spin.connect("value-changed", self.selection_changed)
            self.button(row, "Awal di sini", lambda *_: self.start.set_value(self.seek.get_value()))
            self.button(row, "Akhir di sini", lambda *_: self.end.set_value(self.seek.get_value()))
            crop_row = Gtk.Box(spacing=8)
            self.controls.pack_start(crop_row, False, False, 0)
            self.crop_label = Gtk.Label(xalign=0)
            crop_row.pack_start(self.crop_label, True, True, 0)
            self.button(crop_row, "Reset crop", self.reset_crop)
            self.progress = Gtk.ProgressBar(show_text=True)
            box.pack_start(self.progress, False, False, 0)
            self.status = Gtk.Label(xalign=0)
            self.status.set_line_wrap(True)
            self.status.set_selectable(True)
            box.pack_start(self.status, False, False, 0)
            footer = Gtk.Box(spacing=8)
            box.pack_start(footer, False, False, 0)
            self.save_button = self.button(footer, "Simpan video…", self.save_video)
            self.cancel_button = self.button(footer, "Batalkan ekspor", self.cancel_clicked)
            self.copy_button = self.button(footer, "Copy hasil", self.copy_result)
            self.folder_button = self.button(footer, "Buka folder", self.open_folder)
            self.cancel_button.set_sensitive(False)
            self.copy_button.set_sensitive(False)
            self.selection_changed()
            self.show_all()
            self.load_preview()

        @staticmethod
        def button(box, text, callback):
            button = Gtk.Button(label=text)
            button.connect("clicked", callback)
            box.pack_start(button, False, False, 0)
            return button

        def image_bounds(self):
            size = self.preview.get_allocation()
            scale = min(size.width / self.width, size.height / self.height)
            width, height = self.width * scale, self.height * scale
            return (size.width - width) / 2, (size.height - height) / 2, width, height, scale

        def draw_preview(self, _widget, ctx):
            ctx.set_source_rgb(0.08, 0.08, 0.09)
            ctx.paint()
            if not self.pixbuf:
                return False
            left, top, width, height, scale = self.image_bounds()
            ctx.save()
            ctx.translate(left, top)
            ctx.scale(width / self.pixbuf.get_width(), height / self.pixbuf.get_height())
            Gdk.cairo_set_source_pixbuf(ctx, self.pixbuf, 0, 0)
            ctx.paint()
            ctx.restore()
            x, y, w, h = self.crop
            ctx.save()
            ctx.rectangle(left, top, width, height)
            ctx.rectangle(left + x * scale, top + y * scale, w * scale, h * scale)
            ctx.set_fill_rule(cairo.FILL_RULE_EVEN_ODD)
            ctx.set_source_rgba(0, 0, 0, 0.65)
            ctx.fill()
            ctx.restore()
            ctx.rectangle(left + x * scale, top + y * scale, w * scale, h * scale)
            ctx.set_source_rgb(0.25, 0.85, 0.9)
            ctx.set_line_width(2)
            ctx.stroke()
            return False

        def source_point(self, event):
            left, top, _, _, scale = self.image_bounds()
            return (max(0, min(self.width, (event.x - left) / scale)),
                    max(0, min(self.height, (event.y - top) / scale)))

        def begin_crop(self, _widget, event):
            if event.button == 1 and self.pixbuf and not self.busy:
                self.anchor = self.source_point(event)

        def drag_crop(self, _widget, event):
            if self.anchor and not self.busy:
                self.crop = even_crop(self.anchor, self.source_point(event), self.width, self.height)
                self.selection_changed()
                self.preview.queue_draw()

        def end_crop(self, widget, event):
            if event.button == 1:
                if self.anchor and self.source_point(event) != self.anchor:
                    self.drag_crop(widget, event)
                self.anchor = None

        def reset_crop(self, *_):
            self.crop = even_crop((0, 0), (self.width, self.height), self.width, self.height)
            self.selection_changed()
            self.preview.queue_draw()

        def selection_changed(self, *_):
            valid = self.start.get_value() < self.end.get_value()
            self.save_button.set_sensitive(valid and not self.busy)
            self.copy_button.set_sensitive(False)
            x, y, w, h = self.crop
            self.crop_label.set_text(f"Crop: {w} × {h} px · posisi {x}, {y}")
            self.status.set_text("Video asli tetap disimpan." if valid else "Waktu akhir harus lebih besar dari awal.")

        def seek_changed(self, *_):
            if self.preview_timer:
                GLib.source_remove(self.preview_timer)
            self.preview_timer = GLib.timeout_add(180, self.load_preview)

        def load_preview(self):
            self.preview_timer = None
            with self.lock:
                self.preview_generation += 1
                generation = self.preview_generation
                if self.preview_process and self.preview_process.poll() is None:
                    self.preview_process.terminate()
            seconds = self.seek.get_value()
            threading.Thread(target=self.preview_worker, args=(generation, seconds), daemon=True).start()
            return False

        def preview_worker(self, generation, seconds):
            try:
                with self.lock:
                    if self.closed or generation != self.preview_generation:
                        return
                    proc = subprocess.Popen(
                        ["ffmpeg", "-nostdin", "-v", "error", "-hwaccel", "none", "-ss", str(seconds),
                         "-i", str(self.source), "-frames:v", "1", "-vf",
                         "scale=960:540:force_original_aspect_ratio=decrease,setsar=1",
                         "-threads", "1", "-f", "image2pipe", "-c:v", "png", "-"],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    self.preview_process = proc
                try:
                    data, error = proc.communicate(timeout=15)
                except subprocess.TimeoutExpired:
                    proc.kill()
                    proc.communicate()
                    raise ValueError("Preview terlalu lama. Coba posisi waktu lain.")
                if proc.returncode == 0 and data:
                    GLib.idle_add(self.show_frame, generation, data)
                elif proc.returncode > 0:
                    raise ValueError(error.decode(errors="replace")[-240:] or "Preview tidak tersedia.")
            except Exception as error:
                GLib.idle_add(self.preview_error, generation, str(error))

        def preview_error(self, generation, message):
            if not self.closed and generation == self.preview_generation:
                self.status.set_text(message)
            return False

        def show_frame(self, generation, data):
            if not self.closed and generation == self.preview_generation:
                loader = GdkPixbuf.PixbufLoader.new_with_type("png")
                loader.write(data)
                loader.close()
                self.pixbuf = loader.get_pixbuf()
                self.preview.queue_draw()
            return False

        def save_video(self, *_):
            dialog = Gtk.FileChooserDialog(title="Simpan hasil edit", transient_for=self,
                                           action=Gtk.FileChooserAction.SAVE)
            dialog.add_buttons("Batal", Gtk.ResponseType.CANCEL, "Simpan", Gtk.ResponseType.ACCEPT)
            dialog.set_local_only(True)
            dialog.set_do_overwrite_confirmation(True)
            dialog.set_current_folder(str(self.source.parent))
            dialog.set_current_name(self.source.stem + "-edited.mp4")
            response = dialog.run()
            name = dialog.get_filename()
            dialog.destroy()
            if response != Gtk.ResponseType.ACCEPT or not name:
                return
            target = Path(name)
            if target.suffix.lower() != ".mp4":
                self.status.set_text("Gunakan nama file berakhiran .mp4.")
                return
            if target.resolve() == self.source or (target.exists() and target.samefile(self.source)):
                self.status.set_text("Pilih nama baru agar video asli tetap disimpan.")
                return
            self.busy = True
            self.cancel_export.clear()
            self.controls.set_sensitive(False)
            self.save_button.set_sensitive(False)
            self.copy_button.set_sensitive(False)
            self.cancel_button.set_sensitive(True)
            self.progress.set_fraction(0)
            self.progress.set_text("Menyimpan…")
            self.status.set_text(str(target))
            args = (target, self.start.get_value(), self.end.get_value(), self.crop)
            # Finish cancellation/temporary-file cleanup even when the window closes.
            threading.Thread(target=self.export_worker, args=args).start()

        def export_worker(self, target, start, end, crop):
            temporary = None
            try:
                fd, name = tempfile.mkstemp(prefix=".video-edit-", suffix=".mp4", dir=target.parent)
                os.close(fd)
                temporary = Path(name)
                with tempfile.TemporaryFile() as errors:
                    with self.lock:
                        if self.cancel_export.is_set():
                            raise ValueError("Ekspor dibatalkan.")
                        self.export_process = subprocess.Popen(export_command(self.source, temporary, start, end, crop),
                                                               stdout=subprocess.PIPE, stderr=errors, text=True)
                        proc = self.export_process
                    for line in proc.stdout:
                        if line.startswith("out_time_us="):
                            value = line.strip().partition("=")[2]
                            if value.isdigit():
                                GLib.idle_add(self.update_progress, min(0.99, int(value) / 1e6 / (end - start)))
                    proc.stdout.close()
                    result = proc.wait()
                    if self.cancel_export.is_set():
                        raise ValueError("Ekspor dibatalkan.")
                    if result or not temporary.stat().st_size:
                        errors.seek(0)
                        raise ValueError(errors.read().decode(errors="replace")[-400:] or "Gagal menyimpan video.")
                with self.lock:
                    if self.cancel_export.is_set():
                        raise ValueError("Ekspor dibatalkan.")
                    os.replace(temporary, target)
                GLib.idle_add(self.export_finished, target, None)
            except Exception as error:
                GLib.idle_add(self.export_finished, None, str(error))
            finally:
                if temporary:
                    temporary.unlink(missing_ok=True)

        def update_progress(self, fraction):
            if not self.closed and self.busy:
                self.progress.set_fraction(fraction)
                self.progress.set_text(f"Menyimpan… {fraction:.0%}")
            return False

        def export_finished(self, target, error):
            if self.closed:
                return False
            self.busy = False
            self.controls.set_sensitive(True)
            self.cancel_button.set_sensitive(False)
            self.selection_changed()
            if target:
                self.saved_file = target
                self.copy_button.set_sensitive(True)
                self.progress.set_fraction(1)
                self.progress.set_text("Selesai")
                self.status.set_text(f"Tersimpan: {target}")
            else:
                self.progress.set_fraction(0)
                self.progress.set_text("")
                self.status.set_text(error)
            return False

        def cancel_clicked(self, *_):
            self.cancel_export.set()
            with self.lock:
                if self.export_process and self.export_process.poll() is None:
                    self.export_process.terminate()

        def copy_result(self, *_):
            if self.saved_file and self.saved_file.exists():
                result = subprocess.run(["wl-copy", "--type", "text/uri-list"],
                                        input=(self.saved_file.resolve().as_uri() + "\r\n").encode(),
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self.status.set_text("File hasil edit tersalin. Paste ke aplikasi yang mendukung file."
                                     if result.returncode == 0 else "Clipboard belum bisa diisi. Coba Copy hasil lagi.")

        def open_folder(self, *_):
            folder = self.saved_file.parent if self.saved_file else self.source.parent
            subprocess.Popen(["xdg-open", str(folder)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        def close_editor(self, *_):
            self.closed = True
            if self.preview_timer:
                GLib.source_remove(self.preview_timer)
            self.cancel_clicked()
            with self.lock:
                if self.preview_process and self.preview_process.poll() is None:
                    self.preview_process.terminate()
            return False

    class App(Gtk.Application):
        def __init__(self):
            super().__init__(application_id="io.github.fajar.VideoEdit", flags=Gio.ApplicationFlags.NON_UNIQUE)

        def do_activate(self):
            path = Path(initial_file) if initial_file else None
            if path is None:
                dialog = Gtk.FileChooserDialog(title="Pilih video", action=Gtk.FileChooserAction.OPEN)
                dialog.add_buttons("Batal", Gtk.ResponseType.CANCEL, "Buka", Gtk.ResponseType.ACCEPT)
                response = dialog.run()
                name = dialog.get_filename()
                dialog.destroy()
                if response != Gtk.ResponseType.ACCEPT or not name:
                    self.quit()
                    return
                path = Path(name)
            try:
                Editor(self, path)
            except Exception as error:
                message = Gtk.MessageDialog(message_type=Gtk.MessageType.ERROR,
                                            buttons=Gtk.ButtonsType.CLOSE, text="Video tidak bisa dibuka")
                message.format_secondary_text(str(error))
                message.run()
                message.destroy()
                self.quit()

    return App().run([])


if __name__ == "__main__":
    if len(sys.argv) > 2:
        raise SystemExit(f"Usage: {sys.argv[0]} [VIDEO]")
    raise SystemExit(run_gui(sys.argv[1] if len(sys.argv) == 2 else None))
