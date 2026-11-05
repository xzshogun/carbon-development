import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../Singletons"

/**
 * NotificationPanel.qml
 *
 * Slim Minimalist Vanish-Mode Notification Center (296px Width)
 * - 296px width, height: Math.min(450, screenH - 48), radius: 26
 * - Glass surface rgba(12, 15, 18, 0.78) with 28px blur & 1px rgba(255,255,255, 0.09) border
 * - Header: "Notifications" (16px weight 800) + dynamic subtitle ("N unread", "All caught up", or "Do not disturb is on")
 *   + Two 30px circular buttons (DND toggle & Clear All)
 * - ReactBits Micro-Interaction 1: Rubber-Segment Category Pill (All / Chat / System) with OutBack and rubber stretch
 * - ReactBits Micro-Interaction 2: Vertical Glide-Select Hover Follower behind cards with 2.5px coral left bar
 * - Flickable scroll list with non-stealing gestures and smooth WheelHandler
 * - Empty State: Centered 48px bell circle, "All quiet", "No new notifications right now"
 * - Clear All: Staggers card slide-out by 50ms, dismisses daemon notifs, and transitions cleanly to empty state
 */
Rectangle {
    id: panelRoot

    property bool open: false
    property bool isClearing: false
    signal closeRequested()

    width: 340
    implicitWidth: 340
    implicitHeight: Math.min(450, (panelRoot.parent ? panelRoot.parent.height : 768) - 48)
    height: implicitHeight
    radius: 26
    color: Qt.rgba(Theme.m3surfaceContainer.r, Theme.m3surfaceContainer.g, Theme.m3surfaceContainer.b, 0.88)
    border.width: 1
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
    clip: true

    // MultiEffect Shadow container (preserves crisp razor-sharp text)
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.70
        shadowBlur: 0.85
        shadowVerticalOffset: 24
    }

    // Top VisionOS Specular Rim Highlight
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        height: 1
        color: Qt.rgba(255/255, 255/255, 255/255, 0.16)
    }

    // Tab state: 0 = "All", 1 = "Chat", 2 = "System"
    property int currentTab: 0

    function getFilteredItems(tab, items) {
        if (!items || items.length === 0) return []
        var res = []
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            if (!item) continue
            var cat = String(item.category || "system").toLowerCase()
            if (tab === 0) {
                res.push(item)
            } else if (tab === 1 && cat === "chat") {
                res.push(item)
            } else if (tab === 2 && cat === "system") {
                res.push(item)
            }
        }
        return res
    }

    readonly property var allItems: NotificationService.list || []
    readonly property var tabItems: panelRoot.getFilteredItems(panelRoot.currentTab, panelRoot.allItems)

    readonly property int totalCount: tabItems.length
    readonly property int unreadCount: {
        var c = 0
        for (var i = 0; i < tabItems.length; i++) {
            if (tabItems[i] && tabItems[i].unread) c++
        }
        return c
    }

    readonly property int chatCount: {
        var c = 0
        var items = panelRoot.allItems
        for (var i = 0; i < items.length; i++) {
            if (items[i] && String(items[i].category || "").toLowerCase() === "chat") c++
        }
        return c
    }

    readonly property int systemCount: {
        var c = 0
        var items = panelRoot.allItems
        for (var i = 0; i < items.length; i++) {
            if (items[i] && String(items[i].category || "").toLowerCase() === "system") c++
        }
        return c
    }

    readonly property string subtitleText: {
        if (NotificationService.dnd) return "Do not disturb is on"
        if (panelRoot.unreadCount > 0) return panelRoot.unreadCount + " unread"
        return "All caught up"
    }

    // Reference to currently hovered card for Vertical Glide-Select Follower
    property var hoveredCardItem: null

    function handleCardHovered(cardItem, hovered) {
        if (hovered) {
            panelRoot.hoveredCardItem = cardItem
        } else if (panelRoot.hoveredCardItem === cardItem) {
            panelRoot.hoveredCardItem = null
        }
    }

    // ── Working Clear All with Smooth Stagger ──────────────────────────────────
    function clearCurrentTab() {
        if (panelRoot.totalCount === 0 || panelRoot.isClearing) return
        panelRoot.isClearing = true
        panelRoot.hoveredCardItem = null

        var targetCat = (panelRoot.currentTab === 0) ? "all" : ((panelRoot.currentTab === 1) ? "chat" : "system")
        var count = cardRepeater.count
        var stepMs = count > 1 ? Math.min(30, Math.floor(150 / count)) : 0

        // Trigger staggered slide-out on visible card delegates
        for (var i = 0; i < count; i++) {
            var card = cardRepeater.itemAt(i)
            if (card && typeof card.triggerClearAnimation === "function") {
                card.triggerClearAnimation(i * stepMs)
            }
        }

        // Timer to commit clearing in model after staggered slide completes
        clearCommitTimer.targetCat = targetCat
        clearCommitTimer.interval = Math.min(350, (count * stepMs) + 240)
        clearCommitTimer.restart()
    }

    Timer {
        id: clearCommitTimer
        property string targetCat: "all"
        repeat: false
        onTriggered: {
            NotificationService.clearCategory(targetCat)
            panelRoot.hoveredCardItem = null
            panelRoot.isClearing = false
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ── 1. Minimal Header ────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Notifications"
                    font.family: "Manrope"
                    font.pixelSize: 16
                    font.weight: Font.ExtraBold // 800
                    color: Theme.fg
                }

                Text {
                    text: panelRoot.subtitleText
                    font.family: "Manrope"
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: NotificationService.dnd ? Theme.accent : Theme.fgDim
                }
            }

            // Two 30px Circular Action Buttons
            RowLayout {
                spacing: 6

                // 1. DND Toggle Button (Moon)
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: NotificationService.dnd
                        ? Theme.accent
                        : (dndBtnMouse.containsMouse ? Theme.bgHover : Qt.rgba(255/255, 255/255, 255/255, 0.06))
                    border.width: 1
                    border.color: NotificationService.dnd ? Theme.accent : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)
                    scale: dndBtnMouse.pressed ? 0.92 : (dndBtnMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "notifications_off"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: NotificationService.dnd ? Theme.accentFg : Theme.fg
                    }

                    MouseArea {
                        id: dndBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: NotificationService.toggleDnd()
                    }
                }

                // 2. Clear All Button (Trash)
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    visible: panelRoot.totalCount > 0
                    color: clearBtnMouse.containsMouse
                        ? Qt.rgba(Theme.err.r, Theme.err.g, Theme.err.b, 0.25)
                        : Qt.rgba(255/255, 255/255, 255/255, 0.06)
                    border.width: 1
                    border.color: clearBtnMouse.containsMouse ? Theme.err : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)
                    scale: clearBtnMouse.pressed ? 0.92 : (clearBtnMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale { NumberAnimation { duration: 120 } }
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "delete"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: clearBtnMouse.containsMouse ? Theme.err : Theme.fg
                    }

                    MouseArea {
                        id: clearBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: panelRoot.clearCurrentTab()
                    }
                }
            }
        }

        // ── 2. ReactBits Rubber-Segment Category Pill (All / Chat / System) ─
        Rectangle {
            id: categoryTrack
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            radius: 999
            color: Theme.bgAlt
            border.width: 1
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)

            readonly property real segmentWidth: (width - 6) / 3

            // Sliding Rubber Indicator Pill
            Rectangle {
                id: rubberPill
                x: 3 + (panelRoot.currentTab * categoryTrack.segmentWidth)
                y: 3
                width: categoryTrack.segmentWidth
                height: 24
                radius: 999
                color: Theme.accent
                transformOrigin: Item.Center

                Behavior on x {
                    NumberAnimation {
                        duration: 360
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.15
                    }
                }

                // Rubber stretch animation on tab change
                SequentialAnimation {
                    id: rubberAnim
                    ParallelAnimation {
                        NumberAnimation { target: rubberPill; property: "scale"; to: 1.0; duration: 1 }
                        NumberAnimation { target: rubberPillScale; property: "xScale"; to: 1.22; duration: 160; easing.type: Easing.OutQuad }
                        NumberAnimation { target: rubberPillScale; property: "yScale"; to: 0.84; duration: 160; easing.type: Easing.OutQuad }
                    }
                    ParallelAnimation {
                        NumberAnimation { target: rubberPillScale; property: "xScale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                        NumberAnimation { target: rubberPillScale; property: "yScale"; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                    }
                }

                transform: Scale {
                    id: rubberPillScale
                    origin.x: rubberPill.width / 2
                    origin.y: rubberPill.height / 2
                    xScale: 1.0
                    yScale: 1.0
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 3
                spacing: 0

                Repeater {
                    model: ["All", "Chat", "System"]
                    delegate: Item {
                        required property int index
                        required property string modelData

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5

                            Text {
                                text: modelData
                                font.family: "Manrope"
                                font.pixelSize: 11
                                font.weight: panelRoot.currentTab === index ? Font.Bold : Font.Medium
                                color: panelRoot.currentTab === index ? Theme.accentFg : Theme.fgDim
                            }

                            Rectangle {
                                visible: {
                                    var cnt = (index === 0) ? panelRoot.allItems.length : ((index === 1) ? panelRoot.chatCount : panelRoot.systemCount)
                                    return cnt > 0
                                }
                                Layout.preferredWidth: Math.max(15, tabBadgeText.implicitWidth + 6)
                                Layout.preferredHeight: 14
                                radius: 7
                                color: panelRoot.currentTab === index ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.18)

                                Text {
                                    id: tabBadgeText
                                    anchors.centerIn: parent
                                    text: {
                                        var cnt = (index === 0) ? panelRoot.allItems.length : ((index === 1) ? panelRoot.chatCount : panelRoot.systemCount)
                                        return cnt > 99 ? "99+" : String(cnt)
                                    }
                                    font.family: "Manrope"
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    color: panelRoot.currentTab === index ? Theme.accentFg : Theme.accent
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (panelRoot.currentTab !== index) {
                                    panelRoot.currentTab = index
                                    rubberAnim.restart()
                                    panelRoot.hoveredCardItem = null
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── 3. Scrollable List & ReactBits Vertical Glide-Select Follower ───
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Empty State
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                visible: panelRoot.totalCount === 0

                // Centered 48px Bell Circle
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 48
                    height: 48
                    radius: 24
                    color: Qt.rgba(255/255, 255/255, 255/255, 0.05)
                    border.width: 1
                    border.color: Qt.rgba(255/255, 255/255, 255/255, 0.10)

                    Text {
                        anchors.centerIn: parent
                        text: "notifications"
                        font.family: Theme.fontIcon
                        font.pixelSize: 22
                        color: Qt.rgba(244/255, 246/255, 245/255, 0.45)
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: panelRoot.currentTab === 1 ? "No chat messages" : (panelRoot.currentTab === 2 ? "No system alerts" : "All quiet")
                    font.family: "Manrope"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: panelRoot.currentTab === 1 ? "Messages from chat and social apps will appear here" : (panelRoot.currentTab === 2 ? "System, hardware, and OS alerts will appear here" : "No new notifications right now")
                    font.family: "Manrope"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Theme.fgDim
                }
            }

            // Scrollable Content
            Flickable {
                id: notifFlickable
                anchors.fill: parent
                contentHeight: listContainer.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick
                interactive: true
                clip: true
                visible: panelRoot.totalCount > 0

                WheelHandler {
                    target: notifFlickable
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        var delta = -event.angleDelta.y * 0.75
                        var maxY = Math.max(0, notifFlickable.contentHeight - notifFlickable.height)
                        notifFlickable.contentY = Math.max(0, Math.min(maxY, notifFlickable.contentY + delta))
                    }
                }

                Item {
                    id: listContainer
                    width: notifFlickable.width
                    implicitHeight: cardColumn.implicitHeight + 8

                    // ReactBits Vertical Glide-Select Hover Follower
                    Rectangle {
                        id: hoverFollower
                        z: 0
                        x: 0
                        width: parent.width
                        radius: 16
                        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08)
                        border.width: 1
                        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                        visible: opacity > 0.01
                        opacity: panelRoot.hoveredCardItem ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                        // Stable last-known position — only update while a card IS hovered.
                        // This prevents the follower from snapping to y:0 the moment
                        // hoveredCardItem becomes null (which happens before the fade-out finishes).
                        property real stableY: 0
                        property real stableH: 48

                        Connections {
                            target: panelRoot
                            function onHoveredCardItemChanged() {
                                var card = panelRoot.hoveredCardItem
                                if (card) {
                                    hoverFollower.stableY = card.y
                                    hoverFollower.stableH = card.height
                                }
                                // When null: keep stableY/stableH as-is so the follower
                                // stays in place and fades out smoothly where it was.
                            }
                        }

                        // Animate toward the stable position with SmoothedAnimation
                        // for velocity-continuous gliding (no snapping on rapid hovers)
                        Behavior on y {
                            SmoothedAnimation { velocity: 900; easing.type: Easing.OutCubic }
                        }
                        Behavior on height {
                            SmoothedAnimation { velocity: 600; easing.type: Easing.OutCubic }
                        }

                        y: hoverFollower.stableY
                        height: hoverFollower.stableH

                        // 2.5px vertical indicator bar on left edge
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.topMargin: 8
                            anchors.bottomMargin: 8
                            anchors.leftMargin: 2
                            width: 2.5
                            radius: 1.25
                            color: Theme.accent
                        }
                    }

                    // Card List Column
                    Column {
                        id: cardColumn
                        z: 1
                        width: parent.width
                        spacing: 8

                        Repeater {
                            id: cardRepeater
                            model: panelRoot.tabItems

                            delegate: NotificationCard {
                                id: cardDelegate
                                required property var modelData
                                required property int index

                                notifItem: modelData
                                cardIndex: index
                                width: cardColumn.width

                                onCardHoveredChanged: function(cardItem, hovered) {
                                    panelRoot.handleCardHovered(cardItem, hovered)
                                }

                                onDismissRequested: function(item) {
                                    if (item && item.id !== undefined) {
                                        NotificationService.dismiss(item.id)
                                    }
                                    if (panelRoot.hoveredCardItem === cardDelegate) {
                                        panelRoot.hoveredCardItem = null
                                    }
                                }

                                onActionInvoked: function(item, actionObj) {
                                    NotificationService.invokeAction(item, actionObj)
                                }
                            }
                        }
                    }
                }
            }

            // Top and Bottom Smooth Fade Edges
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 12
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(12/255, 15/255, 18/255, 0.95) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
                visible: notifFlickable.visible && notifFlickable.contentY > 2
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 12
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(12/255, 15/255, 18/255, 0.95) }
                }
                visible: notifFlickable.visible
            }
        }
    }
}
