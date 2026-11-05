#!/usr/bin/env bash
# ==============================================================================
# Carbon Shell — Carbon Drop Toggler / Launcher
# ==============================================================================

if pgrep -x "carbon-drop" > /dev/null; then
    ACTIVE_TITLE=$(hyprctl activewindow -j 2>/dev/null | jq -r '.title // empty' 2>/dev/null)
    if [ "$ACTIVE_TITLE" = "Carbon Drop" ]; then
        hyprctl dispatch closewindow "title:Carbon Drop"
    else
        hyprctl dispatch focuswindow "title:Carbon Drop"
    fi
else
    nohup "${HOME}/.local/bin/carbon-drop" >/dev/null 2>&1 &
fi

