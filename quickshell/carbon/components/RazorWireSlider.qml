import QtQuick
import QtQuick.Layouts
import "../Singletons"

Item {
    id: root

    property string label: ""
    property real from: 0
    property real to: 100
    property real value: 0
    property real internalValue: (value !== 0 ? value : from)
    onValueChanged: {
        if (!mouseArea.pressed) {
            internalValue = value
        }
    }
    Component.onCompleted: {
        if (root.value !== undefined && !isNaN(root.value)) {
            root.internalValue = root.value
        }
    }
    property real stepSize: 1
    property string unit: ""
    property int decimals: 0
    property bool useGradientTrack: false
    property color gradientStart: "#E6F4F1"
    property color gradientEnd: "#F5A623"

    signal moved(real val)

    implicitWidth: 300
    implicitHeight: Math.max(48, Math.round(48 * (Theme && Theme.fontScale !== undefined ? Theme.fontScale : 1.0)))

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: root.label
                font.family: Theme.font
                font.pixelSize: Theme.fontPx(12)
                font.weight: Font.Medium
                color: Qt.rgba(1, 1, 1, 0.85)
                Layout.alignment: Qt.AlignLeft
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.internalValue.toFixed(root.decimals) + (root.unit.length > 0 ? (" " + root.unit) : "")
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.DemiBold
                color: Theme.primary
                Layout.alignment: Qt.AlignRight
            }
        }

        // Track and Diamond Handle
        Item {
            id: trackContainer
            Layout.fillWidth: true
            Layout.preferredHeight: 18

            readonly property real normVal: Math.max(0.0, Math.min(1.0, (root.internalValue - root.from) / (root.to - root.from || 1)))
            readonly property real handleX: normVal * (trackContainer.width - 12)

            // Inactive track (1px solid hairline or linear gradient)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: root.useGradientTrack ? "transparent" : Qt.rgba(1, 1, 1, 0.12)
                gradient: root.useGradientTrack ? trackGrad : null

                Gradient {
                    id: trackGrad
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.gradientStart }
                    GradientStop { position: 1.0; color: root.gradientEnd }
                }
            }

            // Active track (1px glowing Theme.primary line)
            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: trackContainer.handleX + 6
                height: 1
                color: Theme.primary
            }

            // Diamond Handle (10x10 rotated 45 deg, hollow with 1.5px border)
            Rectangle {
                x: trackContainer.handleX
                anchors.verticalCenter: parent.verticalCenter
                width: 10
                height: 10
                rotation: 45
                radius: 2
                color: Theme.surface
                border.color: Theme.primary
                border.width: 1.5

                scale: mouseArea.containsPress ? 1.3 : (mouseArea.containsMouse ? 1.15 : 1.0)
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                // Subtle center dot or glow if dragged
                Rectangle {
                    anchors.centerIn: parent
                    width: 3
                    height: 3
                    radius: 1.5
                    color: Theme.primary
                    visible: mouseArea.containsPress
                }
            }

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function updateVal(mouseX) {
                    var boundedX = Math.max(0, Math.min(trackContainer.width - 12, mouseX - 6))
                    var ratio = boundedX / Math.max(1, trackContainer.width - 12)
                    var raw = root.from + ratio * (root.to - root.from)
                    if (root.stepSize > 0) {
                        raw = Math.round(raw / root.stepSize) * root.stepSize
                    }
                    var clamped = Math.max(root.from, Math.min(root.to, raw))
                    if (root.decimals >= 0) {
                        clamped = parseFloat(clamped.toFixed(root.decimals))
                    }
                    root.internalValue = clamped
                    root.moved(clamped)
                }

                onPositionChanged: function(mouse) {
                    if (pressed) {
                        updateVal(mouse.x)
                    }
                }

                onPressed: function(mouse) {
                    updateVal(mouse.x)
                }
            }
        }
    }
}
