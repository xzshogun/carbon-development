#!/usr/bin/env bash
# ==============================================================================
# Carbon Shell — Touchpad & Multi-Finger Gesture Initializer
# Reads ~/.config/carbon/configs/gestures.conf and dynamically applies touchpad
# natural scrolling, 3-finger workspace swipe, and 3/4-finger directional
# gestures across both legacy Hyprland (<0.48) and modern Hyprland (0.48+/0.51+).
# ==============================================================================

set -uo pipefail

CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
GESTURES_CONF="$CONFIG_DIR/configs/gestures.conf"
if [ ! -f "$GESTURES_CONF" ] && [ -f "$HOME/.config/hypr/configs/gestures.conf" ]; then
    GESTURES_CONF="$HOME/.config/hypr/configs/gestures.conf"
fi

if ! command -v hyprctl >/dev/null 2>&1; then
    exit 0
fi

if ! hyprctl instances >/dev/null 2>&1; then
    exit 0
fi

NATURAL_SCROLL="true"
DISABLE_WHILE_TYPING="true"
TAP_TO_CLICK="true"
SCROLL_FACTOR="1.0"
WS_SWIPE="true"
WS_SWIPE_FINGERS="3"
WS_SWIPE_DISTANCE="400"
WS_SWIPE_INVERT="false"
WS_SWIPE_CREATE_NEW="true"

declare -a GESTURE_RULES=()

if [ -f "$GESTURES_CONF" ]; then
    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        line="$(echo "$raw_line" | sed 's/#.*//;s/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue
        key="$(echo "${line%%=*}" | tr -d '[:space:]')"
        val="$(echo "${line#*=}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        case "$key" in
            natural_scroll) NATURAL_SCROLL="$val" ;;
            disable_while_typing) DISABLE_WHILE_TYPING="$val" ;;
            tap_to_click|tap-to-click) TAP_TO_CLICK="$val" ;;
            scroll_factor) SCROLL_FACTOR="$val" ;;
            workspace_swipe) WS_SWIPE="$val" ;;
            workspace_swipe_fingers) WS_SWIPE_FINGERS="$val" ;;
            workspace_swipe_distance) WS_SWIPE_DISTANCE="$val" ;;
            workspace_swipe_invert) WS_SWIPE_INVERT="$val" ;;
            workspace_swipe_create_new) WS_SWIPE_CREATE_NEW="$val" ;;
            gesture)
                expanded_val="${val//\~/$HOME}"
                GESTURE_RULES+=("$expanded_val")
                ;;
        esac
    done < "$GESTURES_CONF"
else
    GESTURE_RULES=(
        "3, horizontal, workspace"
        "3, up, dispatcher, exec, sh $CONFIG_DIR/scripts/carbon-ipc.sh toggle-overview"
        "3, down, dispatcher, exec, sh $CONFIG_DIR/scripts/carbon-ipc.sh spatial-canvas"
    )
fi

# 1. Apply Touchpad Input Properties
hyprctl keyword input:touchpad:natural_scroll "$NATURAL_SCROLL" >/dev/null 2>&1 || true
hyprctl keyword input:touchpad:disable_while_typing "$DISABLE_WHILE_TYPING" >/dev/null 2>&1 || true
hyprctl keyword input:touchpad:tap-to-click "$TAP_TO_CLICK" >/dev/null 2>&1 || true
hyprctl keyword input:touchpad:scroll_factor "$SCROLL_FACTOR" >/dev/null 2>&1 || true

# 2. Apply Legacy Hyprland (<0.48) Workspace Swipe Properties (ignored silently on 0.51+)
hyprctl keyword gestures:workspace_swipe "$WS_SWIPE" >/dev/null 2>&1 || true
hyprctl keyword gestures:workspace_swipe_fingers "$WS_SWIPE_FINGERS" >/dev/null 2>&1 || true
hyprctl keyword gestures:workspace_swipe_distance "$WS_SWIPE_DISTANCE" >/dev/null 2>&1 || true
hyprctl keyword gestures:workspace_swipe_invert "$WS_SWIPE_INVERT" >/dev/null 2>&1 || true
hyprctl keyword gestures:workspace_swipe_create_new "$WS_SWIPE_CREATE_NEW" >/dev/null 2>&1 || true
hyprctl keyword gestures:workspace_swipe_cancel_ratio 0.15 >/dev/null 2>&1 || true
hyprctl keyword gestures:workspace_swipe_direction_lock true >/dev/null 2>&1 || true

# 3. Apply Modern Hyprland (0.48+ / 0.51+) Gesture Rules
for rule in "${GESTURE_RULES[@]}"; do
    hyprctl keyword gesture "$rule" >/dev/null 2>&1 || true
done

exit 0
