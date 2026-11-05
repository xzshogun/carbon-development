import QtQuick
import "../Singletons"

/**
 * A single Nerd Font glyph in a fixed-size rounded chip with a hover tooltip.
 * Building block for the bar modules.
 */
Item {
    id: root

    property string glyph: ""
    property string tip: ""
    property color color: Theme.fgDim
    property color hoverColor: Theme.fg
    property color bg: "transparent"
    property color hoverBg: Theme.bgHover
    property real size: Theme.iconSize
    property bool pointer: false
    property bool tooltipOn: true
    signal clicked(var mouse)
    signal wheel(var event)
    signal entered()
    signal exited()

    implicitWidth: size + 12
    implicitHeight: size + 12

    property string fontFamily: Theme.fontIcon

    Rectangle {
        id: chip
        anchors.fill: parent
        radius: (parent.width + parent.height) / 8
        color: root.bg
        Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3 } }
    }

    Text {
        anchors.centerIn: parent
        text: root.glyph
        font.family: root.fontFamily
        font.pixelSize: root.size
        color: root.hover ? root.hoverColor : root.color
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3 } }
    }

    property bool hover: false

    scale: iconMouse.pressed ? 0.92 : (root.hover ? 1.08 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutBack
            easing.overshoot: 1.3
        }
    }

    MouseArea {
        id: iconMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: root.pointer ? Qt.PointingHandCursor : Qt.ArrowCursor
        onEntered: { root.hover = true; chip.color = root.hoverBg; root.entered(); }
        onExited: { root.hover = false; chip.color = root.bg; root.exited(); }
        onClicked: (mouse) => root.clicked(mouse)
        onWheel: (wheel) => root.wheel(wheel)
    }

    Tooltip {
        readonly property bool show: root.tooltipOn && root.hover && root.tip.length > 0
        text: root.tip
        anchors.bottom: parent.top
        anchors.bottomMargin: 4
        anchors.horizontalCenter: parent.horizontalCenter
    }
}