import QtQuick
import "../Singletons"

/**
 * Material-You quick-setting tile: a small rounded square with an icon and a
 * label. Shows a circular ink ripple spreading from the press point, and a
 * translucent accent fill while the setting is on (or while its detail popup
 * is held open). `act` is called on click — either toggling the setting or
 * summoning the detail popup.
 */
Item {
    id: root

    required property string glyph
    required property string label
    required property int tileSize

    property bool on: false
    property bool disabled: false
    property bool held: false
    property var act: function() {}

    property bool draggable: false
    property string tileId: ""
    readonly property bool isDragging: hov.drag.active
    property real minX: 0
    property real maxX: parent ? Math.max(0, parent.width - root.width) : 0
    property real minY: 0
    property real maxY: parent ? Math.max(0, parent.height - root.height) : 0
    signal dragEnded()
    signal tileMoved(real centerX, real centerY)

    property bool wasDragged: false
    property bool animReady: false

    Component.onCompleted: {
        Qt.callLater(() => { root.animReady = true })
    }

    implicitWidth: root.tileSize
    implicitHeight: root.tileSize

    z: hov.drag.active ? 100 : 1
    scale: hov.pressed ? 0.94 : (hov.drag.active ? 1.06 : (hov.containsMouse ? 1.04 : 1.0))
    Behavior on scale {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutBack
            easing.overshoot: 1.25
        }
    }

    Behavior on x {
        enabled: root.animReady && !hov.drag.active
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        enabled: root.animReady && !hov.drag.active
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: face
        anchors.fill: parent
        radius: root.tileSize * 0.28
        color: root.on || root.held
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.32)
            : Theme.bgAlt
        border.width: 1
        border.color: hov.drag.active ? Theme.accent : (root.on || root.held ? "transparent" : Theme.outline)
        Behavior on color { ColorAnimation { duration: Motion.fast } }

        /* Subtle drag move hint */
        Text {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.rightMargin: 5
            text: "drag_pan"
            font.family: Theme.fontIcon
            font.pixelSize: 10
            color: hov.drag.active || hov.containsMouse ? Theme.accent : Theme.fgFaint
            opacity: hov.drag.active || hov.containsMouse ? 0.9 : 0.25
            visible: root.draggable
            Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Math.round(root.tileSize * 0.18)
            text: root.glyph
            font.family: Theme.fontIcon
            font.pixelSize: Math.max(14, Math.round(root.tileSize * 0.32))
            color: root.disabled ? Theme.fgFaint
                 : (root.on || root.held ? Theme.accentLit : Theme.fg)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(root.tileSize * 0.14)
            width: root.tileSize - 4
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: root.label
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.max(9, Math.round(root.tileSize * 0.18))
            font.weight: Font.DemiBold
            color: root.disabled ? Theme.fgFaint
                 : (root.on || root.held ? Theme.fg : Theme.fgDim)
        }
    }

    /* Ink ripple: grows from the press point while fading out. */
    Rectangle {
        id: ripple
        width: 20
        height: 20
        radius: 10
        color: "#40479BFF"
        scale: 0
        opacity: 0
        visible: opacity > 0.001
    }

    ParallelAnimation {
        id: rippleAnim
        NumberAnimation {
            target: ripple
            property: "scale"
            from: 0
            to: root.tileSize * 3.2 / ripple.width
            duration: Motion.normal
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: ripple
            property: "opacity"
            from: 1
            to: 0
            duration: Motion.slow + 140
            easing.type: Easing.OutQuad
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: hov.drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        enabled: !root.disabled

        drag.target: root.draggable ? root : null
        drag.axis: Drag.XAndYAxis
        drag.minimumX: root.minX
        drag.maximumX: root.maxX
        drag.minimumY: root.minY
        drag.maximumY: root.maxY
        drag.threshold: 8

        onPressed: (mouse) => {
            root.wasDragged = false
            ripple.x = mouse.x - ripple.width / 2
            ripple.y = mouse.y - ripple.height / 2
            ripple.scale = 0
            ripple.opacity = 1
            ripple.visible = true
            rippleAnim.start()
        }
        onPositionChanged: {
            if (hov.drag.active) {
                root.wasDragged = true
                root.tileMoved(root.x + root.width / 2, root.y + root.height / 2)
            }
        }
        onReleased: {
            if (root.wasDragged) {
                root.dragEnded()
            }
        }
        onClicked: {
            if (!root.wasDragged) {
                root.act()
            }
        }
    }
}