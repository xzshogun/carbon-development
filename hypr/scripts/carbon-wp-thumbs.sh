#!/bin/sh
# Carbon wallpaper thumbnail + pre-scale pipeline. Mirrors the ukishima
# approach: per-folder png previews (512px, for the picker strip) AND
# screen-sized jpg copies (2049x1152, for instant live preview — splicing a
# symlink to a pre-scaled copy is far cheaper than re-scaling on every surf).
WPDIR="$HOME/Pictures/Wallpapers"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/carbon/wp-thumbs"
SCALE="${XDG_CACHE_HOME:-$HOME/.cache}/carbon/wpscale"
mkdir -p "$CACHE" "$SCALE"

# thumb name = source basename with every dot -> underscore, plus .png
thumb_name() {
    printf %s "$1" | tr '.' '_'
}

# Prune thumbs whose source file no longer exists.
{
    find "$WPDIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' \) -printf '%f\n' | sort -u | tr '.' '_'
} > /tmp/.carbon-wp-src.$$

{
    find "$CACHE" -maxdepth 1 -type f -name '*.png' -printf '%f\n' | sed 's/\.png$//' | sort -u
} > /tmp/.carbon-wp-thumb.$$

{
    find "$SCALE" -maxdepth 1 -type f -name '*.jpg' -printf '%f\n' | sed 's/\.jpg$//' | sort -u
} > /tmp/.carbon-wp-scale.$$

comm -23 /tmp/.carbon-wp-thumb.$$ /tmp/.carbon-wp-src.$$ | while IFS= read -r b; do
    rm -f "$CACHE/$b.png"
done
comm -23 /tmp/.carbon-wp-scale.$$ /tmp/.carbon-wp-src.$$ | while IFS= read -r b; do
    rm -f "$SCALE/$b.jpg"
done
rm -f /tmp/.carbon-wp-src.$$ /tmp/.carbon-wp-thumb.$$ /tmp/.carbon-wp-scale.$$

# Regenerate missing or outdated thumbs + scales.
read -r LW LH < <(hyprctl monitors -j | python3 -c \
    'import json,sys; m=json.load(sys.stdin)[0]; print(round(m["width"]/m["scale"]), round(m["height"]/m["scale"]))' 2>/dev/null)
LW="${LW:-2049}"; LH="${LH:-1152}"
find "$WPDIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' \) -print0 | while IFS= read -r -d '' src; do
    base=$(basename "$src")
    ext="${base##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    thumb="$CACHE/$(thumb_name "$base").png"
    scale="$SCALE/$(thumb_name "$base").jpg"

    if [ "$ext" = "mp4" ] || [ "$ext" = "webm" ] || [ "$ext" = "mkv" ]; then
        if [ ! -s "$thumb" ] || [ "$src" -nt "$thumb" ]; then
            ffmpeg -y -ss 00:00:01.000 -i "$src" -vframes 1 -vf "scale=512:-1" "$thumb.tmp.png" 2>/dev/null \
                && mv "$thumb.tmp.png" "$thumb" || rm -f "$thumb.tmp.png"
        fi
        if [ ! -s "$scale" ] || [ "$src" -nt "$scale" ]; then
            ffmpeg -y -ss 00:00:01.000 -i "$src" -vframes 1 "$scale.tmp.jpg" 2>/dev/null \
                && mv "$scale.tmp.jpg" "$scale" || rm -f "$scale.tmp.jpg"
        fi
    else
        if [ ! -s "$thumb" ] || [ "$src" -nt "$thumb" ]; then
            magick "${src}[0]" -strip -resize 512x "png:$thumb.tmp" 2>/dev/null \
                && mv "$thumb.tmp" "$thumb" || rm -f "$thumb.tmp"
        fi
        if [ ! -s "$scale" ] || [ "$src" -nt "$scale" ]; then
            magick "${src}[0]" -auto-orient -strip -resize "${LW}x${LH}^" \
                -gravity south -extent "${LW}x${LH}" -quality 88 "jpg:$scale.tmp" 2>/dev/null \
                && mv "$scale.tmp" "$scale" || rm -f "$scale.tmp"
        fi
    fi
done