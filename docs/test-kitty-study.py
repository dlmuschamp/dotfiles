#!/usr/bin/env python3
"""Run without opening a window: kitty +runpy 'import runpy; runpy.run_path("docs/test-kitty-study.py", run_name="__main__")'."""
from pathlib import Path
import os
import subprocess
import tempfile
import tomllib

from kitty.config import load_config
from kitty.fast_data_types import CURSOR_BEAM
from kitty.fonts.common import get_font_files
from kitty.options.utils import parse_shortcut

ROOT = Path(__file__).resolve().parents[1]


def config(path):
    bad = []
    opts = load_config(str(path), accumulate_bad_lines=bad)
    assert not bad, bad
    return opts


def color(value):
    return f"#{int(value):06X}"


opts = config(ROOT / "kitty/kitty.conf")
assert opts.font_size == 16
assert opts.disable_ligatures == 2
assert opts.term == "xterm-kitty"
assert opts.allow_remote_control == "no"
assert opts.shell == "."
assert opts.background_opacity == 1
assert opts.text_fg_override_threshold == (9.0, "ratio")
assert opts.dim_opacity == 1.0
assert opts.cursor_shape == CURSOR_BEAM
assert opts.cursor_blink_interval == (0.0, 0.0) or opts.cursor_blink_interval == 0
assert opts.cursor_trail == 0
assert opts.tab_bar_style == "hidden"
assert all(x == 10.5 for x in opts.window_padding_width)
for slot, suffix in {"medium": "Regular", "bold": "Bold", "italic": "Italic", "bi": "BoldItalic"}.items():
    font = get_font_files(opts)[slot]
    assert font["family"] == "IBM Plex Mono", font
    assert Path(font["path"]).name == f"IBMPlexMono-{suffix}.ttf", font
    print(f"PASS {slot}: {font['path']}")

for shortcut, action in {
    "shift+insert": "paste_from_clipboard",
    "ctrl+insert": "copy_to_clipboard",
    "ctrl+shift+c": "copy_to_clipboard",
    "ctrl+shift+v": "paste_from_clipboard",
    "shift+enter": r"send_text all \x1b[13;2u",
    "alt+shift+enter": r"send_text all \x1b[13;4u",
}.items():
    definitions = opts.keyboard_modes[""].keymap[parse_shortcut(shortcut)]
    assert definitions[-1].definition == action, (shortcut, definitions)
print("PASS appearance, shell, TERM, remote-control policy and key mappings")

for theme in ("study-day", "study-night"):
    directory = ROOT / "omarchy/themes" / theme
    roles = tomllib.loads((directory / "colors.toml").read_text())
    alacritty = tomllib.loads((directory / "alacritty.toml").read_text())["colors"]
    themed = config(directory / "kitty.conf")
    for key, role in {
        "foreground": "foreground", "background": "background", "cursor": "cursor",
        "cursor_text_color": "cursor_text", "selection_foreground": "selection_text",
        "selection_background": "selection_background",
    }.items():
        assert color(getattr(themed, key)) == roles[role].upper(), (theme, key)
    names = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "white")
    for index in range(16):
        expected = alacritty["normal" if index < 8 else "bright"][names[index % 8]]
        assert color(getattr(themed, f"color{index}")) == expected.upper(), (theme, index)
    print(f"PASS {theme}: cursor, selection, foreground/background and all 16 ANSI colors")

# Exercise only the safe Kitty deployment function, never the full bootstrap.
bootstrap = (ROOT / "bootstrap").read_text()
start = bootstrap.index("install_kitty_config() {")
end = bootstrap.index("\n}\n", start) + 3
function = bootstrap[start:end]
with tempfile.TemporaryDirectory(prefix="kitty-study-") as tmp:
    home = Path(tmp)
    target = home / "kitty/kitty.conf"
    script = function + '\ninstall_kitty_config\n'
    env = dict(os.environ, repo_dir=str(ROOT), config_home=tmp)
    def install():
        subprocess.run(["bash", "-eu", "-c", script], env=env, check=True)
    install()
    assert target.is_symlink() and target.resolve() == ROOT / "kitty/kitty.conf"
    install()
    target.unlink()
    target.write_text("# preserve personal config\n")
    install()
    assert not target.is_symlink() and target.read_text() == "# preserve personal config\n"
    target.unlink()
    target.symlink_to(home / "missing-personal.conf")
    install()
    assert target.is_symlink() and os.readlink(target) == str(home / "missing-personal.conf")
print("PASS bootstrap: new install, idempotence, personal file and dangling symlink preservation")

subprocess.run(["bash", "-n", str(ROOT / "bootstrap")], check=True)
env = dict(os.environ, XDG_CURRENT_DESKTOP="Hyprland")
selected = subprocess.check_output(["xdg-terminal-exec", "--print-id"], env=env, text=True).strip()
assert selected == "kitty.desktop", selected
command = subprocess.check_output([
    "xdg-terminal-exec", "--print-cmd", "--dir=" + str(ROOT), "bash", "-lc", "printf test",
], env=env, text=True).splitlines()
assert command == ["kitty", "--working-directory", str(ROOT), "--", "bash", "-lc", "printf test"], command
assert (ROOT / "xdg-terminal-exec/hyprland-xdg-terminals.list").read_text().splitlines() == ["kitty.desktop", "Alacritty.desktop"]
print("PASS bootstrap syntax and installed default resolver with working directory and command")
with tempfile.TemporaryDirectory(prefix="kitty-resolver-") as tmp:
    isolated = Path(tmp)
    (isolated / "data/applications").mkdir(parents=True)
    (isolated / "config").mkdir()
    (isolated / "config/hyprland-xdg-terminals.list").write_text("kitty.desktop\nAlacritty.desktop\n")
    (isolated / "data/applications/kitty.desktop").write_text(
        "[Desktop Entry]\nType=Application\nName=Unavailable Kitty\nHidden=true\n"
    )
    fallback_env = dict(env, XDG_CONFIG_HOME=str(isolated / "config"),
                        XDG_DATA_HOME=str(isolated / "data"), XDG_DATA_DIRS="/usr/share",
                        XDG_CACHE_HOME=str(isolated / "cache"), XDG_CONFIG_DIRS=str(isolated / "config"))
    fallback = subprocess.check_output(["xdg-terminal-exec", "--print-id"], env=fallback_env, text=True).strip()
    assert fallback == "Alacritty.desktop", fallback
print("PASS actual resolver falls back to Alacritty when Kitty is unavailable")
print("Real-window inline images, SIGUSR1 reload and theme/portal integration require separate GUI tests.")
