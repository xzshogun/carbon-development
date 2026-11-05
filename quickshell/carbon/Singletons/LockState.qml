pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * LockState.qml
 *
 * Singleton managing screen lock state and Carbon // Verci Mode toggle.
 * Reads verciModeEnabled from ~/.config/hypr/carbon-lockscreen.json and ~/.config/carbon/carbon-lockscreen.json
 */
Singleton {
    id: root

    property bool isLocked: false
    property bool cairoModeEnabled: false
    property alias verciModeEnabled: root.cairoModeEnabled
    property bool cairoRomanizeLyrics: false

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string configPath: root.home + "/.config/hypr/carbon-lockscreen.json"
    readonly property string carbonConfigPath: (Quickshell.env("CARBON_CONFIG_DIR") || (root.home + "/.config/carbon")) + "/carbon-lockscreen.json"

    FileView {
        id: cfgFile
        path: root.configPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: {
            cfgFile.reload()
            root.reloadConfig()
        }
        onLoaded: root.reloadConfig()
    }

    FileView {
        id: cfgCarbonFile
        path: root.carbonConfigPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onFileChanged: {
            cfgCarbonFile.reload()
            root.reloadConfig()
        }
        onLoaded: root.reloadConfig()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            cfgFile.reload()
            cfgCarbonFile.reload()
            root.reloadConfig()
        }
    }

    function parseConfig(txt) {
        if (!txt || txt.length === 0) return null
        try {
            return JSON.parse(txt)
        } catch (e) {}
        return null
    }

    function reloadConfig() {
        try {
            var cfgCarbon = parseConfig(cfgCarbonFile.text().trim())
            var cfgHypr = parseConfig(cfgFile.text().trim())
            var cfg = cfgCarbon || cfgHypr
            if (cfg) {
                var cairoVal = undefined
                if (cfg.cairoModeEnabled !== undefined) {
                    cairoVal = Boolean(cfg.cairoModeEnabled)
                } else if (cfg.verciModeEnabled !== undefined) {
                    cairoVal = Boolean(cfg.verciModeEnabled)
                }
                if (cairoVal !== undefined && root.cairoModeEnabled !== cairoVal) {
                    root.cairoModeEnabled = cairoVal
                    console.log("[LockState] cairoModeEnabled updated to:", root.cairoModeEnabled)
                }

                if (cfg.cairoRomanizeLyrics !== undefined) {
                    var romVal = Boolean(cfg.cairoRomanizeLyrics)
                    if (root.cairoRomanizeLyrics !== romVal) {
                        root.cairoRomanizeLyrics = romVal
                        console.log("[LockState] cairoRomanizeLyrics updated to:", root.cairoRomanizeLyrics)
                    }
                }
            }
        } catch (e) {
            console.log("[LockState] Error reading config:", e)
        }
    }

    signal requestUnlock()

    Timer {
        id: fallbackUnlockTimer
        interval: 650
        repeat: false
        onTriggered: {
            if (root.isLocked) {
                root.finishUnlock()
            }
        }
    }

    function lock() {
        root.isLocked = true
        console.log("[LockState] Cairo lock activated (RAM lazy-load start)")
    }

    function unlock() {
        if (!root.isLocked) return
        root.requestUnlock()
        fallbackUnlockTimer.restart()
    }

    function finishUnlock() {
        fallbackUnlockTimer.stop()
        root.isLocked = false
        console.log("[LockState] Cairo unlocked -> Loader destroyed (0 MB RAM)")
    }

    Component.onCompleted: {
        cfgFile.reload()
        cfgCarbonFile.reload()
        root.reloadConfig()
    }
}
