import QtQuick
import Quickshell
import "../components"
import "../Singletons"

/**
 * Carbon dock: three shortcut chips pinned bottom-centre. Launcher, wallpaper
 * picker and an opencode terminal. Emits signals; the shell wires the actions
 * so this module stays dumb.
 */
Item {
    id: root

    signal launchLauncher()
    signal launchWallpaper()
    signal launchTerminal()

    implicitWidth: card.width
    implicitHeight: card.height

    Rectangle {
        id: card
        width: row.width + 16
        height: row.height + 12
        radius: 14
        color: "transparent"
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8

        IconButton {
            id: wallpaperBtn
            glyph: "wallpaper"
            tip: "Change wallpaper"
            color: Theme.fg
            hoverColor: Theme.accentLit
            size: 22
            pointer: true
            onClicked: root.launchWallpaper()
        }

        IconButton {
            id: launcherBtn
            glyph: "apps"
            tip: "Launch apps"
            color: Theme.fg
            hoverColor: Theme.accentLit
            size: 22
            pointer: true
            onClicked: root.launchLauncher()
        }

        IconButton {
            id: terminalBtn
            glyph: "terminal"
            tip: "opencode"
            color: Theme.fg
            hoverColor: Theme.accentLit
            size: 22
            pointer: true
            onClicked: root.launchTerminal()
        }
    }
}