#!/usr/bin/env bash
# ==============================================================================
# carbon-power-profile.sh: Manages power profiles and Ultra Game Mode
# Profiles:
#   power-saver : Power Saving (Eco)
#   balanced    : Balanced
#   performance : Performance
#   ultra       : Ultra (Game Mode via hypr-gamemode)
# ==============================================================================

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/carbon"
PROFILE_FILE="$STATE_DIR/power-profile"
GM_STATE="${XDG_RUNTIME_DIR:-/tmp}/hypr_gamemode_state.json"

mkdir -p "$STATE_DIR"

is_gamemode_active() {
    if [ -f "$GM_STATE" ] || [ -f "/tmp/hypr_gamemode_state.json" ] || [ -f "${XDG_RUNTIME_DIR:-/run/user/1000}/hypr_gamemode_state.json" ]; then
        return 0
    fi
    return 1
}

get_profile() {
    if is_gamemode_active; then
        echo "ultra"
        return
    fi
    if [ -f "$PROFILE_FILE" ]; then
        local p
        p=$(cat "$PROFILE_FILE" 2>/dev/null | tr -d '[:space:]')
        if [ "$p" = "ultra" ]; then
            echo "balanced" > "$PROFILE_FILE"
            echo "balanced"
            return
        elif [ -n "$p" ]; then
            echo "$p"
            return
        fi
    fi
    echo "balanced"
}

set_profile() {
    local target="$1"
    local raw_notify="$2"
    local prev_profile
    prev_profile=$(get_profile)
    local p_name="balanced"

    case "$target" in
        ultra|game|gamemode) p_name="ultra" ;;
        power-saver|powersave|eco) p_name="power-saver" ;;
        performance) p_name="performance" ;;
        balanced|*) p_name="balanced" ;;
    esac

    local do_notify="0"
    if [ "$raw_notify" = "1" ] || [ "$raw_notify" = "--notify" ]; then
        do_notify="1"
    elif [ "$raw_notify" = "0" ] || [ "$raw_notify" = "--no-notify" ]; then
        do_notify="0"
    else
        if [ "$prev_profile" != "$p_name" ]; then
            do_notify="1"
        fi
    fi

    case "$p_name" in
        ultra)
            echo "ultra" > "$PROFILE_FILE"
            if ! is_gamemode_active; then
                ~/.local/bin/hypr-gamemode on >/dev/null 2>&1 || true
            fi
            if command -v powerprofilesctl >/dev/null 2>&1; then
                powerprofilesctl set performance >/dev/null 2>&1 || true
            fi
            for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                [ -w "$f" ] && echo performance > "$f" 2>/dev/null || true
            done
            for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$f" ] && echo performance > "$f" 2>/dev/null || true
            done
            [ "$do_notify" = "1" ] || [ "$do_notify" = "--notify" ] && notify-send -u low -i preferences-system-power "Power Profile: Ultra" "Game Mode activated. Maximum performance & minimum latency." 2>/dev/null || true
            ;;
        power-saver|powersave|eco)
            p_name="power-saver"
            if is_gamemode_active; then
                ~/.local/bin/hypr-gamemode off >/dev/null 2>&1 || true
            fi
            echo "power-saver" > "$PROFILE_FILE"
            if command -v powerprofilesctl >/dev/null 2>&1; then
                powerprofilesctl set power-saver >/dev/null 2>&1 || true
            fi
            for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                [ -w "$f" ] && echo power > "$f" 2>/dev/null || true
            done
            for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$f" ] && echo powersave > "$f" 2>/dev/null || true
            done
            [ "$do_notify" = "1" ] || [ "$do_notify" = "--notify" ] && notify-send -u low -i battery "Power Profile: Power Saving" "Reduced power consumption and battery saver active." 2>/dev/null || true
            ;;
        performance)
            p_name="performance"
            if is_gamemode_active; then
                ~/.local/bin/hypr-gamemode off >/dev/null 2>&1 || true
            fi
            echo "performance" > "$PROFILE_FILE"
            if command -v powerprofilesctl >/dev/null 2>&1; then
                powerprofilesctl set performance >/dev/null 2>&1 || true
            fi
            for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                [ -w "$f" ] && echo performance > "$f" 2>/dev/null || true
            done
            for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$f" ] && echo performance > "$f" 2>/dev/null || true
            done
            [ "$do_notify" = "1" ] || [ "$do_notify" = "--notify" ] && notify-send -u low -i preferences-system-power "Power Profile: Performance" "High performance profile active." 2>/dev/null || true
            ;;
        balanced|*)
            p_name="balanced"
            if is_gamemode_active; then
                ~/.local/bin/hypr-gamemode off >/dev/null 2>&1 || true
            fi
            echo "balanced" > "$PROFILE_FILE"
            if command -v powerprofilesctl >/dev/null 2>&1; then
                powerprofilesctl set balanced >/dev/null 2>&1 || true
            fi
            for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do
                [ -w "$f" ] && echo balance_performance > "$f" 2>/dev/null || true
            done
            for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [ -w "$f" ] && echo powersave > "$f" 2>/dev/null || true
            done
            [ "$do_notify" = "1" ] || [ "$do_notify" = "--notify" ] && notify-send -u low -i battery "Power Profile: Balanced" "Standard balanced power profile active." 2>/dev/null || true
            ;;
    esac

    # Sync into carbon-power.json if present
    python3 -c "
import json, os
for p in ['$STATE_DIR/carbon-power.json', os.path.expanduser('~/.config/hypr/carbon-power.json')]:
    if os.path.exists(p):
        try:
            d = json.load(open(p))
            d['profile'] = '$p_name'
            json.dump(d, open(p, 'w'), indent=2)
        except Exception:
            pass
" 2>/dev/null || true
}

case "$1" in
    get)
        get_profile
        ;;
    set)
        set_profile "$2" "$3"
        ;;
    *)
        get_profile
        ;;
esac
