import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../Singletons"

/**
 * VisualizerHost:
 * Dynamic host and audio source manager for Nucleus audio visualizers.
 * 
 * - Manages single cava child process on-demand (only while playing & visible)
 * - Parses 48 audio bands normalized to 0.0..1.0
 * - Reads musicVisualizer ("liquidHalo" | "none") from carbon-bar-mode.json
 * - Modular design registry: adding a new design requires only 1 file and 1 registry entry
 */
Item {
    id: root

    /* ── Visibility / Activation Gating ── */
    property bool hostVisible: true
    readonly property bool isPlaying: {
        if (LyricsService.isPlaying) return true
        if (Mpris.players) {
            var list = Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
            if (list && list.length > 0) {
                for (var i = 0; i < list.length; i++) {
                    if (list[i] && list[i].playbackState === MprisPlaybackState.Playing) return true
                }
            }
        }
        return false
    }
    readonly property bool activeAndVisible: hostVisible && (root.opacity > 0.05) && root.visible

    implicitWidth: 140
    implicitHeight: 140

    /* ── Audio Bands Data (48 bands, 0.0 .. 1.0) ── */
    property var bands: []

    function resetBands() {
        var arr = new Array(48)
        for (var i = 0; i < 48; i++) {
            arr[i] = 0.0
        }
        root.bands = arr
    }

    Component.onCompleted: {
        root.resetBands()
        root.reloadConfig()
    }

    /* ── Configuration: musicVisualizer ("liquidHalo" | "none") ── */
    property string visualizerDesign: "liquidHalo"
    readonly property string configDir: Quickshell.env("CARBON_CONFIG_DIR") || ((Quickshell.env("HOME") || "") + "/.config/carbon")
    readonly property string configPath: root.configDir + "/carbon-bar-mode.json"

    FileView {
        id: cfgFile
        path: root.configPath
        watchChanges: true
        blockLoading: true
        printErrors: false
        onLoaded: root.reloadConfig()
        onFileChanged: root.reloadConfig()
    }

    function reloadConfig() {
        try {
            var txt = cfgFile.text().trim()
            if (txt.length > 0) {
                var d = JSON.parse(txt)
                if (d.musicVisualizer !== undefined && d.musicVisualizer !== null) {
                    root.visualizerDesign = String(d.musicVisualizer).trim()
                    return
                }
            }
        } catch (e) {
            console.log("[VisualizerHost] Config parse error:", e)
        }
        root.visualizerDesign = "liquidHalo"
    }

    /* ── Cava Subprocess Pipeline (Runs ONLY when active, visible, and playing) ── */
    readonly property bool cavaNeeded: (root.visualizerDesign !== "none") && root.activeAndVisible && root.isPlaying
    readonly property string cavaConfPath: root.configDir + "/cava-nucleus.conf"

    Process {
        id: cavaProc
        command: ["cava", "-p", root.cavaConfPath]
        running: root.cavaNeeded

        onRunningChanged: {
            if (!running) {
                root.resetBands()
            }
        }

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                var trimmed = line.trim()
                if (trimmed.length === 0) return
                var parts = trimmed.split(";")
                if (parts.length >= 48) {
                    var vals = new Array(48)
                    for (var i = 0; i < 48; i++) {
                        var n = parseFloat(parts[i]) || 0.0
                        vals[i] = Math.max(0.0, Math.min(1.0, n / 1000.0))
                    }
                    root.bands = vals
                }
            }
        }
    }

    /* ── Theme Color Roles ── */
    readonly property color colAccent1: (Theme.palette && Theme.palette.teal)
        ? Theme.col(Theme.palette.teal, Theme.accent)
        : Theme.accent
    readonly property color colAccent2: (Theme.palette && Theme.palette.blue)
        ? Theme.col(Theme.palette.blue, Theme.m3secondary)
        : Theme.m3secondary
    readonly property color colAccent3: (Theme.palette && Theme.palette.tertiary)
        ? Theme.col(Theme.palette.tertiary, Theme.m3tertiary)
        : Theme.m3tertiary

    /* ── Reduced Motion Check ── */
    readonly property bool reducedMotion: Boolean(Theme.reducedMotion)

    /* ── Selectable Visualizer Design Registry ── */
    readonly property var designRegistry: ({
        "liquidHalo": Qt.resolvedUrl("LiquidHalo.qml")
    })

    readonly property string selectedSource: (root.visualizerDesign !== "none" && root.designRegistry[root.visualizerDesign])
        ? String(root.designRegistry[root.visualizerDesign])
        : ""

    /* ── Dynamic Design Loader ── */
    Loader {
        id: visualizerLoader
        anchors.fill: parent
        active: root.activeAndVisible && (root.selectedSource !== "")
        source: root.activeAndVisible ? root.selectedSource : ""

        onLoaded: {
            if (item) {
                item.bands = Qt.binding(() => root.bands)
                item.playing = Qt.binding(() => root.isPlaying && root.activeAndVisible)
                item.colorAccent1 = Qt.binding(() => root.colAccent1)
                item.colorAccent2 = Qt.binding(() => root.colAccent2)
                item.colorAccent3 = Qt.binding(() => root.colAccent3)
                item.reducedMotion = Qt.binding(() => root.reducedMotion)
            }
        }
    }
}
