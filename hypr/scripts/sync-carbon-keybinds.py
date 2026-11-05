#!/usr/bin/env python3
"""
Sync Carbon Keybinds:
Translates standard Hyprland format keybinds in ~/.config/hypr/carbon/keybinds.conf
into Hyprland Lua API bindings in ~/.config/hypr/carbon/keybinds.lua.
"""

import os
import re
import subprocess
import sys

CONF_PATH = os.path.expanduser("~/.config/hypr/carbon/keybinds.conf")
LUA_PATH = os.path.expanduser("~/.config/hypr/carbon/keybinds.lua")

def parse_mods(mods_str):
    mods_str = mods_str.strip()
    if not mods_str:
        return ""
    parts = re.split(r"[+\s]+", mods_str)
    lua_parts = []
    for p in parts:
        p = p.strip()
        if not p:
            continue
        if p.startswith("$"):
            lua_parts.append(p[1:])
        else:
            lua_parts.append(f'"{p}"')
    return " .. \" + \" .. ".join(lua_parts)

def build_bind_call(bind_type, mods_expr, key, action, args, var_map=None):
    opts = []
    if bind_type in ("binde", "bindel"):
        opts.append("repeating = true")
    if bind_type in ("bindl", "bindel"):
        opts.append("locked = true")
    if bind_type == "bindm":
        opts.append("mouse = true")

    if mods_expr:
        lhs = f'{mods_expr} .. " + {key}"'
    else:
        lhs = f'"{key}"'

    action_lower = action.lower().strip()
    args_stripped = args.strip().rstrip(",")
    if var_map:
        for vk, vv in var_map.items():
            args_stripped = re.sub(rf'\${vk}\b', vv, args_stripped)

    if action_lower == "exec":
        rhs = f'hl.dsp.exec_cmd("{args_stripped}")'
    elif action_lower == "killactive":
        rhs = "hl.dsp.window.close()"
    elif action_lower == "togglefloating":
        rhs = 'hl.dsp.window.float({ action = "toggle" })'
    elif action_lower == "fullscreen":
        rhs = "hl.dsp.window.fullscreen()"
    elif action_lower == "workspace":
        if args_stripped.startswith("e+") or args_stripped.startswith("e-"):
            rhs = f'hl.dsp.focus({{ workspace = "{args_stripped}" }})'
        elif args_stripped.isdigit():
            rhs = f'hl.dsp.focus({{ workspace = {args_stripped} }})'
        else:
            rhs = f'hl.dsp.focus({{ workspace = "{args_stripped}" }})'
    elif action_lower == "movetoworkspace":
        if args_stripped.isdigit():
            rhs = f'hl.dsp.window.move({{ workspace = {args_stripped} }})'
        else:
            rhs = f'hl.dsp.window.move({{ workspace = "{args_stripped}" }})'
    elif action_lower == "movefocus":
        rhs = f'hl.dsp.exec_cmd("hyprctl dispatch movefocus {args_stripped}")'
    elif action_lower == "movewindow":
        if bind_type == "bindm":
            rhs = "hl.dsp.window.drag()"
        else:
            rhs = f'hl.dsp.window.move({{ direction = "{args_stripped}" }})'
    elif action_lower == "resizewindow":
        rhs = "hl.dsp.window.resize()"
    elif action_lower == "resizeactive":
        rhs = f'hl.dsp.exec_cmd("hyprctl dispatch resizeactive {args_stripped}")'
    else:
        rhs = f'hl.dsp.exec_cmd("hyprctl dispatch {action_lower} {args_stripped}")'

    if opts:
        return f"hl.bind({lhs}, {rhs}, {{ {', '.join(opts)} }})"
    return f"hl.bind({lhs}, {rhs})"

def sync():
    if not os.path.isfile(CONF_PATH):
        print(f"File not found: {CONF_PATH}", file=sys.stderr)
        return False

    with open(CONF_PATH, "r", encoding="utf-8") as f:
        conf_lines = f.readlines()

    lua_lines = [
        "-- Auto-synchronized from ~/.config/hypr/carbon/keybinds.conf\n",
        'local mainMod = "SUPER"\n',
        'local terminal = "kitty"\n',
        'local fileManager = "nautilus"\n\n'
    ]

    var_map = {
        "mainMod": "SUPER",
        "terminal": "kitty",
        "fileManager": "nautilus",
        "menu": "rofi -show run"
    }

    for raw_line in conf_lines:
        line = raw_line.strip()
        if not line:
            lua_lines.append("\n")
            continue
        if line.startswith("#"):
            lua_lines.append(f"-- {line.lstrip('#').strip()}\n")
            continue
        if line.startswith("$"):
            # Variable definition
            m = re.match(r"^\$([a-zA-Z0-9_]+)\s*=\s*(.*)$", line)
            if m:
                k, v = m.group(1), m.group(2).strip()
                var_map[k] = v
                lua_lines.append(f'local {k} = "{v}"\n')
            continue

        m = re.match(r"^(bind[a-z]*)\s*=\s*([^,]*),\s*([^,]+),\s*([^,]+)(?:,\s*(.*))?$", line)
        if m:
            btype = m.group(1)
            mods_str = m.group(2).strip()
            key = m.group(3).strip()
            action = m.group(4).strip()
            args = (m.group(5) or "").strip()

            mods_expr = parse_mods(mods_str)
            try:
                call_str = build_bind_call(btype, mods_expr, key, action, args, var_map=var_map)
                lua_lines.append(f"{call_str}\n")
            except Exception as ex:
                lua_lines.append(f"-- FAILED TO PARSE: {line} ({ex})\n")
        else:
            lua_lines.append(f"-- UNRECOGNIZED: {line}\n")

    with open(LUA_PATH, "w", encoding="utf-8") as f:
        f.writelines(lua_lines)

    print(f"Successfully synced {CONF_PATH} -> {LUA_PATH}")
    return True

if __name__ == "__main__":
    success = sync()
    if success and "--reload" in sys.argv:
        subprocess.run(["hyprctl", "reload"], check=False)
