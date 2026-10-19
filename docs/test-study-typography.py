#!/usr/bin/env python3
"""Verify study typography and real Fontconfig resolution without opening windows."""
from pathlib import Path
import subprocess
import tomllib
import unittest
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]


def family(pattern):
    return subprocess.check_output(["fc-match", "-f", "%{family}", pattern], text=True).strip()


class TypographyTests(unittest.TestCase):
    def test_terminal_faces_and_size(self):
        font = tomllib.loads((ROOT / "alacritty/alacritty.toml").read_text())["font"]
        for kind, style in (("normal", "Regular"), ("bold", "Bold"), ("italic", "Italic")):
            self.assertEqual(font[kind], {"family": "IBM Plex Mono", "style": style})
        self.assertEqual(font["size"], 16.0)

    def test_alias_preserves_explicit_choices(self):
        tree = ET.parse(ROOT / "fontconfig/fonts.conf")
        aliases = {entry.findtext("family"): entry for entry in tree.findall("alias")}
        self.assertEqual(aliases["monospace"].findtext("prefer/family"), "IBM Plex Mono")
        self.assertEqual(aliases["IBM Plex Mono"].findtext("accept/family"), "Symbols Nerd Font Mono")
        self.assertEqual(aliases["IBM Plex Mono"].get("binding"), "strong")
        self.assertFalse(tree.findall("match"), "Do not globally replace explicit font requests")

    def test_real_face_resolution(self):
        for style in ("Regular", "Bold", "Italic", "Bold Italic"):
            with self.subTest(style=style):
                self.assertEqual(family(f"IBM Plex Mono:style={style}"), "IBM Plex Mono")
        self.assertEqual(family("monospace"), "IBM Plex Mono")
        self.assertIn("JetBrainsMonoNL", family("JetBrainsMonoNL Nerd Font Mono"))

    def test_ascii_is_plex_and_icons_are_symbols_only(self):
        # Check ASCII glyphs used in firmware/code and actual Nerd icon fallbacks.
        for glyph in ("23", "25", "30", "31", "49", "4f", "6c", "7b"):
            with self.subTest(glyph=glyph):
                self.assertEqual(family(f"IBM Plex Mono:charset={glyph}"), "IBM Plex Mono")
        for glyph in ("e0b0", "f013", "f121"):
            with self.subTest(glyph=glyph):
                self.assertEqual(family(f"IBM Plex Mono:charset={glyph}"), "Symbols Nerd Font Mono")

    def test_font_dependencies_retained(self):
        packages = (ROOT / "packages/native.txt").read_text().splitlines()
        self.assertIn("ttf-ibm-plex", packages)
        self.assertIn("ttf-nerd-fonts-symbols-mono", packages)


if __name__ == "__main__":
    unittest.main()
