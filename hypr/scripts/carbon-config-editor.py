#!/usr/bin/env python3
"""
Carbon Config Editor — SaneAspect / Tide Island Edition
A modern GTK4 + Libadwaita settings application for Carbon Shell & Hyprland.
Mirrors the clean, category-driven UI with Hero Cards and grouped settings cards.
"""

import os
import sys
import json
import subprocess
import shutil
import re
import threading
import copy

# Ensure fast GTK4 launch without GPU enumeration stalls
os.environ["GSK_RENDERER"] = "cairo"

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Gtk, Adw, Gio, GLib, Gdk, Pango
import time

try:
    from carbon_tile_cropper import (
        ImageCropDialog,
        BLANK_TILE_CONFIG_PATH,
        BLANK_TILE_CROP_PATH,
        BLANK_TILE_HYPR_PATH,
        BLANK_TILE_HYPR_CROP_PATH
    )
except ImportError:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from carbon_tile_cropper import (
        ImageCropDialog,
        BLANK_TILE_CONFIG_PATH,
        BLANK_TILE_CROP_PATH,
        BLANK_TILE_HYPR_PATH,
        BLANK_TILE_HYPR_CROP_PATH
    )

# ── Configuration Paths (Isolated Carbon Runtime with Hypr fallback) ────
CONFIG_DIR = os.environ.get("CARBON_CONFIG_DIR", os.path.expanduser("~/.config/carbon"))
HYPR_DIR = os.path.expanduser("~/.config/hypr")

LOOKNFEEL_CONF_PATH = os.path.join(CONFIG_DIR, "looknfeel.conf")
BAR_MODE_PATH = os.path.join(CONFIG_DIR, "carbon-bar-mode.json")
BAR_POS_PATH = os.path.join(CONFIG_DIR, "carbon-bar-position.json")
CLOCK_STYLE_PATH = os.path.join(CONFIG_DIR, "carbon-clock-style.json")
MOTION_CONFIG_PATH = os.path.join(CONFIG_DIR, "carbon-motion.json")
LAUNCHER_CONFIG_PATH = os.path.join(CONFIG_DIR, "carbon-launcher.json")
NOTIF_CONFIG_PATH = os.path.join(CONFIG_DIR, "carbon-notifications.json")
CONTROL_CONFIG_PATH = os.path.join(CONFIG_DIR, "carbon-control-center.json")
LOCKSCREEN_CONFIG_PATH = os.path.join(CONFIG_DIR, "carbon-lockscreen.json")
VANISH_SHORTCUTS_PATH = os.path.join(CONFIG_DIR, "carbon-vanish-shortcuts.json")
VANISH_KEYBINDS_CONF_PATH = os.path.join(CONFIG_DIR, "vanish-keybinds.conf")
VANISH_DISPATCH_SCRIPT = os.path.join(CONFIG_DIR, "scripts/carbon-vanish-dispatch.sh")
VARIABLES_PATH = os.path.join(CONFIG_DIR, "variables.lua")
THEME_PATH = os.path.join(CONFIG_DIR, "theme.json")
WALLPAPER_SOURCE_PATH = os.path.join(CONFIG_DIR, "carbon-wallpaper-source.json")
BLUR_EXCEPTIONS_JSON = os.path.join(CONFIG_DIR, "carbon-blur-exceptions.json")
BLUR_EXCEPTIONS_CONF = os.path.join(CONFIG_DIR, "blur-exceptions.conf")
POWER_CONFIG_PATH = os.path.join(CONFIG_DIR, "carbon-power.json")
POWER_CONF_PATH = os.path.join(CONFIG_DIR, "power.conf")
HYPRIDLE_CONF_PATH = os.path.join(CONFIG_DIR, "hypridle.conf")
TIDE_USERCONFIG_PATH = os.path.expanduser("~/.config/tide-island/userconfig.json")

DEFAULT_POWER_CONFIG = {
    "profile": "balanced",
    "powerButtonAction": "poweroff",
    "sleepButtonAction": "suspend",
    "lidActionBattery": "suspend",
    "lidActionAC": "suspend",
    "sleepMode": "suspend",
    "hibernationEnabled": True,
    "dimEnabled": True,
    "dimTimeout": 180,
    "dimBrightnessPercent": 20,
    "screenOffTimeout": 300,
    "autoSuspendTimeout": 1800,
}

DEFAULT_VANISH_SHORTCUTS = {
    "hub_toggle": {
        "title": "Toggle Vanish Hub",
        "desc": "Open or close central clock orb and radial satellites",
        "category": "Primary Triggers",
        "mods": "$mainMod",
        "key": "Super_L",
        "display_str": "SUPER",
        "action": "toggle-hub",
        "icon": "view-reveal-symbolic"
    },
    "app_search": {
        "title": "Spotlight & App Search",
        "desc": "Directly open Spotlight Command Palette with keyboard search focus",
        "category": "Primary Triggers",
        "mods": "$mainMod",
        "key": "R",
        "display_str": "SUPER + R",
        "action": "spotlight",
        "icon": "applications-system-symbolic"
    },
    "lyrics_toggle": {
        "title": "Toggle Synced Lyrics",
        "desc": "Morph bottom caption between calendar date and live lyrics",
        "category": "Primary Triggers",
        "mods": "$mainMod",
        "key": "M",
        "display_str": "SUPER + M",
        "action": "lyrics",
        "icon": "media-playback-start-symbolic"
    },
    "wallpaper_ring": {
        "title": "Wallpaper Ring",
        "desc": "Open circular wallpaper gallery lobe",
        "category": "Primary Triggers",
        "mods": "$mainMod",
        "key": "W",
        "display_str": "SUPER + W",
        "action": "wallpaper",
        "icon": "preferences-desktop-wallpaper-symbolic"
    },
    "focus_alerts": {
        "title": "Focus Alerts Lobe",
        "desc": "Directly bloom System Alerts & Notifications satellite",
        "category": "Orbital Satellites",
        "mods": "$mainMod",
        "key": "A",
        "display_str": "SUPER + A",
        "action": "focus-alerts",
        "icon": "preferences-system-notifications-symbolic"
    },
    "focus_connect": {
        "title": "Focus Connect Lobe",
        "desc": "Directly bloom Audio, Network, and Battery satellite",
        "category": "Orbital Satellites",
        "mods": "",
        "key": "",
        "display_str": "Unset",
        "action": "focus-connect",
        "icon": "network-wireless-symbolic"
    },
    "focus_spaces": {
        "title": "Focus Spaces Lobe",
        "desc": "Directly bloom Hyprland Workspaces satellite",
        "category": "Orbital Satellites",
        "mods": "",
        "key": "",
        "display_str": "Unset",
        "action": "focus-spaces",
        "icon": "view-grid-symbolic"
    }
}

DEFAULT_LOOKNFEEL = {
    "gaps_in": 6,
    "gaps_out": 6,
    "border_size": 1,
    "layout": "dwindle",
    "resize_on_border": False,
    "allow_tearing": False,
    "rounding": 15,
    "rounding_power": 2,
    "active_opacity": 0.80,
    "inactive_opacity": 0.95,
    "shadow_enabled": True,
    "shadow_range": 15,
    "shadow_render_power": 3,
    "blur_enabled": True,
    "blur_size": 3,
    "blur_passes": 1,
    "blur_ignore_opacity": True,
    "blur_new_optimizations": True,
    "blur_special": False,
    "blur_popups": True,
    "blur_xray": False,
    "blur_vibrancy": 0.1696,
}


def generate_vanish_keybinds_conf(shortcuts):
    dispatch_path = VANISH_DISPATCH_SCRIPT if os.path.exists(VANISH_DISPATCH_SCRIPT) else os.path.expanduser("~/.config/hypr/scripts/carbon-vanish-dispatch.sh")
    lines = [
        "#################################################################\n",
        "# VANISH MODE DEDICATED SHORTCUTS                               #\n",
        "# Auto-generated by Carbon Config Editor                        #\n",
        "#################################################################\n\n",
        "$mainMod = SUPER\n\n",
    ]
    for key_id, info in shortcuts.items():
        mods = info.get("mods", "").strip()
        key = info.get("key", "").strip()
        action = info.get("action", "").strip()
        if not key or not action:
            continue
        if action == "wallpaper":
            cmd = "sh ~/.config/carbon/scripts/carbon-ipc.sh wallpaper"
        else:
            cmd = f"sh {dispatch_path} {action}"
        if key in ("Super_L", "Super_R"):
            lines.append(f"bindr = $mainMod, Super_L, exec, {cmd}\n")
            lines.append(f"bindr = $mainMod, Super_R, exec, {cmd}\n")
        elif "Alt" in key and ("$mainMod" in mods or "SUPER" in mods):
            lines.append(f"bind = {mods}, {key}, exec, {cmd}\n")
            lines.append(f"bind = {mods}, Alt_R, exec, {cmd}\n")
            lines.append(f"bind = ALT, Super_L, exec, {cmd}\n")
            lines.append(f"bind = ALT, Super_R, exec, {cmd}\n")
        else:
            if mods:
                lines.append(f"bind = {mods}, {key}, exec, {cmd}\n")
            else:
                lines.append(f"bind = , {key}, exec, {cmd}\n")
    try:
        os.makedirs(os.path.dirname(VANISH_KEYBINDS_CONF_PATH), exist_ok=True)
        with open(VANISH_KEYBINDS_CONF_PATH, "w", encoding="utf-8") as f:
            f.writelines(lines)
    except Exception as e:
        print("Error writing vanish-keybinds.conf:", e, file=sys.stderr)

def read_json(path, default=None):
    if default is None:
        default = {}
    candidates = [path]
    basename = os.path.basename(path)
    hypr_alt = os.path.join(HYPR_DIR, basename)
    if hypr_alt not in candidates:
        candidates.append(hypr_alt)
    for c in candidates:
        if os.path.exists(c):
            try:
                with open(c, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass
    return default

def write_json(path, data):
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
    except Exception as e:
        print(f"Error saving {path}: {e}", file=sys.stderr)

def read_variables():
    data = {}
    if os.path.exists(VARIABLES_PATH):
        try:
            with open(VARIABLES_PATH, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if "=" in line and not line.startswith("--"):
                        k, v = line.split("=", 1)
                        k = k.strip().replace("local ", "")
                        v = v.strip().rstrip(",;").strip('"\'')
                        data[k] = v
        except Exception:
            pass
    return data

def write_variable(key, val):
    if not os.path.exists(VARIABLES_PATH):
        return
    try:
        with open(VARIABLES_PATH, "r", encoding="utf-8") as f:
            lines = f.readlines()
        new_lines = []
        found = False
        for line in lines:
            stripped = line.strip()
            if stripped.startswith(key + " ") or stripped.startswith(key + "=") or stripped.startswith("local " + key):
                if isinstance(val, (int, float)):
                    new_lines.append(f"{key} = {val}\n")
                elif isinstance(val, bool):
                    new_lines.append(f"{key} = {'true' if val else 'false'}\n")
                else:
                    new_lines.append(f'{key} = "{val}"\n')
                found = True
            else:
                new_lines.append(line)
        if not found:
            if isinstance(val, (int, float)):
                new_lines.append(f"{key} = {val}\n")
            elif isinstance(val, bool):
                new_lines.append(f"{key} = {'true' if val else 'false'}\n")
            else:
                new_lines.append(f'{key} = "{val}"\n')
        with open(VARIABLES_PATH, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
    except Exception as e:
        print(f"Error updating variables.lua: {e}", file=sys.stderr)

def apply_hyprland_layer_blur(enable: bool):
    blur_conf = os.path.expanduser("~/.config/hypr/configs/carbon-layer-blur.conf")
    try:
        os.makedirs(os.path.dirname(blur_conf), exist_ok=True)
        with open(blur_conf, "w", encoding="utf-8") as f:
            if enable:
                f.write(
                    "layerrule = blur, carbon-.*\n"
                    "layerrule = ignorezero, carbon-.*\n"
                    "layerrule = blur, quickshell\n"
                    "layerrule = ignorezero, quickshell\n"
                    "layerrule = blur, tide-island\n"
                    "layerrule = ignorezero, tide-island\n"
                )
            else:
                f.write("# blur disabled\n")
    except Exception as e:
        print(f"Error updating layer blur: {e}", file=sys.stderr)

def is_layer_blur_enabled():
    try:
        bp = read_json(BAR_POS_PATH, {})
        if "shellBlur" in bp:
            return bool(bp["shellBlur"])
    except Exception:
        pass
    blur_conf = os.path.expanduser("~/.config/hypr/configs/carbon-layer-blur.conf")
    if os.path.exists(blur_conf):
        try:
            with open(blur_conf, "r", encoding="utf-8") as f:
                content = f.read()
            return "layerrule = blur" in content
        except Exception:
            pass
    return True

def read_looknfeel_config():
    data = dict(DEFAULT_LOOKNFEEL)
    path = LOOKNFEEL_CONF_PATH
    if not os.path.exists(path):
        alt = os.path.expanduser("~/.config/hypr/configs/looknfeel.conf")
        if os.path.exists(alt):
            path = alt
        else:
            alt2 = os.path.expanduser("~/carbon-shell/hypr/looknfeel.conf")
            if os.path.exists(alt2):
                path = alt2
            else:
                return data

    try:
        current_sections = []
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "{" in line:
                    sec_name = line.split("{")[0].strip()
                    current_sections.append(sec_name)
                    continue
                if "}" in line:
                    if current_sections:
                        current_sections.pop()
                    continue
                if "=" in line:
                    k, v = line.split("=", 1)
                    k = k.strip()
                    v = v.split("#")[0].strip()

                    def parse_val(val_str):
                        if val_str.lower() in ("true", "yes", "on"):
                            return True
                        elif val_str.lower() in ("false", "no", "off"):
                            return False
                        try:
                            if "." in val_str:
                                return float(val_str)
                            return int(val_str)
                        except ValueError:
                            return val_str

                    val = parse_val(v)
                    context = ":".join(current_sections)
                    if "shadow" in context:
                        data[f"shadow_{k}"] = val
                    elif "blur" in context:
                        data[f"blur_{k}"] = val
                    else:
                        data[k] = val
    except Exception as e:
        print(f"Error reading looknfeel.conf: {e}", file=sys.stderr)
    return data

def write_looknfeel_config(data):
    gaps_in = int(data.get("gaps_in", 6))
    gaps_out = int(data.get("gaps_out", 6))
    border_size = int(data.get("border_size", 1))
    layout = str(data.get("layout", "dwindle"))
    resize_on_border = "true" if data.get("resize_on_border", False) else "false"
    allow_tearing = "true" if data.get("allow_tearing", False) else "false"

    rounding = int(data.get("rounding", 15))
    rounding_power = int(data.get("rounding_power", 2))
    active_opacity = float(data.get("active_opacity", 0.80))
    inactive_opacity = float(data.get("inactive_opacity", 0.95))

    shadow_enabled = "true" if data.get("shadow_enabled", True) else "false"
    shadow_range = int(data.get("shadow_range", 15))
    shadow_render_power = int(data.get("shadow_render_power", 3))

    blur_enabled = "true" if data.get("blur_enabled", True) else "false"
    blur_size = int(data.get("blur_size", 3))
    blur_passes = int(data.get("blur_passes", 1))
    blur_ignore_opacity = "true" if data.get("blur_ignore_opacity", True) else "false"
    blur_new_optimizations = "true" if data.get("blur_new_optimizations", True) else "false"
    blur_special = "true" if data.get("blur_special", False) else "false"
    blur_popups = "true" if data.get("blur_popups", True) else "false"
    blur_xray = "true" if data.get("blur_xray", False) else "false"
    blur_vibrancy = float(data.get("blur_vibrancy", 0.1696))

    content = f"""# ==============================================================================
# Carbon Shell — Hyprland Look & Feel Configuration
# Managed automatically by Carbon Settings App
# ==============================================================================

# Dynamic Material You Theme Colors
source = ~/.config/carbon/colors.conf

general {{
    gaps_in = {gaps_in}
    gaps_out = {gaps_out}

    border_size = {border_size}

    col.active_border = $outline
    col.inactive_border = $outline_variant

    # Set to true enable resizing windows by clicking and dragging on borders and gaps
    resize_on_border = {resize_on_border}

    # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
    allow_tearing = {allow_tearing}

    layout = {layout}
}}

# https://wiki.hyprland.org/Configuring/Variables/#decoration
decoration {{
    rounding = {rounding}
    rounding_power = {rounding_power}

    # Change transparency of focused and unfocused windows
    active_opacity = {active_opacity:.2f}
    inactive_opacity = {inactive_opacity:.2f}

    shadow {{
        enabled = {shadow_enabled}
        range = {shadow_range}
        render_power = {shadow_render_power}
        color = rgba(1a1a1aee)
    }}

    # https://wiki.hyprland.org/Configuring/Variables/#blur
    blur {{
        enabled = {blur_enabled}
        size = {blur_size}
        passes = {blur_passes}
        ignore_opacity = {blur_ignore_opacity}
        new_optimizations = {blur_new_optimizations}
        special = {blur_special}
        popups = {blur_popups}
        xray = {blur_xray}

        vibrancy = {blur_vibrancy:.4f}
    }}
}}
"""
    targets = [
        LOOKNFEEL_CONF_PATH,
        os.path.expanduser("~/.config/hypr/configs/looknfeel.conf"),
        os.path.expanduser("~/carbon-shell/hypr/looknfeel.conf"),
    ]
    for target in targets:
        try:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "w", encoding="utf-8") as f:
                f.write(content)
        except Exception as e:
            pass

    gui_lua = os.path.expanduser("~/.config/hypr/hyprland-gui.lua")
    if os.path.isfile(gui_lua):
        try:
            with open(gui_lua, "r", encoding="utf-8") as f:
                c = f.read()
            c = re.sub(r"(size\s*=\s*)\d+", rf"\g<1>{blur_size}", c)
            c = re.sub(r"(passes\s*=\s*)\d+", rf"\g<1>{blur_passes}", c)
            c = re.sub(r"(xray\s*=\s*)(true|false)", rf"\g<1>{'true' if blur_xray == 'true' else 'false'}", c)
            c = re.sub(r"(enabled\s*=\s*)(true|false)", rf"\g<1>{'true' if blur_enabled == 'true' else 'false'}", c)
            with open(gui_lua, "w", encoding="utf-8") as f:
                f.write(c)
        except Exception:
            pass

def apply_hyprland_looknfeel_live(cfg):
    keywords = [
        ("general:gaps_in", str(int(cfg.get("gaps_in", 6)))),
        ("general:gaps_out", str(int(cfg.get("gaps_out", 6)))),
        ("general:border_size", str(int(cfg.get("border_size", 1)))),
        ("general:layout", str(cfg.get("layout", "dwindle"))),
        ("general:resize_on_border", "true" if cfg.get("resize_on_border", False) else "false"),
        ("general:allow_tearing", "true" if cfg.get("allow_tearing", False) else "false"),
        ("decoration:rounding", str(int(cfg.get("rounding", 15)))),
        ("decoration:rounding_power", str(int(cfg.get("rounding_power", 2)))),
        ("decoration:active_opacity", f"{float(cfg.get('active_opacity', 0.80)):.2f}"),
        ("decoration:inactive_opacity", f"{float(cfg.get('inactive_opacity', 0.95)):.2f}"),
        ("decoration:shadow:enabled", "true" if cfg.get("shadow_enabled", True) else "false"),
        ("decoration:shadow:range", str(int(cfg.get("shadow_range", 15)))),
        ("decoration:shadow:render_power", str(int(cfg.get("shadow_render_power", 3)))),
        ("decoration:blur:enabled", "true" if cfg.get("blur_enabled", True) else "false"),
        ("decoration:blur:size", str(int(cfg.get("blur_size", 3)))),
        ("decoration:blur:passes", str(int(cfg.get("blur_passes", 1)))),
        ("decoration:blur:ignore_opacity", "true" if cfg.get("blur_ignore_opacity", True) else "false"),
        ("decoration:blur:new_optimizations", "true" if cfg.get("blur_new_optimizations", True) else "false"),
        ("decoration:blur:special", "true" if cfg.get("blur_special", False) else "false"),
        ("decoration:blur:popups", "true" if cfg.get("blur_popups", True) else "false"),
        ("decoration:blur:xray", "true" if cfg.get("blur_xray", False) else "false"),
        ("decoration:blur:vibrancy", f"{float(cfg.get('blur_vibrancy', 0.1696)):.4f}"),
    ]
    for key, val in keywords:
        subprocess.run(["hyprctl", "keyword", key, val], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["hyprctl", "reload"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def write_blur_exceptions_config(exceptions):
    lines = [
        "# ==============================================================================\n",
        "# Carbon Shell — Hyprland Blur & Opacity App Exceptions\n",
        "# Auto-generated by Carbon Settings App\n",
        "# ==============================================================================\n\n"
    ]
    for item in exceptions:
        cls = item.get("class", "").strip()
        if not cls:
            continue
        pattern = cls if cls.startswith("^") else f"^({cls})$"
        lines.append(f"windowrule = no_blur on, match:class {pattern}\n")
        lines.append(f"windowrule = opacity 1.0 override 1.0 override, match:class {pattern}\n\n")

    targets = [
        BLUR_EXCEPTIONS_CONF,
        os.path.expanduser("~/carbon-shell/hypr/blur-exceptions.conf"),
        os.path.expanduser("~/.config/hypr/configs/blur-exceptions.conf"),
    ]
    for t in targets:
        try:
            os.makedirs(os.path.dirname(t), exist_ok=True)
            with open(t, "w", encoding="utf-8") as f:
                f.writelines(lines)
        except Exception as e:
            pass

def generate_hypridle_conf(power_cfg):
    dim_enabled = bool(power_cfg.get("dimEnabled", True))
    dim_timeout = int(power_cfg.get("dimTimeout", 180))
    dim_pct = int(power_cfg.get("dimBrightnessPercent", 20))
    screen_off_timeout = int(power_cfg.get("screenOffTimeout", 300))
    auto_suspend_timeout = int(power_cfg.get("autoSuspendTimeout", 1800))

    lines = [
        "# ==============================================================================",
        "# Carbon Shell — Hypridle Configuration",
        "# Managed by Carbon Settings App (carbon-config-editor)",
        "# ==============================================================================",
        "",
        "general {",
        "    lock_cmd = ~/.config/hypr/scripts/hyprlock.sh",
        "    before_sleep_cmd = loginctl lock-session",
        "    after_sleep_cmd = hyprctl dispatch dpms on",
        "}",
        "",
    ]

    if dim_enabled and dim_timeout > 0:
        lines.extend([
            "# === MONITOR BACKLIGHT DIM ===",
            "listener {",
            f"    timeout = {dim_timeout}",
            f"    on-timeout = brightnessctl -s set {dim_pct}%",
            "    on-resume = brightnessctl -r",
            "}",
            "",
        ])

    if screen_off_timeout > 0:
        lines.extend([
            "# === TURN OFF SCREEN ===",
            "listener {",
            f"    timeout = {screen_off_timeout}",
            "    on-timeout = hyprctl dispatch dpms off",
            "    on-resume = hyprctl dispatch dpms on && brightnessctl -r",
            "}",
            "",
        ])

    if auto_suspend_timeout > 0:
        lines.extend([
            "# === AUTO SUSPEND ===",
            "listener {",
            f"    timeout = {auto_suspend_timeout}",
            "    on-timeout = systemctl suspend",
            "}",
            "",
        ])

    return "\n".join(lines) + "\n"

def write_power_configs(power_cfg):
    targets_json = [
        POWER_CONFIG_PATH,
        os.path.expanduser("~/.config/hypr/carbon-power.json"),
        os.path.expanduser("~/carbon-shell/hypr/carbon-power.json"),
    ]
    for t in targets_json:
        try:
            write_json(t, power_cfg)
        except Exception:
            pass

    power_conf_content = (
        "# ==============================================================================\n"
        "# Carbon Shell — Power, Button & Lid Event Bindings\n"
        "# Managed by Carbon Settings App (carbon-config-editor)\n"
        "# ==============================================================================\n\n"
        "# Physical Power & Sleep Buttons\n"
        "bind = , XF86PowerOff, exec, ~/.config/carbon/scripts/carbon-power-handler.sh power_button\n"
        "bind = , XF86Sleep, exec, ~/.config/carbon/scripts/carbon-power-handler.sh sleep_button\n\n"
        "# Laptop Lid Switch Events (switch:on = closed, switch:off = opened)\n"
        "bindl = , switch:on:Lid Switch, exec, ~/.config/carbon/scripts/carbon-power-handler.sh lid_close\n"
        "bindl = , switch:off:Lid Switch, exec, ~/.config/carbon/scripts/carbon-power-handler.sh lid_open\n"
    )
    targets_conf = [
        POWER_CONF_PATH,
        os.path.expanduser("~/.config/hypr/power.conf"),
        os.path.expanduser("~/carbon-shell/hypr/power.conf"),
    ]
    for t in targets_conf:
        try:
            os.makedirs(os.path.dirname(t), exist_ok=True)
            with open(t, "w", encoding="utf-8") as f:
                f.write(power_conf_content)
        except Exception:
            pass

    hypridle_content = generate_hypridle_conf(power_cfg)
    targets_idle = [
        HYPRIDLE_CONF_PATH,
        os.path.expanduser("~/.config/hypr/hypridle.conf"),
        os.path.expanduser("~/carbon-shell/hypr/hypridle.conf"),
    ]
    for t in targets_idle:
        try:
            os.makedirs(os.path.dirname(t), exist_ok=True)
            with open(t, "w", encoding="utf-8") as f:
                f.write(hypridle_content)
        except Exception:
            pass

    pwr_file = os.path.join(CONFIG_DIR, "power-profile")
    if os.path.exists(pwr_file):
        try:
            with open(pwr_file, "r") as pf:
                cur = pf.read().strip()
            if cur:
                power_cfg["profile"] = cur
        except Exception:
            pass

    profile = power_cfg.get("profile", "balanced")
    pwr_script = os.path.join(CONFIG_DIR, "scripts/carbon-power-profile.sh")
    if not os.path.exists(pwr_script):
        pwr_script = os.path.expanduser("~/.config/hypr/scripts/carbon-power-profile.sh")
    if os.path.exists(pwr_script):
        subprocess.run(["bash", pwr_script, "set", profile], check=False)

    try:
        subprocess.run(["pkill", "-x", "hypridle"], check=False)
        subprocess.Popen(["hypridle", "-c", HYPRIDLE_CONF_PATH], start_new_session=True)
    except Exception:
        pass

def get_device_applications():
    apps = []
    seen = set()

    # 1. Currently active windows in Hyprland
    try:
        res = subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, check=False)
        clients = json.loads(res.stdout)
        for c in clients:
            cls = c.get("class", "").strip()
            title = c.get("title", "").strip()
            if not cls or cls in seen:
                continue
            seen.add(cls)
            apps.append({
                "name": title if title and len(title) < 40 else cls,
                "class": cls,
                "icon": "application-x-executable",
                "running": True
            })
    except Exception:
        pass

    # 2. Installed applications from system desktop files
    for app in Gio.AppInfo.get_all():
        if not app.should_show():
            continue
        app_id = app.get_id()
        if not app_id:
            continue

        name = app.get_display_name()
        icon = app.get_icon()
        icon_name = icon.to_string() if icon else "application-x-executable"

        wm_class = None
        for path in [
            os.path.expanduser("~/.local/share/applications/" + app_id),
            "/usr/share/applications/" + app_id,
            "/usr/local/share/applications/" + app_id,
            "/var/lib/flatpak/exports/share/applications/" + app_id,
            os.path.expanduser("~/.local/share/flatpak/exports/share/applications/" + app_id),
        ]:
            if os.path.exists(path):
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as f:
                        for line in f:
                            if line.startswith("StartupWMClass="):
                                wm_class = line.split("=", 1)[1].strip()
                                break
                except Exception:
                    pass
                if wm_class:
                    break

        if not wm_class:
            if app_id.endswith(".desktop"):
                wm_class = app_id[:-8]
            else:
                exe = app.get_executable()
                wm_class = os.path.basename(exe) if exe else app_id

        if wm_class not in seen:
            seen.add(wm_class)
            apps.append({
                "name": name,
                "class": wm_class,
                "icon": icon_name,
                "running": False
            })

    return sorted(apps, key=lambda x: (not x.get("running", False), x["name"].lower()))

class AppPickerWindow(Adw.Window):
    def __init__(self, parent_window, on_app_selected):
        super().__init__()
        self.set_transient_for(parent_window)
        self.set_modal(True)
        self.set_title("Add App Exception")
        self.set_default_size(480, 560)
        self.on_app_selected = on_app_selected

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(box)

        # Header bar
        header = Adw.HeaderBar()
        header.set_show_end_title_buttons(True)
        header.set_title_widget(Gtk.Label(label="Add App Exception", css_classes=["heading"]))
        box.append(header)

        # Content container
        content_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        content_box.set_margin_start(16)
        content_box.set_margin_end(16)
        content_box.set_margin_top(12)
        content_box.set_margin_bottom(16)
        content_box.set_vexpand(True)
        box.append(content_box)

        # Search Entry
        search_entry = Gtk.SearchEntry()
        search_entry.set_placeholder_text("Search apps or running windows…")
        search_entry.add_css_class("search-entry")
        content_box.append(search_entry)

        # Scrolled List
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_vexpand(True)
        content_box.append(scrolled)

        self.listbox = Gtk.ListBox()
        self.listbox.set_selection_mode(Gtk.SelectionMode.NONE)
        self.listbox.add_css_class("settings-card")
        scrolled.set_child(self.listbox)

        # Manual / Custom class entry at bottom
        custom_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        custom_box.set_margin_top(6)

        self.custom_entry = Gtk.Entry()
        self.custom_entry.set_placeholder_text("Custom class (e.g. mpv, zen, steam_app_.*)")
        self.custom_entry.set_hexpand(True)
        custom_box.append(self.custom_entry)

        add_custom_btn = Gtk.Button(label="Add Custom")
        add_custom_btn.add_css_class("suggested-action")
        def on_add_custom(b):
            text = self.custom_entry.get_text().strip()
            if text:
                self.on_app_selected({
                    "name": text,
                    "class": text,
                    "icon": "application-x-executable"
                })
                self.destroy()
        add_custom_btn.connect("clicked", on_add_custom)
        self.custom_entry.connect("activate", lambda e: on_add_custom(None))
        custom_box.append(add_custom_btn)
        content_box.append(custom_box)

        # Populate list
        self.apps = get_device_applications()
        self.app_rows = []
        for app_info in self.apps:
            row = Gtk.ListBoxRow()
            row.app_info = app_info
            row.add_css_class("settings-row")

            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            row_box.set_margin_start(8)
            row_box.set_margin_end(8)
            row_box.set_margin_top(6)
            row_box.set_margin_bottom(6)

            # Icon
            img = Gtk.Image.new_from_icon_name(app_info.get("icon", "application-x-executable"))
            img.set_pixel_size(24)
            img.set_valign(Gtk.Align.CENTER)
            row_box.append(img)

            # Labels
            lb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            lb.set_hexpand(True)
            lb.set_valign(Gtk.Align.CENTER)

            title_lbl = Gtk.Label(label=app_info.get("name", ""))
            title_lbl.set_halign(Gtk.Align.START)
            title_lbl.add_css_class("row-title")
            lb.append(title_lbl)

            sub_text = f"Class: {app_info.get('class', '')}"
            if app_info.get("running"):
                sub_text += " • Running Window"
            sub_lbl = Gtk.Label(label=sub_text)
            sub_lbl.set_halign(Gtk.Align.START)
            sub_lbl.add_css_class("row-subtitle")
            lb.append(sub_lbl)

            row_box.append(lb)

            # Add Button
            btn = Gtk.Button(label="Add")
            btn.set_valign(Gtk.Align.CENTER)
            btn.add_css_class("suggested-action")
            def make_handler(info):
                return lambda b: (self.on_app_selected(info), self.destroy())
            btn.connect("clicked", make_handler(app_info))
            row_box.append(btn)

            row.set_child(row_box)
            self.listbox.append(row)
            self.app_rows.append((row, app_info))

        def on_search(entry):
            query = entry.get_text().strip().lower()
            for row, info in self.app_rows:
                match = not query or (query in info.get("name", "").lower()) or (query in info.get("class", "").lower())
                row.set_visible(match)

        search_entry.connect("search-changed", on_search)

# ── Config App Window ────────────────────────────────────────────────────
class CarbonConfigApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="org.carbon.configeditor", flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.connect("activate", self.on_activate)

    def on_activate(self, app):
        win = self.props.active_window
        if not win:
            win = ConfigEditorWindow(self)
        win.present()

class ConfigEditorWindow(Adw.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Settings")
        self.set_default_size(980, 620)
        self.set_size_request(740, 480)

        # Theme & Accent
        theme = read_json(THEME_PATH, {})
        self.accent_hex = theme.get("accent", "#f4a7b5")
        self.accent_lit = theme.get("accentLit", "#fcd5dc")
        self.theme_mode = theme.get("mode", "dark" if theme.get("isDark", True) else "light")
        self.is_dark = (self.theme_mode == "dark")
        self.theme_mode_btn_pairs = []

        # Loaded Configs
        self.bar_mode = read_json(BAR_MODE_PATH, {"mode": "notch", "islandStyle": "notch"})
        self.bar_pos = read_json(BAR_POS_PATH, {})
        self.tide_config = read_json(TIDE_USERCONFIG_PATH, {})
        self.clock_cfg = read_json(CLOCK_STYLE_PATH, {"style": "titan", "format": "12"})
        self.motion_cfg = read_json(MOTION_CONFIG_PATH, {
            "reduceMotion": False,
            "movementDuration": 400,
            "fadeDuration": 200,
            "hoverResponse": 150,
            "bounce": 40
        })
        self.launcher_cfg = read_json(LAUNCHER_CONFIG_PATH, {
            "animationSpeed": 170,
            "showRecents": True,
            "clipboardHistory": True,
            "maxResults": 8
        })
        self.notif_cfg = read_json(NOTIF_CONFIG_PATH, {
            "enabled": True,
            "dnd": False,
            "timeout": 5,
            "compactIsland": True
        })
        self.control_cfg = read_json(CONTROL_CONFIG_PATH, {
            "volumeStep": 5,
            "brightnessStep": 5,
            "showBatteryPercent": True,
            "showQuickToggles": True
        })
        self.lock_cfg = read_json(LOCKSCREEN_CONFIG_PATH, {
            "layout": "modern",
            "blurRadius": 10,
            "showMedia": True
        })
        self.vanish_shortcuts = read_json(VANISH_SHORTCUTS_PATH, {})
        for k, v in DEFAULT_VANISH_SHORTCUTS.items():
            if k not in self.vanish_shortcuts:
                self.vanish_shortcuts[k] = v
        if not self.bar_mode.get("nucleus"):
            self.bar_mode["nucleus"] = {"transition": True, "animation": "quantum", "transitionWord": "Wooshh!!", "showRestingAtom": True}
        if "showRestingAtom" not in self.bar_mode.get("nucleus", {}):
            self.bar_mode.setdefault("nucleus", {})["showRestingAtom"] = True
        if "musicVisualizer" not in self.bar_mode:
            self.bar_mode["musicVisualizer"] = "liquidHalo"
        self.wallpaper_source_cfg = read_json(WALLPAPER_SOURCE_PATH, {
            "provider": "unsplash",
            "unsplash_access_key": ""
        })
        if "provider" not in self.wallpaper_source_cfg:
            self.wallpaper_source_cfg["provider"] = "unsplash"
        self.tile_cfg = read_json(BLANK_TILE_CONFIG_PATH, {
            "enabled": False,
            "imagePath": "",
            "cropPath": "",
            "cropRect": {"x": 0, "y": 0, "width": 0, "height": 0},
            "opacity": 1.0,
            "timestamp": 0
        })
        self.var_data = read_variables()
        self.looknfeel_cfg = read_looknfeel_config()
        self.power_cfg = read_json(POWER_CONFIG_PATH, DEFAULT_POWER_CONFIG.copy())
        if not isinstance(self.power_cfg, dict):
            self.power_cfg = DEFAULT_POWER_CONFIG.copy()
        for k, v in DEFAULT_POWER_CONFIG.items():
            if k not in self.power_cfg:
                self.power_cfg[k] = v

        profile_file = os.path.join(CONFIG_DIR, "power-profile")
        if os.path.exists(profile_file):
            try:
                with open(profile_file, "r", encoding="utf-8") as f:
                    cur_p = f.read().strip()
                    if cur_p in ("power-saver", "balanced", "performance", "ultra"):
                        self.power_cfg["profile"] = cur_p
            except Exception:
                pass

        self.blur_exceptions = read_json(BLUR_EXCEPTIONS_JSON, [])
        if not isinstance(self.blur_exceptions, list):
            self.blur_exceptions = []

        self.pending_layer_blur = None

        # Deferred Save State Tracking
        self.is_building_ui = True
        self.dirty = False

        # Navigation History
        self.nav_history = []
        self.history_index = -1
        self.is_navigating = False

        # Search Index & Highlighting
        self.search_index = []
        self.current_cat_id = None
        self._active_highlight_widget = None
        self._highlight_timer_id = 0

        self.apply_css()
        self.build_ui()

        # Connect window close intercept for unsaved changes confirmation
        self.connect("close-request", self.on_close_requested)

        # End of initial setup
        self.is_building_ui = False
        self.dirty = False
        self.lbl_status.set_text("")
        self.apply_btn.set_sensitive(False)

    def accent_rgba(self, alpha=1.0):
        h = self.accent_hex.lstrip("#")
        try:
            if len(h) == 6:
                r, g, b = tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
                return f"rgba({r}, {g}, {b}, {alpha})"
            elif len(h) == 8:
                r, g, b = tuple(int(h[i:i+2], 16) for i in (0, 2, 4))
                return f"rgba({r}, {g}, {b}, {alpha})"
        except Exception:
            pass
        return f"rgba(225, 182, 142, {alpha})"

    def mark_dirty(self):
        if self.is_building_ui:
            return
        self.dirty = True
        self.lbl_status.set_text("• Unsaved changes")
        self.apply_btn.set_sensitive(True)
        self.apply_btn.add_css_class("suggested-action")

    def apply_css(self):
        is_light = getattr(self, "theme_mode", "dark") == "light"
        win_bg = "#f6f7fa" if is_light else "#0c0c10"
        win_fg = "#191c20" if is_light else "#e2e2e9"
        sidebar_bg = "#eeeff4" if is_light else "#08080c"
        card_bg = "#ffffff" if is_light else "#131318"
        border_col = "rgba(0, 0, 0, 0.08)" if is_light else "rgba(255, 255, 255, 0.07)"
        row_border = "rgba(0, 0, 0, 0.05)" if is_light else "rgba(255, 255, 255, 0.04)"
        sub_fg = "rgba(0, 0, 0, 0.55)" if is_light else "rgba(255, 255, 255, 0.45)"
        title_fg = "#111418" if is_light else "#f0f0f5"
        search_bg = "rgba(0, 0, 0, 0.04)" if is_light else "rgba(255, 255, 255, 0.05)"
        search_fg = "#111418" if is_light else "#ffffff"

        css = f"""
        window {{
            background-color: {win_bg};
            color: {win_fg};
        }}
        .sidebar-container {{
            background-color: {sidebar_bg};
            border-right: 1px solid {border_col};
            padding: 12px 8px;
        }}
        .search-entry {{
            background-color: {search_bg};
            border: 1px solid {border_col};
            border-radius: 12px;
            color: {search_fg};
            padding: 6px 10px;
            margin-bottom: 8px;
        }}
        .search-entry:focus {{
            border-color: {self.accent_hex};
            background-color: {search_bg};
        }}
        .nav-item-row {{
            border-radius: 12px;
            padding: 6px 10px;
            margin: 2px 4px;
            transition: all 120ms ease;
        }}
        .nav-item-row:hover {{
            background-color: {border_col};
        }}
        .nav-item-row:selected {{
            background-color: {self.accent_rgba(0.12)};
            color: {self.accent_hex};
        }}
        .nav-item-row:selected label {{
            color: {self.accent_hex};
            font-weight: 600;
        }}
        .nav-icon-badge {{
            background-color: {border_col};
            border-radius: 16px;
            min-width: 28px;
            min-height: 28px;
        }}
        .hero-card {{
            background-color: {card_bg};
            border: 1px solid {border_col};
            border-radius: 14px;
            padding: 12px 18px;
            margin-bottom: 10px;
            min-width: 0;
        }}
        .hero-icon-circle {{
            background-color: {self.accent_rgba(0.14)};
            border-radius: 18px;
            min-width: 38px;
            min-height: 38px;
        }}
        .hero-title {{
            font-size: 17px;
            font-weight: 700;
            color: {title_fg};
            margin-top: 4px;
        }}
        .hero-subtitle {{
            font-size: 12px;
            color: {sub_fg};
            margin-top: 2px;
        }}
        .settings-card {{
            background-color: {card_bg};
            border: 1px solid {border_col};
            border-radius: 14px;
            padding: 10px 18px;
            margin-bottom: 10px;
            min-width: 0;
        }}
        .settings-row {{
            padding: 5px 0px;
            border-bottom: 1px solid {row_border};
            min-width: 0;
            border-radius: 10px;
            transition: all 200ms ease;
        }}
        .settings-row:last-child {{
            border-bottom: none;
        }}
        .highlight-setting-row {{
            background-color: {self.accent_rgba(0.20)};
            border: 1.5px solid {self.accent_hex};
            padding: 6px 12px;
        }}
        .search-sub-item-btn {{
            background-color: transparent;
            border: none;
            border-radius: 8px;
            padding: 4px 8px;
            margin: 1px 0px;
            transition: all 120ms ease;
        }}
        .search-sub-item-btn:hover {{
            background-color: {border_col};
        }}
        .sub-arrow-lbl {{
            font-size: 11px;
            color: {self.accent_hex};
        }}
        .sub-title-lbl {{
            font-size: 11px;
            color: {sub_fg};
        }}
        .match-count-badge {{
            background-color: {self.accent_rgba(0.15)};
            color: {self.accent_hex};
            border: 1px solid {self.accent_rgba(0.3)};
            font-size: 10px;
            font-weight: 700;
            border-radius: 10px;
            padding: 2px 7px;
        }}
        .row-title {{
            font-size: 13px;
            font-weight: 600;
            color: {title_fg};
        }}
        .row-subtitle {{
            font-size: 11px;
            color: {sub_fg};
        }}
        .value-label {{
            font-size: 12px;
            font-weight: 600;
            color: {self.accent_hex};
            min-width: 60px;
        }}
        .nav-circle-btn {{
            background-color: {border_col};
            border-radius: 16px;
            min-width: 32px;
            min-height: 32px;
            padding: 0;
            border: none;
            color: {win_fg};
        }}
        .nav-circle-btn:hover {{
            background-color: {self.accent_rgba(0.20)};
        }}
        .nav-circle-btn:disabled {{
            opacity: 0.35;
        }}
        .bottom-action-bar {{
            background-color: {sidebar_bg};
            border-top: 1px solid {border_col};
            padding: 10px 24px;
        }}
        .apply-btn {{
            min-width: 100px;
            font-weight: 600;
            border-radius: 12px;
            padding: 8px 20px;
        }}
        .status-label {{
            font-size: 13px;
            color: {sub_fg};
        }}
        .segmented-group {{
            background-color: {sidebar_bg};
            border: 1px solid {border_col};
            border-radius: 12px;
            padding: 3px;
        }}
        .mode-tab-btn {{
            background-color: transparent;
            border: none;
            border-radius: 9px;
            padding: 5px 12px;
            font-size: 11px;
            font-weight: 500;
            color: {sub_fg};
            transition: all 120ms ease;
        }}
        .mode-tab-btn:hover {{
            color: {title_fg};
            background-color: {border_col};
        }}
        .mode-tab-btn.active {{
            background-color: {self.accent_hex};
            color: #ffffff;
            font-weight: 700;
        }}
        combobox button {{
            border-radius: 10px;
            padding: 4px 10px;
            border: 1px solid {border_col};
            background-color: {sidebar_bg};
            color: {win_fg};
        }}
        scale highlight {{
            background-color: {self.accent_hex};
            border-radius: 3px;
        }}
        scale trough {{
            background-color: {border_col};
            border-radius: 3px;
            min-height: 5px;
        }}
        scale slider {{
            background-color: #ffffff;
            border: 2px solid {self.accent_hex};
            border-radius: 8px;
            min-width: 14px;
            min-height: 14px;
        }}
        switch:checked {{
            background-color: {self.accent_hex};
        }}
        .blank-tile-preview {{
            background-color: {sidebar_bg};
            border: 1px solid {border_col};
            border-radius: 14px;
        }}
        .blank-tile-preview picture, .blank-tile-preview image {{
            border-radius: 14px;
        }}
        .accent-label {{
            color: {self.accent_hex};
            font-weight: 600;
        }}
        """
        if hasattr(self, "_css_provider") and self._css_provider:
            try:
                Gtk.StyleContext.remove_provider_for_display(Gdk.Display.get_default(), self._css_provider)
            except Exception:
                pass
        self._css_provider = Gtk.CssProvider()
        self._css_provider.load_from_data(css.encode("utf-8"))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), self._css_provider, Gtk.STYLE_PROVIDER_PRIORITY_USER + 50
        )

    def build_ui(self):
        root_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_content(root_box)

        # Header Bar (Clean, no apply button in header)
        header = Adw.HeaderBar()
        header.set_show_end_title_buttons(True)
        title_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        t_lbl = Gtk.Label(label="Settings")
        t_lbl.add_css_class("heading")
        title_box.append(t_lbl)
        header.set_title_widget(title_box)

        root_box.append(header)

        # Main Layout: Sidebar (Left) + Content (Right)
        main_paned = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        main_paned.set_vexpand(True)
        root_box.append(main_paned)

        # ── Sidebar ────────────────────────────────────────────────────────
        sidebar_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        sidebar_box.set_size_request(230, -1)
        sidebar_box.add_css_class("sidebar-container")
        main_paned.append(sidebar_box)

        # Search Settings Entry
        self.search_entry = Gtk.SearchEntry()
        self.search_entry.set_placeholder_text("Search Settings")
        self.search_entry.add_css_class("search-entry")
        self.search_entry.connect("search-changed", self.on_search_changed)
        self.search_entry.connect("activate", self.on_search_activated)
        sidebar_box.append(self.search_entry)

        # Category List
        scrolled_nav = Gtk.ScrolledWindow()
        scrolled_nav.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled_nav.set_vexpand(True)
        sidebar_box.append(scrolled_nav)

        self.nav_list = Gtk.ListBox()
        self.nav_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.nav_list.connect("row-selected", self.on_category_selected)
        self.nav_list.connect("row-activated", self.on_category_activated)
        scrolled_nav.set_child(self.nav_list)

        # ── Content Pane ───────────────────────────────────────────────────
        content_frame = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        content_frame.set_hexpand(True)
        content_frame.set_vexpand(True)
        main_paned.append(content_frame)

        # Content Top Bar: < > Navigation Buttons
        top_nav_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        top_nav_bar.set_margin_start(20)
        top_nav_bar.set_margin_top(12)
        top_nav_bar.set_margin_bottom(8)
        content_frame.append(top_nav_bar)

        self.btn_back = Gtk.Button()
        self.btn_back.set_icon_name("go-previous-symbolic")
        self.btn_back.add_css_class("nav-circle-btn")
        self.btn_back.connect("clicked", self.on_go_back)
        top_nav_bar.append(self.btn_back)

        self.btn_forward = Gtk.Button()
        self.btn_forward.set_icon_name("go-next-symbolic")
        self.btn_forward.add_css_class("nav-circle-btn")
        self.btn_forward.connect("clicked", self.on_go_forward)
        top_nav_bar.append(self.btn_forward)

        # Scrolled Stack for Category Pages
        self.scrolled_content = Gtk.ScrolledWindow()
        self.scrolled_content.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.scrolled_content.set_vexpand(True)
        content_frame.append(self.scrolled_content)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(180)
        self.scrolled_content.set_child(self.stack)

        # Bottom Action Bar (Apply button relocated to bottom right)
        bottom_bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        bottom_bar.add_css_class("bottom-action-bar")

        self.lbl_status = Gtk.Label(label="")
        self.lbl_status.set_halign(Gtk.Align.START)
        self.lbl_status.set_hexpand(True)
        self.lbl_status.add_css_class("status-label")
        bottom_bar.append(self.lbl_status)

        self.apply_btn = Gtk.Button(label="Apply")
        self.apply_btn.add_css_class("apply-btn")
        self.apply_btn.set_halign(Gtk.Align.END)
        self.apply_btn.connect("clicked", self.on_apply_clicked)
        bottom_bar.append(self.apply_btn)

        root_box.append(bottom_bar)

        # Define the SaneAspect Categories
        self.categories = [
            ("bar", "Bar & Island", "user-desktop-symbolic", "Bar & Island", "Configure bar style, island shape, position, and dimensions.", self.build_bar_page),
            ("vanish", "Vanish Mode", "view-reveal-symbolic", "Vanish Mode", "Barless atomic desktop with animated clock orb, radial satellites, and gestures.", self.build_vanish_page),
            ("blank_tile", "Blank Tile", "image-x-generic-symbolic", "Blank Tile Customization", "Personalize the top hero tile in Spotlight & Vanish launcher with custom image regions.", self.build_blank_tile_page),
            ("media", "Media", "folder-music-symbolic", "Media", "Media player controls, spinning vinyl disc, and audio visualizer.", self.build_media_page),
            ("clock", "Clock & Date", "preferences-system-time-symbolic", "Clock & Date", "Time formatting, clock typography designs, and calendar integration.", self.build_clock_page),
            ("appearance", "Appearance", "preferences-desktop-appearance-symbolic", "Appearance", "Color scheme, window borders, gaps, corner rounding, blur, shadows, and shell visuals.", self.build_appearance_page),
            ("motion", "Motion", "media-playlist-repeat-symbolic", "Motion", "How fast the shell animates, or whether it animates at all.", self.build_motion_page),
            ("launcher", "Launcher", "system-search-symbolic", "Launcher", "Spotlight search, application launcher, and quick actions.", self.build_launcher_page),
            ("notifications", "Notifications", "preferences-system-notifications-symbolic", "Notifications", "Banner popups, notification badges, and Do Not Disturb.", self.build_notifications_page),
            ("control_center", "Control Center", "emblem-system-symbolic", "Control Center", "Quick toggles, volume mixer, brightness, and network trays.", self.build_control_center_page),
            ("power", "Power & Battery", "battery-full-symbolic", "Power & Battery", "Power profiles, button & lid actions, sleep, hibernation, and display timeouts.", self.build_power_page),
            ("lockscreen", "Lock Screen", "system-lock-screen-symbolic", "Lock Screen", "Hyprlock layout, background blur, and biometric authentication.", self.build_lockscreen_page),
            ("system", "System", "preferences-system-symbolic", "System", "Performance profiles, default applications, and shell diagnostics.", self.build_system_page),
        ]

        self.nav_rows = {}
        for cat_id, title, icon_name, hero_title, hero_sub, builder_func in self.categories:
            row = Gtk.ListBoxRow()
            row.cat_id = cat_id
            row.title_text = title
            row.matched_items = []
            row.add_css_class("nav-item-row")

            row_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)

            header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

            icon_badge = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            icon_badge.add_css_class("nav-icon-badge")
            icon_badge.set_halign(Gtk.Align.CENTER)
            icon_badge.set_valign(Gtk.Align.CENTER)
            img = Gtk.Image.new_from_icon_name(icon_name)
            img.set_pixel_size(16)
            icon_badge.append(img)
            header_box.append(icon_badge)

            lbl = Gtk.Label(label=title)
            lbl.set_halign(Gtk.Align.START)
            lbl.set_hexpand(True)
            header_box.append(lbl)

            badge = Gtk.Label(label="")
            badge.add_css_class("match-count-badge")
            badge.set_visible(False)
            header_box.append(badge)
            row.match_badge = badge

            row_box.append(header_box)

            sub_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            sub_box.set_margin_start(34)
            sub_box.set_visible(False)
            row_box.append(sub_box)
            row.sub_box = sub_box

            row.set_child(row_box)
            self.nav_list.append(row)
            self.nav_rows[cat_id] = row

            self.current_cat_id = cat_id
            page_widget = builder_func(icon_name, hero_title, hero_sub)
            self.stack.add_named(page_widget, cat_id)
        self.current_cat_id = None

        # Default to Bar & Island page (or requested page argument)
        initial_cat = "bar"
        for arg in sys.argv[1:]:
            a = arg.lstrip("-").lower()
            if a in ("looknfeel", "look_and_feel", "look-and-feel"):
                a = "appearance"
            if a in self.nav_rows:
                initial_cat = a
                break
        if initial_cat in self.nav_rows:
            self.nav_list.select_row(self.nav_rows[initial_cat])
            self.stack.set_visible_child_name(initial_cat)
            GLib.idle_add(lambda: (self.scrolled_content.get_vadjustment().set_value(0), False)[1])

    @staticmethod
    def disable_scale_scroll(scale):
        try:
            controllers = scale.observe_controllers()
            to_remove = []
            for i in range(controllers.get_n_items()):
                c = controllers.get_item(i)
                if isinstance(c, Gtk.EventControllerScroll):
                    to_remove.append(c)
            for c in to_remove:
                scale.remove_controller(c)
        except Exception as e:
            print("[Scale] Error disabling scroll:", e)

    def register_search_item(self, cat_id, title, subtitle, widget):
        if not cat_id or not widget or not title:
            return
        cat_title = ""
        for cid, ctitle, *_ in self.categories:
            if cid == cat_id:
                cat_title = ctitle
                break
        keywords = f"{title} {subtitle or ''} {cat_title}".lower()
        self.search_index.append({
            "cat_id": cat_id,
            "cat_title": cat_title,
            "title": title,
            "subtitle": subtitle or "",
            "keywords": keywords,
            "widget": widget,
        })

    def highlight_widget(self, target_widget):
        if hasattr(self, "_active_highlight_widget") and self._active_highlight_widget:
            try:
                self._active_highlight_widget.remove_css_class("highlight-setting-row")
            except Exception:
                pass
            self._active_highlight_widget = None

        if hasattr(self, "_highlight_timer_id") and self._highlight_timer_id:
            GLib.source_remove(self._highlight_timer_id)
            self._highlight_timer_id = 0

        self._active_highlight_widget = target_widget
        target_widget.add_css_class("highlight-setting-row")

        def _clear_highlight():
            if self._active_highlight_widget == target_widget:
                try:
                    target_widget.remove_css_class("highlight-setting-row")
                except Exception:
                    pass
                self._active_highlight_widget = None
            self._highlight_timer_id = 0
            return False

        self._highlight_timer_id = GLib.timeout_add(3000, _clear_highlight)

    def navigate_to_setting(self, cat_id, target_widget):
        row = self.nav_rows.get(cat_id)
        if row:
            self.is_navigating = True
            self.nav_list.select_row(row)
            self.is_navigating = False

        if not self.is_navigating:
            if self.history_index < len(self.nav_history) - 1:
                self.nav_history = self.nav_history[:self.history_index + 1]
            self.nav_history.append(cat_id)
            self.history_index += 1
            self.update_nav_buttons()

        self.stack.set_visible_child_name(cat_id)

        def _do_scroll_highlight(attempts=0):
            page = self.stack.get_child_by_name(cat_id)
            if not page or not target_widget:
                return False
            try:
                res, bounds = target_widget.compute_bounds(page)
                if res and bounds.get_height() > 0:
                    y = bounds.get_y()
                    v_adj = self.scrolled_content.get_vadjustment()
                    if v_adj:
                        v_adj.set_value(max(0, y - 50))
                    self.highlight_widget(target_widget)
                    return False
            except Exception as e:
                pass
            if attempts < 3:
                GLib.timeout_add(100, lambda: _do_scroll_highlight(attempts + 1))
            else:
                self.highlight_widget(target_widget)
            return False

        GLib.timeout_add(100, lambda: _do_scroll_highlight(0))

    # ── Navigation & Search ────────────────────────────────────────────────
    def on_category_selected(self, listbox, row):
        if not row:
            return
        cat_id = getattr(row, "cat_id", None)
        if not cat_id:
            return

        if self.stack.get_visible_child_name() != cat_id:
            if not self.is_navigating:
                if self.history_index < len(self.nav_history) - 1:
                    self.nav_history = self.nav_history[:self.history_index + 1]
                self.nav_history.append(cat_id)
                self.history_index += 1
                self.update_nav_buttons()
            self.stack.set_visible_child_name(cat_id)

        matched_items = getattr(row, "matched_items", None)
        if matched_items:
            target_widget = matched_items[0].get("widget")
            if target_widget:
                self.navigate_to_setting(cat_id, target_widget)
        else:
            v_adj = self.scrolled_content.get_vadjustment()
            if v_adj:
                GLib.idle_add(lambda: (v_adj.set_value(0), False)[1])

    def on_category_activated(self, listbox, row):
        self.on_category_selected(listbox, row)

    def on_go_back(self, btn):
        if self.history_index > 0:
            self.history_index -= 1
            self.is_navigating = True
            cat_id = self.nav_history[self.history_index]
            self.nav_list.select_row(self.nav_rows[cat_id])
            self.is_navigating = False
            self.update_nav_buttons()

    def on_go_forward(self, btn):
        if self.history_index < len(self.nav_history) - 1:
            self.history_index += 1
            self.is_navigating = True
            cat_id = self.nav_history[self.history_index]
            self.nav_list.select_row(self.nav_rows[cat_id])
            self.is_navigating = False
            self.update_nav_buttons()

    def update_nav_buttons(self):
        self.btn_back.set_sensitive(self.history_index > 0)
        self.btn_forward.set_sensitive(self.history_index < len(self.nav_history) - 1)

    def on_search_changed(self, entry):
        query = entry.get_text().strip().lower()

        cat_matches = {cat_id: [] for cat_id in self.nav_rows.keys()}
        if query:
            for item in self.search_index:
                if query in item["keywords"]:
                    cat_matches[item["cat_id"]].append(item)

        for cat_id, row in self.nav_rows.items():
            matches = cat_matches.get(cat_id, [])
            cat_title_match = False
            for cid, ctitle, *_ in self.categories:
                if cid == cat_id and query in ctitle.lower():
                    cat_title_match = True
                    break

            is_visible = bool(not query or matches or cat_title_match)
            row.set_visible(is_visible)
            row.matched_items = matches

            # Clear previous sub-items
            while True:
                child = row.sub_box.get_first_child()
                if not child:
                    break
                row.sub_box.remove(child)

            if query and matches:
                row.match_badge.set_text(str(len(matches)))
                row.match_badge.set_visible(True)

                for item in matches[:5]:
                    sub_btn = Gtk.Button()
                    sub_btn.add_css_class("search-sub-item-btn")

                    btn_content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
                    arrow_lbl = Gtk.Label(label="↳")
                    arrow_lbl.add_css_class("sub-arrow-lbl")
                    btn_content.append(arrow_lbl)

                    title_lbl = Gtk.Label(label=item["title"])
                    title_lbl.set_halign(Gtk.Align.START)
                    title_lbl.set_ellipsize(Pango.EllipsizeMode.END)
                    title_lbl.add_css_class("sub-title-lbl")
                    btn_content.append(title_lbl)

                    sub_btn.set_child(btn_content)

                    def _on_sub_click(btn, c_id=cat_id, w=item["widget"]):
                        self.navigate_to_setting(c_id, w)
                    sub_btn.connect("clicked", _on_sub_click)
                    row.sub_box.append(sub_btn)

                row.sub_box.set_visible(True)
            else:
                row.match_badge.set_visible(False)
                row.sub_box.set_visible(False)

    def on_search_activated(self, entry):
        query = entry.get_text().strip().lower()
        if not query:
            return
        for item in self.search_index:
            if query in item["keywords"]:
                self.navigate_to_setting(item["cat_id"], item["widget"])
                return
        for cat_id, title, *_ in self.categories:
            if query in title.lower():
                row = self.nav_rows.get(cat_id)
                if row:
                    self.on_category_selected(self.nav_list, row)
                return

    # ── UI Builder Helpers ─────────────────────────────────────────────────
    def create_page_container(self, icon_name, title, subtitle):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        box.set_margin_start(20)
        box.set_margin_end(24)
        box.set_margin_top(4)
        box.set_margin_bottom(24)

        hero = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        hero.add_css_class("hero-card")
        hero.set_halign(Gtk.Align.FILL)

        icon_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        icon_box.set_halign(Gtk.Align.CENTER)
        icon_box.add_css_class("hero-icon-circle")
        img = Gtk.Image.new_from_icon_name(icon_name)
        img.set_pixel_size(26)
        img.set_halign(Gtk.Align.CENTER)
        img.set_valign(Gtk.Align.CENTER)
        icon_box.append(img)
        hero.append(icon_box)

        t_lbl = Gtk.Label(label=title)
        t_lbl.add_css_class("hero-title")
        t_lbl.set_halign(Gtk.Align.CENTER)
        t_lbl.set_wrap(True)
        t_lbl.set_wrap_mode(Pango.WrapMode.WORD)
        hero.append(t_lbl)

        s_lbl = Gtk.Label(label=subtitle)
        s_lbl.add_css_class("hero-subtitle")
        s_lbl.set_halign(Gtk.Align.CENTER)
        s_lbl.set_justify(Gtk.Justification.CENTER)
        s_lbl.set_wrap(True)
        s_lbl.set_wrap_mode(Pango.WrapMode.WORD)
        hero.append(s_lbl)

        box.append(hero)
        return box

    def create_settings_card(self):
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        card.add_css_class("settings-card")
        card.set_hexpand(True)
        return card

    def add_switch_row(self, card, title, subtitle, is_active, on_toggle):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("settings-row")
        row.set_hexpand(True)

        label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        label_box.set_hexpand(True)
        lbl_t = Gtk.Label(label=title)
        lbl_t.set_halign(Gtk.Align.START)
        lbl_t.set_wrap(True)
        lbl_t.set_wrap_mode(Pango.WrapMode.WORD)
        lbl_t.add_css_class("row-title")
        label_box.append(lbl_t)

        if subtitle:
            lbl_s = Gtk.Label(label=subtitle)
            lbl_s.set_halign(Gtk.Align.START)
            lbl_s.set_wrap(True)
            lbl_s.set_wrap_mode(Pango.WrapMode.WORD)
            lbl_s.add_css_class("row-subtitle")
            label_box.append(lbl_s)
        row.append(label_box)

        sw = Gtk.Switch()
        sw.set_valign(Gtk.Align.CENTER)
        sw.set_halign(Gtk.Align.END)
        sw.set_active(bool(is_active))
        if on_toggle:
            sw.connect("notify::active", lambda s, p: on_toggle(s.get_active()))
        row.append(sw)

        card.append(row)
        self.register_search_item(self.current_cat_id, title, subtitle, row)
        return sw

    def add_slider_row(self, card, title, subtitle, min_val, max_val, step, cur_val, unit="ms", on_change=None):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("settings-row")
        row.set_hexpand(True)

        label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        label_box.set_hexpand(True)
        lbl_t = Gtk.Label(label=title)
        lbl_t.set_halign(Gtk.Align.START)
        lbl_t.set_wrap(True)
        lbl_t.set_wrap_mode(Pango.WrapMode.WORD)
        lbl_t.add_css_class("row-title")
        label_box.append(lbl_t)

        if subtitle:
            lbl_s = Gtk.Label(label=subtitle)
            lbl_s.set_halign(Gtk.Align.START)
            lbl_s.set_wrap(True)
            lbl_s.set_wrap_mode(Pango.WrapMode.WORD)
            lbl_s.add_css_class("row-subtitle")
            label_box.append(lbl_s)
        row.append(label_box)

        scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, min_val, max_val, step)
        self.disable_scale_scroll(scale)
        scale.set_value(cur_val)
        scale.set_size_request(160, -1)
        scale.set_hexpand(True)
        scale.set_draw_value(False)
        scale.set_valign(Gtk.Align.CENTER)
        row.append(scale)

        fmt = f"{int(cur_val)} {unit}" if unit not in ("x", "pow") else f"{cur_val:.2f}{unit}"
        val_lbl = Gtk.Label(label=fmt)
        val_lbl.add_css_class("value-label")
        val_lbl.set_size_request(65, -1)
        val_lbl.set_halign(Gtk.Align.END)
        val_lbl.set_valign(Gtk.Align.CENTER)
        row.append(val_lbl)

        def on_slider_val_changed(sc):
            v = sc.get_value()
            if step >= 1:
                v = int(round(v))
                val_lbl.set_text(f"{v} {unit}" if unit not in ("x", "pow") else f"{v}{unit}")
            else:
                v = round(v, 2)
                val_lbl.set_text(f"{v:.2f}{unit}")
            if on_change:
                on_change(v)

        scale.connect("value-changed", on_slider_val_changed)
        card.append(row)
        self.register_search_item(self.current_cat_id, title, subtitle, row)
        return scale

    def add_combo_row(self, card, title, subtitle, options, cur_idx, on_change=None):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("settings-row")
        row.set_hexpand(True)

        label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        label_box.set_hexpand(True)
        lbl_t = Gtk.Label(label=title)
        lbl_t.set_halign(Gtk.Align.START)
        lbl_t.set_wrap(True)
        lbl_t.set_wrap_mode(Pango.WrapMode.WORD)
        lbl_t.add_css_class("row-title")
        label_box.append(lbl_t)

        if subtitle:
            lbl_s = Gtk.Label(label=subtitle)
            lbl_s.set_halign(Gtk.Align.START)
            lbl_s.set_wrap(True)
            lbl_s.set_wrap_mode(Pango.WrapMode.WORD)
            lbl_s.add_css_class("row-subtitle")
            label_box.append(lbl_s)
        row.append(label_box)

        dropdown = Gtk.DropDown.new_from_strings(options)
        dropdown.set_selected(cur_idx if 0 <= cur_idx < len(options) else 0)
        dropdown.set_valign(Gtk.Align.CENTER)
        dropdown.set_halign(Gtk.Align.END)
        if on_change:
            dropdown.connect("notify::selected", lambda d, p: on_change(d.get_selected()))
        row.append(dropdown)

        card.append(row)
        self.register_search_item(self.current_cat_id, title, subtitle, row)
        return dropdown

    def add_entry_row(self, card, title, subtitle, cur_val, placeholder="", on_change=None):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("settings-row")
        row.set_hexpand(True)

        label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        label_box.set_hexpand(True)
        lbl_t = Gtk.Label(label=title)
        lbl_t.set_halign(Gtk.Align.START)
        lbl_t.set_wrap(True)
        lbl_t.set_wrap_mode(Pango.WrapMode.WORD)
        lbl_t.add_css_class("row-title")
        label_box.append(lbl_t)

        if subtitle:
            lbl_s = Gtk.Label(label=subtitle)
            lbl_s.set_halign(Gtk.Align.START)
            lbl_s.set_wrap(True)
            lbl_s.set_wrap_mode(Pango.WrapMode.WORD)
            lbl_s.add_css_class("row-subtitle")
            label_box.append(lbl_s)
        row.append(label_box)

        entry = Gtk.Entry()
        entry.set_text(str(cur_val))
        entry.set_placeholder_text(placeholder)
        entry.set_valign(Gtk.Align.CENTER)
        entry.set_halign(Gtk.Align.END)
        entry.set_size_request(160, -1)
        card.append(row)
        self.register_search_item(self.current_cat_id, title, subtitle, row)
        return entry

    # ── Category 1: Bar & Island ───────────────────────────────────────────
    def on_theme_mode_clicked(self, target_mode):
        if self.theme_mode == target_mode:
            return
        self.theme_mode = target_mode
        self.is_dark = (target_mode == "dark")

        if hasattr(self, "btn_dark_mode") and hasattr(self, "btn_light_mode"):
            if self.is_dark:
                self.btn_dark_mode.add_css_class("active")
                self.btn_light_mode.remove_css_class("active")
            else:
                self.btn_light_mode.add_css_class("active")
                self.btn_dark_mode.remove_css_class("active")

        for b_dark, b_light in getattr(self, "theme_mode_btn_pairs", []):
            try:
                if self.is_dark:
                    b_dark.add_css_class("active")
                    b_light.remove_css_class("active")
                else:
                    b_light.add_css_class("active")
                    b_dark.remove_css_class("active")
            except Exception:
                pass

        self.lbl_status.set_text(f"Applying Material You {target_mode.capitalize()} mode...")

        def run_theme_switch():
            script_path = os.path.join(CONFIG_DIR, "scripts/theme-mk.py")
            if not os.path.exists(script_path):
                script_path = os.path.expanduser("~/.config/hypr/scripts/theme-mk.py")
            cmd = ["python3", script_path, "--mode", target_mode]
            subprocess.run(cmd, check=False)
            GLib.idle_add(self._on_theme_switched, target_mode)

        threading.Thread(target=run_theme_switch, daemon=True).start()

    def _on_theme_switched(self, mode):
        theme = read_json(THEME_PATH, {})
        self.accent_hex = theme.get("accent", "#f4a7b5")
        self.accent_lit = theme.get("accentLit", "#fcd5dc")
        self.apply_css()
        self.lbl_status.set_text(f"Material You {mode.capitalize()} mode applied.")

    def build_bar_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)

        # ── 1. Color Scheme & Dynamic Material You Card ──
        card_theme = self.create_settings_card()

        row_theme = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_theme.add_css_class("settings-row")
        row_theme.set_hexpand(True)

        theme_lbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        theme_lbox.set_hexpand(True)
        lbl_th_t = Gtk.Label(label="Color Scheme")
        lbl_th_t.set_halign(Gtk.Align.START)
        lbl_th_t.add_css_class("row-title")
        theme_lbox.append(lbl_th_t)

        lbl_th_s = Gtk.Label(label="Dynamic palette from wallpaper (Notch, Pill, Minimal Island)")
        lbl_th_s.set_halign(Gtk.Align.START)
        lbl_th_s.set_wrap(True)
        lbl_th_s.set_wrap_mode(Pango.WrapMode.WORD)
        lbl_th_s.set_max_width_chars(28)
        lbl_th_s.add_css_class("row-subtitle")
        theme_lbox.append(lbl_th_s)
        row_theme.append(theme_lbox)

        seg_theme = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        seg_theme.add_css_class("segmented-group")
        seg_theme.set_valign(Gtk.Align.CENTER)
        seg_theme.set_halign(Gtk.Align.END)

        self.btn_dark_mode = Gtk.Button(label="Dark")
        self.btn_dark_mode.add_css_class("mode-tab-btn")
        self.btn_light_mode = Gtk.Button(label="Light")
        self.btn_light_mode.add_css_class("mode-tab-btn")

        if self.is_dark:
            self.btn_dark_mode.add_css_class("active")
        else:
            self.btn_light_mode.add_css_class("active")

        self.btn_dark_mode.connect("clicked", lambda b: self.on_theme_mode_clicked("dark"))
        self.btn_light_mode.connect("clicked", lambda b: self.on_theme_mode_clicked("light"))

        seg_theme.append(self.btn_dark_mode)
        seg_theme.append(self.btn_light_mode)
        row_theme.append(seg_theme)
        card_theme.append(row_theme)
        if (self.btn_dark_mode, self.btn_light_mode) not in self.theme_mode_btn_pairs:
            self.theme_mode_btn_pairs.append((self.btn_dark_mode, self.btn_light_mode))
        self.register_search_item(self.current_cat_id, "Color Scheme", "Toggle dynamic Light or Dark Material You theme", row_theme)
        page.append(card_theme)

        # Shell Mode Selection
        card_selector = self.create_settings_card()

        modes = ["Screen Notch", "Minimal Island", "Vanish"]
        mode_ids = ["notch", "minimal", "nucleus"]
        cur_mode = self.bar_mode.get("mode", "notch")
        cur_mode_norm = "minimal" if cur_mode in ("minimal", "minimal_notch") else cur_mode
        cur_idx = mode_ids.index(cur_mode_norm) if cur_mode_norm in mode_ids else 0

        mode_stack = Gtk.Stack()
        mode_stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        mode_stack.set_transition_duration(160)

        def show_mode_settings(target_mode):
            mode_stack.set_visible_child_name(target_mode)

        def on_active_mode_changed(idx):
            mode_id = mode_ids[idx]
            stored_mode = "minimal_notch" if mode_id == "minimal" else mode_id
            self.bar_mode["mode"] = stored_mode
            self.bar_mode["islandStyle"] = stored_mode
            self.mark_dirty()
            show_mode_settings(mode_id)

        dd_mode = self.add_combo_row(
            card_selector,
            "Shell Mode",
            "Choose active bar experience (Screen Notch, Minimal Island, or Vanish)",
            modes,
            cur_idx,
            on_active_mode_changed
        )

        page.append(card_selector)

        # ── 3. Tab 1: Notch Mode ──
        card_notch = self.create_settings_card()

        edges = ["Top", "Bottom"]
        cur_edge = self.bar_pos.get("mainBarEdge", "top")
        edge_idx = 1 if cur_edge == "bottom" else 0
        def on_edge_selected(idx):
            self.bar_pos["mainBarEdge"] = "bottom" if idx == 1 else "top"
            self.mark_dirty()
        self.add_combo_row(card_notch, "Screen Position", "Anchor notch bar to top or bottom edge", edges, edge_idx, on_edge_selected)

        cur_h = int(self.bar_pos.get("notchHeight", 32))
        def on_notch_h_changed(v):
            self.bar_pos["notchHeight"] = v
            self.bar_pos["barHeight"] = v
            self.mark_dirty()
        self.add_slider_row(card_notch, "Notch Height", "Vertical height of the screen notch", 24, 48, 1, cur_h, "px", on_notch_h_changed)

        cur_ear = int(self.bar_pos.get("notchEarRadius", 10))
        def on_notch_ear_changed(v):
            self.bar_pos["notchEarRadius"] = v
            self.mark_dirty()
        self.add_slider_row(card_notch, "Notch Ear Radius", "SaneAspect top concave fillet curve", 0, 16, 1, cur_ear, "px", on_notch_ear_changed)

        cur_bot = int(self.bar_pos.get("notchBottomRadius", 14))
        def on_notch_bot_changed(v):
            self.bar_pos["notchBottomRadius"] = v
            self.mark_dirty()
        self.add_slider_row(card_notch, "Notch Corner Radius", "Convex rounded bottom corners", 8, 24, 1, cur_bot, "px", on_notch_bot_changed)

        cur_o_notch = int(float(self.bar_pos.get("notchOpacity", 0.96)) * 100)
        def on_notch_o_changed(v):
            val = round(v / 100.0, 2)
            self.bar_pos["notchOpacity"] = val
            self.mark_dirty()
        self.add_slider_row(card_notch, "Background Opacity", "Surface darkness / transparency", 20, 100, 5, cur_o_notch, "%", on_notch_o_changed)

        cur_blur_notch = bool(self.bar_pos.get("notchBlur", True))
        def on_notch_blur_toggle(act):
            self.bar_pos["notchBlur"] = act
            self.pending_layer_blur = act
            self.mark_dirty()
        self.add_switch_row(card_notch, "Frosted Glass Blur", "Enable backdrop blur behind the notch", cur_blur_notch, on_notch_blur_toggle)

        cur_bls = int(self.looknfeel_cfg.get("blur_size", 3))
        def on_notch_bls_changed(v):
            self.looknfeel_cfg["blur_size"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_notch, "Blur Radius Size", "Backdrop blur radius (lower = smoother)", 1, 16, 1, cur_bls, "px", on_notch_bls_changed)

        cur_blp = int(self.looknfeel_cfg.get("blur_passes", 1))
        def on_notch_blp_changed(v):
            self.looknfeel_cfg["blur_passes"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_notch, "Blur Passes", "Sampling passes (1 = fast/smooth, 2+ = heavy GPU)", 1, 4, 1, cur_blp, "passes", on_notch_blp_changed)

        bat_layouts = ["Horizontal", "Vertical"]
        cur_bat_layout = str(self.bar_mode.get("batteryLayout", "horizontal")).capitalize()
        bat_idx = 1 if cur_bat_layout == "Vertical" else 0
        def on_bat_layout_selected(idx):
            self.bar_mode["batteryLayout"] = "vertical" if idx == 1 else "horizontal"
            self.mark_dirty()
        self.add_combo_row(card_notch, "Battery Layout", "Control Center fluid battery layout orientation", bat_layouts, bat_idx, on_bat_layout_selected)

        mode_stack.add_named(card_notch, "notch")



        # ── 5. Tab 3: Minimal Island Mode (Tide Island) ──
        card_minimal = self.create_settings_card()

        cur_isl_h = int(self.tide_config.get("islandHeight", self.bar_pos.get("islandHeight", 24)))
        def on_isl_h_changed(v):
            self.tide_config["islandHeight"] = int(v)
            self.bar_pos["islandHeight"] = int(v)
            write_json(TIDE_USERCONFIG_PATH, self.tide_config)
            self.mark_dirty()
        self.add_slider_row(card_minimal, "Island Resting Height", "Height of the minimal island capsule when idle", 20, 50, 1, cur_isl_h, "px", on_isl_h_changed)

        cur_isl_w = int(self.tide_config.get("islandWidth", self.bar_pos.get("islandWidth", 100)))
        def on_isl_w_changed(v):
            self.tide_config["islandWidth"] = int(v)
            self.bar_pos["islandWidth"] = int(v)
            write_json(TIDE_USERCONFIG_PATH, self.tide_config)
            self.mark_dirty()
        self.add_slider_row(card_minimal, "Island Resting Width", "Resting width before expanding for media/status", 80, 400, 5, cur_isl_w, "px", on_isl_w_changed)

        cur_isl_margin = int(self.tide_config.get("islandTopMargin", self.bar_pos.get("islandTopMargin", 3)))
        def on_isl_margin_changed(v):
            self.tide_config["islandTopMargin"] = int(v)
            self.bar_pos["islandTopMargin"] = int(v)
            write_json(TIDE_USERCONFIG_PATH, self.tide_config)
            self.mark_dirty()
        self.add_slider_row(card_minimal, "Top Margin (Floating Distance)", "Distance between screen top bezel and island", 0, 24, 1, cur_isl_margin, "px", on_isl_margin_changed)

        cur_isl_notchmode = bool(self.tide_config.get("notchMode", True))
        def on_isl_notchmode_toggle(act):
            self.tide_config["notchMode"] = act
            write_json(TIDE_USERCONFIG_PATH, self.tide_config)
            self.mark_dirty()
        self.add_switch_row(card_minimal, "Dock to Top Bezel (Notch Style)", "Attach to screen top bezel with optional ear curves", cur_isl_notchmode, on_isl_notchmode_toggle)

        cur_isl_ear = int(self.tide_config.get("notchEarRadius", self.bar_pos.get("notchEarRadius", 0)))
        def on_isl_ear_changed(v):
            self.tide_config["notchEarRadius"] = int(v)
            self.bar_pos["notchEarRadius"] = int(v)
            write_json(TIDE_USERCONFIG_PATH, self.tide_config)
            self.mark_dirty()
        self.add_slider_row(card_minimal, "Dock Ear Fillet Radius", "Concave curve connecting island to screen bezel", 0, 16, 1, cur_isl_ear, "px", on_isl_ear_changed)

        cur_isl_op = int(self.tide_config.get("islandBackgroundOpacity", int(float(self.bar_pos.get("minimalOpacity", 0.6)) * 100)))
        def on_isl_op_changed(v):
            self.tide_config["islandBackgroundOpacity"] = int(v)
            self.bar_pos["minimalOpacity"] = round(v / 100.0, 2)
            write_json(TIDE_USERCONFIG_PATH, self.tide_config)
            self.mark_dirty()
        self.add_slider_row(card_minimal, "Island Surface Opacity", "Surface opacity (adapts to light/dark Material You)", 20, 100, 5, cur_isl_op, "%", on_isl_op_changed)

        cur_isl_blur = bool(self.tide_config.get("shellBlurEnabled", False))
        def on_isl_blur_toggle(act):
            self.tide_config["shellBlurEnabled"] = act
            self.bar_pos["minimalBlur"] = act
            self.pending_layer_blur = act
            self.mark_dirty()
        self.add_switch_row(card_minimal, "Frosted Glass Blur", "Enable backdrop blur behind the minimal island", cur_isl_blur, on_isl_blur_toggle)

        cur_isl_bls = int(self.tide_config.get("shellBlurSize", 3))
        def on_isl_bls_changed(v):
            self.tide_config["shellBlurSize"] = int(v)
            self.looknfeel_cfg["blur_size"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_minimal, "Blur Radius Size", "Backdrop blur radius", 1, 16, 1, cur_isl_bls, "px", on_isl_bls_changed)

        cur_isl_blp = int(self.tide_config.get("shellBlurPasses", 1))
        def on_isl_blp_changed(v):
            self.tide_config["shellBlurPasses"] = int(v)
            self.looknfeel_cfg["blur_passes"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_minimal, "Blur Passes", "Sampling passes (1 = ultra-fast / low lag)", 1, 4, 1, cur_isl_blp, "passes", on_isl_blp_changed)

        self.add_combo_row(card_minimal, "Battery Layout", "Control Center fluid battery layout orientation", bat_layouts, bat_idx, on_bat_layout_selected)

        cur_ws_osd = bool(self.tide_config.get("showWorkspaceCapsule", self.bar_mode.get("showWorkspaceOsd", True)))
        def on_ws_osd_toggle(act):
            self.tide_config["showWorkspaceCapsule"] = act
            self.bar_mode["showWorkspaceOsd"] = act
            write_json(TIDE_USERCONFIG_PATH, self.tide_config)
            self.mark_dirty()
        self.add_switch_row(card_minimal, "Workspace Switch Indicator", "Show workspace number when switching workspaces", cur_ws_osd, on_ws_osd_toggle)

        mode_stack.add_named(card_minimal, "minimal")

        # ── 6. Tab 4: Vanish Mode (Nucleus) ──
        card_vanish = self.create_settings_card()

        row_vstatus = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_vstatus.add_css_class("settings-row")
        vstatus_lbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        vstatus_lbox.set_hexpand(True)
        lbl_vst_t = Gtk.Label(label="Vanish Mode (Orbital Nucleus)")
        lbl_vst_t.set_halign(Gtk.Align.START)
        lbl_vst_t.add_css_class("row-title")
        vstatus_lbox.append(lbl_vst_t)
        lbl_vst_s = Gtk.Label(label="Completely hides persistent top bar for pure full-screen workflow")
        lbl_vst_s.set_halign(Gtk.Align.START)
        lbl_vst_s.add_css_class("row-subtitle")
        vstatus_lbox.append(lbl_vst_s)
        row_vstatus.append(vstatus_lbox)

        btn_act_vanish = Gtk.Button(label="Activate Vanish Mode")
        btn_act_vanish.add_css_class("suggested-action")
        btn_act_vanish.set_valign(Gtk.Align.CENTER)
        def on_quick_vanish(b):
            self.bar_mode["mode"] = "nucleus"
            self.bar_mode["islandStyle"] = "nucleus"
            self.mark_dirty()
            dd_mode.set_selected(3)
            self.save_and_apply()
        btn_act_vanish.connect("clicked", on_quick_vanish)
        row_vstatus.append(btn_act_vanish)
        card_vanish.append(row_vstatus)

        cur_trans = bool(self.bar_mode.get("nucleus", {}).get("transition", True))
        def on_trans_toggle(act):
            if "nucleus" not in self.bar_mode:
                self.bar_mode["nucleus"] = {}
            self.bar_mode["nucleus"]["transition"] = act
            self.mark_dirty()
        self.add_switch_row(card_vanish, "Orbital Transition Animation", "Play dynamic satellite expansion animation when opening", cur_trans, on_trans_toggle)

        cur_v_resting = bool(self.bar_mode.get("nucleus", {}).get("showRestingAtom", True))
        def on_v_resting_toggle(act):
            if "nucleus" not in self.bar_mode or not isinstance(self.bar_mode["nucleus"], dict):
                self.bar_mode["nucleus"] = {}
            self.bar_mode["nucleus"]["showRestingAtom"] = act
            self.mark_dirty()
        self.add_switch_row(card_vanish, "Resting Atom Visibility", "Show the central dot and orbiting valence electrons on desktop when idle", cur_v_resting, on_v_resting_toggle)

        cur_v_ws_osd = bool(self.bar_mode.get("showWorkspaceOsd", True))
        def on_v_ws_osd_toggle(act):
            self.bar_mode["showWorkspaceOsd"] = act
            self.mark_dirty()
        self.add_switch_row(card_vanish, "Workspace Number HUD", "Briefly display workspace number on workspace switch", cur_v_ws_osd, on_v_ws_osd_toggle)

        row_vinfo = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        row_vinfo.add_css_class("settings-row")
        lbl_vinfo_t = Gtk.Label(label="Cyberpunk Aesthetic & Shortcuts")
        lbl_vinfo_t.set_halign(Gtk.Align.START)
        lbl_vinfo_t.add_css_class("row-title")
        row_vinfo.append(lbl_vinfo_t)
        lbl_vinfo_s = Gtk.Label(label="• Vanish Mode retains its dark cyberpunk atomic theme and is exempt from light mode.\n• Summon Orbital Hub with SUPER+SPACE; dismiss with ESC or clicking background.\n• Fullscreen media and orbital satellites animate seamlessly without top-bar occlusion.")
        lbl_vinfo_s.set_halign(Gtk.Align.START)
        lbl_vinfo_s.set_wrap(True)
        lbl_vinfo_s.set_wrap_mode(Pango.WrapMode.WORD)
        lbl_vinfo_s.add_css_class("row-subtitle")
        row_vinfo.append(lbl_vinfo_s)
        card_vanish.append(row_vinfo)

        mode_stack.add_named(card_vanish, "nucleus")

        page.append(mode_stack)

        show_mode_settings(cur_mode_norm)

        return page

    # ── Category 2: Vanish Mode ─────────────────────────────────────────────
    def build_vanish_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)

        card1 = self.create_settings_card()

        row_mode = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_mode.add_css_class("settings-row")
        lbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lbox.set_hexpand(True)
        lbl_t = Gtk.Label(label="Activate Vanish Mode")
        lbl_t.set_halign(Gtk.Align.START)
        lbl_t.add_css_class("row-title")
        lbox.append(lbl_t)
        lbl_s = Gtk.Label(label="Switch desktop to barless orbital nucleus")
        lbl_s.set_halign(Gtk.Align.START)
        lbl_s.add_css_class("row-subtitle")
        lbox.append(lbl_s)
        row_mode.append(lbox)

        btn_act = Gtk.Button(label="Switch to Vanish")
        btn_act.add_css_class("suggested-action")
        btn_act.set_valign(Gtk.Align.CENTER)
        def on_switch_vanish(b):
            self.bar_mode["mode"] = "nucleus"
            self.bar_mode["islandStyle"] = "nucleus"
            self.mark_dirty()
            ipc = os.path.join(CONFIG_DIR, "scripts/carbon-ipc.sh")
            if not os.path.exists(ipc):
                ipc = os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh")
            if os.path.exists(ipc):
                subprocess.run(["sh", ipc, "vanish"], check=False)
        btn_act.connect("clicked", on_switch_vanish)
        row_mode.append(btn_act)
        card1.append(row_mode)
        self.register_search_item(self.current_cat_id, "Activate Vanish Mode", "Switch desktop to barless orbital nucleus", row_mode)

        nuc_cfg = self.bar_mode.get("nucleus", {})

        cur_show_resting = bool(nuc_cfg.get("showRestingAtom", True))
        def on_resting_toggle(act):
            if "nucleus" not in self.bar_mode or not isinstance(self.bar_mode["nucleus"], dict):
                self.bar_mode["nucleus"] = {}
            self.bar_mode["nucleus"]["showRestingAtom"] = act
            self.mark_dirty()
        self.add_switch_row(card1, "Resting Desktop Atom", "Show or remove the central dot and orbiting valence electrons when idle", cur_show_resting, on_resting_toggle)

        # Resting Atom Orbit Behavior
        cur_spin = nuc_cfg.get("restingSpin", "hover")
        spin_options = ["Orbit on Hover / Touch (0% GPU Idle)", "Continuous Orbit 24/7", "Static Atom (No Orbit)"]
        spin_ids = ["hover", "always", "never"]
        cur_s_idx = spin_ids.index(cur_spin) if cur_spin in spin_ids else (1 if cur_spin is True else (2 if cur_spin is False else 0))
        def on_spin_sel(idx):
            s = spin_ids[idx]
            if "nucleus" not in self.bar_mode or not isinstance(self.bar_mode["nucleus"], dict):
                self.bar_mode["nucleus"] = {}
            self.bar_mode["nucleus"]["restingSpin"] = s
            self.mark_dirty()
        self.add_combo_row(card1, "Resting Atom Orbit", "Control background valence electron rotation in Vanish Mode", spin_options, cur_s_idx, on_spin_sel)
        row_prev = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_prev.add_css_class("settings-row")
        lbox_p = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lbox_p.set_hexpand(True)
        lbl_pt = Gtk.Label(label="Test Transition Animation")
        lbl_pt.set_halign(Gtk.Align.START)
        lbl_pt.add_css_class("row-title")
        lbox_p.append(lbl_pt)
        lbl_ps = Gtk.Label(label="Play the transition overlay right now")
        lbl_ps.set_halign(Gtk.Align.START)
        lbl_ps.add_css_class("row-subtitle")
        lbox_p.append(lbl_ps)
        row_prev.append(lbox_p)

        btn_prev = Gtk.Button(label="Play Transition")
        btn_prev.set_valign(Gtk.Align.CENTER)
        def on_play_prev(b):
            ipc = os.path.join(CONFIG_DIR, "scripts/carbon-ipc.sh")
            if not os.path.exists(ipc):
                ipc = os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh")
            if os.path.exists(ipc):
                subprocess.run(["sh", ipc, "vanish"], check=False)
        btn_prev.connect("clicked", on_play_prev)
        row_prev.append(btn_prev)
        card1.append(row_prev)
        self.register_search_item(self.current_cat_id, "Test Transition Animation", "Play the transition overlay right now", row_prev)

        page.append(card1)

        card2 = self.create_settings_card()
        vis_options = ["Liquid Halo (Siri Ring)", "None"]
        vis_val = self.bar_mode.get("musicVisualizer", "liquidHalo")
        vis_idx = 0 if vis_val == "liquidHalo" else 1
        def on_v2_changed(idx):
            self.bar_mode["musicVisualizer"] = "liquidHalo" if idx == 0 else "none"
            self.mark_dirty()
        self.add_combo_row(card2, "Desktop Music Visualizer", "Organic reactive halo pulsing behind central clock orb", vis_options, vis_idx, on_v2_changed)
        page.append(card2)

        card3 = self.create_settings_card()
        lbl_st = Gtk.Label(label="Vanish Mode Dedicated Keybinds")
        lbl_st.set_halign(Gtk.Align.START)
        lbl_st.add_css_class("heading")
        card3.append(lbl_st)

        for s_id, s_info in self.vanish_shortcuts.items():
            row_s = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            row_s.add_css_class("settings-row")
            lb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            lb.set_hexpand(True)
            st = Gtk.Label(label=s_info.get("title", s_id))
            st.set_halign(Gtk.Align.START)
            st.add_css_class("row-title")
            lb.append(st)
            ss = Gtk.Label(label=s_info.get("desc", ""))
            ss.set_halign(Gtk.Align.START)
            ss.add_css_class("row-subtitle")
            lb.append(ss)
            row_s.append(lb)

            lbl_key = Gtk.Label(label=s_info.get("display_str", "Unset"))
            lbl_key.add_css_class("value-label")
            lbl_key.set_valign(Gtk.Align.CENTER)
            row_s.append(lbl_key)
            card3.append(row_s)
            self.register_search_item(self.current_cat_id, s_info.get("title", s_id), s_info.get("desc", ""), row_s)

        row_rst = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_rst.add_css_class("settings-row")
        lbr = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lbr.set_hexpand(True)
        str_lbl = Gtk.Label(label="Reset Vanish Shortcuts")
        str_lbl.set_halign(Gtk.Align.START)
        str_lbl.add_css_class("row-title")
        lbr.append(str_lbl)
        row_rst.append(lbr)

        btn_rst = Gtk.Button(label="Reset Defaults")
        btn_rst.set_valign(Gtk.Align.CENTER)
        def on_reset_vanish_keys(b):
            self.vanish_shortcuts = copy.deepcopy(DEFAULT_VANISH_SHORTCUTS)
            self.mark_dirty()
        btn_rst.connect("clicked", on_reset_vanish_keys)
        row_rst.append(btn_rst)
        card3.append(row_rst)
        self.register_search_item(self.current_cat_id, "Reset Vanish Shortcuts", "Reset default vanish triggers", row_rst)
        page.append(card3)

        # ── Card 4: Launcher Blank Tile ──
        card4 = self.create_settings_card()
        row_bt = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_bt.add_css_class("settings-row")
        lb_bt = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lb_bt.set_hexpand(True)
        lbl_btt = Gtk.Label(label="Launcher Blank Tile Customization")
        lbl_btt.set_halign(Gtk.Align.START)
        lbl_btt.add_css_class("row-title")
        lb_bt.append(lbl_btt)
        lbl_bts = Gtk.Label(label="Customize image background and crop region for the top idle tile")
        lbl_bts.set_halign(Gtk.Align.START)
        lbl_bts.add_css_class("row-subtitle")
        lb_bt.append(lbl_bts)
        row_bt.append(lb_bt)

        btn_goto_bt = Gtk.Button(label="Customize Tile ->")
        btn_goto_bt.set_valign(Gtk.Align.CENTER)
        btn_goto_bt.connect("clicked", lambda b: self.nav_list.select_row(self.nav_rows["blank_tile"]))
        row_bt.append(btn_goto_bt)
        card4.append(row_bt)
        self.register_search_item(self.current_cat_id, "Launcher Blank Tile Customization", "Customize image background and crop region for top idle tile", row_bt)
        page.append(card4)

        return page

    # ── Category: Blank Tile Customization ──────────────────────────────────
    def build_blank_tile_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)

        # ── Card 1: Configuration ──
        card_config = self.create_settings_card()

        # Switch: Use Image Background
        is_en = bool(self.tile_cfg.get("enabled", False))
        def on_enable_toggle(act):
            self.tile_cfg["enabled"] = bool(act)
            self.tile_cfg["timestamp"] = int(time.time() * 1000)
            self.save_tile_config()
            self.update_tile_preview()
        self.sw_tile_enable = self.add_switch_row(
            card_config,
            "Use Image Background",
            "Show a selected image region in the blank tile instead of solid black",
            is_en,
            on_enable_toggle
        )

        # Row: Source Image File
        row_img = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_img.add_css_class("settings-row")
        lbox_i = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lbox_i.set_hexpand(True)
        lbl_it = Gtk.Label(label="Source Image")
        lbl_it.set_halign(Gtk.Align.START)
        lbl_it.add_css_class("row-title")
        lbox_i.append(lbl_it)

        cur_img = self.tile_cfg.get("imagePath", "")
        img_name = os.path.basename(cur_img) if cur_img else "No image chosen"
        self.lbl_img_path = Gtk.Label(label=img_name)
        self.lbl_img_path.set_halign(Gtk.Align.START)
        self.lbl_img_path.add_css_class("row-subtitle")
        lbox_i.append(self.lbl_img_path)
        row_img.append(lbox_i)

        btn_choose = Gtk.Button(label="Choose Image...")
        btn_choose.set_valign(Gtk.Align.CENTER)
        btn_choose.connect("clicked", self.on_choose_tile_image)
        row_img.append(btn_choose)
        card_config.append(row_img)
        self.register_search_item(self.current_cat_id, "Source Image", "Select background image for blank tile", row_img)

        # Row: Crop & Region Selection
        row_crop = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_crop.add_css_class("settings-row")
        lbox_c = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lbox_c.set_hexpand(True)
        lbl_ct = Gtk.Label(label="Selected Region")
        lbl_ct.set_halign(Gtk.Align.START)
        lbl_ct.add_css_class("row-title")
        lbox_c.append(lbl_ct)

        cr = self.tile_cfg.get("cropRect", {})
        crop_str = f"{cr.get('width', 0)}×{cr.get('height', 0)} px at ({cr.get('x', 0)}, {cr.get('y', 0)})" if cr.get("width", 0) > 0 else "Select any region of the image (crop)"
        self.lbl_crop_desc = Gtk.Label(label=crop_str)
        self.lbl_crop_desc.set_halign(Gtk.Align.START)
        self.lbl_crop_desc.add_css_class("row-subtitle")
        lbox_c.append(self.lbl_crop_desc)
        row_crop.append(lbox_c)

        self.btn_crop = Gtk.Button(label="Select / Adjust Region...")
        self.btn_crop.set_valign(Gtk.Align.CENTER)
        self.btn_crop.connect("clicked", self.on_open_tile_cropper)
        self.btn_crop.set_sensitive(bool(self.tile_cfg.get("imagePath") and os.path.exists(self.tile_cfg.get("imagePath"))))
        row_crop.append(self.btn_crop)
        card_config.append(row_crop)
        self.register_search_item(self.current_cat_id, "Selected Region", "Select region of image for blank tile crop", row_crop)

        # Slider: Image Opacity
        cur_op = int(float(self.tile_cfg.get("opacity", 1.0)) * 100)
        def on_op_changed(v):
            val = round(v / 100.0, 2)
            self.tile_cfg["opacity"] = val
            self.tile_cfg["timestamp"] = int(time.time() * 1000)
            self.save_tile_config()
            self.update_tile_preview()
        self.add_slider_row(card_config, "Tile Image Opacity", "Transparency of cropped image in blank tile", 20, 100, 5, cur_op, "%", on_op_changed)

        # Button: Reset to Blank Tile
        row_rst = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_rst.add_css_class("settings-row")
        lbox_r = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lbox_r.set_hexpand(True)
        lbl_rt = Gtk.Label(label="Reset to Default Blank Tile")
        lbl_rt.set_halign(Gtk.Align.START)
        lbl_rt.add_css_class("row-title")
        lbox_r.append(lbl_rt)
        lbl_rs = Gtk.Label(label="Revert to original clean #111116 dark container")
        lbl_rs.set_halign(Gtk.Align.START)
        lbl_rs.add_css_class("row-subtitle")
        lbox_r.append(lbl_rs)
        row_rst.append(lbox_r)

        btn_rst = Gtk.Button(label="Reset Tile")
        btn_rst.set_valign(Gtk.Align.CENTER)
        def on_reset_tile(b):
            self.tile_cfg = {
                "enabled": False,
                "imagePath": "",
                "cropPath": "",
                "cropRect": {"x": 0, "y": 0, "width": 0, "height": 0},
                "opacity": 1.0,
                "timestamp": int(time.time() * 1000)
            }
            self.save_tile_config()
            self.lbl_img_path.set_text("No image chosen")
            self.lbl_crop_desc.set_text("Select any region of the image (crop)")
            self.btn_crop.set_sensitive(False)
            if hasattr(self, "sw_tile_enable"):
                self.sw_tile_enable.set_active(False)
            self.update_tile_preview()
        btn_rst.connect("clicked", on_reset_tile)
        row_rst.append(btn_rst)
        card_config.append(row_rst)
        self.register_search_item(self.current_cat_id, "Reset to Default Blank Tile", "Revert to original clean dark container", row_rst)

        page.append(card_config)

        # ── Card 2: Live Tile Preview ──
        card_prev = self.create_settings_card()
        lbl_pt = Gtk.Label(label="Live Blank Tile Preview")
        lbl_pt.set_halign(Gtk.Align.START)
        lbl_pt.add_css_class("heading")
        card_prev.append(lbl_pt)

        prev_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        prev_container.set_halign(Gtk.Align.CENTER)
        prev_container.set_margin_top(12)
        prev_container.set_margin_bottom(8)

        # Frame matching exact tile aspect ratio (408 x 86)
        self.tile_preview_box = Gtk.Overlay()
        self.tile_preview_box.set_size_request(408, 86)
        self.tile_preview_box.add_css_class("blank-tile-preview")

        self.preview_picture = Gtk.Picture()
        self.preview_picture.set_content_fit(Gtk.ContentFit.COVER)
        self.preview_picture.set_size_request(408, 86)
        self.tile_preview_box.set_child(self.preview_picture)

        self.preview_placeholder = Gtk.Label(label="Default Blank Tile (#111116)")
        self.preview_placeholder.set_halign(Gtk.Align.CENTER)
        self.preview_placeholder.set_valign(Gtk.Align.CENTER)
        self.preview_placeholder.add_css_class("row-subtitle")
        self.tile_preview_box.add_overlay(self.preview_placeholder)

        prev_container.append(self.tile_preview_box)
        card_prev.append(prev_container)
        page.append(card_prev)

        self.update_tile_preview()
        return page

    def notify_shell_blank_tile(self):
        try:
            import socket
            sock_path = "/tmp/carbon-shell.sock"
            if os.path.exists(sock_path):
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                    s.settimeout(0.5)
                    s.connect(sock_path)
                    s.sendall(b"reload-blank-tile\n")
        except Exception:
            pass

    def save_tile_config(self):
        write_json(BLANK_TILE_CONFIG_PATH, self.tile_cfg)
        if BLANK_TILE_HYPR_PATH != BLANK_TILE_CONFIG_PATH:
            write_json(BLANK_TILE_HYPR_PATH, self.tile_cfg)
        self.notify_shell_blank_tile()

    def auto_apply_default_crop(self, image_path):
        try:
            from PIL import Image as PILImage
            img = PILImage.open(image_path)
            orig_w, orig_h = img.size
            tile_aspect = 408.0 / 86.0
            if (orig_w / orig_h) > tile_aspect:
                crop_h = max(30, int(orig_h * 0.65))
                crop_w = int(round(crop_h * tile_aspect))
            else:
                crop_w = max(30, int(orig_w * 0.85))
                crop_h = int(round(crop_w / tile_aspect))
            x1 = max(0, (orig_w - crop_w) // 2)
            y1 = max(0, (orig_h - crop_h) // 2)
            x2 = min(orig_w, x1 + crop_w)
            y2 = min(orig_h, y1 + crop_h)

            cropped = img.crop((x1, y1, x2, y2))
            os.makedirs(CONFIG_DIR, exist_ok=True)
            os.makedirs(HYPR_DIR, exist_ok=True)
            cropped.save(BLANK_TILE_CROP_PATH, format="PNG")
            if BLANK_TILE_HYPR_CROP_PATH != BLANK_TILE_CROP_PATH:
                cropped.save(BLANK_TILE_HYPR_CROP_PATH, format="PNG")

            self.tile_cfg = {
                "enabled": True,
                "imagePath": image_path,
                "cropPath": BLANK_TILE_CROP_PATH,
                "cropRect": {"x": x1, "y": y1, "width": x2 - x1, "height": y2 - y1},
                "opacity": float(self.tile_cfg.get("opacity", 1.0)),
                "timestamp": int(time.time() * 1000)
            }
            if hasattr(self, "sw_tile_enable"):
                self.sw_tile_enable.set_active(True)
            self.save_tile_config()
            self.update_tile_preview()
            cr = self.tile_cfg["cropRect"]
            self.lbl_crop_desc.set_text(f"{cr['width']}×{cr['height']} px at ({cr['x']}, {cr['y']})")
        except Exception as e:
            print("[BlankTile] Auto crop error:", e)

    def update_tile_preview(self):
        if not hasattr(self, "preview_picture") or not hasattr(self, "preview_placeholder"):
            return
        is_en = self.tile_cfg.get("enabled", False)
        crop_path = self.tile_cfg.get("cropPath", "")
        if is_en and crop_path and os.path.exists(crop_path):
            file = Gio.File.new_for_path(crop_path)
            self.preview_picture.set_file(file)
            self.preview_picture.set_visible(True)
            self.preview_placeholder.set_visible(False)
            op = float(self.tile_cfg.get("opacity", 1.0))
            self.preview_picture.set_opacity(op)
        else:
            self.preview_picture.set_visible(False)
            self.preview_placeholder.set_visible(True)

    def on_choose_tile_image(self, btn):
        dialog = Gtk.FileDialog()
        dialog.set_title("Choose Image for Blank Tile")

        filters = Gio.ListStore.new(Gtk.FileFilter)
        img_filter = Gtk.FileFilter()
        img_filter.set_name("Images (*.png, *.jpg, *.jpeg, *.webp)")
        img_filter.add_mime_type("image/png")
        img_filter.add_mime_type("image/jpeg")
        img_filter.add_mime_type("image/webp")
        filters.append(img_filter)
        dialog.set_filters(filters)

        def on_open_finish(source, res):
            try:
                gfile = source.open_finish(res)
                if gfile:
                    path = gfile.get_path()
                    if path and os.path.exists(path):
                        self.tile_cfg["imagePath"] = path
                        self.lbl_img_path.set_text(os.path.basename(path))
                        self.btn_crop.set_sensitive(True)
                        self.auto_apply_default_crop(path)
                        self.on_open_tile_cropper(None)
            except Exception:
                pass

        dialog.open(self, None, on_open_finish)

    def on_open_tile_cropper(self, btn):
        img_path = self.tile_cfg.get("imagePath", "")
        if not img_path or not os.path.exists(img_path):
            return

        crop_rect = self.tile_cfg.get("cropRect")
        crop_dialog = ImageCropDialog(
            parent_window=self,
            image_path=img_path,
            initial_rect=crop_rect,
            accent_hex=self.accent_hex,
            on_apply=self.on_tile_crop_applied
        )
        crop_dialog.present()

    def on_tile_crop_applied(self, new_cfg):
        self.tile_cfg = new_cfg
        cr = self.tile_cfg.get("cropRect", {})
        crop_str = f"{cr.get('width', 0)}×{cr.get('height', 0)} px at ({cr.get('x', 0)}, {cr.get('y', 0)})"
        self.lbl_crop_desc.set_text(crop_str)
        self.lbl_img_path.set_text(os.path.basename(self.tile_cfg.get("imagePath", "")))
        self.btn_crop.set_sensitive(True)
        if hasattr(self, "sw_tile_enable"):
            self.sw_tile_enable.set_active(True)
        self.save_tile_config()
        self.update_tile_preview()

    # ── Category: Media ──────────────────────────────────────────────────
    def build_media_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)
        card = self.create_settings_card()

        disc_act = bool(self.bar_pos.get("showVinylDisc", True))
        def on_disc(act):
            self.bar_pos["showVinylDisc"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Spinning Album Disc", "Show animated vinyl record with album art", disc_act, on_disc)

        eq_act = bool(self.bar_pos.get("showEqualizer", True))
        def on_eq(act):
            self.bar_pos["showEqualizer"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Waveform Equalizer", "Show animated dynamic island audio bars", eq_act, on_eq)

        expand_act = bool(self.bar_pos.get("autoExpandOnTrack", False))
        def on_exp(act):
            self.bar_pos["autoExpandOnTrack"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Auto-expand on Track Change", "Briefly expand island when song changes", expand_act, on_exp)

        vis_options = ["Liquid Halo (Siri Ring)", "None"]
        vis_val = self.bar_mode.get("musicVisualizer", "liquidHalo")
        vis_idx = 0 if vis_val == "liquidHalo" else 1
        def on_vis_changed(idx):
            self.bar_mode["musicVisualizer"] = "liquidHalo" if idx == 0 else "none"
            self.mark_dirty()
        self.add_combo_row(card, "Audio Visualizer Effect", "Choose dynamic glowing visualizer for music playback", vis_options, vis_idx, on_vis_changed)

        page.append(card)
        return page

    # ── Category 4: Clock & Date ───────────────────────────────────────────
    def build_clock_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)
        card = self.create_settings_card()

        styles = [
            "Titan 3D Pop",
            "Stacked Dual",
            "Nordic Monospace",
            "Cyber HUD (Orbitron)",
            "Split Glass Pill",
            "Aero Minimal Pill"
        ]
        style_ids = ["titan", "stacked", "mono_glow", "orbitron", "split_pill", "minimal_pill"]
        cur_s = self.clock_cfg.get("style", "titan")
        idx = style_ids.index(cur_s) if cur_s in style_ids else 0
        def on_s_changed(sel):
            self.clock_cfg["style"] = style_ids[sel]
            self.mark_dirty()
        self.add_combo_row(card, "Typography Style", "Visual appearance of center island clock", styles, idx, on_s_changed)

        fmts = ["12-Hour (AM/PM)", "24-Hour (Military)"]
        cur_fmt = self.clock_cfg.get("format", "12")
        f_idx = 1 if cur_fmt == "24" else 0
        def on_f_changed(sel):
            self.clock_cfg["format"] = "24" if sel == 1 else "12"
            self.mark_dirty()
        self.add_combo_row(card, "Clock Format", "12-hour or 24-hour time display", fmts, f_idx, on_f_changed)

        show_d = bool(self.clock_cfg.get("showDate", True))
        def on_d_toggle(act):
            self.clock_cfg["showDate"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Show Calendar Date", "Display day and date in expanded overview", show_d, on_d_toggle)

        page.append(card)
        return page

    # ── Category 6: Appearance (Configures Theme, Window Borders, Gaps, Opacity, Blur, Shadows) ─
    def build_appearance_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)

        # ── Card 1: Color Scheme & Theme ──
        card_theme = self.create_settings_card()

        row_theme = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_theme.add_css_class("settings-row")
        row_theme.set_hexpand(True)

        theme_lbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        theme_lbox.set_hexpand(True)
        lbl_th_t = Gtk.Label(label="Color Scheme")
        lbl_th_t.set_halign(Gtk.Align.START)
        lbl_th_t.add_css_class("row-title")
        theme_lbox.append(lbl_th_t)

        lbl_th_s = Gtk.Label(label="Dynamic Material You palette generated from active wallpaper")
        lbl_th_s.set_halign(Gtk.Align.START)
        lbl_th_s.set_wrap(True)
        lbl_th_s.set_wrap_mode(Pango.WrapMode.WORD)
        lbl_th_s.set_max_width_chars(28)
        lbl_th_s.add_css_class("row-subtitle")
        theme_lbox.append(lbl_th_s)
        row_theme.append(theme_lbox)

        seg_theme = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=2)
        seg_theme.add_css_class("segmented-group")
        seg_theme.set_valign(Gtk.Align.CENTER)
        seg_theme.set_halign(Gtk.Align.END)

        btn_app_dark = Gtk.Button(label="Dark")
        btn_app_dark.add_css_class("mode-tab-btn")
        btn_app_light = Gtk.Button(label="Light")
        btn_app_light.add_css_class("mode-tab-btn")

        if self.is_dark:
            btn_app_dark.add_css_class("active")
        else:
            btn_app_light.add_css_class("active")

        btn_app_dark.connect("clicked", lambda b: self.on_theme_mode_clicked("dark"))
        btn_app_light.connect("clicked", lambda b: self.on_theme_mode_clicked("light"))

        seg_theme.append(btn_app_dark)
        seg_theme.append(btn_app_light)
        row_theme.append(seg_theme)
        card_theme.append(row_theme)
        if (btn_app_dark, btn_app_light) not in self.theme_mode_btn_pairs:
            self.theme_mode_btn_pairs.append((btn_app_dark, btn_app_light))
        self.register_search_item(self.current_cat_id, "Color Scheme", "Toggle dynamic Light or Dark Material You theme", row_theme)
        self.register_search_item(self.current_cat_id, "Appearance", "Hyprland window styling, borders, gaps, blur, shadows, and color scheme", card_theme)
        self.register_search_item(self.current_cat_id, "Look & Feel", "Hyprland window styling, borders, gaps, blur, shadows, and color scheme", card_theme)
        page.append(card_theme)

        # ── Card 2: Windows & Layout ──
        card_win = self.create_settings_card()
        lbl_win = Gtk.Label(label="Windows & Layout")
        lbl_win.set_halign(Gtk.Align.START)
        lbl_win.add_css_class("heading")
        card_win.append(lbl_win)

        cur_gi = int(self.looknfeel_cfg.get("gaps_in", 6))
        def on_gi_changed(v):
            self.looknfeel_cfg["gaps_in"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_win, "Inner Gaps", "Gaps between adjacent tiled windows", 0, 30, 1, cur_gi, "px", on_gi_changed)

        cur_go = int(self.looknfeel_cfg.get("gaps_out", 6))
        def on_go_changed(v):
            self.looknfeel_cfg["gaps_out"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_win, "Outer Gaps", "Gaps between windows and monitor screen edges", 0, 40, 1, cur_go, "px", on_go_changed)

        cur_b = int(self.looknfeel_cfg.get("border_size", 1))
        def on_b_changed(v):
            self.looknfeel_cfg["border_size"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_win, "Border Width", "Thickness of window border outline", 0, 6, 1, cur_b, "px", on_b_changed)

        layouts = ["Dwindle (Spiral / Fib)", "Master (Master & Stack)"]
        layout_ids = ["dwindle", "master"]
        cur_lay = str(self.looknfeel_cfg.get("layout", "dwindle")).lower()
        lay_idx = layout_ids.index(cur_lay) if cur_lay in layout_ids else 0
        def on_lay_changed(idx):
            self.looknfeel_cfg["layout"] = layout_ids[idx]
            self.mark_dirty()
        self.add_combo_row(card_win, "Window Layout", "Hyprland window tiling layout algorithm", layouts, lay_idx, on_lay_changed)

        cur_rob = bool(self.looknfeel_cfg.get("resize_on_border", False))
        def on_rob_toggle(act):
            self.looknfeel_cfg["resize_on_border"] = act
            self.mark_dirty()
        self.add_switch_row(card_win, "Resize on Border", "Resize windows by clicking and dragging on borders and gaps", cur_rob, on_rob_toggle)

        cur_tear = bool(self.looknfeel_cfg.get("allow_tearing", False))
        def on_tear_toggle(act):
            self.looknfeel_cfg["allow_tearing"] = act
            self.mark_dirty()
        self.add_switch_row(card_win, "Allow Tearing", "Reduce tearing latency for full-screen games / applications", cur_tear, on_tear_toggle)

        page.append(card_win)

        # ── Card 2: Corners & Transparency ──
        card_dec = self.create_settings_card()
        lbl_dec = Gtk.Label(label="Corners & Transparency")
        lbl_dec.set_halign(Gtk.Align.START)
        lbl_dec.add_css_class("heading")
        card_dec.append(lbl_dec)

        cur_r = int(self.looknfeel_cfg.get("rounding", 15))
        def on_r_changed(v):
            self.looknfeel_cfg["rounding"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_dec, "Corner Rounding", "Radius of window corners", 0, 30, 1, cur_r, "px", on_r_changed)

        cur_rp = int(self.looknfeel_cfg.get("rounding_power", 2))
        def on_rp_changed(v):
            self.looknfeel_cfg["rounding_power"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_dec, "Rounding Power", "Curvature exponent (squircle shape factor)", 1, 5, 1, cur_rp, "pow", on_rp_changed)

        cur_ao = int(float(self.looknfeel_cfg.get("active_opacity", 0.80)) * 100)
        def on_ao_changed(v):
            self.looknfeel_cfg["active_opacity"] = round(v / 100.0, 2)
            self.mark_dirty()
        self.add_slider_row(card_dec, "Active Window Opacity", "Focused window surface transparency", 20, 100, 5, cur_ao, "%", on_ao_changed)

        cur_io = int(float(self.looknfeel_cfg.get("inactive_opacity", 0.95)) * 100)
        def on_io_changed(v):
            self.looknfeel_cfg["inactive_opacity"] = round(v / 100.0, 2)
            self.mark_dirty()
        self.add_slider_row(card_dec, "Inactive Window Opacity", "Unfocused window surface transparency", 20, 100, 5, cur_io, "%", on_io_changed)

        page.append(card_dec)

        # ── Card 3: Window Shadows ──
        card_sh = self.create_settings_card()
        lbl_sh = Gtk.Label(label="Window Shadows")
        lbl_sh.set_halign(Gtk.Align.START)
        lbl_sh.add_css_class("heading")
        card_sh.append(lbl_sh)

        cur_she = bool(self.looknfeel_cfg.get("shadow_enabled", True))
        def on_she_toggle(act):
            self.looknfeel_cfg["shadow_enabled"] = act
            self.mark_dirty()
        self.add_switch_row(card_sh, "Enable Drop Shadows", "Render soft shadows around floating and tiled windows", cur_she, on_she_toggle)

        cur_shr = int(self.looknfeel_cfg.get("shadow_range", 15))
        def on_shr_changed(v):
            self.looknfeel_cfg["shadow_range"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_sh, "Shadow Range", "Shadow spread distance", 0, 50, 1, cur_shr, "px", on_shr_changed)

        cur_shp = int(self.looknfeel_cfg.get("shadow_render_power", 3))
        def on_shp_changed(v):
            self.looknfeel_cfg["shadow_render_power"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_sh, "Shadow Render Power", "Falloff sharpness / density power", 1, 4, 1, cur_shp, "pow", on_shp_changed)

        page.append(card_sh)

        # ── Card 4: Backdrop Blur ──
        card_blur = self.create_settings_card()
        lbl_bl = Gtk.Label(label="Backdrop Blur")
        lbl_bl.set_halign(Gtk.Align.START)
        lbl_bl.add_css_class("heading")
        card_blur.append(lbl_bl)

        cur_ble = bool(self.looknfeel_cfg.get("blur_enabled", True))
        def on_ble_toggle(act):
            self.looknfeel_cfg["blur_enabled"] = act
            self.mark_dirty()
        self.add_switch_row(card_blur, "Enable Window Blur", "Dual-kawase backdrop blur behind transparent windows", cur_ble, on_ble_toggle)

        cur_bls = int(self.looknfeel_cfg.get("blur_size", 5))
        def on_bls_changed(v):
            self.looknfeel_cfg["blur_size"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_blur, "Blur Radius Size", "Kernel sample distance radius", 1, 20, 1, cur_bls, "px", on_bls_changed)

        cur_blp = int(self.looknfeel_cfg.get("blur_passes", 2))
        def on_blp_changed(v):
            self.looknfeel_cfg["blur_passes"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_blur, "Blur Passes", "Filter iterations (higher = smoother, GPU intensive)", 1, 5, 1, cur_blp, "passes", on_blp_changed)

        cur_vib = int(float(self.looknfeel_cfg.get("blur_vibrancy", 0.1696)) * 100)
        def on_vib_changed(v):
            self.looknfeel_cfg["blur_vibrancy"] = round(v / 100.0, 4)
            self.mark_dirty()
        self.add_slider_row(card_blur, "Blur Vibrancy", "Color saturation boost through blur", 0, 100, 5, cur_vib, "%", on_vib_changed)

        cur_blio = bool(self.looknfeel_cfg.get("blur_ignore_opacity", True))
        def on_blio_toggle(act):
            self.looknfeel_cfg["blur_ignore_opacity"] = act
            self.mark_dirty()
        self.add_switch_row(card_blur, "Ignore Opacity", "Keep full blur intensity through semi-transparent surfaces", cur_blio, on_blio_toggle)

        cur_blpop = bool(self.looknfeel_cfg.get("blur_popups", True))
        def on_blpop_toggle(act):
            self.looknfeel_cfg["blur_popups"] = act
            self.mark_dirty()
        self.add_switch_row(card_blur, "Blur Popups", "Blur backdrop behind context menus and popups", cur_blpop, on_blpop_toggle)

        cur_blxr = bool(self.looknfeel_cfg.get("blur_xray", True))
        def on_blxr_toggle(act):
            self.looknfeel_cfg["blur_xray"] = act
            self.mark_dirty()
        self.add_switch_row(card_blur, "X-Ray Mode", "Floating windows blur directly through to wallpaper", cur_blxr, on_blxr_toggle)

        cur_blopt = bool(self.looknfeel_cfg.get("blur_new_optimizations", True))
        def on_blopt_toggle(act):
            self.looknfeel_cfg["blur_new_optimizations"] = act
            self.mark_dirty()
        self.add_switch_row(card_blur, "Optimized Blur", "Enable optimized dual-kawase rendering pipelines", cur_blopt, on_blopt_toggle)

        cur_blsp = bool(self.looknfeel_cfg.get("blur_special", False))
        def on_blsp_toggle(act):
            self.looknfeel_cfg["blur_special"] = act
            self.mark_dirty()
        self.add_switch_row(card_blur, "Special Workspace Blur", "Blur behind special scratchpad workspaces", cur_blsp, on_blsp_toggle)

        # ── Blur & Opacity App Exceptions ──
        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep.set_margin_top(8)
        sep.set_margin_bottom(8)
        card_blur.append(sep)

        exc_header_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        exc_header_row.add_css_class("settings-row")

        exc_lb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        exc_lb.set_hexpand(True)
        lbl_exc_t = Gtk.Label(label="Blur & Opacity App Exceptions")
        lbl_exc_t.set_halign(Gtk.Align.START)
        lbl_exc_t.add_css_class("row-title")
        exc_lb.append(lbl_exc_t)

        lbl_exc_s = Gtk.Label(label="Exclude specific apps (media players, browsers, games, etc.) from window blur and transparency")
        lbl_exc_s.set_halign(Gtk.Align.START)
        lbl_exc_s.add_css_class("row-subtitle")
        exc_lb.append(lbl_exc_s)
        exc_header_row.append(exc_lb)

        btn_add_exc = Gtk.Button(label="Add Exception")
        btn_add_exc.set_icon_name("list-add-symbolic")
        btn_add_exc.add_css_class("suggested-action")
        btn_add_exc.set_valign(Gtk.Align.CENTER)
        def on_open_picker(b):
            picker = AppPickerWindow(self, self.on_app_exception_added)
            picker.present()
        btn_add_exc.connect("clicked", on_open_picker)
        exc_header_row.append(btn_add_exc)
        card_blur.append(exc_header_row)
        self.register_search_item(self.current_cat_id, "Blur & Opacity App Exceptions", "Exclude specific apps from window blur and transparency", exc_header_row)

        self.exceptions_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.exceptions_box.set_margin_start(4)
        self.exceptions_box.set_margin_end(4)
        card_blur.append(self.exceptions_box)

        self.render_exceptions_list()

        page.append(card_blur)

        # ── Card 5: Shell & Wallpaper ──
        card_wp = self.create_settings_card()
        lbl_wp = Gtk.Label(label="Shell & Wallpaper")
        lbl_wp.set_halign(Gtk.Align.START)
        lbl_wp.add_css_class("heading")
        card_wp.append(lbl_wp)

        cur_scale = float(self.bar_pos.get("scale", 1.0))
        def on_scale_changed(v):
            self.bar_pos["scale"] = v
            self.mark_dirty()
        self.add_slider_row(card_wp, "Shell UI Scale", "Scale bars, menus, and widgets", 0.75, 1.50, 0.05, cur_scale, "x", on_scale_changed)

        provider_options = ["Unsplash (High-Res Curated Photography)", "Wallhaven (Anime & Digital Art)"]
        provider_ids = ["unsplash", "wallhaven"]
        cur_prov = str(self.wallpaper_source_cfg.get("provider", "unsplash")).lower()
        cur_p_idx = provider_ids.index(cur_prov) if cur_prov in provider_ids else 0
        def on_provider_sel(idx):
            self.wallpaper_source_cfg["provider"] = provider_ids[idx]
            self.mark_dirty()
        self.add_combo_row(card_wp, "Online Wallpaper Provider", "Source catalog used for online wallpapers in the wallpaper picker", provider_options, cur_p_idx, on_provider_sel)

        cur_key = self.wallpaper_source_cfg.get("unsplash_access_key", "")
        def on_key_change(val):
            self.wallpaper_source_cfg["unsplash_access_key"] = val.strip()
            self.mark_dirty()
        self.add_entry_row(card_wp, "Unsplash Access Key (Optional)", "Custom developer API key for quotas (leave empty for built-in catalog)", cur_key, "Leave empty for built-in catalog", on_key_change)

        page.append(card_wp)
        return page

    build_looknfeel_page = build_appearance_page

    # ── Category 6: Motion ──────────────────────────────────────────────────
    def build_motion_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)
        card = self.create_settings_card()

        reduce_act = bool(self.motion_cfg.get("reduceMotion", False))
        def on_reduce(act):
            self.motion_cfg["reduceMotion"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Reduce motion", None, reduce_act, on_reduce)

        mov_dur = int(self.motion_cfg.get("movementDuration", 400))
        def on_mov(v):
            self.motion_cfg["movementDuration"] = v
            self.mark_dirty()
        self.add_slider_row(card, "Movement (size / position)", None, 0, 600, 20, mov_dur, "ms", on_mov)

        fade_dur = int(self.motion_cfg.get("fadeDuration", 200))
        def on_fade(v):
            self.motion_cfg["fadeDuration"] = v
            self.mark_dirty()
        self.add_slider_row(card, "Fades & colour", None, 0, 400, 10, fade_dur, "ms", on_fade)

        hover_dur = int(self.motion_cfg.get("hoverResponse", 150))
        def on_hover(v):
            self.motion_cfg["hoverResponse"] = v
            self.mark_dirty()
        self.add_slider_row(card, "Hover response", None, 0, 300, 10, hover_dur, "ms", on_hover)

        bounce_val = int(self.motion_cfg.get("bounce", 40))
        def on_bounce(v):
            self.motion_cfg["bounce"] = v
            self.mark_dirty()
        self.add_slider_row(card, "Bounce", None, 0, 100, 5, bounce_val, "%", on_bounce)

        page.append(card)
        return page

    # ── Category 7: Launcher ───────────────────────────────────────────────
    def build_launcher_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)

        # ── Card 1: Default Launcher Interface Toggle ──
        mode_card = self.create_settings_card()

        lbl_head = Gtk.Label(label="Launcher Interface")
        lbl_head.set_halign(Gtk.Align.START)
        lbl_head.add_css_class("heading")
        mode_card.append(lbl_head)

        cur_style = self.launcher_cfg.get("launcherStyle", self.launcher_cfg.get("defaultLauncher", "spotlight"))
        if cur_style not in ("spotlight", "launcher"):
            cur_style = "spotlight"

        sw_spotlight = None
        sw_drawer = None
        updating_switches = False

        def on_toggle_spotlight(active):
            nonlocal updating_switches
            if updating_switches:
                return
            updating_switches = True
            if active:
                self.launcher_cfg["launcherStyle"] = "spotlight"
                self.launcher_cfg["defaultLauncher"] = "spotlight"
                if sw_drawer:
                    sw_drawer.set_active(False)
            else:
                self.launcher_cfg["launcherStyle"] = "launcher"
                self.launcher_cfg["defaultLauncher"] = "launcher"
                if sw_drawer:
                    sw_drawer.set_active(True)
            self.mark_dirty()
            updating_switches = False

        def on_toggle_drawer(active):
            nonlocal updating_switches
            if updating_switches:
                return
            updating_switches = True
            if active:
                self.launcher_cfg["launcherStyle"] = "launcher"
                self.launcher_cfg["defaultLauncher"] = "launcher"
                if sw_spotlight:
                    sw_spotlight.set_active(False)
            else:
                self.launcher_cfg["launcherStyle"] = "spotlight"
                self.launcher_cfg["defaultLauncher"] = "spotlight"
                if sw_spotlight:
                    sw_spotlight.set_active(True)
            self.mark_dirty()
            updating_switches = False

        sw_spotlight = self.add_switch_row(
            mode_card,
            "Spotlight Search",
            "Modern keyboard-driven search bar for fast app launching, commands, and calculations",
            cur_style == "spotlight",
            on_toggle_spotlight
        )

        sw_drawer = self.add_switch_row(
            mode_card,
            "App Launcher Drawer",
            "Classic categorized application menu with Niagara alphabet wave and recent apps",
            cur_style == "launcher",
            on_toggle_drawer
        )

        page.append(mode_card)

        # ── Card 2: Launcher Preferences ──
        card = self.create_settings_card()

        lbl_head2 = Gtk.Label(label="Preferences & Animation")
        lbl_head2.set_halign(Gtk.Align.START)
        lbl_head2.add_css_class("heading")
        card.append(lbl_head2)

        speed = int(self.launcher_cfg.get("animationSpeed", 170))
        def on_speed(v):
            self.launcher_cfg["animationSpeed"] = v
            self.mark_dirty()
        self.add_slider_row(card, "Animation Speed", "Duration of opening spring animation", 100, 400, 10, speed, "ms", on_speed)

        rec_act = bool(self.launcher_cfg.get("showRecents", True))
        def on_rec(act):
            self.launcher_cfg["showRecents"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Recent Applications", "Show recently used apps on empty search", rec_act, on_rec)

        clip_act = bool(self.launcher_cfg.get("clipboardHistory", True))
        def on_clip(act):
            self.launcher_cfg["clipboardHistory"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Clipboard History Tab", "Enable clipboard manager in Spotlight search", clip_act, on_clip)

        max_r = int(self.launcher_cfg.get("maxResults", 8))
        def on_max(v):
            self.launcher_cfg["maxResults"] = v
            self.mark_dirty()
        self.add_slider_row(card, "Maximum Results", "Number of search results to display", 4, 16, 1, max_r, "items", on_max)

        page.append(card)
        return page

    # ── Category 8: Notifications ──────────────────────────────────────────
    def build_notifications_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)
        card = self.create_settings_card()

        en_act = bool(self.notif_cfg.get("enabled", True))
        def on_en(act):
            self.notif_cfg["enabled"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Enable Notifications", "Show banner popups for new messages", en_act, on_en)

        dnd_act = bool(self.notif_cfg.get("dnd", False))
        def on_dnd(act):
            self.notif_cfg["dnd"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Do Not Disturb", "Silence all incoming notification popups", dnd_act, on_dnd)

        timeout_val = int(self.notif_cfg.get("timeout", 5))
        def on_t(v):
            self.notif_cfg["timeout"] = v
            self.mark_dirty()
        self.add_slider_row(card, "Banner Timeout", "Time before popups dismiss automatically", 2, 10, 1, timeout_val, "s", on_t)

        page.append(card)
        return page

    # ── Category 9: Control Center ─────────────────────────────────────────
    def build_control_center_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)
        card = self.create_settings_card()

        vol_step = int(self.control_cfg.get("volumeStep", 5))
        def on_vol(v):
            self.control_cfg["volumeStep"] = v
            self.mark_dirty()
        self.add_slider_row(card, "Volume Step", "Step amount for volume keys and sliders", 1, 10, 1, vol_step, "%", on_vol)

        br_step = int(self.control_cfg.get("brightnessStep", 5))
        def on_br(v):
            self.control_cfg["brightnessStep"] = v
            self.mark_dirty()
        self.add_slider_row(card, "Brightness Step", "Step amount for screen brightness keys", 1, 10, 1, br_step, "%", on_br)

        bat_act = bool(self.control_cfg.get("showBatteryPercent", True))
        def on_bat(act):
            self.control_cfg["showBatteryPercent"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Show Battery Percentage", "Display battery percentage text in the Control Center fluid card", bat_act, on_bat)

        page.append(card)
        return page

    # ── Category: Power & Battery ──────────────────────────────────────────
    def build_power_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)

        # ── Card 1: Power Modes ──
        card_modes = self.create_settings_card()
        lbl_m = Gtk.Label(label="Power Modes")
        lbl_m.set_halign(Gtk.Align.START)
        lbl_m.add_css_class("heading")
        card_modes.append(lbl_m)

        modes = [
            "Power Saver (Eco)",
            "Balanced (Standard)",
            "Performance (High)",
            "Ultra (Game Mode)"
        ]
        mode_ids = ["power-saver", "balanced", "performance", "ultra"]
        cur_mode = self.power_cfg.get("profile", "balanced")
        cur_idx = mode_ids.index(cur_mode) if cur_mode in mode_ids else 1

        def on_power_profile(idx):
            self.power_cfg["profile"] = mode_ids[idx]
            self.mark_dirty()

        self.add_combo_row(
            card_modes,
            "Active Power Profile",
            "Select CPU performance, energy bias, and gaming optimizations",
            modes,
            cur_idx,
            on_power_profile
        )
        page.append(card_modes)

        # ── Card 2: Physical Button & Lid Actions ──
        card_buttons = self.create_settings_card()
        lbl_b = Gtk.Label(label="Physical Button & Lid Actions")
        lbl_b.set_halign(Gtk.Align.START)
        lbl_b.add_css_class("heading")
        card_buttons.append(lbl_b)

        btn_actions = ["Shut Down", "Sleep / Suspend", "Hibernate", "Lock Screen", "Do Nothing"]
        btn_action_ids = ["poweroff", "suspend", "hibernate", "lock", "ignore"]

        cur_pwr = self.power_cfg.get("powerButtonAction", "poweroff")
        pwr_idx = btn_action_ids.index(cur_pwr) if cur_pwr in btn_action_ids else 0
        def on_pwr_btn(idx):
            self.power_cfg["powerButtonAction"] = btn_action_ids[idx]
            self.mark_dirty()
        self.add_combo_row(card_buttons, "Power Button Action", "Action when hardware power key is pressed", btn_actions, pwr_idx, on_pwr_btn)

        sleep_actions = ["Sleep / Suspend", "Hibernate", "Lock Screen", "Do Nothing"]
        sleep_action_ids = ["suspend", "hibernate", "lock", "ignore"]
        cur_slp = self.power_cfg.get("sleepButtonAction", "suspend")
        slp_idx = sleep_action_ids.index(cur_slp) if cur_slp in sleep_action_ids else 0
        def on_slp_btn(idx):
            self.power_cfg["sleepButtonAction"] = sleep_action_ids[idx]
            self.mark_dirty()
        self.add_combo_row(card_buttons, "Sleep Button Action", "Action when hardware sleep key is pressed", sleep_actions, slp_idx, on_slp_btn)

        lid_actions = ["Sleep / Suspend", "Hibernate", "Turn off display & Lock", "Shut Down", "Do Nothing"]
        lid_action_ids = ["suspend", "hibernate", "lock_dpms", "poweroff", "ignore"]

        cur_lid_bat = self.power_cfg.get("lidActionBattery", "suspend")
        lid_bat_idx = lid_action_ids.index(cur_lid_bat) if cur_lid_bat in lid_action_ids else 0
        def on_lid_bat(idx):
            self.power_cfg["lidActionBattery"] = lid_action_ids[idx]
            self.mark_dirty()
        self.add_combo_row(card_buttons, "Lid Close (On Battery)", "Action when closing laptop lid while running on battery", lid_actions, lid_bat_idx, on_lid_bat)

        cur_lid_ac = self.power_cfg.get("lidActionAC", "suspend")
        lid_ac_idx = lid_action_ids.index(cur_lid_ac) if cur_lid_ac in lid_action_ids else 0
        def on_lid_ac(idx):
            self.power_cfg["lidActionAC"] = lid_action_ids[idx]
            self.mark_dirty()
        self.add_combo_row(card_buttons, "Lid Close (Plugged In / AC)", "Action when closing laptop lid while connected to charger", lid_actions, lid_ac_idx, on_lid_ac)

        page.append(card_buttons)

        # ── Card 3: Sleep Mode & Hibernation ──
        card_sleep = self.create_settings_card()
        lbl_s = Gtk.Label(label="Sleep Mode & Hibernation")
        lbl_s.set_halign(Gtk.Align.START)
        lbl_s.add_css_class("heading")
        card_sleep.append(lbl_s)

        # Sleep Row
        row_sleep = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_sleep.add_css_class("settings-row")
        row_sleep.set_hexpand(True)
        lbl_box_s = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lbl_box_s.set_hexpand(True)
        lbl_s_t = Gtk.Label(label="Sleep Mode (Suspend to RAM)")
        lbl_s_t.set_halign(Gtk.Align.START)
        lbl_s_t.add_css_class("row-title")
        lbl_box_s.append(lbl_s_t)
        lbl_s_d = Gtk.Label(label="Low-power state that keeps current sessions in RAM for instant wake-up.")
        lbl_s_d.set_halign(Gtk.Align.START)
        lbl_s_d.set_wrap(True)
        lbl_s_d.set_wrap_mode(Pango.WrapMode.WORD)
        lbl_s_d.add_css_class("row-subtitle")
        lbl_box_s.append(lbl_s_d)
        row_sleep.append(lbl_box_s)

        btn_test_sleep = Gtk.Button(label="Test Sleep Now")
        btn_test_sleep.set_valign(Gtk.Align.CENTER)
        btn_test_sleep.connect("clicked", lambda b: subprocess.Popen(["bash", "-c", "sleep 0.5 && systemctl suspend"]))
        row_sleep.append(btn_test_sleep)
        card_sleep.append(row_sleep)
        self.register_search_item(self.current_cat_id, "Sleep Mode (Suspend to RAM)", "Low-power state that keeps current sessions in RAM for instant wake-up", row_sleep)

        # Hibernation Row
        row_hib = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_hib.add_css_class("settings-row")
        row_hib.set_hexpand(True)
        lbl_box_h = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        lbl_box_h.set_hexpand(True)
        lbl_h_t = Gtk.Label(label="Hibernation (Suspend to Disk)")
        lbl_h_t.set_halign(Gtk.Align.START)
        lbl_h_t.add_css_class("row-title")
        lbl_box_h.append(lbl_h_t)
        lbl_h_d = Gtk.Label(label="Saves the entire RAM state to hard drive/SSD and powers off device completely.")
        lbl_h_d.set_halign(Gtk.Align.START)
        lbl_h_d.set_wrap(True)
        lbl_h_d.set_wrap_mode(Pango.WrapMode.WORD)
        lbl_h_d.add_css_class("row-subtitle")
        lbl_box_h.append(lbl_h_d)
        row_hib.append(lbl_box_h)

        btn_test_hib = Gtk.Button(label="Test Hibernation Now")
        btn_test_hib.set_valign(Gtk.Align.CENTER)
        btn_test_hib.connect("clicked", lambda b: subprocess.Popen(["bash", "-c", "sleep 0.5 && systemctl hibernate"]))
        row_hib.append(btn_test_hib)
        card_sleep.append(row_hib)
        self.register_search_item(self.current_cat_id, "Hibernation (Suspend to Disk)", "Saves the entire RAM state to the hard drive/SSD and powers off completely", row_hib)

        page.append(card_sleep)

        # ── Card 4: Display Timeout & Brightness ──
        card_disp = self.create_settings_card()
        lbl_d = Gtk.Label(label="Display Timeout & Brightness")
        lbl_d.set_halign(Gtk.Align.START)
        lbl_d.add_css_class("heading")
        card_disp.append(lbl_d)

        cur_dim_en = bool(self.power_cfg.get("dimEnabled", True))
        def on_dim_en(act):
            self.power_cfg["dimEnabled"] = act
            self.mark_dirty()
        self.add_switch_row(card_disp, "Screen Inactivity Dimming", "Automatically reduce screen backlight during inactivity", cur_dim_en, on_dim_en)

        dim_timeouts = ["1 Minute", "2 Minutes", "3 Minutes", "5 Minutes", "10 Minutes"]
        dim_vals = [60, 120, 180, 300, 600]
        cur_dim_val = int(self.power_cfg.get("dimTimeout", 180))
        cur_dim_idx = dim_vals.index(cur_dim_val) if cur_dim_val in dim_vals else 2
        def on_dim_timeout(idx):
            self.power_cfg["dimTimeout"] = dim_vals[idx]
            self.mark_dirty()
        self.add_combo_row(card_disp, "Dimming Timeout", "Inactivity delay before lowering screen backlight", dim_timeouts, cur_dim_idx, on_dim_timeout)

        cur_dim_pct = int(self.power_cfg.get("dimBrightnessPercent", 20))
        def on_dim_pct(v):
            self.power_cfg["dimBrightnessPercent"] = int(v)
            self.mark_dirty()
        self.add_slider_row(card_disp, "Dimmed Backlight Level", "Target brightness percentage when dimmed", 5, 50, 5, cur_dim_pct, "%", on_dim_pct)

        turnoff_opts = ["Never", "2 Minutes", "5 Minutes", "10 Minutes", "15 Minutes", "30 Minutes"]
        turnoff_vals = [0, 120, 300, 600, 900, 1800]
        cur_off_val = int(self.power_cfg.get("screenOffTimeout", 300))
        cur_off_idx = turnoff_vals.index(cur_off_val) if cur_off_val in turnoff_vals else 2
        def on_screen_off(idx):
            self.power_cfg["screenOffTimeout"] = turnoff_vals[idx]
            self.mark_dirty()
        self.add_combo_row(card_disp, "Screen Turn-Off Timeout", "Idle duration before display enters standby (DPMS off)", turnoff_opts, cur_off_idx, on_screen_off)

        suspend_opts = ["Never", "10 Minutes", "15 Minutes", "20 Minutes", "30 Minutes", "1 Hour"]
        suspend_vals = [0, 600, 900, 1200, 1800, 3600]
        cur_susp_val = int(self.power_cfg.get("autoSuspendTimeout", 1800))
        cur_susp_idx = suspend_vals.index(cur_susp_val) if cur_susp_val in suspend_vals else 4
        def on_auto_suspend(idx):
            self.power_cfg["autoSuspendTimeout"] = suspend_vals[idx]
            self.mark_dirty()
        self.add_combo_row(card_disp, "Automatic Suspend Timeout", "Idle duration before system automatically enters sleep mode", suspend_opts, cur_susp_idx, on_auto_suspend)

        page.append(card_disp)
        return page

    # ── Category 10: Lock Screen ────────────────────────────────────────────
    def build_lockscreen_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)
        card = self.create_settings_card()

        layouts = ["Modern Minimal", "Glass Card", "Bold Clock"]
        cur_l = self.lock_cfg.get("layout", "modern")
        idx = {"modern": 0, "glass": 1, "bold": 2}.get(cur_l, 0)
        def on_l_changed(sel):
            self.lock_cfg["layout"] = ["modern", "glass", "bold"][sel]
            self.mark_dirty()
        self.add_combo_row(card, "Lock Screen Layout", "Visual layout of hyprlock interface", layouts, idx, on_l_changed)

        blur_r = int(self.lock_cfg.get("blurRadius", 2))
        def on_blur_r(v):
            self.lock_cfg["blurRadius"] = v
            self.mark_dirty()
        self.add_slider_row(card, "Background Blur", "Amount of backdrop blur when locked", 0, 10, 1, blur_r, "passes", on_blur_r)

        media_act = bool(self.lock_cfg.get("showMedia", self.lock_cfg.get("mediaOverlay", True)))
        def on_media(act):
            self.lock_cfg["showMedia"] = act
            self.lock_cfg["mediaOverlay"] = act
            self.mark_dirty()
        self.add_switch_row(card, "Media Player on Lock Screen", "Show currently playing track when locked", media_act, on_media)

        page.append(card)

        # ── Card 2: Cairo Kinetic Lyrics Engine ──
        card_cairo = self.create_settings_card()
        lbl_cairo = Gtk.Label(label="Cairo Kinetic Lyrics")
        lbl_cairo.set_halign(Gtk.Align.START)
        lbl_cairo.add_css_class("heading")
        card_cairo.append(lbl_cairo)

        # Carbon // Cairo Synced-Lyric Mode Toggle
        cairo_act = bool(self.lock_cfg.get("cairoModeEnabled", self.lock_cfg.get("verciModeEnabled", False)))
        def on_cairo(act):
            self.lock_cfg["cairoModeEnabled"] = act
            self.lock_cfg["verciModeEnabled"] = act
            write_json(LOCKSCREEN_CONFIG_PATH, self.lock_cfg)
            # Sync to ~/.config/hypr/carbon-lockscreen.json
            hypr_lock_cfg = os.path.expanduser("~/.config/hypr/carbon-lockscreen.json")
            if hypr_lock_cfg != LOCKSCREEN_CONFIG_PATH:
                write_json(hypr_lock_cfg, self.lock_cfg)
            # Instantly inform Carbon Quickshell via IPC
            ipc_script = os.path.join(CONFIG_DIR, "scripts/carbon-ipc.sh")
            if not os.path.exists(ipc_script):
                ipc_script = os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh")
            if not os.path.exists(ipc_script):
                ipc_script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "carbon-ipc.sh")
            if os.path.exists(ipc_script):
                val_str = "true" if act else "false"
                subprocess.run(["sh", ipc_script, f"set-cairo-mode {val_str}"], check=False)
        self.add_switch_row(
            card_cairo,
            "Enable Cairo Kinetic Lyrics Mode",
            "Replace standard lock screen with kinetic synced lyrics standby on solid black (press Enter to unlock)",
            cairo_act,
            on_cairo
        )

        # English Converted Lyrics / Romanization Toggle
        romanize_act = bool(self.lock_cfg.get("cairoRomanizeLyrics", True))
        def on_romanize(act):
            self.lock_cfg["cairoRomanizeLyrics"] = act
            write_json(LOCKSCREEN_CONFIG_PATH, self.lock_cfg)
            hypr_lock_cfg = os.path.expanduser("~/.config/hypr/carbon-lockscreen.json")
            if hypr_lock_cfg != LOCKSCREEN_CONFIG_PATH:
                write_json(hypr_lock_cfg, self.lock_cfg)
            # Clear lyrics cache so current and subsequent tracks re-fetch in chosen mode
            import glob
            for f in glob.glob("/tmp/carbon-lyrics-cache/*.json"):
                try:
                    os.remove(f)
                except OSError:
                    pass
            ipc_script = os.path.expanduser("~/.config/carbon/scripts/carbon-ipc.sh")
            if os.path.exists(ipc_script):
                val_str = "true" if act else "false"
                subprocess.run(["sh", ipc_script, f"set-cairo-romanize {val_str}"], check=False)
                subprocess.run(["sh", ipc_script, "reload-cairo-lyrics"], check=False)
        self.add_switch_row(
            card_cairo,
            "English Converted Lyrics (Romanization)",
            "Pronounce non-English lyrics (Punjabi, Hindi, Russian, Korean, etc.) in readable English/Latin letters",
            romanize_act,
            on_romanize
        )

        page.append(card_cairo)
        return page

    # ── Category 11: System ────────────────────────────────────────────────
    def build_system_page(self, icon, title, subtitle):
        page = self.create_page_container(icon, title, subtitle)
        card = self.create_settings_card()

        # Check for Updates Row
        row_up = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_up.add_css_class("settings-row")

        label_box_up = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        label_box_up.set_hexpand(True)
        lbl_up_t = Gtk.Label(label="Check for Updates")
        lbl_up_t.set_halign(Gtk.Align.START)
        lbl_up_t.add_css_class("row-title")
        label_box_up.append(lbl_up_t)
        self.lbl_update_status = Gtk.Label(label="Check GitHub for new Carbon Shell releases and improvements")
        self.lbl_update_status.set_halign(Gtk.Align.START)
        self.lbl_update_status.add_css_class("row-subtitle")
        label_box_up.append(self.lbl_update_status)
        row_up.append(label_box_up)

        self.btn_check_update = Gtk.Button(label="Check Updates")
        self.btn_check_update.set_valign(Gtk.Align.CENTER)
        self.btn_check_update.connect("clicked", self.on_check_updates_clicked)
        row_up.append(self.btn_check_update)
        card.append(row_up)
        self.register_search_item(self.current_cat_id, "Check for Updates", "Check GitHub for new Carbon Shell releases and improvements", row_up)

        # Actions Row: Restart Carbon Shell
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.add_css_class("settings-row")

        label_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        label_box.set_hexpand(True)
        lbl_t = Gtk.Label(label="Restart Carbon Shell")
        lbl_t.set_halign(Gtk.Align.START)
        lbl_t.add_css_class("row-title")
        label_box.append(lbl_t)
        lbl_s = Gtk.Label(label="Reload quickshell daemon and apply visual updates")
        lbl_s.set_halign(Gtk.Align.START)
        lbl_s.add_css_class("row-subtitle")
        label_box.append(lbl_s)
        row.append(label_box)

        btn = Gtk.Button(label="Restart")
        btn.set_valign(Gtk.Align.CENTER)
        btn.connect("clicked", self.on_reload_shell)
        row.append(btn)
        card.append(row)
        self.register_search_item(self.current_cat_id, "Restart Carbon Shell", "Reload quickshell daemon and apply visual updates", row)

        # Reload Hyprland Row
        row_hl = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row_hl.add_css_class("settings-row")

        label_box_hl = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        label_box_hl.set_hexpand(True)
        lbl_hl_t = Gtk.Label(label="Reload Hyprland")
        lbl_hl_t.set_halign(Gtk.Align.START)
        lbl_hl_t.add_css_class("row-title")
        label_box_hl.append(lbl_hl_t)
        lbl_hl_s = Gtk.Label(label="Reload compositor rules, keybinds, and variables")
        lbl_hl_s.set_halign(Gtk.Align.START)
        lbl_hl_s.add_css_class("row-subtitle")
        label_box_hl.append(lbl_hl_s)
        row_hl.append(label_box_hl)

        btn_hl = Gtk.Button(label="Reload")
        btn_hl.set_valign(Gtk.Align.CENTER)
        btn_hl.connect("clicked", lambda b: subprocess.run(["hyprctl", "reload"], check=False))
        row_hl.append(btn_hl)
        card.append(row_hl)
        self.register_search_item(self.current_cat_id, "Reload Hyprland", "Reload compositor rules, keybinds, and variables", row_hl)

        page.append(card)
        return page

    # ── Reload Shell ───────────────────────────────────────────────────────
    def on_reload_shell(self, btn=None):
        try:
            subprocess.run(["systemctl", "--user", "restart", "carbon-quickshell.service"], check=False)
            subprocess.run(["hyprctl", "reload"], check=False)
        except Exception as e:
            print(f"Error restarting shell: {e}", file=sys.stderr)

    # ── Updates Management ────────────────────────────────────────────────
    def on_check_updates_clicked(self, btn):
        self.btn_check_update.set_sensitive(False)
        self.btn_check_update.set_label("Checking…")
        self.lbl_update_status.set_text("Connecting to remote repository and checking for updates…")
        threading.Thread(target=self._check_updates_worker, daemon=True).start()

    def _get_carbon_repo_dir(self):
        repo_file = os.path.join(CONFIG_DIR, "repo_path")
        if os.path.exists(repo_file):
            try:
                with open(repo_file, "r") as f:
                    line = f.readline().strip()
                    if os.path.isdir(os.path.join(line, ".git")):
                        return line
            except Exception:
                pass

        fallback = os.path.expanduser("~/carbon-shell")
        if os.path.isdir(os.path.join(fallback, ".git")):
            return fallback

        fallback2 = os.path.expanduser("~/.local/share/carbon-shell")
        if os.path.isdir(os.path.join(fallback2, ".git")):
            return fallback2

        return None

    def _check_updates_worker(self):
        repo_dir = self._get_carbon_repo_dir()
        if not repo_dir:
            GLib.idle_add(
                self._on_check_updates_result,
                "error",
                "Carbon Shell repository could not be located.",
                0,
                "",
                ""
            )
            return

        def git_run(args, timeout=15):
            res = subprocess.run(
                ["git"] + args,
                cwd=repo_dir,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return res.returncode, res.stdout.strip(), res.stderr.strip()

        try:
            _, curr_branch, _ = git_run(["rev-parse", "--abbrev-ref", "HEAD"])
            if not curr_branch:
                curr_branch = "main"

            # 1. Determine upstream remote (prefer origin, fallback to first configured remote)
            code_origin, _, _ = git_run(["remote", "get-url", "origin"])
            upstream_remote = "origin" if code_origin == 0 else ""
            if not upstream_remote:
                _, remotes_list, _ = git_run(["remote"])
                remotes = remotes_list.split()
                upstream_remote = remotes[0] if remotes else "origin"

            # 2. Determine target branch on upstream
            remote_target = "main"
            code_verify, _, _ = git_run(["rev-parse", "--verify", f"{upstream_remote}/{curr_branch}"])
            if code_verify == 0:
                remote_target = curr_branch
            else:
                remote_target = "main"

            # 3. Fetch upstream remote
            code_fetch, _, _ = git_run(["fetch", upstream_remote, remote_target], timeout=15)
            if code_fetch != 0:
                GLib.idle_add(
                    self._on_check_updates_result,
                    "offline",
                    "Could not reach remote repository. Please check your internet connection.",
                    0,
                    "",
                    repo_dir
                )
                return

            ref_to_check = f"{upstream_remote}/{remote_target}"

            # 4. Also fetch tracking remote if on custom fork branch
            _, upstream_tracking, _ = git_run(["rev-parse", "--abbrev-ref", "@{u}"])
            if upstream_tracking and upstream_tracking != "@{u}" and "/" in upstream_tracking:
                track_remote, track_branch = upstream_tracking.split("/", 1)
                if track_remote != upstream_remote:
                    git_run(["fetch", track_remote, track_branch], timeout=15)

            # 5. Check how many new upstream commits exist
            _, count_str, _ = git_run(["rev-list", "--count", f"HEAD..{ref_to_check}"])
            count = int(count_str) if count_str.isdigit() else 0

            # If no new upstream commits on main, check if tracking branch has commits ahead
            if count == 0 and upstream_tracking and upstream_tracking != "@{u}":
                _, count_track_str, _ = git_run(["rev-list", "--count", f"HEAD..{upstream_tracking}"])
                track_count = int(count_track_str) if count_track_str.isdigit() else 0
                if track_count > 0:
                    count = track_count
                    ref_to_check = upstream_tracking

            _, local_hash, _ = git_run(["rev-parse", "HEAD"])
            _, commits_log, _ = git_run([
                "log", "--oneline", "--no-merges", "-n", "5", f"HEAD..{ref_to_check}"
            ])

            if count > 0:
                GLib.idle_add(
                    self._on_check_updates_result,
                    "update_available",
                    f"Update available: {count} new commit{'s' if count != 1 else ''} found.",
                    count,
                    commits_log,
                    repo_dir
                )
            else:
                short_hash = local_hash[:8] if local_hash else ""
                GLib.idle_add(
                    self._on_check_updates_result,
                    "up_to_date",
                    f"Carbon Shell is up to date ({short_hash}).",
                    0,
                    "",
                    repo_dir
                )
        except Exception as e:
            GLib.idle_add(
                self._on_check_updates_result,
                "error",
                f"Check failed: {e}",
                0,
                "",
                repo_dir
            )

    def _on_check_updates_result(self, status, message, count, commits_log, repo_dir):
        self.btn_check_update.set_sensitive(True)
        self.btn_check_update.set_label("Check Updates")
        self.lbl_update_status.set_text(message)

        if status == "update_available":
            self._show_update_available_dialog(count, commits_log, repo_dir)
        elif status == "up_to_date":
            self._show_up_to_date_dialog(message)

    def _show_update_available_dialog(self, count, commits_log, repo_dir):
        log_snippet = ""
        if commits_log:
            lines = [f"  • {l}" for l in commits_log.strip().split("\n")[:4]]
            log_snippet = "\n\nRecent improvements:\n" + "\n".join(lines)

        body_text = (
            f"A newer version of Carbon Shell is available ({count} new commit{'s' if count != 1 else ''})."
            f"{log_snippet}\n\n"
            "Would you like to update now, or continue using your current version?"
        )

        def on_response(resp):
            if resp == "update":
                self.lbl_update_status.set_text("Launching Carbon Shell updater…")
                self._launch_updater(repo_dir)
            else:
                self.lbl_update_status.set_text(
                    f"Update available ({count} new commit{'s' if count != 1 else ''}) • Kept current version"
                )

        if hasattr(Adw, "AlertDialog"):
            dialog = Adw.AlertDialog(
                heading="Update Available",
                body=body_text
            )
            dialog.add_response("later", "Later")
            dialog.add_response("update", "Update Now")
            dialog.set_response_appearance("update", Adw.ResponseAppearance.SUGGESTED)
            dialog.set_default_response("update")
            dialog.set_close_response("later")
            dialog.connect("response", lambda d, r: on_response(r))
            dialog.present(self)
        else:
            dialog = Adw.MessageDialog(
                transient_for=self,
                heading="Update Available",
                body=body_text
            )
            dialog.add_response("later", "Later")
            dialog.add_response("update", "Update Now")
            dialog.set_response_appearance("update", Adw.ResponseAppearance.SUGGESTED)
            dialog.set_default_response("update")
            dialog.set_close_response("later")
            dialog.connect("response", lambda d, r: on_response(r))
            dialog.present()

    def _show_up_to_date_dialog(self, message):
        if hasattr(Adw, "AlertDialog"):
            dialog = Adw.AlertDialog(
                heading="Carbon Shell is Up to Date",
                body=message
            )
            dialog.add_response("ok", "OK")
            dialog.set_default_response("ok")
            dialog.set_close_response("ok")
            dialog.present(self)
        else:
            dialog = Adw.MessageDialog(
                transient_for=self,
                heading="Carbon Shell is Up to Date",
                body=message
            )
            dialog.add_response("ok", "OK")
            dialog.set_default_response("ok")
            dialog.set_close_response("ok")
            dialog.present()

    def _launch_updater(self, repo_dir):
        updater_cmd = shutil.which("carbon-update") or os.path.expanduser("~/.local/bin/carbon-update")
        if (not updater_cmd or not os.path.exists(updater_cmd)) and repo_dir:
            updater_cmd = os.path.join(repo_dir, "update.sh")

        term = None
        for candidate in ["kitty", "alacritty", "foot", "ghostty", "wezterm", "gnome-terminal", "xterm"]:
            path = shutil.which(candidate) or (
                os.path.expanduser(f"~/.local/bin/{candidate}")
                if os.path.exists(os.path.expanduser(f"~/.local/bin/{candidate}")) else None
            )
            if path and os.path.isfile(path) and os.access(path, os.X_OK):
                term = path
                break

        if term and updater_cmd and os.path.exists(updater_cmd):
            run_script = f'"{updater_cmd}"; echo; read -n 1 -s -r -p "Press any key to close..."; exit'
            try:
                base_term = os.path.basename(term).lower()
                if "kitty" in base_term or "foot" in base_term:
                    cmd = [term, "--title", "Carbon Shell Updater", "bash", "-c", run_script]
                elif "alacritty" in base_term:
                    cmd = [term, "--title", "Carbon Shell Updater", "-e", "bash", "-c", run_script]
                else:
                    cmd = [term, "-e", "bash", "-c", run_script]
                subprocess.Popen(cmd)
                return
            except Exception as e:
                print(f"Error launching terminal updater: {e}", file=sys.stderr)

        try:
            if updater_cmd and os.path.exists(updater_cmd):
                subprocess.Popen([updater_cmd, "-y"])
            else:
                self.lbl_update_status.set_text("Error: carbon-update script not found.")
        except Exception as e:
            self.lbl_update_status.set_text(f"Could not launch updater: {e}")

    # ── Blur & Opacity App Exceptions Helpers ──────────────────────────────
    def on_app_exception_added(self, app_info):
        cls = app_info.get("class", "").strip()
        if not cls:
            return
        for item in self.blur_exceptions:
            if item.get("class", "").strip().lower() == cls.lower():
                return
        self.blur_exceptions.append({
            "name": app_info.get("name", cls),
            "class": cls,
            "icon": app_info.get("icon", "application-x-executable")
        })
        self.mark_dirty()
        self.render_exceptions_list()

    def remove_app_exception(self, index):
        if 0 <= index < len(self.blur_exceptions):
            self.blur_exceptions.pop(index)
            self.mark_dirty()
            self.render_exceptions_list()

    def render_exceptions_list(self):
        while child := self.exceptions_box.get_first_child():
            self.exceptions_box.remove(child)

        if not self.blur_exceptions:
            empty_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
            empty_box.set_margin_top(4)
            empty_box.set_margin_bottom(4)
            empty_lbl = Gtk.Label(label="No app exceptions added. Blur and transparency apply to all applications.")
            empty_lbl.set_halign(Gtk.Align.START)
            empty_lbl.add_css_class("row-subtitle")
            empty_box.append(empty_lbl)
            self.exceptions_box.append(empty_box)
            return

        for idx, item in enumerate(self.blur_exceptions):
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            row.add_css_class("settings-row")

            img = Gtk.Image.new_from_icon_name(item.get("icon", "application-x-executable"))
            img.set_pixel_size(24)
            img.set_valign(Gtk.Align.CENTER)
            row.append(img)

            lb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            lb.set_hexpand(True)
            lb.set_valign(Gtk.Align.CENTER)

            title_lbl = Gtk.Label(label=item.get("name", item.get("class", "")))
            title_lbl.set_halign(Gtk.Align.START)
            title_lbl.add_css_class("row-title")
            lb.append(title_lbl)

            cls_lbl = Gtk.Label(label=f"Class: {item.get('class', '')}")
            cls_lbl.set_halign(Gtk.Align.START)
            cls_lbl.add_css_class("row-subtitle")
            lb.append(cls_lbl)

            row.append(lb)

            badge = Gtk.Label(label="Opaque • No Blur")
            badge.add_css_class("value-label")
            badge.set_valign(Gtk.Align.CENTER)
            row.append(badge)

            del_btn = Gtk.Button()
            del_btn.set_icon_name("user-trash-symbolic")
            del_btn.add_css_class("nav-circle-btn")
            del_btn.set_valign(Gtk.Align.CENTER)
            del_btn.set_tooltip_text("Remove exception")

            def make_del_handler(index):
                return lambda b: self.remove_app_exception(index)

            del_btn.connect("clicked", make_del_handler(idx))
            row.append(del_btn)

            self.exceptions_box.append(row)

    # ── Deferred Save & Close Confirmation ──────────────────────────────────
    def on_apply_clicked(self, btn):
        self.save_and_apply()

    def save_and_apply(self):
        # 1. Save all JSON configs
        write_json(BAR_MODE_PATH, self.bar_mode)
        hypr_bar_mode = os.path.expanduser("~/.config/hypr/carbon-bar-mode.json")
        if hypr_bar_mode != BAR_MODE_PATH:
            write_json(hypr_bar_mode, self.bar_mode)

        write_json(BAR_POS_PATH, self.bar_pos)
        hypr_bar_pos = os.path.expanduser("~/.config/hypr/carbon-bar-position.json")
        if hypr_bar_pos != BAR_POS_PATH:
            write_json(hypr_bar_pos, self.bar_pos)

        if hasattr(self, "tide_config") and self.tide_config:
            write_json(TIDE_USERCONFIG_PATH, self.tide_config)
            hypr_tide = os.path.expanduser("~/.config/hypr/tide-island-userconfig.json")
            if hypr_tide != TIDE_USERCONFIG_PATH:
                write_json(hypr_tide, self.tide_config)

        write_json(CLOCK_STYLE_PATH, self.clock_cfg)
        hypr_clock = os.path.expanduser("~/.config/hypr/carbon-clock-style.json")
        if hypr_clock != CLOCK_STYLE_PATH:
            write_json(hypr_clock, self.clock_cfg)

        write_json(MOTION_CONFIG_PATH, self.motion_cfg)
        hypr_motion = os.path.expanduser("~/.config/hypr/carbon-motion.json")
        if hypr_motion != MOTION_CONFIG_PATH:
            write_json(hypr_motion, self.motion_cfg)

        write_json(LAUNCHER_CONFIG_PATH, self.launcher_cfg)
        hypr_launcher = os.path.expanduser("~/.config/hypr/carbon-launcher.json")
        if hypr_launcher != LAUNCHER_CONFIG_PATH:
            write_json(hypr_launcher, self.launcher_cfg)

        write_json(NOTIF_CONFIG_PATH, self.notif_cfg)
        hypr_notif = os.path.expanduser("~/.config/hypr/carbon-notifications.json")
        if hypr_notif != NOTIF_CONFIG_PATH:
            write_json(hypr_notif, self.notif_cfg)

        write_json(CONTROL_CONFIG_PATH, self.control_cfg)
        hypr_ctrl = os.path.expanduser("~/.config/hypr/carbon-control-center.json")
        if hypr_ctrl != CONTROL_CONFIG_PATH:
            write_json(hypr_ctrl, self.control_cfg)

        write_json(LOCKSCREEN_CONFIG_PATH, self.lock_cfg)
        hypr_lock = os.path.expanduser("~/.config/hypr/carbon-lockscreen.json")
        if hypr_lock != LOCKSCREEN_CONFIG_PATH:
            write_json(hypr_lock, self.lock_cfg)

        write_json(VANISH_SHORTCUTS_PATH, self.vanish_shortcuts)
        generate_vanish_keybinds_conf(self.vanish_shortcuts)

        write_json(WALLPAPER_SOURCE_PATH, self.wallpaper_source_cfg)
        hypr_wp_path = os.path.expanduser("~/.config/hypr/carbon-wallpaper-source.json")
        if hypr_wp_path != WALLPAPER_SOURCE_PATH:
            write_json(hypr_wp_path, self.wallpaper_source_cfg)

        write_power_configs(self.power_cfg)

        if hasattr(self, "save_tile_config"):
            self.save_tile_config()

        # 2. Save variables.lua if needed
        if "rounding" in self.looknfeel_cfg:
            write_variable("rounding", self.looknfeel_cfg["rounding"])
        if "border_size" in self.looknfeel_cfg:
            write_variable("borderSize", self.looknfeel_cfg["border_size"])
        if "active_opacity" in self.looknfeel_cfg:
            write_variable("windowOpacity", self.looknfeel_cfg["active_opacity"])

        # 3. Save looknfeel.conf & blur-exceptions.conf
        write_looknfeel_config(self.looknfeel_cfg)
        write_json(BLUR_EXCEPTIONS_JSON, self.blur_exceptions)
        hypr_blur_json = os.path.expanduser("~/.config/hypr/carbon-blur-exceptions.json")
        if hypr_blur_json != BLUR_EXCEPTIONS_JSON:
            write_json(hypr_blur_json, self.blur_exceptions)
        write_blur_exceptions_config(self.blur_exceptions)

        # 4. Save lockscreen hyprlock.conf if blurRadius changed
        if "blurRadius" in self.lock_cfg:
            blur_val = int(self.lock_cfg["blurRadius"])
            hyprlock_paths = [
                os.path.expanduser("~/.config/hypr/hyprlock.conf"),
                os.path.expanduser("~/.config/carbon/hyprlock.conf"),
                os.path.expanduser("~/carbon-shell/hypr/hyprlock.conf"),
            ]
            for h_path in hyprlock_paths:
                if os.path.exists(h_path):
                    try:
                        with open(h_path, "r", encoding="utf-8") as f:
                            c = f.read()
                        c = re.sub(r"(blur_passes\s*=\s*)\d+", rf"\g<1>{blur_val}", c)
                        with open(h_path, "w", encoding="utf-8") as f:
                            f.write(c)
                    except Exception:
                        pass

        # 5. Apply layer blur if pending
        if self.pending_layer_blur is not None:
            apply_hyprland_layer_blur(self.pending_layer_blur)

        # 6. Apply live Hyprland Look & Feel keywords
        apply_hyprland_looknfeel_live(self.looknfeel_cfg)

        # Live animations keyword
        if "reduceMotion" in self.motion_cfg:
            anim_enabled = "false" if self.motion_cfg["reduceMotion"] else "true"
            subprocess.run(["hyprctl", "keyword", "animations:enabled", anim_enabled], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        # Bar mode IPC
        mode_id = self.bar_mode.get("mode", "notch")
        ipc_script = os.path.join(CONFIG_DIR, "scripts/carbon-ipc.sh")
        if not os.path.exists(ipc_script):
            ipc_script = os.path.expanduser("~/.config/hypr/scripts/carbon-ipc.sh")
        if os.path.exists(ipc_script):
            if mode_id == "nucleus":
                if self.bar_mode.get("nucleus", {}).get("transition", True):
                    subprocess.run(["sh", ipc_script, "nucleus transition"], check=False)
                else:
                    subprocess.run(["sh", ipc_script, "set-bar-mode nucleus"], check=False)
            else:
                subprocess.run(["sh", ipc_script, f"set-bar-mode {mode_id}"], check=False)


        # 7. Reload Mode-Specific Keybinds & Hyprland (Seamless IPC mode switch, zero service restart)
        try:
            keybinds_script = os.path.expanduser("~/.config/hypr/scripts/carbon-mode-keybinds.sh")
            if os.path.exists(keybinds_script):
                subprocess.run(["bash", keybinds_script, mode_id], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["hyprctl", "reload"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception as e:
            print("Error reloading keybinds or Hyprland:", e, file=sys.stderr)


        self.dirty = False
        self.lbl_status.set_text("Changes applied successfully.")
        self.apply_btn.set_sensitive(False)
        self.apply_btn.remove_css_class("suggested-action")

    def on_close_requested(self, window):
        if self.dirty:
            self.show_unsaved_changes_dialog()
            return True
        return False

    def show_unsaved_changes_dialog(self):
        def on_response(resp):
            if resp == "save":
                self.save_and_apply()
                self.dirty = False
                self.destroy()
            elif resp == "discard":
                self.dirty = False
                self.destroy()

        if hasattr(Adw, "AlertDialog"):
            dialog = Adw.AlertDialog(
                heading="You have unsaved changes",
                body=""
            )
            dialog.add_response("discard", "discard")
            dialog.add_response("save", "save")
            dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED)
            dialog.set_response_appearance("discard", Adw.ResponseAppearance.DESTRUCTIVE)
            dialog.set_default_response("save")
            dialog.set_close_response("cancel")
            dialog.connect("response", lambda d, r: on_response(r))
            dialog.present(self)
        else:
            dialog = Adw.MessageDialog(
                transient_for=self,
                heading="You have unsaved changes",
                body=""
            )
            dialog.add_response("discard", "discard")
            dialog.add_response("save", "save")
            dialog.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED)
            dialog.set_response_appearance("discard", Adw.ResponseAppearance.DESTRUCTIVE)
            dialog.set_default_response("save")
            dialog.set_close_response("cancel")
            dialog.connect("response", lambda d, r: on_response(r))
            dialog.present()

def main():
    app = CarbonConfigApp()
    return app.run([sys.argv[0]])

if __name__ == "__main__":
    sys.exit(main())
