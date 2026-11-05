#!/usr/bin/env python3
"""
carbon-tray-apps.py
Collects all active background applications and running desktop apps
for the Carbon Shell Windows-style system tray popup.
Includes detailed contextual actions for each application based on
its functionality and features, plus a compulsory quit/close option.
"""

import os
import sys
import json
import glob
import subprocess
import shutil

def build_desktop_map():
    d_map = {}
    search_dirs = [
        "/usr/share/applications",
        os.path.expanduser("~/.local/share/applications"),
        "/var/lib/flatpak/exports/share/applications",
        os.path.expanduser("~/.local/share/flatpak/exports/share/applications")
    ]
    for d in search_dirs:
        if not os.path.isdir(d):
            continue
        for f in glob.glob(os.path.join(d, "*.desktop")):
            try:
                base = os.path.splitext(os.path.basename(f))[0].lower()
                name, icon, exec_cmd, categories, x_flatpak = "", "", "", "", ""
                with open(f, "r", errors="ignore") as fp:
                    for line in fp:
                        line_s = line.strip()
                        if line_s.startswith("Name=") and not name:
                            name = line_s.split("=", 1)[1]
                        elif line_s.startswith("Icon=") and not icon:
                            icon = line_s.split("=", 1)[1]
                        elif line_s.startswith("Exec=") and not exec_cmd:
                            exec_cmd = line_s.split("=", 1)[1]
                        elif line_s.startswith("Categories=") and not categories:
                            categories = line_s.split("=", 1)[1]
                        elif line_s.startswith("X-Flatpak=") and not x_flatpak:
                            x_flatpak = line_s.split("=", 1)[1]

                entry = {
                    "name": name,
                    "icon": icon,
                    "exec": exec_cmd,
                    "categories": categories,
                    "x_flatpak": x_flatpak
                }
                d_map[base] = entry
                if x_flatpak:
                    d_map[x_flatpak.lower()] = entry
                if exec_cmd:
                    exe = os.path.basename(exec_cmd.split()[0]).lower()
                    if exe not in d_map:
                        d_map[exe] = entry
            except Exception:
                pass
    return d_map

def resolve_icon_path(icon_name):
    if not icon_name:
        return ""
    if os.path.isabs(icon_name) and os.path.exists(icon_name):
        return f"file://{icon_name}"

    local_icons = os.path.expanduser("~/.local/share/icons")
    kitty_icons = os.path.expanduser("~/.local/opt/kitty/share/icons")
    candidates = [
        f"/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps/{icon_name}.png",
        f"/var/lib/flatpak/exports/share/icons/hicolor/64x64/apps/{icon_name}.png",
        f"/var/lib/flatpak/exports/share/icons/hicolor/scalable/apps/{icon_name}.svg",
        os.path.expanduser(f"~/.local/share/flatpak/exports/share/icons/hicolor/128x128/apps/{icon_name}.png"),
        f"{local_icons}/hicolor/scalable/apps/{icon_name}.svg",
        f"{local_icons}/hicolor/256x256/apps/{icon_name}.png",
        f"{local_icons}/hicolor/128x128/apps/{icon_name}.png",
        f"{kitty_icons}/hicolor/scalable/apps/{icon_name}.svg",
        f"{kitty_icons}/hicolor/256x256/apps/{icon_name}.png",
        f"/usr/share/icons/Papirus/64x64@2x/apps/{icon_name}.svg",
        f"/usr/share/icons/Papirus/64x64/apps/{icon_name}.svg",
        f"/usr/share/icons/Papirus/64x64@2x/categories/{icon_name}.svg",
        f"/usr/share/icons/hicolor/scalable/apps/{icon_name}.svg",
        f"/usr/share/icons/hicolor/512x512/apps/{icon_name}.png",
        f"/usr/share/icons/hicolor/256x256/apps/{icon_name}.png",
        f"/usr/share/icons/hicolor/128x128/apps/{icon_name}.png",
        f"/usr/share/icons/hicolor/64x64/apps/{icon_name}.png",
        f"/usr/share/icons/hicolor/48x48/apps/{icon_name}.png",
        f"/usr/share/icons/breeze/apps/64/{icon_name}.svg",
        f"/usr/share/icons/breeze/apps/48/{icon_name}.svg",
        f"/usr/share/icons/breeze/devices/64/{icon_name}.svg",
        f"/usr/share/icons/breeze/devices/22/{icon_name}.svg",
        f"/usr/share/icons/breeze/preferences/22/{icon_name}.svg",
        f"/usr/share/pixmaps/{icon_name}.svg",
        f"/usr/share/pixmaps/{icon_name}.png",
    ]
    for c in candidates:
        if os.path.exists(c):
            return f"file://{c}"

    flatpak_match = glob.glob(f"/var/lib/flatpak/exports/share/icons/**/{icon_name}.*", recursive=True)
    if flatpak_match and os.path.exists(flatpak_match[0]):
        return f"file://{flatpak_match[0]}"

    user_match = glob.glob(os.path.expanduser(f"~/.local/share/icons/**/{icon_name}.*"), recursive=True)
    if user_match and os.path.exists(user_match[0]):
        return f"file://{user_match[0]}"

    p_match = glob.glob(f"/usr/share/icons/Papirus/**/{icon_name}.*", recursive=True)
    if p_match and os.path.exists(p_match[0]):
        return f"file://{p_match[0]}"

    h_match = glob.glob(f"/usr/share/icons/hicolor/**/{icon_name}.*", recursive=True)
    if h_match and os.path.exists(h_match[0]):
        return f"file://{h_match[0]}"

    all_match = glob.glob(f"/usr/share/icons/**/{icon_name}.*", recursive=True)
    if all_match and os.path.exists(all_match[0]):
        return f"file://{all_match[0]}"

    return ""

def categorize_app(cls_lower, name_lower, categories):
    haystack = f"{cls_lower} {name_lower} {categories.lower()}"
    if any(k in haystack for k in ["gpu-screen-recorder", "screen_recorder", "recorder", "obs", "wf-recorder"]):
        return "recorder"
    if any(k in haystack for k in ["serein", "viceverse"]):
        return "chat"
    if any(k in haystack for k in ["spotify", "mixtapes", "muse", "cider", "vlc", "mpv", "audacious", "music", "audio"]):
        if "easyeffects" in haystack:
            return "audio"
        return "media"
    if any(k in haystack for k in ["easyeffects", "pulseaudio", "pipewire"]):
        return "audio"
    if any(k in haystack for k in ["zen", "firefox", "chrome", "chromium", "brave", "librewolf", "webbrowser"]):
        return "browser"
    if any(k in haystack for k in ["kitty", "alacritty", "foot", "wezterm", "ghostty", "terminal"]):
        return "terminal"
    if any(k in haystack for k in ["discord", "vesktop", "webcord", "slack", "telegram", "element", "chat", "messaging"]):
        return "chat"
    if any(k in haystack for k in ["steam", "lutris", "heroic", "prism", "game"]):
        return "game"
    return "general"

def get_app_actions(app, category):
    has_window = app.get("hasWindow", False)
    cls = (app.get("class") or "").lower()
    name = (app.get("name") or "").lower()
    exec_cmd = app.get("exec") or ""
    pid = app.get("pid")
    actions = []

    if category == "recorder":
        actions.append({"id": "save_replay", "label": "Save Replay (Shadowplay)", "icon": "save", "cmd": "pkill -SIGUSR1 -f gpu-screen-recorder"})
        replays_dir = os.path.expanduser("~/videos/replay")
        recordings_dir = os.path.expanduser("~/videos/recorded")
        actions.append({"id": "open_replays", "label": "Open Replays Folder", "icon": "folder", "cmd": f"xdg-open {replays_dir} 2>/dev/null || xdg-open ~/Videos &"})
        actions.append({"id": "open_recordings", "label": "Open Recordings Folder", "icon": "video_library", "cmd": f"xdg-open {recordings_dir} 2>/dev/null || xdg-open ~/Videos &"})
        actions.append({"id": "open_gui", "label": "Recorder Settings", "icon": "settings", "cmd": "flatpak run com.dec05eba.gpu_screen_recorder 2>/dev/null || gpu-screen-recorder-gtk &"})
        actions.append({"id": "stop_recording", "label": "Stop Recording", "icon": "stop_circle", "cmd": "pkill -SIGINT -f gpu-screen-recorder"})
        actions.append({"id": "quit", "label": "Quit GPU Screen Recorder", "icon": "close", "danger": True, "action": "close", "cmd": "pkill -f gpu-screen-recorder; flatpak kill com.dec05eba.gpu_screen_recorder 2>/dev/null"})

    elif category == "media":
        actions.append({"id": "play_pause", "label": "Play / Pause", "icon": "play_arrow", "cmd": "playerctl play-pause"})
        actions.append({"id": "next", "label": "Next Track", "icon": "skip_next", "cmd": "playerctl next"})
        actions.append({"id": "prev", "label": "Previous Track", "icon": "skip_previous", "cmd": "playerctl previous"})
        if has_window:
            actions.append({"id": "focus", "label": "Focus Window", "icon": "visibility", "action": "focus"})
            actions.append({"id": "workspace", "label": "Move to Current Workspace", "icon": "move_to_inbox", "action": "movetoworkspace"})
        actions.append({"id": "quit", "label": "Close Application", "icon": "close", "danger": True, "action": "close", "cmd": f"kill {pid}" if pid else ""})

    elif category == "audio":
        actions.append({"id": "open_gui", "label": "Open Equalizer / GUI", "icon": "graphic_eq", "cmd": "easyeffects &"})
        actions.append({"id": "bypass", "label": "Bypass Effects", "icon": "power_settings_new", "cmd": "easyeffects -b 3"})
        actions.append({"id": "quit", "label": "Quit EasyEffects", "icon": "close", "danger": True, "action": "close", "cmd": "easyeffects -q || pkill -x easyeffects"})

    elif category == "browser":
        actions.append({"id": "new_window", "label": "New Window", "icon": "open_in_new", "cmd": exec_cmd or (app.get("class", "") + " &")})
        priv_arg = "--private-window" if ("firefox" in cls or "zen" in cls) else "--incognito"
        actions.append({"id": "new_private", "label": "New Private Window", "icon": "visibility_off", "cmd": (exec_cmd + f" {priv_arg}" if exec_cmd else app.get("class", "") + f" {priv_arg} &")})
        if has_window:
            actions.append({"id": "focus", "label": "Focus Window", "icon": "visibility", "action": "focus"})
        actions.append({"id": "quit", "label": "Close Browser", "icon": "close", "danger": True, "action": "close", "cmd": f"kill {pid}" if pid else ""})

    elif category == "terminal":
        actions.append({"id": "new_terminal", "label": "New Terminal Window", "icon": "terminal", "cmd": app.get("class", "kitty") + " &"})
        if has_window:
            actions.append({"id": "focus", "label": "Focus Window", "icon": "visibility", "action": "focus"})
            actions.append({"id": "float", "label": "Toggle Floating", "icon": "crop_portrait", "action": "togglefloating"})
        actions.append({"id": "quit", "label": "Close Terminal", "icon": "close", "danger": True, "action": "close", "cmd": f"kill {pid}" if pid else ""})

    elif category == "chat":
        actions.append({"id": "open_chat", "label": "Open Window", "icon": "chat", "cmd": exec_cmd or (app.get("class", "") + " &")})
        if has_window:
            actions.append({"id": "focus", "label": "Focus Window", "icon": "visibility", "action": "focus"})
            actions.append({"id": "workspace", "label": "Move to Current Workspace", "icon": "move_to_inbox", "action": "movetoworkspace"})
        actions.append({"id": "quit", "label": "Quit Chat", "icon": "close", "danger": True, "action": "close", "cmd": f"kill {pid}" if pid else ""})

    elif category == "game":
        actions.append({"id": "open_game", "label": "Open Library", "icon": "sports_esports", "cmd": exec_cmd or "steam"})
        if has_window:
            actions.append({"id": "focus", "label": "Focus Window", "icon": "visibility", "action": "focus"})
        actions.append({"id": "quit", "label": "Exit Application", "icon": "close", "danger": True, "action": "close", "cmd": "steam -shutdown" if "steam" in cls else (f"kill {pid}" if pid else "")})

    else:
        if has_window:
            actions.append({"id": "focus", "label": "Focus Window", "icon": "visibility", "action": "focus"})
            actions.append({"id": "float", "label": "Toggle Floating", "icon": "crop_portrait", "action": "togglefloating"})
            actions.append({"id": "workspace", "label": "Move to Current Workspace", "icon": "move_to_inbox", "action": "movetoworkspace"})
        if exec_cmd:
            actions.append({"id": "launch", "label": "Launch New Instance", "icon": "open_in_new", "cmd": exec_cmd})
        actions.append({"id": "quit", "label": "Close Application", "icon": "close", "danger": True, "action": "close", "cmd": f"kill {pid}" if pid else ""})

    return actions

def main():
    desktop_map = build_desktop_map()
    apps = []
    seen_classes = set()
    seen_pids = set()

    # 1. Fetch Hyprland active client windows
    try:
        clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], timeout=1.5))
        for c in clients:
            cls = (c.get("class") or "").strip()
            if not cls:
                continue
            cls_lower = cls.lower()
            if cls_lower in seen_classes:
                continue
            seen_classes.add(cls_lower)
            pid = c.get("pid")
            if pid:
                seen_pids.add(pid)

            meta = desktop_map.get(cls_lower)
            if not meta:
                for k, v in desktop_map.items():
                    if k in cls_lower or cls_lower in k:
                        meta = v
                        break

            name = (meta.get("name") if meta else "") or c.get("initialTitle") or cls.capitalize()
            icon_key = (meta.get("icon") if meta else "") or cls_lower
            icon_url = resolve_icon_path(icon_key)
            cat = categorize_app(cls_lower, name.lower(), meta.get("categories", "") if meta else "")

            app_obj = {
                "id": f"{cls_lower}-{pid}",
                "name": name,
                "title": c.get("title") or name,
                "class": cls,
                "category": cat,
                "icon": icon_key,
                "iconPath": icon_url,
                "pid": pid,
                "address": c.get("address", ""),
                "workspace": c.get("workspace", {}).get("id", 1),
                "hasWindow": True,
                "type": "window",
                "exec": meta.get("exec", "") if meta else ""
            }
            app_obj["actions"] = get_app_actions(app_obj, cat)
            apps.append(app_obj)
    except Exception:
        pass

    # 2. Check Background GUI processes (minimized to tray or background services)
    try:
        user = os.environ.get("USER") or os.path.basename(os.path.expanduser("~"))
        ps_out = subprocess.check_output(["ps", "-u", user, "-o", "pid,comm,args"], timeout=1.5).decode()
        discord_path = shutil.which("discord") or os.path.expanduser("~/.local/bin/discord") or "discord"
        known_bg_patterns = [
            ("gpu-screen-recorder", "GPU Screen Recorder", "com.dec05eba.gpu_screen_recorder", "flatpak run com.dec05eba.gpu_screen_recorder", "recorder"),
            ("com.dec05eba.gpu_screen_recorder", "GPU Screen Recorder", "com.dec05eba.gpu_screen_recorder", "flatpak run com.dec05eba.gpu_screen_recorder", "recorder"),
            ("easyeffects", "EasyEffects", "com.github.wwmm.easyeffects", "easyeffects", "audio"),
            ("discord", "Discord", "discord", discord_path, "chat"),
            ("vesktop", "Vesktop", "vesktop", "vesktop", "chat"),
            ("spotify", "Spotify", "spotify", "spotify", "media"),
            ("mixtape", "Mixtape", "mixtape", "mixtape", "media"),
            ("antigravity", "Antigravity", "antigravity", "antigravity", "general"),
            ("steam", "Steam", "steam", "steam", "game"),
            ("telegram", "Telegram", "telegram", "telegram-desktop", "chat"),
            ("slack", "Slack", "slack", "slack", "chat"),
            ("obs", "OBS Studio", "obs", "obs", "recorder")
        ]
        for line in ps_out.splitlines():
            parts = line.strip().split(None, 2)
            if len(parts) < 3:
                continue
            p_pid, comm, args = parts[0], parts[1], parts[2]
            try:
                p_pid_int = int(p_pid)
            except ValueError:
                continue
            if p_pid_int in seen_pids:
                continue

            c_low = comm.lower()
            a_low = args.lower()

            for key, default_name, default_icon, default_exec, default_cat in known_bg_patterns:
                if key in c_low or key in a_low:
                    if key in seen_classes or default_name.lower() in seen_classes:
                        break
                    seen_classes.add(key)
                    seen_classes.add(default_name.lower())
                    seen_pids.add(p_pid_int)

                    meta = desktop_map.get(key) or desktop_map.get(default_icon) or {}
                    icon_key = meta.get("icon") or default_icon
                    icon_url = resolve_icon_path(icon_key)
                    name = meta.get("name") or default_name
                    cat = default_cat

                    app_obj = {
                        "id": f"{key}-{p_pid_int}",
                        "name": name,
                        "title": name,
                        "class": meta.get("x_flatpak") or key,
                        "category": cat,
                        "icon": icon_key,
                        "iconPath": icon_url,
                        "pid": p_pid_int,
                        "address": "",
                        "workspace": -1,
                        "hasWindow": False,
                        "type": "background",
                        "exec": meta.get("exec") or default_exec
                    }
                    app_obj["actions"] = get_app_actions(app_obj, cat)
                    apps.append(app_obj)
                    break
    except Exception:
        pass

    print(json.dumps(apps))

if __name__ == "__main__":
    main()
