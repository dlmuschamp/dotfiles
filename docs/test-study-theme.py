#!/usr/bin/env python3
"""Exercise schedule boundaries without touching the live theme."""
import importlib.machinery
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

script = Path(__file__).resolve().parents[1] / "bin/study-theme"
loader = importlib.machinery.SourceFileLoader("study_theme", str(script))
spec = importlib.util.spec_from_loader(loader.name, loader)
module = importlib.util.module_from_spec(spec)
loader.exec_module(module)


class ScheduleTests(unittest.TestCase):
    def test_normal_day(self):
        for time, expected in [("00:00", "night"), ("06:59", "night"),
                               ("07:00", "day"), ("12:00", "day"),
                               ("19:59", "day"), ("20:00", "night"),
                               ("23:59", "night")]:
            with self.subTest(time=time):
                self.assertEqual(module.scheduled_mode(time, "07:00", "20:00"), expected)

    def test_schedule_across_midnight(self):
        for time, expected in [("19:59", "night"), ("20:00", "day"),
                               ("00:00", "day"), ("06:59", "day"), ("07:00", "night")]:
            with self.subTest(time=time):
                self.assertEqual(module.scheduled_mode(time, "20:00", "07:00"), expected)

    def test_invalid_times(self):
        for time in ["24:00", "7:00", "07:60", "garbage", "", None]:
            with self.subTest(time=time), self.assertRaises(ValueError):
                module.minutes(time)

    def test_equal_boundaries_rejected(self):
        with self.assertRaises(ValueError):
            module.scheduled_mode("12:00", "07:00", "07:00")


class CommandTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ.get("JCODE_SCRATCH_DIR"))
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        config = self.home / ".config/omarchy"
        config.mkdir(parents=True)
        (config / "study-theme.toml").write_text(
            'day_start="07:00"\nnight_start="20:00"\n'
            'day_theme="study-day"\nnight_theme="study-night"\n')
        self.env = {**os.environ, "HOME": str(self.home),
                    "XDG_CONFIG_HOME": str(self.home / ".config"),
                    "XDG_STATE_HOME": str(self.home / ".local/state"),
                    "HYPRLAND_INSTANCE_SIGNATURE": ""}
        self.override = self.home / ".local/state/study-theme/override"

    def run_cli(self, *args):
        return subprocess.run([sys.executable, str(script), *args], env=self.env,
                              capture_output=True, text=True, timeout=5, check=True).stdout

    def test_preview_has_no_side_effects(self):
        self.assertEqual(self.run_cli("day", "--at", "20:00").strip(), "study-night")
        self.assertFalse((self.home / ".local/state").exists())

    def test_manual_override_and_auto(self):
        self.assertIn("deferring", self.run_cli("day"))
        self.assertEqual(self.override.read_text().strip(), "day")
        self.assertIn("Target: study-day", self.run_cli("status"))
        self.run_cli("night")
        self.assertIn("Target: study-night", self.run_cli("status"))
        self.run_cli("auto")
        self.assertFalse(self.override.exists())
        self.assertIn("Mode: auto", self.run_cli("status"))

    def test_off_does_not_apply(self):
        self.assertEqual(self.run_cli("off"), "")
        self.assertEqual(self.run_cli("apply"), "")
        self.assertIn("Target: unchanged", self.run_cli("status"))

    def test_matching_theme_is_noop(self):
        current = self.home / ".local/state/omarchy/current"
        current.mkdir(parents=True)
        (current / "theme.name").write_text("study-night\n")
        self.assertEqual(self.run_cli("night"), "")
        self.assertEqual(self.run_cli("apply"), "")


if __name__ == "__main__":
    unittest.main()
