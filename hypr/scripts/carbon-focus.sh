#!/usr/bin/env bash
# Carbon Shell — Toggle Focus Mode / Focus HUD (Super + Shift + F)

CONFIG_PATH="${HOME}/.local/share/quickshell/carbon"
QS_BIN="/usr/bin/quickshell"
[ -x "$QS_BIN" ] || QS_BIN="$(command -v quickshell 2>/dev/null)"

if [ -n "$QS_BIN" ]; then
    "$QS_BIN" ipc --any-display -p "$CONFIG_PATH" call focus toggle 2>/dev/null && exit 0
fi

# Fallback via socket
if [ -x "${HOME}/.config/hypr/scripts/carbon-ipc.sh" ]; then
    sh "${HOME}/.config/hypr/scripts/carbon-ipc.sh" focus 2>/dev/null && exit 0
elif [ -x "${HOME}/.config/carbon/scripts/carbon-ipc.sh" ]; then
    sh "${HOME}/.config/carbon/scripts/carbon-ipc.sh" focus 2>/dev/null && exit 0
fi

exit 0
