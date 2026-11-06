#!/usr/bin/env bash
# ==============================================================================
# Carbon Shell — Mode Keybind Dispatcher
# Swaps Hyprland mode-specific keybinds in both .conf and .lua formats,
# then executes instant hyprctl reload.
# Guaranteed 0 symlinks. Fully externalized under CARBON_CONFIG_DIR.
# ==============================================================================

set -euo pipefail

CARBON_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
HYPR_DIR="${CARBON_HYPR_DIR:-$HOME/.config/hypr}"
HYPR_CONFIGS="$HYPR_DIR/configs"
CARBON_CONFIGS="$CARBON_DIR/configs"

MODE="${1:-}"

if [ -z "$MODE" ]; then
    JSON_PATH="$CARBON_DIR/carbon-bar-mode.json"
    if [ ! -f "$JSON_PATH" ] && [ -f "$HYPR_DIR/carbon-bar-mode.json" ]; then
        JSON_PATH="$HYPR_DIR/carbon-bar-mode.json"
    fi
    if [ -f "$JSON_PATH" ]; then
        MODE=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get('mode', 'minimal_notch'))" "$JSON_PATH" 2>/dev/null || echo "minimal_notch")
    else
        MODE="minimal_notch"
    fi
fi

# Normalize mode name across all 4 distinct shell modes
case "${MODE,,}" in
    notch|island|three_islands)
        NORM_MODE="notch"
        ;;
    pill|waybar)
        NORM_MODE="pill"
        ;;
    vanish|nucleus)
        NORM_MODE="vanish"
        ;;
    minimal|minimal_notch|tide)
        NORM_MODE="minimal"
        ;;
    *)
        NORM_MODE="minimal"
        ;;
esac

mkdir -p "$CARBON_CONFIGS" "$HYPR_CONFIGS" "$CARBON_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_CONFIGS="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)/configs"

SOURCE_CONF=""
for candidate in \
    "$CARBON_CONFIGS/keybinds-${NORM_MODE}.conf" \
    "$CARBON_DIR/keybinds-${NORM_MODE}.conf" \
    "$HYPR_CONFIGS/keybinds-${NORM_MODE}.conf" \
    "$REPO_CONFIGS/keybinds-${NORM_MODE}.conf" \
    "$HOME/carbon-shell/hypr/configs/keybinds-${NORM_MODE}.conf"; do
    if [ -f "$candidate" ]; then
        SOURCE_CONF="$candidate"
        break
    fi
done

TARGET_CARBON_CONF="$CARBON_CONFIGS/current-mode-keybinds.conf"
TARGET_HYPR_CONF="$HYPR_CONFIGS/current-mode-keybinds.conf"
TARGET_LUA="$HYPR_DIR/current-mode-keybinds.lua"
TARGET_CARBON_LUA="$CARBON_DIR/current-mode-keybinds.lua"

# 1. Update Hyprland Conf format in both external Carbon config dir and Hyprland config dir
if [ -n "$SOURCE_CONF" ] && [ -f "$SOURCE_CONF" ]; then
    if [ "$(realpath "$SOURCE_CONF" 2>/dev/null || echo "$SOURCE_CONF")" != "$(realpath "$TARGET_CARBON_CONF" 2>/dev/null || echo "$TARGET_CARBON_CONF")" ]; then
        cp -f "$SOURCE_CONF" "$TARGET_CARBON_CONF"
    fi
    if [ "$(realpath "$SOURCE_CONF" 2>/dev/null || echo "$SOURCE_CONF")" != "$(realpath "$TARGET_HYPR_CONF" 2>/dev/null || echo "$TARGET_HYPR_CONF")" ]; then
        cp -f "$SOURCE_CONF" "$TARGET_HYPR_CONF"
    fi
else
    echo "# Mode keybinds for $NORM_MODE (empty)" > "$TARGET_CARBON_CONF"
    echo "# Mode keybinds for $NORM_MODE (empty)" > "$TARGET_HYPR_CONF"
fi

# 2. Update Hyprland Lua format directly from the active mode .conf file (with clean fallback)
python3 -c '
import sys, os

mode = sys.argv[1]
conf_path = sys.argv[2]
lua_files = [sys.argv[3], sys.argv[4]]
home = os.environ.get("HOME", os.path.expanduser("~"))
carbon_dir = os.environ.get("CARBON_CONFIG_DIR", os.path.join(home, ".config/carbon"))

lines_out = [f"-- Active Mode: {mode} (synchronized from {os.path.basename(conf_path) if conf_path else mode})"]

if conf_path and os.path.exists(conf_path):
    with open(conf_path, "r", encoding="utf-8", errors="ignore") as f:
        for raw in f:
            s = raw.strip()
            if not s or s.startswith("#") or s.startswith("$"):
                continue
            if "=" not in s:
                continue
            lhs, rhs = s.split("=", 1)
            btype = lhs.strip()
            if not btype.startswith("bind"):
                continue
            parts = [p.strip() for p in rhs.split(",")]
            if len(parts) < 3:
                continue
            mods = parts[0].replace("$mainMod", "SUPER").strip()
            key = parts[1].strip()
            disp = parts[2].strip()
            arg = ",".join(parts[3:]).strip() if len(parts) > 3 else ""
            combo_tokens = [t for t in mods.split() if t]
            if key:
                combo_tokens.append(key)
            combo = " + ".join(combo_tokens)
            opts = []
            if "r" in btype[4:]:
                opts.append("release = true")
            if "e" in btype[4:]:
                opts.append("repeating = true")
            if "l" in btype[4:]:
                opts.append("locked = true")
            opt_str = (", { " + ", ".join(opts) + " }") if opts else ""
            if disp == "exec":
                cmd_escaped = arg.replace("\\", "\\\\").replace("\"", "\\\"")
                lines_out.append(f"hl.bind(\"{combo}\", hl.dsp.exec_cmd(\"{cmd_escaped}\"){opt_str})")
            elif disp == "fullscreen":
                lines_out.append(f"hl.bind(\"{combo}\", hl.dsp.window.fullscreen(){opt_str})")
            elif disp == "movefocus":
                dmap = {"l": "left", "r": "right", "u": "up", "d": "down"}
                lines_out.append(f"hl.bind(\"{combo}\", hl.dsp.focus({{ direction = \"{dmap.get(arg, arg)}\" }}){opt_str})")
            elif disp == "movewindow":
                lines_out.append(f"hl.bind(\"{combo}\", hl.dsp.window.move({{ direction = \"{arg}\" }}){opt_str})")
            else:
                cmd_escaped = f"hyprctl dispatch {disp} {arg}".strip().replace("\\", "\\\\").replace("\"", "\\\"")
                lines_out.append(f"hl.bind(\"{combo}\", hl.dsp.exec_cmd(\"{cmd_escaped}\"){opt_str})")

content = "\n".join(lines_out) + "\n"
for lf in lua_files:
    try:
        os.makedirs(os.path.dirname(lf), exist_ok=True)
        with open(lf, "w", encoding="utf-8") as f:
            f.write(content)
    except Exception:
        pass
' "$NORM_MODE" "$TARGET_CARBON_CONF" "$TARGET_LUA" "$TARGET_CARBON_LUA"

# 3. Instant reload of Hyprland keybinds + gestures (skip in sandbox / no-reload mode)
if [ "${CARBON_NO_RELOAD:-0}" != "1" ] && command -v hyprctl >/dev/null 2>&1; then
    if hyprctl instances >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
        if [ -x "$CARBON_DIR/scripts/carbon-gestures-init.sh" ]; then
            bash "$CARBON_DIR/scripts/carbon-gestures-init.sh" >/dev/null 2>&1 || true
        fi
    fi
fi

echo "[carbon-mode-keybinds] Activated keybinds for mode: $NORM_MODE (from ${SOURCE_CONF:-generated})"
exit 0
