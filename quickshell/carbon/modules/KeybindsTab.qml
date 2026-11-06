import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * KeybindsTab — Per-Mode & Default Keybind Studio + Touchpad Gestures Editor
 *
 * Allows editing each isolated mode keybind file separately so modes never clash:
 *   - minimal:  ~/.config/carbon/configs/keybinds-minimal.conf
 *   - notch:    ~/.config/carbon/configs/keybinds-notch.conf
 *   - pill:     ~/.config/carbon/configs/keybinds-pill.conf
 *   - vanish:   ~/.config/carbon/configs/keybinds-vanish.conf
 *   - shell:    ~/.config/carbon/keybinds-shell-only.conf
 *   - default:  ~/.config/carbon/keybinds.conf
 *   - gestures: ~/.config/carbon/configs/gestures.conf
 */
Item {
    id: root

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("CARBON_CONFIG_DIR") || (root.homeDir + "/.config/carbon")

    property string currentScope: "minimal"
    property string currentFilePath: root.configDir + "/configs/keybinds-minimal.conf"
    property string searchQuery: ""
    property string statusMessage: "Select any mode or default profile below — each file is isolated so keybinds never clash."
    property bool statusIsError: false
    property int recordingIndex: -1

    // Touchpad & Gesture settings state (when currentScope === "gestures")
    property bool tpNaturalScroll: true
    property bool tpTapToClick: true
    property bool tpDisableWhileTyping: true
    property bool tpWorkspaceSwipe: true
    property int tpSwipeFingers: 3
    property int tpSwipeDistance: 400

    readonly property var scopeList: [
        { id: "minimal",  label: "Minimal / Tide",      badge: "MODE",    relPath: "configs/keybinds-minimal.conf",  desc: "Active only when Minimal Island / Tide mode is selected." },
        { id: "notch",    label: "Carbon Notch",        badge: "MODE",    relPath: "configs/keybinds-notch.conf",    desc: "Active only when Carbon Notch mode is selected." },
        { id: "pill",     label: "Pill Mode",           badge: "MODE",    relPath: "configs/keybinds-pill.conf",     desc: "Active only when Pill / Waybar mode is selected." },
        { id: "vanish",   label: "Vanish / Nucleus",    badge: "MODE",    relPath: "configs/keybinds-vanish.conf",   desc: "Active only when Vanish / Nucleus radial mode is selected." },
        { id: "shell",    label: "Default (Shell Base)",badge: "DEFAULT", relPath: "keybinds-shell-only.conf",       desc: "Core Carbon Shell shortcuts shared across modes (Settings Hub, Focus HUD, Fullscreen)." },
        { id: "default",  label: "Default (Full Suite)",badge: "DEFAULT", relPath: "keybinds.conf",                  desc: "Complete Hyprland default keybinds (apps, workspaces, window management, media keys)." },
        { id: "gestures", label: "Touchpad & Gestures", badge: "INPUT",   relPath: "configs/gestures.conf",          desc: "3-finger workspace scroll, touchpad natural scrolling, and directional swipe binds." }
    ]

    ListModel {
        id: bindsModel
    }

    ListModel {
        id: gesturesModel
    }

    function getScopeInfo(scopeId) {
        for (var i = 0; i < root.scopeList.length; i++) {
            if (root.scopeList[i].id === scopeId) return root.scopeList[i]
        }
        return root.scopeList[0]
    }

    function describeAction(disp, arg) {
        var d = String(disp || "").trim()
        var a = String(arg || "").trim()
        if (d === "fullscreen") return "Toggle Fullscreen Window"
        if (d === "killactive") return "Close Active Window"
        if (d === "togglefloating") return "Toggle Floating Window"
        if (d === "movefocus") return "Move Focus (" + a.toUpperCase() + ")"
        if (d === "movewindow") return "Move Window (" + a.toUpperCase() + ")"
        if (d === "resizeactive") return "Resize Active Window (" + a + ")"
        if (d === "workspace") return "Switch to Workspace " + a
        if (d === "movetoworkspace") return "Move Window to Workspace " + a
        if (a.indexOf("carbon-settings-hub") !== -1) return "Open Rust Settings Hub"
        if (a.indexOf("carbon-config-editor") !== -1) return "Open GTK Config Editor"
        if (a.indexOf("carbon-focus.sh") !== -1) return "Toggle Focus Mode / Hyper-Tunnel HUD"
        if (a.indexOf("toggle-overview") !== -1 || a.indexOf("overview toggle") !== -1) return "Toggle Workspace Overview"
        if (a.indexOf("spotlight") !== -1 || a.indexOf("toggleApplicationLauncher") !== -1) return "Open Spotlight / App Launcher"
        if (a.indexOf("wallpaper") !== -1 || a.indexOf("toggleWallpaperPicker") !== -1) return "Open Wallpaper Studio"
        if (a.indexOf("command-center") !== -1 || a.indexOf("toggleControlCenter") !== -1) return "Toggle Command / Control Center"
        if (a.indexOf("spatial-canvas") !== -1) return "Toggle 2D Spatial Canvas"
        if (a.indexOf("toggleNotificationCenter") !== -1 || a.indexOf("focus-alerts") !== -1) return "Toggle Notification Center"
        if (a.indexOf("togglePlayer") !== -1 || a.indexOf("lyrics") !== -1) return "Toggle Media Player / Synced Lyrics"
        if (a.indexOf("togglePowerMenu") !== -1 || a.indexOf("ipc.sh power") !== -1) return "Toggle Power Menu"
        if (a.indexOf("toggle-hub") !== -1) return "Toggle Vanish Radial Hub"
        if (a.indexOf("carbon-pomodoro") !== -1) return "Open Pomodoro Timer"
        if (a.indexOf("hyprlock.sh") !== -1) return "Lock Screen"
        if (a.indexOf("screenshot") !== -1) return "Capture Screenshot"
        if (a === "$terminal" || a.indexOf("kitty") !== -1) return "Launch Terminal"
        if (a === "$fileManager" || a.indexOf("nautilus") !== -1) return "Open File Manager"
        return d + (a.length > 0 ? (" → " + a) : "")
    }

    function keyEventToHyprName(event) {
        var k = event.key
        if (k === Qt.Key_Control || k === Qt.Key_Shift || k === Qt.Key_Alt || k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R) {
            return ""
        }
        var map = {}
        map[Qt.Key_Return] = "Return"
        map[Qt.Key_Enter] = "Return"
        map[Qt.Key_Tab] = "Tab"
        map[Qt.Key_Backtab] = "Tab"
        map[Qt.Key_Space] = "Space"
        map[Qt.Key_Backspace] = "Backspace"
        map[Qt.Key_Delete] = "Delete"
        map[Qt.Key_Escape] = "Escape"
        map[Qt.Key_Left] = "left"
        map[Qt.Key_Right] = "right"
        map[Qt.Key_Up] = "up"
        map[Qt.Key_Down] = "down"
        map[Qt.Key_Print] = "Print"
        map[Qt.Key_Comma] = "comma"
        map[Qt.Key_Period] = "period"
        map[Qt.Key_Slash] = "slash"
        map[Qt.Key_Backslash] = "backslash"
        map[Qt.Key_Minus] = "minus"
        map[Qt.Key_Equal] = "equal"
        map[Qt.Key_QuoteLeft] = "grave"
        for (var f = 1; f <= 12; f++) {
            map[Qt.Key_F1 + (f - 1)] = "F" + f
        }
        if (map[k] !== undefined) return map[k]
        if (event.text && event.text.length === 1) {
            var ch = event.text.toUpperCase()
            if (ch >= "A" && ch <= "Z") return ch
            if (ch >= "0" && ch <= "9") return ch
        }
        return ""
    }

    function modifiersFromKeyEvent(event) {
        var mods = []
        if (event.modifiers & Qt.MetaModifier) mods.push("$mainMod")
        if (event.modifiers & Qt.ControlModifier) mods.push("CTRL")
        if (event.modifiers & Qt.AltModifier) mods.push("ALT")
        if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT")
        if (mods.length === 0) return "$mainMod"
        return mods.join(" ")
    }

    // Loader Process to parse any selected keybind or gesture .conf file
    Process {
        id: loadProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text.trim())
                    if (parsed.filePath) root.currentFilePath = parsed.filePath
                    if (parsed.scope === "gestures") {
                        root.tpNaturalScroll = parsed.natural_scroll !== false
                        root.tpTapToClick = parsed.tap_to_click !== false
                        root.tpDisableWhileTyping = parsed.disable_while_typing !== false
                        root.tpWorkspaceSwipe = parsed.workspace_swipe !== false
                        root.tpSwipeFingers = parsed.workspace_swipe_fingers || 3
                        root.tpSwipeDistance = parsed.workspace_swipe_distance || 400
                        gesturesModel.clear()
                        var gList = parsed.gestures || []
                        for (var g = 0; g < gList.length; g++) {
                            gesturesModel.append({
                                fingers: String(gList[g].fingers || "3"),
                                direction: String(gList[g].direction || "horizontal"),
                                action: String(gList[g].action || "workspace")
                            })
                        }
                    } else {
                        bindsModel.clear()
                        var bList = parsed.binds || []
                        for (var i = 0; i < bList.length; i++) {
                            var item = bList[i]
                            bindsModel.append({
                                bindType: String(item.bindType || "bind"),
                                mods: String(item.mods !== undefined ? item.mods : "$mainMod"),
                                key: String(item.key || ""),
                                dispatcher: String(item.dispatcher || "exec"),
                                arg: String(item.arg || "")
                            })
                        }
                    }
                } catch (e) {
                    root.statusIsError = true
                    root.statusMessage = "Failed to parse keybind file: " + e
                }
            }
        }
    }

    function loadScope(scopeId) {
        root.recordingIndex = -1
        root.currentScope = scopeId
        var info = root.getScopeInfo(scopeId)
        root.currentFilePath = root.configDir + "/" + info.relPath

        var pyScript =
            "import json, os, sys\n" +
            "scope = sys.argv[1]\n" +
            "cfg_dir = os.path.expanduser(sys.argv[2])\n" +
            "rel_path = sys.argv[3]\n" +
            "full_path = os.path.join(cfg_dir, rel_path)\n" +
            "if not os.path.exists(full_path):\n" +
            "    alt = os.path.expanduser('~/.config/hypr/' + rel_path)\n" +
            "    if os.path.exists(alt): full_path = alt\n" +
            "if scope == 'gestures':\n" +
            "    res = {'scope': 'gestures', 'filePath': full_path, 'natural_scroll': True, 'tap_to_click': True, 'disable_while_typing': True, 'workspace_swipe': True, 'workspace_swipe_fingers': 3, 'workspace_swipe_distance': 400, 'gestures': []}\n" +
            "    if os.path.exists(full_path):\n" +
            "        for raw in open(full_path, 'r', encoding='utf-8', errors='ignore'):\n" +
            "            s = raw.split('#', 1)[0].strip()\n" +
            "            if not s or '=' not in s: continue\n" +
            "            k, v = [x.strip() for x in s.split('=', 1)]\n" +
            "            if k == 'natural_scroll': res['natural_scroll'] = (v.lower() == 'true')\n" +
            "            elif k in ('tap_to_click', 'tap-to-click'): res['tap_to_click'] = (v.lower() == 'true')\n" +
            "            elif k == 'disable_while_typing': res['disable_while_typing'] = (v.lower() == 'true')\n" +
            "            elif k == 'workspace_swipe': res['workspace_swipe'] = (v.lower() == 'true')\n" +
            "            elif k == 'workspace_swipe_fingers':\n" +
            "                try: res['workspace_swipe_fingers'] = int(v)\n" +
            "                except Exception: pass\n" +
            "            elif k == 'workspace_swipe_distance':\n" +
            "                try: res['workspace_swipe_distance'] = int(v)\n" +
            "                except Exception: pass\n" +
            "            elif k == 'gesture':\n" +
            "                parts = [p.strip() for p in v.split(',')]\n" +
            "                if len(parts) >= 3:\n" +
            "                    res['gestures'].append({'fingers': parts[0], 'direction': parts[1], 'action': ', '.join(parts[2:])})\n" +
            "    if not res['gestures']:\n" +
            "        res['gestures'] = [\n" +
            "            {'fingers': '3', 'direction': 'horizontal', 'action': 'workspace'},\n" +
            "            {'fingers': '3', 'direction': 'up', 'action': 'dispatcher, exec, sh ~/.config/carbon/scripts/carbon-ipc.sh toggle-overview'},\n" +
            "            {'fingers': '3', 'direction': 'down', 'action': 'dispatcher, exec, sh ~/.config/carbon/scripts/carbon-ipc.sh spatial-canvas'},\n" +
            "            {'fingers': '4', 'direction': 'up', 'action': 'dispatcher, fullscreen'}\n" +
            "        ]\n" +
            "    print(json.dumps(res))\n" +
            "else:\n" +
            "    binds = []\n" +
            "    if os.path.exists(full_path):\n" +
            "        for raw in open(full_path, 'r', encoding='utf-8', errors='ignore'):\n" +
            "            s = raw.strip()\n" +
            "            if not s or s.startswith('#') or s.startswith('$') or '=' not in s: continue\n" +
            "            lhs, rhs = s.split('=', 1)\n" +
            "            btype = lhs.strip()\n" +
            "            if not btype.startswith('bind'): continue\n" +
            "            rhs_clean = rhs.split(' #', 1)[0].strip()\n" +
            "            parts = [p.strip() for p in rhs_clean.split(',')]\n" +
            "            if len(parts) >= 3:\n" +
            "                binds.append({\n" +
            "                    'bindType': btype,\n" +
            "                    'mods': parts[0],\n" +
            "                    'key': parts[1],\n" +
            "                    'dispatcher': parts[2],\n" +
            "                    'arg': ', '.join(parts[3:]).strip() if len(parts) > 3 else ''\n" +
            "                })\n" +
            "    print(json.dumps({'scope': scope, 'filePath': full_path, 'binds': binds}))\n"

        loadProc.command = ["python3", "-c", pyScript, scopeId, root.configDir, info.relPath]
        loadProc.running = true
    }

    function saveCurrentScope() {
        var info = root.getScopeInfo(root.currentScope)
        if (root.currentScope === "gestures") {
            var gArr = []
            for (var g = 0; g < gesturesModel.count; g++) {
                var gi = gesturesModel.get(g)
                gArr.push({
                    fingers: String(gi.fingers || "3").trim(),
                    direction: String(gi.direction || "horizontal").trim(),
                    action: String(gi.action || "workspace").trim()
                })
            }
            var gPayload = JSON.stringify({
                natural_scroll: root.tpNaturalScroll,
                tap_to_click: root.tpTapToClick,
                disable_while_typing: root.tpDisableWhileTyping,
                workspace_swipe: root.tpWorkspaceSwipe,
                workspace_swipe_fingers: root.tpSwipeFingers,
                workspace_swipe_distance: root.tpSwipeDistance,
                gestures: gArr
            })
            Quickshell.execDetached([
                "python3", "-c",
                "import json, os, subprocess, sys\n" +
                "cfg_dir = os.path.expanduser(sys.argv[1])\n" +
                "rel_path = sys.argv[2]\n" +
                "data = json.loads(sys.argv[3])\n" +
                "lines = [\n" +
                "    '#################################################################',\n" +
                "    '# CARBON SHELL — TOUCHPAD & MULTI-FINGER GESTURES               #',\n" +
                "    '# Location: ~/.config/carbon/configs/gestures.conf              #',\n" +
                "    '#################################################################',\n" +
                "    '',\n" +
                "    f\"natural_scroll = {'true' if data.get('natural_scroll', True) else 'false'}\",\n" +
                "    f\"disable_while_typing = {'true' if data.get('disable_while_typing', True) else 'false'}\",\n" +
                "    f\"tap_to_click = {'true' if data.get('tap_to_click', True) else 'false'}\",\n" +
                "    'scroll_factor = 1.0',\n" +
                "    f\"workspace_swipe = {'true' if data.get('workspace_swipe', True) else 'false'}\",\n" +
                "    f\"workspace_swipe_fingers = {int(data.get('workspace_swipe_fingers', 3))}\",\n" +
                "    f\"workspace_swipe_distance = {int(data.get('workspace_swipe_distance', 400))}\",\n" +
                "    'workspace_swipe_invert = false',\n" +
                "    'workspace_swipe_create_new = true',\n" +
                "    ''\n" +
                "]\n" +
                "for g in data.get('gestures', []):\n" +
                "    lines.append(f\"gesture = {g.get('fingers', '3')}, {g.get('direction', 'horizontal')}, {g.get('action', 'workspace')}\")\n" +
                "content = '\\n'.join(lines) + '\\n'\n" +
                "for base in [cfg_dir, os.path.expanduser('~/.config/hypr')]:\n" +
                "    dst = os.path.join(base, rel_path)\n" +
                "    try:\n" +
                "        os.makedirs(os.path.dirname(dst), exist_ok=True)\n" +
                "        open(dst, 'w', encoding='utf-8').write(content)\n" +
                "    except Exception: pass\n" +
                "init_sh = os.path.join(cfg_dir, 'scripts', 'carbon-gestures-init.sh')\n" +
                "if os.path.exists(init_sh):\n" +
                "    subprocess.run(['bash', init_sh], check=False)\n",
                root.configDir,
                info.relPath,
                gPayload
            ])
            root.statusIsError = false
            root.statusMessage = "Saved Touchpad & 3-Finger Gestures to " + info.relPath + " and applied live via hyprctl!"
            return
        }

        var arr = []
        for (var i = 0; i < bindsModel.count; i++) {
            var item = bindsModel.get(i)
            if (!item.key || String(item.key).trim().length === 0) continue
            arr.push({
                bindType: String(item.bindType || "bind").trim(),
                mods: String(item.mods !== undefined ? item.mods : "$mainMod").trim(),
                key: String(item.key || "").trim(),
                dispatcher: String(item.dispatcher || "exec").trim(),
                arg: String(item.arg || "").trim()
            })
        }

        var payloadStr = JSON.stringify(arr)
        Quickshell.execDetached([
            "python3", "-c",
            "import json, os, subprocess, sys\n" +
            "scope = sys.argv[1]\n" +
            "cfg_dir = os.path.expanduser(sys.argv[2])\n" +
            "rel_path = sys.argv[3]\n" +
            "binds = json.loads(sys.argv[4])\n" +
            "lines = [\n" +
            "    '#################################################################',\n" +
            "    f'# CARBON SHELL — {scope.upper()} KEYBINDINGS',\n" +
            "    f'# File: ~/.config/carbon/{rel_path}',\n" +
            "    '# Managed by Carbon Rust Settings Hub (SUPER + SHIFT + C)',\n" +
            "    '#################################################################',\n" +
            "    '',\n" +
            "    '$mainMod = SUPER'\n" +
            "]\n" +
            "if scope == 'default':\n" +
            "    lines.append('$terminal = kitty')\n" +
            "    lines.append('$fileManager = nautilus')\n" +
            "lines.append('')\n" +
            "for b in binds:\n" +
            "    bt = b.get('bindType') or 'bind'\n" +
            "    mods = b.get('mods') or ''\n" +
            "    key = b.get('key') or ''\n" +
            "    disp = b.get('dispatcher') or 'exec'\n" +
            "    arg = b.get('arg') or ''\n" +
            "    if arg:\n" +
            "        lines.append(f'{bt} = {mods}, {key}, {disp}, {arg}')\n" +
            "    else:\n" +
            "        lines.append(f'{bt} = {mods}, {key}, {disp},')\n" +
            "content = '\\n'.join(lines) + '\\n'\n" +
            "for base in [cfg_dir, os.path.expanduser('~/.config/hypr')]:\n" +
            "    dst = os.path.join(base, rel_path)\n" +
            "    try:\n" +
            "        os.makedirs(os.path.dirname(dst), exist_ok=True)\n" +
            "        open(dst, 'w', encoding='utf-8').write(content)\n" +
            "    except Exception: pass\n" +
            "mode_sh = os.path.join(cfg_dir, 'scripts', 'carbon-mode-keybinds.sh')\n" +
            "if os.path.exists(mode_sh):\n" +
            "    subprocess.run(['bash', mode_sh], check=False)\n" +
            "else:\n" +
            "    subprocess.run(['hyprctl', 'reload'], check=False)\n",
            root.currentScope,
            root.configDir,
            info.relPath,
            payloadStr
        ])

        root.statusIsError = false
        root.statusMessage = "Saved " + bindsModel.count + " isolated keybinds to ~/.config/carbon/" + info.relPath + " & reloaded Hyprland!"
    }

    function sanitizeAllModesWasdAndFullscreen() {
        Quickshell.execDetached([
            "python3", "-c",
            "import glob, os, subprocess, sys\n" +
            "cfg_dir = os.path.expanduser(sys.argv[1])\n" +
            "hypr_dir = os.path.expanduser('~/.config/hypr')\n" +
            "targets = []\n" +
            "for base in [cfg_dir, hypr_dir]:\n" +
            "    for pat in ['keybinds*.conf', 'configs/keybinds*.conf', 'configs/vanish-keybinds.conf', 'carbon/keybinds.conf']:\n" +
            "        targets.extend(glob.glob(os.path.join(base, pat)))\n" +
            "for p in set(targets):\n" +
            "    if not os.path.isfile(p): continue\n" +
            "    out = []\n" +
            "    for raw in open(p, 'r', encoding='utf-8', errors='ignore'):\n" +
            "        s = raw.strip()\n" +
            "        if s.startswith('bind') and '=' in s:\n" +
            "            parts = [x.strip() for x in s.split('=', 1)[1].split(',')]\n" +
            "            if len(parts) >= 3:\n" +
            "                m = parts[0].replace('$mainMod', 'SUPER').strip()\n" +
            "                k = parts[1].upper()\n" +
            "                d = parts[2].lower()\n" +
            "                a = ','.join(parts[3:]).strip().lower() if len(parts) > 3 else ''\n" +
            "                if m == 'SUPER' and k in ('W', 'A', 'S', 'D'):\n" +
            "                    continue\n" +
            "                if m == 'SUPER' and k == 'F' and 'firefox' in a:\n" +
            "                    out.append('bind = $mainMod, F, fullscreen,\\n')\n" +
            "                    continue\n" +
            "        out.append(raw)\n" +
            "    open(p, 'w', encoding='utf-8').writelines(out)\n" +
            "mode_sh = os.path.join(cfg_dir, 'scripts', 'carbon-mode-keybinds.sh')\n" +
            "if os.path.exists(mode_sh): subprocess.run(['bash', mode_sh], check=False)\n",
            root.configDir
        ])
        for (var i = bindsModel.count - 1; i >= 0; i--) {
            var it = bindsModel.get(i)
            var mNorm = String(it.mods || "").replace("$mainMod", "SUPER").trim()
            var kNorm = String(it.key || "").toUpperCase().trim()
            if (mNorm === "SUPER" && (kNorm === "W" || kNorm === "A" || kNorm === "S" || kNorm === "D")) {
                bindsModel.remove(i)
            } else if (mNorm === "SUPER" && kNorm === "F" && String(it.arg || "").toLowerCase().indexOf("firefox") !== -1) {
                bindsModel.setProperty(i, "dispatcher", "fullscreen")
                bindsModel.setProperty(i, "arg", "")
            }
        }
        root.statusIsError = false
        root.statusMessage = "Unbound SUPER + W/A/S/D across all modes and restored SUPER + F to Fullscreen!"
    }

    function resetCurrentScopeToDefaults() {
        var info = root.getScopeInfo(root.currentScope)
        Quickshell.execDetached([
            "python3", "-c",
            "import os, shutil, subprocess, sys\n" +
            "cfg_dir = os.path.expanduser(sys.argv[1])\n" +
            "rel_path = sys.argv[2]\n" +
            "dst = os.path.join(cfg_dir, rel_path)\n" +
            "candidates = [\n" +
            "    dst + '.dist',\n" +
            "    os.path.expanduser('~/carbon-development/hypr/' + rel_path),\n" +
            "    os.path.expanduser('~/carbon-shell/hypr/' + rel_path),\n" +
            "    '/app/applet/hypr/' + rel_path\n" +
            "]\n" +
            "repo_file = os.path.join(cfg_dir, 'repo_path')\n" +
            "if os.path.exists(repo_file):\n" +
            "    rp = open(repo_file).read().strip()\n" +
            "    if rp: candidates.insert(0, os.path.join(rp, 'hypr', rel_path))\n" +
            "for c in candidates:\n" +
            "    if os.path.isfile(c):\n" +
            "        os.makedirs(os.path.dirname(dst), exist_ok=True)\n" +
            "        shutil.copyfile(c, dst)\n" +
            "        break\n" +
            "mode_sh = os.path.join(cfg_dir, 'scripts', 'carbon-mode-keybinds.sh')\n" +
            "if os.path.exists(mode_sh): subprocess.run(['bash', mode_sh], check=False)\n",
            root.configDir,
            info.relPath
        ])
        reloadScopeTimer.restart()
        root.statusIsError = false
        root.statusMessage = "Restored default template for " + info.label + " (" + info.relPath + ")"
    }

    Timer {
        id: reloadScopeTimer
        interval: 250
        repeat: false
        onTriggered: root.loadScope(root.currentScope)
    }

    Component.onCompleted: {
        root.loadScope("minimal")
    }

    // Global key catcher when recording a shortcut
    Item {
        id: keyCaptureHandler
        focus: root.recordingIndex >= 0
        Keys.onPressed: (event) => {
            if (root.recordingIndex < 0 || root.recordingIndex >= bindsModel.count) return
            if (event.key === Qt.Key_Escape) {
                root.recordingIndex = -1
                event.accepted = true
                return
            }
            var kName = root.keyEventToHyprName(event)
            if (kName.length > 0) {
                var mName = root.modifiersFromKeyEvent(event)
                bindsModel.setProperty(root.recordingIndex, "mods", mName)
                bindsModel.setProperty(root.recordingIndex, "key", kName)
                root.recordingIndex = -1
                event.accepted = true
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.px(24)
        spacing: Theme.px(14)

        // ==========================================
        // 1. HEADER & ACTION TOOLBAR
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.px(12)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: "KEYBINDS & GESTURES STUDIO"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(18)
                    font.weight: Font.Bold
                    color: "#FFFFFF"
                }

                Text {
                    text: root.statusMessage
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontPx(11)
                    color: root.statusIsError ? "#FF6B6B" : Theme.primary
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            // One-Click Sanitize WASD & MOD+F Fullscreen Button
            Rectangle {
                Layout.preferredHeight: Theme.px(36)
                Layout.preferredWidth: Theme.px(215)
                radius: Theme.px(8)
                color: fixWasdMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.18)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰁪  Free WASD + Fix MOD+F"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(11.5)
                    font.weight: Font.DemiBold
                    color: "#FFFFFF"
                }

                MouseArea {
                    id: fixWasdMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.sanitizeAllModesWasdAndFullscreen()
                }
            }

            // Reset Defaults Button
            Rectangle {
                Layout.preferredHeight: Theme.px(36)
                Layout.preferredWidth: Theme.px(128)
                radius: Theme.px(8)
                color: resetMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.14)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰑐  Reset Scope"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(11.5)
                    font.weight: Font.DemiBold
                    color: Qt.rgba(1, 1, 1, 0.85)
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetCurrentScopeToDefaults()
                }
            }

            // Save & Apply Button
            Rectangle {
                Layout.preferredHeight: Theme.px(36)
                Layout.preferredWidth: Theme.px(164)
                radius: Theme.px(8)
                color: saveMouse.pressed ? Qt.darker(Theme.primary, 1.15) : Theme.primary

                Text {
                    anchors.centerIn: parent
                    text: "󰆓  Save & Reload"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(12)
                    font.weight: Font.Bold
                    color: "#0A0D12"
                }

                MouseArea {
                    id: saveMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.saveCurrentScope()
                }
            }
        }

        // ==========================================
        // 2. ISOLATED SCOPE / MODE SELECTOR PILLS
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(48)
            radius: Theme.px(10)
            color: Qt.rgba(1, 1, 1, 0.03)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.px(6)
                spacing: Theme.px(6)

                Repeater {
                    model: root.scopeList

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.px(7)
                        readonly property bool isCurrent: root.currentScope === modelData.id
                        color: isCurrent
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                            : (scopeTabMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                        border.color: isCurrent ? Theme.primary : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: Theme.px(5)

                            Text {
                                text: modelData.label
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(11.5)
                                font.weight: isCurrent ? Font.Bold : Font.Medium
                                color: isCurrent ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.70)
                            }
                        }

                        MouseArea {
                            id: scopeTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.loadScope(modelData.id)
                        }
                    }
                }
            }
        }

        // ==========================================
        // 3. FILE PATH & FILTER BAR (for Keybind Scopes)
        // ==========================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(44)
            radius: Theme.px(10)
            color: Qt.rgba(1, 1, 1, 0.025)
            border.color: Qt.rgba(1, 1, 1, 0.07)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(14)
                anchors.rightMargin: Theme.px(10)
                spacing: Theme.px(12)

                Text {
                    text: "FILE:"
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontPx(10.5)
                    font.weight: Font.Bold
                    color: Theme.primary
                }

                Text {
                    text: root.currentFilePath
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontPx(11)
                    color: Qt.rgba(1, 1, 1, 0.75)
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }

                // Filter Search Box (visible on keybind scopes)
                Rectangle {
                    visible: root.currentScope !== "gestures"
                    Layout.preferredWidth: Theme.px(220)
                    Layout.preferredHeight: Theme.px(30)
                    radius: Theme.px(6)
                    color: Qt.rgba(0, 0, 0, 0.30)
                    border.color: filterInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(8)
                        anchors.rightMargin: Theme.px(8)
                        spacing: Theme.px(6)

                        Text {
                            text: "󰍉"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(12)
                            color: Qt.rgba(1, 1, 1, 0.45)
                        }

                        TextInput {
                            id: filterInput
                            Layout.fillWidth: true
                            color: "#FFFFFF"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11.5)
                            clip: true
                            onTextChanged: root.searchQuery = text

                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Filter key or action..."
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(11.5)
                                visible: !filterInput.text && !filterInput.activeFocus
                            }
                        }
                    }
                }

                // Add New Bind Button
                Rectangle {
                    Layout.preferredHeight: Theme.px(30)
                    Layout.preferredWidth: Theme.px(124)
                    radius: Theme.px(6)
                    color: addBindMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                    border.color: Theme.primary
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.currentScope === "gestures" ? "+ Add Gesture" : "+ Add Keybind"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(11.5)
                        font.weight: Font.Bold
                        color: Theme.primary
                    }

                    MouseArea {
                        id: addBindMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.currentScope === "gestures") {
                                gesturesModel.append({
                                    fingers: "3",
                                    direction: "up",
                                    action: "dispatcher, exec, sh ~/.config/carbon/scripts/carbon-ipc.sh toggle-overview"
                                })
                            } else {
                                bindsModel.insert(0, {
                                    bindType: "bind",
                                    mods: "$mainMod",
                                    key: "O",
                                    dispatcher: "exec",
                                    arg: "sh ~/.config/carbon/scripts/carbon-ipc.sh spotlight"
                                })
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 4A. KEYBINDINGS LIST EDITOR
        // ==========================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentScope !== "gestures"

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.px(6)

                // Column Headers
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.px(28)
                    radius: Theme.px(6)
                    color: Qt.rgba(1, 1, 1, 0.04)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(12)
                        anchors.rightMargin: Theme.px(12)
                        spacing: Theme.px(10)

                        Text { Layout.preferredWidth: Theme.px(62); text: "TYPE"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.5) }
                        Text { Layout.preferredWidth: Theme.px(155); text: "MODIFIERS"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.5) }
                        Text { Layout.preferredWidth: Theme.px(125); text: "KEY (CLICK OR TYPE)"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.5) }
                        Text { Layout.preferredWidth: Theme.px(115); text: "DISPATCHER"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.5) }
                        Text { Layout.fillWidth: true; text: "COMMAND / TARGET ARGUMENT"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.5) }
                        Text { Layout.preferredWidth: Theme.px(32); text: "DEL"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Qt.rgba(1,1,1,0.5); horizontalAlignment: Text.AlignHCenter }
                    }
                }

                ListView {
                    id: bindsListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: bindsModel
                    spacing: Theme.px(6)
                    clip: true

                    delegate: Rectangle {
                        id: bindRow
                        readonly property string q: root.searchQuery.toLowerCase().trim()
                        readonly property string descText: root.describeAction(dispatcher, arg)
                        readonly property bool matchesFilter: q.length === 0
                            || String(key || "").toLowerCase().indexOf(q) !== -1
                            || String(mods || "").toLowerCase().indexOf(q) !== -1
                            || String(dispatcher || "").toLowerCase().indexOf(q) !== -1
                            || String(arg || "").toLowerCase().indexOf(q) !== -1
                            || descText.toLowerCase().indexOf(q) !== -1

                        width: ListView.view.width
                        height: matchesFilter ? Theme.px(52) : 0
                        visible: matchesFilter
                        radius: Theme.px(8)
                        color: Qt.rgba(1, 1, 1, 0.03)
                        border.color: root.recordingIndex === index ? Theme.primary : Qt.rgba(1, 1, 1, 0.07)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(12)
                            anchors.rightMargin: Theme.px(12)
                            spacing: Theme.px(10)

                            // 1. Bind Type Cycle Pill (bind / bindr / binde / bindel / bindl / bindm)
                            Rectangle {
                                Layout.preferredWidth: Theme.px(62)
                                Layout.preferredHeight: Theme.px(32)
                                radius: Theme.px(6)
                                color: Qt.rgba(1, 1, 1, 0.06)
                                border.color: Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: bindType
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(11)
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var order = ["bind", "bindr", "binde", "bindel", "bindl", "bindm"]
                                        var idx = order.indexOf(bindType)
                                        var next = order[(idx + 1) % order.length]
                                        bindsModel.setProperty(index, "bindType", next)
                                    }
                                }
                            }

                            // 2. Modifiers Input + Cycle Button
                            Rectangle {
                                Layout.preferredWidth: Theme.px(155)
                                Layout.preferredHeight: Theme.px(32)
                                radius: Theme.px(6)
                                color: Qt.rgba(0, 0, 0, 0.28)
                                border.color: modInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.px(8)
                                    anchors.rightMargin: Theme.px(4)
                                    spacing: 4

                                    TextInput {
                                        id: modInput
                                        Layout.fillWidth: true
                                        text: mods
                                        color: "#FFFFFF"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(11)
                                        clip: true
                                        onTextEdited: bindsModel.setProperty(index, "mods", text)
                                    }

                                    Rectangle {
                                        width: Theme.px(22); height: Theme.px(22); radius: Theme.px(4)
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "⇄"
                                            font.pixelSize: Theme.fontPx(10)
                                            color: Qt.rgba(1, 1, 1, 0.7)
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var presets = ["$mainMod", "$mainMod SHIFT", "$mainMod CTRL", "$mainMod ALT", "ALT", "CTRL ALT", ""]
                                                var curIdx = presets.indexOf(mods)
                                                var nextMod = presets[(curIdx + 1) % presets.length]
                                                bindsModel.setProperty(index, "mods", nextMod)
                                            }
                                        }
                                    }
                                }
                            }

                            // 3. Key Input + Interactive Record Button
                            Rectangle {
                                Layout.preferredWidth: Theme.px(125)
                                Layout.preferredHeight: Theme.px(32)
                                radius: Theme.px(6)
                                color: root.recordingIndex === index ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.24) : Qt.rgba(0, 0, 0, 0.28)
                                border.color: (keyInput.activeFocus || root.recordingIndex === index) ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.px(8)
                                    anchors.rightMargin: Theme.px(4)
                                    spacing: 4

                                    TextInput {
                                        id: keyInput
                                        Layout.fillWidth: true
                                        text: root.recordingIndex === index ? "Press key..." : key
                                        color: root.recordingIndex === index ? Theme.primary : "#FFFFFF"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(11.5)
                                        font.weight: Font.Bold
                                        clip: true
                                        onTextEdited: bindsModel.setProperty(index, "key", text)
                                    }

                                    Rectangle {
                                        width: Theme.px(24); height: Theme.px(22); radius: Theme.px(4)
                                        color: root.recordingIndex === index ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰌌"
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(11)
                                            color: root.recordingIndex === index ? "#0A0D12" : Qt.rgba(1, 1, 1, 0.75)
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.recordingIndex === index) {
                                                    root.recordingIndex = -1
                                                } else {
                                                    root.recordingIndex = index
                                                    keyCaptureHandler.forceActiveFocus()
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // 4. Dispatcher Input + Cycle Button
                            Rectangle {
                                Layout.preferredWidth: Theme.px(115)
                                Layout.preferredHeight: Theme.px(32)
                                radius: Theme.px(6)
                                color: Qt.rgba(0, 0, 0, 0.28)
                                border.color: dispInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.px(8)
                                    anchors.rightMargin: Theme.px(4)
                                    spacing: 4

                                    TextInput {
                                        id: dispInput
                                        Layout.fillWidth: true
                                        text: dispatcher
                                        color: "#FFFFFF"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(11)
                                        clip: true
                                        onTextEdited: bindsModel.setProperty(index, "dispatcher", text)
                                    }

                                    Rectangle {
                                        width: Theme.px(20); height: Theme.px(22); radius: Theme.px(4)
                                        color: Qt.rgba(1, 1, 1, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "▾"
                                            font.pixelSize: Theme.fontPx(10)
                                            color: Qt.rgba(1, 1, 1, 0.7)
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var disps = ["exec", "fullscreen", "killactive", "togglefloating", "movefocus", "movewindow", "resizeactive", "workspace", "movetoworkspace"]
                                                var dIdx = disps.indexOf(dispatcher)
                                                var nextD = disps[(dIdx + 1) % disps.length]
                                                bindsModel.setProperty(index, "dispatcher", nextD)
                                            }
                                        }
                                    }
                                }
                            }

                            // 5. Command / Target Argument + Action Description
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: bindRow.descText
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(10)
                                    font.weight: Font.DemiBold
                                    color: Theme.primary
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.px(24)
                                    radius: Theme.px(5)
                                    color: Qt.rgba(0, 0, 0, 0.28)
                                    border.color: argInput.activeFocus ? Theme.primary : Qt.rgba(1, 1, 1, 0.10)
                                    border.width: 1

                                    TextInput {
                                        id: argInput
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.px(8)
                                        anchors.rightMargin: Theme.px(8)
                                        verticalAlignment: Text.AlignVCenter
                                        text: arg
                                        color: Qt.rgba(1, 1, 1, 0.90)
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(10.5)
                                        clip: true
                                        onTextEdited: bindsModel.setProperty(index, "arg", text)
                                    }
                                }
                            }

                            // 6. Delete Bind Button
                            Rectangle {
                                Layout.preferredWidth: Theme.px(32)
                                Layout.preferredHeight: Theme.px(32)
                                radius: Theme.px(6)
                                color: delBindMouse.containsMouse ? Qt.rgba(1.0, 0.3, 0.3, 0.22) : Qt.rgba(1, 1, 1, 0.05)
                                border.color: delBindMouse.containsMouse ? "#FF6B6B" : "transparent"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(12)
                                    color: delBindMouse.containsMouse ? "#FF6B6B" : Qt.rgba(1, 1, 1, 0.6)
                                }

                                MouseArea {
                                    id: delBindMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: bindsModel.remove(index)
                                }
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // 4B. TOUCHPAD & 3-FINGER GESTURES EDITOR
        // ==========================================
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.currentScope === "gestures"
            spacing: Theme.px(14)

            // Touchpad Hardware Toggles Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(116)
                radius: Theme.px(12)
                color: Qt.rgba(1, 1, 1, 0.03)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                GridLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.px(14)
                    columns: 3
                    rowSpacing: Theme.px(10)
                    columnSpacing: Theme.px(12)

                    // Toggle 1: 3-Finger Workspace Swipe
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(38)
                        radius: Theme.px(8)
                        color: root.tpWorkspaceSwipe ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Qt.rgba(1, 1, 1, 0.04)
                        border.color: root.tpWorkspaceSwipe ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: root.tpWorkspaceSwipe ? "✓ 3-Finger Workspace Swipe: ON" : "3-Finger Workspace Swipe: OFF"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11.5)
                            font.weight: Font.Bold
                            color: root.tpWorkspaceSwipe ? Theme.primary : Qt.rgba(1, 1, 1, 0.7)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tpWorkspaceSwipe = !root.tpWorkspaceSwipe
                        }
                    }

                    // Toggle 2: Natural Scroll
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(38)
                        radius: Theme.px(8)
                        color: root.tpNaturalScroll ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Qt.rgba(1, 1, 1, 0.04)
                        border.color: root.tpNaturalScroll ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: root.tpNaturalScroll ? "✓ Touchpad Natural Scroll: ON" : "Touchpad Natural Scroll: OFF"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11.5)
                            font.weight: Font.Bold
                            color: root.tpNaturalScroll ? Theme.primary : Qt.rgba(1, 1, 1, 0.7)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tpNaturalScroll = !root.tpNaturalScroll
                        }
                    }

                    // Toggle 3: Tap to Click
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(38)
                        radius: Theme.px(8)
                        color: root.tpTapToClick ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Qt.rgba(1, 1, 1, 0.04)
                        border.color: root.tpTapToClick ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: root.tpTapToClick ? "✓ Tap-to-Click: ON" : "Tap-to-Click: OFF"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11.5)
                            font.weight: Font.Bold
                            color: root.tpTapToClick ? Theme.primary : Qt.rgba(1, 1, 1, 0.7)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tpTapToClick = !root.tpTapToClick
                        }
                    }

                    // Toggle 4: Disable While Typing
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(38)
                        radius: Theme.px(8)
                        color: root.tpDisableWhileTyping ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Qt.rgba(1, 1, 1, 0.04)
                        border.color: root.tpDisableWhileTyping ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: root.tpDisableWhileTyping ? "✓ Disable While Typing: ON" : "Disable While Typing: OFF"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11.5)
                            font.weight: Font.Bold
                            color: root.tpDisableWhileTyping ? Theme.primary : Qt.rgba(1, 1, 1, 0.7)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tpDisableWhileTyping = !root.tpDisableWhileTyping
                        }
                    }

                    // Toggle 5: Fingers Count (3 vs 4)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(38)
                        radius: Theme.px(8)
                        color: Qt.rgba(1, 1, 1, 0.06)
                        border.color: Qt.rgba(1, 1, 1, 0.14)
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "Workspace Swipe Fingers: " + root.tpSwipeFingers + " (Click to Switch)"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11.5)
                            font.weight: Font.DemiBold
                            color: "#FFFFFF"
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tpSwipeFingers = (root.tpSwipeFingers === 3 ? 4 : 3)
                        }
                    }

                    // Button 6: Test / Apply Live Now
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(38)
                        radius: Theme.px(8)
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                        border.color: Theme.primary
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "󰑓  Apply Touchpad & Gestures Now"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(11.5)
                            font.weight: Font.Bold
                            color: Theme.primary
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.saveCurrentScope()
                        }
                    }
                }
            }

            // Multi-Finger Gesture Rules List
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: gesturesModel
                spacing: Theme.px(6)
                clip: true

                delegate: Rectangle {
                    width: ListView.view.width
                    height: Theme.px(46)
                    radius: Theme.px(8)
                    color: Qt.rgba(1, 1, 1, 0.03)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.px(12)
                        anchors.rightMargin: Theme.px(12)
                        spacing: Theme.px(10)

                        Text {
                            text: "FINGERS:"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(10)
                            color: Qt.rgba(1, 1, 1, 0.5)
                        }

                        Rectangle {
                            Layout.preferredWidth: Theme.px(54)
                            Layout.preferredHeight: Theme.px(30)
                            radius: Theme.px(6)
                            color: Qt.rgba(0, 0, 0, 0.30)
                            border.color: Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1
                            TextInput {
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: fingers
                                color: Theme.primary
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(12)
                                font.weight: Font.Bold
                                onTextEdited: gesturesModel.setProperty(index, "fingers", text)
                            }
                        }

                        Text {
                            text: "DIRECTION:"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(10)
                            color: Qt.rgba(1, 1, 1, 0.5)
                        }

                        Rectangle {
                            Layout.preferredWidth: Theme.px(120)
                            Layout.preferredHeight: Theme.px(30)
                            radius: Theme.px(6)
                            color: Qt.rgba(0, 0, 0, 0.30)
                            border.color: Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1
                            TextInput {
                                anchors.fill: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: direction
                                color: "#FFFFFF"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(11)
                                onTextEdited: gesturesModel.setProperty(index, "direction", text)
                            }
                        }

                        Text {
                            text: "ACTION:"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(10)
                            color: Qt.rgba(1, 1, 1, 0.5)
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: Theme.px(30)
                            radius: Theme.px(6)
                            color: Qt.rgba(0, 0, 0, 0.30)
                            border.color: Qt.rgba(1, 1, 1, 0.14)
                            border.width: 1
                            TextInput {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.px(8)
                                anchors.rightMargin: Theme.px(8)
                                verticalAlignment: Text.AlignVCenter
                                text: action
                                color: "#FFFFFF"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(11)
                                clip: true
                                onTextEdited: gesturesModel.setProperty(index, "action", text)
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: Theme.px(30)
                            Layout.preferredHeight: Theme.px(30)
                            radius: Theme.px(6)
                            color: Qt.rgba(1, 1, 1, 0.06)
                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(11)
                                color: Qt.rgba(1, 1, 1, 0.65)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: gesturesModel.remove(index)
                            }
                        }
                    }
                }
            }
        }
    }
}
