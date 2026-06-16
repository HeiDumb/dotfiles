#!/usr/bin/env python3

import argparse
import configparser
import fcntl
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import time
from pathlib import Path


HOME = Path.home()
SCHEME_PATH = HOME / ".local/state/caelestia/scheme.json"

HYPR_BORDER_PATH = HOME / ".config/hypr/dynamic-border.conf"
HYPRLAND_CONFIG_PATH = HOME / ".config/hypr/hyprland.conf"
HYPRLOCK_CONFIG_PATH = HOME / ".config/quickshell/caelestia/assets/hyprlock.conf"
HYPRLOCK_MARKER_BEGIN = "# Begin wallpaper-synced colours"
HYPRLOCK_MARKER_END = "# End wallpaper-synced colours"
CURSOR_THEME_NAME = "nier-cursors-bin"
CURSOR_LEGACY_THEME_NAME = "caelestia-cursor"
CURSOR_RELOAD_THEME_NAME = "Adwaita"
CURSOR_SIZE = 28
CURSOR_SOURCE_PATH = Path("/usr/share/icons/nier-cursors-bin")
CURSOR_THEME_PATH = HOME / ".icons" / CURSOR_THEME_NAME
CURSOR_THEME_ALIAS_PATH = HOME / ".local/share/icons" / CURSOR_THEME_NAME
CURSOR_LEGACY_THEME_PATHS = (
    HOME / ".icons" / CURSOR_LEGACY_THEME_NAME,
    HOME / ".local/share/icons" / CURSOR_LEGACY_THEME_NAME,
)
XCURSOR_PATH_VALUE = f"{HOME}/.icons:{HOME}/.local/share/icons:/usr/share/icons"
CURSOR_CACHE_PATH = HOME / ".cache/caelestia/cursors"
CURSOR_STATE_PATH = HOME / ".local/state/caelestia/cursor-theme.txt"
CURSOR_PENDING_PATH = HOME / ".local/state/caelestia/cursor-theme-pending.json"
CURSOR_LOCK_PATH = HOME / ".local/state/caelestia/cursor-theme.lock"
CURSOR_DEFAULT_INDEX_PATH = HOME / ".icons/default/index.theme"
GTK3_DYNAMIC_PATH = HOME / ".config/gtk-3.0/caelestia-dynamic.css"
GTK4_DYNAMIC_PATH = HOME / ".config/gtk-4.0/caelestia-dynamic.css"
GTK3_CSS_PATH = HOME / ".config/gtk-3.0/gtk.css"
GTK4_CSS_PATH = HOME / ".config/gtk-4.0/gtk.css"
GTK3_SETTINGS_PATH = HOME / ".config/gtk-3.0/settings.ini"
GTK4_SETTINGS_PATH = HOME / ".config/gtk-4.0/settings.ini"
GTK3_THUNAR_PATH = HOME / ".config/gtk-3.0/thunar.css"
GTK4_THUNAR_PATH = HOME / ".config/gtk-4.0/thunar.css"
ROFI_DYNAMIC_PATH = HOME / ".config/rofi/caelestia-dynamic.rasi"
FOOT_DYNAMIC_PATH = HOME / ".config/foot/colors.ini"
ZSH_THEME_PATH = HOME / ".config/zsh/wallpaper-theme.zsh"
CODE_SETTINGS_PATH = HOME / ".config/Code - OSS/User/settings.json"
CODEX_EXTENSION_CSS_GLOB = ".vscode-oss/extensions/openai.chatgpt-*/webview/assets/index-*.css"
KDE_GLOBALS_PATH = HOME / ".config/kdeglobals"
SPICETIFY_CONFIG_PATH = HOME / ".config/spicetify/config-xpui.ini"
SPICETIFY_THEME_PATH = HOME / ".config/spicetify/Themes/caelestia/color.ini"
ZED_THEME_PATH = HOME / ".config/zed/themes/caelestia.json"
STEAM_LIBRARYROOT_CUSTOM_CSS_PATH = HOME / ".local/share/Steam/steamui/libraryroot.custom.css"
STEAM_DYNAMIC_CSS_PATH = HOME / ".local/share/Steam/steamui/caelestia-dynamic.css"
STEAM_LIBRARY_CSS_PATH = HOME / ".local/share/Steam/steamui/css/library.css"
STEAM_RICE_SCRIPT_PATH = HOME / "scripts/rice-steam.sh"
STEAM_PATCHED_HEADER = "/*patched*/"
STEAM_DYNAMIC_IMPORT_RE = r'(?m)^@import url\("https://steamloopback\.host/caelestia-dynamic\.css(?:\?v=[^"]*)?"\);\n?'
DISCORD_THEME_PATHS = [
    HOME / ".config/Vencord/themes/caelestia.theme.css",
    HOME / ".config/vesktop/themes/caelestia.theme.css",
    HOME / ".config/BetterDiscord/themes/caelestia.theme.css",
    HOME / ".config/legcord/themes/caelestia.theme.css",
    HOME / ".config/equibop/themes/caelestia.theme.css",
    HOME / ".config/Equicord/themes/caelestia.theme.css",
]
ZEN_MARKER_BEGIN = "/* Begin Caelestia Dynamic */"
ZEN_MARKER_END = "/* End Caelestia Dynamic */"


def hex_rgb(value: str | None, fallback: str) -> str:
    value = (value or "").strip().lower().lstrip("#")
    if len(value) >= 6:
        return value[:6]
    return fallback


def hex_rgba(value: str | None, alpha: str = "ff", fallback: str = "ffffff") -> str:
    value = (value or "").strip().lower().lstrip("#")
    if len(value) == 8:
        return value
    if len(value) == 6:
        return f"{value}{alpha}"
    return f"{fallback}{alpha}"


def rgb_tuple(value: str | None, fallback: str) -> tuple[int, int, int]:
    rgb = hex_rgb(value, fallback)
    return tuple(int(rgb[i : i + 2], 16) for i in (0, 2, 4))


def clamp_channel(value: float) -> int:
    return max(0, min(255, int(round(value))))


def blend(rgb_a: tuple[int, int, int], rgb_b: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return tuple(
        clamp_channel(a + (b - a) * amount)
        for a, b in zip(rgb_a, rgb_b)
    )


def rgba_css(value: str | None, alpha: float, fallback: str) -> str:
    r, g, b = rgb_tuple(value, fallback)
    return f"rgba({r}, {g}, {b}, {alpha:.2f})"


def hex_css(value: str | None, fallback: str) -> str:
    return f"#{hex_rgb(value, fallback)}"


def hex_with_alpha(value: str | None, alpha: str, fallback: str) -> str:
    return f"#{hex_rgba(value, alpha=alpha, fallback=fallback)}"


def rgb_css(value: str | None, fallback: str) -> str:
    r, g, b = rgb_tuple(value, fallback)
    return f"rgb({r}, {g}, {b})"


def rgb_csv(value: str | None, fallback: str) -> str:
    r, g, b = rgb_tuple(value, fallback)
    return f"{r},{g},{b}"


def hex_from_rgb(rgb: tuple[int, int, int]) -> str:
    return f"#{rgb[0]:02x}{rgb[1]:02x}{rgb[2]:02x}"


def relative_luminance(rgb: tuple[int, int, int]) -> float:
    def channel(value: int) -> float:
        linear = value / 255
        return linear / 12.92 if linear <= 0.04045 else ((linear + 0.055) / 1.055) ** 2.4

    r, g, b = (channel(value) for value in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def palette_is_light(colours: dict[str, str]) -> bool:
    return relative_luminance(rgb_tuple(colours.get("surface") or colours.get("background"), "151409")) > 0.48


def argb_from_rgb(alpha: int, rgb: tuple[int, int, int]) -> int:
    return (alpha << 24) | (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]


def sgr_truecolor(value: str | None, fallback: str) -> str:
    r, g, b = rgb_tuple(value, fallback)
    return f"38;2;{r};{g};{b}"


def mixed_rgb_css(value: str | None, fallback: str, mix_with: str, amount: float) -> str:
    base = rgb_tuple(value, fallback)
    other = rgb_tuple(mix_with, mix_with)
    mixed = blend(base, other, amount)
    return f"rgb({mixed[0]}, {mixed[1]}, {mixed[2]})"


def write_file(path: Path, content: str) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        try:
            if path.read_text(encoding="utf-8") == content:
                return False
        except OSError:
            pass

    tmp = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    tmp.write_text(content, encoding="utf-8")
    tmp.replace(path)
    return True


def content_version(content: str) -> str:
    return hashlib.sha256(content.encode("utf-8")).hexdigest()[:12]


def run_quiet(args: list[str], timeout: float | None = None) -> None:
    try:
        subprocess.run(
            args,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
            timeout=timeout,
        )
    except (OSError, subprocess.TimeoutExpired):
        pass


def set_ini_value(path: Path, key: str, value: str, section: str = "Settings") -> bool:
    if not path.exists():
        return False

    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()
    in_section = False
    section_seen = False
    changed = False
    insert_at = len(lines)

    for index, line in enumerate(lines):
        stripped = line.strip()
        if stripped == f"[{section}]":
            in_section = True
            section_seen = True
            insert_at = index + 1
            continue

        if stripped.startswith("[") and stripped.endswith("]"):
            if in_section:
                insert_at = index
            in_section = False

        if in_section and re.match(rf"^\s*{re.escape(key)}\s*=", line):
            updated = f"{key}={value}"
            if line != updated:
                lines[index] = updated
                changed = True
            return write_file(path, "\n".join(lines) + "\n") if changed else False

    if not section_seen:
        lines.extend([f"[{section}]", f"{key}={value}"])
    else:
        lines.insert(insert_at, f"{key}={value}")

    return write_file(path, "\n".join(lines) + "\n")


def new_config() -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    return parser


def ensure_import_line(path: Path, line: str) -> None:
    if not path.exists():
        return

    text = path.read_text(encoding="utf-8")
    stripped = line.strip()
    if any(existing.strip() == stripped for existing in text.splitlines()):
        return

    write_file(path, f"{line}\n{text}")


def ensure_line_after(path: Path, anchor: str, line: str) -> None:
    if not path.exists():
        return

    text = path.read_text(encoding="utf-8")
    stripped = line.strip()
    if any(existing.strip() == stripped for existing in text.splitlines()):
        return

    if anchor in text:
        updated = text.replace(anchor, f"{anchor}\n{line}", 1)
    elif "\n:root" in text:
        updated = text.replace("\n:root", f"\n{line}\n\n:root", 1)
    else:
        updated = f"{line}\n{text}"

    write_file(path, updated)


def ensure_steam_dynamic_import(version: str) -> bool:
    if not STEAM_LIBRARYROOT_CUSTOM_CSS_PATH.exists():
        return False

    text = STEAM_LIBRARYROOT_CUSTOM_CSS_PATH.read_text(encoding="utf-8")
    dynamic_import = f'@import url("https://steamloopback.host/caelestia-dynamic.css?v={version}");'
    cleaned = re.sub(STEAM_DYNAMIC_IMPORT_RE, "", text)
    anchor = '@import url("https://steamloopback.host/adwaita/custom/custom.css");'

    if anchor in cleaned:
        updated = cleaned.replace(anchor, f"{anchor}\n{dynamic_import}", 1)
    elif "\n:root" in cleaned:
        updated = cleaned.replace("\n:root", f"\n{dynamic_import}\n\n:root", 1)
    else:
        updated = f"{dynamic_import}\n{cleaned}"

    if updated == text:
        return False

    return write_file(STEAM_LIBRARYROOT_CUSTOM_CSS_PATH, updated)


def steam_library_css_is_patched() -> bool:
    if not STEAM_LIBRARY_CSS_PATH.exists():
        return False

    try:
        with STEAM_LIBRARY_CSS_PATH.open(encoding="utf-8", errors="ignore") as file:
            return file.readline().strip() == STEAM_PATCHED_HEADER
    except OSError:
        return False


def ensure_steam_theme_patch() -> None:
    if steam_library_css_is_patched() or not STEAM_RICE_SCRIPT_PATH.exists():
        return

    run_quiet([str(STEAM_RICE_SCRIPT_PATH)], timeout=30)


def ensure_discord_theme_targets() -> None:
    template = next((path for path in DISCORD_THEME_PATHS if path.exists()), None)
    if template is None:
        return

    try:
        content = template.read_text(encoding="utf-8")
    except OSError:
        return

    for path in DISCORD_THEME_PATHS:
        if path.exists():
            continue
        write_file(path, content)


def first_existing_paths(root: Path, pattern: str) -> list[Path]:
    if not root.exists():
        return []
    return sorted(path for path in root.glob(pattern) if path.is_file())


def theme_exists(name: str) -> bool:
    if not name:
        return False

    roots = (
        HOME / ".themes" / name,
        HOME / ".local/share/themes" / name,
        Path("/usr/share/themes") / name,
    )
    return any(root.exists() for root in roots)


def pick_theme_toggle(current: str | None) -> tuple[str, str] | None:
    if not current:
        return None

    current = current.strip()
    if not current:
        return None

    candidates: list[str]
    if current.endswith("-dark"):
        candidates = [current[:-5], "adw-gtk3", "Adwaita"]
    else:
        candidates = [f"{current}-dark", "adw-gtk3-dark", "Adwaita-dark"]

    for candidate in candidates:
        if candidate and candidate != current and theme_exists(candidate):
            return current, candidate

    return None


def read_command_text(args: list[str]) -> str | None:
    result = subprocess.run(
        args,
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    return result.stdout.strip()


def gsettings_key_exists(schema: str, key: str) -> bool:
    result = subprocess.run(
        ["gsettings", "list-keys", schema],
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode == 0 and key in result.stdout.splitlines()


def bounce_gsettings_value(schema: str, key: str, alternate: str) -> None:
    current = read_command_text(["gsettings", "get", schema, key])
    if not current:
        return

    current = current.strip()
    if current == alternate:
        return

    run_quiet(["gsettings", "set", schema, key, alternate])
    time.sleep(0.08)
    run_quiet(["gsettings", "set", schema, key, current])


def refresh_gtk_theme() -> None:
    if shutil.which("xfconf-query"):
        current = read_command_text(["xfconf-query", "-c", "xsettings", "-p", "/Net/ThemeName"])
        toggle = pick_theme_toggle(current)
        if toggle:
            original, alternate = toggle
            for prop in ("/Net/ThemeName", "/Gtk/ThemeName"):
                subprocess.run(
                    ["xfconf-query", "-c", "xsettings", "-p", prop, "-s", alternate],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )
            time.sleep(0.12)
            for prop in ("/Net/ThemeName", "/Gtk/ThemeName"):
                subprocess.run(
                    ["xfconf-query", "-c", "xsettings", "-p", prop, "-s", original],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )

    if shutil.which("gsettings"):
        current = read_command_text(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"])
        if current:
            current = current.strip().strip("'")
        toggle = pick_theme_toggle(current)
        if toggle:
            original, alternate = toggle
            subprocess.run(
                ["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", alternate],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )
            time.sleep(0.12)
            subprocess.run(
                ["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", original],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )

        schema = "org.gnome.desktop.interface"
        if gsettings_key_exists(schema, "color-scheme"):
            current_scheme = read_command_text(["gsettings", "get", schema, "color-scheme"])
            alternate_scheme = "'default'" if current_scheme == "'prefer-dark'" else "'prefer-dark'"
            bounce_gsettings_value(schema, "color-scheme", alternate_scheme)
        if gsettings_key_exists(schema, "gtk-application-prefer-dark-theme"):
            current_dark = read_command_text(["gsettings", "get", schema, "gtk-application-prefer-dark-theme"])
            alternate_dark = "false" if current_dark == "true" else "true"
            bounce_gsettings_value(schema, "gtk-application-prefer-dark-theme", alternate_dark)


def apply_palette_light_dark(colours: dict[str, str]) -> None:
    if not shutil.which("gsettings"):
        return

    schema = "org.gnome.desktop.interface"
    light = palette_is_light(colours)
    if gsettings_key_exists(schema, "color-scheme"):
        run_quiet(["gsettings", "set", schema, "color-scheme", "default" if light else "prefer-dark"])
    if gsettings_key_exists(schema, "gtk-application-prefer-dark-theme"):
        run_quiet(["gsettings", "set", schema, "gtk-application-prefer-dark-theme", "false" if light else "true"])


def build_cursor_palette(colours: dict[str, str]) -> tuple[tuple[int, int, int], tuple[int, int, int], tuple[int, int, int]]:
    accent = rgb_tuple(colours.get("primary") or colours.get("surfaceTint"), "f7b6ba")
    secondary = rgb_tuple(colours.get("secondary") or colours.get("tertiary"), "77d5e0")
    dark = blend(accent, (0, 0, 0), 0.24)
    light = blend(accent, (255, 255, 255), 0.56)
    glow = blend(secondary, light, 0.28)
    return dark, accent, glow


def cursor_state_for_colours(colours: dict[str, str]) -> str:
    accent = hex_rgb(colours.get("primary") or colours.get("surfaceTint"), "f7b6ba")
    secondary = hex_rgb(colours.get("secondary") or colours.get("tertiary"), "77d5e0")
    tertiary = hex_rgb(colours.get("tertiary") or colours.get("inversePrimary"), "e1bbdd")
    background = hex_rgb(colours.get("background") or colours.get("surface"), "130c0d")
    foreground = hex_rgb(colours.get("onBackground") or colours.get("onSurface"), "f8e0e0")
    return f"v5-vivid:{accent}:{secondary}:{tertiary}:{background}:{foreground}:{CURSOR_SIZE}"


def cursor_cache_dir(state: str) -> Path:
    return CURSOR_CACHE_PATH / hashlib.sha256(state.encode("utf-8")).hexdigest()[:24]


def cursor_cache_ready(state: str) -> bool:
    cache = cursor_cache_dir(state)
    return (cache / "nier" / "Cursor").exists() and (cache / "state.txt").exists()


def tint_cursor_pixel(pixel: int, palette: tuple[tuple[int, int, int], tuple[int, int, int], tuple[int, int, int]]) -> int:
    alpha = (pixel >> 24) & 0xff
    if alpha == 0:
        return pixel

    r = (pixel >> 16) & 0xff
    g = (pixel >> 8) & 0xff
    b = pixel & 0xff
    luminance = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255
    dark, accent, light = palette

    if luminance < 0.46:
        rgb = blend(dark, accent, luminance / 0.46)
    else:
        rgb = blend(accent, light, (luminance - 0.46) / 0.54)

    boosted_alpha = max(alpha, min(255, int(round(alpha * 1.2 + 24))))
    return argb_from_rgb(boosted_alpha, rgb)


def tint_xcursor_file(source: Path, destination: Path, palette: tuple[tuple[int, int, int], tuple[int, int, int], tuple[int, int, int]]) -> bool:
    try:
        data = bytearray(source.read_bytes())
        magic, header_size, _version, toc_count = struct.unpack_from("<4I", data, 0)
    except (OSError, struct.error):
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        return True

    if magic != 0x72756358 or header_size < 16:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        return True

    changed = False
    for index in range(toc_count):
        try:
            chunk_type, _chunk_subtype, chunk_pos = struct.unpack_from("<3I", data, header_size + index * 12)
        except struct.error:
            continue

        if chunk_type != 0xfffd0002:
            continue

        try:
            _chunk_size, _image_type, _image_subtype, _image_version, width, height, _xhot, _yhot, _delay = struct.unpack_from("<9I", data, chunk_pos)
        except struct.error:
            continue

        pixel_offset = chunk_pos + 36
        pixel_count = width * height
        for pixel_index in range(pixel_count):
            offset = pixel_offset + pixel_index * 4
            try:
                pixel = struct.unpack_from("<I", data, offset)[0]
            except struct.error:
                break

            tinted = tint_cursor_pixel(pixel, palette)
            if tinted != pixel:
                struct.pack_into("<I", data, offset, tinted)
                changed = True

    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists() or destination.read_bytes() != data:
        destination.write_bytes(data)
        return True

    return changed


def sync_cursor_symlinks() -> None:
    source_cursors = CURSOR_SOURCE_PATH / "cursors"
    dest_cursors = CURSOR_THEME_PATH / "cursors"
    if not source_cursors.exists():
        return

    dest_cursors.mkdir(parents=True, exist_ok=True)
    for source in source_cursors.iterdir():
        dest = dest_cursors / source.name
        if source.is_symlink():
            target = source.readlink()
            if dest.is_symlink() and dest.readlink() == target:
                continue
            if dest.exists() or dest.is_symlink():
                dest.unlink()
            dest.symlink_to(target)
        elif source.is_file():
            shutil.copy2(source, dest)


def set_cursor_config_values() -> None:
    if CURSOR_THEME_PATH.is_symlink():
        CURSOR_THEME_PATH.unlink()

    CURSOR_THEME_PATH.mkdir(parents=True, exist_ok=True)
    write_file(
        CURSOR_THEME_PATH / "index.theme",
        (
            "[Icon Theme]\n"
            "Name=Nier Cursors\n"
            "Comment=Wallpaper-synced cursor generated by system-theme-sync.py\n"
            f"Inherits={CURSOR_RELOAD_THEME_NAME}\n"
        ),
    )
    sync_cursor_theme_alias()
    sync_legacy_cursor_theme_aliases()

    for settings_path in (GTK3_SETTINGS_PATH, GTK4_SETTINGS_PATH):
        set_ini_value(settings_path, "gtk-cursor-theme-name", CURSOR_THEME_NAME)
        set_ini_value(settings_path, "gtk-cursor-theme-size", str(CURSOR_SIZE))

    write_file(
        CURSOR_DEFAULT_INDEX_PATH,
        (
            "[Icon Theme]\n"
            "Name=Default\n"
            "Comment=Default Cursor Theme\n"
            f"Inherits={CURSOR_THEME_NAME}\n"
        ),
    )


def sync_cursor_theme_alias() -> None:
    if CURSOR_THEME_ALIAS_PATH == CURSOR_THEME_PATH:
        return

    CURSOR_THEME_ALIAS_PATH.parent.mkdir(parents=True, exist_ok=True)
    if CURSOR_THEME_ALIAS_PATH.is_symlink() and CURSOR_THEME_ALIAS_PATH.readlink() == CURSOR_THEME_PATH:
        return

    if CURSOR_THEME_ALIAS_PATH.exists() or CURSOR_THEME_ALIAS_PATH.is_symlink():
        if CURSOR_THEME_ALIAS_PATH.is_dir() and not CURSOR_THEME_ALIAS_PATH.is_symlink():
            index_path = CURSOR_THEME_ALIAS_PATH / "index.theme"
            try:
                generated = "system-theme-sync.py" in index_path.read_text(encoding="utf-8")
            except OSError:
                generated = False
            if not generated:
                return
            shutil.rmtree(CURSOR_THEME_ALIAS_PATH)
        else:
            CURSOR_THEME_ALIAS_PATH.unlink()

    CURSOR_THEME_ALIAS_PATH.symlink_to(CURSOR_THEME_PATH)


def replace_generated_cursor_theme_with_symlink(path: Path, target: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.is_symlink() and path.readlink() == target:
        return

    if path.exists() or path.is_symlink():
        if path.is_dir() and not path.is_symlink():
            index_path = path / "index.theme"
            try:
                generated = "system-theme-sync.py" in index_path.read_text(encoding="utf-8")
            except OSError:
                generated = False
            if not generated:
                return
            shutil.rmtree(path)
        else:
            path.unlink()

    path.symlink_to(target)


def sync_legacy_cursor_theme_aliases() -> None:
    for path in CURSOR_LEGACY_THEME_PATHS:
        replace_generated_cursor_theme_with_symlink(path, CURSOR_THEME_PATH)


def replace_path_with_symlink(path: Path, target: Path) -> None:
    if path.is_symlink() and path.readlink() == target:
        return

    tmp = path.with_name(f".{path.name}.tmp")
    if tmp.exists() or tmp.is_symlink():
        if tmp.is_dir() and not tmp.is_symlink():
            shutil.rmtree(tmp)
        else:
            tmp.unlink()

    tmp.symlink_to(target)
    if path.exists() or path.is_symlink():
        if path.is_dir() and not path.is_symlink():
            shutil.rmtree(path)
        else:
            path.unlink()
    tmp.rename(path)


def activate_cached_cursor(state: str, apply_live: bool = True) -> bool:
    if not cursor_cache_ready(state):
        return False

    set_cursor_config_values()
    replace_path_with_symlink(CURSOR_THEME_PATH / "nier", cursor_cache_dir(state) / "nier")
    sync_cursor_symlinks()
    write_file(CURSOR_STATE_PATH, state + "\n")
    if apply_live:
        apply_cursor_theme_live()
    return True


def apply_cursor_theme_live() -> None:
    # Hyprland caches same-name cursor themes, so bounce once to force reload.
    run_quiet(["hyprctl", "setcursor", CURSOR_RELOAD_THEME_NAME, str(CURSOR_SIZE)], timeout=0.5)
    run_quiet(["hyprctl", "setcursor", CURSOR_THEME_NAME, str(CURSOR_SIZE)], timeout=0.5)

    # Keep GTK / apps / env synced after, without blocking the visible Hyprland cursor switch.
    try:
        subprocess.Popen(
            [
                "sh",
                "-lc",
                (
                    "gsettings set org.gnome.desktop.interface cursor-theme '{reload_theme}'; "
                    "sleep 0.08; "
                    "gsettings set org.gnome.desktop.interface cursor-theme '{theme}'; "
                    "gsettings set org.gnome.desktop.interface cursor-size {size}; "
                    "systemctl --user set-environment "
                    "XCURSOR_THEME={theme} XCURSOR_SIZE={size} "
                    "XCURSOR_PATH='{xcursor_path}'; "
                    "systemctl --user unset-environment HYPRCURSOR_THEME HYPRCURSOR_SIZE; "
                    "dbus-update-activation-environment --systemd "
                    "XCURSOR_THEME={theme} XCURSOR_SIZE={size} "
                    "XCURSOR_PATH='{xcursor_path}'"
                ).format(
                    theme=CURSOR_THEME_NAME,
                    reload_theme=CURSOR_RELOAD_THEME_NAME,
                    size=CURSOR_SIZE,
                    xcursor_path=XCURSOR_PATH_VALUE,
                ),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        pass


def generate_cursor_cache(state: str, colours: dict[str, str]) -> None:
    source_nier = CURSOR_SOURCE_PATH / "nier"
    if not source_nier.exists() or cursor_cache_ready(state):
        return

    cache = cursor_cache_dir(state)
    tmp = cache.with_name(f".{cache.name}.tmp")
    if tmp.exists() or tmp.is_symlink():
        if tmp.is_dir() and not tmp.is_symlink():
            shutil.rmtree(tmp)
        else:
            tmp.unlink()

    dest_nier = tmp / "nier"
    dest_nier.mkdir(parents=True, exist_ok=True)
    palette = build_cursor_palette(colours)
    for source in sorted(source_nier.iterdir()):
        if not source.is_file():
            continue

        destination = dest_nier / source.name
        # The animated wait/error cursors are enormous and were the reason
        # cursor colour changes felt like the whole desktop stalled. Keep
        # those inherited and recolour the small cursor files users actually
        # see constantly: pointer, hand, resize, crosshair, etc.
        if source.stat().st_size > 1024 * 1024:
            destination.symlink_to(source)
        else:
            tint_xcursor_file(source, destination, palette)

    write_file(tmp / "state.txt", state + "\n")
    cache.parent.mkdir(parents=True, exist_ok=True)
    if cache.exists() or cache.is_symlink():
        if cache.is_dir() and not cache.is_symlink():
            shutil.rmtree(cache)
        else:
            cache.unlink()
    tmp.rename(cache)


def request_cursor_worker(state: str, colours: dict[str, str]) -> None:
    write_file(
        CURSOR_PENDING_PATH,
        json.dumps({"state": state, "colours": colours}, sort_keys=True) + "\n",
    )
    try:
        subprocess.Popen(
            [sys.executable, str(Path(__file__).resolve()), "--cursor-only"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        pass


def render_cursor_theme(colours: dict[str, str]) -> None:
    if not (CURSOR_SOURCE_PATH / "nier").exists():
        return

    state = cursor_state_for_colours(colours)
    previous_state = CURSOR_STATE_PATH.read_text(encoding="utf-8").strip() if CURSOR_STATE_PATH.exists() else ""
    current_ready = (CURSOR_THEME_PATH / "nier" / "Cursor").exists() and (CURSOR_THEME_PATH / "cursors" / "left_ptr").exists()

    set_cursor_config_values()
    if cursor_cache_ready(state):
        activate_cached_cursor(state, apply_live=previous_state != state or not current_ready)
    elif previous_state != state or not current_ready:
        request_cursor_worker(state, colours)


def read_pending_cursor_request() -> tuple[str, dict[str, str]] | None:
    try:
        data = json.loads(CURSOR_PENDING_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None

    state = data.get("state")
    colours = data.get("colours")
    if isinstance(state, str) and isinstance(colours, dict):
        return state, colours
    return None


def run_cursor_worker() -> int:
    CURSOR_LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    with CURSOR_LOCK_PATH.open("w") as lock_file:
        try:
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return 0

        last_state = ""
        while True:
            request = read_pending_cursor_request()
            if request is None:
                return 0

            state, colours = request
            if state == last_state:
                return 0

            # Build missing cursor cache, then activate it.
            # If this is slow, the delay is generation, not hyprctl.
            generate_cursor_cache(state, colours)
            if cursor_cache_ready(state):
                activate_cached_cursor(state)
            last_state = state

            latest = read_pending_cursor_request()
            if latest is None or latest[0] == state:
                return 0


def load_scheme() -> dict | None:
    try:
        return json.loads(SCHEME_PATH.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return None


def build_border_values(colours: dict[str, str]) -> tuple[str, str]:
    active_seed = colours.get("primary") or colours.get("surfaceTint")
    active_primary = hex_rgba(active_seed, fallback="ffffff")
    active_secondary = hex_rgba(colours.get("secondary") or colours.get("secondaryFixedDim"), fallback="d3c876")
    active_tertiary = hex_rgba(colours.get("tertiary") or colours.get("primaryFixedDim"), fallback="ffd27a")
    active_shadow = hex_rgba(
        hex_from_rgb(blend(rgb_tuple(active_seed, "ffffff"), rgb_tuple(colours.get("surface") or colours.get("background"), "101614"), 0.7)),
        fallback="223b36",
    )
    inactive = hex_rgba(colours.get("outlineVariant") or colours.get("outline"), alpha="aa", fallback="595959")
    active_value = f"rgba({active_primary}) rgba({active_shadow}) rgba({active_secondary}) rgba({active_tertiary}) 45deg"
    inactive_value = f"rgba({inactive})"
    return active_value, inactive_value


def render_hyprland(colours: dict[str, str]) -> None:
    active_value, inactive_value = build_border_values(colours)
    shadow_active = f"rgba({hex_rgba(colours.get('secondaryContainer') or colours.get('primaryContainer') or colours.get('secondary'), alpha='96', fallback='3f3a1e')})"
    shadow_inactive = f"rgba({hex_rgba(colours.get('surfaceContainerHigh') or colours.get('surfaceContainer') or colours.get('outlineVariant'), alpha='78', fallback='222014')})"
    write_file(
        HYPR_BORDER_PATH,
        (
            "# Generated by ~/scripts/system-theme-sync.py\n"
            "general {\n"
            f"    col.active_border = {active_value}\n"
            f"    col.inactive_border = {inactive_value}\n"
            f"    col.nogroup_border = {inactive_value}\n"
            f"    col.nogroup_border_active = {active_value}\n"
            "}\n"
            "decoration {\n"
            "    shadow {\n"
            f"        color = {shadow_active}\n"
            f"        color_inactive = {shadow_inactive}\n"
            "    }\n"
            "}\n"
            "group {\n"
            f"    col.border_active = {active_value}\n"
            f"    col.border_inactive = {inactive_value}\n"
            f"    col.border_locked_active = {active_value}\n"
            f"    col.border_locked_inactive = {inactive_value}\n"
            "}\n"
        ),
    )
    live_keywords = {
        "general:col.active_border": active_value,
        "general:col.inactive_border": inactive_value,
        "general:col.nogroup_border": inactive_value,
        "general:col.nogroup_border_active": active_value,
        "decoration:shadow:color": shadow_active,
        "decoration:shadow:color_inactive": shadow_inactive,
        "group:col.border_active": active_value,
        "group:col.border_inactive": inactive_value,
        "group:col.border_locked_active": active_value,
        "group:col.border_locked_inactive": inactive_value,
    }
    for keyword, value in live_keywords.items():
        subprocess.run(
            ["hyprctl", "keyword", keyword, value],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )


def render_hyprlock(colours: dict[str, str]) -> None:
    if not HYPRLOCK_CONFIG_PATH.exists():
        return

    values = {
        "hl_clock_text": rgba_css(colours.get("onSurface") or colours.get("onBackground"), 0.98, "f2f6fc"),
        "hl_date_text": rgba_css(colours.get("onSurfaceVariant") or colours.get("outline"), 0.82, "bcc9dc"),
        "hl_divider": rgba_css(colours.get("primary") or colours.get("secondary"), 0.56, "94cdff"),
        "hl_avatar_bg": rgba_css(colours.get("surfaceContainerLow") or colours.get("surface"), 0.16, "0e121a"),
        "hl_avatar_ring": rgba_css(colours.get("outlineVariant") or colours.get("outline"), 0.28, "ccdcf5"),
        "hl_avatar_shadow": rgba_css(colours.get("scrim") or colours.get("shadow"), 0.12, "000000"),
        "hl_avatar_border": rgba_css(colours.get("primaryFixed") or colours.get("onSurface"), 0.30, "e4eefc"),
        "hl_user_text": rgba_css(colours.get("onSurface") or colours.get("onBackground"), 0.92, "e0e8f4"),
        "hl_input_text": rgba_css(colours.get("onSurface") or colours.get("onBackground"), 1.0, "f4f7fc"),
        "hl_input_inner": rgba_css(colours.get("surfaceContainerLowest") or colours.get("surface"), 0.22, "0c1018"),
        "hl_input_outer": rgba_css(colours.get("outline") or colours.get("secondary"), 0.30, "aebfd9"),
        "hl_input_check": rgba_css(colours.get("primary") or colours.get("secondary"), 0.96, "84bfff"),
        "hl_input_fail": rgba_css(colours.get("error"), 0.96, "ff8694"),
        "hl_input_caps": rgba_css(colours.get("tertiary"), 0.96, "ffab7f"),
        "hl_input_num": rgba_css(colours.get("success") or colours.get("green"), 0.96, "7ad5bf"),
        "hl_hint_text": rgba_css(colours.get("outline"), 0.74, "aebacb"),
        "hl_panel_bg": rgba_css(colours.get("surfaceContainerLowest") or colours.get("surface"), 0.12, "0b0f16"),
        "hl_panel_border": rgba_css(colours.get("outlineVariant") or colours.get("outline"), 0.22, "ccdcf5"),
        "hl_panel_shadow": rgba_css(colours.get("scrim") or colours.get("shadow"), 0.10, "000000"),
        "hl_chip_bg": rgba_css(colours.get("surfaceContainerHigh") or colours.get("surfaceContainer"), 0.34, "0e131b"),
        "hl_chip_border": rgba_css(colours.get("secondary") or colours.get("primary"), 0.28, "9aceff"),
        "hl_chip_text": rgba_css(colours.get("secondary") or colours.get("primary"), 1.0, "b0dcff"),
        "hl_panel_text": rgba_css(colours.get("onSurface") or colours.get("onBackground"), 0.98, "f1f5fb"),
    }

    block = (
        "# Generated by ~/scripts/system-theme-sync.py\n"
        f"{HYPRLOCK_MARKER_BEGIN}\n"
        + "".join(f"${name} = {value}\n" for name, value in values.items())
        + f"{HYPRLOCK_MARKER_END}\n"
    )

    text = HYPRLOCK_CONFIG_PATH.read_text(encoding="utf-8")
    pattern = (
        r"# Generated by ~/scripts/system-theme-sync.py\n"
        + re.escape(HYPRLOCK_MARKER_BEGIN)
        + r".*?"
        + re.escape(HYPRLOCK_MARKER_END)
        + r"\n?"
    )

    if re.search(pattern, text, flags=re.S):
        updated = re.sub(pattern, block, text, count=1, flags=re.S)
    else:
        anchor = "$font_mono = CaskaydiaCove NF\n"
        if anchor in text:
            updated = text.replace(anchor, anchor + "\n" + block, 1)
        else:
            updated = block + "\n" + text

    if updated != text:
        write_file(HYPRLOCK_CONFIG_PATH, updated)


def render_gtk(colours: dict[str, str]) -> None:
    accent = hex_css(colours.get("secondary") or colours.get("primary"), "d3c876")
    accent_fg = hex_css(colours.get("onSecondary") or colours.get("onPrimary"), "1d1b14")
    window_bg = hex_css(colours.get("surface") or colours.get("background"), "151409")
    window_fg = hex_css(colours.get("onSurface") or colours.get("onBackground"), "e8e2cf")
    card_bg = hex_css(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), "222014")
    card_fg = window_fg
    selected_bg = rgba_css(colours.get("secondary") or colours.get("primary"), 0.18, "d3c876")
    selected_fg = window_fg
    button_base_rgb = rgb_tuple(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), "222014")
    accent_rgb = rgb_tuple(colours.get("secondary") or colours.get("primary"), "d3c876")
    button_bg = hex_from_rgb(blend(button_base_rgb, accent_rgb, 0.24))
    button_hover = hex_from_rgb(blend(button_base_rgb, accent_rgb, 0.36))
    button_active = accent
    button_border = rgba_css(colours.get("secondary") or colours.get("primary"), 0.32, "d3c876")
    button_shadow = rgba_css(colours.get("scrim") or colours.get("shadow"), 0.16, "000000")
    destructive = hex_css(colours.get("error"), "ffb4ab")
    destructive_fg = hex_css(colours.get("onError") or colours.get("onPrimary"), "690005")

    css = (
        "/* Generated by ~/scripts/system-theme-sync.py */\n"
        f"@define-color accent_color {accent};\n"
        f"@define-color accent_fg_color {accent_fg};\n"
        f"@define-color accent_bg_color {accent};\n"
        f"@define-color window_bg_color {window_bg};\n"
        f"@define-color window_fg_color {window_fg};\n"
        f"@define-color headerbar_bg_color {window_bg};\n"
        f"@define-color headerbar_fg_color {window_fg};\n"
        f"@define-color popover_bg_color {card_bg};\n"
        f"@define-color popover_fg_color {window_fg};\n"
        f"@define-color view_bg_color {window_bg};\n"
        f"@define-color view_fg_color {window_fg};\n"
        f"@define-color card_bg_color {card_bg};\n"
        f"@define-color card_fg_color {card_fg};\n"
        "@define-color sidebar_bg_color @window_bg_color;\n"
        "@define-color sidebar_fg_color @window_fg_color;\n"
        "@define-color sidebar_border_color @window_bg_color;\n"
        "@define-color sidebar_backdrop_color @window_bg_color;\n"
        f"@define-color theme_selected_bg_color {selected_bg};\n"
        f"@define-color theme_selected_fg_color {selected_fg};\n"
        f"@define-color theme_button_bg_color {button_bg};\n"
        f"@define-color theme_button_fg_color {window_fg};\n"
        f"@define-color theme_button_hover_bg_color {button_hover};\n"
        f"@define-color theme_button_active_bg_color {button_active};\n"
        f"@define-color theme_button_active_fg_color {accent_fg};\n"
        f"@define-color theme_button_border_color {button_border};\n"
        "\n"
        "button {\n"
        f"    color: {window_fg};\n"
        f"    background: {button_bg};\n"
        "    background-image: none;\n"
        f"    border-color: {button_border};\n"
        f"    box-shadow: 0 1px 2px {button_shadow};\n"
        "}\n\n"
        "button:hover {\n"
        f"    color: {window_fg};\n"
        f"    background: {button_hover};\n"
        "    background-image: none;\n"
        f"    border-color: {button_border};\n"
        "}\n\n"
        "button:active,\n"
        "button:checked,\n"
        "button.toggle:checked,\n"
        "button.suggested-action,\n"
        "button.default {\n"
        f"    color: {accent_fg};\n"
        f"    background: {button_active};\n"
        "    background-image: none;\n"
        f"    border-color: {button_active};\n"
        "}\n\n"
        "button:active:hover,\n"
        "button:checked:hover,\n"
        "button.toggle:checked:hover,\n"
        "button.suggested-action:hover,\n"
        "button.default:hover {\n"
        f"    color: {accent_fg};\n"
        f"    background: {button_active};\n"
        "    background-image: none;\n"
        f"    border-color: {button_active};\n"
        "}\n\n"
        "button.flat:not(:hover):not(:active):not(:checked) {\n"
        "    background: transparent;\n"
        "    background-image: none;\n"
        "    border-color: transparent;\n"
        "    box-shadow: none;\n"
        "}\n\n"
        "button.destructive-action {\n"
        f"    color: {destructive_fg};\n"
        f"    background: {destructive};\n"
        "    background-image: none;\n"
        f"    border-color: {destructive};\n"
        "}\n"
    )
    changed = write_file(GTK3_DYNAMIC_PATH, css)
    changed = write_file(GTK4_DYNAMIC_PATH, css) or changed
    gtk_css = css + '\n@import "thunar.css";\n'
    changed = write_file(GTK3_CSS_PATH, gtk_css) or changed
    changed = write_file(GTK4_CSS_PATH, gtk_css) or changed
    changed = render_thunar(colours) or changed
    apply_palette_light_dark(colours)
    if changed:
        refresh_gtk_theme()


def render_thunar(colours: dict[str, str]) -> bool:
    window_bg = hex_css(colours.get("surface") or colours.get("background"), "121415")
    window_fg = hex_css(colours.get("onSurface") or colours.get("onBackground"), "e2e2e5")
    panel_bg = hex_css(colours.get("surfaceContainerLow") or colours.get("surfaceContainer"), "1a1c1e")
    panel_strong = hex_css(colours.get("surfaceContainer") or colours.get("surfaceContainerHigh"), "1e2022")
    accent = hex_css(colours.get("secondary") or colours.get("primary"), "bac8d6")
    accent_soft = rgba_css(colours.get("secondary") or colours.get("primary"), 0.15, "bac8d6")
    accent_hover = rgba_css(colours.get("secondary") or colours.get("primary"), 0.08, "bac8d6")
    hover = rgba_css(colours.get("onSurface") or colours.get("onBackground"), 0.10, "e2e2e5")

    css = (
        "/* Generated by ~/scripts/system-theme-sync.py */\n"
        ".thunar * {\n"
        "    outline: none;\n"
        "    border: none;\n"
        "}\n\n"
        ".thunar.background {\n"
        f"    background: {window_bg};\n"
        f"    color: {window_fg};\n"
        "}\n\n"
        ".thunar .titlebar {\n"
        "    background: inherit;\n"
        "    color: inherit;\n"
        "    padding: 15px 0 5px 0;\n"
        "}\n\n"
        ".thunar .titlebutton.close {\n"
        "    margin: 0 15px 0 0;\n"
        "}\n\n"
        ".thunar paned > separator {\n"
        "    min-width: 4px;\n"
        "    margin-right: -7px;\n"
        "    margin-left: -7px;\n"
        "    background: none;\n"
        "    background-image: none;\n"
        "    box-shadow: none;\n"
        "}\n\n"
        ".thunar .frame.standard-view {\n"
        "    padding: 10px;\n"
        "    margin: 10px 15px 0 0;\n"
        "    border-radius: 15px;\n"
        f"    background-color: {panel_bg};\n"
        "    animation: fading 400ms ease forwards;\n"
        "    opacity: 0;\n"
        "    animation-delay: 250ms;\n"
        "}\n\n"
        ".thunar .frame.standard-view .view:not(.rubberband),\n"
        ".thunar .frame.standard-view .view *:not(.rubberband) {\n"
        "    background-color: transparent;\n"
        "}\n\n"
        ".thunar .frame.standard-view .view *:selected {\n"
        f"    color: {accent};\n"
        "}\n\n"
        ".thunar .rubberband {\n"
        f"    background-color: {accent_soft};\n"
        f"    border: 1px solid {accent_soft};\n"
        "}\n\n"
        ".thunar header.top {\n"
        "    background: none;\n"
        "    padding: 0 10px 0 0;\n"
        "    margin: 3px 0 -3px -2px;\n"
        "}\n\n"
        ".thunar header.top tabs .reorderable-page {\n"
        "    margin: 0;\n"
        "    transition: all ease 300ms;\n"
        "}\n\n"
        ".thunar header.top tabs .reorderable-page + .reorderable-page {\n"
        "    margin: 0 0 0 10px;\n"
        "}\n\n"
        ".thunar header.top tabs .reorderable-page:hover {\n"
        f"    background-color: {accent_hover};\n"
        "}\n\n"
        ".thunar header.top tabs .reorderable-page:checked {\n"
        f"    color: {accent};\n"
        f"    background-color: {accent_soft};\n"
        "}\n\n"
        ".thunar .sidebar {\n"
        "    padding: 0 20px;\n"
        "    background: none;\n"
        "    animation: fading 600ms ease forwards;\n"
        "    animation-delay: 100ms;\n"
        "    opacity: 0;\n"
        "}\n\n"
        ".thunar .sidebar .view {\n"
        "    padding: 8px 4px;\n"
        "    border-radius: 10px;\n"
        "    background: none;\n"
        "    transition: all ease 300ms;\n"
        "}\n\n"
        ".thunar .sidebar .view:hover {\n"
        f"    background: {hover};\n"
        "}\n\n"
        ".thunar .sidebar .view:selected {\n"
        f"    background: {accent_soft};\n"
        f"    color: {accent};\n"
        "}\n\n"
        ".thunar .path-bar-button {\n"
        "    margin: 0;\n"
        "    padding: 8px 5px;\n"
        "    transition: all ease 0.4s;\n"
        "}\n\n"
        ".thunar .location-button.toggle:checked,\n"
        ".thunar .path-bar-button.toggle:checked {\n"
        "    padding: 8px 25px;\n"
        f"    background: {accent_soft};\n"
        f"    color: {accent};\n"
        "    box-shadow: none;\n"
        "}\n\n"
        ".thunar .location-button.path-bar-button:not(:checked) {\n"
        f"    background-color: {panel_strong};\n"
        f"    color: {window_fg};\n"
        "}\n\n"
        ".thunar .location-button.path-bar-button:not(:checked):hover {\n"
        f"    background: {accent_hover};\n"
        f"    color: {accent};\n"
        "}\n\n"
        ".thunar .location-button.toggle + .location-button.toggle:checked {\n"
        "    margin-left: 0;\n"
        "    padding: 0 25px;\n"
        "}\n\n"
        ".thunar button.toggle:checked {\n"
        f"    color: {accent};\n"
        "}\n\n"
        ".thunar .image-button {\n"
        "    padding: 8px;\n"
        "    margin: 0 0 0 8px;\n"
        "    transition: all ease 0.4s;\n"
        "}\n\n"
        ".thunar statusbar {\n"
        f"    background-color: {panel_bg};\n"
        "    border-radius: 15px;\n"
        "    padding: 10px 10px;\n"
        "    margin: 15px 5px 15px -10px;\n"
        f"    color: {window_fg};\n"
        "}\n\n"
        ".thunar box.vertical .image {\n"
        "    margin: 15px;\n"
        "}\n\n"
        "@keyframes fading {\n"
        "    to {\n"
        "        opacity: 1;\n"
        "    }\n"
        "}\n"
    )

    changed = write_file(GTK3_THUNAR_PATH, css)
    changed = write_file(GTK4_THUNAR_PATH, css) or changed
    return changed


def render_rofi(colours: dict[str, str]) -> None:
    bg = rgba_css(colours.get("surfaceContainerLowest") or colours.get("surface"), 0.78, "000000")
    bg_alt = rgba_css(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), 0.90, "222014")
    fg = rgba_css(colours.get("onSurface") or colours.get("onBackground"), 0.95, "e8e2cf")
    accent = rgba_css(colours.get("secondary") or colours.get("primary"), 0.96, "d3c876")
    stroke = rgba_css(colours.get("outline") or colours.get("outlineVariant"), 0.18, "969178")
    accent_dim = rgba_css(colours.get("secondary") or colours.get("primary"), 0.16, "d3c876")
    accent_soft = rgba_css(colours.get("secondaryContainer") or colours.get("secondary"), 0.06, "3f3a1e")

    content = (
        "/* Generated by ~/scripts/system-theme-sync.py */\n"
        "* {\n"
        f"    bg: {bg};\n"
        f"    bg-alt: {bg_alt};\n"
        f"    fg: {fg};\n"
        f"    accent: {accent};\n"
        f"    accent-dim: {accent_dim};\n"
        f"    accent-soft: {accent_soft};\n"
        f"    stroke: {stroke};\n"
        "}\n"
    )
    write_file(ROFI_DYNAMIC_PATH, content)


def find_tmux_bin() -> str | None:
    bundled = HOME / ".local/bin/tmux"
    if bundled.exists():
        return str(bundled)
    return shutil.which("tmux")


def render_shell_theme(colours: dict[str, str]) -> None:
    prompt_primary = hex_css(colours.get("secondary") or colours.get("primary"), "d3c876")
    prompt_mid = hex_css(colours.get("primary") or colours.get("onSurface"), "ffffff")
    prompt_tail = hex_css(colours.get("tertiary") or colours.get("secondaryFixed"), "cbce78")
    prompt_arrow = hex_css(colours.get("onSurface") or colours.get("primaryFixed"), "e8e2cf")
    prompt_path = hex_css(colours.get("outline") or colours.get("outlineVariant"), "969178")
    prompt_time = hex_css(colours.get("outlineVariant") or colours.get("outline"), "4a4732")

    ls_colors = ":".join(
        [
            f"di={sgr_truecolor(colours.get('secondary') or colours.get('primary'), 'd3c876')}",
            f"ln={sgr_truecolor(colours.get('primary') or colours.get('secondary'), 'ffffff')}",
            f"so={sgr_truecolor(colours.get('tertiary') or colours.get('term6'), 'cbce78')}",
            f"pi={sgr_truecolor(colours.get('term3') or colours.get('tertiary'), 'ffe66f')}",
            f"ex={sgr_truecolor(colours.get('term2') or colours.get('secondaryFixed'), 'dbcf4d')}",
            f"bd={sgr_truecolor(colours.get('term4') or colours.get('primaryFixed'), 'a2b174')}",
            f"cd={sgr_truecolor(colours.get('term5') or colours.get('secondaryFixed'), 'd3a343')}",
            f"*.zip={sgr_truecolor(colours.get('term9') or colours.get('error'), 'd1a200')}",
            f"*.tar={sgr_truecolor(colours.get('term9') or colours.get('error'), 'd1a200')}",
            f"*.gz={sgr_truecolor(colours.get('term9') or colours.get('error'), 'd1a200')}",
            f"*.jpg={sgr_truecolor(colours.get('primaryFixed') or colours.get('primary'), 'ffffff')}",
            f"*.png={sgr_truecolor(colours.get('primaryFixed') or colours.get('primary'), 'ffffff')}",
            f"*.mp3={sgr_truecolor(colours.get('term4') or colours.get('primaryFixed'), 'a2b174')}",
            f"*.mp4={sgr_truecolor(colours.get('term4') or colours.get('primaryFixed'), 'a2b174')}",
            f"*.py={sgr_truecolor(colours.get('term3') or colours.get('tertiary'), 'ffe66f')}",
            f"*.sh={sgr_truecolor(colours.get('term2') or colours.get('secondaryFixed'), 'dbcf4d')}",
            f"*.js={sgr_truecolor(colours.get('term3') or colours.get('tertiary'), 'ffe66f')}",
            f"*.md={sgr_truecolor(colours.get('outline') or colours.get('outlineVariant'), '969178')}",
        ]
    )

    active_border = hex_css(colours.get("secondary") or colours.get("primary"), "d3c876")
    inactive_border = hex_css(colours.get("outlineVariant") or colours.get("outline"), "4a4732")

    content = (
        "# Generated by ~/scripts/system-theme-sync.py\n"
        f"PROMPT='%F{{{prompt_primary}}}Archlinux%f%F{{{prompt_mid}}}_%f%F{{{prompt_tail}}}Itachi%f %F{{{prompt_arrow}}}❯%f '\n"
        f"RPROMPT='%F{{{prompt_path}}}%~%f %F{{{prompt_time}}}%*%f'\n"
        f"export LESS_TERMCAP_mb=$'\\e[{sgr_truecolor(colours.get('secondary') or colours.get('primary'), 'd3c876')}m'\n"
        f"export LESS_TERMCAP_md=$'\\e[{sgr_truecolor(colours.get('primary') or colours.get('onSurface'), 'ffffff')}m'\n"
        "export LESS_TERMCAP_me=$'\\e[0m'\n"
        "export LESS_TERMCAP_se=$'\\e[0m'\n"
        f"export LESS_TERMCAP_so=$'\\e[{sgr_truecolor(colours.get('term3') or colours.get('tertiary'), 'ffe66f')};48;2;49;43;6m'\n"
        "export LESS_TERMCAP_ue=$'\\e[0m'\n"
        f"export LESS_TERMCAP_us=$'\\e[{sgr_truecolor(colours.get('tertiary') or colours.get('secondaryFixed'), 'cbce78')}m'\n"
        f"export LS_COLORS='{ls_colors}'\n"
        f"export CAELESTIA_TMUX_ACTIVE_BORDER='{active_border}'\n"
        f"export CAELESTIA_TMUX_INACTIVE_BORDER='{inactive_border}'\n"
    )
    write_file(ZSH_THEME_PATH, content)

    tmux_bin = find_tmux_bin()
    if not tmux_bin:
        return

    options = {
        "pane-active-border-style": f"fg={active_border}",
        "pane-border-style": f"fg={inactive_border}",
    }
    for option, value in options.items():
        subprocess.run(
            [tmux_bin, "set-window-option", "-g", option, value],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )

    windows = subprocess.run(
        [tmux_bin, "list-windows", "-a", "-F", "#{session_name}:#{window_index}"],
        capture_output=True,
        text=True,
        check=False,
    )
    if windows.returncode != 0:
        return

    for target in {line.strip() for line in windows.stdout.splitlines() if line.strip()}:
        for option, value in options.items():
            subprocess.run(
                [tmux_bin, "set-window-option", "-t", target, option, value],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )


def render_foot(colours: dict[str, str]) -> None:
    surface_low = rgb_tuple(colours.get("surfaceContainerLow") or colours.get("surfaceContainer") or colours.get("surface"), "1d1c10")
    accent_tint = rgb_tuple(colours.get("secondaryContainer") or colours.get("secondary") or colours.get("primary"), "514a01")
    bg = hex_from_rgb(blend(surface_low, accent_tint, 0.18))
    fg = hex_css(colours.get("onSurface") or colours.get("onBackground"), "e8e2cf")
    selection_fg = hex_css(colours.get("onSecondaryContainer") or colours.get("onSecondary"), "151409")
    selection_base = rgb_tuple(colours.get("secondaryContainer") or colours.get("secondary"), "3f3a1e")
    selection_bg = hex_from_rgb(blend(selection_base, surface_low, 0.12))
    url = hex_css(colours.get("primary") or colours.get("secondary"), "d3c876")
    cursor = hex_css(colours.get("primary") or colours.get("onSurface"), "ffffff")
    cursor_text = bg

    colors = {
        "regular0": colours.get("term0") or colours.get("surfaceContainerLowest") or "000000",
        "regular1": colours.get("term1") or colours.get("error") or colours.get("red") or "ffb4ab",
        "regular2": colours.get("term2") or colours.get("success") or colours.get("green") or "b5ccba",
        "regular3": colours.get("term3") or colours.get("tertiary") or colours.get("yellow") or "ffd27a",
        "regular4": colours.get("term4") or colours.get("primary") or colours.get("blue") or "ffffff",
        "regular5": colours.get("term5") or colours.get("secondary") or colours.get("purple") or "d3c876",
        "regular6": colours.get("term6") or colours.get("surfaceTint") or colours.get("sky") or "c8c1ff",
        "regular7": colours.get("onSurface") or "e8e2cf",
        "bright0": colours.get("term8") or colours.get("outline") or "969178",
        "bright1": colours.get("term9") or colours.get("errorContainer") or colours.get("maroon") or "ff8f86",
        "bright2": colours.get("term10") or colours.get("successContainer") or colours.get("teal") or "d1e9d6",
        "bright3": colours.get("term11") or colours.get("tertiaryContainer") or "f2d58d",
        "bright4": colours.get("term12") or colours.get("primaryFixed") or colours.get("lavender") or "ffffff",
        "bright5": colours.get("term13") or colours.get("secondaryFixed") or colours.get("pink") or "f1e28a",
        "bright6": colours.get("term14") or colours.get("secondaryFixedDim") or colours.get("sapphire") or "ddd3ff",
        "bright7": colours.get("term15") or colours.get("inverseSurface") or "fff8e8",
    }

    def render_section(name: str) -> list[str]:
        lines = [
            f"[{name}]",
            "alpha=0.92",
            "alpha-mode=matching",
            "blur=yes",
            f"foreground={fg}",
            f"background={bg}",
            f"selection-foreground={selection_fg}",
            f"selection-background={selection_bg}",
            f"urls={url}",
            f"cursor={cursor}",
            f"cursor-text={cursor_text}",
        ]
        for color_name, value in colors.items():
            lines.append(f"{color_name}={hex_css(value, 'ffffff')}")
        return lines

    content = "\n".join(
        ["# Generated by ~/scripts/system-theme-sync.py"]
        + render_section("colors")
        + [""]
        + render_section("colors-dark")
        + [""]
        + render_section("colors-light")
    ) + "\n"
    write_file(FOOT_DYNAMIC_PATH, content)

    # Existing foot windows can live-switch by jumping to the dark theme section.
    for proc in ("foot", "footclient"):
        subprocess.run(
            ["pkill", "-USR1", "-x", proc],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )


def patch_discord_theme(path: Path, colours: dict[str, str]) -> None:
    if not path.exists():
        return

    text = path.read_text(encoding="utf-8")

    text0 = hex_css(colours.get("onSecondary") or colours.get("onPrimary"), "1d1b14")
    text1 = rgb_css(colours.get("onPrimaryContainer") or colours.get("onSurface"), "e8e2cf")
    text2 = rgb_css(colours.get("onSurface") or colours.get("onBackground"), "e8e2cf")
    text3 = hex_css(colours.get("onSurface") or colours.get("onBackground"), "e8e2cf")
    text4 = hex_css(colours.get("outline") or colours.get("outlineVariant"), "969178")
    text5 = text4
    bg1 = hex_css(colours.get("surfaceContainerHigh") or colours.get("surfaceContainer"), "2c2a1e")
    bg2 = hex_css(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), "222014")
    bg3 = hex_css(colours.get("surface") or colours.get("background"), "151409")
    bg4 = hex_css(colours.get("surfaceContainerLow") or colours.get("surfaceContainer"), "1d1b11")
    hover = rgba_css(colours.get("onSurface"), 0.08, "e8e2cf")
    active = rgba_css(colours.get("secondary") or colours.get("primary"), 0.10, "d3c876")
    active2 = rgba_css(colours.get("secondary") or colours.get("primary"), 0.20, "d3c876")
    message_hover = hover
    border = rgba_css(colours.get("outline"), 0.20, "969178")
    border_light = rgba_css(colours.get("outline"), 0.0, "969178")
    button_border = border_light

    reds = [hex_css(colours.get("error"), "ffb4ab")]
    greens = [hex_css(colours.get("success"), "b5ccba")]
    blues = [hex_css(colours.get("primary"), "ffffff")]
    yellows = [hex_css(colours.get("tertiary"), "ffd27a")]
    purples = [hex_css(colours.get("secondary"), "d3c876")]

    for arr, source, fallback in (
        (reds, colours.get("errorContainer"), "d8655d"),
        (greens, colours.get("successContainer"), "9db7a3"),
        (blues, colours.get("primaryContainer"), "d8d2a6"),
        (yellows, colours.get("tertiaryContainer"), "f2d58d"),
        (purples, colours.get("secondaryContainer"), "a79f5d"),
    ):
        base = arr[0]
        base_rgb = rgb_tuple(base, fallback)
        mix_rgb = rgb_tuple(source, fallback)
        arr.extend(
            [
                f"rgb({blend(base_rgb, mix_rgb, 0.22)[0]}, {blend(base_rgb, mix_rgb, 0.22)[1]}, {blend(base_rgb, mix_rgb, 0.22)[2]})",
                f"rgb({blend(base_rgb, mix_rgb, 0.42)[0]}, {blend(base_rgb, mix_rgb, 0.42)[1]}, {blend(base_rgb, mix_rgb, 0.42)[2]})",
                f"rgb({blend(base_rgb, mix_rgb, 0.62)[0]}, {blend(base_rgb, mix_rgb, 0.62)[1]}, {blend(base_rgb, mix_rgb, 0.62)[2]})",
                f"rgb({blend(base_rgb, mix_rgb, 0.82)[0]}, {blend(base_rgb, mix_rgb, 0.82)[1]}, {blend(base_rgb, mix_rgb, 0.82)[2]})",
            ]
        )

    replacement = f""":root {{
  --colors: on; /* turn off to use discord default colors */
  /* text colors */
  --text-0: {text0}; /* text on colored elements */
  --text-1: {text1}; /* bright text on colored elements */
  --text-2: {text2}; /* headings and important text */
  --text-3: {text3}; /* normal text */
  --text-4: {text4}; /* icon buttons and channels */
  --text-5: {text5}; /* muted channels/chats and timestamps */
  /* background and dark colors */
  --bg-1: {bg1}; /* dark buttons when clicked */
  --bg-2: {bg2}; /* dark buttons */
  --bg-3: {bg3}; /* spacing, secondary elements */
  --bg-4: {bg4}; /* main background color */
  --hover: {hover}; /* channels and buttons when hovered */
  --active: {active}; /* channels and buttons when clicked or selected */
  --active-2: {active2}; /* extra state for transparent buttons */
  --message-hover: {message_hover}; /* messages when hovered */
  /* accent colors */
  --accent-1: var(--blue-1); /* links and other accent text */
  --accent-2: var(--blue-2); /* small accent elements */
  --accent-3: var(--blue-3); /* accent buttons */
  --accent-4: var(--blue-4); /* accent buttons when hovered */
  --accent-5: var(--blue-5); /* accent buttons when clicked */
  --accent-new: {hex_css(colours.get("error"), "ffb4ab")}; /* stuff that's normally red like mute/deafen buttons */
  --mention: linear-gradient(
      to right,
      color-mix(in hsl, var(--blue-2), transparent 90%) 40%,
      transparent
  ); /* background of messages that mention you */
  --mention-hover: linear-gradient(
      to right,
      color-mix(in hsl, var(--blue-2), transparent 95%) 40%,
      transparent
  ); /* background of messages that mention you when hovered */
  --reply: linear-gradient(
      to right,
      color-mix(in hsl, var(--text-3), transparent 90%) 40%,
      transparent
  ); /* background of messages that reply to you */
  --reply-hover: linear-gradient(
      to right,
      color-mix(in hsl, var(--text-3), transparent 95%) 40%,
      transparent
  ); /* background of messages that reply to you when hovered */
  /* status indicator colors */
  --online: var(--green-2); /* change to #43a25a for default */
  --dnd: var(--red-2); /* change to #d83a42 for default */
  --idle: var(--yellow-2); /* change to #ca9654 for default */
  --streaming: var(--purple-2); /* change to #593695 for default */
  --offline: var(--text-4); /* change to #83838b for default offline color */
  /* border colors */
  --border-light: {border_light}; /* light border color */
  --border: {border}; /* normal border color */
  --button-border: {button_border}; /* neutral border color of buttons */
  /* base colors */
  --red-1: {reds[0]};
  --red-2: {reds[1]};
  --red-3: {reds[2]};
  --red-4: {reds[3]};
  --red-5: {reds[4]};
  --green-1: {greens[0]};
  --green-2: {greens[1]};
  --green-3: {greens[2]};
  --green-4: {greens[3]};
  --green-5: {greens[4]};
  --blue-1: {blues[0]};
  --blue-2: {blues[1]};
  --blue-3: {blues[2]};
  --blue-4: {blues[3]};
  --blue-5: {blues[4]};
  --yellow-1: {yellows[0]};
  --yellow-2: {yellows[1]};
  --yellow-3: {yellows[2]};
  --yellow-4: {yellows[3]};
  --yellow-5: {yellows[4]};
  --purple-1: {purples[0]};
  --purple-2: {purples[1]};
  --purple-3: {purples[2]};
  --purple-4: {purples[3]};
  --purple-5: {purples[4]};
}}"""

    updated = re.sub(r":root\s*\{.*?\n\}", replacement, text, count=1, flags=re.S)
    if updated != text:
        write_file(path, updated)


def render_zen(colours: dict[str, str]) -> None:
    css_color_scheme = "light" if palette_is_light(colours) else "dark"
    surface = rgba_css(colours.get("surface"), 0.82, "151409")
    surface_strong = rgba_css(colours.get("surfaceContainer"), 0.90, "222014")
    accent = hex_css(colours.get("secondary") or colours.get("primary"), "d3c876")
    accent_soft = rgba_css(colours.get("secondary") or colours.get("primary"), 0.35, "d3c876")
    accent_fg = hex_css(colours.get("onSecondary") or colours.get("onPrimary"), "1d1b14")
    fg = hex_css(colours.get("onSurface") or colours.get("onBackground"), "e8e2cf")
    panel = hex_css(colours.get("surfaceContainerLow") or colours.get("surface"), "1d1c10")
    border = hex_with_alpha(colours.get("outline") or colours.get("outlineVariant"), "66", "969178")
    muted = hex_css(colours.get("onSurfaceVariant") or colours.get("outline"), "b6b09a")
    link = hex_css(colours.get("primary") or colours.get("secondary"), "e8e2cf")

    dynamic_css = (
        ":root {\n"
        f"  --caelestia-surface: {surface} !important;\n"
        f"  --caelestia-surface-strong: {surface_strong} !important;\n"
        f"  --caelestia-accent: {accent} !important;\n"
        f"  --toolbar-bgcolor: {surface} !important;\n"
        f"  --toolbar-color: {fg} !important;\n"
        f"  --toolbarbutton-icon-fill: {fg} !important;\n"
        f"  --lwt-accent-color: {panel} !important;\n"
        f"  --lwt-text-color: {fg} !important;\n"
        f"  --tab-selected-bgcolor: {surface_strong} !important;\n"
        f"  --arrowpanel-background: {surface_strong} !important;\n"
        f"  --arrowpanel-color: {fg} !important;\n"
        f"  --newtab-background-color: {panel} !important;\n"
        f"  --newtab-text-primary-color: {fg} !important;\n"
        f"  --chrome-content-separator-color: {border} !important;\n"
        "}\n"
    )
    content_css = (
        ":root {\n"
        f"  --caelestia-page-bg: {panel} !important;\n"
        f"  --caelestia-page-fg: {fg} !important;\n"
        f"  --caelestia-page-muted: {muted} !important;\n"
        f"  --caelestia-page-accent: {accent} !important;\n"
        f"  --caelestia-page-accent-fg: {accent_fg} !important;\n"
        f"  --caelestia-page-selection: {accent_soft} !important;\n"
        f"  --caelestia-page-border: {border} !important;\n"
        f"  --caelestia-page-link: {link} !important;\n"
        "}\n"
        "\n"
        '@-moz-document url-prefix("http://"), url-prefix("https://") {\n'
        "  :root {\n"
        "    accent-color: var(--caelestia-page-accent) !important;\n"
        "    scrollbar-color: var(--caelestia-page-accent) var(--caelestia-page-bg) !important;\n"
        "  }\n"
        "\n"
        "  ::selection {\n"
        "    background-color: var(--caelestia-page-selection) !important;\n"
        "    color: var(--caelestia-page-fg) !important;\n"
        "  }\n"
        "\n"
        "  input,\n"
        "  textarea,\n"
        "  select,\n"
        "  button,\n"
        "  progress,\n"
        "  meter {\n"
        "    accent-color: var(--caelestia-page-accent) !important;\n"
        "  }\n"
        "}\n"
        "\n"
        '@-moz-document url-prefix("about:home"), url-prefix("about:newtab"), url-prefix("about:privatebrowsing") {\n'
        "  :root,\n"
        "  body {\n"
        f"    color-scheme: {css_color_scheme} !important;\n"
        "    background-color: var(--caelestia-page-bg) !important;\n"
        "    color: var(--caelestia-page-fg) !important;\n"
        "    accent-color: var(--caelestia-page-accent) !important;\n"
        "    scrollbar-color: var(--caelestia-page-accent) var(--caelestia-page-bg) !important;\n"
        "  }\n"
        "\n"
        "  a,\n"
        "  .wordmark,\n"
        "  .top-site-outer .title,\n"
        "  .search-handoff-button,\n"
        "  .fake-textbox {\n"
        "    color: var(--caelestia-page-fg) !important;\n"
        "  }\n"
        "\n"
        "  a:any-link {\n"
        "    color: var(--caelestia-page-link) !important;\n"
        "  }\n"
        "\n"
        "  .search-wrapper input,\n"
        "  .search-inner-wrapper,\n"
        "  .top-site-outer,\n"
        "  .card-outer,\n"
        "  .context-menu {\n"
        "    background-color: var(--caelestia-page-bg) !important;\n"
        "    border-color: var(--caelestia-page-border) !important;\n"
        "  }\n"
        "\n"
        "  ::selection {\n"
        "    background-color: var(--caelestia-page-selection) !important;\n"
        "    color: var(--caelestia-page-fg) !important;\n"
        "  }\n"
        "}\n"
    )
    dynamic_block = (
        "/* Generated by ~/scripts/system-theme-sync.py */\n"
        f"{ZEN_MARKER_BEGIN}\n"
        + dynamic_css
        + f"{ZEN_MARKER_END}\n"
    )

    for chrome_css in first_existing_paths(HOME / ".config/zen", "*/chrome/userChrome.css"):
        text = chrome_css.read_text(encoding="utf-8")
        updated = re.sub(
            r'(?m)^@import url\("caelestia-dynamic\.css(?:\?v=[^"]*)?"\);\n?',
            "",
            text,
        )
        updated = re.sub(
            re.escape(ZEN_MARKER_BEGIN) + r".*?" + re.escape(ZEN_MARKER_END) + r"\n?",
            "",
            updated,
            flags=re.S,
        )
        updated = re.sub(
            r"(?m)^/\* Generated by ~/scripts/system-theme-sync\.py \*/\n?",
            "",
            updated,
        )
        updated = re.sub(
            r"(?s)\n*:root\s*\{\s*--caelestia-surface:.*?--caelestia-surface-strong:.*?\}\s*\n*",
            "\n",
            updated,
            count=1,
        ).lstrip("\n")
        updated = f"{dynamic_block}\n{updated}" if updated else dynamic_block
        if updated != text:
            write_file(chrome_css, updated)
        write_file(
            chrome_css.parent / "caelestia-dynamic.css",
            "/* Generated by ~/scripts/system-theme-sync.py */\n" + dynamic_css,
        )
        write_file(
            chrome_css.parent / "userContent.css",
            "/* Generated by ~/scripts/system-theme-sync.py */\n"
            f"{ZEN_MARKER_BEGIN}\n"
            + content_css
            + f"{ZEN_MARKER_END}\n",
        )


def render_kde(colours: dict[str, str]) -> None:
    config = new_config()
    if KDE_GLOBALS_PATH.exists():
        config.read(KDE_GLOBALS_PATH, encoding="utf-8")

    general_section = dict(config["General"]) if config.has_section("General") else {}
    general_section.update(
        {
            "ColorScheme": "CaelestiaDynamic",
            "Name": "CaelestiaDynamic",
            "shadeSortColumn": "true",
        }
    )
    config["General"] = general_section

    window_bg = colours.get("surface") or colours.get("background") or "151409"
    window_alt = colours.get("surfaceContainerLow") or colours.get("surfaceContainer") or "1d1c10"
    panel_bg = colours.get("surfaceContainerHigh") or colours.get("surfaceContainer") or "2c2a1e"
    view_bg = colours.get("surfaceContainerLowest") or colours.get("surface") or "100e05"
    fg = colours.get("onSurface") or colours.get("onBackground") or "e8e2cf"
    fg_muted = colours.get("outline") or colours.get("outlineVariant") or "969178"
    accent = colours.get("secondary") or colours.get("primary") or "d3c876"
    accent_fg = colours.get("onSecondary") or colours.get("onPrimary") or "1d1b14"
    button_bg = hex_from_rgb(
        blend(
            rgb_tuple(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), "222014"),
            rgb_tuple(accent, "d3c876"),
            0.24,
        )
    )

    section_values = {
        "Colors:Window": {
            "BackgroundNormal": rgb_csv(window_bg, "151409"),
            "BackgroundAlternate": rgb_csv(window_alt, "1d1c10"),
            "ForegroundNormal": rgb_csv(fg, "e8e2cf"),
            "ForegroundActive": rgb_csv(fg, "e8e2cf"),
            "ForegroundInactive": rgb_csv(fg_muted, "969178"),
            "DecorationFocus": rgb_csv(accent, "d3c876"),
            "DecorationHover": rgb_csv(accent, "d3c876"),
        },
        "Colors:View": {
            "BackgroundNormal": rgb_csv(view_bg, "100e05"),
            "BackgroundAlternate": rgb_csv(window_alt, "1d1c10"),
            "ForegroundNormal": rgb_csv(fg, "e8e2cf"),
            "ForegroundInactive": rgb_csv(fg_muted, "969178"),
            "DecorationFocus": rgb_csv(accent, "d3c876"),
            "DecorationHover": rgb_csv(accent, "d3c876"),
        },
        "Colors:Button": {
            "BackgroundNormal": rgb_csv(button_bg, "222014"),
            "BackgroundAlternate": rgb_csv(window_alt, "1d1c10"),
            "ForegroundNormal": rgb_csv(fg, "e8e2cf"),
            "ForegroundInactive": rgb_csv(fg_muted, "969178"),
            "DecorationFocus": rgb_csv(accent, "d3c876"),
            "DecorationHover": rgb_csv(accent, "d3c876"),
        },
        "Colors:Selection": {
            "BackgroundNormal": rgb_csv(accent, "d3c876"),
            "BackgroundAlternate": rgb_csv(colours.get("secondaryContainer") or accent, "514a01"),
            "ForegroundNormal": rgb_csv(accent_fg, "1d1b14"),
            "ForegroundInactive": rgb_csv(accent_fg, "1d1b14"),
            "DecorationFocus": rgb_csv(accent, "d3c876"),
            "DecorationHover": rgb_csv(accent, "d3c876"),
        },
        "Colors:Tooltip": {
            "BackgroundNormal": rgb_csv(panel_bg, "2c2a1e"),
            "BackgroundAlternate": rgb_csv(button_bg, "222014"),
            "ForegroundNormal": rgb_csv(fg, "e8e2cf"),
            "ForegroundInactive": rgb_csv(fg_muted, "969178"),
            "DecorationFocus": rgb_csv(accent, "d3c876"),
            "DecorationHover": rgb_csv(accent, "d3c876"),
        },
        "Colors:Complementary": {
            "BackgroundNormal": rgb_csv(panel_bg, "2c2a1e"),
            "BackgroundAlternate": rgb_csv(button_bg, "222014"),
            "ForegroundNormal": rgb_csv(fg, "e8e2cf"),
            "ForegroundInactive": rgb_csv(fg_muted, "969178"),
            "DecorationFocus": rgb_csv(accent, "d3c876"),
            "DecorationHover": rgb_csv(accent, "d3c876"),
        },
        "WM": {
            "activeBackground": rgb_csv(panel_bg, "2c2a1e"),
            "activeForeground": rgb_csv(fg, "e8e2cf"),
            "inactiveBackground": rgb_csv(window_bg, "151409"),
            "inactiveForeground": rgb_csv(fg_muted, "969178"),
        },
    }

    for section, mapping in section_values.items():
        if not config.has_section(section):
            config.add_section(section)
        for key, value in mapping.items():
            config.set(section, key, value)

    with KDE_GLOBALS_PATH.open("w", encoding="utf-8") as handle:
        config.write(handle)


def render_spicetify(colours: dict[str, str]) -> None:
    theme = new_config()
    theme["caelestia"] = {
        "text": hex_rgb(colours.get("onSurface"), "e8e2cf"),
        "subtext": hex_rgb(colours.get("outline"), "969178"),
        "main": hex_rgb(colours.get("surfaceContainerLow") or colours.get("surface"), "1d1c10"),
        "highlight": hex_rgb(colours.get("secondary") or colours.get("primary"), "d3c876"),
        "misc": hex_rgb(colours.get("secondary") or colours.get("primary"), "d3c876"),
        "notification": hex_rgb(colours.get("outline"), "969178"),
        "notification-error": hex_rgb(colours.get("error"), "ffb4ab"),
        "shadow": "000000",
        "card": hex_rgb(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), "222014"),
        "player": hex_rgb(colours.get("surfaceContainerHigh") or colours.get("surfaceContainer"), "2c2a1e"),
        "sidebar": hex_rgb(colours.get("surface"), "151409"),
        "main-elevated": hex_rgb(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), "222014"),
        "highlight-elevated": hex_rgb(colours.get("surfaceContainerHigh") or colours.get("surfaceContainer"), "2c2a1e"),
        "selected-row": hex_rgb(colours.get("onSurface"), "e8e2cf"),
        "button": hex_rgb(colours.get("secondary") or colours.get("primary"), "d3c876"),
        "button-active": hex_rgb(colours.get("secondaryContainer") or colours.get("secondary"), "514a01"),
        "button-disabled": hex_rgb(colours.get("outline"), "969178"),
        "tab-active": hex_rgb(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), "222014"),
    }
    with SPICETIFY_THEME_PATH.open("w", encoding="utf-8") as handle:
        theme.write(handle)

    if SPICETIFY_CONFIG_PATH.exists():
        config = new_config()
        config.read(SPICETIFY_CONFIG_PATH, encoding="utf-8")
        if not config.has_section("Setting"):
            config.add_section("Setting")
        config.set("Setting", "current_theme", "caelestia")
        config.set("Setting", "color_scheme", "")
        with SPICETIFY_CONFIG_PATH.open("w", encoding="utf-8") as handle:
            config.write(handle)


def render_zed(colours: dict[str, str]) -> None:
    if ZED_THEME_PATH.exists():
        try:
            data = json.loads(ZED_THEME_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            data = {}
    else:
        data = {}

    themes = data.setdefault("themes", [{}])
    if not themes:
        themes.append({})

    theme = themes[0]
    theme["name"] = "Caelestia"
    theme["appearance"] = "dark"
    theme.setdefault("author", "Caelestia")
    data["$schema"] = "https://zed.dev/schema/themes/v0.2.0.json"
    data["name"] = "Caelestia"
    data["author"] = "Caelestia"

    style = theme.setdefault("style", {})
    accent = colours.get("secondary") or colours.get("primary") or "d3c876"
    bg = colours.get("surface") or colours.get("background") or "151409"
    bg_alt = colours.get("surfaceContainerLow") or colours.get("surfaceContainer") or "1d1c10"
    bg_card = colours.get("surfaceContainer") or colours.get("surfaceContainerLow") or "222014"
    bg_high = colours.get("surfaceContainerHigh") or colours.get("surfaceContainer") or "2c2a1e"
    fg = colours.get("onSurface") or colours.get("onBackground") or "e8e2cf"
    muted = colours.get("outline") or colours.get("outlineVariant") or "969178"
    muted_soft = colours.get("outlineVariant") or colours.get("outline") or "4a4732"

    style.update(
        {
            "background": hex_css(bg, "151409"),
            "border": hex_with_alpha(muted_soft, "40", "54453c"),
            "border.variant": hex_with_alpha(muted_soft, "60", "54453c"),
            "border.focused": hex_css(accent, "d3c876"),
            "border.selected": hex_with_alpha(accent, "80", "d3c876"),
            "border.transparent": "#00000000",
            "border.disabled": hex_with_alpha(muted_soft, "30", "54453c"),
            "elevated_surface.background": hex_css(bg_card, "222014"),
            "surface.background": hex_css(bg, "151409"),
            "element.background": hex_with_alpha(muted_soft, "40", "54453c"),
            "element.hover": hex_with_alpha(muted_soft, "60", "54453c"),
            "element.active": hex_with_alpha(accent, "30", "d3c876"),
            "element.selected": hex_with_alpha(accent, "20", "d3c876"),
            "element.disabled": hex_with_alpha(muted_soft, "20", "54453c"),
            "drop_target.background": hex_with_alpha(accent, "20", "d3c876"),
            "ghost_element.background": "#00000000",
            "ghost_element.hover": hex_with_alpha(muted_soft, "40", "54453c"),
            "ghost_element.active": hex_with_alpha(accent, "30", "d3c876"),
            "ghost_element.selected": hex_with_alpha(accent, "20", "d3c876"),
            "ghost_element.disabled": hex_with_alpha(muted_soft, "20", "54453c"),
            "text": hex_css(fg, "e8e2cf"),
            "text.muted": hex_css(muted, "969178"),
            "text.placeholder": hex_css(muted_soft, "4a4732"),
            "text.disabled": hex_with_alpha(muted_soft, "80", "4a4732"),
            "text.accent": hex_css(accent, "d3c876"),
            "icon": hex_css(fg, "e8e2cf"),
            "icon.muted": hex_css(muted, "969178"),
            "icon.disabled": hex_with_alpha(muted_soft, "60", "4a4732"),
            "icon.placeholder": hex_css(muted, "969178"),
            "icon.accent": hex_css(accent, "d3c876"),
            "status_bar.background": hex_css(bg, "151409"),
            "title_bar.background": hex_css(bg, "151409"),
            "title_bar.inactive_background": hex_css(bg, "151409"),
            "toolbar.background": hex_css(bg, "151409"),
            "tab_bar.background": hex_css(bg, "151409"),
            "tab.inactive_background": hex_css(bg, "151409"),
            "tab.active_background": hex_css(bg_card, "222014"),
            "search.match_background": hex_with_alpha(accent, "40", "d3c876"),
            "panel.background": hex_css(bg, "151409"),
            "panel.focused_border": hex_css(accent, "d3c876"),
            "pane.focused_border": hex_css(accent, "d3c876"),
            "scrollbar.thumb.background": hex_with_alpha(muted_soft, "30", "54453c"),
            "scrollbar.thumb.hover_background": hex_with_alpha(muted_soft, "60", "54453c"),
            "scrollbar.thumb.border": hex_with_alpha(muted_soft, "20", "54453c"),
            "scrollbar.track.background": "#00000000",
            "scrollbar.track.border": "#00000000",
            "editor.foreground": hex_css(fg, "e8e2cf"),
            "editor.background": hex_css(bg, "151409"),
            "editor.gutter.background": hex_css(bg, "151409"),
            "editor.subheader.background": hex_css(bg_alt, "1d1c10"),
            "editor.active_line.background": hex_with_alpha(bg_high, "60", "2c2a1e"),
            "editor.highlighted_line.background": hex_with_alpha(accent, "15", "d3c876"),
            "editor.line_number": hex_css(muted, "969178"),
            "editor.active_line_number": hex_css(fg, "e8e2cf"),
            "editor.invisible": hex_with_alpha(muted_soft, "40", "54453c"),
            "editor.wrap_guide": hex_with_alpha(muted_soft, "30", "54453c"),
            "editor.active_wrap_guide": hex_with_alpha(muted_soft, "60", "54453c"),
            "editor.document_highlight.read_background": hex_with_alpha(accent, "20", "d3c876"),
            "editor.document_highlight.write_background": hex_with_alpha(accent, "30", "d3c876"),
            "terminal.background": hex_css(bg, "151409"),
            "terminal.foreground": hex_css(fg, "e8e2cf"),
            "terminal.bright_foreground": hex_css(colours.get("term15") or fg, "ffffff"),
            "terminal.dim_foreground": hex_css(muted, "969178"),
            "terminal.ansi.black": hex_css(colours.get("term0") or bg_alt, "353433"),
            "terminal.ansi.bright_black": hex_css(colours.get("term8") or muted, "a9a290"),
            "terminal.ansi.dim_black": hex_with_alpha(colours.get("term0") or bg_alt, "80", "353433"),
            "terminal.ansi.red": hex_css(colours.get("term1") or colours.get("error"), "b48b00"),
            "terminal.ansi.bright_red": hex_css(colours.get("term9") or colours.get("errorContainer"), "d1a200"),
            "terminal.ansi.dim_red": hex_with_alpha(colours.get("term1") or colours.get("error"), "80", "b48b00"),
            "terminal.ansi.green": hex_css(colours.get("term2") or colours.get("success"), "dbcf4d"),
            "terminal.ansi.bright_green": hex_css(colours.get("term10") or colours.get("successContainer"), "eee145"),
            "terminal.ansi.dim_green": hex_with_alpha(colours.get("term2") or colours.get("success"), "80", "dbcf4d"),
            "terminal.ansi.yellow": hex_css(colours.get("term3") or colours.get("tertiary"), "ffe66f"),
            "terminal.ansi.bright_yellow": hex_css(colours.get("term11") or colours.get("tertiaryContainer"), "fff4cb"),
            "terminal.ansi.dim_yellow": hex_with_alpha(colours.get("term3") or colours.get("tertiary"), "80", "ffe66f"),
            "terminal.ansi.blue": hex_css(colours.get("term4") or colours.get("primary"), "a2b174"),
            "terminal.ansi.bright_blue": hex_css(colours.get("term12") or colours.get("primaryFixed"), "c0c49a"),
            "terminal.ansi.dim_blue": hex_with_alpha(colours.get("term4") or colours.get("primary"), "80", "a2b174"),
            "terminal.ansi.magenta": hex_css(colours.get("term5") or colours.get("secondary"), "d3a343"),
            "terminal.ansi.bright_magenta": hex_css(colours.get("term13") or colours.get("secondaryFixed"), "e2b967"),
            "terminal.ansi.dim_magenta": hex_with_alpha(colours.get("term5") or colours.get("secondary"), "80", "d3a343"),
            "terminal.ansi.cyan": hex_css(colours.get("term6") or colours.get("surfaceTint"), "cbce78"),
            "terminal.ansi.bright_cyan": hex_css(colours.get("term14") or colours.get("secondaryFixedDim"), "e0e07e"),
            "terminal.ansi.dim_cyan": hex_with_alpha(colours.get("term6") or colours.get("surfaceTint"), "80", "cbce78"),
            "terminal.ansi.white": hex_css(colours.get("term7") or fg, "e0d8bf"),
            "terminal.ansi.bright_white": hex_css(colours.get("term15") or fg, "ffffff"),
            "terminal.ansi.dim_white": hex_with_alpha(colours.get("term7") or fg, "80", "e0d8bf"),
            "link_text.hover": hex_css(accent, "d3c876"),
            "conflict": hex_css(colours.get("tertiary") or colours.get("term3"), "ffe66f"),
            "conflict.background": hex_with_alpha(colours.get("tertiary") or colours.get("term3"), "15", "ffe66f"),
            "conflict.border": hex_css(colours.get("tertiary") or colours.get("term3"), "ffe66f"),
            "created": hex_css(colours.get("success") or colours.get("term2"), "dbcf4d"),
            "created.background": hex_with_alpha(colours.get("success") or colours.get("term2"), "15", "dbcf4d"),
            "created.border": hex_css(colours.get("success") or colours.get("term2"), "dbcf4d"),
            "deleted": hex_css(colours.get("error") or colours.get("term1"), "b48b00"),
            "deleted.background": hex_with_alpha(colours.get("error") or colours.get("term1"), "15", "b48b00"),
            "deleted.border": hex_css(colours.get("error") or colours.get("term1"), "b48b00"),
            "error": hex_css(colours.get("error"), "ffb4ab"),
            "error.background": hex_with_alpha(colours.get("error"), "15", "ffb4ab"),
            "error.border": hex_css(colours.get("error"), "ffb4ab"),
            "hidden": hex_css(muted, "969178"),
            "hidden.background": hex_with_alpha(muted, "15", "969178"),
            "hidden.border": hex_css(muted, "969178"),
            "hint": hex_css(colours.get("success"), "B5CCBA"),
            "hint.background": hex_with_alpha(colours.get("success"), "15", "B5CCBA"),
            "hint.border": hex_css(colours.get("success"), "B5CCBA"),
            "ignored": hex_css(muted, "969178"),
            "ignored.background": hex_with_alpha(muted, "15", "969178"),
            "ignored.border": hex_css(muted, "969178"),
            "info": hex_css(colours.get("primary") or accent, "ffffff"),
            "info.background": hex_with_alpha(colours.get("primary") or accent, "15", "ffffff"),
            "info.border": hex_css(colours.get("primary") or accent, "ffffff"),
            "modified": hex_css(colours.get("secondary") or accent, "d3c876"),
            "modified.background": hex_with_alpha(colours.get("secondary") or accent, "15", "d3c876"),
            "modified.border": hex_css(colours.get("secondary") or accent, "d3c876"),
            "predictive": hex_css(muted, "969178"),
            "predictive.background": hex_with_alpha(muted, "15", "969178"),
            "predictive.border": hex_with_alpha(muted_soft, "40", "54453c"),
            "renamed": hex_css(colours.get("term6") or colours.get("surfaceTint"), "cbce78"),
            "renamed.background": hex_with_alpha(colours.get("term6") or colours.get("surfaceTint"), "15", "cbce78"),
            "renamed.border": hex_css(colours.get("term6") or colours.get("surfaceTint"), "cbce78"),
            "success": hex_css(colours.get("success"), "B5CCBA"),
            "success.background": hex_with_alpha(colours.get("success"), "15", "B5CCBA"),
            "success.border": hex_css(colours.get("success"), "B5CCBA"),
            "unreachable": hex_css(muted, "969178"),
            "unreachable.background": hex_with_alpha(muted, "15", "969178"),
            "unreachable.border": hex_css(muted, "969178"),
            "warning": hex_css(colours.get("tertiary") or colours.get("term3"), "ffe66f"),
            "warning.background": hex_with_alpha(colours.get("tertiary") or colours.get("term3"), "15", "ffe66f"),
            "warning.border": hex_css(colours.get("tertiary") or colours.get("term3"), "ffe66f"),
        }
    )

    style["players"] = [
        {"cursor": hex_css(colours.get("term15") or fg, "ffffff"), "selection": hex_with_alpha(colours.get("term15") or fg, "60", "ffffff"), "background": hex_css(colours.get("term4"), "a2b174")},
        {"cursor": hex_css(colours.get("term10"), "eee145"), "selection": hex_with_alpha(colours.get("term10"), "40", "eee145"), "background": hex_css(colours.get("term10"), "eee145")},
        {"cursor": hex_css(colours.get("term13"), "e2b967"), "selection": hex_with_alpha(colours.get("term13"), "40", "e2b967"), "background": hex_css(colours.get("term13"), "e2b967")},
        {"cursor": hex_css(colours.get("term11"), "fff4cb"), "selection": hex_with_alpha(colours.get("term11"), "40", "fff4cb"), "background": hex_css(colours.get("term11"), "fff4cb")},
        {"cursor": hex_css(colours.get("term2"), "dbcf4d"), "selection": hex_with_alpha(colours.get("term2"), "40", "dbcf4d"), "background": hex_css(colours.get("term2"), "dbcf4d")},
        {"cursor": hex_css(colours.get("term1"), "b48b00"), "selection": hex_with_alpha(colours.get("term1"), "40", "b48b00"), "background": hex_css(colours.get("term1"), "b48b00")},
        {"cursor": hex_css(colours.get("term6"), "cbce78"), "selection": hex_with_alpha(colours.get("term6"), "40", "cbce78"), "background": hex_css(colours.get("term6"), "cbce78")},
        {"cursor": hex_css(colours.get("term9"), "d1a200"), "selection": hex_with_alpha(colours.get("term9"), "40", "d1a200"), "background": hex_css(colours.get("term9"), "d1a200")},
    ]

    syntax = style.setdefault("syntax", {})
    syntax_updates = {
        "attribute": hex_css(colours.get("term11") or colours.get("tertiary"), "fff4cb"),
        "boolean": hex_css(colours.get("term13") or colours.get("secondary"), "e2b967"),
        "comment": hex_css(muted, "969178"),
        "comment.doc": hex_css(muted, "969178"),
        "constant": hex_css(colours.get("term13") or colours.get("secondary"), "e2b967"),
        "constructor": hex_css(colours.get("term11") or colours.get("tertiary"), "fff4cb"),
        "embedded": hex_css(colours.get("term15") or fg, "ffffff"),
        "emphasis": hex_css(accent, "d3c876"),
        "enum": hex_css(colours.get("term4") or colours.get("primary"), "a2b174"),
        "function": hex_css(colours.get("term4") or colours.get("primary"), "a2b174"),
        "hint": hex_css(colours.get("success"), "B5CCBA"),
        "keyword": hex_css(accent, "d3c876"),
        "label": hex_css(colours.get("term6") or colours.get("surfaceTint"), "cbce78"),
        "link_text": hex_css(accent, "d3c876"),
        "number": hex_css(colours.get("term1") or colours.get("error"), "b48b00"),
        "operator": hex_css(colours.get("term14") or colours.get("secondaryFixedDim"), "e0e07e"),
        "predictive": hex_css(muted, "969178"),
        "preproc": hex_css(colours.get("term6") or colours.get("surfaceTint"), "cbce78"),
        "primary": hex_css(fg, "e8e2cf"),
        "property": hex_css(colours.get("term12") or colours.get("primaryFixed"), "c0c49a"),
        "punctuation": hex_css(muted, "969178"),
        "punctuation.bracket": hex_css(muted, "969178"),
        "punctuation.delimiter": hex_css(muted, "969178"),
        "punctuation.list_marker": hex_css(accent, "d3c876"),
        "string": hex_css(colours.get("term3") or colours.get("tertiary"), "ffe66f"),
        "string.escape": hex_css(colours.get("term6") or colours.get("surfaceTint"), "cbce78"),
        "string.regex": hex_css(colours.get("term10") or colours.get("success"), "eee145"),
        "tag": hex_css(colours.get("term4") or colours.get("primary"), "a2b174"),
        "text.literal": hex_css(fg, "e8e2cf"),
        "title": hex_css(accent, "d3c876"),
        "type": hex_css(colours.get("term12") or colours.get("primaryFixed"), "c0c49a"),
        "variable": hex_css(fg, "e8e2cf"),
        "variable.special": hex_css(colours.get("term1") or colours.get("error"), "b48b00"),
        "variant": hex_css(colours.get("term13") or colours.get("secondary"), "e2b967"),
    }
    for token, color in syntax_updates.items():
        entry = syntax.get(token)
        if not isinstance(entry, dict):
            entry = {}
        entry["color"] = color
        syntax[token] = entry

    write_file(ZED_THEME_PATH, json.dumps(data, indent=2) + "\n")


def render_steam(colours: dict[str, str]) -> None:
    ensure_steam_theme_patch()

    if not STEAM_LIBRARYROOT_CUSTOM_CSS_PATH.exists():
        return

    accent_bg = rgb_csv(colours.get("secondary") or colours.get("primary"), "d3c876")
    accent_fg = rgb_csv(colours.get("onSecondary") or colours.get("onPrimary"), "1d1b14")
    accent = rgb_csv(colours.get("secondaryFixed") or colours.get("primaryFixed") or colours.get("secondary"), "f0e58f")
    success_bg = rgb_csv(colours.get("success") or colours.get("term2"), "26a269")
    success_fg = rgb_csv(colours.get("onSuccess") or colours.get("onPrimary"), "213528")
    success = rgb_csv(colours.get("successContainer") or colours.get("term10") or colours.get("success"), "8ff0a4")
    warning_bg = rgb_csv(colours.get("tertiary") or colours.get("term3"), "cd9309")
    warning_fg = rgb_csv(colours.get("onTertiary") or colours.get("onPrimary"), "263500")
    warning = rgb_csv(colours.get("tertiaryContainer") or colours.get("term11") or colours.get("tertiary"), "f8e45c")
    error_bg = rgb_csv(colours.get("error"), "c01c28")
    error_fg = rgb_csv(colours.get("onError"), "690005")
    error = rgb_csv(colours.get("errorContainer") or colours.get("term9") or colours.get("error"), "ff7b63")
    window_bg = rgb_csv(colours.get("surface") or colours.get("background"), "151409")
    window_fg = rgb_csv(colours.get("onSurface") or colours.get("onBackground"), "e8e2cf")
    view_bg = rgb_csv(colours.get("surfaceContainerLow") or colours.get("surface"), "1d1c10")
    view_fg = window_fg
    headerbar_bg = rgb_csv(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), "222014")
    headerbar_fg = window_fg
    headerbar_border = rgb_csv(colours.get("outlineVariant") or colours.get("outline"), "4a4732")
    headerbar_backdrop = rgb_csv(colours.get("surfaceContainerLow") or colours.get("surface"), "1d1c10")
    sidebar_bg = rgb_csv(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), "222014")
    sidebar_fg = window_fg
    sidebar_backdrop = rgb_csv(colours.get("surfaceContainerLow") or colours.get("surface"), "1d1c10")
    secondary_sidebar_bg = rgb_csv(colours.get("surfaceContainerLow") or colours.get("surface"), "1d1c10")
    secondary_sidebar_fg = window_fg
    secondary_sidebar_backdrop = rgb_csv(colours.get("surfaceContainerLowest") or colours.get("surface"), "100e05")
    card_bg = rgb_csv(colours.get("surfaceContainerHighest") or colours.get("surfaceContainerHigh"), "373528")
    card_fg = window_fg
    dialog_bg = rgb_csv(colours.get("surfaceContainerHigh") or colours.get("surfaceContainer"), "2c2a1e")
    dialog_fg = window_fg
    popover_bg = rgb_csv(colours.get("surfaceContainerHigh") or colours.get("surfaceContainer"), "2c2a1e")
    popover_fg = window_fg
    thumbnail_bg = rgb_csv(colours.get("surfaceContainerHigh") or colours.get("surfaceContainer"), "2c2a1e")
    thumbnail_fg = window_fg

    content = (
        "/* Generated by ~/scripts/system-theme-sync.py */\n"
        ":root {\n"
        f"    --adw-accent-bg-rgb: {accent_bg} !important;\n"
        f"    --adw-accent-fg-rgb: {accent_fg} !important;\n"
        f"    --adw-accent-rgb: {accent} !important;\n"
        f"    --adw-destructive-bg-rgb: {error_bg} !important;\n"
        f"    --adw-destructive-fg-rgb: {error_fg} !important;\n"
        f"    --adw-destructive-rgb: {error} !important;\n"
        f"    --adw-success-bg-rgb: {success_bg} !important;\n"
        f"    --adw-success-fg-rgb: {success_fg} !important;\n"
        f"    --adw-success-rgb: {success} !important;\n"
        f"    --adw-warning-bg-rgb: {warning_bg} !important;\n"
        f"    --adw-warning-fg-rgb: {warning_fg} !important;\n"
        "    --adw-warning-fg-a: 0.92 !important;\n"
        f"    --adw-warning-rgb: {warning} !important;\n"
        f"    --adw-error-bg-rgb: {error_bg} !important;\n"
        f"    --adw-error-fg-rgb: {error_fg} !important;\n"
        f"    --adw-error-rgb: {error} !important;\n"
        f"    --adw-window-bg-rgb: {window_bg} !important;\n"
        f"    --adw-window-fg-rgb: {window_fg} !important;\n"
        f"    --adw-view-bg-rgb: {view_bg} !important;\n"
        f"    --adw-view-fg-rgb: {view_fg} !important;\n"
        f"    --adw-headerbar-bg-rgb: {headerbar_bg} !important;\n"
        f"    --adw-headerbar-fg-rgb: {headerbar_fg} !important;\n"
        f"    --adw-headerbar-border-rgb: {headerbar_border} !important;\n"
        f"    --adw-headerbar-backdrop-rgb: {headerbar_backdrop} !important;\n"
        f"    --adw-sidebar-bg-rgb: {sidebar_bg} !important;\n"
        f"    --adw-sidebar-fg-rgb: {sidebar_fg} !important;\n"
        f"    --adw-sidebar-backdrop-rgb: {sidebar_backdrop} !important;\n"
        f"    --adw-secondary-sidebar-bg-rgb: {secondary_sidebar_bg} !important;\n"
        f"    --adw-secondary-sidebar-fg-rgb: {secondary_sidebar_fg} !important;\n"
        f"    --adw-secondary-sidebar-backdrop-rgb: {secondary_sidebar_backdrop} !important;\n"
        f"    --adw-card-bg-rgb: {card_bg} !important;\n"
        f"    --adw-card-fg-rgb: {card_fg} !important;\n"
        f"    --adw-dialog-bg-rgb: {dialog_bg} !important;\n"
        f"    --adw-dialog-fg-rgb: {dialog_fg} !important;\n"
        f"    --adw-popover-bg-rgb: {popover_bg} !important;\n"
        f"    --adw-popover-fg-rgb: {popover_fg} !important;\n"
        f"    --adw-thumbnail-bg-rgb: {thumbnail_bg} !important;\n"
        f"    --adw-thumbnail-fg-rgb: {thumbnail_fg} !important;\n"
        "    --adw-card-bg-a: 0.10 !important;\n"
        "    --adw-banner-bg-a: 0.22 !important;\n"
        "    --adw-shade-a: 0.24 !important;\n"
        "    --adw-sidebar-shade-a: 0.18 !important;\n"
        "    --adw-popover-shade-a: 0.20 !important;\n"
        "}\n"
    )
    ensure_steam_dynamic_import(content_version(content))
    write_file(STEAM_DYNAMIC_CSS_PATH, content)


def render_vscode(colours: dict[str, str]) -> None:
    if not CODE_SETTINGS_PATH.exists():
        return

    settings = json.loads(CODE_SETTINGS_PATH.read_text(encoding="utf-8"))
    light = palette_is_light(colours)
    bg = hex_css(colours.get("surface") or colours.get("background"), "151409")
    bg_alt = hex_css(colours.get("surfaceContainer") or colours.get("surfaceContainerLow"), "222014")
    bg_soft = hex_css(colours.get("surfaceContainerHigh") or colours.get("surfaceContainer"), "2c2a1e")
    fg = hex_css(colours.get("onSurface") or colours.get("onBackground"), "e8e2cf")
    muted = hex_css(colours.get("outline") or colours.get("outlineVariant"), "969178")
    accent = hex_css(colours.get("secondary") or colours.get("primary"), "d3c876")
    accent_soft = hex_with_alpha(colours.get("secondary") or colours.get("primary"), "29", "d3c876")
    accent_medium = hex_with_alpha(colours.get("secondary") or colours.get("primary"), "52", "d3c876")
    accent_strong = hex_with_alpha(colours.get("secondary") or colours.get("primary"), "b3", "d3c876")
    accent_fg = hex_css(colours.get("onSecondary") or colours.get("onPrimary"), "1d1b14")
    subtle_hover = hex_with_alpha(colours.get("onSurface"), "14", "e8e2cf")
    system_status = accent

    settings["workbench.colorCustomizations"] = {
        "editor.background": bg,
        "editor.foreground": fg,
        "sideBar.background": bg_alt,
        "sideBar.foreground": fg,
        "activityBar.background": bg,
        "activityBar.foreground": fg,
        "activityBarBadge.background": accent,
        "activityBarBadge.foreground": bg,
        "titleBar.activeBackground": bg,
        "titleBar.activeForeground": fg,
        "titleBar.inactiveBackground": bg,
        "titleBar.inactiveForeground": muted,
        "titleBar.border": bg_soft,
        "commandCenter.background": bg_alt,
        "commandCenter.foreground": fg,
        "commandCenter.border": muted,
        "statusBar.background": bg_alt,
        "statusBar.foreground": fg,
        "statusBar.debuggingBackground": accent,
        "statusBar.debuggingForeground": bg,
        "list.activeSelectionBackground": accent_medium,
        "list.inactiveSelectionBackground": accent_soft,
        "list.focusBackground": accent_medium,
        "list.inactiveFocusBackground": accent_soft,
        "list.hoverBackground": subtle_hover,
        "list.activeSelectionForeground": fg,
        "list.inactiveSelectionForeground": fg,
        "list.focusForeground": fg,
        "list.focusAndSelectionOutline": accent,
        "list.errorForeground": system_status,
        "list.warningForeground": system_status,
        "quickInputList.focusBackground": accent_medium,
        "quickInputList.focusForeground": fg,
        "editorSuggestWidget.selectedBackground": accent_medium,
        "editorGroupHeader.tabsBackground": bg,
        "tab.activeBackground": bg_alt,
        "tab.inactiveBackground": bg,
        "tab.activeForeground": fg,
        "tab.inactiveForeground": muted,
        "tab.border": bg,
        "tab.activeBorderTop": accent,
        "tab.unfocusedActiveBorderTop": muted,
        "panel.background": bg,
        "panel.border": muted,
        "input.background": bg_soft,
        "input.foreground": fg,
        "input.border": muted,
        "button.background": accent,
        "button.foreground": bg,
        "button.hoverBackground": hex_css(colours.get("secondaryContainer") or colours.get("secondary"), "a79f5d"),
        "button.secondaryBackground": bg_soft,
        "button.secondaryForeground": fg,
        "button.secondaryHoverBackground": accent_soft,
        "focusBorder": accent,
        "textLink.foreground": accent,
        "badge.background": accent,
        "badge.foreground": bg,
        "statusBarItem.errorBackground": accent,
        "statusBarItem.errorForeground": bg,
        "statusBarItem.warningBackground": accent,
        "statusBarItem.warningForeground": bg,
        "inputValidation.errorBackground": accent_soft,
        "inputValidation.errorBorder": accent,
        "inputValidation.errorForeground": fg,
        "inputValidation.warningBackground": accent_soft,
        "inputValidation.warningBorder": accent,
        "inputValidation.warningForeground": fg,
        "editorError.foreground": system_status,
        "editorError.border": accent_medium,
        "editorWarning.foreground": system_status,
        "editorWarning.border": accent_medium,
        "problemsErrorIcon.foreground": system_status,
        "problemsWarningIcon.foreground": system_status,
        "notificationsErrorIcon.foreground": system_status,
        "notificationsWarningIcon.foreground": system_status,
        "gitDecoration.modifiedResourceForeground": system_status,
        "gitDecoration.deletedResourceForeground": system_status,
        "gitDecoration.untrackedResourceForeground": system_status,
        "gitDecoration.ignoredResourceForeground": muted,
        "gitDecoration.conflictingResourceForeground": system_status,
        "gitDecoration.stageModifiedResourceForeground": system_status,
        "gitDecoration.stageDeletedResourceForeground": system_status,
        "testing.iconFailed": system_status,
        "testing.iconErrored": system_status,
        "testing.iconQueued": accent_strong,
        "testing.iconUnset": muted,
        "debugExceptionWidget.background": bg_soft,
        "debugExceptionWidget.border": accent,
        "extensionButton.prominentBackground": accent,
        "extensionButton.prominentForeground": bg,
        "extensionButton.prominentHoverBackground": hex_css(colours.get("secondaryContainer") or colours.get("secondary"), "a79f5d"),
        "terminal.foreground": fg,
        "terminal.background": bg,
        "terminalCursor.foreground": accent,
        "terminal.ansiBlack": hex_css(colours.get("term0") or bg_soft, "353433"),
        "terminal.ansiRed": hex_css(colours.get("term1") or colours.get("error"), "b48b00"),
        "terminal.ansiGreen": hex_css(colours.get("term2") or colours.get("success"), "dbcf4d"),
        "terminal.ansiYellow": hex_css(colours.get("term3") or colours.get("tertiary"), "ffe66f"),
        "terminal.ansiBlue": hex_css(colours.get("term4") or colours.get("primary"), "a2b174"),
        "terminal.ansiMagenta": hex_css(colours.get("term5") or colours.get("secondary"), "d3a343"),
        "terminal.ansiCyan": hex_css(colours.get("term6") or colours.get("surfaceTint") or colours.get("secondaryFixedDim"), "cbce78"),
        "terminal.ansiWhite": hex_css(colours.get("term7") or fg, "e0d8bf"),
        "terminal.ansiBrightBlack": hex_css(colours.get("term8") or muted, "a9a290"),
        "terminal.ansiBrightRed": hex_css(colours.get("term9") or colours.get("errorContainer"), "d1a200"),
        "terminal.ansiBrightGreen": hex_css(colours.get("term10") or colours.get("successContainer"), "eee145"),
        "terminal.ansiBrightYellow": hex_css(colours.get("term11") or colours.get("tertiaryContainer"), "fff4cb"),
        "terminal.ansiBrightBlue": hex_css(colours.get("term12") or colours.get("primaryFixed"), "c0c49a"),
        "terminal.ansiBrightMagenta": hex_css(colours.get("term13") or colours.get("secondaryFixed"), "e2b967"),
        "terminal.ansiBrightCyan": hex_css(colours.get("term14") or colours.get("secondaryFixedDim"), "e0e07e"),
        "terminal.ansiBrightWhite": hex_css(colours.get("term15") or colours.get("inverseSurface"), "ffffff"),
        "errorForeground": system_status,
    }
    settings["workbench.colorTheme"] = "Default Light Modern" if light else "Dark Modern"
    settings["editor.tokenColorCustomizations"] = {
        "comments": muted,
        "textMateRules": [
            {
                "scope": ["keyword", "storage.type", "storage.modifier"],
                "settings": {"foreground": accent},
            },
            {
                "scope": ["string", "string.quoted"],
                "settings": {"foreground": hex_css(colours.get("tertiary"), "ffd27a")},
            },
            {
                "scope": ["entity.name.function", "support.function"],
                "settings": {"foreground": hex_css(colours.get("primary"), "ffffff")},
            },
            {
                "scope": ["constant.numeric", "constant.language"],
                "settings": {"foreground": hex_css(colours.get("tertiary") or colours.get("secondary"), "ffd27a")},
            },
        ],
    }
    write_file(CODE_SETTINGS_PATH, json.dumps(settings, indent=4) + "\n")


def render_codex_extension(colours: dict[str, str]) -> None:
    accent = hex_css(colours.get("secondary") or colours.get("primary"), "d3c876")
    accent_soft = rgba_css(colours.get("secondary") or colours.get("primary"), 0.16, "d3c876")
    accent_medium = rgba_css(colours.get("secondary") or colours.get("primary"), 0.36, "d3c876")
    accent_border = rgba_css(colours.get("secondary") or colours.get("primary"), 0.44, "d3c876")

    replacements = {
        "--red-50": accent_soft,
        "--red-300": accent,
        "--red-400": accent,
        "--red-500": accent,
        "--red-600": accent,
        "--red-900": accent_soft,
        "--color-red-500": accent,
        "--color-accent-red": accent,
        "--color-token-charts-red": accent,
        "--color-text-error": accent,
        "--color-icon-error": accent,
        "--color-border-error": accent_border,
        "--color-background-status-error": accent_soft,
        "--color-background-danger-active": accent_medium,
        "--color-editor-deleted": accent_soft,
        "--color-decoration-deleted": accent,
    }

    literal_replacements = {
        "#fb2c361a": accent_soft,
        "#fa423e3b": accent_soft,
    }

    for path in HOME.glob(CODEX_EXTENSION_CSS_GLOB):
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue

        updated = text
        for name, value in replacements.items():
            updated = re.sub(
                rf"{re.escape(name)}:[^;}}]+",
                f"{name}:{value}",
                updated,
            )
        for old, new in literal_replacements.items():
            updated = updated.replace(old, new)

        if updated != text:
            write_file(path, updated)


def sync_once() -> bool:
    data = load_scheme()
    if not data:
        return False

    colours = data.get("colours")
    if not isinstance(colours, dict):
        return False

    # Cursor first, because humans apparently notice pointers before Steam CSS.
    render_cursor_theme(colours)

    render_hyprland(colours)
    render_hyprlock(colours)
    render_gtk(colours)
    render_rofi(colours)
    render_shell_theme(colours)
    render_foot(colours)
    render_zen(colours)
    render_kde(colours)
    render_spicetify(colours)
    render_steam(colours)
    render_zed(colours)
    ensure_discord_theme_targets()
    for path in DISCORD_THEME_PATHS:
        patch_discord_theme(path, colours)
    render_vscode(colours)
    render_codex_extension(colours)
    return True


def watch(interval: float) -> int:
    last_mtime_ns = None
    while True:
        try:
            mtime_ns = SCHEME_PATH.stat().st_mtime_ns
        except FileNotFoundError:
            mtime_ns = None

        if mtime_ns != last_mtime_ns:
            sync_once()
            last_mtime_ns = mtime_ns

        time.sleep(max(interval, 0.2))


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync system theme files to the current Caelestia wallpaper palette.")
    parser.add_argument("--cursor-only", action="store_true", help="generate and activate the pending cursor palette")
    parser.add_argument("--watch", action="store_true", help="watch the scheme file and keep syncing on changes")
    parser.add_argument("--interval", type=float, default=0.2, help="poll interval in seconds when watching")
    args = parser.parse_args()

    if args.cursor_only:
        return run_cursor_worker()

    sync_once()
    if args.watch:
        return watch(args.interval)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
