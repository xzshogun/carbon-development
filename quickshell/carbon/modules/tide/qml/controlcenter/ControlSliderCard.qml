import QtQuick
import Quickshell.Widgets
import "../../../../Singletons"

Rectangle {
    id: root

    signal interactionStarted()
    signal valueMoved(real value)
    signal commitRequested()
    signal cancelRequested()

    property string title: ""
    property string iconText: ""
    property string iconFontFamily: ""
    property string textFontFamily: ""
    property real value: 0
    property real knobSize: 24
    property color moduleColor: Theme.bgAlt
    property color moduleHover: Theme.bgHover
    property color trackColor: Theme.bgAlt
    property color textPrimary: Theme.fg
    property color textSecondary: Theme.fgDim
    readonly property bool pressed: sliderArea.pressed

    function clamp01(nextValue) {
        return Math.max(0, Math.min(1, nextValue));
    }

    radius: 24
    color: StyleTokens.clearBlack
    clip: true

    MatteSurface {
        anchors.fill: parent
        radius: root.radius
        hovered: sliderArea.containsMouse
        pressed: sliderArea.pressed
    }

    Item {
        anchors.fill: parent
        anchors.margins: 12

        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            text: root.title
            color: root.textPrimary
            font.pixelSize: 13
            font.family: root.textFontFamily
            font.weight: Font.DemiBold
        }

        Rectangle {
            id: sliderTrack
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 22
            radius: 11
            color: Theme.bgAlt
            border.width: 1
            border.color: Theme.outline
            clip: true

            Rectangle {
                width: root.value <= 0.001
                    ? 0
                    : Math.max(34, Math.min(sliderTrack.width, sliderTrack.width * root.value + 1))
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                width: 18
                height: 18
                radius: 9
                color: StyleTokens.transparent
                z: 2

                Text {
                    anchors.centerIn: parent
                    text: root.iconText
                    color: root.value > 0.12 ? (Theme.accentContrast || StyleTokens.white) : root.textSecondary
                    font.pixelSize: 13
                    font.family: root.iconFontFamily
                }
            }

            Rectangle {
                x: Math.max(0, Math.min(parent.width - width, parent.width * root.value - width / 2))
                y: -1
                width: root.knobSize
                height: root.knobSize
                radius: root.knobSize / 2
                border.width: 1
                border.color: Theme.outline
                color: Theme.accentLit
            }

            MouseArea {
                id: sliderArea
                anchors.fill: parent
                hoverEnabled: true

                function update(mouseX) {
                    root.valueMoved(root.clamp01(mouseX / width));
                }

                onPressed: function(mouse) {
                    root.interactionStarted();
                    update(mouse.x);
                }
                onPositionChanged: function(mouse) {
                    if (pressed)
                        update(mouse.x);
                }
                onReleased: root.commitRequested()
                onCanceled: root.cancelRequested()
            }
        }
    }
}
