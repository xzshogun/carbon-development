import QtQuick
import Quickshell
import "../components"
import "../Singletons"

/**
 * Power chip. Left click spawns the logout dialog (rofi/wlogout, falling back
 * to hyprlock); right click directly suspends.
 */
IconButton {
    id: root

    glyph: "power_settings_new"
    tip: "Power"
    color: Theme.fg
    hoverColor: Theme.accentLit

    pointer: true

    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            Quickshell.execDetached(["systemctl", "suspend"]);
        } else {
            Quickshell.execDetached(["sh", "-c",
                "command -v wlogout >/dev/null && wlogout || hyprlock"]);
        }
    }
}