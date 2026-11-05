import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell
import M3Shapes
import "../components"
import "../Singletons"

/**
 * Workspace moons for the bar. One moon glyph () per workspace, stacked
 * vertically; the moon on the active workspace glows in the accent, the rest
 * sit dimmed and neutral. Clicking a moon jumps to that workspace.
 */
Item {
    id: root

    property var range: []
    property string activeName: "0"
    property int hoverIndex: -1

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

    implicitWidth: 42
    implicitHeight: (range.length ? range.length * 34 + 10 : 0) + 6

    property var knownIds: [1]

    function rebuild() {
        var out = [];
        for (var i = 0; i < root.knownIds.length; i++)
            if (out.indexOf(root.knownIds[i]) === -1)
                out.push(root.knownIds[i]);
        var a = parseInt(root.activeName, 10);
        if (a >= 1 && out.indexOf(a) === -1)
            out.push(a);
        out.sort(function (x, y) { return x - y; });
        var changed = root.range.length !== out.length;
        if (!changed)
            for (var j = 0; j < out.length; j++)
                if (out[j] !== root.range[j]) { changed = true; break; }
        if (changed)
            root.range = out;
    }

    Connections {
        target: Hyprland.focusedMonitor
        function onActiveWorkspaceChanged() {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
                root.activeName = String(Hyprland.focusedMonitor.activeWorkspace.id)
                root.rebuild()
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(name, data) {
            if (name.indexOf("workspace") !== -1 || name.indexOf("monitor") !== -1) {
                if (!listProbe.running) listProbe.running = true
            }
        }
    }

    Process {
        id: listProbe
        command: ["sh", "-c", "hyprctl workspaces -j | jq -r '.[].id' 2>/dev/null || true"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                var v = line.trim();
                if (v.length === 0) return;
                var id = parseInt(v, 10);
                if (isNaN(id) || id < 1) return;
                if (root.knownIds.indexOf(id) === -1)
                    root.knownIds = root.knownIds.concat([id]);
                root.rebuild();
            }
        }
    }

    Component.onCompleted: {
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
            root.activeName = String(Hyprland.focusedMonitor.activeWorkspace.id)
        }
        listProbe.running = true
    }

    Column {
        anchors.fill: parent
        spacing: 14
        Repeater {
            model: root.range
            delegate: Item {
                id: chip
                required property int modelData
                required property int index

                readonly property bool active: root.activeName === String(modelData)
                readonly property bool hovered: root.hoverIndex === index

                width: 30
                height: 30
                anchors.horizontalCenter: parent.horizontalCenter
                scale: chip.active ? 1.15 : (chip.hovered ? 1.08 : 1)

                MaterialShape {
                    anchors.fill: parent
                    shape: chip.active ? root.getShapeForWs(chip.modelData) : (chip.hovered ? root.getShapeForWs(chip.modelData) : MaterialShape.Circle)
                    animationDuration: 280
                    animationEasing: Easing.OutBack
                    color: chip.active ? Theme.accent : (chip.hovered ? Theme.bgHover : "transparent")
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Motion.fast
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.6
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: chip.active ? String(chip.modelData) : ""
                    font.family: chip.active ? "JetBrainsMono Nerd Font" : Theme.font
                    font.pixelSize: chip.active ? 11 : 16
                    font.weight: chip.active ? Font.Bold : Font.Normal
                    color: chip.active ? (Theme.isDark ? "#111111" : "#ffffff")
                         : chip.hovered ? Theme.fg : Theme.fgDim
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(modelData)])
                    onEntered: root.hoverIndex = index
                    onExited: root.hoverIndex = -1
                }
            }
        }
    }
}