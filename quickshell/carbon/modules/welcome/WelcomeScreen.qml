import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../Singletons"

PanelWindow {
    id: rootWindow

    screen: Quickshell.screens[0]
    color: "transparent"
    WlrLayershell.namespace: "carbon-welcome"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("CARBON_CONFIG_DIR") || (rootWindow.home + "/.config/carbon")
    readonly property string doneFlagFile: rootWindow.configDir + "/.welcome_done"

    property int currentTab: 0 // 0: Modes, 1: Theme, 2: Shortcuts, 3: System
    property string selectedMode: "nucleus" // notch, pill, minimal, nucleus
    property bool isDarkMode: true
    property bool dontShowAgain: true

    // Background Dim Scrim
    Rectangle {
        anchors.fill: parent
        color: "#90050508"

        MouseArea {
            anchors.fill: parent
            // Prevent clicks from propagating to windows beneath
        }
    }

    // Centered Welcome Dialog Card
    Item {
        id: dialog
        width: Math.min(1040, rootWindow.width - 48)
        height: Math.min(680, rootWindow.height - 48)
        anchors.centerIn: parent

        // Entrance animation
        opacity: 0
        scale: 0.94

        Component.onCompleted: {
            dialogEntrance.start()
        }

        ParallelAnimation {
            id: dialogEntrance
            NumberAnimation { target: dialog; property: "opacity"; to: 1.0; duration: 380; easing.type: Easing.OutCubic }
            NumberAnimation { target: dialog; property: "scale"; to: 1.0; duration: 440; easing.type: Easing.OutBack }
        }

        // Outer Glow Frame (Reactbits Border Glow effect with rotating perimeter beam)
        Rectangle {
            id: dialogBorderContainer
            anchors.fill: parent
            anchors.margins: -2
            radius: 22
            color: "#181726"
            clip: true

            Item {
                id: dialogBeamSpinner
                width: Math.max(dialog.width, dialog.height) * 2.2
                height: width
                anchors.centerIn: parent

                NumberAnimation on rotation {
                    from: 0
                    to: 360
                    duration: 7200
                    loops: Animation.Infinite
                    running: true
                }

                Rectangle {
                    width: parent.width
                    height: parent.height * 0.35
                    anchors.centerIn: parent
                    opacity: 0.85
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.35; color: "#06b6d4" } // cyan
                        GradientStop { position: 0.65; color: "#a855f7" } // purple
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }
            }
        }

        // Card Container with clipping
        Rectangle {
            id: cardBody
            anchors.fill: parent
            radius: 20
            clip: true
            color: "#0d0c14"

            // Reactbits Aurora Background Mesh
            AuroraBackground {
                anchors.fill: parent
            }

            // Inner subtle border
            Rectangle {
                anchors.fill: parent
                radius: 20
                color: "transparent"
                border.width: 1
                border.color: "#25ffffff"
            }

            // Main Layout
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 20

                // ── HEADER ──────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Carbon Atomic Emblem with dynamic orbit animation
                    Rectangle {
                        width: 48
                        height: 48
                        radius: 24
                        color: "#181726"
                        border.width: 1.5
                        border.color: "#38bdf8"

                        // Pulsing nucleus core
                        Rectangle {
                            anchors.centerIn: parent
                            width: 18
                            height: 18
                            radius: 9
                            color: "#38bdf8"

                            SequentialAnimation on scale {
                                loops: Animation.Infinite
                                NumberAnimation { to: 1.2; duration: 1600; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.88; duration: 1600; easing.type: Easing.InOutSine }
                            }
                        }

                        // Orbiting satellite ring
                        Item {
                            anchors.fill: parent

                            NumberAnimation on rotation {
                                from: 0
                                to: 360
                                duration: 5200
                                loops: Animation.Infinite
                                running: true
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 34
                                height: 34
                                radius: 17
                                color: "transparent"
                                border.width: 1
                                border.color: "#a855f7"
                            }

                            // Orbiting electron dot
                            Rectangle {
                                x: parent.width / 2 - 3
                                y: parent.height / 2 - 17 - 3
                                width: 6
                                height: 6
                                radius: 3
                                color: "#f43f5e"
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        RowLayout {
                            spacing: 10
                            Text {
                                text: "Welcome to Carbon Shell"
                                font.pixelSize: 22
                                font.weight: Font.Bold
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#ffffff"
                            }

                            // Version Badge
                            Rectangle {
                                width: 90
                                height: 22
                                radius: 11
                                color: "#2538bdf8"
                                border.width: 1
                                border.color: "#6038bdf8"

                                Text {
                                    anchors.centerIn: parent
                                    text: "v2.5 Next-Gen"
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: "#38bdf8"
                                }
                            }
                        }

                        Text {
                            text: "Adaptive, Atomic & Ultra-Fast Wayland Desktop Environment"
                            font.pixelSize: 13
                            font.family: "JetBrainsMono Nerd Font"
                            color: "#94a3b8"
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Close / Dismiss X Button with hover rotation & scale
                    Rectangle {
                        width: 34
                        height: 34
                        radius: 17
                        color: closeHover.containsMouse ? "#28ffffff" : "#14ffffff"
                        border.width: 1
                        border.color: closeHover.containsMouse ? "#38bdf8" : "#20ffffff"
                        scale: closeHover.containsMouse ? 1.08 : 1.0
                        rotation: closeHover.containsMouse ? 90 : 0

                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                        Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 180 } }
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 14
                            color: closeHover.containsMouse ? "#ffffff" : "#cbd5e1"
                        }

                        MouseArea {
                            id: closeHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootWindow.finishWelcome()
                        }
                    }
                }

                // ── TAB SELECTOR ────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: [
                            { id: 0, title: "Desktop Modes", icon: "󱂬" },
                            { id: 1, title: "Appearance & Theme", icon: "󰔎" },
                            { id: 2, title: "Keyboard Shortcuts", icon: "󰌌" },
                            { id: 3, title: "System & Features", icon: "󰒓" }
                        ]

                        GlowCard {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44
                            cornerRadius: 12
                            selected: rootWindow.currentTab === modelData.id
                            glowColor: "#38bdf8"
                            cardColor: rootWindow.currentTab === modelData.id ? "#2038bdf8" : "#12111d"
                            cardOpacity: 0.9

                            onClicked: rootWindow.currentTab = modelData.id

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8

                                Text {
                                    text: modelData.icon
                                    font.pixelSize: 16
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: rootWindow.currentTab === modelData.id ? "#38bdf8" : "#94a3b8"
                                }

                                Text {
                                    text: modelData.title
                                    font.pixelSize: 13
                                    font.weight: rootWindow.currentTab === modelData.id ? Font.Bold : Font.Normal
                                    font.family: "JetBrainsMono Nerd Font"
                                    color: rootWindow.currentTab === modelData.id ? "#ffffff" : "#94a3b8"
                                }
                            }
                        }
                    }
                }

                // ── TAB PAGES CONTENT ───────────────────────────────────
                StackLayout {
                    id: stack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: rootWindow.currentTab

                    // ── PAGE 0: DESKTOP MODES ──
                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14

                            Text {
                                text: "Select your primary desktop bar layout. You can switch anytime using the Config Editor."
                                font.pixelSize: 13
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#cbd5e1"
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 2
                                rows: 2
                                rowSpacing: 14
                                columnSpacing: 14

                                // Mode 1: Vanish Mode (Nucleus)
                                GlowCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    selected: rootWindow.selectedMode === "nucleus"
                                    glowColor: "#f43f5e"
                                    onClicked: rootWindow.selectedMode = "nucleus"

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 8

                                        RowLayout {
                                            spacing: 10
                                            Text { text: "󱐋"; font.pixelSize: 22; font.family: "JetBrainsMono Nerd Font"; color: "#f43f5e" }
                                            Text { text: "Vanish Mode (Nucleus)"; font.pixelSize: 16; font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff" }
                                            Item { Layout.fillWidth: true }
                                            Rectangle {
                                                width: 60; height: 20; radius: 10
                                                color: rootWindow.selectedMode === "nucleus" ? "#f43f5e" : "#20ffffff"
                                                Text { anchors.centerIn: parent; text: rootWindow.selectedMode === "nucleus" ? "ACTIVE" : "SELECT"; font.pixelSize: 10; font.weight: Font.Bold; color: "#ffffff" }
                                            }
                                        }

                                        Text {
                                            text: "Barless atomic desktop with animated central clock orb, radial satellites, and gesture navigation. Zero clutter."
                                            font.pixelSize: 12
                                            font.family: "JetBrainsMono Nerd Font"
                                            color: "#94a3b8"
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                // Mode 2: Notch Mode
                                GlowCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    selected: rootWindow.selectedMode === "notch"
                                    glowColor: "#38bdf8"
                                    onClicked: rootWindow.selectedMode = "notch"

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 8

                                        RowLayout {
                                            spacing: 10
                                            Text { text: "󰍹"; font.pixelSize: 22; font.family: "JetBrainsMono Nerd Font"; color: "#38bdf8" }
                                            Text { text: "Notch Mode"; font.pixelSize: 16; font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff" }
                                            Item { Layout.fillWidth: true }
                                            Rectangle {
                                                width: 60; height: 20; radius: 10
                                                color: rootWindow.selectedMode === "notch" ? "#38bdf8" : "#20ffffff"
                                                Text { anchors.centerIn: parent; text: rootWindow.selectedMode === "notch" ? "ACTIVE" : "SELECT"; font.pixelSize: 10; font.weight: Font.Bold; color: "#ffffff" }
                                            }
                                        }

                                        Text {
                                            text: "Dynamic camera-notch bar pinned to the top screen edge with animated music wave, status indicators, and popouts."
                                            font.pixelSize: 12
                                            font.family: "JetBrainsMono Nerd Font"
                                            color: "#94a3b8"
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                // Mode 3: Pill Mode
                                GlowCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    selected: rootWindow.selectedMode === "pill"
                                    glowColor: "#a855f7"
                                    onClicked: rootWindow.selectedMode = "pill"

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 8

                                        RowLayout {
                                            spacing: 10
                                            Text { text: "󰹍"; font.pixelSize: 22; font.family: "JetBrainsMono Nerd Font"; color: "#a855f7" }
                                            Text { text: "Pill Capsule"; font.pixelSize: 16; font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff" }
                                            Item { Layout.fillWidth: true }
                                            Rectangle {
                                                width: 60; height: 20; radius: 10
                                                color: rootWindow.selectedMode === "pill" ? "#a855f7" : "#20ffffff"
                                                Text { anchors.centerIn: parent; text: rootWindow.selectedMode === "pill" ? "ACTIVE" : "SELECT"; font.pixelSize: 10; font.weight: Font.Bold; color: "#ffffff" }
                                            }
                                        }

                                        Text {
                                            text: "Floating rounded capsule island with smooth expanding lobes, quick controls, and integrated workspace switcher."
                                            font.pixelSize: 12
                                            font.family: "JetBrainsMono Nerd Font"
                                            color: "#94a3b8"
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                // Mode 4: Minimal Island
                                GlowCard {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    selected: rootWindow.selectedMode === "minimal"
                                    glowColor: "#2dd4bf"
                                    onClicked: rootWindow.selectedMode = "minimal"

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 8

                                        RowLayout {
                                            spacing: 10
                                            Text { text: "󰇄"; font.pixelSize: 22; font.family: "JetBrainsMono Nerd Font"; color: "#2dd4bf" }
                                            Text { text: "Minimal Island"; font.pixelSize: 16; font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff" }
                                            Item { Layout.fillWidth: true }
                                            Rectangle {
                                                width: 60; height: 20; radius: 10
                                                color: rootWindow.selectedMode === "minimal" ? "#2dd4bf" : "#20ffffff"
                                                Text { anchors.centerIn: parent; text: rootWindow.selectedMode === "minimal" ? "ACTIVE" : "SELECT"; font.pixelSize: 10; font.weight: Font.Bold; color: "#ffffff" }
                                            }
                                        }

                                        Text {
                                            text: "Micro-sized distraction-free island displaying only essential status icons. Expands on hover for low profile setups."
                                            font.pixelSize: 12
                                            font.family: "JetBrainsMono Nerd Font"
                                            color: "#94a3b8"
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── PAGE 1: THEME & WALLPAPER ──
                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 14

                            Text {
                                text: "Theme and color palettes adapt dynamically to your active wallpaper using Material Design 3."
                                font.pixelSize: 13
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#cbd5e1"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                GlowCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 120
                                    selected: rootWindow.isDarkMode
                                    glowColor: "#38bdf8"
                                    onClicked: rootWindow.isDarkMode = true

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text { text: "󰔎"; font.pixelSize: 28; font.family: "JetBrainsMono Nerd Font"; color: "#38bdf8"; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: "Obsidian Dark Mode"; font.pixelSize: 14; font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff"; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: "High-contrast dark glass"; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; color: "#94a3b8"; Layout.alignment: Qt.AlignHCenter }
                                    }
                                }

                                GlowCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 120
                                    selected: !rootWindow.isDarkMode
                                    glowColor: "#f59e0b"
                                    onClicked: rootWindow.isDarkMode = false

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 8
                                        Text { text: "󰖨"; font.pixelSize: 28; font.family: "JetBrainsMono Nerd Font"; color: "#f59e0b"; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: "Luminous Light Mode"; font.pixelSize: 14; font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff"; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: "Clean frosted daylight"; font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"; color: "#94a3b8"; Layout.alignment: Qt.AlignHCenter }
                                    }
                                }
                            }

                            Text {
                                text: "Bundled Wallpaper Presets"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#ffffff"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 12

                                Repeater {
                                    model: [
                                        { title: "Aurora Cosmic", color: "#38bdf8", sub: "Deep gradient" },
                                        { title: "Dark Minimal", color: "#a855f7", sub: "Clean obsidian" },
                                        { title: "Cyber Neon", color: "#f43f5e", sub: "High contrast" },
                                        { title: "Anime Scenery", color: "#2dd4bf", sub: "Scenic landscapes" }
                                    ]

                                    GlowCard {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        glowColor: modelData.color

                                        ColumnLayout {
                                            anchors.fill: parent
                                            spacing: 6

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.fillHeight: true
                                                radius: 8
                                                color: Qt.rgba(1, 1, 1, 0.05)
                                                border.width: 1
                                                border.color: "#20ffffff"

                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: 32; height: 32; radius: 16
                                                    color: modelData.color
                                                    opacity: 0.8
                                                }
                                            }

                                            Text {
                                                text: modelData.title
                                                font.pixelSize: 12
                                                font.weight: Font.Bold
                                                font.family: "JetBrainsMono Nerd Font"
                                                color: "#ffffff"
                                            }
                                            Text {
                                                text: modelData.sub
                                                font.pixelSize: 10
                                                font.family: "JetBrainsMono Nerd Font"
                                                color: "#94a3b8"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── PAGE 2: KEYBOARD SHORTCUTS ──
                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 12

                            Text {
                                text: "Essential keybindings to navigate Carbon Shell seamlessly."
                                font.pixelSize: 13
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#cbd5e1"
                            }

                            GridLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                columns: 2
                                rowSpacing: 10
                                columnSpacing: 14

                                Repeater {
                                    model: [
                                        { key: "Super (Tap)", desc: "Toggle Vanish Central Hub & Satellites", icon: "󱐋" },
                                        { key: "Super + Space", desc: "Toggle App Launcher & Search", icon: "󰀻" },
                                        { key: "Super + Return", desc: "Open Kitty Terminal Emulator", icon: "󰞷" },
                                        { key: "Super + K", desc: "Spotlight Command Palette & Actions", icon: "󰌌" },
                                        { key: "Super + W", desc: "Dynamic Wallpaper Picker Ring", icon: "󰸉" },
                                        { key: "Super + M", desc: "Toggle Real-time Synced Lyrics", icon: "󰎆" },
                                        { key: "Super + C", desc: "Bloom Connectivity Lobe (Audio/WiFi/BT)", icon: "󰤨" },
                                        { key: "Print", desc: "Carbon Interactive Region Screenshot", icon: "󰹑" }
                                    ]

                                    GlowCard {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 52
                                        cornerRadius: 10
                                        glowColor: "#6366f1"

                                        RowLayout {
                                            anchors.fill: parent
                                            spacing: 12

                                            Rectangle {
                                                width: 120
                                                height: 28
                                                radius: 6
                                                color: "#2038bdf8"
                                                border.width: 1
                                                border.color: "#6038bdf8"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.key
                                                    font.pixelSize: 11
                                                    font.weight: Font.Bold
                                                    font.family: "JetBrainsMono Nerd Font"
                                                    color: "#38bdf8"
                                                }
                                            }

                                            Text {
                                                text: modelData.desc
                                                font.pixelSize: 12
                                                font.family: "JetBrainsMono Nerd Font"
                                                color: "#e2e8f0"
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── PAGE 3: SYSTEM QUICK SETUP ──
                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 16

                            Text {
                                text: "Configure initial audio and brightness levels, and toggle essential desktop services."
                                font.pixelSize: 13
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#cbd5e1"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                // Volume Card
                                GlowCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 90
                                    glowColor: "#38bdf8"

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 8
                                        RowLayout {
                                            Text { text: "󰕾"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#38bdf8" }
                                            Text { text: "Master Audio Volume"; font.pixelSize: 13; font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff" }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "75%"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; color: "#38bdf8" }
                                        }
                                        ProgressBar {
                                            Layout.fillWidth: true
                                            value: 0.75
                                        }
                                    }
                                }

                                // Brightness Card
                                GlowCard {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 90
                                    glowColor: "#f59e0b"

                                    ColumnLayout {
                                        anchors.fill: parent
                                        spacing: 8
                                        RowLayout {
                                            Text { text: "󰃠"; font.pixelSize: 16; font.family: "JetBrainsMono Nerd Font"; color: "#f59e0b" }
                                            Text { text: "Display Brightness"; font.pixelSize: 13; font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff" }
                                            Item { Layout.fillWidth: true }
                                            Text { text: "85%"; font.pixelSize: 12; font.family: "JetBrainsMono Nerd Font"; color: "#f59e0b" }
                                        }
                                        ProgressBar {
                                            Layout.fillWidth: true
                                            value: 0.85
                                        }
                                    }
                                }
                            }

                            Text {
                                text: "Desktop Integration Services"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#ffffff"
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Repeater {
                                    model: [
                                        { name: "Night Light", icon: "󰖔", active: true, color: "#f59e0b" },
                                        { name: "WiFi Network", icon: "󰤨", active: true, color: "#38bdf8" },
                                        { name: "Bluetooth", icon: "󰂯", active: true, color: "#a855f7" },
                                        { name: "Clipboard History", icon: "󰅌", active: true, color: "#2dd4bf" }
                                    ]

                                    GlowCard {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 70
                                        selected: modelData.active
                                        glowColor: modelData.color

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 10
                                            Text { text: modelData.icon; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font"; color: modelData.color }
                                            ColumnLayout {
                                                spacing: 2
                                                Text { text: modelData.name; font.pixelSize: 12; font.weight: Font.Bold; font.family: "JetBrainsMono Nerd Font"; color: "#ffffff" }
                                                Text { text: modelData.active ? "Enabled" : "Disabled"; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; color: "#94a3b8" }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── FOOTER BAR ──────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    // Checkbox: Don't show again
                    RowLayout {
                        spacing: 8
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 4
                            color: rootWindow.dontShowAgain ? "#38bdf8" : "#20ffffff"
                            border.width: 1
                            border.color: rootWindow.dontShowAgain ? "#38bdf8" : "#40ffffff"

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                font.pixelSize: 12
                                font.weight: Font.Bold
                                color: "#000000"
                                visible: rootWindow.dontShowAgain
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootWindow.dontShowAgain = !rootWindow.dontShowAgain
                            }
                        }

                        Text {
                            text: "Don't show this screen again on startup"
                            font.pixelSize: 12
                            font.family: "JetBrainsMono Nerd Font"
                            color: "#94a3b8"

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rootWindow.dontShowAgain = !rootWindow.dontShowAgain
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Skip Button
                    Rectangle {
                        width: 90
                        height: 40
                        radius: 12
                        color: skipHover.containsMouse ? "#20ffffff" : "transparent"
                        border.width: 1
                        border.color: skipHover.containsMouse ? "#60ffffff" : "#30ffffff"
                        scale: skipHover.containsMouse ? 1.03 : 1.0

                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Skip"
                            font.pixelSize: 13
                            font.family: "JetBrainsMono Nerd Font"
                            color: skipHover.containsMouse ? "#ffffff" : "#cbd5e1"
                        }

                        MouseArea {
                            id: skipHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootWindow.finishWelcome()
                        }
                    }

                    // Primary Get Started Button (Glowing with pulse & hover scale)
                    Rectangle {
                        id: startBtn
                        width: 160
                        height: 40
                        radius: 12
                        color: startHover.containsMouse ? "#0284c7" : "#0ea5e9"
                        border.width: 1.5
                        border.color: startHover.containsMouse ? "#7dd3fc" : "#38bdf8"
                        scale: startHover.containsMouse ? 1.04 : 1.0

                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Behavior on border.color { ColorAnimation { duration: 160 } }

                        // Soft outer pulse
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -2
                            radius: 14
                            color: "transparent"
                            border.width: 1.5
                            border.color: "#38bdf8"
                            opacity: startHover.containsMouse ? 0.8 : 0.35

                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.75; duration: 1200; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 0.25; duration: 1200; easing.type: Easing.InOutSine }
                            }
                        }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "Get Started"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                font.family: "JetBrainsMono Nerd Font"
                                color: "#ffffff"
                            }
                            Text {
                                text: "→"
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                color: "#ffffff"
                                transform: Translate {
                                    x: startHover.containsMouse ? 4 : 0
                                    Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                                }
                            }
                        }

                        MouseArea {
                            id: startHover
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootWindow.finishWelcome()
                        }
                    }
                }
            }
        }
    }

    function finishWelcome() {
        if (rootWindow.dontShowAgain) {
            Quickshell.execDetached(["sh", "-c", "mkdir -p " + rootWindow.configDir + " && touch " + rootWindow.doneFlagFile])
        }
        // If mode was changed from default, apply it
        if (rootWindow.selectedMode) {
            Quickshell.execDetached(["sh", rootWindow.home + "/.config/hypr/scripts/carbon-ipc.sh", "bar-mode " + rootWindow.selectedMode])
        }
        // Quit process completely to release 100% RAM & CPU
        Qt.quit()
    }
}
