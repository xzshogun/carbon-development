pragma Singleton

import QtQuick
import Quickshell

/**
 * GreetingEngine.qml
 *
 * Lightweight, zero-overhead native QML service for ambient vibes & greetings.
 * Features:
 *   - Dynamic resolution of {user} and {day}
 *   - 140+ curated time-aware lines (3 to 6 words max, cozy, night-owl, arch-friendly)
 *   - Procedural slot-mixer for dynamic procedural variety
 *   - Non-repeating 25-entry history ring buffer
 *   - Auto-shuffle every 15 minutes + click-to-shuffle
 */
Singleton {
    id: root

    readonly property string userName: Quickshell.env("USER") || "user"
    readonly property var weekdays: [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ]
    readonly property string dayName: root.weekdays[(new Date()).getDay()]

    property string currentLine: ""
    property var recentHistory: []

    // --- Curated static lines pool (145 lines) ---
    readonly property var morningPool: [
        "a latte won't hurt, {user}.",
        "coffee first, {user}.",
        "slow morning, sharp mind.",
        "warm cup, clean slate.",
        "fresh start, {user}.",
        "morning glow, {user}.",
        "caffeine loading, {user}...",
        "sun's up, lock in.",
        "brew something good, {user}.",
        "quiet morning, zero rush.",
        "first commit of the day?",
        "stretch out, start slow.",
        "crisp air & clean configs.",
        "espresso and focus, {user}.",
        "new day, clean terminal.",
        "steam rising, thoughts clear.",
        "sunrise code hits clean.",
        "gentle start, big momentum.",
        "ready when you are, {user}.",
        "golden hour of morning.",
        "fresh mind, clean workspace.",
        "breathe in, start fresh.",
        "mugs up, terminals open.",
        "morning peace in {day}.",
        "today's canvas is clean.",
        "first light, good mood.",
        "smooth morning vibes, {user}.",
        "fuel up and conquer.",
        "soft sunshine, warm brew.",
        "rise and design, {user}."
    ]

    readonly property var afternoonPool: [
        "locked in, {user}.",
        "iced coffee o'clock, {user}.",
        "steady pace, {user}.",
        "ride the momentum.",
        "stay hydrated, {user}.",
        "afternoon flow, {user}.",
        "deep work hours.",
        "one tab at a time, {user}.",
        "cruising through {day}.",
        "quick stretch, {user}?",
        "keep the rhythm going.",
        "post-lunch focus mode.",
        "water check, {user}.",
        "smooth execution, {user}.",
        "in the zone now.",
        "making progress look easy.",
        "steady hands, clean logic.",
        "tempo is just right.",
        "focused and untangled, {user}.",
        "afternoon sun, cool focus.",
        "building block by block.",
        "code flowing smoothly today.",
        "breeze outside, focus inside.",
        "halfway through, looking sharp.",
        "dialed in on {day}.",
        "keep pushing the needle.",
        "clean commits all afternoon.",
        "steady pulse, clear vision.",
        "flow state activated, {user}.",
        "pure momentum right now."
    ]

    readonly property var eveningPool: [
        "golden hour, {user}.",
        "cozy mode on, {user}.",
        "tea and good tracks.",
        "evening flow, {user}.",
        "dim lights, good vibes.",
        "smooth sailing, {user}.",
        "sunset in the terminal.",
        "wind down or lock in?",
        "lo-fi evening, {user}.",
        "warm lights, quiet room.",
        "switch to dark mode vibes.",
        "take a breather, {user}.",
        "evening serenity in session.",
        "ambient tunes and code.",
        "sky turning purple outside.",
        "good progress today, {user}.",
        "wrapping up with grace.",
        "soft lamps, warm ambiance.",
        "dusk settled, thoughts aligned.",
        "evening chill hits nice.",
        "the day's best rhythm.",
        "gentle wind down mode.",
        "reflections and clean diffs.",
        "sunset gradient on point.",
        "unwind your mind, {user}.",
        "peaceful evening ahead, {user}.",
        "candlelight or screen glow?",
        "relax into the evening.",
        "smooth transitions tonight, {user}.",
        "cozy room, warm vibes."
    ]

    readonly property var lateNightPool: [
        "peak hours, {user}.",
        "quiet world, warm screen.",
        "2am hits different, {user}.",
        "lo-fi and late code.",
        "night shift, {user}.",
        "best work happens late.",
        "just you and the glow.",
        "hoodie and headphones weather.",
        "rest when you're ready, {user}.",
        "world's asleep, {user}.",
        "late night, quiet mind.",
        "3am flow state.",
        "midnight oil burning clean.",
        "zero pings, pure peace.",
        "night owl territory, {user}.",
        "dark room, bright ideas.",
        "after-hours magic, {user}.",
        "stars awake, screen glowing.",
        "silent city, deep thoughts.",
        "untouchable midnight rhythm, {user}.",
        "shadows dance, code compiles.",
        "pure nocturnal momentum, {user}.",
        "whispering keys in darkness.",
        "the clock stopped caring.",
        "midnight minimalism at work.",
        "dreaming in syntax tonight.",
        "no alarms, just flow.",
        "gentle quiet, deep focus.",
        "soft instrumental night, {user}.",
        "night breeze and warmth.",
        "sleeping world, working magic.",
        "neon shadows, tranquil thoughts.",
        "another late masterpiece, {user}?",
        "hush now, you're flowing.",
        "midnight clarity hits different."
    ]

    readonly property var easterEggPool: [
        "help I forgot to install kitty",
        "configs looking clean, {user}.",
        "zero warnings, zero stress.",
        "arch btw, {user}.",
        "rice looking sharp today.",
        "60fps state of mind.",
        "dotfiles in harmony.",
        "hyprland smooth today, {user}.",
        "compiling memories, {user}.",
        "neovim buffers in sync.",
        "clean git diff, clean mind.",
        "ricing never truly ends.",
        "wayland buttery smooth today.",
        "alacritty or kitty today?",
        "all tests passing, {user}.",
        "zero lag, infinite aesthetic.",
        "unix philosophy in practice.",
        "custom shaders looking crisp.",
        "pacman -Syu completed clean.",
        "minimalism is the peak."
    ]

    // --- Procedural Slot-Mixer: Prefixes by time category ---
    readonly property var morningPrefixes: [
        "quiet morning,", "warm coffee,", "fresh start,", "morning light,", "early dawn,"
    ]
    readonly property var afternoonPrefixes: [
        "steady pace,", "afternoon breeze,", "smooth {day},", "deep focus,", "midday glow,"
    ]
    readonly property var eveningPrefixes: [
        "golden dusk,", "dim lights,", "evening calm,", "lo-fi tunes,", "sunset glow,"
    ]
    readonly property var lateNightPrefixes: [
        "quiet night,", "midnight hours,", "silent world,", "late glow,", "3am silence,"
    ]

    // --- Procedural Slot-Mixer: Universal cozy closers ---
    readonly property var slotClosers: [
        "sharp mind, {user}.",
        "zero noise.",
        "good vibes only.",
        "keep flowing, {user}.",
        "peace of mind.",
        "pure momentum.",
        "stay cozy, {user}.",
        "clean thoughts.",
        "just lock in.",
        "unmatched rhythm.",
        "stay inspired, {user}."
    ]

    function getTimeCategory() {
        var h = (new Date()).getHours();
        if (h >= 5 && h < 12) return "morning";
        if (h >= 12 && h < 17) return "afternoon";
        if (h >= 17 && h < 22) return "evening";
        return "latenight";
    }

    function resolvePlaceholders(str) {
        if (!str) return "";
        var u = root.userName;
        var d = root.dayName;
        return str.replace(/\{user\}/g, u).replace(/\{day\}/g, d);
    }

    function generateCandidate() {
        var cat = getTimeCategory();
        var roll = Math.random();

        // 1. Procedural slot-mixer (~20% chance)
        if (roll < 0.20) {
            var prefixes = root.eveningPrefixes;
            if (cat === "morning") prefixes = root.morningPrefixes;
            else if (cat === "afternoon") prefixes = root.afternoonPrefixes;
            else if (cat === "latenight") prefixes = root.lateNightPrefixes;

            var p = prefixes[Math.floor(Math.random() * prefixes.length)];
            var c = root.slotClosers[Math.floor(Math.random() * root.slotClosers.length)];
            return resolvePlaceholders(p + " " + c);
        }

        // 2. Easter egg / Arch / Rice pool (~15% chance)
        if (roll < 0.35) {
            var egg = root.easterEggPool[Math.floor(Math.random() * root.easterEggPool.length)];
            return resolvePlaceholders(egg);
        }

        // 3. Time-matched curated pool (~65% chance)
        var pool = root.eveningPool;
        if (cat === "morning") pool = root.morningPool;
        else if (cat === "afternoon") pool = root.afternoonPool;
        else if (cat === "latenight") pool = root.lateNightPool;

        var line = pool[Math.floor(Math.random() * pool.length)];
        return resolvePlaceholders(line);
    }

    function shuffle() {
        var candidate = "";
        for (var i = 0; i < 12; ++i) {
            candidate = generateCandidate();
            if (candidate !== root.currentLine && root.recentHistory.indexOf(candidate) === -1) {
                break;
            }
        }
        if (!candidate) {
            candidate = generateCandidate();
        }

        var hist = root.recentHistory.slice();
        hist.push(candidate);
        if (hist.length > 25) {
            hist.shift();
        }
        root.recentHistory = hist;
        root.currentLine = candidate;
        return candidate;
    }

    // Auto-rotate every 15 minutes (900,000 ms)
    Timer {
        interval: 900000
        running: true
        repeat: true
        onTriggered: root.shuffle()
    }

    Component.onCompleted: {
        root.shuffle();
    }
}
