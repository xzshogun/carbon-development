import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"

Item {
    id: root

    implicitWidth: 800
    implicitHeight: 600

    readonly property string wallpaperDir: (Quickshell.env("HOME") || "") + "/Pictures/Wallpapers"
    readonly property string stateFile: (Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")) + "/current_wallpaper_path"
    readonly property string hyprStateFile: (Quickshell.env("HOME") || "") + "/.config/hypr/current_wallpaper_path"
    readonly property string ambientGlowFile: (Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")) + "/ambient_glow_state"

    property string currentWallpaperPath: ""
    property var localWallpapers: []
    property string activeScheme: "Tonal Spot"
    property bool liveBgPaused: false

    // Hyprland compositor options
    property real blurRadius: 5
    property real gapsOut: 6
    property real activeOpacity: 1.0
    property real inactiveOpacity: 1.0
    property real borderWidth: 1
    property bool windowShadows: true
    property bool ambientGlow: false
    property bool m3Transitions: false

    // -----------------------------------------------------------------------
    // RUST BACKEND IPC SOCKET CLIENT (/tmp/carbon-hub.sock)
    // -----------------------------------------------------------------------
    Socket {
        id: hubSocket
        path: "/tmp/carbon-hub.sock"
        connected: true

        onConnectedChanged: {
            if (connected) {
                root.sendHub({ "module": "appearance", "action": "get_state" })
            }
        }

        parser: SplitParser {
            splitMarker: "\n"
            onRead: function(chunk) {
                var raw = chunk.trim()
                if (!raw) return
                try {
                    var resp = JSON.parse(raw)
                    if (resp && resp.status === "ok" && resp.data) {
                        if (resp.action === "get_state") {
                            var d = resp.data
                            if (d.hypr) {
                                if (d.hypr.blur !== undefined) root.blurRadius = d.hypr.blur
                                if (d.hypr.gaps !== undefined) root.gapsOut = d.hypr.gaps
                                if (d.hypr.active_opacity !== undefined) root.activeOpacity = d.hypr.active_opacity
                                if (d.hypr.inactive_opacity !== undefined) root.inactiveOpacity = d.hypr.inactive_opacity
                                if (d.hypr.border !== undefined) root.borderWidth = d.hypr.border
                                if (d.hypr.shadow !== undefined) root.windowShadows = d.hypr.shadow
                            }
                            if (d.current_wallpaper) {
                                root.currentWallpaperPath = d.current_wallpaper
                            }
                            if (d.wallpapers && Array.isArray(d.wallpapers) && d.wallpapers.length > 0) {
                                root.localWallpapers = d.wallpapers
                            }
                        } else if (resp.action === "set_wallpaper" || resp.action === "shuffle_wallpaper") {
                            if (resp.data && resp.data.path) {
                                root.currentWallpaperPath = resp.data.path
                            }
                        } else if (resp.action === "list_wallpapers") {
                            if (Array.isArray(resp.data)) {
                                root.localWallpapers = resp.data
                            }
                        }
                    }
                } catch (e) {
                    console.log("[AppearanceTab] Socket parse error:", e)
                }
            }
        }
    }

    Timer {
        id: reconnectTimer
        interval: 1500
        repeat: true
        running: !hubSocket.connected
        onTriggered: {
            hubSocket.connected = true
        }
    }

    function sendHub(obj) {
        if (hubSocket.connected) {
            hubSocket.write(JSON.stringify(obj) + "\n")
            hubSocket.flush()
        }
    }

    // Debounce timers for 60fps real-time compositor sliders
    Timer {
        id: blurDebounce
        interval: 16
        repeat: false
        onTriggered: root.sendHub({ "module": "appearance", "action": "set_blur", "value": root.blurRadius })
    }
    function queueBlur(val) {
        root.blurRadius = val
        blurDebounce.restart()
    }

    Timer {
        id: gapsDebounce
        interval: 16
        repeat: false
        onTriggered: root.sendHub({ "module": "appearance", "action": "set_gaps", "value": root.gapsOut })
    }
    function queueGaps(val) {
        root.gapsOut = val
        gapsDebounce.restart()
    }

    Timer {
        id: activeOpacityDebounce
        interval: 16
        repeat: false
        onTriggered: root.sendHub({ "module": "appearance", "action": "set_active_opacity", "value": root.activeOpacity })
    }
    function queueActiveOpacity(val) {
        root.activeOpacity = val
        activeOpacityDebounce.restart()
    }

    Timer {
        id: inactiveOpacityDebounce
        interval: 16
        repeat: false
        onTriggered: root.sendHub({ "module": "appearance", "action": "set_inactive_opacity", "value": root.inactiveOpacity })
    }
    function queueInactiveOpacity(val) {
        root.inactiveOpacity = val
        inactiveOpacityDebounce.restart()
    }

    Timer {
        id: borderDebounce
        interval: 16
        repeat: false
        onTriggered: root.sendHub({ "module": "appearance", "action": "set_border", "value": root.borderWidth })
    }
    function queueBorder(val) {
        root.borderWidth = val
        borderDebounce.restart()
    }

    // FileView for live wallpaper state tracking (fallback/live sync across shell)
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

    FileView {
        id: glowFile
        path: root.ambientGlowFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: {
            var t = glowFile.text().trim()
            root.ambientGlow = (t === "1")
        }
        onFileChanged: {
            reload()
            var t = glowFile.text().trim()
            root.ambientGlow = (t === "1")
        }
    }

    Component.onCompleted: {
        root.sendHub({ "module": "appearance", "action": "get_state" })
    }

    // -----------------------------------------------------------------------
    // 2-COLUMN ASYMMETRIC SPLIT LAYOUT (Left: Gallery & Colors, Right: Compositor)
    // -----------------------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ===================================================================
        // LEFT COLUMN: Wallpapers & Matugen Engine (58%)
        // ===================================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.px(460)

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: leftColContent.implicitHeight + Theme.px(40)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: leftColContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.px(20)
                    spacing: Theme.px(16)

                    // Section Header: Wallpaper Gallery
                    Text {
                        text: "WALLPAPER GALLERY"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }

                    // Active Hero Wallpaper Preview (radius: Theme.px(10), clip: true, NO text overlay)
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(280)
                        radius: Theme.px(10)
                        color: Qt.rgba(0, 0, 0, 0.40)
                        border.color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        clip: true

                        Image {
                            id: heroWpImage
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: root.currentWallpaperPath ? (root.currentWallpaperPath.startsWith("file://") ? root.currentWallpaperPath : ("file://" + root.currentWallpaperPath)) : ""
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            sourceSize: Qt.size(1920, 1080)
                            cache: true

                            // Subtle loading / fallback placeholder
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(0, 0, 0, 0.40)
                                visible: heroWpImage.status !== Image.Ready
                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: Theme.px(8)
                                    Text {
                                        text: "󰸉"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(22)
                                        color: Qt.rgba(1, 1, 1, 0.35)
                                    }
                                    Text {
                                        text: "Loading Wallpaper Preview..."
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(12)
                                        color: Qt.rgba(1, 1, 1, 0.45)
                                    }
                                }
                            }
                        }
                    }

                    // Controls Row: [ ⤨ SHUFFLE RANDOM ] + Live BG Pause Badge
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.px(12)

                        // Flush Shuffle Random Button
                        Rectangle {
                            Layout.preferredWidth: shuffleText.implicitWidth + Theme.px(24)
                            Layout.preferredHeight: Theme.px(32)
                            radius: Theme.px(6)
                            color: shuffleMouse.pressed ? Qt.rgba(1, 1, 1, 0.14) : (shuffleMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04))
                            border.color: Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1

                            Text {
                                id: shuffleText
                                anchors.centerIn: parent
                                text: "⤨  SHUFFLE RANDOM"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(11)
                                font.weight: Font.DemiBold
                                color: Qt.rgba(1, 1, 1, 0.90)
                            }

                            MouseArea {
                                id: shuffleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.sendHub({ "module": "appearance", "action": "shuffle_wallpaper" })
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Live BG Pause Toggle Row
                        RowLayout {
                            spacing: Theme.px(8)
                            Text {
                                text: "Live BG Pause"
                                font.family: Theme.font
                                font.pixelSize: Theme.fontPx(12)
                                color: Qt.rgba(1, 1, 1, 0.70)
                            }

                            TerminalStatusBadge {
                                checked: root.liveBgPaused
                                onClicked: {
                                    root.liveBgPaused = !root.liveBgPaused
                                    root.sendHub({ "module": "appearance", "action": "pause_live_bg", "value": root.liveBgPaused })
                                }
                            }
                        }
                    }

                    // Horizontal Scrolling Thumbnails Carousel (140x80, radius 8, NO text overlays)
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(88)

                        ListView {
                            id: thumbList
                            anchors.fill: parent
                            orientation: ListView.Horizontal
                            spacing: Theme.px(12)
                            clip: true
                            model: root.localWallpapers

                            delegate: Rectangle {
                                width: Theme.px(140)
                                height: Theme.px(80)
                                radius: Theme.px(8)
                                clip: true
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.color: (modelData.path === root.currentWallpaperPath) ? Theme.primary : (thumbMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.30) : Qt.rgba(1, 1, 1, 0.10))
                                border.width: (modelData.path === root.currentWallpaperPath) ? 2 : 1

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: (modelData.path === root.currentWallpaperPath) ? Theme.px(2) : 0
                                    fillMode: Image.PreserveAspectCrop
                                    source: modelData.thumb ? (modelData.thumb.startsWith("file://") ? modelData.thumb : ("file://" + modelData.thumb)) : (modelData.path ? (modelData.path.startsWith("file://") ? modelData.path : ("file://" + modelData.path)) : "")
                                    asynchronous: true
                                    smooth: true
                                    mipmap: true
                                    sourceSize: Qt.size(280, 160)
                                    cache: true
                                }

                                MouseArea {
                                    id: thumbMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.currentWallpaperPath = modelData.path
                                        root.sendHub({ "module": "appearance", "action": "set_wallpaper", "path": modelData.path })
                                    }
                                }
                            }
                        }
                    }

                    // Section Divider
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // =======================================================
                    // MATUGEN COLOR ENGINE
                    // =======================================================
                    Text {
                        text: "Matugen Color Scheme"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(12)
                        font.weight: Font.Medium
                        color: Qt.rgba(1, 1, 1, 0.85)
                    }

                    // 5 Live Circular Color Chips (radius: Theme.px(12), 24px)
                    RowLayout {
                        spacing: Theme.px(14)

                        Repeater {
                            model: [
                                { name: "Primary", col: Theme.primary },
                                { name: "Secondary", col: Theme.secondary },
                                { name: "Tertiary", col: Theme.tertiary },
                                { name: "Surface", col: Theme.surface },
                                { name: "Error", col: Theme.error }
                            ]

                            delegate: ColumnLayout {
                                spacing: Theme.px(4)
                                Layout.alignment: Qt.AlignHCenter

                                Rectangle {
                                    width: Theme.px(24)
                                    height: Theme.px(24)
                                    radius: Theme.px(12)
                                    color: modelData.col
                                    border.color: Qt.rgba(1, 1, 1, 0.20)
                                    border.width: 1

                                    Behavior on color { ColorAnimation { duration: 250 } }
                                }

                                Text {
                                    text: modelData.name
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(9)
                                    color: Qt.rgba(1, 1, 1, 0.40)
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }

                    // Segmented Scheme Selector: Tonal Spot | Expressive | Fidelity | Monochrome
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Repeater {
                            model: ["Tonal Spot", "Expressive", "Fidelity", "Monochrome"]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(30)
                                color: (root.activeScheme === modelData) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : (segMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.02))
                                border.color: (root.activeScheme === modelData) ? Theme.primary : Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(11)
                                    font.weight: (root.activeScheme === modelData) ? Font.DemiBold : Font.Normal
                                    color: (root.activeScheme === modelData) ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                }

                                MouseArea {
                                    id: segMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.activeScheme = modelData
                                        root.sendHub({ "module": "appearance", "action": "set_scheme", "scheme": modelData })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ===================================================================
        // 1PX VERTICAL HAIRLINE SEPARATOR
        // ===================================================================
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ===================================================================
        // RIGHT COLUMN: Compositor & Window Rules (42%)
        // ===================================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.px(340)

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: rightColContent.implicitHeight + Theme.px(40)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: rightColContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.px(20)
                    spacing: Theme.px(16)

                    // Section Header: Hyprland Compositor Controls
                    Text {
                        text: "COMPOSITOR & EFFECTS"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }

                    // 5 Razor Wire & Diamond Sliders with Debounced Realtime Dispatch
                    RazorWireSlider {
                        Layout.fillWidth: true
                        label: "Blur Radius"
                        from: 0
                        to: 20
                        stepSize: 1
                        decimals: 0
                        unit: "px"
                        value: root.blurRadius
                        onMoved: (val) => root.queueBlur(val)
                    }

                    RazorWireSlider {
                        Layout.fillWidth: true
                        label: "Gaps Out"
                        from: 0
                        to: 32
                        stepSize: 1
                        decimals: 0
                        unit: "px"
                        value: root.gapsOut
                        onMoved: (val) => root.queueGaps(val)
                    }

                    RazorWireSlider {
                        Layout.fillWidth: true
                        label: "Active Opacity"
                        from: 0.20
                        to: 1.00
                        stepSize: 0.05
                        decimals: 2
                        value: root.activeOpacity
                        onMoved: (val) => root.queueActiveOpacity(val)
                    }

                    RazorWireSlider {
                        Layout.fillWidth: true
                        label: "Inactive Opacity"
                        from: 0.20
                        to: 1.00
                        stepSize: 0.05
                        decimals: 2
                        value: root.inactiveOpacity
                        onMoved: (val) => root.queueInactiveOpacity(val)
                    }

                    RazorWireSlider {
                        Layout.fillWidth: true
                        label: "Border Width"
                        from: 0
                        to: 8
                        stepSize: 1
                        decimals: 0
                        unit: "px"
                        value: root.borderWidth
                        onMoved: (val) => root.queueBorder(val)
                    }

                    // Structural Hairline
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    // Feature Matrix Header
                    Text {
                        text: "FEATURE TOGGLE MATRIX"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }

                    // Feature 1: Enable Window Shadows
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Enable Window Shadows"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(13)
                            font.weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.85)
                            Layout.fillWidth: true
                        }

                        TerminalStatusBadge {
                            checked: root.windowShadows
                            onClicked: {
                                root.windowShadows = !root.windowShadows
                                root.sendHub({ "module": "appearance", "action": "set_shadow", "value": root.windowShadows })
                            }
                        }
                    }

                    // Feature 2: Ambient Glow (Audio Borders)
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Ambient Glow (Audio Borders)"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(13)
                            font.weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.85)
                            Layout.fillWidth: true
                        }

                        TerminalStatusBadge {
                            checked: root.ambientGlow
                            onClicked: {
                                root.ambientGlow = !root.ambientGlow
                                root.sendHub({ "module": "appearance", "action": "set_ambient_glow", "value": root.ambientGlow })
                            }
                        }
                    }

                    // Feature 3: Material-3 Transitions (Dimmed Opacity 0.40 Placeholder)
                    RowLayout {
                        Layout.fillWidth: true
                        opacity: 0.40

                        Text {
                            text: "Material-3 Transitions"
                            font.family: Theme.font
                            font.pixelSize: Theme.fontPx(13)
                            font.weight: Font.Medium
                            color: Qt.rgba(1, 1, 1, 0.85)
                            Layout.fillWidth: true
                        }

                        TerminalStatusBadge {
                            checked: false
                            interactive: false
                        }
                    }
                }
            }
        }
    }
}
