import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../../../Singletons"
import "../../../components"

/**
 * MusicPillIsland: Dynamic music pill for Pill Mode.
 * - Sits on the screen surface below windows (WlrLayer.Bottom) when resting,
 *   elevating to WlrLayer.Top when hovered/expanded.
 * - Stays active as long as media exists (does not disappear when paused).
 * - Hover mode: expands automatically on hover, collapses when pointer leaves.
 * - Synced lyrics matching Minimal Island (slide-up transition with accent styling).
 * - Compact Spotlight-style popup with full transport controls.
 */
PanelWindow {
    id: musicIslandWindow

    property bool expanded: false
    property bool barAtBottom: false

    readonly property color colBg: (Theme && Theme.bg) ? Theme.bg : Qt.color("#121118")
    readonly property color colFg: (Theme && Theme.fg) ? Theme.fg : Qt.color("#e6e1e5")
    readonly property color colAccent: (Theme && Theme.accent) ? Theme.accent : Qt.color("#ffb77a")
    readonly property color colAccentLit: (Theme && Theme.accentLit) ? Theme.accentLit : Qt.color("#ffdcb8")
    readonly property color colOutlineVariant: (Theme && Theme.outlineVariant) ? Theme.outlineVariant : Qt.color("#49454f")

    Component.onCompleted: {
        LyricsService.enabled = true
    }

    // Watch bar position config to ensure real-time adaptation
    FileView {
        id: barPosWatcher
        path: (Quickshell.env("HOME") || "") + "/.config/carbon/carbon-bar-position.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: updatePos()
        onFileChanged: updatePos()
        function updatePos() {
            try {
                var d = JSON.parse(barPosWatcher.text())
                musicIslandWindow.barAtBottom = (d.mainBarEdge === "bottom" || d.edge === "bottom")
            } catch (e) {}
        }
    }

    readonly property bool hasTrack: LyricsService.hasTrack
    readonly property bool isPlaying: LyricsService.isPlaying || (LyricsService.activePlayer && LyricsService.activePlayer.playbackState === MprisPlaybackState.Playing)

    // Synced Lyrics matching Minimal Island
    readonly property bool hasSyncedLyrics: LyricsService.hasLyrics && LyricsService.hasTrack
    readonly property string liveLyricLine: LyricsService.currentLine ? LyricsService.currentLine.trim() : ""
    readonly property string displayLyricLine: {
        if (!hasSyncedLyrics) return ""
        return liveLyricLine.length > 0 ? liveLyricLine : "♪ ♫ ♪"
    }
    property string activeLyricText: displayLyricLine
    property string previousLyricText: ""
    property real lyricChangeProgress: 1.0

    onDisplayLyricLineChanged: {
        if (displayLyricLine === activeLyricText) return
        previousLyricText = activeLyricText
        activeLyricText = displayLyricLine
        lyricChangeProgress = 0.0
        lyricChangeAnimation.restart()
    }

    NumberAnimation {
        id: lyricChangeAnimation
        target: musicIslandWindow
        property: "lyricChangeProgress"
        from: 0.0
        to: 1.0
        duration: 260
        easing.type: Easing.OutCubic
        onFinished: musicIslandWindow.previousLyricText = ""
    }

    // Never disappears while media exists; stays visible until media player itself closes
    readonly property bool shouldShow: hasTrack

    screen: Quickshell.screens[0]
    color: "transparent"
    WlrLayershell.namespace: "carbon-pill-music"
    // On the screen surface below windows when resting, elevating above when expanded
    WlrLayershell.layer: expanded ? WlrLayer.Top : WlrLayer.Bottom
    WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: musicIslandWindow.barAtBottom
        bottom: !musicIslandWindow.barAtBottom
    }
    margins {
        top: musicIslandWindow.barAtBottom ? 12 : 0
        bottom: !musicIslandWindow.barAtBottom ? 12 : 0
    }

    // Stable fixed surface bounds
    implicitWidth: 350
    implicitHeight: 180
    visible: shouldShow || container.animOpacity > 0.01

    // Exact input clipping mask so only the capsule intercepts mouse events
    mask: Region { item: mainCapsule }

    Item {
        id: container
        anchors.fill: parent

        // Slide in/out transition
        property real yOffset: {
            if (shouldShow) return 0
            return musicIslandWindow.barAtBottom ? -36 : 36
        }
        property real animOpacity: shouldShow ? 1.0 : 0.0

        Behavior on yOffset {
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }
        Behavior on animOpacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        transform: Translate { y: container.yOffset }
        opacity: container.animOpacity

        // Title measurement for pill auto-sizing
        TextMetrics {
            id: titleMetrics
            font.family: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Inter"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            text: musicIslandWindow.hasSyncedLyrics ? (musicIslandWindow.activeLyricText || "♪") : (LyricsService.trackTitle || "Music")
        }

        readonly property real restingWidth: Math.max(210, Math.min(320, titleMetrics.advanceWidth + 90))

        Rectangle {
            id: mainCapsule

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: !musicIslandWindow.barAtBottom ? parent.bottom : undefined
            anchors.top: musicIslandWindow.barAtBottom ? parent.top : undefined

            width: musicIslandWindow.expanded ? 330 : container.restingWidth
            height: musicIslandWindow.expanded ? 160 : 34
            radius: musicIslandWindow.expanded ? 16 : 17

            focus: musicIslandWindow.expanded
            Keys.onEscapePressed: musicIslandWindow.expanded = false

            Behavior on width {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
            Behavior on height {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
            Behavior on radius {
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }

            color: Qt.rgba(colBg.r, colBg.g, colBg.b, 0.92)
            border.color: capsuleHover.hovered ? colAccent : Qt.rgba(colOutlineVariant.r, colOutlineVariant.g, colOutlineVariant.b, 0.35)
            border.width: 1
            clip: true

            Behavior on border.color {
                ColorAnimation { duration: 180 }
            }

            // ===================================================================
            // HOVER MODE HANDLER & DEBOUNCE TIMER
            // ===================================================================
            HoverHandler {
                id: capsuleHover
                onHoveredChanged: {
                    if (hovered) {
                        collapseTimer.stop()
                        musicIslandWindow.expanded = true
                    } else {
                        if (!expandedContent.isDraggingSeekBar) {
                            collapseTimer.restart()
                        }
                    }
                }
            }

            Timer {
                id: collapseTimer
                interval: 340
                onTriggered: {
                    if (!capsuleHover.hovered && !expandedContent.isDraggingSeekBar) {
                        musicIslandWindow.expanded = false
                    }
                }
            }

            // ===================================================================
            // RESTING PILL VIEW
            // ===================================================================
            Item {
                id: restingContent
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: musicIslandWindow.expanded ? 0.0 : 1.0

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 10
                    spacing: 8

                    // Album Art Thumbnail (22x22)
                    Rectangle {
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 6
                        color: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.08)
                        clip: true

                        Image {
                            id: restingArt
                            anchors.fill: parent
                            source: LyricsService.artUrl
                            sourceSize: Qt.size(44, 44)
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready && source != ""
                            asynchronous: true
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !restingArt.visible
                            font.family: Theme.fontIcon
                            font.pixelSize: 13
                            color: colAccent
                            text: "music_note"
                        }
                    }

                    // Synced Lyrics (Matching Minimal Island) or Track Info Fallback
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        clip: true

                        // View A: Synced Live Lyrics
                        Item {
                            anchors.fill: parent
                            visible: musicIslandWindow.hasSyncedLyrics

                            Text {
                                id: prevLyricTxt
                                visible: musicIslandWindow.previousLyricText !== ""
                                width: parent.width
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: (parent.height - height) / 2 - 12 * musicIslandWindow.lyricChangeProgress
                                opacity: (1.0 - musicIslandWindow.lyricChangeProgress) * 0.65
                                text: musicIslandWindow.previousLyricText
                                font.family: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Inter"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.55)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                id: curLyricTxt
                                visible: musicIslandWindow.activeLyricText !== ""
                                width: parent.width
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: (parent.height - height) / 2 + (musicIslandWindow.previousLyricText !== "" ? 12 * (1.0 - musicIslandWindow.lyricChangeProgress) : 0)
                                opacity: musicIslandWindow.previousLyricText !== "" ? musicIslandWindow.lyricChangeProgress : 1.0
                                text: musicIslandWindow.activeLyricText
                                font.family: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Inter"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                color: colAccent
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        // View B: Track Title & Artist Fallback
                        ColumnLayout {
                            anchors.fill: parent
                            visible: !musicIslandWindow.hasSyncedLyrics
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: LyricsService.trackTitle || "Playing"
                                font.family: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Inter"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                color: colFg
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: LyricsService.trackArtist || "Unknown Artist"
                                font.family: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Inter"
                                font.pixelSize: 9
                                color: colAccent
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // 4-Bar Animated Mini Equalizer
                    Row {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2.5

                        property real tick: 0
                        Timer {
                            interval: 90
                            running: musicIslandWindow.isPlaying && !musicIslandWindow.expanded
                            repeat: true
                            onTriggered: parent.tick += 0.35
                        }

                        Repeater {
                            model: 4
                            Rectangle {
                                width: 2.5
                                radius: 1.25
                                color: colAccentLit
                                anchors.bottom: parent.bottom
                                height: {
                                    if (!musicIslandWindow.isPlaying) return 3
                                    const t = parent.parent.tick
                                    const offsets = [0, 0.6, 1.2, 0.4]
                                    const mults = [7, 10, 8, 6]
                                    return 3 + Math.round(Math.abs(Math.sin(t * 1.5 + offsets[index])) * mults[index])
                                }
                            }
                        }
                    }
                }
            }

            // ===================================================================
            // EXPANDED SPOTLIGHT-STYLE POPUP VIEW (Compact 330 x 160)
            // ===================================================================
            Item {
                id: expandedContent
                anchors.fill: parent
                visible: opacity > 0.01
                opacity: musicIslandWindow.expanded ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                // Drag state on seek bar to keep popup open while user drags
                property bool isDraggingSeekBar: wavyBar.isDragging

                // Reactive Loop & Shuffle State
                property bool shuffleActive: false
                property string loopState: "None"

                Timer {
                    id: stateSyncTimer
                    interval: 2000
                    running: musicIslandWindow.expanded
                    repeat: true
                    onTriggered: syncStates()
                }

                function syncStates() {
                    if (LyricsService.activePlayer) {
                        if (LyricsService.activePlayer.shuffle !== undefined)
                            shuffleActive = LyricsService.activePlayer.shuffle
                        if (LyricsService.activePlayer.loopStatus !== undefined) {
                            var ls = LyricsService.activePlayer.loopStatus
                            loopState = ls === MprisLoopStatus.Track ? "Track" : (ls === MprisLoopStatus.Playlist ? "Playlist" : "None")
                        }
                    }
                }

                function toggleShuffle() {
                    shuffleActive = !shuffleActive
                    if (LyricsService.activePlayer && LyricsService.activePlayer.shuffle !== undefined) {
                        try { LyricsService.activePlayer.shuffle = shuffleActive } catch(e) {}
                    }
                    Quickshell.execDetached(["playerctl", "shuffle", "Toggle"])
                }

                function toggleLoop() {
                    var nextMode = "Playlist"
                    if (loopState === "Playlist") nextMode = "Track"
                    else if (loopState === "Track") nextMode = "None"
                    else nextMode = "Playlist"
                    loopState = nextMode

                    if (LyricsService.activePlayer && LyricsService.activePlayer.loopStatus !== undefined) {
                        try {
                            LyricsService.activePlayer.loopStatus = nextMode === "Track" ? MprisLoopStatus.Track : (nextMode === "Playlist" ? MprisLoopStatus.Playlist : MprisLoopStatus.None)
                        } catch(e) {}
                    }
                    Quickshell.execDetached(["playerctl", "loop", nextMode])
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    // 1. Header Row: Output Device Badge + Close Button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: "music_note"
                            font.family: Theme.fontIcon
                            font.pixelSize: 12
                            color: colAccentLit
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.description && Pipewire.defaultAudioSink.description.length > 0)
                                    return Pipewire.defaultAudioSink.description
                                if (LyricsService.activePlayer && LyricsService.activePlayer.identity && LyricsService.activePlayer.identity.length > 0)
                                    return LyricsService.activePlayer.identity
                                return "Audio Output"
                            }
                            font.family: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Inter"
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                            color: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.70)
                            elide: Text.ElideRight
                        }

                        // Close Button
                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: closeArea.containsMouse ? Qt.rgba(colFg.r, colFg.g, colFg.b, 0.12) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "close"
                                font.family: Theme.fontIcon
                                font.pixelSize: 13
                                color: closeArea.containsMouse ? colAccentLit : Qt.rgba(colFg.r, colFg.g, colFg.b, 0.55)
                            }

                            MouseArea {
                                id: closeArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: musicIslandWindow.expanded = false
                            }
                        }
                    }

                    // 2. Track Info & Album Art Row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                Layout.fillWidth: true
                                text: LyricsService.hasTrack ? LyricsService.trackTitle : "No Media Playing"
                                font.family: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Inter"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: colFg
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: LyricsService.hasTrack ? (LyricsService.trackArtist || "Unknown Artist") : "Waiting for playback..."
                                font.family: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Inter"
                                font.pixelSize: 10
                                font.weight: Font.Medium
                                color: colAccent
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: LyricsService.trackAlbum.length > 0
                                text: LyricsService.trackAlbum
                                font.family: (Theme && (Theme.fontFamily || Theme.font)) ? (Theme.fontFamily || Theme.font) : "Inter"
                                font.pixelSize: 9
                                color: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.45)
                                elide: Text.ElideRight
                            }
                        }

                        // High-res Album Art Thumbnail (36x36)
                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 8
                            color: Qt.rgba(colFg.r, colFg.g, colFg.b, 0.08)
                            border.color: Qt.rgba(colAccentLit.r, colAccentLit.g, colAccentLit.b, 0.35)
                            border.width: 1
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: LyricsService.artUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready && source != ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "music_note"
                                font.family: Theme.fontIcon
                                font.pixelSize: 16
                                color: LyricsService.isPlaying ? colAccentLit : Qt.rgba(colFg.r, colFg.g, colFg.b, 0.45)
                                visible: !LyricsService.artUrl || LyricsService.artUrl === ""
                            }
                        }
                    }

                    // 3. Compact WavySeekBar
                    WavySeekBar {
                        id: wavyBar
                        Layout.fillWidth: true
                        waveHeight: 10
                        barHeight: 4
                        timeLabelSize: 8
                        accentColor: colAccent
                        accentLitColor: colAccentLit
                    }

                    // 4. Transport Controls Row
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        // Shuffle Button
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: expandedContent.shuffleActive ? Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.18) : (shufArea.containsMouse ? Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: "shuffle"
                                font.family: Theme.fontIcon
                                font.pixelSize: 14
                                color: expandedContent.shuffleActive ? colAccentLit : (shufArea.containsMouse ? colFg : Qt.rgba(colFg.r, colFg.g, colFg.b, 0.60))
                            }

                            MouseArea {
                                id: shufArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: expandedContent.toggleShuffle()
                            }
                        }

                        // Previous Track Button
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: prevArea.containsMouse ? Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                font.family: Theme.fontIcon
                                font.pixelSize: 17
                                color: prevArea.containsMouse ? colAccentLit : colFg
                            }

                            MouseArea {
                                id: prevArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (LyricsService.activePlayer && LyricsService.activePlayer.canGoPrevious) {
                                        LyricsService.activePlayer.previous()
                                    } else {
                                        LyricsService.skipPrevious()
                                    }
                                }
                            }
                        }

                        // Play / Pause Circular Button
                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: playArea.containsMouse ? colAccentLit : colAccent
                            border.color: colAccentLit
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: LyricsService.isPlaying ? "pause" : "play_arrow"
                                font.family: Theme.fontIcon
                                font.pixelSize: 17
                                color: Theme.isDark ? "#121118" : "#ffffff"
                            }

                            MouseArea {
                                id: playArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (LyricsService.activePlayer && LyricsService.activePlayer.canControl) {
                                        LyricsService.activePlayer.togglePlaying()
                                    } else {
                                        LyricsService.togglePlaying()
                                    }
                                }
                            }
                        }

                        // Next Track Button
                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 14
                            color: nextArea.containsMouse ? Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10) : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "skip_next"
                                font.family: Theme.fontIcon
                                font.pixelSize: 17
                                color: nextArea.containsMouse ? colAccentLit : colFg
                            }

                            MouseArea {
                                id: nextArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (LyricsService.activePlayer && LyricsService.activePlayer.canGoNext) {
                                        LyricsService.activePlayer.next()
                                    } else {
                                        LyricsService.skipNext()
                                    }
                                }
                            }
                        }

                        // Loop / Repeat Button
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: expandedContent.loopState !== "None" ? Qt.rgba(colAccent.r, colAccent.g, colAccent.b, 0.18) : (loopArea.containsMouse ? Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10) : "transparent")

                            Text {
                                anchors.centerIn: parent
                                text: expandedContent.loopState === "Track" ? "repeat_one" : "repeat"
                                font.family: Theme.fontIcon
                                font.pixelSize: 14
                                color: expandedContent.loopState !== "None" ? colAccentLit : (loopArea.containsMouse ? colFg : Qt.rgba(colFg.r, colFg.g, colFg.b, 0.60))
                            }

                            MouseArea {
                                id: loopArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: expandedContent.toggleLoop()
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }
}
