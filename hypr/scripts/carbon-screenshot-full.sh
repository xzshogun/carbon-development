#!/usr/bin/env bash
# ==============================================================================
# Carbon Fullscreen Screenshot
# Captures all visible monitors, saves to ~/Pictures/Screenshots,
# copies to clipboard, plays camera shutter sound, and notifies.
# ==============================================================================

DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot-$(date '+%Y-%m-%d_%H-%M-%S').png"

if ! grim "$FILE" 2>/dev/null; then
    exit 1
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
        "Screenshot" 0 "$FILE" "Fullscreen Screenshot" "Saved to $(basename "$FILE") and copied to clipboard" "[]" "{}" 4000 >/dev/null 2>&1 || true
elif command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Carbon Screenshot" -i "$FILE" "Screenshot Taken" "Full screen saved to $(basename "$FILE")" 2>/dev/null || true
fi
