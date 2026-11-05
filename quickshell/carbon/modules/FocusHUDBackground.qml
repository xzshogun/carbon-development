import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * FocusHUDBackground:
 * Renders the full-screen obsidian background and tiled blueprint grid
 * on Wayland Layer Bottom (sits ABOVE the wallpaper, BELOW normal windows).
 */
PanelWindow {
    id: focusHudBg

    WlrLayershell.namespace: "carbon-focus-bg"
    WlrLayershell.layer: WlrLayer.Bottom
    exclusiveZone: 0 
    anchors { top: true; bottom: true; left: true; right: true }
    color: "#050608"

    property var modelData: null
    screen: modelData

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("CARBON_CONFIG_DIR") || (homeDir + "/.config/carbon")
    readonly property string gridSource: configDir + "/assets/blueprint-grid.svg"

    // Pass all mouse events through to wallpaper or windows
    mask: Region {}

    Image {
        anchors.fill: parent
        source: focusHudBg.gridSource
        fillMode: Image.Tile
        opacity: 0.15 
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
    }
}
