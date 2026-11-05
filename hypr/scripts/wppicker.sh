#!/bin/bash

# === CONFIG ===
WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"

cd "$WALLPAPER_DIR" || exit 1

# === handle spaces name
IFS=$'\n'

# === ICON-PREVIEW SELECTION WITH ROFI, SORTED BY NEWEST ===
SELECTED_WALL=$(for a in $(ls -t *.jpg *.png *.gif *.jpeg 2>/dev/null); do echo -en "$a\0icon\x1f$a\n"; done | rofi -dmenu -p "")
[ -z "$SELECTED_WALL" ] && exit 1
SELECTED_PATH="$WALLPAPER_DIR/$SELECTED_WALL"

# === SET WALLPAPER ===
matugen image --source-color-index 0 -t scheme-tonal-spot --prefer saturation -m dark "$SELECTED_PATH" 2>/dev/null || matugen image --source-color-index 0 -t scheme-tonal-spot -m dark "$SELECTED_PATH" 2>/dev/null || true

# === COPY WALLPAPER & APPLY ===
CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
mkdir -p "$CONFIG_DIR"
cp -f "$SELECTED_PATH" "$CONFIG_DIR/current_wallpaper"
echo "$SELECTED_PATH" > "$CONFIG_DIR/current_wallpaper_path"
APPLY_SCRIPT="$CONFIG_DIR/scripts/wp-apply.sh"
[ -f "$APPLY_SCRIPT" ] || APPLY_SCRIPT="$HOME/.config/carbon/scripts/wp-apply.sh"
sh "$APPLY_SCRIPT" "$SELECTED_PATH"


