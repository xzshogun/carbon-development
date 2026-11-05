import QtQuick
import QtQuick.Shapes
import "../../Singletons"

/**
 * CarbonLogoMark.qml
 *
 * Vector implementation of the animated Carbon brand mark:
 * - High-precision GPU curve rendering with subpixel antialiasing
 * - Central luminous nucleus with soft radial glow and dual-ring breathing halo
 * - Rotating dual-spiral orbit with 54s base cycle
 * - Outward drawing intro sequence for spirals & staggered tail pieces
 * - 8s breathing/shimmer/drift cycle for tail segments with local centroid scaling
 * - Periodic coral expanding ping rings and luminous glows on lobes
 * - Interactive typing bump reaction (scale pulse, center ring, rotation speedup)
 * - Wrong-password reaction (coral glow pulse, 10x rotation boost)
 * - Fluid exit dissolve sequence on unlock
 */
Item {
    id: logoRoot

    implicitWidth: 200
    implicitHeight: 200

    property string phase: LockTransition.phase
    property real t: LockTransition.t
    property real u: LockTransition.u
    property bool isExiting: false

    // Timing helper: easing
    function easeOutCubic(p) {
        var x = Math.max(0.0, Math.min(1.0, p))
        return 1.0 - Math.pow(1.0 - x, 3.0)
    }

    function easeInOutCubic(p) {
        var x = Math.max(0.0, Math.min(1.0, p))
        return x < 0.5 ? 4.0 * x * x * x : 1.0 - Math.pow(-2.0 * x + 2.0, 3.0) / 2.0
    }

    function easeOutBack(p) {
        var c1 = 1.70158
        var c3 = c1 + 1.0
        var x = Math.max(0.0, Math.min(1.0, p))
        return 1.0 + c3 * Math.pow(x - 1.0, 3.0) + c1 * Math.pow(x - 1.0, 2.0)
    }

    /* ── Continuous Animation Driver ─────────────────────────────────────── */
    property real runningTime: 0.0
    property real orbitRotation: 0.0
    property real currentOrbitRate: 1.0
    property real targetOrbitRate: 1.0
    property real bumpScale: 1.0
    property real coralGlowOpacity: 0.0

    FrameAnimation {
        id: logoDriver
        running: logoRoot.visible && logoRoot.opacity > 0.001
        onTriggered: {
            var dt = frameTime * 1000.0
            logoRoot.runningTime += dt

            // Smooth orbit rate easing
            logoRoot.currentOrbitRate += (logoRoot.targetOrbitRate - logoRoot.currentOrbitRate) * Math.min(1.0, frameTime * 7.0)

            // Orbit rotation: 360 deg in 54000ms = 0.006667 deg/ms * rate
            var degStep = (360.0 / 54000.0) * dt * logoRoot.currentOrbitRate
            logoRoot.orbitRotation = (logoRoot.orbitRotation + degStep) % 360.0
        }
    }

    /* ── Interactive Trigger Functions ───────────────────────────────────── */
    function bump() {
        if (LockTransition.reducedMotion) return
        bumpAnim.restart()
        kringAnim.restart()
        logoRoot.targetOrbitRate = 7.0
        relaxTimer.restart()
    }

    function wrong() {
        if (LockTransition.reducedMotion) return
        wrongGlowAnim.restart()
        logoRoot.targetOrbitRate = 10.0
        relaxTimer.interval = 520
        relaxTimer.restart()
    }

    function triggerExit() {
        logoRoot.isExiting = true
    }

    function reset() {
        logoRoot.isExiting = false
        logoRoot.targetOrbitRate = 1.0
        logoRoot.currentOrbitRate = 1.0
        logoRoot.bumpScale = 1.0
        logoRoot.coralGlowOpacity = 0.0
    }

    Connections {
        target: LockTransition
        function onPhaseChanged() {
            if (LockTransition.phase === "idle") {
                logoRoot.reset()
            }
        }
    }

    Timer {
        id: relaxTimer
        interval: 700
        repeat: false
        onTriggered: {
            logoRoot.targetOrbitRate = 1.0
        }
    }

    SequentialAnimation {
        id: bumpAnim
        NumberAnimation {
            target: logoRoot
            property: "bumpScale"
            from: 1.0; to: 1.04
            duration: 160
            easing.type: Easing.OutBack
            easing.overshoot: 1.56
        }
        NumberAnimation {
            target: logoRoot
            property: "bumpScale"
            from: 1.04; to: 1.0
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: wrongGlowAnim
        NumberAnimation {
            target: logoRoot
            property: "coralGlowOpacity"
            from: 0.0; to: 0.90
            duration: 250
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: logoRoot
            property: "coralGlowOpacity"
            from: 0.90; to: 0.0
            duration: 650
            easing.type: Easing.OutCubic
        }
    }

    /* ── Intro & Exit State Progression ──────────────────────────────────── */
    // Lock-in: logo appears at t = 180ms. Logo intro clock (ms from appearance, accelerated 1.45x):
    readonly property real introMs: {
        if (phase === "locked") return 5000.0
        if (phase === "locking") return Math.max(0.0, (t - 180.0) * 1.45)
        return 0.0
    }

    // Unlock-out: logo exit starts at u = 160ms. Exit clock (ms from start):
    readonly property real exitMs: {
        if (phase === "unlocking" || phase === "post_unlock") return Math.max(0.0, u - 160.0)
        if (logoRoot.isExiting) return 500.0
        return 0.0
    }
    readonly property bool exiting: ((phase === "unlocking" || phase === "post_unlock") && u >= 160.0) || logoRoot.isExiting

    /* ── Breathing Rhythm for Core and Halo (4.2s alternating) ───────────── */
    readonly property real breathePhase: (logoRoot.runningTime % 4200.0) / 4200.0
    readonly property real breatheScale: 1.0 + 0.045 * Math.sin(breathePhase * 2.0 * Math.PI)
    readonly property real breatheHaloScale: 1.0 + 0.060 * Math.sin((breathePhase + 0.25) * 2.0 * Math.PI)
    readonly property real breatheHaloOpacity: 0.55 + 0.45 * Math.cos(breathePhase * 2.0 * Math.PI)

    // Master Scale Transform
    scale: logoRoot.bumpScale

    /* ── A. Coral Glow behind logo (Wrong password reaction) ─────────────── */
    Rectangle {
        id: eglow
        anchors.centerIn: parent
        width: 250
        height: 250
        radius: 125
        color: "transparent"
        border.color: "#f2705f"
        border.width: 40
        opacity: logoRoot.coralGlowOpacity * 0.45
        visible: opacity > 0.005
        antialiasing: true
        smooth: true
    }

    /* ── B. Center White Shock Ring on Keypress (kring) ──────────────────── */
    Rectangle {
        id: kring
        anchors.centerIn: parent
        width: 70
        height: 70
        radius: 35
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.70)
        border.width: 1.5
        property real kringScale: 0.6
        property real kringAlpha: 0.0
        scale: kringScale
        opacity: kringAlpha
        antialiasing: true
        smooth: true

        ParallelAnimation {
            id: kringAnim
            NumberAnimation {
                target: kring
                property: "kringScale"
                from: 0.6; to: 2.6
                duration: 900
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: kring
                property: "kringAlpha"
                from: 0.55; to: 0.0
                duration: 900
                easing.type: Easing.OutCubic
            }
        }
    }

    /* ── C. Outer Halo ───────────────────────────────────────────────────── */
    Item {
        id: haloGroup
        anchors.centerIn: parent
        width: 64
        height: 64

        readonly property real haloIntroP: Math.max(0.0, Math.min(1.0, (logoRoot.introMs - 155.0) / 620.0))
        readonly property real haloIntroScale: 1.55 - 0.55 * logoRoot.easeOutCubic(haloIntroP)
        readonly property real haloExitP: Math.max(0.0, Math.min(1.0, (logoRoot.exitMs - 350.0) / 500.0))

        scale: logoRoot.exiting ? Math.max(0.0, 1.0 - haloExitP) : (logoRoot.introMs < 155.0 ? 0.0 : haloIntroScale * logoRoot.breatheHaloScale)
        opacity: logoRoot.exiting ? Math.max(0.0, 1.0 - haloExitP) : (logoRoot.introMs < 155.0 ? 0.0 : Math.min(1.0, haloIntroP * 1.5) * logoRoot.breatheHaloOpacity)

        // Filled disk r=32
        Rectangle {
            anchors.centerIn: parent
            width: 64
            height: 64
            radius: 32
            color: "#f4f6f5"
            opacity: 0.07
            antialiasing: true
            smooth: true
        }

        // Thin stroke ring r=29, stroke 3
        Rectangle {
            anchors.centerIn: parent
            width: 58
            height: 58
            radius: 29
            color: "transparent"
            border.color: "#f4f6f5"
            border.width: 3
            opacity: 0.26
            antialiasing: true
            smooth: true
        }
    }

    /* ── D. Central Nucleus ──────────────────────────────────────────────── */
    // Soft radial emissive glow
    Rectangle {
        anchors.centerIn: nucleusCore
        width: 52
        height: 52
        radius: 26
        color: Qt.rgba(0.96, 0.96, 0.96, 0.22)
        scale: nucleusCore.scale
        opacity: nucleusCore.opacity
        antialiasing: true
        smooth: true
    }

    Rectangle {
        id: nucleusCore
        anchors.centerIn: parent
        width: 40
        height: 40
        radius: 20
        color: "#f4f6f5"
        antialiasing: true
        smooth: true

        readonly property real nucPopP: Math.max(0.0, Math.min(1.0, logoRoot.introMs / 589.0))
        readonly property real nucExitP: Math.max(0.0, Math.min(1.0, (logoRoot.exitMs - 1140.0) / 420.0))

        scale: {
            if (logoRoot.exiting) {
                if (logoRoot.exitMs < 1140.0) return 1.0
                return Math.max(0.0, 1.0 - logoRoot.easeOutCubic(nucExitP))
            }
            if (logoRoot.introMs < 10.0) return 0.0
            return (0.35 + 0.65 * logoRoot.easeOutBack(nucPopP)) * logoRoot.breatheScale
        }
        opacity: {
            if (logoRoot.exiting) {
                if (logoRoot.exitMs < 1140.0) return 1.0
                return Math.max(0.0, 1.0 - logoRoot.easeOutCubic(nucExitP))
            }
            return logoRoot.introMs < 10.0 ? 0.0 : Math.min(1.0, nucPopP * 1.8)
        }
    }

    /* ── E. Rotating Orbit Group (Spirals, Tails, Coral Lobes) ───────────── */
    Item {
        id: orbitGroup
        anchors.centerIn: parent
        width: 200
        height: 200
        rotation: logoRoot.orbitRotation
        transformOrigin: Item.Center

        /* ── 1. Spiral 2 Body (Faint Twin) ── */
        Shape {
            anchors.fill: parent
            antialiasing: true
            smooth: true
            preferredRendererType: Shape.CurveRenderer

            readonly property real s2DrawP: Math.max(0.0, Math.min(1.0, (logoRoot.introMs - 155.0) / 837.0))
            readonly property real s2ExitP: Math.max(0.0, Math.min(1.0, logoRoot.exitMs / 750.0))

            readonly property real drawFraction: {
                if (logoRoot.exiting) return Math.max(0.0, 1.0 - logoRoot.easeInOutCubic(s2ExitP))
                if (logoRoot.introMs < 155.0) return 0.0
                return logoRoot.easeInOutCubic(s2DrawP)
            }

            opacity: drawFraction > 0.01 ? 0.42 : 0.0

            ShapePath {
                strokeColor: "#f4f6f5"
                strokeWidth: 5.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                dashPattern: parent.drawFraction < 0.999 ? [175, 175] : []
                dashOffset: 175.0 * (1.0 - parent.drawFraction)

                PathSvg {
                    path: "M100.0 138.0 L98.1 138.2 L96.2 138.3 L94.2 138.3 L92.3 138.2 L90.3 138.0 L88.4 137.7 L86.4 137.3 L84.5 136.8 L82.6 136.2 L80.7 135.5 L78.8 134.7 L76.9 133.8 L75.1 132.8 L73.3 131.8 L71.6 130.6 L69.9 129.3 L68.3 128.0 L66.8 126.5 L65.3 125.0 L63.9 123.3 L62.5 121.6 L61.2 119.9 L60.0 118.0 L59.0 116.1 L57.9 114.1 L57.0 112.1 L56.2 110.0 L55.5 107.8 L54.9 105.6 L54.4 103.4 L54.0 101.1 L53.8 98.8 L53.6 96.5 L53.6 94.2 L53.7 91.8 L53.9 89.5 L54.2 87.1 L54.6 84.8 L55.2 82.4 L55.9 80.1 L56.7 77.8 L57.6 75.5 L58.6 73.3 L59.8 71.1 L61.1 69.0 L62.5 66.9 L64.0 64.8 L65.6 62.9 L67.3 61.0 L69.1 59.2 L71.0 57.5 L73.0 55.9 L75.1 54.3 L77.3 52.9 L79.6 51.6 L81.9 50.3 L84.3 49.2 L86.8 48.3 L89.4 47.4 L92.0 46.6 L94.6 46.0 L97.3 45.6 L100.0 45.2 L102.7 45.0 L105.5 44.9 L108.3 45.0 L111.1 45.2 L113.9 45.5 L116.6 46.0 L119.4 46.7"
                }
            }
        }

        /* ── 2. Spiral 1 Body (Strong Master) ── */
        Shape {
            anchors.fill: parent
            antialiasing: true
            smooth: true
            preferredRendererType: Shape.CurveRenderer

            readonly property real s1DrawP: Math.max(0.0, Math.min(1.0, (logoRoot.introMs - 435.0) / 837.0))
            readonly property real s1ExitP: Math.max(0.0, Math.min(1.0, logoRoot.exitMs / 750.0))

            readonly property real drawFraction: {
                if (logoRoot.exiting) return Math.max(0.0, 1.0 - logoRoot.easeInOutCubic(s1ExitP))
                if (logoRoot.introMs < 435.0) return 0.0
                return logoRoot.easeInOutCubic(s1DrawP)
            }

            opacity: drawFraction > 0.01 ? 1.0 : 0.0

            ShapePath {
                strokeColor: "#f4f6f5"
                strokeWidth: 6.4
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                dashPattern: parent.drawFraction < 0.999 ? [175, 175] : []
                dashOffset: 175.0 * (1.0 - parent.drawFraction)

                PathSvg {
                    path: "M100.0 62.0 L101.9 61.8 L103.8 61.7 L105.8 61.7 L107.7 61.8 L109.7 62.0 L111.6 62.3 L113.6 62.7 L115.5 63.2 L117.4 63.8 L119.3 64.5 L121.2 65.3 L123.1 66.2 L124.9 67.2 L126.7 68.2 L128.4 69.4 L130.1 70.7 L131.7 72.0 L133.2 73.5 L134.7 75.0 L136.1 76.7 L137.5 78.4 L138.8 80.1 L140.0 82.0 L141.0 83.9 L142.1 85.9 L143.0 87.9 L143.8 90.0 L144.5 92.2 L145.1 94.4 L145.6 96.6 L146.0 98.9 L146.2 101.2 L146.4 103.5 L146.4 105.8 L146.3 108.2 L146.1 110.5 L145.8 112.9 L145.4 115.2 L144.8 117.6 L144.1 119.9 L143.3 122.2 L142.4 124.5 L141.4 126.7 L140.2 128.9 L138.9 131.0 L137.5 133.1 L136.0 135.2 L134.4 137.1 L132.7 139.0 L130.9 140.8 L129.0 142.5 L127.0 144.1 L124.9 145.7 L122.7 147.1 L120.4 148.4 L118.1 149.7 L115.7 150.8 L113.2 151.7 L110.6 152.6 L108.0 153.4 L105.4 154.0 L102.7 154.4 L100.0 154.8 L97.3 155.0 L94.5 155.1 L91.7 155.0 L88.9 154.8 L86.1 154.5 L83.4 154.0 L80.6 153.3"
                }
            }
        }

        /* ── 3. Tail Pieces Component Generator ── */
        function computeTailPieceState(delayMs, cycleMs, idx, dx, dy, targetOp) {
            // A. Intro State (fade & scale from 0.55 over 372ms)
            if (logoRoot.introMs < delayMs) return { op: 0.0, sc: 0.55, tx: 0.0, ty: 0.0 }
            var introProgress = Math.max(0.0, Math.min(1.0, (logoRoot.introMs - delayMs) / 372.0))
            var introScale = 0.55 + 0.45 * logoRoot.easeOutBack(introProgress)
            var baseOp = targetOp * introProgress

            // B. Exit State on Unlock (drift 3*dx, fade and shrink over 650ms, staggered 28ms)
            if (logoRoot.exiting) {
                var exitStart = idx * 28.0
                if (logoRoot.exitMs < exitStart) return { op: baseOp, sc: 1.0, tx: 0.0, ty: 0.0 }
                var ep = Math.max(0.0, Math.min(1.0, (logoRoot.exitMs - exitStart) / 650.0))
                return {
                    op: Math.max(0.0, baseOp * (1.0 - ep)),
                    sc: Math.max(0.5, 1.0 - 0.5 * ep),
                    tx: dx * 3.0 * ep,
                    ty: dy * 3.0 * ep
                }
            }

            // C. Idle 8-second repeating cycle
            if (introProgress < 0.999) return { op: baseOp, sc: introScale, tx: 0.0, ty: 0.0 }

            var cycleTime = (logoRoot.runningTime + cycleMs) % 8000.0
            var p = cycleTime / 8000.0
            var opMult = 1.0
            var txVal = 0.0
            var tyVal = 0.0
            var scVal = 1.0

            if (p < 0.22) {
                opMult = 1.0 - 0.40 * (p / 0.22)
            } else if (p < 0.40) {
                opMult = 0.60 + 0.40 * ((p - 0.22) / 0.18)
            } else if (p < 0.52) {
                opMult = 1.0
            } else if (p < 0.72) {
                var driftP = (p - 0.52) / 0.20
                opMult = Math.max(0.0, 1.0 - driftP)
                txVal = dx * driftP
                tyVal = dy * driftP
                scVal = 1.0 - 0.45 * driftP
            } else if (p < 0.76) {
                opMult = 0.0
                scVal = 0.55
            } else if (p < 0.92) {
                var reformP = (p - 0.76) / 0.16
                opMult = reformP
                scVal = 0.55 + 0.45 * reformP
            } else {
                opMult = 1.0
            }

            return {
                op: targetOp * opMult,
                sc: scVal,
                tx: txVal,
                ty: tyVal
            }
        }

        /* ── Spiral 2 Tail Pieces (7 Path Segments + 3 Dots) ── */
        Repeater {
            model: [
                { d: "M130.7 50.9 L133.8 52.5 L136.9 54.4 L139.8 56.5 L142.7 58.8 L145.4 61.2 L147.9 63.9 L150.3 66.7 L152.6 69.6", sw: 4.9, op: 0.39, dx: 7.2, dy: -6.9, cx: 141.6, cy: 60.2, delay: 710, cycle: 1610, idx: 0 },
                { d: "M158.4 79.9 L159.5 82.5 L160.5 85.1 L161.4 87.8 L162.1 90.6 L162.7 93.3 L163.2 96.2 L163.6 99.0 L163.8 101.9", sw: 4.4, op: 0.35, dx: 9.9, dy: -1.5, cx: 161.1, cy: 90.9, delay: 780, cycle: 1750, idx: 1 },
                { d: "M163.2 115.5 L162.8 117.7 L162.4 119.9 L161.9 122.0 L161.3 124.1 L160.6 126.2 L159.9 128.3 L159.1 130.4 L158.2 132.5", sw: 4.0, op: 0.32, dx: 9.3, dy: 3.7, cx: 160.7, cy: 124.0, delay: 850, cycle: 1890, idx: 2 },
                { d: "M150.1 145.9 L149.1 147.2 L148.0 148.5 L146.9 149.8 L145.7 151.0 L144.6 152.3 L143.3 153.5 L142.1 154.6 L140.8 155.8", sw: 3.5, op: 0.29, dx: 6.7, dy: 7.4, cx: 145.4, cy: 150.8, delay: 920, cycle: 2030, idx: 3 },
                { d: "M125.9 165.7 L124.8 166.2 L123.6 166.8 L122.4 167.3 L121.2 167.8 L120.0 168.3 L118.7 168.7 L117.5 169.1 L116.3 169.6", sw: 3.1, op: 0.26, dx: 3.0, dy: 9.5, cx: 121.1, cy: 167.6, delay: 990, cycle: 2170, idx: 4 },
                { d: "M96.2 173.0 L95.2 173.0 L94.2 173.0 L93.3 173.0 L92.3 173.0 L91.3 172.9 L90.3 172.9 L89.3 172.8 L88.3 172.8", sw: 2.6, op: 0.23, dx: -1.1, dy: 9.9, cx: 92.2, cy: 172.9, delay: 1050, cycle: 2300, idx: 5 },
                { d: "M65.9 167.3 L65.2 167.0 L64.5 166.7 L63.8 166.4 L63.1 166.1 L62.4 165.8 L61.7 165.5 L61.0 165.1 L60.3 164.8", sw: 2.2, op: 0.20, dx: -4.9, dy: 8.7, cx: 63.1, cy: 166.0, delay: 1120, cycle: 2440, idx: 6 }
            ]

            delegate: Item {
                id: s2PieceItem
                anchors.fill: parent
                readonly property var st: orbitGroup.computeTailPieceState(modelData.delay, modelData.cycle, modelData.idx, modelData.dx, modelData.dy, modelData.op)
                transform: [
                    Translate { x: s2PieceItem.st.tx; y: s2PieceItem.st.ty },
                    Scale { origin.x: modelData.cx; origin.y: modelData.cy; xScale: s2PieceItem.st.sc; yScale: s2PieceItem.st.sc }
                ]
                opacity: s2PieceItem.st.op

                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    smooth: true
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "#f4f6f5"
                        strokeWidth: modelData.sw
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: modelData.d }
                    }
                }
            }
        }

        Repeater {
            model: [
                { cx: 39.4, cy: 149.1, r: 1.3, op: 0.17, dx: -8.0, dy: 6.1, delay: 1190, cycle: 2580, idx: 7 },
                { cx: 22.0, cy: 119.7, r: 1.3, op: 0.13, dx: -9.7, dy: 2.2, delay: 1260, cycle: 2720, idx: 8 },
                { cx: 18.6, cy: 82.8, r: 1.3, op: 0.10, dx: -9.8, dy: -2.2, delay: 1330, cycle: 2860, idx: 9 }
            ]

            delegate: Item {
                id: s2DotItem
                anchors.fill: parent
                readonly property var st: orbitGroup.computeTailPieceState(modelData.delay, modelData.cycle, modelData.idx, modelData.dx, modelData.dy, modelData.op)
                transform: [
                    Translate { x: s2DotItem.st.tx; y: s2DotItem.st.ty },
                    Scale { origin.x: modelData.cx; origin.y: modelData.cy; xScale: s2DotItem.st.sc; yScale: s2DotItem.st.sc }
                ]
                opacity: s2DotItem.st.op

                Rectangle {
                    x: modelData.cx - modelData.r
                    y: modelData.cy - modelData.r
                    width: modelData.r * 2
                    height: width
                    radius: modelData.r
                    color: "#f4f6f5"
                    antialiasing: true
                    smooth: true
                }
            }
        }

        /* ── Spiral 1 Tail Pieces (7 Path Segments + 3 Dots) ── */
        Repeater {
            model: [
                { d: "M69.3 149.1 L65.7 147.2 L62.2 145.0 L58.9 142.5 L55.8 139.8 L52.8 136.9 L50.0 133.7 L47.4 130.4 L45.1 126.8", sw: 5.8, op: 0.92, dx: -7.4, dy: 6.7, cx: 57.2, cy: 138.0, delay: 990, cycle: 1890, idx: 0 },
                { d: "M40.3 117.1 L39.2 114.1 L38.3 111.0 L37.5 107.8 L36.9 104.6 L36.4 101.3 L36.2 98.0 L36.0 94.7 L36.1 91.4", sw: 5.3, op: 0.85, dx: -10.0, dy: 0.7, cx: 38.2, cy: 104.2, delay: 1060, cycle: 2030, idx: 1 },
                { d: "M37.9 79.0 L38.5 76.6 L39.3 74.1 L40.1 71.7 L41.0 69.4 L42.0 67.0 L43.2 64.7 L44.4 62.5 L45.7 60.2", sw: 4.9, op: 0.77, dx: -8.9, dy: -4.6, cx: 41.8, cy: 69.6, delay: 1130, cycle: 2170, idx: 2 },
                { d: "M54.4 48.8 L55.8 47.4 L57.2 46.1 L58.6 44.7 L60.1 43.5 L61.6 42.2 L63.2 41.0 L64.8 39.9 L66.4 38.7", sw: 4.4, op: 0.70, dx: -5.8, dy: -8.2, cx: 60.4, cy: 43.8, delay: 1200, cycle: 2310, idx: 3 },
                { d: "M81.1 31.4 L82.5 30.9 L83.9 30.4 L85.3 29.9 L86.8 29.5 L88.2 29.2 L89.7 28.8 L91.2 28.5 L92.7 28.2", sw: 4.0, op: 0.62, dx: -1.8, dy: -9.8, cx: 86.9, cy: 29.8, delay: 1260, cycle: 2440, idx: 4 },
                { d: "M111.3 27.2 L112.4 27.3 L113.6 27.4 L114.7 27.5 L115.9 27.7 L117.0 27.9 L118.1 28.0 L119.3 28.2 L120.4 28.5", sw: 3.5, op: 0.55, dx: 2.1, dy: -9.8, cx: 115.8, cy: 27.8, delay: 1330, cycle: 2580, idx: 5 },
                { d: "M140.3 35.5 L141.1 36.0 L141.9 36.4 L142.6 36.8 L143.4 37.2 L144.1 37.7 L144.9 38.1 L145.6 38.6 L146.4 39.1", sw: 3.1, op: 0.47, dx: 5.7, dy: -8.2, cx: 143.4, cy: 37.3, delay: 1400, cycle: 2720, idx: 6 }
            ]

            delegate: Item {
                id: s1PieceItem
                anchors.fill: parent
                readonly property var st: orbitGroup.computeTailPieceState(modelData.delay, modelData.cycle, modelData.idx, modelData.dx, modelData.dy, modelData.op)
                transform: [
                    Translate { x: s1PieceItem.st.tx; y: s1PieceItem.st.ty },
                    Scale { origin.x: modelData.cx; origin.y: modelData.cy; xScale: s1PieceItem.st.sc; yScale: s1PieceItem.st.sc }
                ]
                opacity: s1PieceItem.st.op

                Shape {
                    anchors.fill: parent
                    antialiasing: true
                    smooth: true
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "#f4f6f5"
                        strokeWidth: modelData.sw
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: modelData.d }
                    }
                }
            }
        }

        Repeater {
            model: [
                { cx: 164.2, cy: 55.0, r: 1.3, op: 0.40, dx: 8.4, dy: -5.5, delay: 1470, cycle: 2860, idx: 7 },
                { cx: 179.1, cy: 83.7, r: 1.3, op: 0.32, dx: 9.8, dy: -1.8, delay: 1540, cycle: 3000, idx: 8 },
                { cx: 181.2, cy: 118.3, r: 1.3, op: 0.25, dx: 9.7, dy: 2.4, delay: 1610, cycle: 3140, idx: 9 }
            ]

            delegate: Item {
                id: s1DotItem
                anchors.fill: parent
                readonly property var st: orbitGroup.computeTailPieceState(modelData.delay, modelData.cycle, modelData.idx, modelData.dx, modelData.dy, modelData.op)
                transform: [
                    Translate { x: s1DotItem.st.tx; y: s1DotItem.st.ty },
                    Scale { origin.x: modelData.cx; origin.y: modelData.cy; xScale: s1DotItem.st.sc; yScale: s1DotItem.st.sc }
                ]
                opacity: s1DotItem.st.op

                Rectangle {
                    x: modelData.cx - modelData.r
                    y: modelData.cy - modelData.r
                    width: modelData.r * 2
                    height: width
                    radius: modelData.r
                    color: "#f4f6f5"
                    antialiasing: true
                    smooth: true
                }
            }
        }

        /* ── 4. Coral Lobes, Outer Rings & Expanding Ping Rings ──────────────── */
        function computeLobeState(popDelay, ringDelay, pingOffset, lx, ly) {
            // Intro: pop at popDelay (465ms spring), ring follows at ringDelay (434ms)
            var popProgress = Math.max(0.0, Math.min(1.0, (logoRoot.introMs - popDelay) / 465.0))
            var popScale = logoRoot.introMs < popDelay ? 0.0 : logoRoot.easeOutBack(popProgress)
            var ringProgress = Math.max(0.0, Math.min(1.0, (logoRoot.introMs - ringDelay) / 434.0))

            // Exit: falls into nucleus (translate lx, ly, scale 0.25 over 700ms)
            if (logoRoot.exiting) {
                var exitP = Math.max(0.0, Math.min(1.0, (logoRoot.exitMs - 80.0) / 700.0))
                return {
                    scale: Math.max(0.0, 1.0 - 0.75 * exitP),
                    opacity: Math.max(0.0, 1.0 - exitP),
                    ringOpacity: Math.max(0.0, 0.38 * (1.0 - exitP * 1.5)),
                    tx: lx * exitP,
                    ty: ly * exitP,
                    pingScale: 1.0,
                    pingOpacity: 0.0
                }
            }

            // Idle expanding ping ring every 4600ms
            var pingCycle = (logoRoot.runningTime + pingOffset) % 4600.0
            var pingFraction = pingCycle / 4600.0
            var pScale = 1.0
            var pAlpha = 0.0

            if (popProgress >= 0.99) {
                if (pingFraction < 0.38) {
                    var pf = pingFraction / 0.38
                    pScale = 1.0 + 1.3 * pf // 1.0 -> 2.3
                    pAlpha = 0.85 * (1.0 - pf)
                }
            }

            return {
                scale: popScale,
                opacity: popScale > 0.01 ? 1.0 : 0.0,
                ringOpacity: 0.38 * ringProgress,
                tx: 0.0,
                ty: 0.0,
                pingScale: pScale,
                pingOpacity: pAlpha
            }
        }

        // Lobe 1 (cx: 178.9, cy: 128.7)
        Item {
            id: lobe1Item
            x: 178.9
            y: 128.7
            readonly property var lst: orbitGroup.computeLobeState(980.0, 1035.0, 2110.0, -78.9, -28.7)

            transform: [
                Translate { x: lobe1Item.lst.tx; y: lobe1Item.lst.ty },
                Scale { xScale: lobe1Item.lst.scale; yScale: lobe1Item.lst.scale }
            ]
            opacity: lobe1Item.lst.opacity

            // Expanding Ping Ring
            Rectangle {
                anchors.centerIn: parent
                width: 15
                height: 15
                radius: 7.5
                color: "transparent"
                border.color: "#f2705f"
                border.width: 2.0
                scale: lobe1Item.lst.pingScale
                opacity: lobe1Item.lst.pingOpacity
                antialiasing: true
                smooth: true
            }

            // Ambient Static Ring r=13 (diameter 26)
            Rectangle {
                anchors.centerIn: parent
                width: 26
                height: 26
                radius: 13
                color: "transparent"
                border.color: "#f2705f"
                border.width: 2.0
                opacity: lobe1Item.lst.ringOpacity
                antialiasing: true
                smooth: true
            }

            // Luminous soft coral glow from SVG drop-shadow
            Rectangle {
                anchors.centerIn: parent
                width: 21
                height: 21
                radius: 10.5
                color: Qt.rgba(0.95, 0.44, 0.37, 0.35)
                antialiasing: true
                smooth: true
            }

            // Core Filled Lobe r=7.5 (diameter 15)
            Rectangle {
                anchors.centerIn: parent
                width: 15
                height: 15
                radius: 7.5
                color: "#f2705f"
                antialiasing: true
                smooth: true
            }
        }

        // Lobe 2 (cx: 21.1, cy: 71.3)
        Item {
            id: lobe2Item
            x: 21.1
            y: 71.3
            readonly property var lst: orbitGroup.computeLobeState(1097.0, 1153.0, 4410.0, 78.9, 28.7)

            transform: [
                Translate { x: lobe2Item.lst.tx; y: lobe2Item.lst.ty },
                Scale { xScale: lobe2Item.lst.scale; yScale: lobe2Item.lst.scale }
            ]
            opacity: lobe2Item.lst.opacity

            // Expanding Ping Ring
            Rectangle {
                anchors.centerIn: parent
                width: 15
                height: 15
                radius: 7.5
                color: "transparent"
                border.color: "#f2705f"
                border.width: 2.0
                scale: lobe2Item.lst.pingScale
                opacity: lobe2Item.lst.pingOpacity
                antialiasing: true
                smooth: true
            }

            // Ambient Static Ring r=13 (diameter 26)
            Rectangle {
                anchors.centerIn: parent
                width: 26
                height: 26
                radius: 13
                color: "transparent"
                border.color: "#f2705f"
                border.width: 2.0
                opacity: lobe2Item.lst.ringOpacity
                antialiasing: true
                smooth: true
            }

            // Luminous soft coral glow from SVG drop-shadow
            Rectangle {
                anchors.centerIn: parent
                width: 21
                height: 21
                radius: 10.5
                color: Qt.rgba(0.95, 0.44, 0.37, 0.35)
                antialiasing: true
                smooth: true
            }

            // Core Filled Lobe r=7.5 (diameter 15)
            Rectangle {
                anchors.centerIn: parent
                width: 15
                height: 15
                radius: 7.5
                color: "#f2705f"
                antialiasing: true
                smooth: true
            }
        }
    }
}
