"""Run with: python3 -m unittest discover -s tests -v (requires ffmpeg/ffprobe)."""
import hashlib
import json
from pathlib import Path
import random
import runpy
import subprocess
import tempfile
import unittest


editor = runpy.run_path(str(Path(__file__).resolve().parents[1] / "bin/video-edit.py"),
                       run_name="video_editor_core")


class CropTests(unittest.TestCase):
    def test_scaled_pixel_boundaries(self):
        crop = editor["even_crop"]((39.999999999, 20), (600.000000001, 340), 640, 360)
        self.assertEqual(crop, (40, 20, 560, 320))

    def test_crop_stays_inside_odd_sized_source(self):
        randomizer = random.Random(23)
        for _ in range(250):
            points = [(randomizer.uniform(-100, 750), randomizer.uniform(-100, 470)) for _ in range(2)]
            x, y, width, height = editor["even_crop"](*points, 641, 361)
            self.assertTrue(all(value % 2 == 0 for value in (x, y, width, height)))
            self.assertGreaterEqual(min(x, y), 0)
            self.assertGreaterEqual(min(width, height), 2)
            self.assertLessEqual(x + width, 641)
            self.assertLessEqual(y + height, 361)

    def test_invalid_trim_is_rejected_before_encoding(self):
        for start, end in [(-1, 2), (2, 1), (1, 1), (0, float("nan"))]:
            with self.assertRaises(ValueError):
                editor["export_command"]("source.mp4", "out.mp4", start, end, (0, 0, 640, 360))


class ExportTests(unittest.TestCase):
    def test_recording_without_audio(self):
        with tempfile.TemporaryDirectory(prefix="silent recording test ") as temporary:
            source = Path(temporary) / "silent.mp4"
            output = Path(temporary) / "trimmed.mp4"
            subprocess.run([
                "ffmpeg", "-nostdin", "-v", "error", "-f", "lavfi", "-i",
                "testsrc2=size=64x48:rate=30", "-t", "1", "-c:v", "libx264", str(source),
            ], check=True, timeout=15)
            subprocess.run(editor["export_command"](source, output, 0.2, 0.8, (2, 2, 60, 44)),
                           stdout=subprocess.DEVNULL, check=True, timeout=15)
            width, height, duration, _ = editor["probe_video"](output)
            self.assertEqual((width, height), (60, 44))
            self.assertAlmostEqual(duration, 0.6, delta=0.04)

    def test_trim_crop_audio_and_original_file(self):
        with tempfile.TemporaryDirectory(prefix="video editor test ") as temporary:
            source = Path(temporary) / "source # é.mp4"
            output = Path(temporary) / "cropped video é.mp4"
            subprocess.run([
                "ffmpeg", "-nostdin", "-v", "error", "-f", "lavfi", "-i",
                "testsrc2=size=640x360:rate=30", "-f", "lavfi", "-i",
                "sine=frequency=440:sample_rate=48000", "-t", "3",
                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", str(source),
            ], check=True, timeout=15)
            original_hash = hashlib.sha256(source.read_bytes()).digest()
            width, height, duration, fps = editor["probe_video"](source)
            self.assertEqual((width, height, fps), (640, 360, 30))
            self.assertAlmostEqual(duration, 3, delta=0.05)
            subprocess.run(editor["export_command"](source, output, 1, 2.5, (40, 20, 560, 320)),
                           stdout=subprocess.DEVNULL, check=True, timeout=15)
            info = json.loads(subprocess.check_output([
                "ffprobe", "-v", "error", "-show_entries",
                "format=duration:stream=codec_name,width,height", "-of", "json", str(output),
            ]))
            video = next(stream for stream in info["streams"] if "width" in stream)
            self.assertEqual((video["width"], video["height"], video["codec_name"]), (560, 320, "h264"))
            self.assertAlmostEqual(float(info["format"]["duration"]), 1.5, delta=0.07)
            self.assertTrue(any(stream["codec_name"] == "aac" for stream in info["streams"]))
            self.assertEqual(hashlib.sha256(source.read_bytes()).digest(), original_hash)


if __name__ == "__main__":
    unittest.main()
