pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

/**
 * LyricsService: Global singleton managing real-time synced lyrics (LRCLIB)
 * and MPRIS track progress. Automatically fetches and syncs line by line.
 */
Singleton {
    id: root

    readonly property var players: Mpris.players.values !== undefined ? Mpris.players.values : Mpris.players
    property string preferredPlayerBus: ""
    property real lastSkipTime: 0

    property var activePlayer: null

    function isBrowserPlayer(p) {
        if (!p) return false
        var name = (p.dbusName || p.identity || "").toLowerCase()
        return name.includes("firefox") || name.includes("chromium") || name.includes("chrome") || name.includes("zen")
    }

    function resolveActivePlayer() {
        var list = root.players
        if (!list || list.length === 0) return null

        // 1. If currently active player is playing and is NOT a browser, keep it
        if (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing && !isBrowserPlayer(root.activePlayer)) {
            return root.activePlayer
        }

        // 2. Any dedicated non-browser media player that is currently Playing
        for (var i = 0; i < list.length; i++) {
            if (list[i] && list[i].playbackState === MprisPlaybackState.Playing && !isBrowserPlayer(list[i])) {
                return list[i]
            }
        }

        // 3. Fallback to currently active player if it's Playing (even if browser)
        if (root.activePlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) {
            return root.activePlayer
        }

        // 4. Any player that is Playing (e.g. Browser)
        for (var j = 0; j < list.length; j++) {
            if (list[j] && list[j].playbackState === MprisPlaybackState.Playing) {
                return list[j]
            }
        }

        // 5. Preferred player bus
        if (root.preferredPlayerBus && root.preferredPlayerBus.length > 0) {
            for (var k = 0; k < list.length; k++) {
                if (list[k] && (list[k].dbusName || "") === root.preferredPlayerBus) {
                    return list[k]
                }
            }
        }

        // 6. Dedicated non-browser player that is Paused with trackTitle
        for (var m = 0; m < list.length; m++) {
            var pNonBrowser = list[m]
            if (pNonBrowser && pNonBrowser.playbackState === MprisPlaybackState.Paused && (pNonBrowser.trackTitle || "").length > 0 && !isBrowserPlayer(pNonBrowser)) {
                return pNonBrowser
            }
        }

        // 7. Any player that is Paused with trackTitle
        for (var n = 0; n < list.length; n++) {
            if (list[n] && list[n].playbackState === MprisPlaybackState.Paused && (list[n].trackTitle || "").length > 0) {
                return list[n]
            }
        }

        return list[0] || null
    }

    onActivePlayerChanged: {
        if (activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing) {
            root.preferredPlayerBus = activePlayer.dbusName || ""
        }
    }

    readonly property string trackTitle: activePlayer ? (activePlayer.trackTitle || "") : ""
    readonly property string trackArtist: activePlayer ? (activePlayer.trackArtist || "") : ""
    readonly property string trackAlbum: activePlayer && activePlayer.metadata ? (activePlayer.metadata["xesam:album"] || "") : ""
    readonly property string trackId: activePlayer && activePlayer.metadata && activePlayer.metadata["mpris:trackid"] ? String(activePlayer.metadata["mpris:trackid"]) : ""
    readonly property string artUrl: activePlayer ? (activePlayer.trackArtUrl || "") : ""
    readonly property bool isPlaying: activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: trackTitle.trim().length > 0

    readonly property real currentPosition: (activePlayer && activePlayer.position) ? (activePlayer.position > 100000 ? (activePlayer.position / 1000000) : activePlayer.position) : 0
    readonly property real totalLength: {
        if (!activePlayer || !activePlayer.length) return 0
        return activePlayer.length > 100000 ? (activePlayer.length / 1000000) : activePlayer.length
    }

    property var lines: []
    property bool hasLyrics: lines.length > 0
    readonly property bool hasRichWords: {
        if (!lines || lines.length === 0) return false
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].words && lines[i].words.length > 0) return true
        }
        return false
    }
    property int currentIndex: -1
    property string currentLine: ""
    property string nextLine: ""
    property string prevLine: ""

    property string lastFetchedKey: ""
    property bool enabled: true

    onEnabledChanged: {
        if (!enabled) {
            lyricsProc.running = false
            lines = []
            currentLine = ""
            nextLine = ""
            prevLine = ""
            lastFetchedKey = ""
        }
    }

    Timer {
        id: playerPollTimer
        interval: 300
        repeat: true
        running: root.enabled
        triggeredOnStart: true
        onTriggered: {
            var p = root.resolveActivePlayer()
            if (root.activePlayer !== p) {
                root.activePlayer = p
                console.log("[LyricsService] activePlayer changed to:", p ? p.trackTitle : "null")
            }
            var title = p ? (p.trackTitle || "") : root.trackTitle
            var artist = p ? (p.trackArtist || "") : root.trackArtist
            var key = title + "::" + artist
            if (title.trim().length > 0 && key !== root.lastFetchedKey && !lyricsProc.running) {
                console.log("[LyricsService] Triggering fetchLyrics for:", key)
                root.fetchLyrics()
            }
        }
    }

    onTrackTitleChanged: {
        if (root.enabled) {
            root.lastFetchedKey = ""
            if (lyricsProc.running) lyricsProc.running = false
            root.lines = []
            root.currentLine = ""
            root.nextLine = ""
            root.prevLine = ""
            fetchLyrics()
        }
    }
    onTrackArtistChanged: {
        if (root.enabled) {
            root.lastFetchedKey = ""
            if (lyricsProc.running) lyricsProc.running = false
            root.lines = []
            root.currentLine = ""
            root.nextLine = ""
            root.prevLine = ""
            fetchLyrics()
        }
    }
    onTotalLengthChanged: {
        if (root.enabled && root.totalLength > 5 && (!root.lines || root.lines.length === 0) && !lyricsProc.running) {
            root.lastFetchedKey = ""
            root.fetchLyrics()
        }
    }
    onCurrentPositionChanged: updateSync()
    onIsPlayingChanged: updateSync()

    function reloadLyrics() {
        root.lastFetchedKey = ""
        root.lines = []
        if (lyricsProc.running) lyricsProc.running = false
        root.fetchLyrics()
    }

    function fetchLyrics() {
        var p = root.activePlayer
        var title = p ? (p.trackTitle || "") : root.trackTitle
        var artist = p ? (p.trackArtist || "") : root.trackArtist
        if (!title || title.trim().length === 0) {
            root.lines = []
            root.currentLine = ""
            root.nextLine = ""
            root.prevLine = ""
            return
        }

        var key = title + "::" + artist
        if (root.lastFetchedKey === key && (root.lines.length > 0 || lyricsProc.running)) return
        if (lyricsProc.running) return

        root.lastFetchedKey = key
        lyricsProc.requestedKey = key

        lines = []
        currentIndex = -1
        currentLine = ""
        nextLine = ""
        prevLine = ""

        var home = Quickshell.env("HOME") || ""
        var carbonScript = home + "/.config/carbon/scripts/carbon-lyrics.py"
        var localScript = Qt.resolvedUrl("../scripts/carbon-lyrics.py").toString().replace(/^file:\/\//, "")
        var scriptPath = Quickshell.env("CARBON_LYRICS_PATH") || carbonScript

        var cmd = [
            "python3",
            scriptPath,
            "--title", title,
            "--artist", artist,
            "--duration", String(Math.round(root.totalLength)),
            "--mode", "shell",
            "--no-romanize"
        ]
        if (root.trackId && root.trackId.length > 0) {
            cmd.push("--trackid", root.trackId)
        }
        lyricsProc.command = cmd
        lyricsProc.running = true
    }

    Process {
        id: lyricsProc
        property string requestedKey: ""

        stdout: StdioCollector {
            id: lyricsStdio
            waitForEnd: true
        }
        stderr: SplitParser {
            onRead: (line) => {
                console.log("[LyricsService stderr]", line)
            }
        }

        onExited: function(code) {
            if (requestedKey !== root.lastFetchedKey) {
                return
            }
            var out = (lyricsStdio.text || "").trim()
            if (code === 0 && out.length > 0) {
                try {
                    const res = JSON.parse(out)
                    if (res && res.found && Array.isArray(res.lines) && res.lines.length > 0) {
                        root.lines = res.lines
                        root.updateSync()
                        console.log("[LyricsService] Loaded " + root.lines.length + " synced lyric lines for:", root.trackTitle)
                    } else {
                        root.lines = []
                    }
                } catch (e) {
                    console.log("[LyricsService] Error parsing lyrics JSON:", e)
                    root.lines = []
                }
            } else {
                root.lines = []
            }
        }
    }

    /* Poller for position tracking and real-time lyric line resolution */
    Timer {
        interval: 100
        repeat: true
        running: root.enabled && root.isPlaying
        onTriggered: {
            if (root.activePlayer && root.activePlayer.positionSupported) {
                root.activePlayer.positionChanged()
            }
            root.updateSync()
        }
    }

    function updateSync() {
        if (!lines || lines.length === 0) {
            currentIndex = -1
            currentLine = ""
            nextLine = ""
            prevLine = ""
            return
        }

        // Add 250ms lookahead to compensate for MPRIS polling frequency and audio buffer latency
        const pos = root.currentPosition + 0.25

        // Check if we are still in the song intro before singing starts
        if (pos < lines[0].time) {
            currentIndex = -1
            currentLine = ""
            nextLine = lines[0].text
            prevLine = ""
            return
        }

        let idx = -1
        for (let i = 0; i < lines.length; i++) {
            if (lines[i].time <= pos) {
                idx = i
            } else {
                break
            }
        }

        currentIndex = idx
        if (idx >= 0 && idx < lines.length) {
            const lineTime = lines[idx].time
            const nextTime = (idx + 1 < lines.length) ? lines[idx + 1].time : (lineTime + 10.0)
            const elapsed = pos - lineTime

            // If there is an extended instrumental gap (>8s) and the line was sung >6.5s ago, expire line
            if ((nextTime - lineTime > 8.0) && (elapsed > 6.5)) {
                currentLine = ""
            } else {
                currentLine = lines[idx].text
            }
            nextLine = (idx + 1 < lines.length) ? lines[idx + 1].text : ""
            prevLine = (idx - 1 >= 0) ? lines[idx - 1].text : ""
        } else {
            currentIndex = -1
            currentLine = ""
            nextLine = lines.length > 0 ? lines[0].text : ""
            prevLine = ""
        }
    }

    function formatTime(sec) {
        if (!sec || isNaN(sec) || sec < 0) return "0:00"
        const s = Math.floor(sec)
        const m = Math.floor(s / 60)
        const rem = s % 60
        return `${m}:${rem < 10 ? "0" : ""}${rem}`
    }

    function skipNext() {
        const now = Date.now()
        if (now - root.lastSkipTime < 240) return
        root.lastSkipTime = now
        Quickshell.execDetached(["playerctl", "next"])
    }

    function skipPrevious() {
        const now = Date.now()
        if (now - root.lastSkipTime < 240) return
        root.lastSkipTime = now
        Quickshell.execDetached(["playerctl", "previous"])
    }

    function togglePlaying() {
        Quickshell.execDetached(["playerctl", "play-pause"])
    }

    function seekTo(sec) {
        if (root.activePlayer) {
            try {
                var posUs = Math.round(sec * 1000000)
                root.activePlayer.position = (root.activePlayer.position > 100000) ? posUs : sec
            } catch (e) {}
        }
        Quickshell.execDetached(["playerctl", "position", String(Math.floor(sec))])
        if (root.activePlayer && root.activePlayer.positionSupported) {
            root.activePlayer.positionChanged()
        }
    }

    function seekFraction(frac) {
        if (root.totalLength > 0) {
            root.seekTo(Math.max(0, Math.min(1.0, frac)) * root.totalLength)
        }
    }

    Component.onCompleted: {
        console.log("[LyricsService] Global service initialized")
        fetchLyrics()
    }
}
