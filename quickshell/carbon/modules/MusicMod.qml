import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Singletons"
import "../components"

/**
 * Nebula-style Top-Center Island:
 *   - Collapsed: Dual-tone Titan One 3D clock + divider + circular album art + 2-line title/artist + visualizer
 *   - Expanded on hover: Unified two-column dropdown with full Month Calendar on left and rich Media Player on right
 */
Item {
    id: root

    implicitWidth: 580
    implicitHeight: 330

    readonly property var players: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    readonly property var activePlayer: LyricsService.activePlayer

    property string barMode: "pill"
    property bool externalOpen: false
    property bool expanded: false
    property bool pinned: false
    property bool attachedBottom: false
    readonly property bool isExpanded: root.externalOpen || root.pinned || root.expanded
    property bool pillHovered: false
    property bool panelHovered: false

    signal panelHoverChanged(bool hovered)

    readonly property var cardItem: flyoutPanel
    readonly property bool animatingOut: !root.isExpanded && flyoutPanel.opacity > 0.001

    /* Visualizer animation */
    property real visualizerPhase: 0

    /* Track metadata */
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string trackAlbum: activePlayer && activePlayer.metadata ? (activePlayer.metadata["xesam:album"] || "") : ""
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property string playerIdentity: activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "Music") : "Music"
    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: root.trackTitle !== ""
    readonly property bool showCondition: true

    /* ── Live Clock State ────────────────────────────────────────────────── */
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
    property string hourDigit1: root.hourStr.length > 0 ? root.hourStr[0] : "1"
    property string hourDigit2: root.hourStr.length > 1 ? root.hourStr[1] : "2"
    property string minuteDigit1: root.minStr.length > 0 ? root.minStr[0] : "0"
    property string minuteDigit2: root.minStr.length > 1 ? root.minStr[1] : "0"

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    /* ── Clock Style Configuration ───────────────────────────────────────── */
    property string clockStyle: "titan"
    property string clockFont: root.clockStyle === "titan" ? "Titan One"
                             : (root.clockStyle === "digital" ? "Orbitron"
                             : (root.clockStyle === "pixel" ? "Pixelon" : "JetBrainsMono Nerd Font"))

    readonly property int clockPixelSize: root.clockStyle === "titan" ? 19
                                        : (root.clockStyle === "digital" ? 15
                                        : (root.clockStyle === "pixel" ? 15 : 17))
    readonly property int clockSpacing: root.clockStyle === "titan" ? -2
                                      : (root.clockStyle === "minimal" ? 0 : 1)

    FileView {
        id: clockCfgFile
        path: (Quickshell.env("HOME") || "") + "/.config/hypr/carbon-clock-style.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadClockStyle()
        onFileChanged: reload()
    }

    function reloadClockStyle() {
        try {
            const txt = clockCfgFile.text().trim()
            if (txt.length > 0) {
                const parsed = JSON.parse(txt)
                const s = parsed.style
                if (s === "titan" || s === "minimal" || s === "digital" || s === "pixel") {
                    root.clockStyle = s
                }
            }
        } catch (e) {}
    }

    /* ── Track Position & Duration ───────────────────────────────────────── */
    readonly property real totalLength: {
        if (!activePlayer) return 0
        if (activePlayer.lengthSupported && activePlayer.length > 0)
            return activePlayer.length
        if (activePlayer.metadata && activePlayer.metadata["mpris:length"]) {
            const raw = Number(activePlayer.metadata["mpris:length"])
            if (isFinite(raw) && raw > 0) return raw / 1000000
        }
        return 0
    }

    readonly property real currentPosition: {
        if (!activePlayer) return 0
        return activePlayer.position || 0
    }

    readonly property real progress: totalLength > 0
        ? Math.max(0, Math.min(1, currentPosition / totalLength)) : 0

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec <= 0) return "0:00"
        const m = Math.floor(sec / 60)
        const s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    function visualizerLevel(index) {
        const offset = index * 0.9
        const s1 = Math.sin(root.visualizerPhase + offset)
        const s2 = Math.sin(root.visualizerPhase * 1.7 - offset * 0.6)
        return Math.max(0.1, Math.min(1.0, (s1 + s2 + 2) / 4))
    }

    function pausedVisualizerLevel(index) {
        return 0.15 + (index % 2) * 0.1
    }

    /* ── Live Position & Progress Tracker (Quickshell MPRIS requirement) ─ */
    Timer {
        id: positionTracker
        interval: 250
        running: root.isPlaying && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.activePlayer && root.activePlayer.positionSupported) {
                root.activePlayer.positionChanged()
            }
        }
    }

    FrameAnimation {
        running: root.isPlaying && root.visible
        onTriggered: root.visualizerPhase += frameTime * 5.45
    }

    /* ── Playback Controls ───────────────────────────────────────────────── */
    function togglePlayPause() {
        LyricsService.togglePlaying()
    }

    function playPrev() {
        LyricsService.skipPrevious()
    }

    function playNext() {
        LyricsService.skipNext()
    }

    function toggleShuffle() {
        Quickshell.execDetached(["playerctl", "shuffle", "Toggle"])
    }

    function toggleRepeat() {
        Quickshell.execDetached(["playerctl", "loop", "Track"])
    }

    function seekTo(v) {
        if (root.totalLength > 0) {
            let targetSec = v * root.totalLength
            try {
                if (root.activePlayer) root.activePlayer.position = targetSec
            } catch (e) {}
            Quickshell.execDetached(["playerctl", "position", String(Math.floor(targetSec))])
            if (root.activePlayer && root.activePlayer.positionSupported) {
                root.activePlayer.positionChanged()
            }
        }
    }

    /* ── Hover Leave Timer ───────────────────────────────────────────────── */
    Timer {
        id: leaveTimer
        interval: 350
        onTriggered: {
            if (!root.pillHovered && !root.panelHovered) {
                root.expanded = false
            }
        }
    }

    /* ── Calendar Model & Logic ──────────────────────────────────────────── */
    property int calYear: new Date().getFullYear()
    property int calMonth: new Date().getMonth()

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayNames: ["S", "M", "T", "W", "T", "F", "S"]

    ListModel { id: daysModel }

    function prevMonth() {
        if (root.calMonth === 0) { root.calMonth = 11; root.calYear-- }
        else { root.calMonth-- }
    }

    function nextMonth() {
        if (root.calMonth === 11) { root.calMonth = 0; root.calYear++ }
        else { root.calMonth++ }
    }

    function resetToToday() {
        root.calYear = new Date().getFullYear()
        root.calMonth = new Date().getMonth()
    }

    function rebuildCalendar() {
        daysModel.clear()
        const firstDay = new Date(root.calYear, root.calMonth, 1)
        const startDay = firstDay.getDay() // 0 = Sunday
        const daysInMonth = new Date(root.calYear, root.calMonth + 1, 0).getDate()
        const prevMonthDays = new Date(root.calYear, root.calMonth, 0).getDate()
        const now = new Date()
        const isCurrentMonth = (now.getFullYear() === root.calYear && now.getMonth() === root.calMonth)
        const todayDate = now.getDate()

        for (let i = 0; i < 42; i++) {
            let d
            let isCurrent
            let isToday
            if (i < startDay) {
                d = prevMonthDays - startDay + i + 1
                isCurrent = false
                isToday = false
            } else if (i >= startDay + daysInMonth) {
                d = i - startDay - daysInMonth + 1
                isCurrent = false
                isToday = false
            } else {
                d = i - startDay + 1
                isCurrent = true
                isToday = isCurrentMonth && (d === todayDate)
            }
            daysModel.append({ day: d, isCurrent: isCurrent, isToday: isToday })
        }
    }

    onCalMonthChanged: root.rebuildCalendar()
    onCalYearChanged: root.rebuildCalendar()
    Component.onCompleted: {
        root.reloadClockStyle()
        root.rebuildCalendar()
    }

    /* ========================================================================= */
    readonly property real pillWidth: pill.width

    /* ========================================================================= */
    /* ── Collapsed Bar View (Top-Center Pill) ────────────────────────────────── */
    /* ========================================================================= */
    Rectangle {
        id: pill
        visible: false
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(340, pillRow.implicitWidth + 20)
        height: 38
        radius: 19
        color: root.pillHovered ? Theme.bgAlt : Theme.bg
        border.color: Theme.outline
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            id: pillRow
            anchors.centerIn: parent
            spacing: 8

            /* ── Left: Dynamic Center Clock ───────────────────────────── */
            CenterClock {
                Layout.alignment: Qt.AlignVCenter
            }

            /* Divider */
            Rectangle {
                Layout.preferredWidth: 1.5
                Layout.preferredHeight: 14
                Layout.alignment: Qt.AlignVCenter
                color: "#55FFFFFF"
            }

            /* ── Center: Circular Artwork + Progress Ring ───────────── */
            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter

                CircularProgress {
                    anchors.fill: parent
                    progress: root.progress
                    thickness: 2
                    lineColor: Theme.accent
                    baseColor: "#2AFFFFFF"
                }

                Item {
                    id: discBox
                    anchors.centerIn: parent
                    width: 19
                    height: 19

                    Item {
                        id: discMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "#FFFFFFFF"
                        }
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: discMask
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.bgAlt
                        }

                        Image {
                            anchors.fill: parent
                            source: root.artUrl
                            sourceSize: Qt.size(38, 38)
                            fillMode: Image.PreserveAspectCrop
                            visible: root.artUrl !== ""
                            asynchronous: true
                        }

                        /* Fallback mini equalizer when no artwork and playing */
                        Row {
                            anchors.centerIn: parent
                            spacing: 1.5
                            visible: root.artUrl === "" && root.isPlaying

                            Repeater {
                                model: 3
                                delegate: Rectangle {
                                    required property int index
                                    width: 2
                                    height: Math.min(8, 2 + 4 * root.visualizerLevel(index))
                                    radius: 1
                                    color: Theme.accent
                                }
                            }
                        }

                        /* Fallback music icon when no artwork and paused */
                        Text {
                            anchors.centerIn: parent
                            text: "music_note"
                            font.family: Theme.fontIcon
                            font.pixelSize: 12
                            color: Theme.fgDim
                            visible: root.artUrl === "" && !root.isPlaying
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            /* ── Track Metadata: Two-Line (Title + Artist) ──────────── */
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: Math.max(90, Math.min(160, titleMarquee.implicitWidth))
                spacing: 0

                MarqueeText {
                    id: titleMarquee
                    Layout.fillWidth: true
                    text: root.hasTrack ? root.trackTitle : "Nothing Playing"
                    fontFamily: "JetBrainsMono Nerd Font"
                    pixelSize: Theme.fontPx(11)
                    fontWeight: Font.Bold
                    textColor: Theme.fg
                    scrolling: root.isPlaying
                }

                Text {
                    Layout.fillWidth: true
                    text: root.hasTrack ? (root.trackArtist !== "" ? root.trackArtist : root.trackAlbum) : "Idle"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(9)
                    font.weight: Font.Medium
                    color: Theme.fgDim
                    elide: Text.ElideRight
                }
            }

            /* ── Right: 5-bar visualizer ────────────────────────────── */
            Item {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 16
                Layout.alignment: Qt.AlignVCenter

                Row {
                    anchors.centerIn: parent
                    spacing: 2.5

                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            required property int index
                            width: 2.5
                            height: root.isPlaying
                                ? 3 + 10 * root.visualizerLevel(index)
                                : 3 + 10 * root.pausedVisualizerLevel(index)
                            radius: 1.2
                            color: root.isPlaying ? Theme.accent : Theme.fgDim

                            Behavior on height {
                                NumberAnimation {
                                    duration: root.isPlaying ? 90 : 160
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                root.pillHovered = true
                leaveTimer.stop()
                root.expanded = true
            }
            onExited: {
                root.pillHovered = false
                leaveTimer.restart()
            }
            onClicked: {
                root.expanded = !root.expanded
            }
        }
    }

    /* ========================================================================= */
    /* ── Expanded Dropdown Overlay (Calendar + Music Player) ─────────────────── */
    /* ========================================================================= */
    Rectangle {
        id: flyoutPanel
        anchors.top: !root.attachedBottom ? parent.top : undefined
        anchors.bottom: root.attachedBottom ? parent.bottom : undefined
        anchors.horizontalCenter: parent.horizontalCenter
        width: 580
        height: 330
        radius: 20
        color: Theme.bg
        border.color: root.isExpanded ? Theme.accentLit : Theme.outline
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 380; easing.type: Easing.OutQuad } }

        transformOrigin: !root.attachedBottom ? Item.Top : Item.Bottom
        transform: Translate {
            y: root.isExpanded ? 0 : (!root.attachedBottom ? -22 : 22)
            Behavior on y {
                NumberAnimation {
                    duration: root.isExpanded ? 300 : 160
                    easing.type: root.isExpanded ? Easing.OutExpo : Easing.InQuad
                }
            }
        }

        opacity: root.isExpanded ? 1 : 0
        visible: opacity > 0
        scale: root.isExpanded ? 1.0 : 0.90

        Behavior on opacity {
            NumberAnimation {
                duration: root.isExpanded ? 220 : 140
                easing.type: root.isExpanded ? Easing.OutCubic : Easing.InQuad
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.isExpanded ? 300 : 160
                easing.type: root.isExpanded ? Easing.OutExpo : Easing.InQuad
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 14

            /* ── Left Column: Interactive Month Calendar ────────────── */
            ColumnLayout {
                id: calendarCol
                Layout.preferredWidth: 260
                Layout.minimumWidth: 260
                Layout.maximumWidth: 260
                Layout.fillHeight: true
                spacing: 6

                opacity: root.isExpanded ? 1 : 0
                transform: Translate {
                    x: root.isExpanded ? 0 : -12
                    y: root.isExpanded ? 0 : 8
                    Behavior on x { NumberAnimation { duration: root.isExpanded ? 280 : 120; easing.type: Easing.OutExpo } }
                    Behavior on y { NumberAnimation { duration: root.isExpanded ? 280 : 120; easing.type: Easing.OutExpo } }
                }
                Behavior on opacity { NumberAnimation { duration: root.isExpanded ? 240 : 120; easing.type: Easing.OutCubic } }

                /* Calendar Header */
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 12
                    color: "#18FFFFFF"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 0

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            color: prevHov.hovered ? "#30FFFFFF" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "\u2039"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(18)
                                color: Theme.fg
                            }
                            MouseArea {
                                id: prevHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.prevMonth()
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: root.monthNames[root.calMonth]
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(13)
                                font.weight: Font.Bold
                                color: Theme.fg
                            }

                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: String(root.calYear)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(10)
                                color: Theme.fgDim
                            }
                        }

                        Rectangle {
                            width: 26
                            height: 26
                            radius: 13
                            color: nextHov.hovered ? "#30FFFFFF" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "\u203A"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(18)
                                color: Theme.fg
                            }
                            MouseArea {
                                id: nextHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.nextMonth()
                            }
                        }
                    }
                }

                /* Weekdays row: S M T W T F S */
                Row {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18

                    Repeater {
                        model: root.weekdayNames
                        delegate: Text {
                            required property string modelData
                            width: 260 / 7
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: Font.Bold
                            color: Theme.fgDim
                        }
                    }
                }

                /* Day Grid (42 cells: 7x6) */
                Grid {
                    id: calGrid
                    columns: 7
                    Layout.fillWidth: true
                    Layout.preferredHeight: 168
                    rowSpacing: 2
                    columnSpacing: 0

                    Repeater {
                        model: daysModel
                        delegate: Rectangle {
                            required property var modelData
                            width: Math.floor(260 / 7)
                            height: 26
                            radius: 7
                            color: modelData.isToday ? Theme.accent
                                 : (cellHov.hovered && modelData.isCurrent ? "#22FFFFFF" : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: String(modelData.day)
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: modelData.isToday ? Font.Bold : Font.Normal
                                color: modelData.isToday ? Theme.bg
                                     : (modelData.isCurrent ? Theme.fg : Theme.fgDim)
                                opacity: modelData.isCurrent ? 1.0 : 0.35
                            }

                            MouseArea {
                                id: cellHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.resetToToday()
                            }
                        }
                    }
                }
            }

            /* Divider */
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                Layout.topMargin: 8
                Layout.bottomMargin: 8
                color: "#25FFFFFF"
                opacity: root.isExpanded ? 0.35 : 0
                scale: root.isExpanded ? 1.0 : 0.6
                transformOrigin: Item.Center
                Behavior on opacity { NumberAnimation { duration: root.isExpanded ? 300 : 120; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: root.isExpanded ? 300 : 120; easing.type: Easing.OutExpo } }
            }

            /* ── Right Column: Rich Media Player ────────────────────── */
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 263
                Layout.maximumWidth: 263
                Layout.fillHeight: true
                spacing: 8

                /* Large Album Artwork */
                Item {
                    id: artItem
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 116
                    Layout.preferredHeight: 116
                    opacity: root.isExpanded ? 1 : 0
                    scale: root.isExpanded ? 1.0 : 0.86
                    transform: Translate {
                        y: root.isExpanded ? 0 : 10
                        Behavior on y { NumberAnimation { duration: root.isExpanded ? 320 : 120; easing.type: Easing.OutExpo } }
                    }
                    Behavior on scale { NumberAnimation { duration: root.isExpanded ? 320 : 120; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: root.isExpanded ? 260 : 120; easing.type: Easing.OutCubic } }

                    Item {
                        id: artMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            radius: 14
                            color: "#FFFFFFFF"
                        }
                    }

                    Item {
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: artMask
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.bgAlt
                        }

                        Image {
                            anchors.fill: parent
                            source: root.artUrl
                            sourceSize: Qt.size(232, 232)
                            fillMode: Image.PreserveAspectCrop
                            visible: root.artUrl !== ""
                            asynchronous: true
                        }

                        /* Fallback Waveform Visualizer if no album art */
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: root.artUrl === ""

                            Repeater {
                                model: 9
                                delegate: Rectangle {
                                    required property int index
                                    width: 4
                                    height: root.isPlaying
                                        ? 12 + 40 * root.visualizerLevel(index)
                                        : 12 + 20 * root.pausedVisualizerLevel(index)
                                    radius: 2
                                    color: Theme.accent
                                }
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: "transparent"
                        border.color: Theme.outline
                        border.width: 1
                    }
                }

                /* Player Source Chip (e.g. ● Mozilla zen) */
                Rectangle {
                    id: srcChip
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 20
                    Layout.preferredWidth: srcRow.implicitWidth + 16
                    radius: 10
                    color: "#18FFFFFF"
                    opacity: root.isExpanded ? 1 : 0
                    transform: Translate {
                        y: root.isExpanded ? 0 : 14
                        Behavior on y { NumberAnimation { duration: root.isExpanded ? 340 : 120; easing.type: Easing.OutExpo } }
                    }
                    Behavior on opacity { NumberAnimation { duration: root.isExpanded ? 280 : 120; easing.type: Easing.OutCubic } }

                    Row {
                        id: srcRow
                        anchors.centerIn: parent
                        spacing: 5

                        Rectangle {
                            width: 5
                            height: 5
                            radius: 2.5
                            color: Theme.accent
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: root.playerIdentity
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: Font.Medium
                            color: Theme.fgDim
                        }
                    }
                }

                /* Song Title & Artist */
                ColumnLayout {
                    id: metaCol
                    Layout.fillWidth: true
                    Layout.maximumWidth: 263
                    spacing: 2
                    opacity: root.isExpanded ? 1 : 0
                    transform: Translate {
                        y: root.isExpanded ? 0 : 18
                        Behavior on y { NumberAnimation { duration: root.isExpanded ? 360 : 120; easing.type: Easing.OutExpo } }
                    }
                    Behavior on opacity { NumberAnimation { duration: root.isExpanded ? 300 : 120; easing.type: Easing.OutCubic } }

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 263
                        horizontalAlignment: Text.AlignHCenter
                        text: root.hasTrack ? root.trackTitle : "Nothing Playing"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(14)
                        font.weight: Font.Bold
                        color: Theme.fg
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 263
                        horizontalAlignment: Text.AlignHCenter
                        text: root.hasTrack ? (root.trackArtist + (root.trackAlbum !== "" ? " · " + root.trackAlbum : "")) : "Idle"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(11)
                        color: Theme.fgDim
                        elide: Text.ElideRight
                        wrapMode: Text.NoWrap
                    }
                }

                /* Seekbar with Time Readouts */
                RowLayout {
                    id: seekRow
                    Layout.fillWidth: true
                    spacing: 6
                    opacity: root.isExpanded ? 1 : 0
                    transform: Translate {
                        y: root.isExpanded ? 0 : 22
                        Behavior on y { NumberAnimation { duration: root.isExpanded ? 380 : 120; easing.type: Easing.OutExpo } }
                    }
                    Behavior on opacity { NumberAnimation { duration: root.isExpanded ? 320 : 120; easing.type: Easing.OutCubic } }

                    Text {
                        text: root.formatTime(root.currentPosition)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(10)
                        color: Theme.fgDim
                    }

                    VolSlider {
                        Layout.fillWidth: true
                        active: root.isExpanded
                        interactive: root.totalLength > 0
                        value: root.progress
                        fill: Theme.accent
                        track: "#25FFFFFF"
                        knob: "#FFFFFF"
                        onChanged: (v) => root.seekTo(v)
                    }

                    Text {
                        text: root.formatTime(root.totalLength)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(10)
                        color: Theme.fgDim
                    }
                }

                /* Transport Controls */
                RowLayout {
                    id: transportRow
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12
                    opacity: root.isExpanded ? 1 : 0
                    scale: root.isExpanded ? 1.0 : 0.90
                    transform: Translate {
                        y: root.isExpanded ? 0 : 24
                        Behavior on y { NumberAnimation { duration: root.isExpanded ? 400 : 120; easing.type: Easing.OutExpo } }
                    }
                    Behavior on scale { NumberAnimation { duration: root.isExpanded ? 400 : 120; easing.type: Easing.OutExpo } }
                    Behavior on opacity { NumberAnimation { duration: root.isExpanded ? 350 : 120; easing.type: Easing.OutCubic } }

                    IconButton {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        glyph: "shuffle"
                        tip: "Shuffle"
                        size: 14
                        color: Theme.fgDim
                        pointer: true
                        onClicked: (mouse) => root.toggleShuffle()
                    }

                    IconButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        glyph: "skip_previous"
                        tip: "Previous"
                        size: 18
                        color: Theme.fg
                        pointer: true
                        onClicked: (mouse) => root.playPrev()
                    }

                    Rectangle {
                        Layout.preferredWidth: 38
                        Layout.preferredHeight: 38
                        width: 38
                        height: 38
                        radius: 19
                        color: Theme.accent

                        Text {
                            anchors.centerIn: parent
                            text: root.isPlaying ? "pause" : "play_arrow"
                            font.family: Theme.fontIcon
                            font.pixelSize: 18
                            color: Theme.bg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: (mouse) => root.togglePlayPause()
                        }
                    }

                    IconButton {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32
                        glyph: "skip_next"
                        tip: "Next"
                        size: 18
                        color: Theme.fg
                        pointer: true
                        onClicked: (mouse) => root.playNext()
                    }

                    IconButton {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        glyph: "repeat"
                        tip: "Repeat"
                        size: 14
                        color: Theme.fgDim
                        pointer: true
                        onClicked: (mouse) => root.toggleRepeat()
                    }
                }
            }
        }

        /* HoverHandler for panel hover detection without intercepting child mouse clicks */
        HoverHandler {
            id: flyoutHover
            onHoveredChanged: {
                root.panelHovered = flyoutHover.hovered
                root.panelHoverChanged(flyoutHover.hovered)
                if (flyoutHover.hovered) leaveTimer.stop()
                else leaveTimer.restart()
            }
        }
    }
}