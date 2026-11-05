import QtQuick
import "../Singletons"

/**
 * CarbonLewisWallpaper:
 * Recreates the exact Bohr Atomic Model of Carbon (atomic number 6)
 * from the lockscreen (CarbonLewisLogo), rendered with scalable dimensions
 * and full Dark/Light theme adaptability.
 *
 * Dark Mode: Pure white glyph, dots, rings & shockwaves on #000000.
 * Light Mode: Pure black glyph, dots, rings & shockwaves on #FFFFFF.
 */
Item {
    id: root

    // Dark/Light toggle
    property bool isLight: false

    // Scaled-up orbital radii (substantially bigger than lockscreen as requested)
    property real innerOrbitRadius: 82
    property real outerOrbitRadius: 145

    // Color definitions based on mode
    property color glyphColor: isLight ? "#000000" : "#FFFFFF"
    property color specularColor: isLight ? "#333333" : "#FFFFFF"
    property color centerGlowColor: isLight ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(1, 1, 1, 0.25)
    property color innerRingColor: isLight ? Qt.rgba(0, 0, 0, 0.28) : Qt.rgba(1, 1, 1, 0.32)
    property color outerRingColor: isLight ? Qt.rgba(0, 0, 0, 0.24) : Qt.rgba(1, 1, 1, 0.28)
    property color impactColor: isLight ? "#000000" : "#FFFFFF"

    property color dotHaloColor: isLight ? Qt.rgba(0, 0, 0, 0.18) : Qt.rgba(1, 1, 1, 0.45)
    property color dotCoreBorderColor: isLight ? "#000000" : "#FFFFFF"
    property color dotCoreFillColor: isLight ? "#000000" : "#FFFFFF"
    property color dotInnerColor: isLight ? "#FFFFFF" : "#FFFFFF"

    implicitWidth: outerOrbitRadius * 2 + 160
    implicitHeight: outerOrbitRadius * 2 + 160

    readonly property bool shouldAnimate: root.visible && (root.opacity > 0.01)

    /* ── Ambient Idle Breathing Glow ─────────────────────────────────────── */
    SequentialAnimation {
        id: idleAnim
        running: root.shouldAnimate
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
    SequentialAnimation {
        id: periodicPulseAnim
        running: root.shouldAnimate
        loops: Animation.Infinite

        ParallelAnimation {
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

        PauseAnimation { duration: 1100 }
    }

    /* ── Non-Simultaneous Independent Revolutions (Bohr Atom Dynamics) ────── */
    FrameAnimation {
        running: root.shouldAnimate
        onTriggered: {
            innerOrbitGroup.rotation += frameTime * (360.0 / 5.8)
            outerOrbitGroup.rotation -= frameTime * (360.0 / 9.4)
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
            border.color: root.innerRingColor
            border.width: 1.8
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
            border.color: root.outerRingColor
            border.width: 2.0
            opacity: 0.35
        }

        // Ripple ring on recurring periodic heartbeat pulse
        Rectangle {
            id: impactRing
            anchors.centerIn: parent
            width: root.outerOrbitRadius * 2
            height: root.outerOrbitRadius * 2
            radius: root.outerOrbitRadius
            color: "transparent"
            border.color: root.impactColor
            border.width: 3.2
            opacity: 0.0
            scale: 0.25
        }

        // Central "C" Letter centered precisely at (0, 0)
        Item {
            id: centerLetter
            anchors.centerIn: parent
            width: 140
            height: 140

            // Ambient background glow
            Rectangle {
                id: centerGlow
                anchors.centerIn: parent
                width: 96
                height: 96
                radius: 48
                color: root.centerGlowColor
                opacity: 0.25
            }

            // Outer bold text
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -6
                text: "C"
                font.family: Theme.font
                font.pixelSize: Theme.fontPx(104)
                font.bold: true
                color: root.glyphColor
            }

            // Specular highlight text
            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -6
                text: "C"
                font.family: Theme.font
                font.pixelSize: Theme.fontPx(104)
                font.bold: true
                color: root.specularColor
                opacity: 0.40
            }
        }

        // Component template for an electron dot
        component ValenceDot: Item {
            id: vDot
            property real haloSize: 56
            property real coreSize: 34
            property real innerSize: 11.5

            width: haloSize + 4
            height: haloSize + 4

            // Glowing outer halo
            Rectangle {
                anchors.centerIn: parent
                width: vDot.haloSize
                height: vDot.haloSize
                radius: width / 2
                color: root.dotHaloColor
            }

            // Vibrant core dot
            Rectangle {
                anchors.centerIn: parent
                width: vDot.coreSize
                height: vDot.coreSize
                radius: width / 2
                color: root.dotCoreFillColor
                border.width: 2.5
                border.color: root.dotCoreBorderColor

                // Inner contrast center dot
                Rectangle {
                    anchors.centerIn: parent
                    width: vDot.innerSize
                    height: vDot.innerSize
                    radius: width / 2
                    color: root.dotInnerColor
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
                haloSize: 46
                coreSize: 28
                innerSize: 9.5
                x: -width / 2
                y: -root.innerOrbitRadius - height / 2
            }

            // 2. Inner Bottom Dot: (0, +innerOrbitRadius)
            ValenceDot {
                id: innerDotBottom
                haloSize: 46
                coreSize: 28
                innerSize: 9.5
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
                haloSize: 56
                coreSize: 34
                innerSize: 11.5
                x: -width / 2
                y: -root.outerOrbitRadius - height / 2
            }

            // 4. Outer Bottom Dot: (0, +outerOrbitRadius)
            ValenceDot {
                id: dotBottom
                haloSize: 56
                coreSize: 34
                innerSize: 11.5
                x: -width / 2
                y: root.outerOrbitRadius - height / 2
            }

            // 5. Outer Left Dot: (-outerOrbitRadius, 0)
            ValenceDot {
                id: dotLeft
                haloSize: 56
                coreSize: 34
                innerSize: 11.5
                x: -root.outerOrbitRadius - width / 2
                y: -height / 2
            }

            // 6. Outer Right Dot: (+outerOrbitRadius, 0)
            ValenceDot {
                id: dotRight
                haloSize: 56
                coreSize: 34
                innerSize: 11.5
                x: root.outerOrbitRadius - width / 2
                y: -height / 2
            }
        }
    }
}
