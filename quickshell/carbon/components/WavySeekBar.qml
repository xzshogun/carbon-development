import QtQuick
import QtQuick.Layouts
import Quickshell
import "../Singletons"

/**
 * WavySeekBar: Modern OneUI / Android 13/14 style seek bar featuring:
 *  - Animated organic fluid ripples with multiple waves (natural wavelength).
 *  - Rich theme-sensitive fill with seamless progress bar integration (no harsh stroke borders).
 *  - Thicker hardware-accelerated progress track (pill-shaped).
 *  - Interactive drag-to-seek and click-to-seek with smooth feedback.
 *  - Dynamic theme-sensitive colors adapting to Theme.accent / Theme.accentLit.
 */
Item {
    id: root

    property real currentPosition: LyricsService.currentPosition
    property real totalLength: LyricsService.totalLength
    property bool isPlaying: LyricsService.isPlaying
    property color accentColor: Theme.accent
    property color accentLitColor: Theme.accentLit
    property bool showTimeLabels: true
    property int timeLabelSize: 8
    property real barHeight: 8
    property real waveHeight: 16
    property bool isDragging: false
    property real dragProgress: 0.0

    readonly property real progress: totalLength > 0 ? Math.max(0, Math.min(1.0, currentPosition / totalLength)) : 0.0
    readonly property real displayProgress: isDragging ? dragProgress : progress

    signal seekRequested(real fraction)

    implicitWidth: 200
    implicitHeight: waveHeight + barHeight + (showTimeLabels ? 16 : 0) + 4

    // Smooth transition between playing amplitude and resting amplitude
    property real playEnergy: root.isPlaying ? 1.0 : 0.22
    Behavior on playEnergy {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    onPlayEnergyChanged: waveCanvas.requestPaint()
    onDisplayProgressChanged: waveCanvas.requestPaint()
    onAccentColorChanged: waveCanvas.requestPaint()
    onAccentLitColorChanged: waveCanvas.requestPaint()

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "00:00"
        let s = Math.floor(sec)
        let m = Math.floor(s / 60)
        let rem = s % 60
        return (m < 10 ? "0" : "") + m + ":" + (rem < 10 ? "0" : "") + rem
    }

    /* ── 1. Animated Organic Wave Visualizer (Rich Filled, Seamless) ─── */
    Canvas {
        id: waveCanvas
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.waveHeight + 2

        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        opacity: (root.isPlaying || root.isDragging) ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        readonly property bool isWindowVisible: Window.window ? (Window.window.visible && Window.window.opacity > 0.01) : true
        readonly property bool shouldAnimate: (root.isPlaying || root.isDragging) && root.visible && isWindowVisible && width > 0 && height > 0

        onPaint: {
            var ctx = waveCanvas.getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (width <= 4 || height <= 4) return

            var w = width
            var baseY = height
            var energy = root.playEnergy
            if (energy <= 0.03) return

            var now = waveCanvas.wavePhase
            var step = 3

            /* Background softer wave (layered fluid depth) */
            var maxAmpBg = (root.waveHeight - 2) * energy * 0.65
            ctx.beginPath()
            ctx.moveTo(0, baseY)
            for (var x = 0; x <= w; x += step) {
                var normX = x / w
                var envBg = Math.pow(Math.max(0, Math.sin(Math.PI * normX)), 0.62)
                // 3 to 4 ripples across width
                var phaseBg1 = normX * Math.PI * 6.0 + now * 1.15
                var phaseBg2 = normX * Math.PI * 3.8 - now * 0.75
                var hWaveBg = Math.sin(phaseBg1) * 0.58 + Math.cos(phaseBg2) * 0.42
                var yBg = baseY - (envBg * maxAmpBg * Math.max(0.04, 0.5 + 0.5 * hWaveBg))
                ctx.lineTo(x, yBg)
            }
            ctx.lineTo(w, baseY)
            ctx.closePath()

            var gradBg = ctx.createLinearGradient(0, baseY - maxAmpBg, 0, baseY)
            gradBg.addColorStop(0, Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.55 * energy + 0.05))
            gradBg.addColorStop(1, Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.42 * energy + 0.05))
            ctx.fillStyle = gradBg
            ctx.fill()

            /* Foreground primary wave (rich, filled, natural multi-ripples) */
            var maxAmpFg = (root.waveHeight - 1) * energy * 0.95
            var pts = []
            for (var px = 0; px <= w; px += step) {
                var nx = px / w
                // Bell envelope tapering cleanly at track boundaries
                var envFg = Math.pow(Math.max(0, Math.sin(Math.PI * nx)), 0.65)
                // Shorter wavelength -> multiple natural fluid ripples
                var p1 = nx * Math.PI * 6.8 + now * 1.45
                var p2 = nx * Math.PI * 4.2 - now * 0.85
                var p3 = nx * Math.PI * 10.5 + now * 2.1
                var hFg = Math.sin(p1) * 0.52 + Math.cos(p2) * 0.36 + Math.sin(p3) * 0.12
                var yFg = baseY - (envFg * maxAmpFg * Math.max(0.06, 0.5 + 0.5 * hFg))
                pts.push({ x: px, y: yFg })
            }

            // Fill body under wave seamlessly connecting down to progress baseline
            ctx.beginPath()
            ctx.moveTo(0, baseY)
            for (var i = 0; i < pts.length; i++) {
                ctx.lineTo(pts[i].x, pts[i].y)
            }
            ctx.lineTo(w, baseY)
            ctx.closePath()

            // Rich theme-sensitive fill gradient (no harsh border outline)
            var gradFg = ctx.createLinearGradient(0, baseY - maxAmpFg, 0, baseY)
            gradFg.addColorStop(0, Qt.rgba(root.accentLitColor.r, root.accentLitColor.g, root.accentLitColor.b, 0.72 * energy + 0.08))
            gradFg.addColorStop(1, Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.88 * energy + 0.10))
            ctx.fillStyle = gradFg
            ctx.fill()
        }

        property real wavePhase: 0.0
        FrameAnimation {
            running: waveCanvas.shouldAnimate
            onTriggered: {
                waveCanvas.wavePhase += frameTime * 3.33
                waveCanvas.requestPaint()
            }
        }
    }

    /* ── 2. Thicker Horizontal Progress Baseline Track ───────────────── */
    Item {
        id: trackContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: waveCanvas.bottom
        anchors.topMargin: -1 // Seamless 1px connection with wave canvas
        height: root.barHeight

        // Background unfilled bar (thick rounded pill)
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.16)
        }

        // Filled progress track (thick rounded pill, theme sensitive)
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, Math.min(parent.width, parent.width * root.displayProgress))
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: root.accentColor }
                GradientStop { position: 1.0; color: root.accentLitColor }
            }
        }

        // Scrubber Knob (tactile, glows on hover/scrub)
        Rectangle {
            id: knob
            width: (root.isDragging || scrubArea.containsMouse) ? (root.barHeight + 6) : (root.barHeight + 3)
            height: width
            radius: width / 2
            x: Math.max(0, Math.min(trackContainer.width - width, trackContainer.width * root.displayProgress - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            color: "#ffffff"

            Behavior on width { NumberAnimation { duration: 120 } }

            // Outer soft glow
            Rectangle {
                anchors.centerIn: parent
                width: parent.width + 6
                height: width
                radius: width / 2
                color: Qt.rgba(root.accentLitColor.r, root.accentLitColor.g, root.accentLitColor.b, 0.35)
                z: -1
            }
        }
    }

    /* ── Interactive Mouse Scrubbing Area ────────────────────────────── */
    MouseArea {
        id: scrubArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: trackContainer.bottom
        anchors.bottomMargin: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function updateFraction(mx) {
            var frac = Math.max(0.0, Math.min(1.0, mx / width))
            root.dragProgress = frac
            root.isDragging = true
        }

        onPressed: (mouse) => updateFraction(mouse.x)
        onPositionChanged: (mouse) => {
            if (pressed) updateFraction(mouse.x)
        }
        onReleased: (mouse) => {
            var frac = Math.max(0.0, Math.min(1.0, mouse.x / width))
            root.dragProgress = frac
            root.isDragging = false
            root.seekRequested(frac)
            if (LyricsService.seekFraction) {
                LyricsService.seekFraction(frac)
            } else if (LyricsService.totalLength > 0) {
                var targetSec = frac * LyricsService.totalLength
                try {
                    if (LyricsService.activePlayer) LyricsService.activePlayer.position = targetSec
                } catch(e) {}
                Quickshell.execDetached(["playerctl", "position", String(Math.floor(targetSec))])
                if (LyricsService.activePlayer && LyricsService.activePlayer.positionSupported) {
                    LyricsService.activePlayer.positionChanged()
                }
            }
        }
    }

    /* ── 3. Live Time Labels Row (Under Progress Bar) ─────────────────── */
    RowLayout {
        visible: root.showTimeLabels
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: trackContainer.bottom
        anchors.topMargin: 5

        Text {
            text: root.formatTime(root.isDragging ? (root.dragProgress * root.totalLength) : root.currentPosition)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: root.timeLabelSize
            font.weight: Font.Medium
            color: root.isDragging ? root.accentLitColor : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70)
        }

        Item { Layout.fillWidth: true }

        Text {
            text: root.formatTime(root.totalLength)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: root.timeLabelSize
            font.weight: Font.Medium
            color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.50)
        }
    }
}
