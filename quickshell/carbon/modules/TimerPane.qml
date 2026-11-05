import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * Carbon pomodoro / stopwatch pane.
 * Scaled down to fit comfortably inside the compact 264×296px panel.
 */
Item {
    id: root

    property string mode: "pomo"          // "pomo" | "stop"
    property bool running: false
    property bool onBreak: false
    property bool longBreak: false        // break kind: long vs short
    property int cycles: 0                // completed focus sessions

    property int workSec: 25 * 60
    property int breakSec: 5 * 60
    property int longBreakSec: 15 * 60
    property int remaining: root.workSec  // pomodoro countdown
    property int elapsed: 0               // stopwatch count-up

    readonly property string filePath: (Quickshell.env("HOME") || "") + "/.config/hypr/carbon-pomodoro.json"

    implicitWidth: 264
    implicitHeight: 296

    function fmt(s) {
        const m = Math.floor(s / 60)
        const ss = s % 60
        if (m >= 60) return String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(m % 60).padStart(2, "0") + ":" + String(ss).padStart(2, "0")
        return String(m).padStart(2, "0") + ":" + String(ss).padStart(2, "0")
    }

    Process {
        id: readProc
        command: ["cat", root.filePath]
        stdout: StdioCollector {
            waitForEnd: true
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    try {
                        const parsed = JSON.parse(text.trim())
                        if (parsed && typeof parsed === "object") {
                            if (!root.running) {
                                root.mode = parsed.mode || "pomo"
                                root.workSec = parsed.workSec || 1500
                                root.breakSec = parsed.breakSec || 300
                                root.longBreakSec = parsed.longBreakSec || 900
                                root.remaining = parsed.remaining !== undefined ? parsed.remaining : root.workSec
                                root.elapsed = parsed.elapsed || 0
                                root.cycles = parsed.cycles || 0
                                root.onBreak = (parsed.phase === "short_break" || parsed.phase === "long_break")
                                root.longBreak = (parsed.phase === "long_break")
                            }
                        }
                    } catch (e) {}
                }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: !root.running
        onTriggered: {
            readProc.running = false
            readProc.running = true
        }
    }

    Component.onCompleted: readProc.running = true

    function saveState() {
        const stateObj = {
            running: root.running,
            mode: root.mode,
            phase: root.onBreak ? (root.longBreak ? "long_break" : "short_break") : "work",
            remaining: root.remaining,
            elapsed: root.elapsed,
            workSec: root.workSec,
            breakSec: root.breakSec,
            longBreakSec: root.longBreakSec,
            cycles: root.cycles
        }
        const jsonStr = JSON.stringify(stateObj)
        const pyScript = "import json, os, sys; p = sys.argv[1]; d = json.loads(sys.argv[2]); cur = {}; (os.path.exists(p) and cur.update(json.load(open(p, 'r', encoding='utf-8')))); cur.update(d); open(p, 'w', encoding='utf-8').write(json.dumps(cur, indent=2)); alt = p.replace('/.config/hypr/', '/.config/carbon/') if '/.config/hypr/' in p else p.replace('/.config/carbon/', '/.config/hypr/'); os.path.isdir(os.path.dirname(alt)) and open(alt, 'w', encoding='utf-8').write(json.dumps(cur, indent=2))"
        Quickshell.execDetached(["python3", "-c", pyScript, root.filePath, jsonStr])
    }

    function tick() {
        if (root.mode === "pomo") {
            root.remaining--
            if (root.remaining <= 0) {
                if (root.onBreak) {
                    root.onBreak = false
                    root.longBreak = false
                    root.remaining = root.workSec
                    Quickshell.execDetached(["notify-send", "-a", "Carbon Focus", "⚡ Focus Period Ready", "Break finished! Ready to concentrate on your next session?"])
                } else {
                    root.cycles++
                    root.longBreak = root.cycles % 4 === 0
                    root.onBreak = true
                    root.remaining = root.longBreak ? root.longBreakSec : root.breakSec
                    const msg = root.longBreak ? "Pomodoro completed! Take a well-deserved 15-minute long break." : "Pomodoro session complete! Time for a short break."
                    Quickshell.execDetached(["notify-send", "-a", "Carbon Focus", "☕ Break Period Ready", msg])
                }
            }
        } else {
            root.elapsed++
        }
        if (root.remaining % 5 === 0) root.saveState()
    }

    function startPause() {
        root.running = !root.running
        root.saveState()
    }
    function reset() {
        root.running = false
        if (root.mode === "pomo") {
            root.onBreak = false
            root.longBreak = false
            root.remaining = root.workSec
        } else {
            root.elapsed = 0
        }
        root.saveState()
    }
    function setMode(m) {
        if (root.mode === m) return
        root.mode = m
        root.running = false
        root.reset()
        root.saveState()
    }
    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v))
    }
    function setWork(m) {
        root.workSec = clamp(m, 1, 180) * 60
        if (!root.running && !root.onBreak) root.remaining = root.workSec
        root.saveState()
    }
    function setBreak(m) {
        root.breakSec = clamp(m, 1, 60) * 60
        root.saveState()
    }
    function setLong(m) {
        root.longBreakSec = clamp(m, 5, 90) * 60
        root.saveState()
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.running
        onTriggered: root.tick()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 5

        /* Mode selector */
        Row {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 6

            Rectangle {
                width: 86
                height: 24
                radius: 12
                color: root.mode === "pomo" ? Theme.accent : (pHov.hovered ? Theme.bgHover : "transparent")
                Text {
                    anchors.centerIn: parent
                    text: "Pomodoro"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Bold
                    color: root.mode === "pomo" ? "#0e0e12" : Theme.fgDim
                }
                MouseArea {
                    id: pHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setMode("pomo")
                }
            }

            Rectangle {
                width: 86
                height: 24
                radius: 12
                color: root.mode === "stop" ? Theme.accent : (sHov.hovered ? Theme.bgHover : "transparent")
                Text {
                    anchors.centerIn: parent
                    text: "Stopwatch"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Bold
                    color: root.mode === "stop" ? "#0e0e12" : Theme.fgDim
                }
                MouseArea {
                    id: sHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.setMode("stop")
                }
            }
        }

        /* Status + big time */
        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: {
                if (root.mode === "stop") return "STOPWATCH"
                if (root.onBreak) return root.longBreak ? "LONG BREAK" : "SHORT BREAK"
                return root.cycles === 0 ? "FOCUS" : "FOCUS " + ((root.cycles % 4) || 4)
            }
            font.family: Theme.font
            font.pixelSize: Theme.fontPx(8)
            font.letterSpacing: 2
            color: root.onBreak ? Theme.accentLit : Theme.fgFaint
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            text: root.mode === "pomo" ? root.fmt(root.remaining) : root.fmt(root.elapsed)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Theme.fontPx(32)
            font.weight: Font.Bold
            color: root.running ? Theme.accentLit : Theme.fg
            horizontalAlignment: Text.AlignHCenter
        }

        /* Session dots + counter (pomodoro only) */
        Column {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 2
            visible: root.mode === "pomo"

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        width: 6
                        height: 6
                        radius: 3
                        color: index < (root.cycles % 4) ? Theme.accent : Theme.fgFaint
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "session " + ((root.cycles % 4) || 4) + " of 4"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(9)
                color: Theme.fgFaint
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
            visible: root.mode === "pomo"
        }

        /* Break-length configuration */
        Row {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            visible: root.mode === "pomo"

            Stepper {
                label: "FOCUS"
                minutes: Math.round(root.workSec / 60)
                disabled: root.running
                onChanged: root.setWork(root.workSec / 60 + delta)
            }
            Stepper {
                label: "SHORT"
                minutes: Math.round(root.breakSec / 60)
                disabled: root.running
                onChanged: root.setBreak(root.breakSec / 60 + delta)
            }
            Stepper {
                label: "LONG"
                minutes: Math.round(root.longBreakSec / 60)
                disabled: root.running
                onChanged: root.setLong(root.longBreakSec / 60 + delta)
            }
        }

        Item { Layout.fillHeight: true }

        /* Controls: Perfectly centered Start/Pause and Reset button cluster */
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.bottomMargin: 14

            RowLayout {
                anchors.centerIn: parent
                spacing: 12

                Rectangle {
                    id: startBtn
                    width: 114
                    height: 32
                    radius: 16
                    color: root.running ? Theme.bgHover : Theme.accent
                    border.width: root.running ? 1 : 0
                    border.color: Theme.accentLit
                    scale: startMH.pressed ? 0.94 : (startMH.containsMouse ? 1.03 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                    Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3; easing.type: Theme.easingStandard } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: root.running ? "pause" : "play_arrow"
                            font.family: Theme.fontIcon
                            font.pixelSize: 15
                            color: root.running ? Theme.fg : Theme.accentContrast
                        }
                        Text {
                            text: root.running ? "PAUSE" : "START"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.Bold
                            color: root.running ? Theme.fg : Theme.accentContrast
                        }
                    }
                    MouseArea {
                        id: startMH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startPause()
                    }
                }

                Rectangle {
                    id: resetBtn
                    width: 32
                    height: 32
                    radius: 16
                    color: resetMH.containsMouse ? Theme.bgHover : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                    border.width: 1
                    border.color: resetMH.containsMouse ? Theme.accentLit : Theme.outline

                    scale: resetMH.pressed ? 0.88 : (resetMH.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                    Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3; easing.type: Theme.easingStandard } }

                    Text {
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: Theme.fontIcon
                        font.pixelSize: 16
                        color: resetMH.containsMouse ? Theme.accentLit : Theme.fgDim
                    }
                    MouseArea {
                        id: resetMH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.reset()
                    }
                }
            }
        }
    }
}