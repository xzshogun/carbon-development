import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../Singletons"

/**
 * ControlRing:
 * Minimalist monochrome radial volume & brightness control centered around the Nucleus.
 * 
 * - 270° circular arc from 135° (bottom-left) to 45° (bottom-right) at radius 76px.
 * - Liquid Halo harmonic 3-layer fluid effect behind arc with continuous, unpausing flow.
 * - Borderless 420x420 canvas so fluid layers are never clipped or boxed.
 * - Auto-closes smoothly when user is done increasing or decreasing.
 * - Matugen warm-shifted color pipeline with saturation fallback.
 * - Zero timers and zero CPU usage when closed (0% CPU at rest).
 */
Item {
    id: root

    // Configuration / Modes
    property string kind: "volume"        // "volume" | "brightness"
    property string ringMode: "closed"    // "closed" | "active"
    readonly property bool isOpen: ringMode !== "closed"

    // Large canvas footprint to guarantee fluid layers are completely borderless and unclipped
    implicitWidth: 420
    implicitHeight: 420

    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real arcRadius: 76

    // Smooth unroll / roll-up animation
    property real openProgress: 0.0
    Behavior on openProgress {
        NumberAnimation {
            duration: 340
            easing.type: Easing.OutCubic
        }
    }

    onIsOpenChanged: {
        openProgress = isOpen ? 1.0 : 0.0
        if (isOpen) {
            speedFactor = 0.5
            resetOsdTimer()
        } else {
            osdHideTimer.stop()
            isDragging = false
        }
    }

    /* ── 1. Audio & Backlight Backends ────────────────────────────────── */
    // PipeWire Audio
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property real rawVolume: (audioSink && audioSink.audio) ? audioSink.audio.volume : 0.5
    readonly property bool isMuted: (audioSink && audioSink.audio) ? audioSink.audio.muted : false
    readonly property string sinkName: (audioSink && audioSink.description) ? audioSink.description : "Default Audio"

    // Brightness state
    property real brightnessLevel: 0.45
    property string backlightDevice: "intel_backlight"
    property bool hasBacklight: true

    // Target normalized level (0.0 to 1.0)
    readonly property real currentLevel: (kind === "volume")
        ? (isMuted ? 0.0 : Math.max(0.0, Math.min(1.0, rawVolume)))
        : Math.max(0.01, Math.min(1.0, brightnessLevel))

    // Display level with smooth mute drain or gentle easing
    property real displayLevel: currentLevel
    onCurrentLevelChanged: {
        trailAdd(displayAngleRad)
        speedFactor = 0.6
        if (isOpen && !isDragging) {
            resetOsdTimer()
        }
    }

    Behavior on displayLevel {
        NumberAnimation {
            duration: root.isMuted ? 260 : 120
            easing.type: Easing.OutCubic
        }
    }

    // Ping animations at 0% and 100%
    property real pingProgress: 0.0
    property real pingAngle: 0.0
    property bool pingActive: false

    NumberAnimation {
        id: pingAnim
        target: root
        property: "pingProgress"
        from: 0.0
        to: 1.0
        duration: 650
        easing.type: Easing.OutCubic
        onFinished: root.pingActive = false
    }

    function triggerPing(angleDeg) {
        pingAngle = angleDeg
        pingActive = true
        pingAnim.restart()
    }

    // Hardware Setters
    function setLevel(val, notify) {
        val = Math.max(0.0, Math.min(1.0, val))
        if (kind === "volume") {
            if (audioSink && audioSink.audio) {
                if (audioSink.audio.muted && val > 0.001) {
                    audioSink.audio.muted = false
                }
                audioSink.audio.volume = val
            }
        } else {
            val = Math.max(0.01, val)
            brightnessLevel = val
            setBrightnessProcess(val)
        }

        if (val <= 0.001) triggerPing(135)
        else if (val >= 0.999) triggerPing(45)
    }

    function stepLevel(delta) {
        if (kind === "volume") {
            var nv = Math.max(0.0, Math.min(1.0, rawVolume + delta))
            setLevel(nv, true)
        } else {
            var nb = Math.max(0.01, Math.min(1.0, brightnessLevel + delta))
            setLevel(nb, true)
        }
    }

    function toggleMute() {
        if (kind === "volume" && audioSink && audioSink.audio) {
            audioSink.audio.muted = !audioSink.audio.muted
            if (!audioSink.audio.muted && audioSink.audio.volume <= 0.01) {
                audioSink.audio.volume = 0.25
            }
            resetOsdTimer()
        }
    }

    function setBrightnessProcess(val) {
        var pct = Math.max(1, Math.min(100, Math.round(val * 100)))
        Quickshell.execDetached(["brightnessctl", "set", pct + "%", "-q"])
    }

    // Brightness hardware poller & udev monitor
    Process {
        id: brightWatcher
        command: [
            "sh", "-c",
            "brightnessctl -m 2>/dev/null | head -n1; " +
            "exec udevadm monitor --subsystem-match=backlight --udev 2>/dev/null | while read -r line; do " +
            "  case \"$line\" in *change*) brightnessctl -m 2>/dev/null | head -n1;; esac; " +
            "done"
        ]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split(",")
                if (parts.length >= 4) {
                    root.hasBacklight = true
                    root.backlightDevice = parts[0]
                    var pStr = parts[3].replace("%", "").trim()
                    var pVal = parseInt(pStr, 10)
                    if (!isNaN(pVal)) {
                        root.brightnessLevel = Math.max(0.01, Math.min(1.0, pVal / 100.0))
                    }
                }
            }
        }
    }

    /* ── 2. Unified Auto-Close Timer ──────────────────────────────────── */
    Timer {
        id: osdHideTimer
        interval: 1800
        repeat: false
        onTriggered: {
            root.closeRing()
        }
    }

    function resetOsdTimer() {
        if (root.isOpen && !root.isDragging) {
            osdHideTimer.restart()
        }
    }

    function openControl(k) {
        kind = k
        ringMode = "active"
        resetOsdTimer()
    }

    function openSticky(k) {
        openControl(k)
    }

    function openOsd(k) {
        openControl(k)
    }

    function closeRing() {
        ringMode = "closed"
    }

    /* ── 3. Matugen & Color Pipeline ──────────────────────────────────── */
    function getSaturation(c) {
        var r = c.r, g = c.g, b = c.b
        var max = Math.max(r, Math.max(g, b))
        var min = Math.min(r, Math.min(g, b))
        var delta = max - min
        var l = (max + min) / 2.0
        if (l <= 0.0 || l >= 1.0 || delta === 0) return 0.0
        return delta / (1.0 - Math.abs(2.0 * l - 1.0))
    }

    function getWarmShift(c, targetLightness) {
        if (targetLightness < 0.6) return Qt.rgba(232/255, 120/255, 70/255, 1.0)
        if (targetLightness < 0.8) return Qt.rgba(239/255, 159/255, 39/255, 1.0)
        return Qt.rgba(255/255, 236/255, 190/255, 1.0)
    }

    readonly property color colVolumeLayer0: {
        if (getSaturation(Theme.m3primary) < 0.25) return Qt.rgba(93/255, 202/255, 165/255, 1.0)
        return Theme.m3primary
    }
    readonly property color colVolumeLayer1: {
        if (getSaturation(Theme.m3primary) < 0.25) return Qt.rgba(133/255, 183/255, 235/255, 1.0)
        return Theme.m3secondary
    }
    readonly property color colVolumeLayer2: {
        if (getSaturation(Theme.m3primary) < 0.25) return Qt.rgba(175/255, 169/255, 236/255, 1.0)
        return Theme.m3tertiary
    }

    readonly property color colBrightLayer0: {
        if (getSaturation(Theme.m3primary) < 0.25) return Qt.rgba(232/255, 120/255, 70/255, 1.0)
        return getWarmShift(Theme.m3primary, 0.55)
    }
    readonly property color colBrightLayer1: {
        if (getSaturation(Theme.m3primary) < 0.25) return Qt.rgba(239/255, 159/255, 39/255, 1.0)
        return getWarmShift(Theme.m3primary, 0.70)
    }
    readonly property color colBrightLayer2: {
        if (getSaturation(Theme.m3primary) < 0.25) return Qt.rgba(255/255, 236/255, 190/255, 1.0)
        return getWarmShift(Theme.m3primary, 0.90)
    }

    readonly property color brightnessMidColor: colBrightLayer1

    readonly property color arcFillColor: (kind === "volume")
        ? Qt.rgba(1.0, 1.0, 1.0, isMuted ? 0.30 : 0.95)
        : Qt.rgba(brightnessMidColor.r, brightnessMidColor.g, brightnessMidColor.b, 0.95)

    /* ── 4. Liquid Halo Behind Arc (Continuous, Never Pauses/Restarts) ─── */
    property real speedFactor: 0.0
    property real lagG0: 0.0
    property real lagG1: 0.0
    property real lagG2: 0.0

    property real phase0_1: 0.0
    property real phase0_2: 0.0
    property real phase1_1: 0.0
    property real phase1_2: 0.0
    property real phase2_1: 0.0
    property real phase2_2: 0.0

    FrameAnimation {
        id: frameAnim
        running: (root.isOpen || root.openProgress > 0.005) && root.visible
        onTriggered: {
            var targetL = root.displayLevel
            var dtSec = (frameTime && frameTime > 0.0) ? Math.min(0.05, Math.max(0.005, frameTime)) : 0.016
            var lerpRate = Math.min(1.0, dtSec * 14.0)
            root.lagG0 += (targetL - root.lagG0) * lerpRate
            root.lagG1 += (targetL - root.lagG1) * (lerpRate * 0.65)
            root.lagG2 += (targetL - root.lagG2) * (lerpRate * 0.32)

            // Soft decay of speed factor
            root.speedFactor += (0.0 - root.speedFactor) * (dtSec * 3.0)

            // Continuous calm phase drift: never wraps, never jerks
            var drift = (1.0 + 0.38 * root.speedFactor) * dtSec

            root.phase0_1 += drift
            root.phase0_2 -= drift * 0.72
            root.phase1_1 -= drift * 1.15
            root.phase1_2 += drift * 0.84
            root.phase2_1 += drift * 1.28
            root.phase2_2 -= drift * 0.91

            trailPrune()

            haloCanvas.requestPaint()
            arcCanvas.requestPaint()
        }
    }

    // Liquid Halo Canvas (Full & Borderless, 420x420 bounds)
    Canvas {
        id: haloCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded
        opacity: root.openProgress
        visible: opacity > 0.001

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (root.openProgress < 0.01) return

            var cx = root.cx
            var cy = root.cy
            var isVol = (root.kind === "volume")
            var lvl = root.displayLevel
            var spd = root.speedFactor
            var twoPi = 2.0 * Math.PI
            var numSamples = 120

            // Inner warm disc for brightness
            if (!isVol && root.brightnessLevel > 0.01) {
                ctx.save()
                ctx.beginPath()
                ctx.arc(cx, cy, 68 * (0.4 + 0.6 * root.openProgress), 0, twoPi)
                ctx.fillStyle = Qt.rgba(root.colBrightLayer1.r, root.colBrightLayer1.g, root.colBrightLayer1.b, 0.07 * root.brightnessLevel * root.openProgress)
                ctx.fill()
                ctx.restore()
            }

            var layers = [
                {
                    g: root.lagG0, m1: 2, m2: 3, p1: root.phase0_1, p2: root.phase0_2,
                    col: isVol ? root.colVolumeLayer0 : root.colBrightLayer0, idx: 0
                },
                {
                    g: root.lagG1, m1: 3, m2: 5, p1: root.phase1_1, p2: root.phase1_2,
                    col: isVol ? root.colVolumeLayer1 : root.colBrightLayer1, idx: 1
                },
                {
                    g: root.lagG2, m1: 4, m2: 2, p1: root.phase2_1, p2: root.phase2_2,
                    col: isVol ? root.colVolumeLayer2 : root.colBrightLayer2, idx: 2
                }
            ]

            for (var li = 0; li < layers.length; li++) {
                var l = layers[li]
                var i = l.idx
                var r0 = isVol
                    ? (76 + 12 + l.g * 50 + 1.5 * i)
                    : (76 + 10 + l.g * 40 + 1.5 * i)
                var A = isVol
                    ? ((3 + 8 * spd + 3 * lvl) * (1 + 0.25 * i))
                    : ((2 + 8 * root.brightnessLevel + 8 * spd + 3 * lvl) * (1 + 0.25 * i))

                // Smooth radius scale during unroll
                r0 = (30 + (r0 - 30) * root.openProgress)

                var alpha = isVol ? 0.20 : (0.10 + 0.18 * root.brightnessLevel)
                alpha = alpha * root.openProgress

                ctx.save()
                ctx.beginPath()
                for (var s = 0; s <= numSamples; s++) {
                    var theta = (s / numSamples) * twoPi
                    var r = r0 + A * (0.6 * Math.sin(l.m1 * theta + l.p1) + 0.4 * Math.sin(l.m2 * theta + l.p2 + i))
                    var px = cx + r * Math.cos(theta)
                    var py = cy + r * Math.sin(theta)
                    if (s === 0) ctx.moveTo(px, py)
                    else ctx.lineTo(px, py)
                }
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(l.col.r, l.col.g, l.col.b, alpha)
                ctx.fill()
                ctx.restore()
            }
        }
    }

    /* ── 5. Knob Comet Trail ──────────────────────────────────────────── */
    property var trailPoints: []

    function trailAdd(angleRad) {
        var now = Date.now()
        trailPoints.push({ angle: angleRad, time: now })
    }

    function trailPrune() {
        var now = Date.now()
        var updated = []
        for (var i = 0; i < trailPoints.length; i++) {
            if (now - trailPoints[i].time < 260) {
                updated.push(trailPoints[i])
            }
        }
        trailPoints = updated
    }

    /* ── 6. Arc, Ticks, Knob, Trail & Pings Canvas ─────────────────────── */
    readonly property real displayAngleDeg: 135 + displayLevel * 270
    readonly property real displayAngleRad: displayAngleDeg * Math.PI / 180

    Canvas {
        id: arcCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded
        opacity: root.openProgress
        visible: opacity > 0.001

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (root.openProgress < 0.01) return

            var cx = root.cx
            var cy = root.cy
            var rad = 30 + (root.arcRadius - 30) * root.openProgress
            var trackWidth = 6

            var startAngleRad = 135 * Math.PI / 180
            var maxSweepDeg = 270 * root.openProgress
            var endAngleRad = (135 + maxSweepDeg) * Math.PI / 180

            // 1. Track Arc (white @ 0.18 alpha, 6px round caps)
            ctx.save()
            ctx.beginPath()
            ctx.arc(cx, cy, rad, startAngleRad, (135 + 270) * Math.PI / 180, false)
            ctx.lineWidth = trackWidth
            ctx.lineCap = "round"
            ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, 0.18 * root.openProgress)
            ctx.stroke()
            ctx.restore()

            // 2. 5 Tick Marks (at 0%, 25%, 50%, 75%, 100%)
            var tickPcts = [0.0, 0.25, 0.50, 0.75, 1.0]
            for (var ti = 0; ti < 5; ti++) {
                var tp = tickPcts[ti]
                var tAngleDeg = 135 + tp * 270
                var tAngleRad = tAngleDeg * Math.PI / 180

                var tPop = Math.max(0.0, Math.min(1.0, root.openProgress * 1.3 - 0.18 * ti))
                if (tPop <= 0.01) continue

                var isPassed = (root.displayLevel >= tp)
                var tLen = (isPassed ? 7.0 : 4.0) * tPop
                var tAlpha = (isPassed ? 0.90 : 0.25) * tPop

                var rInner = rad + 10
                var rOuter = rad + 10 + tLen

                var x1 = cx + rInner * Math.cos(tAngleRad)
                var y1 = cy + rInner * Math.sin(tAngleRad)
                var x2 = cx + rOuter * Math.cos(tAngleRad)
                var y2 = cy + rOuter * Math.sin(tAngleRad)

                ctx.save()
                ctx.beginPath()
                ctx.moveTo(x1, y1)
                ctx.lineTo(x2, y2)
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, tAlpha)
                ctx.stroke()
                ctx.restore()
            }

            // 3. Fill Arc
            var currentFillSweepDeg = 270 * root.displayLevel * root.openProgress
            var fillEndAngleRad = (135 + currentFillSweepDeg) * Math.PI / 180

            if (currentFillSweepDeg > 0.5) {
                ctx.save()
                ctx.beginPath()
                ctx.arc(cx, cy, rad, startAngleRad, fillEndAngleRad, false)
                ctx.lineWidth = trackWidth
                ctx.lineCap = "round"
                ctx.strokeStyle = root.arcFillColor
                ctx.stroke()
                ctx.restore()
            }

            // 4. Knob Comet Trail (over 260ms)
            var now = Date.now()
            for (var tri = 0; tri < root.trailPoints.length; tri++) {
                var pt = root.trailPoints[tri]
                var age = now - pt.time
                if (age >= 260) continue
                var trFrac = 1.0 - (age / 260.0)
                var trR = 3.0 + (7.0 - 3.0) * trFrac
                var trAlpha = 0.40 * trFrac * root.openProgress

                var trX = cx + rad * Math.cos(pt.angle)
                var trY = cy + rad * Math.sin(pt.angle)

                ctx.save()
                ctx.beginPath()
                ctx.arc(trX, trY, trR / 2, 0, 2 * Math.PI)
                ctx.fillStyle = Qt.rgba(root.arcFillColor.r, root.arcFillColor.g, root.arcFillColor.b, trAlpha)
                ctx.fill()
                ctx.restore()
            }

            // 5. Knob
            var knobAngleRad = fillEndAngleRad
            var kx = cx + rad * Math.cos(knobAngleRad)
            var ky = cy + rad * Math.sin(knobAngleRad)

            // Dragging Halo (15px halo @ alpha 0.2)
            if (root.isDragging) {
                ctx.save()
                ctx.beginPath()
                ctx.arc(kx, ky, 7.5, 0, 2 * Math.PI)
                ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, 0.20)
                ctx.fill()
                ctx.restore()
            }

            // Knob disc or hollow ring
            ctx.save()
            ctx.beginPath()
            if (root.isMuted && root.kind === "volume") {
                ctx.arc(kx, ky, 4.0, 0, 2 * Math.PI)
                ctx.lineWidth = 1.8
                ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, 0.85 * root.openProgress)
                ctx.stroke()
            } else {
                ctx.arc(kx, ky, 4.5, 0, 2 * Math.PI)
                ctx.fillStyle = root.arcFillColor
                ctx.fill()
            }
            ctx.restore()

            // 6. End Pings
            if (root.pingActive && root.pingProgress < 1.0) {
                var pAngleRad = root.pingAngle * Math.PI / 180
                var px = cx + rad * Math.cos(pAngleRad)
                var py = cy + rad * Math.sin(pAngleRad)
                var pRad = 4.5 + 20.0 * root.pingProgress
                var pAlpha = 0.70 * (1.0 - root.pingProgress)

                ctx.save()
                ctx.beginPath()
                ctx.arc(px, py, pRad, 0, 2 * Math.PI)
                ctx.lineWidth = 1.5
                ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, pAlpha)
                ctx.stroke()
                ctx.restore()
            }
        }
    }

    /* ── 7. End Icons (45° below horizontal at radius +24 = 100px) ───── */
    readonly property real startIconRad: (135 * Math.PI / 180)
    readonly property real startIconX: cx + (arcRadius + 24) * Math.cos(startIconRad)
    readonly property real startIconY: cy + (arcRadius + 24) * Math.sin(startIconRad)

    Text {
        x: root.startIconX - width / 2
        y: root.startIconY - height / 2
        visible: root.openProgress > 0.05
        opacity: 0.70 * root.openProgress
        text: (root.kind === "volume") ? "volume_mute" : "light_mode"
        font.family: Theme.fontIcon
        font.pixelSize: 13
        color: "#FFFFFF"
    }

    readonly property real endIconRad: (45 * Math.PI / 180)
    readonly property real endIconX: cx + (arcRadius + 24) * Math.cos(endIconRad)
    readonly property real endIconY: cy + (arcRadius + 24) * Math.sin(endIconRad)

    Text {
        x: root.endIconX - width / 2
        y: root.endIconY - height / 2
        visible: root.openProgress > 0.05
        opacity: 0.70 * root.openProgress
        text: (root.kind === "volume") ? "volume_up" : "wb_sunny"
        font.family: Theme.fontIcon
        font.pixelSize: 13
        color: "#FFFFFF"
    }

    /* ── 8. Center Readout & Bottom Gap Caption ───────────────────────── */
    readonly property string centerReadoutText: {
        if (root.kind === "volume" && root.isMuted) return "mute"
        return Math.round(root.currentLevel * 100) + "%"
    }

    readonly property string captionLine1: {
        var base = (root.kind === "volume") ? "volume" : "brightness"
        if (root.kind === "volume" && root.isMuted) base += " · muted"
        return base
    }

    readonly property string captionLine2: {
        if (root.kind === "volume") return root.sinkName
        return root.backlightDevice
    }

    Item {
        id: bottomGapCaption
        x: root.cx - width / 2
        y: root.cy + root.arcRadius + 14
        width: 160
        height: 28
        visible: root.openProgress > 0.1
        opacity: root.openProgress

        Column {
            anchors.centerIn: parent
            spacing: 1

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.captionLine1
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(11)
                font.bold: true
                color: "#FFFFFF"
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.captionLine2
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: Theme.fontPx(9)
                color: Qt.rgba(1.0, 1.0, 1.0, 0.60)
                elide: Text.ElideMiddle
                width: 150
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    /* ── 9. Mouse Hit Band & Dragging Interaction ─────────────────────── */
    property bool isDragging: false

    MouseArea {
        id: hitBand
        anchors.fill: parent
        enabled: root.isOpen && root.openProgress > 0.5
        hoverEnabled: true

        function handlePointer(mouseX, mouseY) {
            var dx = mouseX - root.cx
            var dy = mouseY - root.cy
            var dist = Math.sqrt(dx * dx + dy * dy)

            if (dist < 46 || dist > 112) return

            var angleRad = Math.atan2(dy, dx)
            var angleDeg = (angleRad * 180 / Math.PI + 360) % 360

            var sweep = (angleDeg - 135 + 360) % 360
            var val = 0.0

            if (sweep <= 270) {
                val = sweep / 270.0
            } else {
                if (sweep <= 315) {
                    val = 1.0
                } else {
                    val = 0.0
                }
            }

            root.setLevel(val, true)
            root.resetOsdTimer()
        }

        onPressed: mouse => {
            var dx = mouse.x - root.cx
            var dy = mouse.y - root.cy
            var dist = Math.sqrt(dx * dx + dy * dy)
            if (dist >= 46 && dist <= 112) {
                root.isDragging = true
                osdHideTimer.stop()
                handlePointer(mouse.x, mouse.y)
            }
        }

        onPositionChanged: mouse => {
            if (root.isDragging) {
                handlePointer(mouse.x, mouse.y)
            }
        }

        onReleased: {
            if (root.isDragging) {
                root.isDragging = false
                root.resetOsdTimer()
            }
        }

        onCanceled: {
            root.isDragging = false
            root.resetOsdTimer()
        }
    }
}
