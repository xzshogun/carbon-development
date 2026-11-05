import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Singletons"

/**
 * LockScreen:
 * Wraps Quickshell WlSessionLock protocol.
 * Implements lock-first architecture: session lock activates at t=0,
 * and LockSurface is the stage for the entire transition.
 */
Scope {
    id: root

    property alias locked: sessionLock.locked
    property var notificationServer: null

    function lock() {
        if (LockState.cairoModeEnabled) {
            LockState.lock()
            return
        }
        if (LockTransition.lockSync) {
            sessionLock.locked = true
            LockTransition.startLock(false)
        } else {
            // Legacy asynchronous lock
            if (LockTransition.phase === "idle") {
                LockTransition.startLock(false)
            } else {
                sessionLock.locked = true
            }
        }
    }

    function unlock() {
        if (LockState.cairoModeEnabled) {
            LockState.unlock()
            return
        }
        LockTransition.startUnlock()
    }

    Connections {
        target: LockTransition
        function onHandoffToSessionLock() {
            sessionLock.locked = true
        }
        function onUnlockComplete() {
            sessionLock.locked = false
        }
    }

    signal testNotifRequested()
    signal testNotifCenterRequested()
    signal testNotifClearRequested()

    function testNotif() {
        root.testNotifRequested()
    }

    function testNotifCenter() {
        root.testNotifCenterRequested()
    }

    function testNotifClear() {
        root.testNotifClearRequested()
    }

    Timer {
        id: unlockReleaseTimer
        interval: 1
        repeat: false
        onTriggered: {
            sessionLock.locked = false
        }
    }

    WlSessionLock {
        id: sessionLock

        LockSurface {
            id: surf
            sessionLock: sessionLock
            notificationServer: root.notificationServer

            onRequestUnlock: {
                console.log("[LockScreen] Received onRequestUnlock -> unlocking session lock immediately")
                LockTransition.finishUnlock()
                unlockReleaseTimer.restart()
            }

            onRequestUnlockFinish: {
                console.log("[LockScreen] Received onRequestUnlockFinish -> dropping session lock for smooth desktop reveal")
                unlockReleaseTimer.restart()
            }

            Connections {
                target: root
                function onTestNotifRequested() { if (surf) surf.testNotif() }
                function onTestNotifCenterRequested() { if (surf) surf.testNotifCenter() }
                function onTestNotifClearRequested() { if (surf) surf.testNotifClear() }
            }
        }
    }
}
