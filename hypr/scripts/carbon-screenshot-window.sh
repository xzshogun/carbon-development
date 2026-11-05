#!/usr/bin/env bash
# ==============================================================================
# Carbon Active Window Screenshot
# Captures the currently focused window, saves to ~/Pictures/Screenshots,
# copies to clipboard, plays camera shutter sound, and notifies.
# ==============================================================================

DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot-$(date '+%Y-%m-%d_%H-%M-%S').png"

GEOM=""
if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    GEOM=$(hyprctl activewindow -j 2>/dev/null | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null || echo "")
fi

if [ -n "$GEOM" ] && [ "$GEOM" != "null,null nullxnull" ]; then
    grim -g "$GEOM" "$FILE" 2>/dev/null || exit 1
else
    # Fallback to fullscreen if no active window
    grim "$FILE" 2>/dev/null || exit 1
fi

# Copy to clipboard
if command -v wl-copy >/dev/null 2>&1; then
    wl-copy --type image/png < "$FILE" 2>/dev/null || true
elif [ -x "$HOME/.local/bin/wl-copy" ]; then
    "$HOME/.local/bin/wl-copy" --type image/png < "$FILE" 2>/dev/null || true
fi

# Play shutter sound
if command -v canberra-gtk-play >/dev/null 2>&1; then
    canberra-gtk-play -i camera-shutter 2>/dev/null || true
fi

# Send native desktop notification via D-Bus
if command -v gdbus >/dev/null 2>&1; then
    gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        "Screenshot" 0 "$FILE" "Window Screenshot" "Saved to $(basename "$FILE") and copied to clipboard" "[]" "{}" 4000 >/dev/null 2>&1 || true
fi
