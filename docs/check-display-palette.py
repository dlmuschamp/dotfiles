"""Check proposed sRGB colors. No desktop settings are read or changed."""
import json
from pathlib import Path


def luminance(hex_color):
    channels = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]
    return sum(v * weight for v, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast(first, second):
    lo, hi = sorted((luminance(first), luminance(second)))
    return (hi + 0.05) / (lo + 0.05)


palette = json.loads(Path(__file__).with_name("display-palette-proposal.json").read_text())
roles = ["text", "comments", "keywords", "functions", "strings", "numbers", "types", "errors"]
for mode in ("light", "dark"):
    colors = palette[mode]
    print(f"\n{mode.upper()}: role, primary background ratio, current-line ratio")
    for role in roles:
        ratios = [contrast(colors[role], colors[background]) for background in ("background", "current_line")]
        assert min(ratios) >= 7, (mode, role, ratios)
        print(f"{role:12} {colors[role]}  {ratios[0]:.2f}:1  {ratios[1]:.2f}:1")
    for role in ("selection", "search"):
        ratio = contrast(colors[role + "_text"], colors[role + "_background"])
        assert ratio >= 7, (mode, role, ratio)
        print(f"{role:12} {ratio:.2f}:1")
    for role in ("active_border", "inactive_border"):
        ratio = contrast(colors[role], colors["background"])
        assert ratio >= 3, (mode, role, ratio)
        print(f"{role:16} {ratio:.2f}:1")
print("\nPASS: 32 text/background pairs >= 7:1, four selection/search pairs >= 7:1, four border pairs >= 3:1.")
print("These are calculated color ratios, not measurements of the physical display or a clinical comfort test.")
