import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../Singletons"

/**
 * NotificationToast.qml
 *
 * Minimalist Vanish-Mode Notification Toast
 * - 296px wide, radius: 22
 * - Displays notif.appName, notif.summary, and 1-line notif.body
 * - 2px bottom progress bar shrinking over 4.8s (pauses on hover)
 * - Only appears when panel is closed and DND is false
 * - Clicking the toast ONLY dismisses the toast and NEVER opens the panel
 */
Rectangle {
    id: root

    property var toastItem: null
    property bool active: false
    property bool panelOpen: false

    width: 340
    implicitWidth: 340
    implicitHeight: toastContentCol.implicitHeight + 22
    radius: 20
    color: Qt.rgba(Theme.m3surfaceContainer.r, Theme.m3surfaceContainer.g, Theme.m3surfaceContainer.b, 0.94)
    border.width: 1
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
    clip: true

    // Top highlight rim
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        height: 1
        color: Qt.rgba(255/255, 255/255, 255/255, 0.18)
    }

    // Entrance and exit animations
    property real toastProgress: active ? 1.0 : 0.0
    property real swipeX: 0

    Behavior on toastProgress {
        NumberAnimation {
            duration: 260
            easing.type: Easing.OutBack
            easing.overshoot: 1.15
        }
    }

    Behavior on swipeX {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    opacity: Math.max(0.0, toastProgress * (1.0 - (Math.abs(swipeX) / 160.0)))
    scale: 0.88 + (0.12 * toastProgress)

    // 4.8s Shrinking Progress Bar at Bottom (pauses on hover)
    property real remainingTime: 4800
    property bool isPaused: toastMouse.containsMouse || closeBtnMouse.containsMouse

    Timer {
        id: countdownTimer
        interval: 50
        repeat: true
        running: root.active && !root.isPaused
        onTriggered: {
            root.remainingTime = Math.max(0, root.remainingTime - 50)
            if (root.remainingTime <= 0) {
                root.dismissToast()
            }
        }
    }

    Connections {
        target: NotificationService
        function onNotificationArrived(item) {
            // Suppress toast if notifications are disabled, DND is active, or panel is open
            if (!NotificationService.notificationsEnabled) return
            if (NotificationService.dnd || root.panelOpen) return
            root.showToast(item)
        }
    }

    function showToast(item) {
        root.toastItem = item
        root.swipeX = 0
        root.remainingTime = NotificationService.toastTimeoutMs
        root.active = true
    }

    function dismissToast() {
        countdownTimer.stop()
        root.active = false
    }

    // Interactive MouseArea for dismiss
    MouseArea {
        id: toastMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        property real startX: 0
        property real startY: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            startX = mouse.x
            startY = mouse.y
            isDragging = false
        }

        onPositionChanged: (mouse) => {
            if (pressed) {
                var dx = mouse.x - startX
                var dy = mouse.y - startY
                if (!isDragging && Math.abs(dx) > 6 && Math.abs(dx) > Math.abs(dy)) {
                    isDragging = true
                }
                if (isDragging) {
                    root.swipeX = dx
                }
            }
        }

        onReleased: (mouse) => {
            if (isDragging) {
                if (Math.abs(root.swipeX) > 75) {
                    root.dismissToast()
                } else {
                    root.swipeX = 0
                }
                isDragging = false
            }
        }

        onClicked: {
            // Strictly dismiss toast only — NEVER open the panel
            root.dismissToast()
        }
    }

    // Close "✕" button (top right)
    Rectangle {
        id: closeToastBtn
        z: 10
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 9
        anchors.rightMargin: 10
        width: 20
        height: 20
        radius: 10
        color: closeBtnMouse.containsMouse ? Qt.rgba(255/255, 255/255, 255/255, 0.20) : Qt.rgba(255/255, 255/255, 255/255, 0.08)

        Text {
            anchors.centerIn: parent
            text: "✕"
            font.family: "Manrope"
            font.pixelSize: 11
            font.weight: Font.Bold
            color: "#f4f6f5"
        }

        MouseArea {
            id: closeBtnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.dismissToast()
            }
        }
    }

    // Toast Content Column
    ColumnLayout {
        id: toastContentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        anchors.topMargin: 11
        anchors.bottomMargin: 13
        spacing: 3

        // App Name (11px bold uppercase)
        Text {
            Layout.fillWidth: true
            Layout.rightMargin: 24
            text: {
                var app = root.toastItem ? (root.toastItem.appName || "System") : "System"
                return app.toUpperCase()
            }
            font.family: "Manrope"
            font.pixelSize: 11
            font.weight: Font.Bold
            font.letterSpacing: 0.6
            color: Theme.accent
            elide: Text.ElideRight
        }

        // Summary (13px bold)
        Text {
            Layout.fillWidth: true
            Layout.rightMargin: 20
            text: root.toastItem ? (root.toastItem.summary || "Notification") : "Notification"
            font.family: "Manrope"
            font.pixelSize: 13
            font.weight: Font.Bold
            color: Theme.fg
            elide: Text.ElideRight
            maximumLineCount: 1
        }

        // 1-line Body (12px)
        Text {
            Layout.fillWidth: true
            text: root.toastItem ? (root.toastItem.body || "") : ""
            font.family: "Manrope"
            font.pixelSize: 12
            font.weight: Font.Normal
            color: Theme.fgDim
            elide: Text.ElideRight
            maximumLineCount: 1
            visible: text.length > 0
        }
    }

    // Inset 2px Bottom Progress Bar (shrinks over 4.8s, pauses on hover, cleanly inside rounded corners)
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        height: 2
        width: parent.width - 28
        radius: 1
        color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * (root.remainingTime / 4800.0)
            radius: 1
            color: Theme.accent
        }
    }
}
