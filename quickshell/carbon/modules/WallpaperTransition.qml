import QtQuick
import Quickshell
import M3Shapes
import "../Singletons"

/**
 * WallpaperTransition: Fullscreen blurred overlay with the exact fluid morphing
 * MaterialShape transition from the reference video (0:13).
 * When applying wallpapers:
 *   - The screen smoothly blurs and darkens into a frosted veil.
 *   - A solid MaterialShape appears in the center and continuously morphs across
 *     expressive shapes (Cookie12Sided, Pentagon, Cookie9Sided, SoftBurst, Flower, Sunny, Clover4Leaf)
 *     with gentle rotation and subtle organic pulsing.
 *   - As new colors are generated from the wallpaper, the shape's color smoothly transitions.
 *   - When the wallpaper completes, the shape scales down to 0 and the blur dissolves,
 *     revealing the new desktop wallpaper.
 */
Item {
    id: root

    property bool active: false
    property bool pendingFinish: false
    property string statusText: ""
    property real minDurationMs: 900
    property real startTime: 0

    readonly property bool isExiting: finishSignalTimer.running

    signal finished()

    focus: root.active

    readonly property var shapes: [
        MaterialShape.Cookie12Sided,
        MaterialShape.Pentagon,
        MaterialShape.Cookie9Sided,
        MaterialShape.SoftBurst,
        MaterialShape.Flower,
        MaterialShape.Sunny,
        MaterialShape.Clover4Leaf
    ]
    property int currentShapeIndex: 0

    onActiveChanged: {
        if (active) {
            root.startTime = Date.now()
            root.currentShapeIndex = 0
            exitTimer.stop()
            finishSignalTimer.stop()
            morphTimer.restart()
        } else {
            morphTimer.stop()
        }
    }

    onPendingFinishChanged: {
        if (pendingFinish && active) {
            const elapsed = Date.now() - root.startTime
            if (elapsed < root.minDurationMs) {
                exitTimer.interval = Math.max(50, root.minDurationMs - elapsed)
                exitTimer.restart()
            } else {
                doExit()
            }
        }
    }

    function doExit() {
        finishSignalTimer.restart()
    }

    Timer {
        id: exitTimer
        repeat: false
        onTriggered: root.doExit()
    }

    Timer {
        id: finishSignalTimer
        interval: 350
        repeat: false
        onTriggered: {
            root.finished()
        }
    }

    Timer {
        id: morphTimer
        interval: 600
        repeat: true
        running: root.active && !root.isExiting
        onTriggered: {
            root.currentShapeIndex = (root.currentShapeIndex + 1) % root.shapes.length
        }
    }

    /* ── Fullscreen Frosted Dark Tint Backdrop ────────────────────────── */
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Qt.rgba(0.02, 0.03, 0.05, 0.52)
        opacity: (root.active && !root.isExiting) ? 1.0 : 0.0
        Behavior on opacity {
            NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
        }
    }

    /* ── Center Morphing MaterialShape (0:13 Video Reference) ─────────── */
    Item {
        id: centerAnchor
        anchors.centerIn: parent
        width: 84
        height: 84

        opacity: (root.active && !root.isExiting) ? 1.0 : 0.0
        scale: (root.active && !root.isExiting) ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation {
                duration: (root.active && !root.isExiting) ? 380 : 250
                easing.type: (root.active && !root.isExiting) ? Easing.OutBack : Easing.InBack
                easing.overshoot: 1.35
            }
        }

        MaterialShape {
            id: morphingShape
            anchors.centerIn: parent
            width: 80
            height: 80
            shape: root.shapes[root.currentShapeIndex]
            color: Theme.accent
            animationDuration: 520
            animationEasing: Easing.InOutCubic

            Behavior on color {
                ColorAnimation { duration: 400; easing.type: Easing.InOutQuad }
            }

            RotationAnimation on rotation {
                from: 0
                to: 360
                duration: 6500
                loops: Animation.Infinite
                running: root.active
            }

            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: root.active && !root.isExiting
                NumberAnimation { from: 0.94; to: 1.05; duration: 850; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.05; to: 0.94; duration: 850; easing.type: Easing.InOutSine }
            }
        }
    }
}
