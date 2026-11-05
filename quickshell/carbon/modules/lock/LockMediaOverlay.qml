import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../Singletons"

/**
 * LockMediaOverlay:
 * Minimalist, animated media card displayed in the bottom-left corner of the lock screen.
 * Displays only:
 *   - Album / cover art
 *   - Track name
 *   - Artist name
 *   - Sleek progress bar with elapsed & total time
 * Strictly NO pause, play, or skip buttons.
 */
Item {
    id: root

    implicitWidth: 350
    implicitHeight: 86

    /* ── MPRIS Player Resolution ─────────────────────────────────────────── */
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
                && (root.players[i].trackTitle || "") !== "")
                return root.players[i]
        }
        return root.players[0] || null
    }

    function syncPlayer() {
        root.activePlayer = root.resolveActivePlayer()
    }

    onPlayersChanged: root.syncPlayer()

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.syncPlayer()
    }

    /* ── Metadata & Track Properties ─────────────────────────────────────── */
    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: root.trackTitle.trim().length > 0

    /* Track Duration & Position */
    readonly property real totalLength: {
        if (!activePlayer) return 0
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

    /* Position poller to keep progress bar updating smoothly while playing */
    Timer {
        id: posPoller
        interval: 300
        running: root.isPlaying && root.hasTrack
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.activePlayer && root.activePlayer.positionSupported) {
                root.activePlayer.positionChanged()
            }
        }
    }

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec <= 0) return "0:00"
        const m = Math.floor(sec / 60)
        const s = Math.floor(sec % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    /* ── Read Lock Screen Configuration ───────────────────────────────────── */
    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/hypr/carbon-lockscreen.json"
    property bool enabledSetting: true

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
                if (parsed.mediaOverlay !== undefined) {
                    root.enabledSetting = Boolean(parsed.mediaOverlay)
                } else if (parsed.showMedia !== undefined) {
                    root.enabledSetting = Boolean(parsed.showMedia)
                }
            }
        } catch (e) {}
    }

    Component.onCompleted: root.reloadConfig()

    function easeOutCubic(p) {
        var x = Math.max(0.0, Math.min(1.0, p))
        return 1.0 - Math.pow(1.0 - x, 3.0)
    }

    // Enter motion: at t = 680ms, slides up 26px and fades in over 480ms
    readonly property real mediaEnterProgress: {
        if (LockTransition.reducedMotion) return 1.0
        if (LockTransition.phase === "locked") return 1.0
        if (LockTransition.phase === "locking") {
            if (LockTransition.t < 680.0) return 0.0
            return Math.min(1.0, (LockTransition.t - 680.0) / 480.0)
        }
        if (LockTransition.phase === "unlocking") return 1.0
        return 0.0
    }
    readonly property real mediaEnterEased: root.easeOutCubic(mediaEnterProgress)

    // Exit motion: at u >= 520ms, fades out over 450ms
    readonly property real mediaExitProgress: {
        if (LockTransition.phase === "unlocking") {
            if (LockTransition.u < 520.0) return 1.0
            return Math.max(0.0, 1.0 - (LockTransition.u - 520.0) / 450.0)
        }
        if (LockTransition.phase === "post_unlock") return 0.0
        return 1.0
    }

    // Progress bar fills in over 550ms starting at t = 720ms
    readonly property real progressBarFillFactor: {
        if (LockTransition.reducedMotion) return 1.0
        if (LockTransition.phase === "locked") return 1.0
        if (LockTransition.phase === "locking") {
            if (LockTransition.t < 720.0) return 0.0
            return Math.min(1.0, (LockTransition.t - 720.0) / 550.0)
        }
        if (LockTransition.phase === "unlocking") return 1.0
        return 0.0
    }
    readonly property real progressBarFillEased: root.easeOutCubic(progressBarFillFactor)

    /* ── Smooth Animated Visibility ──────────────────────────────────────── */
    property bool stageDriven: false
    property bool entered: stageDriven
    property bool showing: entered && enabledSetting

    visible: opacity > 0.01
    opacity: (root.showing ? 1.0 : 0.0) * root.mediaEnterEased * root.mediaExitProgress
    transform: Translate {
        id: transOffset
        y: root.stageDriven ? (26.0 * (1.0 - root.mediaEnterEased)) : (root.showing ? 0 : 36)
        x: root.stageDriven ? 0 : (root.showing ? 0 : -16)

        Behavior on y {
            enabled: !root.stageDriven
            NumberAnimation {
                duration: 650
                easing.type: Easing.OutCubic
            }
        }
        Behavior on x {
            enabled: !root.stageDriven
            NumberAnimation {
                duration: 650
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on opacity {
        enabled: !root.stageDriven
        NumberAnimation {
            duration: 520
            easing.type: Easing.OutQuad
        }
    }

    Timer {
        id: introDelay
        interval: 180
        running: !root.stageDriven
        onTriggered: root.entered = true
    }

    /* ── Frosted Glass Background Card (Anchored at bottom, height 86) ──── */
    Rectangle {
        id: cardBg
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 86
        radius: 20
        color: "#24111319"
        border.color: "#28FFFFFF"
        border.width: 1

        // Inner glowing ambient accent tint
        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.04)
        }
    }

    /* ── Moon Doodle (top-right inside card) ─────────────────────────────── */
    Image {
        id: moonDoodle
        anchors.top: cardBg.top
        anchors.right: cardBg.right
        anchors.topMargin: 7
        anchors.rightMargin: 10
        width: 38
        height: 38
        source: Theme.isDark
            ? "doodles/doodle_moon_white.png"
            : "doodles/doodle_moon_black.png"
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: root.showing ? 0.72 : 0.0
        visible: root.showing
        Behavior on opacity { NumberAnimation { duration: 350 } }

        // Gentle slow float
        SequentialAnimation on y {
            running: root.showing
            loops: Animation.Infinite
            NumberAnimation { to: -3; duration: 2200; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0;  duration: 2200; easing.type: Easing.InOutSine }
        }
    }



    /* ── Content Layout ─────────────────────────────────────────────────── */
    RowLayout {
        anchors.left: cardBg.left
        anchors.right: cardBg.right
        anchors.top: cardBg.top
        anchors.bottom: cardBg.bottom
        anchors.margins: 11
        spacing: 13

        /* Album Artwork with Masked Rounded Corners */
        Item {
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                id: artBg
                anchors.fill: parent
                radius: 14
                color: "#181B22"
                border.color: "#25FFFFFF"
                border.width: 1

                // Fallback Music Glyph if no cover or idle
                Text {
                    anchors.centerIn: parent
                    text: "music_note"
                    font.family: Theme.fontIcon
                    font.pixelSize: 24
                    color: root.hasTrack ? "#66FFFFFF" : "#44FFFFFF"
                    visible: !root.hasTrack || artImg.status !== Image.Ready
                }
            }

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

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: root.artUrl
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: root.hasTrack && root.artUrl !== "" && status === Image.Ready

                    Behavior on opacity {
                        NumberAnimation { duration: 300 }
                    }
                }
            }

            // Subtle outer border ring
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: "transparent"
                border.color: "#33FFFFFF"
                border.width: 1
            }
        }

        /* Track Info & Sleek Progress Bar (No Skip / Pause) */
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 4

            // Track Title
            Text {
                Layout.fillWidth: true
                text: root.hasTrack ? root.trackTitle : "Nothing Playing"
                font.family: Theme.font
                font.pixelSize: Theme.fontPx(14)
                font.weight: Font.DemiBold
                color: root.hasTrack ? "#F4F6FB" : "#94A3B8"
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            // Artist Name
            Text {
                Layout.fillWidth: true
                text: root.hasTrack ? root.trackArtist : "No media active"
                font.family: Theme.font
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.Normal
                color: root.hasTrack ? "#9CA3AF" : "#5A6578"
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Item { Layout.preferredHeight: 2 }

            // Sleek Progress Bar
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 5

                // Background Track
                Rectangle {
                    anchors.fill: parent
                    radius: 2.5
                    color: "#28FFFFFF"
                }

                // Progress Fill with Smooth Glide
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    radius: 2.5
                    width: root.hasTrack ? Math.max(0, Math.min(parent.width, parent.width * root.progress * root.progressBarFillEased)) : 0
                    color: Theme.accent

                    Behavior on width {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.Linear
                        }
                    }

                    // Round Doodle Thumb Knob (matching reference)
                    Rectangle {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: -4
                        width: 10
                        height: 10
                        radius: 5
                        color: "#FFFFFF"
                        border.width: 1.8
                        border.color: Theme.accent
                        visible: root.hasTrack && root.progress > 0.01 && root.progress < 0.99
                    }
                }
            }

            // Time Labels (Elapsed & Total Duration)
            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: root.hasTrack ? root.formatTime(root.currentPosition) : "0:00"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(9)
                    color: "#8E9AA8"
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: (root.hasTrack && root.totalLength > 0) ? root.formatTime(root.totalLength) : "--:--"
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(9)
                    color: "#8E9AA8"
                }
            }
        }
    }
}
