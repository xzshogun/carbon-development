import QtQuick
import QtQuick.Layouts
import "../Singletons"

/**
 * Small labelled on/off switch used by the recorder row of the quick-settings
 * panel. Emits toggled(checked); the panel decides what to do with it.
 */
Item {
    id: root
    signal toggled(bool checked)

    required property string glyph
    required property string label
    required property bool checked
    required property bool disabled
    required property real widthHint

    property real heightHint: 22

    Layout.preferredWidth: root.widthHint
    Layout.preferredHeight: root.heightHint

    Rectangle {
        anchors.fill: parent
        radius: 6
        color: root.disabled ? "transparent" : (hov.hovered ? Theme.bgHover : "transparent")

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            spacing: 4

            Text {
                Layout.preferredWidth: 14
                Layout.alignment: Qt.AlignVCenter
                text: root.glyph
                font.family: Theme.font
                font.pixelSize: Theme.fontPx(12)
                color: root.checked ? Theme.accentLit : Theme.fgDim
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                text: root.label
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(10)
                color: root.checked ? Theme.fg : Theme.fgDim
                elide: Text.ElideRight
            }

            Rectangle {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 14
                Layout.alignment: Qt.AlignVCenter
                radius: 7
                color: root.checked ? Theme.accent : Theme.bgAlt
                border.width: 1
                border.color: root.checked ? "transparent" : Theme.fgFaint

                Rectangle {
                    id: knob
                    width: 10
                    height: 10
                    radius: 5
                    color: root.checked ? "#0e0e12" : Theme.fgDim
                    anchors.verticalCenter: parent.verticalCenter
                    x: root.checked ? parent.width - width - 2 : 2
                    Behavior on x { NumberAnimation { duration: Motion.fast } }
                }
            }
        }

        MouseArea {
            id: hov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !root.disabled
            onClicked: root.toggled(!root.checked)
        }
    }
}