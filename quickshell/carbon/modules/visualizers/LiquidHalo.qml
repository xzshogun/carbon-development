import QtQuick

/**
 * LiquidHalo:
 * Siri-style three-layer audio-reactive liquid rings centered on the nucleus.
 *
 * - 3 layered, translucent, closed liquid rings centered at (cx, cy)
 * - Layer 1 (bass): bands 0-5, m=(2,3), amp=16px, accent role 1 (teal)
 * - Layer 2 (mids): bands 6-20, m=(3,5), amp=13px, accent role 2 (blue)
 * - Layer 3 (treble): bands 21-47, m=(4,2), amp=11px, accent role 3 (purple)
 * - Fast attack (0.20), silky release (0.08), low-pass filter (0.10)
 * - Calms into completely motionless, perfect concentric circles when paused/idle
 * - Zero timers or animations run while idle (0% CPU at rest)
 */
Item {
    id: root

    /* ── Standard Common Visualizer Interface ── */
    property var bands: []
    property bool playing: false
    property color colorAccent1: "#00F0FF"
    property color colorAccent2: "#3B82F6"
    property color colorAccent3: "#A855F7"
    property bool reducedMotion: false

    implicitWidth: 140
    implicitHeight: 140

    /* ── Internal Filter States ── */
    property real stage1Bass: 0.0
    property real drawBass: 0.0
    property real stage1Mids: 0.0
    property real drawMids: 0.0
    property real stage1Treble: 0.0
    property real drawTreble: 0.0

    /* ── Harmonic Phase States (rad) ── */
    property real phase1_1: 0.0
    property real phase1_2: 0.0
    property real phase2_1: 0.0
    property real phase2_2: 0.0
    property real phase3_1: 0.0
    property real phase3_2: 0.0

    /* ── Animation Controller (Endless continuous loop, 0 pause/restart) ── */
    property real speedFactor: 0.18
    property bool isAnimating: true
    property real lastFrameMs: 0.0

    onPlayingChanged: {
        isAnimating = true
    }

    FrameAnimation {
        id: frameAnim
        running: root.isAnimating && root.visible
        onTriggered: root.updateFrame(frameTime)
    }

    function updateFrame(dtSec) {
        var dt = (dtSec && dtSec > 0.0) ? Math.min(32.0, Math.max(8.0, dtSec * 1000.0)) : 16.0

        /* 1. Extract Raw Energies from 48 Cava Bands */
        var rawBass = 0.0
        var rawMids = 0.0
        var rawTreble = 0.0

        if (root.playing && root.bands && root.bands.length >= 48) {
            // Bass: bands 0-5 with transient peak weighting (boosted sensitivity)
            var bSum = 0.0, bPeak = 0.0
            for (var b = 0; b <= 5; b++) {
                var bv = root.bands[b] || 0.0
                bSum += bv
                if (bv > bPeak) bPeak = bv
            }
            rawBass = Math.min(1.0, (bSum / 6.0) * 1.50 + bPeak * 0.35)

            // Mids: bands 6-20 with transient peak weighting
            var mSum = 0.0, mPeak = 0.0
            for (var m = 6; m <= 20; m++) {
                var mv = root.bands[m] || 0.0
                mSum += mv
                if (mv > mPeak) mPeak = mv
            }
            rawMids = Math.min(1.0, (mSum / 15.0) * 1.60 + mPeak * 0.35)

            // Treble: bands 21-47 with transient peak weighting
            var tSum = 0.0, tPeak = 0.0
            for (var t = 21; t <= 47; t++) {
                var tv = root.bands[t] || 0.0
                tSum += tv
                if (tv > tPeak) tPeak = tv
            }
            rawTreble = Math.min(1.0, (tSum / 27.0) * 1.70 + tPeak * 0.35)
        }

        /* 2. Smoothing: Sensitive Attack (0.32), Natural Release (0.10), Low-Pass (0.22) */
        // Bass
        if (rawBass > root.stage1Bass) {
            root.stage1Bass += (rawBass - root.stage1Bass) * 0.32
        } else {
            root.stage1Bass += (rawBass - root.stage1Bass) * 0.10
        }
        root.drawBass += (root.stage1Bass - root.drawBass) * 0.22

        // Mids
        if (rawMids > root.stage1Mids) {
            root.stage1Mids += (rawMids - root.stage1Mids) * 0.32
        } else {
            root.stage1Mids += (rawMids - root.stage1Mids) * 0.10
        }
        root.drawMids += (root.stage1Mids - root.drawMids) * 0.22

        // Treble
        if (rawTreble > root.stage1Treble) {
            root.stage1Treble += (rawTreble - root.stage1Treble) * 0.32
        } else {
            root.stage1Treble += (rawTreble - root.stage1Treble) * 0.10
        }
        root.drawTreble += (root.stage1Treble - root.drawTreble) * 0.22

        /* 3. Speed Factor Easing (continuous seamless loop, relaxes to gentle idle baseline 0.18) */
        const targetSpeed = (root.playing && !root.reducedMotion) ? 1.0 : (root.reducedMotion ? 0.0 : 0.18)
        root.speedFactor += (targetSpeed - root.speedFactor) * (root.playing ? 0.10 : 0.04)

        /* 4. Phase Drift (continuous monotonic advance, never wraps, never snaps) */
        if (!root.reducedMotion && root.speedFactor > 0.0001) {
            // Layer 1 (bass, m=2, 3)
            root.phase1_1 += root.speedFactor * 0.70 * (1.0 + root.drawBass) * (dt / 1000.0)
            root.phase1_2 -= root.speedFactor * 0.50 * (1.0 + root.drawBass) * (dt / 1000.0)

            // Layer 2 (mids, m=3, 5)
            root.phase2_1 -= root.speedFactor * 0.80 * (1.0 + root.drawMids) * (dt / 1000.0)
            root.phase2_2 += root.speedFactor * 0.60 * (1.0 + root.drawMids) * (dt / 1000.0)

            // Layer 3 (treble, m=4, 2)
            root.phase3_1 += root.speedFactor * 0.90 * (1.0 + root.drawTreble) * (dt / 1000.0)
            root.phase3_2 -= root.speedFactor * 0.70 * (1.0 + root.drawTreble) * (dt / 1000.0)
        }

        /* 5. Continuous Loop: keep animating while visible */
        if (!root.visible) {
            root.isAnimating = false
        } else {
            root.isAnimating = true
        }

        haloCanvas.requestPaint()
    }

    Component.onCompleted: {
        haloCanvas.requestPaint()
    }

    /* ── Render Canvas ── */
    Canvas {
        id: haloCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Immediate

        onPaint: {
            var ctx = getContext("2d")
            ctx.save()
            ctx.clearRect(0, 0, width, height)

            var cx = width / 2.0
            var cy = height / 2.0
            var bassOffset = root.drawBass * 3.8

            // Helper to sample and draw a smooth closed ring (capped at r=48.8 to stay cleanly inside 54px outer ring)
            function drawClosedRing(baseRadius, amp, m1, m2, p1, p2, col) {
                var samples = 120
                var step = (2.0 * Math.PI) / samples

                ctx.beginPath()
                for (var i = 0; i <= samples; i++) {
                    var theta = i * step
                    var deformation = (amp > 0.0001)
                        ? amp * (0.6 * Math.sin(m1 * theta + p1) + 0.4 * Math.sin(m2 * theta + p2))
                        : 0.0
                    var r = Math.min(48.8, baseRadius + deformation)
                    var px = cx + r * Math.cos(theta)
                    var py = cy + r * Math.sin(theta)

                    if (i === 0) {
                        ctx.moveTo(px, py)
                    } else {
                        ctx.lineTo(px, py)
                    }
                }
                ctx.closePath()

                // Translucent liquid fill
                ctx.fillStyle = Qt.rgba(col.r, col.g, col.b, 0.22)
                ctx.fill()

                // Crisp contour stroke
                ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, 0.75)
                ctx.lineWidth = 1.3
                ctx.stroke()
            }

            // Layer 3 (treble): base 33 + bassOffset + 2.2px, harmonics 4 & 2
            drawClosedRing(
                33.0 + bassOffset + 2.2,
                1.8 + root.drawTreble * 9.5,
                4, 2,
                root.phase3_1, root.phase3_2,
                root.colorAccent3
            )

            // Layer 2 (mids): base 33 + bassOffset + 1.1px, harmonics 3 & 5
            drawClosedRing(
                33.0 + bassOffset + 1.1,
                2.0 + root.drawMids * 10.5,
                3, 5,
                root.phase2_1, root.phase2_2,
                root.colorAccent2
            )

            // Layer 1 (bass): base 33 + bassOffset + 0.0px, harmonics 2 & 3
            drawClosedRing(
                33.0 + bassOffset,
                2.5 + root.drawBass * 12.0,
                2, 3,
                root.phase1_1, root.phase1_2,
                root.colorAccent1
            )

            ctx.restore()
        }
    }
}
