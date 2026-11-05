#!/usr/bin/env python3
import subprocess
import time
import math
import os
import hashlib
import urllib.request
from PIL import Image, ImageDraw, ImageFont

OUT_PATH = "/tmp/hyprlock-media.png"

def get_playerctl_info():
    try:
        status = subprocess.check_output(
            ["playerctl", "status"], stderr=subprocess.DEVNULL, timeout=1
        ).decode().strip()
    except Exception:
        return None

    if not status:
        return None

    def get_meta(prop):
        try:
            return subprocess.check_output(
                ["playerctl", "metadata", prop], stderr=subprocess.DEVNULL, timeout=1
            ).decode().strip()
        except Exception:
            return ""

    title = get_meta("xesam:title") or "Unknown Title"
    artist = get_meta("xesam:artist") or "Unknown Artist"
    art_url = get_meta("mpris:artUrl")
    length_str = get_meta("mpris:length")

    pos = 0.0
    try:
        pos_str = subprocess.check_output(
            ["playerctl", "position"], stderr=subprocess.DEVNULL, timeout=1
        ).decode().strip()
        pos = float(pos_str)
    except Exception:
        pos = 0.0

    length = 0.0
    try:
        if length_str:
            length = float(length_str) / 1000000.0
    except Exception:
        length = 0.0

    return {
        "status": status,
        "title": title,
        "artist": artist,
        "art_url": art_url,
        "position": pos,
        "length": length,
    }

def get_theme_colors():
    # Defaults (Carbon / teal palette)
    bg = (14, 21, 20, 225)
    border = (129, 213, 204, 75)
    accent = (129, 213, 204)
    fg = (221, 228, 226)
    fg_dim = (177, 204, 200)
    fg_faint = (80, 100, 96)

    CARBON_CONFIG_DIR = os.environ.get("CARBON_CONFIG_DIR", os.path.expanduser("~/.config/carbon"))
    colors_conf = os.path.join(CARBON_CONFIG_DIR, "colors.conf")
    if not os.path.exists(colors_conf):
        colors_conf = os.path.expanduser("~/.config/hypr/colors.conf")

    if os.path.exists(colors_conf):
        try:
            with open(colors_conf) as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("$primary = rgba(") and len(line) >= 24:
                        hex_c = line.split("rgba(")[1][:6]
                        accent = (int(hex_c[0:2], 16), int(hex_c[2:4], 16), int(hex_c[4:6], 16))
                        border = (accent[0], accent[1], accent[2], 80)
        except Exception:
            pass

    return bg, border, accent, fg, fg_dim, fg_faint

def format_time(seconds):
    m = int(seconds) // 60
    s = int(seconds) % 60
    return f"{m}:{s:02d}"

def render_media_card(data):
    w, h = 360, 92
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    bg, border, accent, fg, fg_dim, fg_faint = get_theme_colors()

    # Card background
    draw.rounded_rectangle([0, 0, w - 1, h - 1], radius=16, fill=bg, outline=border, width=1)

    # Album art
    art_drawn = False
    art_url = data.get("art_url") or ""
    art_img = None

    if art_url.startswith("file://"):
        local_path = art_url[7:]
        if os.path.exists(local_path):
            try:
                art_img = Image.open(local_path).convert("RGBA")
            except Exception:
                pass
    elif art_url.startswith("http://") or art_url.startswith("https://"):
        url_hash = hashlib.md5(art_url.encode()).hexdigest()
        cached = f"/tmp/art_{url_hash}.png"
        if os.path.exists(cached):
            try:
                art_img = Image.open(cached).convert("RGBA")
            except Exception:
                pass
        else:
            try:
                urllib.request.urlretrieve(art_url, cached)
                art_img = Image.open(cached).convert("RGBA")
            except Exception:
                pass

    art_size = 54
    art_x, art_y = 16, 12
    if art_img:
        try:
            art_img = art_img.resize((art_size, art_size), Image.Resampling.LANCZOS)
            mask = Image.new("L", (art_size, art_size), 0)
            ImageDraw.Draw(mask).rounded_rectangle([0, 0, art_size - 1, art_size - 1], radius=10, fill=255)
            img.paste(art_img, (art_x, art_y), mask)
            art_drawn = True
        except Exception:
            pass

    if not art_drawn:
        # Placeholder art square
        draw.rounded_rectangle(
            [art_x, art_y, art_x + art_size, art_y + art_size],
            radius=10,
            fill=(25, 33, 31, 255),
            outline=(border[0], border[1], border[2], 50),
            width=1,
        )
        try:
            icon_font = ImageFont.truetype("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf", 20)
            draw.text((art_x + 18, art_y + 14), "󰎈", fill=fg_dim, font=icon_font)
        except Exception:
            pass

    # Fonts
    font_status = ImageFont.truetype("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf", 9)
    try:
        font_title = ImageFont.truetype("/usr/share/fonts/noto/NotoSans-Bold.ttf", 14)
    except Exception:
        font_title = ImageFont.truetype("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf", 13)
    font_artist = ImageFont.truetype("/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf", 11)

    # Status badge (NOW PLAYING or PAUSED)
    status_str = "NOW PLAYING" if data["status"] == "Playing" else "PAUSED"
    draw.text((80, 12), status_str, fill=fg_faint, font=font_status)

    # Title & Artist
    title = data["title"]
    if len(title) > 23:
        title = title[:21] + "…"
    artist = data["artist"]
    if len(artist) > 27:
        artist = artist[:25] + "…"

    draw.text((80, 25), title, fill=fg, font=font_title)
    draw.text((80, 44), artist, fill=fg_dim, font=font_artist)

    # Time text (e.g. 1:23 / 3:45)
    if data["length"] > 0:
        time_text = f"{format_time(data['position'])} / {format_time(data['length'])}"
        draw.text((w - 90, 12), time_text, fill=fg_faint, font=font_status)

    # Wavy playback progress line
    bar_x = 16
    bar_w = w - 32
    bar_y = 74

    prog = 0.0
    if data["length"] > 0:
        prog = max(0.0, min(1.0, data["position"] / data["length"]))

    knob_x = int(bar_x + prog * bar_w)

    # Inactive line (straight)
    if knob_x + 3 < bar_x + bar_w:
        draw.line([(knob_x + 3, bar_y), (bar_x + bar_w, bar_y)], fill=fg_faint, width=2)

    # Active line (wavy sine curve)
    if prog > 0.005:
        points = []
        freq = 3.0 + 5.0 * prog
        amp = 3.5
        phase = (time.time() * 3.2) % (2 * math.pi) if data["status"] == "Playing" else 0.0
        for x in range(bar_x, knob_x):
            rel = (x - bar_x) / bar_w
            y = bar_y + amp * math.sin(2 * math.pi * freq * rel + phase)
            points.append((x, y))

        if len(points) > 1:
            draw.line(points, fill=accent, width=3)

    # Knob pill
    draw.rounded_rectangle([knob_x - 2, bar_y - 6, knob_x + 2, bar_y + 6], radius=2, fill=(255, 255, 255))

    img.save(OUT_PATH)

def main():
    info = get_playerctl_info()
    if not info:
        # Transparent 1x1 image when nothing is playing
        blank = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
        blank.save(OUT_PATH)
    else:
        render_media_card(info)

    print(OUT_PATH)

if __name__ == "__main__":
    main()
