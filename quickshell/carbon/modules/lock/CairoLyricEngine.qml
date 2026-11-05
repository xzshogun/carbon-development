import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../Singletons"
import "CairoHinglishMap.js" as GlyphMap

/**
 * CairoLyricEngine:
 * High-Precision 60fps Kinetic Lyric Timeline Engine for Carbon // Cairo.
 *
 * Implements:
 *   - 60fps interpolated audio clock with MPRIS D-Bus drift-nudging & seek snapping.
 *   - Live keyboard sync offset (default -120ms lead compensation).
 *   - Enhanced word-level LRC parser (<mm:ss.xx> or [mm:ss.xx]).
 *   - Syllable-clamped vocal window cadence (fixes slow-motion instrumental stretching).
 *   - Holds final word calmly in Stage 0 across instrumental gaps.
 *   - Structured 1-to-2 word rows with per-word startMs/endMs tokens for single-word highlighting.
 */
Item {
    id: root

    readonly property bool isPlaying: LyricsService.isPlaying
    readonly property bool hasTrack: LyricsService.hasTrack
    readonly property real currentPosition: LyricsService.currentPosition

    // ── 1. Live Wall-Clock + MPRIS Sync Engine ──────────────────────────────
    property double songEpochMs: 0
    property real livePositionMs: 0
    property real lastRawMprisPosMs: -1
    property int syncOffsetMs: 0 // Neutral 0ms sync
    readonly property int visualLeadMs: CairoLyricsService.hasRichWords ? 120 : 100 // Calibrated 120ms lead compensation for audio driver latency & snappy on-beat delivery

    readonly property real effectivePositionMs: Math.max(0, root.livePositionMs + root.visualLeadMs - root.syncOffsetMs)
    readonly property real effectivePositionSec: root.effectivePositionMs / 1000.0

    function syncBaseTimeFromMpris() {
        var mprisSec = LyricsService.currentPosition
        var posMs = (mprisSec && !isNaN(mprisSec) && mprisSec >= 0) ? (mprisSec * 1000.0) : 0
        root.songEpochMs = Date.now() - posMs
        root.lastRawMprisPosMs = posMs
        root.livePositionMs = posMs
        root.updateSync()
    }

    function resetPlaybackClock() {
        root.syncBaseTimeFromMpris()
    }

    Connections {
        target: LyricsService
        function onCurrentPositionChanged() {
            var mprisMs = LyricsService.currentPosition * 1000.0
            if (mprisMs >= 0) {
                var diff = Math.abs(root.livePositionMs - mprisMs)
                // If clock drifts more than 160ms or epoch not set, smoothly snap to media player
                if (diff > 160 || root.songEpochMs <= 0) {
                    root.songEpochMs = Date.now() - mprisMs
                    root.livePositionMs = mprisMs
                    root.updateSync()
                }
            }
        }
        function onIsPlayingChanged() {
            root.syncBaseTimeFromMpris()
        }
    }

    // 16ms Live Playback Timer (60 FPS): Pure Date.now() wall-clock stopwatch.
    // NEVER queries activePlayer.position over D-Bus inside this loop to prevent freezing!
    Timer {
        id: playbackTimer
        interval: 16
        repeat: true
        running: true
        onTriggered: {
            var activePlayer = LyricsService.activePlayer
            var isPlaying = root.isPlaying || !activePlayer || activePlayer.playbackState === MprisPlaybackState.Playing || activePlayer.isPlaying !== false
            if (root.songEpochMs > 0 && isPlaying) {
                root.livePositionMs = Math.max(0, Date.now() - root.songEpochMs)
            }
            root.updateSync()
        }
    }

    // ── 2. Lyric Data & Timeline Storage ───────────────────────────────────
    property var allWords: []
    readonly property bool hasLyrics: allWords.length > 0 && hasTrack

    property var row0Word: null
    property var row1Word: null
    property var row2Word: null
    property int clusterSize: 0

    property int currentWordIndex: -1
    property int currentTokenIndex: -1
    property real lastTokenStepTimeMs: 0
    property var activeBeat: null

    signal beatTriggered(var beatData)
    signal clearRequested()

    function sanitizeLineTokens(tokens) {
        if (!tokens || tokens.length === 0) return [];

        // 1. Deduplicate consecutive identical ad-lib echoes within < 350ms
        var deduped = [];
        for (var i = 0; i < tokens.length; i++) {
            var cur = tokens[i];
            if (deduped.length > 0) {
                var prev = deduped[deduped.length - 1];
                var cleanCur = (cur.word || "").trim().toLowerCase();
                var cleanPrev = (prev.word || "").trim().toLowerCase();
                if (cleanCur.length > 0 && cleanCur === cleanPrev && (cur.startMs - prev.endMs) < 350) {
                    prev.endMs = Math.max(prev.endMs, cur.endMs);
                    prev.vocalEndMs = Math.max(prev.vocalEndMs || prev.endMs, cur.vocalEndMs || cur.endMs);
                    continue;
                }
            }
            deduped.push(cur);
        }

        // 2. Enforce minimum 60ms duration per token and shift subsequent tokens on same line
        for (var k = 0; k < deduped.length; k++) {
            var tok = deduped[k];
            tok.endMs = Math.max(tok.startMs + 60, tok.endMs);
            tok.vocalEndMs = Math.max(tok.startMs + 60, tok.vocalEndMs || tok.endMs);
            if (k + 1 < deduped.length) {
                var nextTok = deduped[k + 1];
                if (nextTok.startMs < tok.startMs + 60) {
                    var shiftMs = (tok.startMs + 60) - nextTok.startMs;
                    nextTok.startMs += shiftMs;
                    nextTok.endMs += shiftMs;
                    if (nextTok.vocalEndMs) nextTok.vocalEndMs += shiftMs;
                }
            }
        }

        return deduped;
    }

    function tokenizeLineToSingleWords(lineText, lineStartMs, nextLineStartMs) {
        var rawTokens = lineText.trim().split(/\s+/).filter(function(w) { return w.length > 0; });
        if (rawTokens.length === 0) return [];

        var rawGapMs = Math.max(350, nextLineStartMs - lineStartMs);
        // Spread the words across 92% of the line gap (up to 460ms per word) for a relaxed, natural pace
        var activeWindowMs = Math.min(rawGapMs * 0.92, rawTokens.length * 460);

        var weights = [];
        var totalWeight = 0;
        for (var i = 0; i < rawTokens.length; i++) {
            var token = rawTokens[i];
            var cleanLen = token.replace(/[^a-zA-Z0-9\u0900-\u097F]/g, "").length;
            var w = Math.max(1.0, Math.pow(cleanLen, 0.5));
            if (/[,;\-\u2014\?\!]$|\.\.$/.test(token)) {
                w *= 2.2; // Hold 2.2x longer on comma/breath pauses
            }
            weights.push(w);
            totalWeight += w;
        }

        var result = [];
        var cursorMs = lineStartMs;
        for (var j = 0; j < rawTokens.length; j++) {
            var durMs = (weights[j] / totalWeight) * activeWindowMs;
            var isLast = (j === rawTokens.length - 1);
            result.push({
                word: rawTokens[j],
                startMs: Math.round(cursorMs),
                endMs: isLast ? Math.round(nextLineStartMs) : Math.round(cursorMs + durMs),
                vocalEndMs: isLast ? Math.round(nextLineStartMs) : Math.round(cursorMs + durMs)
            });
            cursorMs += durMs;
        }
        return root.sanitizeLineTokens(result);
    }

    readonly property var leadGlueWords: new Set([
        // English Pronouns, Prepositions, Auxiliaries & Contractions
        "i", "im", "i'm", "ive", "i've", "id", "i'd", "ill", "i'll",
        "you", "youre", "you're", "youve", "you've", "youd", "you'd", "your",
        "he", "hes", "he's", "his", "she", "shes", "she's", "her",
        "we", "were", "we're", "weve", "we've", "we'll", "our",
        "they", "theyre", "they're", "their", "them", "it", "its", "it's",
        "my", "me", "mine", "us", "who", "what", "whats", "what's", "that", "thats", "that's", "this", "these", "those",
        "in", "on", "at", "to", "for", "with", "from", "by", "of", "out", "up", "down", "into", "over", "under", "through",
        "a", "an", "the", "some", "all", "no", "not", "noo", "nah", "oh", "ooh", "ah", "yeah", "yea", "yo", "hey", "ay", "ayy",
        "is", "are", "was", "were", "be", "been", "am", "do", "dont", "don't", "does", "did", "didnt", "didn't",
        "can", "cant", "can't", "could", "will", "wont", "won't", "would", "should", "may", "might", "must",
        "got", "get", "gonna", "gon", "wanna", "wana", "gotta", "lemme", "gimme", "outta", "kinda", "sorta", "tryna",
        "so", "if", "or", "and", "but", "cuz", "cause", "'cause", "cos", "just", "only", "even", "still", "too", "very", "real",
        "when", "where", "why", "how", "now", "then", "here", "there", "every", "each", "another",

        // Hinglish & Punjabi Pronouns, Connectors & Starters
        "tu", "tera", "tere", "teri", "tujhe", "tujhko", "tuhada", "tuhadi", "tenu", "tainu", "tusi",
        "mai", "main", "mera", "mere", "meri", "mujhe", "mujhko", "menu", "mainu", "asi", "assi", "sada", "sade", "sadi", "apna", "apne", "apni",
        "wo", "woh", "o", "oh", "ohda", "ohde", "ohdi", "ohnu", "us", "uska", "uske", "uski", "un", "unka", "unke",
        "ye", "yeh", "eh", "is", "iska", "iske", "iski", "in", "inka",
        "kaun", "kon", "kya", "ki", "kyu", "kyun", "kive", "kiven", "kithe", "kado", "kadon", "koi", "kuch", "kuj", "kujh", "sab", "saare", "sare",
        "ek", "ik", "ikk", "do", "har", "ikalla", "kalla", "kalli",
        "jo", "jiska", "jiske", "jehda", "jehdi", "jehde", "jido", "jadon", "jad", "je", "agar", "par", "lekin", "magar", "phir", "fir", "fer",
        "na", "nahi", "nhi", "nai", "naa", "mat", "bina", "bin", "baaj", "baajo",
        "bhi", "vi", "ve", "ni", "oe", "oye", "haan", "han", "ji", "bas", "hun", "ab", "abhi", "ajj", "aaj", "kal", "roz",
        "थोड़ा", "मेरा", "तेरा", "मैं", "तू", "हम", "वो", "ये", "क्या", "क्यों", "ना", "नहीं", "एक", "हर", "जो", "अब"
    ])

    readonly property var trailGlueWords: new Set([
        // Short trailing auxiliaries, postpositions & particles that sound natural glued to the word before them
        "is", "it", "in", "on", "up", "out", "off", "me", "you", "us", "em", "'em", "now", "too", "so", "no",
        "hai", "hain", "ho", "hoon", "hu", "tha", "the", "thi", "ga", "ge", "gi",
        "si", "siga", "sigi", "ne", "nu", "te", "to", "ton", "ch", "vich", "ich", "de", "da", "di", "ke", "ka", "ki", "ko", "se", "me", "mein", "pe", "par",
        "na", "ni", "vi", "bhi", "hi", "toh", "ta", "tan", "ja", "jaa", "le", "la", "de", "kar", "kr", "reh", "raha", "rahi", "rahe", "gaya", "gayi", "gaye",
        "है", "हैं", "हो", "था", "थी", "थे", "से", "को", "में", "पर", "के", "का", "की", "भी", "ही", "ना", "तो", "जा", "ले"
    ])

    function mixSingleAndDoubleWords(wordTokens) {
        var LEAD_GLUE_WORDS = root.leadGlueWords;
        var TRAIL_GLUE_WORDS = root.trailGlueWords;
        var mixed = [];
        var i = 0;
        while (i < wordTokens.length) {
            var curr = wordTokens[i];
            var next = (i + 1 < wordTokens.length) ? wordTokens[i + 1] : null;

            if (!next) {
                mixed.push(curr);
                break;
            }

            var cleanCurr = (curr.word || "").toLowerCase().replace(/[^a-z0-9'\u0900-\u097F]/g, "");
            var cleanNext = (next.word || "").toLowerCase().replace(/[^a-z0-9'\u0900-\u097F]/g, "");

            var hasPausePunct = /[,;\-\u2014\?\!]$|\.\.$/.test((curr.word || "").trim());
            var timeGapBetweenWords = next.startMs - curr.endMs;
            var combinedLen = cleanCurr.replace(/'/g, "").length + cleanNext.replace(/'/g, "").length;

            var isLeadGlue = LEAD_GLUE_WORDS.has(cleanCurr);
            var isTrailGlue = TRAIL_GLUE_WORDS.has(cleanNext);
            // Rhythm variety hash so even two short 4-letter non-glue words occasionally pair up (~45% of the time):
            var firstChar = (cleanCurr && cleanCurr.length > 0) ? cleanCurr.charCodeAt(0) : 0;
            var rhythmMix = (combinedLen <= 8) && (((firstChar * 37 + i * 19) % 100) < 45);

            // Pair them if there's no comma pause, no long vocal silence (>220ms) between them, and combined length fits cleanly:
            var maxAllowedChars = (isLeadGlue || isTrailGlue) ? 11 : 8;
            var shouldPair = !hasPausePunct && (timeGapBetweenWords <= 220) && (combinedLen <= maxAllowedChars) && (isLeadGlue || isTrailGlue || rhythmMix);

            if (shouldPair) {
                mixed.push({
                    word: curr.word.trim() + " " + next.word.trim(),
                    startMs: curr.startMs,
                    endMs: next.endMs,
                    vocalEndMs: next.vocalEndMs || next.endMs
                });
                i += 2;
            } else {
                mixed.push(curr);
                i += 1;
            }
        }
        return mixed;
    }

    function processLyrics() {
        var rawLines = (CairoLyricsService.lines && CairoLyricsService.lines.length > 0)
                        ? CairoLyricsService.lines
                        : (LyricsService.lines || [])
        if (!rawLines || rawLines.length === 0) {
            root.allWords = []
            root.row0Word = null
            root.row1Word = null
            root.row2Word = null
            root.clusterSize = 0
            root.currentWordIndex = -1
            root.activeBeat = null
            root.clearRequested()
            return
        }

        var wordsList = []

        for (var i = 0; i < rawLines.length; i++) {
            var cur = rawLines[i]
            var lineStartMs = (cur.time > 10000) ? Math.round(cur.time) : Math.round(cur.time * 1000)
            var nextTime = (i + 1 < rawLines.length) ? rawLines[i + 1].time : 0
            var nextLineStartMs = (nextTime > 0)
                ? ((nextTime > 10000) ? Math.round(nextTime) : Math.round(nextTime * 1000))
                : (lineStartMs + 6000)

            // A. Check for rich word-level timestamps (enhanced LRC)
            if (cur.words && cur.words.length > 0) {
                var rawWordTokens = []
                for (var w = 0; w < cur.words.length; w++) {
                    var cw = cur.words[w]
                    var wTime = cw.time
                    var wStart = (wTime > 10000) ? Math.round(wTime) : Math.round(wTime * 1000)
                    var isLastWord = (w === cur.words.length - 1)
                    var nextWTime = !isLastWord ? cur.words[w + 1].time : 0
                    var nextWStart = !isLastWord
                        ? ((nextWTime > 10000) ? Math.round(nextWTime) : Math.round(nextWTime * 1000))
                        : nextLineStartMs
                    var wDurMs = (cw.dur !== undefined && cw.dur > 0)
                        ? ((cw.dur > 100) ? Math.round(cw.dur) : Math.round(cw.dur * 1000))
                        : Math.max(120, nextWStart - wStart)
                    var vocalEnd = wStart + wDurMs

                    rawWordTokens.push({
                        word: cw.text,
                        startMs: wStart,
                        endMs: nextWStart,
                        vocalEndMs: vocalEnd
                    })
                }

                var cleanTokensA = root.sanitizeLineTokens(rawWordTokens)
                var mixedTokensA = root.sanitizeLineTokens(root.mixSingleAndDoubleWords(cleanTokensA))
                for (var ma = 0; ma < mixedTokensA.length; ma++) {
                    var mItemA = mixedTokensA[ma]
                    var vEndA = mItemA.vocalEndMs || mItemA.endMs
                    wordsList.push({
                        id: i + "_" + ma,
                        text: mItemA.word,
                        glyph: GlyphMap.lookupGlyph(mItemA.word) || (function(txt) {
                            var p = txt.trim().split(/\s+/)
                            for (var k = 0; k < p.length; k++) {
                                var g = GlyphMap.lookupGlyph(p[k])
                                if (g) return g
                            }
                            return ""
                        })(mItemA.word),
                        time: mItemA.startMs / 1000.0,
                        startMs: mItemA.startMs,
                        endMs: mItemA.endMs,
                        vocalEndMs: vEndA,
                        duration: (mItemA.endMs - mItemA.startMs) / 1000.0,
                        lineIndex: i,
                        chunkIndex: ma,
                        rowWords: [{ text: mItemA.word, startMs: mItemA.startMs, endMs: vEndA }]
                    })
                }
            } else {
                // B. Pure 1-to-2 Word Architecture (Standard .lrc Lines)
                var singleWords = root.tokenizeLineToSingleWords(cur.text, lineStartMs, nextLineStartMs)
                if (singleWords.length === 0) continue

                var mixedTokensB = root.sanitizeLineTokens(root.mixSingleAndDoubleWords(singleWords))
                for (var mb = 0; mb < mixedTokensB.length; mb++) {
                    var mItemB = mixedTokensB[mb]
                    var vEndB = mItemB.vocalEndMs || mItemB.endMs
                    wordsList.push({
                        id: i + "_" + mb,
                        text: mItemB.word,
                        glyph: GlyphMap.lookupGlyph(mItemB.word) || (function(txt) {
                            var p = txt.trim().split(/\s+/)
                            for (var k = 0; k < p.length; k++) {
                                var g = GlyphMap.lookupGlyph(p[k])
                                if (g) return g
                            }
                            return ""
                        })(mItemB.word),
                        time: mItemB.startMs / 1000.0,
                        startMs: mItemB.startMs,
                        endMs: mItemB.endMs,
                        vocalEndMs: vEndB,
                        duration: (mItemB.endMs - mItemB.startMs) / 1000.0,
                        lineIndex: i,
                        chunkIndex: mb,
                        rowWords: [{ text: mItemB.word, startMs: mItemB.startMs, endMs: vEndB }]
                    })
                }
            }
        }

        root.allWords = wordsList.sort(function(a, b) { return a.startMs - b.startMs })

        // Mandatory Rhythm Fallback (Every 2nd/3rd row MUST display a glyph):
        var ROTATING_FALLBACKS = [
            "JAAN_SPARKLE", "NOOR_COMET", "NASHA_PORTAL", "ISHQ_HEART"
        ]
        var fallbackIdx = 0
        var wordsSinceLastGlyph = 0

        for (var b = 0; b < root.allWords.length; b++) {
            var item = root.allWords[b]
            var hasG = item.glyph && ((typeof item.glyph === "object" && item.glyph.corePath) || (typeof item.glyph === "string" && item.glyph.length > 0))
            if (hasG) {
                wordsSinceLastGlyph = 0
            } else {
                wordsSinceLastGlyph++
                if (wordsSinceLastGlyph >= 2) {
                    var fMotif = ROTATING_FALLBACKS[fallbackIdx % ROTATING_FALLBACKS.length]
                    fallbackIdx++
                    item.glyph = GlyphMap.getGlyphObject(fMotif) || fMotif
                    wordsSinceLastGlyph = 0
                }
            }
        }

        root.updateSync()
    }

    Connections {
        target: CairoLyricsService
        function onLinesChanged() {
            root.processLyrics()
        }
    }

    Connections {
        target: LyricsService
        function onLinesChanged() {
            if (!CairoLyricsService.lines || CairoLyricsService.lines.length === 0) {
                root.processLyrics()
            }
        }
        function onTrackTitleChanged() {
            root.syncBaseTimeFromMpris()
            root.processLyrics()
        }
    }

    // ── 3. Update Sync & Beat Triggering ───────────────────────────────────
    function updateSync() {
        if (!root.allWords || root.allWords.length === 0) {
            root.row0Word = null
            root.row1Word = null
            root.row2Word = null
            root.clusterSize = 0
            root.currentTokenIndex = -1
            root.currentWordIndex = -1
            root.activeBeat = null
            root.clearRequested()
            return
        }

        var livePosMs = root.livePositionMs
        var effectivePos = root.effectivePositionMs

        if (effectivePos < root.allWords[0].startMs) {
            // Before the song's first lyric: hold calmly, never wipe the stage
            return
        }

        var targetIndex = -1
        for (var i = 0; i < root.allWords.length; i++) {
            if (root.allWords[i].startMs <= effectivePos) {
                targetIndex = i
            } else {
                break
            }
        }

        if (targetIndex < 0) {
            return
        }

        if (targetIndex !== root.currentTokenIndex) {
            var nextStep = targetIndex

            root.lastTokenStepTimeMs = Date.now()
            root.currentTokenIndex = nextStep
            root.currentWordIndex = nextStep

            var newWord = root.allWords[nextStep]
            root.activeBeat = newWord

            var isNewPhrase = false
            if (nextStep === 0) {
                isNewPhrase = true
            } else if (root.row2Word) {
                var gap = newWord.startMs - root.row2Word.endMs
                if (gap > 2000 || (newWord.lineIndex !== root.row2Word.lineIndex && gap > 1200)) {
                    isNewPhrase = true
                }
            }

            if (isNewPhrase || root.clusterSize === 0) {
                root.row0Word = null
                root.row1Word = null
                root.row2Word = newWord
                root.clusterSize = 1
            } else if (root.clusterSize === 1) {
                root.row0Word = null
                root.row1Word = root.row2Word
                root.row2Word = newWord
                root.clusterSize = 2
            } else {
                root.row0Word = root.row1Word
                root.row1Word = root.row2Word
                root.row2Word = newWord
                root.clusterSize = 3
            }

            root.beatTriggered(newWord)
        }
    }

    Component.onCompleted: {
        root.resetPlaybackClock()
        root.processLyrics()
    }
}
