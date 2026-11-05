import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Singletons"
import "../components"

/**
 * BarCenter: Top center bar component for Pill mode (and reusable across shell bars).
 *   - Bold dual-tone or stacked clock (CenterClock)
 *   - Vertical subtle separator (|)
 *   - Animated spinning vinyl disc / album art
 *   - 4-bar dynamic equalizer waveform
 *   - Two-line track title & artist (color sensitive)
 *   - Left-click toggles CenterDashboard, hover opens preview, right-click toggles play/pause
 */
Item {
    id: root

    property bool showBackground: false
    property string barContent: "both" // "both", "clock", "music"

    signal openCenterDashboard()
    signal closeCenterDashboard()
    signal toggleCenterDashboard()
    signal toggleMusic()
    signal openMusic()
    signal toggleControls()

    readonly property bool hudActive: HudService.active
    property bool showVinylDisc: true
    property bool showEqualizer: true
    implicitHeight: 34
    implicitWidth: (hudActive ? dynamicPill.implicitWidth : rowLayout.implicitWidth) + (showBackground ? 20 : 0)

    Behavior on implicitWidth {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }

    /* ── Live Clock State ────────────────────────────────────────────── */
    property var currentTime: new Date()
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

    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: root.activePlayer !== null && root.trackTitle.trim().length > 0

    function togglePlayPause() {
        if (root.activePlayer) root.activePlayer.togglePlaying()
    }

    /* Optional background capsule */
    Rectangle {
        id: bgCapsule
        anchors.fill: parent
        radius: height / 2
        color: Theme.bg
        border.color: "transparent"
        border.width: 0
        visible: root.showBackground
    }

    MouseArea {
        id: mainMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
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
    }

    /* ── HUD Mode: Dynamic Island Pill ───────────────────────────────── */
    DynamicIslandPill {
        id: dynamicPill
        anchors.centerIn: parent
        opacity: root.hudActive ? 1.0 : 0.0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 220; easing.type: Easing.OutQuad }
        }
    }

    /* ── Normal Mode: Clock & Music Row ──────────────────────────────── */
    Row {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 8
        opacity: root.hudActive ? 0.0 : 1.0
        visible: opacity > 0.01

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
        }

        /* 1. Center Clock */
        Item {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: centerClockItem.implicitWidth
            implicitHeight: centerClockItem.implicitHeight
            visible: root.barContent !== "music"

            CenterClock {
                id: centerClockItem
                anchors.centerIn: parent
            }
        }

        /* 2. Vertical Divider */
        Rectangle {
            width: 1.5
            height: 16
            color: Qt.alpha(Theme.fg, 0.40)
            anchors.verticalCenter: parent.verticalCenter
            visible: root.barContent === "both"
        }

        /* 3. Music Section (Disc + EQ + Info) */
        Row {
            id: musicRow
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: root.barContent !== "clock"

            /* Spinning Vinyl Disc / Album art */
            Rectangle {
                id: discContainer
                width: 22
                height: 22
                radius: 11
                color: Theme.bgAlt
                border.color: Theme.accent
                border.width: 1.5
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                visible: root.showVinylDisc

                Image {
                    id: albumArtImg
                    anchors.fill: parent
                    source: root.artUrl
                    sourceSize: Qt.size(44, 44)
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
                        font.pixelSize: 14
                        color: Theme.accent
                    }
                }
            }

            /* Dynamic Island 4-Bar Equalizer Waveform */
            Row {
                id: eqWaveform
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showEqualizer && root.hasTrack

                Repeater {
                    model: [
                        { minH: 3, maxH: 13, dur: 380 },
                        { minH: 4, maxH: 15, dur: 520 },
                        { minH: 3, maxH: 11, dur: 440 },
                        { minH: 4, maxH: 14, dur: 610 }
                    ]

                    delegate: Rectangle {
                        id: eqBar
                        required property var modelData
                        required property int index

                        width: 2.5
                        radius: 1.25
                        color: Theme.accent
                        anchors.verticalCenter: parent.verticalCenter

                        height: root.isPlaying ? modelData.minH : 2.5

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

            /* Song & Artist Info */
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                Text {
                    text: root.hasTrack ? root.trackTitle : "Nothing Playing"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(10)
                    font.weight: Font.Bold
                    color: root.hasTrack ? Theme.fg : Theme.fgDim
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 140)
                }

                Text {
                    text: root.hasTrack ? root.trackArtist : ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: Theme.fontPx(8)
                    font.weight: Font.Medium
                    color: Theme.fgDim
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 140)
                    visible: text.length > 0
                }
            }
        }
    }
}
