import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "Singletons"
import "components"
import "modules"
import "modules/lock"
import "modules/tide"
ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string carbonConfigDir: Quickshell.env("CARBON_CONFIG_DIR") || (root.home + "/.config/carbon")
    property bool launcherOpen: false
    property bool wallpaperPickerOpen: false
    property bool settingsHubOpen: false
    property string settingsHubActiveTab: "Appearance"
    property real shellScale: (Theme && Theme.shellScale !== undefined) ? Theme.shellScale : 1.0
    property string wallpaperSource: "local"
    property var wallpaperModItem: null
    property var launcherItem: null
    property var spotlightItem: null
    property var controlsItem: null
    property var musicItem: null
    property var smallMusicItem: null
    property var wpItem: null
    property var mixerItem: null
    property var brightnessItem: null
    property var batteryItem: null
    property var wifiItem: null
    property var btItem: null
    property var trayItem: null
    property var notifItem: null
    property var calendarItem: null
    property var centerDashboardItem: null
    property var focusHudItem: null
    property var commandCenterItem: null
    property var spatialCanvasItem: null

    property bool commandCenterOpen: false
    property bool commandCenterAnimatingOut: false
    function openCommandCenter() {
        root.closeAllPopupsExcept("commandCenter")
        root.commandCenterAnimatingOut = false
        root.commandCenterOpen = true
        if (root.commandCenterItem) root.commandCenterItem.currentChannel = "overview"
    }
    function closeCommandCenter() {
        if (!root.commandCenterOpen && !root.commandCenterAnimatingOut) return
        root.commandCenterAnimatingOut = true
        root.commandCenterOpen = false
    }
    property real lastCommandCenterToggleTime: 0
    function toggleCommandCenter() {
        var now = Date.now()
        if (now - root.lastCommandCenterToggleTime < 250) return
        root.lastCommandCenterToggleTime = now
        if (root.commandCenterOpen) root.closeCommandCenter()
        else root.openCommandCenter()
    }

    property bool spatialCanvasOpen: false
    property bool spatialCanvasAnimatingOut: false
    function openSpatialCanvas() {
        root.closeAllPopupsExcept("spatialCanvas")
        root.spatialCanvasAnimatingOut = false
        root.spatialCanvasOpen = true
        if (root.spatialCanvasItem) root.spatialCanvasItem.zoomToOverview()
    }
    function openSpatialCanvasNode(gx, gy) {
        root.closeAllPopupsExcept("spatialCanvas")
        root.spatialCanvasAnimatingOut = false
        root.spatialCanvasOpen = true
        if (root.spatialCanvasItem) {
            root.spatialCanvasItem.zoomToNode(gx, gy)
        }
    }
    function closeSpatialCanvas() {
        if (!root.spatialCanvasOpen && !root.spatialCanvasAnimatingOut) return
        root.spatialCanvasAnimatingOut = true
        root.spatialCanvasOpen = false
    }
    property real lastSpatialCanvasToggleTime: 0
    function toggleSpatialCanvas() {
        var now = Date.now()
        if (now - root.lastSpatialCanvasToggleTime < 250) return
        root.lastSpatialCanvasToggleTime = now
        if (root.spatialCanvasOpen) root.closeSpatialCanvas()
        else root.openSpatialCanvas()
    }
    onSpatialCanvasOpenChanged: GlobalState.isCommandCenterOpen = root.spatialCanvasOpen || root.commandCenterOpen
    onCommandCenterOpenChanged: GlobalState.isCommandCenterOpen = root.spatialCanvasOpen || root.commandCenterOpen

    property bool focusHudOpen: false
    function openFocusHud() {
        root.closeAllPopupsExcept("focus")
        root.focusHudOpen = true
    }
    function closeFocusHud() {
        root.focusHudOpen = false
    }
    function toggleFocusHud() {
        if (root.focusHudOpen) root.closeFocusHud()
        else root.openFocusHud()
    }

    property bool spotlightOpen: false
    function openSpotlight() {
        root.closeAllPopupsExcept("spotlight")
        root.launcherOpen = false
        root.spotlightOpen = true
    }
    function closeSpotlight() {
        root.spotlightOpen = false
    }
    function toggleSpotlight() {
        if (root.spotlightOpen) root.closeSpotlight()
        else root.openSpotlight()
    }

    /* Launcher style */
    property string launcherStyle: "spotlight"

    FileView {
        id: launcherConfigFile
        path: root.carbonConfigDir + "/carbon-launcher.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadLauncherConfig()
        onFileChanged: root.reloadLauncherConfig()
    }

    FileView {
        id: hyprLauncherConfigFile
        path: root.home + "/.config/hypr/carbon-launcher.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadLauncherConfig()
        onFileChanged: root.reloadLauncherConfig()
    }

    function reloadLauncherConfig() {
        try {
            var txt = launcherConfigFile.text()
            if (!txt || txt.trim().length === 0) txt = hyprLauncherConfigFile.text()
            if (!txt || txt.trim().length === 0) return
            var d = JSON.parse(txt)
            if (d && (d.launcherStyle || d.defaultLauncher)) {
                root.launcherStyle = d.launcherStyle || d.defaultLauncher
            }
        } catch (e) {
            console.log("Error loading launcher config: " + e)
        }
    }

    function toggleDefaultLauncher() {
        if (root.launcherStyle === "launcher") {
            root.toggleLauncher()
        } else {
            root.toggleSpotlight()
        }
    }

    function closeAllPopupsExcept(keep) {
        if (root.nucleusHubItem && root.nucleusHubItem.hubOpen) {
            root.nucleusHubItem.close()
        }
        if (keep !== "spotlight") { root.spotlightOpen = false }
        if (keep !== "launcher") { root.launcherOpen = false }
        if (keep !== "mixer") { root.mixerOpen = false; root.mixerPinned = false }
        if (keep !== "brightness") { root.brightnessOpen = false; root.brightnessPinned = false }
        if (keep !== "battery") { root.batteryOpen = false; root.batteryPinned = false }
        if (keep !== "tray") { root.trayOpen = false; root.trayPinned = false }
        if (keep !== "music") { root.musicOpen = false; root.musicPinned = false; root.musicHovered = false }
        if (keep !== "smallMusic") { root.smallMusicOpen = false; root.smallMusicPinned = false; root.smallMusicHovered = false }
        if (keep !== "wifi") { root.wifiOpen = false; root.wifiPinned = false }
        if (keep !== "bt") { root.btOpen = false; root.btPinned = false }
        if (keep !== "calendar") { root.calendarOpen = false; root.calendarPinned = false }
        if (keep !== "notif") { root.notifOpen = false; root.notifPinned = false }
        if (keep !== "centerDashboard") { root.centerDashboardOpen = false; root.centerDashboardPinned = false }
        if (keep !== "controls") { root.controlsVisible = false; root.controlsPinned = false }
        if (keep !== "commandCenter") { root.commandCenterOpen = false; root.commandCenterAnimatingOut = false }
        if (keep !== "spatialCanvas") { root.spatialCanvasOpen = false; root.spatialCanvasAnimatingOut = false }
        if (keep !== "focus") { root.focusHudOpen = false }
        if (keep !== "settings") { root.settingsHubOpen = false }
    }

    property bool smallMusicOpen: false
    property bool smallMusicPinned: false
    property bool smallMusicHovered: false
    function openSmallMusic() {
        root.closeAllPopupsExcept("smallMusic")
        root.smallMusicOpen = true
    }
    function closeSmallMusic() { root.smallMusicOpen = false; root.smallMusicPinned = false }
    function toggleSmallMusic() {
        if (root.smallMusicOpen) {
            root.closeSmallMusic()
        } else {
            root.closeAllPopupsExcept("smallMusic")
            root.smallMusicPinned = true
            root.smallMusicOpen = true
        }
    }

    Timer {
        id: smallMusicLeaveTimer
        interval: 350
        onTriggered: {
            if ((root.barMode !== "minimal" || !root.smallMusicPinned) && !root.smallMusicHovered) root.closeSmallMusic()
        }
    }

    /* Calendar popup state */
    property bool calendarOpen: false
    property bool calendarPinned: false
    property bool centerDashboardAwaitingHover: false
    function openCalendar() {
        if (root.barMode === "nucleus") {
            if (root.nucleusHubItem) root.nucleusHubItem.openCalendarMode()
            return
        }
        centerDashboardLeaveTimer.stop()
        root.centerDashboardPinned = false
        root.centerDashboardAwaitingHover = true
        root.openCenterDashboard()
        centerDashboardLeaveTimer.interval = 1000
        centerDashboardLeaveTimer.restart()
    }
    function closeCalendar() {
        if (root.barMode === "nucleus") {
            if (root.nucleusHubItem) root.nucleusHubItem.activeMode = "hub"
            return
        }
        root.closeCenterDashboard()
    }
    function toggleCalendar() {
        if (root.barMode === "nucleus") {
            if (root.nucleusHubItem) {
                if (root.nucleusHubItem.hubOpen && root.nucleusHubItem.activeMode === "calendar") {
                    root.nucleusHubItem.close()
                } else {
                    root.nucleusHubItem.openCalendarMode()
                }
            }
            return
        }
        root.toggleCenterDashboard()
    }

    onCalendarOpenChanged: {
        if (root.calendarOpen) { calendarOutTimer.stop(); root.calendarHidden = false }
        else { calendarOutTimer.restart() }
    }

    Timer {
        id: calendarLeaveTimer
        interval: 400
        onTriggered: {
            if (!root.calendarPinned && !root.calendarHovered) root.closeCalendar()
        }
    }

    Timer {
        id: calendarOutTimer
        interval: 90
        onTriggered: root.calendarHidden = true
    }

    /* Center Dashboard state */
    property var notchCenterItem: null
    property bool centerDashboardOpen: false
    property bool centerDashboardPinned: false
    property bool centerDashboardHovered: false
    property bool centerDashboardHidden: true

    function openCenterDashboard(pinned) {
        centerDashboardLeaveTimer.stop()
        root.closeAllPopupsExcept("centerDashboard")
        if (pinned !== undefined) root.centerDashboardPinned = pinned
        else root.centerDashboardPinned = true
        root.centerDashboardOpen = true
    }
    function closeCenterDashboard(force) {
        root.centerDashboardPinned = false
        root.centerDashboardOpen = false
    }
    function toggleCenterDashboard() {
        if (root.centerDashboardOpen) {
            root.centerDashboardPinned = false
            root.centerDashboardOpen = false
        } else {
            root.closeAllPopupsExcept("centerDashboard")
            root.centerDashboardPinned = true
            root.centerDashboardOpen = true
        }
    }

    onCenterDashboardOpenChanged: {
        if (root.centerDashboardOpen) {
            centerDashboardOutTimer.stop()
            root.centerDashboardHidden = false
        } else {
            centerDashboardOutTimer.restart()
        }
    }

    Timer {
        id: centerDashboardLeaveTimer
        interval: 450
        onTriggered: {
            if (!root.centerDashboardPinned && !root.centerDashboardHovered) {
                root.centerDashboardAwaitingHover = false
                root.closeCenterDashboard()
            }
        }
    }

    Timer {
        id: centerDashboardOutTimer
        interval: 180
        onTriggered: root.centerDashboardHidden = true
    }

    /* Mixer popup state: open/pinned (click) or hover-release behaviour. */
    property bool mixerOpen: false
    property bool mixerPinned: false
    property bool mixerHovered: false
    property bool mixerHidden: true

    function openMixer() {
        root.closeAllPopupsExcept("mixer")
        root.mixerOpen = true
    }
    function closeMixer() { root.mixerOpen = false; root.mixerPinned = false }
    function toggleMixer() {
        if (root.mixerOpen) { root.closeMixer() }
        else { root.closeAllPopupsExcept("mixer"); root.mixerPinned = true; root.mixerOpen = true }
    }

    onMixerOpenChanged: {
        if (root.mixerOpen) { mixerOutTimer.stop(); root.mixerHidden = false }
        else { mixerOutTimer.restart() }
    }

    /* Hover-leave: close briefly after the pointer leaves both the bar icon
     * and the popup, unless the popup is pinned (clicked). */
    Timer {
        id: mixerLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.mixerPinned && !root.mixerHovered) root.closeMixer()
        }
    }

    /* Fade-out grace: keep the window alive a moment so the close animation
     * is visible before the layer surface unmaps. */
    Timer {
        id: mixerOutTimer
        interval: 90
        onTriggered: root.mixerHidden = true
    }

    /* Brightness popup state: open/pinned (click) or hover-release behaviour. */
    property bool brightnessOpen: false
    property bool brightnessPinned: false
    property bool brightnessHovered: false
    property bool brightnessHidden: true

    function openBrightness() {
        root.closeAllPopupsExcept("brightness")
        root.brightnessOpen = true
    }
    function closeBrightness() { root.brightnessOpen = false; root.brightnessPinned = false }
    function toggleBrightness() {
        if (root.brightnessOpen) { root.closeBrightness() }
        else { root.closeAllPopupsExcept("brightness"); root.brightnessPinned = true; root.brightnessOpen = true }
    }

    onBrightnessOpenChanged: {
        if (root.brightnessOpen) { brightnessOutTimer.stop(); root.brightnessHidden = false }
        else { brightnessOutTimer.restart() }
    }

    Timer {
        id: brightnessLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.brightnessPinned && !root.brightnessHovered) root.closeBrightness()
        }
    }

    Timer {
        id: brightnessOutTimer
        interval: 90
        onTriggered: root.brightnessHidden = true
    }

    /* Battery popup state: open/pinned (click) or hover-release behaviour. */
    property bool batteryOpen: false
    property bool batteryPinned: false
    property bool batteryHovered: false
    property bool batteryHidden: true

    function openBattery() {
        if (root.barMode === "pill") {
            root.closeAllPopupsExcept("controls")
            root.controlsPinned = true
            root.controlsVisible = true
            if (controlsItem) {
                controlsItem.wifiPopupOpen = false
                controlsItem.btPopupOpen = false
                controlsItem.audioPopupOpen = false
                controlsItem.mode = 2
            }
        } else {
            root.closeAllPopupsExcept("battery")
            root.batteryOpen = true
        }
    }
    function closeBattery() {
        if (root.barMode === "pill") {
            root.closeControls()
        } else {
            root.batteryOpen = false
            root.batteryPinned = false
        }
    }
    function toggleBattery() {
        if (root.barMode === "pill") {
            if (root.controlsVisible && controlsItem && controlsItem.mode === 2) {
                root.closeControls()
            } else {
                root.closeAllPopupsExcept("controls")
                root.controlsPinned = true
                root.controlsVisible = true
                if (controlsItem) {
                    controlsItem.wifiPopupOpen = false
                    controlsItem.btPopupOpen = false
                    controlsItem.audioPopupOpen = false
                    controlsItem.mode = 2
                }
            }
        } else {
            if (root.batteryOpen) {
                root.closeBattery()
            } else {
                root.closeAllPopupsExcept("battery")
                root.batteryPinned = true
                root.batteryOpen = true
            }
        }
    }

    onBatteryOpenChanged: {
        if (root.batteryOpen) { batteryOutTimer.stop(); root.batteryHidden = false }
        else { batteryOutTimer.restart() }
    }

    Timer {
        id: batteryLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.batteryPinned && !root.batteryHovered) root.closeBattery()
        }
    }

    Timer {
        id: batteryOutTimer
        interval: 90
        onTriggered: root.batteryHidden = true
    }

    /* Notification Popup State */
    property bool notifOpen: false
    property bool notifPinned: false
    property bool notifHovered: false
    property bool notifHidden: true

    function openNotif() {
        root.closeAllPopupsExcept("notif")
        root.notifOpen = true
    }
    function closeNotif() {
        root.notifOpen = false
        root.notifPinned = false
    }
    function toggleNotif() {
        if (root.notifOpen) {
            root.closeNotif()
        } else {
            root.closeAllPopupsExcept("notif")
            root.notifPinned = true
            root.notifOpen = true
        }
    }

    onNotifOpenChanged: {
        if (root.notifOpen) { notifOutTimer.stop(); root.notifHidden = false }
        else { notifOutTimer.restart() }
    }
    Timer {
        id: notifOutTimer
        interval: 240
        onTriggered: root.notifHidden = true
    }
    property bool trayOpen: false
    property bool trayPinned: false
    property bool trayHovered: false
    property bool trayHidden: true

    function openTray() {
        root.closeAllPopupsExcept("tray")
        root.trayOpen = true
    }
    function closeTray() { root.trayOpen = false; root.trayPinned = false }
    function toggleTray() {
        if (root.trayOpen) {
            root.closeTray()
        } else {
            root.closeAllPopupsExcept("tray")
            root.trayPinned = true
            root.trayOpen = true
        }
    }

    onTrayOpenChanged: {
        if (root.trayOpen) { trayOutTimer.stop(); root.trayHidden = false }
        else { trayOutTimer.restart() }
    }

    Timer {
        id: trayLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.trayPinned && !root.trayHovered) root.closeTray()
        }
    }

    Timer {
        id: trayOutTimer
        interval: 90
        onTriggered: root.trayHidden = true
    }

    /* Wifi popup state */
    property bool wifiOpen: false
    property bool wifiPinned: false
    property bool wifiHovered: false
    property bool wifiHidden: true

    function openWifi() {
        if (root.barMode === "pill") {
            root.closeAllPopupsExcept("controls")
            root.controlsPinned = true
            root.controlsVisible = true
            if (controlsItem) {
                controlsItem.mode = 0
                controlsItem.openWifiDetails()
            }
        } else {
            root.closeAllPopupsExcept("wifi")
            if (!wifiProbe.running) wifiProbe.running = true
            if (!wifiNameProbe.running) wifiNameProbe.running = true
            root.wifiOpen = true
        }
    }
    function closeWifi() {
        if (root.barMode === "pill") {
            root.closeControls()
        } else {
            root.wifiOpen = false
            root.wifiPinned = false
        }
    }
    function toggleWifi() {
        if (root.barMode === "pill") {
            if (root.controlsVisible && controlsItem && controlsItem.wifiPopupOpen) {
                root.closeControls()
            } else {
                root.closeAllPopupsExcept("controls")
                root.controlsPinned = true
                root.controlsVisible = true
                if (controlsItem) {
                    controlsItem.mode = 0
                    controlsItem.openWifiDetails()
                }
            }
        } else {
            if (root.wifiOpen) { root.closeWifi() }
            else { root.closeAllPopupsExcept("wifi"); root.wifiPinned = true; root.wifiOpen = true }
        }
    }

    onWifiOpenChanged: {
        if (root.wifiOpen) { wifiOutTimer.stop(); root.wifiHidden = false }
        else { wifiOutTimer.restart() }
    }

    Timer {
        id: wifiLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.wifiPinned && !root.wifiHovered) root.closeWifi()
        }
    }

    Timer {
        id: wifiOutTimer
        interval: 90
        onTriggered: root.wifiHidden = true
    }

    /* Bluetooth popup state */
    property bool btOpen: false
    property bool btPinned: false
    property bool btHovered: false
    property bool btHidden: true

    function openBt() {
        if (root.barMode === "pill") {
            root.closeAllPopupsExcept("controls")
            root.controlsPinned = true
            root.controlsVisible = true
            if (controlsItem) {
                controlsItem.mode = 0
                controlsItem.openBtDetails()
            }
        } else {
            root.closeAllPopupsExcept("bt")
            if (!btProbe.running) btProbe.running = true
            if (!btNameProbe.running) btNameProbe.running = true
            root.btOpen = true
        }
    }
    function closeBt() {
        if (root.barMode === "pill") {
            root.closeControls()
        } else {
            root.btOpen = false
            root.btPinned = false
        }
    }
    function toggleBt() {
        if (root.barMode === "pill") {
            if (root.controlsVisible && controlsItem && controlsItem.btPopupOpen) {
                root.closeControls()
            } else {
                root.closeAllPopupsExcept("controls")
                root.controlsPinned = true
                root.controlsVisible = true
                if (controlsItem) {
                    controlsItem.mode = 0
                    controlsItem.openBtDetails()
                }
            }
        } else {
            if (root.btOpen) { root.closeBt() }
            else { root.closeAllPopupsExcept("bt"); root.btPinned = true; root.btOpen = true }
        }
    }

    onBtOpenChanged: {
        if (root.btOpen) { btOutTimer.stop(); root.btHidden = false }
        else { btOutTimer.restart() }
    }

    Timer {
        id: btLeaveTimer
        interval: 350
        onTriggered: {
            if (!root.btPinned && !root.btHovered) root.closeBt()
        }
    }

    Timer {
        id: btOutTimer
        interval: 90
        onTriggered: root.btHidden = true
    }

    /* Wifi & Bluetooth System Probes */
    property bool wifiOn: true
    property string wifiName: ""
    Process {
        id: wifiProbe
        command: ["sh", "-c", "nmcli radio wifi | tr -d ' \\n\\r'"]
        stdout: StdioCollector { id: wifiC; waitForEnd: true }
        onExited: root.wifiOn = String(wifiC.text).trim() === "enabled"
    }
    Process {
        id: wifiNameProbe
        command: ["sh", "-c", "wifi=$(nmcli -t -f IN-USE,SSID dev wifi 2>/dev/null | grep -E '^\\*:|^yes:' | head -1 | cut -d: -f2-); [ -n \"$wifi\" ] && echo \"$wifi\" || nmcli -t -f NAME connection show --active 2>/dev/null | grep -v '^lo:' | head -1 | cut -d: -f1"]
        stdout: StdioCollector { id: wifiNameC; waitForEnd: true }
        onExited: root.wifiName = String(wifiNameC.text).trim()
    }
    function toggleWifiPower() {
        root.wifiOn = !root.wifiOn
        Quickshell.execDetached(["sh", "-c", "nmcli radio wifi " + (root.wifiOn ? "on" : "off")])
    }

    property bool btOn: false
    property string btName: ""
    Process {
        id: btProbe
        command: ["sh", "-c", "timeout 4 bluetoothctl show | sed -n 's/.*Powered:[ ]*//p' | tr -d ' \\n\\r'"]
        stdout: StdioCollector { id: btC; waitForEnd: true }
        onExited: root.btOn = String(btC.text).trim() === "yes"
    }
    Process {
        id: btNameProbe
        command: ["sh", "-c", "bluetoothctl devices Connected 2>/dev/null | sed 's/^Device [0-9A-F:]* //'"]
        stdout: StdioCollector { id: btNameC; waitForEnd: true }
        onExited: root.btName = String(btNameC.text).trim()
    }
    function toggleBtPower() {
        root.btOn = !root.btOn
        if (!root.btOn) root.btName = ""
        Quickshell.execDetached(["sh", "-c", "bluetoothctl power " + (root.btOn ? "on" : "off")])
    }

    Timer {
        interval: 12000
        repeat: true
        running: (root.barMode !== "minimal" && root.barMode !== "minimal_notch")
        triggeredOnStart: false
        onTriggered: {
            if (!wifiProbe.running) wifiProbe.running = true
            if (!wifiNameProbe.running) wifiNameProbe.running = true
            if (!btProbe.running) btProbe.running = true
            if (!btNameProbe.running) btNameProbe.running = true
        }
    }

    /* Power menu state */
    property bool powerOpen: false
    function openPower() { root.powerOpen = true }
    function closePower() { root.powerOpen = false }
    function togglePower() { root.powerOpen = !root.powerOpen }

    /* Workspaces & Windows Overview state */
    property bool overviewOpen: false
    function openOverview() { root.overviewOpen = true }
    function closeOverview() { root.overviewOpen = false }
    function toggleOverview() { root.overviewOpen = !root.overviewOpen }

    /* Wallpaper transition state */
    property bool wallpaperTransitionOpen: false
    property bool wallpaperTransitionPendingFinish: false
    property string wallpaperTransitionText: "Applying Wallpaper"

    function startWallpaperTransition(name) {
        root.wallpaperTransitionText = "Applying Wallpaper"
        root.wallpaperTransitionPendingFinish = false
        root.wallpaperTransitionOpen = true
    }

    function finishWallpaperTransition() {
        root.wallpaperTransitionPendingFinish = true
    }

    function openLauncher() {
        root.closeAllPopupsExcept("launcher")
        root.spotlightOpen = false
        root.closeWallpaperPicker()
        root.launcherOpen = true
    }
    property real lastLauncherToggleTime: 0
    function closeLauncher() {
        root.launcherOpen = false
        // Preserve active workspace so Hyprland does not revert to old workspace where launcher opened
        Quickshell.execDetached(["sh", "-c", "ws=$(hyprctl activeworkspace -j | jq -r .id 2>/dev/null); [ -n \"$ws\" ] && (sleep 0.05 && hyprctl dispatch workspace \"$ws\")"])
    }
    function toggleLauncher() {
        var now = Date.now()
        if (now - root.lastLauncherToggleTime < 280) return
        root.lastLauncherToggleTime = now
        if (root.launcherOpen) closeLauncher(); else openLauncher()
    }

    property real lastWpToggleTime: 0
    function openWallpaperPicker() {
        root.closeLauncher()
        root.wallpaperPickerOpen = true
    }
    function closeWallpaperPicker() { root.wallpaperPickerOpen = false }
    function toggleWallpaperPicker() {
        var now = Date.now()
        if (now - root.lastWpToggleTime < 280) return
        root.lastWpToggleTime = now
        if (root.wallpaperPickerOpen) closeWallpaperPicker(); else openWallpaperPicker()
    }

    property real lastSettingsToggleTime: 0
    function openSettingsHub() {
        root.closeLauncher()
        root.settingsHubOpen = true
    }
    function closeSettingsHub() { root.settingsHubOpen = false }
    function toggleSettingsHub() {
        var now = Date.now()
        if (now - root.lastSettingsToggleTime < 280) return
        root.lastSettingsToggleTime = now
        if (root.settingsHubOpen) closeSettingsHub(); else openSettingsHub()
    }
    onLauncherOpenChanged: {
        if (!root.launcherOpen && root.launcherItem)
            root.launcherItem.resetToApps()
    }

    /* Music popup & notch dropdown state */
    property bool musicOpen: false
    property bool musicPinned: false
    property bool musicHovered: false
    property bool musicHidden: true

    function openMusic() {
        root.closeAllPopupsExcept("music")
        root.musicOpen = true
        root.musicHovered = true
        musicLeaveTimer.stop()
    }
    function closeMusic() {
        root.musicOpen = false
        root.musicPinned = false
        root.musicHovered = false
    }
    function toggleMusic() {
        if (root.musicOpen && root.musicPinned) {
            root.musicPinned = false
            root.musicOpen = false
        } else {
            root.closeAllPopupsExcept("music")
            root.musicPinned = true
            root.musicOpen = true
        }
    }

    onMusicOpenChanged: {
        if (root.musicOpen) {
            musicOutTimer.stop()
            root.musicHidden = false
        } else {
            musicOutTimer.restart()
        }
    }

    Timer {
        id: musicLeaveTimer
        interval: 320
        onTriggered: {
            if (!root.musicPinned && !root.musicHovered) {
                root.musicOpen = false
            }
        }
    }

    Timer {
        id: musicOutTimer
        interval: 220
        onTriggered: root.musicHidden = true
    }

    /* Mode Transitions */
    signal triggerWallpaperTransition()
    property bool nucleusTransitionActive: false
    property bool nucleusTransitionEnabled: false
    property string nucleusTransitionWord: "Wooshh!!"
    property string nucleusTransitionAnimation: "quantum"

    function startNucleusTransition(force) {
        if (!force && !root.nucleusTransitionEnabled) {
            root.barMode = "nucleus"
            return
        }
        root.nucleusTransitionActive = true
        root.triggerWallpaperTransition()
    }

    function finishNucleusTransition() {
        root.barMode = "nucleus"
        root.nucleusTransitionActive = false
        Quickshell.execDetached(["python3", "-c",
            "import json, os; dir=os.environ.get('CARBON_CONFIG_DIR', os.path.expanduser('~/.config/carbon')); os.makedirs(dir, exist_ok=True); p=os.path.join(dir, 'carbon-bar-mode.json'); d=json.load(open(p)) if os.path.exists(p) else {}; d['mode']='nucleus'; json.dump(d, open(p,'w'), indent=2)"])
    }

    /* Bar Mode */
    property string barMode: "notch"
    property bool workspaceOsdActive: false
    property bool showWorkspaceOsd: true
    property var nucleusRestingSpin: "hover"
    property bool nucleusRestingVisible: true
    property bool screenshotFreezeActive: false
    onBarModeChanged: {
        console.log("[BAR-MODE CHANGED] New root.barMode is now: " + root.barMode)
        Quickshell.execDetached(["bash", root.carbonConfigDir + "/scripts/carbon-mode-keybinds.sh", root.barMode])
    }

    FileView {
        id: barModeFile
        path: root.carbonConfigDir + "/carbon-bar-mode.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadBarMode()
        onFileChanged: root.reloadBarMode()
    }

    FileView {
        id: hyprBarModeFile
        path: root.home + "/.config/hypr/carbon-bar-mode.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadBarMode()
        onFileChanged: root.reloadBarMode()
    }

    Timer {
        id: barModePoller
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            if (!root._switchingBarMode) {
                root.reloadBarMode()
            }
        }
    }

    property string islandStyle: "notch"
    property int islandPage: 0
    property bool islandPersistent: true
    property bool islandHovered: false
    property string batteryLayout: "horizontal"
    property bool showVinylDisc: true
    property bool showEqualizer: true
    property bool autoExpandOnTrack: false
    readonly property bool islandRevealed: islandPersistent || islandHovered || mixerOpen || trayOpen || brightnessOpen || batteryOpen || wifiOpen || btOpen || calendarOpen || centerDashboardOpen || smallMusicOpen

    property bool _switchingBarMode: false

    Timer {
        id: switchGuardTimer
        interval: 600
        onTriggered: root._switchingBarMode = false
    }

    function reloadBarMode() {
        if (root._switchingBarMode) {
            return
        }
        try {
            barModeFile.reload()
            var txt = barModeFile.text().trim()
            if (!txt || txt.length === 0) {
                hyprBarModeFile.reload()
                txt = hyprBarModeFile.text().trim()
            }

            if (txt.length > 0) {
                const d = JSON.parse(txt)
                if (d.nucleus) {
                    if (d.nucleus.transition !== undefined) {
                        root.nucleusTransitionEnabled = Boolean(d.nucleus.transition)
                    }
                    if (d.nucleus.transitionWord) {
                        root.nucleusTransitionWord = String(d.nucleus.transitionWord)
                    }
                    if (d.nucleus.animation) {
                        root.nucleusTransitionAnimation = String(d.nucleus.animation)
                    }
                    if (d.nucleus.restingSpin !== undefined) {
                        root.nucleusRestingSpin = d.nucleus.restingSpin
                    }
                    if (d.nucleus.showRestingAtom !== undefined) {
                        root.nucleusRestingVisible = Boolean(d.nucleus.showRestingAtom)
                    }
                }
                if (d.mode) {
                    var target = String(d.mode).toLowerCase()
                    if (target === "three_islands") target = "notch"
                    if (target === "vanish") target = "nucleus"
                    if (target === "island") target = "notch"
                    if (target === "minimal") target = "minimal_notch"
                    if (root.barMode !== target) {
                        console.log("[BAR-MODE] Switching mode from", root.barMode, "to", target)
                        root.barMode = target
                    }
                }
                if (d.islandStyle) {
                    root.islandStyle = d.islandStyle
                }
                if (d.islandPersistent !== undefined) {
                    root.islandPersistent = Boolean(d.islandPersistent)
                }
                if (d.batteryLayout) {
                    root.batteryLayout = String(d.batteryLayout).toLowerCase()
                }
                if (d.showWorkspaceOsd !== undefined) {
                    root.showWorkspaceOsd = Boolean(d.showWorkspaceOsd)
                }
                if (root.barMode === "pill" || root.barMode === "minimal" || root.barMode === "minimal_notch") {
                    if (root.mainBarEdge !== "top" && root.mainBarEdge !== "bottom") {
                        root.mainBarEdge = "top"
                        root.barEdge = "top"
                        root.musicBarEdge = "top"
                    }
                }
            }
        } catch (e) {
            console.log("Error loading bar mode: " + e)
        }
    }

    function switchBarMode(m) {
        console.log("[BAR-MODE] switchBarMode called with: " + m)
        if (!m) return
        m = String(m).toLowerCase()
        if (m === "three_islands") m = "notch"
        if (m === "vanish") m = "nucleus"
        if (m === "island") m = "notch"
        if (m === "minimal") m = "minimal_notch"
        if (m === "nucleus" && root.barMode !== "nucleus" && root.nucleusTransitionEnabled) {
            root.startNucleusTransition(false)
            return
        }
        root._switchingBarMode = true
        switchGuardTimer.restart()
        root.barMode = m
        console.log("[BAR-MODE] switchBarMode set root.barMode to: " + root.barMode)
        Quickshell.execDetached(["python3", "-c",
            "import json, os\n" +
            "dirs = [os.environ.get('CARBON_CONFIG_DIR', os.path.expanduser('~/.config/carbon')), os.path.expanduser('~/.config/hypr')]\n" +
            "for dir in dirs:\n" +
            "  try:\n" +
            "    os.makedirs(dir, exist_ok=True)\n" +
            "    p = os.path.join(dir, 'carbon-bar-mode.json')\n" +
            "    d = json.load(open(p)) if os.path.exists(p) else {}\n" +
            "    if d.get('mode') != '" + m + "':\n" +
            "      d['mode'] = '" + m + "'\n" +
            "      d['islandStyle'] = '" + m + "'\n" +
            "      t = p + '.tmp'\n" +
            "      with open(t, 'w') as f: json.dump(d, f, indent=2)\n" +
            "      os.replace(t, p)\n" +
            "  except Exception: pass\n"
        ])
    }

    function switchIslandStyle(s) {
        if (!s) return
        root.islandStyle = s
        Quickshell.execDetached(["python3", "-c",
            "import json, os; dir=os.environ.get('CARBON_CONFIG_DIR', os.path.expanduser('~/.config/carbon')); os.makedirs(dir, exist_ok=True); p=os.path.join(dir, 'carbon-bar-mode.json'); d=json.load(open(p)) if os.path.exists(p) else {}; d['islandStyle']='" + s + "'; json.dump(d, open(p,'w'), indent=2)"])
    }

    function switchIslandPersistent(p) {
        root.islandPersistent = Boolean(p)
        Quickshell.execDetached(["python3", "-c",
            "import json, os; dir=os.environ.get('CARBON_CONFIG_DIR', os.path.expanduser('~/.config/carbon')); os.makedirs(dir, exist_ok=True); p=os.path.join(dir, 'carbon-bar-mode.json'); d=json.load(open(p)) if os.path.exists(p) else {}; d['islandPersistent']=" + (p ? "True" : "False") + "; json.dump(d, open(p,'w'), indent=2)"])
    }

    function setRestingAtomVisible(vis) {
        root.nucleusRestingVisible = Boolean(vis)
        if (root.nucleusHubItem) root.nucleusHubItem.showRestingAtom = root.nucleusRestingVisible
        Quickshell.execDetached(["python3", "-c",
            "import json, os\n" +
            "dirs = [os.environ.get('CARBON_CONFIG_DIR', os.path.expanduser('~/.config/carbon')), os.path.expanduser('~/.config/hypr')]\n" +
            "for d in dirs:\n" +
            "  try:\n" +
            "    os.makedirs(d, exist_ok=True)\n" +
            "    p = os.path.join(d, 'carbon-bar-mode.json')\n" +
            "    data = json.load(open(p)) if os.path.exists(p) else {}\n" +
            "    if 'nucleus' not in data or not isinstance(data['nucleus'], dict): data['nucleus'] = {}\n" +
            "    data['nucleus']['showRestingAtom'] = " + (vis ? "True" : "False") + "\n" +
            "    tmp = p + '.tmp'\n" +
            "    with open(tmp, 'w') as f: json.dump(data, f, indent=2)\n" +
            "    os.replace(tmp, p)\n" +
            "  except Exception: pass\n"
        ])
    }

    property real shellOpacity: Theme.shellOpacity
    property bool shellBlur: true
    property int basePillHeight: 36
    property int baseNotchHeight: 34
    property int baseNotchEarRadius: 10
    property int baseNotchBottomRadius: 14
    property int baseAppGap: 8

    property int pillHeight: Math.round(root.basePillHeight * root.shellScale)
    property int notchHeight: Math.round(root.baseNotchHeight * root.shellScale)
    property int notchEarRadius: Math.round(root.baseNotchEarRadius * root.shellScale)
    property int notchBottomRadius: Math.round(root.baseNotchBottomRadius * root.shellScale)
    property int sideNotchBottomRadius: Math.round(Math.min(8 * root.shellScale, root.notchBottomRadius))
    property int appGap: Math.round(root.baseAppGap * root.shellScale)
    property int pillAppGap: root.appGap
    property int notchAppGap: root.appGap
    property real pillOpacity: root.shellOpacity
    property bool pillBlur: root.shellBlur
    property real notchOpacity: root.shellOpacity
    property bool notchBlur: root.shellBlur
    property real minimalOpacity: root.shellOpacity
    property bool minimalBlur: root.shellBlur

    /* Minimal Notch */
    readonly property bool screenRecordingActive: false
    property bool focusEnabled: (typeof Theme !== "undefined" && Theme.dnd !== undefined) ? Theme.dnd : false
    property alias tideFocusEnabled: root.focusEnabled
    onFocusEnabledChanged: {
        if (typeof Theme !== "undefined" && Theme.dnd !== root.focusEnabled)
            Theme.dnd = root.focusEnabled
        if (typeof NotificationService !== "undefined" && NotificationService.dnd !== root.focusEnabled)
            NotificationService.dnd = root.focusEnabled
    }
    Connections {
        target: Theme
        function onDndChanged() {
            if (root.focusEnabled !== Theme.dnd)
                root.focusEnabled = Theme.dnd
        }
    }
    property bool tideNightLightEnabled: false
    property bool islandAutoHideRuntimeEnabled: true

    function forEachTideWindow(callback) {
        const windows = tideIslandVariants.instances ? tideIslandVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window)
                callback(window);
        }
    }

    function forFocusedTideWindow(callback) {
        const windows = tideIslandVariants.instances ? tideIslandVariants.instances : [];
        let fallbackWindow = null;
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window && !fallbackWindow)
                fallbackWindow = window;
            if (window && window.monitorFocused) {
                callback(window);
                return;
            }
        }
        if (fallbackWindow)
            callback(fallbackWindow);
    }

    function anyTideOverviewOpen() {
        const windows = tideIslandVariants.instances ? tideIslandVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window && window.overviewPhase !== "closed")
                return true;
        }
        return false;
    }

    function prepareOverviewAll() {
        forEachTideWindow((window) => window.prepareOverview());
    }

    function cancelPreparedOverviewAll() {
        forEachTideWindow((window) => window.cancelPreparedOverview());
    }

    function openOverviewAll() {
        forEachTideWindow((window) => window.openOverview());
    }

    function closeOverviewAll() {
        forEachTideWindow((window) => window.closeOverview());
    }

    function toggleOverviewAll() {
        if (anyTideOverviewOpen())
            closeOverviewAll();
        else
            openOverviewAll();
    }

    function anyIslandShown() {
        const windows = tideIslandVariants.instances ? tideIslandVariants.instances : [];
        for (let index = 0; index < windows.length; index++) {
            const window = windows[index];
            if (window && window.autoHideTargetVisible)
                return true;
        }
        return false;
    }

    function showIslandAll() {
        forEachTideWindow((window) => {
            if (window && window.showIslandWindow)
                window.showIslandWindow();
        });
    }

    function hideIslandAll() {
        forEachTideWindow((window) => {
            if (window && window.hideIslandWindow)
                window.hideIslandWindow();
        });
    }

    function toggleIslandAll() {
        if (anyIslandShown())
            hideIslandAll();
        else
            showIslandAll();
    }

    function refreshIslandAutoHideAll() {
        forEachTideWindow((window) => {
            if (window && window.refreshAutoHideWindow)
                window.refreshAutoHideWindow();
        });
    }

    function toggleNotchAll() {
        forEachTideWindow((window) => {
            if (window && window.toggleNotchMode)
                window.toggleNotchMode();
        });
    }

    function setNotchModeAll(enabled) {
        forEachTideWindow((window) => {
            if (window && window.setNotchMode)
                window.setNotchMode(enabled);
        });
    }

    function refreshOverviewWallpaperCaches(wallpaperPath) {
        forEachTideWindow((window) => {
            if (window && wallpaperPath !== undefined && wallpaperPath !== null && String(wallpaperPath) !== "") {
                window.wallpaperPickerActiveWallpaper = String(wallpaperPath);
            }
            if (window && window.prewarmWallpaperCache)
                window.prewarmWallpaperCache();
        });
    }

    function showTideNotificationAll(appName, summary, body) {
        forEachTideWindow((window) => {
            if (window && window.showNotification)
                window.showNotification(appName, summary, body);
        });
    }
    property int barHeight: root.barMode === "notch" ? root.notchHeight : root.pillHeight
    property string barEdge: "top"
    property string mainBarEdge: "top"
    property string musicBarEdge: "top"
    property string musicBarContent: "both"
    property string leftAlign: "left"
    property string centerAlign: "center"
    property string rightAlign: "right"
    property string leftEdge: "top"
    property string centerEdge: "top"
    property string rightEdge: "top"

    /* Panel corner placement for Quick Settings (Control Center):
     * - Top-right (default floating desktop location)
     * - Bottom edge -> "bottom_right" or "bottom_left"
     */
    readonly property string controlsCorner: {
        return (root.mainBarEdge === "bottom" || root.barEdge === "bottom") ? "bottom_right" : "top_right"
    }

    readonly property int popupTopMargin: {
        if (root.mainBarEdge === "bottom") return 0
        if (root.barMode === "notch") return root.notchHeight + 4
        if (root.barMode === "pill") return root.pillHeight + 10
        if (root.barMode === "minimal" || root.barMode === "minimal_notch") return (root.islandStyle === "notch" ? root.notchHeight + 6 : root.pillHeight + 16)
        return 0
    }

    readonly property int popupBottomMargin: {
        if (root.mainBarEdge !== "bottom") return 0
        if (root.barMode === "notch") return root.notchHeight + 4
        if (root.barMode === "pill") return root.pillHeight + 10
        if (root.barMode === "minimal" || root.barMode === "minimal_notch") return (root.islandStyle === "notch" ? root.notchHeight + 6 : root.pillHeight + 16)
        return 0
    }

    readonly property int popupRightMargin: {
        if (root.barMode === "notch") return 12
        if (root.barMode === "pill") return Math.max(12, Math.round(((Quickshell.screens[0] ? Quickshell.screens[0].width : 1920) - 1000) / 2))
        return 0
    }

    FileView {
        id: barPosFile
        path: root.carbonConfigDir + "/carbon-bar-position.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.applyBarPos(barPosFile.text())
        onFileChanged: {
            reload()
            root.applyBarPos(barPosFile.text())
        }
    }

    function applyBarPos(txt) {
        if (!txt) return
        try {
            var d = JSON.parse(txt)
            var chosenEdge = "top"
            if (d.mainBarEdge === "bottom" || d.edge === "bottom") {
                chosenEdge = "bottom"
            }
            root.mainBarEdge = chosenEdge
            root.musicBarEdge = chosenEdge
            root.barEdge = chosenEdge
            root.leftEdge = chosenEdge
            root.centerEdge = chosenEdge
            root.rightEdge = chosenEdge

            if (d.musicBarContent) root.musicBarContent = d.musicBarContent
            if (d.leftAlign) root.leftAlign = d.leftAlign
            if (d.centerAlign) root.centerAlign = d.centerAlign
            if (d.rightAlign) root.rightAlign = d.rightAlign

            if (d.pillHeight !== undefined) root.basePillHeight = parseInt(d.pillHeight) || 36
            if (d.notchHeight !== undefined) root.baseNotchHeight = parseInt(d.notchHeight) || 34
            if (d.notchEarRadius !== undefined) root.baseNotchEarRadius = parseInt(d.notchEarRadius) || 10
            if (d.notchBottomRadius !== undefined) root.baseNotchBottomRadius = parseInt(d.notchBottomRadius) || 14
            if (d.appGap !== undefined) root.baseAppGap = (!isNaN(parseInt(d.appGap))) ? parseInt(d.appGap) : 8
            if (d.pillAppGap !== undefined) root.pillAppGap = (!isNaN(parseInt(d.pillAppGap))) ? Math.round(parseInt(d.pillAppGap) * root.shellScale) : root.appGap
            else root.pillAppGap = root.appGap
            if (d.notchAppGap !== undefined) root.notchAppGap = (!isNaN(parseInt(d.notchAppGap))) ? Math.round(parseInt(d.notchAppGap) * root.shellScale) : root.appGap
            else root.notchAppGap = root.appGap

            if (d.scale !== undefined) {
                var s = Math.max(0.75, Math.min(1.5, parseFloat(d.scale) || 1.0))
                root.shellScale = s
                if (Theme) {
                    Theme.shellScale = s
                    Theme.fontScale = s
                }
            }

            if (d.shellOpacity !== undefined) {
                root.shellOpacity = Math.max(0.10, Math.min(1.0, parseFloat(d.shellOpacity) || 0.85))
                root.pillOpacity = root.shellOpacity
                root.notchOpacity = root.shellOpacity
                root.minimalOpacity = root.shellOpacity
                Theme.shellOpacity = root.shellOpacity
            } else {
                if (d.pillOpacity !== undefined) root.pillOpacity = parseFloat(d.pillOpacity) || 0.85
                if (d.notchOpacity !== undefined) root.notchOpacity = parseFloat(d.notchOpacity) || 0.90
                if (d.minimalOpacity !== undefined) root.minimalOpacity = parseFloat(d.minimalOpacity) || 0.90
            }

            if (d.shellBlur !== undefined) {
                root.shellBlur = !!d.shellBlur
                root.pillBlur = root.shellBlur
                root.notchBlur = root.shellBlur
                root.minimalBlur = root.shellBlur
            } else {
                if (d.pillBlur !== undefined) root.pillBlur = !!d.pillBlur
                if (d.notchBlur !== undefined) root.notchBlur = !!d.notchBlur
                if (d.minimalBlur !== undefined) root.minimalBlur = !!d.minimalBlur
            }

            if (d.showVinylDisc !== undefined) root.showVinylDisc = Boolean(d.showVinylDisc)
            if (d.showEqualizer !== undefined) root.showEqualizer = Boolean(d.showEqualizer)
            if (d.autoExpandOnTrack !== undefined) root.autoExpandOnTrack = Boolean(d.autoExpandOnTrack)

            root.barHeight = (root.barMode === "notch" ? root.notchHeight : root.pillHeight)
        } catch (e) {}
    }

    Component.onCompleted: {
        reloadBarMode()
        applyBarPos(barPosFile.text())
        reloadControlCenterConfig()
        var _initLyrics = LyricsService.hasTrack
    }

    property real volumeStepVal: 0.05
    property real brightnessStepVal: 0.05
    property bool showBatteryPercent: true

    FileView {
        id: controlCenterConfigFile
        path: root.carbonConfigDir + "/carbon-control-center.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadControlCenterConfig()
        onFileChanged: root.reloadControlCenterConfig()
    }

    FileView {
        id: hyprControlCenterConfigFile
        path: root.home + "/.config/hypr/carbon-control-center.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadControlCenterConfig()
        onFileChanged: root.reloadControlCenterConfig()
    }

    function reloadControlCenterConfig() {
        try {
            var txt = controlCenterConfigFile.text()
            if (!txt || txt.trim().length === 0) txt = hyprControlCenterConfigFile.text()
            if (!txt || txt.trim().length === 0) return
            var d = JSON.parse(txt)
            if (d.volumeStep !== undefined) root.volumeStepVal = Math.max(0.01, Math.min(0.20, (parseFloat(d.volumeStep) || 5) / 100.0))
            if (d.brightnessStep !== undefined) root.brightnessStepVal = Math.max(0.01, Math.min(0.20, (parseFloat(d.brightnessStep) || 5) / 100.0))
            if (d.showBatteryPercent !== undefined) root.showBatteryPercent = Boolean(d.showBatteryPercent)
        } catch (e) {}
    }

    /* MPRIS */
    readonly property var mprisPlayers: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    property var activeMprisPlayer: null
    readonly property var bgLyricsService: LyricsService

    function resolveActiveMprisPlayer() {
        if (!root.mprisPlayers || root.mprisPlayers.length === 0) return null
        for (let i = 0; i < root.mprisPlayers.length; i++) {
            if (root.mprisPlayers[i].playbackState === MprisPlaybackState.Playing)
                return root.mprisPlayers[i]
        }
        for (let i = 0; i < root.mprisPlayers.length; i++) {
            if (root.mprisPlayers[i].playbackState === MprisPlaybackState.Paused
                && (root.mprisPlayers[i].trackTitle || "").length > 0)
                return root.mprisPlayers[i]
        }
        return root.mprisPlayers[0]
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.activeMprisPlayer = root.resolveActiveMprisPlayer()
    }

    readonly property string mprisTrackTitle: activeMprisPlayer ? (activeMprisPlayer.trackTitle || "") : ""
    readonly property string mprisTrackArtist: activeMprisPlayer ? (activeMprisPlayer.trackArtist || "") : ""
    readonly property string mprisArtUrl: activeMprisPlayer ? (activeMprisPlayer.trackArtUrl || "") : ""
    readonly property bool mprisHasTrack: root.activeMprisPlayer !== null && root.mprisTrackTitle.trim().length > 0

    /* Quick-settings panel: hover the top-right hot corner to summon it, and
     * keep it while the pointer is over the panel (or the corner). */
    property bool controlsVisible: false
    property bool controlsHovered: false
    property bool controlsPinned: false

    function openControls() {
        if (root.barMode === "nucleus") return
        root.closeAllPopupsExcept("centerDashboard")
        if (root.notchCenterItem) root.notchCenterItem.notchPage = -1
        root.openCenterDashboard(true)
    }
    function openControlsHover() {
        root.openControls()
    }
    function closeControls() { root.closeCenterDashboard() }
    function toggleControls() {
        if (root.centerDashboardOpen && root.notchCenterItem && root.notchCenterItem.notchPage === -1) {
            root.closeCenterDashboard()
        } else {
            if (root.notchCenterItem) root.notchCenterItem.notchPage = -1
            root.openCenterDashboard(true)
        }
    }

    Timer {
        id: controlsLeaveTimer
        interval: 450
        onTriggered: {
            if (!root.controlsPinned && !root.controlsHovered) root.closeControls()
        }
    }

    /* Notification daemon: claims org.freedesktop.Notifications (swaync is
     * disabled in Hyprland) and feeds the top-right bar. Exactly one. */
    NotificationServer {
        id: notificationServer
        actionsSupported: true
        bodySupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        bodyMarkupSupported: true
        onNotification: notification => {
            notification.tracked = true
            NotificationService.addNotification(notification)
            if (root.barMode === "minimal" || root.barMode === "minimal_notch") {
                if (!NotificationService.dnd && !GlobalState.doNotDisturb) {
                    root.showTideNotificationAll(notification.appName || "Notification", notification.summary || "", notification.body || "")
                }
            }
        }
    }

    Binding {
        target: NotificationService
        property: "server"
        value: notificationServer
    }

    Binding {
        target: LyricsService
        property: "enabled"
        value: true
    }

    Binding {
        target: HudService
        property: "enabled"
        value: (root.barMode !== "minimal" && root.barMode !== "minimal_notch")
    }

    /* External trigger (keybinds): Super+W brokered to the launcher in
     * wallpaper mode by carbon-ipc.sh over this unix socket. */
    SocketServer {
        id: cmdSocketServer
        path: "/tmp/carbon-shell.sock"
        active: true
        handler: Component {
            Socket {
                parser: SplitParser {
                splitMarker: "\n"
                onRead: function (message) {
                    try {
                        var cmd = (message || "").trim()
                        if (!cmd) return
                        console.log("[IPC RECEIVED] " + cmd)
                    if (cmd === "wallpaper" || cmd === "wallpaper-local") {
                        root.wallpaperSource = "local"
                        if (root.barMode === "nucleus" && root.nucleusHubItem && root.nucleusHubItem.hubOpen) {
                            root.nucleusHubItem.close()
                        }
                        root.toggleWallpaperPicker()
                    }
                    else if (cmd === "wallpaper-live") {
                        root.wallpaperSource = "live"
                        if (root.barMode === "nucleus" && root.nucleusHubItem && root.nucleusHubItem.hubOpen) {
                            root.nucleusHubItem.close()
                        }
                        root.openWallpaperPicker()
                    }
                    else if (cmd === "wallpaper-online") {
                        root.wallpaperSource = "wallhaven"
                        if (root.barMode === "nucleus" && root.nucleusHubItem && root.nucleusHubItem.hubOpen) {
                            root.nucleusHubItem.close()
                        }
                        root.openWallpaperPicker()
                    }
                    else if (cmd === "close-wallpaper") {
                        root.closeWallpaperPicker()
                    }
                    else if (cmd === "settings" || cmd === "toggle-settings" || cmd === "open-settings") {
                        root.toggleSettingsHub()
                    }
                    else if (cmd.startsWith("settings-tab ")) {
                        var tabName = cmd.replace(/^settings-tab\s+/, "").trim()
                        if (tabName.length > 0) root.settingsHubActiveTab = tabName.toLowerCase()
                        root.openSettingsHub()
                    }
                    else if (cmd === "close-settings") {
                        root.closeSettingsHub()
                    }
                    else if (cmd === "reload-blank-tile") {
                        if (root.nucleusHubItem && root.nucleusHubItem.reloadBlankTileConfig) {
                            root.nucleusHubItem.reloadBlankTileConfig()
                        }
                    }
                    else if (cmd.startsWith("freeze-start ")) {
                        var fpath = cmd.replace(/^freeze-start\s+/, "").trim()
                        root.screenshotFreezePath = fpath
                        root.screenshotFreezeActive = true
                    }
                    else if (cmd === "freeze-stop") {
                        root.screenshotFreezeActive = false
                        root.screenshotFreezePath = ""
                    }
                    else if (cmd.startsWith("apply-wallpaper ") || cmd.startsWith("set-wallpaper ") || (cmd.startsWith("wallpaper ") && cmd !== "wallpaper live" && cmd !== "wallpaper local" && cmd !== "wallpaper online")) {
                        var wpPath = cmd.replace(/^(apply-wallpaper|set-wallpaper|wallpaper)\s+/, "").trim()
                        if (wpPath.length > 0) {
                            if (root.wallpaperModItem) root.wallpaperModItem.applyNewWallpaper(wpPath)
                        }
                    }
                    else if (cmd === "launcher" || cmd === "toggle-launcher") {
                        if (root.barMode === "nucleus") {
                            if (cmd === "toggle-launcher") {
                                if (root.nucleusHubItem) root.nucleusHubItem.toggle()
                            } else {
                                if (root.nucleusHubItem) root.nucleusHubItem.toggleLauncher()
                            }
                        } else {
                            root.toggleDefaultLauncher()
                        }
                    }
                    else if (cmd === "close-launcher") {
                        if (root.barMode === "nucleus") {
                            if (root.nucleusHubItem) root.nucleusHubItem.close()
                        } else {
                            root.closeLauncher()
                            root.closeSpotlight()
                        }
                    }
                    else if (cmd === "spotlight" || cmd === "toggle-spotlight") {
                        if (root.nucleusHubItem && root.nucleusHubItem.hubOpen) {
                            root.nucleusHubItem.close()
                        }
                        root.toggleDefaultLauncher()
                    }
                    else if (cmd === "open-spotlight") {
                        if (root.nucleusHubItem && root.nucleusHubItem.hubOpen) {
                            root.nucleusHubItem.close()
                        }
                        if (root.launcherStyle === "launcher") root.openLauncher()
                        else root.openSpotlight()
                    }
                    else if (cmd === "close-spotlight") {
                        root.closeSpotlight()
                        root.closeLauncher()
                    }
                    else if (cmd.startsWith("focus-lobe ")) {
                        var lobeTarget = cmd.replace(/^focus-lobe\s+/, "").trim()
                        if (root.barMode === "nucleus" && root.nucleusHubItem) root.nucleusHubItem.focusLobe(lobeTarget)
                    }
                    else if (cmd === "toggle-resting-atom" || cmd === "nucleus toggle-resting-atom" || cmd === "toggle-resting") {
                        root.setRestingAtomVisible(!root.nucleusRestingVisible)
                    }
                    else if (cmd === "show-resting-atom" || cmd === "nucleus show-resting-atom") {
                        root.setRestingAtomVisible(true)
                    }
                    else if (cmd === "hide-resting-atom" || cmd === "remove-resting-atom" || cmd === "nucleus hide-resting-atom") {
                        root.setRestingAtomVisible(false)
                    }
                    else if (cmd === "test-hud-vol")
                        HudService.trigger("volume", 0.72, "72%", "Volume", "", false, "volume_up", "", 2500)
                    else if (cmd === "test-hud-bright")
                        HudService.trigger("brightness", 0.85, "85%", "Brightness", "", false, "light_mode", "", 2500)
                    else if (cmd === "test-hud-track")
                        HudService.trigger("track", 1.0, "Now Playing", "Do I Wanna Know?", "Arctic Monkeys", false, "music_note", "", 3500)
                    else if (cmd === "test-wp-transition")
                        root.startWallpaperTransition("Testing")
                    else if (cmd === "test-wp-finish")
                        root.finishWallpaperTransition()
                    else if (cmd === "focus" || cmd === "focus-hud" || cmd === "toggle-focus" || cmd === "toggle-focus-hud") {
                        root.toggleFocusHud()
                    }
                    else if (cmd === "open-focus" || cmd === "open-focus-hud") {
                        root.openFocusHud()
                    }
                    else if (cmd === "close-focus" || cmd === "close-focus-hud") {
                        root.closeFocusHud()
                    }
                    else if (cmd === "command-center" || cmd === "toggle-command-center" || cmd === "notch-command-center" || cmd === "radar" || cmd === "panel" || cmd === "toggle-panel") {
                        root.toggleCommandCenter()
                    }
                    else if (cmd === "open-command-center" || cmd === "open-radar" || cmd === "open-panel") {
                        root.openCommandCenter()
                    }
                    else if (cmd === "close-command-center" || cmd === "close-radar" || cmd === "close-panel") {
                        root.closeCommandCenter()
                    }
                    else if (cmd === "command-center-overview" || cmd === "radar-overview") {
                        root.openCommandCenter()
                        if (root.commandCenterItem) root.commandCenterItem.currentChannel = "overview"
                    }
                    else if (cmd === "github-uplink" || cmd === "github") {
                        root.openCommandCenter()
                        if (root.commandCenterItem) root.commandCenterItem.currentChannel = "github"
                    }
                    else if (cmd === "command-center-telemetry" || cmd === "telemetry" || cmd === "system-telemetry") {
                        root.openCommandCenter()
                        if (root.commandCenterItem) root.commandCenterItem.currentChannel = "telemetry"
                    }
                    else if (cmd === "telemetry-ram" || cmd === "telemetry-swap") {
                        root.openCommandCenter()
                        if (root.commandCenterItem) {
                            root.commandCenterItem.currentChannel = "telemetry"
                            root.commandCenterItem.telemetrySubMode = "ram"
                        }
                    }
                    else if (cmd === "telemetry-cpu") {
                        root.openCommandCenter()
                        if (root.commandCenterItem) {
                            root.commandCenterItem.currentChannel = "telemetry"
                            root.commandCenterItem.telemetrySubMode = "cpu"
                        }
                    }
                    else if (cmd === "spatial-canvas" || cmd === "toggle-spatial-canvas" || cmd === "spatial-overview" || cmd === "overview" || cmd === "toggle-overview") {
                        root.toggleSpatialCanvas()
                    }
                    else if (cmd === "open-spatial-canvas") {
                        root.openSpatialCanvas()
                    }
                    else if (cmd === "close-spatial-canvas" || cmd === "close-overview") {
                        root.closeSpatialCanvas()
                    }
                    else if (cmd === "spatial-wifi" || cmd === "spatial-bluetooth" || cmd === "spatial-network" || cmd === "spatial-connectivity") {
                        root.openSpatialCanvasNode(-1, 0)
                    }
                    else if (cmd === "spatial-files" || cmd === "spatial-file-browser") {
                        root.openSpatialCanvasNode(0, -1)
                    }
                    else if (cmd === "spatial-workspace" || cmd === "workspaces" || cmd === "workspace-blueprint") {
                        root.openSpatialCanvasNode(0, 0)
                    }
                    else if (cmd === "spatial-engine" || cmd === "spatial-wallpapers" || cmd === "spatial-settings" || cmd === "settings-node") {
                        root.openSpatialCanvasNode(1, 0)
                    }
                    else if (cmd === "spatial-media" || cmd === "spatial-session" || cmd === "spatial-power" || cmd === "spatial-notifications" || cmd === "notifications") {
                        root.openSpatialCanvasNode(0, 1)
                    }
                    else if (cmd.indexOf("spatial-node ") === 0) {
                        var parts = cmd.trim().split(/\s+/);
                        if (parts.length >= 3) {
                            var nx = parseInt(parts[1]);
                            var ny = parseInt(parts[2]);
                            root.openSpatialCanvasNode(nx, ny);
                        }
                    }
                    else if (cmd === "mixer")
                        root.toggleMixer()
                    else if (cmd === "brightness")
                        root.toggleBrightness()
                    else if (cmd === "battery")
                        root.toggleBattery()
                    else if (cmd === "wifi" || cmd === "connect open wifi") {
                        if (root.barMode === "nucleus") {
                            if (root.nucleusHubItem) root.nucleusHubItem.openWifiMode()
                        } else {
                            root.toggleWifi()
                        }
                    }
                    else if (cmd === "bt" || cmd === "bluetooth" || cmd === "connect open bluetooth") {
                        if (root.barMode === "nucleus") {
                            if (root.nucleusHubItem) root.nucleusHubItem.openBluetoothMode()
                        } else {
                            root.toggleBt()
                        }
                    }
                    else if (cmd === "connect close") {
                        if (root.barMode === "nucleus") {
                            if (root.nucleusHubItem) root.nucleusHubItem.closeConnectivityPicker()
                        }
                    }
                    else if (cmd === "tray")
                        root.toggleTray()
                    else if (cmd === "calendar")
                        root.toggleCalendar()
                    else if (cmd === "dashboard" || cmd === "center-dashboard")
                        root.toggleCenterDashboard()
                    else if (cmd === "open-dashboard" || cmd === "open-center-dashboard")
                        root.openCenterDashboard(true)
                    else if (cmd === "close-dashboard" || cmd === "close-center-dashboard")
                        root.closeCenterDashboard()
                    else if (cmd === "small-music")
                        root.toggleSmallMusic()
                    else if (cmd === "controls")
                        root.toggleControls()
                    else if (cmd === "notch-left" || cmd === "controls-prev") {
                        if (root.notchCenterItem) root.notchCenterItem.previousPage()
                    }
                    else if (cmd === "notch-right" || cmd === "controls-next") {
                        if (root.notchCenterItem) root.notchCenterItem.nextPage()
                    }
                    else if (cmd.indexOf("notch-page ") === 0) {
                        var pNum = parseInt(cmd.substring(11).trim())
                        if (!isNaN(pNum) && root.notchCenterItem) root.notchCenterItem.notchPage = pNum
                    }
                    else if (cmd === "controls wifi") {
                        root.openControls()
                        if (controlsItem) controlsItem.openWifiDetails()
                    }
                    else if (cmd === "controls bt" || cmd === "controls bluetooth") {
                        root.openControls()
                        if (controlsItem) controlsItem.openBtDetails()
                    }
                    else if (cmd === "controls audio" || cmd === "controls sound") {
                        root.openControls()
                        if (controlsItem) controlsItem.openAudioDetails()
                    }
                    else if (cmd === "controls-weather" || cmd === "weather") {
                        root.toggleControls()
                        if (controlsItem) {
                            controlsItem.mode = 2
                            controlsItem.weatherSubTab = 0
                        }
                    }
                    else if (cmd === "controls-forecast" || cmd === "forecast") {
                        root.toggleControls()
                        if (controlsItem) {
                            controlsItem.mode = 2
                            controlsItem.weatherSubTab = 1
                        }
                    }
                    else if (cmd === "controls-pomodoro" || cmd === "pomodoro") {
                        root.toggleControls()
                        if (controlsItem) {
                            controlsItem.mode = 1
                        }
                    }
                    else if (cmd === "controls volume up") {
                        if (root.barMode === "nucleus" && root.nucleusHubItem) {
                            root.nucleusHubItem.volumeAction("up")
                        } else {
                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                try {
                                    var s = Pipewire.defaultAudioSink.audio;
                                    s.muted = false;
                                    s.volume = Math.min(1.5, Math.round((s.volume + root.volumeStepVal) * 100) / 100);
                                } catch (e) {}
                            }
                            SysBackend.refreshVolume();
                        }
                    }
                    else if (cmd === "controls volume down") {
                        if (root.barMode === "nucleus" && root.nucleusHubItem) {
                            root.nucleusHubItem.volumeAction("down")
                        } else {
                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                try {
                                    var s = Pipewire.defaultAudioSink.audio;
                                    s.volume = Math.max(0.0, Math.round((s.volume - root.volumeStepVal) * 100) / 100);
                                } catch (e) {}
                            }
                            SysBackend.refreshVolume();
                        }
                    }
                    else if (cmd === "controls volume toggle-mute") {
                        if (root.barMode === "nucleus" && root.nucleusHubItem) {
                            root.nucleusHubItem.volumeAction("toggle-mute")
                        } else {
                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                try {
                                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted;
                                } catch (e) {}
                            }
                            SysBackend.refreshVolume();
                        }
                    }
                    else if (cmd === "controls volume open") {
                        if (root.barMode === "nucleus" && root.nucleusHubItem) root.nucleusHubItem.volumeAction("open")
                    }
                    else if (cmd === "controls brightness up") {
                        if (root.barMode === "nucleus" && root.nucleusHubItem) root.nucleusHubItem.brightnessAction("up")
                    }
                    else if (cmd === "controls brightness down") {
                        if (root.barMode === "nucleus" && root.nucleusHubItem) root.nucleusHubItem.brightnessAction("down")
                    }
                    else if (cmd === "controls brightness open") {
                        if (root.barMode === "nucleus" && root.nucleusHubItem) root.nucleusHubItem.brightnessAction("open")
                    }
                    else if (cmd.startsWith("set-bar-mode ")) {
                        const m = cmd.substring(13).trim()
                        if (m) root.switchBarMode(m)
                    }
                    else if (cmd.startsWith("set-opacity ")) {
                        const val = parseFloat(cmd.substring(12))
                        if (!isNaN(val)) {
                            root.shellOpacity = Math.max(0.10, Math.min(1.0, val))
                            root.pillOpacity = root.shellOpacity
                            root.notchOpacity = root.shellOpacity
                            root.minimalOpacity = root.shellOpacity
                            Theme.shellOpacity = root.shellOpacity
                            Theme.reload()
                        }
                    }
                    else if (cmd.startsWith("set-blur ")) {
                        const val = parseInt(cmd.substring(9))
                        root.shellBlur = (val === 1)
                        root.pillBlur = root.shellBlur
                        root.notchBlur = root.shellBlur
                        root.minimalBlur = root.shellBlur
                    }
                    else if (cmd === "reload-config" || cmd === "apply-settings" || cmd === "reload-lock-config" || cmd === "theme-reload") {
                        root.applyBarPos(barPosFile.text())
                        root.reloadBarMode()
                        Theme.reloadShellOpacity()
                        Theme.reload(true)
                        root.reloadLauncherConfig()
                        LockState.reloadConfig()
                    }
                    else if (cmd.startsWith("set-cairo-mode ") || cmd.startsWith("cairo-mode ")) {
                        var cairoArg = cmd.replace(/^(set-cairo-mode|cairo-mode)\s+/, "").trim().toLowerCase()
                        var cairoEn = (cairoArg === "true" || cairoArg === "1" || cairoArg === "on")
                        LockState.cairoModeEnabled = cairoEn
                        console.log("[IPC] cairoModeEnabled updated to: " + LockState.cairoModeEnabled)
                    }
                    else if (cmd.startsWith("set-cairo-romanize ") || cmd.startsWith("cairo-romanize ")) {
                        var romArg = cmd.replace(/^(set-cairo-romanize|cairo-romanize)\s+/, "").trim().toLowerCase()
                        var romEn = (romArg === "true" || romArg === "1" || romArg === "on")
                        LockState.cairoRomanizeLyrics = romEn
                        console.log("[IPC] cairoRomanizeLyrics updated to: " + LockState.cairoRomanizeLyrics)
                        if (CairoLyricsService && CairoLyricsService.reloadLyrics) {
                            CairoLyricsService.reloadLyrics()
                        }
                    }
                    else if (cmd === "reload-cairo-lyrics" || cmd === "cairo-reload-lyrics") {
                        if (CairoLyricsService && CairoLyricsService.reloadLyrics) {
                            CairoLyricsService.reloadLyrics()
                        }
                    }
                    else if (cmd === "controls-mode-todo" || cmd === "controls-mode-pomodoro" || cmd === "controls-pomodoro" || cmd === "pomodoro") {
                        root.controlsPinned = true
                        root.controlsVisible = true
                        controlsItem.mode = 1
                    } else if (cmd === "controls-mode-timer" || cmd === "controls-mode-weather" || cmd === "controls-weather" || cmd === "weather") {
                        root.controlsPinned = true
                        root.controlsVisible = true
                        controlsItem.mode = 2
                    } else if (cmd === "controls-mode-quick" || cmd === "controls-mode-controls") {
                        root.controlsPinned = true
                        root.controlsVisible = true
                        controlsItem.mode = 0
                    } else if (cmd === "controls-wifi") {
                        root.controlsPinned = true
                        root.controlsVisible = true
                        controlsItem.mode = 0
                        controlsItem.wifiPopupOpen = !controlsItem.wifiPopupOpen
                        if (controlsItem.wifiPopupOpen) controlsItem.btPopupOpen = false
                    } else if (cmd === "controls-bt") {
                        root.controlsPinned = true
                        root.controlsVisible = true
                        controlsItem.mode = 0
                        controlsItem.btPopupOpen = !controlsItem.btPopupOpen
                        if (controlsItem.btPopupOpen) controlsItem.wifiPopupOpen = false
                    } else if (cmd === "controls-notifs") {
                        root.controlsPinned = true
                        root.controlsVisible = true
                        controlsItem.mode = 0
                        controlsItem.scrollToNotifs()
                    } else if (cmd === "controls-notif-next") {
                        controlsItem.selectNextNotif()
                    } else if (cmd === "controls-notif-prev") {
                        controlsItem.selectPrevNotif()
                    } else if (cmd === "controls-notif-enter") {
                        controlsItem.activateSelectedNotif()
                    } else if (cmd === "controls-mode-timer" || cmd === "timer") {
                        root.controlsPinned = true
                        root.controlsVisible = true
                        controlsItem.mode = 2
                    }
                    else if (cmd === "battery")
                        root.toggleBattery()
                    else if (cmd === "mixer")
                        root.toggleMixer()
                    else if (cmd === "brightness")
                        root.toggleBrightness()
                    else if (cmd === "wifi")
                        root.toggleWifi()
                    else if (cmd === "bt" || cmd === "bluetooth")
                        root.toggleBt()
                    else if (cmd === "power" || cmd === "powermenu" || cmd.startsWith("power ")) {
                        const parts = cmd.split(/\s+/)
                        const sub = parts[1] || "open"
                        const hasConfirm = parts.includes("--confirm")
                        console.log("[IPC power] sub=" + sub + " confirm=" + hasConfirm + " barMode=" + root.barMode)
                        if (sub === "open") {
                            if (root.barMode === "nucleus" && root.nucleusHubItem) {
                                root.nucleusHubItem.openPowerMode()
                            } else {
                                root.openPower()
                            }
                        } else if (sub === "close") {
                            if (root.barMode === "nucleus" && root.nucleusHubItem) {
                                root.nucleusHubItem.close()
                            } else {
                                root.closePower()
                            }
                        } else if (sub === "lock") {
                            if (root.barMode === "nucleus" && root.nucleusHubItem) {
                                root.nucleusHubItem.triggerPowerAction("lock")
                            } else {
                                root.closePower()
                                sessionLock.lock()
                            }
                        } else if (sub === "sleep") {
                            if (root.barMode === "nucleus" && root.nucleusHubItem) {
                                root.nucleusHubItem.triggerPowerAction("sleep")
                            } else {
                                root.closePower()
                                Quickshell.execDetached(["systemctl", "suspend"])
                            }
                        } else if (sub === "restart" || sub === "reboot") {
                            if (hasConfirm) {
                                if (root.barMode === "nucleus" && root.nucleusHubItem) {
                                    root.nucleusHubItem.triggerPowerAction("restart")
                                } else {
                                    root.closePower()
                                    Quickshell.execDetached(["systemctl", "reboot"])
                                }
                            } else {
                                console.log("[IPC power restart] requires --confirm")
                                if (root.barMode === "nucleus" && root.nucleusHubItem) {
                                    root.nucleusHubItem.openPowerMode()
                                }
                            }
                        } else if (sub === "shutdown" || sub === "poweroff") {
                            if (hasConfirm) {
                                if (root.barMode === "nucleus" && root.nucleusHubItem) {
                                    root.nucleusHubItem.triggerPowerAction("shutdown")
                                } else {
                                    root.closePower()
                                    Quickshell.execDetached(["systemctl", "poweroff"])
                                }
                            } else {
                                console.log("[IPC power shutdown] requires --confirm")
                                if (root.barMode === "nucleus" && root.nucleusHubItem) {
                                    root.nucleusHubItem.openPowerMode()
                                }
                            }
                        }
                    }
                    else if (cmd === "tray" || cmd === "toggle-tray")
                        root.toggleTray()
                    else if (cmd === "close-power")
                        root.closePower()
                    else if (cmd === "lock") {
                        root.closePower()
                        sessionLock.lock()
                    }
                    else if (cmd === "lock-test") {
                        root.closePower()
                        LockTransition.testLock()
                    }
                    else if (cmd === "unlock") {
                        sessionLock.unlock()
                    }
                    else if (cmd === "unlock-test") {
                        LockTransition.testUnlock()
                    }
                    else if (cmd === "notifications" || cmd === "notif")
                        root.toggleNotif()
                    else if (cmd === "toggle-dnd" || cmd === "dnd" || cmd === "dnd-toggle")
                        NotificationService.toggleDnd()
                    else if (cmd === "overview" || cmd === "toggle-overview")
                        root.toggleOverview()
                    else if (cmd === "close-overview")
                        root.closeOverview()
                    else if (cmd === "theme-reload" || cmd === "reload-theme")
                        Theme.reload(true)
                    else if (cmd === "toggle-dark" || cmd === "toggle-theme" || cmd === "theme-toggle") {
                        var nextMode = Theme.isDark ? "light" : "dark"
                        Quickshell.execDetached(["python3", (Quickshell.env("HOME") || "") + "/.config/carbon/scripts/theme-mk.py", "--mode", nextMode])
                    }
                    else if (cmd === "dark-mode" || cmd === "mode-dark") {
                        Quickshell.execDetached(["python3", (Quickshell.env("HOME") || "") + "/.config/carbon/scripts/theme-mk.py", "--mode", "dark"])
                    }
                    else if (cmd === "light-mode" || cmd === "mode-light") {
                        Quickshell.execDetached(["python3", (Quickshell.env("HOME") || "") + "/.config/carbon/scripts/theme-mk.py", "--mode", "light"])
                    }
                    else if (cmd === "atomic" || cmd === "mode-atomic" || cmd === "toggle-atomic") {
                        if (root.barMode === "atomic") root.switchBarMode("notch")
                        else root.switchBarMode("atomic")
                    }
                    else if (cmd === "shard" || cmd === "mode-shard" || cmd === "toggle-shard") {
                        if (root.barMode === "shard") root.switchBarMode("notch")
                        else root.switchBarMode("shard")
                    }
                    else if (cmd === "bloom" || cmd === "mode-bloom" || cmd === "toggle-bloom") {
                        if (root.barMode === "bloom") root.switchBarMode("notch")
                        else root.switchBarMode("bloom")
                    }
                    else if (cmd === "nucleus transition" || cmd === "vanish-transition" || cmd === "transition-vanish" || cmd === "woosh") {
                        root.startNucleusTransition(true)
                    }
                    else if (cmd === "nucleus" || cmd === "mode-nucleus" || cmd === "toggle-nucleus") {
                        if (root.barMode === "nucleus") root.switchBarMode("notch")
                        else root.switchBarMode("nucleus")
                    }
                    else if (cmd === "nucleus toggle") {
                        if (root.barMode !== "nucleus") root.switchBarMode("nucleus")
                        if (root.nucleusHubItem) root.nucleusHubItem.toggle()
                    }
                    else if (cmd.startsWith("nucleus focus ")) {
                        if (root.barMode !== "nucleus") root.switchBarMode("nucleus")
                        var lobeTarget = cmd.substring("nucleus focus ".length).trim()
                        if (root.nucleusHubItem) root.nucleusHubItem.focusLobe(lobeTarget)
                    }
                    else if (cmd === "nucleus wallpapers") {
                        root.wallpaperSource = "local"
                        root.toggleWallpaperPicker()
                    }
                    else if (cmd === "nucleus launcher") {
                        if (root.barMode !== "nucleus") root.switchBarMode("nucleus")
                        if (root.nucleusHubItem) root.nucleusHubItem.toggleLauncher()
                    }
                    else if (cmd === "nucleus lyrics" || cmd === "nucleus lyrics toggle" || cmd === "nucleus toggle-lyrics") {
                        if (root.barMode !== "nucleus") root.switchBarMode("nucleus")
                        if (root.nucleusHubItem) root.nucleusHubItem.toggleLyrics()
                    }
                    else if (cmd === "nucleus wifi" || cmd === "nucleus wifi toggle") {
                        if (root.barMode !== "nucleus") root.switchBarMode("nucleus")
                        if (root.nucleusHubItem) root.nucleusHubItem.openWifiMode()
                    }
                    else if (cmd === "nucleus bluetooth" || cmd === "nucleus bt" || cmd === "nucleus bluetooth toggle") {
                        if (root.barMode !== "nucleus") root.switchBarMode("nucleus")
                        if (root.nucleusHubItem) root.nucleusHubItem.openBluetoothMode()
                    }
                    else if (cmd === "nucleus notif" || cmd === "nucleus notifications" || cmd === "nucleus toggle-notif" || cmd === "nucleus alert" || cmd === "nucleus alerts") {
                        if (root.barMode !== "nucleus") root.switchBarMode("nucleus")
                        if (root.nucleusHubItem) root.nucleusHubItem.openNotificationPanel()
                    }
                    else if (cmd === "nucleus notif-clear" || cmd === "nucleus clear-notif" || cmd === "nucleus clear-all") {
                        if (root.barMode !== "nucleus") root.switchBarMode("nucleus")
                        if (root.nucleusHubItem && root.nucleusHubItem.clearNotifications) {
                            root.nucleusHubItem.clearNotifications()
                        }
                    }
                    else if (cmd.startsWith("nucleus notif-tab ") || cmd.startsWith("nucleus tab ")) {
                        var tIdx = parseInt(cmd.replace(/^(nucleus notif-tab|nucleus tab)\s+/, "").trim(), 10)
                        if (!isNaN(tIdx) && root.nucleusHubItem && root.nucleusHubItem.setNotificationTab) {
                            root.nucleusHubItem.setNotificationTab(tIdx)
                        }
                    }
                    else if (cmd === "calendar" || cmd === "center-dashboard" || cmd === "center" || cmd === "time-weather" || cmd === "toggle-dashboard" || cmd === "dashboard")
                        root.toggleCenterDashboard()
                    else if (cmd === "calendar-events") {
                        root.closeAllPopupsExcept("centerDashboard")
                        root.centerDashboardPinned = true
                        root.centerDashboardOpen = true
                        if (centerDashboardItem) {
                            centerDashboardItem.calendarViewMode = "events"
                            centerDashboardItem.selectedDay = 14
                        }
                    }
                    else if (cmd === "calendar-form") {
                        root.closeAllPopupsExcept("centerDashboard")
                        root.centerDashboardPinned = true
                        root.centerDashboardOpen = true
                        if (centerDashboardItem) {
                            centerDashboardItem.calendarViewMode = "events"
                            centerDashboardItem.selectedDay = 14
                            centerDashboardItem.eventFormMode = true
                        }
                    }
                    else if (cmd === "lyrics" || cmd === "toggle-lyrics") {
                        root.closeAllPopupsExcept("centerDashboard")
                        root.centerDashboardPinned = true
                        root.centerDashboardOpen = true
                        if (centerDashboardItem && centerDashboardItem.rightColItem) {
                            centerDashboardItem.rightColItem.viewMode = (centerDashboardItem.rightColItem.viewMode === "lyrics" ? "weather" : "lyrics")
                        }
                    }
                    else if (cmd === "music" || cmd === "music-toggle")
                        root.toggleMusic()
                    else if (cmd === "music-open") {
                        root.musicPinned = true
                        root.openMusic()
                    }
                    else if (cmd === "music-close") {
                        root.musicPinned = false
                        root.closeMusic()
                    }
                    else if (cmd === "toggle-small-music" || cmd === "music-small") {
                        root.toggleSmallMusic()
                    }
                    else if (cmd === "close-small-music") {
                        root.smallMusicOpen = false
                    }
                    else if (cmd.startsWith("bar-mode ") || cmd.startsWith("set-bar-mode ") || cmd.startsWith("mode ") || cmd.startsWith("switch-mode ") || cmd.startsWith("bar_mode ") || cmd.startsWith("set_bar_mode ")) {
                        var m = cmd.replace(/^(bar-mode|set-bar-mode|mode|switch-mode|bar_mode|set_bar_mode)\s+/, "").trim().toLowerCase()
                        root.switchBarMode(m)
                    }
                    else if (cmd === "notch" || cmd === "pill" || cmd === "minimal" || cmd === "minimal_notch" || cmd === "vanish" || cmd === "mode-notch" || cmd === "mode-pill" || cmd === "mode-minimal" || cmd === "mode-minimal_notch") {
                        var m = cmd.replace(/^mode-/, "")
                        if (m === "minimal") m = "minimal_notch"
                        root.switchBarMode(m)
                    }
                    else if (cmd.startsWith("island-style ")) {
                        var is = cmd.substring(13).trim()
                        root.switchIslandStyle(is)
                    }
                    else if (cmd.startsWith("island-persistent ")) {
                        var ip = cmd.substring(18).trim().toLowerCase()
                        root.switchIslandPersistent(ip === "true" || ip === "1")
                    }
                    else if (cmd.startsWith("island-page ")) {
                        var pg = parseInt(cmd.substring(12).trim(), 10)
                        if (!isNaN(pg)) root.islandPage = pg
                    }
                    else if (cmd === "island-next-page") {
                        root.islandPage = (root.islandPage + 1) % 3
                    }
                    else if (cmd === "island-prev-page") {
                        root.islandPage = (root.islandPage - 1 + 3) % 3
                    }
                    else if (cmd === "reload-bar-mode")
                        root.reloadBarMode()
                    else if (cmd === "reload-bar-pos") {
                        barPosFile.reload()
                        root.applyBarPos(barPosFile.text())
                    }
                    else if (cmd === "lock") {
                        sessionLock.lock()
                    }
                    else if (cmd === "lock-test") {
                        LockTransition.testLock()
                    }
                    else if (cmd === "unlock") {
                        sessionLock.unlock()
                    }
                    else if (cmd === "unlock-test") {
                        LockTransition.testUnlock()
                    }
                    else if (cmd === "lock-test-notif") {
                        sessionLock.testNotif()
                    }
                    else if (cmd === "lock-test-notif-center") {
                        sessionLock.testNotifCenter()
                    }
                    else if (cmd === "lock-test-notif-clear") {
                        sessionLock.testNotifClear()
                    }
                    else if (cmd === "desktop-notif-clear") {
                        if (notificationServer && notificationServer.trackedNotifications && notificationServer.trackedNotifications.values) {
                            const list = [...notificationServer.trackedNotifications.values]
                            for (let i = 0; i < list.length; i++) {
                                if (list[i] && typeof list[i].dismiss === "function") list[i].dismiss()
                            }
                        }
                    }
                    else if (cmd.startsWith("tide ")) {
                        var tcmd = cmd.substring(5).trim()
                        if (tcmd === "showClock") root.forFocusedTideWindow((w) => w.showClockWindow())
                        else if (tcmd === "showTimer") root.forFocusedTideWindow((w) => w.showTimerWindow())
                        else if (tcmd === "showCustom") root.forFocusedTideWindow((w) => w.showCustomInfoWindow())
                        else if (tcmd === "showLyrics") root.forFocusedTideWindow((w) => w.showLyricsWindow())
                        else if (tcmd === "swipeRight") root.forFocusedTideWindow((w) => w.swipeRightWindow())
                        else if (tcmd === "swipeLeft") root.forFocusedTideWindow((w) => w.swipeLeftWindow())
                        else if (tcmd === "togglePlayer") {
                            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                                root.forFocusedTideWindow((w) => w.togglePlayerWindow())
                            else
                                root.toggleMusic()
                        }
                        else if (tcmd === "toggleControlCenter") {
                            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                                root.forFocusedTideWindow((w) => w.toggleControlCenterWindow())
                            else
                                root.toggleControls()
                        }
                        else if (tcmd === "togglePowerMenu") {
                            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                                root.forFocusedTideWindow((w) => w.togglePowerMenuWindow())
                            else
                                root.openPower()
                        }
                        else if (tcmd === "toggleNotificationCenter") {
                            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                                root.forFocusedTideWindow((w) => w.toggleNotificationCenterWindow())
                            else
                                root.toggleNotif()
                        }
                        else if (tcmd === "toggleWallpaperPicker") {
                            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                                root.forFocusedTideWindow((w) => w.toggleWallpaperPickerWindow())
                            else
                                root.toggleWallpaperPicker()
                        }
                        else if (tcmd === "toggleApplicationLauncher") {
                            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                                root.forFocusedTideWindow((w) => w.toggleApplicationLauncherWindow())
                            else
                                root.toggleDefaultLauncher()
                        }
                    }
                    else if (cmd.startsWith("island ")) {
                        var icmd = cmd.substring(7).trim()
                        if (icmd === "toggle") root.toggleIslandAll()
                        else if (icmd === "show" || icmd === "open" || icmd === "reveal") root.showIslandAll()
                        else if (icmd === "hide") root.hideIslandAll()
                    }
                } catch (e) {
                    console.warn("[IPC ERROR] Exception in command handler:", e)
                }
            }
        }
    }
}
}

    /* Tide Island IPC */
    IpcHandler {
        target: "overview"

        function toggle() {
            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                root.toggleOverviewAll();
            else
                root.toggleOverview();
        }

        function open() {
            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                root.openOverviewAll();
            else
                root.openOverview();
        }

        function close() {
            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                root.closeOverviewAll();
            else
                root.closeOverview();
        }

        function refreshWallpaperCache() {
            root.refreshOverviewWallpaperCaches();
        }
    }

    IpcHandler {
        target: "island"

        function show() {
            root.showIslandAll();
        }

        function open() {
            root.showIslandAll();
        }

        function reveal() {
            root.showIslandAll();
        }

        function hide() {
            root.hideIslandAll();
        }

        function toggle() {
            root.toggleIslandAll();
        }

        function enableAutoHide() {
            root.islandAutoHideRuntimeEnabled = true;
            root.refreshIslandAutoHideAll();
        }

        function disableAutoHide() {
            root.islandAutoHideRuntimeEnabled = false;
            root.showIslandAll();
        }

        function toggleNotch() {
            root.toggleNotchAll();
        }

        function enableNotch() {
            root.setNotchModeAll(true);
        }

        function disableNotch() {
            root.setNotchModeAll(false);
        }

        function reloadConfig() {
            root.forEachTideWindow((w) => {
                if (w && w.reloadExtraConfig)
                    w.reloadExtraConfig();
            });
        }
    }

    IpcHandler {
        target: "tide"

        function toggle() {
            root.toggleIslandAll();
        }

        function toggleIsland() {
            root.toggleIslandAll();
        }

        function hide() {
            root.hideIslandAll();
        }

        function show() {
            root.showIslandAll();
        }

        function showClock() {
            root.forFocusedTideWindow((w) => w.showClockWindow());
        }

        function showTimer() {
            root.forFocusedTideWindow((w) => w.showTimerWindow());
        }

        function showCustom() {
            root.forFocusedTideWindow((w) => w.showCustomInfoWindow());
        }

        function showLyrics() {
            root.forFocusedTideWindow((w) => w.showLyricsWindow());
        }

        function swipeRight() {
            root.forFocusedTideWindow((w) => w.swipeRightWindow());
        }

        function swipeLeft() {
            root.forFocusedTideWindow((w) => w.swipeLeftWindow());
        }

        function togglePlayer() {
            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                root.forFocusedTideWindow((w) => w.togglePlayerWindow());
            else
                root.toggleMusic();
        }

        function toggleControlCenter() {
            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                root.forFocusedTideWindow((w) => w.toggleControlCenterWindow());
            else
                root.toggleControls();
        }

        function togglePowerMenu() {
            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                root.forFocusedTideWindow((w) => w.togglePowerMenuWindow());
            else
                root.openPower();
        }

        function toggleNotificationCenter() {
            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                root.forFocusedTideWindow((w) => w.toggleNotificationCenterWindow());
            else
                root.toggleNotif();
        }

        function toggleWallpaperPicker() {
            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                root.forFocusedTideWindow((w) => w.toggleWallpaperPickerWindow());
            else
                root.toggleWallpaperPicker();
        }

        function toggleApplicationLauncher() {
            if (root.barMode === "minimal" || root.barMode === "minimal_notch")
                root.forFocusedTideWindow((w) => w.toggleApplicationLauncherWindow());
            else
                root.toggleDefaultLauncher();
        }

        function toggleFileShelf() {
            // Disabled per user request
        }
    }

    /* Focus HUD (Hyper-Tunnel) IPC */
    IpcHandler {
        target: "focus"

        function toggle() {
            root.toggleFocusHud();
        }

        function open() {
            root.openFocusHud();
        }
        function close() {
            root.closeFocusHud();
        }

        function reveal() {
            if (root.focusHudItem) root.focusHudItem.isRevealed = true;
        }

        function conceal() {
            if (root.focusHudItem) root.focusHudItem.isRevealed = false;
        }
    }

    IpcHandler {
        target: "focus-hud"

        function toggle() {
            root.toggleFocusHud();
        }

        function open() {
            root.openFocusHud();
        }

        function close() {
            root.closeFocusHud();
        }
    }

    /* Lock Screen */
    LockScreen {
        id: sessionLock
        notificationServer: notificationServer
    }

    GlobalShortcut {
        name: "lock"
        onPressed: sessionLock.lock()
    }

    /* Lock Transition */
    Variants {
        model: (LockTransition.phase === "post_unlock" || (LockTransition.phase === "unlocking" && LockTransition.u >= 800.0) || (!LockTransition.lockSync && LockTransition.phase === "locking")) ? Quickshell.screens : []

        PanelWindow {
            id: lockOverlayWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-lock-transition"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (!LockTransition.lockSync && LockTransition.phase === "locking" && LockTransition.t < 780.0) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors { top: true; bottom: true; left: true; right: true }

            visible: LockTransition.phase === "post_unlock" || (LockTransition.phase === "unlocking" && LockTransition.u >= 800.0) || (!LockTransition.lockSync && LockTransition.phase === "locking")

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
            }

            LockTransitionOverlay {
                anchors.fill: parent
            }
        }
    }

    /* Cairo Mode */
    Variants {
        model: (LockState.isLocked && ShellConfig.cairoModeEnabled) ? Quickshell.screens : []

        PanelWindow {
            id: cairoLockWindow
            required property var modelData

            screen: modelData
            color: "#000000"
            WlrLayershell.namespace: "carbon-cairo-lock"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (LockState.isLocked && ShellConfig.cairoModeEnabled) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors { top: true; bottom: true; left: true; right: true }

            visible: LockState.isLocked && ShellConfig.cairoModeEnabled

            Item {
                anchors.fill: parent
                focus: true

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        if (cairoStageLoader.item && typeof cairoStageLoader.item.triggerUnlock === "function") {
                            event.accepted = true
                            cairoStageLoader.item.triggerUnlock()
                        }
                    }
                }

                // Zero-RAM Lazy Mounting: destroyed completely when unlocked or disabled
                Loader {
                    id: cairoStageLoader
                    anchors.fill: parent
                    active: LockState.isLocked && ShellConfig.cairoModeEnabled
                    asynchronous: true
                    focus: true
                    source: "modules/lock/CairoStage.qml"
                    onLoaded: {
                        if (item) item.forceActiveFocus()
                    }
                }
            }
        }
    }

    /* Wallpaper: bottom-most fullscreen image, updated live by WallpaperMod */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wallpaperWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-wallpaper"
            WlrLayershell.layer: WlrLayer.Background
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            WallpaperMod {
                id: wpInstance
                width: wallpaperWindow.width
                height: wallpaperWindow.height
                anchors.fill: parent

                Component.onCompleted: {
                    if (!root.wallpaperModItem) root.wallpaperModItem = wpInstance
                }

                Connections {
                    target: root
                    function onTriggerWallpaperTransition() {
                        wpInstance.retriggerTransition()
                    }
                }
            }
        }
    }

    /* Audio Border Daemon */
    Process {
        id: audioBorderDaemon
        command: ["python3", root.carbonConfigDir + "/scripts/audio-border.py"]
        running: (root.barMode !== "minimal" && root.barMode !== "minimal_notch")
    }

    /* Edge Reservation */
    readonly property bool hasTopReserve: false
    readonly property bool hasBottomReserve: (root.barMode === "notch" || root.barMode === "atomic" || root.barMode === "shard" || root.barMode === "bloom" || root.barMode === "nucleus" || root.barMode === "minimal" || root.barMode === "minimal_notch") ? false :
        (root.barMode === "pill" ? (root.mainBarEdge === "bottom") : (root.mainBarEdge === "bottom" || root.musicBarEdge === "bottom"))
    readonly property bool hasLeftReserve: false
    readonly property bool hasRightReserve: false

    readonly property int topReserveHeight: 0
    readonly property int bottomReserveHeight: root.hasBottomReserve ? (root.barHeight + (root.barMode === "pill" ? 10 : (root.islandStyle === "notch" ? 4 : 8))) : 0
    readonly property int leftReserveWidth: root.hasLeftReserve ? 38 : 0
    readonly property int rightReserveWidth: root.hasRightReserve ? 38 : 0

    /* Top Edge Reserve */
    Variants {
        model: root.hasTopReserve ? Quickshell.screens : []

        PanelWindow {
            id: reserveTopWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-reserve-top"
            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.topReserveHeight
            anchors { top: true; left: true; right: true }
            implicitHeight: root.topReserveHeight
            visible: root.hasTopReserve

            mask: Region {}
        }
    }

    /* Bottom Edge Reserve */
    Variants {
        model: root.hasBottomReserve ? Quickshell.screens : []

        PanelWindow {
            id: reserveBottomWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-reserve-bottom"
            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.bottomReserveHeight
            anchors { bottom: true; left: true; right: true }
            implicitHeight: root.bottomReserveHeight
            visible: root.hasBottomReserve

            mask: Region {}
        }
    }

    /* Left Edge Reserve */
    Variants {
        model: root.hasLeftReserve ? Quickshell.screens : []

        PanelWindow {
            id: reserveLeftWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-reserve-left"
            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.leftReserveWidth
            anchors { left: true; top: true; bottom: true }
            implicitWidth: root.leftReserveWidth
            visible: root.hasLeftReserve

            mask: Region {}
        }
    }

    /* Right Edge Reserve */
    Variants {
        model: root.hasRightReserve ? Quickshell.screens : []

        PanelWindow {
            id: reserveRightWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-reserve-right"
            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.rightReserveWidth
            anchors { right: true; top: true; bottom: true }
            implicitWidth: root.rightReserveWidth
            visible: root.hasRightReserve

            mask: Region {}
        }
    }

    /* Pill Mode */
    Variants {
        model: root.barMode === "pill_qml" ? Quickshell.screens : []

        PanelWindow {
            id: pillFullBarWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bar-pill-full"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            aboveWindows: true
            anchors {
                top: root.mainBarEdge !== "bottom"
                bottom: root.mainBarEdge === "bottom"
                left: true
                right: true
            }
            margins {
                top: root.mainBarEdge !== "bottom" ? 8 : 0
                bottom: root.mainBarEdge === "bottom" ? 8 : 0
                left: 12
                right: 12
            }

            implicitHeight: root.pillHeight
            visible: false

            Loader {
                id: pillFullBarLoader
                anchors.fill: parent
                active: false && root.mainBarEdge !== "left" && root.mainBarEdge !== "right"
                sourceComponent: Rectangle {
                    id: pillFullCapsule
                    anchors.fill: parent
                    radius: root.pillHeight / 2
                    color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.pillOpacity)
                    border.color: Theme.outline
                    border.width: 1

                    Item {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8

                        BarLeft {
                            id: pillLeftItem
                            visible: false
                            width: 0
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            showBackground: false
                            vertical: false
                            onOpenLauncher: root.toggleDefaultLauncher()
                        }

                        /* Center */
                        BarCenter {
                            id: pillCenterItem
                            anchors.centerIn: parent
                            barContent: root.musicBarContent
                            showVinylDisc: root.showVinylDisc
                            showEqualizer: root.showEqualizer
                            onOpenCenterDashboard: root.openCenterDashboard()
                            onCloseCenterDashboard: centerDashboardLeaveTimer.restart()
                            onToggleCenterDashboard: root.toggleCenterDashboard()
                            onToggleMusic: root.toggleCenterDashboard()
                            onOpenMusic: root.openCenterDashboard()
                            onToggleControls: root.toggleCenterDashboard()
                        }

                        /* Right */
                        BarRight {
                            id: pillRightItem
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            showBackground: false
                            vertical: false
                            anchorWindow: pillFullBarWindow
                            notifCount: (notificationServer && notificationServer.trackedNotifications) ? notificationServer.trackedNotifications.values.length : 0
                            onOpenMixer: root.openMixer()
                            onCloseMixer: mixerLeaveTimer.restart()
                            onToggleMixer: root.toggleMixer()
                            onOpenBrightness: root.openBrightness()
                            onCloseBrightness: brightnessLeaveTimer.restart()
                            onToggleBrightness: root.toggleBrightness()
                            onOpenBattery: root.openBattery()
                            onCloseBattery: batteryLeaveTimer.restart()
                            onToggleBattery: root.toggleBattery()
                            onOpenTray: root.openTray()
                            onCloseTray: trayLeaveTimer.restart()
                            onToggleTray: root.toggleTray()
                            onToggleNotif: root.toggleNotif()
                            onToggleControls: root.toggleControls()
                            onOpenPower: root.openPower()
                        }
                    }
                }
            }
        }
    }

    /* Pill Mode Vertical */
    Variants {
        model: root.barMode === "pill_qml" ? Quickshell.screens : []

        PanelWindow {
            id: pillFullVerticalBarWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bar-pill-vert"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: true
                bottom: true
                left: root.mainBarEdge === "left"
                right: root.mainBarEdge === "right"
            }
            margins {
                top: 8
                bottom: 8
                left: root.mainBarEdge === "left" ? 8 : 0
                right: root.mainBarEdge === "right" ? 8 : 0
            }

            implicitWidth: 38
            visible: false

            Rectangle {
                id: pillFullVertCapsule
                anchors.fill: parent
                radius: 19
                color: Theme.bg
                border.color: Theme.outline
                border.width: 1

                Item {
                    anchors.fill: parent
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8

                    BarLeft {
                        id: pillVertLeftItem
                        visible: false
                        height: 0
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        showBackground: false
                        vertical: true
                        onOpenLauncher: root.openLauncher()
                    }

                    /* Center */
                    Item {
                        anchors.centerIn: parent
                        width: 32
                        height: 52

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: Theme.bgAlt
                                border.color: Theme.accent
                                border.width: 1.5
                                anchors.horizontalCenter: parent.horizontalCenter
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: root.mprisArtUrl
                                    sourceSize: Qt.size(44, 44)
                                    fillMode: Image.PreserveAspectCrop
                                    visible: root.mprisHasTrack && root.mprisArtUrl.length > 0
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "music_note"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 14
                                    color: Theme.accent
                                    visible: !root.mprisHasTrack || root.mprisArtUrl.length === 0
                                }
                            }

                            Text {
                                text: {
                                    let d = new Date()
                                    let h = d.getHours() % 12
                                    if (h === 0) h = 12
                                    let m = d.getMinutes()
                                    return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
                                }
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(9)
                                font.weight: Font.Bold
                                color: Theme.fg
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: false
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleMusic()
                        }
                    }

                    /* Bottom */
                    BarRight {
                        id: pillVertRightItem
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        showBackground: false
                        vertical: true
                        anchorWindow: pillFullVerticalBarWindow
                        notifCount: (notificationServer && notificationServer.trackedNotifications) ? notificationServer.trackedNotifications.values.length : 0
                        onOpenMixer: root.openMixer()
                        onCloseMixer: mixerLeaveTimer.restart()
                        onToggleMixer: root.toggleMixer()
                        onOpenBrightness: root.openBrightness()
                        onCloseBrightness: brightnessLeaveTimer.restart()
                        onToggleBrightness: root.toggleBrightness()
                        onOpenBattery: root.openBattery()
                        onCloseBattery: batteryLeaveTimer.restart()
                        onToggleBattery: root.toggleBattery()
                        onOpenTray: root.openTray()
                        onCloseTray: trayLeaveTimer.restart()
                        onToggleTray: root.toggleTray()
                        onToggleNotif: root.toggleNotif()
                        onToggleControls: root.toggleControls()
                        onOpenPower: root.openPower()
                    }
                }
            }
        }
    }

    /* Minimal Mode */
    Variants {
        model: root.barMode === "minimal_old" ? Quickshell.screens : []

        PanelWindow {
            id: minimalIslandWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bar-minimal"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: root.islandPersistent ? ExclusionMode.Normal : ExclusionMode.Ignore
            exclusiveZone: root.islandPersistent ? Math.max(0, (root.islandStyle === "notch" ? (root.notchHeight + root.notchAppGap) : (root.pillHeight + (root.mainBarEdge !== "bottom" ? 8 : 0) + root.pillAppGap))) : 0
            WlrLayershell.keyboardFocus: (root.islandHovered || islandHov.hovered) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            Keys.forwardTo: [minimalIslandItem]
            aboveWindows: true
            anchors {
                top: root.mainBarEdge !== "bottom"
                bottom: root.mainBarEdge === "bottom"
            }
            margins {
                top: 0
                bottom: 0
            }

            implicitHeight: Math.max(root.barHeight + 28, minimalIslandItem.height + 16)
            implicitWidth: 600
            visible: root.barMode === "minimal_old"

            mask: Region {
                item: root.islandRevealed ? minimalIslandItem : edgeTrigger
            }

            Item {
                id: edgeTrigger
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: root.mainBarEdge !== "bottom" ? parent.top : undefined
                anchors.bottom: root.mainBarEdge === "bottom" ? parent.bottom : undefined
                width: Math.max(minimalIslandItem.width, 360)
                height: 8
                visible: !root.islandPersistent

                HoverHandler {
                    id: edgeHov
                    onHoveredChanged: {
                        if (edgeHov.hovered) {
                            islandHoverLeaveTimer.stop()
                            root.islandHovered = true
                        }
                    }
                }
            }

            Timer {
                id: islandHoverLeaveTimer
                interval: 350
                onTriggered: {
                    if (!edgeHov.hovered && !islandHov.hovered) {
                        root.islandHovered = false
                    }
                }
            }

            MinimalIsland {
                id: minimalIslandItem
                attachedBottom: root.mainBarEdge === "bottom"
                islandStyle: root.islandStyle
                islandOpacity: root.minimalOpacity
                pillHeight: root.pillHeight
                notchHeight: root.notchHeight
                notifCount: (notificationServer && notificationServer.trackedNotifications) ? notificationServer.trackedNotifications.values.length : 0
                anchors.horizontalCenter: parent.horizontalCenter

                y: {
                    if (root.mainBarEdge === "bottom") {
                        return root.islandRevealed
                            ? (parent.height - height - ((root.islandStyle === "notch") ? 0 : 8))
                            : (parent.height + 10)
                    } else {
                        return root.islandRevealed
                            ? ((root.islandStyle === "notch") ? 0 : 8)
                            : (-height - 10)
                    }
                }
                opacity: root.islandRevealed ? 1.0 : 0.0

                Behavior on y {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                HoverHandler {
                    id: islandHov
                    onHoveredChanged: {
                        if (islandHov.hovered) {
                            islandHoverLeaveTimer.stop()
                            root.islandHovered = true
                            minimalIslandItem.forceActiveFocus()
                        } else {
                            islandHoverLeaveTimer.restart()
                        }
                    }
                }

                Binding on currentPage {
                    value: root.islandPage
                }
                onCurrentPageChanged: {
                    if (root.islandPage !== currentPage) root.islandPage = currentPage
                }
                onOpenLauncher: root.toggleDefaultLauncher()
                onToggleControls: root.toggleControls()
                onOpenMixer: root.openMixer()
                onCloseMixer: mixerLeaveTimer.restart()
                onToggleMixer: root.toggleMixer()
                onOpenBrightness: root.openBrightness()
                onCloseBrightness: brightnessLeaveTimer.restart()
                onToggleBrightness: root.toggleBrightness()
                onOpenBattery: root.openBattery()
                onCloseBattery: batteryLeaveTimer.restart()
                onToggleBattery: root.toggleBattery()
                onOpenWifi: root.openWifi()
                onCloseWifi: wifiLeaveTimer.restart()
                onToggleWifi: root.toggleWifi()
                onOpenBt: root.openBt()
                onCloseBt: btLeaveTimer.restart()
                onToggleBt: root.toggleBt()
                onOpenNotif: root.openNotif()
                onCloseNotif: notifLeaveTimer.restart()
                onToggleNotif: root.toggleNotif()
                onOpenCalendar: root.openCalendar()
                onCloseCalendar: {
                    calendarLeaveTimer.restart()
                    if (root.centerDashboardOpen && !root.centerDashboardHovered) {
                        centerDashboardLeaveTimer.interval = 1000
                        centerDashboardLeaveTimer.restart()
                    }
                }
                onToggleCalendar: root.toggleCalendar()
                onOpenSmallMusic: root.openSmallMusic()
                onCloseSmallMusic: smallMusicLeaveTimer.restart()
                onToggleSmallMusic: root.toggleSmallMusic()
                onSwitchIslandStyle: (s) => root.switchIslandStyle(s)
                onToggleSpotlight: root.toggleDefaultLauncher()
                onOpenSpotlight: root.toggleDefaultLauncher()
            }
        }
    }

    /* Minimal Notch Mode */
    Variants {
        id: tideIslandVariants
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch") ? Quickshell.screens : []

        TideIslandWindow {
            required property var modelData
            screen: modelData
            shellRootController: root
        }
    }

    /* Small Music Overlay */
    Variants {
        model: (root.barMode === "notch" || root.barMode === "pill") ? Quickshell.screens : []

        PanelWindow {
            id: smallMusicWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-music-small"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.smallMusicOpen ? (root.barMode === "minimal" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: (root.smallMusicOpen || smallMusicItem.animatingOut) && root.barMode !== "minimal"

            Item {
                anchors.fill: parent
                focus: root.smallMusicOpen
                Keys.enabled: root.smallMusicOpen
                Keys.onEscapePressed: (event) => {
                    root.closeSmallMusic()
                    event.accepted = true
                }

                /* Outside click dismisser */
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("[smallMusicWindow] Outside click - closing small music")
                        root.closeSmallMusic()
                    }
                }

                SmallMusicOverlay {
                    id: smallMusicItem
                    x: (root.barMode === "pill")
                       ? Math.round(((parent.width > 0 ? parent.width : (modelData ? modelData.width : 1920)) + 1000) / 2 - width - 140)
                       : Math.round(((parent.width > 0 ? parent.width : (modelData ? modelData.width : 1920)) - width) / 2)
                    y: root.mainBarEdge === "bottom"
                       ? (parent.height - height - root.popupBottomMargin)
                       : (root.barMode === "pill" ? (root.popupTopMargin > 0 ? root.popupTopMargin + 6 : 14) : root.popupTopMargin)
                    width: smallMusicItem.implicitWidth
                    height: smallMusicItem.implicitHeight
                    focus: root.smallMusicOpen
                    open: root.smallMusicOpen
                    attachedBottom: root.mainBarEdge === "bottom"
                    onCloseRequested: root.closeSmallMusic()
                    HoverHandler {
                        id: smallMusicHov
                        onHoveredChanged: {
                            root.smallMusicHovered = smallMusicHov.hovered
                            if (root.smallMusicHovered) smallMusicLeaveTimer.stop()
                            else smallMusicLeaveTimer.restart()
                        }
                    }
                }
            }
        }
    }



    /* Music Island */
    Variants {
        model: (root.barMode === "notch" || root.barMode === "pill" || root.barMode === "bar") ? Quickshell.screens : []

        PanelWindow {
            id: musicWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-music"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: root.musicBarEdge !== "bottom"
                bottom: root.musicBarEdge === "bottom"
            }
            margins {
                top: root.musicBarEdge !== "bottom" ? (root.barMode === "notch" ? 36 : 48) : 0
                bottom: root.musicBarEdge === "bottom" ? (root.barMode === "notch" ? 36 : 48) : 0
            }

            implicitWidth: 600
            implicitHeight: 360
            visible: (!root.musicHidden || musicItem.animatingOut)

            mask: Region {
                item: root.musicOpen ? musicItem.cardItem : null
            }

            MusicMod {
                id: musicItem
                anchors.centerIn: parent
                attachedBottom: root.musicBarEdge === "bottom"
                barMode: root.barMode
                pinned: root.musicPinned
                externalOpen: root.musicOpen
                onPanelHoverChanged: (hovered) => {
                    if (hovered) {
                        root.musicHovered = true
                        musicLeaveTimer.stop()
                    } else {
                        root.musicHovered = false
                        musicLeaveTimer.restart()
                    }
                }
            }
        }
    }

    /* Notch Dashboard Scrim */
    Variants {
        model: (root.barMode === "notch" && root.centerDashboardOpen) ? Quickshell.screens : []

        PanelWindow {
            id: centerDashboardScrimWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-center-dashboard-scrim"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            visible: root.barMode === "notch" && root.centerDashboardOpen

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    console.log("[scrim] Outside click detected - closing center dashboard")
                    root.closeCenterDashboard()
                }
            }
        }
    }

    /* Notch Mode */
    Variants {
        model: root.barMode === "notch" ? Quickshell.screens : []

        PanelWindow {
            id: notchBarWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bar-notch"
            WlrLayershell.layer: root.centerDashboardOpen ? WlrLayer.Overlay : WlrLayer.Top
            exclusionMode: root.barMode === "notch" ? ExclusionMode.Normal : ExclusionMode.Ignore
            exclusiveZone: root.barMode === "notch" ? Math.max(0, root.notchHeight + root.notchAppGap) : 0
            aboveWindows: true
            anchors {
                top: root.mainBarEdge !== "bottom"
                bottom: root.mainBarEdge === "bottom"
                left: true
                right: true
            }
            margins {
                top: 0
                bottom: 0
            }

            implicitHeight: 370
            WlrLayershell.keyboardFocus: root.centerDashboardOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            visible: (root.barMode === "notch") && !GlobalState.isFocusActive

            Item {
                id: notchKeyHandler
                anchors.fill: parent
                focus: root.centerDashboardOpen
                Keys.enabled: root.centerDashboardOpen
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        console.log("[notchBarWindow] ESCAPE PRESSED - closing center dashboard")
                        root.closeCenterDashboard()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        if (notchCenterItem) notchCenterItem.previousPage()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Right) {
                        if (notchCenterItem) notchCenterItem.nextPage()
                        event.accepted = true
                    }
                }
                Keys.onEscapePressed: (event) => {
                    console.log("[notchBarWindow] onEscapePressed - closing center dashboard")
                    root.closeCenterDashboard()
                    event.accepted = true
                }
            }

            mask: (root.barMode === "notch" && notchBarWindow.visible && !GlobalState.isCommandCenterOpen) ? notchMask : null
            Region {
                id: notchMask
                Region {
                    x: notchLeftItem.x
                    y: root.mainBarEdge === "bottom" ? (notchBarWindow.height - notchLeftItem.height) : 0
                    width: notchLeftItem.visible ? notchLeftItem.width : 0
                    height: notchLeftItem.visible ? notchLeftItem.height : 0
                }
                Region {
                    x: notchCenterItem.x
                    y: root.mainBarEdge === "bottom" ? (notchBarWindow.height - notchCenterItem.height) : 0
                    width: root.musicBarEdge === root.mainBarEdge ? notchCenterItem.width : 0
                    height: root.musicBarEdge === root.mainBarEdge ? notchCenterItem.height : 0
                }
                Region {
                    x: notchRightItem.x
                    y: root.mainBarEdge === "bottom" ? (notchBarWindow.height - notchRightItem.height) : 0
                    width: notchRightItem.width
                    height: notchRightItem.height
                }
            }

            Item {
                id: notchBarContent
                anchors.fill: parent
                opacity: !GlobalState.isCommandCenterOpen ? 1.0 : 0.0
                visible: opacity > 0.005
                Behavior on opacity {
                    NumberAnimation { duration: 200 }
                }

                NotchBarLeft {
                    id: notchLeftItem
                    visible: true
                    notchOpacity: root.notchOpacity
                    filletRadius: root.notchEarRadius
                    bottomRadius: root.sideNotchBottomRadius
                    height: root.notchHeight
                    implicitHeight: root.notchHeight
                    attachedBottom: root.mainBarEdge === "bottom"
                    y: root.mainBarEdge === "bottom" ? (notchBarWindow.height - height) : 0
                    anchors.left: parent.left
                    leftFillet: false
                    rightFillet: true
                    onToggleSpotlight: root.toggleDefaultLauncher()
                    onOpenSpotlight: root.toggleDefaultLauncher()
                }

                NotchBarCenter {
                    id: notchCenterItem
                    z: root.centerDashboardOpen ? 100 : 1
                    notchOpacity: root.notchOpacity
                    filletRadius: root.notchEarRadius
                    bottomRadius: root.centerDashboardOpen ? 20 : root.notchBottomRadius
                    isExpanded: root.centerDashboardOpen
                    visible: root.musicBarEdge === root.mainBarEdge
                    barContent: root.musicBarContent
                    showVinylDisc: root.showVinylDisc
                    showEqualizer: root.showEqualizer
                    attachedBottom: root.mainBarEdge === "bottom"
                    hasAttachedPopup: (root.calendarOpen || root.smallMusicOpen) && !root.centerDashboardOpen
                    height: isExpanded ? (notchCenterItem.dashImplicitHeight || 270) : ((notchCenterItem.dragActive || notchCenterItem.isUploading) ? Math.round(48 * root.shellScale) : root.notchHeight)
                    implicitHeight: isExpanded ? (notchCenterItem.dashImplicitHeight || 270) : ((notchCenterItem.dragActive || notchCenterItem.isUploading) ? Math.round(48 * root.shellScale) : root.notchHeight)
                    y: root.mainBarEdge === "bottom" ? (notchBarWindow.height - height) : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    leftFillet: true
                    rightFillet: true
                    onToggleCenterDashboard: root.toggleCenterDashboard()
                    onCloseCenterDashboard: root.closeCenterDashboard()
                    onToggleMusic: root.toggleCenterDashboard()
                    onOpenMusic: root.openCenterDashboard()
                    onToggleControls: root.toggleCenterDashboard()
                    onOpenSpatialCanvasNode: (gx, gy) => root.openSpatialCanvasNode(gx, gy)
                    onOpenNotifications: root.openSpatialCanvasNode(0, 1)
                    Component.onCompleted: root.notchCenterItem = notchCenterItem
                }

                NotchBarRight {
                    id: notchRightItem
                    z: 1
                    notchOpacity: root.notchOpacity
                    filletRadius: root.notchEarRadius
                    bottomRadius: root.sideNotchBottomRadius
                    height: root.notchHeight
                    implicitHeight: root.notchHeight
                    attachedBottom: root.mainBarEdge === "bottom"
                    hasAttachedPopup: false
                    y: root.mainBarEdge === "bottom" ? (notchBarWindow.height - height) : 0
                    anchors.right: parent.right
                    leftFillet: true
                    rightFillet: false
                    onOpenMixer: root.openMixer()
                    onCloseMixer: mixerLeaveTimer.restart()
                    onToggleMixer: root.toggleMixer()
                    onOpenBrightness: root.openBrightness()
                    onCloseBrightness: brightnessLeaveTimer.restart()
                    onToggleBrightness: root.toggleBrightness()
                    onOpenBattery: root.openBattery()
                    onCloseBattery: batteryLeaveTimer.restart()
                    onToggleBattery: root.toggleBattery()
                    onOpenTray: root.openTray()
                    onCloseTray: trayLeaveTimer.restart()
                    onToggleTray: root.toggleTray()
                    onOpenWifi: root.openWifi()
                    onToggleWifi: root.toggleWifi()
                    onOpenPower: root.openPower()
                }
            }
        }
    }

    /* Shard Mode */
    Variants {
        model: root.barMode === "shard" ? Quickshell.screens : []

        PanelWindow {
            id: kineticShardWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-kinetic-shard"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: true
            }
            margins {
                top: 8
            }

            implicitWidth: 720
            implicitHeight: 46
            visible: root.barMode === "shard"

            KineticShardBar {
                id: kineticShardItem
                anchors.centerIn: parent
                onOpenLauncher: root.openLauncher()
                onToggleCenterDashboard: root.toggleCenterDashboard()
                onOpenCenterDashboard: root.openCenterDashboard()
                onToggleControls: root.toggleControls()
                onOpenMixer: root.openMixer()
                onToggleMixer: root.toggleMixer()
                onOpenWifi: root.openWifi()
                onToggleWifi: root.toggleWifi()
                onOpenBattery: root.openBattery()
                onToggleBattery: root.toggleBattery()
                onOpenPower: root.openPower()
            }
        }
    }

    /* Nucleus Mode */
    readonly property QtObject nucleusHubItem: QtObject {
        property bool hubOpen: false
        property bool isClosing: false
        property bool notifPanelOpen: false
        property string activeMode: "hub"
        property bool showRestingAtom: root.nucleusRestingVisible
        signal toggleRequested()
        signal openRequested()
        signal closeRequested()
        signal focusLobeRequested(string lobe)
        signal wallpaperModeRequested()
        signal launcherModeRequested()
        signal wifiModeRequested()
        signal bluetoothModeRequested()
        signal calendarModeRequested()

        property real lastToggleTime: 0
        function toggle() { 
            var now = Date.now()
            if (now - lastToggleTime < 350) return
            lastToggleTime = now
            if (!hubOpen || isClosing) {
                isClosing = false
                hubOpen = true
                openRequested()
            } else {
                close()
            }
        }
        function open() { 
            isClosing = false
            hubOpen = true
            openRequested() 
        }
        function close() { 
            if (hubOpen && !isClosing) {
                isClosing = true
                closeRequested()
            }
        }
        function focusLobe(l) { 
            isClosing = false
            hubOpen = true
            focusLobeRequested(l) 
        }
        function openWallpaperMode() { 
            isClosing = false
            hubOpen = true
            wallpaperModeRequested() 
        }
        function openLauncherMode() { 
            isClosing = false
            hubOpen = true
            launcherModeRequested() 
        }
        function toggleLauncher() {
            if (!hubOpen || isClosing) {
                isClosing = false
                hubOpen = true
                launcherModeRequested()
            } else {
                close()
            }
        }
        signal toggleLyricsRequested()
        function toggleLyrics() {
            toggleLyricsRequested()
        }
        function openWifiMode() {
            isClosing = false
            hubOpen = true
            wifiModeRequested()
        }
        function openBluetoothMode() {
            isClosing = false
            hubOpen = true
            bluetoothModeRequested()
        }
        function openCalendarMode() {
            isClosing = false
            hubOpen = true
            activeMode = "calendar"
            calendarModeRequested()
        }
        signal powerModeRequested()
        function openPowerMode() {
            isClosing = false
            hubOpen = true
            activeMode = "power"
            powerModeRequested()
        }
        signal powerActionRequested(string action)
        function triggerPowerAction(action) {
            isClosing = false
            hubOpen = true
            powerActionRequested(action)
        }
        signal volumeActionRequested(string action, bool wasClosed)
        signal brightnessActionRequested(string action, bool wasClosed)
        function volumeAction(action) {
            var wasClosed = (!hubOpen || isClosing)
            if (wasClosed) {
                isClosing = false
                hubOpen = true
                openRequested()
            }
            volumeActionRequested(action, wasClosed)
        }
        function brightnessAction(action) {
            var wasClosed = (!hubOpen || isClosing)
            if (wasClosed) {
                isClosing = false
                hubOpen = true
                openRequested()
            }
            brightnessActionRequested(action, wasClosed)
        }
        signal notifPanelRequested()
        function openNotificationPanel() {
            isClosing = false
            hubOpen = true
            openRequested()
            notifPanelRequested()
        }
        signal notifTabRequested(int tabIdx)
        function setNotificationTab(tabIdx) {
            notifTabRequested(tabIdx)
        }
    }

    Variants {
        model: (root.barMode === "nucleus" || root.barMode === "vanish") ? Quickshell.screens : []

        // 1. Resting Dot (Sits on desktop below windows, never blocks apps)
        PanelWindow {
            id: nucleusRestingWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-nucleus-resting"
            WlrLayershell.layer: WlrLayer.Bottom
            exclusionMode: ExclusionMode.Ignore
            anchors {}
            implicitWidth: 80
            implicitHeight: 80

            visible: root.barMode === "nucleus" && !root.nucleusHubItem.hubOpen && root.nucleusRestingVisible

            mask: Region {
                item: nucleusRestingCenterDot
            }

            Item {
                id: nucleusRestingCenterDot
                anchors.centerIn: parent
                width: 80
                height: 80
                opacity: root.workspaceOsdActive ? 0.0 : 1.0
                visible: opacity > 0.002
                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }

                property bool restingPressing: false
                property real restingHoldProgress: 0.0
                property bool justTriggeredPower: false
                readonly property bool shouldSpin: {
                    if (!nucleusRestingWindow.visible || !nucleusRestingCenterDot.visible) return false
                    if (root.nucleusRestingSpin === "never" || root.nucleusRestingSpin === false) return false
                    if (root.nucleusRestingSpin === "always" || root.nucleusRestingSpin === true) return true
                    return (restingMouseArea && restingMouseArea.containsMouse) || restingPressing
                }

                FrameAnimation {
                    running: nucleusRestingCenterDot.shouldSpin
                    onTriggered: {
                        var dt = frameTime > 0.0 ? Math.min(0.05, frameTime) : 0.016
                        ring1Orbit.rotation = (ring1Orbit.rotation + (20.0 * dt)) % 360
                        ring2Orbit.rotation = (ring2Orbit.rotation - ((360.0 / 28.0) * dt)) % 360
                    }
                }

                // Ring 1 (Inner, 2 electrons)
                Rectangle {
                    anchors.centerIn: parent
                    width: 40; height: 40; radius: 20
                    color: "transparent"
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)
                    border.width: 1

                    Item {
                        id: ring1Orbit
                        anchors.centerIn: parent
                        width: parent.width; height: parent.height
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: -3.5; width: 6; height: 6; radius: 3; color: Theme.accent
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: parent.height - 2.5; width: 6; height: 6; radius: 3; color: Theme.accent
                        }
                    }
                }

                // Ring 2 (Outer, 4 electrons)
                Rectangle {
                    anchors.centerIn: parent
                    width: 72; height: 72; radius: 36
                    color: "transparent"
                    border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16)
                    border.width: 1

                    Item {
                        id: ring2Orbit
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
                                    y: -3.5; width: 6; height: 6; radius: 3; color: Theme.accent
                                }
                            }
                        }
                    }
                }

                // 16px center nucleus dot
                Rectangle {
                    anchors.centerIn: parent
                    width: 16; height: 16; radius: 8
                    color: Theme.accent
                    border.color: "#FFFFFF"
                    border.width: 1.0
                }

                // Clockwise Halo Ring (radius 27px, fills white clockwise over 600ms on hold)
                Shape {
                    id: restingHoldRingShape
                    anchors.centerIn: parent
                    width: 54
                    height: 54
                    visible: nucleusRestingCenterDot.restingHoldProgress > 0.001
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
                            sweepAngle: Math.max(0.1, Math.min(359.9, nucleusRestingCenterDot.restingHoldProgress * 360.0))
                        }
                    }
                }

                FrameAnimation {
                    running: nucleusRestingCenterDot.restingPressing || nucleusRestingCenterDot.restingHoldProgress > 0.0
                    onTriggered: {
                        var dt = frameTime * 1000.0
                        if (nucleusRestingCenterDot.restingPressing) {
                            nucleusRestingCenterDot.restingHoldProgress = Math.min(1.0, nucleusRestingCenterDot.restingHoldProgress + dt / 600.0)
                            if (nucleusRestingCenterDot.restingHoldProgress >= 1.0) {
                                nucleusRestingCenterDot.restingHoldProgress = 0.0
                                nucleusRestingCenterDot.restingPressing = false
                                nucleusRestingCenterDot.justTriggeredPower = true
                                if (root.nucleusHubItem) root.nucleusHubItem.openPowerMode()
                            }
                        } else if (nucleusRestingCenterDot.restingHoldProgress > 0.0) {
                            nucleusRestingCenterDot.restingHoldProgress = Math.max(0.0, nucleusRestingCenterDot.restingHoldProgress - dt * 0.004)
                        }
                    }
                }

                MouseArea {
                    id: restingMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onPressed: {
                        nucleusRestingCenterDot.justTriggeredPower = false
                        nucleusRestingCenterDot.restingPressing = true
                    }
                    onReleased: nucleusRestingCenterDot.restingPressing = false
                    onCanceled: nucleusRestingCenterDot.restingPressing = false
                    onClicked: {
                        nucleusRestingCenterDot.restingPressing = false
                        if (nucleusRestingCenterDot.justTriggeredPower) {
                            nucleusRestingCenterDot.justTriggeredPower = false
                            return
                        }
                        if (nucleusRestingCenterDot.restingHoldProgress < 0.99) {
                            if (root.nucleusHubItem) root.nucleusHubItem.open()
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: (root.barMode === "nucleus" || root.barMode === "vanish") ? Quickshell.screens : []

        // 2. Opened Radial Hub (Always on overlay layer, appears above all windows when active)
        PanelWindow {
            id: nucleusHubWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-nucleus-hub"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (root.barMode === "nucleus" && root.nucleusHubItem.hubOpen && !root.nucleusHubItem.isClosing) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: root.barMode === "nucleus" && (root.nucleusHubItem.hubOpen || root.nucleusHubItem.isClosing)

            NucleusHub {
                id: nucleusHubItemInstance
                anchors.fill: parent
                showRestingAtom: root.nucleusRestingVisible
                onOpenLauncher: root.openLauncher()
                onOpenWallpapers: root.openWallpaperPicker()
                onOpenPower: root.openPower()
                onRequestLock: sessionLock.lock()
                onClosingStarted: {
                    root.nucleusHubItem.isClosing = true
                }
                onCloseRequested: {
                    root.nucleusHubItem.hubOpen = false
                    root.nucleusHubItem.isClosing = false
                    root.nucleusHubItem.notifPanelOpen = false
                    root.nucleusHubItem.activeMode = "hub"
                }
                onActiveModeChanged: {
                    root.nucleusHubItem.activeMode = activeMode
                }
                onNotifPanelOpenChanged: {
                    root.nucleusHubItem.notifPanelOpen = notifPanelOpen
                }

                Connections {
                    target: root.nucleusHubItem
                    function onToggleRequested() { nucleusHubItemInstance.toggle() }
                    function onOpenRequested() { nucleusHubItemInstance.open() }
                    function onCloseRequested() { nucleusHubItemInstance.close() }
                    function onFocusLobeRequested(lobe) { nucleusHubItemInstance.focusLobe(lobe) }
                    function onWallpaperModeRequested() { nucleusHubItemInstance.openWallpaperMode() }
                    function onLauncherModeRequested() { nucleusHubItemInstance.openLauncherMode() }
                    function onToggleLyricsRequested() { nucleusHubItemInstance.toggleLyrics() }
                    function onWifiModeRequested() { nucleusHubItemInstance.openWifiMode() }
                    function onBluetoothModeRequested() { nucleusHubItemInstance.openBluetoothMode() }
                    function onCalendarModeRequested() { nucleusHubItemInstance.openCalendarMode() }
                    function onPowerModeRequested() { nucleusHubItemInstance.openPowerMode() }
                    function onPowerActionRequested(action) { nucleusHubItemInstance.triggerPowerAction(action) }
                    function onVolumeActionRequested(action, wasClosed) {
                        if (wasClosed && action !== "open") {
                            nucleusHubItemInstance.osdOpenedHub = true
                        }
                        if (action === "up") nucleusHubItemInstance.stepVolume(root.volumeStepVal)
                        else if (action === "down") nucleusHubItemInstance.stepVolume(-root.volumeStepVal)
                        else if (action === "toggle-mute") nucleusHubItemInstance.toggleVolumeMute()
                        else if (action === "open") nucleusHubItemInstance.openVolumeMode()
                    }
                    function onBrightnessActionRequested(action, wasClosed) {
                        if (wasClosed && action !== "open") {
                            nucleusHubItemInstance.osdOpenedHub = true
                        }
                        if (action === "up") nucleusHubItemInstance.stepBrightness(root.brightnessStepVal)
                        else if (action === "down") nucleusHubItemInstance.stepBrightness(-root.brightnessStepVal)
                        else if (action === "open") nucleusHubItemInstance.openBrightnessMode()
                    }
                    function onNotifPanelRequested() {
                        nucleusHubItemInstance.notifPanelOpen = true
                        nucleusHubItemInstance.focusedLobe = "alerts"
                    }
                    function onNotifTabRequested(tabIdx) {
                        nucleusHubItemInstance.setNotificationTab(tabIdx)
                    }
                }
            }
        }
    }

    /* Nucleus Transition */
    Variants {
        model: root.nucleusTransitionActive ? Quickshell.screens : []

        PanelWindow {
            id: nucleusTransitionWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-nucleus-transition"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: true

            NucleusTransitionOverlay {
                id: transitionOverlayItem
                anchors.fill: parent
                isPrimaryScreen: (modelData === Quickshell.screens[0])
                transitionWord: root.nucleusTransitionWord
                transitionEnabled: root.nucleusTransitionEnabled
                transitionAnimation: root.nucleusTransitionAnimation

                Component.onCompleted: {
                    play()
                }

                onTransitionFinished: {
                    root.finishNucleusTransition()
                }
            }
        }
    }

    /* Notch Center Island */
    Variants {
        model: (root.barMode === "notch" && (root.musicBarEdge !== root.mainBarEdge || root.mainBarEdge === "left" || root.mainBarEdge === "right")) ? Quickshell.screens : []

        PanelWindow {
            id: notchCenterWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bar-notch-center"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors {
                top: root.musicBarEdge !== "bottom"
                bottom: root.musicBarEdge === "bottom"
            }
            implicitHeight: (separateNotchCenter.dragActive || separateNotchCenter.isUploading) ? Math.round(48 * root.shellScale) : 34
            implicitWidth: separateNotchCenter.implicitWidth
            visible: root.barMode === "notch" && (root.musicBarEdge !== root.mainBarEdge || root.mainBarEdge === "left" || root.mainBarEdge === "right") && !GlobalState.isFocusActive

            NotchBarCenter {
                id: separateNotchCenter
                barContent: root.musicBarContent
                showVinylDisc: root.showVinylDisc
                showEqualizer: root.showEqualizer
                attachedBottom: root.musicBarEdge === "bottom"
                hasAttachedPopup: root.centerDashboardOpen || root.calendarOpen || root.smallMusicOpen
                anchors.fill: parent
                onOpenMusicHover: root.openCenterDashboard()
                onCloseMusicHover: centerDashboardLeaveTimer.restart()
                onOpenCenterDashboard: root.openCenterDashboard()
                onCloseCenterDashboard: centerDashboardLeaveTimer.restart()
                onToggleCenterDashboard: root.toggleCenterDashboard()
                onToggleMusic: root.toggleCenterDashboard()
                onOpenMusic: root.openCenterDashboard()
                onToggleControls: root.toggleCenterDashboard()
                onOpenSpatialCanvasNode: (gx, gy) => root.openSpatialCanvasNode(gx, gy)
                onOpenNotifications: root.openSpatialCanvasNode(0, 1)
            }
        }
    }

    /* Launcher popup */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: launcherWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.launcherOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.launcherOpen || (launcherItem && launcherItem.animatingOut)

            MouseArea {
                anchors.fill: parent
                enabled: root.launcherOpen
                onClicked: (mouse) => {
                    var lw = launcherItem.width
                    var lh = launcherItem.height
                    var lx = launcherItem.x
                    var ly = launcherItem.y
                    if (mouse.x < lx || mouse.x > lx + lw || mouse.y < ly || mouse.y > ly + lh)
                        root.closeLauncher()
                }
            }

            LauncherMod {
                id: launcherItem
                open: root.launcherOpen
                barEdge: root.mainBarEdge
                onCloseRequested: root.closeLauncher()
            }
        }
    }

    /* Spotlight Command Palette */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: spotlightWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-spotlight"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.spotlightOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.spotlightOpen || (spotlightItem && spotlightItem.animatingOut)

            MouseArea {
                anchors.fill: parent
                enabled: root.spotlightOpen
                onClicked: (mouse) => {
                    var sw = spotlightItem.width
                    var sh = spotlightItem.height
                    var sx = spotlightItem.x
                    var sy = spotlightItem.y
                    if (mouse.x < sx || mouse.x > sx + sw || mouse.y < sy || mouse.y > sy + sh)
                        root.closeSpotlight()
                }
            }

            SpotlightModal {
                id: spotlightItem
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -40
                barMode: root.barMode
                open: root.spotlightOpen
                shellOpacity: root.shellOpacity
                onCloseRequested: root.closeSpotlight()
            }
        }
    }

    /* Wallpaper Picker */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: wallpaperPickerWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-wallpaper-picker"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.wallpaperPickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.wallpaperPickerOpen || (wpItem && wpItem.animatingOut)

            /* Backdrop click dismisses wallpaper picker */
            MouseArea {
                anchors.fill: parent
                enabled: root.wallpaperPickerOpen
                onClicked: root.closeWallpaperPicker()
            }

            WallpaperPicker {
                id: wpItem
                anchors.fill: parent
                open: root.wallpaperPickerOpen
                activeSource: root.wallpaperSource
                onCloseRequested: root.closeWallpaperPicker()
                onWallpaperApplyStarted: (name) => root.startWallpaperTransition(name)
                onWallpaperApplyFinished: () => root.finishWallpaperTransition()

                Connections {
                    target: root
                    function onWallpaperSourceChanged() {
                        wpItem.activeSource = root.wallpaperSource
                    }
                    function onWallpaperPickerOpenChanged() {
                        if (root.wallpaperPickerOpen) {
                            wpItem.activeSource = root.wallpaperSource
                        }
                    }
                }
            }
        }
    }

    /* Carbon Settings Hub Overlay */
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: settingsHubWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-settings-hub"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.settingsHubOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.settingsHubOpen

            SettingsHub {
                id: hubInst
                anchors.fill: parent
                open: root.settingsHubOpen
                Binding {
                    target: hubInst
                    property: "currentSection"
                    value: root.settingsHubActiveTab
                }
                onCurrentSectionChanged: {
                    if (root.settingsHubActiveTab !== currentSection) {
                        root.settingsHubActiveTab = currentSection
                    }
                }
                onCloseRequested: root.closeSettingsHub()
            }
        }
    }

    /* Focus HUD Background (Blueprint & Dimming) */
    Variants {
        model: Quickshell.screens

        FocusHUDBackground {
            required property var modelData
            modelData: modelData
            screen: modelData
            visible: root.focusHudOpen
        }
    }

    /* Focus HUD (Hyper-Tunnel) Side Bar */
    Variants {
        model: Quickshell.screens

        FocusHUD {
            id: focusHudInst
            required property var modelData
            modelData: modelData
            screen: modelData
            visible: root.focusHudOpen
            onCloseRequested: root.closeFocusHud()
            Component.onCompleted: root.focusHudItem = this
        }
    }

    /* Notch Command Center (Radar 2x2 Blueprint Panel) */
    Variants {
        model: Quickshell.screens

        CommandCenter {
            id: commandCenterInst
            required property var modelData
            modelData: modelData
            screen: modelData
            barEdge: root.mainBarEdge
            barMode: root.barMode
            visible: root.commandCenterOpen || root.commandCenterAnimatingOut || commandCenterInst.animatingOut
            isOpen: root.commandCenterOpen
            onCloseRequested: root.closeCommandCenter()
            onAnimationFinished: {
                root.commandCenterAnimatingOut = false
            }
            Component.onCompleted: root.commandCenterItem = this
        }
    }

    /* 3x3 Spatial Canvas OS App Suite & Blueprint Workspace Switcher */
    Variants {
        model: Quickshell.screens

        SpatialCanvas {
            id: spatialCanvasInst
            required property var modelData
            modelData: modelData
            screen: modelData
            barEdge: root.mainBarEdge
            barMode: root.barMode
            visible: root.spatialCanvasOpen || root.spatialCanvasAnimatingOut || spatialCanvasInst.animatingOut
            isOpen: root.spatialCanvasOpen
            onCloseRequested: root.closeSpatialCanvas()
            onAnimationFinished: {
                root.spatialCanvasAnimatingOut = false
            }
            Component.onCompleted: root.spatialCanvasItem = this
        }
    }

    /* Wallpaper Transition Overlay */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch" || !root.wallpaperTransitionOpen) ? [] : Quickshell.screens

        PanelWindow {
            id: wallpaperTransitionWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-wallpaper-transition"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.wallpaperTransitionOpen

            WallpaperTransition {
                anchors.fill: parent
                active: root.wallpaperTransitionOpen
                pendingFinish: root.wallpaperTransitionPendingFinish
                statusText: root.wallpaperTransitionText
                onFinished: {
                    root.wallpaperTransitionOpen = false
                }
            }
        }
    }

    /* Mixer popup: fullscreen transparent overlay with outside click dismissal */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: mixerWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-mixer"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.mixerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: (root.mixerOpen || mixerItem.animatingOut) && root.mainBarEdge !== "left"

            Item {
                anchors.fill: parent
                focus: root.mixerOpen
                Keys.enabled: root.mixerOpen
                Keys.onEscapePressed: (event) => {
                    root.closeMixer()
                    event.accepted = true
                }

                /* Outside click-absorber: clicking outside the panel closes it */
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("[mixerWindow] Outside click - closing mixer")
                        root.closeMixer()
                    }
                }

                MixerMod {
                    id: mixerItem
                    x: (root.barMode === "pill")
                       ? Math.round(((parent.width > 0 ? parent.width : (mixerWindow.screen ? mixerWindow.screen.width : 1920)) - 1000) / 2)
                       : (root.barMode === "minimal")
                       ? Math.round(((parent.width > 0 ? parent.width : (mixerWindow.screen ? mixerWindow.screen.width : 1920)) - width) / 2)
                       : ((parent.width > 0 ? parent.width : (mixerWindow.screen ? mixerWindow.screen.width : 1920)) - width - root.popupRightMargin)
                    y: root.mainBarEdge === "bottom"
                       ? (parent.height - height - root.popupBottomMargin)
                       : (root.barMode === "pill" ? (root.popupTopMargin > 0 ? root.popupTopMargin + 6 : 14) : root.popupTopMargin)
                    width: mixerItem.implicitWidth
                    height: mixerItem.implicitHeight
                    barMode: root.barMode
                    barEdge: root.mainBarEdge
                    notchOpacity: root.notchOpacity
                    open: root.mixerOpen
                    onCloseRequested: root.closeMixer()
                    onAnyHoverChanged: {
                        root.mixerHovered = mixerItem.anyHover
                        if (root.mixerHovered) mixerLeaveTimer.stop()
                        else mixerLeaveTimer.restart()
                    }
                }
            }
        }
    }

    /* Brightness popup: fullscreen transparent overlay with outside click dismissal */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: brightnessWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-brightness"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.brightnessOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: (root.brightnessOpen || brightnessItem.animatingOut) && root.mainBarEdge !== "left"

            Item {
                anchors.fill: parent
                focus: root.brightnessOpen
                Keys.enabled: root.brightnessOpen
                Keys.onEscapePressed: (event) => {
                    root.closeBrightness()
                    event.accepted = true
                }

                /* Outside click-absorber */
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("[brightnessWindow] Outside click - closing brightness")
                        root.closeBrightness()
                    }
                }

                BrightnessPopup {
                    id: brightnessItem
                    x: (root.barMode === "minimal")
                       ? Math.round(((parent.width > 0 ? parent.width : (brightnessWindow.screen ? brightnessWindow.screen.width : 1920)) - width) / 2)
                       : (root.barMode === "pill")
                       ? Math.round(((parent.width > 0 ? parent.width : (brightnessWindow.screen ? brightnessWindow.screen.width : 1920)) + 1000) / 2 - width)
                       : ((parent.width > 0 ? parent.width : (brightnessWindow.screen ? brightnessWindow.screen.width : 1920)) - width - root.popupRightMargin)
                    y: root.mainBarEdge === "bottom"
                       ? (parent.height - height - root.popupBottomMargin)
                       : (root.barMode === "pill" ? (root.popupTopMargin > 0 ? root.popupTopMargin + 6 : 14) : root.popupTopMargin)
                    width: brightnessItem.implicitWidth
                    height: brightnessItem.implicitHeight
                    barMode: root.barMode
                    barEdge: root.mainBarEdge
                    notchOpacity: root.notchOpacity
                    open: root.brightnessOpen
                    onCloseRequested: root.closeBrightness()
                    onAnyHoverChanged: {
                        root.brightnessHovered = brightnessItem.anyHover
                        if (root.brightnessHovered) brightnessLeaveTimer.stop()
                        else brightnessLeaveTimer.restart()
                    }
                }
            }
        }
    }

    /* Battery popup: fullscreen transparent overlay with outside click dismissal */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: batteryWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-battery"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: (root.batteryOpen || batteryItem.animatingOut) && root.mainBarEdge !== "left" && root.barMode !== "pill"

            Item {
                anchors.fill: parent
                focus: root.batteryOpen
                Keys.enabled: root.batteryOpen
                Keys.onEscapePressed: (event) => {
                    root.closeBattery()
                    event.accepted = true
                }

                /* Outside click-absorber */
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("[batteryWindow] Outside click - closing battery")
                        root.closeBattery()
                    }
                }

                BatteryPopup {
                    id: batteryItem
                    x: (root.barMode === "minimal")
                       ? Math.round(((parent.width > 0 ? parent.width : (batteryWindow.screen ? batteryWindow.screen.width : 1920)) - width) / 2)
                       : (root.barMode === "pill")
                       ? Math.round(((parent.width > 0 ? parent.width : (batteryWindow.screen ? batteryWindow.screen.width : 1920)) + 1000) / 2 - width)
                       : ((parent.width > 0 ? parent.width : (batteryWindow.screen ? batteryWindow.screen.width : 1920)) - width - root.popupRightMargin)
                    y: root.mainBarEdge === "bottom"
                       ? (parent.height - height - root.popupBottomMargin)
                       : (root.barMode === "pill" ? (root.popupTopMargin > 0 ? root.popupTopMargin + 6 : 14) : root.popupTopMargin)
                    width: batteryItem.implicitWidth
                    height: batteryItem.implicitHeight
                    barMode: root.barMode
                    barEdge: root.mainBarEdge
                    notchOpacity: root.notchOpacity
                    open: root.batteryOpen
                    onHoveredChanged: {
                        root.batteryHovered = batteryItem.hovered
                        if (root.batteryHovered) batteryLeaveTimer.stop()
                        else batteryLeaveTimer.restart()
                    }
                }
            }
        }
    }

    /* Wifi popup: fullscreen transparent overlay with outside click dismissal */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: wifiWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-wifi"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.wifiOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: (root.wifiOpen || wifiItem.animatingOut) && root.mainBarEdge !== "left" && root.barMode !== "pill"

            Item {
                anchors.fill: parent
                focus: root.wifiOpen
                Keys.enabled: root.wifiOpen
                Keys.onEscapePressed: (event) => {
                    root.closeWifi()
                    event.accepted = true
                }

                /* Outside click-absorber */
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("[wifiWindow] Outside click - closing wifi")
                        root.closeWifi()
                    }
                }

                WifiPopup {
                    id: wifiItem
                    x: (root.barMode === "minimal")
                       ? Math.round(((parent.width > 0 ? parent.width : (wifiWindow.screen ? wifiWindow.screen.width : 1920)) - width) / 2)
                       : (root.barMode === "pill")
                       ? Math.round(((parent.width > 0 ? parent.width : (wifiWindow.screen ? wifiWindow.screen.width : 1920)) + 1000) / 2 - width)
                       : ((parent.width > 0 ? parent.width : (wifiWindow.screen ? wifiWindow.screen.width : 1920)) - width - root.popupRightMargin)
                    y: root.mainBarEdge === "bottom"
                       ? (parent.height - height - root.popupBottomMargin)
                       : (root.barMode === "pill" ? (root.popupTopMargin > 0 ? root.popupTopMargin + 6 : 14) : root.popupTopMargin)
                    width: wifiItem.implicitWidth
                    height: wifiItem.implicitHeight
                    barMode: root.barMode
                    barEdge: root.mainBarEdge
                    notchOpacity: root.notchOpacity
                    open: root.wifiOpen
                    powerOn: root.wifiOn
                    wifiName: root.wifiName
                    onPowerToggled: (on) => root.toggleWifiPower()
                    onRequestedClose: root.closeWifi()
                    HoverHandler {
                        id: wifiHov
                        onHoveredChanged: {
                            root.wifiHovered = wifiHov.hovered
                            if (root.wifiHovered) wifiLeaveTimer.stop()
                            else wifiLeaveTimer.restart()
                        }
                    }
                }
            }
        }
    }

    /* Bluetooth popup: fullscreen transparent overlay with outside click dismissal */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: btWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-bluetooth"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.btOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: (root.btOpen || btItem.animatingOut) && root.mainBarEdge !== "left" && root.barMode !== "pill"

            Item {
                anchors.fill: parent
                focus: root.btOpen
                Keys.enabled: root.btOpen
                Keys.onEscapePressed: (event) => {
                    root.closeBt()
                    event.accepted = true
                }

                /* Outside click-absorber */
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("[btWindow] Outside click - closing bt")
                        root.closeBt()
                    }
                }

                BtPopup {
                    id: btItem
                    x: (root.barMode === "minimal")
                       ? Math.round(((parent.width > 0 ? parent.width : (btWindow.screen ? btWindow.screen.width : 1920)) - width) / 2)
                       : (root.barMode === "pill")
                       ? Math.round(((parent.width > 0 ? parent.width : (btWindow.screen ? btWindow.screen.width : 1920)) + 1000) / 2 - width)
                       : ((parent.width > 0 ? parent.width : (btWindow.screen ? btWindow.screen.width : 1920)) - width - root.popupRightMargin)
                    y: root.mainBarEdge === "bottom"
                       ? (parent.height - height - root.popupBottomMargin)
                       : (root.barMode === "pill" ? (root.popupTopMargin > 0 ? root.popupTopMargin + 6 : 14) : root.popupTopMargin)
                    width: btItem.implicitWidth
                    height: btItem.implicitHeight
                    barMode: root.barMode
                    barEdge: root.mainBarEdge
                    notchOpacity: root.notchOpacity
                    open: root.btOpen
                    powerOn: root.btOn
                    btName: root.btName
                    onPowerToggled: (on) => root.toggleBtPower()
                    onRequestedClose: root.closeBt()
                    HoverHandler {
                        id: btHov
                        onHoveredChanged: {
                            root.btHovered = btHov.hovered
                            if (root.btHovered) btLeaveTimer.stop()
                            else btLeaveTimer.restart()
                        }
                    }
                }
            }
        }
    }

    /* Tray overflow popup */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: trayWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-tray"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: root.mainBarEdge !== "bottom" && root.mainBarEdge !== "right"
                bottom: root.mainBarEdge === "bottom" || root.mainBarEdge === "right"
                right: root.barMode !== "minimal"
            }
            margins {
                top: root.popupTopMargin
                bottom: root.popupBottomMargin
                right: root.popupRightMargin
            }

            implicitWidth: trayItem.implicitWidth
            implicitHeight: trayItem.implicitHeight

            visible: (root.trayOpen || trayItem.animatingOut) && root.mainBarEdge !== "left" && root.barMode !== "minimal"

            mask: Region {
                item: (root.trayOpen || trayItem.animatingOut) ? trayItem : null
                x: 0; y: 0
                width: (root.trayOpen || trayItem.animatingOut) ? trayItem.implicitWidth : 0
                height: (root.trayOpen || trayItem.animatingOut) ? trayItem.implicitHeight : 0
            }

            TrayPopup {
                id: trayItem
                barMode: root.barMode
                barEdge: root.mainBarEdge
                notchOpacity: root.notchOpacity
                open: root.trayOpen
                onHoveredChanged: {
                    root.trayHovered = trayItem.hovered
                    if (root.trayHovered) trayLeaveTimer.stop()
                    else trayLeaveTimer.restart()
                }
                onRequestedClose: root.closeTray()
            }
        }
    }

    /* Notification popup */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: notifWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-notification-popup"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: root.mainBarEdge !== "bottom" && root.mainBarEdge !== "right"
                bottom: root.mainBarEdge === "bottom" || root.mainBarEdge === "right"
                right: root.barMode !== "minimal"
            }
            margins {
                top: root.barMode === "notch" ? 38 : root.popupTopMargin
                bottom: root.popupBottomMargin
                right: root.popupRightMargin
            }

            implicitWidth: notifItem.implicitWidth
            implicitHeight: notifItem.implicitHeight

            visible: false

            mask: Region {
                item: (root.notifOpen || notifItem.animatingOut) ? notifItem : null
                x: 0; y: 0
                width: (root.notifOpen || notifItem.animatingOut) ? notifItem.implicitWidth : 0
                height: (root.notifOpen || notifItem.animatingOut) ? notifItem.implicitHeight : 0
            }

            NotificationPopup {
                id: notifItem
                barMode: root.barMode
                barEdge: root.mainBarEdge
                server: notificationServer
                open: root.notifOpen
                onRequestClose: root.closeNotif()
            }
        }
    }

    /* Calendar popup: fullscreen transparent overlay with outside click dismissal */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: calendarWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-calendar"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.calendarOpen ? (root.barMode === "minimal" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: (root.calendarOpen || calendarItem.animatingOut) && root.mainBarEdge !== "left"

            Item {
                anchors.fill: parent
                focus: root.calendarOpen
                Keys.enabled: root.calendarOpen
                Keys.onEscapePressed: (event) => {
                    root.closeCalendar()
                    event.accepted = true
                }

                /* Outside click-absorber */
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("[calendarWindow] Outside click - closing calendar")
                        root.closeCalendar()
                    }
                }

                CalendarPopup {
                    id: calendarItem
                    x: (root.barMode === "minimal" || root.barMode === "pill")
                       ? Math.round(((parent.width > 0 ? parent.width : (calendarWindow.screen ? calendarWindow.screen.width : 1920)) - width) / 2)
                       : ((parent.width > 0 ? parent.width : (calendarWindow.screen ? calendarWindow.screen.width : 1920)) - width - 16)
                    y: root.mainBarEdge === "bottom"
                       ? (parent.height - height - root.popupBottomMargin)
                       : (root.barMode === "pill" ? (root.popupTopMargin > 0 ? root.popupTopMargin + 6 : 14) : root.popupTopMargin)
                    width: 216
                    height: 206
                    barEdge: root.mainBarEdge
                    focus: root.calendarOpen
                    open: root.calendarOpen
                    onCloseRequested: root.closeCalendar()
                    onAnyHoverChanged: {
                        root.calendarHovered = calendarItem.anyHover
                        if (root.calendarHovered) calendarLeaveTimer.stop()
                        else calendarLeaveTimer.restart()
                    }
                }
            }
        }
    }

    /* Center Dashboard */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: centerDashboardWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-center-dashboard"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.centerDashboardOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: (root.centerDashboardOpen || centerDashboardItem.animatingOut) && root.barMode !== "notch" && root.barMode !== "minimal"

            function updateHover() {
                var isHov = centerDashboardItem.hovered
                root.centerDashboardHovered = isHov
                if (isHov) {
                    root.centerDashboardAwaitingHover = false
                    centerDashboardLeaveTimer.stop()
                } else if (!root.centerDashboardPinned && !root.centerDashboardAwaitingHover) {
                    centerDashboardLeaveTimer.interval = 350
                    centerDashboardLeaveTimer.restart()
                }
            }

            Item {
                anchors.fill: parent
                focus: root.centerDashboardOpen
                Keys.enabled: root.centerDashboardOpen
                Keys.onEscapePressed: (event) => {
                    root.closeCenterDashboard();
                    event.accepted = true;
                }

                /* Outside click dismisser */
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("[centerDashboardWindow] Outside click - closing center dashboard")
                        root.closeCenterDashboard()
                    }
                }

                CenterDashboard {
                    id: centerDashboardItem
                    anchors.top: root.mainBarEdge !== "bottom" ? parent.top : undefined
                    anchors.bottom: root.mainBarEdge === "bottom" ? parent.bottom : undefined
                    anchors.topMargin: root.mainBarEdge !== "bottom" ? root.popupTopMargin : 0
                    anchors.bottomMargin: root.mainBarEdge === "bottom" ? root.popupBottomMargin : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    open: root.centerDashboardOpen
                    minimalCalendarOnly: root.barMode === "minimal"
                    attachedBottom: root.mainBarEdge === "bottom"
                    onCloseRequested: root.closeCenterDashboard()
                    onHoveredChanged: centerDashboardWindow.updateHover()
                    Keys.onEscapePressed: root.closeCenterDashboard()
                }
            }
        }
    }

    /* Left Edge Popups */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch" || root.mainBarEdge !== "left") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: mixerWindowLeft
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-mixer-left"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors {
                bottom: true
                left: true
            }
            margins {
                bottom: 14
                left: root.barMode === "notch" ? 38 : 54
            }

            implicitWidth: mixerItemLeft.implicitWidth
            implicitHeight: mixerItemLeft.implicitHeight + 20

            visible: (root.mixerOpen || mixerItemLeft.animatingOut) && root.mainBarEdge === "left"

            mask: Region {
                item: (root.mixerOpen || mixerItemLeft.animatingOut) ? mixerItemLeft : null
                x: 0; y: 0
                width: (root.mixerOpen || mixerItemLeft.animatingOut) ? mixerItemLeft.implicitWidth : 0
                height: (root.mixerOpen || mixerItemLeft.animatingOut) ? mixerItemLeft.implicitHeight + 20 : 0
            }

            MixerMod {
                id: mixerItemLeft
                barEdge: "left"
                open: root.mixerOpen
                onCloseRequested: root.closeMixer()
                onAnyHoverChanged: {
                    root.mixerHovered = mixerItemLeft.anyHover
                    if (root.mixerHovered) mixerLeaveTimer.stop()
                    else mixerLeaveTimer.restart()
                }
            }
        }
    }

    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch" || root.mainBarEdge !== "left") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: brightnessWindowLeft
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-brightness-left"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors {
                bottom: true
                left: true
            }
            margins {
                bottom: 14
                left: root.barMode === "notch" ? 38 : 54
            }

            implicitWidth: brightnessItemLeft.implicitWidth
            implicitHeight: brightnessItemLeft.implicitHeight + 20

            visible: (root.brightnessOpen || brightnessItemLeft.animatingOut) && root.mainBarEdge === "left"

            mask: Region {
                item: (root.brightnessOpen || brightnessItemLeft.animatingOut) ? brightnessItemLeft : null
                x: 0; y: 0
                width: (root.brightnessOpen || brightnessItemLeft.animatingOut) ? brightnessItemLeft.implicitWidth : 0
                height: (root.brightnessOpen || brightnessItemLeft.animatingOut) ? brightnessItemLeft.implicitHeight + 20 : 0
            }

            BrightnessPopup {
                id: brightnessItemLeft
                barEdge: "left"
                open: root.brightnessOpen
                onCloseRequested: root.closeBrightness()
                onAnyHoverChanged: {
                    root.brightnessHovered = brightnessItemLeft.anyHover
                    if (root.brightnessHovered) brightnessLeaveTimer.stop()
                    else brightnessLeaveTimer.restart()
                }
            }
        }
    }

    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch" || root.mainBarEdge !== "left") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: batteryWindowLeft
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-battery-left"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors {
                bottom: true
                left: true
            }
            margins {
                bottom: 14
                left: root.barMode === "notch" ? 38 : 54
            }

            implicitWidth: batteryItemLeft.implicitWidth
            implicitHeight: batteryItemLeft.implicitHeight + 20

            visible: (root.batteryOpen || batteryItemLeft.animatingOut) && root.mainBarEdge === "left"

            mask: Region {
                item: (root.batteryOpen || batteryItemLeft.animatingOut) ? batteryItemLeft : null
                x: 0; y: 0
                width: (root.batteryOpen || batteryItemLeft.animatingOut) ? batteryItemLeft.implicitWidth : 0
                height: (root.batteryOpen || batteryItemLeft.animatingOut) ? batteryItemLeft.implicitHeight + 20 : 0
            }

            BatteryPopup {
                id: batteryItemLeft
                barEdge: "left"
                open: root.batteryOpen
                onHoveredChanged: {
                    root.batteryHovered = batteryItemLeft.hovered
                    if (root.batteryHovered) batteryLeaveTimer.stop()
                    else batteryLeaveTimer.restart()
                }
            }
        }
    }

    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch" || root.mainBarEdge !== "left") ? [] : (Quickshell.screens.length > 0 ? [Quickshell.screens[0]] : [])

        PanelWindow {
            id: trayWindowLeft
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-tray-left"
            WlrLayershell.layer: WlrLayer.Overlay
            exclusionMode: ExclusionMode.Ignore
            anchors {
                bottom: true
                left: true
            }
            margins {
                bottom: 14
                left: root.barMode === "notch" ? 38 : 54
            }

            implicitWidth: trayItemLeft.implicitWidth
            implicitHeight: trayItemLeft.implicitHeight + 20

            visible: (root.trayOpen || trayItemLeft.animatingOut) && root.mainBarEdge === "left"

            mask: Region {
                item: (root.trayOpen || trayItemLeft.animatingOut) ? trayItemLeft : null
                x: 0; y: 0
                width: (root.trayOpen || trayItemLeft.animatingOut) ? trayItemLeft.implicitWidth : 0
                height: (root.trayOpen || trayItemLeft.animatingOut) ? trayItemLeft.implicitHeight + 20 : 0
            }

            TrayPopup {
                id: trayItemLeft
                barEdge: "left"
                open: root.trayOpen
                onHoveredChanged: {
                    root.trayHovered = trayItemLeft.hovered
                    if (root.trayHovered) trayLeaveTimer.stop()
                    else trayLeaveTimer.restart()
                }
                onRequestedClose: root.closeTray()
            }
        }
    }
    /* Power menu */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch" || !root.powerOpen) ? [] : Quickshell.screens

        PanelWindow {
            id: powerWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-power"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.powerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.powerOpen

            PowerMenu {
                anchors.fill: parent
                open: root.powerOpen
                onRequestClose: root.closePower()
                onRequestLock: {
                    root.closePower()
                    sessionLock.lock()
                }
            }
        }
    }

    /* Workspaces Overview */
    Variants {
        model: (root.barMode === "minimal" || root.barMode === "minimal_notch" || !root.overviewOpen) ? [] : Quickshell.screens

        PanelWindow {
            id: overviewWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-overview"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            anchors { top: true; left: true; right: true; bottom: true }

            aboveWindows: true
            visible: root.overviewOpen

            OverviewMod {
                anchors.fill: parent
                open: root.overviewOpen
                onRequestClose: root.closeOverview()
            }
        }
    }


    /* Quick-settings panel: DECOMMISSIONED - folded into Center Notch Settings Mode (notchPage == -1) */
    Variants {
        model: []

        PanelWindow {
            id: controlsWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-controls"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            visible: (root.controlsVisible || controlsItem.animatingOut) && root.barMode !== "nucleus"

            Item {
                anchors.fill: parent
                focus: root.controlsVisible
                Keys.enabled: root.controlsVisible
                Keys.onEscapePressed: event => {
                    if (controlsItem.audioPopupOpen) {
                        controlsItem.audioPopupOpen = false
                        event.accepted = true
                    } else if (controlsItem.btPopupOpen) {
                        controlsItem.btPopupOpen = false
                        event.accepted = true
                    } else if (controlsItem.wifiPopupOpen) {
                        controlsItem.wifiPopupOpen = false
                        event.accepted = true
                    } else {
                        root.closeControls()
                        event.accepted = true
                    }
                }

                /* Outside click-absorber: clicking outside the panel closes it */
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.closeControls()
                }

                ControlHub {
                    id: controlsItem
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    y: root.mainBarEdge === "bottom" ? 14 : (parent.height - height - 14)
                    corner: root.mainBarEdge === "bottom" ? "top_right" : "bottom_right"
                    width: controlsItem.implicitWidth
                    height: controlsItem.implicitHeight
                    open: root.controlsVisible
                    batteryLayout: root.batteryLayout
                    showBatteryPercent: root.showBatteryPercent
                    shellOpacity: root.shellOpacity
                    server: notificationServer
                    Component.onCompleted: root.controlsItem = controlsItem
                    onHoveredChanged: {
                        root.controlsHovered = controlsItem.hovered
                        if (controlsItem.hovered) {
                            controlsLeaveTimer.stop()
                        } else {
                            controlsLeaveTimer.restart()
                        }
                    }
                }
            }
        }
    }

    /* Hot Corner Trigger for ControlHub - DECOMMISSIONED */
    Variants {
        model: []

        PanelWindow {
            id: controlHubTriggerWindow
            required property var modelData
            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-controls-trigger"
            WlrLayershell.layer: WlrLayer.Top
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors {
                top: root.mainBarEdge === "bottom"
                bottom: root.mainBarEdge !== "bottom"
                right: true
            }

            implicitWidth: 48
            implicitHeight: 48
            visible: !GlobalState.isFocusActive

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                enabled: !GlobalState.isFocusActive
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    root.openControls()
                }
                onExited: {
                    if (!root.controlsPinned) {
                        controlsLeaveTimer.restart()
                    }
                }
            }
        }
    }


    /* Vanish Workspace OSD */
    Variants {
        model: (root.barMode === "nucleus" || root.barMode === "vanish") ? Quickshell.screens : []

        PanelWindow {
            id: workspaceOsdWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-workspace-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
            }
            margins {
                top: 16
            }
            implicitWidth: 96
            implicitHeight: 72

            visible: (root.barMode === "nucleus" || root.barMode === "vanish") && (wsOsdItem.active || wsOsdItem.opacity > 0.002)

            // Empty region mask ensures 100% mouse click & touch pass-through to underlying windows!
            mask: Region {}

            WorkspaceOsd {
                id: wsOsdItem
                anchors.centerIn: parent
                barMode: root.barMode
                showWorkspaceOsd: root.showWorkspaceOsd
                onActiveChanged: root.workspaceOsdActive = wsOsdItem.active
            }
        }
    }

    /* Notification Toast (Disabled: Replaced by Center Notch ticker & Spatial Canvas log) */
    Variants {
        model: []

        PanelWindow {
            id: toastWindow
            required property var modelData

            screen: modelData
            color: "transparent"
            WlrLayershell.namespace: "carbon-notification-toast"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true

            anchors {
                top: true
                right: root.barMode !== "nucleus"
            }

            margins {
                top: (root.barMode === "nucleus")
                    ? Math.round((toastWindow.screen.height / 2) + 226 - (toastItemComp.implicitHeight / 2))
                    : 24
                right: 24
            }

            implicitWidth: toastItemComp.implicitWidth
            implicitHeight: toastItemComp.implicitHeight
            visible: (toastItemComp.active || toastItemComp.opacity > 0.005) && !(root.nucleusHubItem && root.nucleusHubItem.notifPanelOpen)

            NotificationToast {
                id: toastItemComp
                panelOpen: root.nucleusHubItem ? root.nucleusHubItem.notifPanelOpen : false
            }
        }
    }

    /* Screenshot Freeze Overlay */
    Variants {
        model: (root.screenshotFreezeActive && root.screenshotFreezePath.length > 0) ? Quickshell.screens : []

        PanelWindow {
            id: screenshotFreezeWindow
            required property var modelData
            screen: modelData
            color: "#000000"
            visible: root.screenshotFreezeActive && root.screenshotFreezePath.length > 0
            WlrLayershell.namespace: "carbon-screenshot-freeze"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: true
            anchors { top: true; bottom: true; left: true; right: true }

            Image {
                anchors.fill: parent
                source: (root.screenshotFreezeActive && root.screenshotFreezePath.length > 0) ? ("file://" + root.screenshotFreezePath) : ""
                fillMode: Image.PreserveAspectFit
                cache: false
                asynchronous: false
            }
        }
    }
}