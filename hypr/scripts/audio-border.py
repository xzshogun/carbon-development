#!/usr/bin/env python3
"""
audio-border.py: Audio-reactive active window border for Hyprland.
Pulses the thin border line around active application windows between bright and dim
in rhythm with the music, using the dynamic Caelestia/Carbon theme accent color.
"""

import os
import sys
import time
import socket
import signal
import json
import subprocess
import fcntl

# Single instance lock
try:
    _lock_file = open("/tmp/audio-border.lock", "w")
    fcntl.lockf(_lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
except (IOError, BlockingIOError):
    sys.exit(0)

# 1. Locate Hyprland IPC Socket
def get_hypr_socket():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if sig and os.path.exists(f"/run/user/1000/hypr/{sig}/.socket.sock"):
        return f"/run/user/1000/hypr/{sig}/.socket.sock"
    try:
        base = "/run/user/1000/hypr"
        if os.path.exists(base):
            for d in os.listdir(base):
                p = os.path.join(base, d, ".socket.sock")
                if os.path.exists(p):
                    return p
    except Exception:
        pass
    return None

sock_path = get_hypr_socket()

def send_hypr(cmd):
    global sock_path
    if not sock_path or not os.path.exists(sock_path):
        sock_path = get_hypr_socket()
    if not sock_path:
        return
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(0.1)
            s.connect(sock_path)
            s.sendall((cmd + "\n").encode())
            s.recv(64)
    except Exception:
        sock_path = None

def set_border(color_str):
    send_hypr(f'eval hl.config({{ general = {{ col = {{ active_border = "{color_str}" }} }} }})')

# 2. Theme Color Management
CARBON_CONFIG_DIR = os.environ.get("CARBON_CONFIG_DIR", os.path.expanduser("~/.config/carbon"))
scheme_path = os.path.expanduser("~/.local/state/caelestia/scheme.json")
fallback_path = os.path.join(CARBON_CONFIG_DIR, "theme.json")
if not os.path.exists(fallback_path):
    fallback_path = os.path.expanduser("~/.config/hypr/theme.json")

last_scheme_mtime = 0
last_fallback_mtime = 0
primary_hex = "c6c6c6"

def load_theme_color():
    global last_scheme_mtime, last_fallback_mtime, primary_hex
    try:
        if os.path.exists(scheme_path):
            mtime = os.path.getmtime(scheme_path)
            if mtime != last_scheme_mtime:
                last_scheme_mtime = mtime
                with open(scheme_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                colours = data.get("colours", {})
                val = colours.get("primary") or data.get("primary")
                if val:
                    val = str(val).lstrip("#")
                    if len(val) == 6:
                        primary_hex = val
                        return primary_hex
        if os.path.exists(fallback_path):
            mtime = os.path.getmtime(fallback_path)
            if mtime != last_fallback_mtime:
                last_fallback_mtime = mtime
                with open(fallback_path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                val = data.get("accent") or data.get("primary")
                if val:
                    val = str(val).lstrip("#")
                    if len(val) == 6:
                        primary_hex = val
                        return primary_hex
    except Exception:
        pass
    return primary_hex

load_theme_color()

# 3. Clean Shutdown Handler
def cleanup(signum=None, frame=None):
    load_theme_color()
    set_border(f"rgba({primary_hex}cc)")
    sys.exit(0)

signal.signal(signal.SIGINT, cleanup)
signal.signal(signal.SIGTERM, cleanup)

# 4. Color Helper: modulate brightness & alpha in exact theme color
def compute_border_color(energy):
    """
    energy: 0.0 (silent) to 1.0 (peak beat)
    Modulates the active window border in the exact theme color,
    brightening and dimming smoothly with music.
    """
    # Alpha scales from 0x30 (dim subtle line) to 0xFF (vivid glowing highlight)
    alpha = int(0x30 + energy * (0xFF - 0x30))
    return f"rgba({primary_hex}{alpha:02x})"

# 5. Cava Setup
cava_conf = os.path.join(CARBON_CONFIG_DIR, "cava-island.conf")
if not os.path.exists(cava_conf):
    cava_conf = os.path.join(CARBON_CONFIG_DIR, "cava-edge-glow.conf")
if not os.path.exists(cava_conf):
    cava_conf = os.path.expanduser("~/.config/hypr/cava-island.conf")
if not os.path.exists(cava_conf):
    cava_conf = os.path.expanduser("~/.config/hypr/cava-edge-glow.conf")


def run_loop():
    global sock_path
    proc = subprocess.Popen(["cava", "-p", cava_conf], stdout=subprocess.PIPE, text=True, bufsize=1)

    smooth = 0.0
    last_update = 0
    silence_start = None
    is_idle = False
    check_theme_timer = 0

    while True:
        line = proc.stdout.readline()
        if not line:
            time.sleep(0.05)
            continue

        parts = line.strip().split(";")
        if len(parts) < 4:
            continue

        try:
            b0 = int(parts[0])
            b1 = int(parts[1])
            b2 = int(parts[2])
            b3 = int(parts[3])
        except ValueError:
            continue

        bass = (b0 + b1) / 180.0
        treble = (b2 + b3) / 180.0
        raw_energy = min(1.0, max(0.0, bass * 0.80 + treble * 0.20))

        now = time.time()
        # Check theme file changes every ~1 second
        if now - check_theme_timer >= 1.0:
            check_theme_timer = now
            old_hex = primary_hex
            load_theme_color()
            if is_idle and primary_hex != old_hex:
                set_border(f"rgba({primary_hex}e6)")

        # Check silence
        if raw_energy < 0.02:
            if silence_start is None:
                silence_start = now
            elif not is_idle and (now - silence_start > 1.2):
                is_idle = True
                set_border(f"rgba({primary_hex}e6)")
        else:
            silence_start = None
            is_idle = False

        if is_idle:
            time.sleep(0.08)
            continue

        # Attack / Decay Envelope
        if raw_energy > smooth:
            smooth = smooth * 0.35 + raw_energy * 0.65
        else:
            smooth = smooth * 0.82 + raw_energy * 0.18

        # Rate limit to ~30 fps max
        if now - last_update >= 0.033:
            last_update = now
            color_str = compute_border_color(smooth)
            set_border(color_str)

if __name__ == "__main__":
    try:
        run_loop()
    except KeyboardInterrupt:
        cleanup()
