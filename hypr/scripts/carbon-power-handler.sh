#!/usr/bin/env bash
# ==============================================================================
# carbon-power-handler.sh: System Power, Button & Lid Event Handler
# Carbon Shell Integration
# Handles events:
#   power_button   : Power key pressed
#   sleep_button   : Sleep key pressed
#   lid_close      : Laptop lid closed (checks AC vs Battery state)
#   lid_open       : Laptop lid opened (turns display on)
#   test_sleep     : Test suspend to RAM
#   test_hibernate : Test save to disk and power off
# ==============================================================================

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/carbon/carbon-power.json"
HYPR_CONFIG_FILE="${HOME}/.config/hypr/carbon-power.json"

get_config_val() {
    local key="$1"
    local default="$2"
    local val=""
    if [ -f "$CONFIG_FILE" ]; then
        val=$(python3 -c "import json; d=json.load(open('$CONFIG_FILE')); print(d.get('$key', ''))" 2>/dev/null)
    elif [ -f "$HYPR_CONFIG_FILE" ]; then
        val=$(python3 -c "import json; d=json.load(open('$HYPR_CONFIG_FILE')); print(d.get('$key', ''))" 2>/dev/null)
    fi
    if [ -n "$val" ]; then
        echo "$val"
    else
        echo "$default"
    fi
}

is_on_ac() {
    for f in /sys/class/power_supply/AC*/online /sys/class/power_supply/A*/online /sys/class/power_supply/mains/online; do
        if [ -f "$f" ]; then
            if [ "$(cat "$f" 2>/dev/null)" = "1" ]; then
                return 0
            fi
        fi
    done
    return 1
}

lock_screen() {
    if command -v hyprlock >/dev/null 2>&1; then
        pidof hyprlock >/dev/null 2>&1 || hyprlock &
    elif command -v loginctl >/dev/null 2>&1; then
        loginctl lock-session
    fi
}

execute_action() {
    local action="$1"
    case "$action" in
        suspend|sleep)
            lock_screen
            systemctl suspend
            ;;
        hibernate)
            lock_screen
            systemctl hibernate
            ;;
        poweroff|shutdown)
            systemctl poweroff
            ;;
        lock)
            lock_screen
            ;;
        lock_dpms)
            lock_screen
            hyprctl dispatch dpms off
            ;;
        ignore|none|"")
            # Do nothing
            ;;
        *)
            # Fallback
            ;;
    esac
}

EVENT="$1"

case "$EVENT" in
    power_button)
        action=$(get_config_val "powerButtonAction" "poweroff")
        execute_action "$action"
        ;;
    sleep_button)
        action=$(get_config_val "sleepButtonAction" "suspend")
        execute_action "$action"
        ;;
    lid_close)
        if is_on_ac; then
            action=$(get_config_val "lidActionAC" "suspend")
        else
            action=$(get_config_val "lidActionBattery" "suspend")
        fi
        execute_action "$action"
        ;;
    lid_open)
        hyprctl dispatch dpms on
        ;;
    test_sleep)
        execute_action "suspend"
        ;;
    test_hibernate)
        execute_action "hibernate"
        ;;
    *)
        echo "Usage: $0 {power_button|sleep_button|lid_close|lid_open|test_sleep|test_hibernate}"
        exit 1
        ;;
esac
