import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * FocusHUD — Hyper-Tunnel Deep Work & Flow State Engine (SUPER + K)
 *
 * Slide-out minimalist control drawer from the left screen edge.
 * Provides full standalone QML timer + distraction/dimming control + acoustic
 * synthesis (Rain & Brown Noise) + persistent Schematic Checklist, while also
 * syncing with the native `carbon-focus-engine` daemon when installed.
 */
Item {
    id: focusHud

    property bool active: false
    property bool isRevealed: false

    // Settings synced with ~/.config/carbon/focus-settings.json (from Settings Hub -> Panels & Canvas)
    property bool leftEdgeHoverEnabled: true
    property bool waylandBlackout: true
    property string defaultSound: "none" // "none" | "rain" | "brown"

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("CARBON_CONFIG_DIR") || (focusHud.homeDir + "/.config/carbon")
    readonly property string tasksFilePath: focusHud.configDir + "/focus-tasks.json"
    readonly property string settingsFilePath: focusHud.configDir + "/focus-settings.json"

    // Focus Engine Telemetry State
    property string engineState: "Idle" // "Idle", "Focus", "Break"
    property int remainingSec: 25 * 60
    property int totalSec: 25 * 60
    property int focusDurationMin: 25
    property int breakDurationMin: 5
    property string activeAppClass: "Desktop"
    property string activeAppTitle: "No active window"
    property var distractedApps: ["discord", "vesktop", "steam", "lutris", "telegram-desktop", "slack", "spotify"]
    property int frozenCount: 0
    property string activeNoise: "none"
    property bool rustEngineConnected: false

    // Acoustic Isolation
    property bool playingRain: false
    property bool playingBrown: false

    // Persistent Tasks Model
    ListModel {
        id: tasksModel
        ListElement { title: "Complete UI Shader Polish"; done: false }
        ListElement { title: "Optimize Rust Event Loop"; done: false }
        ListElement { title: "Review Hyprland IPC Hooks"; done: true }
    }

    function saveTasks() {
        var arr = []
        for (var i = 0; i < tasksModel.count; i++) {
            var item = tasksModel.get(i)
            arr.push({ title: String(item.title || ""), done: Boolean(item.done) })
        }
        var jsonStr = JSON.stringify(arr, null, 2)
        Quickshell.execDetached([
            "python3", "-c",
            "import os, sys; p = os.path.expanduser(sys.argv[1]); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w', encoding='utf-8').write(sys.argv[2])",
            focusHud.tasksFilePath,
            jsonStr
        ])
    }

    function addTask(titleText) {
        var cleaned = String(titleText || "").trim()
        if (cleaned.length === 0) return
        tasksModel.append({ title: cleaned, done: false })
        saveTasks()
    }

    function removeTask(idx) {
        if (idx >= 0 && idx < tasksModel.count) {
            tasksModel.remove(idx)
            saveTasks()
        }
    }

    FileView {
        id: tasksFileView
        path: focusHud.tasksFilePath
        watchChanges: false
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                var txt = tasksFileView.text().trim()
                if (txt.length > 0) {
                    var parsed = JSON.parse(txt)
                    if (Array.isArray(parsed) && parsed.length > 0) {
                        tasksModel.clear()
                        for (var i = 0; i < parsed.length; i++) {
                            if (parsed[i] && parsed[i].title) {
                                tasksModel.append({
                                    title: String(parsed[i].title),
                                    done: Boolean(parsed[i].done)
                                })
                            }
                        }
                    }
                }
            } catch (e) {}
        }
    }

    FileView {
        id: focusSettingsFileView
        path: focusHud.settingsFilePath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: focusHud.applyFocusSettings(focusSettingsFileView.text())
        onFileChanged: {
            reload()
            focusHud.applyFocusSettings(focusSettingsFileView.text())
        }
    }

    function applyFocusSettings(txt) {
        if (!txt || txt.trim().length === 0) return
        try {
            var d = JSON.parse(txt)
            if (d.leftEdgeHover !== undefined) focusHud.leftEdgeHoverEnabled = Boolean(d.leftEdgeHover)
            if (d.waylandBlackout !== undefined) focusHud.waylandBlackout = Boolean(d.waylandBlackout)
            if (d.defaultSound !== undefined) focusHud.defaultSound = String(d.defaultSound)
            if (d.defaultFocusMin !== undefined) {
                var fm = parseInt(d.defaultFocusMin)
                if (!isNaN(fm) && fm >= 1 && fm <= 240) {
                    focusHud.focusDurationMin = fm
                    if (focusHud.engineState === "Idle") {
                        focusHud.remainingSec = fm * 60
                        focusHud.totalSec = fm * 60
                    }
                }
            }
            if (d.defaultBreakMin !== undefined) {
                var bm = parseInt(d.defaultBreakMin)
                if (!isNaN(bm) && bm >= 1 && bm <= 120) {
                    focusHud.breakDurationMin = bm
                }
            }
        } catch (e) {}
    }

    function saveFocusSettings() {
        var payload = JSON.stringify({
            leftEdgeHover: focusHud.leftEdgeHoverEnabled,
            waylandBlackout: focusHud.waylandBlackout,
            defaultFocusMin: focusHud.focusDurationMin,
            defaultBreakMin: focusHud.breakDurationMin,
            defaultSound: focusHud.defaultSound
        }, null, 2)
        Quickshell.execDetached([
            "python3", "-c",
            "import os, sys; p = os.path.expanduser(sys.argv[1]); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w', encoding='utf-8').write(sys.argv[2])",
            focusHud.settingsFilePath,
            payload
        ])
    }

    // Rain Audio Process (multi-backend fallback: mpv -> ffplay -> pw-play -> paplay -> synthesized rain)
    Process {
        id: rainAudioProc
        command: [
            "bash", "-c",
            "RAIN_FILE=\"${CARBON_CONFIG_DIR:-$HOME/.config/carbon}/assets/rain.mp3\"; " +
            "[ ! -f \"$RAIN_FILE\" ] && RAIN_FILE=\"$HOME/.local/share/quickshell/carbon/assets/rain.mp3\"; " +
            "if [ -f \"$RAIN_FILE\" ]; then " +
            "  if command -v mpv >/dev/null 2>&1; then exec mpv --no-video --loop=inf --volume=65 \"$RAIN_FILE\"; " +
            "  elif command -v ffplay >/dev/null 2>&1; then exec ffplay -nodisp -loop 0 -loglevel quiet \"$RAIN_FILE\"; " +
            "  elif command -v pw-play >/dev/null 2>&1; then while true; do pw-play \"$RAIN_FILE\" || break; done; " +
            "  elif command -v paplay >/dev/null 2>&1; then while true; do paplay \"$RAIN_FILE\" || break; done; fi; " +
            "fi; " +
            "if command -v ffplay >/dev/null 2>&1; then exec ffplay -nodisp -autoexit -loglevel quiet -f lavfi 'anoisesrc=c=pink:r=48000:a=0.06'; " +
            "elif command -v mpv >/dev/null 2>&1; then exec mpv --no-video --lavfi-complex='[anoisesrc=c=pink:r=48000:a=0.06[ao]]'; fi"
        ]
        running: focusHud.playingRain
        onExited: focusHud.playingRain = false
    }

    // Brown Noise Audio Process (multi-backend fallback: mpv lavfi-complex -> ffplay -> python PCM synthesizer)
    Process {
        id: brownAudioProc
        command: [
            "bash", "-c",
            "if command -v mpv >/dev/null 2>&1; then " +
            "  mpv --no-video --lavfi-complex='[anoisesrc=c=brown:r=48000:a=0.08[ao]]' >/dev/null 2>&1 && exit 0; " +
            "fi; " +
            "if command -v ffplay >/dev/null 2>&1; then " +
            "  exec ffplay -nodisp -autoexit -loglevel quiet -f lavfi 'anoisesrc=c=brown:r=48000:a=0.08'; " +
            "fi; " +
            "python3 -c 'import os, random, struct, subprocess; " +
            "cmd = [\"pw-cat\", \"-p\", \"--rate\", \"24000\", \"--channels\", \"1\", \"--format\", \"s16\", \"-\"] if os.system(\"command -v pw-cat >/dev/null 2>&1\") == 0 else [\"aplay\", \"-q\", \"-f\", \"S16_LE\", \"-r\", \"24000\", \"-c\", \"1\"]; " +
            "p = subprocess.Popen(cmd, stdin=subprocess.PIPE); val = 0.0\n" +
            "while True:\n" +
            "  buf = bytearray()\n" +
            "  for _ in range(4800):\n" +
            "    val = max(-1.0, min(1.0, (val + random.uniform(-0.08, 0.08)) * 0.98))\n" +
            "    buf += struct.pack(\"<h\", int(val * 3200))\n" +
            "  p.stdin.write(buf); p.stdin.flush()'"
        ]
        running: focusHud.playingBrown
        onExited: focusHud.playingBrown = false
    }

    // Built-in standalone QML Focus Timer (functions even when Rust carbon-focus-engine is not running)
    Timer {
        id: internalFocusTimer
        interval: 1000
        repeat: true
        running: !focusHud.rustEngineConnected && (focusHud.engineState === "Focus" || focusHud.engineState === "Break")
        onTriggered: {
            if (focusHud.remainingSec > 0) {
                focusHud.remainingSec -= 1
            } else {
                if (focusHud.engineState === "Focus") {
                    focusHud.startBreak()
                } else if (focusHud.engineState === "Break") {
                    focusHud.stopSession()
                }
            }
        }
    }

    // Active window poller for standalone mode
    Process {
        id: activeWinPollProc
        command: [
            "python3", "-c",
            "import json, subprocess\ntry:\n  out = subprocess.check_output(['hyprctl', 'activewindow', '-j'], stderr=subprocess.DEVNULL, timeout=1.0).decode()\n  d = json.loads(out)\n  print(json.dumps({'class': d.get('class') or 'Desktop', 'title': d.get('title') or 'No active window'}))\nexcept Exception:\n  print(json.dumps({'class': 'Desktop', 'title': 'No active window'}))"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text.trim())
                    if (parsed.class) focusHud.activeAppClass = parsed.class
                    if (parsed.title) focusHud.activeAppTitle = parsed.title
                } catch (e) {}
            }
        }
    }

    Timer {
        id: activeWinTimer
        interval: 2000
        repeat: true
        running: focusHud.visible && !focusHud.rustEngineConnected
        onTriggered: {
            if (!activeWinPollProc.running) activeWinPollProc.running = true
        }
    }

    // Rust Daemon Process (`carbon-focus-engine` if installed)
    Process {
        id: focusEngineProc
        command: [
            "bash", "-c",
            "if [ -x \"$HOME/.local/bin/carbon-focus-engine\" ]; then exec \"$HOME/.local/bin/carbon-focus-engine\"; " +
            "elif command -v carbon-focus-engine >/dev/null 2>&1; then exec carbon-focus-engine; " +
            "else exit 1; fi"
        ]
        running: true

        stdinEnabled: true

        stdout: SplitParser {
            onRead: data => {
                try {
                    var json = JSON.parse(data)
                    focusHud.rustEngineConnected = true
                    focusHud.engineState = json.state || "Idle"
                    focusHud.remainingSec = json.remaining_sec !== undefined ? json.remaining_sec : 1500
                    focusHud.totalSec = json.total_sec !== undefined ? json.total_sec : 1500
                    focusHud.focusDurationMin = json.focus_duration_min || 25
                    focusHud.breakDurationMin = json.break_duration_min || 5
                    focusHud.activeAppClass = json.active_app_class || "Desktop"
                    focusHud.activeAppTitle = json.active_app_title || ""
                    focusHud.distractedApps = json.distracted_apps || []
                    focusHud.frozenCount = json.frozen_pids_count || 0
                } catch (e) {}
            }
        }
        onExited: {
            focusHud.rustEngineConnected = false
        }
    }

    onVisibleChanged: {
        focusHud.isRevealed = visible
        if (visible && !focusHud.rustEngineConnected && !activeWinPollProc.running) {
            activeWinPollProc.running = true
        }
    }

    function sendCommand(cmdObj) {
        if (focusEngineProc.running && focusHud.rustEngineConnected) {
            focusEngineProc.write(JSON.stringify(cmdObj) + "\n")
        }
    }

    function applyWaylandDimming(enableDim) {
        if (enableDim && focusHud.waylandBlackout) {
            Quickshell.execDetached(["sh", "-c", "hyprctl keyword decoration:dim_inactive true >/dev/null 2>&1; hyprctl keyword decoration:dim_strength 0.65 >/dev/null 2>&1"])
        } else {
            Quickshell.execDetached(["sh", "-c", "hyprctl keyword decoration:dim_inactive false >/dev/null 2>&1"])
        }
    }

    function startFocus() {
        focusHud.engineState = "Focus"
        focusHud.totalSec = Math.max(1, focusHud.focusDurationMin) * 60
        focusHud.remainingSec = focusHud.totalSec
        applyWaylandDimming(true)
        if (focusHud.defaultSound === "rain" && !focusHud.playingRain) {
            focusHud.playingBrown = false
            focusHud.playingRain = true
            focusHud.activeNoise = "rain"
        } else if (focusHud.defaultSound === "brown" && !focusHud.playingBrown) {
            focusHud.playingRain = false
            focusHud.playingBrown = true
            focusHud.activeNoise = "brown"
        }
        sendCommand({ "action": "start_focus" })
    }

    function startBreak() {
        focusHud.engineState = "Break"
        focusHud.totalSec = Math.max(1, focusHud.breakDurationMin) * 60
        focusHud.remainingSec = focusHud.totalSec
        applyWaylandDimming(false)
        sendCommand({ "action": "start_break" })
    }

    function stopSession() {
        focusHud.engineState = "Idle"
        focusHud.totalSec = Math.max(1, focusHud.focusDurationMin) * 60
        focusHud.remainingSec = focusHud.totalSec
        applyWaylandDimming(false)
        sendCommand({ "action": "stop" })
    }

    function setFocusMins(mins) {
        var m = Math.max(1, Math.min(240, parseInt(mins) || 25))
        focusHud.focusDurationMin = m
        if (focusHud.engineState === "Idle") {
            focusHud.totalSec = m * 60
            focusHud.remainingSec = m * 60
        }
        saveFocusSettings()
        sendCommand({ "action": "set_focus_duration", "mins": m })
    }

    function setBreakMins(mins) {
        var m = Math.max(1, Math.min(120, parseInt(mins) || 5))
        focusHud.breakDurationMin = m
        saveFocusSettings()
        sendCommand({ "action": "set_break_duration", "mins": m })
    }

    function toggleNoise(type) {
        if (type === "rain") {
            if (focusHud.playingRain) {
                focusHud.playingRain = false
                focusHud.activeNoise = "none"
            } else {
                focusHud.playingBrown = false
                focusHud.playingRain = true
                focusHud.activeNoise = "rain"
            }
            return
        }

        if (type === "brown") {
            if (focusHud.playingBrown) {
                focusHud.playingBrown = false
                focusHud.activeNoise = "none"
                sendCommand({ "action": "noise_stop" })
            } else {
                focusHud.playingRain = false
                focusHud.playingBrown = true
                focusHud.activeNoise = "brown"
            }
        }
    }

    function formatTime(sec) {
        var m = Math.floor(sec / 60)
        var s = sec % 60
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    // Left-edge hover detector
    MouseArea {
        id: edgeSensor
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: focusHud.isRevealed ? 380 : (focusHud.leftEdgeHoverEnabled ? 8 : 0)
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onEntered: {
            if (focusHud.leftEdgeHoverEnabled) focusHud.isRevealed = true
        }
        onExited: {
            if (!drawerHover.hovered) {
                focusHud.isRevealed = false
            }
        }
    }

    // Slide-out Control Drawer
    Rectangle {
        id: controlDrawer
        width: 360
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 16
        x: focusHud.isRevealed ? 16 : -380

        radius: 24
        color: Qt.rgba(Theme.m3surfaceContainer.r, Theme.m3surfaceContainer.g, Theme.m3surfaceContainer.b, 0.90)
        border.color: Qt.rgba(Theme.m3outline.r, Theme.m3outline.g, Theme.m3outline.b, 0.25)
        border.width: 1

        Behavior on x {
            NumberAnimation { duration: 400; easing.type: Easing.OutExpo }
        }

        HoverHandler {
            id: drawerHover
            onHoveredChanged: {
                if (!hovered && !edgeSensor.containsMouse) {
                    if (!focusInput.activeFocus && !breakInput.activeFocus && !newTaskInput.activeFocus) {
                        focusHud.isRevealed = false
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 18

            // Header
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "HYPER-TUNNEL"
                        color: Theme.m3primary
                        font.pixelSize: 12
                        font.weight: Font.Black
                        font.letterSpacing: 2.0
                        font.family: Theme.fontFamily
                    }
                    Text {
                        text: focusHud.engineState === "Focus" ? "Deep Work Engaged" : (focusHud.engineState === "Break" ? "Rest & Recharge" : "Ready to Initiate")
                        color: Theme.m3onSurface
                        font.pixelSize: 20
                        font.weight: Font.Bold
                        font.family: Theme.fontFamily
                    }
                }
                Item { Layout.fillWidth: true }

                // Close Button
                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: closeMouse.containsMouse ? Theme.m3errorContainer : Theme.m3surfaceContainerHighest
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: closeMouse.containsMouse ? Theme.m3onErrorContainer : Theme.m3onSurfaceVariant
                        font.pixelSize: 14
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            stopSession()
                            if (typeof root !== "undefined" && root.closeFocusHud) {
                                root.closeFocusHud()
                            } else {
                                focusHud.visible = false
                            }
                        }
                    }
                }
            }

            // Central Timer Ring
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 168

                Rectangle {
                    width: 156; height: 156; radius: 78
                    anchors.centerIn: parent
                    color: "transparent"
                    border.color: Theme.m3surfaceContainerHighest
                    border.width: 8
                }

                Rectangle {
                    width: 156; height: 156; radius: 78
                    anchors.centerIn: parent
                    color: "transparent"
                    border.color: focusHud.engineState === "Break" ? Theme.m3tertiary : Theme.m3primary
                    border.width: 8
                    opacity: focusHud.engineState === "Idle" ? 0.3 : 1.0

                    SequentialAnimation on scale {
                        running: focusHud.engineState !== "Idle"
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.03; duration: 2000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 2000; easing.type: Easing.InOutSine }
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: focusHud.formatTime(focusHud.remainingSec)
                        color: Theme.m3onSurface
                        font.pixelSize: 34
                        font.weight: Font.Black
                        font.family: "JetBrainsMono Nerd Font"
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: focusHud.engineState.toUpperCase()
                        color: Theme.m3onSurfaceVariant
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.5
                        font.family: Theme.fontFamily
                    }
                }
            }

            // Custom Timer Inputs (Editable when Idle or Anytime)
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    height: 36; radius: 10
                    color: Theme.m3surfaceContainerHigh
                    border.color: focusInput.activeFocus ? Theme.m3primary : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        Text { text: "Focus (m):"; color: Theme.m3onSurfaceVariant; font.pixelSize: 11 }
                        TextInput {
                            id: focusInput
                            Layout.fillWidth: true
                            text: focusHud.focusDurationMin.toString()
                            color: Theme.m3onSurface
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignRight
                            validator: IntValidator { bottom: 1; top: 240 }
                            onEditingFinished: {
                                focusHud.setFocusMins(parseInt(text))
                                focus = false
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 36; radius: 10
                    color: Theme.m3surfaceContainerHigh
                    border.color: breakInput.activeFocus ? Theme.m3primary : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        Text { text: "Break (m):"; color: Theme.m3onSurfaceVariant; font.pixelSize: 11 }
                        TextInput {
                            id: breakInput
                            Layout.fillWidth: true
                            text: focusHud.breakDurationMin.toString()
                            color: Theme.m3onSurface
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignRight
                            validator: IntValidator { bottom: 1; top: 120 }
                            onEditingFinished: {
                                focusHud.setBreakMins(parseInt(text))
                                focus = false
                            }
                        }
                    }
                }
            }

            // Session Controls
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 40; radius: 12
                    color: focusHud.engineState === "Focus" ? Theme.m3primary : Theme.m3surfaceContainerHighest
                    Text {
                        anchors.centerIn: parent
                        text: "Start Focus"
                        color: focusHud.engineState === "Focus" ? Theme.m3onPrimary : Theme.m3onSurface
                        font.weight: Font.Bold; font.pixelSize: 13
                        font.family: Theme.fontFamily
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: focusHud.startFocus()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 40; radius: 12
                    color: focusHud.engineState === "Break" ? Theme.m3tertiary : Theme.m3surfaceContainerHighest
                    Text {
                        anchors.centerIn: parent
                        text: "Break"
                        color: focusHud.engineState === "Break" ? Theme.m3onTertiary : Theme.m3onSurface
                        font.weight: Font.Bold; font.pixelSize: 13
                        font.family: Theme.fontFamily
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: focusHud.startBreak()
                    }
                }

                Rectangle {
                    width: 68; height: 40; radius: 12
                    color: Theme.m3surfaceContainerHighest
                    Text {
                        anchors.centerIn: parent
                        text: "Reset"
                        color: Theme.m3onSurfaceVariant
                        font.weight: Font.Bold; font.pixelSize: 13
                        font.family: Theme.fontFamily
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: focusHud.stopSession()
                    }
                }
            }

            // Schematic Task Checklist (Interactive + Persistent)
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "SCHEMATIC CHECKLIST"
                        color: Theme.m3onSurfaceVariant
                        font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2
                        font.family: Theme.fontFamily
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: tasksModel.count + " TASKS"
                        color: Theme.m3primary
                        font.pixelSize: 10; font.weight: Font.Bold
                        font.family: "JetBrainsMono Nerd Font"
                    }
                }

                // Add Task Row
                Rectangle {
                    Layout.fillWidth: true
                    height: 36; radius: 10
                    color: Theme.m3surfaceContainerHigh
                    border.color: newTaskInput.activeFocus ? Theme.m3primary : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 6

                        TextInput {
                            id: newTaskInput
                            Layout.fillWidth: true
                            color: Theme.m3onSurface
                            font.pixelSize: 12
                            font.family: Theme.fontFamily
                            clip: true
                            onAccepted: {
                                focusHud.addTask(text)
                                text = ""
                            }
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Add focus task..."
                                color: Theme.m3onSurfaceVariant
                                opacity: 0.55
                                font.pixelSize: 12
                                font.family: Theme.fontFamily
                                visible: !newTaskInput.text && !newTaskInput.activeFocus
                            }
                        }

                        Rectangle {
                            width: 26; height: 26; radius: 7
                            color: addTaskMouse.containsMouse ? Theme.m3primary : Theme.m3surfaceContainerHighest
                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                color: addTaskMouse.containsMouse ? Theme.m3onPrimary : Theme.m3onSurface
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }
                            MouseArea {
                                id: addTaskMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    focusHud.addTask(newTaskInput.text)
                                    newTaskInput.text = ""
                                }
                            }
                        }
                    }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: tasksModel
                    spacing: 6
                    clip: true

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 36; radius: 8
                        color: done ? Qt.rgba(Theme.m3surfaceContainerHighest.r, Theme.m3surfaceContainerHighest.g, Theme.m3surfaceContainerHighest.b, 0.4) : Theme.m3surfaceContainerHigh

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 8
                            spacing: 10

                            Rectangle {
                                width: 16; height: 16; radius: 4
                                color: done ? Theme.m3primary : "transparent"
                                border.color: done ? Theme.m3primary : Theme.m3outline
                                border.width: 1.5
                                Text {
                                    anchors.centerIn: parent
                                    text: done ? "✓" : ""
                                    color: Theme.m3onPrimary
                                    font.pixelSize: 11
                                    font.weight: Font.Bold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        tasksModel.setProperty(index, "done", !done)
                                        focusHud.saveTasks()
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: title
                                color: done ? Theme.m3onSurfaceVariant : Theme.m3onSurface
                                font.pixelSize: 12
                                font.strikeout: done
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        tasksModel.setProperty(index, "done", !done)
                                        focusHud.saveTasks()
                                    }
                                }
                            }

                            Rectangle {
                                width: 20; height: 20; radius: 6
                                color: delTaskMouse.containsMouse ? Qt.rgba(Theme.m3error.r, Theme.m3error.g, Theme.m3error.b, 0.2) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: delTaskMouse.containsMouse ? Theme.m3error : Theme.m3onSurfaceVariant
                                    opacity: delTaskMouse.containsMouse ? 1.0 : 0.5
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    id: delTaskMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: focusHud.removeTask(index)
                                }
                            }
                        }
                    }
                }
            }

            // Acoustic Isolation (Ambient Sound Generator)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: "ACOUSTIC ISOLATION"
                    color: Theme.m3onSurfaceVariant
                    font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2
                    font.family: Theme.fontFamily
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 10
                        color: focusHud.playingBrown ? Theme.m3secondaryContainer : Theme.m3surfaceContainerHigh
                        border.color: focusHud.playingBrown ? Theme.m3primary : "transparent"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: focusHud.playingBrown ? "󰕾 Brown Noise" : "Brown Noise"
                            color: focusHud.playingBrown ? Theme.m3onSecondaryContainer : Theme.m3onSurface
                            font.pixelSize: 12; font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: focusHud.toggleNoise("brown")
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 10
                        color: focusHud.playingRain ? Theme.m3secondaryContainer : Theme.m3surfaceContainerHigh
                        border.color: focusHud.playingRain ? Theme.m3primary : "transparent"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: focusHud.playingRain ? "󰖗 Rain (Active)" : "Rain"
                            color: focusHud.playingRain ? Theme.m3onSecondaryContainer : Theme.m3onSurface
                            font.pixelSize: 12; font.weight: Font.Medium
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: focusHud.toggleNoise("rain")
                        }
                    }
                }
            }

            // Active Window & Distraction Matrix
            Rectangle {
                Layout.fillWidth: true
                height: 76; radius: 14
                color: Theme.m3surfaceContainerHigh
                Layout.margins: 0

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "ACTIVE TARGET:"
                            color: Theme.m3onSurfaceVariant
                            font.pixelSize: 10; font.weight: Font.Bold
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: focusHud.frozenCount > 0 ? ("FROZEN: " + focusHud.frozenCount + " APPS") : (focusHud.waylandBlackout ? "DIMMING READY" : "STANDBY")
                            color: focusHud.frozenCount > 0 ? Theme.m3error : Theme.m3primary
                            font.pixelSize: 10; font.weight: Font.Black
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: focusHud.activeAppClass + " — " + focusHud.activeAppTitle
                        color: Theme.m3onSurface
                        font.pixelSize: 12; font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Blocked: " + focusHud.distractedApps.join(", ")
                        color: Theme.m3onSurfaceVariant
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
