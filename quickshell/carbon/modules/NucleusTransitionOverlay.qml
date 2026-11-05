import QtQuick
import Quickshell
import Quickshell.Io
import "../Singletons"

/**
 * NucleusTransitionOverlay:
 * Fullscreen cinematic mode-switch transition from bar mode to nucleus mode (~2.4s total).
 * 
 * Mathematical Timeline Architecture:
 * - 100–1000ms: Light streams (16 thin streams spiral into center, e=easeInCubic((t-100)/800), 12 segments, cycling colors)
 * - 300–1250ms: Accretion ring (tilted ellipse rx:64 ry:17 rot:-0.35rad, 3 strokes, orbiting dot angle=t*0.012)
 * - 250–1300ms: Black disc (r=18 near-black, thin white rim, grows 250–550ms, shrinks 1000–1300ms)
 * - 950–1500ms: Polar jets (vertical beams up/down to 140px, teal glow 12px->2px, white core 4px->1px)
 * - 1000ms: Impact (white flash 250ms, expanding 70px white disc, 190px teal ring, delayed purple ring)
 * - 1050–2350ms: Kinetic text ("Wooshh!!", heavy italic 46px, 82px above nucleus, 28ms stagger over 320ms,
 *                3 layers, 7 purple speed lines retracting, exit fade/drift/stretch at 1900ms) - primary screen only!
 * - 1200–1900ms: Atom grows in (easeOutCubic, central teal nucleus dot, 22px & 40px rings, 2 inner & 4 outer electrons)
 * - 2300ms+: Caption "nucleus mode" fades in, overlay destroyed/removed at ~2400ms for seamless handoff
 * 
 * Rules:
 * - Driven strictly from a single master time value `timeMs` (ms), fully scrubbable and replayable.
 * - Smooth easing only, no jitter or boxes of any kind.
 * - Colors dynamically bound to Theme accents (never hardcoded).
 * - Fullscreen layer-shell window per screen, destroyed when finished.
 * - Kinetic word on primary screen only.
 * - Respects Theme.reducedMotion (300ms simple crossfade).
 * - Zero timers or residual processes once completed.
 */
Item {
    id: root

    anchors.fill: parent

    /* ── Configuration & Properties ── */
    property bool isPrimaryScreen: false
    property string transitionWord: "Wooshh!!"
    property bool transitionEnabled: true
    property string transitionAnimation: "quantum"

    /* ── Single Master Time Driver (ms) ── */
    property real timeMs: 0.0

    /* ── Signals ── */
    signal transitionFinished()

    /* ── Theme Accent Colors ── */
    readonly property color colTeal: (Theme.palette && Theme.palette.teal)
        ? Theme.col(Theme.palette.teal, Theme.accent)
        : Theme.accent
    readonly property color colPurple: (Theme.palette && Theme.palette.tertiary)
        ? Theme.col(Theme.palette.tertiary, Theme.m3tertiary)
        : Theme.m3tertiary
    readonly property color colWhite: "#FFFFFF"
    readonly property color colBg: Theme.bg || "#0e0e14"
    readonly property bool reducedMotion: Boolean(Theme.reducedMotion)

    /* ── Mathematical Easing Functions ── */
    function clamp(v, minVal, maxVal) {
        return Math.max(minVal, Math.min(maxVal, v))
    }
    function easeInCubic(t) {
        return t * t * t
    }
    function easeOutCubic(t) {
        var inv = 1.0 - t
        return 1.0 - inv * inv * inv
    }
    function easeInQuad(t) {
        return t * t
    }
    function easeOutQuad(t) {
        return 1.0 - (1.0 - t) * (1.0 - t)
    }
    function easeOutExpo(t) {
        return (t >= 1.0) ? 1.0 : (1.0 - Math.pow(2.0, -10.0 * t))
    }

    /* ── Playback Controller ── */
    function play() {
        if (!root.transitionEnabled) {
            root.transitionFinished()
            return
        }
        root.timeMs = 0.0
        timeDriver.restart()
    }

    NumberAnimation {
        id: timeDriver
        target: root
        property: "timeMs"
        from: 0.0
        to: (root.reducedMotion || root.transitionAnimation === "crossfade") ? 300.0 : 2400.0
        duration: (root.reducedMotion || root.transitionAnimation === "crossfade") ? 300 : 2400
        easing.type: Easing.Linear
        running: false
        onFinished: {
            root.transitionFinished()
        }
    }

    onTimeMsChanged: {
        renderCanvas.requestPaint()
    }

    /* ── Fullscreen Hardware-Accelerated Canvas Engine ── */
    Canvas {
        id: renderCanvas
        anchors.fill: parent
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Threaded

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var w = root.width
            var h = root.height
            var cx = w / 2.0
            var cy = h / 2.0
            var t = root.timeMs

            // ── 0. Reduced Motion / Simple Crossfade Mode (300ms) ───────────
            if (root.reducedMotion || root.transitionAnimation === "crossfade") {
                var pCross = clamp(t / 300.0, 0.0, 1.0)
                var alphaCross = Math.sin(pCross * Math.PI) * 0.40
                ctx.fillStyle = Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, alphaCross)
                ctx.fillRect(0, 0, w, h)
                return
            }

            // ── Subtle Atmospheric Backdrop ───────────────────────────────
            // Smoothly darkens the screen slightly without hard edges or boxes
            var pBackdrop = 0.0
            if (t <= 300.0) {
                pBackdrop = easeOutCubic(t / 300.0)
            } else if (t >= 2100.0) {
                pBackdrop = 1.0 - easeOutCubic(clamp((t - 2100.0) / 300.0, 0.0, 1.0))
            } else {
                pBackdrop = 1.0
            }
            if (pBackdrop > 0.001) {
                ctx.fillStyle = Qt.rgba(root.colBg.r, root.colBg.g, root.colBg.b, 0.28 * pBackdrop)
                ctx.fillRect(0, 0, w, h)
            }

            // ── 1. Light Streams (100–1000ms) ──────────────────────────────
            // 16 thin streams spiral into screen center
            if (t >= 100.0 && t <= 1000.0) {
                var pStream = clamp((t - 100.0) / 800.0, 0.0, 1.0)
                var e = easeInCubic(pStream)
                var streamFade = (e > 0.85) ? (1.0 - (e - 0.85) / 0.15) : 1.0
                var overallAlpha = 0.75 * clamp(streamFade, 0.0, 1.0)

                ctx.lineCap = "round"
                ctx.lineWidth = 1.6

                for (var i = 0; i < 16; i++) {
                    var noise = (((i * 17 + 7) % 10) / 10.0 - 0.5)
                    var a_i = (i / 16.0) * (2.0 * Math.PI) + (noise * 0.4)
                    var r0 = 130.0 + ((i * 37) % 101)
                    var r_head = r0 * (1.0 - e)
                    var r_tail = r0 * (1.0 - Math.max(0.0, e - 0.35))

                    var col = (i % 3 === 0) ? root.colTeal : ((i % 3 === 1) ? root.colPurple : root.colWhite)

                    for (var s = 0; s < 12; s++) {
                        var frac1 = s / 12.0
                        var frac2 = (s + 1) / 12.0
                        var r1 = r_tail + (r_head - r_tail) * frac1
                        var r2 = r_tail + (r_head - r_tail) * frac2

                        var th1 = a_i + 3.2 * (1.0 - r1 / r0)
                        var th2 = a_i + 3.2 * (1.0 - r2 / r0)

                        var x1 = cx + r1 * Math.cos(th1)
                        var y1 = cy + r1 * Math.sin(th1)
                        var x2 = cx + r2 * Math.cos(th2)
                        var y2 = cy + r2 * Math.sin(th2)

                        var segAlpha = overallAlpha * frac2
                        if (segAlpha > 0.005) {
                            ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, segAlpha)
                            ctx.beginPath()
                            ctx.moveTo(x1, y1)
                            ctx.lineTo(x2, y2)
                            ctx.stroke()
                        }
                    }
                }
            }

            // ── 2. Accretion Ring (300–1250ms) ─────────────────────────────
            // Tilted ellipse (rx 64, ry 17, rotated -0.35rad) with 3 strokes and orbiting dot
            if (t >= 300.0 && t <= 1250.0) {
                var ringFadeIn = clamp((t - 300.0) / 500.0, 0.0, 1.0)
                var ringFadeOut = (t >= 1000.0) ? (1.0 - clamp((t - 1000.0) / 250.0, 0.0, 1.0)) : 1.0
                var ringFade = ringFadeIn * ringFadeOut

                if (ringFade > 0.005) {
                    ctx.save()
                    ctx.translate(cx, cy)
                    ctx.rotate(-0.35)

                    // Ellipse path (rx: 64, ry: 17)
                    ctx.beginPath()
                    for (var st = 0; st <= 64; st++) {
                        var phi = st * (2.0 * Math.PI / 64.0)
                        var ex = 64.0 * Math.cos(phi)
                        var ey = 17.0 * Math.sin(phi)
                        if (st === 0) ctx.moveTo(ex, ey)
                        else ctx.lineTo(ex, ey)
                    }
                    ctx.closePath()

                    // Stroke 1: 5px teal at 0.25 alpha
                    ctx.lineWidth = 5.0
                    ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.25 * ringFade)
                    ctx.stroke()

                    // Stroke 2: 3px purple at 0.50 alpha
                    ctx.lineWidth = 3.0
                    ctx.strokeStyle = Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.50 * ringFade)
                    ctx.stroke()

                    // Stroke 3: 1.5px white at 0.90 alpha
                    ctx.lineWidth = 1.5
                    ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, 0.90 * ringFade)
                    ctx.stroke()

                    // Orbiting bright dot (angle = t * 0.012)
                    var dotAng = t * 0.012
                    var odx = 64.0 * Math.cos(dotAng)
                    var ody = 17.0 * Math.sin(dotAng)

                    // Dot soft outer glow
                    ctx.beginPath()
                    ctx.arc(odx, ody, 6.0, 0, 2 * Math.PI)
                    ctx.fillStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.35 * ringFade)
                    ctx.fill()

                    // Dot bright core
                    ctx.beginPath()
                    ctx.arc(odx, ody, 2.5, 0, 2 * Math.PI)
                    ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, 0.95 * ringFade)
                    ctx.fill()

                    ctx.restore()
                }
            }

            // ── 3. Black Disc (250–1300ms) ─────────────────────────────────
            // Radius 18, near-black, thin white rim (alpha 0.6)
            if (t >= 250.0 && t <= 1300.0) {
                var discR = 18.0
                if (t < 550.0) {
                    var pGrow = clamp((t - 250.0) / 300.0, 0.0, 1.0)
                    discR = 18.0 * easeOutCubic(pGrow)
                } else if (t > 1000.0) {
                    var pShrink = clamp((t - 1000.0) / 300.0, 0.0, 1.0)
                    discR = 18.0 * (1.0 - easeInCubic(pShrink))
                }

                if (discR > 0.1) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, discR, 0, 2 * Math.PI)
                    ctx.fillStyle = Qt.rgba(0.04, 0.05, 0.07, 0.96)
                    ctx.fill()

                    ctx.lineWidth = 1.0
                    ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, 0.60 * clamp(discR / 18.0, 0.0, 1.0))
                    ctx.stroke()
                }
            }

            // ── 4. Polar Jets (950–1500ms) ─────────────────────────────────
            // Two vertical beams from center (up & down), length easeOut to 140px
            if (t >= 950.0 && t <= 1500.0) {
                var pJet = clamp((t - 950.0) / 550.0, 0.0, 1.0)
                var jetLen = 140.0 * easeOutCubic(pJet)
                var glowW = 12.0 - 10.0 * pJet
                var glowA = 0.30 * (1.0 - pJet)
                var coreW = 4.0 - 3.0 * pJet
                var coreA = 1.00 * (1.0 - pJet)

                if (jetLen > 0.5) {
                    // Teal glow (12px to 2px, alpha 0.3 to 0)
                    ctx.lineWidth = Math.max(0.5, glowW)
                    ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, glowA)
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.lineTo(cx, cy - jetLen)
                    ctx.moveTo(cx, cy)
                    ctx.lineTo(cx, cy + jetLen)
                    ctx.stroke()

                    // White core (4px to 1px, alpha 1.0 to 0)
                    ctx.lineWidth = Math.max(0.5, coreW)
                    ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, coreA)
                    ctx.beginPath()
                    ctx.moveTo(cx, cy)
                    ctx.lineTo(cx, cy - jetLen)
                    ctx.moveTo(cx, cy)
                    ctx.lineTo(cx, cy + jetLen)
                    ctx.stroke()
                }
            }

            // ── 5. Impact (1000ms+) ─────────────────────────────────────────
            // Flash, expanding white disc to r=70, expanding 190px teal ring, delayed purple ring
            if (t >= 1000.0) {
                // Fullscreen white flash (alpha 0.1, gone in 250ms -> 1000–1250ms)
                if (t <= 1250.0) {
                    var pFlash = clamp((t - 1000.0) / 250.0, 0.0, 1.0)
                    var aFlash = 0.10 * (1.0 - pFlash)
                    ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, aFlash)
                    ctx.fillRect(0, 0, w, h)
                }

                // White disc expanding to r=70 (alpha 0.55 to 0, 1000–1300ms)
                if (t <= 1300.0) {
                    var pWDisc = clamp((t - 1000.0) / 300.0, 0.0, 1.0)
                    var rWDisc = 70.0 * easeOutCubic(pWDisc)
                    var aWDisc = 0.55 * (1.0 - pWDisc)
                    ctx.beginPath()
                    ctx.arc(cx, cy, rWDisc, 0, 2 * Math.PI)
                    ctx.fillStyle = Qt.rgba(1.0, 1.0, 1.0, aWDisc)
                    ctx.fill()
                }

                // Teal ring expanding to 190px (radius 95px, 3px to 0.5px, 700ms easeOutCubic -> 1000–1700ms)
                if (t <= 1700.0) {
                    var pTRing = clamp((t - 1000.0) / 700.0, 0.0, 1.0)
                    var rTRing = 95.0 * easeOutCubic(pTRing)
                    var wTRing = 3.0 - 2.5 * pTRing
                    var aTRing = 0.85 * (1.0 - pTRing)
                    ctx.beginPath()
                    ctx.arc(cx, cy, rTRing, 0, 2 * Math.PI)
                    ctx.lineWidth = Math.max(0.5, wTRing)
                    ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, aTRing)
                    ctx.stroke()
                }

                // Purple ring delayed 80ms (1080–1780ms)
                if (t >= 1080.0 && t <= 1780.0) {
                    var pPRing = clamp((t - 1080.0) / 700.0, 0.0, 1.0)
                    var rPRing = 95.0 * easeOutCubic(pPRing)
                    var wPRing = 2.5 - 2.0 * pPRing
                    var aPRing = 0.75 * (1.0 - pPRing)
                    ctx.beginPath()
                    ctx.arc(cx, cy, rPRing, 0, 2 * Math.PI)
                    ctx.lineWidth = Math.max(0.5, wPRing)
                    ctx.strokeStyle = Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, aPRing)
                    ctx.stroke()
                }
            }

            // ── 6. Kinetic Text ("Wooshh!!", 1050–2350ms) ───────────────────
            // Primary screen only! Centered, ~82px above nucleus
            if (root.isPrimaryScreen && t >= 1050.0 && t <= 2350.0) {
                var word = root.transitionWord || "Wooshh!!"
                var numLetters = word.length
                var textCenterY = cy - 82.0

                // Exit fade, upward drift, and stretch at 1900ms over 400ms
                var pExit = clamp((t - 1900.0) / 400.0, 0.0, 1.0)
                var exitAlpha = 1.0 - pExit
                var exitYDrift = -18.0 * easeOutCubic(pExit)
                var exitStretch = 1.0 + 0.60 * easeOutCubic(pExit)

                ctx.save()
                ctx.font = "italic 900 46px 'JetBrainsMono Nerd Font', 'JetBrainsMono Nerd Font', 'JetBrainsMono Nerd Font', sans-serif"
                ctx.textBaseline = "middle"

                // Measure total text width for accurate centering
                var totalW = 0
                for (var m = 0; m < numLetters; m++) {
                    totalW += ctx.measureText(word.charAt(m)).width
                }
                var startX = cx - (totalW / 2.0)

                // 7 horizontal purple speed lines behind it to left, then retract (1050–1650ms)
                if (t <= 1650.0) {
                    var pRetract = clamp((t - 1050.0) / 550.0, 0.0, 1.0)
                    var retractEase = easeOutCubic(pRetract)
                    var lineLen = 95.0 * (1.0 - retractEase)
                    var lineAlpha = 0.70 * (1.0 - pRetract)

                    if (lineLen > 1.0 && lineAlpha > 0.01) {
                        ctx.strokeStyle = Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, lineAlpha)
                        ctx.lineWidth = 1.5
                        for (var tr = 0; tr < 7; tr++) {
                            var ly = textCenterY - 20.0 + tr * 6.5
                            var lx = startX - 10.0
                            ctx.beginPath()
                            ctx.moveTo(lx, ly)
                            ctx.lineTo(lx - lineLen, ly)
                            ctx.stroke()
                        }
                    }
                }

                // Draw each letter with 28ms stagger over 320ms
                var curX = startX
                for (var li = 0; li < numLetters; li++) {
                    var ch = word.charAt(li)
                    var chW = ctx.measureText(ch).width
                    var tEnter = 1050.0 + (li * 28.0)
                    var pEnter = clamp((t - tEnter) / 320.0, 0.0, 1.0)

                    if (pEnter > 0.001) {
                        var enterEase = easeOutExpo(pEnter)
                        // Slide in from -140px left
                        var chSlideX = -140.0 * (1.0 - enterEase)
                        // ScaleX 3.2 to 1
                        var chScaleX = 1.0 + 2.2 * (1.0 - enterEase)
                        var chAlpha = pEnter * exitAlpha

                        var finalScaleX = chScaleX * exitStretch
                        var finalScaleY = exitStretch
                        var finalX = curX + chSlideX
                        var finalY = textCenterY + exitYDrift

                        ctx.save()
                        ctx.translate(finalX, finalY)
                        // Skew -0.2 & horizontal scaling
                        ctx.transform(finalScaleX, 0, -0.20, finalScaleY, 0, 0)

                        // Layer 1: Purple offset shadow (+3, +3)
                        ctx.fillStyle = Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, chAlpha * 0.90)
                        ctx.fillText(ch, 3.0, 3.0)

                        // Layer 2: Teal main fill
                        ctx.fillStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, chAlpha)
                        ctx.fillText(ch, 0, 0)

                        // Layer 3: Thin white stroke
                        ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, chAlpha * 0.95)
                        ctx.lineWidth = 1.0
                        ctx.strokeText(ch, 0, 0)

                        ctx.restore()
                    }
                    curX += chW
                }
                ctx.restore()
            }

            // ── 7. Atom (1200–1900ms+) ─────────────────────────────────────
            // Resting carbon atom grows in (easeOutCubic), seamless handoff to resting nucleus
            if (t >= 1200.0) {
                var pAtom = clamp((t - 1200.0) / 700.0, 0.0, 1.0)
                var atomScale = easeOutCubic(pAtom)

                var rInner = 22.0 * atomScale
                var rOuter = 40.0 * atomScale

                // Orbit rings at 22px and 40px
                ctx.lineWidth = 1.0
                ctx.beginPath()
                ctx.arc(cx, cy, rInner, 0, 2 * Math.PI)
                ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.22 * atomScale)
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(cx, cy, rOuter, 0, 2 * Math.PI)
                ctx.strokeStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.16 * atomScale)
                ctx.stroke()

                // Central teal nucleus dot
                var dotRadius = 8.0 * atomScale
                ctx.beginPath()
                ctx.arc(cx, cy, dotRadius, 0, 2 * Math.PI)
                ctx.fillStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 1.0)
                ctx.fill()
                ctx.lineWidth = 1.0
                ctx.strokeStyle = Qt.rgba(1.0, 1.0, 1.0, 0.85 * atomScale)
                ctx.stroke()

                // Rotating electrons in opposite directions:
                // 2 purple electrons inner (22px)
                var rotInner = (t - 1200.0) * 0.0012
                for (var ei = 0; ei < 2; ei++) {
                    var aIn = rotInner + ei * Math.PI
                    var ex1 = cx + rInner * Math.cos(aIn)
                    var ey1 = cy + rInner * Math.sin(aIn)
                    ctx.beginPath()
                    ctx.arc(ex1, ey1, 3.0 * atomScale, 0, 2 * Math.PI)
                    ctx.fillStyle = Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, atomScale)
                    ctx.fill()
                }

                // 4 teal electrons outer (40px)
                var rotOuter = -(t - 1200.0) * 0.0008
                for (var eo = 0; eo < 4; eo++) {
                    var aOut = rotOuter + eo * (Math.PI / 2.0)
                    var ex2 = cx + rOuter * Math.cos(aOut)
                    var ey2 = cy + rOuter * Math.sin(aOut)
                    ctx.beginPath()
                    ctx.arc(ex2, ey2, 3.0 * atomScale, 0, 2 * Math.PI)
                    ctx.fillStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, atomScale)
                    ctx.fill()
                }

                // At t=2300ms caption "nucleus mode" fades in
                if (t >= 2300.0) {
                    var pCap = clamp((t - 2300.0) / 100.0, 0.0, 1.0)
                    ctx.save()
                    ctx.font = "bold 12px 'JetBrainsMono Nerd Font', 'JetBrainsMono Nerd Font', sans-serif"
                    ctx.textAlign = "center"
                    ctx.textBaseline = "middle"
                    ctx.fillStyle = Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, pCap * 0.80)
                    ctx.fillText("nucleus mode", cx, cy + 68.0)
                    ctx.restore()
                }
            }
        }
    }
}
