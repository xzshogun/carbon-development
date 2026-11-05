#!/usr/bin/env bash
# Vanish Mode Dedicated Dispatcher
# Routes keybinds exclusively when Vanish Mode (nucleus) is active.
# Keeps standard desktop modes (Pill, Notch, Minimal) completely unhindered.

ACTION="$1"

# Debounce fast repeated triggers (e.g. key repeat or multiple release events)
DEBOUNCE_FILE="/tmp/carbon-vanish-$ACTION.lock"
NOW=$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s%3N 2>/dev/null || date +%s 2>/dev/null)
if [ -f "$DEBOUNCE_FILE" ]; then
    PREV=$(cat "$DEBOUNCE_FILE" 2>/dev/null || echo 0)
    DIFF=$((NOW - PREV))
    if [ "$DIFF" -ge 0 ] && [ "$DIFF" -lt 350 ]; then
        exit 0
    fi
fi
echo "$NOW" > "$DEBOUNCE_FILE"
CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
if [ ! -d "$CONFIG_DIR" ] && [ -d "$HOME/.config/hypr" ]; then
    CONFIG_DIR="$HOME/.config/hypr"
fi
MODE_FILE="$CONFIG_DIR/carbon-bar-mode.json"

CURRENT_MODE="nucleus"
if [ -f "$MODE_FILE" ]; then
    CURRENT_MODE=$(python3 -c "import json; print(json.load(open('$MODE_FILE')).get('mode', 'nucleus'))" 2>/dev/null || echo "nucleus")
fi

if [ "$CURRENT_MODE" != "nucleus" ]; then
    # In non-vanish modes, vanish shortcuts do not trigger, preventing key collisions
    if [ "$ACTION" = "toggle-hub" ]; then
        IPC_SCRIPT="$CONFIG_DIR/scripts/carbon-ipc.sh"
        [ -f "$IPC_SCRIPT" ] || IPC_SCRIPT="$HOME/.config/hypr/scripts/carbon-ipc.sh"
        exec sh "$IPC_SCRIPT" "toggle-launcher"
    fi
    exit 0
fi

IPC_SCRIPT="$CONFIG_DIR/scripts/carbon-ipc.sh"
[ -f "$IPC_SCRIPT" ] || IPC_SCRIPT="$HOME/.config/hypr/scripts/carbon-ipc.sh"

case "$ACTION" in
    toggle-hub)
        sh "$IPC_SCRIPT" "nucleus toggle"
        ;;
    launcher)
        sh "$IPC_SCRIPT" "nucleus launcher"
        ;;
    spotlight)
        sh "$IPC_SCRIPT" "spotlight"
        ;;
    lyrics)
        sh "$IPC_SCRIPT" "nucleus lyrics"
        ;;
    wallpaper)
        sh "$IPC_SCRIPT" "nucleus wallpapers"
        ;;
    focus-connect)
        sh "$IPC_SCRIPT" "nucleus focus connect"
        ;;
    focus-spaces)
        sh "$IPC_SCRIPT" "nucleus focus spaces"
        ;;
    focus-alerts)
        sh "$IPC_SCRIPT" "nucleus focus alerts"
        ;;
    *)
        exit 0
        ;;
esac
