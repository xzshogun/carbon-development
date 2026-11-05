#!/bin/sh
# hyprlock image reload_cmd: prints the path of the next ornament frame.
I=$(cat /tmp/lock-ornament-idx 2>/dev/null)
[ -z "$I" ] && I=0
idx=$(( (I + 1) % 12 ))
echo "$idx" > /tmp/lock-ornament-idx
DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}/lock-ornament"
[ -d "$DIR" ] || DIR="${HOME}/.config/hypr/lock-ornament"
printf '%s/orn_%02d.png' "$DIR" "$idx"