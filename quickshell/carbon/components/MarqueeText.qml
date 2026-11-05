import QtQuick
import "../Singletons"

Item {
    id: root

    property string text: ""
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int pixelSize: Theme.fontPx(13)
    property int fontWeight: Font.Medium
    property color textColor: Theme.fg
    property bool scrolling: true
    property real gap: 40
    property real speed: 28
    property int startDelay: 1500

    implicitWidth: primaryText.implicitWidth
    implicitHeight: primaryText.implicitHeight
    clip: true

    readonly property bool overflowing: root.width > 0 && primaryText.implicitWidth > root.width + 1
    readonly property bool animating: root.scrolling && root.overflowing

    Row {
        id: track
        spacing: root.gap

        Text {
            id: primaryText
            text: root.text
            font.family: root.fontFamily
            font.pixelSize: root.pixelSize
            font.weight: root.fontWeight
            color: root.textColor
            verticalAlignment: Text.AlignVCenter
            width: root.animating || root.width <= 0 ? implicitWidth : Math.min(implicitWidth, root.width)
            elide: root.animating ? Text.ElideNone : Text.ElideRight
        }

        Text {
            id: secondaryText
            text: root.text
            font.family: root.fontFamily
            font.pixelSize: root.pixelSize
            font.weight: root.fontWeight
            color: root.textColor
            verticalAlignment: Text.AlignVCenter
            width: implicitWidth
            visible: root.animating
        }
    }

    SequentialAnimation {
        id: scrollAnim
        running: root.animating
        loops: Animation.Infinite

        PauseAnimation { duration: root.startDelay }

        NumberAnimation {
            target: track
            property: "x"
            from: 0
            to: -(primaryText.implicitWidth + root.gap)
            duration: Math.max(1, (primaryText.implicitWidth + root.gap) / root.speed * 1000)
            easing.type: Easing.Linear
        }
    }

    onAnimatingChanged: {
        if (!root.animating) {
            scrollAnim.stop();
            track.x = 0;
        }
    }

    onTextChanged: {
        track.x = 0;
    }
}
