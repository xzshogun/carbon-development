#!/usr/bin/env bash
# ==============================================================================
# Carbon Shell — Mode Keybind Dispatcher
# Swaps Hyprland mode-specific keybinds in both .conf and .lua formats,
# then executes instant hyprctl reload.
# Guaranteed 0 symlinks.
# ==============================================================================

MODE="${1:-}"

if [ -z "$MODE" ]; then
    JSON_PATH="$HOME/.config/carbon/carbon-bar-mode.json"
    if [ -f "$JSON_PATH" ]; then
        MODE=$(python3 -c "import json; print(json.load(open('$JSON_PATH')).get('mode', 'minimal_notch'))" 2>/dev/null || echo "minimal_notch")
    else
        MODE="minimal_notch"
    fi
fi

# Normalize mode name
case "$MODE" in
    notch|island)
        NORM_MODE="notch"
        ;;
    vanish|nucleus)
        NORM_MODE="vanish"
        ;;
    minimal|minimal_notch)
        NORM_MODE="minimal"
        ;;
    *)
        NORM_MODE="minimal"
        ;;
esac

CARBON_DIR="$HOME/.config/carbon"
HYPR_CONFIGS="$HOME/.config/hypr/configs"
SOURCE_CONF="$CARBON_DIR/keybinds-${NORM_MODE}.conf"
TARGET_CONF="$HYPR_CONFIGS/current-mode-keybinds.conf"
TARGET_LUA="$HOME/.config/hypr/current-mode-keybinds.lua"

mkdir -p "$HYPR_CONFIGS" "$CARBON_DIR"

if [ ! -f "$SOURCE_CONF" ]; then
    if [ -f "$HYPR_CONFIGS/keybinds-${NORM_MODE}.conf" ]; then
        SOURCE_CONF="$HYPR_CONFIGS/keybinds-${NORM_MODE}.conf"
    elif [ -f "$HOME/carbon-shell/hypr/configs/keybinds-${NORM_MODE}.conf" ]; then
        SOURCE_CONF="$HOME/carbon-shell/hypr/configs/keybinds-${NORM_MODE}.conf"
    fi
fi

# 1. Update Hyprland Conf format
if [ -f "$SOURCE_CONF" ]; then
    cp -f "$SOURCE_CONF" "$TARGET_CONF"
else
    echo "# Mode keybinds for $NORM_MODE (empty)" > "$TARGET_CONF"
fi

# 2. Update Hyprland Lua format
python3 -c '
import sys, os

mode = sys.argv[1]
lua_file = sys.argv[2]
home = os.environ.get("HOME", os.path.expanduser("~"))

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
hl.bind("SUPER + Up", hl.dsp.focus({{ direction = "up" }}))
hl.bind("SUPER + ALT + Left", hl.dsp.focus({{ direction = "left" }}))
hl.bind("SUPER + ALT + Right", hl.dsp.focus({{ direction = "right" }}))
hl.bind("SUPER + ALT + Up", hl.dsp.focus({{ direction = "up" }}))
hl.bind("SUPER + ALT + Down", hl.dsp.focus({{ direction = "down" }}))
""",
    "notch": f"""-- Active Mode: Carbon Notch
hl.bind("SUPER + B", hl.dsp.exec_cmd("{home}/.config/hypr/scripts/carbon-ipc.sh center-dashboard"))
hl.bind("SUPER + K", hl.dsp.exec_cmd("{home}/.config/hypr/scripts/carbon-ipc.sh spotlight"))
hl.bind("SUPER + R", hl.dsp.exec_cmd("{home}/.config/hypr/scripts/carbon-ipc.sh spotlight"))
hl.bind("SUPER + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("{home}/.config/hypr/scripts/carbon-ipc.sh controls"))
hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("{home}/.config/hypr/scripts/carbon-ipc.sh power"))
hl.bind("SUPER + Left", hl.dsp.window.move({{ direction = "l" }}))
hl.bind("SUPER + Right", hl.dsp.window.move({{ direction = "r" }}))
hl.bind("SUPER + Up", hl.dsp.window.move({{ direction = "u" }}))
hl.bind("SUPER + Down", hl.dsp.window.move({{ direction = "d" }}))
""",
    "pill": f"""-- Active Mode: Pill / Waybar
hl.bind("SUPER + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("{home}/.config/hypr/scripts/carbon-ipc.sh controls"))
hl.bind("SUPER + K", hl.dsp.exec_cmd("{home}/.config/hypr/scripts/carbon-ipc.sh spotlight"))
hl.bind("SUPER + R", hl.dsp.exec_cmd("{home}/.config/hypr/scripts/carbon-ipc.sh spotlight"))
hl.bind("SUPER + Left", hl.dsp.window.move({{ direction = "l" }}))
hl.bind("SUPER + Right", hl.dsp.window.move({{ direction = "r" }}))
hl.bind("SUPER + Up", hl.dsp.window.move({{ direction = "u" }}))
hl.bind("SUPER + Down", hl.dsp.window.move({{ direction = "d" }}))
"""
,
    "vanish": f"""-- Active Mode: Vanish / Nucleus
hl.bind("SUPER + Super_L", hl.dsp.exec_cmd("sh {home}/.config/carbon/scripts/carbon-vanish-dispatch.sh toggle-hub"), {{ release = true }})
hl.bind("SUPER + Super_R", hl.dsp.exec_cmd("sh {home}/.config/carbon/scripts/carbon-vanish-dispatch.sh toggle-hub"), {{ release = true }})
hl.bind("SUPER + R", hl.dsp.exec_cmd("{home}/.config/hypr/scripts/carbon-ipc.sh spotlight"))
hl.bind("SUPER + K", hl.dsp.exec_cmd("{home}/.config/hypr/scripts/carbon-ipc.sh spotlight"))
hl.bind("SUPER + M", hl.dsp.exec_cmd("sh {home}/.config/carbon/scripts/carbon-vanish-dispatch.sh lyrics"))
hl.bind("SUPER + W", hl.dsp.exec_cmd("sh {home}/.config/carbon/scripts/carbon-ipc.sh wallpaper"))
hl.bind("SUPER + A", hl.dsp.exec_cmd("sh {home}/.config/carbon/scripts/carbon-vanish-dispatch.sh focus-alerts"))
hl.bind("SUPER + B", hl.dsp.exec_cmd("sh {home}/.config/carbon/scripts/carbon-vanish-dispatch.sh quick-toggles"))
hl.bind("SUPER + C", hl.dsp.exec_cmd("hyprpicker -a"))
hl.bind("SUPER + Left", hl.dsp.window.move({{ direction = "l" }}))
hl.bind("SUPER + Right", hl.dsp.window.move({{ direction = "r" }}))
hl.bind("SUPER + Up", hl.dsp.window.move({{ direction = "u" }}))
hl.bind("SUPER + Down", hl.dsp.window.move({{ direction = "d" }}))
"""
}

content = lua_bindings.get(mode, lua_bindings["minimal"])
with open(lua_file, "w") as f:
    f.write(content)
' "$NORM_MODE" "$TARGET_LUA"

# 3. Instant reload of Hyprland keybinds
if command -v hyprctl >/dev/null 2>&1; then
    hyprctl reload >/dev/null 2>&1 || true
fi

echo "[carbon-mode-keybinds] Activated keybinds for mode: $NORM_MODE"
exit 0
