import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../Singletons"
import "../components"

/**
 * Carbon ControlHub
 * Modern, tactile multi-mode dropdown panel featuring:
 *   1. Control Center: Volume & Brightness sliders, Quick toggle tiles (Wi-Fi, Bluetooth, DND, Theme).
 *   2. Pomodoro: Synchronized with ~/.config/hypr/carbon-pomodoro.json and carbon-pomodoro.py.
 *   3. Weather: Live weather conditions and inline OpenWeatherMap API Key / Location settings.
 */
Item {
    id: root

    property bool open: false
    property bool hovered: false
    property int mode: 0            // 0: Controls, 1: Pomodoro, 2: Weather
    property alias weatherSubTab: paneWeather.weatherSubTab
    property string corner: "top_right"
    property real shellOpacity: Theme.shellOpacity

    // Compatibility stubs for shell.qml
    property bool audioPopupOpen: false
    property bool btPopupOpen: false
    property bool wifiPopupOpen: false
    property var batteryLayout: null
    property bool showBatteryPercent: true
    property var server: null

    implicitWidth: 350
    implicitHeight: 450
    width: implicitWidth
    height: implicitHeight

    readonly property bool animatingOut: !root.open && card.opacity > 0.001

    /* ── Card Container with Smooth Transition ── */
    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: Theme.cardBg || Theme.bgElevated || "#131316"
        opacity: root.open ? root.shellOpacity : 0.0
        scale: root.open ? 1.0 : 0.96
        border.width: 1
        border.color: Theme.outline || Qt.rgba(1, 1, 1, 0.12)
        clip: true

        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: { root.hovered = true }
            onExited: { root.hovered = false }
            onClicked: { /* absorb outside clicks */ }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            /* ── Header Segmented Tab Switcher ── */
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 18
                color: Qt.alpha(Theme.fg, 0.05)
                border.width: 1
                border.color: Qt.alpha(Theme.fg, 0.08)

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 4

                    // Tab 0: Controls
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 15
                        color: root.mode === 0 ? Theme.accent : (t0Hover.containsMouse ? Qt.alpha(Theme.fg, 0.08) : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰕮"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: root.mode === 0 ? Theme.accentContrast : Theme.fgDim
                            }
                            Text {
                                text: "Controls"
                                font.family: "Plus Jakarta Sans"
                                font.pixelSize: 11
                                font.weight: root.mode === 0 ? Font.Bold : Font.DemiBold
                                color: root.mode === 0 ? Theme.accentContrast : Theme.fgDim
                            }
                        }
                        MouseArea {
                            id: t0Hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.mode = 0 }
                        }
                    }

                    // Tab 1: Pomodoro
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 15
                        color: root.mode === 1 ? Theme.accent : (t1Hover.containsMouse ? Qt.alpha(Theme.fg, 0.08) : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰔐"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: root.mode === 1 ? Theme.accentContrast : Theme.fgDim
                            }
                            Text {
                                text: "Pomodoro"
                                font.family: "Plus Jakarta Sans"
                                font.pixelSize: 11
                                font.weight: root.mode === 1 ? Font.Bold : Font.DemiBold
                                color: root.mode === 1 ? Theme.accentContrast : Theme.fgDim
                            }
                        }
                        MouseArea {
                            id: t1Hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.mode = 1 }
                        }
                    }

                    // Tab 2: Weather
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 15
                        color: root.mode === 2 ? Theme.accent : (t2Hover.containsMouse ? Qt.alpha(Theme.fg, 0.08) : "transparent")
                        Behavior on color { ColorAnimation { duration: 140 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "󰖐"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 13
                                color: root.mode === 2 ? Theme.accentContrast : Theme.fgDim
                            }
                            Text {
                                text: "Weather"
                                font.family: "Plus Jakarta Sans"
                                font.pixelSize: 11
                                font.weight: root.mode === 2 ? Font.Bold : Font.DemiBold
                                color: root.mode === 2 ? Theme.accentContrast : Theme.fgDim
                            }
                        }
                        MouseArea {
                            id: t2Hover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.mode = 2 }
                        }
                    }
                }
            }

            /* ── Divider ── */
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(Theme.fg, 0.08)
            }

            /* ── Content Panes ── */
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: root.mode

                /* ========================================================
                 * TAB 0: CONTROL CENTER (ASYMMETRIC VINYL DECK & FADER SPINE)
                 * ======================================================== */
                Item {
                    id: paneControls

                    // Backend services & pollers for toggles
                    Process {
                        id: wifiPoller
                        command: ["sh", "-c", "nmcli radio wifi | tr -d ' \n\r'"]
                        running: root.open && root.mode === 0
                        stdout: StdioCollector {
                            onTextChanged: {
                                if (text) tileWifi.wifiOn = (text.trim() === "enabled")
                            }
                        }
                    }

                    Process {
                        id: ssidPoller
                        command: ["sh", "-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2-"]
                        running: root.open && root.mode === 0
                        stdout: StdioCollector {
                            onTextChanged: {
                                if (text && text.trim().length > 0) tileWifi.ssid = text.trim()
                            }
                        }
                    }

                    Process {
                        id: btPoller
                        command: ["sh", "-c", "bluetoothctl show 2>/dev/null | grep 'Powered:' | awk '{print $2}'"]
                        running: root.open && root.mode === 0
                        stdout: StdioCollector {
                            onTextChanged: {
                                if (text) tileBt.btOn = (text.trim() === "yes")
                            }
                        }
                    }

                    Timer {
                        interval: 4000
                        repeat: true
                        running: root.open && root.mode === 0
                        onTriggered: {
                            wifiPoller.running = true
                            ssidPoller.running = true
                            btPoller.running = true
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        /* ====================================================
                         * 1. TOP ZONE: Full-Width Asymmetric Vinyl Deck
                         * ==================================================== */
                        Item {
                            id: musicDeck
                            Layout.fillWidth: true
                            Layout.preferredHeight: 148
                            clip: true

                            // Ambient Backdrop Tint & Card Frame
                            Rectangle {
                                anchors.fill: parent
                                radius: 14
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                            }

                            // MPRIS Media Resolver
                            readonly property var mprisPlayers: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
                            property var activePlayer: null

                            function resolveActivePlayer() {
                                if (!mprisPlayers || mprisPlayers.length === 0) return null
                                for (let i = 0; i < mprisPlayers.length; i++) {
                                    if (mprisPlayers[i].playbackState === MprisPlaybackState.Playing)
                                        return mprisPlayers[i]
                                }
                                for (let i = 0; i < mprisPlayers.length; i++) {
                                    if (mprisPlayers[i].playbackState === MprisPlaybackState.Paused && (mprisPlayers[i].trackTitle || "").length > 0)
                                        return mprisPlayers[i]
                                }
                                return mprisPlayers[0]
                            }

                            Timer {
                                interval: 1000
                                repeat: true
                                running: root.open && root.mode === 0
                                triggeredOnStart: true
                                onTriggered: musicDeck.activePlayer = musicDeck.resolveActivePlayer()
                            }

                            readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
                            readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
                            readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
                            readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
                            readonly property bool hasTrack: activePlayer !== null && trackTitle.trim().length > 0

                            function togglePlayPause() {
                                if (activePlayer) activePlayer.togglePlaying()
                                else Quickshell.execDetached(["playerctl", "play-pause"])
                            }

                            function fmtTime(sec) {
                                if (!sec || isNaN(sec) || sec <= 0) return "00:00"
                                var h = Math.floor(sec / 3600)
                                var m = Math.floor((sec % 3600) / 60)
                                var s = Math.floor(sec % 60)
                                if (h > 0) {
                                    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
                                }
                                return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
                            }

                            property real positionSec: 0
                            property real lengthSec: (activePlayer && activePlayer.length > 0) ? activePlayer.length : 240
                            readonly property real progressRatio: lengthSec > 0 ? Math.max(0.0, Math.min(1.0, positionSec / lengthSec)) : 0.0

                            Timer {
                                interval: 1000
                                repeat: true
                                running: root.open && root.mode === 0 && musicDeck.isPlaying
                                onTriggered: {
                                    if (musicDeck.activePlayer && musicDeck.activePlayer.position !== undefined && musicDeck.activePlayer.position > 0) {
                                        musicDeck.positionSec = musicDeck.activePlayer.position
                                    } else {
                                        posProc.running = true
                                    }
                                }
                            }

                            Process {
                                id: posProc
                                command: ["playerctl", "position"]
                                stdout: StdioCollector {
                                    onTextChanged: {
                                        var p = parseFloat(text.trim())
                                        if (!isNaN(p) && p >= 0) musicDeck.positionSec = p
                                    }
                                }
                            }

                            Process {
                                id: lenProc
                                command: ["playerctl", "metadata", "mpris:length"]
                                stdout: StdioCollector {
                                    onTextChanged: {
                                        var l = parseFloat(text.trim())
                                        if (!isNaN(l) && l > 0) musicDeck.lengthSec = l / 1000000.0
                                    }
                                }
                            }

                            onActivePlayerChanged: {
                                posProc.running = true
                                lenProc.running = true
                            }

                            // ── Corner-Bleed Spinning Vinyl Disc (116x116, top: -14, right: -14) ──
                            Item {
                                id: vinylContainer
                                width: 116
                                height: 116
                                anchors.top: parent.top
                                anchors.topMargin: -14
                                anchors.right: parent.right
                                anchors.rightMargin: -14

                                // Outer Vinyl Disc Base (#090b0a)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 58
                                    color: "#090b0a"
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                }

                                // Concentric Vinyl Groove Rings Canvas
                                Canvas {
                                    anchors.fill: parent
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.06)
                                        ctx.lineWidth = 1
                                        var rings = [48, 41, 35]
                                        for (var idx = 0; idx < rings.length; idx++) {
                                            ctx.beginPath()
                                            ctx.arc(width / 2, height / 2, rings[idx], 0, 2 * Math.PI, false)
                                            ctx.stroke()
                                        }
                                    }
                                }

                                // Spinning Center Disc (Strict Easing.Linear Infinite RotationAnimator)
                                Item {
                                    id: vinylRotator
                                    anchors.fill: parent

                                    RotationAnimator {
                                        target: vinylRotator
                                        from: 0
                                        to: 360
                                        duration: 14000
                                        loops: Animation.Infinite
                                        running: musicDeck.isPlaying
                                        easing.type: Easing.Linear
                                    }

                                    // Center Circular Clipped Album Cover (diameter: 64px)
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 64
                                        height: 64
                                        radius: 32
                                        color: "#181a1b"
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.15)
                                        clip: true

                                        Image {
                                            id: albumCoverImg
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            source: musicDeck.artUrl
                                            visible: status === Image.Ready && musicDeck.artUrl.length > 0
                                        }

                                        // Fallback Record Center Label
                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 64
                                            height: 64
                                            radius: 32
                                            color: Qt.alpha(Theme.primary, 0.25)
                                            visible: !albumCoverImg.visible

                                            Rectangle {
                                                anchors.centerIn: parent
                                                width: 22
                                                height: 22
                                                radius: 11
                                                color: Theme.primary

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 6
                                                    height: 6
                                                    radius: 3
                                                    color: "#090b0a"
                                                }
                                            }
                                        }
                                    }
                                }

                                // Circular Song Progress Rim Canvas
                                Canvas {
                                    id: progressArcCanvas
                                    anchors.fill: parent
                                    antialiasing: true

                                    Connections {
                                        target: musicDeck
                                        function onProgressRatioChanged() { progressArcCanvas.requestPaint() }
                                    }

                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        var cx = width / 2
                                        var cy = height / 2
                                        var r = 55.5
                                        var startAngle = -Math.PI / 2
                                        var sweep = 2 * Math.PI * musicDeck.progressRatio
                                        var endAngle = startAngle + sweep

                                        if (musicDeck.progressRatio > 0.005) {
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, r, startAngle, endAngle, false)
                                            ctx.lineWidth = 2.5
                                            ctx.strokeStyle = Theme.primary
                                            ctx.lineCap = "round"
                                            ctx.stroke()

                                            // Glowing 4px tip dot
                                            var dotX = cx + r * Math.cos(endAngle)
                                            var dotY = cy + r * Math.sin(endAngle)
                                            ctx.beginPath()
                                            ctx.arc(dotX, dotY, 2.5, 0, 2 * Math.PI, false)
                                            ctx.fillStyle = "#ffffff"
                                            ctx.shadowColor = Theme.primary
                                            ctx.shadowBlur = 6
                                            ctx.fill()
                                        }
                                    }
                                }
                            }

                            // ── Left Content Stack (Status Tag, Track Title, Artist Subtitle) ──
                            ColumnLayout {
                                anchors.top: parent.top
                                anchors.topMargin: 12
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 104
                                spacing: 2

                                // Status Micro-Tag
                                Text {
                                    text: musicDeck.isPlaying ? "NOW PLAYING" : (musicDeck.hasTrack ? "PAUSED // MEDIA" : "IDLE // MEDIA")
                                    font.family: "Plus Jakarta Sans"
                                    font.pixelSize: 9
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.2
                                    color: Theme.primary
                                    opacity: 0.85
                                }

                                // Track Title
                                Text {
                                    Layout.fillWidth: true
                                    text: musicDeck.hasTrack ? musicDeck.trackTitle : "No Media Active"
                                    font.family: "Plus Jakarta Sans"
                                    font.pixelSize: 13
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"
                                    elide: Text.ElideRight
                                }

                                // Artist Subtitle
                                Text {
                                    Layout.fillWidth: true
                                    text: musicDeck.hasTrack ? (musicDeck.trackArtist || "Unknown Artist") : "System Audio Idle"
                                    font.family: "Plus Jakarta Sans"
                                    font.pixelSize: 11
                                    color: "#9aa59e"
                                    elide: Text.ElideRight
                                }
                            }

                            // ── Bottom Zone: WavySeekBar & Transport Row ──
                            ColumnLayout {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                spacing: 4

                                // Animated Organic Fluid Ripple Seek Bar
                                WavySeekBar {
                                    id: musicSeekBar
                                    Layout.fillWidth: true
                                    waveHeight: 12
                                    barHeight: 5
                                    timeLabelSize: 8
                                    accentColor: Theme.primary
                                    accentLitColor: Theme.primary
                                    showTimeLabels: false
                                    currentPosition: (musicDeck.activePlayer && LyricsService.currentPosition > 0) ? LyricsService.currentPosition : musicDeck.positionSec
                                    totalLength: (musicDeck.activePlayer && LyricsService.totalLength > 0) ? LyricsService.totalLength : musicDeck.lengthSec
                                    isPlaying: musicDeck.isPlaying
                                    onSeekRequested: frac => {
                                        var targetSec = frac * musicDeck.lengthSec
                                        musicDeck.positionSec = targetSec
                                        if (musicDeck.activePlayer && musicDeck.activePlayer.canSeek) {
                                            musicDeck.activePlayer.position = targetSec
                                        } else {
                                            Quickshell.execDetached(["playerctl", "position", String(Math.floor(targetSec))])
                                        }
                                    }
                                }

                                // Transport Controls & Timestamp Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 24
                                    spacing: 8

                                    // Left: Timestamps 01:24 / 03:45
                                    Text {
                                        text: musicDeck.fmtTime(musicDeck.positionSec) + " / " + (musicDeck.lengthSec > 0 ? musicDeck.fmtTime(musicDeck.lengthSec) : "--:--")
                                        font.family: "Plus Jakarta Sans"
                                        font.pixelSize: 10
                                        color: "#8a968e"
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Prev Button
                                    Rectangle {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        radius: 11
                                        color: prevBtnMouse.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰒮"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                            color: Theme.fg
                                        }

                                        MouseArea {
                                            id: prevBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (musicDeck.activePlayer) musicDeck.activePlayer.previous()
                                                else Quickshell.execDetached(["playerctl", "previous"])
                                            }
                                        }
                                    }

                                    // Play / Pause Capsule Pill
                                    Rectangle {
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 22
                                        radius: 11
                                        color: playBtnMouse.containsMouse ? Qt.alpha(Theme.primary, 0.35) : Qt.alpha(Theme.primary, 0.22)
                                        border.width: 1
                                        border.color: Qt.alpha(Theme.primary, 0.45)

                                        Text {
                                            anchors.centerIn: parent
                                            text: musicDeck.isPlaying ? "󰏤" : "󰐊"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                            color: Theme.primary
                                        }

                                        MouseArea {
                                            id: playBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: musicDeck.togglePlayPause()
                                        }
                                    }

                                    // Next Button
                                    Rectangle {
                                        Layout.preferredWidth: 22
                                        Layout.preferredHeight: 22
                                        radius: 11
                                        color: nextBtnMouse.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent"

                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰒭"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 13
                                            color: Theme.fg
                                        }

                                        MouseArea {
                                            id: nextBtnMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (musicDeck.activePlayer) musicDeck.activePlayer.next()
                                                else Quickshell.execDetached(["playerctl", "next"])
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        /* ====================================================
                         * 2. CENTER ZONE: Aesthetic Dual Capsule Faders
                         * (Volume & Brightness horizontal console)
                         * ==================================================== */
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // ── A. Volume Studio Capsule Slider ──
                            Rectangle {
                                id: volSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 18
                                color: Qt.rgba(0.04, 0.05, 0.04, 0.85)
                                border.width: 1
                                border.color: volMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                                clip: true
                                Behavior on border.color { ColorAnimation { duration: 140 } }

                                readonly property var sink: Pipewire.defaultAudioSink
                                readonly property real rawVol: (sink && sink.audio && sink.audio.volume !== undefined)
                                    ? sink.audio.volume : (SysBackend ? SysBackend.currentVolume : 0.5)
                                readonly property bool isMuted: (sink && sink.audio && sink.audio.muted !== undefined)
                                    ? sink.audio.muted : (SysBackend ? SysBackend.isMuted : false)
                                readonly property real clampedVol: Math.max(0.0, Math.min(1.0, rawVol))

                                // Liquid Fill Bar with Meniscus Glow
                                Rectangle {
                                    id: volLiquidFill
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 2
                                    width: volSlider.isMuted ? 0 : Math.max(0, Math.min(parent.width - 4, (parent.width - 4) * volSlider.clampedVol))
                                    radius: 16
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) }
                                        GradientStop { position: 1.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45) }
                                    }
                                    Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

                                    // Glowing Vertical Meniscus Pill Line
                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.topMargin: 4
                                        anchors.bottomMargin: 4
                                        width: 3
                                        radius: 1.5
                                        color: "#FFFFFF"
                                        visible: !volSlider.isMuted && volSlider.clampedVol > 0.02

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 7
                                            height: parent.height + 4
                                            radius: 3.5
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                            z: -1
                                        }
                                    }
                                }

                                // Interactive Mute / Speaker Icon Button (Left)
                                Rectangle {
                                    id: volMuteBtn
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: volMuteMouse.containsMouse ? Qt.alpha(Theme.primary, 0.25) : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: volSlider.isMuted ? "󰝟" : (volSlider.clampedVol < 0.33 ? "󰕿" : (volSlider.clampedVol < 0.66 ? "󰖀" : "󰕾"))
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: volSlider.isMuted ? Theme.fgFaint : Theme.primary
                                    }

                                    MouseArea {
                                        id: volMuteMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                                Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                                            } else {
                                                Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                                            }
                                        }
                                    }
                                }

                                // Subtext Label: Volume
                                Text {
                                    anchors.left: volMuteBtn.right
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Volume"
                                    font.family: "Plus Jakarta Sans"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: volSlider.isMuted ? Theme.fgFaint : "#d8dfd9"
                                }

                                // Right Percentage Badge
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 38
                                    height: 20
                                    radius: 10
                                    color: Qt.rgba(0, 0, 0, 0.40)

                                    Text {
                                        anchors.centerIn: parent
                                        text: volSlider.isMuted ? "MUT" : Math.round(volSlider.clampedVol * 100) + "%"
                                        font.family: "Plus Jakarta Sans"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: volSlider.isMuted ? Theme.fgFaint : "#FFFFFF"
                                    }
                                }

                                // Interactive Scrubbing MouseArea
                                MouseArea {
                                    id: volMouse
                                    anchors.fill: parent
                                    anchors.leftMargin: 36
                                    anchors.rightMargin: 48
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    function setVolFromX(mouseX) {
                                        var r = Math.max(0.0, Math.min(1.0, mouseX / width))
                                        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                            Pipewire.defaultAudioSink.audio.volume = r
                                            if (Pipewire.defaultAudioSink.audio.muted) Pipewire.defaultAudioSink.audio.muted = false
                                        } else {
                                            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(r * 100) + "%"])
                                        }
                                    }

                                    onPressed: mouse => setVolFromX(mouse.x)
                                    onPositionChanged: mouse => { if (pressed) setVolFromX(mouse.x) }
                                    onWheel: wheel => {
                                        var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                        var newVol = Math.max(0.0, Math.min(1.0, volSlider.clampedVol + delta))
                                        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                            Pipewire.defaultAudioSink.audio.volume = newVol
                                            if (Pipewire.defaultAudioSink.audio.muted) Pipewire.defaultAudioSink.audio.muted = false
                                        } else {
                                            Quickshell.execDetached(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(newVol * 100) + "%"])
                                        }
                                    }
                                }
                            }

                            // ── B. Brightness Studio Capsule Slider ──
                            Rectangle {
                                id: brightSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: 18
                                color: Qt.rgba(0.04, 0.05, 0.04, 0.85)
                                border.width: 1
                                border.color: brightMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                                clip: true
                                Behavior on border.color { ColorAnimation { duration: 140 } }

                                property int curBrightness: (SysBackend && SysBackend.lastBrightnessPct >= 0)
                                    ? SysBackend.lastBrightnessPct : 80
                                readonly property real brightRatio: Math.max(0.05, Math.min(1.0, curBrightness / 100.0))

                                // Liquid Fill Bar with Meniscus Glow
                                Rectangle {
                                    id: brightLiquidFill
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.margins: 2
                                    width: Math.max(0, Math.min(parent.width - 4, (parent.width - 4) * brightSlider.brightRatio))
                                    radius: 16
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) }
                                        GradientStop { position: 1.0; color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45) }
                                    }
                                    Behavior on width { NumberAnimation { duration: 80; easing.type: Easing.OutCubic } }

                                    // Glowing Vertical Meniscus Pill Line
                                    Rectangle {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        anchors.topMargin: 4
                                        anchors.bottomMargin: 4
                                        width: 3
                                        radius: 1.5
                                        color: "#FFFFFF"

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 7
                                            height: parent.height + 4
                                            radius: 3.5
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                            z: -1
                                        }
                                    }
                                }

                                // Icon (Left)
                                Rectangle {
                                    id: brightIconBox
                                    anchors.left: parent.left
                                    anchors.leftMargin: 4
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: brightSlider.curBrightness < 33 ? "󰃞" : (brightSlider.curBrightness < 66 ? "󰃟" : "󰃠")
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 14
                                        color: Theme.primary
                                    }
                                }

                                // Subtext Label: Brightness
                                Text {
                                    anchors.left: brightIconBox.right
                                    anchors.leftMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Brightness"
                                    font.family: "Plus Jakarta Sans"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: "#d8dfd9"
                                }

                                // Right Percentage Badge
                                Rectangle {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 38
                                    height: 20
                                    radius: 10
                                    color: Qt.rgba(0, 0, 0, 0.40)

                                    Text {
                                        anchors.centerIn: parent
                                        text: brightSlider.curBrightness + "%"
                                        font.family: "Plus Jakarta Sans"
                                        font.pixelSize: 10
                                        font.bold: true
                                        color: "#FFFFFF"
                                    }
                                }

                                // Interactive Scrubbing MouseArea
                                MouseArea {
                                    id: brightMouse
                                    anchors.fill: parent
                                    anchors.leftMargin: 36
                                    anchors.rightMargin: 48
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    function setBrightFromX(mouseX) {
                                        var pct = Math.round(Math.max(5, Math.min(100, (mouseX / width) * 100)))
                                        brightSlider.curBrightness = pct
                                        Quickshell.execDetached(["brightnessctl", "set", pct + "%", "-q"])
                                    }

                                    onPressed: mouse => setBrightFromX(mouse.x)
                                    onPositionChanged: mouse => { if (pressed) setBrightFromX(mouse.x) }
                                    onWheel: wheel => {
                                        var delta = wheel.angleDelta.y > 0 ? 5 : -5
                                        var pct = Math.max(5, Math.min(100, brightSlider.curBrightness + delta))
                                        brightSlider.curBrightness = pct
                                        Quickshell.execDetached(["brightnessctl", "set", pct + "%", "-q"])
                                    }
                                }
                            }
                        }

                        /* ====================================================
                         * 3. BOTTOM ZONE: 2x2 Tactile Action Button Grid
                         * Wi-Fi & Bluetooth: Click toggles On/Off, Longpress opens manager
                         * ==================================================== */
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 6
                            columnSpacing: 6

                            // ── Button 1: Wi-Fi ──
                            Rectangle {
                                id: tileWifi
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 12
                                property bool wifiOn: true
                                property string ssid: "Connected"
                                color: tileWifi.wifiOn
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, wifiMouse.containsMouse ? 0.20 : 0.12)
                                    : (wifiMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.035))
                                border.width: 1
                                border.color: tileWifi.wifiOn
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                    : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: 130 } }
                                Behavior on border.color { ColorAnimation { duration: 130 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Button Icon Circle
                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: tileWifi.wifiOn ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                        scale: wifiMouse.pressed ? 0.92 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 90 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: tileWifi.wifiOn ? "󰤨" : "󰤭"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                            color: tileWifi.wifiOn ? "#090b0a" : Theme.fgFaint
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Wi-Fi"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#FFFFFF"
                                        }
                                        Text {
                                            text: tileWifi.wifiOn ? tileWifi.ssid : "Off"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 10
                                            color: tileWifi.wifiOn ? "#a2ada6" : "#606863"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: wifiMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    pressAndHoldInterval: 450
                                    property bool held: false

                                    onPressed: { held = false }
                                    onPressAndHold: {
                                        held = true
                                        Quickshell.execDetached(["nm-connection-editor"])
                                    }
                                    onClicked: {
                                        if (!held) {
                                            var nextState = !tileWifi.wifiOn
                                            tileWifi.wifiOn = nextState
                                            Quickshell.execDetached(["nmcli", "radio", "wifi", nextState ? "on" : "off"])
                                            wifiPoller.running = false
                                            wifiPoller.running = true
                                        }
                                    }
                                }
                            }

                            // ── Button 2: Bluetooth ──
                            Rectangle {
                                id: tileBt
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 12
                                property bool btOn: false
                                color: tileBt.btOn
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, btMouse.containsMouse ? 0.20 : 0.12)
                                    : (btMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.035))
                                border.width: 1
                                border.color: tileBt.btOn
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                    : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: 130 } }
                                Behavior on border.color { ColorAnimation { duration: 130 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    // Button Icon Circle
                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: tileBt.btOn ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                        scale: btMouse.pressed ? 0.92 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 90 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: tileBt.btOn ? "󰂯" : "󰂲"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                            color: tileBt.btOn ? "#090b0a" : Theme.fgFaint
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Bluetooth"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#FFFFFF"
                                        }
                                        Text {
                                            text: tileBt.btOn ? "Enabled" : "Off"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 10
                                            color: tileBt.btOn ? "#a2ada6" : "#606863"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: btMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    pressAndHoldInterval: 450
                                    property bool held: false

                                    onPressed: { held = false }
                                    onPressAndHold: {
                                        held = true
                                        Quickshell.execDetached(["blueman-manager"])
                                    }
                                    onClicked: {
                                        if (!held) {
                                            var next = !tileBt.btOn
                                            tileBt.btOn = next
                                            Quickshell.execDetached(["bluetoothctl", "power", next ? "on" : "off"])
                                            btPoller.running = false
                                            btPoller.running = true
                                        }
                                    }
                                }
                            }

                            // ── Button 3: Do Not Disturb ──
                            Rectangle {
                                id: tileDnd
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 12
                                readonly property bool isDnd: (typeof Theme !== "undefined" && Theme.dnd !== undefined) ? Theme.dnd : false
                                color: tileDnd.isDnd
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, dndMouse.containsMouse ? 0.20 : 0.12)
                                    : (dndMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.035))
                                border.width: 1
                                border.color: tileDnd.isDnd
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                    : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: 130 } }
                                Behavior on border.color { ColorAnimation { duration: 130 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: tileDnd.isDnd ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                        scale: dndMouse.pressed ? 0.92 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 90 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: tileDnd.isDnd ? "󰂛" : "󰂚"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                            color: tileDnd.isDnd ? "#090b0a" : Theme.fgFaint
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Do Not Disturb"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#FFFFFF"
                                        }
                                        Text {
                                            text: tileDnd.isDnd ? "Muted" : "Alerts On"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 10
                                            color: tileDnd.isDnd ? "#a2ada6" : "#606863"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: dndMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof NotificationService !== "undefined" && NotificationService.toggleDnd) {
                                            NotificationService.toggleDnd()
                                        } else if (typeof Theme !== "undefined") {
                                            Theme.dnd = !Theme.dnd
                                        }
                                    }
                                }
                            }

                            // ── Button 4: Appearance ──
                            Rectangle {
                                id: tileAppr
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 12
                                readonly property bool dark: (typeof Theme !== "undefined" && Theme.isDark !== undefined) ? Theme.isDark : true
                                color: tileAppr.dark
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, apprMouse.containsMouse ? 0.20 : 0.12)
                                    : (apprMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.035))
                                border.width: 1
                                border.color: tileAppr.dark
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
                                    : Qt.rgba(1, 1, 1, 0.08)
                                Behavior on color { ColorAnimation { duration: 130 } }
                                Behavior on border.color { ColorAnimation { duration: 130 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: tileAppr.dark ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                        scale: apprMouse.pressed ? 0.92 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 90 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: tileAppr.dark ? "󰖔" : "󰖙"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 14
                                            color: tileAppr.dark ? "#090b0a" : Theme.fgFaint
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Appearance"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: "#FFFFFF"
                                        }
                                        Text {
                                            text: tileAppr.dark ? "Dark Mode" : "Light Mode"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 10
                                            color: tileAppr.dark ? "#a2ada6" : "#606863"
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: apprMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof Theme !== "undefined") {
                                            if (Theme.toggleDark) Theme.toggleDark()
                                            else Theme.isDark = !Theme.isDark
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                /* ========================================================
                 * TAB 1: POMODORO
                 * ======================================================== */
                Item {
                    id: panePomodoro

                    readonly property string pomoJsonPath: (Quickshell.env("HOME") || "") + "/.config/hypr/carbon-pomodoro.json"
                    property bool running: false
                    property string phase: "work" // "work" | "short_break" | "long_break"
                    property int remaining: 1500
                    property int workSec: 1500
                    property int breakSec: 300
                    property int longBreakSec: 900
                    property int cycles: 0

                    function fmtTime(s) {
                        var m = Math.floor(s / 60)
                        var sec = s % 60
                        return String(m).padStart(2, "0") + ":" + String(sec).padStart(2, "0")
                    }

                    // Poll the shared json file
                    Process {
                        id: pomoReader
                        command: ["cat", panePomodoro.pomoJsonPath]
                        running: true
                        stdout: StdioCollector {
                            waitForEnd: true
                            onTextChanged: {
                                if (text && text.trim().length > 0) {
                                    try {
                                        var d = JSON.parse(text.trim())
                                        if (d) {
                                            panePomodoro.running = !!d.running
                                            panePomodoro.phase = d.phase || "work"
                                            panePomodoro.remaining = d.remaining !== undefined ? d.remaining : 1500
                                            panePomodoro.workSec = d.workSec || 1500
                                            panePomodoro.breakSec = d.breakSec || 300
                                            panePomodoro.longBreakSec = d.longBreakSec || 900
                                            panePomodoro.cycles = d.cycles || 0
                                        }
                                    } catch (e) {}
                                }
                            }
                        }
                    }

                    Timer {
                        interval: 1000
                        repeat: true
                        running: root.open && root.mode === 1
                        onTriggered: {
                            pomoReader.running = false
                            pomoReader.running = true
                        }
                    }

                    function savePomo(newRunning, newRemaining, newPhase) {
                        var obj = {
                            "running": newRunning,
                            "phase": newPhase,
                            "remaining": newRemaining,
                            "workSec": panePomodoro.workSec,
                            "breakSec": panePomodoro.breakSec,
                            "longBreakSec": panePomodoro.longBreakSec,
                            "cycles": panePomodoro.cycles
                        }
                        var py = "import json, sys; p = sys.argv[1]; cur = {}; (open(p) and cur.update(json.load(open(p)))); cur.update(json.loads(sys.argv[2])); open(p, 'w').write(json.dumps(cur, indent=2))"
                        Quickshell.execDetached(["python3", "-c", py, panePomodoro.pomoJsonPath, JSON.stringify(obj)])
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12

                        // Phase Badge
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 130
                            Layout.preferredHeight: 26
                            radius: 13
                            color: panePomodoro.phase === "work" ? Qt.alpha(Theme.accent, 0.15) : Qt.alpha("#10B981", 0.15)
                            border.width: 1
                            border.color: panePomodoro.phase === "work" ? Theme.accent : "#10B981"

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: panePomodoro.phase === "work" ? Theme.accent : "#10B981"
                                }

                                Text {
                                    text: panePomodoro.phase === "work" ? "FOCUS SESSION" : (panePomodoro.phase === "long_break" ? "LONG BREAK" : "SHORT BREAK")
                                    font.family: "Plus Jakarta Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: panePomodoro.phase === "work" ? Theme.accentLit : "#10B981"
                                }
                            }
                        }

                        // Big Timer Countdown
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: panePomodoro.fmtTime(panePomodoro.remaining)
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 42
                            font.weight: Font.Bold
                            color: panePomodoro.running ? Theme.accentLit : Theme.fg
                        }

                        // Progress Line
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 4
                            radius: 2
                            color: Qt.alpha(Theme.fg, 0.1)

                            readonly property int totalSec: panePomodoro.phase === "work" ? panePomodoro.workSec : (panePomodoro.phase === "long_break" ? panePomodoro.longBreakSec : panePomodoro.breakSec)
                            readonly property real prog: totalSec > 0 ? Math.max(0.0, Math.min(1.0, 1.0 - (panePomodoro.remaining / totalSec))) : 0

                            Rectangle {
                                width: Math.round(parent.width * parent.prog)
                                height: parent.height
                                radius: 2
                                color: panePomodoro.phase === "work" ? Theme.accent : "#10B981"
                                Behavior on width { NumberAnimation { duration: 120 } }
                            }
                        }

                        // Session Dots & Text
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    required property int index
                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: index < (panePomodoro.cycles % 4) ? Theme.accent : Qt.alpha(Theme.fg, 0.18)
                                }
                            }

                            Text {
                                text: "Session " + ((panePomodoro.cycles % 4) + 1) + " of 4"
                                font.family: "Plus Jakarta Sans"
                                font.pixelSize: 11
                                color: Theme.fgDim
                            }
                        }

                        // Action Controls (Start / Pause, Reset, Skip)
                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 12

                            // Reset Button
                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: 19
                                color: resetHov.containsMouse ? Qt.alpha(Theme.fg, 0.12) : Qt.alpha(Theme.fg, 0.05)
                                border.width: 1
                                border.color: Qt.alpha(Theme.fg, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰑐"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                    color: Theme.fgDim
                                }
                                MouseArea {
                                    id: resetHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var dur = panePomodoro.phase === "work" ? panePomodoro.workSec : panePomodoro.breakSec
                                        panePomodoro.savePomo(false, dur, panePomodoro.phase)
                                        pomoReader.running = false
                                        pomoReader.running = true
                                    }
                                }
                            }

                            // Start / Pause Primary Button
                            Rectangle {
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 38
                                radius: 19
                                color: panePomodoro.running ? Qt.alpha(Theme.accent, 0.2) : Theme.accent
                                border.width: panePomodoro.running ? 1 : 0
                                border.color: Theme.accent

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: panePomodoro.running ? "󰏤" : "󰐊"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                        color: panePomodoro.running ? Theme.accentLit : Theme.accentContrast
                                    }
                                    Text {
                                        text: panePomodoro.running ? "PAUSE" : "START"
                                        font.family: "Plus Jakarta Sans"
                                        font.pixelSize: 12
                                        font.weight: Font.Bold
                                        color: panePomodoro.running ? Theme.accentLit : Theme.accentContrast
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        panePomodoro.savePomo(!panePomodoro.running, panePomodoro.remaining, panePomodoro.phase)
                                        pomoReader.running = false
                                        pomoReader.running = true
                                    }
                                }
                            }

                            // Skip Button
                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 38
                                radius: 19
                                color: skipHov.containsMouse ? Qt.alpha(Theme.fg, 0.12) : Qt.alpha(Theme.fg, 0.05)
                                border.width: 1
                                border.color: Qt.alpha(Theme.fg, 0.1)

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒭"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 16
                                    color: Theme.fgDim
                                }
                                MouseArea {
                                    id: skipHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var nextPhase = panePomodoro.phase === "work" ? "short_break" : "work"
                                        var nextDur = nextPhase === "work" ? panePomodoro.workSec : panePomodoro.breakSec
                                        panePomodoro.savePomo(false, nextDur, nextPhase)
                                        pomoReader.running = false
                                        pomoReader.running = true
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Launch full Carbon Pomodoro App
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: 10
                            color: openAppHov.containsMouse ? Qt.alpha(Theme.accent, 0.15) : Qt.alpha(Theme.fg, 0.05)
                            border.width: 1
                            border.color: openAppHov.containsMouse ? Theme.accent : Qt.alpha(Theme.fg, 0.1)

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    text: "󰄬"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: Theme.accent
                                }
                                Text {
                                    text: "Open Full Pomodoro Tracker"
                                    font.family: "Plus Jakarta Sans"
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    color: Theme.fg
                                }
                            }

                            MouseArea {
                                id: openAppHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Quickshell.execDetached(["python3", (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/carbon-pomodoro.py"])
                                    root.open = false
                                }
                            }
                        }
                    }
                }

                /* ========================================================
                 * TAB 2: WEATHER & API KEY CONFIGURATION
                 * ======================================================== */
                Item {
                    id: paneWeather

                    property string apiKey: ""
                    property string cityName: "Patna,IN"
                    property string unit: "metric"
                    property string temp: "--"
                    property string feelsLike: "--"
                    property string desc: "Loading..."
                    property string icon: "󰖐"
                    property string humidity: "--"
                    property string wind: "--"
                    property var forecast: []
                    property int weatherSubTab: 0  // 0: Today, 1: 7-Day Forecast
                    property string statusMsg: ""
                    property bool showConfig: false

                    readonly property string weatherScriptPath: (Quickshell.env("HOME") || "") + "/.local/share/quickshell/carbon/scripts/carbon-weather.py"

                    Process {
                        id: weatherPoller
                        command: ["python3", paneWeather.weatherScriptPath, "status"]
                        running: true
                        stdout: StdioCollector {
                            waitForEnd: true
                            onTextChanged: {
                                if (text && text.trim().length > 0) {
                                    try {
                                        var d = JSON.parse(text.trim())
                                        if (d) {
                                            paneWeather.apiKey = d.api_key || ""
                                            paneWeather.cityName = d.city_name || "Patna,IN"
                                            paneWeather.unit = d.unit || "metric"
                                            paneWeather.temp = d.temp || "--"
                                            paneWeather.feelsLike = d.feels_like || "--"
                                            paneWeather.desc = d.description || ""
                                            paneWeather.icon = d.icon || "󰖐"
                                            paneWeather.humidity = d.humidity || "--"
                                            paneWeather.wind = d.wind || "--"
                                            paneWeather.forecast = (d.forecast && Array.isArray(d.forecast)) ? d.forecast : []
                                            if (d.error) paneWeather.statusMsg = d.error
                                            else paneWeather.statusMsg = ""
                                        }
                                    } catch (e) {}
                                }
                            }
                        }
                    }

                    Timer {
                        interval: 60000
                        repeat: true
                        running: root.open && root.mode === 2
                        onTriggered: {
                            weatherPoller.running = false
                            weatherPoller.running = true
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 10

                        // Top Row: City & Refresh / Config Toggle
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "󰍎 " + paneWeather.cityName
                                font.family: "Plus Jakarta Sans"
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: Theme.fg
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            // Refresh Button
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                color: refHov.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰑐"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: Theme.fgDim
                                }
                                MouseArea {
                                    id: refHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        weatherPoller.command = ["python3", paneWeather.weatherScriptPath, "status", "--force"]
                                        weatherPoller.running = false
                                        weatherPoller.running = true
                                    }
                                }
                            }

                            // Config / Gear Button
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                color: paneWeather.showConfig ? Theme.accent : (cfgHov.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent")

                                Text {
                                    anchors.centerIn: parent
                                    text: "󰒓"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 14
                                    color: paneWeather.showConfig ? Theme.accentContrast : Theme.fgDim
                                }
                                MouseArea {
                                    id: cfgHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        paneWeather.showConfig = !paneWeather.showConfig
                                    }
                                }
                            }
                        }

                        // Sub-navigation Switcher: [ Today | 7-Day Forecast ]
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 15
                            color: Qt.alpha(Theme.fg, 0.05)
                            border.width: 1
                            border.color: Qt.alpha(Theme.fg, 0.08)
                            visible: !paneWeather.showConfig

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 2
                                spacing: 2

                                // Tab: Today
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 13
                                    color: paneWeather.weatherSubTab === 0 ? Theme.accent : (tSub0Hov.containsMouse ? Qt.alpha(Theme.fg, 0.08) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text {
                                            text: "󰖐"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: paneWeather.weatherSubTab === 0 ? Theme.accentContrast : Theme.fgDim
                                        }
                                        Text {
                                            text: "Today"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 11
                                            font.weight: paneWeather.weatherSubTab === 0 ? Font.Bold : Font.Medium
                                            color: paneWeather.weatherSubTab === 0 ? Theme.accentContrast : Theme.fgDim
                                        }
                                    }
                                    MouseArea {
                                        id: tSub0Hov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { paneWeather.weatherSubTab = 0 }
                                    }
                                }

                                // Tab: 7-Day Forecast
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 13
                                    color: paneWeather.weatherSubTab === 1 ? Theme.accent : (tSub1Hov.containsMouse ? Qt.alpha(Theme.fg, 0.08) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 140 } }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Text {
                                            text: "󰸗"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            color: paneWeather.weatherSubTab === 1 ? Theme.accentContrast : Theme.fgDim
                                        }
                                        Text {
                                            text: "7-Day Forecast"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 11
                                            font.weight: paneWeather.weatherSubTab === 1 ? Font.Bold : Font.Medium
                                            color: paneWeather.weatherSubTab === 1 ? Theme.accentContrast : Theme.fgDim
                                        }
                                    }
                                    MouseArea {
                                        id: tSub1Hov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { paneWeather.weatherSubTab = 1 }
                                    }
                                }
                            }
                        }

                        // Weather Display Card (When Config is closed and subTab === 0)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 110
                            radius: 12
                            color: Qt.alpha(Theme.fg, 0.04)
                            border.width: 1
                            border.color: Qt.alpha(Theme.fg, 0.08)
                            visible: !paneWeather.showConfig && paneWeather.weatherSubTab === 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 14

                                Text {
                                    text: paneWeather.icon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 48
                                    color: Theme.accent
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: paneWeather.temp
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 28
                                        font.weight: Font.Bold
                                        color: Theme.accentLit || "#ffffff"
                                    }
                                    Text {
                                        text: paneWeather.desc
                                        font.family: "Plus Jakarta Sans"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: Theme.fgDim
                                    }
                                    Text {
                                        text: "Feels like: " + paneWeather.feelsLike
                                        font.family: "Plus Jakarta Sans"
                                        font.pixelSize: 10
                                        color: Theme.fgFaint
                                    }
                                }
                            }
                        }

                        // Weather Stats (Humidity, Wind)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            visible: !paneWeather.showConfig && paneWeather.weatherSubTab === 0

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 10
                                color: Qt.alpha(Theme.fg, 0.04)
                                border.width: 1
                                border.color: Qt.alpha(Theme.fg, 0.08)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text {
                                        text: "󰖟"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                        color: Theme.accent
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Humidity"; font.family: "Plus Jakarta Sans"; font.pixelSize: 9; color: Theme.fgFaint }
                                        Text { text: paneWeather.humidity; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.fg }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 46
                                radius: 10
                                color: Qt.alpha(Theme.fg, 0.04)
                                border.width: 1
                                border.color: Qt.alpha(Theme.fg, 0.08)

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text {
                                        text: "󰖝"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 16
                                        color: Theme.accent
                                    }
                                    ColumnLayout {
                                        spacing: 1
                                        Text { text: "Wind"; font.family: "Plus Jakarta Sans"; font.pixelSize: 9; color: Theme.fgFaint }
                                        Text { text: paneWeather.wind; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11; font.weight: Font.Bold; color: Theme.fg }
                                    }
                                }
                            }
                        }

                        // 7-Day Forecast View (When subTab === 1)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: Qt.alpha(Theme.fg, 0.03)
                            border.width: 1
                            border.color: Qt.alpha(Theme.fg, 0.08)
                            clip: true
                            visible: !paneWeather.showConfig && paneWeather.weatherSubTab === 1

                            ListView {
                                id: forecastList
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 4
                                clip: true
                                model: paneWeather.forecast
                                boundsBehavior: Flickable.StopAtBounds

                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index

                                    width: forecastList.width
                                    height: 32
                                    radius: 8
                                    color: dayHov.containsMouse ? Qt.alpha(Theme.accent, 0.12) : (index % 2 === 0 ? Qt.alpha(Theme.fg, 0.03) : "transparent")
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        spacing: 8

                                        // Day & Date
                                        ColumnLayout {
                                            Layout.preferredWidth: 62
                                            spacing: 0
                                            Text {
                                                text: modelData.day
                                                font.family: "Plus Jakarta Sans"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: index === 0 ? (Theme.accentLit || Theme.accent) : Theme.fg
                                            }
                                            Text {
                                                text: modelData.date
                                                font.family: "Plus Jakarta Sans"
                                                font.pixelSize: 8
                                                color: Theme.fgFaint
                                            }
                                        }

                                        // Weather Icon
                                        Text {
                                            Layout.preferredWidth: 20
                                            horizontalAlignment: Text.AlignHCenter
                                            text: modelData.icon || "󰖐"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 15
                                            color: Theme.accent
                                        }

                                        // Condition Description
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.desc || ""
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 10
                                            color: Theme.fgDim
                                            elide: Text.ElideRight
                                        }

                                        // Temperature Range Bar & Values
                                        RowLayout {
                                            spacing: 6
                                            Text {
                                                text: modelData.temp_min_str || (modelData.temp_min + "°")
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 10
                                                color: Theme.fgDim
                                            }

                                            // Visual Range Bar
                                            Rectangle {
                                                Layout.preferredWidth: 32
                                                Layout.preferredHeight: 4
                                                radius: 2
                                                color: Qt.alpha(Theme.fg, 0.1)

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.right: parent.right
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    height: 4
                                                    radius: 2
                                                    color: Theme.accent
                                                    opacity: 0.85
                                                }
                                            }

                                            Text {
                                                text: modelData.temp_max_str || (modelData.temp_max + "°")
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: 11
                                                font.weight: Font.Bold
                                                color: Theme.fg
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: dayHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                    }
                                }
                            }
                        }

                        // Weather Settings Form (Toggled via Gear Icon)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: Qt.alpha(Theme.fg, 0.04)
                            border.width: 1
                            border.color: Qt.alpha(Theme.fg, 0.08)
                            visible: paneWeather.showConfig

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 8

                                Text {
                                    text: "OpenWeatherMap API Key"
                                    font.family: "Plus Jakarta Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Theme.fgDim
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 6
                                    color: Qt.alpha(Theme.fg, 0.06)
                                    border.width: 1
                                    border.color: keyInput.activeFocus ? Theme.accent : Qt.alpha(Theme.fg, 0.12)

                                    TextInput {
                                        id: keyInput
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: paneWeather.apiKey
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: Theme.fg
                                        clip: true
                                        selectByMouse: true
                                    }
                                }

                                Text {
                                    text: "City / Region (e.g. London,UK or Patna,IN)"
                                    font.family: "Plus Jakarta Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: Theme.fgDim
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 6
                                    color: Qt.alpha(Theme.fg, 0.06)
                                    border.width: 1
                                    border.color: cityInput.activeFocus ? Theme.accent : Qt.alpha(Theme.fg, 0.12)

                                    TextInput {
                                        id: cityInput
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: paneWeather.cityName
                                        font.family: "Plus Jakarta Sans"
                                        font.pixelSize: 11
                                        color: Theme.fg
                                        clip: true
                                        selectByMouse: true
                                    }
                                }

                                // Units Toggle
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text {
                                        text: "Units:"
                                        font.family: "Plus Jakarta Sans"
                                        font.pixelSize: 10
                                        font.weight: Font.Bold
                                        color: Theme.fgDim
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 60
                                        Layout.preferredHeight: 24
                                        radius: 12
                                        color: paneWeather.unit === "metric" ? Theme.accent : Qt.alpha(Theme.fg, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "°C Metric"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            color: paneWeather.unit === "metric" ? Theme.accentContrast : Theme.fgDim
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { paneWeather.unit = "metric" }
                                        }
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: 68
                                        Layout.preferredHeight: 24
                                        radius: 12
                                        color: paneWeather.unit === "imperial" ? Theme.accent : Qt.alpha(Theme.fg, 0.08)
                                        Text {
                                            anchors.centerIn: parent
                                            text: "°F Imperial"
                                            font.family: "Plus Jakarta Sans"
                                            font.pixelSize: 9
                                            font.weight: Font.Bold
                                            color: paneWeather.unit === "imperial" ? Theme.accentContrast : Theme.fgDim
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { paneWeather.unit = "imperial" }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }

                                // Save & Apply Button
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: 8
                                    color: saveHov.containsMouse ? Theme.accentLit : Theme.accent

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Save & Fetch Weather"
                                        font.family: "Plus Jakarta Sans"
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: Theme.accentContrast
                                    }

                                    MouseArea {
                                        id: saveHov
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            weatherPoller.command = [
                                                "python3", paneWeather.weatherScriptPath, "update",
                                                "--api-key", keyInput.text.trim(),
                                                "--city", cityInput.text.trim(),
                                                "--unit", paneWeather.unit
                                            ]
                                            weatherPoller.running = false
                                            weatherPoller.running = true
                                            paneWeather.showConfig = false
                                        }
                                    }
                                }
                            }
                        }

                        // Status message / Notice if any
                        Text {
                            Layout.fillWidth: true
                            text: paneWeather.statusMsg
                            font.family: "Plus Jakarta Sans"
                            font.pixelSize: 10
                            color: Theme.accentLit
                            visible: paneWeather.statusMsg.length > 0
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
