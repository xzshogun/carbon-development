#!/usr/bin/env bash
# Carbon Shell — Show Desktop / Peek toggle (Hyprland)
# ---------------------------------------------------------------
# Press once  -> jump to a free (empty) workspace so you can see the desktop.
# Press again -> return to the workspace you were on.
#
# Bound via ~/.config/carbon/keybinds.conf: SUPER + D

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/carbon-show-desktop"
STATE_FILE="$STATE_DIR/prev_workspace"

mkdir -p "$STATE_DIR"

# Already peeking? Go back to the workspace we saved.
if [ -f "$STATE_FILE" ]; then
    PREV=$(cat "$STATE_FILE" 2>/dev/null)
    rm -f "$STATE_FILE"
    if [ -n "$PREV" ] && [ "$PREV" -ge 1 ] 2>/dev/null; then
        hyprctl dispatch workspace "$PREV"
    fi
    exit 0
fi

ACTIVE=$(hyprctl activeworkspace -j 2>/dev/null)
CUR=$(printf '%s' "$ACTIVE" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("id", -1))' 2>/dev/null)
WIN=$(printf '%s' "$ACTIVE" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("windows", 0))' 2>/dev/null)

# Empty workspace -> desktop already visible, nothing to do.
if [ "$CUR" -lt 1 ] 2>/dev/null || [ "$WIN" -eq 0 ] 2>/dev/null; then
    exit 0
fi

# Pick a free workspace (id with 0 windows), otherwise fall back to 99.
EMPTY=$(hyprctl workspaces -j 2>/dev/null | python3 -c '
import json, sys
ids = [w["id"] for w in json.load(sys.stdin)
       if w.get("windows", 0) == 0 and w["id"] > 0 and w["id"] != 99]
print(max(ids) if ids else 99)
' 2>/dev/null)

[ -z "$EMPTY" ] && EMPTY=99
[ "$EMPTY" = "$CUR" ] && exit 0

printf '%s' "$CUR" > "$STATE_FILE"
hyprctl dispatch workspace "$EMPTY"