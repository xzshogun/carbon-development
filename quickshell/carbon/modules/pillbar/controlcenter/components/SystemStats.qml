import QtQuick 6.10
import QtQuick.Layouts 6.10
import Quickshell
import "../../effects"

Item {
    id: root

    required property var systemUsage
    property var pywal

    readonly property color cSurfaceContainer: pywal ? pywal.surfaceContainerHigh : "#111111"
    readonly property color cOnSurface: pywal ? pywal.foreground : "#dddddd"
    readonly property color cOnSurfaceVariant: pywal ? pywal.onSurfaceMuted : "#999999"

    Layout.fillWidth: true
    Layout.preferredHeight: 84

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: root.cSurfaceContainer

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 0

            Item { Layout.fillWidth: true }
            StatItem {
                icon: "󰘚"; label: "CPU"; value: ((root.systemUsage && root.systemUsage.cpuPerc !== undefined) ? root.systemUsage.cpuPerc : 0) * 100
                accentColor: value > 80 ? pywal.error : value > 50 ? pywal.warning : pywal.primary
            }
            Item { Layout.fillWidth: true }
            Rectangle { width: 1; height: 36; color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.1) }
            Item { Layout.fillWidth: true }
            StatItem {
                icon: "󰍛"; label: "RAM"; value: ((root.systemUsage && root.systemUsage.memPerc !== undefined) ? root.systemUsage.memPerc : 0) * 100
                accentColor: value > 80 ? pywal.error : value > 50 ? pywal.warning : pywal.secondary
            }
            Item { Layout.fillWidth: true }
            Rectangle { width: 1; height: 36; color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.1) }
            Item { Layout.fillWidth: true }
            StatItem {
                icon: "󰋊"; label: "DISK"; value: ((root.systemUsage && root.systemUsage.diskPerc !== undefined) ? root.systemUsage.diskPerc : 0) * 100
                accentColor: value > 80 ? pywal.error : value > 50 ? pywal.warning : pywal.tertiary
            }
            Item { Layout.fillWidth: true }
        }
    }

    component StatItem: ColumnLayout {
        property string icon
        property string label
        property real value
        property color accentColor

        spacing: 2

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: label
            font.family: "Inter"; font.pixelSize: 10; font.weight: Font.Medium
            color: root.cOnSurfaceVariant
            font.letterSpacing: 1.0
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Math.round(value) + "%"
            font.family: "Inter"; font.pixelSize: 20; font.weight: Font.Black
            color: root.cOnSurface
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // M3 Expressive Active Indicator Line
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 32
            Layout.preferredHeight: 3
            radius: 1.5
            color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.1)

            Rectangle {
                width: parent.width * Math.min(value / 100, 1.0)
                height: parent.height
                radius: 1.5
                color: accentColor

                Behavior on width { NumberAnimation { duration: 400; easing.bezierCurve: Material3Anim.emphasizedDecelerate } }
                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }
    }
}
