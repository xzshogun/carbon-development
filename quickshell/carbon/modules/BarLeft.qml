import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import M3Shapes
import "../Singletons"
import "../components"

/**
 * Nebula-style Top-Left Island (Proportionally Scaled 38px):
 *   - App launcher button (Caelestia logo)
 *   - Instant-reacting horizontal workspaces (1..4 base, 5+ conditional)
 *   - Clean active workspace label (e.g. "Workspace 1")
 */
Item {
    id: root

    implicitHeight: root.vertical ? (verticalCol.implicitHeight + (root.attachedEdge !== "" ? 24 : (root.showBackground ? 16 : 8))) : 38
    implicitWidth: root.vertical ? (root.attachedEdge !== "" ? 34 : 38) : pill.width

    signal openLauncher()

    /* Workspaces state */
    property int activeWs: 1
    property var activeWorkspaces: [1]

    function getShapeForWs(wsId) {
        switch (wsId) {
            case 1: return MaterialShape.Clover4Leaf
            case 2: return MaterialShape.Sunny
            case 3: return MaterialShape.Flower
            case 4: return MaterialShape.Cookie12Sided
            case 5: return MaterialShape.Gem
            case 6: return MaterialShape.Diamond
            case 7: return MaterialShape.Cookie4Sided
            case 8: return MaterialShape.SoftBurst
            case 9: return MaterialShape.Boom
            case 10: return MaterialShape.Ghostish
            default: {
                const extraShapes = [
                    MaterialShape.Slanted,
                    MaterialShape.Pentagon,
                    MaterialShape.ClamShell,
                    MaterialShape.PuffyDiamond,
                    MaterialShape.Arch
                ]
                return extraShapes[Math.abs(wsId - 11) % extraShapes.length]
            }
        }
    }

    function switchWorkspace(id) {
        root.activeWs = id
        Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(id)])
    }

    /* Track active workspace instantly via Hyprland Raw IPC Events */
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

    /* Workspace occupancy probe */
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
        interval: 15000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: listProbe.running = true
    }

    /* Dynamic workspace models (base 1..4, 5+ strictly conditional) */
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

    property bool showBackground: true
    property bool vertical: false
    property string attachedEdge: ""

    readonly property string notchFillPath: {
        const w = pill.width
        const h = pill.height
        const rf = 12
        const rc = 12
        if (root.attachedEdge === "left") {
            return `M 0 0 A ${rf} ${rf} 0 0 0 ${rf} ${rf} L ${w - rc} ${rf} A ${rc} ${rc} 0 0 1 ${w} ${rf + rc} L ${w} ${h - (rf + rc)} A ${rc} ${rc} 0 0 1 ${w - rc} ${h - rf} L ${rf} ${h - rf} A ${rf} ${rf} 0 0 0 0 ${h} L 0 0 Z`
        } else if (root.attachedEdge === "right") {
            return `M ${w} 0 A ${rf} ${rf} 0 0 1 ${w - rf} ${rf} L ${rc} ${rf} A ${rc} ${rc} 0 0 0 0 ${rf + rc} L 0 ${h - (rf + rc)} A ${rc} ${rc} 0 0 0 ${rc} ${h - rf} L ${w - rf} ${h - rf} A ${rf} ${rf} 0 0 1 ${w} ${h} L ${w} 0 Z`
        }
        return ""
    }

    readonly property string notchStrokePath: {
        const w = pill.width
        const h = pill.height
        const rf = 12
        const rc = 12
        if (root.attachedEdge === "left") {
            return `M 0 0 A ${rf} ${rf} 0 0 0 ${rf} ${rf} L ${w - rc} ${rf} A ${rc} ${rc} 0 0 1 ${w} ${rf + rc} L ${w} ${h - (rf + rc)} A ${rc} ${rc} 0 0 1 ${w - rc} ${h - rf} L ${rf} ${h - rf} A ${rf} ${rf} 0 0 0 0 ${h}`
        } else if (root.attachedEdge === "right") {
            return `M ${w} 0 A ${rf} ${rf} 0 0 1 ${w - rf} ${rf} L ${rc} ${rf} A ${rc} ${rc} 0 0 0 0 ${rf + rc} L 0 ${h - (rf + rc)} A ${rc} ${rc} 0 0 0 ${rc} ${h - rf} L ${w - rf} ${h - rf} A ${rf} ${rf} 0 0 1 ${w} ${h}`
        }
        return ""
    }

    Rectangle {
        id: pill
        anchors.top: parent.top
        anchors.left: parent.left
        height: root.vertical ? (verticalCol.implicitHeight + (root.attachedEdge !== "" ? 28 : (root.showBackground ? 16 : 8))) : 38
        width: root.vertical ? (root.attachedEdge !== "" ? 34 : 38) : (contentRow.implicitWidth + (root.showBackground ? 20 : 8))
        radius: root.attachedEdge !== "" ? 0 : 19
        color: (root.attachedEdge === "" && root.showBackground) ? Theme.bg : "transparent"
        border.color: (root.attachedEdge === "" && root.showBackground) ? Theme.outline : "transparent"
        border.width: (root.attachedEdge === "" && root.showBackground) ? 1 : 0

        Shape {
            id: notchShape
            visible: root.attachedEdge !== ""
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false
            layer.enabled: true
            layer.smooth: true

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: root.showBackground ? Theme.bg : "transparent"

                PathSvg {
                    path: root.notchFillPath
                }
            }

            ShapePath {
                strokeWidth: root.showBackground ? 1 : 0
                strokeColor: root.showBackground ? Theme.outline : "transparent"
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin

                PathSvg {
                    path: root.notchStrokePath
                }
            }
        }

        RowLayout {
            id: contentRow
            visible: false
        }

        ColumnLayout {
            id: verticalCol
            visible: false
        }
    }
}
