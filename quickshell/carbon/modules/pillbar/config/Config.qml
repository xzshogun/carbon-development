pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import "../services" as QsServices

Singleton {
    id: root

    Component.onCompleted: file.reload()

    property var data: ({})

    function _expandHome(p) {
        if (!p || typeof p !== "string") return p
        if (p.startsWith("~/")) return `${Quickshell.env("HOME")}/${p.slice(2)}`
        return p
    }

    readonly property var appearance: ({
        fontFamily: (data.appearance && data.appearance.fontFamily) ? data.appearance.fontFamily : "Inter",
        materialIconFont: (data.appearance && data.appearance.materialIconFont) ? data.appearance.materialIconFont : "Material Design Icons"
    })

    readonly property var paths: ({
        pywalColors: _expandHome((data.paths && data.paths.pywalColors) ? data.paths.pywalColors : "~/.cache/wal/colors.json"),
        screenshotsDir: _expandHome((data.paths && data.paths.screenshotsDir) ? data.paths.screenshotsDir : "~/Pictures/Screenshots")
    })

    readonly property var osd: ({
        volumeTimeoutMs: (data.osd && data.osd.volumeTimeoutMs !== undefined) ? data.osd.volumeTimeoutMs : 2000,
        brightnessTimeoutMs: (data.osd && data.osd.brightnessTimeoutMs !== undefined) ? data.osd.brightnessTimeoutMs : 2000
    })

    readonly property var notifications: ({
        popupWidth: (data.notifications && data.notifications.popupWidth !== undefined) ? data.notifications.popupWidth : 340,
        maxVisible: (data.notifications && data.notifications.maxVisible !== undefined) ? data.notifications.maxVisible : 5,
        timeoutMs: (data.notifications && data.notifications.timeoutMs !== undefined) ? data.notifications.timeoutMs : 7000,
        registerServer: (data.notifications && data.notifications.registerServer !== undefined) ? data.notifications.registerServer : true,
        spacing: (data.notifications && data.notifications.spacing !== undefined) ? data.notifications.spacing : 8,
        margin: (data.notifications && data.notifications.margin !== undefined) ? data.notifications.margin : 8
    })

    readonly property var launcher: ({
        enabled: (data.launcher && data.launcher.enabled !== undefined) ? data.launcher.enabled : true,
        width: (data.launcher && data.launcher.width !== undefined) ? data.launcher.width : 720,
        maxResults: (data.launcher && data.launcher.maxResults !== undefined) ? data.launcher.maxResults : 8,
        terminalCommand: (data.launcher && data.launcher.terminalCommand) ? data.launcher.terminalCommand : ["foot"],
        favorites: (data.launcher && data.launcher.favorites) ? data.launcher.favorites : [
            "org.wezfurlong.wezterm",
            "kitty",
            "Alacritty",
            "firefox",
            "zen-browser",
            "thunar",
            "org.gnome.Nautilus",
            "code",
            "Code"
        ]
    })

    readonly property var sidebar: ({
        enabled: (data.sidebar && data.sidebar.enabled !== undefined) ? data.sidebar.enabled : true,
        width: (data.sidebar && data.sidebar.width !== undefined) ? data.sidebar.width : 420,
        margin: (data.sidebar && data.sidebar.margin !== undefined) ? data.sidebar.margin : 12,
        maxHistory: (data.sidebar && data.sidebar.maxHistory !== undefined) ? data.sidebar.maxHistory : 80
    })

    readonly property var dashboard: ({
        enabled: (data.dashboard && data.dashboard.enabled !== undefined) ? data.dashboard.enabled : true,
        width: (data.dashboard && data.dashboard.width !== undefined) ? data.dashboard.width : 860,
        height: (data.dashboard && data.dashboard.height !== undefined) ? data.dashboard.height : 640,
        margin: (data.dashboard && data.dashboard.margin !== undefined) ? data.dashboard.margin : 18
    })

    readonly property BarConfig bar: BarConfig {}
    readonly property AppearanceConfig appearanceTokens: AppearanceConfig {}

    FileView {
        id: file
        path: {
            const home = Quickshell.env("HOME")
            const xdg = Quickshell.env("XDG_CONFIG_HOME")
            const cfgHome = (xdg && xdg.length > 0) ? xdg : `${home}/.config`
            return `${cfgHome}/quickshell/shell.json`
        }
        watchChanges: true

        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                root.data = parsed
                QsServices.Logger.debug("Config", "shell.json loaded")
            } catch (e) {
                QsServices.Logger.warn("Config", `Failed to parse shell.json: ${(e && e.message) ? e.message : e}`)
            }
        }

        onFileChanged: {
            file.reload()
        }

        onLoadFailed: err => {
            if (err !== FileViewError.FileNotFound)
                QsServices.Logger.warn("Config", `Failed to read shell.json: ${FileViewError.toString(err)}`)
        }
    }

    // Backwards-compatible aliases used across the repo
    readonly property var controlCenter: ({
        width: 700,
        maxHeight: 1000,
        padding: 16,
        spacing: 12,
        margin: 4,
        cornerRadius: 24
    })

    readonly property var popups: ({
        width: 280,
        minHeight: 100,
        maxHeight: 400,
        hoverDelay: 300,
        margin: 6
    })
}
