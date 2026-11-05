#!/usr/bin/env python3
"""
Generate Carbon Lewis Live Wallpapers (Dark and Light versions)
Renders the exact Bohr atomic model of Carbon (atomic number 6)
with the scaled up radii and pure monochrome aesthetic:
- Carbon-Live-Dark.mp4: Pure black background, white C, white dots, white rings
- Carbon-Live-Light.mp4: Pure white background, black C, black dots, black rings
"""
import math
import os
import subprocess
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont

W, H = 1366, 768
CX, CY = W // 2, H // 2
FPS = 60
DURATION = 8.0
TOTAL_FRAMES = int(FPS * DURATION)  # 480 frames

R_INNER = 82
R_OUTER = 145

FONT_PATH = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf"
FONT_MAIN = ImageFont.truetype(FONT_PATH, 104)

OUT_DIR = os.path.expanduser("~/Pictures/Live_Wallpapers")
os.makedirs(OUT_DIR, exist_ok=True)


def render_lewis_frame(t, is_light=False):
    """
    Renders a single frame of the Carbon Lewis dot animation.
    """
    bg_val = 255 if is_light else 0
    fg_col = (0, 0, 0) if is_light else (255, 255, 255)       # BGR
    ring_col = (180, 180, 180) if is_light else (75, 75, 75)
    dot_core = (0, 0, 0) if is_light else (255, 255, 255)
    dot_halo = (210, 210, 210) if is_light else (115, 115, 115)
    inner_dot_center = (255, 255, 255) if is_light else (255, 255, 255)

    frame = np.full((H, W, 3), bg_val, dtype=np.uint8)

    # 1. Breathing pulse
    pulse_phase = (2.0 * math.pi * 2.0 * t) / DURATION
    breath = 0.5 + 0.5 * math.sin(pulse_phase)

    # 2. Periodic Shockwave Ripple (Heartbeat) every 1.85s
    heartbeat_cycle = 1.85
    r_t = t % heartbeat_cycle
    r_progress = r_t / heartbeat_cycle
    if r_progress < 0.45:
        # Scale 0.9 to 2.3
        ease = 1.0 - (1.0 - (r_progress / 0.45)) ** 2.0
        r_current = int(R_OUTER * (0.9 + ease * 1.4))
        r_alpha = (1.0 - (r_progress / 0.45)) ** 1.5 * 0.85
        if is_light:
            r_col = tuple(int(255 - (255 - 0) * r_alpha) for _ in range(3))
        else:
            r_col = tuple(int(255 * r_alpha) for _ in range(3))
        cv2.circle(frame, (CX, CY), r_current, r_col, 3, lineType=cv2.LINE_AA)

    # 3. Orbital Rings
    # Inner ring (radius 82)
    cv2.circle(frame, (CX, CY), R_INNER, ring_col, 2, lineType=cv2.LINE_AA)
    # Outer ring (radius 145)
    cv2.circle(frame, (CX, CY), R_OUTER, ring_col, 2, lineType=cv2.LINE_AA)

    # 4. Dot scale pulse on heartbeat
    dot_scale = 1.0
    if r_progress < 0.12:
        dot_scale = 1.0 + 0.35 * (r_progress / 0.12)
    elif r_progress < 0.28:
        dot_scale = 1.35 - 0.35 * ((r_progress - 0.12) / 0.16)

    # 5. Valence Dots
    # Layer 1: Inner 2 dots (clockwise, 5.8s period)
    ang_inner = (2.0 * math.pi * t) / 5.8
    inner_dots = [ang_inner, ang_inner + math.pi]

    # Layer 2: Outer 4 dots (counter-clockwise, 9.4s period)
    ang_outer = - (2.0 * math.pi * t) / 9.4
    outer_dots = [ang_outer + i * (math.pi / 2.0) for i in range(4)]

    def draw_valence_dot(x, y, halo_r, core_r, inner_r):
        h_r = int(round(halo_r * dot_scale))
        c_r = int(round(core_r * dot_scale))
        i_r = int(round(inner_r * dot_scale))

        # Halo
        cv2.circle(frame, (x, y), h_r, dot_halo, -1, lineType=cv2.LINE_AA)
        # Core
        cv2.circle(frame, (x, y), c_r, dot_core, -1, lineType=cv2.LINE_AA)
        if is_light:
            cv2.circle(frame, (x, y), c_r, (0, 0, 0), 2, lineType=cv2.LINE_AA)
        else:
            cv2.circle(frame, (x, y), c_r, (255, 255, 255), 2, lineType=cv2.LINE_AA)
        # Center dot
        cv2.circle(frame, (x, y), i_r, inner_dot_center, -1, lineType=cv2.LINE_AA)

    # Draw inner dots
    for ang in inner_dots:
        dx = int(round(CX + R_INNER * math.cos(ang)))
        dy = int(round(CY + R_INNER * math.sin(ang)))
        draw_valence_dot(dx, dy, 23, 14, 5)

    # Draw outer dots
    for ang in outer_dots:
        dx = int(round(CX + R_OUTER * math.cos(ang)))
        dy = int(round(CY + R_OUTER * math.sin(ang)))
        draw_valence_dot(dx, dy, 28, 17, 6)

    # 6. Central "C" Glyph via PIL for crisp typography
    pil_frame = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(pil_frame, "RGBA")

    # Center glow disc
    glow_alpha = int(40 + 25 * breath)
    glow_col = (0, 0, 0, glow_alpha) if is_light else (255, 255, 255, glow_alpha)
    draw.ellipse([CX - 48, CY - 48, CX + 48, CY + 48], fill=glow_col)

    # Central "C" letter
    bbox = FONT_MAIN.getbbox("C")
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    tx = CX - bw // 2 - bbox[0]
    ty = CY - bh // 2 - bbox[1] - 6

    text_col = (0, 0, 0, 255) if is_light else (255, 255, 255, 255)
    spec_col = (60, 60, 60, 140) if is_light else (255, 255, 255, 120)

    draw.text((tx, ty), "C", font=FONT_MAIN, fill=text_col)
    draw.text((tx, ty), "C", font=FONT_MAIN, fill=spec_col)

    result_bgr = cv2.cvtColor(np.array(pil_frame.convert("RGB")), cv2.COLOR_RGB2BGR)
    return result_bgr


def generate_video(is_light, filename):
    out_path = os.path.join(OUT_DIR, filename)
    print(f"Generating {'Light' if is_light else 'Dark'} video to {out_path}...")

    ffmpeg_cmd = [
        "ffmpeg", "-y",
        "-f", "rawvideo",
        "-vcodec", "rawvideo",
        "-s", f"{W}x{H}",
        "-pix_fmt", "bgr24",
        "-r", str(FPS),
        "-i", "-",
        "-c:v", "libx264",
        "-pix_fmt", "yuv420p",
        "-crf", "16",
        "-preset", "fast",
        out_path
    ]

    proc = subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE, stderr=subprocess.PIPE)

    for i in range(TOTAL_FRAMES):
        t = (i / float(TOTAL_FRAMES)) * DURATION
        frame = render_lewis_frame(t, is_light=is_light)
        proc.stdin.write(frame.tobytes())

    proc.stdin.close()
    proc.wait()
    print(f"Finished {out_path}!")


if __name__ == "__main__":
    generate_video(is_light=False, filename="Carbon-Live-Dark.mp4")
    generate_video(is_light=True, filename="Carbon-Live-Light.mp4")
