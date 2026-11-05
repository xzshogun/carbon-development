import QtQuick
import Quickshell
import "../Singletons"

/**
 * FocusHUDBackground — Spatial Canvas Blueprint Backdrop
 *
 * Renders ONLY on the background Wayland layer (behind windows) when Focus Mode is active.
 */
Item {
    id: focusHudBg

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string configDir: Quickshell.env("CARBON_CONFIG_DIR") || (focusHudBg.homeDir + "/.config/carbon")
    property string gridSource: "file://" + focusHudBg.configDir + "/assets/blueprint-grid.svg"

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
        opacity: 0.45
        onStatusChanged: {
            if (status === Image.Error && String(source).indexOf("/.local/share/quickshell/") === -1) {
                source = "file://" + focusHudBg.homeDir + "/.local/share/quickshell/carbon/assets/blueprint-grid.svg"
            }
        }
    }
}
