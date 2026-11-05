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
    cp -f "$SOURCE_CONF" "$TARGET_CARBON_CONF"
    cp -f "$SOURCE_CONF" "$TARGET_HYPR_CONF"
else
    echo "# Mode keybinds for $NORM_MODE (empty)" > "$TARGET_CARBON_CONF"
    echo "# Mode keybinds for $NORM_MODE (empty)" > "$TARGET_HYPR_CONF"
fi

# 2. Update Hyprland Lua format
python3 -c '
import sys, os

mode = sys.argv[1]
lua_files = [sys.argv[2], sys.argv[3]]
home = os.environ.get("HOME", os.path.expanduser("~"))
carbon_dir = os.environ.get("CARBON_CONFIG_DIR", os.path.join(home, ".config/carbon"))

lua_bindings = {
    "minimal": f"""-- Active Mode: Minimal Notch / Tide Island
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call tide toggleControlCenter"))
hl.bind("SUPER + R", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call tide toggleApplicationLauncher"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call tide togglePlayer"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call tide toggleWallpaperPicker"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call tide toggleNotificationCenter"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call tide togglePowerMenu"))
hl.bind("SUPER + Tab", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call overview toggle"))
hl.bind("SUPER + Down", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call tide showClock"))
hl.bind("SUPER + Right", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call tide swipeRight"))
hl.bind("SUPER + Left", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call tide swipeLeft"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("/usr/bin/quickshell ipc --any-display -p {home}/.local/share/quickshell/carbon call tide toggle"))
hl.bind("SUPER + K", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-focus.sh"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-settings-hub"))
hl.bind("SUPER + Up", hl.dsp.focus({{ direction = "up" }}))
hl.bind("SUPER + ALT + Left", hl.dsp.focus({{ direction = "left" }}))
hl.bind("SUPER + ALT + Right", hl.dsp.focus({{ direction = "right" }}))
hl.bind("SUPER + ALT + Up", hl.dsp.focus({{ direction = "up" }}))
hl.bind("SUPER + ALT + Down", hl.dsp.focus({{ direction = "down" }}))
""",
    "notch": f"""-- Active Mode: Carbon Notch
hl.bind("SUPER + B", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-ipc.sh center-dashboard"))
hl.bind("SUPER + K", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-focus.sh"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-settings-hub"))
hl.bind("SUPER + R", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-ipc.sh spotlight"))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-ipc.sh controls"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-ipc.sh power"))
hl.bind("SUPER + Left", hl.dsp.window.move({{ direction = "l" }}))
hl.bind("SUPER + Right", hl.dsp.window.move({{ direction = "r" }}))
hl.bind("SUPER + Up", hl.dsp.window.move({{ direction = "u" }}))
hl.bind("SUPER + Down", hl.dsp.window.move({{ direction = "d" }}))
""",
    "pill": f"""-- Active Mode: Pill / Waybar
hl.bind("SUPER + B", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-ipc.sh controls"))
hl.bind("SUPER + K", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-focus.sh"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-settings-hub"))
hl.bind("SUPER + R", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-ipc.sh toggle-spotlight"))
hl.bind("SUPER + Left", hl.dsp.window.move({{ direction = "l" }}))
hl.bind("SUPER + Right", hl.dsp.window.move({{ direction = "r" }}))
hl.bind("SUPER + Up", hl.dsp.window.move({{ direction = "u" }}))
hl.bind("SUPER + Down", hl.dsp.window.move({{ direction = "d" }}))
""",
    "vanish": f"""-- Active Mode: Vanish / Nucleus
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd("sh {carbon_dir}/scripts/carbon-vanish-dispatch.sh toggle-hub"), {{ release = true }})
hl.bind("SUPER + Super_R", hl.dsp.exec_cmd("sh {carbon_dir}/scripts/carbon-vanish-dispatch.sh toggle-hub"), {{ release = true }})
hl.bind("SUPER + R", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-ipc.sh spotlight"))
hl.bind("SUPER + K", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-focus.sh"))
hl.bind("SUPER + SHIFT + C", hl.dsp.exec_cmd("{carbon_dir}/scripts/carbon-settings-hub"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("sh {carbon_dir}/scripts/carbon-vanish-dispatch.sh lyrics"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("sh {carbon_dir}/scripts/carbon-ipc.sh wallpaper"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("sh {carbon_dir}/scripts/carbon-vanish-dispatch.sh focus-alerts"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("sh {carbon_dir}/scripts/carbon-vanish-dispatch.sh quick-toggles"))
hl.bind("SUPER + Left", hl.dsp.window.move({{ direction = "l" }}))
hl.bind("SUPER + Right", hl.dsp.window.move({{ direction = "r" }}))
hl.bind("SUPER + Up", hl.dsp.window.move({{ direction = "u" }}))
hl.bind("SUPER + Down", hl.dsp.window.move({{ direction = "d" }}))
"""
}

content = lua_bindings.get(mode, lua_bindings["minimal"])
for lf in lua_files:
    try:
        os.makedirs(os.path.dirname(lf), exist_ok=True)
        with open(lf, "w") as f:
            f.write(content)
    except Exception:
        pass
' "$NORM_MODE" "$TARGET_LUA" "$TARGET_CARBON_LUA"

# 3. Instant reload of Hyprland keybinds (skip in sandbox / no-reload mode)
if [ "${CARBON_NO_RELOAD:-0}" != "1" ] && command -v hyprctl >/dev/null 2>&1; then
    if hyprctl instances >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
    fi
fi

echo "[carbon-mode-keybinds] Activated keybinds for mode: $NORM_MODE (from ${SOURCE_CONF:-generated})"
exit 0
