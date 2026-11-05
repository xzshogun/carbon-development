import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Singletons"
import "../components"

/**
 * NotchBarLeft: Top-attached curved notch for Left side
 *   - App launcher button
 *   - Sleek tactile workspace pills (Carbon aesthetic, no Material UI shapes)
 *   - Mouse wheel workspace scrolling
 */
NotchContainer {
    id: root

    implicitHeight: 34
    earWidth: 20
    contentSpacing: 7
    implicitWidth: contentImplicitWidth + (rightFillet ? filletRadius : 0) + (horizontalPadding * 2)

    signal openSpotlight()
    signal toggleSpotlight()

    /* ── Hyprland Workspace Tracking ─────────────────────────────────── */
    property int activeWs: 1
    property var activeWorkspaces: [1]

    function switchWorkspace(id) {
        if (id <= 0) return
        root.activeWs = id
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(id)])
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name
            if (n === "workspace" || n === "workspacev2") {
                const id = parseInt(event.data, 10)
                if (!isNaN(id) && id > 0) root.activeWs = id
                listProbe.running = true
            } else if (n === "createworkspace" || n === "destroyworkspace"
                       || n === "focusedmon" || n === "focusedmonv2") {
                listProbe.running = true
            }
        }
    }

    Connections {
        target: Hyprland.focusedMonitor
        function onActiveWorkspaceChanged() {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
                root.activeWs = Hyprland.focusedMonitor.activeWorkspace.id
            }
        }
    }

    Process {
        id: listProbe
        command: ["sh", "-c", "hyprctl workspaces -j | jq -r '.[].id' 2>/dev/null || true"]
        running: false
        stdout: StdioCollector { id: listC; waitForEnd: true }
        onExited: {
            const lines = listC.text.trim().split("\n")
            const ids = []
            for (let i = 0; i < lines.length; i++) {
                const id = parseInt(lines[i].trim(), 10)
                if (!isNaN(id) && id > 0 && ids.indexOf(id) === -1) {
                    ids.push(id)
                }
            }
            ids.sort((a, b) => a - b)
            if (ids.length > 0) root.activeWorkspaces = ids
        }
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: listProbe.running = true
    }

    readonly property var displayWorkspaces: {
        const base = [1, 2, 3, 4]
        for (let i = 0; i < root.activeWorkspaces.length; i++) {
            const id = root.activeWorkspaces[i]
            if (id <= 10 && base.indexOf(id) === -1) base.push(id)
        }
        if (root.activeWs <= 10 && base.indexOf(root.activeWs) === -1) {
            base.push(root.activeWs)
        }
        base.sort((a, b) => a - b)
        return base
    }

    property string activeWsGlyph: (typeof Theme !== "undefined" && Theme.workspaceActiveGlyph) ? Theme.workspaceActiveGlyph : "◆"
    property string inactiveWsGlyph: (typeof Theme !== "undefined" && Theme.workspaceInactiveGlyph) ? Theme.workspaceInactiveGlyph : "◇"

    /* ── Content Row Inside Notch ────────────────────────────────────── */
    content: [
        /* 1. App Launcher / Brand Button */
        Item {
            id: launcherBtn
            width: Theme.px(26)
            height: Theme.px(26)
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool isHovered: launcherMouse.containsMouse

            Rectangle {
                anchors.fill: parent
                radius: Theme.px(6)
                color: launcherBtn.isHovered ? Qt.alpha(Theme.accent, 0.15) : "transparent"
                border.color: launcherBtn.isHovered ? Theme.accent : "transparent"
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            CarbonLogoIcon {
                anchors.centerIn: parent
                width: Theme.px(20)
                height: Theme.px(20)
                color: launcherBtn.isHovered ? Theme.accent : Theme.fg
            }

            MouseArea {
                id: launcherMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleSpotlight()
            }
        },

        /* Subtle Vertical Divider */
        Rectangle {
            width: 1
            height: Theme.px(14)
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.alpha(Theme.fg, 0.15)
        },

        /* 2. Pure Glyph Shape Workspaces Row */
        Item {
            id: wsContainer
            implicitWidth: wsRow.implicitWidth
            implicitHeight: Theme.px(24)
            anchors.verticalCenter: parent.verticalCenter

            Row {
                id: wsRow
                spacing: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: root.displayWorkspaces

                    delegate: Item {
                        id: wsItem
                        required property int modelData
                        readonly property int wsId: modelData
                        readonly property bool isActive: (wsId === root.activeWs)
                        readonly property bool isOccupied: (root.activeWorkspaces.indexOf(wsId) !== -1)
                        readonly property bool isHovered: wsMouse.containsMouse

                        width: Theme.px(22)
                        height: Theme.px(22)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: wsItem.isActive ? root.activeWsGlyph : root.inactiveWsGlyph
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(wsItem.isActive ? 16 : 14)
                            scale: wsItem.isActive ? 1.25 : (wsItem.isHovered ? 1.15 : (wsItem.isOccupied ? 1.0 : 0.85))
                            color: {
                                if (wsItem.isActive) return Theme.accent
                                if (wsItem.isHovered) return Theme.accentLit
                                if (wsItem.isOccupied) return Theme.fg
                                return Qt.alpha(Theme.fg, 0.28)
                            }

                            Behavior on scale {
                                NumberAnimation { duration: 160; easing.type: Easing.OutBack }
                            }
                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }
                        }

                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.switchWorkspace(wsItem.wsId)
                        }
                    }
                }
            }

            /* Scroll wheel support: scroll up/down anywhere over workspaces to switch */
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        root.switchWorkspace(Math.max(1, root.activeWs - 1))
                    } else if (wheel.angleDelta.y < 0) {
                        root.switchWorkspace(root.activeWs + 1)
                    }
                }
            }
        }
    ]
}
