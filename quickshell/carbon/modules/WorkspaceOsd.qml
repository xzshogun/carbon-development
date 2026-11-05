import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../Singletons"

/**
 * WorkspaceOsd:
 * Sleek, aesthetic workspace transition HUD.
 * Exclusively active in Vanish (nucleus) mode!
 * Simple, plane circle design matching the central nucleus:
 * - Glowing theme-sensitive neon outer halo
 * - Crisp white core disc with theme accent neon border
 * - Centered bold workspace number (only the number, no labels, no roaming orbs)
 * - Disappears promptly and smoothly with non-blocking pass-through
 */
Item {
    id: root

    property string barMode: "nucleus"
    property bool showWorkspaceOsd: true
    readonly property bool isVanishMode: root.barMode === "nucleus" || root.barMode === "vanish"

    property int currentWs: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) ? Hyprland.focusedMonitor.activeWorkspace.id : 1
    property int prevWs: currentWs
    property bool active: false
    property bool initialized: false

    // Theme tokens identical to NucleusHub central nucleus
    readonly property color colAccent: Theme.accent || "#e1b68e"
    readonly property color colWhite: "#FFFFFF"
    readonly property color colTextDark: "#0b0e14"

    implicitWidth: 52
    implicitHeight: 52
    width: implicitWidth
    height: implicitHeight

    // Hide timer: holds for 650ms then smoothly fades out
    Timer {
        id: hideTimer
        interval: 650
        onTriggered: root.active = false
    }

    // Startup grace period to prevent false trigger on initial desktop load
    Timer {
        id: startupGraceTimer
        interval: 800
        running: true
        repeat: false
        onTriggered: {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
                root.currentWs = Hyprland.focusedMonitor.activeWorkspace.id
                root.prevWs = root.currentWs
            }
            root.initialized = true
        }
    }

    function trigger(newWs) {
        if (!root.isVanishMode || !root.showWorkspaceOsd) return
        if (!root.initialized) return
        if (newWs <= 0 || isNaN(newWs)) return
        if (newWs === root.prevWs && root.active) {
            hideTimer.restart()
            return
        }

        root.currentWs = newWs
        root.prevWs = newWs

        root.active = true
        hideTimer.restart()
    }

    Timer {
        id: popDelayTimer
        interval: 16
        onTriggered: {
            root.active = true
            hideTimer.restart()
        }
    }

    /* ── Hyprland Workspace Listeners ── */
    Connections {
        target: Hyprland.focusedMonitor
        function onActiveWorkspaceChanged() {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
                root.trigger(Hyprland.focusedMonitor.activeWorkspace.id)
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event, data) {
            let n = ""
            let d = ""
            if (typeof event === "object" && event !== null) {
                n = event.name || ""
                d = event.data || ""
            } else if (typeof event === "string") {
                n = event
                d = (data !== undefined) ? String(data) : ""
            }
            if (n === "workspace" || n === "workspacev2") {
                const id = parseInt(d, 10)
                if (!isNaN(id) && id > 0) root.trigger(id)
            }
        }
    }

    /* ── Visual HUD Container ── */
    visible: opacity > 0.002
    opacity: (root.isVanishMode && root.active) ? 1.0 : 0.0
    scale: (root.isVanishMode && root.active) ? 1.0 : 0.78

    Behavior on opacity {
        NumberAnimation {
            duration: root.active ? 130 : 200
            easing.type: root.active ? Easing.OutCubic : Easing.InQuad
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.active ? 260 : 180
            easing.type: root.active ? Easing.OutBack : Easing.InQuad
            easing.overshoot: 1.15
        }
    }

    // ── Glowing Outer Neon Halo (Matches NucleusHalo) ──
    Rectangle {
        id: halo
        anchors.centerIn: parent
        width: 48
        height: 48
        radius: 24
        color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.42)
        border.width: 1.2
        border.color: Qt.rgba(root.colAccent.r, root.colAccent.g, root.colAccent.b, 0.65)
    }

    // ── Vibrant Crisp Core Disc (Matches NucleusCoreDisc: White with Neon Accent Border) ──
    Rectangle {
        id: coreDisc
        anchors.centerIn: parent
        width: 36
        height: 36
        radius: 18
        color: root.colWhite
        border.color: root.colAccent
        border.width: 1.8

        // Bold centered workspace number only (no labels, no extra text)
        Text {
            anchors.centerIn: parent
            text: String(root.currentWs)
            font.family: Theme.font
            font.pixelSize: 16
            font.bold: true
            color: root.colTextDark
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
