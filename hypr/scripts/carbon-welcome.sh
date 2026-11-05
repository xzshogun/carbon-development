#!/usr/bin/env bash
# Carbon Shell First-Boot Welcome Screen Runner
# Checks if ~/.config/carbon/.welcome_done exists. If not (or if --force is passed),
# launches the isolated WelcomeScreen.qml instance.
# When closed or completed, the process exits, consuming zero RAM afterwards.

CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
DONE_FILE="$CONFIG_DIR/.welcome_done"

if [ "$1" != "--force" ] && [ -f "$DONE_FILE" ]; then
    exit 0
fi

QS_BIN="$HOME/.local/bin/quickshell"
if ! command -v "$QS_BIN" &>/dev/null; then
    QS_BIN="quickshell"
fi

WELCOME_QML="$HOME/.local/share/quickshell/carbon/modules/welcome/WelcomeScreen.qml"
if [ ! -f "$WELCOME_QML" ]; then
    WELCOME_QML="$HOME/carbon-shell/quickshell/carbon/modules/welcome/WelcomeScreen.qml"
fi

if [ -f "$WELCOME_QML" ]; then
    exec "$QS_BIN" -p "$WELCOME_QML"
fi
