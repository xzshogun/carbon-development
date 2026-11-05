import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10
import "../../effects"

Item {
    id: root

    required property var audio
    property var pywal

    readonly property bool isMuted: audio ? audio.muted : false
    readonly property int currentVolume: audio ? Math.round(audio.percentage) : 0

    readonly property color cSurface: pywal ? pywal.surfaceContainer : "#1a1a1a"
    readonly property color cOnSurface: pywal ? pywal.foreground : "#dddddd"
    readonly property color cPrimary: pywal ? pywal.primary : "#88cc88"

    Layout.fillWidth: true
    Layout.preferredHeight: 52

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 16
        spacing: 12

        // M3 Icon Button
        Rectangle {
            Layout.preferredWidth: 36; Layout.preferredHeight: 36; radius: 18
            color: iconMouse.pressed ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.12) : iconMouse.containsMouse ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }
            scale: iconMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 100; easing.bezierCurve: Material3Anim.springGentle } }

            Text {
                anchors.centerIn: parent
                text: root.isMuted ? "󰖁" : (root.currentVolume >= 70 ? "󰕾" : (root.currentVolume >= 30 ? "󰖀" : "󰕿"))
                font.family: "Material Design Icons"; font.pixelSize: 20
                color: root.isMuted ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.4) : root.cPrimary
            }
            MouseArea {
                id: iconMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.audio) root.audio.toggleMute()
            }
        }

        Slider {
            id: slider
            Layout.fillWidth: true; Layout.fillHeight: true
            from: 0; to: 100; value: root.currentVolume; live: true
            onMoved: if (root.audio) root.audio.setVolume(value / 100)

            background: Rectangle {
                x: slider.leftPadding; y: slider.topPadding + slider.availableHeight / 2 - height / 2
                implicitWidth: 160; implicitHeight: 6
                width: slider.availableWidth; height: implicitHeight
                radius: 3
                color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.1)

                Rectangle {
                    width: slider.visualPosition * parent.width; height: parent.height; radius: 3
                    color: root.cPrimary
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
            }

            handle: Rectangle {
                x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                y: slider.topPadding + slider.availableHeight / 2 - height / 2
                property real targetHeight: slider.pressed ? 24 : 16
                width: 16
                height: targetHeight
                radius: width / 2
                color: root.cPrimary

                Behavior on height { NumberAnimation { duration: 200; easing.bezierCurve: Material3Anim.emphasized } }
            }
        }

        Text {
            Layout.preferredWidth: 36
            text: root.isMuted ? "MUTE" : (root.currentVolume + "%")
            font.family: "Inter"; font.pixelSize: 12; font.weight: Font.Bold
            color: root.isMuted ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.4) : root.cOnSurface
            horizontalAlignment: Text.AlignRight
        }
    }
}
