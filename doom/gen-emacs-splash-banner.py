#!/usr/bin/env python3
"""Generate emacs-splash-banner.el from the official Emacs splash.xpm."""
from pathlib import Path
import colorsys
import re

SPLASH = Path("/usr/share/emacs/30.2/etc/images/splash.xpm")
OUT = Path(__file__).resolve().parent / "emacs-splash-banner.el"

# Slightly smaller than the first high-res version (~73x32).
OUT_W, OUT_H = 52, 24


def main() -> None:
    text = SPLASH.read_text(errors="replace")
    start = text.find("static char")
    strs = re.findall(r'"([^"]*)"', text[start:])
    cols, rows, ncolors, cpp = map(int, strs[0].split()[:4])
    palette = {}
    for i in range(1, ncolors + 1):
        s = strs[i]
        key = s[:cpp]
        m = re.search(r"\bc\s+(\S+)", s)
        c = m.group(1) if m else "None"
        if c.startswith("#") and len(c) == 4:
            c = "#" + "".join(ch * 2 for ch in c[1:])
        palette[key] = c
    pix = strs[1 + ncolors : 1 + ncolors + rows]

    def parse_rgb(c):
        if not c or c in ("None", "none", "transparent"):
            return None
        if not str(c).startswith("#") or len(c) < 7:
            return None
        try:
            return int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16)
        except ValueError:
            return None

    def keep_ink(rgb):
        if rgb is None:
            return False
        r, g, b = [x / 255.0 for x in rgb]
        _h, l, s = colorsys.rgb_to_hls(r, g, b)
        if l > 0.82:
            return False
        if l > 0.62 and s < 0.35:
            return False
        return True

    def color_at(x, y):
        if not (0 <= x < cols and 0 <= y < rows):
            return None
        c = palette.get(pix[y][x * cpp : (x + 1) * cpp], "None")
        rgb = parse_rgb(c)
        if not keep_ink(rgb):
            return None
        return "#%02x%02x%02x" % rgb

    def sample(x0, x1, y0, y1):
        counts = {}
        for y in range(y0, min(y1, rows)):
            for x in range(x0, min(x1, cols)):
                c = color_at(x, y)
                if c:
                    counts[c] = counts.get(c, 0) + 1
        return max(counts, key=counts.get) if counts else None

    cells = []
    for cy in range(OUT_H):
        y0 = int(cy * 2 * rows / (OUT_H * 2))
        y1 = int((cy * 2 + 1) * rows / (OUT_H * 2))
        y2 = int((cy * 2 + 2) * rows / (OUT_H * 2))
        y1 = max(y1, y0 + 1)
        y2 = max(y2, y1 + 1)
        row = []
        for cx in range(OUT_W):
            x0 = int(cx * cols / OUT_W)
            x1 = max(x0 + 1, int((cx + 1) * cols / OUT_W))
            row.append((sample(x0, x1, y0, y1), sample(x0, x1, y1, y2)))
        cells.append(row)

    def row_empty(r):
        return all(t is None and b is None for t, b in r)

    while cells and row_empty(cells[0]):
        cells.pop(0)
    while cells and row_empty(cells[-1]):
        cells.pop()
    left, right = 0, len(cells[0])
    while left < right and all(c[left] == (None, None) for c in cells):
        left += 1
    while right > left and all(c[right - 1] == (None, None) for c in cells):
        right -= 1
    cells = [[r[x] for x in range(left, right)] for r in cells]
    width = len(cells[0])

    def cell_ch(top, bot):
        if top is None and bot is None:
            return " "
        if bot is None:
            return "▀"
        if top is None:
            return "▄"
        if top == bot:
            return "█"
        return "▀"

    # Pad every row to equal width so Doom's line-prefix centering is true.
    for row in cells:
        while len(row) < width:
            row.append((None, None))

    def esc(s: str) -> str:
        return s.replace("\\", "\\\\").replace('"', '\\"')

    parts: list[str] = []
    for row in cells:
        runs: list[tuple[tuple, str]] = []
        cur = None
        buf = ""
        for top, bot in row:
            key = (top, bot)
            ch = cell_ch(top, bot)
            if cur is None:
                cur, buf = key, ch
            elif key == cur:
                buf += ch
            else:
                runs.append((cur, buf))
                cur, buf = key, ch
        if buf:
            runs.append((cur, buf))
        for (top, bot), text in runs:
            if top is None and bot is None:
                parts.append(f'"{esc(text)}"')
            elif bot is None:
                parts.append(
                    f'(propertize "{esc(text)}" \'face \'(:foreground "{top}"))'
                )
            elif top is None:
                parts.append(
                    f'(propertize "{esc(text)}" \'face \'(:foreground "{bot}"))'
                )
            elif top == bot:
                parts.append(
                    f'(propertize "{esc(text)}" \'face \'(:foreground "{top}"))'
                )
            else:
                parts.append(
                    f'(propertize "{esc(text)}" \'face \''
                    f'(:foreground "{top}" :background "{bot}"))'
                )
        # Newlines with line-height t collapse inter-row seams between half-blocks.
        parts.append("(propertize \"\\n\" 'line-height t)")

    parts.append("(propertize \"\\n\" 'line-height t)")
    caption = "G N U   E M A C S"
    pad = max(0, (width - len(caption)) // 2)
    caption_line = (" " * pad) + caption
    if len(caption_line) < width:
        caption_line += " " * (width - len(caption_line))
    parts.append(
        f'(propertize "{esc(caption_line)}" \'face \'+dashboard-banner)'
    )

    body = "\n   ".join(parts)
    OUT.write_text(
        ";;; emacs-splash-banner.el --- colored Emacs splash banner "
        "-*- lexical-binding: t; -*-\n"
        ";; Auto-generated from Emacs etc/images/splash.xpm "
        "(smaller, equal-width for centering).\n"
        ";; Regenerate: python3 gen-emacs-splash-banner.py\n"
        "(defun luciano/emacs-splash-banner-string ()\n"
        '  "Colored half-block Emacs splash (scaled for the dashboard)."\n'
        "  (concat\n"
        f"   {body}))\n"
        "\n"
        "(provide 'emacs-splash-banner)\n"
    )
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes) size={len(cells)}x{width}")


if __name__ == "__main__":
    main()
