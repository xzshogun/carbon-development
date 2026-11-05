import QtQuick 6.10
import Quickshell
import "../services" as QsServices
import "../effects"
import "../../../Singletons"

Item {
    id: root

    property var sidebar
    property var controlCenter
    property var launcher

    readonly property var pywal: QsServices.Pywal
    readonly property var notifs: QsServices.Notifs
    readonly property bool isActive: (sidebar && sidebar.shouldShow) ? true : false
    readonly property bool isHovered: mouse.containsMouse
    readonly property int unreadCount: typeof NotificationService !== "undefined" ? NotificationService.unreadCount : (notifs ? notifs.unreadCount : 0)

    implicitWidth: bell.implicitWidth + 8
    implicitHeight: bell.implicitHeight

    MouseArea {
        id: mouse
        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            if (!sidebar)
                return

            if (sidebar.toggle) {
                sidebar.toggle()
            } else if (sidebar.shouldShow !== undefined) {
                sidebar.shouldShow = !sidebar.shouldShow
            }
            if (sidebar.shouldShow && controlCenter) {
                controlCenter.shouldShow = false
            }
        }
    }

    Text {
        id: bell
        anchors.centerIn: parent
        text: unreadCount > 0 ? "󰂚" : "󰂜"
        font.family: "Material Design Icons"
        font.pixelSize: 18
        color: isActive || unreadCount > 0
            ? pywal.primary
            : isHovered
                ? pywal.primary
                : pywal.foreground

        Behavior on color {
            ColorAnimation {
                duration: Material3Anim.short3
                easing.bezierCurve: Material3Anim.standard
            }
        }

        scale: mouse.pressed ? 0.92 : (isHovered || isActive ? 1.08 : 1.0)
        Behavior on scale {
            NumberAnimation {
                duration: Material3Anim.short2
                easing.bezierCurve: Material3Anim.standard
            }
        }
    }

    Rectangle {
        id: notifDot
        anchors.top: bell.top
        anchors.right: bell.right
        anchors.topMargin: 1
        anchors.rightMargin: 0
        width: 5
        height: 5
        radius: 2.5
        color: pywal.primary
        border.width: 1
        border.color: pywal.surfaceContainerHigh
        visible: unreadCount > 0

        scale: visible ? 1.0 : 0.0
        Behavior on scale {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutBack
            }
        }
    }
}
