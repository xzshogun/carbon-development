import QtQuick 6.10
import QtQuick.Layouts 6.10
import QtQuick.Controls 6.10
import Quickshell
import "../../effects"

Item {
    id: root

    required property var mpris
    property var pywal

    readonly property var activePlayer: (mpris && mpris.active) ? mpris.active : null
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isPlaying: hasPlayer && Boolean(activePlayer.isPlaying)
    readonly property string trackTitle: (hasPlayer && activePlayer.trackTitle) ? activePlayer.trackTitle : "Unknown"
    readonly property string trackArtist: (hasPlayer && activePlayer.trackArtist) ? activePlayer.trackArtist : ""
    readonly property real position: (hasPlayer && activePlayer.position) ? activePlayer.position : 0
    readonly property real length: (hasPlayer && activePlayer.length) ? activePlayer.length : 1

    Layout.fillWidth: true
    Layout.preferredHeight: hasPlayer ? 78 : 0
    visible: hasPlayer

    Behavior on Layout.preferredHeight { NumberAnimation { duration: 300; easing.bezierCurve: Material3Anim.emphasized } }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 18
        color: pywal ? pywal.surfaceContainerHigh : "#1a1a1a"
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Solid M3 Album Art Container
            Rectangle {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 54
                radius: 12
                clip: true
                color: Qt.rgba(root.pywal.foreground.r, root.pywal.foreground.g, root.pywal.foreground.b, 0.05)

                Image {
                    id: albumArt
                    anchors.fill: parent
                    source: (root.activePlayer && root.activePlayer.trackArtUrl) ? root.activePlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰝚"
                    font.family: "Material Design Icons"; font.pixelSize: 26
                    color: Qt.rgba(root.pywal.foreground.r, root.pywal.foreground.g, root.pywal.foreground.b, 0.2)
                    visible: albumArt.status !== Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 2

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: root.trackTitle || "No Media"
                    font.family: "Inter"; font.pixelSize: 14; font.weight: Font.Bold
                    color: root.pywal.foreground; elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.trackArtist
                    font.family: "Inter"; font.pixelSize: 11
                    color: root.pywal.onSurfaceMuted; elide: Text.ElideRight
                    visible: text !== ""
                }

                Item { Layout.fillHeight: true }
            }

            // M3 FAB (Floating Action Button)
            Rectangle {
                id: playBtn
                Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 21
                color: root.pywal.primary

                scale: playMouse.pressed ? 0.90 : 1.0
                transformOrigin: Item.Center
                Behavior on scale { NumberAnimation { duration: 150; easing.bezierCurve: Material3Anim.springBounce } }

                Text {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "󰏤" : "󰐊"
                    font.family: "Material Design Icons"; font.pixelSize: 22
                    color: root.pywal.background
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.mpris.togglePlaying()
                }
            }
        }

        // Integrated Bottom Progress Track
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            color: Qt.rgba(root.pywal.foreground.r, root.pywal.foreground.g, root.pywal.foreground.b, 0.1)

            Rectangle {
                width: parent.width * (root.length > 0 ? Math.min(root.position / root.length, 1.0) : 0)
                height: parent.height
                color: root.pywal.primary

                Behavior on width { NumberAnimation { duration: 500; easing.bezierCurve: Material3Anim.standard } }
            }
        }
    }
}
