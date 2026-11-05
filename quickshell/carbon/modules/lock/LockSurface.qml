import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../Singletons"

/**
 * LockSurface:
 * Fullscreen WlSessionLockSurface that serves as the single stage for
 * both lock and unlock transitions (lock-first architecture).
 *
 * Implements:
 * 1. Sharp wallpaper + pre-blurred cached texture cross-fade with 1.0 -> 1.1 scale.
 * 2. Dim layer (rgba(6,8,12, 0.34)) underneath all UI and visualizer.
 * 3. Seamless desktop resting nucleus handoff:
 *    - 62px disc with HH:mm and shockwave ring at t=0
 *    - Shrinks to 0.677 into the Carbon logo nucleus position
 *    - Logo appears at 300ms and plays full vector intro
 *    - On unlock: logo exits, disc springs back 0.677 -> 1.0 at u=1300ms
 * 4. Password card opening pill (46px circle -> 312px) and check mark morph.
 * 5. Clock and media card staggered entrances and resting positions.
 * 6. Top-edge Cava visualizer maintained at z: 100 with real-time audio pipeline.
 */
WlSessionLockSurface {
    id: root

    signal requestUnlock()
    signal requestUnlockFinish()
    property var sessionLock: null
    property var notificationServer: null
    readonly property string home: Quickshell.env("HOME") || ""

    color: "transparent"

    readonly property string phase: LockTransition.phase
    readonly property real t: LockTransition.t
    readonly property real u: LockTransition.u
    readonly property real centerX: root.width / 2
    readonly property real centerY: root.height / 2 - 20

    // Surface reveal progress: 1.0 during locking/locked; smoothly glides 1.0 -> 0.0 between u=1250ms and 1800ms to reveal underlying open apps
    readonly property real surfaceRevealProgress: {
        if (LockTransition.reducedMotion) return ((root.phase === "unlocking" || root.phase === "post_unlock") ? 0.0 : 1.0)
        if (root.phase === "unlocking" || root.phase === "post_unlock") {
            if (root.u < 1250.0) return 1.0
            var p = Math.max(0.0, Math.min(1.0, (root.u - 1250.0) / 550.0))
            return Math.max(0.0, 1.0 - root.easeInOutCubic(p))
        }
        return 1.0
    }

    function easeInCubic(p) {
        var x = Math.max(0.0, Math.min(1.0, p))
        return x * x * x
    }

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

    /* ── First-Frame Safety & Unlock Finalization ────────────────────────── */
    property bool firstFrameSeen: false
    property bool waitingUnlockFinalFrame: false

    FrameAnimation {
        id: surfaceFrameDriver
        running: true
        onTriggered: {
            if (!root.firstFrameSeen) {
                root.firstFrameSeen = true
                console.log("[LockSurface] First rendered frame detected -> starting lock transition")
                LockTransition.notifyLockSurfaceReady()
            }
            if (root.waitingUnlockFinalFrame) {
                root.waitingUnlockFinalFrame = false
                console.log("[LockSurface] Final unlock frame reached -> requesting session lock release")
                root.requestUnlockFinish()
            }
        }
    }

    Connections {
        target: LockTransition
        function onUnlockAnimationFinished() {
            root.waitingUnlockFinalFrame = true
        }
    }

    Component.onCompleted: {
        pwdCard.revealed = false
        pwdCard.forceActiveFocus()
    }

    function startUnlock() {
        LockTransition.startUnlock()
    }

    function testNotif() {
        notifOverlay.showToast("Test Notification", "Lock Screen Preview", "Notifications pop smoothly above the music overlay.")
    }

    function testNotifCenter() {
        notifOverlay.toggleCenter()
    }

    function testNotifClear() {
        notifOverlay.clearAll()
    }

    // Capture clicks anywhere on the lock screen to restore password card focus
    MouseArea {
        anchors.fill: parent
        onClicked: {
            pwdCard.forceActiveFocus()
        }
    }

    /* ── 1. Wallpaper Background (Sharp base + Pre-Blurred Cached Cross-Fade) ── */
    // Scale: 1.0 -> 1.1 over 1400ms at lock; 1.1 -> 1.0 over 1100ms at u=760ms
    readonly property real wpScaleProgress: Math.max(0.0, Math.min(1.0, root.t / 1400.0))
    readonly property real wpScaleUnlockProgress: Math.max(0.0, Math.min(1.0, (root.u - 760.0) / 1100.0))
    readonly property real wallpaperScale: {
        if (LockTransition.reducedMotion) return 1.0
        if (root.phase === "locking") {
            return 1.0 + 0.10 * root.easeOutCubic(root.wpScaleProgress)
        }
        if (root.phase === "unlocking" || root.phase === "post_unlock") {
            if (root.u < 760.0) return 1.10
            return 1.10 - 0.10 * root.easeOutCubic(root.wpScaleUnlockProgress)
        }
        if (root.phase === "locked") return 1.10
        return 1.0
    }

    // Blur & darken cross-fade: 0 -> 1 over 800ms at lock; 1 -> 0 over 1100ms at u=760ms
    readonly property real blurFadeLockProgress: Math.max(0.0, Math.min(1.0, root.t / 800.0))
    readonly property real blurFadeUnlockProgress: Math.max(0.0, Math.min(1.0, (root.u - 760.0) / 1100.0))
    readonly property real blurLayerOpacity: {
        if (LockTransition.reducedMotion) return (root.phase === "locked" ? 1.0 : 0.0)
        if (root.phase === "locking") return root.easeOutCubic(root.blurFadeLockProgress)
        if (root.phase === "unlocking" || root.phase === "post_unlock") {
            if (root.u < 760.0) return 1.0
            return Math.max(0.0, 1.0 - root.easeOutCubic(root.blurFadeUnlockProgress))
        }
        if (root.phase === "locked") return 1.0
        return 0.0
    }

    // Base background layer; fades out on unlock to smoothly reveal open desktop windows
    Rectangle {
        id: surfaceBaseBg
        anchors.fill: parent
        color: "#050508"
        z: -1
        opacity: root.surfaceRevealProgress
    }

    Item {
        id: wallpaperLayer
        anchors.fill: parent
        scale: root.wallpaperScale
        transformOrigin: Item.Center
        z: 0
        opacity: root.surfaceRevealProgress

        Image {
            id: bgSharp
            anchors.fill: parent
            source: "file://" + root.home + "/.cache/carbon/wallpaper_scaled.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
        }

        Image {
            id: bgBlurred
            anchors.fill: parent
            source: "file://" + root.home + "/.cache/carbon/wallpaper_blurred.jpg"
            fillMode: Image.PreserveAspectCrop
            asynchronous: false
            cache: true
            opacity: root.blurLayerOpacity
        }
    }

    // Dim layer (rgba(6,8,12, .34)) fades in over 1200ms; fades out over 1100ms at u=760ms
    Rectangle {
        id: dimLayer
        anchors.fill: parent
        color: "#06080c"
        z: 1
        opacity: {
            var baseDim = 0.0
            if (LockTransition.reducedMotion) baseDim = (root.phase === "locked" ? 0.34 : 0.0)
            else if (root.phase === "locking") {
                var p = Math.max(0.0, Math.min(1.0, root.t / 700.0))
                baseDim = 0.34 * root.easeOutCubic(p)
            } else if (root.phase === "unlocking" || root.phase === "post_unlock") {
                if (root.u < 760.0) baseDim = 0.34
                else {
                    var up = Math.max(0.0, Math.min(1.0, (root.u - 760.0) / 1100.0))
                    baseDim = Math.max(0.0, 0.34 * (1.0 - root.easeOutCubic(up)))
                }
            } else if (root.phase === "locked") baseDim = 0.34
            return baseDim * root.surfaceRevealProgress
        }
    }

    /* ── 2. Center Assembly: Desktop Nucleus Handoff & Carbon Logo ──────── */
    // Desktop resting nucleus: 62px circle with time text, shrinks to 0.677 onto logo center
    Item {
        id: desktopRestingNucleus
        x: root.centerX - 31
        y: root.centerY - 31
        width: 62
        height: 62
        z: 2
        visible: opacity > 0.001

        scale: {
            if (LockTransition.reducedMotion) return (root.phase === "locked" ? 0.0 : 1.0)
            if (root.phase === "locking") {
                var p = Math.max(0.0, Math.min(1.0, root.t / 320.0))
                return 1.0 - (1.0 - 0.677) * root.easeInOutCubic(p)
            }
            if (root.phase === "unlocking" || root.phase === "post_unlock") return 0.677
            if (root.phase === "locked") return 0.0
            return 1.0
        }

        opacity: {
            if (LockTransition.reducedMotion) return 0.0
            if (root.phase === "locking") {
                if (root.t < 120.0) return 1.0
                return Math.max(0.0, 1.0 - (root.t - 120.0) / 200.0)
            }
            if (root.phase === "unlocking" || root.phase === "post_unlock" || root.phase === "locked") return 0.0
            if (root.phase === "idle") return 1.0
            return 0.0
        }

        // Outer glow disc (r=44, diam 88, 8% opacity)
        Rectangle {
            anchors.centerIn: parent
            width: 88; height: 88; radius: 44
            color: Qt.rgba(1, 1, 1, 0.08)
            antialiasing: true
            smooth: true
        }

        // Mid glow disc (r=37, diam 74, 20% opacity)
        Rectangle {
            anchors.centerIn: parent
            width: 74; height: 74; radius: 37
            color: Qt.rgba(1, 1, 1, 0.20)
            antialiasing: true
            smooth: true
        }

        // Core white disc 62px
        Rectangle {
            anchors.fill: parent
            radius: 31
            color: "#FFFFFF"
            antialiasing: true
            smooth: true

            Text {
                id: nucTimeText
                anchors.centerIn: parent
                text: Qt.formatTime(new Date(), "hh:mm")
                font.family: "Google Sans Flex"
                font.pixelSize: 15
                font.weight: Font.ExtraBold
                color: "#0c0f12"
                opacity: {
                    if (root.phase === "locking") return Math.max(0.0, 1.0 - root.t / 160.0)
                    if (root.phase === "unlocking" || root.phase === "post_unlock" || root.phase === "locked") return 0.0
                    if (root.phase === "idle") return 1.0
                    return 0.0
                }
            }
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: {
            if (desktopRestingNucleus.visible) {
                nucTimeText.text = Qt.formatTime(new Date(), "hh:mm")
            }
        }
    }

    // Shockwave Ring: 62px expanding to 9x (558px), opacity 0.65 to 0 over 750ms
    Rectangle {
        id: nucShockwave
        x: root.centerX - 31
        y: root.centerY - 31
        width: 62
        height: 62
        radius: 31
        z: 2
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.70)
        border.width: 1.5
        antialiasing: true
        smooth: true

        readonly property real shockP: Math.max(0.0, Math.min(1.0, root.t / 750.0))
        readonly property real shockEased: root.easeOutCubic(shockP)

        scale: 1.0 + 8.0 * shockEased
        opacity: {
            if (LockTransition.reducedMotion) return 0.0
            if (root.phase === "locking") return Math.max(0.0, 0.65 * (1.0 - shockEased))
            return 0.0
        }
        visible: opacity > 0.005
    }

    // Animated Carbon Logo Mark (replaces UnifiedCarbonAtom)
    CarbonLogoMark {
        id: logoMark
        x: root.centerX - width / 2
        y: root.centerY - height / 2
        width: 200
        height: 200
        z: 2

        opacity: {
            if (LockTransition.reducedMotion) return (root.phase === "locked" ? 1.0 : 0.0)
            if (root.phase === "locking") {
                if (root.t < 180.0) return 0.0
                return 1.0
            }
            if (root.phase === "unlocking" || root.phase === "post_unlock") {
                if (root.u < 900.0) return 1.0
                return Math.max(0.0, 1.0 - (root.u - 900.0) / 320.0)
            }
            if (root.phase === "locked") return 1.0
            return 0.0
        }
        visible: opacity > 0.001
    }

    // Password Card (Horizontal center at root.centerX, resting top lowered to root.centerY + 126 to prevent overlap with logo mark)
    PasswordCard {
        id: pwdCard
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.centerY + 126
        z: 2
        logoComponent: logoMark
        revealed: false
        onUnlocked: root.startUnlock()
    }

    /* ── 3. Bottom Widgets (Pixel-identical resting positions) ───────────── */
    // Bottom-Right Clock
    LockClock {
        id: lockClock
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 36
        stageDriven: true
        z: 2
    }

    // Bottom-Left Media Card
    LockMediaOverlay {
        id: mediaOverlay
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 36
        anchors.bottomMargin: 36
        stageDriven: true
        z: 2
    }

    // Notifications Overlay (Anchored above media card)
    LockNotificationOverlay {
        id: notifOverlay
        notificationServer: root.notificationServer
        anchors.left: parent.left
        anchors.leftMargin: 36
        anchors.bottomMargin: 14
        anchors.bottom: mediaOverlay.top
        z: 3
        opacity: (root.phase === "unlocking" || root.phase === "post_unlock") ? Math.max(0.0, 1.0 - (root.u - 520.0) / 250.0) : 1.0
    }

    /* ── 4. Top Cava Visualizer (Top z-order 100, active real-time pipeline) ─ */
    LockCavaVisualizer {
        id: topVisualizer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 70
        z: 100
    }
}
