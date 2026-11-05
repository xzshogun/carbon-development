#!/bin/sh
CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
IPC="$CONFIG_DIR/scripts/carbon-ipc.sh"
[ -f "$IPC" ] || IPC="$HOME/.config/hypr/scripts/carbon-ipc.sh"
sh "$IPC" lock

