import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../Singletons"

/**
 * LockNotificationOverlay:
 * Positioned directly above the LockMediaOverlay in the bottom-left corner.
 * Features:
 *   1. Toast Mode: Incoming notifications pop up directly above the music overlay
 *      and auto-dismiss after 5.5s (with a close button).
 *   2. Notification Center Mode: Hovering near the bottom-left area above the music overlay
 *      smoothly expands a full notification hub with a scrollable list, clear button,
 *      and clean empty state.
 */
Item {
    id: root

    property var notificationServer: null
    property bool enabledSetting: true

    width: 350
    height: 234

    /* ── Read Lock Screen Configuration ───────────────────────────────────── */
    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/hypr/carbon-lockscreen.json"

    FileView {
        id: cfgFile
        path: root.configPath
        onFileChanged: root.reloadConfig()
        onLoaded: root.reloadConfig()
    }

    function reloadConfig() {
        try {
            const txt = cfgFile.text().trim()
            if (txt.length > 0) {
                const parsed = JSON.parse(txt)
                if (parsed.notificationPopup !== undefined) {
                    root.enabledSetting = parsed.notificationPopup
                }
            }
        } catch (e) {
            console.log("Failed to parse lockscreen config in LockNotificationOverlay:", e)
        }
    }

    Component.onCompleted: root.reloadConfig()

    /* ── Notifications Model & Count ──────────────────────────────────────── */
    readonly property var notifModel: (notificationServer && notificationServer.trackedNotifications)
        ? notificationServer.trackedNotifications : null
    readonly property int notifCount: notifList ? notifList.count : 0

    /* ── Toast Notification State ─────────────────────────────────────────── */
    property string toastApp: ""
    property string toastSummary: ""
    property string toastBody: ""
    property bool toastShowing: false

    function showToast(app, summary, body) {
        if (!root.enabledSetting) return
        root.toastApp = app || "System"
        root.toastSummary = summary || (app || "Notification")
        root.toastBody = body || ""
        root.toastShowing = true
        toastTimer.restart()
    }

    function dismissToast() {
        toastTimer.stop()
        root.toastShowing = false
    }

    Timer {
        id: toastTimer
        interval: 5500
        onTriggered: {
            if (!sensorHover.hovered && !cardHover.hovered) {
                root.dismissToast()
            }
        }
    }

    // External listener for incoming system notifications
    Connections {
        target: root.notificationServer
        ignoreUnknownSignals: true

        function onNotification(n) {
            if (!n || !root.enabledSetting) return
            n.tracked = true
            root.showToast(n.appName || "Notification", n.summary || "", n.body || "")
        }
    }

    /* ── Notification Center (Hover Mode) State ───────────────────────────── */
    property bool centerOpen: false

    function toggleCenter() {
        root.centerOpen = !root.centerOpen
    }

    function clearAll() {
        if (root.notifModel && root.notifModel.values) {
            const list = [...root.notifModel.values]
            for (let i = 0; i < list.length; i++) {
                if (list[i] && typeof list[i].dismiss === "function") {
                    list[i].dismiss()
                }
            }
        }
        root.dismissToast()
    }

    readonly property bool isAnyHovered: sensorHover.hovered || (root.centerOpen && cardHover.hovered)

    Timer {
        id: enterTimer
        interval: 100
        onTriggered: {
            if (sensorHover.hovered && root.enabledSetting) {
                leaveTimer.stop()
                root.centerOpen = true
            }
        }
    }

    Timer {
        id: leaveTimer
        interval: 350
        onTriggered: {
            if (!sensorHover.hovered && !cardHover.hovered) {
                root.centerOpen = false
            }
        }
    }

    function checkHoverState() {
        if (sensorHover.hovered || (root.centerOpen && cardHover.hovered)) {
            leaveTimer.stop()
            if (!root.centerOpen && !enterTimer.running && root.enabledSetting) {
                enterTimer.start()
            }
        } else {
            enterTimer.stop()
            if (root.centerOpen && !leaveTimer.running) {
                leaveTimer.start()
            }
        }
    }

    /* ── Bottom-Left Hover Hitbox ─────────────────────────────────────────── */
    Item {
        id: hoverHitbox
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 64

        HoverHandler {
            id: sensorHover
            onHoveredChanged: root.checkHoverState()
        }
    }

    /* ── 1. Toast Notification Card (Visible when toast active & center closed) */
    Rectangle {
        id: toastCard
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        width: parent.width
        height: 68
        radius: 18
        color: "#F0101319"
        border.color: "#30FFFFFF"
        border.width: 1

        visible: opacity > 0.001
        opacity: (root.toastShowing && !root.centerOpen) ? 1.0 : 0.0
        scale: (root.toastShowing && !root.centerOpen) ? 1.0 : 0.92
        transform: Translate {
            y: (root.toastShowing && !root.centerOpen) ? 0 : 16
            Behavior on y {
                enabled: LockTransition.phase === "locked"
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
        }

        Behavior on opacity {
            enabled: LockTransition.phase === "locked"
            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
        }
        Behavior on scale {
            enabled: LockTransition.phase === "locked"
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }

        // Left accent bar
        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 3
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            width: 3.5
            radius: 2
            color: Theme.accent ? Theme.accent : "#00F0FF"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 12
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 10

            // Icon glyph
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 10
                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "notifications"
                    font.family: Theme.fontIcon
                    font.pixelSize: 18
                    color: Theme.accent ? Theme.accent : "#00F0FF"
                }
            }

            // Summary and Body
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: root.toastApp
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Medium
                        color: Theme.accent ? Theme.accent : "#00F0FF"
                        elide: Text.ElideRight
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: "Just now"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(9)
                        color: "#66FFFFFF"
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.toastSummary
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(12)
                    font.weight: Font.DemiBold
                    color: "#FFFFFF"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    Layout.fillWidth: true
                    text: root.toastBody
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(11)
                    color: "#A0FFFFFF"
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    visible: text.length > 0
                }
            }

            // Dismiss X Button
            Rectangle {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: closeHover.hovered ? Qt.rgba(1, 1, 1, 0.20) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "close"
                    font.family: Theme.fontIcon
                    font.pixelSize: 14
                    color: "#99FFFFFF"
                }

                HoverHandler { id: closeHover }
                TapHandler {
                    onTapped: root.dismissToast()
                }
            }
        }
    }

    /* ── 2. Expanded Notification Center Popup (Hover-Activated) ───────────── */
    Rectangle {
        id: centerCard
        anchors.fill: parent
        radius: 18
        color: "#F0101319"
        border.color: root.centerOpen ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5) : "#28FFFFFF"
        border.width: 1

        visible: opacity > 0.001
        opacity: root.centerOpen ? 1.0 : 0.0
        scale: root.centerOpen ? 1.0 : 0.94
        transform: Translate {
            y: root.centerOpen ? 0 : 20
            Behavior on y {
                enabled: LockTransition.phase === "locked"
                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
        }

        Behavior on opacity {
            enabled: LockTransition.phase === "locked"
            NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
        }
        Behavior on scale {
            enabled: LockTransition.phase === "locked"
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            enabled: LockTransition.phase === "locked"
            ColorAnimation { duration: 250 }
        }

        HoverHandler {
            id: cardHover
            onHoveredChanged: root.checkHoverState()
        }

        TapHandler {}

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 11
            spacing: 8

            // Header Bar
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 3
                Layout.rightMargin: 3
                spacing: 7

                Text {
                    text: "notifications"
                    font.family: Theme.fontIcon
                    font.pixelSize: 16
                    color: Theme.accent ? Theme.accent : "#00F0FF"
                }

                Text {
                    text: "Notifications"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(13)
                    font.weight: Font.DemiBold
                    color: "#FFFFFF"
                }

                Text {
                    text: "(" + root.notifCount + ")"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Medium
                    color: "#77FFFFFF"
                }

                Item { Layout.fillWidth: true }

                // Clear All Button
                Rectangle {
                    visible: root.notifCount > 0
                    width: clearText.contentWidth + 14
                    height: 22
                    radius: 11
                    color: clearBtnHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: clearBtnHover.hovered ? "#33FFFFFF" : "#1AFFFFFF"
                    border.width: 1

                    Text {
                        id: clearText
                        anchors.centerIn: parent
                        text: "Clear all"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Medium
                        color: clearBtnHover.hovered ? "#FFFFFF" : "#B0FFFFFF"
                    }

                    HoverHandler { id: clearBtnHover }
                    TapHandler {
                        onTapped: root.clearAll()
                    }
                }
            }

            // Separator line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#18FFFFFF"
            }

            // Empty State View
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.notifCount === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "check"
                        font.family: Theme.fontIcon
                        font.pixelSize: 24
                        color: "#44FFFFFF"
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No notifications"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(12)
                        font.weight: Font.Medium
                        color: "#66FFFFFF"
                    }
                }
            }

            // Scrollable Notifications List
            ListView {
                id: notifList
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.notifCount > 0
                clip: true
                spacing: 5
                model: root.notifModel

                delegate: Rectangle {
                    id: delegateCard
                    required property int index
                    required property var modelData

                    width: notifList.width
                    height: 48
                    radius: 12
                    color: dHover.hovered
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                        : "#1AFFFFFF"
                    border.color: dHover.hovered
                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)
                        : "#14FFFFFF"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    HoverHandler { id: dHover }

                    TapHandler {
                        onTapped: {
                            if (delegateCard.modelData) delegateCard.modelData.dismiss()
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 7
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)

                            Text {
                                anchors.centerIn: parent
                                text: "•"
                                font.pixelSize: Theme.fontPx(15)
                                color: Theme.accent ? Theme.accent : "#00F0FF"
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: delegateCard.modelData
                                    ? (delegateCard.modelData.summary || delegateCard.modelData.appName || "Notification")
                                    : ""
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.DemiBold
                                color: "#FFFFFF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: delegateCard.modelData ? (delegateCard.modelData.body || "") : ""
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(10)
                                color: "#99FFFFFF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        // Dismiss button per card
                        Rectangle {
                            Layout.preferredWidth: 18
                            Layout.preferredHeight: 18
                            radius: 9
                            color: itemCloseHover.hovered ? Qt.rgba(1, 1, 1, 0.22) : "transparent"
                            visible: dHover.hovered

                            Text {
                                anchors.centerIn: parent
                                text: "close"
                                font.family: Theme.fontIcon
                                font.pixelSize: 13
                                color: "#A0FFFFFF"
                            }

                            HoverHandler { id: itemCloseHover }
                            TapHandler {
                                onTapped: {
                                    if (delegateCard.modelData) delegateCard.modelData.dismiss()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
