#!/usr/bin/env bash
# ==============================================================================
# Carbon Region Screenshot with Instant Screen Freeze
# Captures the screen immediately when invoked, freezes the display on
# Quickshell's overlay layer while selecting, and crops the frozen frame.
# ==============================================================================

DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/screenshot-$(date '+%Y-%m-%d_%H-%M-%S').png"
TMP_FREEZE="/tmp/carbon_freeze_$$.png"

CARBON_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IPC_SCRIPT="$CARBON_SCRIPTS/carbon-ipc.sh"
[ ! -f "$IPC_SCRIPT" ] && IPC_SCRIPT="$HOME/.config/carbon/scripts/carbon-ipc.sh"
[ ! -f "$IPC_SCRIPT" ] && IPC_SCRIPT="$HOME/.config/hypr/scripts/carbon-ipc.sh"

# Ensure freeze overlay and temp files are cleaned up on any exit
cleanup() {
    if [ -f "$IPC_SCRIPT" ]; then
        sh "$IPC_SCRIPT" "freeze-stop" >/dev/null 2>&1 || true
    fi
    rm -f "$TMP_FREEZE"
}
trap cleanup EXIT INT TERM

# 1. Capture instant snapshot of the full desktop
if ! grim "$TMP_FREEZE" 2>/dev/null; then
    exit 1
fi

# 2. Trigger screen freeze overlay on Quickshell
if [ -f "$IPC_SCRIPT" ]; then
    sh "$IPC_SCRIPT" "freeze-start $TMP_FREEZE" >/dev/null 2>&1 || true
    # Brief yield so layer-shell commits the surface
    sleep 0.04
fi

# 3. Gather window bounding boxes on active workspace for single-click window capture
BOXES=""
if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    WS_ID=$(hyprctl activeworkspace -j 2>/dev/null | jq '.id' 2>/dev/null || echo "")
    if [ -n "$WS_ID" ]; then
        BOXES=$(hyprctl clients -j 2>/dev/null | jq -r ".[] | select(.workspace.id == $WS_ID) | \"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])\"" 2>/dev/null || echo "")
    fi
fi

# 4. Let user select window or drag custom region over the frozen screen
SLURP_ARGS=(-d -b "#00000055" -c "#f4a7b5" -s "#f4a7b522" -w 2)
if [ -n "$BOXES" ]; then
    GEOM=$(echo "$BOXES" | slurp "${SLURP_ARGS[@]}" 2>/dev/null) || exit 0
else
    GEOM=$(slurp "${SLURP_ARGS[@]}" 2>/dev/null) || exit 0
fi

# 5. Hide freeze overlay immediately after selection completes
if [ -f "$IPC_SCRIPT" ]; then
    sh "$IPC_SCRIPT" "freeze-stop" >/dev/null 2>&1 || true
fi

# Cancelled or invalid geometry
if [ -z "$GEOM" ]; then
    exit 0
fi

# 6. Crop exactly from the frozen capture using Python PIL (pixel-perfect frame accuracy)
python3 -c '
import sys
from PIL import Image
try:
    geom = sys.argv[1].strip()
    src = sys.argv[2]
    dst = sys.argv[3]
    pos, size = geom.split()
    x, y = map(int, pos.split(","))
    w, h = map(int, size.split("x"))
    if w <= 0 or h <= 0:
        sys.exit(1)
    im = Image.open(src)
    crop = im.crop((x, y, x + w, y + h))
    crop.save(dst)
except Exception:
    sys.exit(1)
' "$GEOM" "$TMP_FREEZE" "$FILE" || {
    # Fallback to grim if cropping fails
    grim -g "$GEOM" "$FILE" 2>/dev/null || exit 1
}

# 7. Copy to clipboard
if command -v wl-copy >/dev/null 2>&1; then
    wl-copy --type image/png < "$FILE" 2>/dev/null || true
elif [ -x "$HOME/.local/bin/wl-copy" ]; then
    "$HOME/.local/bin/wl-copy" --type image/png < "$FILE" 2>/dev/null || true
fi

# 8. Play shutter sound
if command -v canberra-gtk-play >/dev/null 2>&1; then
    canberra-gtk-play -i camera-shutter 2>/dev/null || true
fi

# 9. Send native desktop notification via D-Bus
if command -v gdbus >/dev/null 2>&1; then
    gdbus call --session \
        --dest org.freedesktop.Notifications \
        --object-path /org/freedesktop/Notifications \
        --method org.freedesktop.Notifications.Notify \
        "Screenshot" 0 "$FILE" "Screenshot Captured" "Saved to $(basename "$FILE") and copied to clipboard" "[]" "{}" 4000 >/dev/null 2>&1 || true
elif command -v notify-send >/dev/null 2>&1; then
    notify-send -a "Carbon Screenshot" -i "$FILE" "Screenshot Captured" "Saved to $(basename "$FILE")" 2>/dev/null || true
fi