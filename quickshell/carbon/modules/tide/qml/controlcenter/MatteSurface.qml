import QtQuick
import Quickshell.Widgets
import "../../../../Singletons"

Item {
    id: root

    property real radius: 20
    property bool hovered: false
    property bool pressed: false
    readonly property real innerRadius: Math.max(0, radius - 1)

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.pressed ? Theme.bgActive : (root.hovered ? Theme.bgHover : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.35))
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.innerRadius
        color: root.pressed ? Theme.bgActive : (root.hovered ? Theme.bgHover : (Theme.isDark ? Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.25) : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.4)))
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: root.innerRadius
        color: StyleTokens.transparent
        border.width: 1
        border.color: root.hovered ? Theme.accent : Theme.outline
    }
}
