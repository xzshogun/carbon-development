import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../Singletons"

/**
 * FocusHUD:
 * High-performance Hyper-Tunnel Focus HUD Side Bar for Carbon Shell.
 * Hover-only sliding drawer on Wayland Layer Top (sits ABOVE windows).
 * Slides in when mouse hits the leftmost border of the screen,
 * automatically retracts on mouse leave, strict shortcut-only toggle,
 * and dynamically matches the active system font.
 */
PanelWindow {
    id: focusHud

    WlrLayershell.namespace: "carbon-focus-bar"
    WlrLayershell.layer: WlrLayer.Top
    aboveWindows: true
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    property var modelData: null
    screen: modelData
    property bool open: visible
    signal closeRequested()

    anchors {
        left: true
        top: true
        bottom: true
    }

    implicitWidth: 340

    property bool isRevealed: false

    // Input mask: only receptive to mouse on the left edge trigger when closed,
    // and full 340px sidebar when revealed.
    mask: Region {
        item: focusHud.isRevealed ? hudPanel : leftEdgeTrigger
    }

    WlrLayershell.keyboardFocus: (visible && focusHud.isRevealed) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    // ── Focus Engine State ──
    property string focusState: "idle"     // "idle" | "focus" | "break"
    property int remainingSec: 1500
    property int focusTargetMin: 25
    property int breakTargetMin: 5
    property bool noiseActive: false
    property string noiseType: "none"

    readonly property string formattedTime: {
        var mins = Math.floor(focusHud.remainingSec / 60)
        var secs = focusHud.remainingSec % 60
        var mm = mins < 10 ? "0" + mins : mins
        var ss = secs < 10 ? "0" + secs : secs
        return mm + ":" + ss
    }
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("CARBON_CONFIG_DIR") || (homeDir + "/.config/carbon")
    readonly property string rainAudioPath: configDir + "/assets/rain.mp3"

    // ── Static Audio Process (Prevents process stacking / audio ghosts) ──
    Process {
        id: audioProcess
        command: ["mpv", "--loop=inf", "--no-video", focusHud.rainAudioPath]
        running: false
    }

    // ── OS Command Dispatcher (Screen Dimming & Distraction Freezing) ──
    Process {
        id: osCommandDispatcher
        running: false
    }

    onVisibleChanged: {
        GlobalState.isFocusActive = visible; // Broadcast to the rest of the shell
        focusHud.isRevealed = false;         // Always start tucked away

        if (visible) {
            let cmd = [
                "sh", "-c",
                "hyprctl keyword decoration:dim_inactive true 2>/dev/null; hyprctl keyword decoration:dim_strength 0.90 2>/dev/null; hyprctl repl 'hl.config({ decoration = { dim_inactive = true, dim_strength = 0.90 } })' 2>/dev/null; killall -STOP discord steam telegram-desktop 2>/dev/null || true"
            ];
            osCommandDispatcher.command = cmd;
            osCommandDispatcher.running = true;
            Quickshell.execDetached(cmd);
        } else {
            let cmd = [
                "sh", "-c",
                "hyprctl keyword decoration:dim_inactive false 2>/dev/null; hyprctl keyword decoration:dim_strength 0.20 2>/dev/null; hyprctl repl 'hl.config({ decoration = { dim_inactive = false, dim_strength = 0.20 } })' 2>/dev/null; killall -CONT discord steam telegram-desktop 2>/dev/null || true"
            ];
            audioProcess.running = false; // Kills the rain audio automatically
            osCommandDispatcher.command = cmd;
            osCommandDispatcher.running = true;
            Quickshell.execDetached(cmd);
        }
    }

    Component.onDestruction: {
        if (audioProcess.running) {
            audioProcess.running = false
        }
    }

    // ── Engine Subprocess Pipe ──
    Process {
        id: focusEngineProc
        command: [
            "sh", "-c",
            "if command -v carbon-focus-engine >/dev/null 2>&1; then exec carbon-focus-engine; elif [ -x \"$HOME/.local/bin/carbon-focus-engine\" ]; then exec \"$HOME/.local/bin/carbon-focus-engine\"; else exec carbon-focus-engine; fi"
        ]
        running: true
        stdinEnabled: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function(line) {
                var raw = (line || "").trim()
                if (!raw) return
                try {
                    var msg = JSON.parse(raw)
                    if (!msg) return
                    if (msg.state !== undefined) focusHud.focusState = msg.state
                    if (msg.remaining !== undefined) focusHud.remainingSec = msg.remaining
                    if (msg.focus_target !== undefined) focusHud.focusTargetMin = msg.focus_target
                    if (msg.break_target !== undefined) focusHud.breakTargetMin = msg.break_target
                    if (msg.noise_active !== undefined) focusHud.noiseActive = Boolean(msg.noise_active)
                    if (msg.noise_type !== undefined) focusHud.noiseType = msg.noise_type
                } catch(e) {}
            }
        }
    }

    function sendCmd(cmd) {
        if (focusEngineProc.running) {
            focusEngineProc.write(cmd + "\n")
        }
    }

    function startFocus() {
        sendCmd("start")
    }

    function startBreak() {
        sendCmd("start_break")
    }

    function stopSession() {
        if (audioProcess.running) audioProcess.running = false
        sendCmd("stop")
    }

    function setFocusMins(m) {
        var val = parseInt(m, 10)
        if (!isNaN(val) && val > 0) {
            sendCmd("set_focus " + val)
        }
    }

    function setBreakMins(m) {
        var val = parseInt(m, 10)
        if (!isNaN(val) && val > 0) {
            sendCmd("set_break " + val)
        }
    }

    // ── Leftmost Screen Edge Trigger Zone ──
    Item {
        id: leftEdgeTrigger
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 14

        HoverHandler {
            id: edgeHover
            onHoveredChanged: {
                if (edgeHover.hovered) {
                    leaveTimer.stop()
                    focusHud.isRevealed = true
                }
            }
        }
    }

    // ── Debounced Retraction Timer ──
    Timer {
        id: leaveTimer
        interval: 350
        repeat: false
        onTriggered: {
            if (!panelHover.hovered && !edgeHover.hovered && !focusInput.activeFocus && !breakInput.activeFocus) {
                focusHud.isRevealed = false
            }
        }
    }

    // ── Strict Monochrome Side Panel ──
    Rectangle {
        id: hudPanel
        width: 340
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        x: focusHud.isRevealed ? 0 : -width

        Behavior on x {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutCubic
            }
        }

        color: Qt.rgba(10/255, 11/255, 14/255, 0.90) 
        border.color: Qt.rgba(255/255, 255/255, 255/255, 0.15) 
        border.width: 1

        HoverHandler {
            id: panelHover
            onHoveredChanged: {
                if (!panelHover.hovered && !edgeHover.hovered && !focusInput.activeFocus && !breakInput.activeFocus) {
                    leaveTimer.restart()
                } else {
                    leaveTimer.stop()
                }
            }
        }

        // Header: Title (Close button removed, toggled exclusively via bound shortcut)
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 24

            Text {
                text: "HYPER-TUNNEL"
                color: "#ffffff"
                font.family: Theme.fontFamily
                font.pixelSize: 13
                font.bold: true
                font.letterSpacing: 1.5
            }

            Item { Layout.fillWidth: true }
        }

        // Main Timer Text
        Text {
            id: timerText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 76
            text: focusHud.formattedTime
            font.pixelSize: 64
            font.weight: Font.Bold
            font.family: Theme.fontFamily
            color: "#ffffff"
        }

        Text {
            id: stateSubtitle
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: timerText.bottom
            anchors.topMargin: 4
            text: focusHud.focusState === "focus"
                ? "TUNNEL ACTIVE • DISTRACTIONS FROZEN"
                : (focusHud.focusState === "break" ? "REST & RECHARGE • SYSTEM RESTORED" : "READY TO ENTER HYPER-TUNNEL")
            color: "#888888"
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.0
            font.family: Theme.fontFamily
        }

        // Control Buttons Row (Start Focus, Break, Reset)
        RowLayout {
            id: controlButtonsRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: stateSubtitle.bottom
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 22
            spacing: 8

            // Start Focus Button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 6
                color: focusHud.focusState === "focus" ? "#ffffff" : (startHover.hovered ? Qt.rgba(255/255, 255/255, 255/255, 0.20) : Qt.rgba(255/255, 255/255, 255/255, 0.08))
                border.width: 1
                border.color: focusHud.focusState === "focus" ? "#ffffff" : Qt.rgba(255/255, 255/255, 255/255, 0.25)

                Text {
                    anchors.centerIn: parent
                    text: focusHud.focusState === "focus" ? "FOCUSING" : "START FOCUS"
                    color: focusHud.focusState === "focus" ? "#000000" : "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                HoverHandler { id: startHover }
                TapHandler {
                    onTapped: {
                        if (focusHud.focusState === "focus") {
                            focusHud.stopSession()
                        } else {
                            focusHud.startFocus()
                        }
                    }
                }
            }

            // Take Break Button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 6
                color: focusHud.focusState === "break" ? "#ffffff" : (breakHover.hovered ? Qt.rgba(255/255, 255/255, 255/255, 0.20) : Qt.rgba(255/255, 255/255, 255/255, 0.08))
                border.width: 1
                border.color: focusHud.focusState === "break" ? "#ffffff" : Qt.rgba(255/255, 255/255, 255/255, 0.25)

                Text {
                    anchors.centerIn: parent
                    text: focusHud.focusState === "break" ? "ON BREAK" : "BREAK"
                    color: focusHud.focusState === "break" ? "#000000" : "#ffffff"
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                HoverHandler { id: breakHover }
                TapHandler {
                    onTapped: focusHud.startBreak()
                }
            }

            // Reset Button
            Rectangle {
                Layout.preferredWidth: 60
                Layout.preferredHeight: 36
                radius: 6
                color: resetHover.hovered ? Qt.rgba(255/255, 255/255, 255/255, 0.20) : Qt.rgba(255/255, 255/255, 255/255, 0.08)
                border.width: 1
                border.color: Qt.rgba(255/255, 255/255, 255/255, 0.25)

                Text {
                    anchors.centerIn: parent
                    text: "RESET"
                    color: "#aaaaaa"
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                }

                HoverHandler { id: resetHover }
                TapHandler {
                    onTapped: focusHud.stopSession()
                }
            }
        }

        // Section: Blueprint Task List
        Text {
            id: tasksHeader
            anchors.left: parent.left
            anchors.top: controlButtonsRow.bottom
            anchors.leftMargin: 24
            anchors.topMargin: 28
            text: "SCHEMATIC CHECKLIST"
            color: "#888888"
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.2
            font.family: Theme.fontFamily
        }

        ListModel {
            id: taskModel
            ListElement { taskName: "Architect DBus API"; completed: false }
            ListElement { taskName: "Migrate QML Physics"; completed: false }
            ListElement { taskName: "Optimize Rust Daemon"; completed: false }
        }

        ListView {
            id: taskList
            width: parent.width - 48
            height: 120
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: tasksHeader.bottom
            anchors.topMargin: 12
            model: taskModel
            spacing: 12

            delegate: MouseArea {
                width: ListView.view.width
                height: 30
                onClicked: model.completed = !model.completed

                Row {
                    spacing: 12
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        width: 18; height: 18
                        anchors.verticalCenter: parent.verticalCenter
                        color: "transparent"
                        border.color: model.completed ? "#555555" : "#ffffff"
                        border.width: 1

                        Rectangle {
                            anchors.centerIn: parent
                            width: 10; height: 10
                            color: "#ffffff"
                            visible: model.completed
                        }
                    }

                    Text {
                        text: model.taskName
                        color: model.completed ? "#555555" : "#ffffff"
                        font.pixelSize: 13
                        font.strikeout: model.completed
                        font.family: Theme.fontFamily 
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        // Section: Acoustic Isolation
        Text {
            id: audioHeader
            anchors.left: parent.left
            anchors.top: taskList.bottom
            anchors.leftMargin: 24
            anchors.topMargin: 20
            text: "ACOUSTIC ISOLATION"
            color: "#888888"
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.2
            font.family: Theme.fontFamily
        }

        RowLayout {
            id: audioRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: audioHeader.bottom
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 12
            spacing: 10

            // Rain Noise Button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 6
                readonly property bool isSelected: audioProcess.running
                color: isSelected ? "#ffffff" : (rainHover.hovered ? Qt.rgba(255/255, 255/255, 255/255, 0.20) : Qt.rgba(255/255, 255/255, 255/255, 0.08))
                border.width: 1
                border.color: isSelected ? "#ffffff" : Qt.rgba(255/255, 255/255, 255/255, 0.25)

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "󰖗"
                        color: parent.parent.isSelected ? "#000000" : "#ffffff"
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Rain"
                        color: parent.parent.isSelected ? "#000000" : "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: rainHover }
                TapHandler {
                    onTapped: {
                        audioProcess.running = !audioProcess.running
                    }
                }
            }

            // Brown Noise Button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 6
                readonly property bool isSelected: focusHud.noiseActive && focusHud.noiseType === "brown"
                color: isSelected ? "#ffffff" : (brownHover.hovered ? Qt.rgba(255/255, 255/255, 255/255, 0.20) : Qt.rgba(255/255, 255/255, 255/255, 0.08))
                border.width: 1
                border.color: isSelected ? "#ffffff" : Qt.rgba(255/255, 255/255, 255/255, 0.25)

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "󰝚"
                        color: parent.parent.isSelected ? "#000000" : "#ffffff"
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Brown Noise"
                        color: parent.parent.isSelected ? "#000000" : "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: brownHover }
                TapHandler {
                    onTapped: {
                        if (audioProcess.running) audioProcess.running = false
                        if (focusHud.noiseActive && focusHud.noiseType === "brown") {
                            focusHud.sendCmd("noise_stop")
                        } else {
                            focusHud.sendCmd("noise_brown")
                        }
                    }
                }
            }
        }

        // Section: Session Durations
        Text {
            id: durationsHeader
            anchors.left: parent.left
            anchors.top: audioRow.bottom
            anchors.leftMargin: 24
            anchors.topMargin: 20
            text: "DURATIONS (MINUTES)"
            color: "#888888"
            font.pixelSize: 9
            font.bold: true
            font.letterSpacing: 1.2
            font.family: Theme.fontFamily
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: durationsHeader.bottom
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 10
            spacing: 12

            // Focus Minutes
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 6
                color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                border.width: 1
                border.color: focusInput.activeFocus ? "#ffffff" : Qt.rgba(255/255, 255/255, 255/255, 0.20)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Text {
                        text: "FOCUS"
                        color: "#888888"
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                    }

                    TextInput {
                        id: focusInput
                        Layout.fillWidth: true
                        text: focusHud.focusTargetMin.toString()
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        selectByMouse: true
                        validator: IntValidator { bottom: 1; top: 180 }
                        onEditingFinished: focusHud.setFocusMins(text)
                        onAccepted: focusHud.setFocusMins(text)
                    }
                }
            }

            // Break Minutes
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 6
                color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                border.width: 1
                border.color: breakInput.activeFocus ? "#ffffff" : Qt.rgba(255/255, 255/255, 255/255, 0.20)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    Text {
                        text: "BREAK"
                        color: "#888888"
                        font.family: Theme.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                    }

                    TextInput {
                        id: breakInput
                        Layout.fillWidth: true
                        text: focusHud.breakTargetMin.toString()
                        color: "#ffffff"
                        font.family: Theme.fontFamily
                        font.pixelSize: 15
                        font.bold: true
                        selectByMouse: true
                        validator: IntValidator { bottom: 1; top: 60 }
                        onEditingFinished: focusHud.setBreakMins(text)
                        onAccepted: focusHud.setBreakMins(text)
                    }
                }
            }
        }
    }
}
