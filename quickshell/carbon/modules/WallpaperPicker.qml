import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * Unified Wallpaper Picker & Downloader
 * Combines Local System Wallpapers (File tab) and Wallhaven Online Search (Globe tab)
 * with identical modern preview cards, resolution chips, active badge, and 1-click apply.
 */
Item {
    id: root

    property bool open: false
    signal closeRequested()
    signal wallpaperApplyStarted(string name)
    signal wallpaperApplyFinished()

    readonly property var cardItem: panelCard
    readonly property bool animatingOut: !root.open && root.opacity > 0.001

    // Mode: "local" (system wallpapers), "live" (video/gif wallpapers), or "wallhaven" (online search)
    property string activeSource: "local"
    // Online Provider: "unsplash" or "wallhaven"
    property string onlineProvider: "unsplash"
    property bool searchOpen: false
    property string currentSort: "toplist"
    property string searchQuery: ""
    property var wallpapers: []
    property bool isLoading: false
    property bool isLoadingMore: false
    property int currentPage: 1
    property bool hasMore: true
    property string activeDownloadId: ""
    property string downloadStatus: ""
    property string currentWallpaperPath: ""
    property string noticeMessage: ""

    readonly property string wallpaperDir: (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"
    readonly property string stateFile: (Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")) + "/current_wallpaper_path"
    readonly property string hyprStateFile: (Quickshell.env("HOME") || "") + "/.config/hypr/current_wallpaper_path"
    readonly property string wallpaperSourceFile: (Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")) + "/carbon-wallpaper-source.json"
    readonly property string wallhavenScript: {
        const home = Quickshell.env("HOME") || ""
        const carbonDir = Quickshell.env("CARBON_CONFIG_DIR") || (home + "/.config/carbon")
        return carbonDir + "/scripts/wallhaven.py"
    }

    FileView {
        id: wpSourceFile
        path: root.wallpaperSourceFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: root.loadWallpaperSource()
        onFileChanged: {
            reload()
            root.loadWallpaperSource()
        }
    }

    function loadWallpaperSource() {
        try {
            var t = wpSourceFile.text().trim()
            if (t) {
                var d = JSON.parse(t)
                if (d && d.provider) {
                    var p = String(d.provider).toLowerCase()
                    if (p === "unsplash" || p === "wallhaven") {
                        root.onlineProvider = p
                    }
                }
            }
        } catch (e) {}
    }

    function setOnlineProvider(prov) {
        var p = prov.toLowerCase()
        if (p !== "unsplash" && p !== "wallhaven") return
        if (root.onlineProvider === p) return
        root.onlineProvider = p

        var cfg = {
            "provider": root.onlineProvider,
            "unsplash_access_key": "5fda81bc223a576f33934dd4dee20cf2217f2777f798c4c0f1e00e377cba5bcc"
        }
        var jsonStr = JSON.stringify(cfg, null, 2)
        Quickshell.execDetached(["sh", "-c", "echo '" + jsonStr + "' > " + root.wallpaperSourceFile + "; [ -d ~/.config/hypr ] && echo '" + jsonStr + "' > ~/.config/hypr/carbon-wallpaper-source.json"])

        if (root.activeSource === "wallhaven") {
            root.fetchWallpapers()
        }
    }

    FileView {
        id: wpLinkFile
        path: root.stateFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            var t = wpLinkFile.text().trim()
            if (t) root.currentWallpaperPath = t
        }
        onFileChanged: {
            reload()
            var t = wpLinkFile.text().trim()
            if (t) root.currentWallpaperPath = t
        }
    }

    FileView {
        id: hyprWpLinkFile
        path: root.hyprStateFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            var t = hyprWpLinkFile.text().trim()
            if (t && !root.currentWallpaperPath) root.currentWallpaperPath = t
        }
        onFileChanged: {
            reload()
            var t = hyprWpLinkFile.text().trim()
            if (t) root.currentWallpaperPath = t
        }
    }

    /* Track current wallpaper basename */
    readonly property string currentWpBasename: {
        if (!root.currentWallpaperPath) return ""
        const parts = root.currentWallpaperPath.split("/")
        return parts[parts.length - 1]
    }

    /* Debounce timer for search */
    Timer {
        id: searchDebounce
        interval: 400
        repeat: false
        onTriggered: root.fetchWallpapers()
    }

    onActiveSourceChanged: {
        root.searchOpen = false
        searchInput.text = ""
        root.searchQuery = ""
        root.fetchWallpapers()
    }

    onOnlineProviderChanged: {
        if (root.open && root.activeSource === "wallhaven") {
            root.currentPage = 1
            root.fetchWallpapers()
        }
    }

    onCurrentSortChanged: {
        if (root.open && root.activeSource === "wallhaven") root.fetchWallpapers()
    }


    onOpenChanged: {
        if (root.open) {
            searchInput.forceActiveFocus()
            root.fetchWallpapers()
        }
    }

    Timer {
        id: fetchDebounce
        interval: 20
        repeat: false
        onTriggered: root.doFetchWallpapers()
    }

    function fetchWallpapers() {
        fetchDebounce.restart()
    }

    function doFetchWallpapers() {
        if (!root.open) return
        if (searchProc.running) {
            searchProc.running = false
        }
        root.isLoading = true
        root.isLoadingMore = false
        root.currentPage = 1
        root.hasMore = true
        root.wallpapers = []
        root.noticeMessage = ""

        var args = []
        if (root.activeSource === "local") {
            args = ["python3", root.wallhavenScript, "list-local"]
            if (root.searchQuery && root.searchQuery.trim().length > 0) {
                args.push("--query", root.searchQuery.trim())
            }
        } else if (root.activeSource === "live") {
            args = ["python3", root.wallhavenScript, "list-live"]
            if (root.searchQuery && root.searchQuery.trim().length > 0) {
                args.push("--query", root.searchQuery.trim())
            }
        } else {
            args = ["python3", root.wallhavenScript, "search", "--client", "picker", "--provider", root.onlineProvider, "--sort", root.currentSort, "--page", "1"]
            if (root.searchQuery && root.searchQuery.trim().length > 0) {
                args.push("--query", root.searchQuery.trim())
            }
        }

        searchProc.command = args
        searchProc.running = true
    }

    function fetchMore() {
        if (root.activeSource !== "wallhaven" || root.isLoading || root.isLoadingMore || !root.hasMore) return
        root.isLoadingMore = true
        var nextPage = root.currentPage + 1

        var args = ["python3", root.wallhavenScript, "search", "--client", "picker", "--provider", root.onlineProvider, "--sort", root.currentSort, "--page", String(nextPage)]
        if (root.searchQuery && root.searchQuery.trim().length > 0) {
            args.push("--query", root.searchQuery.trim())
        }

        moreProc.command = args
        moreProc.running = true
    }

    Process {
        id: searchProc
        property string buffer: ""

        onRunningChanged: {
            if (running) {
                buffer = ""
            } else {
                root.isLoading = false
                if (buffer.trim().length > 0) {
                    try {
                        var res = JSON.parse(buffer)
                        if (res && res.success && Array.isArray(res.data)) {
                            root.wallpapers = res.data
                            root.hasMore = res.data.length >= 20
                            root.noticeMessage = res.notice || ""
                        } else {
                            root.wallpapers = []
                            root.hasMore = false
                            root.noticeMessage = (res && res.error) ? res.error : ""
                        }
                    } catch (e) {
                        console.log("Failed to parse wallpaper list response:", e)
                        root.wallpapers = []
                        root.hasMore = false
                        root.noticeMessage = ""
                    }
                }
            }
        }

        stdout: SplitParser {
            onRead: (chunk) => {
                searchProc.buffer += chunk + "\n"
            }
        }
    }

    Process {
        id: moreProc
        property string buffer: ""

        onRunningChanged: {
            if (running) {
                buffer = ""
            } else {
                root.isLoadingMore = false
                if (buffer.trim().length > 0) {
                    try {
                        var res = JSON.parse(buffer)
                        if (res && res.success && Array.isArray(res.data)) {
                            if (res.data.length === 0) {
                                root.hasMore = false
                            } else {
                                root.currentPage += 1
                                var existing = {}
                                for (var i = 0; i < root.wallpapers.length; i++) {
                                    existing[root.wallpapers[i].id] = true
                                }
                                var updated = root.wallpapers.slice()
                                for (var j = 0; j < res.data.length; j++) {
                                    if (!existing[res.data[j].id]) {
                                        updated.push(res.data[j])
                                    }
                                }
                                var prevScroll = wpGrid.contentY
                                root.wallpapers = updated
                                Qt.callLater(function() {
                                    wpGrid.contentY = prevScroll
                                })
                                root.hasMore = res.data.length >= 20
                            }
                        } else {
                            root.hasMore = false
                        }
                    } catch (e) {
                        console.log("Failed to parse more wallpapers response:", e)
                        root.hasMore = false
                    }
                }
            }
        }

        stdout: SplitParser {
            onRead: (chunk) => {
                moreProc.buffer += chunk + "\n"
            }
        }
    }

    function selectWallpaper(item) {
        if (!item) return
        var title = item.name || item.filename || item.id || "Wallpaper"
        root.wallpaperApplyStarted(title)
        root.closeRequested()

        root.activeDownloadId = ""
        root.downloadStatus = ""

        if (item.is_local) {
            // Directly apply local wallpaper
            applyProc.command = ["python3", root.wallhavenScript, "apply", item.path]
            applyProc.running = true
        } else {
            // Download from Wallhaven then apply
            downloadProc.buffer = ""
            downloadProc.command = ["python3", root.wallhavenScript, "download", item.url, item.filename]
            downloadProc.running = true
        }
    }

    Process {
        id: applyProc
        property string buffer: ""
        onRunningChanged: {
            if (!running) {
                root.activeDownloadId = ""
                root.downloadStatus = ""
                root.wallpaperApplyFinished()
            }
        }
        stdout: SplitParser {
            onRead: (chunk) => { applyProc.buffer += chunk + "\n" }
        }
    }

    Process {
        id: downloadProc
        property string buffer: ""
        onRunningChanged: {
            if (!running) {
                root.activeDownloadId = ""
                root.downloadStatus = ""
                try {
                    var res = JSON.parse(buffer)
                    if (res && res.success) {
                        root.currentWallpaperPath = res.path
                    }
                } catch (e) {}
                root.wallpaperApplyFinished()
            }
        }
        stdout: SplitParser {
            onRead: (chunk) => { downloadProc.buffer += chunk + "\n" }
        }
    }

    /* Fullscreen layout with smooth fade/scale */
    opacity: root.open ? 1.0 : 0.0
    scale: root.open ? 1.0 : 0.98

    Behavior on opacity {
        NumberAnimation {
            duration: root.open ? 260 : 160
            easing.type: root.open ? Easing.OutCubic : Easing.InQuad
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: root.open ? 260 : 160
            easing.type: root.open ? Easing.OutCubic : Easing.InQuad
        }
    }

    /* Catch keys: Esc closes */
    Keys.onEscapePressed: root.closeRequested()

    Rectangle {
        id: panelCard
        anchors.fill: parent
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.96)

        /* Prevent clicks inside from propagating to background */
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            anchors.leftMargin: 28
            anchors.rightMargin: 28
            spacing: 16

            /* ── Header: Source Icons, API Switcher, Search Bar & Filters ─────────── */
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                /* Source Switcher: Local, Live, and Online */
                RowLayout {
                    spacing: 6

                    /* File Icon: My Local Wallpapers */
                    Rectangle {
                        id: localTabBtn
                        height: 40
                        width: 48
                        radius: 12
                        readonly property bool isActive: root.activeSource === "local"
                        color: isActive ? Theme.accent : (locHov.containsMouse ? Theme.bgHover : Qt.alpha(Theme.fg, 0.06))
                        border.color: isActive ? Theme.accentLit : Qt.alpha(Theme.fg, 0.12)
                        border.width: 1
                        scale: locHov.pressed ? 0.94 : (locHov.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                        Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3; easing.type: Theme.easingStandard } }

                        Text {
                            anchors.centerIn: parent
                            text: "folder"
                            font.family: Theme.fontIcon
                            font.pixelSize: 20
                            color: localTabBtn.isActive ? "#111111" : Theme.fg
                        }

                        MouseArea {
                            id: locHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeSource = "local"
                        }
                    }

                    /* Film Reel Icon: Live Wallpapers (.mp4, .gif) */
                    Rectangle {
                        id: liveTabBtn
                        height: 40
                        width: 48
                        radius: 12
                        readonly property bool isActive: root.activeSource === "live"
                        color: isActive ? Theme.accent : (liveHov.containsMouse ? Theme.bgHover : Qt.alpha(Theme.fg, 0.06))
                        border.color: isActive ? Theme.accentLit : Qt.alpha(Theme.fg, 0.12)
                        border.width: 1
                        scale: liveHov.pressed ? 0.94 : (liveHov.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                        Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3; easing.type: Theme.easingStandard } }

                        Text {
                            anchors.centerIn: parent
                            text: "movie"
                            font.family: Theme.fontIcon
                            font.pixelSize: 20
                            color: liveTabBtn.isActive ? "#111111" : Theme.fg
                        }

                        MouseArea {
                            id: liveHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeSource = "live"
                        }
                    }

                    /* Globe Icon: Online Search */
                    Rectangle {
                        id: onlineTabBtn
                        height: 40
                        width: 48
                        radius: 12
                        readonly property bool isActive: root.activeSource === "wallhaven"
                        color: isActive ? Theme.accent : (onlHov.containsMouse ? Theme.bgHover : Qt.alpha(Theme.fg, 0.06))
                        border.color: isActive ? Theme.accentLit : Qt.alpha(Theme.fg, 0.12)
                        border.width: 1
                        scale: onlHov.pressed ? 0.94 : (onlHov.containsMouse ? 1.05 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                        Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3; easing.type: Theme.easingStandard } }

                        Text {
                            anchors.centerIn: parent
                            text: "public"
                            font.family: Theme.fontIcon
                            font.pixelSize: 20
                            color: onlineTabBtn.isActive ? "#111111" : Theme.fg
                        }

                        MouseArea {
                            id: onlHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activeSource = "wallhaven"
                        }
                    }
                }

                /* API Provider Switcher (Unsplash / Wallhaven) - Visible in Online mode */
                Rectangle {
                    height: 40
                    radius: 12
                    color: Qt.alpha(Theme.fg, 0.05)
                    border.color: Qt.alpha(Theme.fg, 0.12)
                    border.width: 1
                    visible: root.activeSource === "wallhaven"
                    implicitWidth: providerRow.implicitWidth + 8

                    RowLayout {
                        id: providerRow
                        anchors.centerIn: parent
                        spacing: 2

                        /* Unsplash Pill */
                        Rectangle {
                            height: 32
                            width: unsplashTxt.implicitWidth + 20
                            radius: 9
                            readonly property bool isSelected: root.onlineProvider === "unsplash"
                            color: isSelected ? Theme.accent : (unsHov.containsMouse ? Theme.bgHover : "transparent")
                            scale: unsHov.pressed ? 0.95 : 1.0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                id: unsplashTxt
                                anchors.centerIn: parent
                                text: "Unsplash"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.Bold
                                color: parent.isSelected ? "#111111" : Theme.fgDim
                            }

                            MouseArea {
                                id: unsHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setOnlineProvider("unsplash")
                            }
                        }

                        /* Wallhaven Pill */
                        Rectangle {
                            height: 32
                            width: whTxt.implicitWidth + 20
                            radius: 9
                            readonly property bool isSelected: root.onlineProvider === "wallhaven"
                            color: isSelected ? Theme.accent : (whHov.containsMouse ? Theme.bgHover : "transparent")
                            scale: whHov.pressed ? 0.95 : 1.0
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 100 } }

                            Text {
                                id: whTxt
                                anchors.centerIn: parent
                                text: "Wallhaven"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.Bold
                                color: parent.isSelected ? "#111111" : Theme.fgDim
                            }

                            MouseArea {
                                id: whHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setOnlineProvider("wallhaven")
                            }
                        }
                    }
                }

                /* Spacer when in Wallhaven Best/Latest mode without search bar */
                Item {
                    Layout.fillWidth: true
                    visible: root.activeSource === "wallhaven" && !root.searchOpen
                }

                /* Online Sort Chips: Best & Latest (Visible in Online mode) */
                RowLayout {
                    spacing: 6
                    visible: root.activeSource === "wallhaven"

                    /* Best Tab */
                    Rectangle {
                        id: bestBtn
                        height: 40
                        width: 82
                        radius: 12
                        readonly property bool isActive: root.currentSort === "toplist"
                        color: isActive ? Theme.accent : (bestHov.containsMouse ? Theme.bgHover : Qt.alpha(Theme.fg, 0.06))
                        border.color: isActive ? Theme.accentLit : Qt.alpha(Theme.fg, 0.12)
                        border.width: 1
                        scale: bestHov.pressed ? 0.94 : (bestHov.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                        Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3; easing.type: Theme.easingStandard } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "star"
                                font.family: Theme.fontIcon
                                font.pixelSize: 15
                                color: bestBtn.isActive ? "#111111" : Theme.fg
                            }
                            Text {
                                text: "Best"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(12)
                                font.weight: Font.Bold
                                color: bestBtn.isActive ? "#111111" : Theme.fg
                            }
                        }

                        MouseArea {
                            id: bestHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentSort = "toplist"
                            }
                        }
                    }

                    /* Latest Tab */
                    Rectangle {
                        id: latestBtn
                        height: 40
                        width: 86
                        radius: 12
                        readonly property bool isActive: root.currentSort === "date_added"
                        color: isActive ? Theme.accent : (latestHov.containsMouse ? Theme.bgHover : Qt.alpha(Theme.fg, 0.06))
                        border.color: isActive ? Theme.accentLit : Qt.alpha(Theme.fg, 0.12)
                        border.width: 1
                        scale: latestHov.pressed ? 0.94 : (latestHov.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                        Behavior on color { ColorAnimation { duration: Theme.motionDurationShort3; easing.type: Theme.easingStandard } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "schedule"
                                font.family: Theme.fontIcon
                                font.pixelSize: 15
                                color: latestBtn.isActive ? "#111111" : Theme.fg
                            }
                            Text {
                                text: "Latest"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: Theme.fontPx(12)
                                font.weight: Font.Bold
                                color: latestBtn.isActive ? "#111111" : Theme.fg
                            }
                        }

                        MouseArea {
                            id: latestHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentSort = "date_added"
                            }
                        }
                    }
                }

                /* Search Bar: Always visible on top of screen */
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: Qt.alpha(Theme.fg, 0.06)
                    border.color: searchInput.activeFocus ? Theme.accent : Qt.alpha(Theme.fg, 0.14)
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 8

                        /* Target Icon */
                        Text {
                            text: root.activeSource === "wallhaven" ? (root.onlineProvider === "unsplash" ? "photo_camera" : "image") : (root.activeSource === "live" ? "movie" : "folder")
                            font.family: Theme.fontIcon
                            font.pixelSize: 18
                            color: searchInput.activeFocus ? Theme.accent : Theme.fgDim
                        }

                        /* Quick Provider toggle chip inside search bar */
                        Rectangle {
                            visible: root.activeSource === "wallhaven"
                            height: 24
                            width: provChipRow.implicitWidth + 12
                            radius: 6
                            color: provChipHov.containsMouse ? Theme.bgHover : Qt.alpha(Theme.accent, 0.20)
                            border.width: 1
                            border.color: Theme.accentLit

                            RowLayout {
                                id: provChipRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: root.onlineProvider === "unsplash" ? "photo_camera" : "image"
                                    font.family: Theme.fontIcon
                                    font.pixelSize: 12
                                    color: Theme.accentLit
                                }
                                Text {
                                    text: root.onlineProvider === "unsplash" ? "Unsplash" : "Wallhaven"
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontPx(8)
                                    font.weight: Font.Bold
                                    color: Theme.accentLit
                                }
                            }

                            MouseArea {
                                id: provChipHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.setOnlineProvider(root.onlineProvider === "unsplash" ? "wallhaven" : "unsplash")
                            }
                        }

                        TextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: Theme.fontPx(13)
                            color: Theme.fg
                            selectByMouse: true
                            clip: true

                            Text {
                                anchors.fill: parent
                                text: root.activeSource === "wallhaven" ? ("Search " + (root.onlineProvider === "unsplash" ? "Unsplash" : "Wallhaven") + " wallpapers...") : (root.activeSource === "live" ? "Search live wallpapers..." : "Search local wallpapers...")
                                font: searchInput.font
                                color: Theme.fgFaint
                                visible: !searchInput.text
                                verticalAlignment: Text.AlignVCenter
                            }

                            onTextChanged: {
                                root.searchQuery = searchInput.text
                                searchDebounce.restart()
                            }

                            onAccepted: {
                                searchDebounce.stop()
                                root.fetchWallpapers()
                            }
                            Keys.onEscapePressed: root.closeRequested()
                        }

                        /* Clear button */
                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: clrHov.containsMouse ? Theme.bgHover : "transparent"
                            scale: clrHov.pressed ? 0.90 : 1.0
                            Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }
                            visible: searchInput.text.length > 0

                            Text {
                                anchors.centerIn: parent
                                text: "close"
                                font.family: Theme.fontIcon
                                font.pixelSize: 13
                                color: Theme.fgDim
                            }

                            MouseArea {
                                id: clrHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = ""
                                    root.searchQuery = ""
                                    root.fetchWallpapers()
                                }
                            }
                        }
                    }
                }

                /* Refresh Button */
                Rectangle {
                    height: 40
                    width: 40
                    radius: 12
                    color: refHov.containsMouse ? Theme.bgHover : Qt.alpha(Theme.fg, 0.06)
                    border.color: Qt.alpha(Theme.fg, 0.12)
                    border.width: 1
                    scale: refHov.pressed ? 0.94 : (refHov.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }

                    Text {
                        anchors.centerIn: parent
                        text: "refresh"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: Theme.fg

                        NumberAnimation on rotation {
                            from: 0; to: 360; duration: 800
                            loops: Animation.Infinite
                            easing.type: Easing.Linear
                            running: root.isLoading
                        }
                    }

                    MouseArea {
                        id: refHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.fetchWallpapers()
                    }
                }

                /* Close Button */
                Rectangle {
                    height: 40
                    width: 40
                    radius: 12
                    color: clsHov.containsMouse ? Qt.alpha(Theme.err, 0.25) : Qt.alpha(Theme.fg, 0.06)
                    border.color: clsHov.containsMouse ? Theme.err : Qt.alpha(Theme.fg, 0.12)
                    border.width: 1
                    scale: clsHov.pressed ? 0.94 : (clsHov.containsMouse ? 1.05 : 1.0)
                    Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }

                    Text {
                        anchors.centerIn: parent
                        text: "close"
                        font.family: Theme.fontIcon
                        font.pixelSize: 18
                        color: clsHov.containsMouse ? Theme.err : Theme.fgDim
                    }

                    MouseArea {
                        id: clsHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.closeRequested()
                    }
                }
            }

            /* ── Divider ────────────────────────────────────────────── */
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.outline
            }

            /* ── Outage / Maintenance Notice Banner ──────────────────── */
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                visible: root.activeSource === "wallhaven" && root.noticeMessage.length > 0
                color: Qt.alpha(Theme.warn || "#e5c07b", 0.12)
                border.color: Qt.alpha(Theme.warn || "#e5c07b", 0.35)
                border.width: 1
                radius: 6

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "warning"
                        font.family: Theme.fontIcon
                        font.pixelSize: 14
                        color: Theme.warn || "#e5c07b"
                    }
                    Text {
                        text: root.noticeMessage
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(11)
                        color: Theme.fg
                    }
                }
            }

            /* ── Main Content Area: Wallpapers Grid ─────────────────── */
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                /* Loading Overlay */
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: root.isLoading && root.wallpapers.length === 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "progress_activity"
                        font.family: Theme.fontIcon
                        font.pixelSize: 32
                        color: Theme.accent

                        NumberAnimation on rotation {
                            from: 0; to: 360; duration: 1000
                            loops: Animation.Infinite
                            easing.type: Easing.Linear
                            running: root.isLoading && root.wallpapers.length === 0
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.activeSource === "wallhaven" ? (root.onlineProvider === "unsplash" ? "Searching Unsplash..." : "Searching Wallhaven...") : (root.activeSource === "live" ? "Loading Live Wallpapers..." : "Loading Wallpapers...")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(13)
                        color: Theme.fgDim
                    }
                }

                /* Empty state */
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: !root.isLoading && root.wallpapers.length === 0

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "search_off"
                        font.family: Theme.fontIcon
                        font.pixelSize: 28
                        color: Theme.fgDim
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.searchQuery ? ("No wallpapers found for \"" + root.searchQuery + "\"") : (root.activeSource === "live" ? "No live wallpapers found in ~/Pictures/Live_Wallpapers" : "No wallpapers found")
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: Theme.fontPx(13)
                        color: Theme.fgDim
                    }
                }

                /* Wallpapers Grid (Identical cards for both Local and Wallhaven) */
                GridView {
                    id: wpGrid
                    anchors.fill: parent
                    clip: true
                    // Compute number of columns dynamically so cards are never cramped (~300px min width)
                    readonly property int columns: Math.max(2, Math.floor(width / 310))
                    cellWidth: Math.floor(width / columns)
                    cellHeight: Math.round(cellWidth * 0.62)
                    model: root.wallpapers
                    visible: root.wallpapers.length > 0

                    onContentYChanged: {
                        if (root.activeSource === "wallhaven" && !root.isLoading && !root.isLoadingMore && root.hasMore) {
                            if (contentY + height >= contentHeight - 180) {
                                root.fetchMore()
                            }
                        }
                    }

                    delegate: Item {
                        id: cardItem
                        width: wpGrid.cellWidth
                        height: wpGrid.cellHeight
                        z: tileHov.containsMouse ? 10 : 1
                        required property var modelData
                        required property int index

                        readonly property bool isDownloading: root.activeDownloadId === cardItem.modelData.id
                        readonly property bool isCurrent: root.currentWpBasename === cardItem.modelData.filename

                        Rectangle {
                            id: tile
                            width: cardItem.width - 16
                            height: cardItem.height - 16
                            anchors.centerIn: parent
                            radius: 14
                            color: Qt.alpha(Theme.fg, 0.04)
                            border.color: cardItem.isCurrent ? Theme.accentLit : (tileHov.containsMouse ? Theme.accentLit : Theme.outline)
                            border.width: (cardItem.isCurrent || tileHov.containsMouse) ? 2 : 1
                            clip: true

                            y: tileHov.containsMouse ? -5 : 0
                            scale: tileHov.containsMouse ? 1.03 : 1.0
                            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                            Behavior on border.width { NumberAnimation { duration: 150 } }

                            /* Wallpaper Thumbnail Preview */
                            Image {
                                anchors.fill: parent
                                source: cardItem.modelData.thumb
                                sourceSize: Qt.size(260, 165)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true

                                /* Loading placeholder */
                                Rectangle {
                                    anchors.fill: parent
                                    color: Qt.alpha(Theme.fg, 0.08)
                                    visible: parent.status !== Image.Ready
                                    Text {
                                        anchors.centerIn: parent
                                        text: "image"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 26
                                        color: Qt.alpha(Theme.fg, 0.2)
                                    }
                                }
                            }

                            /* Gradient dark bottom shade for readability */
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 42
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "transparent" }
                                    GradientStop { position: 1.0; color: "#D0000000" }
                                }
                            }

                            /* Resolution / Live badge */
                            Rectangle {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                height: 18
                                width: resTxt.implicitWidth + 8
                                radius: 4
                                color: (cardItem.modelData.is_live || cardItem.modelData.category === "live") ? Theme.accent : "#A0000000"

                                Text {
                                    id: resTxt
                                    anchors.centerIn: parent
                                    text: (cardItem.modelData.is_live || cardItem.modelData.category === "live") ? "LIVE" : (cardItem.modelData.resolution || "HD")
                                    font.family: "JetBrainsMono Nerd Font"
                                    font.pixelSize: Theme.fontPx(9)
                                    font.weight: Font.Bold
                                    color: (cardItem.modelData.is_live || cardItem.modelData.category === "live") ? "#111111" : "#FFFFFF"
                                }
                            }

                            /* Current Wallpaper Badge */
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.margins: 6
                                height: 18
                                width: curBadgeRow.implicitWidth + 10
                                radius: 4
                                color: Theme.accent
                                visible: cardItem.isCurrent

                                RowLayout {
                                    id: curBadgeRow
                                    anchors.centerIn: parent
                                    spacing: 3
                                    Text {
                                        text: "check"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 11
                                        color: "#111111"
                                    }
                                    Text {
                                        text: "Active"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(9)
                                        font.weight: Font.Bold
                                        color: "#111111"
                                    }
                                }
                            }

                            /* Applying / Downloading Overlay */
                            Rectangle {
                                anchors.fill: parent
                                color: "#B8000000"
                                visible: cardItem.isDownloading

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "progress_activity"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 24
                                        color: Theme.accent

                                        NumberAnimation on rotation {
                                            from: 0; to: 360; duration: 900
                                            loops: Animation.Infinite
                                            easing.type: Easing.Linear
                                            running: cardItem.isDownloading
                                        }
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: "Applying..."
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: Font.Bold
                                        color: "#FFFFFF"
                                    }
                                }
                            }

                            /* Illuminated hover sheen */
                            Rectangle {
                                anchors.fill: parent
                                radius: tile.radius
                                color: Qt.alpha(Theme.accentLit, 0.08)
                                visible: tileHov.containsMouse && !cardItem.isCurrent
                                opacity: tileHov.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }

                            /* Interactive hover action pill */
                            Rectangle {
                                anchors.centerIn: parent
                                width: hoverPillRow.implicitWidth + 20
                                height: 28
                                radius: 14
                                color: Qt.alpha(Theme.bg, 0.90)
                                border.color: Theme.accentLit
                                border.width: 1
                                visible: !cardItem.isCurrent && !cardItem.isDownloading
                                opacity: tileHov.containsMouse ? 1.0 : 0.0
                                scale: tileHov.containsMouse ? 1.0 : 0.84
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                                RowLayout {
                                    id: hoverPillRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: cardItem.modelData.is_local ? "wallpaper" : "download"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 13
                                        color: Theme.accentLit
                                    }
                                    Text {
                                        text: cardItem.modelData.is_local ? "Apply" : "Get"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: Font.Bold
                                        color: Theme.fg
                                    }
                                }
                            }

                            /* Click to Apply (Local) or Download & Apply (Wallhaven) */
                            MouseArea {
                                id: tileHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectWallpaper(cardItem.modelData)
                            }
                        }
                    }

                    footer: Item {
                        width: wpGrid.width
                        height: (root.activeSource === "wallhaven" && root.wallpapers.length > 0) ? 44 : 8
                        visible: root.activeSource === "wallhaven" && root.wallpapers.length > 0

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                height: 28
                                width: 130
                                radius: 8
                                color: loadMoreHov.containsMouse ? Theme.bgHover : Qt.alpha(Theme.fg, 0.06)
                                border.color: Qt.alpha(Theme.fg, 0.12)
                                border.width: 1
                                scale: loadMoreHov.pressed ? 0.95 : (loadMoreHov.containsMouse ? 1.03 : 1.0)
                                Behavior on scale { NumberAnimation { duration: Theme.motionDurationShort2; easing.type: Theme.easingEmphasized } }

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text {
                                        text: root.isLoadingMore ? "progress_activity" : "expand_more"
                                        font.family: Theme.fontIcon
                                        font.pixelSize: 14
                                        color: Theme.accent

                                        NumberAnimation on rotation {
                                            from: 0; to: 360; duration: 800
                                            loops: Animation.Infinite
                                            easing.type: Easing.Linear
                                            running: root.isLoadingMore
                                        }
                                    }
                                    Text {
                                        text: root.isLoadingMore ? "Loading more..." : (root.hasMore ? "Load more" : "End of results")
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: Theme.fontPx(11)
                                        font.weight: Font.Medium
                                        color: Theme.fgDim
                                    }
                                }

                                MouseArea {
                                    id: loadMoreHov
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    enabled: root.hasMore && !root.isLoadingMore
                                    onClicked: root.fetchMore()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
