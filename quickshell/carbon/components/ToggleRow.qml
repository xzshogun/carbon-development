import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../Singletons"

/**
 * Carbon quick-toggle row: icon, label (with an optional small subtitle),
 * and a slide switch. `on` / `disabled` / `info` are live QML bindings from
 * the caller so the switch always tracks the real state; the whole row is
 * clickable and invokes `act`.
 */
Item {
    id: root

    required property string glyph
    required property string label
    required property real widthHint

    property bool on: false
    property bool disabled: false
    property bool subtitle: false
    property string info: ""
    property string placeholder: ""
    property var act: function() {}

    Layout.preferredWidth: root.widthHint
    Layout.preferredHeight: root.subtitle ? 46 : 34

    readonly property bool hasConn: root.info.length > 0
    readonly property string subText: root.hasConn ? root.info : root.placeholder

    Rectangle {
        id: chipBg
        anchors.fill: parent
        radius: 9
        color: (hov.hovered && !root.disabled) ? Theme.bgHover : "transparent"
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            Layout.preferredWidth: 16
            Layout.alignment: Qt.AlignVCenter
            text: root.glyph
            font.family: Theme.font
            font.pixelSize: Theme.fontPx(15)
            color: root.disabled ? Theme.fgFaint : (root.on ? Theme.accentLit : Theme.fgDim)
            horizontalAlignment: Text.AlignHCenter
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.label + (root.disabled ? " · missing" : "")
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(15)
                color: root.disabled ? Theme.fgFaint : Theme.fg
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.subtitle
                text: root.subText
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(12)
                color: root.disabled ? Theme.fgFaint : Theme.fgDim
                elide: Text.ElideRight
            }
        }

        /* Material-You style switch: rounded track with an inset thumb that
         * slides across, shows a check when on, and casts a small shadow. */
        Rectangle {
            id: m3Track
            Layout.preferredWidth: 46
            Layout.preferredHeight: 26
            Layout.alignment: Qt.AlignVCenter
            radius: 13
            color: root.on ? Theme.accent : "transparent"
            border.width: 2
            border.color: root.on ? "transparent" : Theme.fgFaint
            opacity: root.disabled ? 0.4 : 1

            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            Rectangle {
                id: m3Knob
                width: 18
                height: 18
                radius: 9
                color: root.on ? "#0e0e12" : Theme.fgDim
                anchors.verticalCenter: parent.verticalCenter
                x: root.on ? parent.width - width - 4 : 4

                Behavior on x {
                    NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic }
                }
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.35
                    shadowBlur: 0.5
                    shadowVerticalOffset: 1
                }

                Text {
                    anchors.centerIn: parent
                    text: root.on ? "check" : ""
                    font.family: Theme.fontIcon
                    font.pixelSize: 11
                    color: root.on ? Theme.accent : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.motionDurationShort2 } }
                }
            }
        }
    }

    MouseArea {
        id: hov
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.act()
    }
}