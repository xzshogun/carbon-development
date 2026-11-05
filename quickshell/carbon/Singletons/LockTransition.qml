pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * LockTransition.qml
 *
 * Singleton that drives the unified single-timeline lock/unlock transition.
 * Stage is the WlSessionLockSurface itself (lock-first architecture).
 */
Item {
    id: root

    // "idle" | "locking" | "locked" | "unlocking"
    property string phase: "idle"
    property real t: 0.0 // lock timeline in ms (0 -> 1250)
    property real u: 0.0 // unlock timeline in ms (0 -> 1650)

    // Configuration
    property bool lockSync: true
    property real durationScale: 1.0
    property bool reducedMotion: false
    property bool debugTimeline: false

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string cacheDir: root.home + "/.cache/carbon"
    readonly property string configPath: root.home + "/.config/hypr/carbon-lockscreen.json"

    readonly property real lockTotalDuration: 1300.0
    readonly property real unlockHandoffTime: 1250.0
    readonly property real unlockTotalDuration: 1800.0
    readonly property string screenshotPath: ""

    // Legacy signals for lockSync: false compatibility
    signal handoffToSessionLock()
    signal unlockComplete()
    signal unlockAnimationFinished()

    // First-frame safety flag
    property bool lockSurfaceReady: false
    property bool unlockFinishedSignaled: false

    // Timing diagnostics for QSG_RENDER_TIMING / debug HUD
    property real lastFrameTimeMs: 16.6
    property real minFrameTimeMs: 999.0
    property real maxFrameTimeMs: 0.0
    property real avgFrameTimeMs: 16.6
    property int frameCount: 0
    property real totalFrameTimeMs: 0.0

    function resetTimingStats() {
        root.minFrameTimeMs = 999.0
        root.maxFrameTimeMs = 0.0
        root.totalFrameTimeMs = 0.0
        root.frameCount = 0
        root.avgFrameTimeMs = 16.6
        root.lastFrameTimeMs = 16.6
    }

    FileView {
        id: cfgFile
        path: root.configPath
        watchChanges: true
        onFileChanged: root.reloadConfig()
        onLoaded: root.reloadConfig()
    }

    function reloadConfig() {
        try {
            const txt = cfgFile.text().trim()
            if (txt.length > 0) {
                const parsed = JSON.parse(txt)
                if (parsed.transition) {
                    if (parsed.transition.lockSync !== undefined)
                        root.lockSync = Boolean(parsed.transition.lockSync)
                    if (parsed.transition.durationScale !== undefined)
                        root.durationScale = Math.max(0.1, Number(parsed.transition.durationScale) || 1.0)
                    if (parsed.transition.reducedMotion !== undefined)
                        root.reducedMotion = Boolean(parsed.transition.reducedMotion)
                    if (parsed.transition.debug !== undefined)
                        root.debugTimeline = Boolean(parsed.transition.debug)
                }
            }
        } catch (e) {
            console.log("[LockTransition] Error loading config:", e)
        }
    }

    Component.onCompleted: {
        root.reloadConfig()
        root.ensureBlurredWallpaper()
    }

    // Ensure blurred wallpaper exists on disk once
    function ensureBlurredWallpaper() {
        var scaled = root.cacheDir + "/wallpaper_scaled.jpg"
        var blurred = root.cacheDir + "/wallpaper_blurred.jpg"
        wpBlurCheckProc.command = ["sh", "-c", "if [ ! -s \"" + blurred + "\" ] || [ \"" + blurred + "\" -ot \"" + scaled + "\" ]; then magick \"" + scaled + "\" -resize 25% -blur 0x16 -resize 1366x768! -fill '#050508' -colorize 55% -quality 85 \"" + blurred + "\" 2>/dev/null || true; fi"]
        wpBlurCheckProc.running = true
    }

    Process {
        id: wpBlurCheckProc
        command: []
    }

    // Single FrameAnimation driving the continuous timeline
    FrameAnimation {
        id: timeDriver
        running: (root.phase === "locking" && root.lockSurfaceReady) || root.phase === "unlocking" || root.phase === "post_unlock"
        onTriggered: {
            var fMs = frameTime * 1000.0
            root.lastFrameTimeMs = fMs
            root.frameCount++
            root.totalFrameTimeMs += fMs
            root.avgFrameTimeMs = root.totalFrameTimeMs / root.frameCount
            if (fMs < root.minFrameTimeMs) root.minFrameTimeMs = fMs
            if (fMs > root.maxFrameTimeMs) root.maxFrameTimeMs = fMs

            var dt = fMs / Math.max(0.1, root.durationScale)

            if (root.phase === "locking") {
                root.t += dt
                if (root.t >= root.lockTotalDuration) {
                    root.t = root.lockTotalDuration
                    root.phase = "locked"
                    console.log("[LockTransition] Lock timeline complete. Stats: min=" + root.minFrameTimeMs.toFixed(1) + "ms avg=" + root.avgFrameTimeMs.toFixed(1) + "ms max=" + root.maxFrameTimeMs.toFixed(1) + "ms")
                }
            } else if (root.phase === "unlocking") {
                root.u += dt
                if (root.u >= root.unlockHandoffTime && !root.unlockFinishedSignaled) {
                    root.unlockFinishedSignaled = true
                    root.phase = "post_unlock"
                    console.log("[LockTransition] Unlock handoff reached at " + root.u.toFixed(0) + "ms -> releasing session lock to post_unlock overlay")
                    root.unlockAnimationFinished()
                }
            } else if (root.phase === "post_unlock") {
                root.u += dt
                if (root.u >= root.unlockTotalDuration) {
                    root.u = root.unlockTotalDuration
                    console.log("[LockTransition] Post-unlock desktop reveal complete. Stats: min=" + root.minFrameTimeMs.toFixed(1) + "ms avg=" + root.avgFrameTimeMs.toFixed(1) + "ms max=" + root.maxFrameTimeMs.toFixed(1) + "ms")
                    root.finishUnlock()
                }
            }
        }
    }

    // Called by LockSurface on its first frameSwapped (First-Frame Safety)
    function notifyLockSurfaceReady() {
        if (!root.lockSurfaceReady) {
            root.lockSurfaceReady = true
            console.log("[LockTransition] LockSurface first frame presented -> starting t timeline")
        }
    }

    function startLock(isSystem) {
        if (root.phase === "locking" || root.phase === "locked") return

        if (!root.lockSync) {
            root.phase = "locked"
            root.t = root.lockTotalDuration
            root.handoffToSessionLock()
            return
        }

        root.resetTimingStats()
        root.lockSurfaceReady = false
        root.t = 0.0
        root.u = 0.0
        root.phase = "locking"
    }

    Timer {
        id: unlockWatchdogTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (root.phase === "unlocking" || root.phase === "post_unlock") {
                console.log("[LockTransition] Watchdog timeout (2.5s) triggered -> releasing lock safely")
                root.finishUnlock()
            }
        }
    }

    function startUnlock() {
        if (root.phase === "unlocking" || root.phase === "post_unlock" || root.phase === "idle") return

        if (!root.lockSync) {
            root.phase = "idle"
            root.t = 0.0
            root.u = 0.0
            root.unlockComplete()
            return
        }

        root.resetTimingStats()
        root.u = 0.0
        root.unlockFinishedSignaled = false
        root.phase = "unlocking"
        unlockWatchdogTimer.restart()
    }

    function finishUnlock() {
        unlockWatchdogTimer.stop()
        root.phase = "idle"
        root.t = 0.0
        root.u = 0.0
        root.lockSurfaceReady = false
        root.unlockFinishedSignaled = false
        root.unlockComplete()
    }

    function cancelLock() {
        root.phase = "idle"
        root.t = 0.0
        root.u = 0.0
        root.lockSurfaceReady = false
    }

    function testLock() {
        startLock(false)
    }

    function testUnlock() {
        startUnlock()
    }
}
