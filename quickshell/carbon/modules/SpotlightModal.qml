import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../Singletons"
import "../components"

/**
 * SpotlightModal: Modern Raycast / Spotlight command palette (Super + K).
 * Features:
 * - Real-time math & unit/currency evaluation via qalc
 * - Clipboard history search & paste via cliphist
 * - Instant system commands (screenshot, wallpaper, lock, settings, power)
 * - Desktop application search & launch
 * - Caelestia Material 3 surfaceContainer glass design
 */
Item {
    id: root

    property bool open: false
    property real shellOpacity: Theme.shellOpacity
    signal closeRequested()
    readonly property string home: Quickshell.env("HOME") || ""

    /* Caelestia Shell bottom slide-up & fluid pop-in animation */
    readonly property bool animatingOut: !root.open && (root.opacity > 0.005 || opacityAnim.running || slideAnim.running)

    property real yOffset: root.open ? 0 : 20
    transform: Translate { y: root.yOffset }
    transformOrigin: Item.Center
    scale: root.open ? 1.0 : 0.97
    opacity: root.open ? 1.0 : 0.0

    Behavior on yOffset {
        NumberAnimation {
            id: slideAnim
            duration: root.open ? root.animSpeed : Math.round(root.animSpeed * 0.7)
            easing.type: root.open ? Easing.OutCubic : Easing.InCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: root.open ? root.animSpeed : Math.round(root.animSpeed * 0.7)
            easing.type: root.open ? Easing.OutCubic : Easing.InCubic
        }
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

    /* ── Launcher Configuration Watcher ── */
    property int animSpeed: 170
    property int maxResultsCount: 8
    property bool showRecentsEnabled: true
    property bool clipboardEnabled: true

    readonly property string launcherConfigFile: {
        var envDir = Quickshell.env("CARBON_CONFIG_DIR")
        if (envDir && envDir.length > 0) return envDir + "/carbon-launcher.json"
        return (Quickshell.env("HOME") || "") + "/.config/carbon/carbon-launcher.json"
    }

    FileView {
        id: launcherConfigWatcher
        path: root.launcherConfigFile
        watchChanges: true
        printErrors: false
        onFileChanged: launcherConfigWatcher.reload()
        onLoaded: {
            try {
                const raw = launcherConfigWatcher.text().trim()
                if (raw) {
                    const d = JSON.parse(raw)
                    if (d.animationSpeed !== undefined) root.animSpeed = Math.max(50, parseInt(d.animationSpeed) || 170)
                    if (d.maxResults !== undefined) root.maxResultsCount = Math.max(2, parseInt(d.maxResults) || 8)
                    if (d.showRecents !== undefined) root.showRecentsEnabled = Boolean(d.showRecents)
                    if (d.clipboardHistory !== undefined) root.clipboardEnabled = Boolean(d.clipboardHistory)
                }
            } catch (e) {}
        }
    }

    Behavior on opacity {
        NumberAnimation {
            id: opacityAnim
            duration: root.open ? Math.round(root.animSpeed * 0.8) : Math.round(root.animSpeed * 0.6)
            easing.type: Easing.OutCubic
        }
    }

    property string barMode: "nucleus"
    readonly property bool isVanishMode: true

    width: 520
    implicitWidth: 520

    readonly property bool isSearchEmpty: !searchInput.text || searchInput.text.trim().length === 0

    // Dynamic height calculation: idle state fits the 2 tiles (in vanish mode); search state fits results
    readonly property int calculatedHeight: {
        if (isVanishMode && isSearchEmpty) {
            return 338 // margins(24) + header(38) + spacing(10) + blackTile(90) + spacing(10) + musicCard(166)
        }
        let h = 145 // base: margins (24) + search header (38) + divider (1) + tabs (26) + footer (20) + spacings (36)
        if (calcCard.visible) {
            h += 60
        }
        if (resultsModel.count > 0) {
            h += 10 + Math.min(240, resultsModel.count * 48)
        } else if (!calcCard.visible) {
            h += 52 // empty placeholder
        }
        return Math.max(160, Math.min(460, h))
    }
    height: calculatedHeight
    implicitHeight: height

    Behavior on height {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    property string currentTab: "apps" // "apps", "clipboard", "commands"
    property real tabContentOpacity: 1.0
    property real tabContentY: 0

    onCurrentTabChanged: {
        tabSwitchAnim.restart()
    }

    SequentialAnimation {
        id: tabSwitchAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "tabContentOpacity"; to: 0.20; duration: 40; easing.type: Easing.OutQuad }
            NumberAnimation { target: root; property: "tabContentY"; to: 6; duration: 40; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "tabContentOpacity"; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
            NumberAnimation { target: root; property: "tabContentY"; to: 0; duration: 120; easing.type: Easing.OutCubic }
        }
    }

    property string calcResult: ""
    property bool hasCalcResult: false

    // App & Action lists
    property var allApps: []
    property var clipboardItems: []
    property int selectedIndex: 0

    /* ── System Actions ───────────────────────────────────────────────── */
    readonly property var systemActions: [
        {
            id: "screenshot-region",
            title: "Screenshot Region",
            desc: "Select a region on screen and copy to clipboard",
            glyph: "crop",
            category: "System",
            run: () => {
                root.closeRequested()
                Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-screenshot-region.sh"])
            }
        },
        {
            id: "screenshot-full",
            title: "Screenshot Full Screen",
            desc: "Capture all monitors and save to Pictures",
            glyph: "photo_camera",
            category: "System",
            run: () => {
                root.closeRequested()
                Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-screenshot-full.sh"])
            }
        },
        {
            id: "wallpaper",
            title: "Change Wallpaper",
            desc: "Open Carbon dynamic wallpaper picker",
            glyph: "wallpaper",
            appIcon: "preferences-desktop-wallpaper",
            category: "Personalization",
            run: () => {
                root.closeRequested()
                Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-ipc.sh", "wallpaper"])
            }
        },
        {
            id: "config",
            title: "Carbon Config & Theme Editor",
            desc: "Configure shell layout, notch mode, and keybinds",
            glyph: "settings",
            appIcon: "carbon-settings",
            category: "Preferences",
            run: () => {
                root.closeRequested()
                Quickshell.execDetached(["carbon-config-editor"])
            }
        },
        {
            id: "terminal",
            title: "Open Terminal",
            desc: "Launch kitty terminal emulator",
            glyph: "terminal",
            appIcon: "kitty",
            category: "Developer",
            run: () => {
                root.closeRequested()
                Quickshell.execDetached(["kitty"])
            }
        },
        {
            id: "lock",
            title: "Lock Screen",
            desc: "Lock the desktop session with Carbon Lock",
            glyph: "lock",
            category: "Security",
            run: () => {
                root.closeRequested()
                Quickshell.execDetached(["sh", root.home + "/.config/hypr/scripts/carbon-ipc.sh", "lock"])
            }
        },
        {
            id: "suspend",
            title: "Sleep / Suspend",
            desc: "Put the system into low power sleep mode",
            glyph: "bedtime",
            category: "Power",
            run: () => {
                root.closeRequested()
                Quickshell.execDetached(["systemctl", "suspend"])
            }
        },
        {
            id: "restart-shell",
            title: "Restart Carbon Shell",
            desc: "Reload Quickshell process and UI",
            glyph: "refresh",
            category: "Developer",
            run: () => {
                root.closeRequested()
                Quickshell.execDetached(["sh", "-c", "systemctl --user restart carbon-quickshell.service 2>/dev/null || (pkill -9 quickshell; sleep 0.4; quickshell --config " + root.home + "/.local/share/quickshell/carbon &)"])
            }
        }
    ]

    ListModel {
        id: resultsModel
    }

    /* ── Desktop Applications Loader ──────────────────────────────────── */
    function loadApps() {
        const values = DesktopEntries.applications.values || []
        const list = []
        for (let i = 0; i < values.length; i++) {
            const e = values[i]
            if (e.noDisplay || !e.name || !e.command || e.command.length === 0) continue
            list.push(e)
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        root.allApps = list
    }

    function resolveAppIcon(app) {
        if (!app) return ""
        if (app.icon) {
            var p = Quickshell.iconPath(app.icon, "")
            if (p) return p
        }
        var appId = (app.id || "").toString()
        var appName = (app.name || "").toString()
        var searchTerms = [(app.icon || ""), appId, appName]
        for (var i = 0; i < searchTerms.length; i++) {
            var t = searchTerms[i].toLowerCase()
            if (t.indexOf("obsidian") !== -1) {
                var o = Quickshell.iconPath("obsidian", "") || Quickshell.iconPath("md.obsidian.Obsidian", "")
                if (o) return o
                return "file://" + (Quickshell.env("HOME") || "") + "/.local/share/icons/hicolor/scalable/apps/obsidian.svg"
            }
        }
        if (appId) {
            var p2 = Quickshell.iconPath(appId, "")
            if (p2) return p2
            var parts = appId.split(".")
            var last = parts[parts.length - 1]
            var p3 = Quickshell.iconPath(last, "")
            if (p3) return p3
        }
        if (app.icon) {
            return Quickshell.iconPath(app.icon, "application-x-executable")
        }
        return ""
    }

    Component.onCompleted: {
        root.loadApps()
        root.reloadBlankTileConfig()
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            root.loadApps()
            root.rebuildResults()
        }
    }

    /* ── Clipboard Fetcher via cliphist ───────────────────────────────── */
    Process {
        id: cliphistProcess
        command: ["sh", "-c", "cliphist list | head -n 40"]
        running: false
        stdout: StdioCollector {
            id: clipCol
            waitForEnd: true
        }
        onExited: {
            const raw = String(clipCol.text || "").trim()
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
            root.rebuildResults()
        }
    }

    function refreshClipboard() {
        cliphistProcess.running = false
        cliphistProcess.running = true
    }

    /* ── Math & Conversion Evaluator via qalc ─────────────────────────── */
    Timer {
        id: qalcDebounceTimer
        interval: 60
        onTriggered: {
            const q = searchInput.text.trim()
            if (q.length === 0) {
                root.calcResult = ""
                root.hasCalcResult = false
                return
            }
            // Check if input might be an expression
            const hasMath = /^[=]/.test(q) || (/[0-9]/.test(q) && /[+\-*/^%=()]/.test(q)) || /(sqrt|sin|cos|tan|log|ln|pi|to\s+[a-z]+)/i.test(q)
            if (hasMath) {
                const expr = q.replace(/^=\s*/, "")
                qalcProcess.running = false
                qalcProcess.command = ["qalc", "-t", "-m", "500", expr]
                qalcProcess.running = true
            } else {
                root.calcResult = ""
                root.hasCalcResult = false
            }
        }
    }

    Process {
        id: qalcProcess
        running: false
        stdout: StdioCollector {
            id: qalcCol
            waitForEnd: true
        }
        onExited: {
            const res = String(qalcCol.text || "").trim()
            if (res.length > 0 && !res.toLowerCase().startsWith("error") && !res.toLowerCase().includes("syntax error") && !res.toLowerCase().includes("parse error")) {
                root.calcResult = res
                root.hasCalcResult = true
            } else {
                root.calcResult = ""
                root.hasCalcResult = false
            }
            root.rebuildResults()
        }
    }

    /* ── Rebuild Results Model ────────────────────────────────────────── */
    function rebuildResults() {
        resultsModel.clear()
        const q = searchInput.text.trim().toLowerCase()

        // 1. If in clipboard mode
        if (root.currentTab === "clipboard" || q.startsWith("c ") || q.startsWith("clip ")) {
            const subQ = q.startsWith("clip ") ? q.substring(5).trim() : (q.startsWith("c ") ? q.substring(2).trim() : q)
            for (let i = 0; i < root.clipboardItems.length; i++) {
                const item = root.clipboardItems[i]
                if (subQ.length === 0 || (item.preview && item.preview.toLowerCase().includes(subQ))) {
                    resultsModel.append({
                        itemType: "clipboard",
                        itemId: item.id,
                        title: item.preview || "",
                        subTitle: "Press Enter to copy to clipboard",
                        glyph: "content_paste",
                        iconSource: "",
                        rawRef: item.raw || ""
                    })
                }
            }
            resultsList.currentIndex = resultsModel.count > 0 ? 0 : -1
            return
        }

        // 2. If in commands mode
        if (root.currentTab === "commands" || q.startsWith(">")) {
            const subQ = q.startsWith(">") ? q.substring(1).trim() : q
            for (let i = 0; i < root.systemActions.length; i++) {
                const act = root.systemActions[i]
                if (subQ.length === 0 || act.title.toLowerCase().includes(subQ) || act.desc.toLowerCase().includes(subQ)) {
                    resultsModel.append({
                        itemType: "action",
                        itemId: act.id,
                        title: act.title,
                        subTitle: act.desc,
                        glyph: act.glyph,
                        iconSource: act.appIcon ? Quickshell.iconPath(act.appIcon, "") : "",
                        rawRef: ""
                    })
                }
            }
            resultsList.currentIndex = resultsModel.count > 0 ? 0 : -1
            return
        }

        // 3. Applications mode (default)
        let count = 0
        for (let i = 0; i < root.allApps.length; i++) {
            const app = root.allApps[i]
            const name = (app.name || "").toLowerCase()
            const generic = (app.genericName || "").toLowerCase()
            const comment = (app.comment || "").toLowerCase()
            if (q.length === 0 || name.includes(q) || generic.includes(q) || comment.includes(q)) {
                resultsModel.append({
                    itemType: "app",
                    itemId: app.id || app.name,
                    title: app.name,
                    subTitle: app.genericName || app.comment || "Application",
                    glyph: "apps",
                    iconSource: root.resolveAppIcon(app),
                    rawRef: ""
                })
                count++
                if (count > 30) break
            }
        }

        resultsList.currentIndex = resultsModel.count > 0 ? 0 : -1
    }

    function executeCurrentItem() {
        const q = searchInput.text.trim()
        const isMathQuery = root.hasCalcResult && (/^[=]/.test(q) || /[+\-*/^%]/.test(q) || /(sqrt|sin|cos|tan|log|ln)/i.test(q))

        if (root.hasCalcResult && (resultsList.currentIndex <= 0 || isMathQuery)) {
            copyCalcResult()
            return
        }

        if (resultsList.currentIndex < 0 || resultsList.currentIndex >= resultsModel.count) {
            if (root.hasCalcResult) {
                copyCalcResult()
            }
            return
        }

        const item = resultsModel.get(resultsList.currentIndex)
        if (!item) return

        if (item.itemType === "action") {
            for (let i = 0; i < root.systemActions.length; i++) {
                if (root.systemActions[i].id === item.itemId) {
                    root.systemActions[i].run()
                    return
                }
            }
        } else if (item.itemType === "app") {
            for (let i = 0; i < root.allApps.length; i++) {
                if (root.allApps[i].id === item.itemId || root.allApps[i].name === item.title) {
                    root.closeRequested()
                    root.allApps[i].execute()
                    return
                }
            }
        } else if (item.itemType === "clipboard") {
            root.closeRequested()
            Quickshell.execDetached(["sh", "-c", "cliphist decode " + item.itemId + " | wl-copy"])
        }
    }

    function copyCalcResult() {
        if (!root.calcResult) return
        Quickshell.execDetached(["sh", "-c", "printf '%s' " + JSON.stringify(root.calcResult) + " | wl-copy"])
        root.closeRequested()
    }

    /* ── Activation & Reset ───────────────────────────────────────────── */
    onOpenChanged: {
        if (root.open) {
            root.reloadBlankTileConfig()
            searchInput.text = ""
            root.calcResult = ""
            root.hasCalcResult = false
            root.currentTab = "apps"
            root.refreshClipboard()
            root.rebuildResults()
            searchInput.forceActiveFocus()
        }
    }

    /* ── Outer Glow / Halo (Vanish Mode Aesthetic) ── */
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: 22
        color: "transparent"
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28)
        border.width: 3
        opacity: 0.85
    }

    /* ── Main Background Container ────────────────────────────────────── */
    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(Theme.m3surfaceContainer.r, Theme.m3surfaceContainer.g, Theme.m3surfaceContainer.b, root.shellOpacity)
        border.color: Qt.alpha(Theme.outline, 0.35)
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            /* 1. Top Search Header */
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                spacing: 10

                CarbonLogoIcon {
                    Layout.preferredWidth: Theme.px(26)
                    Layout.preferredHeight: Theme.px(26)
                    Layout.alignment: Qt.AlignVCenter
                    color: Theme.accent
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(15)
                    font.weight: Font.Medium
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.bg
                    clip: true

                    Text {
                        anchors.fill: parent
                        text: root.currentTab === "clipboard" ? "Search clipboard history..." : (root.currentTab === "commands" ? "Search commands..." : "Search apps, type / for commands...")
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(15)
                        color: Theme.fgFaint
                        visible: !searchInput.text && !searchInput.inputMethodComposing
                    }

                    onTextChanged: {
                        qalcDebounceTimer.restart()
                        root.rebuildResults()
                    }

                    Keys.onEscapePressed: root.closeRequested()
                    Keys.onReturnPressed: root.executeCurrentItem()
                    Keys.onDownPressed: {
                        if (resultsList.count > 0) {
                            resultsList.currentIndex = (resultsList.currentIndex + 1) % resultsList.count
                            resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                        }
                    }
                    Keys.onUpPressed: {
                        if (resultsList.count > 0) {
                            resultsList.currentIndex = (resultsList.currentIndex - 1 + resultsList.count) % resultsList.count
                            resultsList.positionViewAtIndex(resultsList.currentIndex, ListView.Contain)
                        }
                    }
                    Keys.onTabPressed: {
                        const tabs = ["apps", "clipboard", "commands"]
                        const nextIdx = (tabs.indexOf(root.currentTab) + 1) % tabs.length
                        root.currentTab = tabs[nextIdx]
                        root.rebuildResults()
                    }
                }

                /* ? Help Button */
                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 12
                    color: helpArea.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "?"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(13)
                        font.bold: true
                        color: Theme.fgDim
                    }
                    MouseArea {
                        id: helpArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentTab = "commands"
                            searchInput.text = "/"
                        }
                    }
                }

                /* Grid / Apps Drawer Icon */
                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    radius: 6
                    color: gridArea.containsMouse ? Qt.alpha(Theme.fg, 0.12) : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "apps"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: Theme.fgDim
                    }
                    MouseArea {
                        id: gridArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentTab = "apps"
                            root.rebuildResults()
                        }
                    }
                }
            }

            /* 2. Idle State Container (Black Tile + Notch Mode Middle Bar Music Overlay) */
            ColumnLayout {
                id: idleContainer
                Layout.fillWidth: true
                spacing: 10
                visible: root.isVanishMode && opacity > 0.01
                opacity: (root.isVanishMode && root.isSearchEmpty) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                /* ── Top Personalized Tile (Rounded Corners + Right-Side Weather) ── */
                Rectangle {
                    id: blackTile
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    radius: 14
                    color: "#111116"
                    border.color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.12)
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
                            color: Theme.accent
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

                /* ── Bottom Music Overlay Card (Exact Middle Bar Notch Mode Layout) ── */
                Rectangle {
                    id: musicCard
                    Layout.fillWidth: true
                    Layout.preferredHeight: 166
                    radius: 14
                    color: Qt.rgba(0.08, 0.09, 0.12, 0.95)
                    border.color: Qt.rgba(Theme.m3outlineVariant.r, Theme.m3outlineVariant.g, Theme.m3outlineVariant.b, 0.35)
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

                        /* 1. Header: Device / App Badge */
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Text {
                                text: "music_note"
                                font.family: Theme.fontIcon
                                font.pixelSize: 13
                                color: Theme.accentLit
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
                                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.78)
                                elide: Text.ElideRight
                            }
                        }

                        /* 2. Middle Row: Track Title & Artist + Album Art Thumbnail */
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
                                    color: Theme.fg
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: LyricsService.hasTrack ? (LyricsService.trackArtist || "Unknown Artist") : "Waiting for playback..."
                                    font.family: "Valley Sans"
                                    font.pixelSize: 10
                                    color: Theme.accent
                                    elide: Text.ElideRight
                                }
                            }

                            // Album Art Thumbnail
                            Rectangle {
                                Layout.preferredWidth: 42
                                Layout.preferredHeight: 42
                                radius: 8
                                color: Qt.rgba(0.12, 0.14, 0.18, 0.9)
                                border.color: Qt.rgba(Theme.accentLit.r, Theme.accentLit.g, Theme.accentLit.b, 0.35)
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
                                    color: LyricsService.isPlaying ? Theme.accentLit : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                                    visible: !LyricsService.artUrl || LyricsService.artUrl === ""
                                }
                            }
                        }

                        /* 3. Animated Wavy Visualizer & Interactive Progress Bar */
                        WavySeekBar {
                            Layout.fillWidth: true
                            waveHeight: 14
                            barHeight: 6
                            timeLabelSize: 8
                            accentColor: Theme.accent
                            accentLitColor: Theme.accentLit
                        }

                        /* 4. Transport Controls Row */
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter

                            Item { Layout.fillWidth: true }

                            // Shuffle
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 13
                                color: shufArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "shuffle"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 14
                                    color: shufArea.containsMouse ? Theme.accentLit : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                                }

                                MouseArea {
                                    id: shufArea
                                    anchors.fill: parent
                                    hoverEnabled: true
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
                                color: prevArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "skip_previous"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 18
                                    color: prevArea.containsMouse ? Theme.accentLit : Theme.fg
                                }

                                MouseArea {
                                    id: prevArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: LyricsService.skipPrevious()
                                }
                            }

                            Item { Layout.preferredWidth: 10 }

                            // Play / Pause
                            Rectangle {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32
                                radius: 16
                                color: playArea.containsMouse ? Theme.accentLit : Theme.accent
                                border.color: Theme.accentLit
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: LyricsService.isPlaying ? "pause" : "play_arrow"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 18
                                    color: Theme.isDark ? "#121118" : "#ffffff"
                                }

                                MouseArea {
                                    id: playArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: LyricsService.togglePlaying()
                                }
                            }

                            Item { Layout.preferredWidth: 10 }

                            // Next
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "skip_next"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 18
                                    color: nextArea.containsMouse ? Theme.accentLit : Theme.fg
                                }

                                MouseArea {
                                    id: nextArea
                                    anchors.fill: parent
                                    hoverEnabled: true
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
                                color: loopArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

                                Text {
                                    anchors.centerIn: parent
                                    text: "repeat"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 14
                                    color: loopArea.containsMouse ? Theme.accentLit : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.65)
                                }

                                MouseArea {
                                    id: loopArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["playerctl", "loop", "Track"])
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            /* 3. Search Active State Container */
            ColumnLayout {
                id: searchContainer
                Layout.fillWidth: true
                spacing: 8
                visible: (!root.isVanishMode || !root.isSearchEmpty) && opacity > 0.01
                opacity: (!root.isVanishMode || !root.isSearchEmpty) ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                /* Divider */
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Qt.alpha(Theme.outlineVariant, 0.25)
                }

                /* Category Filter Tabs */
                Item {
                id: modeTabs
                Layout.fillWidth: true
                Layout.preferredHeight: 26

                // Animated sliding background indicator pill
                Rectangle {
                    id: tabIndicator
                    y: 1
                    height: 24
                    radius: 12
                    color: Qt.alpha(Theme.accent, 0.22)
                    border.color: Qt.alpha(Theme.accent, 0.7)
                    border.width: 1
                    x: {
                        if (root.currentTab === "clipboard") return tabClip.x
                        if (root.currentTab === "commands") return tabCmd.x
                        return tabApps.x
                    }
                    width: {
                        if (root.currentTab === "clipboard") return tabClip.width
                        if (root.currentTab === "commands") return tabCmd.width
                        return tabApps.width
                    }

                    Behavior on x {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    anchors.fill: parent
                    spacing: 6

                    Item {
                        id: tabApps
                        width: tabAppsText.implicitWidth + 20
                        height: 26

                        Text {
                            id: tabAppsText
                            anchors.centerIn: parent
                            text: "Applications"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: root.currentTab === "apps" ? Font.Bold : Font.Normal
                            color: root.currentTab === "apps" ? Theme.accent : Theme.fgDim
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentTab = "apps"
                                root.rebuildResults()
                            }
                        }
                    }

                    Item {
                        id: tabClip
                        width: root.clipboardEnabled ? (tabClipText.implicitWidth + 20) : 0
                        height: 26
                        visible: root.clipboardEnabled

                        Text {
                            id: tabClipText
                            anchors.centerIn: parent
                            text: "Clipboard"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: root.currentTab === "clipboard" ? Font.Bold : Font.Normal
                            color: root.currentTab === "clipboard" ? Theme.accent : Theme.fgDim
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentTab = "clipboard"
                                root.rebuildResults()
                            }
                        }
                    }

                    Item {
                        id: tabCmd
                        width: tabCmdText.implicitWidth + 20
                        height: 26

                        Text {
                            id: tabCmdText
                            anchors.centerIn: parent
                            text: "Commands"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: root.currentTab === "commands" ? Font.Bold : Font.Normal
                            color: root.currentTab === "commands" ? Theme.accent : Theme.fgDim
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentTab = "commands"
                                root.rebuildResults()
                            }
                        }
                    }
                }
            }

            /* 3. Live Calculation Card (When Expression Detected) */
            Rectangle {
                id: calcCard
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                radius: 10
                color: Qt.alpha(Theme.accent, 0.12)
                border.color: Qt.alpha(Theme.accent, 0.4)
                border.width: 1
                visible: root.hasCalcResult && root.calcResult.length > 0

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 12

                    Rectangle {
                        width: 34
                        height: 34
                        radius: 8
                        color: Theme.accent
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "calculate"
                            font.family: Theme.fontIcon
                            font.pixelSize: 20
                            color: Theme.bg
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: root.calcResult
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(16)
                            font.weight: Font.Bold
                            color: Theme.fg
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Text {
                            text: "Press Enter to copy result to clipboard"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(9)
                            color: Theme.fgDim
                        }
                    }

                    Rectangle {
                        width: 65
                        height: 24
                        radius: 6
                        color: Qt.alpha(Theme.accent, 0.25)
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: "↵ Copy"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(10)
                            font.weight: Font.Bold
                            color: Theme.accent
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyCalcResult()
                }
            }

            /* 4. Results List View */
            ListView {
                id: resultsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(240, resultsModel.count * 48)
                Layout.minimumHeight: resultsModel.count > 0 ? Math.min(240, resultsModel.count * 48) : 0
                clip: true
                spacing: 4
                boundsBehavior: Flickable.StopAtBounds
                model: resultsModel
                visible: resultsModel.count > 0
                opacity: root.tabContentOpacity
                transform: Translate { y: root.tabContentY }

                delegate: Rectangle {
                    id: rowDelegate
                    required property int index
                    required property string itemType
                    required property string itemId
                    required property string title
                    required property string subTitle
                    required property string glyph
                    required property string iconSource

                    width: resultsList.width
                    height: 44
                    radius: 8
                    color: resultsList.currentIndex === index ? Qt.alpha(Theme.accent, 0.15) : (rowHover.hovered ? Qt.alpha(Theme.fg, 0.05) : "transparent")
                    border.color: resultsList.currentIndex === index ? Qt.alpha(Theme.accent, 0.4) : "transparent"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        /* Icon */
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 6
                            color: Qt.alpha(Theme.fg, 0.06)
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                id: rowIconImg
                                anchors.centerIn: parent
                                width: 20
                                height: 20
                                source: rowDelegate.iconSource
                                sourceSize: Qt.size(40, 40)
                                fillMode: Image.PreserveAspectFit
                                visible: rowDelegate.iconSource.length > 0 && status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: rowDelegate.glyph
                                font.family: Theme.fontIcon
                                font.pixelSize: 16
                                color: resultsList.currentIndex === rowDelegate.index ? Theme.accent : Theme.fgDim
                                visible: !rowIconImg.visible
                            }
                        }

                        /* Texts */
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            Text {
                                text: rowDelegate.title
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(12)
                                font.weight: resultsList.currentIndex === rowDelegate.index ? Font.Bold : Font.Medium
                                color: resultsList.currentIndex === rowDelegate.index ? Theme.accent : Theme.fg
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: rowDelegate.subTitle
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(9)
                                color: Theme.fgDim
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        /* Enter hint on selected item */
                        Text {
                            text: "↵"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(13)
                            color: Theme.accent
                            visible: resultsList.currentIndex === rowDelegate.index
                        }
                    }

                    MouseArea {
                        id: rowHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            resultsList.currentIndex = rowDelegate.index
                            root.executeCurrentItem()
                        }
                    }
                }
            }

            /* Empty State Placeholder */
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                visible: resultsModel.count === 0 && !root.hasCalcResult
                opacity: root.tabContentOpacity
                transform: Translate { y: root.tabContentY }

                Text {
                    anchors.centerIn: parent
                    text: root.currentTab === "clipboard" ? "Clipboard is empty" : (root.currentTab === "commands" ? "No commands found" : "No applications found")
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(12)
                    color: Theme.fgDim
                }
            }

            /* 5. Footer Shortcuts */
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                spacing: 12

                Text {
                    text: resultsModel.count === 1 ? "1 result" : (resultsModel.count + " results")
                    font.family: Theme.font
                    font.pixelSize: Theme.fontPx(9)
                    color: Theme.fgFaint
                }

                Item { Layout.fillWidth: true }

                Row {
                    spacing: 10

                    Row {
                        spacing: 4
                        Text { text: "↑↓"; font.pixelSize: Theme.fontPx(9); color: Theme.fgDim; font.weight: Font.Bold }
                        Text { text: "Navigate"; font.pixelSize: Theme.fontPx(9); color: Theme.fgFaint }
                    }

                    Row {
                        spacing: 4
                        Text { text: "Tab"; font.pixelSize: Theme.fontPx(9); color: Theme.fgDim; font.weight: Font.Bold }
                        Text { text: "Filter"; font.pixelSize: Theme.fontPx(9); color: Theme.fgFaint }
                    }

                    Row {
                        spacing: 4
                        Text { text: "↵"; font.pixelSize: Theme.fontPx(9); color: Theme.fgDim; font.weight: Font.Bold }
                        Text { text: "Open"; font.pixelSize: Theme.fontPx(9); color: Theme.fgFaint }
                    }
                }
            }
        }
    }
}
}
