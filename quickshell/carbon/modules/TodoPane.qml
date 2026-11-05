import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * Animated, clean, editable To-Do list pane for Carbon QuickSettings.
 * Persists tasks to ~/.config/hypr/carbon-todos.json.
 */
Item {
    id: root

    implicitWidth: 264
    implicitHeight: 296

    property var todos: []
    readonly property int totalCount: root.todos.length
    readonly property int doneCount: {
        let c = 0
        for (let i = 0; i < root.todos.length; i++) {
            if (root.todos[i].done) c++
        }
        return c
    }

    readonly property string filePath: (Quickshell.env("HOME") || "") + "/.config/hypr/carbon-todos.json"

    /* ── Storage Read / Write ────────────────────────────────────────────── */
    Process {
        id: readProc
        command: ["cat", root.filePath]
        stdout: StdioCollector {
            waitForEnd: true
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    try {
                        const parsed = JSON.parse(text.trim())
                        if (Array.isArray(parsed)) {
                            root.todos = parsed
                            return
                        }
                    } catch (e) {}
                }
                /* Default seed if empty or file missing */
                if (root.todos.length === 0) {
                    root.todos = [
                        { id: 1, text: "Explore Nebula bar & clock", done: true },
                        { id: 2, text: "Try out workspace buttons", done: false },
                        { id: 3, text: "Check battery & power popup", done: false }
                    ]
                    root.saveTodos()
                }
            }
        }
    }

    function saveTodos() {
        const jsonStr = JSON.stringify(root.todos)
        Quickshell.execDetached(["sh", "-c", "echo '" + jsonStr.replace(/'/g, "'\\''") + "' > " + root.filePath])
    }

    Component.onCompleted: readProc.running = true

    function addTask(txt) {
        const clean = txt.trim()
        if (clean.length === 0) return
        const newId = Date.now()
        const updated = root.todos.concat([{ id: newId, text: clean, done: false }])
        root.todos = updated
        root.saveTodos()
        taskInput.text = ""
    }

    function toggleTask(idx) {
        if (idx < 0 || idx >= root.todos.length) return
        const updated = root.todos.slice()
        updated[idx].done = !updated[idx].done
        root.todos = updated
        root.saveTodos()
    }

    function deleteTask(idx) {
        if (idx < 0 || idx >= root.todos.length) return
        const updated = root.todos.slice()
        updated.splice(idx, 1)
        root.todos = updated
        root.saveTodos()
    }

    function clearDone() {
        const updated = root.todos.filter(t => !t.done)
        root.todos = updated
        root.saveTodos()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        /* ── Header Row ─────────────────────────────────────────── */
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "To-Do List"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(13)
                font.weight: Font.Bold
                color: Theme.fg
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                width: countTxt.implicitWidth + 10
                height: 18
                radius: 9
                color: Qt.alpha(Theme.accent, 0.16)

                Text {
                    id: countTxt
                    anchors.centerIn: parent
                    text: root.doneCount + "/" + root.totalCount
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(9)
                    font.weight: Font.Bold
                    color: Theme.accent
                }
            }

            /* Clear done button */
            Rectangle {
                width: 22
                height: 22
                radius: 11
                color: clearHov.containsMouse ? Theme.bgHover : "transparent"
                scale: clearHov.pressed ? 0.90 : (clearHov.containsMouse ? 1.08 : 1.0)
                Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                visible: root.doneCount > 0

                Text {
                    anchors.centerIn: parent
                    text: "delete_sweep"
                    font.family: Theme.fontIcon
                    font.pixelSize: 13
                    color: clearHov.containsMouse ? Theme.err : Theme.fgDim
                }

                MouseArea {
                    id: clearHov
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearDone()
                }
            }
        }

        /* ── Input Bar ──────────────────────────────────────────── */
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: 8
            color: Theme.bgHover
            border.color: taskInput.activeFocus ? Theme.accent : Theme.outline
            border.width: 1

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                onClicked: taskInput.forceActiveFocus()
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 6
                spacing: 6

                TextInput {
                    id: taskInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(11)
                    color: Theme.fg
                    clip: true
                    selectByMouse: true
                    activeFocusOnTab: true

                    Text {
                        anchors.fill: parent
                        text: "Add a task and hit Enter..."
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(11)
                        color: Theme.fgFaint
                        visible: !taskInput.text && !taskInput.activeFocus
                    }

                    onAccepted: root.addTask(taskInput.text)
                }

                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    color: addHov.containsMouse ? Theme.accent : "#20FFFFFF"
                    scale: addHov.pressed ? 0.90 : (addHov.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }

                    Text {
                        anchors.centerIn: parent
                        text: "add"
                        font.family: Theme.fontIcon
                        font.pixelSize: 13
                        color: addHov.containsMouse ? "#111111" : Theme.fg
                    }

                    MouseArea {
                        id: addHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.addTask(taskInput.text)
                    }
                }
            }
        }

        /* ── Task List ──────────────────────────────────────────── */
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 4
            model: root.todos

            delegate: Rectangle {
                id: taskRow
                required property var modelData
                required property int index

                width: listView.width
                height: 32
                radius: 8
                color: rowMouse.containsMouse ? Theme.bgHover : "#10FFFFFF"

                Behavior on color { ColorAnimation { duration: 100 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    /* Checkbox */
                    Rectangle {
                        width: 16
                        height: 16
                        radius: 4
                        color: taskRow.modelData.done ? Theme.accent : "transparent"
                        border.color: taskRow.modelData.done ? Theme.accent : Theme.outline
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "check"
                            font.family: Theme.fontIcon
                            font.pixelSize: 11
                            color: "#111111"
                            visible: taskRow.modelData.done
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleTask(taskRow.index)
                        }
                    }

                    /* Task text */
                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: taskRow.modelData.text
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(11)
                        font.strikeout: taskRow.modelData.done
                        color: taskRow.modelData.done ? Theme.fgFaint : Theme.fg
                        elide: Text.ElideRight
                    }

                    /* Delete button */
                    Rectangle {
                        width: 18
                        height: 18
                        radius: 9
                        color: delHov.containsMouse ? Qt.alpha(Theme.err, 0.22) : "transparent"
                        scale: delHov.pressed ? 0.88 : (delHov.containsMouse ? 1.1 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                        opacity: rowMouse.containsMouse ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "close"
                            font.family: Theme.fontIcon
                            font.pixelSize: 11
                            color: delHov.containsMouse ? Theme.err : Theme.fgDim
                        }

                        MouseArea {
                            id: delHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deleteTask(taskRow.index)
                        }
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    z: -1
                    onClicked: root.toggleTask(taskRow.index)
                }
            }

            /* Empty state message */
            Text {
                anchors.centerIn: parent
                text: "No tasks yet!\nType above and press Enter."
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(11)
                color: Theme.fgFaint
                horizontalAlignment: Text.AlignHCenter
                visible: root.totalCount === 0
            }
        }
    }
}
