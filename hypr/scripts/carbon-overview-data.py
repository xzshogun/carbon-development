#!/usr/bin/env python3
import json
import subprocess
import sys

def get_overview_data():
    try:
        clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], text=True))
    except Exception:
        clients = []

    try:
        workspaces = json.loads(subprocess.check_output(["hyprctl", "workspaces", "-j"], text=True))
    except Exception:
        workspaces = []

    try:
        active = json.loads(subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True))
        active_id = active.get("id", 1)
    except Exception:
        active_id = 1

    standard_ids = {1, 2, 3, active_id}
    for ws in workspaces:
        ws_id = ws.get("id")
        if ws_id and ws_id > 0:
            standard_ids.add(ws_id)

    ws_dict = {}
    for wid in sorted(standard_ids):
        ws_dict[wid] = {
            "id": wid,
            "name": f"Workspace {wid}",
            "isActive": (wid == active_id),
            "windows": []
        }

    for c in clients:
        ws_info = c.get("workspace", {})
        wid = ws_info.get("id")
        if not wid or wid <= 0:
            continue
        if wid not in ws_dict:
            ws_dict[wid] = {
                "id": wid,
                "name": f"Workspace {wid}",
                "isActive": (wid == active_id),
                "windows": []
            }
        
        cls = c.get("class", "")
        init_cls = c.get("initialClass", "")
        title = c.get("title", "")
        init_title = c.get("initialTitle", "")
        addr = c.get("address", "")
        
        app_name = init_cls or cls or "Application"
        if app_name.lower() == "zen": app_name = "Zen Browser"
        elif app_name.lower() == "discord": app_name = "Discord"
        elif app_name.lower() == "antigravity": app_name = "Antigravity"
        elif app_name.lower() == "foot": app_name = "Terminal"
        elif app_name.lower() == "kitty": app_name = "Kitty"
        elif app_name.lower() == "thunar": app_name = "Files"
        elif app_name.lower() == "firefox": app_name = "Firefox"
        else:
            app_name = app_name.capitalize()

        icon_name = cls.lower()
        if icon_name == "zen": icon_name = "zen-browser"

        ws_dict[wid]["windows"].append({
            "address": addr,
            "class": cls,
            "appName": app_name,
            "title": title or init_title or app_name,
            "icon": icon_name,
            "floating": bool(c.get("floating", False)),
            "fullscreen": bool(c.get("fullscreen", 0) > 0),
            "pid": c.get("pid", 0)
        })

    result = [ws_dict[k] for k in sorted(ws_dict.keys())]
    return {"activeWorkspace": active_id, "workspaces": result}

if __name__ == "__main__":
    print(json.dumps(get_overview_data()))
