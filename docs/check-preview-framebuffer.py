#!/usr/bin/env python3
"""Audit six-row real Kitty preview fixture screenshots, not synthetic colors.

Usage: python3 docs/check-preview-framebuffer.py /path/to/captured/frames
Requires preview-contrast-{night,day}-{before,after}.png, with six text rows
starting at y=14 and spaced 56 px: notes, reasoning, dim purple, dim accent,
dim green diff, bold black. See study-theme.md for the measured outcome.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import runpy
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("frames", type=Path)
args = parser.parse_args()
contrast = runpy.run_path(str(Path(__file__).with_name("check-display-palette.py")))["contrast"]
labels = ("notes", "reasoning", "dim_purple", "dim_accent", "dim_green_diff", "bold_black")
report = {}
for mode, background in (("night", "#1F2329"), ("day", "#F7F5F0")):
    report[mode] = {}
    for state in ("before", "after"):
        image = Image.open(args.frames / f"preview-contrast-{mode}-{state}.png").convert("RGB")
        report[mode][state] = {}
        for index, label in enumerate(labels):
            row = image.crop((14, 14 + 56 * index, 900, 44 + 56 * index))
            colors = Counter(row.get_flattened_data())
            colors.pop(tuple(bytes.fromhex(background[1:])), None)
            ink, count = colors.most_common(1)[0]
            color = "#%02X%02X%02X" % ink
            report[mode][state][label] = {
                "ink": color, "solid_pixels": count,
                "contrast": round(contrast(color, background), 3),
            }
    for label, row in report[mode]["after"].items():
        assert row["solid_pixels"] > 100, (mode, label, row)
        assert row["contrast"] >= 7.4, (mode, label, row)
    for label in ("dim_purple", "dim_accent"):
        red, green, blue = bytes.fromhex(report[mode]["after"][label]["ink"][1:])
        assert blue > red > green, (mode, label, "purple hue lost")
print(json.dumps(report, indent=2))
print("PASS: 12 actual framebuffer samples >=7.4:1, purple retained in both modes")
