import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"

/**
 * PanelsCanvasTab.qml:
 * Carbon Shell // Panels & Canvas Architectural Studio
 *
 * Implements:
 *   1. Segmented Switcher for the 3 Core Panels:
 *        - Side Panel (Focus HUD Drawer)
 *        - Main Center Panel (Command Center Floating Card)
 *        - Spatial Canvas (2D Blueprint Layout Editor)
 *   2. General Settings Section placed first for each panel type:
 *        - Docking positions, keybind triggers, edge sensors, timers, snap controls.
 *   3. Architectural Blueprint Background:
 *        - Deep blueprint styling with dual-frequency precision grid, coordinate crosshairs, and rulers.
 *   4. Side Panel (Focus HUD):
 *        - Authentic left-edge sliding drawer with working countdown timer, duration chips, and ambient ASMR.
 *   5. Main Center Panel (Command Center):
 *        - Totally interactable top/bottom center floating card dock featuring Overview, GitHub, and live Telemetry graphs.
 *   6. Spatial Canvas (2D Layout Editor):
 *        - 5-Node layout where tiles display ONLY the clean Carbon brand logo (CarbonLogoIcon),
 *          smoothly draggable to reposition tiles with laser connectors and Zoom Focus capability.
 */
Item {
    id: root

    implicitWidth: 800
    implicitHeight: 600

    // Active panel: 0 = Side Panel (Focus HUD), 1 = Main Center Panel (Command Center), 2 = Spatial Canvas
    property int currentPanel: 1

    // Sub-view: "Settings" or "Blueprint"
    property string activeSubSection: "Settings" // "Settings" | "Blueprint"

    // ── Global & Shared Settings ─────────────────────────────────────────────
    readonly property string configDir: Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")
    property real globalPanelOpacity: 0.92
    property bool globalBlurEnabled: true
    property bool clickOutsideDismiss: true
    property bool escKeyDismiss: true
    property string activeKeybindFocus: "SUPER + SHIFT + F"
    property string activeKeybindCenter: "SUPER + G"
    property string activeKeybindCanvas: "SUPER + `"

    // ── Side Panel (Focus HUD) Configuration ─────────────────────────────────
    property bool sideEdgeHoverEnabled: true
    property int sideEdgeSensorWidth: 4
    property int sideDefaultFocusMin: 25
    property int sideDefaultBreakMin: 5
    property string sideDefaultSound: "rain" // "rain" | "binaural" | "white" | "none"
    property bool sideWaylandBlackout: true

    // Side Panel Preview State (Interactive)
    property bool sideTimerRunning: false
    property int sideRemainingSeconds: 25 * 60
    property string sideActiveMode: "focus" // "focus" | "break"
    property string sideActiveSound: "none"
    property var sideTasks: [
        { title: "Architectural Blueprint verification", done: true },
        { title: "CalDAV event synchronization", done: false },
        { title: "Low-latency IPC socket healthcheck", done: false }
    ]

    Timer {
        id: sideCountdownTimer
        interval: 1000
        repeat: true
        running: root.sideTimerRunning
        onTriggered: {
            if (root.sideRemainingSeconds > 0) {
                root.sideRemainingSeconds--
            } else {
                root.sideTimerRunning = false
            }
        }
    }

    function toggleSideTimer() {
        root.sideTimerRunning = !root.sideTimerRunning
    }

    function resetSideTimer(minutes) {
        root.sideTimerRunning = false
        var m = minutes || (root.sideActiveMode === "focus" ? root.sideDefaultFocusMin : root.sideDefaultBreakMin)
        root.sideRemainingSeconds = m * 60
    }

    // ── Main Center Panel (Command Center) Configuration ─────────────────────
    property string centerDockEdge: "bottom" // "bottom" | "top"
    property string centerDefaultChannel: "overview" // "overview" | "github" | "telemetry"
    property string centerWeatherCity: "Patna"
    property string centerWeatherTemp: "22°C"
    property string centerWeatherDesc: "Clear Sky"
    property int centerTelemetryInterval: 1000 // ms
    property bool centerAnimatingOut: false

    // Center Panel Preview State (Interactive)
    property string centerCurrentChannel: "overview"
    property real centerTelemetryTick: 0.0
    property var centerCpuHistory: [28, 35, 42, 38, 55, 62, 48, 40, 45, 52, 60, 58, 49, 44, 38, 42, 50, 65, 58, 48, 42, 39, 45, 54, 48, 52, 46, 40]
    property var centerRamHistory: [52, 52, 53, 53, 54, 54, 55, 55, 54, 54, 55, 56, 56, 55, 55, 54, 55, 55, 56, 56, 57, 57, 56, 56, 55, 55, 56, 56]
    property string centerTelemetrySubMode: "cpu" // "cpu" | "ram"
    property string centerSelectedNote: "Project Notes // Antigravity"
    property var centerClipboardItems: [
        { text: "git checkout -b feat/panels-canvas-studio", time: "2m ago" },
        { text: "https://github.com/xzshogun/carbon-development", time: "14m ago" },
        { text: "hyprctl dispatch workspace 1", time: "1h ago" }
    ]

    Timer {
        id: centerTelemetryTicker
        interval: root.centerTelemetryInterval
        repeat: true
        running: root.currentPanel === 1 && root.centerCurrentChannel === "telemetry"
        onTriggered: {
            var newCpuVal = Math.round(30 + Math.random() * 45)
            var newRamVal = Math.round(52 + Math.random() * 6)
            var cList = root.centerCpuHistory.slice()
            cList.push(newCpuVal)
            while (cList.length > 28) cList.shift()
            root.centerCpuHistory = cList

            var rList = root.centerRamHistory.slice()
            rList.push(newRamVal)
            while (rList.length > 28) rList.shift()
            root.centerRamHistory = rList
        }
    }

    function saveCenterBarEdgeConfig(edge) {
        root.centerDockEdge = edge
        var script = "import json, os\n" +
            "dir = os.environ.get('CARBON_CONFIG_DIR', os.path.expanduser('~/.config/carbon'))\n" +
            "os.makedirs(dir, exist_ok=True)\n" +
            "p1 = os.path.join(dir, 'carbon-bar-position.json')\n" +
            "d1 = json.load(open(p1)) if os.path.exists(p1) else {}\n" +
            "d1['mainBarEdge'] = '" + edge + "'\n" +
            "json.dump(d1, open(p1, 'w'), indent=2)\n"
        Quickshell.execDetached(["python3", "-c", script])
    }

    // ── Spatial Canvas Configuration ─────────────────────────────────────────
    property string canvasDefaultView: "overview" // "overview" | "focused"
    property bool canvasGridSnap: true
    property real canvasDragDamping: 0.85
    property real canvasZoomScale: 0.42
    property bool canvasIsZoomFocused: false
    property int canvasFocusedNodeIndex: 0
    property real canvasPanX: 0
    property real canvasPanY: 0

    // 5-Node Model: Positions are relative to the canvas center (X: 0, Y: 0)
    // Only logos are displayed inside each node card!
    property var canvasNodes: [
        {
            id: "node_0_0",
            name: "WORKSPACE BLUEPRINT",
            badge: "[ 0,  0 ]",
            sub: "Core Window & Workspace Switcher",
            glyph: "grid_view",
            brandIcon: "󰣇",
            defaultX: 0,
            defaultY: 0,
            x: 0,
            y: 0,
            color: Theme.primary
        },
        {
            id: "node_m1_0",
            name: "CONNECTIVITY HUB",
            badge: "[ -1,  0 ]",
            sub: "Wi-Fi 6 & Bluetooth 5.3 Unified Deck",
            glyph: "wifi",
            brandIcon: "󰤨",
            defaultX: -260,
            defaultY: 0,
            x: -260,
            y: 0,
            color: "#4FC3F7"
        },
        {
            id: "node_1_0",
            name: "WALLPAPER & ENGINE",
            badge: "[  1,  0 ]",
            sub: "Studio Discovery & Matugen Engine",
            glyph: "palette",
            brandIcon: "󰸉",
            defaultX: 260,
            defaultY: 0,
            x: 260,
            y: 0,
            color: "#BA68C8"
        },
        {
            id: "node_0_m1",
            name: "QUICK FILE BROWSER",
            badge: "[  0, -1 ]",
            sub: "Aesthetic Files & Storage Deck",
            glyph: "folder_open",
            brandIcon: "󰉋",
            defaultX: 0,
            defaultY: -170,
            x: 0,
            y: -170,
            color: "#FFB74D"
        },
        {
            id: "node_0_1",
            name: "SYSTEM CONTROL & MEDIA",
            badge: "[  0,  1 ]",
            sub: "MPRIS Media Mixer & Session Power",
            glyph: "graphic_eq",
            brandIcon: "󰓃",
            defaultX: 0,
            defaultY: 170,
            x: 0,
            y: 170,
            color: "#4DB6AC"
        }
    ]

    function resetCanvasNodes() {
        var copy = []
        for (var i = 0; i < root.canvasNodes.length; i++) {
            var n = Object.assign({}, root.canvasNodes[i])
            n.x = n.defaultX
            n.y = n.defaultY
            copy.push(n)
        }
        root.canvasNodes = copy
        zoomToCanvasOverview()
    }

    function zoomToCanvasNode(index) {
        if (index < 0 || index >= root.canvasNodes.length) return
        root.canvasFocusedNodeIndex = index
        root.canvasIsZoomFocused = true
        var targetNode = root.canvasNodes[index]
        // Center the camera on this node
        root.canvasPanX = -targetNode.x
        root.canvasPanY = -targetNode.y
        root.canvasZoomScale = 1.0
    }

    function zoomToCanvasOverview() {
        root.canvasIsZoomFocused = false
        root.canvasPanX = 0
        root.canvasPanY = 0
        root.canvasZoomScale = 0.42
    }

    // ── External Trigger Helpers ─────────────────────────────────────────────
    function triggerExternalLaunch(cmd) {
        Quickshell.execDetached(["sh", (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/carbon-ipc.sh", cmd])
    }

    // ══════════════════════════════════════════════════════════════════════════
    // MAIN LAYOUT
    // ══════════════════════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // =====================================================================
        // 1. TOP HEADER & PANEL SWITCHER (Pill Bar)
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(64)
            color: Qt.rgba(0, 0, 0, 0.22)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.px(20)
                anchors.rightMargin: Theme.px(20)
                spacing: Theme.px(16)

                // Title & Tagline
                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "PANELS & CANVAS STUDIO"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(14)
                        font.weight: Font.Bold
                        color: Theme.primary
                    }
                    Text {
                        text: "Architectural blueprint layout customizer & interactive deck manager"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(11)
                        color: Qt.rgba(1, 1, 1, 0.45)
                    }
                }

                Item { Layout.fillWidth: true }

                // Rubber-Segment Category Selector
                Rectangle {
                    Layout.preferredHeight: Theme.px(38)
                    Layout.preferredWidth: Theme.px(420)
                    radius: Theme.px(19)
                    color: Qt.rgba(0, 0, 0, 0.45)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.px(3)
                        spacing: Theme.px(4)

                        // Button 0: Side Panel
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(16)
                            color: (root.currentPanel === 0) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (p0Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.color: (root.currentPanel === 0) ? Theme.primary : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.px(6)
                                Text {
                                    text: "󰍹"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(13)
                                    color: (root.currentPanel === 0) ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                }
                                Text {
                                    text: "Side Panel"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(11.5)
                                    font.weight: (root.currentPanel === 0) ? Font.DemiBold : Font.Normal
                                    color: (root.currentPanel === 0) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.65)
                                }
                            }
                            MouseArea {
                                id: p0Mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentPanel = 0
                            }
                        }

                        // Button 1: Main Center Panel
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(16)
                            color: (root.currentPanel === 1) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (p1Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.color: (root.currentPanel === 1) ? Theme.primary : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.px(6)
                                Text {
                                    text: "󰕮"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(13)
                                    color: (root.currentPanel === 1) ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                }
                                Text {
                                    text: "Center Panel"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(11.5)
                                    font.weight: (root.currentPanel === 1) ? Font.DemiBold : Font.Normal
                                    color: (root.currentPanel === 1) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.65)
                                }
                            }
                            MouseArea {
                                id: p1Mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentPanel = 1
                            }
                        }

                        // Button 2: Spatial Canvas
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(16)
                            color: (root.currentPanel === 2) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (p2Mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            border.color: (root.currentPanel === 2) ? Theme.primary : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: Theme.px(6)
                                Text {
                                    text: "󰘚"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(13)
                                    color: (root.currentPanel === 2) ? Theme.primary : Qt.rgba(1, 1, 1, 0.65)
                                }
                                Text {
                                    text: "Spatial Canvas"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(11.5)
                                    font.weight: (root.currentPanel === 2) ? Font.DemiBold : Font.Normal
                                    color: (root.currentPanel === 2) ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.65)
                                }
                            }
                            MouseArea {
                                id: p2Mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.currentPanel = 2
                            }
                        }
                    }
                }

                // Sub-section toggle: [ General Settings | Blueprint Preview ]
                Rectangle {
                    Layout.preferredHeight: Theme.px(34)
                    Layout.preferredWidth: Theme.px(190)
                    radius: Theme.px(6)
                    color: Qt.rgba(0, 0, 0, 0.35)
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(5)
                            color: root.activeSubSection === "Settings" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : "transparent"
                            border.color: root.activeSubSection === "Settings" ? Theme.primary : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "SETTINGS"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(10)
                                font.weight: Font.Bold
                                color: root.activeSubSection === "Settings" ? Theme.primary : Qt.rgba(1, 1, 1, 0.50)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeSubSection = "Settings"
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.px(5)
                            color: root.activeSubSection === "Blueprint" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : "transparent"
                            border.color: root.activeSubSection === "Blueprint" ? Theme.primary : "transparent"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "BLUEPRINT"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(10)
                                font.weight: Font.Bold
                                color: root.activeSubSection === "Blueprint" ? Theme.primary : Qt.rgba(1, 1, 1, 0.50)
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeSubSection = "Blueprint"
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // 2. MAIN WORKSPACE AREA (Split or View Stack)
        // =====================================================================
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ─────────────────────────────────────────────────────────────────
            // VIEW A: GENERAL SETTINGS (First Section per User Request)
            // ─────────────────────────────────────────────────────────────────
            Flickable {
                anchors.fill: parent
                visible: root.activeSubSection === "Settings"
                contentWidth: width
                contentHeight: settingsContentCol.implicitHeight + Theme.px(48)
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: settingsContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.px(24)
                    spacing: Theme.px(20)

                    // ── Active Panel Identity Banner ──
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(74)
                        radius: Theme.px(10)
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.px(16)
                            spacing: Theme.px(14)

                            Rectangle {
                                Layout.preferredWidth: Theme.px(42)
                                Layout.preferredHeight: Theme.px(42)
                                radius: Theme.px(8)
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                                border.color: Theme.primary
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: root.currentPanel === 0 ? "󰍹" : (root.currentPanel === 1 ? "󰕮" : "󰘚")
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(20)
                                    color: Theme.primary
                                }
                            }

                            ColumnLayout {
                                spacing: 2
                                Text {
                                    text: root.currentPanel === 0
                                          ? "NOTCH SIDE PANEL (FOCUS HUD)"
                                          : (root.currentPanel === 1 ? "MAIN CENTER PANEL (COMMAND CENTER)" : "2D SPATIAL CANVAS (OS SUITE)")
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(13.5)
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                }
                                Text {
                                    text: root.currentPanel === 0
                                          ? "Left screen-border sliding focus drawer with Pomodoro timer, binaural sound, and task deck."
                                          : (root.currentPanel === 1
                                             ? "Central floating dock with Notes, Calendar, Recent Apps, GitHub PR uplink, and live Telemetry waves."
                                             : "5-Node spatial blueprint suite with draggable logo-only cards and smooth Zoom Focus.")
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(11)
                                    color: Qt.rgba(1, 1, 1, 0.65)
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Quick Jump to Blueprint Preview Button
                            Rectangle {
                                Layout.preferredHeight: Theme.px(32)
                                Layout.preferredWidth: jumpBtnText.implicitWidth + Theme.px(24)
                                radius: Theme.px(6)
                                color: jumpBtnMouse.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                                border.color: Theme.primary
                                border.width: 1

                                Text {
                                    id: jumpBtnText
                                    anchors.centerIn: parent
                                    text: "OPEN BLUEPRINT CANVAS ↗"
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(10)
                                    font.weight: Font.Bold
                                    color: jumpBtnMouse.containsMouse ? "#000000" : Theme.primary
                                }
                                MouseArea {
                                    id: jumpBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.activeSubSection = "Blueprint"
                                }
                            }
                        }
                    }

                    // ── PANEL-SPECIFIC GENERAL SETTINGS ──

                    // 1. SIDE PANEL SETTINGS
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.currentPanel === 0
                        spacing: Theme.px(12)

                        Text {
                            text: "GENERAL BEHAVIOR & TRIGGERS"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.50)
                        }

                        // Card: Edge Trigger & Screen Blackout
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: sideCard1Col.implicitHeight + Theme.px(28)
                            radius: Theme.px(8)
                            color: Qt.rgba(0, 0, 0, 0.30)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            ColumnLayout {
                                id: sideCard1Col
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.px(14)
                                spacing: Theme.px(12)

                                // Row 1: Edge Hover Sensor
                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: "Left Edge Hover Reveal"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.weight: Font.DemiBold; color: "#FFFFFF" }
                                        Text { text: "Automatically slide out the Focus HUD when cursor hits leftmost screen boundary"; font.family: Theme.font; font.pixelSize: Theme.fontPx(11); color: Qt.rgba(1, 1, 1, 0.45) }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Switch {
                                        checked: root.sideEdgeHoverEnabled
                                        onToggled: root.sideEdgeHoverEnabled = checked
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.06) }

                                // Row 2: Wayland Full Blackout
                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: "Wayland Deep Focus Blackout"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.weight: Font.DemiBold; color: "#FFFFFF" }
                                        Text { text: "Dim desktop wallpaper and background apps to eliminate distractions during focus"; font.family: Theme.font; font.pixelSize: Theme.fontPx(11); color: Qt.rgba(1, 1, 1, 0.45) }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Switch {
                                        checked: root.sideWaylandBlackout
                                        onToggled: root.sideWaylandBlackout = checked
                                    }
                                }
                            }
                        }

                        Text {
                            text: "DEFAULT SESSION TIMERS & SOUNDS"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.50)
                            Layout.topMargin: Theme.px(8)
                        }

                        // Card: Durations & Ambient Audio
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: sideCard2Col.implicitHeight + Theme.px(28)
                            radius: Theme.px(8)
                            color: Qt.rgba(0, 0, 0, 0.30)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            ColumnLayout {
                                id: sideCard2Col
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.px(14)
                                spacing: Theme.px(14)

                                // Focus Duration Chips
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Focus Duration"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); color: "#FFFFFF"; Layout.preferredWidth: Theme.px(160) }
                                    RowLayout {
                                        spacing: Theme.px(8)
                                        Repeater {
                                            model: [15, 25, 45, 60]
                                            delegate: Rectangle {
                                                width: Theme.px(64); height: Theme.px(28); radius: Theme.px(6)
                                                color: root.sideDefaultFocusMin === modelData ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                                border.color: root.sideDefaultFocusMin === modelData ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                                border.width: 1
                                                Text { anchors.centerIn: parent; text: modelData + " MIN"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: root.sideDefaultFocusMin === modelData ? Theme.primary : Qt.rgba(1, 1, 1, 0.70) }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.sideDefaultFocusMin = modelData; root.resetSideTimer(modelData) } }
                                            }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.06) }

                                // Ambient Sound Preset Chips
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Default Ambient Noise"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); color: "#FFFFFF"; Layout.preferredWidth: Theme.px(160) }
                                    RowLayout {
                                        spacing: Theme.px(8)
                                        Repeater {
                                            model: [
                                                { id: "rain", label: "🌧 Rain ASMR" },
                                                { id: "binaural", label: "🎧 Binaural" },
                                                { id: "white", label: "📻 White Noise" },
                                                { id: "none", label: "🔇 Mute" }
                                            ]
                                            delegate: Rectangle {
                                                width: Theme.px(100); height: Theme.px(28); radius: Theme.px(6)
                                                color: root.sideDefaultSound === modelData.id ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                                border.color: root.sideDefaultSound === modelData.id ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                                border.width: 1
                                                Text { anchors.centerIn: parent; text: modelData.label; font.family: Theme.font; font.pixelSize: Theme.fontPx(10); font.weight: Font.DemiBold; color: root.sideDefaultSound === modelData.id ? Theme.primary : Qt.rgba(1, 1, 1, 0.70) }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.sideDefaultSound = modelData.id }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2. MAIN CENTER PANEL SETTINGS
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.currentPanel === 1
                        spacing: Theme.px(12)

                        Text {
                            text: "DOCKING ORIENTATION & GEOMETRY"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.50)
                        }

                        // Card: Dock Position & Starting Channel
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: centerCard1Col.implicitHeight + Theme.px(28)
                            radius: Theme.px(8)
                            color: Qt.rgba(0, 0, 0, 0.30)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            ColumnLayout {
                                id: centerCard1Col
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.px(14)
                                spacing: Theme.px(14)

                                // Dock Edge Selector
                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: "Screen Dock Attachment"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.weight: Font.DemiBold; color: "#FFFFFF" }
                                        Text { text: "Choose whether the Command Center floats up from the bottom or drops down from top center"; font.family: Theme.font; font.pixelSize: Theme.fontPx(11); color: Qt.rgba(1, 1, 1, 0.45) }
                                    }
                                    Item { Layout.fillWidth: true }
                                    RowLayout {
                                        spacing: Theme.px(8)
                                        Rectangle {
                                            width: Theme.px(110); height: Theme.px(28); radius: Theme.px(6)
                                            color: root.centerDockEdge === "bottom" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: root.centerDockEdge === "bottom" ? Theme.primary : Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                            Text { anchors.centerIn: parent; text: "BOTTOM CENTER"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9.5); font.weight: Font.Bold; color: root.centerDockEdge === "bottom" ? Theme.primary : Qt.rgba(1, 1, 1, 0.70) }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveCenterBarEdgeConfig("bottom") }
                                        }
                                        Rectangle {
                                            width: Theme.px(110); height: Theme.px(28); radius: Theme.px(6)
                                            color: root.centerDockEdge === "top" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: root.centerDockEdge === "top" ? Theme.primary : Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                            Text { anchors.centerIn: parent; text: "TOP CENTER"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9.5); font.weight: Font.Bold; color: root.centerDockEdge === "top" ? Theme.primary : Qt.rgba(1, 1, 1, 0.70) }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.saveCenterBarEdgeConfig("top") }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.06) }

                                // Default Initial Channel
                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: "Default Startup Channel"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.weight: Font.DemiBold; color: "#FFFFFF" }
                                        Text { text: "The primary tab visible whenever the Command Center panel is opened"; font.family: Theme.font; font.pixelSize: Theme.fontPx(11); color: Qt.rgba(1, 1, 1, 0.45) }
                                    }
                                    Item { Layout.fillWidth: true }
                                    RowLayout {
                                        spacing: Theme.px(8)
                                        Repeater {
                                            model: ["overview", "github", "telemetry"]
                                            delegate: Rectangle {
                                                width: Theme.px(90); height: Theme.px(28); radius: Theme.px(6)
                                                color: root.centerDefaultChannel === modelData ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                                border.color: root.centerDefaultChannel === modelData ? Theme.primary : Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                                Text { anchors.centerIn: parent; text: modelData.toUpperCase(); font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9.5); font.weight: Font.Bold; color: root.centerDefaultChannel === modelData ? Theme.primary : Qt.rgba(1, 1, 1, 0.70) }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.centerDefaultChannel = modelData; root.centerCurrentChannel = modelData } }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "DATA UPLINKS & TELEMETRY STREAM"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.50)
                            Layout.topMargin: Theme.px(8)
                        }

                        // Card: Weather City & Telemetry Sample Rate
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: centerCard2Col.implicitHeight + Theme.px(28)
                            radius: Theme.px(8)
                            color: Qt.rgba(0, 0, 0, 0.30)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            ColumnLayout {
                                id: centerCard2Col
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.px(14)
                                spacing: Theme.px(14)

                                // Weather City Input
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Weather Location City"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); color: "#FFFFFF"; Layout.preferredWidth: Theme.px(180) }
                                    Rectangle {
                                        Layout.preferredWidth: Theme.px(160); Layout.preferredHeight: Theme.px(28); radius: Theme.px(6)
                                        color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.15); border.width: 1
                                        TextInput {
                                            anchors.fill: parent; anchors.margins: Theme.px(6)
                                            text: root.centerWeatherCity
                                            color: "#FFFFFF"; font.family: Theme.font; font.pixelSize: Theme.fontPx(11)
                                            verticalAlignment: TextInput.AlignVCenter
                                            onTextChanged: root.centerWeatherCity = text
                                        }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Text {
                                        text: root.centerWeatherTemp + " • " + root.centerWeatherDesc
                                        font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(11); color: Theme.primary
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.06) }

                                // Telemetry Stream Rate
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { text: "Telemetry Polling Rate"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); color: "#FFFFFF"; Layout.preferredWidth: Theme.px(180) }
                                    RowLayout {
                                        spacing: Theme.px(8)
                                        Repeater {
                                            model: [
                                                { ms: 500, label: "0.5s Fast" },
                                                { ms: 1000, label: "1.0s Norm" },
                                                { ms: 2500, label: "2.5s Eco" }
                                            ]
                                            delegate: Rectangle {
                                                width: Theme.px(80); height: Theme.px(28); radius: Theme.px(6)
                                                color: root.centerTelemetryInterval === modelData.ms ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                                border.color: root.centerTelemetryInterval === modelData.ms ? Theme.primary : Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                                Text { anchors.centerIn: parent; text: modelData.label; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9.5); font.weight: Font.Bold; color: root.centerTelemetryInterval === modelData.ms ? Theme.primary : Qt.rgba(1, 1, 1, 0.70) }
                                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.centerTelemetryInterval = modelData.ms }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 3. SPATIAL CANVAS SETTINGS
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.currentPanel === 2
                        spacing: Theme.px(12)

                        Text {
                            text: "2D CANVAS GEOMETRY & DRAGGABLE PHYSICS"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(11)
                            font.weight: Font.Bold
                            color: Qt.rgba(1, 1, 1, 0.50)
                        }

                        // Card: Drag & Snap & Reset
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: canvasCard1Col.implicitHeight + Theme.px(28)
                            radius: Theme.px(8)
                            color: Qt.rgba(0, 0, 0, 0.30)
                            border.color: Qt.rgba(1, 1, 1, 0.08)
                            border.width: 1

                            ColumnLayout {
                                id: canvasCard1Col
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: Theme.px(14)
                                spacing: Theme.px(14)

                                // Snap to Grid Toggle
                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: "Magnetic 3x3 Grid Snapping"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.weight: Font.DemiBold; color: "#FFFFFF" }
                                        Text { text: "Snap dragged node tiles automatically to clean architectural grid positions"; font.family: Theme.font; font.pixelSize: Theme.fontPx(11); color: Qt.rgba(1, 1, 1, 0.45) }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Switch {
                                        checked: root.canvasGridSnap
                                        onToggled: root.canvasGridSnap = checked
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.06) }

                                // Default Startup Zoom
                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: "Default Startup Presentation"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.weight: Font.DemiBold; color: "#FFFFFF" }
                                        Text { text: "Present all 5 nodes in full overview or open zoomed directly into Node 0,0"; font.family: Theme.font; font.pixelSize: Theme.fontPx(11); color: Qt.rgba(1, 1, 1, 0.45) }
                                    }
                                    Item { Layout.fillWidth: true }
                                    RowLayout {
                                        spacing: Theme.px(8)
                                        Rectangle {
                                            width: Theme.px(110); height: Theme.px(28); radius: Theme.px(6)
                                            color: root.canvasDefaultView === "overview" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: root.canvasDefaultView === "overview" ? Theme.primary : Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                            Text { anchors.centerIn: parent; text: "5-NODE OVERVIEW"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: root.canvasDefaultView === "overview" ? Theme.primary : Qt.rgba(1, 1, 1, 0.70) }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.canvasDefaultView = "overview" }
                                        }
                                        Rectangle {
                                            width: Theme.px(110); height: Theme.px(28); radius: Theme.px(6)
                                            color: root.canvasDefaultView === "focused" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                                            border.color: root.canvasDefaultView === "focused" ? Theme.primary : Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                            Text { anchors.centerIn: parent; text: "CENTER FOCUSED"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: root.canvasDefaultView === "focused" ? Theme.primary : Qt.rgba(1, 1, 1, 0.70) }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.canvasDefaultView = "focused" }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.06) }

                                // Reset Nodes Action
                                RowLayout {
                                    Layout.fillWidth: true
                                    ColumnLayout {
                                        spacing: 2
                                        Text { text: "Reset Node Placement"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.weight: Font.DemiBold; color: "#FFFFFF" }
                                        Text { text: "Return all 5 dragged tiles to standard Cardinal Cross (+) layout coordinates"; font.family: Theme.font; font.pixelSize: Theme.fontPx(11); color: Qt.rgba(1, 1, 1, 0.45) }
                                    }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        width: Theme.px(150); height: Theme.px(28); radius: Theme.px(6)
                                        color: resetMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : Qt.rgba(1, 1, 1, 0.06)
                                        border.color: resetMouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.15); border.width: 1
                                        Text { anchors.centerIn: parent; text: "RESET TO DEFAULT (+)"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9.5); font.weight: Font.Bold; color: resetMouse.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.80) }
                                        MouseArea {
                                            id: resetMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.resetCanvasNodes()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── GLOBAL FAST TRIGGER SHORTCUTS ──
                    Text {
                        text: "KEYBOARD SHORTCUTS & LAUNCHERS"
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontPx(11)
                        font.weight: Font.Bold
                        color: Qt.rgba(1, 1, 1, 0.50)
                        Layout.topMargin: Theme.px(8)
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: keybindCol.implicitHeight + Theme.px(24)
                        radius: Theme.px(8)
                        color: Qt.rgba(0, 0, 0, 0.30)
                        border.color: Qt.rgba(1, 1, 1, 0.08)
                        border.width: 1

                        ColumnLayout {
                            id: keybindCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.px(14)
                            spacing: Theme.px(12)

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Side Panel (Focus HUD)"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12); color: "#FFFFFF"; Layout.preferredWidth: Theme.px(180) }
                                Rectangle {
                                    Layout.preferredHeight: Theme.px(24); Layout.preferredWidth: Theme.px(130); radius: Theme.px(4)
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15); border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40); border.width: 1
                                    Text { anchors.centerIn: parent; text: root.activeKeybindFocus; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Theme.primary }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: Theme.px(100); height: Theme.px(24); radius: Theme.px(4); color: t1.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.08); border.color: Theme.primary; border.width: 1
                                    Text { anchors.centerIn: parent; text: "TEST LAUNCH"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: t1.containsMouse ? "#000" : Theme.primary }
                                    MouseArea { id: t1; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerExternalLaunch("toggle-focus") }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.06) }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Main Center Panel"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12); color: "#FFFFFF"; Layout.preferredWidth: Theme.px(180) }
                                Rectangle {
                                    Layout.preferredHeight: Theme.px(24); Layout.preferredWidth: Theme.px(130); radius: Theme.px(4)
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15); border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40); border.width: 1
                                    Text { anchors.centerIn: parent; text: root.activeKeybindCenter; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Theme.primary }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: Theme.px(100); height: Theme.px(24); radius: Theme.px(4); color: t2.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.08); border.color: Theme.primary; border.width: 1
                                    Text { anchors.centerIn: parent; text: "TEST LAUNCH"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: t2.containsMouse ? "#000" : Theme.primary }
                                    MouseArea { id: t2; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerExternalLaunch("toggle-command-center") }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.06) }

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Spatial Canvas 2D"; font.family: Theme.font; font.pixelSize: Theme.fontPx(12); color: "#FFFFFF"; Layout.preferredWidth: Theme.px(180) }
                                Rectangle {
                                    Layout.preferredHeight: Theme.px(24); Layout.preferredWidth: Theme.px(130); radius: Theme.px(4)
                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15); border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40); border.width: 1
                                    Text { anchors.centerIn: parent; text: root.activeKeybindCanvas; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Theme.primary }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: Theme.px(100); height: Theme.px(24); radius: Theme.px(4); color: t3.containsMouse ? Theme.primary : Qt.rgba(1, 1, 1, 0.08); border.color: Theme.primary; border.width: 1
                                    Text { anchors.centerIn: parent; text: "TEST LAUNCH"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: t3.containsMouse ? "#000" : Theme.primary }
                                    MouseArea { id: t3; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.triggerExternalLaunch("toggle-spatial-canvas") }
                                }
                            }
                        }
                    }
                }
            }

            // ─────────────────────────────────────────────────────────────────
            // VIEW B: ARCHITECTURAL BLUEPRINT CANVAS PREVIEW
            // ─────────────────────────────────────────────────────────────────
            Item {
                anchors.fill: parent
                visible: root.activeSubSection === "Blueprint"

                // Blueprint Outer Card Container
                Rectangle {
                    id: blueprintCardContainer
                    anchors.fill: parent
                    anchors.margins: Theme.px(16)
                    radius: Theme.px(14)
                    color: "#071018"
                    border.color: Qt.rgba(0.20, 0.60, 0.85, 0.35)
                    border.width: 1
                    clip: true

                    // ── Architectural Blueprint Dual-Grid Canvas ──
                    Canvas {
                        id: blueprintGridCanvas
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)

                            // 1. Minor Grid Lines (every 16px)
                            ctx.strokeStyle = "rgba(28, 62, 88, 0.35)"
                            ctx.lineWidth = 0.8
                            var minorStep = 16
                            ctx.beginPath()
                            for (var x = 0; x < width; x += minorStep) {
                                ctx.moveTo(x, 0); ctx.lineTo(x, height)
                            }
                            for (var y = 0; y < height; y += minorStep) {
                                ctx.moveTo(0, y); ctx.lineTo(width, y)
                            }
                            ctx.stroke()

                            // 2. Major Grid Lines (every 64px)
                            ctx.strokeStyle = "rgba(42, 110, 150, 0.60)"
                            ctx.lineWidth = 1.2
                            var majorStep = 64
                            ctx.beginPath()
                            for (var mx = 0; mx < width; mx += majorStep) {
                                ctx.moveTo(mx, 0); ctx.lineTo(mx, height)
                            }
                            for (var my = 0; my < height; my += majorStep) {
                                ctx.moveTo(0, my); ctx.lineTo(width, my)
                            }
                            ctx.stroke()

                            // 3. Technical Crosshairs at intersections
                            ctx.fillStyle = "rgba(80, 190, 240, 0.70)"
                            for (var cx = 0; cx < width; cx += majorStep) {
                                for (var cy = 0; cy < height; cy += majorStep) {
                                    ctx.fillRect(cx - 3, cy, 7, 1)
                                    ctx.fillRect(cx, cy - 3, 1, 7)
                                }
                            }
                        }
                    }

                    // ── Technical Blueprint Header Banner ──
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Theme.px(30)
                        color: Qt.rgba(7/255, 16/255, 24/255, 0.85)
                        border.color: Qt.rgba(42/255, 110/255, 150/255, 0.40)
                        border.width: 1
                        z: 20

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.px(12)
                            anchors.rightMargin: Theme.px(12)
                            spacing: Theme.px(10)

                            Text {
                                text: "PROJECT: CARBON SHELL // SCHEMATIC VIEW"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(9.5)
                                font.weight: Font.Bold
                                color: Qt.rgba(80/255, 190/255, 240/255, 0.90)
                            }

                            Rectangle { Layout.preferredHeight: 12; Layout.preferredWidth: 1; color: Qt.rgba(1, 1, 1, 0.15) }

                            Text {
                                text: root.currentPanel === 0
                                      ? "MODULE: NOTCH SIDE PANEL (FOCUS HUD)"
                                      : (root.currentPanel === 1 ? "MODULE: MAIN CENTER PANEL (COMMAND CENTER)" : "MODULE: 2D SPATIAL CANVAS")
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(9)
                                color: Theme.primary
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: "SCALE: 1:1 // ORTHOGRAPHIC"
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontPx(8.5)
                                color: Qt.rgba(1, 1, 1, 0.35)
                            }
                        }
                    }

                    // ── Blueprint Viewport Container (Where the Panels sit) ──
                    Item {
                        id: blueprintViewport
                        anchors.fill: parent
                        anchors.topMargin: Theme.px(30)
                        clip: true

                        // ══════════════════════════════════════════════════════
                        // PREVIEW 1: SIDE PANEL (Focus HUD)
                        // ══════════════════════════════════════════════════════
                        Rectangle {
                            id: previewSidePanel
                            visible: root.currentPanel === 0
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.min(Theme.px(340), parent.width * 0.45)
                            color: Qt.rgba(10/255, 11/255, 14/255, 0.94)
                            border.color: Qt.rgba(255/255, 255/255, 255/255, 0.16)
                            border.width: 1
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(18)
                                spacing: Theme.px(14)

                                // Side Panel Header
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "HYPER-TUNNEL"
                                        color: "#FFFFFF"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(13)
                                        font.bold: true
                                        font.letterSpacing: 1.5
                                    }
                                    Item { Layout.fillWidth: true }
                                    Rectangle {
                                        Layout.preferredHeight: Theme.px(20); Layout.preferredWidth: Theme.px(70); radius: Theme.px(10)
                                        color: root.sideTimerRunning ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                                        border.color: root.sideTimerRunning ? Theme.primary : Qt.rgba(1, 1, 1, 0.15); border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: root.sideTimerRunning ? "FOCUSING" : "IDLE"
                                            font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(8.5); font.weight: Font.Bold
                                            color: root.sideTimerRunning ? Theme.primary : Qt.rgba(1, 1, 1, 0.60)
                                        }
                                    }
                                }

                                // Interactive Countdown Clock
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.px(100)
                                    radius: Theme.px(12)
                                    color: Qt.rgba(0, 0, 0, 0.35)
                                    border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: Theme.px(6)

                                        Text {
                                            readonly property int mins: Math.floor(root.sideRemainingSeconds / 60)
                                            readonly property int secs: root.sideRemainingSeconds % 60
                                            readonly property string mm: mins < 10 ? "0" + mins : mins
                                            readonly property string ss: secs < 10 ? "0" + secs : secs
                                            text: mm + ":" + ss
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontPx(32)
                                            font.weight: Font.Bold
                                            color: "#FFFFFF"
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        // Play / Pause Button
                                        Rectangle {
                                            Layout.preferredHeight: Theme.px(26); Layout.preferredWidth: Theme.px(90); radius: Theme.px(13)
                                            Layout.alignment: Qt.AlignHCenter
                                            color: root.sideTimerRunning ? Qt.rgba(255, 80, 80, 0.25) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                            border.color: root.sideTimerRunning ? "#FF5252" : Theme.primary; border.width: 1

                                            RowLayout {
                                                anchors.centerIn: parent; spacing: Theme.px(6)
                                                Text { text: root.sideTimerRunning ? "⏸" : "▶"; font.pixelSize: Theme.fontPx(10); color: root.sideTimerRunning ? "#FF5252" : Theme.primary }
                                                Text { text: root.sideTimerRunning ? "PAUSE" : "START"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: root.sideTimerRunning ? "#FF5252" : Theme.primary }
                                            }

                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.toggleSideTimer()
                                            }
                                        }
                                    }
                                }

                                // Preset Chips
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(6)
                                    Repeater {
                                        model: [25, 50, 90]
                                        delegate: Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: Theme.px(26); radius: Theme.px(6)
                                            color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.12); border.width: 1
                                            Text { anchors.centerIn: parent; text: modelData + "m"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9.5); font.weight: Font.Bold; color: Qt.rgba(1, 1, 1, 0.70) }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.resetSideTimer(modelData) }
                                        }
                                    }
                                }

                                // Ambient Audio Switcher
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: Theme.px(54)
                                    radius: Theme.px(8)
                                    color: Qt.rgba(0, 0, 0, 0.25)
                                    border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: Theme.px(10); spacing: Theme.px(8)
                                        Text { text: "🎧"; font.pixelSize: Theme.fontPx(16) }
                                        ColumnLayout {
                                            spacing: 1
                                            Text { text: "Ambient ASMR"; font.family: Theme.font; font.pixelSize: Theme.fontPx(11); font.bold: true; color: "#FFFFFF" }
                                            Text { text: root.sideActiveSound === "none" ? "Muted" : root.sideActiveSound.toUpperCase(); font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); color: Theme.primary }
                                        }
                                        Item { Layout.fillWidth: true }
                                        Rectangle {
                                            Layout.preferredHeight: Theme.px(22); Layout.preferredWidth: Theme.px(54); radius: Theme.px(4)
                                            color: root.sideActiveSound !== "none" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : Qt.rgba(1, 1, 1, 0.08)
                                            border.color: root.sideActiveSound !== "none" ? Theme.primary : Qt.rgba(1, 1, 1, 0.15); border.width: 1
                                            Text { anchors.centerIn: parent; text: root.sideActiveSound !== "none" ? "ACTIVE" : "OFF"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(8.5); font.weight: Font.Bold; color: root.sideActiveSound !== "none" ? Theme.primary : Qt.rgba(1, 1, 1, 0.50) }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: root.sideActiveSound = (root.sideActiveSound === "none" ? "rain" : "none")
                                            }
                                        }
                                    }
                                }

                                // Interactive Task Items
                                Text { text: "FOCUS OBJECTIVES"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9.5); font.weight: Font.Bold; color: Qt.rgba(1, 1, 1, 0.40) }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.px(6)
                                    Repeater {
                                        model: root.sideTasks
                                        delegate: RowLayout {
                                            Layout.fillWidth: true; spacing: Theme.px(8)
                                            Rectangle {
                                                width: Theme.px(14); height: Theme.px(14); radius: Theme.px(3)
                                                color: modelData.done ? Theme.primary : "transparent"
                                                border.color: modelData.done ? Theme.primary : Qt.rgba(1, 1, 1, 0.35); border.width: 1
                                                Text { anchors.centerIn: parent; visible: modelData.done; text: "✓"; font.pixelSize: Theme.fontPx(9); font.bold: true; color: "#000" }
                                                MouseArea {
                                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        var copy = root.sideTasks.slice()
                                                        copy[index].done = !copy[index].done
                                                        root.sideTasks = copy
                                                    }
                                                }
                                            }
                                            Text {
                                                text: modelData.title
                                                font.family: Theme.font; font.pixelSize: Theme.fontPx(11)
                                                color: modelData.done ? Qt.rgba(1, 1, 1, 0.40) : "#FFFFFF"
                                                font.strikeout: modelData.done
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        // ══════════════════════════════════════════════════════
                        // PREVIEW 2: MAIN CENTER PANEL (Command Center)
                        // ══════════════════════════════════════════════════════
                        Rectangle {
                            id: previewCenterCard
                            visible: root.currentPanel === 1
                            width: Math.min(Theme.px(640), parent.width - Theme.px(48))
                            height: Math.min(Theme.px(360), parent.height - Theme.px(32))
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.verticalCenterOffset: root.centerDockEdge === "bottom" ? Theme.px(24) : -Theme.px(24)

                            Behavior on anchors.verticalCenterOffset {
                                NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                            }

                            radius: Theme.px(16)
                            color: Qt.rgba(0.06, 0.07, 0.09, 0.92)
                            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.22)
                            border.width: 1
                            clip: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: Theme.px(14)
                                spacing: Theme.px(10)

                                // ── Center Card Header (Channel Switcher) ──
                                RowLayout {
                                    Layout.fillWidth: true; spacing: Theme.px(10)

                                    Text {
                                        text: "COMMAND CENTER"
                                        font.family: Theme.font; font.pixelSize: Theme.fontPx(12.5); font.weight: Font.Bold; color: Theme.primary
                                    }

                                    Item { Layout.fillWidth: true }

                                    // Channels: Overview / GitHub / Telemetry
                                    RowLayout {
                                        spacing: Theme.px(4)
                                        Repeater {
                                            model: [
                                                { id: "overview", label: "OVERVIEW", icon: "󰘚" },
                                                { id: "github", label: "GITHUB", icon: "󰊤" },
                                                { id: "telemetry", label: "TELEMETRY", icon: "󰓅" }
                                            ]
                                            delegate: Rectangle {
                                                width: Theme.px(92); height: Theme.px(26); radius: Theme.px(6)
                                                color: root.centerCurrentChannel === modelData.id ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : (chMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                                                border.color: root.centerCurrentChannel === modelData.id ? Theme.primary : "transparent"; border.width: 1

                                                RowLayout {
                                                    anchors.centerIn: parent; spacing: Theme.px(4)
                                                    Text { text: modelData.icon; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(11); color: root.centerCurrentChannel === modelData.id ? Theme.primary : Qt.rgba(1, 1, 1, 0.50) }
                                                    Text { text: modelData.label; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: root.centerCurrentChannel === modelData.id ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.60) }
                                                }

                                                MouseArea {
                                                    id: chMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: root.centerCurrentChannel = modelData.id
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                                // ── Channel 1: OVERVIEW ──
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    visible: root.centerCurrentChannel === "overview"
                                    spacing: Theme.px(10)

                                    // Row 1: Notes & Calendar/Weather
                                    RowLayout {
                                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.px(10)

                                        // Obsidian Notes Tile
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(10)
                                            color: Qt.rgba(0, 0, 0, 0.28); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                                            ColumnLayout {
                                                anchors.fill: parent; anchors.margins: Theme.px(10); spacing: Theme.px(6)
                                                RowLayout {
                                                    Text { text: "󰠮"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(12); color: "#B388FF" }
                                                    Text { text: "OBSIDIAN NOTES"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: Qt.rgba(1, 1, 1, 0.60) }
                                                }
                                                Text { text: root.centerSelectedNote; font.family: Theme.font; font.pixelSize: Theme.fontPx(11.5); font.bold: true; color: "#FFFFFF"; elide: Text.ElideRight; Layout.fillWidth: true }
                                                Text { text: "• Implemented 2D spatial canvas with logo-only tiles\n• Unified Plus Jakarta Sans font across hud\n• Restored Hyprland safe mode crash recovery"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); color: Qt.rgba(1, 1, 1, 0.50); Layout.fillWidth: true }
                                                Item { Layout.fillHeight: true }
                                            }
                                        }

                                        // Calendar & Weather Tile
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(10)
                                            color: Qt.rgba(0, 0, 0, 0.28); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                                            ColumnLayout {
                                                anchors.fill: parent; anchors.margins: Theme.px(10); spacing: Theme.px(6)
                                                RowLayout {
                                                    Text { text: "󰅐"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(12); color: Theme.primary }
                                                    Text { text: "SCHEDULE & WEATHER"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: Qt.rgba(1, 1, 1, 0.60) }
                                                }
                                                RowLayout {
                                                    spacing: Theme.px(12)
                                                    Text { text: "18:42"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(20); font.weight: Font.Bold; color: "#FFFFFF" }
                                                    ColumnLayout {
                                                        spacing: 1
                                                        Text { text: root.centerWeatherCity.toUpperCase(); font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(8.5); color: Theme.primary; font.weight: Font.Bold }
                                                        Text { text: root.centerWeatherTemp + " " + root.centerWeatherDesc; font.family: Theme.font; font.pixelSize: Theme.fontPx(10); color: Qt.rgba(1, 1, 1, 0.65) }
                                                    }
                                                }
                                                Text { text: "No overlapping CalDAV schedule alerts right now"; font.family: Theme.font; font.pixelSize: Theme.fontPx(9.5); color: Qt.rgba(1, 1, 1, 0.45) }
                                                Item { Layout.fillHeight: true }
                                            }
                                        }
                                    }

                                    // Row 2: Recent Apps Dock & Clipboard History
                                    RowLayout {
                                        Layout.fillWidth: true; Layout.preferredHeight: Theme.px(64); spacing: Theme.px(10)

                                        // Recent Apps Dock
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(10)
                                            color: Qt.rgba(0, 0, 0, 0.28); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                                            RowLayout {
                                                anchors.fill: parent; anchors.margins: Theme.px(8); spacing: Theme.px(10)
                                                Text { text: "󰀻 RECENT:"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: Qt.rgba(1, 1, 1, 0.50) }
                                                Repeater {
                                                    model: [
                                                        { name: "Terminal", icon: "󰆍" },
                                                        { name: "VS Code", icon: "󰨞" },
                                                        { name: "Browser", icon: "󰈹" },
                                                        { name: "Files", icon: "󰉋" },
                                                        { name: "Settings", icon: "󰒓" }
                                                    ]
                                                    delegate: Rectangle {
                                                        width: Theme.px(34); height: Theme.px(34); radius: Theme.px(6)
                                                        color: appMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20) : Qt.rgba(1, 1, 1, 0.06)
                                                        border.color: appMouse.containsMouse ? Theme.primary : "transparent"; border.width: 1
                                                        Text { anchors.centerIn: parent; text: modelData.icon; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(15); color: appMouse.containsMouse ? Theme.primary : "#FFFFFF" }
                                                        MouseArea { id: appMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                                                    }
                                                }
                                                Item { Layout.fillWidth: true }
                                            }
                                        }

                                        // Clipboard History
                                        Rectangle {
                                            Layout.preferredWidth: Theme.px(220); Layout.fillHeight: true; radius: Theme.px(10)
                                            color: Qt.rgba(0, 0, 0, 0.28); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                                            RowLayout {
                                                anchors.fill: parent; anchors.margins: Theme.px(10); spacing: Theme.px(8)
                                                Text { text: "󰅍"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(14); color: Theme.primary }
                                                ColumnLayout {
                                                    Layout.fillWidth: true; spacing: 1
                                                    Text { text: "CLIPBOARD"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(8.5); font.weight: Font.Bold; color: Qt.rgba(1, 1, 1, 0.50) }
                                                    Text { text: root.centerClipboardItems[0].text; font.family: Theme.font; font.pixelSize: Theme.fontPx(10); color: "#FFFFFF"; elide: Text.ElideRight; Layout.fillWidth: true }
                                                }
                                            }
                                        }
                                    }
                                }

                                // ── Channel 2: GITHUB UPLINK ──
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    visible: root.centerCurrentChannel === "github"
                                    spacing: Theme.px(8)

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Theme.px(8)
                                        Text { text: "󰊤 REPOSITORY SYNCHRONIZATION"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Theme.primary }
                                        Item { Layout.fillWidth: true }
                                        Text { text: "branch: main [UP TO DATE]"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); color: Qt.rgba(1, 1, 1, 0.40) }
                                    }

                                    Repeater {
                                        model: [
                                            { pr: "#42", title: "feat: Panels & Canvas Studio in Settings Hub", author: "xzshogun", status: "MERGED" },
                                            { pr: "#41", title: "fix: Hyprland safe mode package.path recovery", author: "xzshogun", status: "MERGED" },
                                            { pr: "#40", title: "feat: 2D Spatial Zoom Canvas with brand logos", author: "xzshogun", status: "OPEN" }
                                        ]
                                        delegate: Rectangle {
                                            Layout.fillWidth: true; Layout.preferredHeight: Theme.px(36); radius: Theme.px(6)
                                            color: Qt.rgba(1, 1, 1, 0.04); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                                            RowLayout {
                                                anchors.fill: parent; anchors.margins: Theme.px(10); spacing: Theme.px(10)
                                                Text { text: modelData.pr; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Theme.primary }
                                                Text { text: modelData.title; font.family: Theme.font; font.pixelSize: Theme.fontPx(11); color: "#FFFFFF"; Layout.fillWidth: true; elide: Text.ElideRight }
                                                Rectangle {
                                                    width: Theme.px(54); height: Theme.px(18); radius: Theme.px(4)
                                                    color: modelData.status === "MERGED" ? Qt.rgba(180, 100, 255, 0.20) : Qt.rgba(80, 200, 120, 0.20)
                                                    border.color: modelData.status === "MERGED" ? "#B388FF" : "#69F0AE"; border.width: 1
                                                    Text { anchors.centerIn: parent; text: modelData.status; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(8); font.weight: Font.Bold; color: modelData.status === "MERGED" ? "#B388FF" : "#69F0AE" }
                                                }
                                            }
                                        }
                                    }
                                    Item { Layout.fillHeight: true }
                                }

                                // ── Channel 3: TELEMETRY STREAM ──
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    visible: root.centerCurrentChannel === "telemetry"
                                    spacing: Theme.px(8)

                                    RowLayout {
                                        Layout.fillWidth: true; spacing: Theme.px(10)
                                        Text { text: "LIVE TELEMETRY WAVEFORM STREAM"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(10); font.weight: Font.Bold; color: Theme.primary }
                                        Item { Layout.fillWidth: true }
                                        Text { text: "SAMPLE: 1000ms // 28 NODES"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(8.5); color: Qt.rgba(1, 1, 1, 0.40) }
                                    }

                                    // Real-time Bar Graphs for CPU & RAM
                                    RowLayout {
                                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.px(12)

                                        // CPU Graph Card
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(8)
                                            color: Qt.rgba(0, 0, 0, 0.35); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                                            ColumnLayout {
                                                anchors.fill: parent; anchors.margins: Theme.px(10); spacing: Theme.px(6)
                                                RowLayout {
                                                    Text { text: "CPU WORKLOAD"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: Theme.primary }
                                                    Item { Layout.fillWidth: true }
                                                    Text { text: root.centerCpuHistory[root.centerCpuHistory.length - 1] + "%"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(11); font.weight: Font.Bold; color: "#FFFFFF" }
                                                }
                                                // Bars row
                                                RowLayout {
                                                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.px(3)
                                                    Repeater {
                                                        model: root.centerCpuHistory
                                                        delegate: Rectangle {
                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignBottom
                                                            height: Math.max(Theme.px(4), (modelData / 100.0) * Theme.px(65))
                                                            radius: Theme.px(2)
                                                            color: Theme.primary
                                                            opacity: 0.40 + (index / 28.0) * 0.60
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // RAM Graph Card
                                        Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true; radius: Theme.px(8)
                                            color: Qt.rgba(0, 0, 0, 0.35); border.color: Qt.rgba(1, 1, 1, 0.08); border.width: 1

                                            ColumnLayout {
                                                anchors.fill: parent; anchors.margins: Theme.px(10); spacing: Theme.px(6)
                                                RowLayout {
                                                    Text { text: "RAM ALLOCATION"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); font.weight: Font.Bold; color: "#64B5F6" }
                                                    Item { Layout.fillWidth: true }
                                                    Text { text: root.centerRamHistory[root.centerRamHistory.length - 1] + "%"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(11); font.weight: Font.Bold; color: "#FFFFFF" }
                                                }
                                                // Bars row
                                                RowLayout {
                                                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.px(3)
                                                    Repeater {
                                                        model: root.centerRamHistory
                                                        delegate: Rectangle {
                                                            Layout.fillWidth: true
                                                            Layout.alignment: Qt.AlignBottom
                                                            height: Math.max(Theme.px(4), (modelData / 100.0) * Theme.px(65))
                                                            radius: Theme.px(2)
                                                            color: "#64B5F6"
                                                            opacity: 0.40 + (index / 28.0) * 0.60
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ══════════════════════════════════════════════════════
                        // PREVIEW 3: SPATIAL CANVAS (Draggable, Logo-Only Tiles)
                        // ══════════════════════════════════════════════════════
                        Item {
                            id: previewSpatialWorkspace
                            visible: root.currentPanel === 2
                            anchors.fill: parent

                            // Pan & Zoom Container Item
                            Item {
                                id: canvasCamera
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                scale: root.canvasZoomScale
                                x: (parent.width / 2) + root.canvasPanX
                                y: (parent.height / 2) + root.canvasPanY

                                Behavior on scale { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                                Behavior on x { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }
                                Behavior on y { NumberAnimation { duration: 340; easing.type: Easing.OutCubic } }

                                // ── Laser Schematic Connector Lines linking nodes to center (0,0) ──
                                Shape {
                                    anchors.fill: parent
                                    z: 1
                                    ShapePath {
                                        strokeColor: (root.canvasNodes && root.canvasNodes.length > 1) ? root.canvasNodes[1].color : Theme.primary
                                        strokeWidth: 1.5
                                        fillColor: "transparent"
                                        dashPattern: [4, 4]
                                        startX: (canvasCamera.width / 2) + (root.canvasNodes && root.canvasNodes[0] ? root.canvasNodes[0].x : 0)
                                        startY: (canvasCamera.height / 2) + (root.canvasNodes && root.canvasNodes[0] ? root.canvasNodes[0].y : 0)
                                        PathLine {
                                            x: (canvasCamera.width / 2) + (root.canvasNodes && root.canvasNodes[1] ? root.canvasNodes[1].x : 0)
                                            y: (canvasCamera.height / 2) + (root.canvasNodes && root.canvasNodes[1] ? root.canvasNodes[1].y : 0)
                                        }
                                    }
                                    ShapePath {
                                        strokeColor: (root.canvasNodes && root.canvasNodes.length > 2) ? root.canvasNodes[2].color : Theme.primary
                                        strokeWidth: 1.5
                                        fillColor: "transparent"
                                        dashPattern: [4, 4]
                                        startX: (canvasCamera.width / 2) + (root.canvasNodes && root.canvasNodes[0] ? root.canvasNodes[0].x : 0)
                                        startY: (canvasCamera.height / 2) + (root.canvasNodes && root.canvasNodes[0] ? root.canvasNodes[0].y : 0)
                                        PathLine {
                                            x: (canvasCamera.width / 2) + (root.canvasNodes && root.canvasNodes[2] ? root.canvasNodes[2].x : 0)
                                            y: (canvasCamera.height / 2) + (root.canvasNodes && root.canvasNodes[2] ? root.canvasNodes[2].y : 0)
                                        }
                                    }
                                    ShapePath {
                                        strokeColor: (root.canvasNodes && root.canvasNodes.length > 3) ? root.canvasNodes[3].color : Theme.primary
                                        strokeWidth: 1.5
                                        fillColor: "transparent"
                                        dashPattern: [4, 4]
                                        startX: (canvasCamera.width / 2) + (root.canvasNodes && root.canvasNodes[0] ? root.canvasNodes[0].x : 0)
                                        startY: (canvasCamera.height / 2) + (root.canvasNodes && root.canvasNodes[0] ? root.canvasNodes[0].y : 0)
                                        PathLine {
                                            x: (canvasCamera.width / 2) + (root.canvasNodes && root.canvasNodes[3] ? root.canvasNodes[3].x : 0)
                                            y: (canvasCamera.height / 2) + (root.canvasNodes && root.canvasNodes[3] ? root.canvasNodes[3].y : 0)
                                        }
                                    }
                                    ShapePath {
                                        strokeColor: (root.canvasNodes && root.canvasNodes.length > 4) ? root.canvasNodes[4].color : Theme.primary
                                        strokeWidth: 1.5
                                        fillColor: "transparent"
                                        dashPattern: [4, 4]
                                        startX: (canvasCamera.width / 2) + (root.canvasNodes && root.canvasNodes[0] ? root.canvasNodes[0].x : 0)
                                        startY: (canvasCamera.height / 2) + (root.canvasNodes && root.canvasNodes[0] ? root.canvasNodes[0].y : 0)
                                        PathLine {
                                            x: (canvasCamera.width / 2) + (root.canvasNodes && root.canvasNodes[4] ? root.canvasNodes[4].x : 0)
                                            y: (canvasCamera.height / 2) + (root.canvasNodes && root.canvasNodes[4] ? root.canvasNodes[4].y : 0)
                                        }
                                    }
                                }

                                // ── The 5 Interactive Draggable Tiles (LOGO-ONLY per requirement) ──
                                Repeater {
                                    model: root.canvasNodes
                                    delegate: Item {
                                        id: tileDelegate
                                        width: Theme.px(190)
                                        height: Theme.px(125)
                                        x: (canvasCamera.width / 2) + modelData.x - (width / 2)
                                        y: (canvasCamera.height / 2) + modelData.y - (height / 2)
                                        z: (root.canvasIsZoomFocused && root.canvasFocusedNodeIndex === index) ? 10 : 2

                                        // Tile Visual Card
                                        Rectangle {
                                            id: tileCard
                                            anchors.fill: parent
                                            radius: Theme.px(12)
                                            color: Qt.rgba(10/255, 14/255, 20/255, 0.94)
                                            border.color: (root.canvasIsZoomFocused && root.canvasFocusedNodeIndex === index)
                                                          ? Theme.primary
                                                          : (tileMouse.containsMouse ? modelData.color : Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.35))
                                            border.width: (root.canvasIsZoomFocused && root.canvasFocusedNodeIndex === index) ? 2 : 1
                                            clip: true

                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            // Soft ambient neon glow
                                            Rectangle {
                                                anchors.fill: parent
                                                radius: Theme.px(12)
                                                color: modelData.color
                                                opacity: (root.canvasIsZoomFocused && root.canvasFocusedNodeIndex === index) ? 0.12 : (tileMouse.containsMouse ? 0.08 : 0.03)
                                            }

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: Theme.px(10)
                                                spacing: Theme.px(6)

                                                // Top Bar: Title & Coordinates Badge
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: Theme.px(6)

                                                    Text {
                                                        text: modelData.name
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontPx(8.5)
                                                        font.weight: Font.Bold
                                                        color: "#FFFFFF"
                                                        elide: Text.ElideRight
                                                        Layout.fillWidth: true
                                                    }

                                                    Rectangle {
                                                        Layout.preferredHeight: Theme.px(16); Layout.preferredWidth: coordText.implicitWidth + Theme.px(10); radius: Theme.px(4)
                                                        color: Qt.rgba(modelData.color.r, modelData.color.g, modelData.color.b, 0.20)
                                                        border.color: modelData.color; border.width: 1
                                                        Text {
                                                            id: coordText
                                                            anchors.centerIn: parent
                                                            text: modelData.badge
                                                            font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(7.5); font.weight: Font.Bold
                                                            color: modelData.color
                                                        }
                                                    }
                                                }

                                                // ── CENTER BODY: ONLY THE LOGO ──
                                                Item {
                                                    Layout.fillWidth: true
                                                    Layout.fillHeight: true

                                                    CarbonLogoIcon {
                                                        anchors.centerIn: parent
                                                        width: Theme.px(34)
                                                        height: Theme.px(34)
                                                        color: modelData.color
                                                        twinColor: Theme.primary
                                                        spinning: (root.canvasIsZoomFocused && root.canvasFocusedNodeIndex === index)
                                                    }
                                                }

                                                // Bottom Bar: Drag Indicator & Zoom Focus Action
                                                RowLayout {
                                                    Layout.fillWidth: true; spacing: Theme.px(6)

                                                    RowLayout {
                                                        spacing: Theme.px(3)
                                                        Text { text: "󰍡"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(9); color: Qt.rgba(1, 1, 1, 0.40) }
                                                        Text { text: "DRAGGABLE"; font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(7.5); color: Qt.rgba(1, 1, 1, 0.40) }
                                                    }

                                                    Item { Layout.fillWidth: true }

                                                    // Zoom Focus Action Pill
                                                    Rectangle {
                                                        Layout.preferredHeight: Theme.px(20); Layout.preferredWidth: zoomPillText.implicitWidth + Theme.px(12); radius: Theme.px(4)
                                                        color: zoomPillMouse.containsMouse ? modelData.color : Qt.rgba(1, 1, 1, 0.08)
                                                        border.color: modelData.color; border.width: 1

                                                        Text {
                                                            id: zoomPillText
                                                            anchors.centerIn: parent
                                                            text: (root.canvasIsZoomFocused && root.canvasFocusedNodeIndex === index) ? "FOCUSED" : "ZOOM FOCUS"
                                                            font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(7.5); font.weight: Font.Bold
                                                            color: zoomPillMouse.containsMouse ? "#000000" : modelData.color
                                                        }

                                                        MouseArea {
                                                            id: zoomPillMouse
                                                            anchors.fill: parent
                                                            hoverEnabled: true
                                                            cursorShape: Qt.PointingHandCursor
                                                            onClicked: {
                                                                if (root.canvasIsZoomFocused && root.canvasFocusedNodeIndex === index) {
                                                                    root.zoomToCanvasOverview()
                                                                } else {
                                                                    root.zoomToCanvasNode(index)
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Drag MouseArea: Drag tile across the blueprint
                                        MouseArea {
                                            id: tileMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            drag.target: tileDelegate
                                            drag.axis: Drag.XAndYAxis

                                            onPositionChanged: {
                                                if (drag.active) {
                                                    // Calculate coordinate relative to canvas center
                                                    var relX = (tileDelegate.x + (tileDelegate.width / 2)) - (canvasCamera.width / 2)
                                                    var relY = (tileDelegate.y + (tileDelegate.height / 2)) - (canvasCamera.height / 2)

                                                    if (root.canvasGridSnap) {
                                                        relX = Math.round(relX / 32) * 32
                                                        relY = Math.round(relY / 32) * 32
                                                    }

                                                    var list = root.canvasNodes.slice()
                                                    list[index].x = relX
                                                    list[index].y = relY
                                                    root.canvasNodes = list
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // ── Spatial Canvas Floating HUD Controls (Bottom-Right) ──
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: Theme.px(16)
                                height: Theme.px(34)
                                width: hudRow.implicitWidth + Theme.px(24)
                                radius: Theme.px(17)
                                color: Qt.rgba(7/255, 16/255, 24/255, 0.90)
                                border.color: Qt.rgba(42/255, 110/255, 150/255, 0.60)
                                border.width: 1
                                z: 30

                                RowLayout {
                                    id: hudRow
                                    anchors.centerIn: parent
                                    spacing: Theme.px(12)

                                    Text {
                                        text: root.canvasIsZoomFocused
                                              ? "FOCUSED: " + root.canvasNodes[root.canvasFocusedNodeIndex].name
                                              : "5-NODE OVERVIEW"
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(9.5)
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                    }

                                    Rectangle { Layout.preferredHeight: 14; Layout.preferredWidth: 1; color: Qt.rgba(1, 1, 1, 0.15) }

                                    // Zoom Out / Overview Action
                                    Rectangle {
                                        Layout.preferredHeight: Theme.px(22); Layout.preferredWidth: Theme.px(76); radius: Theme.px(11)
                                        color: overMouse.containsMouse ? Theme.primary : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                        border.color: Theme.primary; border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: root.canvasIsZoomFocused ? "OVERVIEW" : "ZOOM (0,0)"
                                            font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(8); font.weight: Font.Bold
                                            color: overMouse.containsMouse ? "#000" : Theme.primary
                                        }
                                        MouseArea {
                                            id: overMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (root.canvasIsZoomFocused) root.zoomToCanvasOverview()
                                                else root.zoomToCanvasNode(0)
                                            }
                                        }
                                    }

                                    // Reset Positions Action
                                    Rectangle {
                                        Layout.preferredHeight: Theme.px(22); Layout.preferredWidth: Theme.px(64); radius: Theme.px(11)
                                        color: resMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.20) : Qt.rgba(255, 255, 255, 0.08)
                                        border.color: Qt.rgba(255, 255, 255, 0.20); border.width: 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: "RESET"
                                            font.family: Theme.fontMono; font.pixelSize: Theme.fontPx(8); font.weight: Font.Bold
                                            color: "#FFFFFF"
                                        }
                                        MouseArea {
                                            id: resMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: root.resetCanvasNodes()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
