import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../Singletons"
import "../components"

/**
 * SpatialCanvas:
 * Symmetrical 5-Node OS Suite for Carbon Shell.
 *
 * Symmetrical Cardinal Cross (+) Layout:
 *   - (0, 0)   Center: Workspace Blueprint & Opened Windows Switcher
 *   - (-1, 0)  Left:   Connectivity Hub (Wi-Fi 6 + Bluetooth 5.3 Unified Deck)
 *   - (1, 0)   Right:  Carbon Engine & Wallpaper Studio (Discovery, Randomizer, Matugen)
 *   - (0, -1)  Top:    Aesthetic Quick File Browser & Storage Capacity Deck
 *   - (0, 1)   Bottom: System Control Deck (MPRIS Media Mixer + Session Power Tiles)
 */
PanelWindow {
    id: spatialCanvasWindow

    property bool isOpen: false
    property bool animatingOut: false
    signal closeRequested()
    signal animationFinished()

    property string barEdge: "top"
    property string barMode: "notch"
    readonly property bool isTopBarUp: barEdge !== "bottom"

    WlrLayershell.namespace: "carbon-spatial-canvas"
    WlrLayershell.layer: WlrLayer.Overlay
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    FileView {
        id: barPosWatcher
        path: (Quickshell.env("HOME") || "") + "/.config/carbon/carbon-bar-position.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: spatialCanvasWindow.updateBarPos(barPosWatcher.text())
        onFileChanged: {
            reload()
            spatialCanvasWindow.updateBarPos(barPosWatcher.text())
        }
    }

    function updateBarPos(txt) {
        if (!txt) return
        try {
            var d = JSON.parse(txt)
            if (d.mainBarEdge) spatialCanvasWindow.barEdge = d.mainBarEdge
            else if (d.edge) spatialCanvasWindow.barEdge = d.edge
        } catch(e) {}
    }

    FileView {
        id: barModeWatcher
        path: (Quickshell.env("HOME") || "") + "/.config/carbon/carbon-bar-mode.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: spatialCanvasWindow.updateBarMode(barModeWatcher.text())
        onFileChanged: {
            reload()
            spatialCanvasWindow.updateBarMode(barModeWatcher.text())
        }
    }

    function updateBarMode(txt) {
        if (!txt) return
        try {
            var d = JSON.parse(txt)
            if (d.mode) spatialCanvasWindow.barMode = d.mode
            if (d.mainBarEdge) spatialCanvasWindow.barEdge = d.mainBarEdge
        } catch(e) {}
    }

    visible: isOpen || animatingOut
    WlrLayershell.keyboardFocus: (isOpen && !animatingOut) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real rootOpacity: 0.0

    onIsOpenChanged: {
        GlobalState.isCommandCenterOpen = isOpen || animatingOut
        if (!isOpen) {
            rootOpacity = 0.0
            animatingOut = true
            closeAnimTimer.restart()
            activeGridX = 0
            activeGridY = 0
            isOverview = true
            viewport.zoomScale = 0.33
        } else {
            animatingOut = false
            closeAnimTimer.stop()
            rootOpacity = 1.0
            viewport.zoomScale = isOverview ? 0.33 : 1.0
            spatialCanvasWindow.refreshBrowserFiles()
            spatialCanvasWindow.refreshWallpapers()
            spatialCanvasWindow.refreshBluetooth()
            spatialCanvasWindow.refreshUptime()
            spatialCanvasWindow.refreshVolume()
            spatialCanvasWindow.refreshClients()
            centerKeyHandler.forceActiveFocus()
        }
    }

    Component.onCompleted: {
        refreshBrowserFiles();
        refreshWallpapers();
        refreshBluetooth();
        refreshUptime();
        refreshVolume();
        refreshClients();
    }

    Timer {
        id: clientPollTimer
        interval: 1500
        repeat: true
        running: spatialCanvasWindow.visible
        onTriggered: spatialCanvasWindow.refreshClients()
    }

    Timer {
        id: entranceTimer
        interval: 16
        onTriggered: {
            if (spatialCanvasWindow.isOverview) {
                viewport.zoomScale = 0.33
            }
        }
    }

    Timer {
        id: closeAnimTimer
        interval: 260
        onTriggered: {
            spatialCanvasWindow.animatingOut = false
            spatialCanvasWindow.animationFinished()
        }
    }

    // System Clock
    SystemClock {
        id: sysClock
        precision: SystemClock.Seconds
    }

    // Command runner
    Process {
        id: actionRunner
    }

    function execCommand(cmd) {
        actionRunner.command = ["sh", "-c", cmd]
        actionRunner.running = true
    }

    property string feedbackMessage: ""
    Timer {
        id: feedbackClearTimer
        interval: 2500
        onTriggered: spatialCanvasWindow.feedbackMessage = ""
    }

    function showFeedback(msg) {
        feedbackMessage = msg
        feedbackClearTimer.restart()
    }

    function triggerThemeReload() {
        execCommand("sh -c 'sleep 0.8; carbon-ipc.sh reload-theme || true'")
    }

    // ══════════════════════════════════════════════════════════════════
    // DATA SOURCE: LIVE WORKSPACES & CLIENTS
    // ══════════════════════════════════════════════════════════════════
    property var workspacesData: []
    property int activeWorkspaceId: 1
    property var liveClients: []
    property string appFilterQuery: ""

    Process {
        id: radarEngineProc
        command: [
            "sh", "-c",
            "if command -v carbon-radar-engine >/dev/null 2>&1; then exec carbon-radar-engine; elif [ -x \"$HOME/.local/bin/carbon-radar-engine\" ]; then exec \"$HOME/.local/bin/carbon-radar-engine\"; elif [ -x \"$HOME/carbon-shell/apps/carbon-radar/target/release/carbon-radar-engine\" ]; then exec \"$HOME/carbon-shell/apps/carbon-radar/target/release/carbon-radar-engine\"; else exec carbon-radar-engine; fi"
        ]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                var raw = (line || "").trim()
                if (!raw) return
                try {
                    var payload = JSON.parse(raw)
                    if (!payload) return
                    if (payload.workspaces !== undefined) spatialCanvasWindow.workspacesData = payload.workspaces
                    if (payload.active_workspace_id !== undefined) spatialCanvasWindow.activeWorkspaceId = payload.active_workspace_id
                } catch(e) {}
            }
        }
    }

    Process {
        id: clientsFetcherProc
        command: [
            "python3", "-c",
            "import subprocess, json\n" +
            "try:\n" +
            "    c = json.loads(subprocess.check_output(['hyprctl', '-j', 'clients']).decode())\n" +
            "    a = json.loads(subprocess.check_output(['hyprctl', '-j', 'activeworkspace']).decode())\n" +
            "    print(json.dumps({'clients': c, 'active_ws': a.get('id', 1)}))\n" +
            "except Exception:\n" +
            "    print('{}')\n"
        ]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    try {
                        var parsed = JSON.parse(text.trim());
                        if (parsed.active_ws !== undefined) {
                            spatialCanvasWindow.activeWorkspaceId = parsed.active_ws;
                        }
                        if (Array.isArray(parsed.clients)) {
                            spatialCanvasWindow.liveClients = parsed.clients.filter(function(c) {
                                return c.mapped && !c.hidden && c.workspace && c.workspace.id > 0 && c.class && c.class.length > 0;
                            });
                        }
                    } catch(e) {}
                }
            }
        }
    }

    function refreshClients() {
        if (!clientsFetcherProc.running) clientsFetcherProc.running = true;
    }

    readonly property var allOpenWindows: liveClients || []

    readonly property var filteredWindows: {
        var list = allOpenWindows;
        var q = (appFilterQuery || "").trim().toLowerCase();
        if (!q) return list;
        return list.filter(function(w) {
            var cls = (w.class || "").toLowerCase();
            var ttl = (w.title || "").toLowerCase();
            var wsName = w.workspace ? String(w.workspace.name || w.workspace.id).toLowerCase() : "";
            return cls.indexOf(q) !== -1 || ttl.indexOf(q) !== -1 || wsName.indexOf(q) !== -1;
        });
    }

    function getWorkspaces() {
        var res = [];
        var clients = liveClients || [];
        var activeId = activeWorkspaceId || 1;

        for (var i = 1; i <= 9; i++) {
            var wsWins = [];
            for (var j = 0; j < clients.length; j++) {
                var c = clients[j];
                if (c.workspace && c.workspace.id === i) {
                    wsWins.push({
                        address: c.address,
                        class: c.class,
                        title: c.title,
                        at: c.at,
                        size: c.size,
                        is_focused: (c.focusHistoryID === 0)
                    });
                }
            }
            res.push({
                id: i,
                name: String(i),
                is_active: (i === activeId),
                has_windows: (wsWins.length > 0),
                windows: wsWins
            });
        }
        return res;
    }

    function resolveAppIcon(cls) {
        if (!cls) return ""
        var raw = cls.trim()
        var c = raw.toLowerCase()

        if (c.indexOf("obsidian") !== -1) {
            var o = Quickshell.iconPath("obsidian", "") || Quickshell.iconPath("md.obsidian.Obsidian", "")
            if (o) return o
            return "file://" + Theme.home + "/.local/share/icons/hicolor/scalable/apps/obsidian.svg"
        }
        if (c === "antigravity") return Quickshell.iconPath("antigravity", "")
        if (c === "cz.viceverse.serein" || c === "serein") return Quickshell.iconPath("serein", "")

        if (typeof DesktopEntries !== "undefined" && DesktopEntries && DesktopEntries.applications) {
            var apps = DesktopEntries.applications.values || []
            var parts = c.split(".")
            var lastSegment = parts[parts.length - 1]

            for (var i = 0; i < apps.length; i++) {
                var a = apps[i]
                if (a && a.startupWmClass && a.startupWmClass.toLowerCase() === c) {
                    if (a.icon) {
                        if (a.icon.startsWith("/")) return "file://" + a.icon
                        return Quickshell.iconPath(a.icon.toLowerCase(), "")
                    }
                }
            }
            for (var i = 0; i < apps.length; i++) {
                var a = apps[i]
                var aid = (a && a.id ? a.id : "").toLowerCase()
                if (aid === c || aid === c + ".desktop" || aid === lastSegment || aid === lastSegment + ".desktop") {
                    if (a.icon) {
                        if (a.icon.startsWith("/")) return "file://" + a.icon
                        return Quickshell.iconPath(a.icon.toLowerCase(), "")
                    }
                }
            }
        }
        var parts = c.split(".")
        var last = parts[parts.length - 1]
        if (last && last.length > 0 && last !== c) {
            return Quickshell.iconPath(last, "")
        }
        return Quickshell.iconPath(c, "application-x-executable")
    }

    function switchToWorkspace(wsId) {
        execCommand("hyprctl dispatch workspace " + wsId);
        spatialCanvasWindow.closeRequested();
    }

    // ══════════════════════════════════════════════════════════════════
    // DATA SOURCE: BLUETOOTH SUBSYSTEM
    // ══════════════════════════════════════════════════════════════════
    property bool btPowerOn: true
    property bool btScanning: false
    property bool btWorking: false
    property string btStatus: ""
    property var btDevices: []

    Process {
        id: btListProc
        command: ["sh", "-c", "echo '===POWER==='; bluetoothctl show | grep -i 'Powered:' | awk '{print $2}'; echo '===PAIRED==='; bluetoothctl devices Paired 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+) (.*)/\\1|\\2/'; echo '===CONNECTED==='; bluetoothctl devices Connected 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+).*/\\1/'; echo '===ALL==='; bluetoothctl devices 2>/dev/null | sed -E 's/^Device ([0-9A-F:]+) (.*)/\\1|\\2/'"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onTextChanged: {
                if (text) spatialCanvasWindow.parseBtDevices(text);
            }
        }
    }

    Process {
        id: btActProc
        command: ["sh", "-c", "true"]
        running: false
        stdout: StdioCollector { id: btActC; waitForEnd: true }
        stderr: StdioCollector { id: btActE; waitForEnd: true }
        onExited: {
            spatialCanvasWindow.btWorking = false;
            if (exitCode === 0) {
                spatialCanvasWindow.btStatus = "Success";
            } else {
                var err = String(btActE.text).trim();
                if (!err) err = String(btActC.text).trim();
                spatialCanvasWindow.btStatus = err.length > 0 ? err.split("\n")[0] : "Action failed";
            }
            btRelistTimer.restart();
        }
    }

    Timer {
        id: btRelistTimer
        interval: 1200
        onTriggered: spatialCanvasWindow.refreshBluetooth()
    }

    Process {
        id: btScanProc
        command: ["sh", "-c", "bluetoothctl scan on >/dev/null 2>&1; sleep 8; bluetoothctl scan off >/dev/null 2>&1"]
        running: false
        onExited: {
            spatialCanvasWindow.btScanning = false;
            spatialCanvasWindow.refreshBluetooth();
        }
    }

    Timer {
        id: btScanTicker
        interval: 2000
        repeat: true
        running: spatialCanvasWindow.isOpen && spatialCanvasWindow.btScanning
        onTriggered: spatialCanvasWindow.refreshBluetooth()
    }

    function refreshBluetooth() {
        if (!btListProc.running) btListProc.running = true;
    }

    function scanBluetooth() {
        if (!btPowerOn || btScanning || btWorking) return;
        btScanning = true;
        btStatus = "Scanning...";
        btScanProc.running = true;
    }

    function toggleBtPower() {
        if (btWorking) return;
        btWorking = true;
        var next = !btPowerOn;
        btStatus = next ? "Powering on..." : "Powering off...";
        btActProc.command = ["sh", "-c", "bluetoothctl power " + (next ? "on" : "off")];
        btActProc.running = true;
        btPowerOn = next;
    }

    function toggleBtDevice(mac, connected, paired) {
        if (btWorking) return;
        btWorking = true;
        var safeMac = "'" + String(mac).replace(/'/g, "'\\''") + "'";
        if (connected) {
            btStatus = "Disconnecting...";
            btActProc.command = ["sh", "-c", "bluetoothctl disconnect " + safeMac];
        } else if (paired) {
            btStatus = "Connecting...";
            btActProc.command = ["sh", "-c", "bluetoothctl connect " + safeMac];
        } else {
            btStatus = "Pairing...";
            btActProc.command = ["sh", "-c", "bluetoothctl trust " + safeMac + " >/dev/null 2>&1; bluetoothctl pair " + safeMac + " && bluetoothctl connect " + safeMac];
        }
        btActProc.running = true;
    }

    function resolveBtIcon(name) {
        if (!name) return "bluetooth";
        var n = name.toLowerCase();
        if (n.indexOf("airdrop") !== -1 || n.indexOf("ear") !== -1 || n.indexOf("bud") !== -1 || n.indexOf("rockerz") !== -1 || n.indexOf("headphone") !== -1 || n.indexOf("headset") !== -1) {
            return "headphones";
        }
        if (n.indexOf("rugby") !== -1 || n.indexOf("speaker") !== -1 || n.indexOf("sound") !== -1 || n.indexOf("audio") !== -1) {
            return "speaker";
        }
        if (n.indexOf("mouse") !== -1) return "mouse";
        if (n.indexOf("keyboard") !== -1 || n.indexOf("keychron") !== -1) return "keyboard";
        if (n.indexOf("phone") !== -1 || n.indexOf("iphone") !== -1 || n.indexOf("galaxy") !== -1) return "smartphone";
        return "bluetooth";
    }

    function parseBtDevices(text) {
        var pairedMap = {};
        var connectedMap = {};
        var allDevices = {};
        var lines = String(text).split("\n");
        var section = "";

        for (var i = 0; i < lines.length; i++) {
            var l = lines[i].trim();
            if (!l) continue;
            if (l === "===POWER===") { section = "power"; continue; }
            if (l === "===PAIRED===") { section = "paired"; continue; }
            if (l === "===CONNECTED===") { section = "connected"; continue; }
            if (l === "===ALL===") { section = "all"; continue; }

            if (section === "power") {
                btPowerOn = (l.toLowerCase() === "yes" || l.toLowerCase() === "on");
            } else if (section === "paired") {
                var barP = l.indexOf("|");
                if (barP > 0) {
                    var mP = l.substring(0, barP).trim();
                    var nP = l.substring(barP + 1).trim();
                    if (mP) {
                        pairedMap[mP] = nP;
                        allDevices[mP] = { mac: mP, name: nP, paired: true, connected: false };
                    }
                }
            } else if (section === "connected") {
                connectedMap[l] = true;
            } else if (section === "all") {
                var barA = l.indexOf("|");
                if (barA > 0) {
                    var mA = l.substring(0, barA).trim();
                    var nA = l.substring(barA + 1).trim();
                    if (mA && !allDevices[mA]) {
                        allDevices[mA] = { mac: mA, name: nA, paired: false, connected: false };
                    }
                }
            }
        }

        var rows = [];
        for (var k in allDevices) {
            var dev = allDevices[k];
            dev.connected = !!connectedMap[dev.mac];
            dev.paired = !!pairedMap[dev.mac];
            rows.push(dev);
        }

        rows.sort(function(a, b) {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.paired !== b.paired) return a.paired ? -1 : 1;
            return a.name.localeCompare(b.name);
        });

        btDevices = rows;
    }

    // ══════════════════════════════════════════════════════════════════
    // DATA SOURCE: WALLPAPERS & ENGINE
    // ══════════════════════════════════════════════════════════════════
    property var wallpaperList: []
    property string currentWallpaperPath: ""

    FileView {
        id: currentWpWatcher
        path: (Quickshell.env("HOME") || "") + "/.config/carbon/current_wallpaper_path"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: spatialCanvasWindow.currentWallpaperPath = currentWpWatcher.text().trim()
        onFileChanged: {
            reload()
            spatialCanvasWindow.currentWallpaperPath = currentWpWatcher.text().trim()
        }
    }

    Process {
        id: wallpaperListProc
        property string buffer: ""
        command: [
            "python3", "-c",
            "import os, glob, json;\n" +
            "exts = ('.jpg', '.jpeg', '.png', '.webp');\n" +
            "wp_dir = os.path.expanduser('~/Pictures/Wallpapers');\n" +
            "res = [];\n" +
            "if os.path.isdir(wp_dir):\n" +
            "    for root, _, files in os.walk(wp_dir):\n" +
            "        for f in files:\n" +
            "            if f.lower().endswith(exts) and not f.startswith('.'):\n" +
            "                res.append(os.path.join(root, f));\n" +
            "res.sort(key=lambda x: os.path.getmtime(x), reverse=True);\n" +
            "print(json.dumps(res))"
        ]
        running: false
        onRunningChanged: {
            if (running) {
                buffer = ""
            } else {
                if (buffer.trim().length > 0) {
                    try {
                        var parsed = JSON.parse(buffer.trim());
                        if (Array.isArray(parsed) && parsed.length > 0) spatialCanvasWindow.wallpaperList = parsed;
                    } catch(e) {}
                }
            }
        }
        stdout: SplitParser {
            onRead: (chunk) => { wallpaperListProc.buffer += chunk + "\n" }
        }
    }

    function refreshWallpapers() {
        wallpaperListProc.running = false
        wallpaperListProc.running = true
    }

    function setRandomWallpaper() {
        if (!wallpaperList || wallpaperList.length === 0) return;
        var idx = Math.floor(Math.random() * wallpaperList.length);
        var chosen = wallpaperList[idx];
        applyWallpaper(chosen);
    }

    function applyWallpaper(wpPath) {
        execCommand("bash ~/.config/carbon/scripts/wp-apply.sh \"" + wpPath + "\"");
        currentWallpaperPath = wpPath;
        var fname = wpPath.substring(wpPath.lastIndexOf("/") + 1);
        showFeedback("Applied: " + fname);
        triggerThemeReload();
    }

    function applyBarMode(mode) {
        execCommand("sh ~/.config/hypr/scripts/carbon-mode-keybinds.sh " + mode);
        showFeedback("Switched to " + mode + " mode");
    }

    // ══════════════════════════════════════════════════════════════════
    // DATA SOURCE: QUICK FILE BROWSER
    // ══════════════════════════════════════════════════════════════════
    property string currentBrowserPath: (Quickshell.env("HOME") || "/home/shogun")
    property var currentBrowserFiles: []
    property string storageUsageText: "Storage Capacity"
    property real storageUsageFraction: 0.50

    Process {
        id: fileBrowserProc
        property string buffer: ""
        running: false
        onRunningChanged: {
            if (running) {
                buffer = ""
            } else {
                if (buffer.trim().length > 0) {
                    try {
                        var parsed = JSON.parse(buffer.trim())
                        if (Array.isArray(parsed)) spatialCanvasWindow.currentBrowserFiles = parsed
                    } catch(e) {}
                }
            }
        }
        stdout: SplitParser {
            onRead: (chunk) => { fileBrowserProc.buffer += chunk + "\n" }
        }
    }

    Process {
        id: storageCapacityProc
        property string buffer: ""
        running: false
        onRunningChanged: {
            if (running) {
                buffer = ""
            } else {
                if (buffer.trim().length > 0) {
                    var parts = buffer.trim().split("|")
                    if (parts.length > 0) spatialCanvasWindow.storageUsageText = parts[0]
                    if (parts.length > 1) {
                        var pct = parseInt(parts[1]) || 50
                        spatialCanvasWindow.storageUsageFraction = Math.max(0.0, Math.min(1.0, pct / 100.0))
                    }
                }
            }
        }
        stdout: SplitParser {
            onRead: (chunk) => { storageCapacityProc.buffer += chunk + "\n" }
        }
    }

    function refreshBrowserFiles() {
        fileBrowserProc.running = false
        fileBrowserProc.command = [
            "python3", "-c",
            "import os, sys, json;\n" +
            "p = os.path.expanduser(sys.argv[1]);\n" +
            "entries = [];\n" +
            "try:\n" +
            "    for e in os.scandir(p):\n" +
            "        if not e.name.startswith('.'):\n" +
            "            entries.append({'name': e.name, 'isDir': e.is_dir(), 'size': e.stat().st_size if not e.is_dir() else 0});\n" +
            "except Exception: pass;\n" +
            "entries.sort(key=lambda x: (not x['isDir'], x['name'].lower()));\n" +
            "print(json.dumps(entries[:60]))",
            spatialCanvasWindow.currentBrowserPath
        ]
        fileBrowserProc.running = true

        storageCapacityProc.running = false
        storageCapacityProc.command = [
            "python3", "-c",
            "import shutil, os; t, u, f = shutil.disk_usage(os.path.expanduser('~')); p = int(u/t*100); print(f'{u//(1024**3)}G / {t//(1024**3)}G ({p}%)|{p}%')"
        ]
        storageCapacityProc.running = true
    }

    onCurrentBrowserPathChanged: refreshBrowserFiles()

    readonly property var pathSegments: {
        var p = currentBrowserPath || "/";
        var parts = p.split("/").filter(function(x) { return x.length > 0; });
        var res = [{ name: "/", path: "/" }];
        var acc = "";
        for (var i = 0; i < parts.length; i++) {
            acc += "/" + parts[i];
            res.push({ name: parts[i], path: acc });
        }
        return res;
    }

    readonly property var quickPlaces: [
        { name: "Home", path: (Quickshell.env("HOME") || "/home/shogun"), icon: "home", color: "#38bdf8" },
        { name: "Desktop", path: (Quickshell.env("HOME") || "/home/shogun") + "/Desktop", icon: "desktop_windows", color: "#818cf8" },
        { name: "Downloads", path: (Quickshell.env("HOME") || "/home/shogun") + "/Downloads", icon: "download", color: "#34d399" },
        { name: "Documents", path: (Quickshell.env("HOME") || "/home/shogun") + "/Documents", icon: "description", color: "#fbbf24" },
        { name: "Pictures", path: (Quickshell.env("HOME") || "/home/shogun") + "/Pictures", icon: "photo", color: "#f472b6" },
        { name: "Wallpapers", path: (Quickshell.env("HOME") || "/home/shogun") + "/Pictures/Wallpapers", icon: "image", color: "#a78bfa" },
        { name: ".config", path: (Quickshell.env("HOME") || "/home/shogun") + "/.config", icon: "settings", color: "#94a3b8" }
    ]

    function getFileIcon(name, isDir) {
        if (isDir) return "folder";
        var dot = name.lastIndexOf(".");
        if (dot === -1) return "insert_drive_file";
        var ext = name.substring(dot + 1).toLowerCase();
        if (["png", "jpg", "jpeg", "webp", "svg", "gif", "ico"].indexOf(ext) !== -1) return "image";
        if (["qml", "py", "rs", "js", "ts", "sh", "json", "css", "html", "c", "cpp", "h"].indexOf(ext) !== -1) return "code";
        if (["mp3", "wav", "flac", "ogg", "m4a"].indexOf(ext) !== -1) return "music_note";
        if (["mp4", "mkv", "webm", "avi", "mov"].indexOf(ext) !== -1) return "movie";
        if (["md", "txt", "pdf", "doc", "docx"].indexOf(ext) !== -1) return "description";
        if (["zip", "tar", "gz", "bz2", "xz", "7z"].indexOf(ext) !== -1) return "inventory_2";
        return "insert_drive_file";
    }

    function getFileColor(name, isDir) {
        if (isDir) return "#f59e0b";
        var dot = name.lastIndexOf(".");
        if (dot === -1) return Theme.fgDim;
        var ext = name.substring(dot + 1).toLowerCase();
        if (["png", "jpg", "jpeg", "webp", "svg", "gif"].indexOf(ext) !== -1) return "#06b6d4";
        if (["qml", "py", "rs", "js", "ts", "sh", "json", "css", "html"].indexOf(ext) !== -1) return "#10b981";
        if (["mp3", "wav", "flac", "ogg", "m4a", "mp4", "mkv"].indexOf(ext) !== -1) return "#a855f7";
        if (["md", "txt", "pdf"].indexOf(ext) !== -1) return "#f97316";
        if (["zip", "tar", "gz", "7z"].indexOf(ext) !== -1) return "#ef4444";
        return Theme.fgDim;
    }

    // ══════════════════════════════════════════════════════════════════
    // DATA SOURCE: MEDIA & AUDIO & POWER
    // ══════════════════════════════════════════════════════════════════
    readonly property var activeMprisPlayer: {
        var list = (typeof Mpris !== "undefined" && Mpris && Mpris.players && Mpris.players.values !== undefined) ? Mpris.players.values : [];
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].playbackState === MprisPlaybackState.Playing) return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }
    property real masterOutputVolume: 0.75
    property bool masterOutputMuted: false

    Process {
        id: masterVolumeWatcherProc
        command: ["bash", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo 'Volume: 0.75'"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    var t = text.trim();
                    spatialCanvasWindow.masterOutputMuted = t.indexOf("[MUTED]") !== -1;
                    var match = t.match(/([0-9]+(\.[0-9]+)?)/);
                    if (match) {
                        var val = parseFloat(match[1]);
                        spatialCanvasWindow.masterOutputVolume = Math.max(0.0, Math.min(1.0, val));
                    }
                }
            }
        }
    }

    function refreshVolume() {
        if (!masterVolumeWatcherProc.running) masterVolumeWatcherProc.running = true;
    }

    function setMasterVolume(pct) {
        var safe = Math.max(0.0, Math.min(1.5, pct));
        masterOutputVolume = Math.min(1.0, safe);
        execCommand("wpctl set-volume @DEFAULT_AUDIO_SINK@ " + safe.toFixed(2));
    }

    function toggleMasterMute() {
        execCommand("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle");
        masterOutputMuted = !masterOutputMuted;
        refreshVolume();
    }

    property string systemUptime: "Up 2h 45m"
    Process {
        id: uptimeProc
        command: ["uptime", "-p"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    spatialCanvasWindow.systemUptime = text.trim();
                }
            }
        }
    }

    function refreshUptime() {
        if (!uptimeProc.running) uptimeProc.running = true;
    }

    // ══════════════════════════════════════════════════════════════════
    // 2D SPATIAL ZOOM & CARDINAL CROSS CAMERA
    // ══════════════════════════════════════════════════════════════════
    property int activeGridX: 0
    property int activeGridY: 0
    property bool isOverview: true

    function getNodeTitle(gx, gy) {
        if (gx === 0 && gy === 0) return "WORKSPACE BLUEPRINT";
        if (gx === -1 && gy === 0) return "CONNECTIVITY HUB";
        if (gx === 1 && gy === 0) return "CARBON ENGINE & WALLPAPERS";
        if (gx === 0 && gy === -1) return "QUICK FILE BROWSER";
        if (gx === 0 && gy === 1) return "SYSTEM CONTROL DECK";
        return "NODE [" + gx + ", " + gy + "]";
    }

    function getNodeDesc(gx, gy) {
        if (gx === 0 && gy === 0) return "Live 3x3 Virtual Desktops & Opened Applications Hub";
        if (gx === -1 && gy === 0) return "Dual-Deck Wi-Fi 6 & Bluetooth 5.3 Controller";
        if (gx === 1 && gy === 0) return "Wallpaper Studio, Randomizer & Shell Architecture Engine";
        if (gx === 0 && gy === -1) return "Filesystem Navigation, Breadcrumbs & Storage Deck";
        if (gx === 0 && gy === 1) return "MPRIS Media Mixer, Volume & Session Power Controls";
        return "";
    }

    onIsOverviewChanged: {
        if (!entranceTimer.running) {
            viewport.zoomScale = isOverview ? 0.33 : 1.0;
        }
    }

    function zoomToNode(gx, gy) {
        entranceTimer.stop();
        activeGridX = gx;
        activeGridY = gy;
        isOverview = false;
        viewport.zoomScale = 1.0;
    }

    function zoomToOverview() {
        entranceTimer.stop();
        isOverview = true;
        viewport.zoomScale = 0.33;
    }

    function toggleNodeZoom(gx, gy) {
        if (!isOverview && activeGridX === gx && activeGridY === gy) {
            zoomToOverview();
        } else {
            zoomToNode(gx, gy);
        }
    }

    function moveGrid(dx, dy) {
        var curX = activeGridX;
        var curY = activeGridY;

        if (curX === 0 && curY === 0) {
            if (dx === -1) { activeGridX = -1; activeGridY = 0; }
            else if (dx === 1) { activeGridX = 1; activeGridY = 0; }
            else if (dy === -1) { activeGridX = 0; activeGridY = -1; }
            else if (dy === 1) { activeGridX = 0; activeGridY = 1; }
        } else if (curX === -1 && curY === 0) {
            if (dx === 1) { activeGridX = 0; activeGridY = 0; }
            else if (dy === -1) { activeGridX = 0; activeGridY = -1; }
            else if (dy === 1) { activeGridX = 0; activeGridY = 1; }
        } else if (curX === 1 && curY === 0) {
            if (dx === -1) { activeGridX = 0; activeGridY = 0; }
            else if (dy === -1) { activeGridX = 0; activeGridY = -1; }
            else if (dy === 1) { activeGridX = 0; activeGridY = 1; }
        } else if (curX === 0 && curY === -1) {
            if (dy === 1) { activeGridX = 0; activeGridY = 0; }
            else if (dx === -1) { activeGridX = -1; activeGridY = 0; }
            else if (dx === 1) { activeGridX = 1; activeGridY = 0; }
        } else if (curX === 0 && curY === 1) {
            if (dy === -1) { activeGridX = 0; activeGridY = 0; }
            else if (dx === -1) { activeGridX = -1; activeGridY = 0; }
            else if (dx === 1) { activeGridX = 1; activeGridY = 0; }
        }
    }

    Item {
        id: container
        anchors.fill: parent
        opacity: spatialCanvasWindow.rootOpacity
        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }

        // ── Full-surface Keyboard Handler ──
        Item {
            id: centerKeyHandler
            anchors.fill: parent
            focus: spatialCanvasWindow.isOpen
            Keys.enabled: spatialCanvasWindow.isOpen
            Keys.priority: Keys.BeforeItem

            Keys.onPressed: (event) => {
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                    var num = event.key - Qt.Key_0;
                    spatialCanvasWindow.switchToWorkspace(num);
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Escape) {
                    if (!spatialCanvasWindow.isOverview) {
                        spatialCanvasWindow.zoomToOverview();
                    } else {
                        spatialCanvasWindow.closeRequested();
                    }
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    if (spatialCanvasWindow.isOverview) {
                        spatialCanvasWindow.zoomToNode(spatialCanvasWindow.activeGridX, spatialCanvasWindow.activeGridY);
                        event.accepted = true;
                        return;
                    }
                }

                if (event.key === Qt.Key_Up || event.key === Qt.Key_W) {
                    spatialCanvasWindow.moveGrid(0, -1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down || event.key === Qt.Key_S) {
                    spatialCanvasWindow.moveGrid(0, 1);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_A) {
                    spatialCanvasWindow.moveGrid(-1, 0);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) {
                    spatialCanvasWindow.moveGrid(1, 0);
                    event.accepted = true;
                }
            }
        }

        // ── Deep Frosted Acrylic Backdrop ──
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(8/255, 9/255, 14/255, 0.90)
        }

        // ── 2D Spatial Viewport ──
        Item {
            id: viewport
            anchors.fill: parent
            clip: true

            property alias activeX: spatialCanvasWindow.activeGridX
            property alias activeY: spatialCanvasWindow.activeGridY
            property alias isOverview: spatialCanvasWindow.isOverview
            property real zoomScale: isOverview ? 0.33 : 1.0

            readonly property real stepX: Math.round(width * 0.88)
            readonly property real stepY: Math.round(height * 0.96)
            readonly property real cardWidth: Math.round(width * 0.72)
            readonly property real cardHeight: Math.round(height * 0.70)

            MouseArea {
                anchors.fill: parent
                z: 0
                onClicked: {
                    if (!spatialCanvasWindow.isOverview) {
                        spatialCanvasWindow.zoomToOverview()
                    } else {
                        spatialCanvasWindow.closeRequested()
                    }
                }
                onWheel: (wheel) => {
                    if (!spatialCanvasWindow.isOverview && wheel.angleDelta.y > 0) {
                        return
                    }
                    if (wheel.angleDelta.y < 0) {
                        spatialCanvasWindow.zoomToOverview()
                    } else if (wheel.angleDelta.y > 0) {
                        spatialCanvasWindow.zoomToNode(spatialCanvasWindow.activeGridX, spatialCanvasWindow.activeGridY)
                    }
                }
            }

            // Outer Zoom Rig
            Item {
                id: cameraZoomRig
                anchors.fill: parent
                z: 1

                transform: Scale {
                    origin.x: cameraZoomRig.width / 2
                    origin.y: cameraZoomRig.height / 2
                    xScale: viewport.zoomScale
                    yScale: viewport.zoomScale
                    Behavior on xScale {
                        NumberAnimation {
                            duration: 550
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                        }
                    }
                    Behavior on yScale {
                        NumberAnimation {
                            duration: 550
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                        }
                    }
                }

                // Inner World Pan
                Item {
                    id: spatialWorld
                    width: viewport.width
                    height: viewport.height

                    x: spatialCanvasWindow.isOverview ? (-spatialCanvasWindow.activeGridX * viewport.stepX * 0.12) : (-spatialCanvasWindow.activeGridX * viewport.stepX)
                    y: spatialCanvasWindow.isOverview ? (-spatialCanvasWindow.activeGridY * viewport.stepY * 0.12) : (-spatialCanvasWindow.activeGridY * viewport.stepY)

                    Behavior on x {
                        NumberAnimation {
                            duration: 550
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 550
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.16, 1.0, 0.3, 1.0, 1.0, 1.0]
                        }
                    }

                    // ══════════════════════════════════════════════════════════
                    // 1. NODE (0, 0) :: WORKSPACE BLUEPRINT (Center)
                    // ══════════════════════════════════════════════════════════
                    Rectangle {
                        id: cardNode0_0
                        readonly property int nodeX: 0
                        readonly property int nodeY: 0
                        readonly property bool isCurrentTarget: (spatialCanvasWindow.activeGridX === cardNode0_0.nodeX && spatialCanvasWindow.activeGridY === cardNode0_0.nodeY)
                        readonly property string cardIcon: "grid_view"
                        readonly property string cardTitle: "Workspace Blueprint"
                        readonly property string cardSubtitle: "3x3 Virtual Desktops & Live Windows"

                        width: viewport.cardWidth
                        height: viewport.cardHeight
                        x: Math.round((viewport.width - width) / 2 + (cardNode0_0.nodeX * viewport.stepX))
                        y: Math.round((viewport.height - height) / 2 + (cardNode0_0.nodeY * viewport.stepY))
                        radius: 22

                        color: cardNode0_0.isCurrentTarget ? Qt.rgba(16/255, 18/255, 26/255, 0.96) : Qt.rgba(13/255, 15/255, 22/255, 0.90)
                        border.width: cardNode0_0.isCurrentTarget && !viewport.isOverview ? 1.5 : 1
                        border.color: (cardNode0_0ClickArea.containsMouse || cardNode0_0.isCurrentTarget) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60) : Qt.rgba(255, 255, 255, 0.12)
                        clip: true

                        // Specular Highlight Line
                        Rectangle {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: Theme.px(22); anchors.rightMargin: Theme.px(22)
                            height: 1; color: Qt.rgba(255, 255, 255, 0.18); z: 5
                        }

                        // Header Bar
                        RowLayout {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.topMargin: Theme.px(14); anchors.leftMargin: Theme.px(22); anchors.rightMargin: Theme.px(22)
                            height: Theme.px(28); spacing: Theme.px(10); z: 10

                            CarbonLogoIcon {
                                Layout.preferredWidth: Theme.px(16)
                                Layout.preferredHeight: Theme.px(16)
                                Layout.alignment: Qt.AlignVCenter
                                color: cardNode0_0.isCurrentTarget ? Theme.primary : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.65)
                            }
                            Text { text: cardNode0_0.cardIcon; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(16); color: cardNode0_0.isCurrentTarget ? Theme.primary : Theme.fgDim }
                            Text { text: cardNode0_0.cardTitle; font.family: Theme.font; font.pixelSize: Theme.fontPx(13.5); font.bold: true; color: cardNode0_0.isCurrentTarget ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75) }

                            Rectangle {
                                Layout.preferredHeight: Theme.px(18); Layout.preferredWidth: cardNode0_0SubText.implicitWidth + Theme.px(12); radius: Theme.px(9)
                                color: Qt.rgba(255, 255, 255, 0.05); border.color: Qt.rgba(255, 255, 255, 0.08); border.width: 1
                                Text { id: cardNode0_0SubText; anchors.centerIn: parent; text: cardNode0_0.cardSubtitle; font.family: Theme.font; font.pixelSize: Theme.fontPx(9); font.weight: Font.Medium; color: Theme.fgDim }
                            }
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: cardNode0_0.isCurrentTarget && !spatialCanvasWindow.isOverview
                                Layout.preferredHeight: Theme.px(22); Layout.preferredWidth: cardNode0_0OverviewBtnText.implicitWidth + Theme.px(16); radius: Theme.px(11)
                                color: cardNode0_0OverviewArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(255, 255, 255, 0.06)
                                border.color: cardNode0_0OverviewArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : Qt.rgba(255, 255, 255, 0.12)
                                border.width: 1
                                Text { id: cardNode0_0OverviewBtnText; anchors.centerIn: parent; text: "Overview [ESC]"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: cardNode0_0OverviewArea.containsMouse ? Theme.primary : Theme.fgDim }
                                MouseArea { id: cardNode0_0OverviewArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToOverview() }
                            }
                        }

                        // Blueprint Inner Content
                        Item {
                            anchors.fill: parent; anchors.margins: Theme.px(16); anchors.topMargin: Theme.px(48); clip: true; z: 2

                            RowLayout {
                                anchors.fill: parent; spacing: Theme.px(14)

                                // 3x3 Grid (68% width)
                                Item {
                                    Layout.fillWidth: true; Layout.preferredWidth: Math.round(parent.width * 0.68); Layout.fillHeight: true

                                    GridLayout {
                                        anchors.fill: parent; columns: 3; rows: 3; columnSpacing: Theme.px(10); rowSpacing: Theme.px(10)

                                        Repeater {
                                            model: spatialCanvasWindow.getWorkspaces()
                                            Rectangle {
                                                id: wsTile
                                                Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(12)
                                                clip: true

                                                readonly property bool isActive: modelData.is_active
                                                readonly property bool hasWindows: modelData.windows && modelData.windows.length > 0
                                                readonly property bool isHovered: wsMouseArea.containsMouse

                                                opacity: (!hasWindows && !isActive && !isHovered) ? 0.38 : 1.0
                                                Behavior on opacity { NumberAnimation { duration: 160 } }

                                                color: (isActive || hasWindows)
                                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                                    : (isHovered
                                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                                        : Qt.rgba(14/255, 16/255, 23/255, 0.55))

                                                border.color: (isActive || hasWindows)
                                                    ? Theme.primary
                                                    : (isHovered
                                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.65)
                                                        : Qt.rgba(1, 1, 1, 0.05))

                                                border.width: isActive ? 1.5 : (hasWindows ? 1.2 : 1.0)

                                                Behavior on color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                                Behavior on border.color { ColorAnimation { duration: 160; easing.type: Easing.OutCubic } }
                                                Behavior on border.width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                                                // Top Specular Highlight on Tile
                                                Rectangle {
                                                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                                                    anchors.leftMargin: Theme.px(8); anchors.rightMargin: Theme.px(8)
                                                    height: 1
                                                    color: wsTile.isActive
                                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                                        : (wsTile.isHovered ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.08))
                                                    Behavior on color { ColorAnimation { duration: 160 } }
                                                }

                                                // Workspace Tile Header
                                                RowLayout {
                                                    anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                                                    anchors.topMargin: Theme.px(7); anchors.leftMargin: Theme.px(9); anchors.rightMargin: Theme.px(9)
                                                    height: Theme.px(18); spacing: Theme.px(5)

                                                    Text {
                                                        text: "WS " + (modelData.id < 10 ? "0" + modelData.id : modelData.id)
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(11.5)
                                                        font.bold: true
                                                        font.letterSpacing: 0.5
                                                        color: wsTile.isActive ? Theme.primary : (wsTile.isHovered ? Theme.primary : Theme.fg)
                                                        Behavior on color { ColorAnimation { duration: 160 } }
                                                    }

                                                    // Active status pill
                                                    Rectangle {
                                                        visible: wsTile.isActive
                                                        Layout.preferredHeight: Theme.px(13)
                                                        Layout.preferredWidth: activeTagText.implicitWidth + Theme.px(8)
                                                        radius: Theme.px(6.5)
                                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
                                                        border.width: 1

                                                        RowLayout {
                                                            anchors.centerIn: parent; spacing: Theme.px(3)
                                                            Rectangle { width: Theme.px(3.5); height: Theme.px(3.5); radius: Theme.px(2); color: Theme.primary }
                                                            Text {
                                                                id: activeTagText
                                                                text: "ACTIVE"
                                                                font.family: Theme.font
                                                                font.pixelSize: Theme.fontPx(7)
                                                                font.bold: true
                                                                color: Theme.primary
                                                            }
                                                        }
                                                    }

                                                    Item { Layout.fillWidth: true }

                                                    // Window count pill
                                                    Rectangle {
                                                        visible: wsTile.hasWindows
                                                        Layout.preferredHeight: Theme.px(15)
                                                        Layout.preferredWidth: winCountText.implicitWidth + Theme.px(9)
                                                        radius: Theme.px(7.5)
                                                        color: wsTile.isActive
                                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                                                            : Qt.rgba(255, 255, 255, 0.08)
                                                        border.color: wsTile.isActive
                                                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                                            : Qt.rgba(255, 255, 255, 0.12)
                                                        border.width: 1

                                                        Text {
                                                            id: winCountText
                                                            anchors.centerIn: parent
                                                            text: modelData.windows.length + (modelData.windows.length === 1 ? " win" : " wins")
                                                            font.family: Theme.font
                                                            font.pixelSize: Theme.fontPx(8)
                                                            font.bold: true
                                                            color: wsTile.isActive ? Theme.primary : Theme.fgDim
                                                        }
                                                    }
                                                }

                                                // Miniature window container
                                                Item {
                                                    id: miniArea
                                                    anchors.fill: parent
                                                    anchors.topMargin: Theme.px(28)
                                                    anchors.bottomMargin: Theme.px(6)
                                                    anchors.leftMargin: Theme.px(6)
                                                    anchors.rightMargin: Theme.px(6)
                                                    clip: true

                                                    // Soft empty workspace watermark
                                                    RowLayout {
                                                        anchors.centerIn: parent
                                                        visible: !wsTile.hasWindows
                                                        spacing: Theme.px(4)
                                                        opacity: wsTile.isHovered ? 0.65 : 0.28
                                                        Behavior on opacity { NumberAnimation { duration: 160 } }

                                                        Text {
                                                            text: "desktop_windows"
                                                            font.family: Theme.fontIcon
                                                            font.pixelSize: Theme.fontPx(13)
                                                            color: wsTile.isActive ? Theme.primary : Theme.fgDim
                                                        }
                                                        Text {
                                                            text: "Empty"
                                                            font.family: Theme.font
                                                            font.pixelSize: Theme.fontPx(9)
                                                            font.weight: Font.Medium
                                                            color: wsTile.isActive ? Theme.primary : Theme.fgDim
                                                        }
                                                    }

                                                    // Live window representations
                                                    Repeater {
                                                        model: modelData.windows || []
                                                        Rectangle {
                                                            id: winMini
                                                            readonly property real screenW: Screen.desktopAvailableWidth || Screen.width || 1366
                                                            readonly property real screenH: Screen.desktopAvailableHeight || Screen.height || 768
                                                            readonly property real normX: modelData.at ? Math.max(0, Math.min(0.9, modelData.at[0] / screenW)) : 0.05
                                                            readonly property real normY: modelData.at ? Math.max(0, Math.min(0.9, modelData.at[1] / screenH)) : 0.05
                                                            readonly property real normW: modelData.size ? Math.max(0.18, Math.min(0.95, modelData.size[0] / screenW)) : 0.45
                                                            readonly property real normH: modelData.size ? Math.max(0.18, Math.min(0.95, modelData.size[1] / screenH)) : 0.45

                                                            x: Math.round(normX * (miniArea.width - width))
                                                            y: Math.round(normY * (miniArea.height - height))
                                                            width: Math.max(Theme.px(36), Math.min(miniArea.width * 0.92, Math.round(normW * miniArea.width)))
                                                            height: Math.max(Theme.px(36), Math.min(miniArea.height * 0.92, Math.round(normH * miniArea.height)))
                                                            radius: Theme.px(6)

                                                            color: modelData.is_focused
                                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.32)
                                                                : (wsTile.isHovered
                                                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                                                    : Qt.rgba(255, 255, 255, 0.08))

                                                            border.color: modelData.is_focused
                                                                ? Theme.primary
                                                                : (wsTile.isHovered
                                                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                                                                    : Qt.rgba(255, 255, 255, 0.15))
                                                            border.width: modelData.is_focused ? 1.5 : 1

                                                            Behavior on color { ColorAnimation { duration: 150 } }
                                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                                            Image {
                                                                anchors.centerIn: parent
                                                                width: Math.min(parent.width - Theme.px(4), Theme.px(32))
                                                                height: Math.min(parent.height - Theme.px(4), Theme.px(32))
                                                                source: spatialCanvasWindow.resolveAppIcon(modelData.class)
                                                                sourceSize: Qt.size(32, 32)
                                                                fillMode: Image.PreserveAspectFit
                                                            }
                                                        }
                                                    }
                                                }

                                                // Seamless workspace interaction
                                                MouseArea {
                                                    id: wsMouseArea
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: spatialCanvasWindow.switchToWorkspace(modelData.id)
                                                }
                                            }
                                        }
                                    }
                                }

                                // Right: Opened Windows List (32% width)
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(parent.width * 0.32); Layout.fillHeight: true; spacing: Theme.px(8)

                                    RowLayout {
                                        Layout.fillWidth: true; height: Theme.px(22)
                                        Text {
                                            text: "OPENED APPLICATIONS"
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontPx(10)
                                            font.bold: true
                                            font.letterSpacing: 0.8
                                            color: Theme.primary
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            Layout.preferredHeight: Theme.px(18)
                                            Layout.preferredWidth: activeWinCountText.implicitWidth + Theme.px(12)
                                            radius: Theme.px(9)
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                                            border.width: 1

                                            Text {
                                                id: activeWinCountText
                                                anchors.centerIn: parent
                                                text: spatialCanvasWindow.allOpenWindows.length + " ACTIVE"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(8.5)
                                                font.bold: true
                                                color: Theme.primary
                                            }
                                        }
                                    }

                                    // Empty state when no windows are open
                                    Rectangle {
                                        visible: spatialCanvasWindow.allOpenWindows.length === 0
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(10)
                                        color: Qt.rgba(255, 255, 255, 0.03); border.color: Qt.rgba(255, 255, 255, 0.06); border.width: 1

                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: Theme.px(6)
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: "grid_off"
                                                font.family: Theme.fontIcon
                                                font.pixelSize: Theme.fontPx(28)
                                                color: Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.40)
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: "No Windows Open"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(10.5)
                                                font.bold: true
                                                color: Theme.fgDim
                                            }
                                        }
                                    }

                                    ListView {
                                        id: openedWinList
                                        visible: spatialCanvasWindow.allOpenWindows.length > 0
                                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: Theme.px(5)
                                        model: spatialCanvasWindow.filteredWindows

                                        delegate: Rectangle {
                                            id: appRowCard
                                            width: openedWinList.width; height: Theme.px(42); radius: Theme.px(8)

                                            readonly property bool isHovered: appRowArea.containsMouse

                                            color: isHovered
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                                                : Qt.rgba(255, 255, 255, 0.04)
                                            border.color: isHovered
                                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60)
                                                : Qt.rgba(255, 255, 255, 0.08)
                                            border.width: isHovered ? 1.5 : 1

                                            Behavior on color { ColorAnimation { duration: 150 } }
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            MouseArea {
                                                id: appRowArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (modelData.address) spatialCanvasWindow.execCommand("hyprctl dispatch focuswindow address:" + modelData.address);
                                                    spatialCanvasWindow.closeRequested();
                                                }
                                            }

                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: Theme.px(9); anchors.rightMargin: Theme.px(9); spacing: Theme.px(9)

                                                // Icon container
                                                Rectangle {
                                                    Layout.preferredWidth: Theme.px(26); Layout.preferredHeight: Theme.px(26); radius: Theme.px(6)
                                                    color: appRowCard.isHovered ? Qt.rgba(255, 255, 255, 0.12) : Qt.rgba(255, 255, 255, 0.06)
                                                    border.color: Qt.rgba(255, 255, 255, 0.10); border.width: 1
                                                    Behavior on color { ColorAnimation { duration: 150 } }

                                                    Image {
                                                        anchors.centerIn: parent
                                                        width: Theme.px(17); height: Theme.px(17)
                                                        source: spatialCanvasWindow.resolveAppIcon(modelData.class)
                                                        sourceSize: Qt.size(24, 24)
                                                        fillMode: Image.PreserveAspectFit
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: Theme.px(1)
                                                    Text {
                                                        text: modelData.class ? (modelData.class.charAt(0).toUpperCase() + modelData.class.slice(1)) : "App"
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(11)
                                                        font.bold: true
                                                        color: appRowCard.isHovered ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.88)
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                    Text {
                                                        text: modelData.title || ""
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(9)
                                                        color: Theme.fgDim
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }
                                                }

                                                Rectangle {
                                                    Layout.preferredHeight: Theme.px(19); Layout.preferredWidth: wsTagText.implicitWidth + Theme.px(12); radius: Theme.px(5)
                                                    color: appRowCard.isHovered
                                                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.30)
                                                        : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                                    border.width: 1

                                                    Text {
                                                        id: wsTagText
                                                        anchors.centerIn: parent
                                                        text: "WS " + (modelData.workspace ? (modelData.workspace.id || 1) : 1)
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(8)
                                                        font.bold: true
                                                        color: Theme.primary
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: cardNode0_0ClickArea
                            anchors.fill: parent; z: 90; enabled: viewport.isOverview || (!cardNode0_0.isCurrentTarget)
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToNode(cardNode0_0.nodeX, cardNode0_0.nodeY)
                        }

                    }

                    // ══════════════════════════════════════════════════════════
                    // 2. NODE (-1, 0) :: CONNECTIVITY HUB (Wi-Fi 6 + Bluetooth 5.3)
                    // ══════════════════════════════════════════════════════════
                    Rectangle {
                        id: cardNodeMinus1_0
                        readonly property int nodeX: -1
                        readonly property int nodeY: 0
                        readonly property bool isCurrentTarget: (spatialCanvasWindow.activeGridX === cardNodeMinus1_0.nodeX && spatialCanvasWindow.activeGridY === cardNodeMinus1_0.nodeY)
                        readonly property string cardIcon: "sensors"
                        readonly property string cardTitle: "Connectivity Hub"
                        readonly property string cardSubtitle: "Wi-Fi 6 & Bluetooth 5.3 Unified Controller"

                        width: viewport.cardWidth
                        height: viewport.cardHeight
                        x: Math.round((viewport.width - width) / 2 + (cardNodeMinus1_0.nodeX * viewport.stepX))
                        y: Math.round((viewport.height - height) / 2 + (cardNodeMinus1_0.nodeY * viewport.stepY))
                        radius: 22

                        color: cardNodeMinus1_0.isCurrentTarget ? Qt.rgba(16/255, 18/255, 26/255, 0.96) : Qt.rgba(13/255, 15/255, 22/255, 0.90)
                        border.width: cardNodeMinus1_0.isCurrentTarget && !viewport.isOverview ? 1.5 : 1
                        border.color: (cardNodeMinus1_0Hover.hovered || cardNodeMinus1_0.isCurrentTarget) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60) : Qt.rgba(255, 255, 255, 0.12)
                        clip: true

                        HoverHandler { id: cardNodeMinus1_0Hover }

                        // Specular Line
                        Rectangle {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: Theme.px(22); anchors.rightMargin: Theme.px(22)
                            height: 1; color: Qt.rgba(255, 255, 255, 0.18); z: 5
                        }

                        // Header Bar
                        RowLayout {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.topMargin: Theme.px(14); anchors.leftMargin: Theme.px(22); anchors.rightMargin: Theme.px(22)
                            height: Theme.px(28); spacing: Theme.px(10); z: 10

                            CarbonLogoIcon {
                                Layout.preferredWidth: Theme.px(16)
                                Layout.preferredHeight: Theme.px(16)
                                Layout.alignment: Qt.AlignVCenter
                                color: cardNodeMinus1_0.isCurrentTarget ? Theme.primary : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.65)
                            }
                            Text { text: cardNodeMinus1_0.cardIcon; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(16); color: cardNodeMinus1_0.isCurrentTarget ? Theme.primary : Theme.fgDim }
                            Text { text: cardNodeMinus1_0.cardTitle; font.family: Theme.font; font.pixelSize: Theme.fontPx(13.5); font.bold: true; color: cardNodeMinus1_0.isCurrentTarget ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75) }

                            Rectangle {
                                Layout.preferredHeight: Theme.px(18); Layout.preferredWidth: cardNodeMinus1_0SubText.implicitWidth + Theme.px(12); radius: Theme.px(9)
                                color: Qt.rgba(255, 255, 255, 0.05); border.color: Qt.rgba(255, 255, 255, 0.08); border.width: 1
                                Text { id: cardNodeMinus1_0SubText; anchors.centerIn: parent; text: cardNodeMinus1_0.cardSubtitle; font.family: Theme.font; font.pixelSize: Theme.fontPx(9); font.weight: Font.Medium; color: Theme.fgDim }
                            }
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: cardNodeMinus1_0.isCurrentTarget && !spatialCanvasWindow.isOverview
                                Layout.preferredHeight: Theme.px(22); Layout.preferredWidth: cardNodeMinus1_0OverviewBtnText.implicitWidth + Theme.px(16); radius: Theme.px(11)
                                color: cardNodeMinus1_0OverviewArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(255, 255, 255, 0.06)
                                border.color: cardNodeMinus1_0OverviewArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : Qt.rgba(255, 255, 255, 0.12)
                                border.width: 1
                                Text { id: cardNodeMinus1_0OverviewBtnText; anchors.centerIn: parent; text: "Overview [ESC]"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: cardNodeMinus1_0OverviewArea.containsMouse ? Theme.primary : Theme.fgDim }
                                MouseArea { id: cardNodeMinus1_0OverviewArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToOverview() }
                            }
                        }

                        // Connectivity Hub Dual-Deck (50% Wi-Fi, 50% Bluetooth)
                        Item {
                            anchors.fill: parent; anchors.margins: Theme.px(16); anchors.topMargin: Theme.px(48); clip: true; z: 2

                            RowLayout {
                                anchors.fill: parent; spacing: Theme.px(14)

                                // ─── LEFT DECK (50%): Wi-Fi Controller ───
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.px(10)

                                    // Active Wi-Fi Hero Card
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: Theme.px(120); radius: Theme.px(10)
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25); border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent; anchors.margins: Theme.px(12); spacing: Theme.px(8)

                                            RowLayout {
                                                spacing: Theme.px(10)
                                                Text {
                                                    text: (typeof WifiController !== "undefined" && WifiController && WifiController.currentSsid.length > 0) ? "wifi" : "wifi_off"
                                                    font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(28)
                                                    color: (typeof WifiController !== "undefined" && WifiController && WifiController.currentSsid.length > 0) ? Theme.primary : Theme.fgDim
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: Theme.px(1)
                                                    Text {
                                                        text: (typeof WifiController !== "undefined" && WifiController && WifiController.currentSsid.length > 0) ? WifiController.currentSsid : "Wi-Fi Disconnected"
                                                        font.family: Theme.font; font.pixelSize: Theme.fontPx(13.5); font.bold: true; color: Theme.fg; elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        text: (typeof WifiController !== "undefined" && WifiController && WifiController.currentSsid.length > 0) ? "Connected • Signal " + WifiController.currentSignal + "%" : "No active network"
                                                        font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9); color: Theme.primary
                                                    }
                                                }
                                            }

                                            // Signal Meter
                                            Rectangle {
                                                Layout.fillWidth: true; height: Theme.px(4); radius: Theme.px(2); color: Qt.rgba(255, 255, 255, 0.08)
                                                Rectangle {
                                                    height: parent.height; radius: parent.radius
                                                    width: Math.round(parent.width * (typeof WifiController !== "undefined" && WifiController ? (WifiController.currentSignal / 100.0) : 0))
                                                    color: Theme.primary
                                                }
                                            }

                                            // Action Buttons
                                            RowLayout {
                                                Layout.fillWidth: true; spacing: Theme.px(6)
                                                Rectangle {
                                                    Layout.fillWidth: true; height: Theme.px(26); radius: Theme.px(5)
                                                    color: wfTogHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                                                    border.color: Theme.primary; border.width: 1
                                                    HoverHandler { id: wfTogHov }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: if (typeof WifiController !== "undefined" && WifiController) WifiController.setEnabled(!WifiController.enabled)
                                                    }
                                                    Text { anchors.centerIn: parent; text: (typeof WifiController !== "undefined" && WifiController && WifiController.enabled) ? "Disable Wi-Fi" : "Enable Wi-Fi"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: Theme.primary }
                                                }
                                                Rectangle {
                                                    visible: typeof WifiController !== "undefined" && WifiController && WifiController.currentSsid.length > 0
                                                    Layout.preferredWidth: Theme.px(90); height: Theme.px(26); radius: Theme.px(5)
                                                    color: wfDiscHov.hovered ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.25) : Qt.rgba(255, 255, 255, 0.05)
                                                    border.color: wfDiscHov.hovered ? Theme.err : Qt.rgba(255, 255, 255, 0.10); border.width: 1
                                                    HoverHandler { id: wfDiscHov }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: if (typeof WifiController !== "undefined" && WifiController) WifiController.disconnectCurrent()
                                                    }
                                                    Text { anchors.centerIn: parent; text: "Disconnect"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: wfDiscHov.hovered ? Theme.err : Theme.fgDim }
                                                }
                                            }
                                        }
                                    }

                                    // Nearby Networks List
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "NEARBY WI-FI NETWORKS"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: Theme.primary }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: "RESCAN"
                                            font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(8.5); color: wfRescanHov.hovered ? Theme.primary : Theme.fgDim
                                            HoverHandler { id: wfRescanHov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: if (typeof WifiController !== "undefined" && WifiController) WifiController.refreshNetworks(true)
                                            }
                                        }
                                    }

                                    ListView {
                                        id: wifiListView
                                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: Theme.px(4)
                                        model: (typeof WifiController !== "undefined" && WifiController) ? WifiController.networks : []

                                        ScrollBar.vertical: ScrollBar { active: wifiListView.moving || wifiListView.dragging; policy: ScrollBar.AsNeeded }

                                        delegate: Rectangle {
                                            width: wifiListView.width; height: Theme.px(34); radius: Theme.px(5)
                                            color: wfNetHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : Qt.rgba(255, 255, 255, 0.03)
                                            border.color: modelData.connected ? Theme.primary : (wfNetHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) : Qt.rgba(255, 255, 255, 0.06))
                                            border.width: 1
                                            HoverHandler { id: wfNetHov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: if (typeof WifiController !== "undefined" && WifiController) WifiController.connectToNetwork(modelData.ssid)
                                            }
                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: Theme.px(8); anchors.rightMargin: Theme.px(8); spacing: Theme.px(8)
                                                Text {
                                                    text: modelData.signal > 60 ? "signal_wifi_4_bar" : (modelData.signal > 30 ? "network_wifi_3_bar" : "network_wifi_1_bar")
                                                    font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(14); color: modelData.connected ? Theme.primary : Theme.fgDim
                                                }
                                                Text {
                                                    Layout.fillWidth: true; text: modelData.ssid; font.family: Theme.font; font.pixelSize: Theme.fontPx(10.5); font.bold: modelData.connected
                                                    color: modelData.connected ? Theme.primary : Theme.fg; elide: Text.ElideRight
                                                }
                                                Text {
                                                    text: modelData.signal + "%"
                                                    font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(8.5); color: Theme.fgDim
                                                }
                                            }
                                        }
                                    }
                                }

                                // ─── RIGHT DECK (50%): Bluetooth Controller ───
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.px(10)

                                    // Bluetooth Controller Hero Card
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: Theme.px(120); radius: Theme.px(10)
                                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25); border.width: 1

                                        ColumnLayout {
                                            anchors.fill: parent; anchors.margins: Theme.px(12); spacing: Theme.px(8)

                                            RowLayout {
                                                spacing: Theme.px(10)
                                                Text {
                                                    text: spatialCanvasWindow.btPowerOn ? "bluetooth" : "bluetooth_disabled"
                                                    font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(28)
                                                    color: spatialCanvasWindow.btPowerOn ? Theme.accent : Theme.fgDim
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: Theme.px(1)
                                                    Text {
                                                        text: spatialCanvasWindow.btPowerOn ? "Bluetooth Adapter Active" : "Bluetooth Adapter Off"
                                                        font.family: Theme.font; font.pixelSize: Theme.fontPx(13.5); font.bold: true; color: Theme.fg; elide: Text.ElideRight
                                                    }
                                                    Text {
                                                        text: spatialCanvasWindow.btStatus.length > 0 ? spatialCanvasWindow.btStatus : (spatialCanvasWindow.btPowerOn ? "Discoverable & Ready" : "Hardware Radio Disabled")
                                                        font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9); color: Theme.accent
                                                    }
                                                }
                                            }

                                            // Action Buttons
                                            RowLayout {
                                                Layout.fillWidth: true; spacing: Theme.px(6)
                                                Rectangle {
                                                    Layout.fillWidth: true; height: Theme.px(26); radius: Theme.px(5)
                                                    color: btTogHov.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                                                    border.color: Theme.accent; border.width: 1
                                                    HoverHandler { id: btTogHov }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: spatialCanvasWindow.toggleBtPower()
                                                    }
                                                    Text { anchors.centerIn: parent; text: spatialCanvasWindow.btPowerOn ? "Turn Bluetooth Off" : "Turn Bluetooth On"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: Theme.accent }
                                                }
                                                Rectangle {
                                                    visible: spatialCanvasWindow.btPowerOn
                                                    Layout.preferredWidth: Theme.px(90); height: Theme.px(26); radius: Theme.px(5)
                                                    color: btScanHov.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : Qt.rgba(255, 255, 255, 0.05)
                                                    border.color: btScanHov.hovered ? Theme.accent : Qt.rgba(255, 255, 255, 0.10); border.width: 1
                                                    HoverHandler { id: btScanHov }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: spatialCanvasWindow.scanBluetooth()
                                                    }
                                                    Text { anchors.centerIn: parent; text: spatialCanvasWindow.btScanning ? "Scanning..." : "Scan"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: Theme.accent }
                                                }
                                            }
                                        }
                                    }

                                    // Paired & Discovered Devices List
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Text { text: "BLUETOOTH DEVICES"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: Theme.accent }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: spatialCanvasWindow.btDevices.length + " FOUND"
                                            font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(8.5); color: Theme.fgDim
                                        }
                                    }

                                    ListView {
                                        id: btListView
                                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: Theme.px(4)
                                        model: spatialCanvasWindow.btDevices

                                        ScrollBar.vertical: ScrollBar { active: btListView.moving || btListView.dragging; policy: ScrollBar.AsNeeded }

                                        delegate: Rectangle {
                                            width: btListView.width; height: Theme.px(38); radius: Theme.px(5)
                                            color: btDevHov.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12) : Qt.rgba(255, 255, 255, 0.03)
                                            border.color: modelData.connected ? Theme.accent : (btDevHov.hovered ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35) : Qt.rgba(255, 255, 255, 0.06))
                                            border.width: 1
                                            HoverHandler { id: btDevHov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: spatialCanvasWindow.toggleBtDevice(modelData.mac, modelData.connected, modelData.paired)
                                            }
                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: Theme.px(8); anchors.rightMargin: Theme.px(8); spacing: Theme.px(8)
                                                Text {
                                                    text: spatialCanvasWindow.resolveBtIcon(modelData.name)
                                                    font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(16); color: modelData.connected ? Theme.accent : Theme.fgDim
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: Theme.px(1)
                                                    Text { text: modelData.name || modelData.mac; font.family: Theme.font; font.pixelSize: Theme.fontPx(10.5); font.bold: modelData.connected; color: modelData.connected ? Theme.accent : Theme.fg; elide: Text.ElideRight }
                                                    Text { text: modelData.mac; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(8); color: Theme.fgDim }
                                                }
                                                Rectangle {
                                                    visible: modelData.connected || modelData.paired
                                                    Layout.preferredHeight: Theme.px(16); Layout.preferredWidth: btTagText.implicitWidth + Theme.px(8); radius: Theme.px(3)
                                                    color: modelData.connected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : Qt.rgba(255, 255, 255, 0.08)
                                                    Text { id: btTagText; anchors.centerIn: parent; text: modelData.connected ? "CONNECTED" : "PAIRED"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(7.5); font.bold: true; color: modelData.connected ? Theme.accent : Theme.fgDim }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; z: 90; enabled: viewport.isOverview || (!cardNodeMinus1_0.isCurrentTarget)
                            cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToNode(cardNodeMinus1_0.nodeX, cardNodeMinus1_0.nodeY)
                        }
                    }

                    // ══════════════════════════════════════════════════════════
                    // 3. NODE (1, 0) :: CARBON ENGINE & WALLPAPER STUDIO (Right)
                    // ══════════════════════════════════════════════════════════
                    Rectangle {
                        id: cardNode1_0
                        readonly property int nodeX: 1
                        readonly property int nodeY: 0
                        readonly property bool isCurrentTarget: (spatialCanvasWindow.activeGridX === cardNode1_0.nodeX && spatialCanvasWindow.activeGridY === cardNode1_0.nodeY)
                        readonly property string cardIcon: "tune"
                        readonly property string cardTitle: "Carbon Engine"
                        readonly property string cardSubtitle: "Wallpaper Studio & Theme Palette"

                        width: viewport.cardWidth
                        height: viewport.cardHeight
                        x: Math.round((viewport.width - width) / 2 + (cardNode1_0.nodeX * viewport.stepX))
                        y: Math.round((viewport.height - height) / 2 + (cardNode1_0.nodeY * viewport.stepY))
                        radius: 22

                        color: cardNode1_0.isCurrentTarget ? Qt.rgba(16/255, 18/255, 26/255, 0.96) : Qt.rgba(13/255, 15/255, 22/255, 0.90)
                        border.width: cardNode1_0.isCurrentTarget && !viewport.isOverview ? 1.5 : 1
                        border.color: (cardNode1_0Hover.hovered || cardNode1_0.isCurrentTarget) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60) : Qt.rgba(255, 255, 255, 0.12)
                        clip: true

                        HoverHandler { id: cardNode1_0Hover }

                        // Specular Highlight Line
                        Rectangle {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: Theme.px(22); anchors.rightMargin: Theme.px(22)
                            height: 1; color: Qt.rgba(255, 255, 255, 0.18); z: 5
                        }

                        // Header Bar
                        RowLayout {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.topMargin: Theme.px(14); anchors.leftMargin: Theme.px(22); anchors.rightMargin: Theme.px(22)
                            height: Theme.px(28); spacing: Theme.px(10); z: 10

                            CarbonLogoIcon {
                                Layout.preferredWidth: Theme.px(16)
                                Layout.preferredHeight: Theme.px(16)
                                Layout.alignment: Qt.AlignVCenter
                                color: cardNode1_0.isCurrentTarget ? Theme.primary : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.65)
                            }
                            Text { text: cardNode1_0.cardIcon; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(16); color: cardNode1_0.isCurrentTarget ? Theme.primary : Theme.fgDim }
                            Text { text: cardNode1_0.cardTitle; font.family: Theme.font; font.pixelSize: Theme.fontPx(13.5); font.bold: true; color: cardNode1_0.isCurrentTarget ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75) }

                            Rectangle {
                                Layout.preferredHeight: Theme.px(18); Layout.preferredWidth: cardNode1_0SubText.implicitWidth + Theme.px(12); radius: Theme.px(9)
                                color: Qt.rgba(255, 255, 255, 0.05); border.color: Qt.rgba(255, 255, 255, 0.08); border.width: 1
                                Text { id: cardNode1_0SubText; anchors.centerIn: parent; text: cardNode1_0.cardSubtitle; font.family: Theme.font; font.pixelSize: Theme.fontPx(9); font.weight: Font.Medium; color: Theme.fgDim }
                            }
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: cardNode1_0.isCurrentTarget && !spatialCanvasWindow.isOverview
                                Layout.preferredHeight: Theme.px(22); Layout.preferredWidth: cardNode1_0OverviewBtnText.implicitWidth + Theme.px(16); radius: Theme.px(11)
                                color: cardNode1_0OverviewArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(255, 255, 255, 0.06)
                                border.color: cardNode1_0OverviewArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : Qt.rgba(255, 255, 255, 0.12)
                                border.width: 1
                                Text { id: cardNode1_0OverviewBtnText; anchors.centerIn: parent; text: "Overview [ESC]"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: cardNode1_0OverviewArea.containsMouse ? Theme.primary : Theme.fgDim }
                                MouseArea { id: cardNode1_0OverviewArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToOverview() }
                            }
                        }

                        // Engine Inner Content
                        Item {
                            anchors.fill: parent; anchors.margins: Theme.px(16); anchors.topMargin: Theme.px(48); clip: true; z: 2

                            RowLayout {
                                anchors.fill: parent; spacing: Theme.px(16)

                                // ─── LEFT SIDE (36%): Hero Active Preview & Controls ───
                                ColumnLayout {
                                    Layout.preferredWidth: Math.round(parent.width * 0.36); Layout.fillHeight: true; spacing: Theme.px(10)

                                    // Active Wallpaper Preview
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: Theme.px(150); radius: Theme.px(10)
                                        color: "#050608"; border.color: Qt.rgba(255, 255, 255, 0.14); border.width: 1; clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: "file://" + (spatialCanvasWindow.currentWallpaperPath || (Quickshell.env("HOME") || "") + "/.config/hypr/current_wallpaper")
                                            fillMode: Image.PreserveAspectCrop; cache: false
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            gradient: Gradient {
                                                orientation: Gradient.Vertical
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.75) }
                                            }
                                        }

                                        ColumnLayout {
                                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                                            anchors.margins: Theme.px(10); spacing: Theme.px(2)
                                            RowLayout {
                                                spacing: Theme.px(6)
                                                Text { text: "image"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(14); color: Theme.primary }
                                                Text { text: "ACTIVE WALLPAPER"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9); font.bold: true; color: Theme.fg }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                text: (spatialCanvasWindow.currentWallpaperPath ? spatialCanvasWindow.currentWallpaperPath.substring(spatialCanvasWindow.currentWallpaperPath.lastIndexOf("/") + 1) : "current_wallpaper")
                                                font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(8.5); color: Theme.fgDim; elide: Text.ElideMiddle
                                            }
                                        }
                                    }

                                    // Action Buttons: Random & Open Folder
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Theme.px(6)

                                        Rectangle {
                                            Layout.fillWidth: true; height: Theme.px(28); radius: Theme.px(6)
                                            color: randWpHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                            border.color: Theme.primary; border.width: 1
                                            HoverHandler { id: randWpHov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: spatialCanvasWindow.setRandomWallpaper()
                                            }
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: Theme.px(4)
                                                Text { text: "shuffle"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(13); color: Theme.primary }
                                                Text { text: "Random"; font.family: Theme.font; font.pixelSize: Theme.fontPx(10); font.bold: true; color: Theme.primary }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true; height: Theme.px(28); radius: Theme.px(6)
                                            color: openFolHov.hovered ? Qt.rgba(255, 255, 255, 0.10) : Qt.rgba(255, 255, 255, 0.05)
                                            border.color: Qt.rgba(255, 255, 255, 0.12); border.width: 1
                                            HoverHandler { id: openFolHov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: spatialCanvasWindow.execCommand("xdg-open ~/Pictures/Wallpapers")
                                            }
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: Theme.px(4)
                                                Text { text: "folder_open"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(13); color: Theme.fg }
                                                Text { text: "Open Folder"; font.family: Theme.font; font.pixelSize: Theme.fontPx(10); color: Theme.fg }
                                            }
                                        }
                                    }

                                    // Shell Modes
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: Theme.px(4)
                                        Text { text: "SHELL ARCHITECTURE"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9); font.bold: true; color: Theme.primary }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Theme.px(6)
                                            Repeater {
                                                model: [
                                                    { id: "notch", name: "Notch", icon: "dock_to_bottom" },
                                                    { id: "vanish", name: "Vanish", icon: "visibility_off" },
                                                    { id: "minimal", name: "Minimal", icon: "horizontal_rule" }
                                                ]
                                                Rectangle {
                                                    id: modeCard
                                                    Layout.fillWidth: true; Layout.preferredHeight: Theme.px(28); radius: Theme.px(5)
                                                    readonly property bool isActive: (spatialCanvasWindow.barMode === modelData.id)
                                                    color: modeCard.isActive ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : (modeHov.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04))
                                                    border.color: modeCard.isActive ? Theme.primary : Qt.rgba(255, 255, 255, 0.10); border.width: 1
                                                    HoverHandler { id: modeHov }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.applyBarMode(modelData.id) }
                                                    RowLayout {
                                                        anchors.centerIn: parent; spacing: Theme.px(4)
                                                        Text { text: modelData.icon; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(12); color: modeCard.isActive ? Theme.primary : Theme.fgDim }
                                                        Text { text: modelData.name; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: modeCard.isActive; color: modeCard.isActive ? Theme.fg : Theme.fgDim }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Extracted Matugen Palette
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: Theme.px(4)
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text { text: "MATUGEN PALETTE"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9); font.bold: true; color: Theme.primary }
                                            Item { Layout.fillWidth: true }
                                            Text {
                                                text: "REGEN"
                                                font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(8.5); color: palRegenHov.hovered ? Theme.primary : Theme.fgDim
                                                HoverHandler { id: palRegenHov }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        spatialCanvasWindow.execCommand("python3 ~/.config/hypr/scripts/theme-mk.py ~/.config/hypr/current_wallpaper");
                                                        spatialCanvasWindow.triggerThemeReload();
                                                        spatialCanvasWindow.showFeedback("Regenerating theme...");
                                                    }
                                                }
                                            }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true; spacing: Theme.px(6)
                                            Repeater {
                                                model: [
                                                    { name: "Primary", col: Theme.primary },
                                                    { name: "Accent", col: Theme.accent },
                                                    { name: "Surface", col: Theme.surface },
                                                    { name: "Container", col: Theme.container },
                                                    { name: "Muted", col: Theme.fgDim },
                                                    { name: "Error", col: Theme.err }
                                                ]
                                                Rectangle {
                                                    width: Theme.px(22); height: Theme.px(22); radius: Theme.px(11); color: modelData.col
                                                    border.color: Qt.rgba(255, 255, 255, 0.25); border.width: 1
                                                }
                                            }
                                        }
                                    }

                                    Item { Layout.fillHeight: true }
                                }

                                // ─── RIGHT SIDE (64%): Visual Wallpaper Thumbnail Grid ───
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.px(8)

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Theme.px(6)
                                        Text { text: "photo_library"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(14); color: Theme.primary }
                                        Text { text: "WALLPAPERS DISCOVERY"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(10.5); font.bold: true; color: Theme.fg }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: (spatialCanvasWindow.wallpaperList.length) + " WALLPAPERS"
                                            font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9); color: Theme.fgDim
                                        }
                                        Text {
                                            text: "• RESCAN"
                                            font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(8.5); color: wpRescanHov.hovered ? Theme.primary : Theme.fgDim
                                            HoverHandler { id: wpRescanHov }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.refreshWallpapers() }
                                        }
                                    }

                                    GridView {
                                        id: wpGridView
                                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                                        cellWidth: Math.floor(width / 3); cellHeight: Math.floor(cellWidth * 0.65)
                                        model: spatialCanvasWindow.wallpaperList

                                        ScrollBar.vertical: ScrollBar { active: wpGridView.moving || wpGridView.dragging; policy: ScrollBar.AsNeeded }

                                        delegate: Rectangle {
                                            width: wpGridView.cellWidth - Theme.px(6); height: wpGridView.cellHeight - Theme.px(6)
                                            radius: Theme.px(8); color: "#08090d"
                                            readonly property bool isCurrentWp: (spatialCanvasWindow.currentWallpaperPath === modelData)
                                            border.color: isCurrentWp ? Theme.primary : (wpItemHov.hovered ? Theme.primary : Qt.rgba(255, 255, 255, 0.10))
                                            border.width: isCurrentWp || wpItemHov.hovered ? 2 : 1
                                            clip: true

                                            HoverHandler { id: wpItemHov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: spatialCanvasWindow.applyWallpaper(modelData)
                                            }

                                            Image {
                                                anchors.fill: parent; source: "file://" + modelData
                                                sourceSize: Qt.size(180, 110); fillMode: Image.PreserveAspectCrop; asynchronous: true
                                            }

                                            Rectangle {
                                                anchors.fill: parent
                                                color: wpItemHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : "transparent"
                                            }

                                            // Active badge
                                            Rectangle {
                                                visible: isCurrentWp
                                                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: Theme.px(6)
                                                height: Theme.px(16); width: activeWpText.implicitWidth + Theme.px(10); radius: Theme.px(4)
                                                color: Theme.primary
                                                Text { id: activeWpText; anchors.centerIn: parent; text: "ACTIVE"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(7.5); font.bold: true; color: "#000" }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; z: 90; enabled: viewport.isOverview || (!cardNode1_0.isCurrentTarget)
                            cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToNode(cardNode1_0.nodeX, cardNode1_0.nodeY)
                        }
                    }

                    // ══════════════════════════════════════════════════════════
                    // 4. NODE (0, -1) :: AESTHETIC QUICK FILE BROWSER (Top)
                    // ══════════════════════════════════════════════════════════
                    Rectangle {
                        id: cardNode0_Minus1
                        readonly property int nodeX: 0
                        readonly property int nodeY: -1
                        readonly property bool isCurrentTarget: (spatialCanvasWindow.activeGridX === cardNode0_Minus1.nodeX && spatialCanvasWindow.activeGridY === cardNode0_Minus1.nodeY)
                        readonly property string cardIcon: "folder_open"
                        readonly property string cardTitle: "Quick File Browser"
                        readonly property string cardSubtitle: "Interactive Filesystem, Quick Places & Storage Deck"

                        width: viewport.cardWidth
                        height: viewport.cardHeight
                        x: Math.round((viewport.width - width) / 2 + (cardNode0_Minus1.nodeX * viewport.stepX))
                        y: Math.round((viewport.height - height) / 2 + (cardNode0_Minus1.nodeY * viewport.stepY))
                        radius: 22

                        color: cardNode0_Minus1.isCurrentTarget ? Qt.rgba(16/255, 18/255, 26/255, 0.96) : Qt.rgba(13/255, 15/255, 22/255, 0.90)
                        border.width: cardNode0_Minus1.isCurrentTarget && !viewport.isOverview ? 1.5 : 1
                        border.color: (cardNode0_Minus1Hover.hovered || cardNode0_Minus1.isCurrentTarget) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60) : Qt.rgba(255, 255, 255, 0.12)
                        clip: true

                        HoverHandler { id: cardNode0_Minus1Hover }

                        // Specular Line
                        Rectangle {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: Theme.px(22); anchors.rightMargin: Theme.px(22)
                            height: 1; color: Qt.rgba(255, 255, 255, 0.18); z: 5
                        }

                        // Header Bar
                        RowLayout {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.topMargin: Theme.px(14); anchors.leftMargin: Theme.px(22); anchors.rightMargin: Theme.px(22)
                            height: Theme.px(28); spacing: Theme.px(10); z: 10

                            CarbonLogoIcon {
                                Layout.preferredWidth: Theme.px(16)
                                Layout.preferredHeight: Theme.px(16)
                                Layout.alignment: Qt.AlignVCenter
                                color: cardNode0_Minus1.isCurrentTarget ? Theme.primary : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.65)
                            }
                            Text { text: cardNode0_Minus1.cardIcon; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(16); color: cardNode0_Minus1.isCurrentTarget ? Theme.primary : Theme.fgDim }
                            Text { text: cardNode0_Minus1.cardTitle; font.family: Theme.font; font.pixelSize: Theme.fontPx(13.5); font.bold: true; color: cardNode0_Minus1.isCurrentTarget ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75) }

                            Rectangle {
                                Layout.preferredHeight: Theme.px(18); Layout.preferredWidth: cardNode0_Minus1SubText.implicitWidth + Theme.px(12); radius: Theme.px(9)
                                color: Qt.rgba(255, 255, 255, 0.05); border.color: Qt.rgba(255, 255, 255, 0.08); border.width: 1
                                Text { id: cardNode0_Minus1SubText; anchors.centerIn: parent; text: cardNode0_Minus1.cardSubtitle; font.family: Theme.font; font.pixelSize: Theme.fontPx(9); font.weight: Font.Medium; color: Theme.fgDim }
                            }
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: cardNode0_Minus1.isCurrentTarget && !spatialCanvasWindow.isOverview
                                Layout.preferredHeight: Theme.px(22); Layout.preferredWidth: cardNode0_Minus1OverviewBtnText.implicitWidth + Theme.px(16); radius: Theme.px(11)
                                color: cardNode0_Minus1OverviewArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(255, 255, 255, 0.06)
                                border.color: cardNode0_Minus1OverviewArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : Qt.rgba(255, 255, 255, 0.12)
                                border.width: 1
                                Text { id: cardNode0_Minus1OverviewBtnText; anchors.centerIn: parent; text: "Overview [ESC]"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: cardNode0_Minus1OverviewArea.containsMouse ? Theme.primary : Theme.fgDim }
                                MouseArea { id: cardNode0_Minus1OverviewArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToOverview() }
                            }
                        }

                        // File Browser Inner Content
                        Item {
                            anchors.fill: parent; anchors.margins: Theme.px(16); anchors.topMargin: Theme.px(48); clip: true; z: 2

                            ColumnLayout {
                                anchors.fill: parent; spacing: Theme.px(10)

                                // Top Interactive Breadcrumb & Actions Bar
                                RowLayout {
                                    Layout.fillWidth: true; spacing: Theme.px(8)

                                    // Up Arrow
                                    Rectangle {
                                        Layout.preferredHeight: Theme.px(28); Layout.preferredWidth: Theme.px(28); radius: Theme.px(6)
                                        color: fbUpHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : Qt.rgba(255, 255, 255, 0.05)
                                        border.color: Qt.rgba(255, 255, 255, 0.10); border.width: 1
                                        HoverHandler { id: fbUpHov }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var cur = spatialCanvasWindow.currentBrowserPath;
                                                var parentPath = cur.substring(0, cur.lastIndexOf("/")) || "/";
                                                spatialCanvasWindow.currentBrowserPath = parentPath;
                                            }
                                        }
                                        Text { anchors.centerIn: parent; text: "arrow_upward"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(14); color: Theme.primary }
                                    }

                                    // Breadcrumb Pills Bar
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: Theme.px(28); radius: Theme.px(6)
                                        color: Qt.rgba(255, 255, 255, 0.04); border.color: Qt.rgba(255, 255, 255, 0.08); border.width: 1; clip: true

                                        ListView {
                                            anchors.fill: parent; anchors.leftMargin: Theme.px(8); anchors.rightMargin: Theme.px(8)
                                            orientation: ListView.Horizontal; spacing: Theme.px(4); model: spatialCanvasWindow.pathSegments

                                            delegate: RowLayout {
                                                spacing: Theme.px(4)
                                                Rectangle {
                                                    Layout.preferredHeight: Theme.px(20); Layout.preferredWidth: pillText.implicitWidth + Theme.px(10); radius: Theme.px(4)
                                                    color: pillHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : "transparent"
                                                    HoverHandler { id: pillHov }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.currentBrowserPath = modelData.path }
                                                    Text { id: pillText; anchors.centerIn: parent; text: modelData.name; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9.5); color: pillHov.hovered ? Theme.primary : Theme.fg }
                                                }
                                                Text { text: "/"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9); color: Theme.fgDim; visible: index < spatialCanvasWindow.pathSegments.length - 1 }
                                            }
                                        }
                                    }

                                    // Terminal & File Manager Quick Launchers
                                    Rectangle {
                                        Layout.preferredHeight: Theme.px(28); Layout.preferredWidth: termBtnText.implicitWidth + Theme.px(16); radius: Theme.px(6)
                                        color: termHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : Qt.rgba(255, 255, 255, 0.05)
                                        border.color: Qt.rgba(255, 255, 255, 0.12); border.width: 1
                                        HoverHandler { id: termHov }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                spatialCanvasWindow.execCommand("kitty --working-directory \"" + spatialCanvasWindow.currentBrowserPath + "\"");
                                                spatialCanvasWindow.closeRequested();
                                            }
                                        }
                                        RowLayout {
                                            anchors.centerIn: parent; spacing: Theme.px(4)
                                            Text { text: "terminal"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(13); color: Theme.primary }
                                            Text { id: termBtnText; text: "Terminal"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: Theme.fg }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredHeight: Theme.px(28); Layout.preferredWidth: fmBtnText.implicitWidth + Theme.px(16); radius: Theme.px(6)
                                        color: fmHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                                        border.color: Theme.primary; border.width: 1
                                        HoverHandler { id: fmHov }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                spatialCanvasWindow.execCommand("xdg-open \"" + spatialCanvasWindow.currentBrowserPath + "\"");
                                                spatialCanvasWindow.closeRequested();
                                            }
                                        }
                                        RowLayout {
                                            anchors.centerIn: parent; spacing: Theme.px(4)
                                            Text { text: "folder_open"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(13); color: Theme.primary }
                                            Text { id: fmBtnText; text: "File Manager"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: Theme.primary }
                                        }
                                    }
                                }

                                // Main Split: Quick Places (24%) + File Grid (76%)
                                RowLayout {
                                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.px(12)

                                    // Quick Places Sidebar
                                    ColumnLayout {
                                        Layout.preferredWidth: Theme.px(175)
                                        Layout.maximumWidth: Theme.px(185)
                                        Layout.fillHeight: true
                                        spacing: Theme.px(4)

                                        Text { text: "QUICK PLACES"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(9); font.bold: true; color: Theme.primary }

                                        Repeater {
                                            model: spatialCanvasWindow.quickPlaces
                                            Rectangle {
                                                Layout.fillWidth: true; Layout.preferredHeight: Theme.px(30); radius: Theme.px(6)
                                                readonly property bool isCur: (spatialCanvasWindow.currentBrowserPath === modelData.path)
                                                color: isCur ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : (plHov.hovered ? Qt.rgba(255, 255, 255, 0.06) : "transparent")
                                                border.color: isCur ? Theme.primary : "transparent"; border.width: 1
                                                HoverHandler { id: plHov }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.currentBrowserPath = modelData.path }

                                                RowLayout {
                                                    anchors.fill: parent; anchors.leftMargin: Theme.px(8); spacing: Theme.px(8)
                                                    Text { text: modelData.icon; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(14); color: modelData.color }
                                                    Text { text: modelData.name; font.family: Theme.font; font.pixelSize: Theme.fontPx(10.5); font.bold: isCur; color: isCur ? Theme.fg : Theme.fgDim }
                                                }
                                            }
                                        }

                                        Item { Layout.fillHeight: true }

                                        // Storage Capacity Meter
                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: Theme.px(4)
                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text { text: "STORAGE DECK"; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(8.5); font.bold: true; color: Theme.primary }
                                                Item { Layout.fillWidth: true }
                                                Text { text: spatialCanvasWindow.storageUsageText; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(8); color: Theme.fgDim }
                                            }
                                            Rectangle {
                                                Layout.fillWidth: true; height: Theme.px(5); radius: Theme.px(2.5); color: Qt.rgba(255, 255, 255, 0.08)
                                                Rectangle {
                                                    height: parent.height; radius: parent.radius
                                                    width: Math.round(parent.width * spatialCanvasWindow.storageUsageFraction)
                                                    color: Theme.primary
                                                }
                                            }
                                        }
                                    }

                                    // Visual File Grid
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true

                                        // Empty state placeholder
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            visible: !spatialCanvasWindow.currentBrowserFiles || spatialCanvasWindow.currentBrowserFiles.length === 0
                                            spacing: Theme.px(6)
                                            Text { Layout.alignment: Qt.AlignHCenter; text: "folder_open"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(32); color: Qt.rgba(255, 255, 255, 0.20) }
                                            Text { Layout.alignment: Qt.AlignHCenter; text: "Empty directory or loading..."; font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(10); color: Theme.fgDim }
                                        }

                                        GridView {
                                            id: fileGridView
                                            anchors.fill: parent
                                            clip: true
                                            cellWidth: Math.floor(width / 3)
                                            cellHeight: Theme.px(64)
                                            model: spatialCanvasWindow.currentBrowserFiles

                                            ScrollBar.vertical: ScrollBar { active: fileGridView.moving || fileGridView.dragging; policy: ScrollBar.AsNeeded }

                                            delegate: Rectangle {
                                                width: fileGridView.cellWidth - Theme.px(6); height: fileGridView.cellHeight - Theme.px(6)
                                                radius: Theme.px(7)
                                                color: fHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14) : Qt.rgba(255, 255, 255, 0.04)
                                                border.color: fHov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45) : Qt.rgba(255, 255, 255, 0.08)
                                                border.width: 1

                                                HoverHandler { id: fHov }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        if (modelData.isDir) {
                                                            var cur = spatialCanvasWindow.currentBrowserPath;
                                                            spatialCanvasWindow.currentBrowserPath = (cur === "/" ? "" : cur) + "/" + modelData.name;
                                                        } else {
                                                            var full = spatialCanvasWindow.currentBrowserPath + "/" + modelData.name;
                                                            spatialCanvasWindow.execCommand("xdg-open \"" + full + "\"");
                                                            spatialCanvasWindow.closeRequested();
                                                        }
                                                    }
                                                }

                                                RowLayout {
                                                    anchors.fill: parent; anchors.margins: Theme.px(8); spacing: Theme.px(8)

                                                    Rectangle {
                                                        Layout.preferredWidth: Theme.px(34); Layout.preferredHeight: Theme.px(34); radius: Theme.px(6)
                                                        color: Qt.rgba(255, 255, 255, 0.06)
                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: spatialCanvasWindow.getFileIcon(modelData.name, modelData.isDir)
                                                            font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(18)
                                                            color: spatialCanvasWindow.getFileColor(modelData.name, modelData.isDir)
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true; spacing: Theme.px(1)
                                                        Text {
                                                            Layout.fillWidth: true; text: modelData.name; font.family: Theme.font; font.pixelSize: Theme.fontPx(10.5); font.bold: modelData.isDir
                                                            color: fHov.hovered ? Theme.primary : Theme.fg; elide: Text.ElideMiddle
                                                        }
                                                        Text {
                                                            text: modelData.isDir ? "Directory" : (modelData.size > 0 ? (Math.round(modelData.size / 1024) + " KB") : "Empty file")
                                                            font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(8); color: Theme.fgDim
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; z: 90; enabled: viewport.isOverview || (!cardNode0_Minus1.isCurrentTarget)
                            cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToNode(cardNode0_Minus1.nodeX, cardNode0_Minus1.nodeY)
                        }
                    }

                    // ══════════════════════════════════════════════════════════
                    // 5. NODE (0, 1) :: SYSTEM CONTROL DECK (Media & Session Power) (Bottom)
                    // ══════════════════════════════════════════════════════════
                    Rectangle {
                        id: cardNode0_1
                        readonly property int nodeX: 0
                        readonly property int nodeY: 1
                        readonly property bool isCurrentTarget: (spatialCanvasWindow.activeGridX === cardNode0_1.nodeX && spatialCanvasWindow.activeGridY === cardNode0_1.nodeY)
                        readonly property string cardIcon: "power_settings_new"
                        readonly property string cardTitle: "System Control Deck"
                        readonly property string cardSubtitle: "Notifications Log & Session Power"

                        width: viewport.cardWidth
                        height: viewport.cardHeight
                        x: Math.round((viewport.width - width) / 2 + (cardNode0_1.nodeX * viewport.stepX))
                        y: Math.round((viewport.height - height) / 2 + (cardNode0_1.nodeY * viewport.stepY))
                        radius: 22

                        color: cardNode0_1.isCurrentTarget ? Qt.rgba(16/255, 18/255, 26/255, 0.96) : Qt.rgba(13/255, 15/255, 22/255, 0.90)
                        border.width: cardNode0_1.isCurrentTarget && !viewport.isOverview ? 1.5 : 1
                        border.color: (cardNode0_1Hover.hovered || cardNode0_1.isCurrentTarget) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.60) : Qt.rgba(255, 255, 255, 0.12)
                        clip: true

                        HoverHandler { id: cardNode0_1Hover }

                        // Specular Line
                        Rectangle {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.leftMargin: Theme.px(22); anchors.rightMargin: Theme.px(22)
                            height: 1; color: Qt.rgba(255, 255, 255, 0.18); z: 5
                        }

                        // Header Bar
                        RowLayout {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
                            anchors.topMargin: Theme.px(14); anchors.leftMargin: Theme.px(22); anchors.rightMargin: Theme.px(22)
                            height: Theme.px(28); spacing: Theme.px(10); z: 10

                            CarbonLogoIcon {
                                Layout.preferredWidth: Theme.px(16)
                                Layout.preferredHeight: Theme.px(16)
                                Layout.alignment: Qt.AlignVCenter
                                color: cardNode0_1.isCurrentTarget ? Theme.primary : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.65)
                            }
                            Text { text: cardNode0_1.cardIcon; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(16); color: cardNode0_1.isCurrentTarget ? Theme.primary : Theme.fgDim }
                            Text { text: cardNode0_1.cardTitle; font.family: Theme.font; font.pixelSize: Theme.fontPx(13.5); font.bold: true; color: cardNode0_1.isCurrentTarget ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.75) }

                            Rectangle {
                                Layout.preferredHeight: Theme.px(18); Layout.preferredWidth: cardNode0_1SubText.implicitWidth + Theme.px(12); radius: Theme.px(9)
                                color: Qt.rgba(255, 255, 255, 0.05); border.color: Qt.rgba(255, 255, 255, 0.08); border.width: 1
                                Text { id: cardNode0_1SubText; anchors.centerIn: parent; text: cardNode0_1.cardSubtitle; font.family: Theme.font; font.pixelSize: Theme.fontPx(9); font.weight: Font.Medium; color: Theme.fgDim }
                            }
                            Item { Layout.fillWidth: true }

                            Rectangle {
                                visible: cardNode0_1.isCurrentTarget && !spatialCanvasWindow.isOverview
                                Layout.preferredHeight: Theme.px(22); Layout.preferredWidth: cardNode0_1OverviewBtnText.implicitWidth + Theme.px(16); radius: Theme.px(11)
                                color: cardNode0_1OverviewArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : Qt.rgba(255, 255, 255, 0.06)
                                border.color: cardNode0_1OverviewArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : Qt.rgba(255, 255, 255, 0.12)
                                border.width: 1
                                Text { id: cardNode0_1OverviewBtnText; anchors.centerIn: parent; text: "Overview [ESC]"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); font.bold: true; color: cardNode0_1OverviewArea.containsMouse ? Theme.primary : Theme.fgDim }
                                MouseArea { id: cardNode0_1OverviewArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToOverview() }
                            }
                        }

                        // System Deck Inner Content (Notifications Left ~38%, Session Power Right ~62%)
                        Item {
                            anchors.fill: parent; anchors.margins: Theme.px(16); anchors.topMargin: Theme.px(48); clip: true; z: 2

                            RowLayout {
                                anchors.fill: parent; spacing: Theme.px(16)

                                // ─── COLUMN 1 (38%): Live Notification Log & DND ───
                                ColumnLayout {
                                    Layout.preferredWidth: 38; Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.px(8)

                                    // Notifications Container Card
                                    Rectangle {
                                        id: notifPanelContainer
                                        Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(14)
                                        color: Qt.rgba(14/255, 16/255, 24/255, 0.85)
                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22); border.width: 1
                                        clip: true

                                        // Intercept ALL wheel events in the notification panel so they NEVER bubble to canvas zoom
                                        WheelHandler {
                                            id: notifPanelWheel
                                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                            onWheel: (event) => {
                                                if (notifListView.visible && notifListView.contentHeight > notifListView.height) {
                                                    var delta = -event.angleDelta.y * 0.75
                                                    var maxY = Math.max(0, notifListView.contentHeight - notifListView.height)
                                                    notifListView.contentY = Math.max(0, Math.min(maxY, notifListView.contentY + delta))
                                                }
                                                event.accepted = true
                                            }
                                        }

                                        ColumnLayout {
                                            anchors.fill: parent; anchors.margins: Theme.px(14); spacing: Theme.px(10)

                                            // ── Header Bar ──
                                            RowLayout {
                                                Layout.fillWidth: true; spacing: Theme.px(8)

                                                Text {
                                                    text: "notifications"
                                                    font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(17); color: Theme.primary
                                                }

                                                Text {
                                                    text: "Notifications"
                                                    font.family: Theme.font; font.pixelSize: Theme.fontPx(13.5); font.bold: true; color: Theme.fg
                                                }

                                                // Unread count pill
                                                Rectangle {
                                                    visible: NotificationService.unreadCount > 0
                                                    Layout.preferredHeight: Theme.px(20); Layout.preferredWidth: notifCountText.implicitWidth + Theme.px(12); radius: Theme.px(10)
                                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                                    border.color: Theme.primary; border.width: 1

                                                    Text {
                                                        id: notifCountText
                                                        anchors.centerIn: parent
                                                        text: NotificationService.unreadCount + " NEW"
                                                        font.family: Theme.font; font.pixelSize: Theme.fontPx(9); font.bold: true; color: Theme.primary
                                                    }
                                                }

                                                Item { Layout.fillWidth: true }

                                                // [ DND ] Toggle Pill / Tile
                                                Rectangle {
                                                    id: dndTileBtn
                                                    readonly property bool active: NotificationService.dnd || GlobalState.doNotDisturb
                                                    Layout.preferredHeight: Theme.px(24); Layout.preferredWidth: dndPillRow.implicitWidth + Theme.px(16); radius: Theme.px(12)
                                                    color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (dndHov.hovered ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04))
                                                    border.color: active ? Theme.primary : (dndHov.hovered ? Qt.rgba(255, 255, 255, 0.25) : Qt.rgba(255, 255, 255, 0.10))
                                                    border.width: 1
                                                    HoverHandler { id: dndHov }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: NotificationService.toggleDnd()
                                                    }
                                                    RowLayout {
                                                        id: dndPillRow
                                                        anchors.centerIn: parent; spacing: Theme.px(5)
                                                        Text {
                                                            text: dndTileBtn.active ? "notifications_off" : "notifications"
                                                            font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(13)
                                                            color: dndTileBtn.active ? Theme.primary : (dndHov.hovered ? Theme.fg : Theme.fgDim)
                                                        }
                                                        Text {
                                                            text: dndTileBtn.active ? "DND On" : "DND"
                                                            font.family: Theme.font; font.pixelSize: Theme.fontPx(10.5); font.bold: true
                                                            color: dndTileBtn.active ? Theme.primary : (dndHov.hovered ? Theme.fg : Theme.fgDim)
                                                        }
                                                    }
                                                }

                                                // [ Clear All ] Button
                                                Rectangle {
                                                    visible: NotificationService.list.length > 0
                                                    Layout.preferredHeight: Theme.px(24); Layout.preferredWidth: clearAllText.implicitWidth + Theme.px(16); radius: Theme.px(12)
                                                    color: clearAllHov.hovered ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.20) : Qt.rgba(255, 255, 255, 0.04)
                                                    border.color: clearAllHov.hovered ? Theme.err : Qt.rgba(255, 255, 255, 0.10); border.width: 1
                                                    HoverHandler { id: clearAllHov }
                                                    MouseArea {
                                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                        onClicked: NotificationService.clearAll()
                                                    }
                                                    Text {
                                                        id: clearAllText
                                                        anchors.centerIn: parent
                                                        text: "Clear All"
                                                        font.family: Theme.font; font.pixelSize: Theme.fontPx(10); font.bold: true
                                                        color: clearAllHov.hovered ? Theme.err : Theme.fgDim
                                                    }
                                                }
                                            }

                                            // ── Empty State ──
                                            Item {
                                                Layout.fillWidth: true; Layout.fillHeight: true
                                                visible: NotificationService.list.length === 0

                                                ColumnLayout {
                                                    anchors.centerIn: parent; spacing: Theme.px(8)

                                                    Rectangle {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        width: Theme.px(48); height: Theme.px(48); radius: Theme.px(24)
                                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22); border.width: 1

                                                        Text {
                                                            anchors.centerIn: parent
                                                            text: "notifications_none"
                                                            font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(22); color: Theme.primary
                                                        }
                                                    }

                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: "No Notifications"
                                                        font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.bold: true; color: Theme.fgDim
                                                    }

                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: "Incoming alerts and messages log here"
                                                        font.family: Theme.font; font.pixelSize: Theme.fontPx(10); color: Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.50)
                                                    }
                                                }
                                            }

                                            // ── Scrollable Notification List ──
                                            ListView {
                                                id: notifListView
                                                Layout.fillWidth: true; Layout.fillHeight: true
                                                visible: NotificationService.list.length > 0
                                                clip: true; spacing: Theme.px(8); boundsBehavior: Flickable.StopAtBounds
                                                model: NotificationService.list

                                                delegate: Rectangle {
                                                    id: notifCard
                                                    required property var modelData
                                                    required property int index

                                                    width: notifListView.width
                                                    implicitHeight: notifCardCol.implicitHeight + Theme.px(16)
                                                    radius: Theme.px(10)
                                                    color: notifCardHov.hovered ? Qt.rgba(255, 255, 255, 0.06) : Qt.rgba(255, 255, 255, 0.03)
                                                    border.color: notifCardHov.hovered ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                                                    border.width: 1

                                                    HoverHandler { id: notifCardHov }

                                                    ColumnLayout {
                                                        id: notifCardCol
                                                        anchors.fill: parent; anchors.margins: Theme.px(10); spacing: Theme.px(4)

                                                        // Header: App icon, appName, time, and dismiss X
                                                        RowLayout {
                                                            Layout.fillWidth: true; spacing: Theme.px(6)

                                                            // App Icon
                                                            Item {
                                                                Layout.preferredWidth: Theme.px(16); Layout.preferredHeight: Theme.px(16)

                                                                Rectangle {
                                                                    anchors.centerIn: parent
                                                                    width: Theme.px(6); height: Theme.px(6); radius: Theme.px(3)
                                                                    color: Theme.primary
                                                                    visible: !cardAppIcon.visible
                                                                }

                                                                Image {
                                                                    id: cardAppIcon
                                                                    anchors.fill: parent
                                                                    source: modelData.appIcon || ""
                                                                    sourceSize: Qt.size(Theme.px(16), Theme.px(16))
                                                                    fillMode: Image.PreserveAspectFit
                                                                    visible: !!source && status === Image.Ready
                                                                }
                                                            }

                                                            Text {
                                                                text: modelData.appName || "System"
                                                                font.family: Theme.font; font.pixelSize: Theme.fontPx(11); font.bold: true; color: Theme.primary
                                                                elide: Text.ElideRight; Layout.maximumWidth: Theme.px(130)
                                                            }

                                                            Text {
                                                                text: "• " + (modelData.timeStr || "now")
                                                                font.family: Theme.font; font.pixelSize: Theme.fontPx(10); color: Theme.fgDim
                                                            }

                                                            Item { Layout.fillWidth: true }

                                                            // Dismiss X button
                                                            Rectangle {
                                                                width: Theme.px(18); height: Theme.px(18); radius: Theme.px(9)
                                                                color: dismissHov.hovered ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.25) : "transparent"
                                                                opacity: notifCardHov.hovered ? 1.0 : 0.0
                                                                HoverHandler { id: dismissHov }
                                                                MouseArea {
                                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                                    onClicked: NotificationService.dismissNotification(modelData.id)
                                                                }
                                                                Text {
                                                                    anchors.centerIn: parent
                                                                    text: "close"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(12)
                                                                    color: dismissHov.hovered ? Theme.err : Theme.fgDim
                                                                }
                                                            }
                                                        }

                                                        // Summary
                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: modelData.summary || ""
                                                            font.family: Theme.font; font.pixelSize: Theme.fontPx(11.5); font.bold: true; color: Theme.fg
                                                            elide: Text.ElideRight; maximumLineCount: 1; visible: text.length > 0
                                                        }

                                                        // Body
                                                        Text {
                                                            Layout.fillWidth: true
                                                            text: modelData.body || ""
                                                            font.family: Theme.font; font.pixelSize: Theme.fontPx(10); color: Theme.fgDim
                                                            elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap; visible: text.length > 0
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ─── COLUMN 2 (62%): Session Power & System Deck ───
                                ColumnLayout {
                                    Layout.preferredWidth: 62; Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.px(12)

                                    // Hero Digital Clock & Host Telemetry Card
                                    Rectangle {
                                        Layout.fillWidth: true; Layout.preferredHeight: Theme.px(115); radius: Theme.px(14)
                                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22); border.width: 1

                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: Theme.px(3)
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: Qt.formatTime(new Date(), "HH:mm")
                                                font.family: Theme.fontMono || "monospace"; font.pixelSize: Theme.fontPx(38); font.bold: true; color: Theme.primary
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: Qt.formatDate(new Date(), "dddd, MMMM d, yyyy")
                                                font.family: Theme.font; font.pixelSize: Theme.fontPx(11.5); font.bold: true; color: Theme.fg
                                            }
                                            Text {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: spatialCanvasWindow.systemUptime + " • shogun@Raid"
                                                font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); color: Theme.fgDim
                                            }
                                        }
                                    }

                                    // 4 Power Actions (2x2 Expanded Grid)
                                    GridLayout {
                                        Layout.fillWidth: true; Layout.fillHeight: true; columns: 2; columnSpacing: Theme.px(10); rowSpacing: Theme.px(10)

                                        // 1. Lock Screen
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(12)
                                            color: p1Hov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : Qt.rgba(255, 255, 255, 0.04)
                                            border.color: p1Hov.hovered ? Theme.primary : Qt.rgba(255, 255, 255, 0.10); border.width: 1
                                            HoverHandler { id: p1Hov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { spatialCanvasWindow.execCommand("hyprlock"); spatialCanvasWindow.closeRequested(); }
                                            }
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: Theme.px(12)
                                                Rectangle {
                                                    width: Theme.px(38); height: Theme.px(38); radius: Theme.px(19)
                                                    color: p1Hov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(255, 255, 255, 0.06)
                                                    Text { anchors.centerIn: parent; text: "lock"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(20); color: Theme.primary }
                                                }
                                                ColumnLayout {
                                                    spacing: Theme.px(2)
                                                    Text { text: "Lock Screen"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.bold: true; color: Theme.fg }
                                                    Text { text: "Secure workstation & display"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); color: Theme.fgDim }
                                                }
                                            }
                                        }

                                        // 2. Suspend
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(12)
                                            color: p2Hov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : Qt.rgba(255, 255, 255, 0.04)
                                            border.color: p2Hov.hovered ? Theme.primary : Qt.rgba(255, 255, 255, 0.10); border.width: 1
                                            HoverHandler { id: p2Hov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { spatialCanvasWindow.execCommand("systemctl suspend"); spatialCanvasWindow.closeRequested(); }
                                            }
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: Theme.px(12)
                                                Rectangle {
                                                    width: Theme.px(38); height: Theme.px(38); radius: Theme.px(19)
                                                    color: p2Hov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(255, 255, 255, 0.06)
                                                    Text { anchors.centerIn: parent; text: "bedtime"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(20); color: Theme.primary }
                                                }
                                                ColumnLayout {
                                                    spacing: Theme.px(2)
                                                    Text { text: "Suspend"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.bold: true; color: Theme.fg }
                                                    Text { text: "Low-power sleep state"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); color: Theme.fgDim }
                                                }
                                            }
                                        }

                                        // 3. Reboot
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(12)
                                            color: p3Hov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : Qt.rgba(255, 255, 255, 0.04)
                                            border.color: p3Hov.hovered ? Theme.primary : Qt.rgba(255, 255, 255, 0.10); border.width: 1
                                            HoverHandler { id: p3Hov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { spatialCanvasWindow.execCommand("systemctl reboot"); spatialCanvasWindow.closeRequested(); }
                                            }
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: Theme.px(12)
                                                Rectangle {
                                                    width: Theme.px(38); height: Theme.px(38); radius: Theme.px(19)
                                                    color: p3Hov.hovered ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(255, 255, 255, 0.06)
                                                    Text { anchors.centerIn: parent; text: "restart_alt"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(20); color: Theme.primary }
                                                }
                                                ColumnLayout {
                                                    spacing: Theme.px(2)
                                                    Text { text: "Reboot System"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.bold: true; color: Theme.fg }
                                                    Text { text: "Restart operating system"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); color: Theme.fgDim }
                                                }
                                            }
                                        }

                                        // 4. Power Off
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(12)
                                            color: p4Hov.hovered ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.22) : Qt.rgba(255, 255, 255, 0.04)
                                            border.color: p4Hov.hovered ? Theme.err : Qt.rgba(255, 255, 255, 0.10); border.width: 1
                                            HoverHandler { id: p4Hov }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: { spatialCanvasWindow.execCommand("systemctl poweroff"); spatialCanvasWindow.closeRequested(); }
                                            }
                                            RowLayout {
                                                anchors.centerIn: parent; spacing: Theme.px(12)
                                                Rectangle {
                                                    width: Theme.px(38); height: Theme.px(38); radius: Theme.px(19)
                                                    color: p4Hov.hovered ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.35) : Qt.rgba(255, 255, 255, 0.06)
                                                    Text { anchors.centerIn: parent; text: "power_settings_new"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(20); color: p4Hov.hovered ? Theme.err : Theme.fgDim }
                                                }
                                                ColumnLayout {
                                                    spacing: Theme.px(2)
                                                    Text { text: "Power Off"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.bold: true; color: p4Hov.hovered ? Theme.err : Theme.fg }
                                                    Text { text: "Shut down system cleanly"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); color: Theme.fgDim }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent; z: 90; enabled: viewport.isOverview || (!cardNode0_1.isCurrentTarget)
                            cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToNode(cardNode0_1.nodeX, cardNode0_1.nodeY)
                        }
                    }

                } // spatialWorld
            } // cameraZoomRig
        } // viewport

        // ══════════════════════════════════════════════════════════════════
        // FLOATING MINIMAP & OVERVIEW HUD (Bottom Center)
        // ══════════════════════════════════════════════════════════════════
        Rectangle {
            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: Theme.px(16)
            height: Theme.px(42); width: hudRow.implicitWidth + Theme.px(28); radius: Theme.px(21)
            color: Qt.rgba(10/255, 12/255, 18/255, 0.88)
            border.color: Qt.rgba(255, 255, 255, 0.14); border.width: 1; z: 95

            RowLayout {
                id: hudRow
                anchors.centerIn: parent; spacing: Theme.px(12)

                // 5-Node Mini Cross Indicators
                RowLayout {
                    spacing: Theme.px(4)

                    // Node Top: (0, -1) Files
                    Rectangle {
                        id: hTop
                        width: Theme.px(26); height: Theme.px(26); radius: Theme.px(13)
                        readonly property bool isActive: (spatialCanvasWindow.activeGridX === 0 && spatialCanvasWindow.activeGridY === -1)
                        color: hTop.isActive ? Theme.primary : Qt.rgba(255, 255, 255, 0.08)
                        HoverHandler { id: mTopHov }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToNode(0, -1) }
                        Text { anchors.centerIn: parent; text: "folder"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(13); color: hTop.isActive ? "#000" : Theme.fg }
                    }

                    // Node Left: (-1, 0) Connectivity
                    Rectangle {
                        id: hLeft
                        width: Theme.px(26); height: Theme.px(26); radius: Theme.px(13)
                        readonly property bool isActive: (spatialCanvasWindow.activeGridX === -1 && spatialCanvasWindow.activeGridY === 0)
                        color: hLeft.isActive ? Theme.primary : Qt.rgba(255, 255, 255, 0.08)
                        HoverHandler { id: mLeftHov }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToNode(-1, 0) }
                        Text { anchors.centerIn: parent; text: "sensors"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(13); color: hLeft.isActive ? "#000" : Theme.fg }
                    }

                    // Node Center: (0, 0) Workspaces
                    Rectangle {
                        id: hCent
                        width: Theme.px(26); height: Theme.px(26); radius: Theme.px(13)
                        readonly property bool isActive: (spatialCanvasWindow.activeGridX === 0 && spatialCanvasWindow.activeGridY === 0)
                        color: hCent.isActive ? Theme.primary : Qt.rgba(255, 255, 255, 0.08)
                        HoverHandler { id: mCentHov }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToNode(0, 0) }
                        Text { anchors.centerIn: parent; text: "grid_view"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(13); color: hCent.isActive ? "#000" : Theme.fg }
                    }

                    // Node Right: (1, 0) Wallpapers & Engine
                    Rectangle {
                        id: hRight
                        width: Theme.px(26); height: Theme.px(26); radius: Theme.px(13)
                        readonly property bool isActive: (spatialCanvasWindow.activeGridX === 1 && spatialCanvasWindow.activeGridY === 0)
                        color: hRight.isActive ? Theme.primary : Qt.rgba(255, 255, 255, 0.08)
                        HoverHandler { id: mRightHov }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToNode(1, 0) }
                        Text { anchors.centerIn: parent; text: "tune"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(13); color: hRight.isActive ? "#000" : Theme.fg }
                    }

                    // Node Bottom: (0, 1) System & Media
                    Rectangle {
                        id: hBot
                        width: Theme.px(26); height: Theme.px(26); radius: Theme.px(13)
                        readonly property bool isActive: (spatialCanvasWindow.activeGridX === 0 && spatialCanvasWindow.activeGridY === 1)
                        color: hBot.isActive ? Theme.primary : Qt.rgba(255, 255, 255, 0.08)
                        HoverHandler { id: mBotHov }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: spatialCanvasWindow.zoomToNode(0, 1) }
                        Text { anchors.centerIn: parent; text: "power_settings_new"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(13); color: hBot.isActive ? "#000" : Theme.fg }
                    }
                }

                // Vertical Divider
                Rectangle { Layout.preferredHeight: Theme.px(18); Layout.preferredWidth: 1; color: Qt.rgba(255, 255, 255, 0.15) }

                // Mode / Focus Title
                Text {
                    text: spatialCanvasWindow.isOverview ? "5-NODE OVERVIEW" : spatialCanvasWindow.getNodeTitle(spatialCanvasWindow.activeGridX, spatialCanvasWindow.activeGridY)
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(10.5)
                    font.bold: true
                    font.letterSpacing: 0.8
                    color: Theme.primary
                }

                // Overview Toggle Button
                Rectangle {
                    id: hudTogBtn
                    Layout.preferredHeight: Theme.px(22); Layout.preferredWidth: hudToggleText.implicitWidth + Theme.px(16); radius: Theme.px(11)
                    color: hudTogArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : Qt.rgba(255, 255, 255, 0.06)
                    border.color: hudTogArea.containsMouse ? Theme.primary : Qt.rgba(255, 255, 255, 0.12); border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: hudTogArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (spatialCanvasWindow.isOverview) spatialCanvasWindow.zoomToNode(spatialCanvasWindow.activeGridX, spatialCanvasWindow.activeGridY);
                            else spatialCanvasWindow.zoomToOverview();
                        }
                    }
                    Text {
                        id: hudToggleText
                        anchors.centerIn: parent
                        text: spatialCanvasWindow.isOverview ? "Zoom Focus" : "Overview"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(9)
                        font.bold: true
                        color: hudTogArea.containsMouse ? Theme.primary : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════
        // TOAST FEEDBACK NOTIFIER
        // ══════════════════════════════════════════════════════════════════
        Rectangle {
            anchors.top: parent.top; anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: Theme.px(24)
            visible: spatialCanvasWindow.feedbackMessage.length > 0
            height: Theme.px(32); width: toastText.implicitWidth + Theme.px(28); radius: Theme.px(16)
            color: Qt.rgba(14/255, 16/255, 24/255, 0.94)
            border.color: Theme.primary; border.width: 1; z: 99

            RowLayout {
                anchors.centerIn: parent; spacing: Theme.px(8)
                Text { text: "check_circle"; font.family: Theme.fontIcon; font.pixelSize: Theme.fontPx(14); color: Theme.primary }
                Text { id: toastText; text: spatialCanvasWindow.feedbackMessage; font.family: Theme.font; font.pixelSize: Theme.fontPx(11); font.bold: true; color: Theme.fg }
            }
        }

    } // container
}
