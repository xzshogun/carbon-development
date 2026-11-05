import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../Singletons"

/**
 * NotificationCard.qml
 *
 * Minimalist Vanish-Mode Notification Card (296px panel width compatible)
 * - Padding: 11px 12px, Radius: 16
 * - Top row: 6px unread coral dot + notif.appName (10.5px bold uppercase) + relative timestamp ("now", "2m")
 * - Middle: notif.summary (13px weight 700 #f4f6f5)
 * - Bottom: notif.body (12px rgba(244, 246, 245, 0.68)), clamped to 2 lines when collapsed, up to 8 lines when expanded
 * - Slide-Commit Swipe Dismissal (commitThreshold = 85px) with rubber drag resistance past 85px and commit badge
 * - Non-stealing gesture scrolling: drag.axis = Drag.XAxis, wheel events pass directly through to parent Flickable
 */
Item {
    id: root

    required property var notifItem
    required property int cardIndex

    signal dismissRequested(var item)
    signal actionInvoked(var item, var actionObj)
    signal cardHoveredChanged(var cardItem, bool hovered)

    readonly property bool isUnread: root.notifItem ? (root.notifItem.unread === true) : false
    readonly property var actionsList: (root.notifItem && root.notifItem.actions) ? root.notifItem.actions : []
    readonly property bool hasActions: actionsList.length > 0

    property bool isExpanded: false
    property bool isDying: false
    property bool isClearing: false

    width: parent ? parent.width : 272
    implicitWidth: 272
    height: isDying ? 0 : (cardContentCol.implicitHeight + 22)
    clip: true

    Behavior on height {
        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    opacity: isDying ? 0.0 : 1.0
    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    function triggerClearAnimation(delayMs) {
        root.isClearing = true
        root.slideTargetX = root.width + 60
        clearTimer.interval = delayMs
        clearTimer.restart()
    }

    Timer {
        id: clearTimer
        repeat: false
        onTriggered: {
            slideOutAnim.restart()
        }
    }

    property real slideTargetX: 0

    function commitSlideOut(dir) {
        root.slideTargetX = dir * (root.width + 60)
        slideOutAnim.restart()
    }

    // Slide-out animation for dismiss
    SequentialAnimation {
        id: slideOutAnim
        ParallelAnimation {
            NumberAnimation {
                target: cardBody
                property: "x"
                to: root.slideTargetX !== 0 ? root.slideTargetX : (cardBody.x >= 0 ? (root.width + 60) : (-root.width - 60))
                duration: 220
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: cardBody
                property: "opacity"
                to: 0.0
                duration: 200
                easing.type: Easing.OutQuad
            }
        }
        ScriptAction {
            script: {
                root.isDying = true
                if (!root.isClearing) {
                    collapseTimer.restart()
                }
            }
        }
    }

    Timer {
        id: collapseTimer
        interval: 210
        repeat: false
        onTriggered: {
            if (!root.isClearing) {
                root.dismissRequested(root.notifItem)
            }
        }
    }

    function activateAndRedirect() {
        if (root.notifItem && root.notifItem.unread) {
            NotificationService.markRead(root.notifItem.id)
        }
        var app = root.notifItem ? String(root.notifItem.appName || "").trim() : ""
        var icon = root.notifItem ? String(root.notifItem.appIcon || "").trim() : ""
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
        root.isExpanded = !root.isExpanded
    }

    /* ── 1. Behind-the-card Commit Pill Track (revealed on horizontal swipe) ── */
    Rectangle {
        id: commitTrack
        anchors.fill: parent
        radius: 16
        color: Qt.rgba(Theme.m3surfaceVariant.r, Theme.m3surfaceVariant.g, Theme.m3surfaceVariant.b, 0.45)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
        visible: Math.abs(cardBody.x) > 2

        readonly property bool swipingLeft: cardBody.x < 0
        readonly property real commitProgress: Math.min(1.0, Math.abs(cardBody.x) / 75.0)
        readonly property bool isCommitted: Math.abs(cardBody.x) >= 74.0

        // Slide-Commit Handle
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            x: commitTrack.swipingLeft ? (parent.width - width - 12) : 12
            width: commitTrack.isCommitted ? 42 : (30 + 8 * commitTrack.commitProgress)
            height: 30
            radius: 15
            color: commitTrack.isCommitted ? Theme.accent : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20 * commitTrack.commitProgress)
            border.width: 1
            border.color: commitTrack.isCommitted ? Theme.accent : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)

            scale: commitTrack.isCommitted ? 1.12 : (0.85 + 0.15 * commitTrack.commitProgress)
            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
            Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: 150 } }

            Text {
                anchors.centerIn: parent
                text: commitTrack.isCommitted ? "✓" : (commitTrack.swipingLeft ? "←" : "→")
                font.family: "Manrope"
                font.pixelSize: commitTrack.isCommitted ? 14 : 12
                font.weight: Font.Bold
                color: commitTrack.isCommitted ? Theme.accentFg : Theme.fg
            }
        }
    }

    /* ── 2. Front Interactive Card Body ── */
    Rectangle {
        id: cardBody
        width: parent.width
        height: parent.height
        radius: 16
        color: root.isUnread
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
            : Qt.rgba(Theme.m3surfaceContainerHigh.r, Theme.m3surfaceContainerHigh.g, Theme.m3surfaceContainerHigh.b, 0.65)
        border.width: 1
        border.color: root.isUnread
            ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40)
            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)

        // Smooth return animation when released below commit threshold
        Behavior on x {
            id: cardXAnim
            enabled: !cardDragArea.pressed && !slideOutAnim.running
            NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
        }

        // Horizontal swipe gesture area (non-stealing)
        MouseArea {
            id: cardDragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            property real startRootX: 0
            property real startRootY: 0
            property bool isHorizontalDrag: false

            // Do NOT capture wheel events: propagate cleanly to parent Flickable
            onWheel: (wheel) => {
                wheel.accepted = false
            }

            onEntered: {
                root.cardHoveredChanged(root, true)
            }
            onExited: {
                root.cardHoveredChanged(root, false)
            }

            onPressed: (mouse) => {
                var p = cardDragArea.mapToItem(root, mouse.x, mouse.y)
                startRootX = p.x
                startRootY = p.y
                isHorizontalDrag = false
            }

            onPositionChanged: (mouse) => {
                if (pressed) {
                    var p = cardDragArea.mapToItem(root, mouse.x, mouse.y)
                    var dx = p.x - startRootX
                    var dy = p.y - startRootY
                    if (!isHorizontalDrag && Math.abs(dx) > 6 && Math.abs(dx) > Math.abs(dy)) {
                        isHorizontalDrag = true
                    }
                    if (isHorizontalDrag) {
                        // Apply rubber resistance beyond 75px commit threshold
                        if (Math.abs(dx) > 75) {
                            var sign = dx > 0 ? 1 : -1
                            var excess = Math.abs(dx) - 75
                            cardBody.x = sign * (75 + (excess * 0.35))
                        } else {
                            cardBody.x = dx
                        }
                    }
                }
            }

            onReleased: (mouse) => {
                if (isHorizontalDrag) {
                    if (Math.abs(cardBody.x) >= 74) {
                        // Slide Commit confirmed!
                        root.commitSlideOut(cardBody.x > 0 ? 1 : -1)
                    } else {
                        // Spring back to 0
                        cardBody.x = 0
                    }
                    isHorizontalDrag = false
                }
            }

            onCanceled: {
                cardBody.x = 0
                isHorizontalDrag = false
            }

            onClicked: (mouse) => {
                if (!isHorizontalDrag && Math.abs(cardBody.x) < 5) {
                    root.activateAndRedirect()
                }
            }
        }

        // Inner Card Content Layout (Padding: 11px 12px)
        ColumnLayout {
            id: cardContentCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            anchors.topMargin: 11
            anchors.bottomMargin: 11
            spacing: 5

            // ── Top Row: App Icon + 6px coral dot + App Name (11px bold uppercase) + Relative Timestamp ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // App Icon (18px x 18px)
                Rectangle {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 5
                    color: Qt.rgba(Theme.m3surfaceVariant.r, Theme.m3surfaceVariant.g, Theme.m3surfaceVariant.b, 0.40)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
                    clip: true

                    Image {
                        id: iconImg
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        fillMode: Image.PreserveAspectFit
                        source: {
                            var icon = root.notifItem ? (root.notifItem.appIcon || "") : ""
                            if (icon.indexOf("/") !== -1 || icon.startsWith("file:")) return icon
                            if (icon) {
                                var p = Quickshell.iconPath(icon, "")
                                if (p) return p
                            }
                            var app = root.notifItem ? (root.notifItem.appName || "") : ""
                            if (app) {
                                var pApp = Quickshell.iconPath(app.toLowerCase(), "")
                                if (pApp) return pApp
                                var pDash = Quickshell.iconPath(app.toLowerCase().replace(/\s+/g, "-"), "")
                                if (pDash) return pDash
                            }
                            return ""
                        }
                        visible: status === Image.Ready && source !== ""
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !iconImg.visible
                        text: {
                            var n = root.notifItem ? (root.notifItem.appName || "") : ""
                            return n.length > 0 ? n.charAt(0).toUpperCase() : "•"
                        }
                        font.family: "Manrope"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.accent
                    }
                }

                // 6px Unread Accent Dot
                Rectangle {
                    visible: root.isUnread
                    Layout.preferredWidth: 6
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Theme.accent
                }

                // App Name in 11px bold uppercase
                Text {
                    text: {
                        var app = root.notifItem ? (root.notifItem.appName || "System") : "System"
                        return app.toUpperCase()
                    }
                    font.family: "Manrope"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                    font.letterSpacing: 0.6
                    color: Theme.fgDim
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // Relative Timestamp ("now", "2m", "1h")
                Text {
                    text: root.notifItem ? (root.notifItem.timeStr || "now") : "now"
                    font.family: "Manrope"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Theme.fgFaint
                    Layout.alignment: Qt.AlignRight
                }
            }

            // ── Middle: Summary in 13px weight 700 ──
            Text {
                Layout.fillWidth: true
                text: root.notifItem ? (root.notifItem.summary || "Notification") : "Notification"
                font.family: "Manrope"
                font.pixelSize: 13
                font.weight: Font.Bold
                color: Theme.fg
                wrapMode: Text.Wrap
                maximumLineCount: root.isExpanded ? 4 : 2
                elide: Text.ElideRight
                visible: text.length > 0
            }

            // ── Bottom: Body in 12px ──
            Text {
                Layout.fillWidth: true
                text: root.notifItem ? (root.notifItem.body || "") : ""
                font.family: "Manrope"
                font.pixelSize: 12
                font.weight: Font.Normal
                lineHeight: 1.25
                color: Theme.fgDim
                wrapMode: Text.Wrap
                maximumLineCount: root.isExpanded ? 8 : 2
                elide: Text.ElideRight
                visible: text.length > 0
            }

            // ── Action Pills (Revealed when expanded) ──
            Flow {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 6
                visible: root.isExpanded

                Repeater {
                    model: root.actionsList
                    delegate: Rectangle {
                        id: actBtn
                        required property var modelData
                        height: 24
                        width: actText.implicitWidth + 16
                        radius: 12
                        color: actMouse.containsMouse ? Theme.bgHover : Qt.rgba(255/255, 255/255, 255/255, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)

                        Text {
                            id: actText
                            anchors.centerIn: parent
                            text: actBtn.modelData.text || "Action"
                            font.family: "Manrope"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            color: Theme.fg
                        }

                        MouseArea {
                            id: actMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (actBtn.modelData && typeof actBtn.modelData.invoke === "function") {
                                    actBtn.modelData.invoke()
                                }
                                root.actionInvoked(root.notifItem, actBtn.modelData)
                            }
                        }
                    }
                }

                // Explicit "Dismiss" Pill
                Rectangle {
                    id: dismissPill
                    height: 24
                    width: dismissText.implicitWidth + 16
                    radius: 12
                    color: dismissMouse.containsMouse ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.25) : Qt.rgba(255/255, 255/255, 255/255, 0.06)
                    border.width: 1
                    border.color: dismissMouse.containsMouse ? Theme.err : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)

                    Text {
                        id: dismissText
                        anchors.centerIn: parent
                        text: "Dismiss"
                        font.family: "Manrope"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: dismissMouse.containsMouse ? Theme.err : Theme.fgDim
                    }

                    MouseArea {
                        id: dismissMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            slideOutAnim.restart()
                        }
                    }
                }
            }
        }
    }
}
