import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../Singletons"
import "../components"

/**
 * SmallMusicOverlay: Modern OneUI / Android 13/14 styled floating media overlay.
 * Features:
 *  - Output device badge / Spotify header
 *  - Album art background blur + rounded album thumbnail
 *  - Track title & artist typography
 *  - Animated wavy visualizer & interactive progress scrubber
 *  - 5-button transport controls (Shuffle, Prev, Play/Pause, Next, Loop)
 */
Item {
    id: root

    implicitWidth: 340
    implicitHeight: 180
    width: 340
    height: 180
    clip: true

    signal closeRequested()

    readonly property var activePlayer: LyricsService.activePlayer
    readonly property bool isPlaying: LyricsService.isPlaying
    readonly property bool hasTrack: LyricsService.hasTrack
    readonly property real currentPosition: LyricsService.currentPosition
    readonly property real totalLength: LyricsService.totalLength

    property bool open: true
    property bool attachedBottom: false
    property bool animatingOut: false
    onOpenChanged: {
        if (!open) {
            animatingOut = true
            animatingOutTimer.restart()
        } else {
            animatingOut = false
            animatingOutTimer.stop()
        }
    }
    Timer {
        id: animatingOutTimer
        interval: 200
        onTriggered: root.animatingOut = false
    }

    readonly property string deviceName: {
        if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.description && Pipewire.defaultAudioSink.description.length > 0) {
            return Pipewire.defaultAudioSink.description
        }
        if (activePlayer && activePlayer.identity && activePlayer.identity.length > 0) {
            return activePlayer.identity
        }
        return "Audio Output"
    }

    readonly property bool isSpotify: activePlayer && activePlayer.identity && activePlayer.identity.toLowerCase().includes("spotify")

    Item {
        id: bgCard
        width: parent.width
        height: parent.height

        /* Swallow clicks on the popup card background so they don't dismiss the window */
        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {}
        }

        Shape {
            id: cardBgShape
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            preferredRendererType: Shape.CurveRenderer

            // 1. Fill background (Seamlessly attached: square top, rounded bottom)
            ShapePath {
                fillColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, Theme.shellOpacity)
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 0; startY: 0
                PathLine { x: bgCard.width; y: 0 }
                PathLine { x: bgCard.width; y: bgCard.height - 20 }
                PathArc { x: bgCard.width - 20; y: bgCard.height; radiusX: 20; radiusY: 20 }
                PathLine { x: 20; y: bgCard.height }
                PathArc { x: 0; y: bgCard.height - 20; radiusX: 20; radiusY: 20 }
                PathLine { x: 0; y: 0 }
            }

            // 2. Continuous stroke (Right, Bottom, Left - NO stroke on top edge to blend seamlessly into the bar)
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : Theme.outline
                strokeWidth: 1
                startX: bgCard.width; startY: 0
                PathLine { x: bgCard.width; y: bgCard.height - 20 }
                PathArc { x: bgCard.width - 20; y: bgCard.height; radiusX: 20; radiusY: 20 }
                PathLine { x: 20; y: bgCard.height }
                PathArc { x: 0; y: bgCard.height - 20; radiusX: 20; radiusY: 20 }
                PathLine { x: 0; y: 0 }
            }
        }

        opacity: root.open ? 1.0 : 0.0
        y: root.open ? 0 : (!root.attachedBottom ? -height : height)

        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? 180 : 140
                easing.bezierCurve: Theme.animCurves.expressiveDefaultEffects
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.open ? 240 : 160
                easing.bezierCurve: root.open ? Theme.animCurves.expressiveDefaultSpatial : Theme.animCurves.standardAccel
            }
        }

        /* ── Subtle blurred/dimmed album art ambient background ───────── */
        Image {
            anchors.fill: parent
            source: LyricsService.artUrl
            sourceSize: Qt.size(280, 200)
            fillMode: Image.PreserveAspectCrop
            opacity: 0.14
            visible: status === Image.Ready && source != ""
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 6

            /* ── 1. Top Header Row: Device / App Badge + Close Button ── */
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // App / Device Icon
                    Text {
                        text: "music_note"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: Theme.accentLit
                    }

                    // Device Name (e.g. boAt Rockerz 400 / Galaxy Buds2 Pro)
                    Text {
                        Layout.fillWidth: true
                        text: root.deviceName
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.DemiBold
                        color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.78)
                        elide: Text.ElideRight
                    }
                }

                // Close Button
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    radius: 10
                    color: closeArea.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.28) : Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: closeArea.containsMouse ? "#ff5555" : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            /* ── 2. Middle Row: Track Title & Artist + Album Art Thumbnail ── */
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.hasTrack ? LyricsService.trackTitle : "No Media Playing"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: Font.Bold
                        color: Theme.fg
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.hasTrack ? (LyricsService.trackArtist || "Unknown Artist") : "Waiting for playback..."
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(10)
                        font.weight: Font.Normal
                        color: Theme.accent
                        elide: Text.ElideRight
                    }
                }

                // Album Art Thumbnail
                Rectangle {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    radius: 9
                    color: Qt.rgba(0.12, 0.14, 0.18, 0.9)
                    border.color: Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.35)
                    border.width: 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: LyricsService.artUrl
                        sourceSize: Qt.size(84, 84)
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready && source != ""
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "music_note"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: root.isPlaying ? Theme.accentLit : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                        visible: !LyricsService.artUrl || LyricsService.artUrl === ""
                    }
                }
            }

            /* ── 3. Animated Wavy Visualizer & Interactive Progress Bar ─ */
            WavySeekBar {
                Layout.fillWidth: true
                waveHeight: 16
                barHeight: 8
                timeLabelSize: 8
                accentColor: Theme.accent
                accentLitColor: Theme.accentLit
            }

            /* ── 4. Transport Controls Row (Shuffle, Prev, Play/Pause, Next, Loop) ── */
            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter

                Item { Layout.fillWidth: true }

                // Shuffle
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: shufArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "shuffle"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: shufArea.containsMouse ? Theme.accentLit : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                    }

                    MouseArea {
                        id: shufArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["playerctl", "shuffle", "Toggle"])
                    }
                }

                Item { Layout.preferredWidth: 8 }

                // Previous
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "skip_previous"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: prevArea.containsMouse ? Theme.accentLit : Theme.fg
                    }

                    MouseArea {
                        id: prevArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.skipPrevious()
                    }
                }

                Item { Layout.preferredWidth: 8 }

                // Play / Pause (Accent filled circle)
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34
                    radius: 17
                    color: playArea.containsMouse ? Theme.accentLit : Theme.accent
                    border.color: Theme.accentLit
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root.isPlaying ? "pause" : "play_arrow"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: Theme.isDark ? "#121118" : "#ffffff"
                    }

                    MouseArea {
                        id: playArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.togglePlaying()
                    }
                }

                Item { Layout.preferredWidth: 8 }

                // Next
                Rectangle {
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    radius: 14
                    color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "skip_next"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: nextArea.containsMouse ? Theme.accentLit : Theme.fg
                    }

                    MouseArea {
                        id: nextArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: LyricsService.skipNext()
                    }
                }

                Item { Layout.preferredWidth: 8 }

                // Loop / Repeat
                Rectangle {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    radius: 13
                    color: loopArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "repeat"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: loopArea.containsMouse ? Theme.accentLit : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                    }

                    MouseArea {
                        id: loopArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached(["playerctl", "loop", "Track"])
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
