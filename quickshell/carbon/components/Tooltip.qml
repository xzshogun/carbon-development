import QtQuick
import "../Singletons"

/**
 * Minimal tooltip bubble. Parent it inside a MouseArea-tracked container and
 * set `visible` yourself (or attach to a hover signal).
 */
Rectangle {
    id: root

    default property alias content: contentRow.children

    property string text: ""
    property int maxWidth: 260
    property bool show: false

    readonly property real desiredW: Math.min(maxWidth, Math.max(contentText.implicitWidth + 20, contentRow.width > 0 ? contentRow.width + 24 : contentText.implicitWidth + 20))
    readonly property real desiredH: contentRow.height > 0 ? contentRow.height + 16 : contentText.implicitHeight + 16

    width: desiredW
    height: desiredH

    visible: show
    color: Theme.bgAlt
    border.color: Theme.outline
    border.width: 1
    radius: 8
    z: 100

    opacity: visible ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Motion.fast } }

    Text {
        id: contentText
        visible: root.text.length > 0 && contentRow.children.length === 0
        anchors.fill: parent
        anchors.margins: 8
        text: root.text
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontPx(11)
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 4
        visible: contentRow.children.length > 0
    }
}