#!/usr/bin/env python3
"""Carbon Hub Daemon (Python asyncio fallback for /tmp/carbon-hub.sock).

Implements the exact same newline-delimited JSON RPC protocol over /tmp/carbon-hub.sock
as the native Rust `carbon-hub-daemon`, ensuring that `SUPER + SHIFT + C` (Settings Hub)
works 100% even on systems where `cargo` / Rust was not installed at setup time.
"""

import asyncio
import json
import os
import random
import subprocess
import sys
import time

SOCKET_PATH = "/tmp/carbon-hub.sock"


def home_dir():
    return os.environ.get("HOME", os.path.expanduser("~"))


def config_dir():
    return os.environ.get("CARBON_CONFIG_DIR", os.path.join(home_dir(), ".config", "carbon"))


def hypr_cmd(args):
    try:
        subprocess.run(["hyprctl"] + list(args), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1.5)
        return True
    except Exception:
        return False


def get_hypr_option(opt, default_val):
    try:
        res = subprocess.run(["hyprctl", "getoption", opt, "-j"], capture_output=True, text=True, timeout=1.0)
        if res.returncode == 0 and res.stdout.strip():
            d = json.loads(res.stdout)
            if "float" in d and isinstance(d["float"], (int, float)) and d["float"] != 0:
                return d["float"]
            if "int" in d and isinstance(d["int"], int):
                return d["int"]
    except Exception:
        pass
    return default_val


def get_hypr_state():
    return {
        "blur": int(get_hypr_option("decoration:blur:size", 5)),
        "gaps": int(get_hypr_option("general:gaps_out", 6)),
        "active_opacity": float(get_hypr_option("decoration:active_opacity", 1.0)),
        "inactive_opacity": float(get_hypr_option("decoration:inactive_opacity", 1.0)),
        "border": int(get_hypr_option("general:border_size", 1)),
        "shadow": bool(get_hypr_option("decoration:shadow:enabled", 1)),
    }


def get_hypr_monitors():
    try:
        res = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=1.5)
        if res.returncode == 0 and res.stdout.strip():
            return json.loads(res.stdout)
    except Exception:
        pass
    return []


def collect_wallpapers(include_video=True):
    dirs = [
        os.path.join(home_dir(), "Pictures", "Wallpapers"),
        os.path.join(config_dir(), "assets", "wallpapers"),
        os.path.join(home_dir(), ".local", "share", "quickshell", "carbon", "assets", "wallpapers"),
        os.path.join(home_dir(), ".local", "share", "wallpapers"),
    ]
    exts = {".jpg", ".jpeg", ".png", ".webp", ".avif"}
    if include_video:
        exts |= {".mp4", ".mkv", ".webm"}

    seen = set()
    results = []
    for base in dirs:
        if not os.path.isdir(base):
            continue
        for root_d, _, files in os.walk(base):
            for f in sorted(files):
                ext = os.path.splitext(f)[1].lower()
                if ext in exts:
                    full = os.path.join(root_d, f)
                    if full not in seen:
                        seen.add(full)
                        results.append(full)
    return results


def list_local_wallpapers():
    thumb_dir = os.path.join(home_dir(), ".cache", "carbon", "thumbs")
    out = []
    for path in collect_wallpapers(include_video=True):
        fname = os.path.basename(path)
        thumb_path = os.path.join(thumb_dir, f"{fname}.jpg")
        thumb_url = f"file://{thumb_path}" if os.path.isfile(thumb_path) else f"file://{path}"
        out.append({
            "id": fname,
            "path": path,
            "thumb": thumb_url,
            "filename": fname,
        })
    return out


def apply_wallpaper(path):
    cfg = config_dir()
    os.makedirs(cfg, exist_ok=True)
    for target in [os.path.join(cfg, "current_wallpaper_path"), os.path.join(home_dir(), ".config", "hypr", "current_wallpaper_path")]:
        try:
            os.makedirs(os.path.dirname(target), exist_ok=True)
            with open(target, "w", encoding="utf-8") as f:
                f.write(path)
        except Exception:
            pass

    wp_apply = os.path.join(cfg, "scripts", "wp-apply.sh")
    wallhaven_py = os.path.join(cfg, "scripts", "wallhaven.py")
    if os.path.isfile(wp_apply):
        subprocess.Popen(["bash", wp_apply, path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif os.path.isfile(wallhaven_py):
        subprocess.Popen(["python3", wallhaven_py, "apply", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def run_matugen(scheme, wall_path=None):
    cfg = config_dir()
    os.makedirs(cfg, exist_ok=True)
    try:
        with open(os.path.join(cfg, "scheme_state"), "w", encoding="utf-8") as f:
            f.write(f"{scheme}\n")
    except Exception:
        pass

    wp = wall_path or ""
    if not wp:
        try:
            with open(os.path.join(cfg, "current_wallpaper_path"), "r", encoding="utf-8") as f:
                wp = f.read().strip()
        except Exception:
            wp = ""

    theme_mk = os.path.join(cfg, "scripts", "theme-mk.py")
    if os.path.isfile(theme_mk):
        cmd = ["python3", theme_mk]
        if wp:
            cmd.append(wp)
        cmd.extend(["--scheme", scheme])
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def set_shell_scale(scale):
    cfg = config_dir()
    for p in [os.path.join(cfg, "carbon-bar-position.json"), os.path.join(home_dir(), ".config", "hypr", "carbon-bar-position.json")]:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        d = {}
        if os.path.isfile(p):
            try:
                d = json.load(open(p, "r", encoding="utf-8"))
            except Exception:
                d = {}
        d["scale"] = float(scale)
        try:
            with open(p, "w", encoding="utf-8") as f:
                json.dump(d, f, indent=2)
        except Exception:
            pass


def get_shell_scale():
    p = os.path.join(config_dir(), "carbon-bar-position.json")
    if os.path.isfile(p):
        try:
            d = json.load(open(p, "r", encoding="utf-8"))
            return float(d.get("scale", 1.0))
        except Exception:
            pass
    return 1.0


def handle_request(req):
    t0 = time.monotonic()
    action = req.get("action", "")
    val = req.get("value")

    try:
        if action == "get_state":
            cfg = config_dir()
            wp = ""
            for p in [os.path.join(cfg, "current_wallpaper_path"), os.path.join(home_dir(), ".config", "hypr", "current_wallpaper_path")]:
                if os.path.isfile(p):
                    try:
                        wp = open(p, "r", encoding="utf-8").read().strip()
                        if wp:
                            break
                    except Exception:
                        pass
            data = {
                "hypr": get_hypr_state(),
                "current_wallpaper": wp,
                "wallpapers": list_local_wallpapers(),
            }
        elif action == "set_blur":
            if isinstance(val, bool):
                hypr_cmd(["keyword", "decoration:blur:enabled", "true" if val else "false"])
                data = {"blur": val}
            else:
                v = max(0, int(float(val if val is not None else 5)))
                if v == 0:
                    hypr_cmd(["keyword", "decoration:blur:enabled", "false"])
                else:
                    hypr_cmd(["keyword", "decoration:blur:enabled", "true"])
                    hypr_cmd(["keyword", "decoration:blur:size", str(v)])
                data = {"blur": v}
        elif action == "set_gaps":
            v = max(0, int(float(val if val is not None else 6)))
            gaps_in = max(2, v // 2)
            hypr_cmd(["keyword", "general:gaps_out", str(v)])
            hypr_cmd(["keyword", "general:gaps_in", str(gaps_in)])
            data = {"gaps": v}
        elif action in ("set_active_opacity", "set_opacity"):
            v = float(val if val is not None else 1.0)
            hypr_cmd(["keyword", "decoration:active_opacity", f"{v:.2f}"])
            data = {"active_opacity": v}
        elif action == "set_inactive_opacity":
            v = float(val if val is not None else 1.0)
            hypr_cmd(["keyword", "decoration:inactive_opacity", f"{v:.2f}"])
            data = {"inactive_opacity": v}
        elif action == "set_border":
            v = int(float(val if val is not None else 1))
            hypr_cmd(["keyword", "general:border_size", str(v)])
            data = {"border": v}
        elif action == "set_shadow":
            v = bool(val) if val is not None else True
            hypr_cmd(["keyword", "decoration:shadow:enabled", "true" if v else "false"])
            data = {"shadow": v}
        elif action == "set_ambient_glow":
            v = bool(val)
            cfg = config_dir()
            os.makedirs(cfg, exist_ok=True)
            with open(os.path.join(cfg, "ambient_glow_state"), "w", encoding="utf-8") as f:
                f.write("1\n" if v else "0\n")
            ab = os.path.join(cfg, "scripts", "audio-border.py")
            if v and os.path.isfile(ab):
                subprocess.Popen(["python3", ab], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            elif not v:
                subprocess.Popen(["pkill", "-f", "audio-border.py"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            data = {"ambient_glow": v}
        elif action == "set_m3_transitions":
            v = bool(val) if val is not None else True
            cfg = config_dir()
            os.makedirs(cfg, exist_ok=True)
            with open(os.path.join(cfg, "m3_transitions_state"), "w", encoding="utf-8") as f:
                f.write("1\n" if v else "0\n")
            data = {"m3_transitions": v}
        elif action == "pause_live_bg":
            pause = bool(val)
            sig = "-STOP" if pause else "-CONT"
            subprocess.Popen(["pkill", sig, "-f", "mpvpaper|swww"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            data = {"paused": pause}
        elif action in ("set_wallpaper", "apply_wallpaper"):
            path = req.get("path") or req.get("wallpaper") or (str(val) if val else "")
            if path:
                apply_wallpaper(path)
            data = {"path": path}
        elif action == "shuffle_wallpaper":
            cands = collect_wallpapers(include_video=False)
            chosen = random.choice(cands) if cands else ""
            if chosen:
                apply_wallpaper(chosen)
            data = {"path": chosen}
        elif action == "set_scheme":
            scheme = req.get("scheme") or (str(val) if val else "Tonal Spot")
            run_matugen(scheme, req.get("path") or req.get("wallpaper"))
            data = {"scheme": scheme}
        elif action == "list_wallpapers":
            data = list_local_wallpapers()
        elif action == "get_monitors":
            data = get_hypr_monitors()
        elif action in ("set_resolution", "set_orientation", "set_scale", "set_refresh_rate", "set_position"):
            monitors = get_hypr_monitors()
            mon_name = req.get("monitor") or (monitors[0].get("name") if monitors else "eDP-1")
            cur = next((m for m in monitors if m.get("name") == mon_name), monitors[0] if monitors else {})
            w = int(req.get("w") or req.get("width") or cur.get("width") or 1920)
            h = int(req.get("h") or req.get("height") or cur.get("height") or 1080)
            r = int(round(float(req.get("rate") or cur.get("refreshRate") or 60)))
            x = int(req.get("x") if req.get("x") is not None else (cur.get("x") or 0))
            y = int(req.get("y") if req.get("y") is not None else (cur.get("y") or 0))
            s = float(req.get("scale") or (val if action == "set_scale" and val is not None else (cur.get("scale") or 1.0)))
            t = int(req.get("transform") if req.get("transform") is not None else (val if action == "set_orientation" and val is not None else (cur.get("transform") or 0)))
            hypr_cmd(["keyword", "monitor", f"{mon_name},{w}x{h}@{r},{x}x{y},{s:.2f},transform,{t}"])
            data = {"monitor": mon_name, "w": w, "h": h, "rate": r, "scale": s, "transform": t}
        elif action == "set_shell_scale":
            s = float(req.get("scale") or val or 1.0)
            set_shell_scale(s)
            data = {"scale": s}
        elif action == "get_shell_scale":
            data = {"scale": get_shell_scale()}
        elif action == "set_vrr":
            state = int(req.get("state") if req.get("state") is not None else (val or 0))
            hypr_cmd(["keyword", "misc:vrr", str(state)])
            data = {"state": state}
        elif action == "set_temperature":
            temp = int(req.get("temp") or val or 6500)
            if temp >= 6500:
                for p in ["hyprsunset", "wlsunset", "gammastep"]:
                    subprocess.Popen(["pkill", "-x", p], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            else:
                subprocess.run(["pkill", "-x", "hyprsunset"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                try:
                    subprocess.Popen(["hyprsunset", "-t", str(temp)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                except Exception:
                    subprocess.run(["pkill", "-x", "wlsunset"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    try:
                        subprocess.Popen(["wlsunset", "-T", str(temp + 100), "-t", str(temp)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    except Exception:
                        pass
            data = {"temp": temp}
        elif action == "set_display_feature":
            feat = req.get("feature", "")
            state = bool(val)
            if feat == "direct_scanout":
                hypr_cmd(["keyword", "render:direct_scanout", "1" if state else "0"])
            elif feat == "10bit":
                monitors = get_hypr_monitors()
                if monitors:
                    m = monitors[0]
                    name = m.get("name", "eDP-1")
                    w, h = m.get("width", 1920), m.get("height", 1080)
                    r = int(round(float(m.get("refreshRate", 60))))
                    x, y = m.get("x", 0), m.get("y", 0)
                    s = float(m.get("scale", 1.0))
                    suffix = ",bitdepth,10" if state else ""
                    hypr_cmd(["keyword", "monitor", f"{name},{w}x{h}@{r},{x}x{y},{s:.2f}{suffix}"])
            elif feat == "mirror":
                monitors = get_hypr_monitors()
                if len(monitors) >= 2:
                    primary = monitors[0].get("name", "eDP-1")
                    for m in monitors[1:]:
                        sec = m.get("name")
                        if sec:
                            suffix = f",mirror,{primary}" if state else ""
                            hypr_cmd(["keyword", "monitor", f"{sec},preferred,auto,1{suffix}"])
            data = {"feature": feat, "state": state}
        else:
            return {
                "status": "error",
                "action": action,
                "error": f"Unknown action: {action}",
                "elapsed_us": int((time.monotonic() - t0) * 1_000_000),
            }

        return {
            "status": "ok",
            "action": action,
            "data": data,
            "elapsed_us": int((time.monotonic() - t0) * 1_000_000),
        }
    except Exception as e:
        return {
            "status": "error",
            "action": action,
            "error": str(e),
            "elapsed_us": int((time.monotonic() - t0) * 1_000_000),
        }


async def handle_client(reader, writer):
    try:
        while True:
            line = await reader.readline()
            if not line:
                break
            txt = line.decode("utf-8", errors="ignore").strip()
            if not txt:
                continue
            try:
                req = json.loads(txt)
                resp = handle_request(req)
            except Exception as e:
                resp = {"status": "error", "error": f"Invalid JSON: {e}"}
            writer.write((json.dumps(resp) + "\n").encode("utf-8"))
            await writer.drain()
    except Exception:
        pass
    finally:
        try:
            writer.close()
        except Exception:
            pass


async def main():
    if os.path.exists(SOCKET_PATH):
        try:
            os.unlink(SOCKET_PATH)
        except Exception:
            pass
    server = await asyncio.start_unix_server(handle_client, path=SOCKET_PATH)
    try:
        os.chmod(SOCKET_PATH, 0o666)
    except Exception:
        pass
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
