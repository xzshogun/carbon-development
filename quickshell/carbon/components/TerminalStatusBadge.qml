import QtQuick
import "../Singletons"

Item {
    id: root

    property bool checked: false
    property bool interactive: true
    signal clicked()

    implicitWidth: textLabel.implicitWidth + 12
    implicitHeight: 24

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 4
        color: {
            if (!root.interactive) return "transparent"
            if (mouseArea.pressed) return Qt.rgba(1, 1, 1, 0.10)
            if (mouseArea.containsMouse) return Qt.rgba(1, 1, 1, 0.05)
            return "transparent"
        }
        border.color: (root.interactive && mouseArea.containsMouse) ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Text {
        id: textLabel
        anchors.centerIn: parent
        text: root.checked ? "[ ◆ ON ]" : "[ ◇ OFF ]"
        font.family: Theme.fontMono
        font.pixelSize: Theme.fontPx(11)
        font.weight: Font.DemiBold
        color: root.checked ? Theme.primary : Qt.rgba(1, 1, 1, 0.45)

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            root.checked = !root.checked
            root.clicked()
        }
    }
}
