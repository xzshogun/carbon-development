import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../Singletons"
import "../components"

Item {
    id: root

    property bool open: false
    signal closeRequested()

    property string currentSection: "Modes"

    // Backdrop dismissal
    MouseArea {
        anchors.fill: parent
        onClicked: root.closeRequested()
    }

    // Main Hub Window (Full-screen flush edge-to-edge layout separated by strict 1px hairlines)
    Rectangle {
        id: hubWindow
        anchors.fill: parent
        color: Theme.surface
        border.width: 0
        radius: 0
        clip: true
        focus: true

        Keys.onEscapePressed: root.closeRequested()

        // Stop propagation so clicking inside window doesn't close
        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Header Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Theme.px(52)
                color: Qt.rgba(0, 0, 0, 0.20)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.px(20)
                    anchors.rightMargin: Theme.px(16)
                    spacing: Theme.px(12)

                    Text {
                        text: "CARBON // SETTINGS HUB"
                        font.family: Theme.font
                        font.pixelSize: Theme.fontPx(13)
                        font.weight: Font.Bold
                        color: Theme.primary
                    }

                    Item { Layout.fillWidth: true }

                    // Close Button
                    Rectangle {
                        Layout.preferredWidth: Theme.px(28)
                        Layout.preferredHeight: Theme.px(28)
                        radius: Theme.px(6)
                        color: closeMouse.pressed ? Qt.rgba(1, 1, 1, 0.15) : (closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        border.color: closeMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : "transparent"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(13)
                            color: Qt.rgba(1, 1, 1, 0.70)
                        }

                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.closeRequested()
                        }
                    }
                }
            }

            // Body: Sidebar + Vertical Hairline + Main Tab Content
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // ==========================================
                // SIDEBAR with subtle tactile hardware pattern
                // ==========================================
                Item {
                    Layout.preferredWidth: Theme.px(210)
                    Layout.fillHeight: true

                    // Plain solid background
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                    }

                    // Sidebar Navigation Items
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: Theme.px(16)
                        anchors.leftMargin: Theme.px(12)
                        anchors.rightMargin: Theme.px(12)
                        spacing: Theme.px(4)

                        Repeater {
                            model: [
                                { name: "Appearance", glyph: "󰏘", badge: "M3" },
                                { name: "Modes", glyph: "󱐋", badge: "STUDIO" },
                                { name: "Keybinds", glyph: "󰌌", badge: "MODES" },
                                { name: "Panels & Canvas", glyph: "󰹑", badge: "PRO" },
                                { name: "Display", glyph: "󰍹", badge: "" },
                                { name: "Audio", glyph: "󰓃", badge: "" },
                                { name: "Network", glyph: "󰤨", badge: "" },
                                { name: "System", glyph: "󰘚", badge: "" }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(38)
                                radius: Theme.px(6)
                                color: (root.currentSection.toLowerCase() === modelData.name.toLowerCase()) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : (navMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                                border.color: (root.currentSection.toLowerCase() === modelData.name.toLowerCase()) ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40) : "transparent"
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.px(12)
                                    anchors.rightMargin: Theme.px(12)
                                    spacing: Theme.px(10)

                                    Text {
                                        text: modelData.glyph
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(15)
                                        color: (root.currentSection.toLowerCase() === modelData.name.toLowerCase()) ? Theme.primary : Qt.rgba(1, 1, 1, 0.60)
                                    }

                                    Text {
                                        text: modelData.name
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(13)
                                        font.weight: (root.currentSection.toLowerCase() === modelData.name.toLowerCase()) ? Font.DemiBold : Font.Normal
                                        color: (root.currentSection.toLowerCase() === modelData.name.toLowerCase()) ? Qt.rgba(1, 1, 1, 0.95) : Qt.rgba(1, 1, 1, 0.65)
                                        Layout.fillWidth: true
                                    }

                                    Text {
                                        visible: modelData.badge.length > 0
                                        text: modelData.badge
                                        font.family: Theme.fontMono
                                        font.pixelSize: Theme.fontPx(9)
                                        font.weight: Font.Bold
                                        color: Theme.primary
                                    }
                                }

                                MouseArea {
                                    id: navMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.currentSection = modelData.name
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        // Version info at bottom of sidebar
                        Text {
                            text: "CARBON // v2.6.4"
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontPx(10)
                            color: Qt.rgba(1, 1, 1, 0.25)
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 12
                        }
                    }
                }

                // 1px Vertical Hairline Separating Sidebar & Content
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    color: Qt.rgba(1, 1, 1, 0.08)
                }

                // Main Content View
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    AppearanceTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "appearance"
                    }

                    ModesTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "modes"
                    }

                    KeybindsTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "keybinds"
                    }

                    PanelsCanvasTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "panels & canvas" || root.currentSection.toLowerCase() === "panels"
                    }

                    DisplaysTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "display" || root.currentSection.toLowerCase() === "displays"
                    }

                    AudioTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "audio"
                    }

                    NetworkTab {
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "network"
                    }

                    // System & Lifecycle Management Tab
                    Item {
                        id: sysTabRoot
                        anchors.fill: parent
                        visible: root.currentSection.toLowerCase() === "system"

                        readonly property string cfgDir: Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")
                        property string keybindProfile: "keep"
                        property string activeShellMode: "minimal_notch"
                        property string statusBanner: "Ready — Repo: xzshogun/carbon-development"

                        FileView {
                            id: kbProfileView
                            path: sysTabRoot.cfgDir + "/keybind_profile"
                            watchChanges: true
                            blockLoading: true
                            printErrors: false
                            onLoaded: {
                                var t = kbProfileView.text().trim()
                                if (t === "carbon" || t === "keep") sysTabRoot.keybindProfile = t
                            }
                            onFileChanged: {
                                reload()
                                var t = kbProfileView.text().trim()
                                if (t === "carbon" || t === "keep") sysTabRoot.keybindProfile = t
                            }
                        }

                        FileView {
                            id: modeFileView
                            path: sysTabRoot.cfgDir + "/carbon-bar-mode.json"
                            watchChanges: true
                            blockLoading: true
                            printErrors: false
                            onLoaded: {
                                try {
                                    var d = JSON.parse(modeFileView.text())
                                    if (d && d.mode) sysTabRoot.activeShellMode = d.mode
                                } catch (e) {}
                            }
                            onFileChanged: {
                                reload()
                                try {
                                    var d = JSON.parse(modeFileView.text())
                                    if (d && d.mode) sysTabRoot.activeShellMode = d.mode
                                } catch (e) {}
                            }
                        }

                        function setKeybindProfile(profile) {
                            sysTabRoot.keybindProfile = profile
                            sysTabRoot.statusBanner = "Keybind profile set to '" + profile + "' & mode keybinds synced"
                            Quickshell.execDetached([
                                "bash", "-c",
                                "CFG=\"${CARBON_CONFIG_DIR:-$HOME/.config/carbon}\"; mkdir -p \"$CFG\"; echo \"" + profile + "\" > \"$CFG/keybind_profile\"; " +
                                "[ -x \"$CFG/scripts/carbon-mode-keybinds.sh\" ] && \"$CFG/scripts/carbon-mode-keybinds.sh\""
                            ])
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.px(28)
                            spacing: Theme.px(18)

                            ColumnLayout {
                                spacing: 4
                                Text {
                                    text: "SYSTEM & LIFECYCLE CONTROL"
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontPx(18)
                                    font.weight: Font.Bold
                                    color: "#FFFFFF"
                                }
                                Text {
                                    text: sysTabRoot.statusBanner
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontPx(11)
                                    color: Theme.primary
                                }
                            }

                            // Card 1: Keybind Isolation & Profile Mode
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(140)
                                radius: Theme.px(14)
                                color: Qt.rgba(1, 1, 1, 0.03)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.px(18)
                                    spacing: Theme.px(10)

                                    RowLayout {
                                        Layout.fillWidth: true
                                        ColumnLayout {
                                            spacing: 2
                                            Text {
                                                text: "Hyprland Keybind Profile"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(13.5)
                                                font.weight: Font.Bold
                                                color: "#FFFFFF"
                                            }
                                            Text {
                                                text: "Keep your existing Hyprland binds (+ mode-specific Carbon binds) or use the full Carbon keybind suite."
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(11)
                                                color: Qt.rgba(1, 1, 1, 0.55)
                                            }
                                        }
                                        Item { Layout.fillWidth: true }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.px(12)

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: Theme.px(42)
                                            radius: Theme.px(10)
                                            color: sysTabRoot.keybindProfile === "keep" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                                            border.color: sysTabRoot.keybindProfile === "keep" ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Keep My Existing Binds (+ Mode Binds)"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(12)
                                                font.weight: Font.DemiBold
                                                color: sysTabRoot.keybindProfile === "keep" ? Theme.primary : "#FFFFFF"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: sysTabRoot.setKeybindProfile("keep")
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: Theme.px(42)
                                            radius: Theme.px(10)
                                            color: sysTabRoot.keybindProfile === "carbon" ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22) : Qt.rgba(1, 1, 1, 0.04)
                                            border.color: sysTabRoot.keybindProfile === "carbon" ? Theme.primary : Qt.rgba(1, 1, 1, 0.12)
                                            border.width: 1

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Full Carbon Keybind Suite"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(12)
                                                font.weight: Font.DemiBold
                                                color: sysTabRoot.keybindProfile === "carbon" ? Theme.primary : "#FFFFFF"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: sysTabRoot.setKeybindProfile("carbon")
                                            }
                                        }
                                    }
                                }
                            }

                            // Card 2: Shell Lifecycle & Quick Actions
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Theme.px(150)
                                radius: Theme.px(14)
                                color: Qt.rgba(1, 1, 1, 0.03)
                                border.color: Qt.rgba(1, 1, 1, 0.08)
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: Theme.px(18)
                                    spacing: Theme.px(12)

                                    Text {
                                        text: "Shell Lifecycle & Repository Actions"
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontPx(13.5)
                                        font.weight: Font.Bold
                                        color: "#FFFFFF"
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: Theme.px(10)

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: Theme.px(42)
                                            radius: Theme.px(10)
                                            color: Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Qt.rgba(1, 1, 1, 0.14)
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰑓  Re-Sync Mode Keybinds"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(12)
                                                font.weight: Font.DemiBold
                                                color: "#FFFFFF"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    sysTabRoot.statusBanner = "Synchronized isolated keybinds for mode: " + sysTabRoot.activeShellMode
                                                    Quickshell.execDetached(["bash", sysTabRoot.cfgDir + "/scripts/carbon-mode-keybinds.sh"])
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: Theme.px(42)
                                            radius: Theme.px(10)
                                            color: Qt.rgba(1, 1, 1, 0.06)
                                            border.color: Qt.rgba(1, 1, 1, 0.14)
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰓦  Open Focus HUD (SUPER + K)"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(12)
                                                font.weight: Font.DemiBold
                                                color: "#FFFFFF"
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Quickshell.execDetached(["sh", sysTabRoot.cfgDir + "/scripts/carbon-focus.sh"])
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: Theme.px(42)
                                            radius: Theme.px(10)
                                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                            border.color: Theme.primary
                                            border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰚰  Update Shell (carbon-update)"
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontPx(12)
                                                font.weight: Font.Bold
                                                color: Theme.primary
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    sysTabRoot.statusBanner = "Running carbon-update in background..."
                                                    Quickshell.execDetached(["bash", "-c", "if command -v kitty >/dev/null 2>&1; then kitty -e bash -c '\"$HOME/.local/bin/carbon-update\"; read -p \"Press Enter to close...\"'; else \"$HOME/.local/bin/carbon-update\"; fi"])
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true }
                        }
                    }
                }
            }
        }
    }
}
