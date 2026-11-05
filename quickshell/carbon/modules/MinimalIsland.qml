import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../Singletons"

/**
 * MinimalIsland: Ultra-lightweight Dynamic Island single-bar capsule.
 * Designed to look and feel exactly like the authentic Tide Island:
 *
 * Modes:
 *   1. Resting (Time): Workspace badge, crisp digital clock, and minimal battery %.
 *   2. Music Playing: Album art thumbnail, track title & artist typography, and live mini audio equalizer.
 *   3. HUD Active: Smooth morph into Dynamic Island volume/brightness/battery pill.
 *
 * Switching between Music and Time:
 *   - Left Arrow Key (or swipe/drag left): Switches to normal Time view (even while music is playing!).
 *   - Right Arrow Key (or swipe/drag right): Switches to Music view.
 *   - Subtle indicator in resting mode when media is playing.
 *
 * Click Interactions:
 *   - Left-click (in Music view): Toggles sleek expanded Media Player card.
 *   - Left-click (in Time view): Toggles sleek expanded Calendar & Date card.
 *   - Right-click: Toggles Control Center / Quick Settings.
 *   - Middle-click: Toggles modern Spotlight Launcher.
 *   - Scroll Wheel: Fine volume control (vertical) / view toggle (horizontal).
 */
Item {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    property bool attachedBottom: false
    property string islandStyle: "pill" // "pill" or "notch"
    property int pillHeight: 36
    property int notchHeight: 32
    property real islandOpacity: 0.90
    property int notifCount: 0
    property int currentPage: 0

    /* ── Synced Lyrics Multi-Line & State (Tide Island Style) ── */
    readonly property bool hasSyncedLyrics: LyricsService.hasLyrics && LyricsService.hasTrack
    readonly property string liveLyricLine: LyricsService.currentLine ? LyricsService.currentLine.trim() : ""
    readonly property string displayLyricLine: {
        if (!hasSyncedLyrics) return ""
        return liveLyricLine.length > 0 ? liveLyricLine : "♪ ♫ ♪"
    }
    property string activeLyricText: displayLyricLine
    property string previousLyricText: ""
    property real lyricChangeProgress: 1.0

    implicitHeight: islandStyle === "notch" ? notchHeight : pillHeight
    height: implicitHeight
    implicitWidth: capsule.width
    width: capsule.width

    /* ── Active Sub-View State (Music vs Time) ── */
    property string activeView: "music" // "music" or "time"

    focus: true
    Keys.enabled: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Left) {
            root.activeView = "time"
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            if (root.isPlaying || root.hasTrack) {
                root.activeView = "music"
            }
            event.accepted = true
        }
    }
    Keys.onLeftPressed: event => {
        root.activeView = "time"
        event.accepted = true
    }
    Keys.onRightPressed: event => {
        if (root.isPlaying || root.hasTrack) {
            root.activeView = "music"
        }
        event.accepted = true
    }

    onDisplayLyricLineChanged: {
        if (displayLyricLine === activeLyricText) return
        previousLyricText = activeLyricText
        activeLyricText = displayLyricLine
        lyricChangeProgress = 0.0
        lyricChangeAnimation.restart()
    }

    NumberAnimation {
        id: lyricChangeAnimation
        target: root
        property: "lyricChangeProgress"
        from: 0.0
        to: 1.0
        duration: 320
        easing.bezierCurve: Theme.animCurves.expressiveDefaultSpatial
        onFinished: root.previousLyricText = ""
    }

    /* ── Signals for shell.qml integration ── */
    signal openLauncher()
    signal toggleControls()
    signal openNotif()
    signal closeNotif()
    signal toggleNotif()
    signal openMixer()
    signal closeMixer()
    signal toggleMixer()
    signal openBrightness()
    signal closeBrightness()
    signal toggleBrightness()
    signal openBattery()
    signal closeBattery()
    signal toggleBattery()
    signal openWifi()
    signal closeWifi()
    signal toggleWifi()
    signal openBt()
    signal closeBt()
    signal toggleBt()
    signal openCalendar()
    signal closeCalendar()
    signal toggleCalendar()
    signal openSmallMusic()
    signal closeSmallMusic()
    signal toggleSmallMusic()
    signal openSpotlight()
    signal toggleSpotlight()
    signal convertToPill()
    signal convertToNotch()
    signal switchIslandStyle(string style)

    /* ── HUD State ── */
    readonly property bool hudActive: HudService.active

    /* ── MPRIS Music State ── */
    readonly property var activePlayer: LyricsService.activePlayer
    readonly property bool isPlaying: LyricsService.isPlaying && (LyricsService.hasTrack || (activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing))
    readonly property string trackTitle: LyricsService.trackTitle || (activePlayer ? activePlayer.trackTitle : "")
    readonly property string trackArtist: LyricsService.trackArtist || (activePlayer ? (activePlayer.trackArtists ? activePlayer.trackArtists.join(", ") : "") : "")
    readonly property string artUrl: LyricsService.artUrl || (activePlayer ? activePlayer.artUrl : "")
    readonly property bool hasTrack: trackTitle.length > 0

    onIsPlayingChanged: {
        if (root.isPlaying) {
            root.activeView = "music"
        }
    }

    /* ── Mini Cava Visualizer State (5 Bars, Low CPU) ── */
    property var cavaBars: [4, 8, 12, 8, 4]
    property real cavaAnimTick: 0

    Process {
        id: cavaProc
        command: ["cava", "-p", root.home + "/.config/hypr/cava-island.conf"]
        running: root.isPlaying && root.activeView === "music"
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const parts = line.trim().split(";")
                if (parts.length >= 5) {
                    const b0 = Math.max(3, Math.min(13, Math.round((parseInt(parts[0]) || 0) * 0.13)))
                    const b1 = Math.max(3, Math.min(13, Math.round((parseInt(parts[1]) || 0) * 0.13)))
                    const b2 = Math.max(3, Math.min(13, Math.round((parseInt(parts[2]) || 0) * 0.13)))
                    const b3 = Math.max(3, Math.min(13, Math.round((parseInt(parts[3]) || 0) * 0.13)))
                    const b4 = Math.max(3, Math.min(13, Math.round((parseInt(parts[4]) || 0) * 0.13)))
                    root.cavaBars = [b0, b1, b2, b3, b4]
                }
            }
        }
    }

    Timer {
        interval: 100
        repeat: true
        running: root.isPlaying && root.activeView === "music" && (!cavaProc.running)
        onTriggered: {
            root.cavaAnimTick += 0.4
            const b0 = 3 + Math.round(Math.abs(Math.sin(root.cavaAnimTick)) * 6)
            const b1 = 3 + Math.round(Math.abs(Math.cos(root.cavaAnimTick * 1.3)) * 8)
            const b2 = 3 + Math.round(Math.abs(Math.sin(root.cavaAnimTick * 0.8 + 1)) * 10)
            const b3 = 3 + Math.round(Math.abs(Math.cos(root.cavaAnimTick * 1.1 + 0.5)) * 8)
            const b4 = 3 + Math.round(Math.abs(Math.sin(root.cavaAnimTick * 1.4 + 0.2)) * 6)
            root.cavaBars = [b0, b1, b2, b3, b4]
        }
    }

    /* ── Live Clock State ── */
    property var currentTime: new Date()
    property int currentHourRaw: currentTime.getHours()
    property int currentHour12: {
        let h = currentHourRaw % 12
        return h === 0 ? 12 : h
    }
    property string hourStr: (currentHour12 < 10 ? "0" : "") + currentHour12
    property string minStr: {
        let m = currentTime.getMinutes()
        return (m < 10 ? "0" : "") + m
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    /* ── Workspaces (Hyprland Event Driven) ── */
    property int activeWs: (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) ? Hyprland.focusedMonitor.activeWorkspace.id : 1
    Connections {
        target: Hyprland.focusedMonitor
        function onActiveWorkspaceChanged() {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
                root.activeWs = Hyprland.focusedMonitor.activeWorkspace.id
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "workspace" || event.name === "workspacev2") {
                const id = parseInt(event.data, 10)
                if (!isNaN(id) && id > 0) root.activeWs = id
            }
        }
    }

    /* ── Battery State (UPower Direct) ── */
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isPresent : false
    readonly property real batteryPct: battery ? battery.percentage : 1.0
    readonly property bool isCharging: battery ? (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged) : false
    readonly property string batteryGlyph: {
        if (isCharging) return "battery_charging_full"
        const p = batteryPct * 100
        if (p > 85) return "battery_full"
        if (p > 60) return "battery_5_bar"
        if (p > 35) return "battery_3_bar"
        if (p > 10) return "battery_1_bar"
        return "battery_alert"
    }

    /* ── Notch Geometry (Tide Island Style: Flat Top Flush to Screen, Rounded Bottom) ── */
    property real bottomRadius: 16

    readonly property string notchFillPath: {
        const r = root.bottomRadius
        const w = capsule.width
        const h = capsule.height

        if (root.attachedBottom) {
            let p = `M 0 ${h} `
            p += `L 0 ${r} `
            p += `A ${r} ${r} 0 0 1 ${r} 0 `
            p += `L ${w - r} 0 `
            p += `A ${r} ${r} 0 0 1 ${w} ${r} `
            p += `L ${w} ${h} `
            p += `Z`
            return p
        }

        let p = "M 0 0 "
        p += `L 0 ${h - r} `
        p += `A ${r} ${r} 0 0 0 ${r} ${h} `
        p += `L ${w - r} ${h} `
        p += `A ${r} ${r} 0 0 0 ${w} ${h - r} `
        p += `L ${w} 0 `
        p += `Z`
        return p
    }

    readonly property string notchStrokePath: {
        const r = root.bottomRadius
        const w = capsule.width
        const h = capsule.height

        if (root.attachedBottom) {
            let p = `M 0 ${h} `
            p += `L 0 ${r} `
            p += `A ${r} ${r} 0 0 1 ${r} 0 `
            p += `L ${w - r} 0 `
            p += `A ${r} ${r} 0 0 1 ${w} ${r} `
            p += `L ${w} ${h}`
            return p
        }

        let p = `M 0 0 `
        p += `L 0 ${h - r} `
        p += `A ${r} ${r} 0 0 0 ${r} ${h} `
        p += `L ${w - r} ${h} `
        p += `A ${r} ${r} 0 0 0 ${w} ${h - r} `
        p += `L ${w} 0`
        return p
    }

    /* ── Main Dynamic Island Capsule ── */
    Item {
        id: capsule
        height: root.implicitHeight
        anchors.centerIn: parent

        readonly property bool showMusic: (!root.hudActive && (root.isPlaying || root.hasTrack) && root.activeView === "music")
        readonly property int baseWidth: {
            if (root.hudActive) return 170
            if (capsule.showMusic) {
                if (root.hasSyncedLyrics) {
                    return 264
                }
                return 226
            }
            return (root.isPlaying || root.hasTrack) ? 148 : 124
        }

        width: baseWidth

        Behavior on width {
            NumberAnimation {
                duration: 350
                easing.bezierCurve: Theme.animCurves.expressiveDefaultSpatial
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: 350
                easing.bezierCurve: Theme.animCurves.expressiveDefaultSpatial
            }
        }

        /* ── 1A. Pill Mode Background (Floating Rounded Capsule) ── */
        Rectangle {
            id: pillBg
            anchors.fill: parent
            visible: root.islandStyle !== "notch"
            radius: height / 2
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.islandOpacity)
            border.color: Theme.outline
            border.width: 1
        }

        /* ── 1B. Notch Mode Background (Screen-Attached Curved Notch) ── */
        Shape {
            id: notchShape
            anchors.fill: parent
            visible: root.islandStyle === "notch"
            preferredRendererType: Shape.CurveRenderer
            asynchronous: false
            layer.enabled: true
            layer.smooth: true

            ShapePath {
                strokeWidth: 0
                strokeColor: "transparent"
                fillColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.islandOpacity)
                PathSvg { path: root.notchFillPath }
            }

            ShapePath {
                strokeWidth: 1.2
                strokeColor: Qt.alpha(Theme.outline, 0.45)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                PathSvg { path: root.notchStrokePath }
            }
        }

        /* ── Unified Click, Wheel, and Gesture Interaction ── */
        MouseArea {
            id: mainMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            z: 10

            onEntered: root.forceActiveFocus()

            property real pressX: 0
            onPressed: mouse => {
                pressX = mouse.x
            }
            onReleased: mouse => {
                const dx = mouse.x - pressX
                if (dx > 25) {
                    if (root.isPlaying || root.hasTrack) root.activeView = "music"
                } else if (dx < -25) {
                    root.activeView = "time"
                }
            }

            onClicked: mouse => {
                root.forceActiveFocus()
                if (mouse.button === Qt.RightButton) {
                    root.toggleControls()
                } else if (mouse.button === Qt.MiddleButton) {
                    root.toggleSpotlight()
                } else {
                    if (root.isPlaying || root.hasTrack) {
                        root.activeView = (root.activeView === "music" ? "time" : "music")
                    }
                }
            }

            onWheel: wheel => {
                if (!wheel) return
                // Horizontal wheel or Shift+Wheel: switches between time & music view
                if (wheel.angleDelta.x > 0 || (wheel.modifiers & Qt.ShiftModifier && wheel.angleDelta.y > 0)) {
                    if (root.isPlaying || root.hasTrack) root.activeView = "music"
                } else if (wheel.angleDelta.x < 0 || (wheel.modifiers & Qt.ShiftModifier && wheel.angleDelta.y < 0)) {
                    root.activeView = "time"
                } else if (wheel.angleDelta.y !== 0) {
                    // Vertical wheel: Volume adjustment
                    if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                        if (wheel.angleDelta.y > 0) {
                            Pipewire.defaultAudioSink.audio.volume = Math.min(1.0, (Pipewire.defaultAudioSink.audio.volume || 0) + 0.02)
                        } else {
                            Pipewire.defaultAudioSink.audio.volume = Math.max(0.0, (Pipewire.defaultAudioSink.audio.volume || 0) - 0.02)
                        }
                    }
                }
            }
        }

        /* ── Content Container ── */
        Item {
            id: contentContainer
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            clip: true
            z: 2

            /* ── A. HUD Mode (DynamicIslandPill) ── */
            DynamicIslandPill {
                id: dynamicPill
                anchors.centerIn: parent
                opacity: root.hudActive ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }
            }

            /* ── B. Music Playing Mode ── */
            Item {
                id: musicModeLayout
                anchors.fill: parent
                opacity: capsule.showMusic ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        width: 0
                        height: 0
                        visible: false
                    }
                    Item {
                        width: root.hasSyncedLyrics ? 172 : 130
                        height: 22
                        anchors.verticalCenter: parent.verticalCenter
                        clip: true

                        // View A: Synced Live Lyric
                        Item {
                            anchors.fill: parent
                            visible: root.hasSyncedLyrics

                            Text {
                                id: prevLyricTxt
                                visible: root.previousLyricText !== ""
                                width: parent.width
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: (parent.height - height) / 2 - 12 * root.lyricChangeProgress
                                opacity: (1.0 - root.lyricChangeProgress) * 0.65
                                text: root.previousLyricText
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.DemiBold
                                color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55)
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                id: curLyricTxt
                                visible: root.activeLyricText !== ""
                                width: parent.width
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: (parent.height - height) / 2 + (root.previousLyricText !== "" ? 12 * (1.0 - root.lyricChangeProgress) : 0)
                                opacity: root.previousLyricText !== "" ? root.lyricChangeProgress : 1.0
                                text: root.activeLyricText
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.Bold
                                color: Theme.accent
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        // View B: Track Title & Artist Fallback
                        Column {
                            anchors.fill: parent
                            visible: !root.hasSyncedLyrics
                            spacing: 1

                            Text {
                                width: parent.width
                                text: root.trackTitle || "Playing"
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.DemiBold
                                color: Theme.fg
                                elide: Text.ElideRight
                            }

                            Text {
                                width: parent.width
                                text: root.trackArtist || "Unknown Artist"
                                font.pixelSize: Theme.fontPx(9)
                                color: Theme.fgDim
                                elide: Text.ElideRight
                            }
                        }
                    }

                    /* 3. Live 5-Bar Mini Cava Equalizer */
                    Row {
                        spacing: 2.5
                        height: 14
                        anchors.verticalCenter: parent.verticalCenter

                        Repeater {
                            model: 5
                            Rectangle {
                                width: 2.5
                                height: Math.max(3, root.cavaBars[index] || 3)
                                radius: 1.25
                                color: Theme.accentLit
                                anchors.bottom: parent.bottom

                                Behavior on height {
                                    NumberAnimation { duration: 75 }
                                }
                            }
                        }
                    }
                }
            }

            /* ── C. Clean Minimal Resting Mode (Time & Battery) ── */
            Item {
                id: restingModeLayout
                anchors.fill: parent
                opacity: (!root.hudActive && !capsule.showMusic) ? 1.0 : 0.0
                visible: opacity > 0.01

                Behavior on opacity {
                    NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    /* 1. Clean Digital Clock */
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.hourStr + ":" + root.minStr
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: Font.DemiBold
                        font.letterSpacing: -0.2
                        color: Theme.fg
                    }

                    /* 2. Music Active Indicator (Clickable to switch back to music) */
                    Rectangle {
                        visible: (root.isPlaying || root.hasTrack)
                        width: 8
                        height: 8
                        radius: 4
                        color: Theme.accentLit
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.isPlaying ? 0.95 : 0.5

                        SequentialAnimation on opacity {
                            running: root.isPlaying && (!capsule.showMusic)
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                            NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.activeView = "music"
                            }
                        }
                    }
                }
            }
        }
    }
}
