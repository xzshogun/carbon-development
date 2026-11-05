import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import "../Singletons"

/**
 * Top-right notifications panel. The shell owns the surface; this module
 * claims incoming notifications (via the single NotificationServer) and
 * renders them as a vertical stack of cards, oldest first.
 *
 * The panel opens like the other Carbon panels — a fixed-size card that
 * fades/slides in from the corner — rather than resizing. It is summoned by
 * an invisible hot-spot in the top-right corner, and notifications still pop
 * up on arrival. Hovering the panel pauses expiry; clicking a card (or ✕)
 * dismisses it. Senders that request no timeout stay until clicked away.
 */
Item {
    id: root

    required property var server

    /* Set by the shell when the pointer is over the external hot-spot. */
    property bool sensorHovered: false

    readonly property int total: items.count

    /* Whether the pointer is over the panel itself. */
    property bool panelHovered: false
    property bool hovered: false
    HoverHandler {
        onHoveredChanged: {
            root.panelHovered = hovered
            root.hovered = hovered
        }
    }

    /* The panel is shown while hovered (panel or hot-spot) or while live
     * notifications are present (unless Do Not Disturb is active). Fixed geometry,
     * so it opens/closes as a clean panel animation instead of a layer resize. */
    readonly property bool shown: root.sensorHovered || root.panelHovered || (root.total > 0 && !Theme.dnd)

    /* Font used for lyrics in MusicMod.qml */
    readonly property string notifFont: "JetBrainsMono Nerd Font"

    /* Sizing: compact overall height and cleaner proportions */
    readonly property int rowH: 68
    readonly property int rowGap: 6
    readonly property int stackPitch: root.rowH + root.rowGap
    readonly property int viewH: 286

    implicitWidth: 310
    implicitHeight: 340

    function dismissAll() {
        if (!root.server || !root.server.trackedNotifications) return
        const list = root.server.trackedNotifications.values ? [...root.server.trackedNotifications.values] : []
        for (let i = 0; i < list.length; i++) {
            if (list[i] && typeof list[i].dismiss === "function") {
                list[i].dismiss()
            }
        }
    }

    /* Keep every notification that arrives: untracked ones are dropped
     * by the server before they ever reach the model. */
    Connections {
        target: root.server
        function onNotification(notification) { notification.tracked = true }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: Theme.bg
        border.color: Theme.outline
        border.width: 1

        opacity: root.shown ? 1 : 0
        y: root.shown ? 0 : 16
        Behavior on opacity {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.5
            shadowBlur: 0.9
            shadowVerticalOffset: 8
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            /* --- Top action bar: Clear all button & DND indicator (heading & divider removed) --- */
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                visible: root.total > 0 || Theme.dnd

                Rectangle {
                    visible: Theme.dnd
                    Layout.preferredHeight: 22
                    Layout.preferredWidth: dndRow.implicitWidth + 14
                    radius: 11
                    color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0.15)
                    border.color: Theme.warn
                    border.width: 1

                    Row {
                        id: dndRow
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "do_not_disturb_on"
                            font.family: Theme.fontIcon
                            font.pixelSize: 13
                            color: Theme.warn
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "DND"
                            font.family: root.notifFont
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.DemiBold
                            color: Theme.warn
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    visible: root.total > 0
                    Layout.preferredHeight: 24
                    Layout.preferredWidth: clearRow.implicitWidth + 16
                    radius: 12
                    color: clearHov.hovered ? Theme.bgHover : Theme.bgAlt
                    border.color: clearHov.hovered ? Theme.accent : Theme.outline
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3 } }
                    Behavior on border.color { ColorAnimation { duration: Theme.motionDurationShort3 } }

                    Row {
                        id: clearRow
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "delete_sweep"
                            font.family: Theme.fontIcon
                            font.pixelSize: 14
                            color: clearHov.hovered ? Theme.accent : Theme.fgDim
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Clear all"
                            font.family: root.notifFont
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.Medium
                            color: clearHov.hovered ? Theme.accent : Theme.fg
                        }
                    }

                    MouseArea {
                        id: clearHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.dismissAll()
                    }
                }
            }

            /* --- Body --- */
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                Text {
                    anchors.centerIn: parent
                    text: "No notifications"
                    font.family: root.notifFont
                    font.pixelSize: Theme.fontPx(13)
                    font.weight: Font.Medium
                    color: Theme.fgFaint
                    visible: root.total === 0
                }

                Flickable {
                    anchors.fill: parent
                    clip: true
                    contentHeight: Math.max(parent.height, root.total * root.stackPitch - root.rowGap)
                    boundsBehavior: Flickable.StopAtBounds

                    Item {
                        width: parent.width
                        height: root.total * root.stackPitch - root.rowGap

                        Repeater {
                            id: items
                            model: root.server.trackedNotifications

                            delegate: Rectangle {
                                id: cardItem
                                required property int index
                                required property var modelData

                                readonly property bool autoExpire: cardItem.modelData.expireTimeout !== 0
                                /* -1 = sender wants the server to decide (we use 8s),
                                 * >0 = explicit timeout (min 5s), 0 = never expire. */
                                readonly property int timeoutMs: cardItem.modelData.expireTimeout > 0
                                    ? Math.max(cardItem.modelData.expireTimeout, 5000) : 8000
                                property bool dying: false
                                property real slide: -12

                                x: 0
                                y: cardItem.index * root.stackPitch + cardItem.slide
                                width: parent.width
                                height: root.rowH

                                radius: 12
                                color: Theme.bgAlt
                                border { width: 1; color: Theme.outline }

                                opacity: 0
                                Behavior on opacity {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }
                                Behavior on slide {
                                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }

                                function beginExit() {
                                    if (cardItem.dying) return
                                    cardItem.dying = true
                                    cardItem.opacity = 0
                                    cardItem.slide = 12
                                    outTimer.start()
                                }

                                Timer {
                                    id: outTimer
                                    interval: 200
                                    onTriggered: {
                                        cardItem.dying = false
                                        cardItem.modelData.dismiss()
                                    }
                                }

                                Timer {
                                    id: expireTimer
                                    interval: cardItem.timeoutMs
                                    running: cardItem.autoExpire && !cardItem.dying
                                        && !root.panelHovered && !root.sensorHovered
                                    onTriggered: cardItem.beginExit()
                                }

                                Component.onCompleted: {
                                    cardItem.opacity = 1
                                    cardItem.slide = 0
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: cardItem.beginExit()
                                    onEntered: expireTimer.stop()
                                    onExited: if (!cardItem.dying && !root.panelHovered && !root.sensorHovered)
                                        expireTimer.restart()
                                }

                                RowLayout {
                                    anchors { fill: parent; margins: 10 }
                                    spacing: 10

                                    Rectangle {
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        Layout.alignment: Qt.AlignTop
                                        radius: 12
                                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 48 / 255)
                                        border { width: 1; color: Theme.outline }
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: {
                                                const icon = String(cardItem.modelData.appIcon || "")
                                                icon.startsWith("/") || icon.startsWith("file:")
                                                    ? icon : ""
                                            }
                                            sourceSize: Qt.size(48, 48)
                                            fillMode: Image.PreserveAspectFit
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: cardItem.modelData.summary.length > 0
                                                ? cardItem.modelData.summary : cardItem.modelData.appName
                                            font.family: root.notifFont
                                            font.pixelSize: Theme.fontPx(13)
                                            font.weight: Font.DemiBold
                                            color: Theme.fg
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: cardItem.modelData.body
                                            font.family: root.notifFont
                                            font.pixelSize: Theme.fontPx(12)
                                            color: Theme.fgDim
                                            elide: Text.ElideRight
                                            visible: cardItem.modelData.body.length > 0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}