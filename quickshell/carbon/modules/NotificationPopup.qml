import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Services.Notifications
import "../Singletons"

/**
 * Animated Notification Panel Popup:
 *   - Displays active notifications tracked by NotificationServer
 *   - App icons resolved cleanly with freedesktop icon theme fallback
 *   - Clickable notification cards that redirect directly to the running application
 *   - Includes header with unread badge, "Clear all" button, and close action
 *   - Individual card dismiss on hover X button
 *   - Polished empty state when all notifications are cleared
 */
Item {
    id: root

    required property var server
    property bool open: false
    property string barEdge: "top"
    property string barMode: "notch"
    property bool hovered: false

    readonly property var notifs: server && server.trackedNotifications ? server.trackedNotifications : null
    readonly property int total: listView ? listView.count : 0

    signal requestClose()

    implicitWidth: 324
    implicitHeight: 360

    HoverHandler {
        onHoveredChanged: root.hovered = hovered
    }

    property bool animatingOut: false
    onOpenChanged: {
        if (root.open) {
            root.animatingOut = false
            animatingOutTimer.stop()
        } else {
            root.animatingOut = true
            animatingOutTimer.restart()
        }
    }
    Timer {
        id: animatingOutTimer
        interval: 220
        onTriggered: root.animatingOut = false
    }

    function dismissAll() {
        if (!root.notifs) return
        const list = root.notifs.values ? [...root.notifs.values] : []
        for (let i = 0; i < list.length; i++) {
            if (list[i] && typeof list[i].dismiss === "function") {
                list[i].dismiss()
            }
        }
    }

    /* Auto-track any notification arriving at the server */
    Connections {
        target: root.server
        function onNotification(notification) {
            notification.tracked = true
        }
    }

    function getAppIcon(modelData) {
        if (!modelData) return ""
        var raw = String(modelData.appIcon || "").trim()
        if (raw.startsWith("/") || raw.startsWith("file:")) return raw
        if (raw.length > 0) {
            var p = Quickshell.iconPath(raw, "")
            if (p) return p
        }
        var appName = String(modelData.appName || "").toLowerCase().trim()
        if (appName.length > 0) {
            var pName = Quickshell.iconPath(appName, "")
            if (pName) return pName
            var pDash = Quickshell.iconPath(appName.replace(/\s+/g, "-"), "")
            if (pDash) return pDash
        }
        return ""
    }

    Rectangle {
        id: card
        width: parent.width
        height: parent.height
        radius: 16
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.94)
        border.color: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        /* Specular rim highlight */
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: card.radius - 1
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, root.open ? 0.20 : 0.06)
            z: 99
        }

        opacity: root.open ? 1 : 0
        x: root.open ? 0 : (root.barEdge === "left" ? -28 : (root.barEdge === "right" ? 28 : 0))
        y: root.open ? 0 : (root.barEdge === "top" ? -20 : (root.barEdge === "bottom" ? 20 : 0))
        scale: root.open ? 1.0 : 0.90

        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on opacity {
            NumberAnimation { duration: root.open ? 200 : 140; easing.type: Easing.OutCubic }
        }
        Behavior on x {
            NumberAnimation {
                duration: root.open ? 280 : 150
                easing.type: root.open ? Easing.OutBack : Easing.OutCubic
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.open ? 280 : 150
                easing.type: root.open ? Easing.OutBack : Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 280 : 150
                easing.type: root.open ? Easing.OutBack : Easing.OutCubic
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            opacity: root.open ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            /* ── Header ─────────────────────────────────────────────── */
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                spacing: 6

                Rectangle {
                    width: 24; height: 24; radius: 6
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)
                    border.width: 1
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.35)
                    Text {
                        anchors.centerIn: parent
                        text: "notifications"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: Theme.accent
                    }
                }

                Text {
                    text: "Notifications"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(11)
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                /* Unread counter badge */
                Rectangle {
                    visible: root.total > 0
                    Layout.preferredHeight: 18
                    Layout.preferredWidth: countText.implicitWidth + 10
                    radius: 9
                    color: Theme.accent

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: String(root.total)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(7.5)
                        font.weight: Font.Bold
                        color: Theme.isDark ? "#101116" : "#ffffff"
                    }
                }

                Item { Layout.fillWidth: true }

                /* Clear all button */
                Rectangle {
                    visible: root.total > 0
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: clearText.implicitWidth + 12
                    radius: 11
                    color: clearMouse.containsMouse ? Theme.bgHover : "transparent"
                    border.color: clearMouse.containsMouse ? Theme.accent : Theme.outline
                    border.width: 1

                    RowLayout {
                        id: clearText
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: "delete_sweep"
                            font.family: Theme.fontIcon
                            font.pixelSize: 12
                            color: clearMouse.containsMouse ? Theme.accent : Theme.fgDim
                        }
                        Text {
                            text: "Clear"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(7.5)
                            color: clearMouse.containsMouse ? Theme.accent : Theme.fgDim
                        }
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissAll()
                    }
                }

                /* Close button */
                Rectangle {
                    width: 22
                    height: 22
                    radius: 11
                    color: closeMouse.containsMouse ? Theme.bgHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: Theme.fontIcon
                        font.pixelSize: 13
                        color: closeMouse.containsMouse ? Theme.fg : Theme.fgFaint
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestClose()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.08)
            }

            /* ── Content View ────────────────────────────────────────── */
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                /* Empty state */
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    visible: root.total === 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "notifications_paused"
                        font.family: Theme.fontIcon
                        font.pixelSize: 32
                        color: Qt.alpha(Theme.fg, 0.25)
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No Notifications"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.DemiBold
                        color: Theme.fgDim
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "You're all caught up!"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(7.5)
                        color: Theme.fgFaint
                    }
                }

                /* Notification Cards List */
                ListView {
                    id: listView
                    anchors.fill: parent
                    clip: true
                    spacing: 6
                    model: root.notifs
                    boundsBehavior: Flickable.StopAtBounds
                    visible: root.total > 0

                    delegate: Rectangle {
                        id: cardItem
                        required property int index
                        required property var modelData

                        width: listView.width
                        height: contentCol.implicitHeight + 16
                        radius: 10
                        color: itemMouse.containsMouse
                            ? Qt.rgba(Theme.bgHover.r, Theme.bgHover.g, Theme.bgHover.b, 0.88)
                            : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.72)
                        border.color: itemMouse.containsMouse ? Theme.accent : Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1

                        /* Specular rim inside card */
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: cardItem.radius - 1
                            color: "transparent"
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, itemMouse.containsMouse ? 0.22 : 0.06)
                            z: 10
                        }

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        property bool dying: false
                        x: dying ? width + 50 : 0
                        opacity: dying ? 0 : 1
                        scale: dying ? 0.85 : (itemMouse.pressed ? 0.97 : (itemMouse.containsMouse ? 1.01 : 1.0))

                        Behavior on x {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.InBack
                            }
                        }
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on scale {
                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutBack
                            }
                        }

                        Timer {
                            id: exitTimer
                            interval: 180
                            onTriggered: {
                                if (cardItem.modelData) cardItem.modelData.dismiss()
                            }
                        }

                        function dismissCard() {
                            if (cardItem.dying) return
                            cardItem.dying = true
                            exitTimer.start()
                        }

                        function activateAndRedirect(m) {
                            if (!m) return
                            if (m.defaultAction) {
                                try { m.defaultAction.invoke() } catch (e) {}
                            } else if (m.actions && m.actions.length > 0) {
                                try { m.actions[0].invoke() } catch (e) {}
                            }

                            var app = String(m.appName || "").trim()
                            var icon = String(m.appIcon || "").trim()
                            var term = app.toLowerCase()
                            if (term) {
                                Quickshell.execDetached(["sh", "-c",
                                    "target=\"" + term + "\"; " +
                                    "addr=$(hyprctl clients -j | jq -r --arg t \"$target\" '.[] | select((.class | ascii_downcase | contains($t)) or (.initialClass | ascii_downcase | contains($t)) or (.title | ascii_downcase | contains($t))) | .address' | head -n1); " +
                                    "if [ -n \"$addr\" ] && [ \"$addr\" != \"null\" ]; then " +
                                    "  hyprctl dispatch focuswindow address:$addr; " +
                                    "else " +
                                    "  gtk-launch \"$target\" 2>/dev/null || gtk-launch \"" + icon + "\" 2>/dev/null || \"$target\" & " +
                                    "fi"
                                ])
                            }

                            cardItem.dismissCard()
                            root.requestClose()
                        }

                        MouseArea {
                            id: itemMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: cardItem.activateAndRedirect(cardItem.modelData)
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            /* App / Sender Icon */
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                Layout.alignment: Qt.AlignTop
                                radius: 7
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                                border.color: Theme.outline
                                border.width: 1
                                clip: true

                                Image {
                                    id: notifIconImg
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: root.getAppIcon(cardItem.modelData)
                                    sourceSize: Qt.size(32, 32)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    mipmap: true
                                    visible: status === Image.Ready
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "notifications"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 14
                                    color: Theme.accent
                                    visible: notifIconImg.status !== Image.Ready
                                }
                            }

                            /* Text Details */
                            ColumnLayout {
                                id: contentCol
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        Layout.fillWidth: true
                                        text: {
                                            if (!cardItem.modelData) return ""
                                            return cardItem.modelData.summary.length > 0
                                                ? cardItem.modelData.summary
                                                : cardItem.modelData.appName
                                        }
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(9)
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                        elide: Text.ElideRight
                                    }

                                    /* Dismiss cross on hover */
                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        color: closeCrossMA.containsMouse ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.25) : "transparent"
                                        visible: itemMouse.containsMouse || closeCrossMA.containsMouse
                                        z: 20

                                        Text {
                                            anchors.centerIn: parent
                                            text: "close"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 11
                                            color: Theme.err
                                        }

                                        MouseArea {
                                            id: closeCrossMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: cardItem.dismissCard()
                                        }
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: cardItem.modelData ? String(cardItem.modelData.body || "") : ""
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontPx(7.5)
                                    color: Theme.fgDim
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: cardItem.modelData ? String(cardItem.modelData.appName || "") : ""
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontPx(6.5)
                                    color: Theme.accentLit
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
