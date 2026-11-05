#!/bin/sh
# Carbon night light controller
# Usage: carbon-night.sh <on|off|toggle|status>

ACTION="$1"
LOCKFILE="/tmp/carbon-night.on"
SHADER="${HOME:-/root}/.config/hypr/shaders/nightlight.frag"

apply_on() {
    if command -v hyprsunset >/dev/null 2>&1; then
        pkill -x hyprsunset >/dev/null 2>&1
        sleep 0.1
        (nohup hyprsunset -t 3500 </dev/null >/dev/null 2>&1 &)
    else
        hyprctl keyword decoration:screen_shader "$SHADER" >/dev/null 2>&1
    fi
    touch "$LOCKFILE"
}

apply_off() {
    pkill -x hyprsunset >/dev/null 2>&1
    hyprctl keyword decoration:screen_shader "" >/dev/null 2>&1
    rm -f "$LOCKFILE"
}

case "$ACTION" in
    on)
        apply_on
        ;;
    off)
        apply_off
        ;;
    toggle)
        if [ -f "$LOCKFILE" ]; then
            apply_off
        else
            apply_on
        fi
        ;;
    status)
        if [ -f "$LOCKFILE" ]; then
            echo "on"
        else
            echo "off"
        fi
        ;;
    *)
        echo "Usage: $0 {on|off|toggle|status}"
        exit 1
        ;;
esac
exit 0
