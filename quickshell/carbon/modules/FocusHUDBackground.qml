import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Singletons"

/**
 * FocusHUDBackground — Spatial Canvas Blueprint Backdrop
 *
 * Renders on Wayland Layer Bottom (above wallpaper, below normal windows) when Focus Mode is active.
 */
PanelWindow {
    id: focusHudBg

    WlrLayershell.namespace: "carbon-focus-bg"
    WlrLayershell.layer: WlrLayer.Bottom
    exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "#050608"

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("CARBON_CONFIG_DIR") || (focusHudBg.homeDir + "/.config/carbon")
    property string gridSource: "file://" + focusHudBg.configDir + "/assets/blueprint-grid.svg"

    // Pass all mouse events through to wallpaper or windows
    mask: Region {}

    // Deep Architectural Dimming Backdrop
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Theme.m3surfaceContainerLowest.r, Theme.m3surfaceContainerLowest.g, Theme.m3surfaceContainerLowest.b, 0.88)

        Behavior on color { ColorAnimation { duration: 400 } }
    }

    // Architectural Blueprint SVG Grid Overlay
    Image {
        id: blueprintImg
        anchors.fill: parent
        source: focusHudBg.gridSource
        fillMode: Image.Tile
        opacity: 0.35
        horizontalAlignment: Image.AlignLeft
        verticalAlignment: Image.AlignTop
        onStatusChanged: {
            if (status === Image.Error && String(source).indexOf("/.local/share/quickshell/") === -1) {
                source = "file://" + focusHudBg.homeDir + "/.local/share/quickshell/carbon/assets/blueprint-grid.svg"
            }
        }
    }
}
