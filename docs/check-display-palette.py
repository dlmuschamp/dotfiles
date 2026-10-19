"""Check installed-design sRGB palettes and syntax separation, without desktop changes."""
import itertools
import json
import math
from pathlib import Path
import tomllib

ROOT = Path(__file__).resolve().parents[1]
ROLES = ["text", "comments", "keywords", "functions", "strings", "numbers", "types", "errors"]


def linear_rgb(hex_color):
    channels = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in channels]


def luminance(hex_color):
    return sum(v * weight for v, weight in zip(linear_rgb(hex_color), (0.2126, 0.7152, 0.0722)))


def contrast(first, second):
    lo, hi = sorted((luminance(first), luminance(second)))
    return (hi + 0.05) / (lo + 0.05)


def oklab(hex_color):
    """Björn Ottosson's sRGB conversion: https://bottosson.github.io/posts/oklab/"""
    r, g, b = linear_rgb(hex_color)
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def check():
    palette = json.loads((ROOT / "docs/display-palette-proposal.json").read_text())
    for mode, name in (("light", "day"), ("dark", "night")):
        colors = palette[mode]
        directory = ROOT / f"omarchy/themes/study-{name}"
        native = tomllib.loads((directory / "colors.toml").read_text())
        terminal = tomllib.loads((directory / "alacritty.toml").read_text())
        for key, value in colors.items():
            assert native[key] == value, (mode, key, "spec/native mismatch")
        assert terminal["window"]["opacity"] == 1.0
        assert terminal["colors"]["primary"] == {"background": colors["background"], "foreground": colors["text"]}
        print(f"\n{mode.upper()}: role, primary background ratio, current-line ratio")
        for role in ROLES:
            ratios = [contrast(colors[role], colors[background]) for background in ("background", "current_line")]
            assert min(ratios) >= 7, (mode, role, ratios)
            if mode == "dark":
                assert min(ratios) >= 7.4, (mode, role, "night contrast floor", ratios)
            if role not in ("text",):
                assert native[f"syntax_{role}"] == colors[role], (mode, role, "syntax alias mismatch")
            print(f"{role:12} {colors[role]}  {ratios[0]:.2f}:1  {ratios[1]:.2f}:1")
        for role in ("selection", "search"):
            ratio = contrast(colors[role + "_text"], colors[role + "_background"])
            assert ratio >= 7, (mode, role, ratio)
            print(f"{role:12} {ratio:.2f}:1")
        assert terminal["colors"]["selection"] == {"text": colors["selection_text"], "background": colors["selection_background"]}
        for state in ("matches", "focused_match"):
            assert terminal["colors"]["search"][state] == {"foreground": colors["search_text"], "background": colors["search_background"]}
        ansi_roles = {"red": "errors", "green": "strings", "yellow": "numbers", "blue": "functions", "magenta": "keywords", "cyan": "types"}
        for ansi, role in ansi_roles.items():
            for level in ("normal", "bright"):
                assert terminal["colors"][level][ansi] == colors[role], (mode, level, ansi)
        for role in ("active_border", "inactive_border"):
            ratio = contrast(colors[role], colors["background"])
            assert ratio >= 3, (mode, role, ratio)
            print(f"{role:16} {ratio:.2f}:1")

    # Project-specific regression guards, NOT WCAG or color-vision thresholds.
    # Both modes use the same separation floor, with weight/diagnostic cues too.
    for mode, minimum in (("light", 0.10), ("dark", 0.10)):
        colors = palette[mode]
        print(f"\n{mode.upper()}: Oklab syntax distances (normal color vision model)")
        pairs = []
        for a, b in itertools.combinations(ROLES[2:], 2):
            distance = math.dist(oklab(colors[a]), oklab(colors[b]))
            assert distance >= minimum, (mode, a, b, distance)
            pairs.append((distance, a, b))
        for distance, a, b in sorted(pairs):
            print(f"{a:10} / {b:10} {distance:.3f}")
        print(f"Minimum syntax distance: {min(pairs)[0]:.6f} (guard {minimum:.2f})")
        for state in ("selection", "search"):
            ratio = contrast(colors[state + "_background"], colors["background"])
            assert ratio >= 1.5, (mode, state, "highlight visibility regressed", ratio)
            print(f"{state} / canvas: {ratio:.2f}:1")
    # Keep role families stable when switching modes: pink keywords, blue
    # callables, green strings, ochre numbers, violet types, red errors.
    for role in ("keywords", "functions", "strings", "numbers", "types", "errors"):
        day = oklab(palette["light"][role])
        night = oklab(palette["dark"][role])
        day_hue, night_hue = math.atan2(day[2], day[1]), math.atan2(night[2], night[1])
        difference = abs(math.atan2(math.sin(day_hue - night_hue), math.cos(day_hue - night_hue)))
        print(f"{role:10} day/night hue difference: {math.degrees(difference):.2f} degrees")
        assert math.degrees(difference) <= 35, (role, "day/night hue family changed", math.degrees(difference))
    print("\nPASS: 32 text pairs >= 7:1, four selection/search text pairs >= 7:1, four borders >= 3:1.")
    print("Spec/native/terminal mappings match. Both-mode syntax, interaction and hue-family guards pass.")
    print("Calculated sRGB/model results, not physical-display, color-blindness or personal-comfort certification.")


if __name__ == "__main__":
    check()
