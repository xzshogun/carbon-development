import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "../components"
import "../Singletons"

/**
 * Carbon Control Center (Quick Settings)
 *
 * Precision Desktop Workstation Control Panel matching Center Dashboard styling:
 *   - Visual Theme: Theme.bg with shellOpacity, ambient glowing blobs, and CenterDashboard bezier curves
 *   - Header: Live clock/date, Screenshot, Settings, Lock, and Power shortcuts
 *   - Tab Bar: Swift Options, Tasks, Power (Battery), Calendar
 *   - Mode 0 (Swift Options):
 *       - Desktop Dock Row (Icons only, no names): Wi-Fi, Bluetooth, Microphone, Night Light, Game Mode, Do Not Disturb
 *       - Detail Menus: Wi-Fi & Bluetooth open the dedicated Vanish Mode Orbit Picker
 *       - Hardware Sliders: Volume, Brightness, and Night Light Warmth
 *       - Media Player: Compact now-playing card with album art, title, artist, seekable progress, and playback controls
 *   - Mode 1 (Tasks): Native Todo list pane
 *   - Mode 2 (Power): Hero Battery telemetry & 4 Power Profiles (Power Saving, Balance, Performance, Ultra [Game Mode])
 *   - Mode 3 (Calendar): Interactive Month Grid with month navigation and day selector
 */
Item {
    id: root

    property bool open: false
    property bool hovered: false
    property int mode: 0            // 0: Swift, 1: Tasks, 2: Power, 3: Calendar
    property string corner: "top_right"
    property real shellOpacity: Theme.shellOpacity
    readonly property string home: Quickshell.env("HOME") || ""

    // Notification server reference preserved for backward compatibility
    property var server: null

    /* ── Panel Dimensions ── */
    readonly property int paneW: 360
    readonly property int paneH: 284
    readonly property int cardW: root.paneW + 24
    readonly property int cardH: root.paneH + 96
    implicitWidth: root.cardW
    implicitHeight: root.cardH
    width: root.implicitWidth
    height: root.implicitHeight

    readonly property var cardItem: card
    readonly property bool animatingOut: !root.open && card.opacity > 0.001

    function paneX(idx) { return (idx - root.mode) * root.paneW }

    /* ============================ MPRIS Media ============================ */
    readonly property var players: Mpris.players.values !== undefined
        ? Mpris.players.values : Mpris.players
    property var activePlayer: null
    property string trackTitle: ""
    property string trackArtist: ""
    property string artUrl: ""
    property bool playing: false
    property bool canPrev: false
    property bool canNext: false
    property bool posSupported: false
    property double posUs: 0
    property double lenUs: 0
    property real progRatio: root.lenUs > 0
        ? Math.max(0, Math.min(1, root.posUs / root.lenUs)) : 0

    function resolveActivePlayer() {
        if (!root.players || root.players.length === 0)
            return null
        for (let i = 0; i < root.players.length; i++)
            if (root.players[i].playbackState === MprisPlaybackState.Playing)
                return root.players[i]
        for (let i = 0; i < root.players.length; i++)
            if (root.players[i].playbackState === MprisPlaybackState.Paused
                && (root.players[i].trackTitle || "").length > 0)
                return root.players[i]
        return root.players[0]
    }

    function syncPlayer() {
        const p = root.resolveActivePlayer()
        root.activePlayer = p
        root.trackTitle = p ? String(p.trackTitle || "") : ""
        root.trackArtist = (p && p.metadata && p.metadata["xesam:artist"]) ? String(p.metadata["xesam:artist"]) : ""
        root.artUrl = p && p.metadata ? String(p.metadata["mpris:artUrl"] || "") : ""
        root.playing = !!p && p.playbackState === MprisPlaybackState.Playing
        root.canPrev = !!p && p.canGoPrevious
        root.canNext = !!p && p.canGoNext
        root.posSupported = !!p && p.positionSupported
        root.posUs = p ? p.position : 0
        root.lenUs = p ? p.length : 0
    }

    Timer {
        id: progTick
        interval: 200
        repeat: true
        running: root.open && root.playing && root.lenUs > 0
        onTriggered: {
            if (root.posUs + 200000 <= root.lenUs) root.posUs += 200000
        }
    }

    Timer {
        id: playerProbe
        interval: 800
        repeat: true
        running: root.open
        onTriggered: root.syncPlayer()
    }

    function togglePlayPause() {
        if (root.activePlayer) root.activePlayer.togglePlaying()
    }

    function seekToRatio(r) {
        if (root.lenUs <= 0) return
        const clamped = Math.max(0, Math.min(1, r))
        root.posUs = clamped * root.lenUs
        const targetSec = root.posUs / 1000000.0
        try {
            if (root.activePlayer) root.activePlayer.position = root.posUs
        } catch (e) {}
        Quickshell.execDetached(["playerctl", "position", targetSec.toFixed(2)])
        if (root.activePlayer && root.activePlayer.positionSupported) {
            root.activePlayer.positionChanged()
        }
    }

    /* ============================ Audio (Pipewire) ============================ */
    readonly property var audioSink: Pipewire.defaultAudioSink
    readonly property real volRatio: (audioSink && audioSink.audio) ? Math.max(0, Math.min(1.0, audioSink.audio.volume)) : 0.0
    readonly property bool isMuted: (audioSink && audioSink.audio) ? audioSink.audio.muted : false

    /* ============================ Display Brightness ============================ */
    property real brightRatio: 0.5
    property real brightMax: 1
    property real lastBrightWrite: 0

    Process {
        id: brightProbe
        command: ["sh", "-c", 'echo "a b c $(brightnessctl --class backlight get) $(brightnessctl --class backlight max)"']
        stdout: SplitParser {
            onRead: data => {
                const tokens = data.trim().split(/\s+/)
                if (tokens.length < 2) return
                const cur = parseFloat(tokens[tokens.length - 2])
                const mx = parseFloat(tokens[tokens.length - 1])
                if (isNaN(cur) || isNaN(mx) || mx <= 0) return
                root.brightMax = mx
                root.brightRatio = Math.max(0.05, Math.min(1.0, cur / mx))
            }
        }
    }

    function refreshBrightness() {
        if (!brightProbe.running) brightProbe.running = true
    }

    function setBrightness(v) {
        root.brightRatio = Math.max(0.05, Math.min(1.0, v))
        root.lastBrightWrite = Date.now()
        Quickshell.execDetached(["brightnessctl", "--class", "backlight", "s",
            String(Math.round(root.brightRatio * root.brightMax)), "--quiet"])
    }

    Timer {
        interval: 3000
        repeat: true
        running: root.open
        onTriggered: {
            if (Date.now() - root.lastBrightWrite > 1500)
                root.refreshBrightness()
        }
    }

    /* ============================ Night Light Warmth ============================ */
    property real nightRatio: 0.5
    Process {
        id: nightWarmthProbe
        command: [root.home + "/.config/hypr/scripts/carbon-night.sh", "get"]
        stdout: StdioCollector { id: nightWarmthC; waitForEnd: true }
        onExited: {
            const val = parseFloat(String(nightWarmthC.text).trim())
            if (!isNaN(val) && val >= 0) {
                root.nightRatio = Math.max(0.05, Math.min(1.0, val / 100.0))
            }
        }
    }

    function setNightWarmth(r) {
        root.nightRatio = Math.max(0.05, Math.min(1.0, r))
        const pct = Math.round(root.nightRatio * 100)
        Quickshell.execDetached([root.home + "/.config/hypr/scripts/carbon-night.sh", "set", String(pct)])
    }

    /* ============================ Quick Toggles ============================ */
    property bool btOn: false
    property bool wifiOn: true
    property bool micMuted: false
    property bool nightAvailable: true
    property bool nightOn: false
    property bool gameModeOn: false
    property bool dndOn: false
    property string wifiName: ""
    property string btName: ""
    property bool wifiPopupOpen: false
    property bool btPopupOpen: false
    property bool audioPopupOpen: false

    Timer {
        id: settleTimer
        interval: 800
        onTriggered: root.refreshStates()
    }

    function refreshStates() {
        if (!root.open) return
        if (!btProbe.running) btProbe.running = true
        if (!wifiProbe.running) wifiProbe.running = true
        if (!nightProbe.running) nightProbe.running = true
        if (!nightWarmthProbe.running) nightWarmthProbe.running = true
        if (!dndProbe.running) dndProbe.running = true
        if (!micProbe.running) micProbe.running = true
        if (!gameModeProbe.running) gameModeProbe.running = true
        if (!btNameProbe.running) btNameProbe.running = true
        if (!wifiNameProbe.running) wifiNameProbe.running = true
        if (!powerProfileGetProc.running) powerProfileGetProc.running = true
        root.refreshBrightness()
    }

    /* Bluetooth */
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
    function toggleBt() {
        root.btOn = !root.btOn
        if (!root.btOn) root.btName = ""
        Quickshell.execDetached(["sh", "-c",
            "bluetoothctl power " + (root.btOn ? "on" : "off") + " >/dev/null 2>&1"])
        settleTimer.restart()
    }
    function openBtDetails() {
        root.wifiPopupOpen = false
        root.audioPopupOpen = false
        root.btPopupOpen = true
        if (vanishPicker) vanishPicker.openBluetooth()
    }

    /* Wi-Fi */
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
    function toggleWifi() {
        root.wifiOn = !root.wifiOn
        if (!root.wifiOn) root.wifiName = ""
        Quickshell.execDetached(["sh", "-c",
            "nmcli radio wifi " + (root.wifiOn ? "on" : "off") + " >/dev/null 2>&1"])
        settleTimer.restart()
    }
    function openWifiDetails() {
        root.btPopupOpen = false
        root.audioPopupOpen = false
        root.wifiPopupOpen = true
        if (vanishPicker) vanishPicker.openWifi()
    }
    function openAudioDetails() {
        root.wifiPopupOpen = false
        root.btPopupOpen = false
        root.audioPopupOpen = true
        if (audioPicker) audioPicker.refreshAll()
    }

    /* Microphone */
    Process {
        id: micProbe
        command: ["sh", "-c", "pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null | grep -qi 'yes' && echo true || echo false"]
        stdout: StdioCollector { id: micC; waitForEnd: true }
        onExited: root.micMuted = String(micC.text).trim() === "true"
    }
    function toggleMic() {
        root.micMuted = !root.micMuted
        Quickshell.execDetached(["pactl", "set-source-mute", "@DEFAULT_SOURCE@", "toggle"])
        settleTimer.restart()
    }

    /* Night light */
    Process {
        id: nightProbe
        command: [root.home + "/.config/hypr/scripts/carbon-night.sh", "status"]
        stdout: StdioCollector { id: nightC; waitForEnd: true }
        onExited: {
            const v = String(nightC.text).trim()
            root.nightAvailable = v !== "missing"
            root.nightOn = v === "on"
        }
    }
    function toggleNight() {
        if (!root.nightAvailable) return
        root.nightOn = !root.nightOn
        Quickshell.execDetached([root.home + "/.config/hypr/scripts/carbon-night.sh", root.nightOn ? "on" : "off"])
        settleTimer.restart()
    }

    /* Game Mode */
    Process {
        id: gameModeProbe
        command: ["sh", "-c", "if [ -f \"${XDG_RUNTIME_DIR:-/tmp}/hypr_gamemode_state.json\" ]; then echo true; else echo false; fi"]
        stdout: StdioCollector { id: gameModeC; waitForEnd: true }
        onExited: root.gameModeOn = String(gameModeC.text).trim() === "true"
    }
    function toggleGameMode() {
        root.gameModeOn = !root.gameModeOn
        Quickshell.execDetached([root.home + "/.local/bin/hypr-gamemode", "toggle"])
        settleTimer.restart()
    }

    /* Do Not Disturb */
    Process {
        id: dndProbe
        command: ["sh", "-c", "if [ -f /tmp/carbon-dnd.on ]; then echo true; else echo false; fi"]
        stdout: StdioCollector { id: dndC; waitForEnd: true }
        onExited: {
            root.dndOn = String(dndC.text).trim() === "true"
            Theme.dnd = root.dndOn
        }
    }
    function toggleDnd() {
        root.dndOn = !root.dndOn
        Theme.dnd = root.dndOn
        Quickshell.execDetached(["sh", "-c",
            root.dndOn ? "touch /tmp/carbon-dnd.on" : "rm -f /tmp/carbon-dnd.on"])
        settleTimer.restart()
    }

    /* Clock & Date Header */
    property string timeStr: Qt.formatTime(new Date(), "hh:mm")
    property string dateStr: Qt.formatDate(new Date(), "ddd, MMM d")

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date()
            root.timeStr = Qt.formatTime(now, "hh:mm")
            root.dateStr = Qt.formatDate(now, "ddd, MMM d")
        }
    }

    /* ============================ Battery & Power Profiles ============================ */
    property string batteryLayout: "horizontal"
    property bool showBatteryPercent: true
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery ? battery.isPresent : false
    readonly property real batteryPct: battery ? battery.percentage : 1.0
    readonly property int batteryState: battery ? battery.state : UPowerDeviceState.FullyCharged
    readonly property bool isCharging: batteryState === UPowerDeviceState.Charging
    readonly property bool isFull: batteryState === UPowerDeviceState.FullyCharged || root.batteryPct >= 0.99
    property real animatedBatteryPct: root.batteryPct
    Behavior on animatedBatteryPct { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

    readonly property color batteryStatusColor: {
        if (root.isCharging) return Theme.accentLit
        if (root.batteryPct < 0.20) return Theme.err
        if (root.batteryPct < 0.40) return Theme.warn
        return Theme.accent
    }

    FileView {
        id: qsBarModeFile
        path: root.home + "/.config/carbon/carbon-bar-mode.json"
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.loadBatteryLayout()
        onFileChanged: root.loadBatteryLayout()
    }

    function loadBatteryLayout() {
        try {
            qsBarModeFile.reload()
            const txt = qsBarModeFile.text().trim()
            if (txt.length > 0) {
                const d = JSON.parse(txt)
                if (d.batteryLayout) {
                    root.batteryLayout = String(d.batteryLayout).toLowerCase()
                }
            }
        } catch (e) {}
    }

    readonly property string batteryTimeStr: {
        if (root.isFull) return "Fully Charged"
        if (root.isCharging) {
            if (battery && battery.timeToFull > 0) {
                const hrs = Math.floor(battery.timeToFull / 3600)
                const mins = Math.floor((battery.timeToFull % 3600) / 60)
                return hrs > 0 ? (hrs + "h " + mins + "m until full") : (mins + "m until full")
            }
            return "Charging..."
        }
        if (battery && battery.timeToEmpty > 0) {
            const hrs = Math.floor(battery.timeToEmpty / 3600)
            const mins = Math.floor((battery.timeToEmpty % 3600) / 60)
            return hrs > 0 ? (hrs + "h " + mins + "m remaining") : (mins + "m remaining")
        }
        return "On Battery"
    }

    readonly property string batteryIconGlyph: {
        if (root.isCharging) return "battery_charging_full"
        if (root.batteryPct >= 0.95) return "battery_full"
        if (root.batteryPct >= 0.80) return "battery_6_bar"
        if (root.batteryPct >= 0.60) return "battery_5_bar"
        if (root.batteryPct >= 0.40) return "battery_4_bar"
        if (root.batteryPct >= 0.20) return "battery_2_bar"
        if (root.batteryPct >= 0.10) return "battery_1_bar"
        return "battery_alert"
    }

    property string powerProfile: "balanced"
    Process {
        id: powerProfileGetProc
        command: [root.home + "/.config/hypr/scripts/carbon-power-profile.sh", "get"]
        stdout: StdioCollector { id: powerProfileC; waitForEnd: true }
        onExited: {
            const p = String(powerProfileC.text).trim()
            if (p.length > 0) root.powerProfile = p
        }
    }

    function setPowerProfile(modeName) {
        root.powerProfile = modeName
        Quickshell.execDetached([root.home + "/.config/hypr/scripts/carbon-power-profile.sh", "set", modeName])
        if (modeName === "ultra") {
            root.gameModeOn = true
        } else {
            root.gameModeOn = false
        }
        settleTimer.restart()
    }

    /* ============================ Calendar State ============================ */
    property var calCurrentDate: new Date()
    property int calYear: calCurrentDate.getFullYear()
    property int calMonth: calCurrentDate.getMonth() // 0-11
    property int selectedDay: calCurrentDate.getDate()

    readonly property var monthNames: [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
    ]

    function prevMonth() {
        if (root.calMonth === 0) {
            root.calMonth = 11
            root.calYear--
        } else {
            root.calMonth--
        }
    }

    function nextMonth() {
        if (root.calMonth === 11) {
            root.calMonth = 0
            root.calYear++
        } else {
            root.calMonth++
        }
    }

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate()
    }

    function firstDayWeekday(y, m) {
        let d = new Date(y, m, 1).getDay()
        return d === 0 ? 6 : d - 1
    }

    onOpenChanged: {
        if (root.open) {
            root.syncPlayer()
            root.refreshStates()
            root.calCurrentDate = new Date()
            root.calMonth = root.calCurrentDate.getMonth()
            root.calYear = root.calCurrentDate.getFullYear()
            root.selectedDay = root.calCurrentDate.getDate()
        } else {
            root.wifiPopupOpen = false
            root.btPopupOpen = false
            root.audioPopupOpen = false
            if (vanishPicker) vanishPicker.resetPicker()
        }
    }

    onWifiPopupOpenChanged: {
        if (!root.wifiPopupOpen && !root.btPopupOpen && vanishPicker) {
            vanishPicker.resetPicker()
        }
    }

    onBtPopupOpenChanged: {
        if (!root.wifiPopupOpen && !root.btPopupOpen && vanishPicker) {
            vanishPicker.resetPicker()
        }
    }

    Component.onCompleted: {
        root.refreshStates()
    }

    /* ============================ Visual Card Container ============================ */
    Item {
        id: card
        width: root.cardW
        height: root.cardH
        clip: true

        /* Dead-zone click absorber inside card boundary so clicks never fall through */
        MouseArea {
            anchors.fill: parent
            z: 0
        }

        // Shape matching CenterDashboard.qml identically
        Shape {
            id: cardBgShape
            anchors.fill: parent
            layer.enabled: true
            layer.smooth: true
            preferredRendererType: Shape.CurveRenderer

            // 1. Fill background (CenterDashboard exact theme)
            ShapePath {
                fillColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, root.shellOpacity)
                strokeColor: "transparent"
                strokeWidth: 0
                startX: 20; startY: 0
                PathLine { x: card.width - 20; y: 0 }
                PathArc { x: card.width; y: 20; radiusX: 20; radiusY: 20 }
                PathLine { x: card.width; y: card.height - 20 }
                PathArc { x: card.width - 20; y: card.height; radiusX: 20; radiusY: 20 }
                PathLine { x: 20; y: card.height }
                PathArc { x: 0; y: card.height - 20; radiusX: 20; radiusY: 20 }
                PathLine { x: 0; y: 20 }
                PathArc { x: 20; y: 0; radiusX: 20; radiusY: 20 }
            }

            // 2. Continuous stroke (CenterDashboard exact stroke)
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.open ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.45) : Theme.outline
                strokeWidth: 1.0
                startX: 20; startY: 0
                PathLine { x: card.width - 20; y: 0 }
                PathArc { x: card.width; y: 20; radiusX: 20; radiusY: 20 }
                PathLine { x: card.width; y: card.height - 20 }
                PathArc { x: card.width - 20; y: card.height; radiusX: 20; radiusY: 20 }
                PathLine { x: 20; y: card.height }
                PathArc { x: 0; y: card.height - 20; radiusX: 20; radiusY: 20 }
                PathLine { x: 0; y: 20 }
                PathArc { x: 20; y: 0; radiusX: 20; radiusY: 20 }
            }
        }

        /* Ambient subtle color blobs from CenterDashboard */
        Rectangle {
            width: parent.width * 0.55; height: width; radius: width / 2
            x: parent.width * 0.65 - width / 2
            y: parent.height * 0.25 - height / 2
            opacity: 0.03
            color: Theme.accentLit
        }
        Rectangle {
            width: parent.width * 0.45; height: width; radius: width / 2
            x: parent.width * 0.25 - width / 2
            y: parent.height * 0.75 - height / 2
            opacity: 0.02
            color: Theme.accent
        }

        transformOrigin: (root.corner === "top_right") ? Item.TopRight :
                         ((root.corner === "top_center" || root.corner === "center") ? Item.Top :
                         (root.corner === "bottom_center" ? Item.Bottom :
                         (root.corner === "top_left" ? Item.TopLeft :
                         (root.corner === "bottom_left" ? Item.BottomLeft : Item.BottomRight))))

        x: (root.corner === "top_center" || root.corner === "center" || root.corner === "bottom_center") ? 0 :
           ((root.corner === "top_left" || root.corner === "bottom_left") ? (root.open ? 0 : -14) : (root.open ? 0 : 14))
        y: (root.corner === "top_right" || root.corner === "top_center" || root.corner === "center" || root.corner === "top_left") ? (root.open ? 0 : -14) :
           (root.corner === "bottom_center" ? (root.open ? 0 : 12) : (root.open ? 0 : 14))
        scale: root.open ? 1.0 : 0.97
        opacity: root.open ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation {
                duration: root.open ? 180 : 140
                easing.bezierCurve: Theme.animCurves.expressiveDefaultEffects
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: root.open ? 240 : 160
                easing.bezierCurve: root.open ? Theme.animCurves.expressiveDefaultSpatial : Theme.animCurves.standardAccel
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: root.open ? 240 : 160
                easing.bezierCurve: root.open ? Theme.animCurves.expressiveDefaultSpatial : Theme.animCurves.standardAccel
            }
        }

        HoverHandler {
            onHoveredChanged: root.hovered = hovered
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            z: 1
            opacity: (root.wifiPopupOpen || root.btPopupOpen || root.audioPopupOpen) ? 0.0 : 1.0
            visible: opacity > 0.0
            enabled: !root.wifiPopupOpen && !root.btPopupOpen && !root.audioPopupOpen
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            /* ── Header: Clock & Action Shortcuts (Screen recorder removed) ── */
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                spacing: 5

                // Clock & Date
                RowLayout {
                    spacing: 5
                    Text {
                        text: root.timeStr
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(12)
                        font.weight: Font.Bold
                        color: Theme.fg
                    }
                    Text {
                        text: "· " + root.dateStr
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(8)
                        font.weight: Font.Medium
                        color: Theme.fgDim
                    }
                }

                Item { Layout.fillWidth: true }

                // Screenshot Button
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: shotMH.containsMouse ? Theme.accent : Theme.outline
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "photo_camera"
                        font.family: Theme.fontIcon
                        font.pixelSize: 13
                        color: shotMH.containsMouse ? Theme.accent : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: shotMH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached([root.home + "/.config/hypr/scripts/carbon-screenshot-region.sh"])
                        }
                    }
                }

                // Settings Button
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: setMH.containsMouse ? Theme.accent : Theme.outline
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "settings"
                        font.family: Theme.fontIcon
                        font.pixelSize: 13
                        color: setMH.containsMouse ? Theme.accent : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: setMH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["sh", root.home + "/.config/carbon/scripts/carbon-ipc.sh", "settings"])
                        }
                    }
                }

                // Lock Button
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: lockMH.containsMouse ? Theme.accent : Theme.outline
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "lock"
                        font.family: Theme.fontIcon
                        font.pixelSize: 13
                        color: lockMH.containsMouse ? Theme.accent : Theme.fgDim
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    MouseArea {
                        id: lockMH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached([root.home + "/.config/hypr/scripts/hyprlock.sh"])
                        }
                    }
                }

                // Power Button
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: pwrMH.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: pwrMH.containsMouse ? "#ff5555" : Theme.outline
                    Text {
                        anchors.centerIn: parent
                        text: "power_settings_new"
                        font.family: Theme.fontIcon
                        font.pixelSize: 13
                        color: pwrMH.containsMouse ? "#ff5555" : Theme.fgDim
                    }
                    MouseArea {
                        id: pwrMH
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Quickshell.execDetached(["sh", root.home + "/.config/carbon/scripts/carbon-ipc.sh", "power"])
                        }
                    }
                }
            }

            /* ── Header: Modern Slim Pill Tabs (Swift Options, Tasks, Power, Calendar) ── */
            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: 15
                color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)
                opacity: (root.wifiPopupOpen || root.btPopupOpen || root.audioPopupOpen) ? 0.0 : 1.0
                visible: opacity > 0.0
                enabled: !root.wifiPopupOpen && !root.btPopupOpen && !root.audioPopupOpen
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 3

                    Repeater {
                        model: [
                            { glyph: "tune", label: "Swift" },
                            { glyph: "checklist", label: "Tasks" },
                            { glyph: "battery_charging_full", label: "Power" },
                            { glyph: "calendar_month", label: "Calendar" }
                        ]
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 12
                            color: root.mode === index ? Theme.accent : "transparent"
                            border.width: 1
                            border.color: root.mode === index ? Theme.accent : (tabHov.hovered ? Theme.accent : "transparent")
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 3
                                Text {
                                    text: modelData.glyph
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 12
                                    color: root.mode === index ? (Theme.isDark ? "#101116" : "#ffffff") : Theme.fgDim
                                }
                                Text {
                                    text: modelData.label
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontPx(7.5)
                                    font.weight: root.mode === index ? Font.Bold : Font.Normal
                                    color: root.mode === index ? (Theme.isDark ? "#101116" : "#ffffff") : Theme.fgDim
                                }
                            }

                            MouseArea {
                                id: tabHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.mode = index
                            }
                        }
                    }
                }
            }

            /* ── Content Panes ── */
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.paneH
                clip: true
                opacity: (root.wifiPopupOpen || root.btPopupOpen || root.audioPopupOpen) ? 0.0 : 1.0
                visible: opacity > 0.0
                enabled: !root.wifiPopupOpen && !root.btPopupOpen && !root.audioPopupOpen
                Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                /* ==== Mode 0: Swift Options ==== */
                Item {
                    id: pane0
                    width: parent.width
                    height: parent.height
                    x: root.paneX(0)
                    opacity: root.mode === 0 ? 1 : 0
                    enabled: root.mode === 0
                    clip: true
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutCubic } }

                    ColumnLayout {
                        id: unifiedCol
                        width: parent.width
                        spacing: 8

                        /* ── Part 1: Quick Toggles (Desktop Dock Row: Icons Only) ── */
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            radius: 14
                            color: Theme.isDark ? Qt.rgba(0.08, 0.09, 0.12, 0.65) : Qt.rgba(0.95, 0.95, 0.97, 0.65)
                            border.width: 1
                            border.color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.07)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                // 1. Wi-Fi
                                Rectangle {
                                    id: wifiTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    scale: wifiMH.pressed ? 0.96 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    color: root.wifiOn
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                        : Qt.rgba(1, 1, 1, 0.03)
                                    border.width: 1.0
                                    border.color: root.wifiOn
                                        ? Theme.accentLit
                                        : (wifiMH.containsMouse ? Theme.accent : Theme.outline)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    // Expander indicator
                                    Text {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 3
                                        text: "arrow_drop_down"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 10
                                        color: wifiMH.containsMouse ? Theme.accentLit : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.35)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -2
                                        text: root.wifiOn ? "wifi" : "wifi_off"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 18
                                        color: root.wifiOn ? Theme.accent : Theme.fgDim
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    // Hardware Micro-LED Bar
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        width: root.wifiOn ? 12 : 5
                                        height: 2.5
                                        radius: 1.25
                                        color: root.wifiOn ? Theme.accentLit : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.20)
                                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: wifiMH
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                root.openWifiDetails()
                                            } else {
                                                root.toggleWifi()
                                            }
                                        }
                                    }

                                    ToolTip {
                                        visible: wifiMH.containsMouse
                                        delay: 350
                                        contentItem: Text {
                                            text: root.wifiOn
                                                ? ("Wi-Fi: " + (root.wifiName.length > 0 ? root.wifiName : "Connected"))
                                                : "Wi-Fi: Disconnected"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7.5)
                                            font.weight: Font.Medium
                                            color: Theme.fg
                                        }
                                        background: Rectangle {
                                            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
                                            border.width: 1
                                            border.color: Theme.accent
                                            radius: 6
                                        }
                                    }
                                }

                                // 2. Bluetooth
                                Rectangle {
                                    id: btTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    scale: btMH.pressed ? 0.96 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    color: root.btOn
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                        : Qt.rgba(1, 1, 1, 0.03)
                                    border.width: 1.0
                                    border.color: root.btOn
                                        ? Theme.accentLit
                                        : (btMH.containsMouse ? Theme.accent : Theme.outline)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 3
                                        text: "arrow_drop_down"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 10
                                        color: btMH.containsMouse ? Theme.accentLit : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.35)
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -2
                                        text: root.btOn ? "bluetooth" : "bluetooth_disabled"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 18
                                        color: root.btOn ? Theme.accent : Theme.fgDim
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    // Hardware Micro-LED Bar
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        width: root.btOn ? 12 : 5
                                        height: 2.5
                                        radius: 1.25
                                        color: root.btOn ? Theme.accentLit : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.20)
                                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: btMH
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                root.openBtDetails()
                                            } else {
                                                root.toggleBt()
                                            }
                                        }
                                    }

                                    ToolTip {
                                        visible: btMH.containsMouse
                                        delay: 350
                                        contentItem: Text {
                                            text: root.btOn
                                                ? ("Bluetooth: " + (root.btName.length > 0 ? root.btName : "Ready"))
                                                : "Bluetooth: Off"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7.5)
                                            font.weight: Font.Medium
                                            color: Theme.fg
                                        }
                                        background: Rectangle {
                                            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
                                            border.width: 1
                                            border.color: Theme.accent
                                            radius: 6
                                        }
                                    }
                                }

                                // 3. Microphone
                                Rectangle {
                                    id: micTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    scale: micMH.pressed ? 0.96 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    color: !root.micMuted
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                        : Qt.rgba(1, 1, 1, 0.03)
                                    border.width: 1.0
                                    border.color: !root.micMuted
                                        ? Theme.accentLit
                                        : (micMH.containsMouse ? Theme.accent : Theme.outline)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -2
                                        text: root.micMuted ? "mic_off" : "mic"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 18
                                        color: root.micMuted ? "#ff6b6b" : Theme.accent
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    // Hardware Micro-LED Bar
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        width: !root.micMuted ? 12 : 5
                                        height: 2.5
                                        radius: 1.25
                                        color: root.micMuted ? "#ff6b6b" : Theme.accentLit
                                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: micMH
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleMic()
                                    }

                                    ToolTip {
                                        visible: micMH.containsMouse
                                        delay: 350
                                        contentItem: Text {
                                            text: root.micMuted ? "Microphone: Muted" : "Microphone: Live (Active)"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7.5)
                                            font.weight: Font.Medium
                                            color: Theme.fg
                                        }
                                        background: Rectangle {
                                            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
                                            border.width: 1
                                            border.color: Theme.accent
                                            radius: 6
                                        }
                                    }
                                }

                                // 4. Night Light
                                Rectangle {
                                    id: nightTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    scale: nightMH.pressed ? 0.96 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    color: root.nightOn
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                        : Qt.rgba(1, 1, 1, 0.03)
                                    border.width: 1.0
                                    border.color: root.nightOn
                                        ? Theme.accentLit
                                        : (nightMH.containsMouse ? Theme.accent : Theme.outline)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -2
                                        text: root.nightOn ? "dark_mode" : "bedtime"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 18
                                        color: root.nightOn ? Theme.accent : Theme.fgDim
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    // Hardware Micro-LED Bar
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        width: root.nightOn ? 12 : 5
                                        height: 2.5
                                        radius: 1.25
                                        color: root.nightOn ? Theme.accentLit : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.20)
                                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: nightMH
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleNight()
                                    }

                                    ToolTip {
                                        visible: nightMH.containsMouse
                                        delay: 350
                                        contentItem: Text {
                                            text: root.nightOn ? "Night Light: Active" : "Night Light: Off"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7.5)
                                            font.weight: Font.Medium
                                            color: Theme.fg
                                        }
                                        background: Rectangle {
                                            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
                                            border.width: 1
                                            border.color: Theme.accent
                                            radius: 6
                                        }
                                    }
                                }

                                // 5. Game Mode
                                Rectangle {
                                    id: gameModeTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    scale: gameModeMH.pressed ? 0.96 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    color: root.gameModeOn
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                        : Qt.rgba(1, 1, 1, 0.03)
                                    border.width: 1.0
                                    border.color: root.gameModeOn
                                        ? Theme.accentLit
                                        : (gameModeMH.containsMouse ? Theme.accent : Theme.outline)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -2
                                        text: root.gameModeOn ? "sports_esports" : "videogame_asset"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 18
                                        color: root.gameModeOn ? Theme.accent : Theme.fgDim
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    // Hardware Micro-LED Bar
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        width: root.gameModeOn ? 12 : 5
                                        height: 2.5
                                        radius: 1.25
                                        color: root.gameModeOn ? Theme.accentLit : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.20)
                                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: gameModeMH
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleGameMode()
                                    }

                                    ToolTip {
                                        visible: gameModeMH.containsMouse
                                        delay: 350
                                        contentItem: Text {
                                            text: root.gameModeOn ? "Game Mode: Active (Direct Scanout)" : "Game Mode: Off"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7.5)
                                            font.weight: Font.Medium
                                            color: Theme.fg
                                        }
                                        background: Rectangle {
                                            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
                                            border.width: 1
                                            border.color: Theme.accent
                                            radius: 6
                                        }
                                    }
                                }

                                // 6. Do Not Disturb (DND)
                                Rectangle {
                                    id: dndTile
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 10
                                    scale: dndMH.pressed ? 0.96 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }
                                    color: root.dndOn
                                        ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                        : Qt.rgba(1, 1, 1, 0.03)
                                    border.width: 1.0
                                    border.color: root.dndOn
                                        ? Theme.accentLit
                                        : (dndMH.containsMouse ? Theme.accent : Theme.outline)
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: -2
                                        text: root.dndOn ? "notifications_off" : "notifications"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 18
                                        color: root.dndOn ? Theme.accent : Theme.fgDim
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    // Hardware Micro-LED Bar
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        width: root.dndOn ? 12 : 5
                                        height: 2.5
                                        radius: 1.25
                                        color: root.dndOn ? Theme.accentLit : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.20)
                                        Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        id: dndMH
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleDnd()
                                    }

                                    ToolTip {
                                        visible: dndMH.containsMouse
                                        delay: 350
                                        contentItem: Text {
                                            text: root.dndOn ? "Do Not Disturb: Active" : "Do Not Disturb: Off"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7.5)
                                            font.weight: Font.Medium
                                            color: Theme.fg
                                        }
                                        background: Rectangle {
                                            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.95)
                                            border.width: 1
                                            border.color: Theme.accent
                                            radius: 6
                                        }
                                    }
                                }
                            }
                        }

                        /* ── Part 2: Hardware Sliders (Volume, Brightness & Night Light Warmth) ── */
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 124
                            radius: 16
                            color: Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                            border.width: 1
                            border.color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                // 1. Volume Slider Row & Output Device Switcher
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 14

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 4

                                            Text {
                                                Layout.fillWidth: true
                                                text: {
                                                    if (!root.audioSink) return "Audio Output"
                                                    return String(root.audioSink.description || root.audioSink.name || "Default Output")
                                                }
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: Theme.fontPx(7.5)
                                                font.weight: Font.DemiBold
                                                color: devChipHov.containsMouse ? Theme.accent : Theme.fgDim
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: "Devices & Ports"
                                                font.family: "JetBrainsMono Nerd Font"
                                                font.pixelSize: Theme.fontPx(7.0)
                                                color: devChipHov.containsMouse ? Theme.accent : Qt.rgba(Theme.fgDim.r, Theme.fgDim.g, Theme.fgDim.b, 0.7)
                                            }

                                            Text {
                                                text: "chevron_right"
                                                font.family: Theme.fontIcon
                                                font.pixelSize: 12
                                                color: devChipHov.containsMouse ? Theme.accent : Theme.fgDim
                                            }
                                        }

                                        MouseArea {
                                            id: devChipHov
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.openAudioDetails()
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Rectangle {
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: "transparent"
                                            border.width: 1
                                            border.color: muteHov.containsMouse ? Theme.accent : "transparent"
                                            Behavior on border.color { ColorAnimation { duration: 120 } }
                                            Text {
                                                anchors.centerIn: parent
                                                text: root.isMuted ? "volume_off" : (root.volRatio <= 0.01 ? "volume_mute" : (root.volRatio < 0.5 ? "volume_down" : "volume_up"))
                                                font.family: Theme.fontIcon
                                                font.pixelSize: 15
                                                color: root.isMuted ? Theme.fgDim : Theme.accent
                                            }
                                            MouseArea {
                                                id: muteHov
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (root.audioSink && root.audioSink.audio) {
                                                        root.audioSink.audio.muted = !root.audioSink.audio.muted
                                                    }
                                                }
                                            }
                                        }

                                        Item {
                                            id: volTrack
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 16

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 8
                                                color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
                                            }

                                            Rectangle {
                                                height: parent.height
                                                width: Math.max(0, Math.min(parent.width, parent.width * (root.isMuted ? 0 : root.volRatio)))
                                                radius: 8
                                                color: root.isMuted ? Theme.fgFaint : Theme.accent
                                                Behavior on width {
                                                    enabled: !volArea.pressed
                                                    NumberAnimation { duration: 100 }
                                                }
                                            }

                                            MouseArea {
                                                id: volArea
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor

                                                function updateVol(mx) {
                                                    var r = Math.max(0, Math.min(1.0, mx / volTrack.width))
                                                    if (root.audioSink && root.audioSink.audio) {
                                                        root.audioSink.audio.volume = r
                                                        if (root.audioSink.audio.muted && r > 0) root.audioSink.audio.muted = false
                                                    }
                                                }

                                                onPressed: mouse => updateVol(mouse.x)
                                                onPositionChanged: mouse => { if (pressed) updateVol(mouse.x) }
                                            }

                                            WheelHandler {
                                                target: volTrack
                                                onWheel: (event) => {
                                                    var step = event.angleDelta.y > 0 ? 0.03 : -0.03
                                                    if (root.audioSink && root.audioSink.audio) {
                                                        root.audioSink.audio.volume = Math.max(0, Math.min(1.0, root.volRatio + step))
                                                        if (root.audioSink.audio.muted && step > 0) root.audioSink.audio.muted = false
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.preferredWidth: 28
                                            horizontalAlignment: Text.AlignRight
                                            text: Math.round((root.isMuted ? 0 : root.volRatio) * 100) + "%"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7.5)
                                            font.weight: Font.Bold
                                            color: Theme.fgDim
                                        }
                                    }
                                }

                                // 2. Brightness Slider Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "brightness_6"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 15
                                            color: Theme.accentLit
                                        }
                                    }

                                    Item {
                                        id: brightTrack
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 16

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
                                        }

                                        Rectangle {
                                            height: parent.height
                                            width: Math.max(0, Math.min(parent.width, parent.width * root.brightRatio))
                                            radius: 8
                                            color: Theme.accentLit
                                            Behavior on width {
                                                enabled: !brightArea.pressed
                                                NumberAnimation { duration: 100 }
                                            }
                                        }

                                        MouseArea {
                                            id: brightArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            function updateBright(mx) {
                                                var r = Math.max(0.05, Math.min(1.0, mx / brightTrack.width))
                                                root.setBrightness(r)
                                            }

                                            onPressed: mouse => updateBright(mouse.x)
                                            onPositionChanged: mouse => { if (pressed) updateBright(mouse.x) }
                                        }

                                        WheelHandler {
                                            target: brightTrack
                                            onWheel: (event) => {
                                                var step = event.angleDelta.y > 0 ? 0.05 : -0.05
                                                root.setBrightness(Math.max(0.05, Math.min(1.0, root.brightRatio + step)))
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 28
                                        horizontalAlignment: Text.AlignRight
                                        text: Math.round(root.brightRatio * 100) + "%"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(7.5)
                                        font.weight: Font.Bold
                                        color: Theme.fgDim
                                    }
                                }

                                // 3. Night Light Warmth Slider Row
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: "transparent"
                                        border.width: 1
                                        border.color: nightIconHov.containsMouse ? Theme.accent : "transparent"
                                        Behavior on border.color { ColorAnimation { duration: 120 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.nightOn ? "bedtime" : "nightlight"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 15
                                            color: root.nightOn ? "#ff9f43" : Theme.fgDim
                                        }
                                        MouseArea {
                                            id: nightIconHov
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.toggleNight()
                                        }
                                    }

                                    Item {
                                        id: nightTrack
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 16

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.10)
                                        }

                                        Rectangle {
                                            height: parent.height
                                            width: Math.max(0, Math.min(parent.width, parent.width * root.nightRatio))
                                            radius: 8
                                            color: "#ff9f43"
                                            Behavior on width {
                                                enabled: !nightArea.pressed
                                                NumberAnimation { duration: 100 }
                                            }
                                        }

                                        MouseArea {
                                            id: nightArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor

                                            function updateWarmth(mx) {
                                                var r = Math.max(0.05, Math.min(1.0, mx / nightTrack.width))
                                                root.setNightWarmth(r)
                                            }

                                            onPressed: mouse => updateWarmth(mouse.x)
                                            onPositionChanged: mouse => { if (pressed) updateWarmth(mouse.x) }
                                        }

                                        WheelHandler {
                                            target: nightTrack
                                            onWheel: (event) => {
                                                var step = event.angleDelta.y > 0 ? 0.05 : -0.05
                                                root.setNightWarmth(Math.max(0.05, Math.min(1.0, root.nightRatio + step)))
                                            }
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 28
                                        horizontalAlignment: Text.AlignRight
                                        text: Math.round(root.nightRatio * 100) + "%"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(7.5)
                                        font.weight: Font.Bold
                                        color: "#ff9f43"
                                    }
                                }
                            }
                        }

                        /* ── Part 3: Media Player Capsule ── */
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 74
                            radius: 16
                            color: Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                            border.width: 1
                            border.color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                // Album Art / Fallback
                                Rectangle {
                                    width: 44
                                    height: 44
                                    radius: 10
                                    clip: true
                                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.15)
                                    border.width: 1
                                    border.color: Theme.outline

                                    Image {
                                        id: artImg
                                        anchors.fill: parent
                                        sourceSize: Qt.size(80, 80)
                                        fillMode: Image.PreserveAspectCrop
                                        source: root.artUrl
                                        visible: root.artUrl.length > 0 && status === Image.Ready
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: !artImg.visible
                                        text: "music_note"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 22
                                        color: Theme.accent
                                    }
                                }

                                // Track Info & Progress
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.trackTitle.length > 0 ? root.trackTitle : "No Media Playing"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(9)
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.trackArtist.length > 0 ? root.trackArtist : (root.activePlayer ? "Standby" : "Idle")
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(7.5)
                                        color: Theme.fgDim
                                        elide: Text.ElideRight
                                    }

                                    // Progress Track
                                    Item {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 4
                                        visible: root.lenUs > 0

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 2
                                            color: Qt.rgba(1, 1, 1, 0.10)
                                        }

                                        Rectangle {
                                            height: parent.height
                                            width: Math.max(0, Math.min(parent.width, parent.width * root.progRatio))
                                            radius: 2
                                            color: Theme.accent
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: mouse => root.seekToRatio(mouse.x / width)
                                        }
                                    }
                                }

                                // Playback Controls
                                RowLayout {
                                    spacing: 2

                                    Rectangle {
                                        width: 26
                                        height: 26
                                        radius: 13
                                        color: "transparent"
                                        border.width: 1
                                        border.color: prevBtnHov.containsMouse ? Theme.accent : "transparent"
                                        Behavior on border.color { ColorAnimation { duration: 120 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "skip_previous"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 16
                                            color: root.canPrev ? (prevBtnHov.containsMouse ? Theme.accentLit : Theme.fg) : Theme.fgDim
                                        }
                                        MouseArea {
                                            id: prevBtnHov
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: if (root.activePlayer) root.activePlayer.previous()
                                        }
                                    }

                                    Rectangle {
                                        width: 30
                                        height: 30
                                        radius: 15
                                        color: Theme.accent
                                        scale: playBtnHov.pressed ? 0.92 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 80 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.playing ? "pause" : "play_arrow"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 18
                                            color: Theme.isDark ? "#101116" : "#ffffff"
                                        }
                                        MouseArea {
                                            id: playBtnHov
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.togglePlayPause()
                                        }
                                    }

                                    Rectangle {
                                        width: 26
                                        height: 26
                                        radius: 13
                                        color: "transparent"
                                        border.width: 1
                                        border.color: nextBtnHov.containsMouse ? Theme.accent : "transparent"
                                        Behavior on border.color { ColorAnimation { duration: 120 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: "skip_next"
                                            font.family: Theme.fontIcon
                                            font.pixelSize: 16
                                            color: root.canNext ? (nextBtnHov.containsMouse ? Theme.accentLit : Theme.fg) : Theme.fgDim
                                        }
                                        MouseArea {
                                            id: nextBtnHov
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: if (root.activePlayer) root.activePlayer.next()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                /* ==== Mode 1: Tasks ==== */
                TodoPane {
                    width: parent.width
                    height: parent.height
                    x: root.paneX(1)
                    opacity: root.mode === 1 ? 1 : 0
                    enabled: root.mode === 1
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutCubic } }
                }

                /* ==== Mode 2: Power (Battery & 4 Power Modes) ==== */
                Item {
                    id: pane2
                    width: parent.width
                    height: parent.height
                    x: root.paneX(2)
                    opacity: root.mode === 2 ? 1 : 0
                    enabled: root.mode === 2
                    clip: true
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutCubic } }

                    property real wavePhase: 0.0

                    FrameAnimation {
                        id: waveAnim
                        running: root.open && root.mode === 2
                        onTriggered: {
                            pane2.wavePhase += frameTime * 0.88
                            if (root.batteryLayout === "vertical") {
                                if (vertWaveCanvas.visible) vertWaveCanvas.requestPaint()
                            } else {
                                if (horizWaveCanvas.visible) horizWaveCanvas.requestPaint()
                            }
                        }
                    }

                    /* ── 1. HORIZONTAL BATTERY LAYOUT ────────────────────────────────────────── */
                    ColumnLayout {
                        id: horizPowerLayout
                        anchors.fill: parent
                        spacing: 8
                        visible: root.batteryLayout !== "vertical"

                        /* Hero Animated Wavy Liquid Battery Card */
                        Rectangle {
                            id: horizWavyCard
                            Layout.fillWidth: true
                            Layout.preferredHeight: 90
                            radius: 16
                            color: Qt.alpha(root.batteryStatusColor, 0.08)
                            border.width: root.isCharging ? 1.5 : 1.0
                            border.color: root.isCharging ? root.batteryStatusColor : Qt.alpha(root.batteryStatusColor, 0.25)
                            clip: true

                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            Canvas {
                                id: horizWaveCanvas
                                anchors.fill: parent
                                visible: root.batteryLayout !== "vertical"

                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)

                                    const fillPct = Math.min(1.0, Math.max(0.0, root.animatedBatteryPct))
                                    const minWaterY = 16
                                    const maxWaterY = height - 6
                                    const waterLevelY = maxWaterY - fillPct * (maxWaterY - minWaterY)
                                    const amp = root.isCharging ? 3.8 : 2.5
                                    const waveLength = width * 0.45
                                    const phase = pane2.wavePhase

                                    // Secondary wave
                                    ctx.save()
                                    ctx.beginPath()
                                    ctx.moveTo(0, height)
                                    ctx.lineTo(0, waterLevelY)
                                    for (let x = 0; x <= width; x += 2) {
                                        const y = waterLevelY + (amp * 0.65) * Math.sin((x / waveLength + phase * 1.3 + 1.5) * Math.PI * 2)
                                        ctx.lineTo(x, y)
                                    }
                                    ctx.lineTo(width, height)
                                    ctx.closePath()
                                    ctx.fillStyle = Qt.alpha(root.batteryStatusColor, 0.22)
                                    ctx.fill()
                                    ctx.restore()

                                    // Primary wave
                                    ctx.save()
                                    ctx.beginPath()
                                    ctx.moveTo(0, height)
                                    ctx.lineTo(0, waterLevelY)
                                    for (let x = 0; x <= width; x += 2) {
                                        const y = waterLevelY + amp * Math.sin((x / waveLength + phase) * Math.PI * 2)
                                        ctx.lineTo(x, y)
                                    }
                                    ctx.lineTo(width, height)
                                    ctx.closePath()

                                    const grad = ctx.createLinearGradient(0, waterLevelY, 0, height)
                                    grad.addColorStop(0.0, Qt.alpha(root.batteryStatusColor, 0.45))
                                    grad.addColorStop(1.0, Qt.alpha(root.batteryStatusColor, 0.80))
                                    ctx.fillStyle = grad
                                    ctx.fill()

                                    // Crest highlight line
                                    ctx.beginPath()
                                    for (let x = 0; x <= width; x += 2) {
                                        const y = waterLevelY + amp * Math.sin((x / waveLength + phase) * Math.PI * 2)
                                        if (x === 0) ctx.moveTo(x, y)
                                        else ctx.lineTo(x, y)
                                    }
                                    ctx.strokeStyle = Qt.alpha("#FFFFFF", 0.50)
                                    ctx.lineWidth = 1.5
                                    ctx.stroke()
                                    ctx.restore()
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                // Left: Glyph & Labels
                                RowLayout {
                                    spacing: 10
                                    Text {
                                        text: root.batteryIconGlyph
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 24
                                        color: root.isCharging ? root.batteryStatusColor : Theme.fg
                                    }

                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            text: "System Battery"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(9.5)
                                            font.weight: Font.Bold
                                            color: Theme.fg
                                        }
                                        Text {
                                            text: root.batteryTimeStr
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7.5)
                                            font.weight: Font.Medium
                                            color: Theme.fgDim
                                        }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Right: Big % & Status Pill
                                ColumnLayout {
                                    spacing: 3
                                    Text {
                                        Layout.alignment: Qt.AlignRight
                                        text: Math.round(root.batteryPct * 100) + "%"
                                        visible: root.showBatteryPercent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(22)
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                    }

                                    Rectangle {
                                        Layout.alignment: Qt.AlignRight
                                        height: 18
                                        width: horizStatusText.implicitWidth + 12
                                        radius: 9
                                        color: root.isCharging ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.20) : Qt.rgba(1, 1, 1, 0.12)
                                        Text {
                                            id: horizStatusText
                                            anchors.centerIn: parent
                                            text: root.isCharging ? "Charging" : (root.isFull ? "Plugged In" : "Discharging")
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7)
                                            font.weight: Font.Bold
                                            color: root.isCharging ? Theme.accentLit : Theme.fgDim
                                        }
                                    }
                                }
                            }
                        }

                        /* Power Profile Header */
                        Text {
                            text: "POWER PROFILE"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(8)
                            font.weight: Font.Bold
                            font.letterSpacing: 1.0
                            color: Theme.fgDim
                        }

                        /* 4 Power Modes 2x2 Grid (Clean simple outline on hover) */
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 6
                            columnSpacing: 6

                            // 1. Power Saving (Eco)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 12
                                readonly property bool isActive: root.powerProfile === "power-saver"
                                color: isActive
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                    : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                                border.width: isActive ? 1.5 : 1.0
                                border.color: isActive ? Theme.accentLit : (ecoMH.containsMouse ? Theme.accent : Theme.outline)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    Text {
                                        text: "eco"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 22
                                        color: parent.parent.isActive ? Theme.accentLit : Theme.fgDim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: "Power Saving"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(8.5)
                                            font.weight: Font.Bold
                                            color: parent.parent.parent.isActive ? Theme.accentLit : Theme.fg
                                        }
                                        Text {
                                            text: "Reduced Power"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7)
                                            color: Theme.fgDim
                                        }
                                    }
                                }
                                MouseArea {
                                    id: ecoMH
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPowerProfile("power-saver")
                                }
                            }

                            // 2. Balance
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 12
                                readonly property bool isActive: root.powerProfile === "balanced"
                                color: isActive
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                    : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                                border.width: isActive ? 1.5 : 1.0
                                border.color: isActive ? Theme.accentLit : (balMH.containsMouse ? Theme.accent : Theme.outline)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    Text {
                                        text: "speed"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 22
                                        color: parent.parent.isActive ? Theme.accentLit : Theme.fgDim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: "Balance"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(8.5)
                                            font.weight: Font.Bold
                                            color: parent.parent.parent.isActive ? Theme.accentLit : Theme.fg
                                        }
                                        Text {
                                            text: "Dynamic Balance"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7)
                                            color: Theme.fgDim
                                        }
                                    }
                                }
                                MouseArea {
                                    id: balMH
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPowerProfile("balanced")
                                }
                            }

                            // 3. Performance
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 12
                                readonly property bool isActive: root.powerProfile === "performance"
                                color: isActive
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                    : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                                border.width: isActive ? 1.5 : 1.0
                                border.color: isActive ? Theme.accentLit : (perfMH.containsMouse ? Theme.accent : Theme.outline)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    Text {
                                        text: "bolt"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 22
                                        color: parent.parent.isActive ? Theme.accentLit : Theme.fgDim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: "Performance"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(8.5)
                                            font.weight: Font.Bold
                                            color: parent.parent.parent.isActive ? Theme.accentLit : Theme.fg
                                        }
                                        Text {
                                            text: "Maximum Clocks"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7)
                                            color: Theme.fgDim
                                        }
                                    }
                                }
                                MouseArea {
                                    id: perfMH
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPowerProfile("performance")
                                }
                            }

                            // 4. Ultra (Game Mode)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                radius: 12
                                readonly property bool isActive: root.powerProfile === "ultra" || root.gameModeOn
                                color: isActive
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                                    : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                                border.width: isActive ? 1.5 : 1.0
                                border.color: isActive ? Theme.accentLit : (ultraMH.containsMouse ? Theme.accent : Theme.outline)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    Text {
                                        text: "sports_esports"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 22
                                        color: parent.parent.isActive ? Theme.accentLit : Theme.fgDim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            text: "Ultra (Game)"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(8.5)
                                            font.weight: Font.Bold
                                            color: parent.parent.parent.isActive ? Theme.accentLit : Theme.fg
                                        }
                                        Text {
                                            text: "Direct Scanout"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(7)
                                            color: Theme.fgDim
                                        }
                                    }
                                }
                                MouseArea {
                                    id: ultraMH
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPowerProfile("ultra")
                                }
                            }
                        }
                    }

                    /* ── 2. VERTICAL BATTERY LAYOUT ──────────────────────────────────────────── */
                    RowLayout {
                        id: vertPowerLayout
                        anchors.fill: parent
                        spacing: 8
                        visible: root.batteryLayout === "vertical"

                        /* Left: Tall Animated Wavy Liquid Battery Tank */
                        Rectangle {
                            id: vertWavyCard
                            Layout.preferredWidth: 106
                            Layout.fillHeight: true
                            radius: 16
                            color: Qt.alpha(root.batteryStatusColor, 0.08)
                            border.width: root.isCharging ? 1.5 : 1.0
                            border.color: root.isCharging ? root.batteryStatusColor : Qt.alpha(root.batteryStatusColor, 0.25)
                            clip: true

                            Behavior on border.color { ColorAnimation { duration: 200 } }

                            Canvas {
                                id: vertWaveCanvas
                                anchors.fill: parent
                                visible: root.batteryLayout === "vertical"

                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)

                                    const fillPct = Math.min(1.0, Math.max(0.0, root.animatedBatteryPct))
                                    const minWaterY = 36
                                    const maxWaterY = height - 10
                                    const waterLevelY = maxWaterY - fillPct * (maxWaterY - minWaterY)
                                    const amp = root.isCharging ? 4.5 : 3.2
                                    const waveLength = width * 0.85
                                    const phase = pane2.wavePhase

                                    // Secondary wave
                                    ctx.save()
                                    ctx.beginPath()
                                    ctx.moveTo(0, height)
                                    ctx.lineTo(0, waterLevelY)
                                    for (let x = 0; x <= width; x += 2) {
                                        const y = waterLevelY + (amp * 0.7) * Math.sin((x / waveLength + phase * 1.3 + 1.5) * Math.PI * 2)
                                        ctx.lineTo(x, y)
                                    }
                                    ctx.lineTo(width, height)
                                    ctx.closePath()
                                    ctx.fillStyle = Qt.alpha(root.batteryStatusColor, 0.25)
                                    ctx.fill()
                                    ctx.restore()

                                    // Primary wave
                                    ctx.save()
                                    ctx.beginPath()
                                    ctx.moveTo(0, height)
                                    ctx.lineTo(0, waterLevelY)
                                    for (let x = 0; x <= width; x += 2) {
                                        const y = waterLevelY + amp * Math.sin((x / waveLength + phase) * Math.PI * 2)
                                        ctx.lineTo(x, y)
                                    }
                                    ctx.lineTo(width, height)
                                    ctx.closePath()

                                    const grad = ctx.createLinearGradient(0, waterLevelY, 0, height)
                                    grad.addColorStop(0.0, Qt.alpha(root.batteryStatusColor, 0.55))
                                    grad.addColorStop(1.0, Qt.alpha(root.batteryStatusColor, 0.85))
                                    ctx.fillStyle = grad
                                    ctx.fill()

                                    // Crest highlight line
                                    ctx.beginPath()
                                    for (let x = 0; x <= width; x += 2) {
                                        const y = waterLevelY + amp * Math.sin((x / waveLength + phase) * Math.PI * 2)
                                        if (x === 0) ctx.moveTo(x, y)
                                        else ctx.lineTo(x, y)
                                    }
                                    ctx.strokeStyle = Qt.alpha("#FFFFFF", 0.55)
                                    ctx.lineWidth = 1.5
                                    ctx.stroke()
                                    ctx.restore()
                                }
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: 10

                                /* Top: Battery icon & label */
                                RowLayout {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    spacing: 4

                                    Text {
                                        text: root.isCharging ? "bolt" : root.batteryIconGlyph
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 15
                                        color: root.isCharging ? root.batteryStatusColor : Theme.fg
                                    }

                                    Text {
                                        text: "Battery"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(9.5)
                                        font.weight: Font.DemiBold
                                        color: Theme.fg
                                        elide: Text.ElideRight
                                    }
                                }

                                /* Bottom: Big % & Status */
                                ColumnLayout {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    spacing: 2

                                    Text {
                                        text: Math.round(root.batteryPct * 100) + "%"
                                        visible: root.showBatteryPercent
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(22)
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                    }

                                    Text {
                                        text: root.isCharging ? "Charging" : (root.isFull ? "Full" : "Discharging")
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(8)
                                        font.weight: Font.Medium
                                        color: Theme.fgDim
                                    }

                                    Text {
                                        text: root.batteryTimeStr
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(6.5)
                                        color: Theme.fgFaint
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }

                        /* Right: Stack of 4 Power Modes (Clean simple outline on hover) */
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 6

                            Text {
                                text: "POWER PROFILE"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(8)
                                font.weight: Font.Bold
                                font.letterSpacing: 1.0
                                color: Theme.fgDim
                            }

                            // 1. Power Saving (Eco)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 12
                                readonly property bool isActive: root.powerProfile === "power-saver"
                                color: isActive
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                    : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                                border.width: isActive ? 1.5 : 1.0
                                border.color: isActive ? Theme.accentLit : (ecoVertMH.containsMouse ? Theme.accent : Theme.outline)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Text {
                                        text: "eco"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 18
                                        color: parent.parent.isActive ? Theme.accentLit : Theme.fgDim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Power Saving"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(8)
                                            font.weight: Font.Bold
                                            color: parent.parent.parent.isActive ? Theme.accentLit : Theme.fg
                                        }
                                        Text {
                                            text: "Reduced Power"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(6.5)
                                            color: Theme.fgDim
                                        }
                                    }
                                }
                                MouseArea {
                                    id: ecoVertMH
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPowerProfile("power-saver")
                                }
                            }

                            // 2. Balance
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 12
                                readonly property bool isActive: root.powerProfile === "balanced"
                                color: isActive
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                    : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                                border.width: isActive ? 1.5 : 1.0
                                border.color: isActive ? Theme.accentLit : (balVertMH.containsMouse ? Theme.accent : Theme.outline)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Text {
                                        text: "speed"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 18
                                        color: parent.parent.isActive ? Theme.accentLit : Theme.fgDim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Balance"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(8)
                                            font.weight: Font.Bold
                                            color: parent.parent.parent.isActive ? Theme.accentLit : Theme.fg
                                        }
                                        Text {
                                            text: "Dynamic Balance"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(6.5)
                                            color: Theme.fgDim
                                        }
                                    }
                                }
                                MouseArea {
                                    id: balVertMH
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPowerProfile("balanced")
                                }
                            }

                            // 3. Performance
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 12
                                readonly property bool isActive: root.powerProfile === "performance"
                                color: isActive
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.20)
                                    : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                                border.width: isActive ? 1.5 : 1.0
                                border.color: isActive ? Theme.accentLit : (perfVertMH.containsMouse ? Theme.accent : Theme.outline)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Text {
                                        text: "bolt"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 18
                                        color: parent.parent.isActive ? Theme.accentLit : Theme.fgDim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Performance"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(8)
                                            font.weight: Font.Bold
                                            color: parent.parent.parent.isActive ? Theme.accentLit : Theme.fg
                                        }
                                        Text {
                                            text: "Maximum Clocks"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(6.5)
                                            color: Theme.fgDim
                                        }
                                    }
                                }
                                MouseArea {
                                    id: perfVertMH
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPowerProfile("performance")
                                }
                            }

                            // 4. Ultra (Game Mode)
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 12
                                readonly property bool isActive: root.powerProfile === "ultra" || root.gameModeOn
                                color: isActive
                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.25)
                                    : Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                                border.width: isActive ? 1.5 : 1.0
                                border.color: isActive ? Theme.accentLit : (ultraVertMH.containsMouse ? Theme.accent : Theme.outline)
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Text {
                                        text: "sports_esports"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 18
                                        color: parent.parent.isActive ? Theme.accentLit : Theme.fgDim
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 1
                                        Text {
                                            text: "Ultra (Game)"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(8)
                                            font.weight: Font.Bold
                                            color: parent.parent.parent.isActive ? Theme.accentLit : Theme.fg
                                        }
                                        Text {
                                            text: "Direct Scanout"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(6.5)
                                            color: Theme.fgDim
                                        }
                                    }
                                }
                                MouseArea {
                                    id: ultraVertMH
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.setPowerProfile("ultra")
                                }
                            }
                        }
                    }
                }

                /* ==== Mode 3: Calendar ==== */
                Item {
                    id: pane3
                    width: parent.width
                    height: parent.height
                    x: root.paneX(3)
                    opacity: root.mode === 3 ? 1 : 0
                    enabled: root.mode === 3
                    clip: true
                    Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutCubic } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 16
                        color: Qt.rgba(Theme.bgAlt.r, Theme.bgAlt.g, Theme.bgAlt.b, 0.65)
                        border.width: 1
                        border.color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.06)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                        /* Header: <  MONTH YEAR  >  Today */
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: "transparent"
                                border.width: 1
                                border.color: prevCalM.containsMouse ? Theme.accent : "transparent"
                                Behavior on border.color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "‹"
                                    font.pixelSize: Theme.fontPx(14)
                                    font.weight: Font.Bold
                                    color: prevCalM.containsMouse ? Theme.accent : Theme.fgDim
                                }
                                MouseArea {
                                    id: prevCalM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.prevMonth()
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.monthNames[root.calMonth] + " " + root.calYear
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.Bold
                                font.letterSpacing: 1.0
                                color: Theme.fg
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: "transparent"
                                border.width: 1
                                border.color: nextCalM.containsMouse ? Theme.accent : "transparent"
                                Behavior on border.color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "›"
                                    font.pixelSize: Theme.fontPx(14)
                                    font.weight: Font.Bold
                                    color: nextCalM.containsMouse ? Theme.accent : Theme.fgDim
                                }
                                MouseArea {
                                    id: nextCalM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.nextMonth()
                                }
                            }

                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: "transparent"
                                border.width: 1
                                border.color: todayCalM.containsMouse ? Theme.accent : "transparent"
                                Behavior on border.color { ColorAnimation { duration: 120 } }
                                Text {
                                    anchors.centerIn: parent
                                    text: "•"
                                    font.pixelSize: Theme.fontPx(14)
                                    font.weight: Font.Bold
                                    color: todayCalM.containsMouse ? Theme.accentLit : Theme.fgDim
                                }
                                MouseArea {
                                    id: todayCalM
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.calMonth = root.calCurrentDate.getMonth()
                                        root.calYear = root.calCurrentDate.getFullYear()
                                        root.selectedDay = root.calCurrentDate.getDate()
                                    }
                                }
                            }
                        }

                        /* Weekday Names Row */
                        Row {
                            Layout.fillWidth: true
                            spacing: 0
                            readonly property var dayHeaders: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Repeater {
                                model: parent.dayHeaders
                                Item {
                                    width: pane3.width / 7
                                    height: 18
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(8.5)
                                        font.weight: Font.DemiBold
                                        color: Theme.fgDim
                                    }
                                }
                            }
                        }

                        /* Days Grid */
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Grid {
                                id: daysGrid
                                anchors.fill: parent
                                columns: 7
                                rows: 6

                                readonly property int totalDaysCur: root.daysInMonth(root.calYear, root.calMonth)
                                readonly property int firstDayIndex: root.firstDayWeekday(root.calYear, root.calMonth)
                                readonly property int prevMonthDays: {
                                    let pm = root.calMonth === 0 ? 11 : root.calMonth - 1
                                    let py = root.calMonth === 0 ? root.calYear - 1 : root.calYear
                                    return root.daysInMonth(py, pm)
                                }

                                Repeater {
                                    model: 42
                                    Item {
                                        width: daysGrid.width / 7
                                        height: daysGrid.height / 6

                                        readonly property int cellIndex: index
                                        readonly property bool isPrevMonth: cellIndex < daysGrid.firstDayIndex
                                        readonly property bool isNextMonth: cellIndex >= (daysGrid.firstDayIndex + daysGrid.totalDaysCur)
                                        readonly property bool isCurMonth: !isPrevMonth && !isNextMonth

                                        readonly property int dayNum: {
                                            if (isPrevMonth) {
                                                return daysGrid.prevMonthDays - (daysGrid.firstDayIndex - cellIndex - 1)
                                            } else if (isCurMonth) {
                                                return cellIndex - daysGrid.firstDayIndex + 1
                                            } else {
                                                return cellIndex - (daysGrid.firstDayIndex + daysGrid.totalDaysCur) + 1
                                            }
                                        }

                                        readonly property bool isToday: isCurMonth &&
                                                                        dayNum === root.calCurrentDate.getDate() &&
                                                                        root.calMonth === root.calCurrentDate.getMonth() &&
                                                                        root.calYear === root.calCurrentDate.getFullYear()

                                        readonly property bool isSelected: isCurMonth && dayNum === root.selectedDay

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 24
                                            height: 24
                                            radius: 12
                                            color: isToday
                                                ? Theme.accentLit
                                                : (isSelected
                                                    ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.40)
                                                    : (dayMouseArea.containsMouse
                                                        ? (isCurMonth ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.22) : Qt.rgba(1, 1, 1, 0.08))
                                                        : "transparent"))
                                            border.color: isToday
                                                ? "transparent"
                                                : (isSelected
                                                    ? Theme.accentLit
                                                    : (dayMouseArea.containsMouse
                                                        ? (isCurMonth ? Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.60) : Qt.rgba(1, 1, 1, 0.18))
                                                        : "transparent"))
                                            border.width: 1

                                            scale: dayMouseArea.containsMouse && !isToday ? 1.08 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 120 } }
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                            Behavior on border.color { ColorAnimation { duration: 100 } }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: dayNum
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: Theme.fontPx(9.5)
                                            font.weight: (isToday || isSelected || dayMouseArea.containsMouse) ? Font.Bold : Font.Normal
                                            color: isToday
                                                ? (Theme.isDark ? "#121118" : "#ffffff")
                                                : ((isSelected || (dayMouseArea.containsMouse && isCurMonth))
                                                    ? Theme.accentLit
                                                    : (dayMouseArea.containsMouse
                                                        ? Theme.fg
                                                        : (isCurMonth ? Theme.fg : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22))))
                                        }

                                        MouseArea {
                                            id: dayMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (isCurMonth) {
                                                    root.selectedDay = dayNum
                                                } else if (isPrevMonth) {
                                                    root.prevMonth()
                                                    root.selectedDay = dayNum
                                                } else {
                                                    root.nextMonth()
                                                    root.selectedDay = dayNum
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        /* Bottom Date Summary */
                        Text {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 18
                            horizontalAlignment: Text.AlignHCenter
                            text: new Date(root.calYear, root.calMonth, root.selectedDay).toLocaleDateString(Qt.locale(), "dddd, MMMM d, yyyy")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(8)
                            font.weight: Font.Medium
                            color: Theme.accentLit
                        }
                    }
                    }
                }
            }
        }

        /* Detail overlay: Dedicated Orbit Picker for Wi-Fi & Bluetooth, and Audio Device Picker */
        Item {
            id: detailContainer
            anchors.fill: parent
            clip: true
            z: 100
            visible: root.wifiPopupOpen || root.btPopupOpen || root.audioPopupOpen || vanishPicker.isOpen || (vanishPicker.transitionProgress > 0.001)
            opacity: (root.wifiPopupOpen || root.btPopupOpen || root.audioPopupOpen) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            ConnectivityOrbitPicker {
                id: vanishPicker
                standaloneMode: true
                visible: (root.wifiPopupOpen || root.btPopupOpen) && !root.audioPopupOpen
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 0
                onBackRequested: {
                    root.wifiPopupOpen = false
                    root.btPopupOpen = false
                }
            }

            AudioDevicePicker {
                id: audioPicker
                visible: root.audioPopupOpen
                anchors.fill: parent
                onBackRequested: {
                    root.audioPopupOpen = false
                }
            }
        }
    }
}