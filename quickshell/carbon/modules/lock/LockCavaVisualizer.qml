import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"

/**
 * LockCavaVisualizer:
 * Full-width continuous audio-reactive wavy visualizer attached to the top edge of the lock screen.
 * Spans completely from left to right edge with smooth bezier wave crests and neon glowing fill.
 * Configurable via ~/.config/hypr/carbon-lockscreen.json (enabled/disabled).
 */
Item {
    id: root

    property bool active: true
    readonly property int barsCount: 48
    readonly property real maxWaveHeight: 58

    property var rawTargetValues: []
    property var smoothedValues: []
    property bool enabledSetting: true

    implicitWidth: 1366
    implicitHeight: 70

    /* ── Read Lock Screen Configuration ───────────────────────────────────── */
    readonly property string configPath: (Quickshell.env("HOME") || "") + "/.config/hypr/carbon-lockscreen.json"

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
                if (parsed.visualizer !== undefined) {
                    root.enabledSetting = parsed.visualizer
                }
            }
        } catch (e) {
            console.log("Failed to parse lockscreen config:", e)
        }
    }

    Component.onCompleted: {
        var initial = []
        for (var i = 0; i < root.barsCount; i++) {
            initial.push(0)
        }
        root.rawTargetValues = initial.slice()
        root.smoothedValues = initial.slice()
        root.reloadConfig()
    }

    /* ── Cava Subprocess Pipeline ────────────────────────────────────────── */
    Process {
        id: cavaProc
        command: ["cava", "-p", (Quickshell.env("HOME") || "") + "/.config/hypr/cava-lock.conf"]
        running: root.enabledSetting && root.active && root.visible
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var parts = line.trim().split(";")
                if (parts.length >= root.barsCount) {
                    var vals = []
                    for (var i = 0; i < root.barsCount; i++) {
                        vals.push(parseInt(parts[i]) || 0)
                    }
                    root.rawTargetValues = vals
                }
            }
        }
    }

    /* ── Smooth Waveform Lerp & Decay Animation ──────────────────────────── */
    FrameAnimation {
        id: smoothAnim
        running: root.showing && root.active && root.visible
        onTriggered: {
            var targets = root.rawTargetValues
            var cur = root.smoothedValues
            if (!targets || !cur || targets.length < root.barsCount || cur.length < root.barsCount) return

            var dt = (frameTime && frameTime > 0.0) ? Math.min(0.05, Math.max(0.005, frameTime)) : 0.016
            var attackRate = Math.min(1.0, dt * 15.0)
            var decayRate = Math.min(1.0, dt * 5.5)

            var changed = false
            for (var i = 0; i < root.barsCount; i++) {
                var t = targets[i] || 0
                var c = cur[i] || 0
                var diff = t - c
                if (Math.abs(diff) > 0.15) {
                    if (diff > 0) {
                        cur[i] = c + diff * attackRate
                    } else {
                        cur[i] = c + diff * decayRate
                    }
                    changed = true
                } else if (c !== t) {
                    cur[i] = t
                    changed = true
                }
            }
            if (changed) {
                waveCanvas.requestPaint()
            }
        }
    }

    /* ── Smooth Animated Visibility & Entrance ───────────────────────────── */
    property bool stageDriven: false
    property bool entered: stageDriven
    property bool showing: (root.entered && root.enabledSetting)

    visible: opacity > 0.01
    opacity: showing ? 1.0 : 0.0
    transform: Translate {
        id: transOffset
        y: root.stageDriven ? 0 : (root.showing ? 0 : -root.height)

        Behavior on y {
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

    /* ── Continuous Wavy Canvas ─────────────────────────────────────────── */
    Canvas {
        id: waveCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width
            var h = height
            if (w <= 0 || h <= 0) return

            var vals = root.smoothedValues
            if (!vals || vals.length < 2) return

            var n = vals.length
            var points = []

            // Construct spline points spanning full width from x=0 to x=w
            for (var i = 0; i < n; i++) {
                var x = (i / (n - 1)) * w
                // Edge window envelope to smoothly ground ends at the bezels
                var env = Math.min(1.0, Math.sin((i / (n - 1)) * Math.PI) * 1.85)
                var amp = ((vals[i] || 0) / 100.0) * root.maxWaveHeight * env
                var y = Math.max(0, Math.min(h - 2, amp))
                points.push({ x: x, y: y })
            }

            var accent = Theme.accent ? Theme.accent : Qt.rgba(0, 0.94, 1, 1)

            // 1. Translucent Gradient Wave Fill
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(points[0].x, points[0].y)
            for (var i = 0; i < points.length - 1; i++) {
                var xc = (points[i].x + points[i + 1].x) / 2
                var yc = (points[i].y + points[i + 1].y) / 2
                ctx.quadraticCurveTo(points[i].x, points[i].y, xc, yc)
            }
            ctx.quadraticCurveTo(
                points[points.length - 1].x,
                points[points.length - 1].y,
                points[points.length - 1].x,
                points[points.length - 1].y
            )
            ctx.lineTo(w, 0)
            ctx.closePath()

            var fillGrad = ctx.createLinearGradient(0, 0, 0, root.maxWaveHeight + 8)
            fillGrad.addColorStop(0.0, Qt.rgba(accent.r, accent.g, accent.b, 0.35))
            fillGrad.addColorStop(0.55, Qt.rgba(accent.r, accent.g, accent.b, 0.14))
            fillGrad.addColorStop(1.0, Qt.rgba(accent.r, accent.g, accent.b, 0.00))
            ctx.fillStyle = fillGrad
            ctx.fill()

            // 2. Bright Glowing Neon Crest Stroke
            ctx.beginPath()
            ctx.moveTo(points[0].x, points[0].y)
            for (var i = 0; i < points.length - 1; i++) {
                var xc = (points[i].x + points[i + 1].x) / 2
                var yc = (points[i].y + points[i + 1].y) / 2
                ctx.quadraticCurveTo(points[i].x, points[i].y, xc, yc)
            }
            ctx.quadraticCurveTo(
                points[points.length - 1].x,
                points[points.length - 1].y,
                points[points.length - 1].x,
                points[points.length - 1].y
            )
            ctx.strokeStyle = accent
            ctx.lineWidth = 2.2
            ctx.stroke()

            // 3. Specular Bright Core Highlight Line
            ctx.beginPath()
            ctx.moveTo(points[0].x, points[0].y)
            for (var i = 0; i < points.length - 1; i++) {
                var xc = (points[i].x + points[i + 1].x) / 2
                var yc = (points[i].y + points[i + 1].y) / 2
                ctx.quadraticCurveTo(points[i].x, points[i].y, xc, yc)
            }
            ctx.quadraticCurveTo(
                points[points.length - 1].x,
                points[points.length - 1].y,
                points[points.length - 1].x,
                points[points.length - 1].y
            )
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.65)
            ctx.lineWidth = 0.8
            ctx.stroke()

            // 4. Subtle Top Edge Boundary Line
            ctx.beginPath()
            ctx.moveTo(0, 0.5)
            ctx.lineTo(w, 0.5)
            var topGrad = ctx.createLinearGradient(0, 0, w, 0)
            topGrad.addColorStop(0.0, Qt.rgba(accent.r, accent.g, accent.b, 0.0))
            topGrad.addColorStop(0.2, Qt.rgba(accent.r, accent.g, accent.b, 0.55))
            topGrad.addColorStop(0.8, Qt.rgba(accent.r, accent.g, accent.b, 0.55))
            topGrad.addColorStop(1.0, Qt.rgba(accent.r, accent.g, accent.b, 0.0))
            ctx.strokeStyle = topGrad
            ctx.lineWidth = 1.0
            ctx.stroke()
        }
    }
}

