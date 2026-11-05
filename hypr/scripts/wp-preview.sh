#!/bin/bash

# Carbon wallpaper LIVE PREVIEW: re-point current_wallpaper and, when a
# pre-scaled copy exists (~/.cache/carbon/wpscale), just re-splice the symlink
# — no ImageMagick on the hot path, so arrow-surfing is instant. Falls back to
# a one-off scale for wallpapers the cache hasn't caught up with yet. The shell
# watches the symlink and redraws, WITHOUT touching the theme.
# Usage: wp-preview.sh /path/to/wallpaper

WALL_IN="$1"
[ -z "$WALL_IN" ] && exit 1

WALL="$(readlink -f -- "$WALL_IN")"
[ -f "$WALL" ] || exit 1

CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
mkdir -p "$CONFIG_DIR"
CACHE_DIR="$HOME/.cache/carbon"
mkdir -p "$CACHE_DIR"

SCALED="$CACHE_DIR/wpscale/$(basename "$WALL" | tr '.' '_').jpg"
if [ -s "$SCALED" ]; then
    cp -f "$SCALED" "$CACHE_DIR/wallpaper_scaled.jpg"
else
    magick "$WALL" -auto-orient -resize '2049x1152^' -gravity south -extent 2049x1152 \
        -quality 90 "$CACHE_DIR/wallpaper_scaled.jpg" 2>/dev/null || exit 1
fi

cp -f "$WALL" "$CONFIG_DIR/current_wallpaper"
echo "$WALL" > "$CONFIG_DIR/current_wallpaper_path"
echo "preview-ready: $WALL"