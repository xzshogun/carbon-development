#!/bin/bash

# Carbon wallpaper APPLY: re-point current_wallpaper, regenerate the
# monitor-sized copy, rebuild the shell theme from the image palette
# (light/dark detected automatically) and restart the shell so the new
# palette takes effect. Usage: wp-apply.sh /path/to/wallpaper

WALL_IN="$1"
[ -z "$WALL_IN" ] && exit 1

WALL="$(readlink -f -- "$WALL_IN")"
[ -f "$WALL" ] || exit 1

SYMLINK="$HOME/.config/hypr/current_wallpaper"
CACHE_DIR="$HOME/.cache/carbon"
mkdir -p "$CACHE_DIR"

EXT="${WALL##*.}"
EXT="$(echo "$EXT" | tr '[:upper:]' '[:lower:]')"

SCALED="$CACHE_DIR/wpscale/$(basename "$WALL" | tr '.' '_').jpg"
SIG_FILE="${SCALED}.sig"
WALL_SIG="$(stat -c '%Y-%s' "$WALL" 2>/dev/null || stat -f '%m-%z' "$WALL" 2>/dev/null)"
mkdir -p "$CACHE_DIR/wpscale"

if [ -s "$SCALED" ] && [ -f "$SIG_FILE" ] && [ "$(cat "$SIG_FILE" 2>/dev/null)" = "$WALL_SIG" ]; then
    ln -sfn "$SCALED" "$CACHE_DIR/wallpaper_scaled.jpg"
else
    read -r LW LH < <(hyprctl monitors -j | python3 -c \
        'import json,sys; m=json.load(sys.stdin)[0]; print(round(m["width"]/m["scale"]), round(m["height"]/m["scale"]))' 2>/dev/null)
    LW="${LW:-2049}"; LH="${LH:-1152}"

    FRAME_SRC="$WALL"
    if [ "$EXT" = "mp4" ] || [ "$EXT" = "m4v" ] || [ "$EXT" = "webm" ] || [ "$EXT" = "mkv" ]; then
        ffmpeg -y -i "$WALL" -vframes 1 -ss 00:00:00.500 "$CACHE_DIR/wp_temp_frame.jpg" 2>/dev/null || ffmpeg -y -i "$WALL" -vframes 1 "$CACHE_DIR/wp_temp_frame.jpg" 2>/dev/null
        FRAME_SRC="$CACHE_DIR/wp_temp_frame.jpg"
    elif [ "$EXT" = "gif" ]; then
        FRAME_SRC="${WALL}[0]"
    fi

    MAGICK_BIN="magick"
    if ! command -v magick &>/dev/null; then
        if command -v convert &>/dev/null; then
            MAGICK_BIN="convert"
        else
            MAGICK_BIN=""
        fi
    fi

    if [ -n "$MAGICK_BIN" ]; then
        "$MAGICK_BIN" "$FRAME_SRC" -auto-orient -resize "${LW}x${LH}^" -gravity south -extent "${LW}x${LH}" \
            -quality 90 "$SCALED" 2>/dev/null || cp -f "$FRAME_SRC" "$SCALED" 2>/dev/null || true
    else
        cp -f "$FRAME_SRC" "$SCALED" 2>/dev/null || true
    fi
    echo "$WALL_SIG" > "$SIG_FILE"
    ln -sfn "$SCALED" "$CACHE_DIR/wallpaper_scaled.jpg"

    BLURRED="$CACHE_DIR/wpscale/$(basename "$WALL" | tr '.' '_')_blurred.jpg"
    if [ ! -s "$BLURRED" ] || [ "$BLURRED" -ot "$SCALED" ]; then
        if [ -n "$MAGICK_BIN" ]; then
            "$MAGICK_BIN" "$SCALED" -resize 25% -blur 0x16 -resize "${LW}x${LH}!" -fill "#050508" -colorize 55% -quality 85 "$BLURRED" 2>/dev/null || true
        fi
    fi
    if [ -f "$BLURRED" ]; then
        ln -sfn "$BLURRED" "$CACHE_DIR/wallpaper_blurred.jpg"
    fi
fi

# Update hypr config
mkdir -p "$HOME/.config/hypr"
ln -sfn "$WALL" "$SYMLINK"
echo "$WALL" > "$HOME/.config/hypr/current_wallpaper_path"

# Keep carbon configuration synchronized
CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
mkdir -p "$CONFIG_DIR"
ln -sfn "$WALL" "$CONFIG_DIR/current_wallpaper"
echo "$WALL" > "$CONFIG_DIR/current_wallpaper_path"

# Kill any lingering theme-mk.py from rapid changes
pkill -f "python3.*theme-mk.py" 2>/dev/null || true

# Paint wallpaper to monitor via awww daemon with distinct dynamic transitions
if command -v awww &>/dev/null; then
    TRANSITION_TYPES=("fade" "left" "right" "top" "bottom" "wipe" "wave" "grow" "center" "any" "outer")
    RANDOM_T="${TRANSITION_TYPES[$((RANDOM % ${#TRANSITION_TYPES[@]}))]}"
    RANDOM_ANGLE=$((RANDOM % 360))
    awww img "$WALL" \
        --transition-type "$RANDOM_T" \
        --transition-angle "$RANDOM_ANGLE" \
        --transition-duration 1.2 \
        --transition-fps 60 2>/dev/null || true
fi

# Update tide-island userconfig
TIDE_CFG="$HOME/.config/tide-island/userconfig.json"
if [ -f "$TIDE_CFG" ]; then
    python3 -c "import json, sys; p=sys.argv[1]; w=sys.argv[2]; d=json.load(open(p)); d['wallpaperPath']=w; json.dump(d, open(p, 'w'), indent=4)" "$TIDE_CFG" "$WALL" 2>/dev/null || true
fi

# Rebuild theme from palette
THEME_SCRIPT="$CONFIG_DIR/scripts/theme-mk.py"
[ -f "$THEME_SCRIPT" ] || THEME_SCRIPT="$HOME/.config/hypr/scripts/theme-mk.py"
[ -f "$THEME_SCRIPT" ] || THEME_SCRIPT="$(dirname "$(readlink -f "$0")")/theme-mk.py"
if [ -f "$THEME_SCRIPT" ]; then
    export MATUGEN_NO_HOOK=1
    python3 "$THEME_SCRIPT" "$WALL" 2>/dev/null || true
fi

# Direct IPC notify to Quickshell
IPC_SCRIPT="$CONFIG_DIR/scripts/carbon-ipc.sh"
[ -f "$IPC_SCRIPT" ] || IPC_SCRIPT="$HOME/.config/hypr/scripts/carbon-ipc.sh"
[ -f "$IPC_SCRIPT" ] || IPC_SCRIPT="$(dirname "$(readlink -f "$0")")/carbon-ipc.sh"
if [ -f "$IPC_SCRIPT" ] && [ -S "/tmp/carbon-shell.sock" ]; then
    sh "$IPC_SCRIPT" "apply-wallpaper $WALL" 2>/dev/null || true
fi

echo "applied: $WALL"