import QtQuick

/**
 * Carbon volume/level slider in clean, sleek linear style:
 *   · smooth linear track with rounded capsule pill fill,
 *   · elegant draggable knob marking the current value,
 *   · responsive mouse drag and wheel interaction.
 */
Item {
    id: root

    property real value: 0
    property real minValue: 0
    property real maxValue: 1
    property color fill: "#EDFF33"
    property color track: "#40FFFFFF"
    property color knob: "#F6F4F4"
    property bool interactive: true
    property bool active: true
    property real handleWidth: 8
    property real handleHeight: 14

    signal changed(real value)

    readonly property bool isPressed: area.pressed
    property real dragValue: 0
    readonly property real effectiveValue: isPressed ? dragValue : value

    /* Live-bound: recomputes as `effectiveValue` moves without breaking bindings. */
    property real ratio: Math.max(0, Math.min(1.0, (root.effectiveValue - root.minValue) / Math.max(0.0001, root.maxValue - root.minValue)))

    implicitHeight: 22
    implicitWidth: 160

    function setFromMouse(mx) {
        var w = Math.max(1, root.width)
        var r = Math.max(0, Math.min(1, mx / w))
        var v = root.minValue + r * (root.maxValue - root.minValue)
        root.dragValue = v
        root.changed(v)
    }

    /* Track background */
    Rectangle {
        id: bgTrack
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Qt.rgba(root.track.r, root.track.g, root.track.b, Math.max(0.22, root.track.a))
    }

    /* Filled active progress bar */
    Rectangle {
        id: fillBar
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        width: Math.max(0, Math.min(parent.width, parent.width * root.ratio))
        color: root.fill
        Behavior on width {
            enabled: !root.isPressed
            NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
        }
    }

    /* Drag knob handle */
    Rectangle {
        id: knob
        width: root.handleWidth
        height: root.handleHeight
        radius: root.handleWidth / 2
        anchors.verticalCenter: parent.verticalCenter
        color: root.knob
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.25)
        x: Math.max(0, Math.min(parent.width - width, root.ratio * (parent.width - width)))
        scale: area.pressed ? 1.2 : (area.containsMouse ? 1.1 : 1.0)
        Behavior on scale { NumberAnimation { duration: 100 } }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (m) => root.setFromMouse(m.x)
        onPositionChanged: (m) => { if (area.pressed) root.setFromMouse(m.x) }
        onWheel: (w) => {
            if (w.angleDelta.y > 0)
                root.setFromMouse(Math.min(root.width, root.width * (root.ratio + 0.05)))
            else
                root.setFromMouse(Math.max(0, root.width * (root.ratio - 0.05)))
        }
    }
}