#!/usr/bin/env bash
# Carbon Shell — Toggle Focus Mode / Focus HUD (Super + K)

CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
CONFIG_PATH="${HOME}/.local/share/quickshell/carbon"
QS_BIN="/usr/bin/quickshell"
[ -x "$QS_BIN" ] || QS_BIN="$(command -v quickshell 2>/dev/null || true)"

# Primary: send directly over Carbon Shell Unix socket (/tmp/carbon-shell.sock)
if [ -S "/tmp/carbon-shell.sock" ]; then
    if [ -x "$CONFIG_DIR/scripts/carbon-ipc.sh" ]; then
        sh "$CONFIG_DIR/scripts/carbon-ipc.sh" focus 2>/dev/null && exit 0
    elif [ -x "${HOME}/.config/hypr/scripts/carbon-ipc.sh" ]; then
        sh "${HOME}/.config/hypr/scripts/carbon-ipc.sh" focus 2>/dev/null && exit 0
    fi
fi

# Fallback: Quickshell IPC handler
if [ -n "$QS_BIN" ]; then
    "$QS_BIN" ipc --any-display -p "$CONFIG_PATH" call focus toggle 2>/dev/null && exit 0
fi

if [ -x "$CONFIG_DIR/scripts/carbon-ipc.sh" ]; then
    sh "$CONFIG_DIR/scripts/carbon-ipc.sh" focus 2>/dev/null && exit 0
fi

exit 0
