import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../Singletons"

/**
 * TacticalPomodoro:
 * Hybrid Focus Sprint Matrix + Interactive Tasklist (Fusion of Concepts 3 & 4).
 * Features:
 *   - Miniature Orbital Compass Ring with traveling photon star (matches clock geometry)
 *   - Live Pomodoro sprint countdown (25m Focus / 5m Break) with Start/Pause/Reset/+5m controls
 *   - Bento Glass Hero card with active objective and progress bar
 *   - Interactive Queued Directives list (click any task to focus it, checkbox to complete)
 *   - Daily streak and sprint completion pips
 *   - 100% dynamic bindings to Matugen Theme tokens
 */
Item {
    id: root

    implicitWidth: 260
    implicitHeight: 210

    // ── Pomodoro Timer State ──────────────────────────────────────────────────
    property string currentMode: "focus" // "focus" (25m) or "break" (5m)
    property int focusDuration: 25 * 60
    property int breakDuration: 5 * 60
    property int secondsLeft: focusDuration
    property bool isRunning: false

    property int completedSprints: 3
    property int goalSprints: 4

    readonly property string timeDisplayStr: {
        var m = Math.floor(root.secondsLeft / 60)
        var s = root.secondsLeft % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }

    readonly property real progress: {
        var total = root.currentMode === "focus" ? root.focusDuration : root.breakDuration
        if (total <= 0) return 0.0
        return (total - root.secondsLeft) / total
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: root.isRunning
        onTriggered: {
            if (root.secondsLeft > 0) {
                root.secondsLeft--
                ringCanvas.requestPaint()
            } else {
                // Timer finished
                root.isRunning = false
                if (root.currentMode === "focus") {
                    root.completedSprints++
                    root.currentMode = "break"
                    root.secondsLeft = root.breakDuration
                } else {
                    root.currentMode = "focus"
                    root.secondsLeft = root.focusDuration
                }
                ringCanvas.requestPaint()
            }
        }
    }

    // ── Interactive Tasks List Model ──────────────────────────────────────────
    property var taskList: [
        { text: "Core Development", tag: "#dev", completed: false, active: true },
        { text: "14:00 — Sync & Review PRs", tag: "#team", completed: false, active: false },
        { text: "16:30 — Evening Workout", tag: "#health", completed: false, active: false }
    ]

    function setActiveTask(index) {
        var list = []
        for (var i = 0; i < root.taskList.length; i++) {
            var item = root.taskList[i]
            list.push({
                text: item.text,
                tag: item.tag,
                completed: item.completed,
                active: (i === index)
            })
        }
        root.taskList = list
    }

    function toggleTaskComplete(index) {
        var list = []
        for (var i = 0; i < root.taskList.length; i++) {
            var item = root.taskList[i]
            if (i === index) {
                list.push({
                    text: item.text,
                    tag: item.tag,
                    completed: !item.completed,
                    active: item.active
                })
            } else {
                list.push(item)
            }
        }
        root.taskList = list
    }

    readonly property string activeTaskText: {
        for (var i = 0; i < root.taskList.length; i++) {
            if (root.taskList[i].active) return root.taskList[i].text
        }
        return "Core Development"
    }

    readonly property string activeTaskTag: {
        for (var i = 0; i < root.taskList.length; i++) {
            if (root.taskList[i].active) return root.taskList[i].tag
        }
        return "#dev"
    }

    // ── Layout Structure ──────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: 7

        /* ── Header: Telemetry & Mode Selector ───────────────────────────────── */
        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 5
                Rectangle {
                    width: 5
                    height: 5
                    radius: 2.5
                    color: root.isRunning ? Theme.primary : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.40)
                    opacity: root.isRunning ? 0.9 : 0.5
                }

                Text {
                    text: "FOCUS DIRECTIVES"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(8.5)
                    font.weight: Font.Bold
                    font.letterSpacing: 1.4
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70)
                }
            }

            Item { Layout.fillWidth: true }

            // Mode Pill Button: [ 25M FOCUS ] or [ 05M BREAK ]
            Rectangle {
                implicitWidth: modeText.implicitWidth + 12
                implicitHeight: 18
                radius: 4
                color: root.currentMode === "focus" 
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                    : Qt.rgba(0.2, 0.8, 0.5, 0.16)
                border.color: root.currentMode === "focus"
                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                    : Qt.rgba(0.2, 0.8, 0.5, 0.4)
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isRunning = false
                        if (root.currentMode === "focus") {
                            root.currentMode = "break"
                            root.secondsLeft = root.breakDuration
                        } else {
                            root.currentMode = "focus"
                            root.secondsLeft = root.focusDuration
                        }
                        ringCanvas.requestPaint()
                    }
                }

                Text {
                    id: modeText
                    anchors.centerIn: parent
                    text: root.currentMode === "focus" ? "25M FOCUS" : "05M BREAK"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(8)
                    font.weight: Font.Bold
                    font.letterSpacing: 0.8
                    color: root.currentMode === "focus" ? Theme.primary : "#50fa7b"
                }
            }
        }

        /* ── Bento Orbital Hero Card (Focus Sprint Matrix) ──────────────────── */
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 74
            radius: 10
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, root.isRunning ? 0.38 : 0.20)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 9

                // 1. Miniature Orbital Compass Ring
                Item {
                    id: ringContainer
                    width: 48
                    height: 48
                    Layout.alignment: Qt.AlignVCenter

                    Canvas {
                        id: ringCanvas
                        anchors.fill: parent
                        renderTarget: Canvas.FramebufferObject
                        renderStrategy: Canvas.Threaded
                        antialiasing: true

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            var cx = width / 2
                            var cy = height / 2
                            var r = 19

                            // Base Track
                            ctx.beginPath()
                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                            ctx.strokeStyle = Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12)
                            ctx.lineWidth = 2.2
                            ctx.stroke()

                            // Active Progress Arc
                            var startAngle = -Math.PI / 2
                            var sweep = root.progress * (Math.PI * 2)
                            var endAngle = startAngle + sweep

                            if (sweep > 0.01) {
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, startAngle, endAngle)
                                ctx.strokeStyle = root.currentMode === "focus" ? Theme.primary : Qt.rgba(0.2, 0.8, 0.5, 0.9)
                                ctx.lineWidth = 2.8
                                ctx.lineCap = "round"
                                ctx.stroke()

                                // Photon Star on Tip
                                var px = cx + r * Math.cos(endAngle)
                                var py = cy + r * Math.sin(endAngle)
                                ctx.beginPath()
                                ctx.arc(px, py, 2.6, 0, Math.PI * 2)
                                ctx.fillStyle = "#ffffff"
                                ctx.fill()
                            }
                        }
                    }

                    // Inside Ring: Minutes Remaining
                    Text {
                        anchors.centerIn: parent
                        text: Math.ceil(root.secondsLeft / 60) + "m"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Black
                        color: Theme.fg
                    }
                }

                // 2. Active Directive & Action Controls
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 3

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "[ TARGET OP ]"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(7.5)
                            font.weight: Font.Bold
                            font.letterSpacing: 0.8
                            color: Theme.primary
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.timeDisplayStr
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(12)
                            font.weight: Font.Black
                            color: root.isRunning ? Theme.primary : Theme.fg
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.activeTaskText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Bold
                        color: Theme.fg
                        elide: Text.ElideRight
                    }

                    // Quick Action Buttons Bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        // Play / Pause Button
                        Rectangle {
                            implicitWidth: 54
                            implicitHeight: 18
                            radius: 4
                            color: root.isRunning 
                                ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                : Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: root.isRunning ? "PAUSE" : "START"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(8)
                                font.weight: Font.Black
                                color: root.isRunning ? Theme.primary : Theme.bg
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.isRunning = !root.isRunning
                            }
                        }

                        // +5m Button
                        Rectangle {
                            implicitWidth: 32
                            implicitHeight: 18
                            radius: 4
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                            border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.15)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "+5m"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(8)
                                font.weight: Font.Bold
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.80)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.secondsLeft += 5 * 60
                                    ringCanvas.requestPaint()
                                }
                            }
                        }

                        // Reset Button
                        Rectangle {
                            implicitWidth: 22
                            implicitHeight: 18
                            radius: 4
                            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                            border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.15)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "⟳"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(9)
                                font.weight: Font.Bold
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70)
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.isRunning = false
                                    root.secondsLeft = root.currentMode === "focus" ? root.focusDuration : root.breakDuration
                                    ringCanvas.requestPaint()
                                }
                            }
                        }
                    }
                }
            }
        }

        /* ── Directives Backlog (Tasks List) ────────────────────────────────── */
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            Repeater {
                model: root.taskList

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 28
                    radius: 6
                    color: modelData.active 
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
                        : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.03)
                    border.color: modelData.active
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
                        : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 7
                        anchors.rightMargin: 7
                        spacing: 7

                        // Checkbox (Click to toggle complete)
                        Rectangle {
                            width: 14
                            height: 14
                            radius: 3
                            color: modelData.completed ? Theme.primary : "transparent"
                            border.color: modelData.completed ? Theme.primary : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.35)
                            border.width: 1.2

                            Text {
                                anchors.centerIn: parent
                                visible: modelData.completed
                                text: "✓"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(9)
                                font.weight: Font.Black
                                color: Theme.bg
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleTaskComplete(index)
                            }
                        }

                        // Task Title (Click to promote to active sprint)
                        Text {
                            Layout.fillWidth: true
                            text: modelData.text
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: modelData.active ? Font.Bold : Font.Medium
                            font.strikeout: modelData.completed
                            color: modelData.completed 
                                ? Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.35)
                                : (modelData.active ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.80))
                            elide: Text.ElideRight

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setActiveTask(index)
                            }
                        }

                        // Tag Pill
                        Rectangle {
                            implicitWidth: tagTxt.implicitWidth + 8
                            implicitHeight: 15
                            radius: 3
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)

                            Text {
                                id: tagTxt
                                anchors.centerIn: parent
                                text: modelData.tag
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontPx(7.5)
                                font.weight: Font.Bold
                                color: Theme.primary
                            }
                        }
                    }
                }
            }
        }

        /* ── Footer: Completed Sprints & Streak ──────────────────────────────── */
        RowLayout {
            Layout.fillWidth: true

            RowLayout {
                spacing: 3
                Text {
                    text: "SPRINTS:"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(7.5)
                    font.weight: Font.Bold
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                }

                Repeater {
                    model: root.goalSprints
                    Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: index < root.completedSprints 
                            ? Theme.primary 
                            : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.15)
                    }
                }
            }

            Item { Layout.fillWidth: true }

            RowLayout {
                spacing: 3
                Text {
                    text: "🔥"
                    font.pixelSize: Theme.fontPx(9)
                }
                Text {
                    text: "7-DAY STREAK"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontPx(7.5)
                    font.weight: Font.Bold
                    color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.60)
                }
            }
        }
    }
}
