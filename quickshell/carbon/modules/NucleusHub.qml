import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
import "../Singletons"
import "../components"
import "visualizers"

/**
 * NucleusHub — Barless sp3 Radial Desktop Environment
 *
 * Concepts:
 * 1. Resting state: tiny 14px nucleus dot at screen center with 2 faint concentric orbit rings
 *    and 6 carbon electrons (2 inner, 4 outer) rotating quietly.
 * 2. Opening: ripple ring expands from center, central nucleus grows to 38px circle displaying HH:mm,
 *    calendar ticks ring around it (today's tick elongated & accent colored), weekday & date caption below.
 * 3. Phase 2: 4 sp3 hybrid orbital teardrops (QtQuick Shapes ShapePath cubic bezier curves)
 *    blossom at angles -65°, 25°, 135°, 205° with uneven organic scales (1.0, 0.88, 1.05, 0.9).
 * 4. Phase 3: Focus & 4 round satellites per lobe (CONNECT, LAUNCH, SPACES, ALERTS).
 * 5. Phase 4: Wallpapers mode collapses lobes into nucleus, revealing 16 circular thumbnail orbs
 *    (6 inner ring, 10 outer ring) connected to Wallhaven.
 */
Item {
    id: root

    /* ── Signals ── */
    signal openLauncher()
    signal openWallpapers()
    signal openPower()
    signal requestLock()
    signal closingStarted()
    signal closeRequested()

    /* ── Properties & State ── */
    property bool hubOpen: false
    property bool isClosingHub: false
    property bool nucleusExpanded: false
    property string activeMode: "hub" // "hub" | "wallpapers" | "appsearch" | "wifi" | "bluetooth" | "battery" | "power" | "calendar"
    property string focusedLobe: ""    // "" | "connect" | "launch" | "spaces" | "alerts"
    property bool nightLightOn: false
    property bool justOpenedPower: false
    property bool notifPanelOpen: false

    readonly property var hubBattery: UPower.displayDevice
    readonly property real hubBatteryPct: hubBattery ? hubBattery.percentage : 1.0
    readonly property bool hubIsCharging: hubBattery ? (hubBattery.state === UPowerDeviceState.Charging) : false
    readonly property string batteryIconName: {
        if (root.hubIsCharging) return "battery_charging_full"
        if (root.hubBatteryPct >= 0.90) return "battery_full"
        if (root.hubBatteryPct >= 0.70) return "battery_6_bar"
        if (root.hubBatteryPct >= 0.50) return "battery_5_bar"
        if (root.hubBatteryPct >= 0.30) return "battery_3_bar"
        if (root.hubBatteryPct >= 0.15) return "battery_2_bar"
        return "battery_alert"
    }

    function toggleNotifPanel() {
        root.notifPanelOpen = !root.notifPanelOpen
        if (root.notifPanelOpen) {
            if (!root.hubOpen) root.open()
            root.focusedLobe = "alerts"
        }
    }

    function openNotificationPanel() {
        if (!root.hubOpen) root.open()
        root.focusedLobe = "alerts"
        root.notifPanelOpen = true
    }

    function clearNotifications() {
        if (notifPanel && notifPanel.clearCurrentTab) {
            notifPanel.clearCurrentTab()
        }
    }

    function setNotificationTab(tabIdx) {
        if (notifPanel) {
            notifPanel.currentTab = tabIdx
        }
    }

    readonly property string nightScript: {
        const home = Quickshell.env("HOME") || ""
        const carbonDir = Quickshell.env("CARBON_CONFIG_DIR") || (home + "/.config/carbon")
        return carbonDir + "/scripts/carbon-night.sh"
    }

    Process {
        id: nightProbe
        command: ["/usr/bin/sh", root.nightScript, "status"]
        stdout: StdioCollector {
            id: nightCollector
            waitForEnd: true
        }
        onExited: {
            var v = String(nightCollector.text).trim()
            root.nightLightOn = (v === "on")
        }
    }

    Timer {
        id: nightVerifyTimer
        interval: 350
        repeat: false
        onTriggered: root.checkNightLight()
    }

    // 60fps continuous phase accumulator for organic roaming orbits, waves, and quantum floats
    property real continuousPhase: 0.0
    Timer {
        id: nucleusContinuousPhaseTimer
        interval: 16
        running: (root.hubOpen || root.hubProgress > 0.01) && !root.isClosingHub
        repeat: true
        onTriggered: {
            root.continuousPhase += 0.022
            if (root.continuousPhase > 6283.1853) root.continuousPhase -= 6283.1853
        }
    }

    function checkNightLight() {
        if (!nightProbe.running) {
            nightProbe.command = ["/usr/bin/sh", root.nightScript, "status"]
            nightProbe.running = true
        }
    }

    function toggleNightLight() {
        root.nightLightOn = !root.nightLightOn
        Quickshell.execDetached(["/usr/bin/sh", root.nightScript, root.nightLightOn ? "on" : "off"])
        nightVerifyTimer.restart()
    }

    /* External IPC Triggers */
    function toggle() {
        if (root.hubOpen && !root.isClosingHub) {
            close()
        } else {
            open()
        }
    }

    Component.onCompleted: {
        root.randomizeOrbitalPositions()
        root.loadApps()
        root.checkNightLight()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.loadApps()
        }
    }

    onHubOpenChanged: {
        if (root.hubOpen) {
            root.reloadBlankTileConfig()
            root.randomizeOrbitalPositions()
            root.checkNightLight()
        }
    }

    function open() {
        closeFinishTimer.stop()
        nucleusShrinkTimer.stop()
        root.isClosingHub = false
        root.randomizeOrbitalPositions()
        root.hubOpen = true
        root.nucleusExpanded = true
        root.activeMode = "hub"
        root.focusedLobe = ""
        root.notifPanelOpen = false
    }

    Timer {
        id: nucleusShrinkTimer
        interval: 400
        repeat: false
        onTriggered: {
            root.nucleusExpanded = false
            closeFinishTimer.restart()
        }
    }

    Timer {
        id: closeFinishTimer
        interval: 260
        repeat: false
        onTriggered: {
            root.isClosingHub = false
            root.hubOpen = false
            root.activeMode = "hub"
            if (connectivityPicker) connectivityPicker.resetPicker()
            root.closeRequested()
        }
    }

    function close() {
        if (!root.hubOpen || root.isClosingHub) return
        root.notifPanelOpen = false
        if (connectivityPicker) connectivityPicker.resetPicker()
        root.isClosingHub = true
        root.focusedLobe = ""
        root.activeMode = "hub"
        root.closingStarted()
        nucleusShrinkTimer.restart()
    }

    function focusLobe(name) {
        if (root.isClosingHub) return
        if (!root.hubOpen) root.open()
        root.activeMode = "hub"
        root.focusedLobe = (root.focusedLobe === name) ? "" : name
    }

    property var alertsRandomOffsets: [
        { dx: 0, dy: 0 },
        { dx: 0, dy: 0 },
        { dx: 0, dy: 0 },
        { dx: 0, dy: 0 }
    ]

    function randomizeAlertsSubLobes() {
        var offsets = []
        for (var i = 0; i < 4; i++) {
            var rX = (Math.random() - 0.5) * 4
            var rY = (Math.random() - 0.5) * 4
            offsets.push({ dx: rX, dy: rY })
        }
        root.alertsRandomOffsets = offsets
    }

    function resetAlertsSubLobes() {
        root.alertsRandomOffsets = [
            { dx: 0, dy: 0 },
            { dx: 0, dy: 0 },
            { dx: 0, dy: 0 },
            { dx: 0, dy: 0 }
        ]
    }

    onFocusedLobeChanged: {
        if (root.focusedLobe === "alerts") {
            root.randomizeAlertsSubLobes()
        } else {
            root.notifPanelOpen = false
            root.resetAlertsSubLobes()
        }
    }

    function captureSatellitePositions() {
        if (!lobeConnect || !connectivityPicker) return
        const lobeDeg = lobeConnect.rotation
        const lobeRad = lobeDeg * (Math.PI / 180.0)
        const cosLobe = Math.cos(lobeRad)
        const sinLobe = Math.sin(lobeRad)

        // Satellite 0 (WiFi, relDeg = -57)
        const rad0 = -57.0 * (Math.PI / 180.0)
        const lx0 = lobeConnect.orbitalRadius + 64.0 * Math.cos(rad0)
        const ly0 = 64.0 * Math.sin(rad0)
        connectivityPicker.capturedWifiX = lx0 * cosLobe - ly0 * sinLobe
        connectivityPicker.capturedWifiY = lx0 * sinLobe + ly0 * cosLobe

        // Satellite 1 (Bluetooth, relDeg = -19)
        const rad1 = -19.0 * (Math.PI / 180.0)
        const lx1 = lobeConnect.orbitalRadius + 64.0 * Math.cos(rad1)
        const ly1 = 64.0 * Math.sin(rad1)
        connectivityPicker.capturedBtX = lx1 * cosLobe - ly1 * sinLobe
        connectivityPicker.capturedBtY = lx1 * sinLobe + ly1 * cosLobe
    }

    function openWifiMode() {
        closeFinishTimer.stop()
        nucleusShrinkTimer.stop()
        root.isClosingHub = false
        if (!root.hubOpen) {
            root.randomizeOrbitalPositions()
            root.hubOpen = true
            root.nucleusExpanded = true
        }
        root.captureSatellitePositions()
        root.activeMode = "wifi"
        if (connectivityPicker) connectivityPicker.openWifi()
    }

    function openBluetoothMode() {
        closeFinishTimer.stop()
        nucleusShrinkTimer.stop()
        root.isClosingHub = false
        if (!root.hubOpen) {
            root.randomizeOrbitalPositions()
            root.hubOpen = true
            root.nucleusExpanded = true
        }
        root.captureSatellitePositions()
        root.activeMode = "bluetooth"
        if (connectivityPicker) connectivityPicker.openBluetooth()
    }

    function closeConnectivityPicker() {
        if (connectivityPicker) connectivityPicker.closePicker()
        else root.activeMode = "hub"
    }

    function openBatteryMode() {
        closeFinishTimer.stop()
        nucleusShrinkTimer.stop()
        root.isClosingHub = false
        if (!root.hubOpen) {
            root.randomizeOrbitalPositions()
            root.hubOpen = true
            root.nucleusExpanded = true
        }
        root.activeMode = "battery"
        root.focusedLobe = ""
        if (batteryOrbitSection) batteryOrbitSection.openSection()
    }

    function closeBatteryMode() {
        if (batteryOrbitSection) batteryOrbitSection.closeSection()
        else {
            root.activeMode = "hub"
            root.focusedLobe = "connect"
        }
    }

    function openWallpaperMode() {
        root.close()
        root.openWallpapers()
    }


    function openPowerMode() {
        closeFinishTimer.stop()
        nucleusShrinkTimer.stop()
        root.isClosingHub = false
        if (!root.hubOpen) {
            root.randomizeOrbitalPositions()
            root.hubOpen = true
            root.nucleusExpanded = true
        }
        root.activeMode = "power"
        root.powerAction = "none"
        root.powerActionT = 0.0
        root.focusedLobe = ""
        root.randomizePowerPositions()
        globalKeyHandler.forceActiveFocus()
    }

    function openCalendarMode() {
        closeFinishTimer.stop()
        nucleusShrinkTimer.stop()
        root.isClosingHub = false
        if (!root.hubOpen) {
            root.randomizeOrbitalPositions()
            root.hubOpen = true
            root.nucleusExpanded = true
        }
        root.activeMode = "calendar"
        root.focusedLobe = ""
    }

    Timer {
        id: focusSearchTimer
        interval: 75
        onTriggered: {
            if (appSearchInput) {
                appSearchInput.forceActiveFocus()
            }
        }
    }

    function openLauncherMode(initialText) {
        closeFinishTimer.stop()
        nucleusShrinkTimer.stop()
        root.isClosingHub = false
        if (!root.hubOpen) {
            root.randomizeOrbitalPositions()
            root.hubOpen = true
            root.nucleusExpanded = true
        }
        root.activeMode = "appsearch"
        root.focusedLobe = "launch"
        root.launcherTab = "apps"
        root.calcResult = ""
        root.hasCalcResult = false
        root.refreshClipboard()
        if (appSearchInput) {
            appSearchInput.text = (initialText !== undefined && initialText !== null) ? initialText : ""
        }
        root.loadApps()
        focusSearchTimer.restart()
    }

    function toggleLauncher() {
        if (root.hubOpen && root.activeMode === "appsearch") {
            root.close()
        } else {
            root.openLauncherMode()
        }
    }

    function toggleLyrics() {
        if (dateLyricsCaption) {
            dateLyricsCaption.showLyrics = !dateLyricsCaption.showLyrics
        }
    }

    function setLyricsMode(show) {
        if (dateLyricsCaption) {
            dateLyricsCaption.showLyrics = show
        }
    }

    /* ── Randomize Orbital Positions & Distances on Each Open ── */
    function randomizeOrbitalPositions() {
        if (!lobeConnect || !lobeLaunch || !lobeSpaces || !lobeAlerts) return

        // 4 dedicated sectors spanning the upper dome (175° .. 360°)
        // Completely leaves the bottom 170° clear — orbs never enter the music overlay/controls region!
        // Each lobe occupies a designated quadrant for consistent mental model, with subtle organic jitter.
        var lobeSectorMap = [
            { lobe: lobeSpaces,  min: 180.0, max: 205.0 }, // Left: Core Apps & Dev Shortcuts
            { lobe: lobeConnect, min: 225.0, max: 250.0 }, // Top-Left: Hardware & Connectivity
            { lobe: lobeAlerts,  min: 290.0, max: 315.0 }, // Top-Right: Productivity & Time
            { lobe: lobeLaunch,  min: 335.0, max: 360.0 }  // Right: System Utilities & Capture
        ]

        for (var k = 0; k < lobeSectorMap.length; k++) {
            var item = lobeSectorMap[k]
            if (!item.lobe) continue
            var angle = item.min + (Math.random() * (item.max - item.min))
            if (angle >= 360.0) angle -= 360.0
            var dist = Math.round(124.0 + (Math.random() * 26.0))
            item.lobe.targetAngle = angle
            item.lobe.orbitalRadius = dist
        }
    }

    /* ── Power Menu Configuration & Backend Driver ── */
    readonly property string powerConfigFile: {
        var envDir = Quickshell.env("CARBON_CONFIG_DIR")
        if (envDir && envDir.length > 0) return envDir + "/carbon-bar-mode.json"
        return (Quickshell.env("HOME") || "") + "/.config/carbon/carbon-bar-mode.json"
    }

    property string powerAnimMode: "full" // "full" | "short" | "none"
    property real powerHoldMs: 600.0
    property real powerConfirmHoldMs: 800.0
    property bool powerEnableLogout: false
    property bool showRestingAtom: true

    readonly property bool powerReducedMotion: (Theme.reducedMotion || root.powerAnimMode === "none")
    readonly property real powerDurationScale: (root.powerAnimMode === "short" ? 0.5 : 1.0)

    FileView {
        id: powerConfigWatcher
        path: root.powerConfigFile
        watchChanges: true
        printErrors: false
        onFileChanged: powerConfigWatcher.reload()
        onLoaded: root.loadPowerConfig()
    }

    function loadPowerConfig() {
        try {
            const raw = powerConfigWatcher.text().trim()
            if (!raw) return
            const cfg = JSON.parse(raw)
            if (cfg.nucleus) {
                if (cfg.nucleus.showRestingAtom !== undefined) {
                    root.showRestingAtom = Boolean(cfg.nucleus.showRestingAtom)
                }
            }
            if (cfg.power) {
                if (cfg.power.animation) root.powerAnimMode = String(cfg.power.animation)
                if (cfg.power.holdMs !== undefined) root.powerHoldMs = Math.max(100.0, Number(cfg.power.holdMs) || 600.0)
                if (cfg.power.confirmHoldMs !== undefined) root.powerConfirmHoldMs = Math.max(100.0, Number(cfg.power.confirmHoldMs) || 800.0)
                if (cfg.power.enableLogout !== undefined) root.powerEnableLogout = Boolean(cfg.power.enableLogout)
            }
        } catch (e) {}
    }

    /* ── Blank Tile Customization Configuration ── */
    readonly property string blankTileConfigFile: {
        var envDir = Quickshell.env("CARBON_CONFIG_DIR")
        if (envDir && envDir.length > 0) return envDir + "/carbon-blank-tile.json"
        return (Quickshell.env("HOME") || "") + "/.config/carbon/carbon-blank-tile.json"
    }

    property var blankTileConfig: ({ enabled: false, cropPath: "", opacity: 1.0, timestamp: 0 })

    FileView {
        id: blankTileConfigWatcher
        path: root.blankTileConfigFile
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: root.reloadBlankTileConfig()
        onLoaded: root.reloadBlankTileConfig()
    }

    function reloadBlankTileConfig() {
        try {
            blankTileConfigWatcher.reload()
            const raw = blankTileConfigWatcher.text().trim()
            if (raw) root.blankTileConfig = JSON.parse(raw)
        } catch (e) {}
    }

    /* ── Weather State for Tile ── */
    property string weatherTemp: "--"
    property string weatherIcon: "󰖐"
    property string weatherDesc: ""
    readonly property string weatherScriptPath: (Quickshell.env("HOME") || "") + "/.local/share/quickshell/carbon/scripts/carbon-weather.py"
    readonly property string weatherCacheFile: "/tmp/carbon-weather-cache.json"

    FileView {
        id: weatherCacheWatcher
        path: root.weatherCacheFile
        watchChanges: true
        printErrors: false
        onFileChanged: weatherCacheWatcher.reload()
        onLoaded: {
            try {
                const raw = weatherCacheWatcher.text().trim()
                if (raw) {
                    const d = JSON.parse(raw)
                    if (d.temp) root.weatherTemp = d.temp
                    if (d.icon) root.weatherIcon = d.icon
                    if (d.description) root.weatherDesc = d.description
                }
            } catch (e) {}
        }
    }

    Process {
        id: weatherPoller
        command: ["python3", root.weatherScriptPath, "status"]
        running: true
        stdout: StdioCollector {
            waitForEnd: true
            onTextChanged: {
                if (text && text.trim().length > 0) {
                    try {
                        var d = JSON.parse(text.trim())
                        if (d) {
                            if (d.temp) root.weatherTemp = d.temp
                            if (d.icon) root.weatherIcon = d.icon
                            if (d.description) root.weatherDesc = d.description
                        }
                    } catch (e) {}
                }
            }
        }
    }

    /* ── Power State & Action Variables ── */
    property bool isPressingNucleus: false
    property real nucleusHoldProgress: 0.0

    property string heldPowerOrb: ""
    property string lastHeldPowerOrb: ""
    property real orbHoldProgress: 0.0
    property string hoveredPowerOrb: ""

    property string powerAction: "none" // "none" | "lock" | "sleep" | "restart" | "shutdown"
    property real powerActionT: 0.0     // action timeline time in ms (scaled)
    property string powerErrorMessage: ""
    property real powerBloomRadius: 0.0

    property bool lockFired: false
    property bool sleepFired: false
    property bool restartFired: false
    property bool shutdownFired: false

    property real innerElectronAngle: 0.0
    property real outerElectronAngle: 0.0

    // Easing helpers
    function easeOutCubic(p) {
        var x = Math.max(0.0, Math.min(1.0, p))
        return 1.0 - Math.pow(1.0 - x, 3.0)
    }

    function easeInOutCubic(p) {
        var x = Math.max(0.0, Math.min(1.0, p))
        return x < 0.5 ? 4.0 * x * x * x : 1.0 - Math.pow(-2.0 * x + 2.0, 3.0) / 2.0
    }

    /* ── Fixed Power Orb Bloom Data (r=86px, angles: -150°, -60°, 30°, 120°) ── */
    readonly property var powerOrbData: [
        { id: "lock", icon: "lock", deg: -150.0, dist: 86.0, iconColor: "#FFFFFF", holdColor: "#FFFFFF", name: "Lock", isDestructive: false },
        { id: "sleep", icon: "bedtime", deg: -60.0, dist: 86.0, iconColor: "#FFFFFF", holdColor: "#FFFFFF", name: "Sleep", isDestructive: false },
        { id: "restart", icon: "restart_alt", deg: 30.0, dist: 86.0, iconColor: "#FFFFFF", holdColor: "#FFFFFF", name: "Restart", isDestructive: true },
        { id: "shutdown", icon: "power_settings_new", deg: 120.0, dist: 86.0, iconColor: "#F87171", holdColor: "#F87171", name: "Shut down", isDestructive: true }
    ]

    function randomizePowerPositions() {
        // Compatibility hook: maintain fixed radial layout per rules
        root.hoveredPowerOrb = ""
        root.heldPowerOrb = ""
        root.orbHoldProgress = 0.0
    }

    /* ── Power Hold-and-Drain Driver (Runs only during hold/drain, NEVER at rest) ── */
    FrameAnimation {
        id: powerHoldDriver
        running: (root.isPressingNucleus || root.nucleusHoldProgress > 0.0 ||
                  root.heldPowerOrb !== "" || root.orbHoldProgress > 0.0) &&
                  root.powerAction === "none"
        onTriggered: {
            var dt = frameTime * 1000.0

            // 1. Nucleus Hold & Early-Release Drain
            if (root.isPressingNucleus) {
                root.nucleusHoldProgress = Math.min(1.0, root.nucleusHoldProgress + dt / root.powerHoldMs)
                if (root.nucleusHoldProgress >= 1.0) {
                    root.nucleusHoldProgress = 0.0
                    root.isPressingNucleus = false
                    root.justOpenedPower = true
                    root.openPowerMode()
                }
            } else if (root.nucleusHoldProgress > 0.0) {
                root.nucleusHoldProgress = Math.max(0.0, root.nucleusHoldProgress - dt * 0.004)
            }

            // 2. Destructive Orb Hold & Early-Release Drain
            if (root.heldPowerOrb !== "") {
                root.orbHoldProgress = Math.min(1.0, root.orbHoldProgress + dt / root.powerConfirmHoldMs)
                if (root.orbHoldProgress >= 1.0) {
                    var actionToTrigger = root.heldPowerOrb
                    root.heldPowerOrb = ""
                    root.orbHoldProgress = 0.0
                    if (actionToTrigger === "lock" && root.powerEnableLogout) {
                        Quickshell.execDetached(["hyprctl", "dispatch", "exit"])
                        root.close()
                    } else {
                        root.triggerPowerAction(actionToTrigger)
                    }
                }
            } else if (root.orbHoldProgress > 0.0) {
                root.orbHoldProgress = Math.max(0.0, root.orbHoldProgress - dt * 0.004)
            }
        }
    }

    /* ── Action Trigger, Cancellation & Execution ── */
    function triggerPowerAction(action) {
        if (root.powerAction !== "none") return
        if (!root.hubOpen) {
            root.hubOpen = true
        }
        root.activeMode = "power"
        root.powerErrorMessage = ""
        root.heldPowerOrb = ""
        root.orbHoldProgress = 0.0
        root.isPressingNucleus = false
        root.nucleusHoldProgress = 0.0
        root.lockFired = false
        root.sleepFired = false
        root.restartFired = false
        root.shutdownFired = false

        if (root.powerReducedMotion) {
            root.powerAction = action
            root.powerActionT = 0.0
            reducedMotionTimer.action = action
            reducedMotionTimer.restart()
            return
        }

        root.powerAction = action
        root.powerActionT = 0.0
        root.innerElectronAngle = 0.0
        root.outerElectronAngle = 0.0

        if (action === "sleep") {
            // Lock first so resume displays the lock screen
            LockTransition.startLock(false)
        }
    }

    function cancelPowerAction() {
        if (root.powerAction === "none") return false
        var t = root.powerActionT
        var cancellable = false

        if (root.powerReducedMotion) {
            cancellable = reducedMotionTimer.running
        } else if (root.powerAction === "lock" && t < 400.0) {
            cancellable = true
        } else if (root.powerAction === "sleep" && t < 700.0) {
            cancellable = true
        } else if (root.powerAction === "restart" && t < 1400.0) {
            cancellable = true
        } else if (root.powerAction === "shutdown" && t < 2300.0) {
            cancellable = true
        }

        if (cancellable) {
            reducedMotionTimer.stop()
            root.powerAction = "none"
            root.powerActionT = 0.0
            root.lockFired = false
            root.sleepFired = false
            root.restartFired = false
            root.shutdownFired = false
            return true
        }
        return false
    }

    Timer {
        id: reducedMotionTimer
        property string action: ""
        interval: 300
        onTriggered: {
            if (action === "lock") {
                LockTransition.startLock(false)
                root.requestLock()
            } else if (action === "sleep") {
                root.executeSleep()
            } else if (action === "restart") {
                root.executeReboot()
            } else if (action === "shutdown") {
                root.executeShutdown()
            }
        }
    }

    /* ── Action Animation Driver (Runs only during action, NEVER at rest) ── */
    FrameAnimation {
        id: powerActionDriver
        running: root.activeMode === "power" && root.powerAction !== "none" && !root.powerReducedMotion
        onTriggered: {
            var dt = (frameTime * 1000.0) / Math.max(0.1, root.powerDurationScale)
            root.powerActionT += dt
            var t = root.powerActionT

            if (root.powerAction === "lock") {
                root.innerElectronAngle += dt * 0.0011
                root.outerElectronAngle -= dt * 0.0007

                // Never delay real lock beyond 450ms
                if (t >= 400.0 && !root.lockFired) {
                    root.lockFired = true
                    LockTransition.startLock(false)
                    root.requestLock()
                }
            } else if (root.powerAction === "sleep") {
                // Decay electron speed: exp(-(t-500)/350)
                var decay = (t < 500.0) ? 1.0 : Math.exp(-(t - 500.0) / 350.0)
                root.innerElectronAngle += dt * 0.0011 * decay
                root.outerElectronAngle -= dt * 0.0007 * decay

                // At 1400ms: dim finished -> run systemctl suspend
                if (t >= 1400.0 && !root.sleepFired) {
                    root.sleepFired = true
                    root.executeSleep()
                }
            } else if (root.powerAction === "restart") {
                var mult = 1.0
                if (t >= 500.0 && t < 1300.0) {
                    mult = 1.0 + (t - 500.0) / 120.0
                } else if (t >= 1300.0 && t < 1600.0) {
                    mult = 1.0 + 800.0 / 120.0
                }
                root.innerElectronAngle += dt * 0.0011 * mult
                root.outerElectronAngle -= dt * 0.0007 * mult

                // At 1800ms (black frame): fire reboot command
                if (t >= 1800.0 && !root.restartFired) {
                    root.restartFired = true
                    root.executeReboot()
                }

                // At 2600ms: atom turns back into clock
                if (t >= 2650.0) {
                    root.powerAction = "none"
                    root.powerActionT = 0.0
                    root.restartFired = false
                }
            } else if (root.powerAction === "shutdown") {
                root.innerElectronAngle += dt * 0.0011
                root.outerElectronAngle -= dt * 0.0007

                // At 3000ms: fire poweroff command
                if (t >= 3000.0 && !root.shutdownFired) {
                    root.shutdownFired = true
                    root.executeShutdown()
                }
            }
        }
    }

    /* ── System Command Execution & Inhibitor Check ── */
    Process {
        id: powerActionProc
        property string actionName: ""
        property string errorText: ""
        command: []
        stderr: SplitParser {
            onRead: data => {
                powerActionProc.errorText += data + " "
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.log("[PowerAction] Command failed:", actionName, "exitCode:", exitCode, "err:", errorText)
                var msg = errorText.trim()
                if (!msg) msg = "systemctl failed with exit code " + exitCode
                root.handlePowerCommandFailed(msg)
            } else {
                if (actionName === "sleep") {
                    root.handleSleepResume()
                }
            }
        }
    }

    function executeSleep() {
        powerActionProc.actionName = "sleep"
        powerActionProc.errorText = ""
        powerActionProc.command = ["systemctl", "suspend"]
        powerActionProc.running = true
    }

    function executeReboot() {
        powerActionProc.actionName = "restart"
        powerActionProc.errorText = ""
        powerActionProc.command = ["systemctl", "reboot"]
        powerActionProc.running = true
    }

    function executeShutdown() {
        powerActionProc.actionName = "shutdown"
        powerActionProc.errorText = ""
        powerActionProc.command = ["systemctl", "poweroff"]
        powerActionProc.running = true
    }

    function handlePowerCommandFailed(reason) {
        root.powerErrorMessage = reason
        root.powerAction = "none"
        root.powerActionT = 0.0
        root.lockFired = false
        root.sleepFired = false
        root.restartFired = false
        root.shutdownFired = false
    }

    function handleSleepResume() {
        // Resume reverses screen dim over 500ms and resets all menu state
        wakeReverseAnimation.restart()
    }

    property real powerDimOverride: 1.0
    SequentialAnimation {
        id: wakeReverseAnimation
        PropertyAction { target: root; property: "powerDimOverride"; value: 1.0 }
        NumberAnimation {
            target: root
            property: "powerDimOverride"
            to: 0.0
            duration: 500
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                root.powerAction = "none"
                root.powerActionT = 0.0
                root.sleepFired = false
                root.close()
            }
        }
    }

    /* ── Mathematics for 6 Bohr Electrons During Action ── */
    function getPowerElectronPos(index) {
        var t = root.powerActionT

        if (root.powerAction === "shutdown") {
            var t0 = 0.0
            var r0 = 40.0
            var dir = -1.0
            var baseAngle = 0.0

            if (index < 4) {
                // 4 Outer electrons (indices 0..3): detach 260ms apart starting at 500ms
                t0 = 500.0 + index * 260.0
                r0 = 40.0
                dir = -1.0
                baseAngle = -0.0007 * t0 + index * (Math.PI / 2.0)
            } else {
                // 2 Inner electrons (indices 4..5): detach 260ms apart starting at 1540ms
                t0 = 1540.0 + (index - 4) * 260.0
                r0 = 22.0
                dir = 1.0
                baseAngle = 0.0011 * t0 + (index - 4) * Math.PI
            }

            if (t < t0) {
                var curAngle = (index < 4)
                    ? (root.outerElectronAngle + index * (Math.PI / 2.0))
                    : (root.innerElectronAngle + (index - 4) * Math.PI)
                return {
                    x: r0 * Math.cos(curAngle),
                    y: r0 * Math.sin(curAngle),
                    alpha: 1.0,
                    vx: -Math.sin(curAngle) * dir,
                    vy: Math.cos(curAngle) * dir
                }
            }

            var dt = t - t0
            var r = r0 + dt * 0.12 + dt * dt * 0.0003
            var tangentDist = Math.sqrt(Math.max(0.0, r * r - r0 * r0))
            var tx = r0 * Math.cos(baseAngle) + dir * tangentDist * (-Math.sin(baseAngle))
            var ty = r0 * Math.sin(baseAngle) + dir * tangentDist * (Math.cos(baseAngle))
            var alpha = Math.max(0.0, 1.0 - dt / 700.0)

            return {
                x: tx,
                y: ty,
                alpha: alpha,
                vx: -Math.sin(baseAngle) * dir,
                vy: Math.cos(baseAngle) * dir
            }
        }

        // Lock, Sleep, Restart
        var rCur = 0.0
        var thetaCur = 0.0
        var alphaCur = 1.0
        var isInner = (index >= 4)

        if (isInner) {
            var idxIn = index - 4
            thetaCur = root.innerElectronAngle + idxIn * Math.PI
            if (t < 500.0) {
                rCur = 22.0 * root.easeOutCubic(t / 500.0)
            } else if (root.powerAction === "restart") {
                if (t < 1300.0) {
                    rCur = 22.0
                } else if (t < 1600.0) {
                    rCur = 22.0 * (1.0 - root.easeInOutCubic((t - 1300.0) / 300.0))
                } else if (t < 2100.0) {
                    rCur = 0.0
                } else if (t < 2600.0) {
                    rCur = 22.0 * root.easeOutCubic((t - 2100.0) / 500.0)
                } else {
                    rCur = 22.0
                }
            } else {
                rCur = 22.0
            }
        } else {
            thetaCur = root.outerElectronAngle + index * (Math.PI / 2.0)
            if (t < 500.0) {
                rCur = 40.0 * root.easeOutCubic(t / 500.0)
            } else if (root.powerAction === "restart") {
                if (t < 1300.0) {
                    rCur = 40.0
                } else if (t < 1600.0) {
                    rCur = 40.0 * (1.0 - root.easeInOutCubic((t - 1300.0) / 300.0))
                } else if (t < 2100.0) {
                    rCur = 0.0
                } else if (t < 2600.0) {
                    rCur = 40.0 * root.easeOutCubic((t - 2100.0) / 500.0)
                } else {
                    rCur = 40.0
                }
            } else {
                rCur = 40.0
            }
        }

        if (root.powerAction === "sleep") {
            if (t >= 500.0 && t <= 1200.0) {
                alphaCur = 1.0 - 0.75 * ((t - 500.0) / 700.0)
            } else if (t > 1200.0) {
                alphaCur = 0.25
            }
        }

        var velX = -Math.sin(thetaCur) * (isInner ? 1.0 : -1.0)
        var velY = Math.cos(thetaCur) * (isInner ? 1.0 : -1.0)

        return {
            x: rCur * Math.cos(thetaCur),
            y: rCur * Math.sin(thetaCur),
            alpha: alphaCur,
            vx: velX,
            vy: velY
        }
    }

    /* ── Dynamic Orbit Ring Alpha ── */
    readonly property real powerOrbitRingAlpha: {
        if (root.activeMode !== "power" || root.powerAction === "none") return 0.0
        var t = root.powerActionT
        if (t < 500.0) return 0.14 * root.easeOutCubic(t / 500.0)

        if (root.powerAction === "restart") {
            if (t < 1300.0) return 0.14 + 0.36 * ((t - 500.0) / 800.0)
            if (t < 1600.0) return 0.50 * (1.0 - (t - 1300.0) / 300.0)
            if (t < 2100.0) return 0.0
            if (t < 2600.0) return 0.14 * root.easeOutCubic((t - 2100.0) / 500.0)
            return 0.0
        }

        if (root.powerAction === "shutdown") {
            if (t < 2200.0) return 0.14
            if (t < 2600.0) return 0.14 * (1.0 - (t - 2200.0) / 400.0)
            return 0.0
        }

        return 0.14
    }

    /* ── Dynamic Screen Dimmer Scrim Opacity ── */
    readonly property real effectiveScrimOpacity: {
        if (root.notifPanelOpen) {
            return 0.50
        }
        if (root.activeMode !== "power" || root.powerAction === "none") {
            return root.hubProgress * 0.42
        }
        if (root.powerReducedMotion) {
            return 0.42 + 0.58 * Math.min(1.0, root.powerActionT / 300.0)
        }
        var t = root.powerActionT
        if (root.powerAction === "sleep") {
            if (root.powerDimOverride < 0.999) return 0.72 * root.powerDimOverride
            if (t < 700.0) return 0.42
            var p = Math.min(1.0, (t - 700.0) / 700.0)
            return 0.42 + (0.72 - 0.42) * root.easeInOutCubic(p)
        }
        if (root.powerAction === "restart") {
            if (t < 1400.0) return 0.42
            if (t < 1600.0) {
                var p1 = Math.min(1.0, (t - 1400.0) / 200.0)
                return 0.42 + (0.92 - 0.42) * root.easeInOutCubic(p1)
            }
            if (t < 2100.0) return 0.92
            var p2 = Math.min(1.0, (t - 2100.0) / 500.0)
            return 0.92 - (0.92 - 0.42) * root.easeOutCubic(p2)
        }
        if (root.powerAction === "shutdown") {
            if (t < 2300.0) return 0.42
            var p3 = Math.min(1.0, (t - 2300.0) / 700.0)
            return 0.42 + (1.0 - 0.42) * p3
        }
        return 0.42
    }

    /* ── Colors / Theme Tokens ── */
    readonly property color colTeal: Theme.accent || "#00F0FF"
    readonly property color colPurple: Theme.m3tertiary || "#c084fc"
    readonly property color colCoral: Theme.err || "#f87171"
    readonly property color colAmber: Theme.warn || "#fbbf24"
    readonly property color colBgDark: (Theme.isDark ? Theme.bg : "#0e0e14") || "#0e0e14"
    readonly property color colFg: (Theme.isDark ? Theme.fg : "#e6e4f0") || "#e6e4f0"
    readonly property color colFgDim: (Theme.isDark && Theme.fgDim && (0.299 * Theme.fgDim.r + 0.587 * Theme.fgDim.g + 0.114 * Theme.fgDim.b < 0.45)) ? Qt.rgba(1, 1, 1, 0.68) : ((Theme.isDark ? Theme.fgDim : "#94a3b8") || "#94a3b8")

    /* ── Time & Date ── */
    property var currentTime: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.currentTime = new Date()
    }

    readonly property string hourStr: {
        var h = root.currentTime.getHours()
        return h < 10 ? "0" + h : String(h)
    }
    readonly property string minStr: {
        var m = root.currentTime.getMinutes()
        return m < 10 ? "0" + m : String(m)
    }
    readonly property string timeStr: hourStr + ":" + minStr

    readonly property string dateCaptionStr: {
        var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return days[root.currentTime.getDay()] + " " + root.currentTime.getDate() + " " + months[root.currentTime.getMonth()]
    }

    /* ── Services Integration ── */
    // 1. Audio Sink
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property int audioVol: (audioSink && audioSink.audio) ? Math.round(audioSink.audio.volume * 100) : 50
    property bool osdOpenedHub: false

    function stepVolume(delta) {
        if (controlRing) {
            if (!controlRing.isOpen) {
                controlRing.openOsd("volume")
            }
            controlRing.stepLevel(delta)
        } else if (audioSink && audioSink.audio) {
            audioSink.audio.volume = Math.max(0.0, Math.min(1.0, audioSink.audio.volume + delta))
        }
    }

    function stepBrightness(delta) {
        if (controlRing) {
            if (!controlRing.isOpen) {
                controlRing.openOsd("brightness")
            }
            controlRing.stepLevel(delta)
        }
    }

    function toggleVolumeMute() {
        if (controlRing) {
            if (!controlRing.isOpen) {
                controlRing.openOsd("volume")
            }
            controlRing.toggleMute()
        } else if (audioSink && audioSink.audio) {
            audioSink.audio.muted = !audioSink.audio.muted
        }
    }

    function openVolumeMode() {
        if (controlRing) controlRing.openSticky("volume")
    }

    function openBrightnessMode() {
        if (controlRing) controlRing.openSticky("brightness")
    }

    function toggleControlRing(kind) {
        if (controlRing) controlRing.openSticky(kind)
    }

    // 2. Battery
    readonly property var batteryDev: UPower.displayDevice
    readonly property int batteryPct: batteryDev ? Math.round(batteryDev.percentage * 100) : 100
    readonly property bool isCharging: batteryDev ? (batteryDev.state === 1 || batteryDev.state === 4) : false

    // 3. Workspaces (Hyprland)
    property int activeWs: 1
    Connections {
        target: Hyprland.focusedMonitor
        function onActiveWorkspaceChanged() {
            if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace) {
                root.activeWs = Hyprland.focusedMonitor.activeWorkspace.id
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            const n = event.name
            if (n === "workspace" || n === "workspacev2") {
                const id = parseInt(event.data, 10)
                if (!isNaN(id) && id > 0) root.activeWs = id
            }
        }
    }
    function switchWorkspace(id) {
        root.activeWs = id
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + id + " })"])
    }

    /* ── Spotlight Engine for App Launcher (Vanish Mode) ── */
    property string launcherTab: "apps" // "apps" | "clipboard" | "commands"
    property string calcResult: ""
    property bool hasCalcResult: false
    property var clipboardItems: []

    readonly property var systemActions: [
        {
            id: "screenshot-region",
            title: "Screenshot Region",
            desc: "Select a region on screen and copy to clipboard",
            glyph: "crop",
            run: () => {
                root.close()
                Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-screenshot-region.sh"])
            }
        },
        {
            id: "screenshot-full",
            title: "Screenshot Full Screen",
            desc: "Capture all monitors and save to Pictures",
            glyph: "photo_camera",
            run: () => {
                root.close()
                Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-screenshot-full.sh"])
            }
        },
        {
            id: "wallpaper",
            title: "Change Wallpaper",
            desc: "Open Carbon dynamic wallpaper picker",
            glyph: "wallpaper",
            run: () => {
                root.openWallpaperMode()
            }
        },
        {
            id: "config",
            title: "Carbon Config & Theme Editor",
            desc: "Configure shell layout, notch mode, and keybinds",
            glyph: "settings",
            run: () => {
                root.close()
                Quickshell.execDetached(["python3", root.home + "/.config/hypr/scripts/carbon-config-editor.py"])
            }
        },
        {
            id: "terminal",
            title: "Open Terminal",
            desc: "Launch kitty terminal emulator",
            glyph: "terminal",
            run: () => {
                root.close()
                Quickshell.execDetached(["kitty"])
            }
        },
        {
            id: "lock",
            title: "Lock Screen",
            desc: "Lock the desktop session with Carbon Lock",
            glyph: "lock",
            run: () => {
                root.close()
                Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-ipc.sh", "lock"])
            }
        },
        {
            id: "suspend",
            title: "Sleep / Suspend",
            desc: "Put the system into low power sleep mode",
            glyph: "bedtime",
            run: () => {
                root.close()
                Quickshell.execDetached(["systemctl", "suspend"])
            }
        },
        {
            id: "restart-shell",
            title: "Restart Carbon Shell",
            desc: "Reload Quickshell process and UI",
            glyph: "refresh",
            run: () => {
                root.close()
                Quickshell.execDetached(["sh", "-c", "systemctl --user restart carbon-quickshell.service 2>/dev/null || (pkill -9 quickshell; sleep 0.4; quickshell --config " + root.home + "/.local/share/quickshell/carbon &)"])
            }
        }
    ]

    /* Clipboard Fetcher via cliphist */
    Process {
        id: hubCliphistProcess
        command: ["sh", "-c", "cliphist list | head -n 40"]
        running: false
        stdout: StdioCollector {
            id: hubClipCol
            waitForEnd: true
        }
        onExited: {
            const raw = String(hubClipCol.text || "").trim()
            if (!raw) return
            const lines = raw.split("\n")
            const items = []
            for (let i = 0; i < lines.length; i++) {
                const l = lines[i]
                if (!l) continue
                const tabIdx = l.indexOf("\t")
                if (tabIdx > 0) {
                    const id = l.substring(0, tabIdx).trim()
                    const preview = l.substring(tabIdx + 1).trim()
                    items.push({ id: id, raw: l, preview: preview })
                }
            }
            root.clipboardItems = items
            root.filterApps(appSearchInput ? appSearchInput.text : "")
        }
    }

    function refreshClipboard() {
        hubCliphistProcess.running = false
        hubCliphistProcess.running = true
    }

    /* Calculator via qalc */
    Timer {
        id: hubQalcDebounceTimer
        interval: 60
        onTriggered: {
            const q = appSearchInput ? appSearchInput.text.trim() : ""
            if (q.length === 0) {
                root.calcResult = ""
                root.hasCalcResult = false
                return
            }
            const hasMath = /^[=]/.test(q) || (/[0-9]/.test(q) && /[+\-*\/^%=()]/.test(q)) || /(sqrt|sin|cos|tan|log|ln|pi|to\s+[a-z]+)/i.test(q)
            if (hasMath) {
                const expr = q.replace(/^=\s*/, "")
                hubQalcProcess.running = false
                hubQalcProcess.command = ["qalc", "-t", "-m", "500", expr]
                hubQalcProcess.running = true
            } else {
                root.calcResult = ""
                root.hasCalcResult = false
            }
        }
    }

    Process {
        id: hubQalcProcess
        running: false
        stdout: StdioCollector {
            id: hubQalcCol
            waitForEnd: true
        }
        onExited: {
            const res = String(hubQalcCol.text || "").trim()
            if (res.length > 0 && !res.toLowerCase().startsWith("error") && !res.toLowerCase().includes("syntax error") && !res.toLowerCase().includes("parse error")) {
                root.calcResult = res
                root.hasCalcResult = true
            } else {
                root.calcResult = ""
                root.hasCalcResult = false
            }
            root.filterApps(appSearchInput ? appSearchInput.text : "")
        }
    }

    function copyCalcResult() {
        if (!root.calcResult) return
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(root.calcResult) + " | wl-copy"])
        root.close()
    }

    // 4. Notifications
    readonly property int unreadNotifCount: NotificationService.unreadCount

    /* ── Animation Progress Constants ── */
    property real hubProgress: root.nucleusExpanded ? 1.0 : 0.0
    Behavior on hubProgress {
        NumberAnimation {
            duration: 260
            easing.type: Easing.InOutCubic
        }
    }

    /* ── Media Playback Morph Progress (0.0 = idle carbon clock, 1.0 = media playing) ── */
    readonly property bool isMediaPlaying: LyricsService.hasTrack && LyricsService.isPlaying
    property real mediaPlayProgress: isMediaPlaying ? 1.0 : 0.0
    Behavior on mediaPlayProgress {
        NumberAnimation {
            duration: 450
            easing.type: Easing.InOutCubic
        }
    }

    /* ── Dim Scrim Background ── */
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.effectiveScrimOpacity
        visible: opacity > 0.005
        Behavior on opacity {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (root.isClosingHub) return
                if (root.notifPanelOpen) {
                    root.notifPanelOpen = false
                    return
                }
                if (root.activeMode === "power") {
                    // In power mode, do not close on background click — only close on Escape key
                    return
                } else {
                    root.close()
                }
            }
        }
    }

    /* ── Keyboard Handling (Escape to close or back, typing to search) ── */
    Item {
        id: globalKeyHandler
        focus: root.hubOpen && !root.isClosingHub && root.activeMode !== "appsearch" && root.activeMode !== "wifi" && root.activeMode !== "bluetooth" && root.activeMode !== "calendar"
        Keys.onEscapePressed: {
            if (root.notifPanelOpen) {
                root.notifPanelOpen = false
            } else if (controlRing && controlRing.isOpen) {
                controlRing.closeRing()
            } else if (root.activeMode === "wifi" || root.activeMode === "bluetooth") {
                if (connectivityPicker) connectivityPicker.goBack()
            } else if (root.activeMode === "battery") {
                root.closeBatteryMode()
            } else if (root.activeMode === "power") {
                if (root.cancelPowerAction()) return
                root.close()
            } else if (root.activeMode === "appsearch" || root.activeMode === "calendar") {
                root.activeMode = "hub"
            } else if (root.focusedLobe !== "") {
                root.focusedLobe = ""
            } else {
                root.close()
            }
        }
        Keys.onPressed: (event) => {
            if (root.activeMode === "hub" && event.text && event.text.length > 0 && (!event.modifiers || event.modifiers === Qt.ShiftModifier)) {
                const ch = event.text
                if (ch.trim().length > 0) {
                    root.openLauncherMode(ch)
                }
            }
        }
    }

    /* ══════════════════════════════════════════════════════════════════════════
       PHASE 1: Resting Carbon Dot & Expanding Ripple + Nucleus
       ══════════════════════════════════════════════════════════════════════════ */

    // Full Hub Arena Centered
    Item {
        id: hubCenter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        readonly property real maxSlideUp: Math.max(0.0, ((root.height / 2) + 340) - (root.height - 24))
        anchors.verticalCenterOffset: -(maxSlideUp * (connectivityPicker ? connectivityPicker.transitionProgress : 0.0))
        width: 1
        height: 1

        /* ══════════════════════════════════════════════════════════════════════
           PHASE 2: The Four sp3 Hybrid Orbital Lobes
           Teardrop Bezier Curves: M0,0 C22,-36 80,-38 100,0 C80,38 22,36 0,0
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: lobesLayer
            anchors.centerIn: parent
            readonly property real pickerShrink: (connectivityPicker && (root.activeMode === "wifi" || root.activeMode === "bluetooth" || connectivityPicker.transitionProgress > 0.001)) ? Math.max(0.0, 1.0 - connectivityPicker.transitionProgress) : 1.0
            scale: pickerShrink
            visible: (root.hubOpen || root.isClosingHub || (root.hubProgress > 0.01)) && (root.activeMode === "hub" || (connectivityPicker && connectivityPicker.transitionProgress > 0.001)) && !(controlRing && controlRing.isOpen)
            opacity: (root.activeMode === "hub" && !(controlRing && controlRing.isOpen)) ? (((root.hubOpen || root.isClosingHub) ? 1.0 : root.hubProgress) * pickerShrink) : pickerShrink
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            // Lobe template component
            component OrbitalLobe: Item {
                id: lobeItem
                property string lobeId: ""
                property real targetAngle: 0
                property real orbitalRadius: 155
                property real baseScale: 1.0
                property color lobeColor: root.colTeal
                property string iconGlyph: ""
                property string lobeTitle: ""
                property int staggerDelay: 0
                property int retractDelay: 0

                Behavior on orbitalRadius { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on targetAngle { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

                // Gentle organic quantum idle float (continuous 60fps harmonic, zero pause/restart)
                property int idleDuration: 5400
                property int idlePhaseDelay: 0
                readonly property real idleAngleOffset: (!root.isClosingHub && !lobeItem.isThisFocused && (root.activeMode === "hub" || root.activeMode === ""))
                    ? (1.4 * Math.sin(root.continuousPhase * 0.75 + (lobeItem.idlePhaseDelay / 5400.0) * 6.28318))
                    : 0.0
                readonly property real idleDistOffset: (!root.isClosingHub && !lobeItem.isThisFocused && (root.activeMode === "hub" || root.activeMode === ""))
                    ? (2.5 * Math.cos(root.continuousPhase * 0.75 + (lobeItem.idlePhaseDelay / 5400.0) * 6.28318))
                    : 0.0

                // Alerts Lobe remains in its natural orbit position (no jumping away from cursor)
                readonly property bool isThisAlerts: lobeItem.lobeId === "alerts"
                readonly property bool isAlertsFocused: root.focusedLobe === "alerts"
                readonly property real alertShiftX: 0
                readonly property real alertShiftY: 0

                property real animAlertX: 0
                property real animAlertY: 0

                // Origin is at center of hub, with gentle radial displacement + alert shift
                readonly property real idleRad: targetAngle * (Math.PI / 180.0)
                x: ((isThisFocused || root.isClosingHub) ? 0 : (idleDistOffset * Math.cos(idleRad))) + animAlertX
                y: ((isThisFocused || root.isClosingHub) ? 0 : (idleDistOffset * Math.sin(idleRad))) + animAlertY
                width: 1
                height: 1
                transformOrigin: Item.TopLeft

                // Geometry
                readonly property bool isThisFocused: root.focusedLobe === lobeItem.lobeId
                readonly property bool isAnyFocused: root.focusedLobe !== ""

                // Dynamic Scale & Opacity:
                // Keep Alert Lobe identical in scale to other lobes when focused
                readonly property real targetScale: isThisFocused
                    ? 0.92
                    : (isAnyFocused ? (baseScale * 0.45) : baseScale)
                readonly property real targetAlpha: isThisFocused
                    ? 1.0
                    : (isAnyFocused ? 0.35 : 1.0)

                property real focusScale: targetScale
                Behavior on focusScale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                property real focusAlpha: targetAlpha
                Behavior on focusAlpha { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                property real bloomAnim: 0.0

                Connections {
                    target: root
                    function onHubOpenChanged() {
                        if (root.hubOpen && !root.isClosingHub && root.activeMode === "hub") {
                            lobeRetractSeq.stop()
                            lobeBloomSeq.restart()
                        }
                    }
                    function onIsClosingHubChanged() {
                        if (root.isClosingHub) {
                            lobeBloomSeq.stop()
                            lobeRetractSeq.restart()
                        } else if (root.hubOpen && root.activeMode === "hub") {
                            lobeRetractSeq.stop()
                            lobeBloomSeq.restart()
                        }
                    }
                    function onActiveModeChanged() {
                        if (root.hubOpen && !root.isClosingHub && root.activeMode === "hub") {
                            lobeRetractSeq.stop()
                            lobeBloomSeq.restart()
                        } else if (root.activeMode !== "hub") {
                            lobeBloomSeq.stop()
                            lobeRetractSeq.restart()
                        }
                    }
                }

                // Dynamic distance: on opening and closing, the satellites physically travel between the central nucleus and orbit
                readonly property real currentRadius: lobeItem.orbitalRadius * bloomAnim

                SequentialAnimation {
                    id: lobeRetractSeq
                    PauseAnimation { duration: lobeItem.retractDelay }
                    NumberAnimation {
                        target: lobeItem
                        property: "bloomAnim"
                        to: 0.0
                        duration: 250
                        easing.type: Easing.InCubic
                    }
                }

                SequentialAnimation {
                    id: lobeBloomSeq
                    running: root.hubOpen && !root.isClosingHub && root.activeMode === "hub"
                    PauseAnimation { duration: lobeItem.staggerDelay }
                    NumberAnimation {
                        target: lobeItem
                        property: "bloomAnim"
                        from: 0.0
                        to: 1.0
                        duration: 360
                        easing.type: Easing.OutCubic
                    }
                }

                rotation: targetAngle + (isThisFocused ? 0.0 : idleAngleOffset)
                scale: focusScale * (0.68 + 0.32 * bloomAnim)
                opacity: focusAlpha * (bloomAnim > 0.04 ? 1.0 : (bloomAnim * 25.0))

                property int hoveredSatellitesCount: 0
                readonly property bool isClusterHovered: lobeMouse.containsMouse || bridgeMouse.containsMouse || (hoveredSatellitesCount > 0)

                Timer {
                    id: unfocusDebounceTimer
                    interval: 420
                    repeat: false
                    onTriggered: {
                        if (lobeItem.lobeId === "alerts" && root.notifPanelOpen) {
                            return
                        }
                        if (!lobeItem.isClusterHovered && root.focusedLobe === lobeItem.lobeId && (root.activeMode === "hub" || root.activeMode === "")) {
                            root.focusedLobe = ""
                        }
                    }
                }

                Connections {
                    target: root
                    function onFocusedLobeChanged() {
                        if (root.focusedLobe !== lobeItem.lobeId) {
                            lobeItem.hoveredSatellitesCount = 0
                            unfocusDebounceTimer.stop()
                        }
                    }
                    function onHubOpenChanged() {
                        if (!root.hubOpen) {
                            lobeItem.hoveredSatellitesCount = 0
                            unfocusDebounceTimer.stop()
                        }
                    }
                }

                // ── Hit bridge keeping hover active when traversing between lobe button and satellites ──
                Item {
                    id: lobeHitBridge
                    x: lobeItem.currentRadius - 35
                    y: -85
                    width: 135
                    height: 170
                    visible: lobeItem.isThisFocused
                    z: -1
                    MouseArea {
                        id: bridgeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            lobeItem.hoveredSatellitesCount++
                            unfocusDebounceTimer.stop()
                        }
                        onExited: {
                            lobeItem.hoveredSatellitesCount = Math.max(0, lobeItem.hoveredSatellitesCount - 1)
                            if (lobeItem.hoveredSatellitesCount === 0 && !lobeMouse.containsMouse) {
                                unfocusDebounceTimer.restart()
                            }
                        }
                        onPressed: (mouse) => { mouse.accepted = true }
                        onReleased: (mouse) => { mouse.accepted = true }
                        onClicked: (mouse) => { mouse.accepted = true }
                    }
                }

                // ── 48px Standalone Round Icon Button at dynamic orbitalRadius ──
                Item {
                    id: lobeTipButton
                    readonly property real btnSize: 48
                    x: lobeItem.currentRadius - (btnSize / 2)
                    y: -(btnSize / 2)
                    width: btnSize
                    height: btnSize

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: lobeMouse.containsMouse 
                               ? Qt.rgba(lobeItem.lobeColor.r, lobeItem.lobeColor.g, lobeItem.lobeColor.b, 0.40) 
                               : (lobeItem.isThisFocused 
                                  ? Qt.rgba(lobeItem.lobeColor.r, lobeItem.lobeColor.g, lobeItem.lobeColor.b, 0.30)
                                  : Qt.rgba(root.colBgDark.r, root.colBgDark.g, root.colBgDark.b, 0.92))
                        border.color: lobeItem.lobeColor
                        border.width: 2.0
                        scale: lobeMouse.containsMouse ? 1.08 : 1.0
                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                        MonolineIcon {
                            anchors.centerIn: parent
                            name: lobeItem.iconGlyph
                            size: 22
                            strokeColor: lobeMouse.containsMouse || lobeItem.isThisFocused ? "#ffffff" : lobeItem.lobeColor
                            strokeWidth: 1.75
                            rotation: -lobeItem.rotation
                        }

                        // Alerts Lobe Unread Count Badge (top-right, coral #f2705f, 2px dark border, bump scale 1 -> 1.6 -> 1 over 500ms)
                        Rectangle {
                            id: notifBadgeItem
                            visible: lobeItem.lobeId === "alerts" && NotificationService.unreadCount > 0
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.topMargin: -4
                            anchors.rightMargin: -4
                            width: Math.max(18, badgeText.implicitWidth + 8)
                            height: 18
                            radius: 9
                            color: Theme.accent
                            border.color: root.colBgDark
                            border.width: 2.0
                            rotation: -lobeItem.rotation

                            property real badgeBump: 1.0
                            scale: badgeBump
                            transformOrigin: Item.Center

                            SequentialAnimation {
                                id: notifBadgeBumpAnim
                                NumberAnimation { target: notifBadgeItem; property: "badgeBump"; to: 1.6; duration: 200; easing.type: Easing.OutBack }
                                NumberAnimation { target: notifBadgeItem; property: "badgeBump"; to: 1.0; duration: 300; easing.type: Easing.OutCubic }
                            }

                            Connections {
                                target: NotificationService
                                function onUnreadCountChanged() {
                                    if (NotificationService.unreadCount > 0 && lobeItem.lobeId === "alerts") {
                                        notifBadgeBumpAnim.restart()
                                    }
                                }
                            }

                            Text {
                                id: badgeText
                                anchors.centerIn: parent
                                text: NotificationService.unreadCount > 9 ? "9+" : String(NotificationService.unreadCount)
                                font.family: "Valley Sans"
                                font.pixelSize: 10
                                font.bold: true
                                color: Theme.accentFg
                            }
                        }

                        // Alerts Lobe DND Moon Mark (bottom-left, lavender #c9d0ff on dark circle)
                        Rectangle {
                            visible: lobeItem.lobeId === "alerts" && NotificationService.dnd
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.bottomMargin: -3
                            anchors.leftMargin: -3
                            width: 16
                            height: 16
                            radius: 8
                            color: root.colBgDark
                            border.color: "#c9d0ff"
                            border.width: 1.5
                            rotation: -lobeItem.rotation

                            MonolineIcon {
                                anchors.centerIn: parent
                                name: "moon"
                                size: 10
                                strokeColor: "#c9d0ff"
                                strokeWidth: 1.5
                            }
                        }
                    }

                    MouseArea {
                        id: lobeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            unfocusDebounceTimer.stop()
                            if (root.hubOpen && !root.isClosingHub && (root.activeMode === "hub" || root.activeMode === "")) {
                                root.focusedLobe = lobeItem.lobeId
                            }
                        }
                        onExited: {
                            if (lobeItem.hoveredSatellitesCount === 0) {
                                unfocusDebounceTimer.restart()
                            }
                        }
                        onClicked: {
                            if (!root.isClosingHub) {
                                root.focusLobe(lobeItem.lobeId)
                            }
                        }
                    }
                }

                /* ══════════════════════════════════════════════════════════════
                   PHASE 3: Satellites around tip when focused
                   Smooth blooming OutBack spring blossom animation
                   ══════════════════════════════════════════════════════════════ */
                Item {
                    id: satellitesContainer
                    x: lobeItem.currentRadius
                    y: 0
                    visible: opacity > 0.005
                    opacity: lobeItem.isThisFocused ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                    Repeater {
                        model: lobeItem.satelliteModel
                        delegate: Item {
                            id: satDelegateItem
                            required property int index
                            required property var modelData

                            // Symmetrical 4-node arc (38° spacing, 64px radius: centers ~41.7px apart for 38px nodes -> no overlap)
                            readonly property var satAngles: [-57, -19, 19, 57]
                            readonly property real relDeg: (index < satAngles.length) ? satAngles[index] : 0
                            readonly property real relRad: relDeg * (Math.PI / 180.0)
                            readonly property real satRadius: 64

                            property real satPop: lobeItem.isThisFocused ? 1.0 : 0.0
                            Behavior on satPop {
                                NumberAnimation {
                                    duration: 280
                                    easing.type: Easing.OutCubic
                                }
                            }

                            readonly property real subLobeSize: 38

                            // Radial position smoothly blooms outward with fluid spring
                            x: (satRadius * Math.cos(relRad) * satPop) - width / 2
                            y: (satRadius * Math.sin(relRad) * satPop) - height / 2
                            width: subLobeSize
                            height: subLobeSize
                            visible: (modelData.visible !== undefined) ? modelData.visible : true
                            scale: 0.35 + 0.65 * satPop
                            opacity: Math.min(1.0, satPop * 1.5)

                            // Circular Satellite Button
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: {
                                    if (modelData.customBg !== undefined) return modelData.customBg
                                    if (modelData.isActive) return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)
                                    if (satMouse.containsMouse) return Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.95)
                                    return Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.78)
                                }
                                border.color: {
                                    if (modelData.customBorder !== undefined) return modelData.customBorder
                                    if (modelData.isActive || satMouse.containsMouse) return Theme.primary
                                    return Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.42)
                                }
                                border.width: (modelData.customBorderWidth !== undefined) ? modelData.customBorderWidth : 1.5
                                scale: satMouse.containsMouse ? 1.12 : 1.0
                                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                                // Soft outer glow/ring when satellite has active ring (e.g. open panel)
                                Rectangle {
                                    visible: modelData.hasRing === true
                                    anchors.centerIn: parent
                                    width: parent.width + 8
                                    height: parent.height + 8
                                    radius: width / 2
                                    color: "transparent"
                                    border.color: Qt.rgba(1, 1, 1, 0.35)
                                    border.width: 1.5
                                }

                                MonolineIcon {
                                    anchors.centerIn: parent
                                    name: modelData.icon || ""
                                    size: 19
                                    strokeColor: {
                                        if (modelData.customColor !== undefined) return modelData.customColor
                                        if (modelData.isActive || satMouse.containsMouse) return "#ffffff"
                                        return Qt.lighter(Theme.primary, 1.35)
                                    }
                                    strokeWidth: 1.75
                                    rotation: -lobeItem.rotation
                                }

                                // Unread notification dot indicator (vibrant solid red circle, no numbers)
                                Item {
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: parent.height
                                    rotation: -lobeItem.rotation
                                    visible: modelData.badgeCount !== undefined && modelData.badgeCount > 0

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.topMargin: 2
                                        anchors.rightMargin: 2
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: "#ff2222"
                                        border.width: 1
                                        border.color: Qt.rgba(0, 0, 0, 0.45)
                                    }
                                }

                                MouseArea {
                                    id: satMouse
                                    anchors.centerIn: parent
                                    width: 44
                                    height: 44
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        lobeItem.hoveredSatellitesCount++
                                        unfocusDebounceTimer.stop()
                                    }
                                    onExited: {
                                        lobeItem.hoveredSatellitesCount = Math.max(0, lobeItem.hoveredSatellitesCount - 1)
                                        if (lobeItem.hoveredSatellitesCount === 0 && !lobeMouse.containsMouse && !bridgeMouse.containsMouse) {
                                            unfocusDebounceTimer.restart()
                                        }
                                    }
                                    onClicked: {
                                        modelData.action()
                                    }
                                }
                            }
                        }
                    }
                }

                // Placeholder property overridden per lobe instance
                property var satelliteModel: []
            }

            // ── 1. CONNECT (Top-Left / Hardware & Connectivity, Color: Teal) ──────────
            OrbitalLobe {
                id: lobeConnect
                lobeId: "connect"
                targetAngle: 235
                baseScale: 1.00
                staggerDelay: 0
                retractDelay: 135
                idleDuration: 5200
                idlePhaseDelay: 0
                lobeColor: root.colTeal
                iconGlyph: "sliders"
                lobeTitle: "Connect"

                satelliteModel: [
                    {
                        icon: "wifi",
                        isActive: root.activeMode === "wifi",
                        action: function() {
                            root.openWifiMode()
                        }
                    },
                    {
                        icon: "bluetooth",
                        isActive: root.activeMode === "bluetooth",
                        action: function() {
                            root.openBluetoothMode()
                        }
                    },
                    {
                        icon: "volume",
                        isActive: controlRing && controlRing.isOpen && controlRing.kind === "volume",
                        action: function() {
                            root.toggleControlRing("volume")
                        }
                    },
                    {
                        icon: "sun",
                        isActive: controlRing && controlRing.isOpen && controlRing.kind === "brightness",
                        visible: controlRing ? controlRing.hasBacklight : true,
                        action: function() {
                            root.toggleControlRing("brightness")
                        }
                    }
                ]
            }

            // ── 2. LAUNCH / UTILITIES (Right / System Utilities & Capture, Color: Purple) ────
            OrbitalLobe {
                id: lobeLaunch
                lobeId: "launch"
                targetAngle: 345
                baseScale: 0.88
                staggerDelay: 90
                retractDelay: 90
                idleDuration: 6200
                idlePhaseDelay: 1200
                lobeColor: root.colPurple
                iconGlyph: "command"
                lobeTitle: "Utilities"

                satelliteModel: [
                    {
                        icon: "search",
                        isActive: root.activeMode === "appsearch",
                        action: function() {
                            root.openLauncherMode()
                        }
                    },
                    {
                        icon: "crop",
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["grimblast", "copysave", "area"])
                        }
                    },
                    {
                        icon: "file-text",
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["sh", "-c", "kitty -e micro || kitty"])
                        }
                    },
                    {
                        icon: "settings",
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["sh", (Quickshell.env("HOME") || "") + "/.config/carbon/scripts/carbon-ipc.sh", "wallpaper"])
                        }
                    }
                ]
            }

            // ── 3. SPACES / APPS (Left / Core Apps & Dev Shortcuts, Color: Coral) ──────────
            OrbitalLobe {
                id: lobeSpaces
                lobeId: "spaces"
                targetAngle: 195
                baseScale: 1.05
                staggerDelay: 180
                retractDelay: 45
                idleDuration: 5600
                idlePhaseDelay: 2400
                lobeColor: root.colCoral
                iconGlyph: "layout-grid"
                lobeTitle: "Apps"

                satelliteModel: [
                    {
                        icon: "terminal",
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["kitty"])
                        }
                    },
                    {
                        icon: "globe",
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["xdg-open", "https://google.com"])
                        }
                    },
                    {
                        icon: "code",
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["sh", "-c", "code || antigravity || kitty -e micro || kitty"])
                        }
                    },
                    {
                        icon: "folder",
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["xdg-open", Quickshell.env("HOME") || "."])
                        }
                    }
                ]
            }

            // ── 4. ALERTS (Top-Right / Productivity & Time, Color: Amber) ──────────
            OrbitalLobe {
                id: lobeAlerts
                lobeId: "alerts"
                targetAngle: 305
                baseScale: 1.00
                staggerDelay: 270
                retractDelay: 0
                idleDuration: 6800
                idlePhaseDelay: 3600
                lobeColor: root.colAmber
                iconGlyph: "sparkles"
                lobeTitle: "Alerts"

                satelliteModel: [
                    {
                        // Small bell: toggles notification panel
                        icon: "bell",
                        isActive: root.notifPanelOpen,
                        customBg: root.notifPanelOpen ? "#ffffff" : undefined,
                        customColor: root.notifPanelOpen ? "#0f1416" : undefined,
                        customBorder: root.notifPanelOpen ? "#ffffff" : undefined,
                        hasRing: root.notifPanelOpen,
                        badgeCount: root.notifPanelOpen ? 0 : root.unreadNotifCount,
                        action: function() {
                            root.toggleNotifPanel()
                        }
                    },
                    {
                        // Calendar
                        icon: "calendar",
                        isActive: root.activeMode === "calendar",
                        action: function() {
                            root.openCalendarMode()
                        }
                    },
                    {
                        // Clipboard
                        icon: "clipboard",
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["sh", "-c", "cliphist list | fuzzel -d | cliphist decode | wl-copy || true"])
                        }
                    },
                    {
                        // Focus / Timer
                        icon: "timer",
                        isActive: false,
                        action: function() {
                            Quickshell.execDetached(["notify-send", "Focus Timer", "25-minute focus session started", "-i", "alarm"])
                        }
                    }
                ]
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           CENTER NUCLEUS ORB (Lockscreen ValenceDot Bohr Atom Styling)
           - Glowing outer neon halo matching lockscreen dots
           - Vibrant crisp core disc (White with neon accent border)
           - Inner bright dot when resting; clear bold time display when open
           ══════════════════════════════════════════════════════════════════════ */

        // Resting Carbon Valence Orbit Rings & 6 Electrons (fades in as core disc shrinks)
        Item {
            id: hubRestingElectrons
            z: -1
            anchors.centerIn: parent
            visible: root.showRestingAtom && root.hubProgress < 0.65 && root.activeMode === "hub"
            opacity: Math.max(0.0, Math.min(1.0, (0.65 - root.hubProgress) / 0.65))
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

            // Ring 1 (Inner, 2 electrons)
            Rectangle {
                anchors.centerIn: parent
                width: 40; height: 40; radius: 20
                color: "transparent"
                border.color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.22)
                border.width: 1

                Item {
                    id: hubRing1Orbit
                    anchors.centerIn: parent
                    width: parent.width; height: parent.height
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -3.5; width: 6; height: 6; radius: 3; color: root.colTeal
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height - 2.5; width: 6; height: 6; radius: 3; color: root.colTeal
                    }

                    NumberAnimation on rotation {
                        from: 0
                        to: 360
                        duration: 18000
                        loops: Animation.Infinite
                        easing.type: Easing.Linear
                        running: hubRestingElectrons.visible && hubRestingElectrons.opacity > 0.01
                    }
                }
            }

            // Ring 2 (Outer, 4 electrons)
            Rectangle {
                anchors.centerIn: parent
                width: 72; height: 72; radius: 36
                color: "transparent"
                border.color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.16)
                border.width: 1

                Item {
                    id: hubRing2Orbit
                    anchors.centerIn: parent
                    width: parent.width; height: parent.height
                    rotation: 45
                    Repeater {
                        model: 4
                        delegate: Item {
                            anchors.fill: parent
                            rotation: index * 90
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: -3.5; width: 6; height: 6; radius: 3; color: root.colTeal
                            }
                        }
                    }

                    NumberAnimation on rotation {
                        from: 45
                        to: -315
                        duration: 28000
                        loops: Animation.Infinite
                        easing.type: Easing.Linear
                        running: hubRestingElectrons.visible && hubRestingElectrons.opacity > 0.01
                    }
                }
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           ROAMING CARBON SVG DASHED ORBITS & COMET SATELLITES (Compact Reference Match)
           ══════════════════════════════════════════════════════════════════════ */
        Canvas {
            id: roamingCarbonOrbits
            z: 2
            anchors.centerIn: parent
            width: 148
            height: 148
            visible: (root.hubProgress > 0.05) && (root.activeMode === "hub") && !(controlRing && controlRing.isOpen)
            opacity: (root.hubProgress > 0.15 && root.activeMode === "hub" && !(controlRing && controlRing.isOpen)) ? root.hubProgress : 0.0
            scale: 0.8 + (0.2 * root.hubProgress)
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            renderTarget: Canvas.FramebufferObject
            renderStrategy: Canvas.Threaded

            Connections {
                target: root
                function onContinuousPhaseChanged() {
                    if (roamingCarbonOrbits.visible) roamingCarbonOrbits.requestPaint()
                }
                function onMediaPlayProgressChanged() {
                    if (roamingCarbonOrbits.visible) roamingCarbonOrbits.requestPaint()
                }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.save()
                ctx.clearRect(0, 0, width, height)

                var cx = width / 2.0
                var cy = height / 2.0
                var phase = root.continuousPhase
                var m = root.mediaPlayProgress // 0.0 = idle (Pic 2), 1.0 = playing (Pic 1)

                // Theme primary accent color (warm gold/champagne/teal)
                var primaryCol = (Theme.primary || root.colTeal || Qt.rgba(201/255, 190/255, 146/255, 1.0))

                ctx.lineCap = "round"

                // ── Track 1 (Inner Arc, r = 37.0px): Exactly 3 pieces of equal length (28px each), 120° apart ──
                if (m < 0.99) {
                    var r1 = 37.0
                    var a1 = -phase * 0.28
                    var alpha1 = 0.38 * (1.0 - m)
                    var arcHalfSpan1 = (28.0 / r1) / 2.0
                    var stepAngle1 = (2.0 * Math.PI) / 3.0

                    ctx.save()
                    ctx.setLineDash([])
                    ctx.lineWidth = 3.8
                    ctx.strokeStyle = Qt.rgba(240/255, 242/255, 240/255, alpha1)
                    for (var k = 0; k < 3; k++) {
                        var angle1 = a1 + (k * stepAngle1)
                        ctx.beginPath()
                        ctx.arc(cx, cy, r1, angle1 - arcHalfSpan1, angle1 + arcHalfSpan1)
                        ctx.stroke()
                    }
                    ctx.restore()
                }

                // ── Track 2 (Mid Arc / Ring after Visualizer): Exactly 3 pieces of equal length (38px each), 120° apart ──
                // In idle: r = 48.0px. When media plays: expands to r = 54.0px with space for visualizer
                var r2 = 48.0 + (6.0 * m)
                var a2 = phase * 0.24
                var arcHalfSpan2 = (38.0 / r2) / 2.0
                var stepAngle2 = (2.0 * Math.PI) / 3.0
                var alpha2 = 0.36 + (0.09 * m)

                ctx.save()
                ctx.setLineDash([])
                ctx.lineWidth = 3.8
                ctx.strokeStyle = Qt.rgba(240/255, 242/255, 240/255, alpha2)
                for (var i = 0; i < 3; i++) {
                    var centerAngle = a2 + (i * stepAngle2)
                    ctx.beginPath()
                    ctx.arc(cx, cy, r2, centerAngle - arcHalfSpan2, centerAngle + arcHalfSpan2)
                    ctx.stroke()
                }
                ctx.restore()

                // ── Track 3 (Satellite Orbit Track & 2 Bullseye Satellites, r = 59.5px) ──
                // Present in normal idle mode (Pic 2); removed when media is playing to create breathing room
                if (m < 0.99) {
                    var r3 = 59.5
                    var satRadius = 59.5
                    var satAngle = -phase * 0.24
                    var tailAngleRad = 36.0 * (Math.PI / 180.0) // 36° tail
                    var satAlphaFactor = (1.0 - m)
                    var alpha3 = 0.26 * satAlphaFactor

                    // ── Synchronized Orbit Arcs (placed symmetrically in gaps between the 2 orbs so they never collide) ──
                    var arcHalfSpan3 = (34.0 * Math.PI) / 180.0 // 68° arc length
                    var gapMidOffset = (Math.PI + tailAngleRad) / 2.0 // Center of gap between comet tail and next satellite

                    ctx.save()
                    ctx.setLineDash([])
                    ctx.lineWidth = 2.4
                    ctx.strokeStyle = Qt.rgba(240/255, 242/255, 240/255, alpha3)
                    for (var s = 0; s < 2; s++) {
                        var midAngle = satAngle + gapMidOffset + (s * Math.PI)
                        ctx.beginPath()
                        ctx.arc(cx, cy, r3, midAngle - arcHalfSpan3, midAngle + arcHalfSpan3)
                        ctx.stroke()
                    }
                    ctx.restore()

                    // ── Two Bullseye Satellite Nodes with 36° Fading Comet Tails (r = 59.5px) ──
                    function drawSatellite(centerAngle) {
                        var tailSteps = 24
                        var tailStepAngle = tailAngleRad / tailSteps
                        for (var t = 0; t < tailSteps; t++) {
                            var aStart = centerAngle + t * tailStepAngle
                            var aEnd = centerAngle + (t + 1) * tailStepAngle
                            var frac = 1.0 - (t / tailSteps)
                            var alpha = frac * 0.60 * satAlphaFactor
                            ctx.beginPath()
                            ctx.arc(cx, cy, satRadius, aStart, aEnd)
                            ctx.lineWidth = 2.2 * (0.5 + 0.5 * frac)
                            ctx.strokeStyle = Qt.rgba(primaryCol.r, primaryCol.g, primaryCol.b, alpha)
                            ctx.stroke()
                        }

                        var sx = cx + satRadius * Math.cos(centerAngle)
                        var sy = cy + satRadius * Math.sin(centerAngle)

                        ctx.beginPath()
                        ctx.arc(sx, sy, 5.8, 0, 2 * Math.PI)
                        ctx.lineWidth = 1.2
                        ctx.strokeStyle = Qt.rgba(primaryCol.r, primaryCol.g, primaryCol.b, 0.70 * satAlphaFactor)
                        ctx.fillStyle = Qt.rgba(primaryCol.r, primaryCol.g, primaryCol.b, 0.12 * satAlphaFactor)
                        ctx.fill()
                        ctx.stroke()

                        ctx.beginPath()
                        ctx.arc(sx, sy, 3.0, 0, 2 * Math.PI)
                        ctx.fillStyle = Qt.rgba(primaryCol.r, primaryCol.g, primaryCol.b, satAlphaFactor)
                        ctx.fill()
                    }

                    drawSatellite(satAngle)
                    drawSatellite(satAngle + Math.PI)
                }

                ctx.restore()
            }
        }

        Item {
            id: nucleusCore
            anchors.centerIn: parent
            width: {
                if (root.activeMode === "power" && root.powerAction !== "none" && !root.powerReducedMotion) {
                    var t = root.powerActionT
                    if (t < 500.0) {
                        return 44.0 - 28.0 * root.easeOutCubic(t / 500.0)
                    }
                    if (root.powerAction === "restart" && t >= 2100.0 && t <= 2600.0) {
                        return 16.0 + 28.0 * root.easeOutCubic((t - 2100.0) / 500.0)
                    }
                    if (root.powerAction === "restart" && t > 2600.0) {
                        return 44.0
                    }
                    return 16.0
                }
                if (root.activeMode === "power") return 44.0
                return root.nucleusExpanded ? 58 : 16
            }
            height: width
            z: 10
            visible: (root.activeMode === "hub" || root.activeMode === "power")
            opacity: {
                if (root.activeMode === "power" && root.powerAction === "shutdown" && root.powerActionT >= 2200.0 && !root.powerReducedMotion) {
                    return Math.max(0.0, 1.0 - (root.powerActionT - 2200.0) / 400.0)
                }
                if (!root.showRestingAtom && root.isClosingHub) {
                    return root.hubProgress
                }
                return (root.activeMode === "hub" || root.activeMode === "power") ? 1.0 : 0.0
            }
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

            // Glowing Outer Halo (matches lockscreen ValenceDot halo)
            Rectangle {
                id: nucleusHalo
                z: 0
                anchors.centerIn: parent
                width: nucleusCore.width + (root.nucleusExpanded ? 24 : 10)
                height: width
                radius: width / 2
                color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.28)
                opacity: (root.activeMode === "power") ? 0.0 : (root.nucleusExpanded ? 0.40 : 0.25)
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }
            }

            // Siri-style Audio Visualizer (Liquid Halo & Selectable Designs)
            VisualizerHost {
                id: nucleusVisualizerHost
                z: 1
                anchors.centerIn: parent
                width: 140
                height: 140
                hostVisible: (root.hubOpen || root.hubProgress > 0.05 || root.isMediaPlaying) && (root.activeMode === "hub")
                opacity: (root.activeMode === "hub") ? (root.nucleusExpanded ? root.mediaPlayProgress : (root.mediaPlayProgress * 0.90)) : 0.0
                scale: 0.58 + (0.42 * root.hubProgress)
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
            }

            // Clockwise Halo Ring (radius 27px, fills white clockwise over 600ms on hold)
            Shape {
                id: nucleusHoldRingShape
                anchors.centerIn: parent
                width: 54
                height: 54
                z: 3
                visible: root.nucleusHoldProgress > 0.001
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeWidth: 2.5
                    strokeColor: "#FFFFFF"
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 27
                    startY: 0
                    PathAngleArc {
                        centerX: 27
                        centerY: 27
                        radiusX: 27
                        radiusY: 27
                        startAngle: -90
                        sweepAngle: Math.max(0.1, Math.min(359.9, root.nucleusHoldProgress * 360.0))
                    }
                }
            }

            // Lock Seal Ring (radius 52px, 2px white, sweeps clockwise 500-1000ms)
            Shape {
                id: lockSealRing
                anchors.centerIn: parent
                width: 104
                height: 104
                z: 4
                visible: root.powerAction === "lock" && root.powerActionT >= 500.0 && root.powerActionT <= 1200.0 && !root.powerReducedMotion
                layer.enabled: true
                layer.samples: 4
                ShapePath {
                    strokeWidth: 2.0
                    strokeColor: "#FFFFFF"
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: 52
                    startY: 0
                    PathAngleArc {
                        centerX: 52
                        centerY: 52
                        radiusX: 52
                        radiusY: 52
                        startAngle: -90
                        sweepAngle: Math.max(0.1, Math.min(359.9, 360.0 * root.easeOutCubic(Math.min(1.0, (root.powerActionT - 500.0) / 500.0))))
                    }
                }
            }

            // Restart Flash Disc (radius expands to 60px, alpha 0.5 -> 0, at 1300-1600ms)
            Rectangle {
                anchors.centerIn: parent
                z: 5
                visible: root.powerAction === "restart" && root.powerActionT >= 1300.0 && root.powerActionT <= 1600.0 && !root.powerReducedMotion
                readonly property real pFlash: Math.min(1.0, (root.powerActionT - 1300.0) / 300.0)
                width: (60.0 * 2) * root.easeOutCubic(pFlash)
                height: width
                radius: width / 2
                color: "#FFFFFF"
                opacity: 0.5 * (1.0 - pFlash)
            }

            // Vibrant Core Disc (Sleek Dark Matugen Glass Surface with Crisp White Text)
            Rectangle {
                id: nucleusCoreDisc
                z: 2
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(0.08, 0.085, 0.10, 0.92)
                border.color: (root.activeMode === "power")
                    ? "transparent"
                    : Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.35)
                border.width: (root.activeMode === "power") ? 0 : 1.0
                Behavior on border.width { NumberAnimation { duration: 240; easing.type: Easing.InOutCubic } }

                // Time readout inside disc when open (fades out 0-500ms on action)
                Text {
                    anchors.centerIn: parent
                    visible: opacity > 0.01 && !(root.powerAction === "lock" && root.powerActionT >= 1000.0)
                    opacity: (root.activeMode === "power" && root.powerAction !== "none" && !root.powerReducedMotion)
                        ? Math.max(0.0, 1.0 - root.powerActionT / 500.0)
                        : root.hubProgress
                    text: {
                        if (controlRing && controlRing.isOpen) return controlRing.centerReadoutText
                        return root.timeStr
                    }
                    font.family: "JetBrainsMono Nerd Font, Valley Sans, Rubik, monospace"
                    font.pixelSize: Theme.fontPx((controlRing && controlRing.isOpen) ? 15 : ((root.activeMode === "power") ? 11 : 12.5))
                    font.bold: true
                    font.letterSpacing: 0.6
                    color: "#FFFFFF"
                }

                // Lock glyph replacing nucleus at t >= 1000ms
                Text {
                    anchors.centerIn: parent
                    visible: root.powerAction === "lock" && root.powerActionT >= 1000.0 && !root.powerReducedMotion
                    text: "lock"
                    font.family: Theme.fontIcon
                    font.pixelSize: 10
                    color: "#FFFFFF"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton

                    onPressed: {
                        root.justOpenedPower = false
                        if (!root.isClosingHub && (root.activeMode === "hub" || (root.activeMode === "power" && root.powerAction === "none"))) {
                            root.isPressingNucleus = true
                        }
                    }
                    onReleased: {
                        root.isPressingNucleus = false
                    }
                    onCanceled: {
                        root.isPressingNucleus = false
                    }
                    onClicked: {
                        root.isPressingNucleus = false
                        if (root.isClosingHub) return
                        if (root.justOpenedPower) {
                            root.justOpenedPower = false
                            return
                        }
                        if (controlRing && controlRing.isOpen) {
                            if (controlRing.kind === "volume") {
                                controlRing.toggleMute()
                            } else {
                                controlRing.closeRing()
                            }
                        } else if (root.activeMode === "wifi" || root.activeMode === "bluetooth") {
                            if (connectivityPicker) connectivityPicker.goBack()
                        } else if (root.activeMode === "power") {
                            // In power mode, do not close on click — only close on Escape key!
                            return
                        } else {
                            root.toggle()
                        }
                    }
                    onWheel: wheel => {
                        var delta = (wheel.angleDelta.y > 0) ? 0.03 : -0.03
                        root.stepVolume(delta)
                    }
                }
            }
        }

        /* ── Power Action Atom Bohr Orbit Layer (22px & 40px orbits + 6 electrons) ── */
        Item {
            id: powerAtomLayer
            anchors.centerIn: parent
            width: 240
            height: 240
            z: 9
            visible: root.activeMode === "power" && root.powerAction !== "none" && !root.powerReducedMotion

            // Orbit Ring 1 (Inner, r=22)
            Rectangle {
                anchors.centerIn: parent
                width: 44; height: 44; radius: 22
                color: "transparent"
                border.color: "#FFFFFF"
                border.width: 1.0
                opacity: root.powerOrbitRingAlpha
            }

            // Orbit Ring 2 (Outer, r=40)
            Rectangle {
                anchors.centerIn: parent
                width: 80; height: 80; radius: 40
                color: "transparent"
                border.color: "#FFFFFF"
                border.width: 1.0
                opacity: root.powerOrbitRingAlpha
            }

            // 6 Bohr Electrons (2 inner, 4 outer)
            Repeater {
                model: 6
                delegate: Item {
                    id: powerElectronItem
                    required property int index
                    readonly property var pos: root.getPowerElectronPos(index)

                    x: (powerAtomLayer.width / 2) + pos.x - 3
                    y: (powerAtomLayer.height / 2) + pos.y - 3
                    width: 6
                    height: 6
                    opacity: pos.alpha

                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: "#FFFFFF"
                    }

                    // Restart speed trail ghost dot (ramps mult 500-1300ms)
                    Rectangle {
                        anchors.fill: parent
                        radius: 3
                        color: "#FFFFFF"
                        visible: root.powerAction === "restart" && root.powerActionT >= 500.0 && root.powerActionT <= 1300.0
                        opacity: 0.35
                        transform: Translate {
                            x: -powerElectronItem.pos.vx * 4.5
                            y: -powerElectronItem.pos.vy * 4.5
                        }
                    }
                }
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           OUTERMOST ORBITAL PROGRESS RING (r = 67.5px, Bold Neon Track)
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: musicProgressRing
            anchors.centerIn: parent
            width: 154
            height: 154
            z: 12
            visible: (opacity > 0.01) && LyricsService.hasTrack && root.activeMode === "hub" && !(controlRing && controlRing.isOpen)
            opacity: (root.hubProgress > 0.35 && LyricsService.hasTrack && root.activeMode === "hub" && !(controlRing && controlRing.isOpen)) ? root.mediaPlayProgress : 0.0
            scale: 0.8 + (0.2 * root.hubProgress)
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            readonly property real rawProgress: (LyricsService.totalLength > 0)
                ? Math.max(0.0, Math.min(1.0, LyricsService.currentPosition / LyricsService.totalLength)) : 0.0

            property real animProgress: rawProgress
            Behavior on animProgress {
                NumberAnimation { duration: 150; easing.type: Easing.Linear }
            }

            readonly property real trackRadius: 67.5
            readonly property real centerOffset: 77.0
            readonly property real currentAngleRad: -Math.PI / 2 + (2 * Math.PI * animProgress)

            // 1. Faint Outermost Guide Ring
            Rectangle {
                anchors.centerIn: parent
                width: 135
                height: 135
                radius: 67.5
                color: "transparent"
                border.width: 1.0
                border.color: Qt.rgba(1, 1, 1, 0.08)
            }

            // 2. Bold Neon Accent Progress Arc
            Shape {
                id: progressShape
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                visible: musicProgressRing.animProgress > 0.001

                ShapePath {
                    strokeWidth: 2.8
                    strokeColor: root.colTeal
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    startX: musicProgressRing.centerOffset
                    startY: musicProgressRing.centerOffset - musicProgressRing.trackRadius
                    PathAngleArc {
                        centerX: musicProgressRing.centerOffset
                        centerY: musicProgressRing.centerOffset
                        radiusX: musicProgressRing.trackRadius
                        radiusY: musicProgressRing.trackRadius
                        startAngle: -90
                        sweepAngle: (musicProgressRing.animProgress > 0.001)
                            ? Math.min(359.9, musicProgressRing.animProgress * 360.0)
                            : 0.0
                    }
                }
            }

            // Leading Specular Glowing Dot at progress head
            Rectangle {
                id: progressDot
                visible: musicProgressRing.animProgress > 0.005
                width: 7
                height: 7
                radius: 3.5
                color: "#FFFFFF"
                x: musicProgressRing.centerOffset + musicProgressRing.trackRadius * Math.cos(musicProgressRing.currentAngleRad) - 3.5
                y: musicProgressRing.centerOffset + musicProgressRing.trackRadius * Math.sin(musicProgressRing.currentAngleRad) - 3.5

                Rectangle {
                    anchors.centerIn: parent
                    width: 14
                    height: 14
                    radius: 7
                    color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.65)
                    z: -1
                }
            }

            // Interactive Click & Drag to Seek on Outer Circle
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function seekFromMouse(mouse) {
                    const dx = mouse.x - width / 2;
                    const dy = mouse.y - height / 2;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist >= 52 && dist <= 84) {
                        let angle = Math.atan2(dy, dx);
                        let frac = (angle + Math.PI / 2) / (2 * Math.PI);
                        if (frac < 0) frac += 1.0;
                        LyricsService.seekFraction(frac);
                    }
                }

                onPressed: (mouse) => {
                    const dx = mouse.x - width / 2;
                    const dy = mouse.y - height / 2;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist < 52) {
                        mouse.accepted = false;
                    }
                }
                onClicked: (mouse) => seekFromMouse(mouse)
                onPositionChanged: (mouse) => {
                    if (pressed) seekFromMouse(mouse);
                }
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           ORGANIC MUSIC & SYNCED LYRICS OVERLAY (Barless, pure circular geometry)
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: nucleusMusicOverlay
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 74
            Behavior on anchors.topMargin { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            width: 320
            height: 84
            z: 15
            visible: (opacity > 0.01) && LyricsService.hasTrack && root.activeMode === "hub" && !(controlRing && controlRing.isOpen)
            opacity: (root.hubProgress > 0.25 && LyricsService.hasTrack && root.activeMode === "hub" && !(controlRing && controlRing.isOpen)) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

            property bool forceMetadata: false
            readonly property bool showingLyrics: !forceMetadata && LyricsService.hasLyrics && (LyricsService.currentLine.trim().length > 0)

            ColumnLayout {
                anchors.fill: parent
                spacing: 5

                // ── 1. Track Info Display ──
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        // Circular Album Art Micro-Orb
                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 13
                            color: "#181B22"
                            border.color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.5)
                            border.width: 1.2
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: LyricsService.artUrl
                                sourceSize: Qt.size(52, 52)
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready && source !== ""
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "music_note"
                                font.family: Theme.fontIcon
                                font.pixelSize: 14
                                color: root.colTeal
                                visible: !LyricsService.artUrl || LyricsService.artUrl === ""
                            }
                        }

                        ColumnLayout {
                            spacing: 1

                            Text {
                                text: LyricsService.trackTitle || "Playing Track"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(12)
                                font.bold: true
                                color: "#FFFFFF"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.maximumWidth: 250
                            }

                            Text {
                                text: LyricsService.trackArtist || "Unknown Artist"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(10)
                                color: root.colFgDim
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.maximumWidth: 250
                            }
                        }
                    }

                    // Scrolling on track area also morphs the bottom caption between date and lyrics
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y < 0) dateLyricsCaption.showLyrics = true
                            else if (wheel.angleDelta.y > 0) dateLyricsCaption.showLyrics = false
                        }
                        onClicked: {
                            dateLyricsCaption.showLyrics = !dateLyricsCaption.showLyrics
                        }
                    }
                }

                // ── 2. ValenceDot Circular Transport Controls Row ──
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 12

                    // Elapsed Time Readout
                    Text {
                        text: LyricsService.formatTime(LyricsService.currentPosition)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(9)
                        color: root.colFgDim
                    }

                    // Skip Previous Button (26px circle, 36px hit target)
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: prevMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0.08, 0.10, 0.14, 0.75)
                        border.color: prevMouse.containsMouse ? root.colTeal : Qt.rgba(1, 1, 1, 0.14)
                        border.width: 1.2
                        scale: prevMouse.containsMouse ? 1.14 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            font.family: Theme.fontIcon
                            font.pixelSize: 15
                            color: prevMouse.containsMouse ? root.colTeal : "#D0D6E0"
                        }

                        MouseArea {
                            id: prevMouse
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LyricsService.skipPrevious()
                        }
                    }

                    // Play / Pause Button (32px ValenceDot circle with halo, 44px hit target)
                    Item {
                        Layout.preferredWidth: 32
                        Layout.preferredHeight: 32

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 10
                            height: width
                            radius: width / 2
                            color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.35)
                            visible: playMouse.containsMouse || LyricsService.isPlaying
                            opacity: playMouse.containsMouse ? 0.75 : 0.40
                            Behavior on opacity { NumberAnimation { duration: 180 } }
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: LyricsService.isPlaying ? root.colTeal : "#FFFFFF"
                            border.color: root.colTeal
                            border.width: 1.8
                            scale: playMouse.containsMouse ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                            Text {
                                anchors.centerIn: parent
                                text: LyricsService.isPlaying ? "pause" : "play_arrow"
                                font.family: Theme.fontIcon
                                font.pixelSize: 18
                                color: "#0b0e14"
                            }
                        }

                        MouseArea {
                            id: playMouse
                            anchors.centerIn: parent
                            width: 44
                            height: 44
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LyricsService.togglePlaying()
                        }
                    }

                    // Skip Next Button (26px circle, 36px hit target)
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: nextMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0.08, 0.10, 0.14, 0.75)
                        border.color: nextMouse.containsMouse ? root.colTeal : Qt.rgba(1, 1, 1, 0.14)
                        border.width: 1.2
                        scale: nextMouse.containsMouse ? 1.14 : 1.0
                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                        Text {
                            anchors.centerIn: parent
                            text: "skip_next"
                            font.family: Theme.fontIcon
                            font.pixelSize: 15
                            color: nextMouse.containsMouse ? root.colTeal : "#D0D6E0"
                        }

                        MouseArea {
                            id: nextMouse
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: LyricsService.skipNext()
                        }
                    }

                    // Total Duration Readout
                    Text {
                        text: (LyricsService.totalLength > 0) ? LyricsService.formatTime(LyricsService.totalLength) : "--:--"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(9)
                        color: root.colFgDim
                    }
                }
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           MORPHING DATE / SYNCED LYRICS CAPTION
           - Scroll DOWN or Click: Morphs smoothly into Synced Lyrics
           - Scroll UP or Click: Morphs smoothly into Day, Date & Month
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: dateLyricsCaption
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: ((root.activeMode === "wifi" || root.activeMode === "bluetooth" || root.activeMode === "power") ? 134 : ((LyricsService.hasTrack && root.activeMode === "hub") ? 166 : 82))
            Behavior on anchors.topMargin { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            visible: root.hubProgress > 0.1 && (root.activeMode === "hub" || root.activeMode === "wifi" || root.activeMode === "bluetooth") && !(controlRing && controlRing.isOpen)
            opacity: ((root.activeMode === "hub" || root.activeMode === "wifi" || root.activeMode === "bluetooth") && !(controlRing && controlRing.isOpen)) ? root.hubProgress : 0.0
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            width: 360
            height: 24
            clip: true

            property bool showLyrics: false

            Connections {
                target: LyricsService
                function onHasTrackChanged() {
                    if (!LyricsService.hasTrack) dateLyricsCaption.showLyrics = false
                }
            }

            // 1. Date View (Slides up and fades out when lyrics are shown)
            Item {
                id: dateView
                anchors.fill: parent
                opacity: (!dateLyricsCaption.showLyrics && root.activeMode === "hub") ? 1.0 : 0.0
                y: !dateLyricsCaption.showLyrics ? 0 : -14
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: root.dateCaptionStr
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(12)
                        font.bold: true
                        color: root.colFgDim
                    }
                }
            }

            // 2. Synced Lyrics View (Slides in from bottom and fades in when lyrics are shown)
            Item {
                id: lyricsView
                anchors.fill: parent
                opacity: (dateLyricsCaption.showLyrics && root.activeMode === "hub") ? 1.0 : 0.0
                y: dateLyricsCaption.showLyrics ? 0 : 14
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        id: activeLyricText
                        text: {
                            if (!LyricsService.hasTrack) return "No media playing"
                            if (LyricsService.hasLyrics && LyricsService.currentLine.trim().length > 0) {
                                return LyricsService.currentLine
                            }
                            if (LyricsService.hasLyrics) {
                                return "· · ·"
                            }
                            return "No Synced Lyrics"
                        }
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(12)
                        font.bold: true
                        color: (LyricsService.hasLyrics && LyricsService.currentLine.trim().length > 0) ? root.colTeal : root.colFgDim
                        elide: Text.ElideRight
                        Layout.maximumWidth: 320
                        horizontalAlignment: Text.AlignHCenter

                        Behavior on color { ColorAnimation { duration: 180 } }

                        Connections {
                            target: LyricsService
                            function onCurrentLineChanged() {
                                lyricTextPulse.restart()
                            }
                        }

                        SequentialAnimation {
                            id: lyricTextPulse
                            NumberAnimation { target: activeLyricText; property: "opacity"; to: 0.35; duration: 90; easing.type: Easing.OutQuad }
                            NumberAnimation { target: activeLyricText; property: "opacity"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            // 3. Connectivity Caption View (Shows Wi-Fi / Bluetooth status, SSID, security, signal, etc.)
            Item {
                id: connectivityCaptionView
                anchors.fill: parent
                visible: root.activeMode === "wifi" || root.activeMode === "bluetooth"
                opacity: (root.activeMode === "wifi" || root.activeMode === "bluetooth") ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: (connectivityPicker && connectivityPicker.captionText) ? connectivityPicker.captionText : ""
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(12)
                    font.bold: true
                    color: root.colFgDim
                    elide: Text.ElideMiddle
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                }
            }



            // 5. Power Orbit Caption View
            Item {
                id: powerCaptionView
                anchors.fill: parent
                visible: root.activeMode === "power"
                opacity: (root.activeMode === "power") ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    text: {
                        if (root.powerErrorMessage.length > 0) return root.powerErrorMessage
                        if (root.powerAction === "lock") return "Locking..."
                        if (root.powerAction === "sleep") return "sleeping"
                        if (root.powerAction === "restart") return "Restarting..."
                        if (root.powerAction === "shutdown") return "shutting down..."

                        if (root.heldPowerOrb === "restart" || root.heldPowerOrb === "shutdown") {
                            return (root.heldPowerOrb === "restart" ? "Restart" : "Shut down") + " (holding to confirm...)"
                        }
                        if (root.hoveredPowerOrb === "lock") {
                            return root.powerEnableLogout ? "Lock (hold for log out)" : "Lock"
                        }
                        if (root.hoveredPowerOrb === "sleep") return "Sleep"
                        if (root.hoveredPowerOrb === "restart") return "Restart — hold to confirm"
                        if (root.hoveredPowerOrb === "shutdown") return "Shut down — hold to confirm"
                        return "power actions / tap nucleus or Esc to return"
                    }
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(12)
                    font.bold: true
                    color: (root.powerErrorMessage.length > 0) ? root.colCoral : root.colFgDim
                    elide: Text.ElideMiddle
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Interactive MouseArea: Scroll Down -> Lyrics, Scroll Up -> Date, Click -> Toggle
            MouseArea {
                id: dateCaptionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onWheel: (wheel) => {
                    if (root.activeMode !== "hub") return
                    if (wheel.angleDelta.y < 0) {
                        // Scroll down: morph to lyrics
                        dateLyricsCaption.showLyrics = true
                    } else if (wheel.angleDelta.y > 0) {
                        // Scroll up: morph to date
                        dateLyricsCaption.showLyrics = false
                    }
                }

                onClicked: {
                    if (root.activeMode === "hub") {
                        if (dateLyricsCaption.showLyrics) {
                            dateLyricsCaption.showLyrics = false
                        } else {
                            root.openCalendarMode()
                        }
                    }
                }
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           PHASE 3: Enhanced Spotlight App Launcher (Inside Vanish Mode)
           Exact preserved dimensions: width: 380, height: 460
           Features: Apps, Clipboard, Commands & Real-time Calculator
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: appSearchContainer
            anchors.centerIn: parent
            z: 80
            visible: root.hubOpen && root.activeMode === "appsearch"
            opacity: (root.hubOpen && root.activeMode === "appsearch") ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            width: 440
            readonly property bool isSearchEmpty: !appSearchInput.text || appSearchInput.text.trim().length === 0
            height: isSearchEmpty ? 344 : 460
            Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            // Consume clicks inside the search container so clicking on empty areas doesn't close the hub
            MouseArea {
                anchors.fill: parent
                onClicked: (mouse) => mouse.accepted = true
            }

            // Outer Glow / Halo
            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: 32
                color: "transparent"
                border.color: Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.25)
                border.width: 4
                opacity: 0.8
            }

            // Main Glass Card
            Rectangle {
                anchors.fill: parent
                radius: 28
                color: Qt.rgba(root.colBgDark.r, root.colBgDark.g, root.colBgDark.b, 0.94)
                border.color: Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.45)
                border.width: 1.5

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    // 1. Search Bar Pill
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 21
                        color: Qt.rgba(0, 0, 0, 0.42)
                        border.color: appSearchInput.activeFocus ? root.colPurple : Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.3)
                        border.width: appSearchInput.activeFocus ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 8

                            Text {
                                text: {
                                    if (root.launcherTab === "clipboard") return "content_paste"
                                    if (root.launcherTab === "commands") return "terminal"
                                    return "search"
                                }
                                font.family: Theme.fontIcon
                                font.pixelSize: 18
                                color: root.colPurple
                            }

                            TextInput {
                                id: appSearchInput
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(14)
                                font.weight: Font.Medium
                                color: "#ffffff"
                                clip: true
                                selectByMouse: true
                                selectionColor: Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.5)

                                Text {
                                    text: {
                                        if (root.launcherTab === "clipboard") return "Search clipboard history..."
                                        if (root.launcherTab === "commands") return "Search system commands..."
                                        return "Search apps, math (=2+2), or >cmd..."
                                    }
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(13)
                                    color: Qt.rgba(1, 1, 1, 0.35)
                                    visible: !appSearchInput.text && !appSearchInput.inputMethodComposing
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                onTextChanged: {
                                    hubQalcDebounceTimer.restart()
                                    root.filterApps(text)
                                }

                                Keys.onDownPressed: (event) => {
                                    if (appMatches.count > 0) {
                                        root.selectedAppIndex = Math.min(appMatches.count - 1, root.selectedAppIndex + 1)
                                        appListView.positionViewAtIndex(root.selectedAppIndex, ListView.Contain)
                                    }
                                    event.accepted = true
                                }
                                Keys.onUpPressed: (event) => {
                                    if (appMatches.count > 0) {
                                        root.selectedAppIndex = Math.max(0, root.selectedAppIndex - 1)
                                        appListView.positionViewAtIndex(root.selectedAppIndex, ListView.Contain)
                                    }
                                    event.accepted = true
                                }
                                Keys.onReturnPressed: (event) => {
                                    root.executeCurrentItem()
                                    event.accepted = true
                                }
                                Keys.onEscapePressed: (event) => {
                                    if (text.length > 0) {
                                        text = ""
                                    } else {
                                        root.activeMode = "hub"
                                    }
                                    event.accepted = true
                                }
                                Keys.onTabPressed: (event) => {
                                    const tabs = ["apps", "clipboard", "commands"]
                                    const nextIdx = (tabs.indexOf(root.launcherTab) + 1) % tabs.length
                                    root.launcherTab = tabs[nextIdx]
                                    root.filterApps(text)
                                    event.accepted = true
                                }
                            }

                            // Clear / Close button
                            Item {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                visible: appSearchInput.text.length > 0
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 11
                                    color: clearHover.hovered ? Qt.rgba(1, 1, 1, 0.15) : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "close"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 13
                                        color: Qt.rgba(1, 1, 1, 0.6)
                                    }
                                    HoverHandler { id: clearHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            appSearchInput.text = ""
                                            appSearchInput.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    /* ── Idle State Container: Top Black Tile + Bottom Music Card ── */
                    ColumnLayout {
                        id: idleContainer
                        Layout.fillWidth: true
                        spacing: 8
                        visible: appSearchContainer.isSearchEmpty

                        /* 1. Top Black Tile (Empty container for user personalization) */
                        Rectangle {
                            id: blackTile
                            Layout.fillWidth: true
                            Layout.preferredHeight: 86
                            radius: 14
                            color: "#111116"
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1

                            // Mask Item defining the 14px rounded corner shape
                            Item {
                                id: blackTileMask
                                anchors.fill: parent
                                visible: false
                                layer.enabled: true
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 14
                                    color: "#ffffff"
                                }
                            }

                            // Masked image layer ensuring corners are 100% round
                            Item {
                                anchors.fill: parent
                                layer.enabled: true
                                layer.effect: MultiEffect {
                                    maskEnabled: true
                                    maskSource: blackTileMask
                                }

                                Image {
                                    id: blackTileImg
                                    anchors.fill: parent
                                    fillMode: Image.PreserveAspectCrop
                                    source: (root.blankTileConfig && root.blankTileConfig.enabled && root.blankTileConfig.cropPath)
                                            ? ("file://" + root.blankTileConfig.cropPath + "?t=" + (root.blankTileConfig.timestamp || 0))
                                            : ""
                                    visible: Boolean(root.blankTileConfig && root.blankTileConfig.enabled && root.blankTileConfig.cropPath)
                                    opacity: (root.blankTileConfig && root.blankTileConfig.opacity !== undefined) ? root.blankTileConfig.opacity : 1.0
                                    cache: false
                                }
                            }

                            // Weather Indicator on the right side of the tile (unpilled, larger icon, temp below)
                            Column {
                                id: weatherCol
                                anchors.right: parent.right
                                anchors.rightMargin: 18
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.weatherIcon
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: 28
                                    color: root.colPurple
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: root.weatherTemp
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontPx(13)
                                    font.weight: Font.Bold
                                    color: Theme.fg
                                    style: Text.Outline
                                    styleColor: Qt.rgba(0, 0, 0, 0.75)
                                }
                            }
                        }

                        /* 2. Bottom Music Overlay Card (Exact Middle Bar Notch Mode Layout) */
                        Rectangle {
                            id: musicCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: 166
                            radius: 14
                            color: Qt.rgba(0.08, 0.09, 0.12, 0.95)
                            border.color: Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.35)
                            border.width: 1
                            clip: true

                            // Subtle blurred/dimmed album art ambient background
                            Image {
                                anchors.fill: parent
                                source: LyricsService.artUrl
                                fillMode: Image.PreserveAspectCrop
                                opacity: 0.14
                                visible: status === Image.Ready && source != ""
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 6

                                /* Header: Device / App Badge */
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: "music_note"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 13
                                        color: root.colTeal
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: {
                                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.description && Pipewire.defaultAudioSink.description.length > 0)
                                                return Pipewire.defaultAudioSink.description
                                            if (LyricsService.activePlayer && LyricsService.activePlayer.identity && LyricsService.activePlayer.identity.length > 0)
                                                return LyricsService.activePlayer.identity
                                            return "Audio Output"
                                        }
                                        font.family: "Valley Sans"
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                        color: Qt.rgba(1, 1, 1, 0.78)
                                        elide: Text.ElideRight
                                    }
                                }

                                /* Track Title & Artist + Album Art Thumbnail */
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Text {
                                            Layout.fillWidth: true
                                            text: LyricsService.hasTrack ? LyricsService.trackTitle : "No Media Playing"
                                            font.family: "Valley Sans"
                                            font.pixelSize: 13
                                            font.bold: true
                                            color: "#ffffff"
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: LyricsService.hasTrack ? (LyricsService.trackArtist || "Unknown Artist") : "Waiting for playback..."
                                            font.family: "Valley Sans"
                                            font.pixelSize: 10
                                            color: root.colTeal
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Album Art Thumbnail
                                    Rectangle {
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: 42
                                        radius: 8
                                        color: Qt.rgba(0.12, 0.14, 0.18, 0.9)
                                        border.color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.35)
                                        border.width: 1
                                        clip: true

                                        Image {
                                            anchors.fill: parent
                                            source: LyricsService.artUrl
                                            fillMode: Image.PreserveAspectCrop
                                            visible: status === Image.Ready && source != ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "music_note"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 18
                                            color: LyricsService.isPlaying ? root.colTeal : Qt.rgba(1, 1, 1, 0.45)
                                            visible: !LyricsService.artUrl || LyricsService.artUrl === ""
                                        }
                                    }
                                }

                                /* Animated Wavy Visualizer & Interactive Progress Bar */
                                WavySeekBar {
                                    Layout.fillWidth: true
                                    waveHeight: 14
                                    barHeight: 6
                                    timeLabelSize: 8
                                    accentColor: root.colTeal
                                    accentLitColor: root.colTeal
                                }

                                /* Transport Controls Row (No lyrics!) */
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter

                                    Item { Layout.fillWidth: true }

                                    // Shuffle
                                    Rectangle {
                                        Layout.preferredWidth: 26
                                        Layout.preferredHeight: 26
                                        radius: 13
                                        color: shufHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "shuffle"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 14
                                            color: shufHov.hovered ? root.colTeal : Qt.rgba(1, 1, 1, 0.65)
                                        }
                                        HoverHandler { id: shufHov }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Quickshell.execDetached(["playerctl", "shuffle", "Toggle"])
                                        }
                                    }

                                    Item { Layout.preferredWidth: 10 }

                                    // Previous
                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: prevHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "skip_previous"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 18
                                            color: prevHov.hovered ? root.colTeal : "#ffffff"
                                        }
                                        HoverHandler { id: prevHov }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: LyricsService.skipPrevious()
                                        }
                                    }

                                    Item { Layout.preferredWidth: 8 }

                                    // Play / Pause (Distinct Pill)
                                    Rectangle {
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: 18
                                        color: root.colTeal
                                        scale: playHov.hovered ? 1.06 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 120 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: LyricsService.isPlaying ? "pause" : "play_arrow"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 20
                                            color: "#0b0e14"
                                        }
                                        HoverHandler { id: playHov }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: LyricsService.togglePlaying()
                                        }
                                    }

                                    Item { Layout.preferredWidth: 8 }

                                    // Next
                                    Rectangle {
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 28
                                        radius: 14
                                        color: nextHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "skip_next"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 18
                                            color: nextHov.hovered ? root.colTeal : "#ffffff"
                                        }
                                        HoverHandler { id: nextHov }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: LyricsService.skipNext()
                                        }
                                    }

                                    Item { Layout.preferredWidth: 10 }

                                    // Loop
                                    Rectangle {
                                        Layout.preferredWidth: 26
                                        Layout.preferredHeight: 26
                                        radius: 13
                                        color: loopHov.hovered ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "repeat"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 14
                                            color: loopHov.hovered ? root.colTeal : Qt.rgba(1, 1, 1, 0.65)
                                        }
                                        HoverHandler { id: loopHov }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: Quickshell.execDetached(["playerctl", "loop", "Track"])
                                        }
                                    }

                                    Item { Layout.fillWidth: true }
                                }
                            }
                        }
                    }

                    // 2. Category Filter Tabs (Apps | Clipboard | Commands)
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        spacing: 6
                        visible: !appSearchContainer.isSearchEmpty

                        Repeater {
                            model: [
                                { id: "apps", label: "Apps", icon: "apps" },
                                { id: "clipboard", label: "Clipboard", icon: "content_paste" },
                                { id: "commands", label: "Commands", icon: "terminal" }
                            ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 24
                                radius: 12
                                readonly property bool isCurrent: root.launcherTab === modelData.id
                                color: isCurrent ? Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.28) : (tabHov.hovered ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.25))
                                border.color: isCurrent ? root.colPurple : "transparent"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    Text {
                                        text: modelData.icon
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 12
                                        color: isCurrent ? root.colPurple : Qt.rgba(1, 1, 1, 0.5)
                                    }
                                    Text {
                                        text: modelData.label
                                        font.family: "Valley Sans"
                                        font.pixelSize: 11
                                        font.weight: isCurrent ? Font.Bold : Font.Normal
                                        color: isCurrent ? "#ffffff" : Qt.rgba(1, 1, 1, 0.6)
                                    }
                                }

                                HoverHandler { id: tabHov }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.launcherTab = modelData.id
                                        root.filterApps(appSearchInput.text)
                                        appSearchInput.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }

                    // 3. Live Calculation Card (When Math Expression Detected)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 12
                        color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.16)
                        border.color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.5)
                        border.width: 1
                        visible: root.hasCalcResult && root.calcResult.length > 0

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            Rectangle {
                                width: 28
                                height: 28
                                radius: 8
                                color: root.colTeal
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "calculate"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 16
                                    color: "#0b0e14"
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    text: root.calcResult
                                    font.family: "Valley Sans"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    color: "#ffffff"
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "Press Enter to copy result"
                                    font.family: "Valley Sans"
                                    font.pixelSize: 9
                                    color: Qt.rgba(1, 1, 1, 0.55)
                                }
                            }

                            Rectangle {
                                width: 56
                                height: 22
                                radius: 6
                                color: Qt.rgba(root.colTeal.r, root.colTeal.g, root.colTeal.b, 0.28)
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    anchors.centerIn: parent
                                    text: "↵ Copy"
                                    font.family: "Valley Sans"
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: root.colTeal
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyCalcResult()
                        }
                    }

                    // 4. Results List (Apps / Clipboard / Commands)
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !appSearchContainer.isSearchEmpty

                        ListView {
                            id: appListView
                            anchors.fill: parent
                            clip: true
                            spacing: 4
                            boundsBehavior: Flickable.StopAtBounds
                            model: ListModel { id: appMatches }

                            delegate: Rectangle {
                                id: appRow
                                width: appListView.width
                                height: 44
                                radius: 12
                                readonly property bool isSelected: index === root.selectedAppIndex

                                color: isSelected
                                    ? Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.22)
                                    : (rowHover.hovered ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                border.color: isSelected
                                    ? Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.5)
                                    : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                HoverHandler {
                                    id: rowHover
                                    onHoveredChanged: {
                                        if (hovered) root.selectedAppIndex = index
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selectedAppIndex = index
                                        root.executeCurrentItem()
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    // Icon / Glyph
                                    Rectangle {
                                        Layout.preferredWidth: 30
                                        Layout.preferredHeight: 30
                                        radius: 15
                                        color: Qt.rgba(0, 0, 0, 0.35)
                                        border.color: isSelected ? root.colPurple : Qt.rgba(1, 1, 1, 0.1)
                                        border.width: 1

                                        Image {
                                            id: appIconImg
                                            anchors.centerIn: parent
                                            width: 20
                                            height: 20
                                            source: (model.itemType === "app" && model.icon) ? Quickshell.iconPath(model.icon, "application-x-executable") : ""
                                            sourceSize: Qt.size(40, 40)
                                            fillMode: Image.PreserveAspectFit
                                            visible: model.itemType === "app" && status === Image.Ready
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: !appIconImg.visible
                                            text: {
                                                if (model.glyph && model.glyph.length > 0) return model.glyph
                                                if (model.name && model.name.length > 0) return model.name.charAt(0).toUpperCase()
                                                return "apps"
                                            }
                                            font.family: (model.glyph && model.glyph.length > 0) ? Theme.fontIcon : "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx((model.glyph && model.glyph.length > 0) ? 15 : 12)
                                            font.bold: true
                                            color: root.colPurple
                                        }
                                    }

                                    // Details (Title & Subtitle)
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1

                                        Text {
                                            Layout.fillWidth: true
                                            text: model.name || ""
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontPx(13)
                                            font.weight: isSelected ? Font.DemiBold : Font.Normal
                                            color: isSelected ? "#ffffff" : Qt.rgba(1, 1, 1, 0.88)
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: text.length > 0
                                            text: model.comment || ""
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontPx(10)
                                            color: Qt.rgba(1, 1, 1, 0.45)
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Action Return Glyph
                                    Text {
                                        visible: isSelected
                                        text: "keyboard_return"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 14
                                        color: root.colPurple
                                        opacity: 0.8
                                    }
                                }
                            }
                        }

                        // Empty State
                        Item {
                            anchors.fill: parent
                            visible: appMatches.count === 0 && (!root.hasCalcResult || root.calcResult.length === 0)

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "search_off"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 28
                                    color: Qt.rgba(root.colPurple.r, root.colPurple.g, root.colPurple.b, 0.4)
                                }

                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "No applications found"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(12)
                                    color: Qt.rgba(1, 1, 1, 0.4)
                                }
                            }
                        }
                    }

                    // 5. Bottom Footer Hint Pill
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 12
                        visible: !appSearchContainer.isSearchEmpty

                        RowLayout {
                            spacing: 3
                            Text {
                                text: "↑↓"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(11)
                                font.bold: true
                                color: Qt.rgba(1, 1, 1, 0.45)
                            }
                            Text {
                                text: "Navigate"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(10)
                                color: Qt.rgba(1, 1, 1, 0.35)
                            }
                        }

                        RowLayout {
                            spacing: 3
                            Text {
                                text: "↵"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(11)
                                font.bold: true
                                color: root.colPurple
                            }
                            Text {
                                text: "Launch"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(10)
                                color: Qt.rgba(1, 1, 1, 0.35)
                            }
                        }

                        RowLayout {
                            spacing: 3
                            Text {
                                text: "ESC"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(10)
                                font.bold: true
                                color: Qt.rgba(1, 1, 1, 0.45)
                            }
                            Text {
                                text: "Back"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(10)
                                color: Qt.rgba(1, 1, 1, 0.35)
                            }
                        }
                    }
                }
            }
        }


        /* ══════════════════════════════════════════════════════════════════════
           PHASE 5: Monochrome Orbit-Orb Connectivity Picker (Wi-Fi & Bluetooth)
           ══════════════════════════════════════════════════════════════════════ */
        ConnectivityOrbitPicker {
            id: connectivityPicker
            anchors.centerIn: parent
            visible: root.hubOpen && (root.activeMode === "wifi" || root.activeMode === "bluetooth") && (transitionProgress > 0.001)
            opacity: visible ? 1.0 : 0.0

            onBackRequested: {
                root.activeMode = "hub"
                root.focusedLobe = "connect"
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           PHASE 5.5: Battery Orbit Section & Power Profile Switcher
           ══════════════════════════════════════════════════════════════════════ */
        BatteryOrbitSection {
            id: batteryOrbitSection
            anchors.centerIn: parent
            z: 2

            onBackRequested: {
                root.activeMode = "hub"
                root.focusedLobe = "connect"
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           PHASE 6: Monochrome Volume & Brightness Control Ring
           ══════════════════════════════════════════════════════════════════════ */
        ControlRing {
            id: controlRing
            anchors.centerIn: parent
            z: 1
        }

        Connections {
            target: controlRing
            function onIsOpenChanged() {
                if (!controlRing.isOpen && root.osdOpenedHub) {
                    root.osdOpenedHub = false
                    root.close()
                }
            }
        }

        /* ══════════════════════════════════════════════════════════════════════
           PHASE 7: Radial Orbital Power Menu (Vanish Mode Nucleus Power Satellites)
           ══════════════════════════════════════════════════════════════════════ */
        Item {
            id: powerOrbitLayer
            anchors.centerIn: parent
            width: 320
            height: 320
            z: 2
            visible: opacity > 0.005
            opacity: (root.activeMode === "power" && root.hubOpen && root.powerAction === "none") ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            property real bloomRadius: (root.activeMode === "power" && root.hubOpen && root.powerAction === "none") ? 86.0 : 0.0
            Behavior on bloomRadius { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

            // 4 Circular Satellite Action Buttons (angles: -150°, -60°, 30°, 120°, 38px orbs)
            Repeater {
                model: root.powerOrbData

                delegate: Item {
                    id: powerOrbItem
                    required property var modelData
                    required property int index

                    readonly property real rad: modelData.deg * (Math.PI / 180.0)
                    readonly property real targetX: (powerOrbitLayer.width / 2) + (powerOrbitLayer.bloomRadius * Math.cos(rad)) - (width / 2)
                    readonly property real targetY: (powerOrbitLayer.height / 2) + (powerOrbitLayer.bloomRadius * Math.sin(rad)) - (height / 2)

                    x: targetX
                    y: targetY
                    width: 38
                    height: 38

                    scale: orbMouse.containsMouse ? 1.12 : 1.0
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                    // Destructive Orb Hold Confirmation Ring (radius 24px, fills clockwise over 800ms)
                    Shape {
                        anchors.centerIn: parent
                        width: 48
                        height: 48
                        visible: (root.heldPowerOrb === powerOrbItem.modelData.id ||
                                 (root.heldPowerOrb === "" && root.lastHeldPowerOrb === powerOrbItem.modelData.id && root.orbHoldProgress > 0.001))
                        layer.enabled: true
                        layer.samples: 4
                        ShapePath {
                            strokeWidth: 2.2
                            strokeColor: powerOrbItem.modelData.holdColor
                            fillColor: "transparent"
                            capStyle: ShapePath.RoundCap
                            startX: 24
                            startY: 0
                            PathAngleArc {
                                centerX: 24
                                centerY: 24
                                radiusX: 24
                                radiusY: 24
                                startAngle: -90
                                sweepAngle: Math.max(0.1, Math.min(359.9, root.orbHoldProgress * 360.0))
                            }
                        }
                    }

                    // Circular satellite disk
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "#141418"
                        border.color: orbMouse.containsMouse
                            ? Qt.rgba(1, 1, 1, 0.75)
                            : Qt.rgba(1, 1, 1, 0.32)
                        border.width: 1.5
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        Text {
                            anchors.centerIn: parent
                            text: powerOrbItem.modelData.icon
                            font.family: Theme.fontIcon
                            font.pixelSize: 20
                            color: powerOrbItem.modelData.iconColor
                        }
                    }

                    MouseArea {
                        id: orbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hoveredPowerOrb = powerOrbItem.modelData.id
                        onExited: {
                            if (root.hoveredPowerOrb === powerOrbItem.modelData.id) {
                                root.hoveredPowerOrb = ""
                            }
                        }
                        onPressed: {
                            if (powerOrbItem.modelData.isDestructive) {
                                root.lastHeldPowerOrb = powerOrbItem.modelData.id
                                root.heldPowerOrb = powerOrbItem.modelData.id
                            } else if (powerOrbItem.modelData.id === "lock" && root.powerEnableLogout) {
                                root.lastHeldPowerOrb = "lock"
                                root.heldPowerOrb = "lock"
                            }
                        }
                        onReleased: {
                            if (root.heldPowerOrb === powerOrbItem.modelData.id) {
                                root.heldPowerOrb = ""
                            }
                        }
                        onCanceled: {
                            if (root.heldPowerOrb === powerOrbItem.modelData.id) {
                                root.heldPowerOrb = ""
                            }
                        }
                        onClicked: {
                            if (!powerOrbItem.modelData.isDestructive) {
                                if (powerOrbItem.modelData.id === "lock" && root.powerEnableLogout && root.orbHoldProgress >= 0.99) {
                                    return
                                }
                                root.triggerPowerAction(powerOrbItem.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }


    /* ── App Scanning & Filtering Logic (Reusing DesktopEntries) ── */
    property var allAppsList: []
    property int selectedAppIndex: 0

    function loadApps() {
        const values = DesktopEntries.applications.values || []
        const list = []
        for (let i = 0; i < values.length; i++) {
            const e = values[i]
            if (!e || e.noDisplay || !e.name || !e.command || e.command.length === 0) continue
            list.push(e)
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        root.allAppsList = list
        filterApps(appSearchInput ? appSearchInput.text : "")
    }

    function refreshAppList() {
        root.loadApps()
    }

    function filterApps(needle) {
        appMatches.clear()
        const raw = (needle || "").trim()
        const n = raw.toLowerCase()

        // 1. If in clipboard mode or prefixed with "clip " or "c "
        if (root.launcherTab === "clipboard" || n.startsWith("c ") || n.startsWith("clip ")) {
            const subQ = n.startsWith("clip ") ? n.substring(5).trim() : (n.startsWith("c ") ? n.substring(2).trim() : n)
            for (let i = 0; i < root.clipboardItems.length; i++) {
                const item = root.clipboardItems[i]
                if (subQ.length === 0 || (item.preview && item.preview.toLowerCase().includes(subQ))) {
                    appMatches.append({
                        itemType: "clipboard",
                        name: item.preview || "",
                        comment: "Press Enter to copy to clipboard",
                        icon: "",
                        glyph: "content_paste",
                        appIndex: i,
                        clipId: item.id || ""
                    })
                }
            }
            root.selectedAppIndex = 0
            return
        }

        // 2. If in commands mode or prefixed with ">"
        if (root.launcherTab === "commands" || n.startsWith(">")) {
            const subQ = n.startsWith(">") ? n.substring(1).trim() : n
            for (let i = 0; i < root.systemActions.length; i++) {
                const act = root.systemActions[i]
                if (subQ.length === 0 || act.title.toLowerCase().includes(subQ) || act.desc.toLowerCase().includes(subQ)) {
                    appMatches.append({
                        itemType: "action",
                        name: act.title,
                        comment: act.desc,
                        icon: "",
                        glyph: act.glyph || "terminal",
                        appIndex: i,
                        actionId: act.id
                    })
                }
            }
            root.selectedAppIndex = 0
            return
        }

        // 3. Applications mode (default)
        let count = 0
        for (let i = 0; i < root.allAppsList.length && count < 30; i++) {
            const a = root.allAppsList[i]
            const name = a.name || ""
            const comment = a.comment || a.genericName || ""
            if (n.length === 0 || name.toLowerCase().includes(n) || comment.toLowerCase().includes(n)) {
                appMatches.append({
                    itemType: "app",
                    name: name,
                    comment: comment,
                    icon: a.icon || "",
                    glyph: "apps",
                    appIndex: i,
                    clipId: "",
                    actionId: ""
                })
                count++
            }
        }
        root.selectedAppIndex = 0
    }

    function executeCurrentItem() {
        const q = appSearchInput ? appSearchInput.text.trim() : ""
        const isMathQuery = root.hasCalcResult && (/^[=]/.test(q) || /[+\-*\/^%]/.test(q) || /(sqrt|sin|cos|tan|log|ln)/i.test(q))

        if (root.hasCalcResult && (root.selectedAppIndex <= 0 || isMathQuery)) {
            root.copyCalcResult()
            return
        }

        if (root.selectedAppIndex < 0 || root.selectedAppIndex >= appMatches.count) {
            if (root.hasCalcResult) {
                root.copyCalcResult()
            }
            return
        }

        const item = appMatches.get(root.selectedAppIndex)
        if (!item) return

        if (item.itemType === "action") {
            for (let i = 0; i < root.systemActions.length; i++) {
                if (root.systemActions[i].id === item.actionId) {
                    root.systemActions[i].run()
                    return
                }
            }
        } else if (item.itemType === "clipboard") {
            root.close()
            Quickshell.execDetached(["sh", "-c", "cliphist decode " + item.clipId + " | wl-copy"])
        } else {
            root.launchAppIndex(item.appIndex)
        }
    }

    function launchAppIndex(idx) {
        if (idx < 0 || idx >= root.allAppsList.length) return
        const entry = root.allAppsList[idx]
        if (!entry) return
        if (entry.runInTerminal) {
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", entry.command.join(" ")])
        } else {
            entry.execute()
        }
        root.close()
    }

    function launchApp(entry) {
        if (!entry) return
        if (entry.runInTerminal) {
            Quickshell.execDetached(["kitty", "-e", "sh", "-c", entry.command.join(" ")])
        } else {
            entry.execute()
        }
        root.close()
    }

    /* ══════════════════════════════════════════════════════════════════════
       PHASE 5.5: Modular Carbon Calendar UI Modal (Top-Level Fullscreen Layer)
       ══════════════════════════════════════════════════════════════════════ */
    CarbonCalendar {
        id: calendarModal
        anchors.fill: parent
        z: 100
        open: root.hubOpen && root.activeMode === "calendar"
        onCloseRequested: {
            root.activeMode = "hub"
        }
    }

    /* ══════════════════════════════════════════════════════════════════════
       PHASE 5.6: Minimalist Notification Panel (296px Width)
       Placed to the LEFT of Nucleus (right edge 176px left of Nucleus center,
       top = Math.max(nucleusY - 225, 24)), blooms from Second Bell sub-lobe
       (scale 0.28 -> 1.0, opacity 0 -> 1).
       ══════════════════════════════════════════════════════════════════════ */
    readonly property point bellSatelliteScreenPos: {
        if (!lobeAlerts) return Qt.point(root.width / 2, root.height / 2)
        // Hub center coordinates on root screen
        const hubX = root.width / 2
        const hubY = (root.height / 2) + hubCenter.anchors.verticalCenterOffset
        // Lobe rotation
        const lobeDeg = lobeAlerts.rotation
        const lobeRad = lobeDeg * (Math.PI / 180.0)
        // Bell satellite is index 0 (angle: -57°)
        const satRad = -57.0 * (Math.PI / 180.0)
        const satR = 64.0
        // Satellite coordinates in lobe's local frame
        const localX = lobeAlerts.orbitalRadius + (satR * Math.cos(satRad))
        const localY = satR * Math.sin(satRad)
        // Rotate by lobe angle
        const worldX = hubX + (localX * Math.cos(lobeRad) - localY * Math.sin(lobeRad))
        const worldY = hubY + (localX * Math.sin(lobeRad) + localY * Math.cos(lobeRad))
        return Qt.point(worldX, worldY)
    }

    NotificationPanel {
        id: notifPanel
        z: 90
        open: root.notifPanelOpen && root.hubOpen && !root.isClosingHub
        visible: opacity > 0.005

        property real panelProgress: open ? 1.0 : 0.0
        Behavior on panelProgress {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }

        opacity: panelProgress

        // Placement: Placed to the LEFT of Nucleus (right edge 176px left of Nucleus center, top = Math.max(nucleusY - 225, 24))
        readonly property real nucleusX: root.width / 2
        readonly property real nucleusY: (root.height / 2) + hubCenter.anchors.verticalCenterOffset
        readonly property real targetRightX: nucleusX - 176
        readonly property real computedX: {
            if (targetRightX - width < 24) {
                // If near left edge, flip to right of Nucleus
                return Math.min(root.width - width - 24, nucleusX + 176)
            }
            return Math.max(24, targetRightX - width)
        }
        readonly property real computedY: Math.max(24, Math.min(root.height - height - 24, nucleusY - 225))

        x: computedX
        y: computedY

        // Blooms from Second Bell sub-lobe (scale 0.28 -> 1.0)
        transform: Scale {
            origin.x: Math.max(0, Math.min(notifPanel.width, root.bellSatelliteScreenPos.x - notifPanel.x))
            origin.y: Math.max(0, Math.min(notifPanel.height, root.bellSatelliteScreenPos.y - notifPanel.y))
            xScale: 0.28 + (0.72 * notifPanel.panelProgress)
            yScale: 0.28 + (0.72 * notifPanel.panelProgress)
        }

        onCloseRequested: {
            root.notifPanelOpen = false
        }
    }
}
