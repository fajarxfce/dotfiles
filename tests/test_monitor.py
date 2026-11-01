"""Exercise monitor presets with recorded displays and an isolated Hyprland CLI."""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bin/monitor.sh"
PORTRAIT = """# Saved manual layout
monitor=eDP-2,1920x1080@144,100x200,1,vrr,0
monitor=HDMI-A-1,1920x1080@60,0x0,1,cm,srgb
monitor=HDMI-A-1,transform,3
monitor=DP-9,preferred,auto,1
"""


class MonitorPresets(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="monitor-preset-test-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.config = self.root / "config/hypr/monitors.conf"
        self.config.parent.mkdir(parents=True)
        self.config.write_text(PORTRAIT)
        self.env = dict(os.environ, PATH=str(self.bin) + ":" + os.environ["PATH"],
                        XDG_CONFIG_HOME=str(self.root / "config"),
                        XDG_CACHE_HOME=str(self.root / "cache"),
                        MONITOR_TEST_ROOT=str(self.root))
        hyprctl = self.bin / "hyprctl"
        hyprctl.write_text("""#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
root=Path(os.environ['MONITOR_TEST_ROOT'])
if sys.argv[1]=='monitors':
    print((root/'displays.json').read_text())
elif sys.argv[1]=='eval':
    with (root/'commands.jsonl').open('a') as file:
        file.write(json.dumps(sys.argv[2])+'\\n')
    print(os.environ.get('MONITOR_TEST_RESPONSE','ok'))
else:
    raise SystemExit('Unexpected test command')
""")
        hyprctl.chmod(0o755)
        notify = self.bin / "notify-send"
        notify.write_text("#!/bin/sh\nexit 0\n")
        notify.chmod(0o755)
        self.displays(["1920x1080@144.00Hz", "1920x1080@60.00Hz"],
                      ["3840x2160@30.00Hz", "1920x1080@60.00Hz"])

    def displays(self, internal, external):
        (self.root / "displays.json").write_text(json.dumps([
            {"name": "eDP-2", "availableModes": internal, "transform": 0},
            {"name": "HDMI-A-1", "availableModes": external, "transform": 3},
        ]))

    def preset(self, *args, success=True):
        result = subprocess.run([str(SCRIPT), *args], env=self.env, capture_output=True,
                                text=True, timeout=10)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        command = json.loads((self.root / "commands.jsonl").read_text().splitlines()[-1])
        specs = []
        for fields in re.findall(r"hl\.monitor\(\{(.*?)\}\)", command):
            specs.append(json.loads("{" + re.sub(r"(\w+)=", r'"\1":', fields) + "}"))
        return specs

    def test_mirror_clears_portrait_and_saves_a_reload_safe_layout(self):
        source, mirror = self.preset("mirror")
        self.assertEqual([source["mode"], mirror["mode"]], ["1920x1080@60.00Hz"] * 2)
        self.assertEqual([source["transform"], mirror["transform"]], [0, 0])
        self.assertEqual(source["mirror"], "")
        self.assertEqual(mirror["mirror"], "eDP-2")
        saved = self.config.read_text()
        self.assertNotIn("transform,3", saved)
        self.assertEqual(saved.count("monitor=HDMI-A-1,"), 1)
        self.assertIn("cm,srgb", saved)
        source_line = next(line for line in saved.splitlines() if line.startswith("monitor=eDP-2,"))
        mirror_line = next(line for line in saved.splitlines() if line.startswith("monitor=HDMI-A-1,"))
        self.assertTrue(source_line.endswith(",mirror,"))
        self.assertTrue(mirror_line.endswith(",mirror,eDP-2"))
        self.assertIn("monitor=DP-9,preferred,auto,1", saved)
        backups = list((self.root / "cache/dotfiles/backups").glob("monitors-*.conf"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), PORTRAIT)
        self.preset("mirror")
        self.assertEqual(self.config.read_text(), saved)
        self.assertEqual(len(list(backups[0].parent.glob("monitors-*.conf"))), 1)

    def test_different_refresh_rates_are_each_supported(self):
        self.displays(["1920x1080@144.00Hz"], ["1920x1080@59.94Hz"])
        source, mirror = self.preset("mirror")
        self.assertEqual(source["mode"], "1920x1080@144.00Hz")
        self.assertEqual(mirror["mode"], "1920x1080@59.94Hz")

    def test_different_resolutions_still_enable_both_in_landscape(self):
        self.displays(["1920x1080@60.00Hz"], ["1280x720@60.00Hz"])
        for spec in self.preset("mirror"):
            self.assertEqual(spec["mode"], "preferred")
            self.assertEqual(spec["transform"], 0)
            self.assertFalse(spec["disabled"])

    def test_extend_releases_mirroring_on_both_outputs(self):
        self.preset("mirror")
        source, external = self.preset("extend", "left")
        self.assertEqual(source["mirror"], "")
        self.assertEqual(external["mirror"], "")
        self.assertEqual(external["position"], "auto-left")
        self.assertNotIn("mirror,eDP-2", self.config.read_text())

    def test_external_only_enables_target_before_disabling_source(self):
        self.preset("mirror")
        external, internal = self.preset("external")
        self.assertEqual(external["output"], "HDMI-A-1")
        self.assertEqual(external["mirror"], "")
        self.assertFalse(external["disabled"])
        self.assertTrue(internal["disabled"])
        for spec in self.preset("mirror"):
            self.assertFalse(spec["disabled"])

    def test_rejected_layout_does_not_replace_saved_config(self):
        self.env["MONITOR_TEST_RESPONSE"] = "Invalid monitor option"
        self.preset("mirror", success=False)
        self.assertEqual(self.config.read_text(), PORTRAIT)
        self.assertFalse((self.root / "cache/dotfiles/backups").exists())

    def test_mirror_without_external_leaves_saved_profile_untouched(self):
        displays = self.root / "displays.json"
        displays.write_text(json.dumps(json.loads(displays.read_text())[:1]))
        result = subprocess.run([str(SCRIPT), "mirror"], env=self.env,
                                capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "commands.jsonl").exists())
        self.assertEqual(self.config.read_text(), PORTRAIT)


if __name__ == "__main__":
    unittest.main()
