#!/usr/bin/env python3
"""
Carbon Live Animated Wallpaper Generator
Renders a high-tech quantum Bohr model of Carbon with pure pitch-black background,
glowing electron orbital paths, flowing comet trails, hexagonal graphene lattice,
HUD telemetry, and periodic harmonic shockwaves.
"""
import math
import subprocess
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFont

W, H = 1366, 768
CX, CY = W // 2, H // 2
FPS = 60
DURATION = 8.0
TOTAL_FRAMES = int(FPS * DURATION)  # 480 frames

# Color definitions (BGR for OpenCV)
C_BLACK = (0, 0, 0)
C_CYAN_NEON = (255, 240, 0)     # #00f0ff in BGR
C_CYAN_BRIGHT = (255, 190, 40)  # #28bef0 in BGR
C_CYAN_MID = (220, 140, 0)      # #008cdc in BGR
C_CYAN_DEEP = (160, 80, 0)      # #0050a0 in BGR
C_CYAN_FAINT = (80, 40, 0)      # very faint cyan
C_WHITE = (255, 255, 255)
C_SAPPHIRE = (70, 25, 5)

FONT_PATH = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf"
FONT_MAIN = ImageFont.truetype(FONT_PATH, 86)
FONT_SM = ImageFont.truetype(FONT_PATH, 13)
FONT_XS = ImageFont.truetype(FONT_PATH, 11)

# Pre-generate 120 ambient quantum particles with harmonic sinusoidal drift
# This guarantees 100% mathematically seamless looping with zero jumps at boundary!
np.random.seed(42)
PARTICLES = []
for _ in range(120):
    PARTICLES.append({
        "x0": np.random.uniform(30, W - 30),
        "y0": np.random.uniform(30, H - 30),
        "ax": np.random.uniform(15, 45),    # harmonic x amplitude
        "ay": np.random.uniform(10, 30),    # harmonic y amplitude
        "radius": np.random.choice([1.0, 1.3, 1.8, 2.2], p=[0.5, 0.3, 0.15, 0.05]),
        "base_alpha": np.random.uniform(0.20, 0.70),
        "phase": np.random.uniform(0, math.pi * 2),
        "freq": np.random.choice([1, 2])    # integer cycles per 8.0s
    })

def render_frame(t):
    """
    Render a single frame at time t (0 <= t < DURATION).
    """
    # 1. Base pitch-black background
    frame = np.zeros((H, W, 3), dtype=np.uint8)
    
    # 2. Breathing central nebula / aura + Heartbeat Surge
    pulse_phase = (2.0 * math.pi * 2.0 * t) / DURATION
    breath = 0.5 + 0.5 * math.sin(pulse_phase)
    
    # Heartbeat surge every 2 seconds
    surge_t = (t % 2.0)
    surge = ((0.35 - surge_t) / 0.35) ** 2.0 if surge_t < 0.35 else 0.0
    
    # Draw soft radial gradient using multiple blended circles
    nebula_overlay = np.zeros((H, W, 3), dtype=np.uint8)
    nebula_r_max = int(330 + 35 * breath + 20 * surge)
    for nr in range(nebula_r_max, 20, -25):
        factor = (1.0 - (nr / nebula_r_max)) ** 1.8
        alpha = factor * (0.16 + 0.06 * breath + 0.08 * surge)
        col = (int(C_SAPPHIRE[0] * alpha * 2.6), int(C_SAPPHIRE[1] * alpha * 2.6), int(C_SAPPHIRE[2] * alpha * 2.6))
        cv2.circle(nebula_overlay, (CX, CY), nr, col, -1, lineType=cv2.LINE_AA)
    
    frame = cv2.add(frame, nebula_overlay)

    # 3. Hexagonal Graphene Lattice (Carbon honeycomb)
    hex_overlay = np.zeros((H, W, 3), dtype=np.uint8)
    hex_size = 42
    dx = hex_size * 1.5
    dy = hex_size * math.sqrt(3)
    radius_limit = 480
    
    rows = int(radius_limit / dy) + 2
    cols = int(radius_limit / dx) + 2
    
    for r in range(-rows, rows + 1):
        for c in range(-cols, cols + 1):
            hx = CX + c * dx
            hy = CY + r * dy + (c % 2) * (dy / 2)
            dist = math.hypot(hx - CX, hy - CY)
            if dist > radius_limit or dist < 65:  # clear space inside nucleus
                continue
            
            # Smooth falloff at edges
            edge_fade = max(0.0, 1.0 - (dist / radius_limit)) ** 1.5
            inner_fade = min(1.0, (dist - 65) / 50.0)
            alpha = edge_fade * inner_fade * (0.07 + 0.02 * breath + 0.03 * surge)
            col = (int(C_CYAN_NEON[0] * alpha), int(C_CYAN_NEON[1] * alpha), int(C_CYAN_NEON[2] * alpha))
            
            pts = []
            for i in range(6):
                ang = math.radians(60 * i)
                px = int(hx + hex_size * 0.52 * math.cos(ang))
                py = int(hy + hex_size * 0.52 * math.sin(ang))
                pts.append((px, py))
            pts = np.array(pts, np.int32)
            cv2.polylines(hex_overlay, [pts], True, col, 1, lineType=cv2.LINE_AA)
            
            # Small vertex dots on some intersections
            if (r + c) % 3 == 0 and dist < 380:
                dot_col = (int(C_CYAN_NEON[0] * alpha * 1.6), int(C_CYAN_NEON[1] * alpha * 1.6), int(C_CYAN_NEON[2] * alpha * 1.6))
                cv2.circle(hex_overlay, (int(hx), int(hy)), 1, dot_col, -1, lineType=cv2.LINE_AA)

    frame = cv2.add(frame, hex_overlay)

    # 4. Ambient Quantum Dust Particles (Harmonic seamless loop)
    particle_overlay = np.zeros((H, W, 3), dtype=np.uint8)
    frac = t / DURATION
    for p in PARTICLES:
        k = p["freq"]
        px = int(p["x0"] + p["ax"] * math.sin(2.0 * math.pi * k * frac + p["phase"]))
        py = int(p["y0"] + p["ay"] * math.cos(2.0 * math.pi * k * frac + p["phase"]))
        
        # Twinkle
        p_twinkle = math.sin(2.0 * math.pi * k * frac + p["phase"])
        alpha = max(0.08, min(0.95, p["base_alpha"] + 0.28 * p_twinkle))
        
        # Slight cyan-white tint
        col = (int(255 * alpha), int(235 * alpha), int(190 * alpha))
        cv2.circle(particle_overlay, (px, py), int(round(p["radius"])), col, -1, lineType=cv2.LINE_AA)

    frame = cv2.add(frame, particle_overlay)

    # 5. Harmonic Shockwave Ripples (staggered by 2.0s, period 4.0s)
    ripple_period = 4.0
    for ripple_idx in range(2):
        r_t = (t + ripple_idx * 2.0) % ripple_period
        progress = r_t / ripple_period  # 0.0 to 1.0
        
        # Expanding radius: ease-out
        ease_p = 1.0 - (1.0 - progress) ** 2.2
        r_current = int(50 + ease_p * 460)
        
        if progress < 0.75:
            r_alpha = (1.0 - (progress / 0.75)) ** 1.3 * 0.48
            r_thick = max(1, int(3 * (1.0 - progress)))
            r_col = (int(C_CYAN_NEON[0] * r_alpha), int(C_CYAN_NEON[1] * r_alpha), int(C_CYAN_NEON[2] * r_alpha))
            # Secondary soft glow line
            glow_col = (int(C_CYAN_NEON[0] * r_alpha * 0.35), int(C_CYAN_NEON[1] * r_alpha * 0.35), int(C_CYAN_NEON[2] * r_alpha * 0.35))
            cv2.circle(frame, (CX, CY), r_current, glow_col, r_thick + 4, lineType=cv2.LINE_AA)
            cv2.circle(frame, (CX, CY), r_current, r_col, r_thick, lineType=cv2.LINE_AA)

    # 6. Atomic Orbital Shells & Guide Tracks
    R_INNER = 120  # K-shell radius
    R_OUTER = 220  # L-shell radius
    R_VALENCE = 320 # HUD valence limit

    # Outer HUD valence ring (subtle dashed / segmented)
    hud_overlay = np.zeros((H, W, 3), dtype=np.uint8)
    # Draw subtle circular tracks
    cv2.circle(hud_overlay, (CX, CY), R_INNER, (60, 35, 0), 1, lineType=cv2.LINE_AA)
    cv2.circle(hud_overlay, (CX, CY), R_OUTER, (60, 35, 0), 1, lineType=cv2.LINE_AA)
    cv2.circle(hud_overlay, (CX, CY), R_VALENCE, (40, 20, 0), 1, lineType=cv2.LINE_AA)

    # HUD degree tick marks at R_VALENCE
    hud_rot = (2.0 * math.pi * t) / DURATION  # 1 rotation per 8s
    for deg in range(0, 360, 15):
        rad = math.radians(deg) + hud_rot * 0.2
        is_major = (deg % 90 == 0)
        is_semi = (deg % 45 == 0)
        tick_len = 10 if is_major else (6 if is_semi else 3)
        tick_alpha = 0.55 if is_major else (0.35 if is_semi else 0.18)
        
        x1 = int(CX + (R_VALENCE - tick_len / 2) * math.cos(rad))
        y1 = int(CY + (R_VALENCE - tick_len / 2) * math.sin(rad))
        x2 = int(CX + (R_VALENCE + tick_len / 2) * math.cos(rad))
        y2 = int(CY + (R_VALENCE + tick_len / 2) * math.sin(rad))
        
        tcol = (int(C_CYAN_NEON[0] * tick_alpha), int(C_CYAN_NEON[1] * tick_alpha), int(C_CYAN_NEON[2] * tick_alpha))
        cv2.line(hud_overlay, (x1, y1), (x2, y2), tcol, 1 if not is_major else 2, lineType=cv2.LINE_AA)

    # 4 Cardinal Reticle Brackets on outer shell
    bracket_rad = R_VALENCE + 20
    for ang_deg in [45, 135, 225, 315]:
        arad = math.radians(ang_deg)
        bx = int(CX + bracket_rad * math.cos(arad))
        by = int(CY + bracket_rad * math.sin(arad))
        # Draw small crosshair corner
        bcol = (140, 90, 0)
        cv2.drawMarker(hud_overlay, (bx, by), bcol, markerType=cv2.MARKER_TILTED_CROSS, markerSize=8, thickness=1, line_type=cv2.LINE_AA)

    # Inner core rotating reticle (dashed ring at r=52)
    reticle_r = 52
    reticle_rot = (2.0 * math.pi * t) / DURATION  # clockwise
    for seg in range(12):
        s_ang1 = seg * 30 + reticle_rot * 180 / math.pi
        s_ang2 = s_ang1 + 16
        cv2.ellipse(hud_overlay, (CX, CY), (reticle_r, reticle_r), 0, s_ang1, s_ang2, (150, 90, 0), 1, lineType=cv2.LINE_AA)

    frame = cv2.add(frame, hud_overlay)

    # 7. Electrons & Flowing Comet Trails
    # K-Shell (Inner): 2 electrons, clockwise, 2 full cycles in 8s (omega = 4*pi / 8)
    omega_k = (4.0 * math.pi * t) / DURATION
    electrons_k = [omega_k, omega_k + math.pi]

    # L-Shell (Outer): 4 electrons, counter-clockwise, 1 full cycle in 8s (omega = -2*pi / 8)
    omega_l = - (2.0 * math.pi * t) / DURATION
    electrons_l = [omega_l + i * (math.pi / 2.0) for i in range(4)]

    trail_overlay = np.zeros((H, W, 3), dtype=np.uint8)

    # Helper to draw an electron with silky smooth continuous comet tail
    def draw_electron_with_tail(overlay, radius, angle, direction, tail_angle_span=0.75, num_dots=50, dot_base_r=5.5):
        # Sample points along the trail from tail to head
        pts = []
        alphas = []
        for s in range(num_dots, -1, -1):
            frac = s / float(num_dots)  # 1.0 at tail end, 0.0 at head
            trail_ang = angle - direction * (frac * tail_angle_span)
            tx = int(round(CX + radius * math.cos(trail_ang)))
            ty = int(round(CY + radius * math.sin(trail_ang)))
            pts.append((tx, ty))
            alphas.append((1.0 - frac) ** 1.7)

        # Draw smooth glowing segments
        for i in range(len(pts) - 1):
            p1, p2 = pts[i], pts[i+1]
            a = (alphas[i] + alphas[i+1]) * 0.5
            thick = max(1, int(round(a * 4.0)))
            
            # Outer diffuse glow pass
            glow_thick = thick + 5
            g_alpha = a * 0.22
            gcol = (int(C_CYAN_NEON[0] * g_alpha), int(C_CYAN_NEON[1] * g_alpha), int(C_CYAN_NEON[2] * g_alpha))
            cv2.line(overlay, p1, p2, gcol, glow_thick, lineType=cv2.LINE_AA)
            
            # Core bright stream
            c_alpha = a * 0.85
            ccol = (int(C_CYAN_NEON[0] * c_alpha), int(C_CYAN_NEON[1] * c_alpha), int(C_CYAN_NEON[2] * c_alpha))
            cv2.line(overlay, p1, p2, ccol, thick, lineType=cv2.LINE_AA)

        # Electron head position
        ex = int(round(CX + radius * math.cos(angle)))
        ey = int(round(CY + radius * math.sin(angle)))

        # Wide luminous glow halo
        cv2.circle(overlay, (ex, ey), 18, (140, 70, 0), -1, lineType=cv2.LINE_AA)
        cv2.circle(overlay, (ex, ey), 11, (240, 150, 0), -1, lineType=cv2.LINE_AA)
        cv2.circle(overlay, (ex, ey), 7, C_CYAN_NEON, -1, lineType=cv2.LINE_AA)
        # Intense white energized core
        cv2.circle(overlay, (ex, ey), int(round(dot_base_r)), C_WHITE, -1, lineType=cv2.LINE_AA)
        cv2.circle(overlay, (ex, ey), int(round(dot_base_r - 2)), C_CYAN_NEON, 1, lineType=cv2.LINE_AA)

    # Draw Inner K-shell electrons (clockwise: direction = +1)
    for ang in electrons_k:
        draw_electron_with_tail(trail_overlay, R_INNER, ang, direction=1, tail_angle_span=0.90, num_dots=50, dot_base_r=5.0)

    # Draw Outer L-shell electrons (counter-clockwise: direction = -1)
    for ang in electrons_l:
        draw_electron_with_tail(trail_overlay, R_OUTER, ang, direction=-1, tail_angle_span=0.75, num_dots=45, dot_base_r=5.5)

    frame = cv2.add(frame, trail_overlay)

    # 8. Central Carbon Nucleus "C" Glyph
    pil_frame = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(pil_frame, "RGBA")

    # Central Core glow disc
    core_glow_r = int(38 + 4 * breath)
    core_glow_alpha = int(75 + 40 * breath)
    draw.ellipse([CX - core_glow_r, CY - core_glow_r, CX + core_glow_r, CY + core_glow_r],
                 fill=(0, 180, 255, core_glow_alpha))
    
    # Outer core ring
    draw.ellipse([CX - 40, CY - 40, CX + 40, CY + 40],
                 outline=(0, 240, 255, 150), width=2)

    # Calculate exact bounding box of "C"
    bbox = FONT_MAIN.getbbox("C")
    bw = bbox[2] - bbox[0]
    bh = bbox[3] - bbox[1]
    tx = CX - bw // 2 - bbox[0]
    ty = CY - bh // 2 - bbox[1] - 3  # optical center balance

    # Layered bloom for "C"
    # Outer diffuse cyan glow
    for off in [(-2, 0), (2, 0), (0, -2), (0, 2), (-1, -1), (1, 1), (-1, 1), (1, -1)]:
        draw.text((tx + off[0] * 2, ty + off[1] * 2), "C", font=FONT_MAIN, fill=(0, 160, 255, 95))
    # Intense cyan body
    draw.text((tx, ty), "C", font=FONT_MAIN, fill=(0, 240, 255, 245))
    # Crisp specular white inner highlight
    draw.text((tx, ty), "C", font=FONT_MAIN, fill=(255, 255, 255, 140))

    # 9. Carbon Sci-Fi Telemetry & Typography
    # Upper left of atom:
    draw.text((CX - 280, CY - 240), "CARBON // [C-12]", font=FONT_SM, fill=(0, 220, 255, 140))
    draw.text((CX - 280, CY - 222), "ATOMIC NO. 06  •  M = 12.011 u", font=FONT_XS, fill=(0, 180, 240, 95))
    
    # Lower right of atom:
    draw.text((CX + 110, CY + 225), "SHELL CONFIG: [He] 2s² 2p²", font=FONT_SM, fill=(0, 220, 255, 140))
    draw.text((CX + 110, CY + 243), "VALENCE: 4 ELECTRONS  •  BOHR MODEL", font=FONT_XS, fill=(0, 180, 240, 95))

    # Faint cardinal crosshair line marks extending outward
    draw.line([(CX - R_VALENCE - 40, CY), (CX - R_VALENCE - 15, CY)], fill=(0, 200, 255, 80), width=1)
    draw.line([(CX + R_VALENCE + 15, CY), (CX + R_VALENCE + 40, CY)], fill=(0, 200, 255, 80), width=1)
    draw.line([(CX, CY - R_VALENCE - 40), (CX, CY - R_VALENCE - 15)], fill=(0, 200, 255, 80), width=1)
    draw.line([(CX, CY + R_VALENCE + 15), (CX, CY + R_VALENCE + 40)], fill=(0, 200, 255, 80), width=1)

    # Convert back to OpenCV BGR
    result_bgr = cv2.cvtColor(np.array(pil_frame.convert("RGB")), cv2.COLOR_RGB2BGR)
    return result_bgr

if __name__ == "__main__":
    import sys
    home_dir = os.path.expanduser("~")
    if len(sys.argv) > 1 and sys.argv[1] == "--test":
        print("Rendering preview frame at t=1.2s...")
        preview = render_frame(1.2)
        preview_path = os.path.join(home_dir, ".cache/carbon/carbon_preview.png")
        os.makedirs(os.path.dirname(preview_path), exist_ok=True)
        cv2.imwrite(preview_path, preview)
        print(f"Saved preview to {preview_path}")
    else:
        out_path = os.path.join(home_dir, "Pictures/Wallpapers/carbon-quantum-dark.mp4")
        print(f"Rendering {TOTAL_FRAMES} frames ({DURATION}s @ {FPS}fps) to {out_path}...")
        
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
            frame = render_frame(t)
            proc.stdin.write(frame.tobytes())
            if (i + 1) % 60 == 0 or i == TOTAL_FRAMES - 1:
                print(f"Progress: {i+1}/{TOTAL_FRAMES} frames ({((i+1)/TOTAL_FRAMES)*100:.1f}%)")
                
        proc.stdin.close()
        proc.wait()
        print(f"Done! Live animated wallpaper successfully created at: {out_path}")
