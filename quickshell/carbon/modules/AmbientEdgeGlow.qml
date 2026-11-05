import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../Singletons"

/**
 * AmbientEdgeGlow: Audio-reactive ambient glow along screen bezel.
 * - Width dynamically expands and contracts with audio/bass beats.
 * - Maximum expansion is strictly capped to only touch the inner ends of the left and right bars.
 * - Vertical length/height remains static (44px) to avoid jerky vertical stretching.
 * - Automatically hibernates when no music is playing for 0.0% CPU overhead.
 */
Item {
    id: root

    property string position: "top" // "top" | "bottom"

    // 1. Static constant vertical length/height — no vertical jumping
    implicitHeight: 44
    height: implicitHeight

    // 2. Dynamic horizontal width: expands and contracts between center and the ends of the left & right bars
    readonly property real minGlowWidth: 420
    readonly property real maxGlowWidth: Math.max(minGlowWidth, (parent ? parent.width : 1920) - 520)

    width: minGlowWidth + ((maxGlowWidth - minGlowWidth) * Math.min(1.0, (root.smoothBass * 0.75 + root.smoothOverall * 0.25)))

    anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined
    anchors.top: position === "top" ? (parent ? parent.top : undefined) : undefined
    anchors.bottom: position === "bottom" ? (parent ? parent.bottom : undefined) : undefined

    Behavior on width {
        NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
    }

    /* ── MPRIS State ─────────────────────────────────────────────────── */
    readonly property var players: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    property bool isPlaying: false

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.players || root.players.length === 0) {
                root.isPlaying = false
                return
            }
            let playing = false
            for (let i = 0; i < root.players.length; i++) {
                if (root.players[i].playbackState === MprisPlaybackState.Playing) {
                    playing = true
                    break
                }
            }
            root.isPlaying = playing
        }
    }

    /* ── Audio Frequency Levels (0.0 to 1.0) ──────────────────────────── */
    property real rawBass: 0.0
    property real rawMid: 0.0
    property real rawHigh: 0.0

    property real smoothBass: rawBass
    property real smoothMid: rawMid
    property real smoothHigh: rawHigh
    property real smoothOverall: (smoothBass * 0.5) + (smoothMid * 0.3) + (smoothHigh * 0.2)

    Behavior on smoothBass { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
    Behavior on smoothMid  { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }
    Behavior on smoothHigh { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

    /* ── Cava Process & Config ────────────────────────────────────────── */
    readonly property string cavaConfigPath: (Quickshell.env("HOME") || "") + "/.config/hypr/cava-edge-glow.conf"

    Process {
        id: cavaProcess
        command: ["cava", "-p", root.cavaConfigPath]
        running: root.isPlaying
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const parts = line.trim().split(";")
                if (parts.length >= 6) {
                    const b0 = parseInt(parts[0], 10) || 0
                    const b1 = parseInt(parts[1], 10) || 0
                    const b2 = parseInt(parts[2], 10) || 0
                    const b3 = parseInt(parts[3], 10) || 0
                    const b4 = parseInt(parts[4], 10) || 0
                    const b5 = parseInt(parts[5], 10) || 0

                    root.rawBass = Math.max(0, Math.min(1.0, (b0 + b1) / 180.0))
                    root.rawMid = Math.max(0, Math.min(1.0, (b2 + b3) / 180.0))
                    root.rawHigh = Math.max(0, Math.min(1.0, (b4 + b5) / 180.0))
                }
            }
        }
    }

    // Smooth falloff when audio is paused or stopped
    Timer {
        interval: 120
        repeat: true
        running: !root.isPlaying && (root.rawBass > 0.01 || root.smoothOverall > 0.01)
        onTriggered: {
            root.rawBass = Math.max(0, root.rawBass * 0.8)
            root.rawMid = Math.max(0, root.rawMid * 0.8)
            root.rawHigh = Math.max(0, root.rawHigh * 0.8)
        }
    }

    /* ── Visual Edge Glow Rendering ───────────────────────────────────── */
    opacity: root.isPlaying ? Math.max(0.18, Math.min(0.92, 0.25 + (root.smoothOverall * 0.65))) : 0.0
    visible: opacity > 0.005

    Behavior on opacity {
        NumberAnimation { duration: 350; easing.type: Easing.OutQuad }
    }

    // 1. Broad Ambient Aurora Glow (Horizontal feathering + vertical fade)
    Rectangle {
        anchors.fill: parent

        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: root.position === "top" ? 0.0 : 1.0
                color: Qt.alpha(Theme.accent, 0.28 + (root.smoothBass * 0.45))
            }
            GradientStop {
                position: root.position === "top" ? 0.45 : 0.55
                color: Qt.alpha(Theme.secondary || Theme.accent, 0.12 + (root.smoothMid * 0.28))
            }
            GradientStop {
                position: root.position === "top" ? 1.0 : 0.0
                color: "transparent"
            }
        }
    }

    // 2. Soft Horizon Falloff (Feathers the left and right ends smoothly)
    Rectangle {
        anchors.fill: parent
        opacity: 0.45 + (root.smoothOverall * 0.55)

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.12; color: Qt.alpha(Theme.accent, 0.15) }
            GradientStop { position: 0.50; color: Qt.alpha(Theme.accent, 0.55) }
            GradientStop { position: 0.88; color: Qt.alpha(Theme.accent, 0.15) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // 3. Razor-thin Bezel Core Line (Matches expanding/contracting width)
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: root.position === "top" ? parent.top : undefined
        anchors.bottom: root.position === "bottom" ? parent.bottom : undefined
        height: 1.5

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.15; color: Qt.alpha(Theme.accent, 0.50) }
            GradientStop { position: 0.50; color: Qt.alpha(Theme.accent, 0.90 + (root.smoothHigh * 0.10)) }
            GradientStop { position: 0.85; color: Qt.alpha(Theme.accent, 0.50) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
