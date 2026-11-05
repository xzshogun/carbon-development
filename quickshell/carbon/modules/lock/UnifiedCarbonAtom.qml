import QtQuick
import QtQuick.Shapes
import "../../Singletons"

/**
 * UnifiedCarbonAtom:
 * The single source of truth for the Carbon Bohr atom across both
 * LockTransitionOverlay (desktop overlay) and LockSurface (session lock).
 *
 * Geometry & Visual Specs:
 *   - Orbits: Inner K-shell r = 24px (2 electrons), Outer L-shell r = 38px (4 electrons)
 *   - Seal Ring: r = 50px (strokeWidth: 1.8)
 *   - Central Glyph: "C" in Theme.accent / #00F0FF (bold, pixelSize: Theme.fontPx(32))
 *   - Flash Disc: expanding white core (r up to 40px)
 *   - Pulse Rings: shockwaves expanding outward at key transition stamps
 *   - Rotation: continuous rotation driven by continuous time (0.0004 rad/ms)
 */
Item {
    id: atomRoot

    implicitWidth: 120
    implicitHeight: 120

    // Drives: reads from LockTransition singleton
    readonly property string phase: LockTransition.phase
    readonly property real t: LockTransition.t
    readonly property real u: LockTransition.u

    function easeInCubic(p) {
        return Math.pow(Math.max(0.0, Math.min(1.0, p)), 3.0)
    }

    function easeOutCubic(p) {
        var x = Math.max(0.0, Math.min(1.0, p))
        return 1.0 - Math.pow(1.0 - x, 3.0)
    }

    function easeInOutCubic(p) {
        var x = Math.max(0.0, Math.min(1.0, p))
        return x < 0.5 ? 4.0 * x * x * x : 1.0 - Math.pow(-2.0 * x + 2.0, 3.0) / 2.0
    }

    // Continuous rotation time tracker
    property real continuousTime: 0.0
    FrameAnimation {
        running: atomRoot.visible && (atomRoot.opacity > 0.001)
        onTriggered: {
            atomRoot.continuousTime += 16.67
        }
    }

    /* ── A. Flash Disc (at t = 380-720ms to 40px, or u = 850-1200ms to 34px) ── */
    Rectangle {
        anchors.centerIn: parent
        readonly property real flashP: {
            if (atomRoot.phase === "locking") return Math.max(0.0, Math.min(1.0, (atomRoot.t - 380.0) / 340.0))
            if (atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") {
                return Math.max(0.0, Math.min(1.0, (atomRoot.u - 850.0) / 350.0))
            }
            return 0.0
        }
        width: (atomRoot.phase === "locking" ? 44.0 : 34.0) * atomRoot.easeOutCubic(flashP)
        height: width
        radius: width / 2
        color: "#FFFFFF"
        opacity: (atomRoot.phase === "locking" ? 0.80 : 0.60) * (1.0 - flashP)
        visible: (atomRoot.phase === "locking" && atomRoot.t >= 380.0 && atomRoot.t <= 720.0) ||
                 ((atomRoot.phase === "post_unlock" || atomRoot.phase === "unlocking") && atomRoot.u >= 850.0 && atomRoot.u <= 1200.0)
    }

    /* ── B. Orbital Guides (Faint rings r=24 and r=38) ── */
    Item {
        anchors.centerIn: parent
        width: 1
        height: 1
        visible: (atomRoot.phase === "locking" && atomRoot.t >= 440.0) ||
                 (atomRoot.phase === "locked") ||
                 ((atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") && atomRoot.u <= 950.0)

        readonly property real guideAlpha: {
            if (atomRoot.phase === "locking") {
                var p = Math.max(0.0, Math.min(1.0, (atomRoot.t - 440.0) / 450.0))
                return atomRoot.easeOutCubic(p) * 0.15
            }
            if (atomRoot.phase === "locked") return 0.15
            if (atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") {
                var p2 = Math.max(0.0, Math.min(1.0, (atomRoot.u - 600.0) / 350.0))
                return (1.0 - atomRoot.easeInCubic(p2)) * 0.15
            }
            return 0.0
        }

        // Inner orbit guide r=24
        Rectangle {
            anchors.centerIn: parent
            width: 48
            height: 48
            radius: 24
            color: "transparent"
            border.color: "#FFFFFF"
            border.width: 1.0
            opacity: parent.guideAlpha
        }

        // Outer orbit guide r=38
        Rectangle {
            anchors.centerIn: parent
            width: 76
            height: 76
            radius: 38
            color: "transparent"
            border.color: "#FFFFFF"
            border.width: 1.0
            opacity: parent.guideAlpha
        }
    }

    /* ── C. Central "C" Glyph ── */
    Text {
        id: atomLetter
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text: "C"
        font.family: Theme.font
        font.pixelSize: Theme.fontPx(24)
        font.bold: true
        color: "#FFFFFF"

        readonly property real cPopP: Math.max(0.0, Math.min(1.0, (atomRoot.t - 420.0) / 360.0))
        readonly property real cFadeP: Math.max(0.0, Math.min(1.0, (atomRoot.u - 650.0) / 300.0))

        scale: {
            if (atomRoot.phase === "locking") {
                if (atomRoot.t < 420.0) return 0.0
                return 1.5 - 0.5 * atomRoot.easeOutCubic(cPopP)
            } else if (atomRoot.phase === "locked") {
                return 1.0
            } else if (atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") {
                if (atomRoot.u < 650.0) return 1.0
                return 1.0 - 0.4 * atomRoot.easeInCubic(cFadeP) // 1.0 -> 0.6
            }
            return 0.0
        }

        opacity: {
            if (atomRoot.phase === "locking") {
                if (atomRoot.t < 420.0) return 0.0
                return atomRoot.easeOutCubic(cPopP)
            } else if (atomRoot.phase === "locked") {
                return 1.0
            } else if (atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") {
                if (atomRoot.u < 650.0) return 1.0
                return Math.max(0.0, 1.0 - atomRoot.easeInCubic(cFadeP))
            }
            return 0.0
        }
    }

    /* ── D. Seal Ring (r = 50px, stroke: 1.8px) ── */
    Item {
        id: sealRingGroup
        anchors.centerIn: parent
        width: 100
        height: 100
        visible: (atomRoot.phase === "locking" && atomRoot.t >= 440.0) ||
                 (atomRoot.phase === "locked") ||
                 ((atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") && atomRoot.u <= 750.0)

        readonly property real sweepP: {
            if (atomRoot.phase === "locking") {
                var p = Math.max(0.0, Math.min(1.0, (atomRoot.t - 440.0) / 450.0))
                return atomRoot.easeOutCubic(p)
            }
            if (atomRoot.phase === "locked") return 1.0
            if (atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") {
                var up = Math.max(0.0, Math.min(1.0, (atomRoot.u - 400.0) / 350.0))
                return 1.0 - atomRoot.easeOutCubic(up)
            }
            return 0.0
        }

        readonly property real ringOpacity: {
            if (atomRoot.phase === "locking") {
                return atomRoot.t < 890.0 ? 1.0 : (1.0 - 0.78 * Math.min(1.0, (atomRoot.t - 890.0) / 300.0))
            }
            if (atomRoot.phase === "locked") return 0.22
            if (atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") {
                return (sweepP > 0.01 && sweepP < 0.99) ? 1.0 : 0.22
            }
            return 0.22
        }

        Shape {
            anchors.fill: parent
            layer.enabled: true
            ShapePath {
                strokeColor: Theme.accent ? Theme.accent : "#00F0FF"
                strokeWidth: 1.8
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                startX: 50
                startY: 0

                PathAngleArc {
                    centerX: 50
                    centerY: 50
                    radiusX: 50
                    radiusY: 50
                    startAngle: -90
                    sweepAngle: 360 * sealRingGroup.sweepP
                }
            }
            opacity: sealRingGroup.ringOpacity
        }

        // Pulse Ring on Lock finish (at t = 890ms: radius 50 -> 74, alpha 0.5 -> 0, 450ms)
        Rectangle {
            anchors.centerIn: parent
            readonly property real pulseP: Math.max(0.0, Math.min(1.0, (atomRoot.t - 890.0) / 450.0))
            width: (50.0 + 24.0 * pulseP) * 2
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Theme.accent ? Theme.accent : "#00F0FF"
            border.width: 1.6
            opacity: 0.50 * (1.0 - pulseP)
            visible: atomRoot.phase === "locking" && atomRoot.t >= 890.0 && atomRoot.t <= 1340.0
        }

        // Pulse Ring on Unlock start (at u = 300ms: radius 30 -> 64, alpha 0.5 -> 0, 350ms)
        Rectangle {
            anchors.centerIn: parent
            readonly property real unlockPulseP: Math.max(0.0, Math.min(1.0, (atomRoot.u - 300.0) / 350.0))
            width: (30.0 + 34.0 * unlockPulseP) * 2
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Theme.accent ? Theme.accent : "#00F0FF"
            border.width: 1.6
            opacity: 0.50 * (1.0 - unlockPulseP)
            visible: (atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") && atomRoot.u >= 300.0 && atomRoot.u <= 650.0
        }
    }

    /* ── E. 6 Electrons Burst & Orbits (inner r=24, outer r=38, rotation 0.0004 rad/ms) ── */
    Item {
        id: electronsGroup
        anchors.centerIn: parent
        width: 1
        height: 1
        visible: (atomRoot.phase === "locking" && atomRoot.t >= 440.0) ||
                 (atomRoot.phase === "locked") ||
                 ((atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") && atomRoot.u <= 950.0)

        readonly property real burstP: Math.max(0.0, Math.min(1.0, (atomRoot.t - 440.0) / 450.0))
        readonly property real drainP: Math.max(0.0, Math.min(1.0, (atomRoot.u - 550.0) / 350.0))

        readonly property real orbitScale: {
            if (atomRoot.phase === "locking") return atomRoot.easeOutCubic(burstP)
            if (atomRoot.phase === "locked") return 1.0
            if (atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") {
                return 1.0 - atomRoot.easeInCubic(drainP)
            }
            return 1.0
        }
        readonly property real swirlOffset: {
            if (atomRoot.phase === "locking") return 2.0 * (1.0 - burstP)
            if (atomRoot.phase === "locked") return 0.0
            if (atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") {
                return -2.0 * atomRoot.easeInCubic(drainP)
            }
            return 0.0
        }
        readonly property real electronAlpha: {
            if (atomRoot.phase === "locking") return burstP
            if (atomRoot.phase === "locked") return 1.0
            if (atomRoot.phase === "unlocking" || atomRoot.phase === "post_unlock") {
                return 1.0 - drainP
            }
            return 1.0
        }

        readonly property real ang: atomRoot.continuousTime * 0.0004
        readonly property real innerRot: swirlOffset + ang
        readonly property real outerRot: -swirlOffset - ang * 0.70

        // 2 Inner electrons (radius 24)
        Repeater {
            model: [0, Math.PI]
            Rectangle {
                required property real modelData
                readonly property real angle: modelData + electronsGroup.innerRot
                readonly property real r: 24.0 * electronsGroup.orbitScale
                x: Math.cos(angle) * r - 3
                y: Math.sin(angle) * r - 3
                width: 6
                height: 6
                radius: 3
                color: "#FFFFFF"
                opacity: electronsGroup.electronAlpha
            }
        }

        // 4 Outer electrons (radius 38)
        Repeater {
            model: [0, Math.PI / 2, Math.PI, 3 * Math.PI / 2]
            Rectangle {
                required property real modelData
                readonly property real angle: modelData + electronsGroup.outerRot
                readonly property real r: 38.0 * electronsGroup.orbitScale
                x: Math.cos(angle) * r - 3.5
                y: Math.sin(angle) * r - 3.5
                width: 7
                height: 7
                radius: 3.5
                color: "#FFFFFF"
                opacity: electronsGroup.electronAlpha
            }
        }
    }
}
