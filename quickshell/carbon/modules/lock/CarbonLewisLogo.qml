import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"

/**
 * CarbonLewisLogo:
 * Renders the Bohr Atomic Model of Carbon (atomic number 6):
 *   - Bold, prominent central "C" glyph with exact optical centering
 *   - 6 total electrons in 2 concentric circumcircles:
 *       • Layer 1 (Inner K-shell): 2 dots rotating clockwise (5.8s)
 *       • Layer 2 (Outer L-shell): 4 dots rotating counter-clockwise (9.4s)
 *   - Non-simultaneous independent rotations create an authentic atomic simulation
 *   - Screen-edge converging animation at startup for all 6 dots
 *   - Periodic shockwave ripple and dot pulse (toggleable via carbon-lockscreen.json "heartbeat")
 */
Item {
    id: root

    signal settled()

    property real screenWidth: 1366
    property real screenHeight: 768

    // Center offset to absolute screen coordinates
    property real screenCenterX: screenWidth / 2
    property real screenCenterY: screenHeight / 2 - 28

    // Dual concentric circumcircle orbital radii
    property real innerOrbitRadius: 52
    property real outerOrbitRadius: 92

    // Heartbeat pulse configuration
    property bool heartbeatEnabled: true
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
                if (parsed.heartbeat !== undefined) {
                    root.heartbeatEnabled = parsed.heartbeat
                    if (!root.heartbeatEnabled) {
                        periodicPulseTimer.stop()
                        periodicPulseAnim.stop()
                        impactRing.opacity = 0
                    } else if (introAnim.running === false) {
                        periodicPulseTimer.restart()
                    }
                }
            }
        } catch (e) {
            console.log("Failed to parse lockscreen config in CarbonLewisLogo:", e)
        }
    }

    implicitWidth: root.outerOrbitRadius * 2 + 80
    implicitHeight: root.outerOrbitRadius * 2 + 80

    function playIntro() {
        innerOrbitAnim.stop()
        outerOrbitAnim.stop()
        innerOrbitGroup.rotation = 0
        outerOrbitGroup.rotation = 0
        introAnim.restart()
    }

    Component.onCompleted: {
        root.reloadConfig()
        playIntro()
    }

    /* ── Ambient Idle Breathing Glow ─────────────────────────────────────── */
    SequentialAnimation {
        id: idleAnim
        running: false
        loops: Animation.Infinite

        ParallelAnimation {
            NumberAnimation {
                targets: [innerGlowRing, outerGlowRing]
                property: "opacity"
                to: 0.65
                duration: 2000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                targets: [innerGlowRing, outerGlowRing]
                property: "scale"
                to: 1.03
                duration: 2000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: centerGlow
                property: "opacity"
                to: 0.35
                duration: 2000
                easing.type: Easing.InOutSine
            }
        }
        ParallelAnimation {
            NumberAnimation {
                targets: [innerGlowRing, outerGlowRing]
                property: "opacity"
                to: 0.25
                duration: 2000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                targets: [innerGlowRing, outerGlowRing]
                property: "scale"
                to: 0.98
                duration: 2000
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                target: centerGlow
                property: "opacity"
                to: 0.15
                duration: 2000
                easing.type: Easing.InOutSine
            }
        }
    }

    /* ── Periodic Pulse & Shockwave (Heartbeat Effect) ────────────────────── */
    Timer {
        id: periodicPulseTimer
        interval: 1850
        running: false
        repeat: true
        onTriggered: {
            if (root.heartbeatEnabled) {
                periodicPulseAnim.restart()
            }
        }
    }

    ParallelAnimation {
        id: periodicPulseAnim

        // Expanding circular shockwave ring from the outer circumcircle outwards
        SequentialAnimation {
            PropertyAction { target: impactRing; property: "scale"; value: 0.9 }
            PropertyAction { target: impactRing; property: "opacity"; value: 0.85 }

            ParallelAnimation {
                NumberAnimation {
                    target: impactRing
                    property: "scale"
                    to: 2.3
                    duration: 750
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: impactRing
                    property: "opacity"
                    to: 0.0
                    duration: 750
                    easing.type: Easing.OutQuad
                }
            }
        }

        // All 6 dots pulse with scale bounce
        SequentialAnimation {
            ParallelAnimation {
                NumberAnimation {
                    targets: [innerDotTop, innerDotBottom, dotTop, dotBottom, dotLeft, dotRight]
                    property: "scale"
                    to: 1.35
                    duration: 180
                    easing.type: Easing.OutQuad
                }
            }
            ParallelAnimation {
                NumberAnimation {
                    targets: [innerDotTop, innerDotBottom, dotTop, dotBottom, dotLeft, dotRight]
                    property: "scale"
                    to: 1.0
                    duration: 350
                    easing.type: Easing.OutBack
                }
            }
        }

        // Orbital rings flash brightly
        SequentialAnimation {
            NumberAnimation {
                targets: [innerGlowRing, outerGlowRing]
                property: "opacity"
                to: 0.85
                duration: 180
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                targets: [innerGlowRing, outerGlowRing]
                property: "opacity"
                to: 0.28
                duration: 550
                easing.type: Easing.OutQuad
            }
        }

        // Central "C" glow surges
        SequentialAnimation {
            NumberAnimation {
                target: centerGlow
                property: "opacity"
                to: 0.50
                duration: 180
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: centerGlow
                property: "opacity"
                to: 0.18
                duration: 550
                easing.type: Easing.OutQuad
            }
        }
    }

    /* ── Non-Simultaneous Independent Revolutions (Bohr Atom Dynamics) ────── */
    property bool isOrbiting: false
    FrameAnimation {
        running: root.isOrbiting && root.visible
        onTriggered: {
            innerOrbitGroup.rotation += frameTime * (360.0 / 5.8)
            outerOrbitGroup.rotation -= frameTime * (360.0 / 9.4)
        }
    }
    property var innerOrbitAnim: ({ stop: function() { root.isOrbiting = false }, restart: function() { root.isOrbiting = true } })
    property var outerOrbitAnim: ({ stop: function() { root.isOrbiting = false }, restart: function() { root.isOrbiting = true } })

    /* ── Intro Converging Animation (All 6 Atoms Fly In) ─────────────────── */
    ParallelAnimation {
        id: introAnim
        onFinished: {
            impactAnim.restart()
            idleAnim.restart()
            if (root.heartbeatEnabled) {
                periodicPulseTimer.restart()
            }
            innerOrbitAnim.restart()
            outerOrbitAnim.restart()
            root.settled()
        }

        // Central "C" fade and scale in
        NumberAnimation {
            target: centerLetter
            property: "scale"
            from: 0.15
            to: 1.0
            duration: 720
            easing.type: Easing.OutBack
            easing.overshoot: 1.3
        }
        NumberAnimation {
            target: centerLetter
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 550
            easing.type: Easing.OutCubic
        }

        // ── Layer 1: Inner 2 Dots ──
        // 1. Inner Top dot flying in from top screen edge
        NumberAnimation {
            target: innerDotTop
            property: "y"
            from: -root.screenCenterY - 80
            to: -root.innerOrbitRadius - innerDotTop.height / 2
            duration: 850
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: innerDotTop
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 450
            easing.type: Easing.OutQuad
        }

        // 2. Inner Bottom dot flying in from bottom screen edge
        NumberAnimation {
            target: innerDotBottom
            property: "y"
            from: (root.screenHeight - root.screenCenterY) + 80
            to: root.innerOrbitRadius - innerDotBottom.height / 2
            duration: 850
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: innerDotBottom
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 450
            easing.type: Easing.OutQuad
        }

        // ── Layer 2: Outer 4 Dots ──
        // 3. Outer Top dot flying in from top screen edge
        NumberAnimation {
            target: dotTop
            property: "y"
            from: -root.screenCenterY - 80
            to: -root.outerOrbitRadius - dotTop.height / 2
            duration: 950
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: dotTop
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 450
            easing.type: Easing.OutQuad
        }

        // 4. Outer Bottom dot flying in from bottom screen edge
        NumberAnimation {
            target: dotBottom
            property: "y"
            from: (root.screenHeight - root.screenCenterY) + 80
            to: root.outerOrbitRadius - dotBottom.height / 2
            duration: 950
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: dotBottom
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 450
            easing.type: Easing.OutQuad
        }

        // 5. Outer Left dot flying in from left screen edge
        NumberAnimation {
            target: dotLeft
            property: "x"
            from: -root.screenCenterX - 80
            to: -root.outerOrbitRadius - dotLeft.width / 2
            duration: 950
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: dotLeft
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 450
            easing.type: Easing.OutQuad
        }

        // 6. Outer Right dot flying in from right screen edge
        NumberAnimation {
            target: dotRight
            property: "x"
            from: (root.screenWidth - root.screenCenterX) + 80
            to: root.outerOrbitRadius - dotRight.width / 2
            duration: 950
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: dotRight
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: 450
            easing.type: Easing.OutQuad
        }
    }

    /* ── Impact Settle Pulse & Expanding Ripple ─────────────────────────── */
    ParallelAnimation {
        id: impactAnim

        // All 6 dots pop on impact
        SequentialAnimation {
            NumberAnimation {
                targets: [innerDotTop, innerDotBottom, dotTop, dotBottom, dotLeft, dotRight]
                property: "scale"
                to: 1.45
                duration: 140
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                targets: [innerDotTop, innerDotBottom, dotTop, dotBottom, dotLeft, dotRight]
                property: "scale"
                to: 1.0
                duration: 260
                easing.type: Easing.OutBack
            }
        }

        // Expanding circular ripple
        SequentialAnimation {
            NumberAnimation {
                target: impactRing
                property: "scale"
                from: 0.25
                to: 2.4
                duration: 520
                easing.type: Easing.OutCubic
            }
        }
        SequentialAnimation {
            NumberAnimation {
                target: impactRing
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 520
                easing.type: Easing.OutQuad
            }
        }
    }

    /* ── Visual Elements ─────────────────────────────────────────────────── */
    Item {
        id: container
        anchors.centerIn: parent
        width: 1
        height: 1

        // Layer 1 Inner circumcircle guide ring
        Rectangle {
            id: innerGlowRing
            anchors.centerIn: parent
            width: root.innerOrbitRadius * 2
            height: root.innerOrbitRadius * 2
            radius: root.innerOrbitRadius
            color: "transparent"
            border.color: Theme.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.32) : Qt.rgba(0, 0.94, 1, 0.32)
            border.width: 1.3
            opacity: 0.35
        }

        // Layer 2 Outer circumcircle guide ring
        Rectangle {
            id: outerGlowRing
            anchors.centerIn: parent
            width: root.outerOrbitRadius * 2
            height: root.outerOrbitRadius * 2
            radius: root.outerOrbitRadius
            color: "transparent"
            border.color: Theme.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28) : Qt.rgba(0, 0.94, 1, 0.28)
            border.width: 1.5
            opacity: 0.35
        }

        // Ripple ring on impact and recurring periodic heartbeat pulse
        Rectangle {
            id: impactRing
            anchors.centerIn: parent
            width: root.outerOrbitRadius * 2
            height: root.outerOrbitRadius * 2
            radius: root.outerOrbitRadius
            color: "transparent"
            border.color: Theme.accent ? Theme.accent : "#00F0FF"
            border.width: 2.5
            opacity: 0.0
            scale: 0.25
        }

        // Central "C" Letter centered precisely at (0, 0)
        Item {
            id: centerLetter
            anchors.centerIn: parent
            width: 100
            height: 100

            // Ambient background glow
            Rectangle {
                id: centerGlow
                anchors.centerIn: parent
                width: 68
                height: 68
                radius: 34
                color: Theme.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25) : Qt.rgba(0, 0.94, 1, 0.25)
                opacity: 0.25
            }

            // Outer bold glow shadow text
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -5
                text: "C"
                font.family: Theme.font
                font.pixelSize: Theme.fontPx(76)
                font.bold: true
                color: Theme.accent ? Theme.accent : "#00F0FF"
            }

            // Crisp inner white specular highlight
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -5
                text: "C"
                font.family: Theme.font
                font.pixelSize: Theme.fontPx(76)
                font.bold: true
                color: "#FFFFFF"
                opacity: 0.45
            }
        }

        // Component template for an electron dot
        component ValenceDot: Item {
            id: vDot
            property real haloSize: 40
            property real coreSize: 24
            property real innerSize: 8

            width: haloSize + 4
            height: haloSize + 4

            // Glowing outer halo
            Rectangle {
                anchors.centerIn: parent
                width: vDot.haloSize
                height: vDot.haloSize
                radius: width / 2
                color: Theme.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45) : Qt.rgba(0, 0.94, 1, 0.45)
            }

            // Vibrant core dot
            Rectangle {
                anchors.centerIn: parent
                width: vDot.coreSize
                height: vDot.coreSize
                radius: width / 2
                color: "#FFFFFF"
                border.width: 2.2
                border.color: Theme.accent ? Theme.accent : "#00F0FF"

                // Inner bright neon center dot
                Rectangle {
                    anchors.centerIn: parent
                    width: vDot.innerSize
                    height: vDot.innerSize
                    radius: width / 2
                    color: Theme.accent ? Theme.accent : "#00F0FF"
                }
            }
        }

        /* ── Layer 1 Orbit Group: 2 Inner Atoms (Clockwise) ──────────────── */
        Item {
            id: innerOrbitGroup
            anchors.centerIn: parent
            width: 1
            height: 1
            rotation: 0

            // 1. Inner Top Dot: (0, -innerOrbitRadius)
            ValenceDot {
                id: innerDotTop
                haloSize: 32
                coreSize: 19
                innerSize: 6.5
                x: -width / 2
                y: -root.innerOrbitRadius - height / 2
            }

            // 2. Inner Bottom Dot: (0, +innerOrbitRadius)
            ValenceDot {
                id: innerDotBottom
                haloSize: 32
                coreSize: 19
                innerSize: 6.5
                x: -width / 2
                y: root.innerOrbitRadius - height / 2
            }
        }

        /* ── Layer 2 Orbit Group: 4 Outer Atoms (Counter-Clockwise) ──────── */
        Item {
            id: outerOrbitGroup
            anchors.centerIn: parent
            width: 1
            height: 1
            rotation: 0

            // 3. Outer Top Dot: (0, -outerOrbitRadius)
            ValenceDot {
                id: dotTop
                haloSize: 40
                coreSize: 24
                innerSize: 8
                x: -width / 2
                y: -root.outerOrbitRadius - height / 2
            }

            // 4. Outer Bottom Dot: (0, +outerOrbitRadius)
            ValenceDot {
                id: dotBottom
                haloSize: 40
                coreSize: 24
                innerSize: 8
                x: -width / 2
                y: root.outerOrbitRadius - height / 2
            }

            // 5. Outer Left Dot: (-outerOrbitRadius, 0)
            ValenceDot {
                id: dotLeft
                haloSize: 40
                coreSize: 24
                innerSize: 8
                x: -root.outerOrbitRadius - width / 2
                y: -height / 2
            }

            // 6. Outer Right Dot: (+outerOrbitRadius, 0)
            ValenceDot {
                id: dotRight
                haloSize: 40
                coreSize: 24
                innerSize: 8
                x: root.outerOrbitRadius - width / 2
                y: -height / 2
            }
        }
    }
}

