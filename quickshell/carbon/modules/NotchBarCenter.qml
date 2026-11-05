import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Singletons"
import "../components"

/**
 * NotchBarCenter: Top-attached curved notch for Center (Clock & Music)
 *   - Bold two-tone Titan clock (10:19)
 *   - Vertical separator (|)
 *   - Animated spinning vinyl disc / album art
 *   - Two-line track title & artist (Do I Wanna Know? / Arctic Monkeys)
 */
NotchContainer {
    id: root

    property bool isExpanded: false
    clip: true
    bottomRadius: isExpanded ? Theme.px(20) : Theme.px(14)
    readonly property real dashImplicitHeight: dashContent ? dashContent.implicitHeight : Theme.px(270)
    readonly property real dashImplicitWidth: dashContent ? dashContent.implicitWidth : Theme.px(820)
    implicitHeight: isExpanded ? dashImplicitHeight : ((root.dragActive || root.isUploading) ? Theme.px(48) : Theme.px(34))
    implicitWidth: isExpanded ? dashImplicitWidth : (contentImplicitWidth + (leftFillet ? filletRadius : 0) + (rightFillet ? filletRadius : 0) + (horizontalPadding * 2))

    property int notchPage: 0
    onNotchPageChanged: {
        if (dashContent && dashContent.notchPage !== root.notchPage) {
            dashContent.notchPage = root.notchPage
        }
    }
    function previousPage() {
        if (root.notchPage > -1) {
            root.notchPage--
            if (dashContent) dashContent.notchPage = root.notchPage
        }
    }
    function nextPage() {
        if (root.notchPage < 1) {
            root.notchPage++
            if (dashContent) dashContent.notchPage = root.notchPage
        }
    }

    earWidth: Theme.px(20)
    contentSpacing: Theme.px(8)

    signal openMusicHover()
    signal closeMusicHover()
    signal toggleMusic()
    signal openMusic()
    signal toggleControls()
    signal toggleCenterDashboard()
    signal openCenterDashboard()
    signal closeCenterDashboard()
    signal openSpatialCanvasNode(int gx, int gy)
    signal openNotifications()

    /* ── Live Notification State ─────────────────────────────────────── */
    property var activeToast: null
    property bool showNotchToast: false
    readonly property int unreadNotifCount: NotificationService.unreadCount || (GlobalState.notificationsList ? (GlobalState.notificationsList.length || 0) : 0)

    readonly property string notificationContentText: {
        if (!root.activeToast) return ""
        var app = (root.activeToast.appName || "").trim()
        var sum = (root.activeToast.summary || "").trim()
        var bod = (root.activeToast.body || "").trim()
        if (sum === app && bod.length > 0) return bod
        if (sum.length > 0 && bod.length > 0 && bod !== sum) return sum + "  " + bod
        if (sum.length > 0) return sum
        if (bod.length > 0) return bod
        return "New notification"
    }

    Timer {
        id: notchToastTimer
        interval: 3500
        repeat: false
        onTriggered: root.showNotchToast = false
    }

    Connections {
        target: NotificationService
        function onNotificationArrived(item) {
            if (NotificationService.dnd || GlobalState.doNotDisturb) return
            root.activeToast = item
            root.showNotchToast = true
            notchToastTimer.restart()
        }
    }

    function openSpatialControlDeck() {
        root.showNotchToast = false
        root.openNotifications()
        root.openSpatialCanvasNode(0, 1)
        Quickshell.execDetached(["sh", (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/carbon-ipc.sh", "spatial-media"])
    }

    property bool showVinylDisc: true
    property bool showEqualizer: true

    readonly property bool hudActive: HudService.active

    focus: root.isExpanded
    Keys.enabled: root.isExpanded
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.closeCenterDashboard()
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            root.previousPage()
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            root.nextPage()
            event.accepted = true
        }
    }
    Keys.onEscapePressed: (event) => {
        root.closeCenterDashboard()
        event.accepted = true
    }

    onIsExpandedChanged: {
        if (root.isExpanded) {
            root.forceActiveFocus()
        }
    }

    mouseArea.hoverEnabled: false
    mouseArea.cursorShape: Qt.PointingHandCursor
    mouseArea.acceptedButtons: Qt.LeftButton | Qt.RightButton
    mouseArea.onClicked: (mouse) => {
        if (root.hudActive) {
            HudService.dismiss()
            return
        }
        if (mouse.button === Qt.RightButton) {
            root.togglePlayPause()
        } else {
            root.toggleCenterDashboard()
        }
    }

    /* ── Live Clock State ────────────────────────────────────────────── */
    property var currentTime: new Date()
    property int currentHourRaw: currentTime.getHours()
    property int currentHour12: {
        let h = root.currentHourRaw % 12
        return h === 0 ? 12 : h
    }
    property string hourStr: (root.currentHour12 < 10 ? "0" : "") + root.currentHour12
    property string minStr: {
        let m = root.currentTime.getMinutes()
        return (m < 10 ? "0" : "") + m
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    /* ── MPRIS State ─────────────────────────────────────────────────── */
    readonly property var players: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    property var activePlayer: null

    function resolveActivePlayer() {
        if (!root.players || root.players.length === 0) return null
        for (let i = 0; i < root.players.length; i++) {
            if (root.players[i].playbackState === MprisPlaybackState.Playing)
                return root.players[i]
        }
        for (let i = 0; i < root.players.length; i++) {
            if (root.players[i].playbackState === MprisPlaybackState.Paused
                && (root.players[i].trackTitle || "").length > 0)
                return root.players[i]
        }
        return root.players[0]
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.activePlayer = root.resolveActivePlayer()
    }

    trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: root.activePlayer !== null && root.trackTitle.trim().length > 0

    function togglePlayPause() {
        if (root.activePlayer) root.activePlayer.togglePlaying()
    }

    property string barContent: "both"

    /* ── Content Inside Notch ────────────────────────────────────────── */
    content: [
        Item {
            id: notchContentContainer
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Theme.px(26)
            implicitWidth: root.hudActive 
                ? dynamicPill.implicitWidth 
                : (root.showNotchToast ? notifCapsuleItem.implicitWidth : normalNotchRow.implicitWidth)
            opacity: root.isExpanded ? 0.0 : 1.0
            visible: opacity > 0.01

            Behavior on opacity {
                NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
            }

            Behavior on implicitWidth {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }

            /* HUD Mode: Dynamic Island Pill */
            DynamicIslandPill {
                id: dynamicPill
                anchors.centerIn: parent
                opacity: root.hudActive ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
                }
            }

            /* Notification Mode: Minimal Island Capsule */
            Item {
                id: notifCapsuleItem
                anchors.centerIn: parent
                implicitHeight: Theme.px(26)
                implicitWidth: Math.max(Theme.px(200), Math.min(Theme.px(420), notifCapsuleRow.implicitWidth + Theme.px(16)))
                opacity: (!root.hudActive && root.showNotchToast) ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
                }

                Row {
                    id: notifCapsuleRow
                    anchors.centerIn: parent
                    spacing: Theme.px(10)

                    /* Icon Slot (App Icon or Theme Accent Bell) */
                    Item {
                        width: Theme.px(18)
                        height: Theme.px(18)
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: capsuleAppIcon
                            anchors.fill: parent
                            source: (root.activeToast && root.activeToast.appIcon) ? root.activeToast.appIcon : ""
                            sourceSize: Qt.size(Theme.px(18), Theme.px(18))
                            fillMode: Image.PreserveAspectFit
                            visible: !!source && status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !capsuleAppIcon.visible
                            text: "notifications"
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontPx(16)
                            color: Theme.accent
                        }
                    }

                    /* Text Content */
                    Row {
                        spacing: Theme.px(6)
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: notifAppNameText
                            text: (root.activeToast && root.activeToast.appName && root.activeToast.appName !== "notify-send") ? root.activeToast.appName : ""
                            visible: text.length > 0
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(11.5)
                            font.weight: Font.Bold
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            id: notifBodyText
                            text: root.notificationContentText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontPx(11.5)
                            font.weight: Font.DemiBold
                            color: Theme.fg
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, Theme.px(280))
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openSpatialControlDeck()
                }
            }

            /* Normal Mode: Clock & Music Row */
            Row {
                id: normalNotchRow
                anchors.centerIn: parent
                spacing: Theme.px(8)
                opacity: (root.hudActive || root.showNotchToast) ? 0.0 : 1.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }

                /* 1. Center Island Clock & Notification / DND Indicator */
                Row {
                    id: clockWithIndicatorRow
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.px(6)
                    visible: root.barContent !== "music"
                    z: 10

                    /* Notification Dot / DND Indicator (Left side of Clock) */
                    Item {
                        id: notchNotifIndicator
                        anchors.verticalCenter: parent.verticalCenter
                        readonly property bool isDnd: NotificationService.dnd || GlobalState.doNotDisturb
                        readonly property bool hasNotifs: root.unreadNotifCount > 0
                        visible: isDnd || hasNotifs
                        implicitWidth: visible ? (isDnd ? Theme.px(16) : Theme.px(8)) : 0
                        implicitHeight: Theme.px(16)

                        Behavior on implicitWidth {
                            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                        }

                        // DND Icon: replaces dot when DND is on
                        Text {
                            anchors.centerIn: parent
                            visible: notchNotifIndicator.isDnd
                            text: "notifications_off"
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontPx(13.5)
                            color: Theme.primary
                        }

                        // Simple dot: only a dot, no digit
                        Rectangle {
                            anchors.centerIn: parent
                            visible: !notchNotifIndicator.isDnd && notchNotifIndicator.hasNotifs
                            width: Theme.px(6)
                            height: Theme.px(6)
                            radius: Theme.px(3)
                            color: Theme.primary
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openSpatialControlDeck()
                        }
                    }

                    /* Center Island Clock (Click to toggle Dashboard) */
                    Item {
                        implicitWidth: centerClockItem.implicitWidth
                        implicitHeight: centerClockItem.implicitHeight
                        anchors.verticalCenter: parent.verticalCenter

                        CenterClock {
                            id: centerClockItem
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleCenterDashboard()
                        }
                    }
                }

        /* 2. Vertical Divider */
        Rectangle {
            width: Math.max(1, Theme.px(1.5))
            height: Theme.px(16)
            color: Qt.alpha(Theme.fg, 0.40)
            anchors.verticalCenter: parent.verticalCenter
            visible: root.barContent === "both"
        }

        /* 3. Music Section (Disc + Track Info) */
        Item {
            anchors.verticalCenter: parent.verticalCenter
            implicitHeight: Theme.px(26)
            implicitWidth: musicRow.implicitWidth
            visible: root.barContent !== "clock"

            Row {
                id: musicRow
                spacing: Theme.px(8)
                anchors.verticalCenter: parent.verticalCenter

                /* Spinning Vinyl Disc / Album art */
                Rectangle {
                    id: discContainer
                    width: Theme.px(22)
                    height: Theme.px(22)
                    radius: Theme.px(11)
                    color: Theme.bgAlt
                    border.color: Theme.accent
                    border.width: 1.5
                    anchors.verticalCenter: parent.verticalCenter
                    clip: true
                    visible: root.showVinylDisc

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePlayPause()
                    }

                    Image {
                        id: albumArtImg
                        anchors.fill: parent
                        source: root.artUrl
                        sourceSize: Qt.size(Theme.px(44), Theme.px(44))
                        visible: root.hasTrack && root.artUrl.length > 0
                        fillMode: Image.PreserveAspectCrop
                    }

                    Item {
                        id: vinylDisc
                        anchors.fill: parent
                        visible: !root.hasTrack || root.artUrl.length === 0

                        Text {
                            anchors.centerIn: parent
                            text: "music_note"
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontPx(14)
                            color: Theme.accent
                        }
                    }
                }

                /* Dynamic Island 4-Bar Equalizer Waveform */
                Row {
                    id: eqWaveform
                    spacing: Math.max(1, Theme.px(2))
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.showEqualizer && root.hasTrack

                    Repeater {
                        model: [
                            { minH: Theme.px(3), maxH: Theme.px(13), dur: 380 },
                            { minH: Theme.px(4), maxH: Theme.px(15), dur: 520 },
                            { minH: Theme.px(3), maxH: Theme.px(11), dur: 440 },
                            { minH: Theme.px(4), maxH: Theme.px(14), dur: 610 }
                        ]

                        delegate: Rectangle {
                            id: eqBar
                            required property var modelData
                            required property int index

                            width: Math.max(1, Theme.px(2.5))
                            radius: Math.max(1, Theme.px(1.25))
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter

                            height: root.isPlaying ? modelData.minH : Math.max(1, Theme.px(2.5))

                            SequentialAnimation on height {
                                running: root.isPlaying && root.visible
                                loops: Animation.Infinite
                                NumberAnimation { to: eqBar.modelData.maxH; duration: eqBar.modelData.dur; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: eqBar.modelData.minH; duration: eqBar.modelData.dur * 0.85; easing.type: Easing.InOutQuad }
                            }

                            Behavior on height {
                                enabled: !root.isPlaying
                                NumberAnimation { duration: 250; easing.type: Easing.OutQuad }
                            }
                        }
                    }
                }

                /* Song & Artist Info (Two lines) */
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: root.hasTrack ? root.trackTitle : "Nothing Playing"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Bold
                        color: root.hasTrack ? Theme.fg : Theme.fgDim
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, Theme.px(150))
                    }

                    Text {
                        text: root.hasTrack ? root.trackArtist : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontPx(9)
                        font.weight: Font.Medium
                        color: Theme.fgDim
                        elide: Text.ElideRight
                        width: Math.min(implicitWidth, Theme.px(150))
                        visible: text.length > 0
                    }
                }
            }
        }

    }
    }
    ]

    CenterDashboard {
        id: dashContent
        parent: root
        z: 5
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: (root.leftFillet && root.filletRadius > 0) ? root.filletRadius : 0
        anchors.right: parent.right
        anchors.rightMargin: (root.rightFillet && root.filletRadius > 0) ? root.filletRadius : 0
        showBackground: false
        open: root.isExpanded
        notchPage: root.notchPage
        onNotchPageChanged: {
            if (root.notchPage !== dashContent.notchPage) {
                root.notchPage = dashContent.notchPage
            }
        }
        visible: opacity > 0.01
        opacity: root.isExpanded ? 1.0 : 0.0
        scale: root.isExpanded ? 1.0 : 0.98
        Behavior on opacity {
            NumberAnimation { duration: root.isExpanded ? 220 : 150; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: root.isExpanded ? 260 : 180; easing.type: Easing.OutCubic }
        }
        onCloseRequested: root.closeCenterDashboard()
    }
}
