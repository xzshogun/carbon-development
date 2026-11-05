import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "../Singletons"

/**
 * TrayPopup:
 * Windows-style compact background applications icon grid.
 * Displays only application icons for background processes and system tray items.
 * Left-click to open/activate, right-click to close/menu, hover displays application name tooltip.
 */
Item {
    id: root

    property bool open: false
    property string barEdge: "top"
    property string barMode: "notch"
    property real notchOpacity: 0.96
    property bool hovered: hoverHandler.hovered
    property string selectedAppId: ""
    property string hoveredAppName: ""
    signal requestedClose()

    clip: true

    focus: root.open
    Keys.enabled: root.open
    Keys.onEscapePressed: (event) => {
        root.requestedClose()
        event.accepted = true
    }

    // 1. Native StatusNotifierItem (SNI) tray items
    readonly property var sniItems: SystemTray.items.values.filter(function (it) {
        var key = ((it.id || "") + " " + (it.title || "") + " " + (it.tooltipTitle || "")).toLowerCase()
        return !/(nm[ _-]?applet|blueman)/.test(key)
    })

    // 2. Active Background & Desktop Applications (scanned from Hyprland & user processes)
    property var bgApps: []

    Process {
        id: bgAppsProbe
        command: ["python3", (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/carbon-tray-apps.py"]
        stdout: StdioCollector {
            id: bgAppsCol
            waitForEnd: true
        }
        onExited: {
            try {
                const txt = String(bgAppsCol.text).trim()
                if (txt.length > 0) {
                    root.bgApps = JSON.parse(txt)
                }
            } catch (e) {
                console.log("[TrayPopup] Error parsing background apps:", e)
            }
        }
    }

    Timer {
        id: bgRefreshTimer
        interval: 3000
        repeat: true
        running: root.open
        onTriggered: {
            if (!bgAppsProbe.running) bgAppsProbe.running = true
        }
    }

    property bool animatingOut: false
    onOpenChanged: {
        if (root.open) {
            root.hoveredAppName = ""
            if (!bgAppsProbe.running) bgAppsProbe.running = true
            root.animatingOut = false
            animatingOutTimer.stop()
        } else {
            root.hoveredAppName = ""
            root.animatingOut = true
            animatingOutTimer.restart()
        }
    }
    Timer {
        id: animatingOutTimer
        interval: 200
        onTriggered: root.animatingOut = false
    }

    Component.onCompleted: {
        if (!bgAppsProbe.running) bgAppsProbe.running = true
    }

    // Unified List of All Tray & Background Apps
    readonly property var allItems: {
        var list = []
        var seenKeys = {}

        // Add native SNI items first
        for (var i = 0; i < sniItems.length; i++) {
            var it = sniItems[i]
            var key = ((it.id || "") + " " + (it.title || "")).toLowerCase()
            seenKeys[key] = true
            list.push({
                id: "sni-" + (it.id || i),
                isSni: true,
                rawItem: it,
                name: it.title || it.tooltipTitle || it.id || "Tray App",
                icon: it.icon || "",
                iconPath: "",
                hasWindow: false,
                actions: [
                    { id: "activate", label: "Open / Activate", action: "sniActivate" },
                    (it.hasMenu ? { id: "native_menu", label: "App Menu", action: "sniMenu" } : null),
                    { id: "quit", label: "Quit", danger: true, action: "sniQuit" }
                ].filter(function (a) { return a !== null })
            })
        }

        // Add Background applications (Serein, Antigravity, Firefox, Mixtape, etc.)
        for (var j = 0; j < bgApps.length; j++) {
            var app = bgApps[j]
            var appKey = (app.class || app.name || "").toLowerCase()
            var matched = false
            for (var k in seenKeys) {
                if (k.indexOf(appKey) !== -1 || appKey.indexOf(k) !== -1) {
                    matched = true
                    break
                }
            }
            if (!matched) {
                list.push({
                    id: app.id || ("bg-" + j),
                    isSni: false,
                    rawItem: app,
                    name: app.name || app.title || "App",
                    icon: app.icon || "application-x-executable",
                    iconPath: app.iconPath || "",
                    address: app.address || "",
                    workspace: app.workspace || 1,
                    hasWindow: Boolean(app.hasWindow),
                    exec: app.exec || "",
                    appClass: app.class || "",
                    pid: app.pid || 0,
                    actions: (app.actions && app.actions.length > 0) ? app.actions : [
                        (app.hasWindow ? { id: "focus", action: "focus" } : null),
                        { id: "quit", danger: true, action: "close" }
                    ].filter(function (a) { return a !== null })
                })
            }
        }

        return list
    }

    function executeAction(act, app) {
        if (!act || !app) return

        // 1. Direct shell command
        if (act.cmd) {
            Quickshell.execDetached(["sh", "-c", act.cmd])
        }

        // 2. Hyprland window actions
        if (act.action === "focus") {
            if (app.hasWindow && app.address) {
                if (app.workspace > 0) {
                    Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(app.workspace)])
                }
                Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + app.address])
            }
            root.requestedClose()
            return
        }
        else if (act.action === "movetoworkspace") {
            if (app.hasWindow && app.address) {
                Quickshell.execDetached(["hyprctl", "dispatch", "movetoworkspace", "+0,address:" + app.address])
                Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + app.address])
            }
            root.requestedClose()
            return
        }
        else if (act.action === "togglefloating") {
            if (app.hasWindow && app.address) {
                Quickshell.execDetached(["hyprctl", "dispatch", "togglefloating", "address:" + app.address])
            }
            root.requestedClose()
            return
        }
        // 3. Compulsory close / quit
        else if (act.action === "close") {
            if (app.hasWindow && app.address) {
                Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + app.address])
            }
            if (app.pid) {
                Quickshell.execDetached(["kill", String(app.pid)])
            }
            root.requestedClose()
            bgRefreshTimer.restart()
            if (!bgAppsProbe.running) bgAppsProbe.running = true
            return
        }
        // 4. Native SNI actions
        else if (act.action === "sniActivate") {
            if (app.rawItem) app.rawItem.activate()
            root.requestedClose()
            return
        }
        else if (act.action === "sniMenu") {
            if (app.rawItem && app.rawItem.hasMenu) {
                app.rawItem.openMenu(0, 0)
            } else if (app.rawItem) {
                app.rawItem.secondaryActivate()
            }
            root.requestedClose()
            return
        }
        else if (act.action === "sniQuit") {
            if (app.rawItem) {
                app.rawItem.secondaryActivate()
            }
            var procName = (app.name || "").toLowerCase().replace(/\s+/g, "")
            if (procName) {
                Quickshell.execDetached(["sh", "-c", "pkill -f " + procName + " 2>/dev/null || true"])
            }
            root.requestedClose()
            bgRefreshTimer.restart()
            if (!bgAppsProbe.running) bgAppsProbe.running = true
            return
        }
    }

    readonly property int colCount: 4
    readonly property int rowCount: Math.max(1, Math.ceil(allItems.length / 4))

    implicitWidth: 196
    implicitHeight: Math.max(110, (rowCount * 44) + 76)

    HoverHandler {
        id: hoverHandler
    }

    /* ── Floating Windows-style Card Container ── */
    Rectangle {
        id: bgCard
        anchors.fill: parent
        radius: 14
        color: Theme.cardBg || Theme.bgElevated || Qt.rgba(0.08, 0.08, 0.1, 0.95)
        border.width: 1
        border.color: Theme.outline || Qt.alpha(Theme.fg, 0.12)
        clip: true

        opacity: root.open ? 1.0 : 0.0
        scale: root.open ? 1.0 : 0.95
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            // Header Row: Icon & Section title
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: "󰅀"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    color: Theme.accent
                }

                Text {
                    text: "BACKGROUND APPS"
                    font.family: "Plus Jakarta Sans"
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: Theme.fgDim
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                // Count badge
                Rectangle {
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    radius: 9
                    color: Qt.alpha(Theme.accent, 0.15)

                    Text {
                        anchors.centerIn: parent
                        text: String(root.allItems.length)
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        color: Theme.accentLit || Theme.accent
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Qt.alpha(Theme.fg, 0.08)
            }

            // Apps Grid Area
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Empty state if no apps running
                Text {
                    anchors.centerIn: parent
                    text: "No background apps"
                    font.family: "Plus Jakarta Sans"
                    font.pixelSize: 10
                    color: Theme.fgFaint
                    visible: root.allItems.length === 0
                }

                Grid {
                    id: appsGrid
                    anchors.centerIn: parent
                    columns: 4
                    spacing: 6
                    visible: root.allItems.length > 0

                    Repeater {
                        model: root.allItems

                        Rectangle {
                            id: tile
                            required property var modelData
                            required property int index

                            width: 38
                            height: 38
                            radius: 8
                            color: tileMouse.containsMouse ? Qt.alpha(Theme.accent, 0.18) : Qt.alpha(Theme.fg, 0.04)
                            border.width: 1
                            border.color: tileMouse.containsMouse ? Theme.accent : Qt.alpha(Theme.fg, 0.06)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            // Icon display
                            Image {
                                id: img
                                anchors.centerIn: parent
                                width: 22
                                height: 22
                                sourceSize: Qt.size(22, 22)
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                source: (tile.modelData.iconPath && tile.modelData.iconPath.length > 0)
                                    ? tile.modelData.iconPath
                                    : (tile.modelData.icon ? ("image://icon/" + tile.modelData.icon) : "")
                                visible: status === Image.Ready
                            }

                            // Fallback glyph if image is not loaded
                            Text {
                                anchors.centerIn: parent
                                visible: img.status !== Image.Ready
                                text: "󰣆"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 18
                                color: Theme.accent
                            }

                            MouseArea {
                                id: tileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton

                                onEntered: {
                                    root.hoveredAppName = tile.modelData.name
                                }
                                onExited: {
                                    if (root.hoveredAppName === tile.modelData.name) {
                                        root.hoveredAppName = ""
                                    }
                                }

                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        if (tile.modelData.isSni && tile.modelData.rawItem && tile.modelData.rawItem.hasMenu) {
                                            root.executeAction({ action: "sniMenu" }, tile.modelData)
                                        } else if (tile.modelData.actions && tile.modelData.actions.length > 0) {
                                            var closeAct = tile.modelData.actions.find(function (a) { return a.action === "close" || a.action === "sniQuit" })
                                            if (closeAct) root.executeAction(closeAct, tile.modelData)
                                            else root.executeAction(tile.modelData.actions[tile.modelData.actions.length - 1], tile.modelData)
                                        }
                                    } else {
                                        if (tile.modelData.isSni) {
                                            root.executeAction({ action: "sniActivate" }, tile.modelData)
                                        } else if (tile.modelData.hasWindow) {
                                            root.executeAction({ action: "focus" }, tile.modelData)
                                        } else if (tile.modelData.actions && tile.modelData.actions.length > 0) {
                                            root.executeAction(tile.modelData.actions[0], tile.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Footer / Tooltip Bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                radius: 6
                color: Qt.alpha(Theme.fg, 0.03)

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                    text: root.hoveredAppName.length > 0
                        ? root.hoveredAppName
                        : (root.allItems.length > 0 ? "Left-click: Open • Right-click: Close" : "No running apps")
                    font.family: "Plus Jakarta Sans"
                    font.pixelSize: 9
                    font.weight: root.hoveredAppName.length > 0 ? Font.Bold : Font.Normal
                    color: root.hoveredAppName.length > 0 ? (Theme.accentLit || Theme.accent) : Theme.fgFaint
                    elide: Text.ElideRight
                }
            }
        }
    }
}
