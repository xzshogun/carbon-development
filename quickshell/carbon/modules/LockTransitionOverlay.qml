import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../Singletons"
import "lock"

/**
 * LockTransitionOverlay.qml
 *
 * Fullscreen item inside overlay PanelWindow providing the seamless desktop-to-lock
 * (0-780ms pre-roll) and post-unlock (900-1250ms bloom) transition timeline.
 */
Item {
    id: root
    anchors.fill: parent

    readonly property string phase: LockTransition.phase
    readonly property real t: LockTransition.t
    readonly property real u: LockTransition.u
    visible: root.phase === "post_unlock" || (root.phase === "unlocking" && root.u >= 800.0) || (!LockTransition.lockSync && root.phase === "locking")

    opacity: {
        if (root.phase === "locking") {
            return 1.0 // Stays at 1.0 throughout entire lock sequence; handoff occurs seamlessly to WlSessionLock
        } else if (root.phase === "post_unlock" || root.phase === "unlocking") {
            // Holds wallpaper and fades out smoothly over 550ms after unlock handoff (1250-1800ms)
            if (root.u < 1250.0) return 1.0
            var p = Math.max(0.0, Math.min(1.0, (root.u - 1250.0) / 550.0))
            return Math.max(0.0, 1.0 - root.easeInOutCubic(p))
        }
        return 0.0
    }

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property real screenDiag: Math.sqrt(root.width * root.width + root.height * root.height)
    readonly property real centerX: root.width / 2
    readonly property real centerY: root.height / 2 - 20

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

    /* ── 1. Screenshot Background (Sharp & Single Shared Blurred Layer) ── */
    Item {
        anchors.fill: parent

        // Solid background base (guarantees opacity before first texture frame)
        Rectangle {
            anchors.fill: parent
            color: "#050508"
            z: -1
        }

        // Base sharp wallpaper
        Image {
            id: sharpSnap
            anchors.fill: parent
            source: "file://" + root.homeDir + "/.cache/carbon/wallpaper_scaled.jpg"
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: false
            opacity: 1.0
        }

        // Blurred + Dimmed Layer revealed through expanding radial mask (t = 400ms -> 1350ms)
        Item {
            id: blurredLayer
            anchors.fill: parent
            visible: !LockTransition.lockSync && root.phase === "locking" && root.t >= 400.0
            opacity: {
                if (root.phase === "locking") {
                    if (root.t < 400.0) return 0.0
                    return Math.min(1.0, (root.t - 400.0) / 120.0)
                }
                return 1.0
            }

            Image {
                id: blurredSnap
                anchors.fill: parent
                source: sharpSnap.source
                fillMode: Image.PreserveAspectCrop
                cache: false

                // Unified single-pass MultiEffect: performs blur AND radial mask in ONE pass!
                layer.enabled: true
                layer.effect: MultiEffect {
                    autoPaddingEnabled: false
                    blurEnabled: true
                    blur: 1.0
                    blurMax: 36
                    blurMultiplier: 1.0
                    maskEnabled: root.phase === "locking"
                    maskSource: blurMaskItem
                    maskSpreadAtMin: 0.25
                }
            }

            // 0.50 dark dim
            Rectangle {
                anchors.fill: parent
                color: "#050508"
                opacity: 0.50
                layer.enabled: root.phase === "locking"
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: blurMaskItem
                    maskSpreadAtMin: 0.25
                }
            }
        }
    }

    // Radial Mask item for soft edge expanding gracefully (400ms -> 1350ms)
    Item {
        id: blurMaskItem
        anchors.fill: parent
        visible: false

        readonly property real p: Math.max(0.0, Math.min(1.0, (root.t - 400.0) / 950.0))
        readonly property real currentRadius: root.easeInOutCubic(p) * 0.58 * root.screenDiag

        Rectangle {
            x: root.centerX - blurMaskItem.currentRadius
            y: root.centerY - blurMaskItem.currentRadius
            width: blurMaskItem.currentRadius * 2
            height: blurMaskItem.currentRadius * 2
            radius: blurMaskItem.currentRadius
            color: "#FFFFFF"
        }
    }

    // Shockwave Ring riding the radial front (t = 400-1400ms)
    Item {
        anchors.fill: parent
        visible: root.phase === "locking" && root.t >= 400.0 && root.t <= 1400.0

        readonly property real p: Math.max(0.0, Math.min(1.0, (root.t - 400.0) / 950.0))
        readonly property real currentRadius: root.easeInOutCubic(p) * 0.58 * root.screenDiag
        readonly property real shockAlpha: Math.max(0.0, 0.60 * (1.0 - p))

        // Soft halo (7px)
        Rectangle {
            x: root.centerX - parent.currentRadius - 3.5
            y: root.centerY - parent.currentRadius - 3.5
            width: (parent.currentRadius + 3.5) * 2
            height: (parent.currentRadius + 3.5) * 2
            radius: parent.currentRadius + 3.5
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, parent.shockAlpha * 0.35)
            border.width: 7.0
        }

        // Crisp white ring (1.6px)
        Rectangle {
            x: root.centerX - parent.currentRadius
            y: root.centerY - parent.currentRadius
            width: parent.currentRadius * 2
            height: parent.currentRadius * 2
            radius: parent.currentRadius
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, parent.shockAlpha)
            border.width: 1.6
        }
    }

    /* ── 2. Center Hub & Atomic Transition Assembly ── */
    Item {
        id: centerAssembly
        visible: !LockTransition.lockSync && root.phase === "locking"
        x: root.centerX
        y: root.centerY
        width: 1
        height: 1

        // A. Hub 4 Satellites Implosion (t = 0-380ms) & Swirl Out (u = 850-1300ms)
        Item {
            id: hubSatellitesGroup
            visible: {
                if (root.phase === "locking") return root.t < 420.0
                if (root.phase === "post_unlock" || root.phase === "unlocking") return root.u >= 850.0
                return false
            }

            readonly property real satProgress: {
                if (root.phase === "locking") return Math.max(0.0, Math.min(1.0, root.t / 380.0))
                if (root.phase === "post_unlock" || root.phase === "unlocking") {
                    var up = Math.max(0.0, Math.min(1.0, (root.u - 850.0) / 450.0))
                    return 1.0 - root.easeOutCubic(up)
                }
                return 1.0
            }
            readonly property real satEase: root.easeInCubic(satProgress)
            readonly property real satRadius: 54.0 * (1.0 - satEase)
            readonly property real satAngleOffset: 2.2 * satEase
            readonly property real satAlpha: Math.max(0.0, 1.0 - satEase)

            Repeater {
                model: [
                    { baseAngle: -0.85, color: "#00F0FF" },
                    { baseAngle: 0.35,  color: "#A6E3A1" },
                    { baseAngle: 2.35,  color: "#F9E2AF" },
                    { baseAngle: 3.55,  color: "#CBA6F7" }
                ]

                Item {
                    required property var modelData
                    required property int index

                    // 3 Ghost trails at 22ms spacing
                    Repeater {
                        model: 3
                        Item {
                            required property int index
                            readonly property real trailDelay: (index + 1) * 22.0
                            readonly property real trailT: Math.max(0.0, root.t - trailDelay)
                            readonly property real trailP: Math.max(0.0, Math.min(1.0, trailT / 380.0))
                            readonly property real trailEase: root.easeInCubic(trailP)
                            readonly property real trailR: 54.0 * (1.0 - trailEase)
                            readonly property real trailA: modelData.baseAngle + 2.2 * trailEase

                            x: Math.cos(trailA) * trailR - 6
                            y: Math.sin(trailA) * trailR - 6
                            width: 12
                            height: 12
                            opacity: (root.phase === "locking" && root.t <= 380.0) ? (0.25 * hubSatellitesGroup.satAlpha) : 0.0

                            Rectangle {
                                anchors.fill: parent
                                radius: 6
                                color: modelData.color
                            }
                        }
                    }

                    // Satellite orb
                    Item {
                        readonly property real curAngle: modelData.baseAngle + hubSatellitesGroup.satAngleOffset
                        x: Math.cos(curAngle) * hubSatellitesGroup.satRadius - 7
                        y: Math.sin(curAngle) * hubSatellitesGroup.satRadius - 7
                        width: 14
                        height: 14
                        opacity: hubSatellitesGroup.satAlpha

                        Rectangle {
                            anchors.fill: parent
                            radius: 7
                            color: modelData.color
                            border.color: "#FFFFFF"
                            border.width: 1.2
                        }
                    }
                }
            }
        }

        // B. Desktop Clock Disc Shrink (t = 200-420ms) & Growth (u = 850-1200ms)
        Item {
            id: clockDiscGroup
            visible: {
                if (root.phase === "locking") return root.t < 450.0
                if (root.phase === "post_unlock" || root.phase === "unlocking") return root.u >= 850.0
                return false
            }

            readonly property real clkP: {
                if (root.phase === "locking") {
                    return Math.max(0.0, Math.min(1.0, (root.t - 200.0) / 220.0))
                } else {
                    var up = Math.max(0.0, Math.min(1.0, (root.u - 850.0) / 350.0))
                    return 1.0 - root.easeOutCubic(up)
                }
            }
            readonly property real clkRadius: 22.0 * (1.0 - root.easeInCubic(clkP))

            // Disc & Halo
            Rectangle {
                anchors.centerIn: parent
                width: clockDiscGroup.clkRadius * 2
                height: width
                radius: clockDiscGroup.clkRadius
                color: "#16161E"
                border.color: Theme.accent ? Theme.accent : "#00F0FF"
                border.width: 1.5
                opacity: clockDiscGroup.clkRadius > 1.0 ? 1.0 : 0.0
            }

            // Flash Disc (at t = 380-720ms expanding to 40px, or u = 850ms to 34px)
            Rectangle {
                anchors.centerIn: parent
                readonly property real flashP: {
                    if (root.phase === "locking") return Math.max(0.0, Math.min(1.0, (root.t - 380.0) / 340.0))
                    return Math.max(0.0, Math.min(1.0, (root.u - 850.0) / 350.0))
                }
                width: (root.phase === "locking" ? 44.0 : 34.0) * root.easeOutCubic(flashP)
                height: width
                radius: width / 2
                color: "#FFFFFF"
                opacity: (root.phase === "locking" ? 0.80 : 0.60) * (1.0 - flashP)
                visible: (root.phase === "locking" && root.t >= 380.0 && root.t <= 720.0) ||
                         ((root.phase === "post_unlock" || root.phase === "unlocking") && root.u >= 850.0 && root.u <= 1200.0)
            }
        }

        // C. Unified Bohr Atom (Identical to LockSurface)
        UnifiedCarbonAtom {
            anchors.centerIn: parent
            width: 120
            height: 120
        }
    }

    /* ── 3. Widgets Bezier Flight Preview (t = 700-1400ms) ── */
    // Quadratic Bezier function: P0 (center), P2 (target), P1 (ctrl: 20% in x, 85% in y)
    function bezierPoint(p0, p2, progress) {
        var p1 = p0 + (progress < 0.5 ? 0.20 : 0.85) * (p2 - p0)
        var s = progress
        return (1.0 - s) * (1.0 - s) * p0 + 2.0 * (1.0 - s) * s * p1 + s * s * p2
    }

    // A. Clock widget in flight (t = 700-1300ms)
    Item {
        visible: !LockTransition.lockSync && root.phase === "locking" && root.t >= 700.0 && root.t <= 1400.0
        readonly property real p: Math.max(0.0, Math.min(1.0, (root.t - 700.0) / 600.0))
        readonly property real endX: root.width - 220
        readonly property real endY: root.height - 120
        x: root.bezierPoint(root.centerX, endX, p)
        y: root.bezierPoint(root.centerY, endY, p)
        opacity: p

        Text {
            text: Qt.formatTime(new Date(), "hh:mm")
            font.family: Theme.font
            font.pixelSize: Theme.fontPx(38)
            font.bold: true
            color: "#FFFFFF"
        }
    }

    // B. Media Card widget in flight (t = 850-1400ms)
    Item {
        visible: !LockTransition.lockSync && root.phase === "locking" && root.t >= 850.0 && root.t <= 1400.0
        readonly property real p: Math.max(0.0, Math.min(1.0, (root.t - 850.0) / 550.0))
        readonly property real endX: 36
        readonly property real endY: root.height - 122
        x: root.bezierPoint(root.centerX, endX, p)
        y: root.bezierPoint(root.centerY, endY, p)
        scale: 0.35 + 0.65 * p
        opacity: p

        Rectangle {
            width: 280
            height: 64
            radius: 16
            color: Qt.rgba(0.08, 0.08, 0.12, 0.85)
            border.color: Theme.accent ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4) : Qt.rgba(0, 0.94, 1, 0.4)
            border.width: 1.2
        }
    }
}

