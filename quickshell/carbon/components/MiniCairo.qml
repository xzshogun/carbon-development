import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../Singletons"

/**
 * MiniCairo.qml:
 * Compact, ultra-low-overhead Kinetic Lyric Engine for Carbon // Center Notch Dropdown.
 *
 * Implements:
 *   - Unified Second-Based Timeline (matching MPRIS and LRCLIB native second units).
 *   - 60fps Interpolated Audio Clock (active ONLY when pavilion is open & media is playing).
 *   - Kinetic 3-Slot Vertical Barrel (Previous Word, Active Word, Next Incoming Word).
 *   - Signature Cairo Translucent Glass Tape Highlight with Matugen primary aura.
 *   - Automatic word-level LRC fallback: splits standard line-level lyrics into rhythm chunks.
 *   - 0.0% CPU usage when dashboard is closed.
 */
Item {
    id: root

    property bool active: true

    readonly property bool hasTrack: LyricsService.hasTrack
    readonly property bool isPlaying: LyricsService.isPlaying
    readonly property real currentPosition: LyricsService.currentPosition

    readonly property var rawLines: (CairoLyricsService.lines && CairoLyricsService.lines.length > 0)
                                    ? CairoLyricsService.lines
                                    : LyricsService.lines
    readonly property bool isUntimed: hasTrack && rawLines && rawLines.length > 0 && Boolean(rawLines[0] && rawLines[0].untimed === true)
    readonly property bool hasTimedLyrics: hasTrack && rawLines && rawLines.length > 0 && !isUntimed
    readonly property bool hasLyrics: hasTimedLyrics

    property var tokens: []
    property int currentTokenIndex: -1

    // ── 1. 60 FPS Interpolated Wall-Clock Audio Engine (Seconds Based) ────────
    property double lastUpdateMs: Date.now()
    property real basePosSec: 0

    onCurrentPositionChanged: {
        root.lastUpdateMs = Date.now()
        root.basePosSec = root.currentPosition
        root.updateWithPosition(root.basePosSec)
    }

    onIsPlayingChanged: {
        root.lastUpdateMs = Date.now()
        root.basePosSec = root.currentPosition
        root.updateWithPosition(root.basePosSec)
    }

    onActiveChanged: {
        if (root.active) {
            root.lastUpdateMs = Date.now()
            root.basePosSec = root.currentPosition
            root.updateWithPosition(root.basePosSec)
        }
    }

    Timer {
        id: liveClockTimer
        interval: 16
        repeat: true
        running: root.active && root.isPlaying && root.hasLyrics
        onTriggered: {
            if (root.isPlaying) {
                var elapsedSec = (Date.now() - root.lastUpdateMs) / 1000.0
                var estPos = root.basePosSec + elapsedSec
                root.updateWithPosition(estPos)
            }
        }
    }

    // ── 2. Word Tokenizer (Word-level LRC or Procedural Rhythm Chunks) ────────
    onRawLinesChanged: rebuildTokens()
    onHasTrackChanged: rebuildTokens()

    function rebuildTokens() {
        var srcLines = root.rawLines || []
        if (srcLines.length === 0 || !root.hasTrack) {
            root.tokens = []
            root.currentTokenIndex = -1
            return
        }

        var result = []
        for (var l = 0; l < srcLines.length; l++) {
            var line = srcLines[l]
            var lineStart = Number(line.time) || 0.0
            var nextLineStart = (l + 1 < srcLines.length && srcLines[l + 1].time !== undefined)
                                ? Number(srcLines[l + 1].time)
                                : (lineStart + 4.0)
            var lineDuration = Math.max(0.8, nextLineStart - lineStart)

            if (line.words && Array.isArray(line.words) && line.words.length > 0) {
                for (var w = 0; w < line.words.length; w++) {
                    var wd = line.words[w]
                    var wStart = (wd.time !== undefined) ? Number(wd.time) : lineStart
                    var wDur = (wd.dur !== undefined)
                               ? Number(wd.dur)
                               : (wd.duration ? (Number(wd.duration) / 1000.0) : 0.32)
                    var wEnd = (w + 1 < line.words.length && line.words[w + 1].time !== undefined)
                               ? Number(line.words[w + 1].time)
                               : (wStart + Math.max(0.10, wDur))
                    result.push({
                        text: (wd.text || "").trim(),
                        start: wStart,
                        end: Math.max(wStart + 0.08, wEnd)
                    })
                }
            } else {
                var txt = (line.text || "").trim()
                if (txt.length === 0) continue
                var words = txt.split(/\s+/).filter(function(x) { return x.length > 0 })
                if (words.length === 0) continue

                var chunks = []
                var idx = 0
                while (idx < words.length) {
                    if (idx + 1 < words.length && (words[idx].length + words[idx + 1].length) < 13) {
                        chunks.push(words[idx] + " " + words[idx + 1])
                        idx += 2
                    } else {
                        chunks.push(words[idx])
                        idx += 1
                    }
                }

                var activeWindow = Math.min(lineDuration * 0.90, chunks.length * 0.48)
                var chunkDuration = activeWindow / chunks.length
                for (var c = 0; c < chunks.length; c++) {
                    var cStart = lineStart + (c * chunkDuration)
                    var cEnd = cStart + chunkDuration
                    result.push({
                        text: chunks[c],
                        start: cStart,
                        end: cEnd
                    })
                }
            }
        }

        root.tokens = result
        root.lastUpdateMs = Date.now()
        root.basePosSec = root.currentPosition
        root.updateWithPosition(root.basePosSec)
    }

    function updateWithPosition(pos) {
        var toks = root.tokens
        if (!toks || toks.length === 0) {
            root.currentTokenIndex = -1
            return
        }

        // Calibrated 0.12s visual lookahead for responsive lead
        var p = pos + 0.12

        if (p < toks[0].start) {
            root.currentTokenIndex = -1
            return
        }

        var cur = root.currentTokenIndex
        if (cur >= 0 && cur < toks.length) {
            if (p >= toks[cur].start && p < toks[cur].end) {
                return
            }
        }

        var found = -1
        for (var i = 0; i < toks.length; i++) {
            if (p >= toks[i].start && p < toks[i].end) {
                found = i
                break
            }
            if (p < toks[i].start) {
                found = Math.max(0, i - 1)
                break
            }
        }
        if (found === -1 && toks.length > 0) {
            if (p >= toks[toks.length - 1].end) {
                found = toks.length - 1
            } else {
                found = 0
            }
        }
        if (root.currentTokenIndex !== found) {
            root.currentTokenIndex = found
        }
    }

    Component.onCompleted: {
        rebuildTokens()
        root.lastUpdateMs = Date.now()
        root.basePosSec = root.currentPosition
        root.updateWithPosition(root.basePosSec)
    }

    // ── 3. Empty State (Strictly preserves user's favorite notice) ───────────
    Item {
        anchors.fill: parent
        visible: !root.hasLyrics

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 6

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "music_note"
                font.family: Theme.fontIcon
                font.pixelSize: 18
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.40)
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.hasTrack ? "uh oh we got no lyrics for this !" : "STANDBY // NO MEDIA"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(10.5)
                font.weight: Font.Medium
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45)
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    // ── 4. Mini Cairo 3-Slot Kinetic Barrel ────────────────────────────────────
    Item {
        id: kineticBarrel
        anchors.fill: parent
        clip: true
        visible: root.hasLyrics

        readonly property real centerY: height / 2
        readonly property var toks: root.tokens
        readonly property int idx: root.currentTokenIndex

        readonly property string prevText: (idx > 0 && idx - 1 < toks.length) ? toks[idx - 1].text : ""
        readonly property string curText: (idx >= 0 && idx < toks.length) ? toks[idx].text : (toks.length > 0 ? "♪ ♪ ♪" : "")
        readonly property string nextText: (idx === -1 && toks.length > 0)
                                           ? toks[0].text
                                           : ((idx + 1 < toks.length) ? toks[idx + 1].text : "")

        // Slot 0: Previous Word (Receding upward, Stage 1)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: kineticBarrel.centerY - 34 - height / 2
            width: prevTxt.implicitWidth
            height: prevTxt.implicitHeight
            opacity: kineticBarrel.prevText.length > 0 ? 0.35 : 0.0
            scale: 0.88

            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

            Text {
                id: prevTxt
                anchors.centerIn: parent
                text: kineticBarrel.prevText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.Medium
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.60)
            }
        }

        // Slot 1: Active Word (Stage 0 with Cairo Glass Tape Highlight)
        Item {
            id: activeWordSlot
            anchors.horizontalCenter: parent.horizontalCenter
            y: kineticBarrel.centerY - height / 2
            width: Math.max(80, curTxt.implicitWidth + 28)
            height: curTxt.implicitHeight + 10
            opacity: kineticBarrel.curText.length > 0 ? (kineticBarrel.idx === -1 ? 0.45 : 1.0) : 0.0

            Behavior on width { NumberAnimation { duration: 140; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

            // Cairo Signature Translucent Glass Tape Block
            Rectangle {
                anchors.fill: parent
                radius: 6
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.22)
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.65)
                border.width: 1
                z: -1
                visible: kineticBarrel.idx >= 0

                // Subtle ambient glow border
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: 7
                    color: "transparent"
                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                    border.width: 1
                }
            }

            // Word Text
            Text {
                id: curTxt
                anchors.centerIn: parent
                text: kineticBarrel.curText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(15)
                font.weight: Font.ExtraBold
                font.letterSpacing: -0.4
                color: Theme.fg

                Behavior on text {
                    SequentialAnimation {
                        NumberAnimation { target: curTxt; property: "scale"; to: 0.94; duration: 40; easing.type: Easing.OutQuad }
                        NumberAnimation { target: curTxt; property: "scale"; to: 1.0; duration: 90; easing.type: Easing.OutBack }
                    }
                }
            }
        }

        // Slot 2: Next Incoming Word (Stage -1)
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            y: kineticBarrel.centerY + 34 - height / 2
            width: nextTxt.implicitWidth
            height: nextTxt.implicitHeight
            opacity: kineticBarrel.nextText.length > 0 ? 0.45 : 0.0
            scale: 0.90

            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuint } }
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

            Text {
                id: nextTxt
                anchors.centerIn: parent
                text: kineticBarrel.nextText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontPx(11)
                font.weight: Font.Medium
                color: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.70)
            }
        }
    }
}
