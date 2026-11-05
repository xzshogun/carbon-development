import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import "../Singletons"

/**
 * Carbon floating clock, modelled on caelestia's DesktopClock: a big time on
 * the bottom-right of the screen with the weekday below in a cursive face and
 * the date beside it.
 */
Item {
    id: root

    property string timeStr: Qt.formatTime(new Date(), "hh:mm")
    property string dayStr: Qt.formatDate(new Date(), "dddd")
    property string dateStr: Qt.formatDate(new Date(), "d MMMM")

    implicitWidth: 300
    implicitHeight: clockCol.implicitHeight + 8

    function refresh() {
        var d = new Date();
        root.timeStr = Qt.formatTime(d, "hh:mm");
        root.dayStr = Qt.formatDate(d, "dddd");
        root.dateStr = Qt.formatDate(d, "d MMMM");
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Column {
        id: clockCol
        anchors.fill: parent
        spacing: 4

        Text {
            id: timeText
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.timeStr
            font.family: Theme.font
            font.pixelSize: Theme.fontPx(76)
            font.weight: Font.Bold
            color: Theme.fg

            layer.enabled: true
            layer.effect: shadowFx
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Text {
                id: dayText
                anchors.verticalCenter: parent.verticalCenter
                text: root.dayStr
                font.family: "Caveat"
                font.pixelSize: Theme.fontPx(36)
                font.weight: Font.Bold
                color: Theme.accentLit

                layer.enabled: true
                layer.effect: shadowFx
            }

            Rectangle {
                width: 1
                height: 22
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.outline
            }

            Text {
                id: dateText
                anchors.verticalCenter: parent.verticalCenter
                text: root.dateStr
                font.family: Theme.font
                font.pixelSize: Theme.fontPx(18)
                color: Theme.fgDim
            }
        }

        Component {
            id: shadowFx
            MultiEffect {
                shadowEnabled: true
                shadowColor: "#000000"
                shadowOpacity: 0.35
                shadowBlur: 0.6
            }
        }
    }
}