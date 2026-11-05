#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Scripts for volume controls for audio and mic 

iDIR="$HOME/.config/swaync/icons"
sDIR="$HOME/.config/hypr/scripts"

# Get Volume
get_volume() {
    if command -v pamixer &>/dev/null; then
        local is_muted=$(pamixer --get-mute 2>/dev/null)
        if [ "$is_muted" == "true" ]; then
            echo "Muted"
            return
        fi
        local volume=$(pamixer --get-volume 2>/dev/null)
        if [[ "$volume" -eq "0" ]]; then
            echo "Muted"
        else
            echo "$volume %"
        fi
    elif command -v wpctl &>/dev/null; then
        local raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
        if [[ "$raw" == *"[MUTED]"* ]]; then
            echo "Muted"
        else
            local val=$(echo "$raw" | awk '{print int($2 * 100)}')
            echo "$val %"
        fi
    fi
}

# Get icons
get_icon() {
    current=$(get_volume)
    if [[ "$current" == "Muted" ]]; then
        echo "$iDIR/volume-mute.png"
    elif [[ "${current%\%}" -le 30 ]]; then
        echo "$iDIR/volume-low.png"
    elif [[ "${current%\%}" -le 60 ]]; then
        echo "$iDIR/volume-mid.png"
    else
        echo "$iDIR/volume-high.png"
    fi
}

# Notify
notify_user() {
    if [[ "$(get_volume)" == "Muted" ]]; then
        notify-send -e -h string:x-canonical-private-synchronous:volume_notif -u low -i "$(get_icon)" " Volume:" " Muted"
    else
        notify-send -e -h int:value:"$(get_volume | sed 's/%//')" -h string:x-canonical-private-synchronous:volume_notif -u low -i "$(get_icon)" " Volume Level:" " $(get_volume)" &&
        "$sDIR/Sounds.sh" --volume
    fi
}

get_volume_step() {
    local cfg="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}/carbon-control-center.json"
    [ -f "$cfg" ] || cfg="$HOME/.config/hypr/carbon-control-center.json"
    if [ -f "$cfg" ]; then
        python3 -c "import json; print(json.load(open('$cfg')).get('volumeStep', 5))" 2>/dev/null || echo 5
    else
        echo 5
    fi
}

# Increase Volume
inc_volume() {
    local step=$(get_volume_step)
    if command -v wpctl &>/dev/null; then
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${step}%+"
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
    elif command -v pamixer &>/dev/null; then
        pamixer -u 2>/dev/null || true
        pamixer -i "$step" --allow-boost --set-limit 150
    fi
    if [ -S /tmp/carbon-shell.sock ]; then
        ~/.config/carbon/scripts/carbon-ipc.sh "controls volume up" 2>/dev/null || true
    else
        notify_user
    fi
}

# Decrease Volume
dec_volume() {
    local step=$(get_volume_step)
    if command -v wpctl &>/dev/null; then
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "${step}%-"
    elif command -v pamixer &>/dev/null; then
        pamixer -d "$step"
    fi
    if [ -S /tmp/carbon-shell.sock ]; then
        ~/.config/carbon/scripts/carbon-ipc.sh "controls volume down" 2>/dev/null || true
    else
        notify_user
    fi
}

# Toggle Mute
toggle_mute() {
    if command -v wpctl &>/dev/null; then
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    elif command -v pamixer &>/dev/null; then
        pamixer -t
    fi
    if [ -S /tmp/carbon-shell.sock ]; then
        ~/.config/carbon/scripts/carbon-ipc.sh "controls volume toggle-mute" 2>/dev/null || true
    else
        if [ "$(pamixer --get-mute 2>/dev/null)" == "true" ]; then
            notify-send -e -u low -i "$iDIR/volume-mute.png" " Mute"
        else
            notify-send -e -u low -i "$(get_icon)" " Volume:" " Switched ON"
        fi
    fi
}

# Toggle Mic
toggle_mic() {
	if [ "$(pamixer --default-source --get-mute)" == "false" ]; then
		pamixer --default-source -m && notify-send -e -u low -i "$iDIR/microphone-mute.png" " Microphone:" " Switched OFF"
	elif [ "$(pamixer --default-source --get-mute)" == "true" ]; then
		pamixer -u --default-source u && notify-send -e -u low -i "$iDIR/microphone.png" " Microphone:" " Switched ON"
	fi
}
# Get Mic Icon
get_mic_icon() {
    current=$(pamixer --default-source --get-volume)
    if [[ "$current" -eq "0" ]]; then
        echo "$iDIR/microphone-mute.png"
    else
        echo "$iDIR/microphone.png"
    fi
}

# Get Microphone Volume
get_mic_volume() {
    volume=$(pamixer --default-source --get-volume)
    if [[ "$volume" -eq "0" ]]; then
        echo "Muted"
    else
        echo "$volume %"
    fi
}

# Notify for Microphone
notify_mic_user() {
    volume=$(get_mic_volume)
    icon=$(get_mic_icon)
    notify-send -e -h int:value:"$volume" -h "string:x-canonical-private-synchronous:volume_notif" -u low -i "$icon"  " Mic Level:" " $volume"
}

# Increase MIC Volume
inc_mic_volume() {
    if [ "$(pamixer --default-source --get-mute)" == "true" ]; then
        toggle_mic
    else
        pamixer --default-source -i 5 && notify_mic_user
    fi
}

# Decrease MIC Volume
dec_mic_volume() {
    if [ "$(pamixer --default-source --get-mute)" == "true" ]; then
        toggle-mic
    else
        pamixer --default-source -d 5 && notify_mic_user
    fi
}

# Execute accordingly
if [[ "$1" == "--get" ]]; then
	get_volume
elif [[ "$1" == "--inc" ]]; then
	inc_volume
elif [[ "$1" == "--dec" ]]; then
	dec_volume
elif [[ "$1" == "--toggle" ]]; then
	toggle_mute
elif [[ "$1" == "--toggle-mic" ]]; then
	toggle_mic
elif [[ "$1" == "--get-icon" ]]; then
	get_icon
elif [[ "$1" == "--get-mic-icon" ]]; then
	get_mic_icon
elif [[ "$1" == "--mic-inc" ]]; then
	inc_mic_volume
elif [[ "$1" == "--mic-dec" ]]; then
	dec_mic_volume
else
	get_volume
fi