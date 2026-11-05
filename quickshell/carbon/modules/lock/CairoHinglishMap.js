// CairoHinglishMap.js: 16 Custom 3-Layer Kinetic Vector Assemblies & Multilingual Normalizer for Carbon // Cairo
// Strictly 0% Unicode Emojis. Native 24x24 EvenOdd SVG Paths.

.pragma library

function _createKineticGlyph(motifName, animType, haloPath, corePath, satPath) {
    var obj = {
        motif: motifName,
        animType: animType,
        haloPath: haloPath,
        corePath: corePath,
        satPath: satPath,
        length: motifName.length,
        toString: function() { return this.motif; },
        valueOf: function() { return this.motif; }
    };
    return obj;
}

var KINETIC_GLYPHS = {
    // 1. ISHQ_HEART — 3D Ribbon Heart + Heartbeat Thump + Orbiting Concave Star
    ISHQ_HEART: _createKineticGlyph(
        "ISHQ_HEART",
        "pulse",
        "M12 22.4 C12 22.4 1.5 15.6 1.5 8.5 C1.5 4.6 4.5 1.8 8.2 1.8 C10.2 1.8 11.4 2.8 12 3.9 C12.6 2.8 13.8 1.8 15.8 1.8 C19.5 1.8 22.5 4.6 22.5 8.5 C22.5 15.6 12 22.4 12 22.4 Z",
        "M12 20.8 C12 20.8 3.2 14.8 3.2 8.8 C3.2 5.5 5.6 3.2 8.5 3.2 C10.3 3.2 11.4 4.1 12 5.1 C12.6 4.1 13.7 3.2 15.5 3.2 C18.4 3.2 20.8 5.5 20.8 8.8 C20.8 14.8 12 20.8 12 20.8 Z M13.2 7.4 L9.4 12.4 L12.2 12.4 L10.8 16.5 L14.6 11.5 L11.8 11.5 Z",
        "M19.5 1.0 Q19.5 4.0 22.5 4.0 Q19.5 4.0 19.5 7.0 Q19.5 4.0 16.5 4.0 Q19.5 4.0 19.5 1.0 Z"
    ),

    // 2. AAG_FIRE — Dual-Wave Streetwear Flame + Rising Ember Sparks
    AAG_FIRE: _createKineticGlyph(
        "AAG_FIRE",
        "sway",
        "M11.5 0.8 C15.8 4.5 21.2 8.8 21.2 14.8 C21.2 19.8 17.0 23.2 12.0 23.2 C7.0 23.2 2.8 19.8 2.8 14.8 C2.8 10.5 5.5 7.0 7.5 5.2 C6.8 8.2 8.0 10.2 9.5 10.8 C8.2 6.8 9.5 3.2 11.5 0.8 Z",
        "M12.8 2.0 C15.2 5.2 19.2 8.5 19.2 14.2 C19.2 18.6 15.8 22.0 11.8 22.0 C7.6 22.0 4.8 18.8 4.8 14.5 C4.8 11.4 6.5 8.6 8.0 7.2 C7.5 9.4 8.4 11.0 9.8 11.5 C9.0 7.8 10.6 4.2 12.8 2.0 Z M12.0 13.5 C10.4 15.0 9.5 16.6 10.0 18.4 C10.4 19.6 11.6 20.2 13.0 19.8 C14.4 19.2 15.0 17.5 14.0 15.6 C13.5 14.6 12.8 14.0 12.0 13.5 Z",
        "M18.5 2.2 L20.0 4.2 L18.5 6.2 L17.0 4.2 Z M6.0 3.5 L7.2 5.0 L6.0 6.5 L4.8 5.0 Z"
    ),

    // 3. RAAT_MOON — Razor Crescent + Translucent Eclipse Disc + Orbiting Twinkle Star
    RAAT_MOON: _createKineticGlyph(
        "RAAT_MOON",
        "orbit",
        "M12.0 2.2 A9.8 9.8 0 1 0 12.0 21.8 A9.8 9.8 0 1 0 12.0 2.2 Z",
        "M15.0 2.2 C9.4 2.8 5.2 7.5 5.2 13.2 C5.2 17.2 7.4 20.8 10.8 22.4 C5.5 21.9 1.6 17.5 1.6 12.2 C1.6 6.4 6.4 1.8 12.2 1.8 C13.2 1.8 14.2 1.9 15.0 2.2 Z",
        "M18.0 4.2 Q18.0 8.8 22.6 8.8 Q18.0 8.8 18.0 13.4 Q18.0 8.8 13.4 8.8 Q18.0 8.8 18.0 4.2 Z"
    ),

    // 4. NAINA_EYE — Curved Almond Lashes + Left/Right Scanning Iris & Glint
    NAINA_EYE: _createKineticGlyph(
        "NAINA_EYE",
        "scan",
        "M0.8 12.0 C4.2 5.0 8.0 2.8 12.0 2.8 C16.0 2.8 19.8 5.0 23.2 12.0 C19.8 19.0 16.0 21.2 12.0 21.2 C8.0 21.2 4.2 19.0 0.8 12.0 Z",
        "M1.5 12.0 C4.8 6.2 8.3 4.2 12.0 4.2 C15.7 4.2 19.2 6.2 22.5 12.0 C19.2 17.8 15.7 19.8 12.0 19.8 C8.3 19.8 4.8 17.8 1.5 12.0 Z M12.0 6.8 A5.2 5.2 0 1 0 12.0 17.2 A5.2 5.2 0 1 0 12.0 6.8 Z",
        "M12.0 8.8 A3.2 3.2 0 1 0 12.0 15.2 A3.2 3.2 0 1 0 12.0 8.8 Z M13.5 9.2 A1.2 1.2 0 1 0 13.5 11.6 A1.2 1.2 0 1 0 13.5 9.2 Z"
    ),

    // 5. DHUN_VINYL — Spinning Grooved Vinyl Disc + Floating Beam Note
    DHUN_VINYL: _createKineticGlyph(
        "DHUN_VINYL",
        "float",
        "M12.0 1.8 A10.2 10.2 0 1 0 12.0 22.2 A10.2 10.2 0 1 0 12.0 1.8 Z M12.0 5.0 A7.0 7.0 0 1 0 12.0 19.0 A7.0 7.0 0 1 0 12.0 5.0 Z",
        "M9.2 17.8 A3.1 3.1 0 1 1 6.1 14.7 C6.8 14.7 7.4 14.9 7.8 15.2 L7.8 5.5 L20.0 3.0 L20.0 15.5 A3.1 3.1 0 1 1 16.9 12.4 C17.6 12.4 18.2 12.6 18.6 12.9 L18.6 7.0 L9.2 8.8 Z",
        "M4.0 4.5 Q4.0 7.2 6.7 7.2 Q4.0 7.2 4.0 9.9 Q4.0 7.2 1.3 7.2 Q4.0 7.2 4.0 4.5 Z"
    ),

    // 6. JAAN_SPARKLE — 3-Piece Celestial Astro-Cluster
    JAAN_SPARKLE: _createKineticGlyph(
        "JAAN_SPARKLE",
        "orbit",
        "M10.5 3.5 A7.0 7.0 0 1 0 10.5 17.5 A7.0 7.0 0 1 0 10.5 3.5 Z",
        "M10.0 1.0 Q10.0 10.0 19.0 10.0 Q10.0 10.0 10.0 19.0 Q10.0 10.0 1.0 10.0 Q10.0 10.0 10.0 1.0 Z M10.0 7.8 A2.2 2.2 0 1 0 10.0 12.2 A2.2 2.2 0 1 0 10.0 7.8 Z",
        "M18.5 13.0 Q18.5 18.0 23.5 18.0 Q18.5 18.0 18.5 23.0 Q18.5 18.0 13.5 18.0 Q18.5 18.0 18.5 13.0 Z M4.5 17.5 Q4.5 20.2 7.2 20.2 Q4.5 20.2 4.5 22.9 Q4.5 20.2 1.8 20.2 Q4.5 20.2 4.5 17.5 Z"
    ),

    // 7. BAARISH_DROP — Sculpted Glossy Raindrop + Expanding Water Ripple Ring
    BAARISH_DROP: _createKineticGlyph(
        "BAARISH_DROP",
        "float",
        "M12.0 17.5 C17.5 17.5 22.0 19.0 22.0 20.8 C22.0 22.6 17.5 24.0 12.0 24.0 C6.5 24.0 2.0 22.6 2.0 20.8 C2.0 19.0 6.5 17.5 12.0 17.5 Z M12.0 19.0 C8.2 19.0 5.2 19.8 5.2 20.8 C5.2 21.8 8.2 22.6 12.0 22.6 C15.8 22.6 18.8 21.8 18.8 20.8 C18.8 19.8 15.8 19.0 12.0 19.0 Z",
        "M12.0 1.5 C12.0 1.5 18.8 9.2 18.8 14.2 C18.8 18.0 15.8 21.0 12.0 21.0 C8.2 21.0 5.2 18.0 5.2 14.2 C5.2 9.2 12.0 1.5 12.0 1.5 Z",
        "M9.2 11.2 C8.2 13.0 8.5 15.5 10.2 16.8 C10.8 17.3 11.6 16.8 11.2 16.0 C10.0 14.8 9.8 13.2 10.6 11.8 C11.0 11.0 9.8 10.4 9.2 11.2 Z M19.2 3.5 A1.5 1.5 0 1 0 19.2 6.5 A1.5 1.5 0 1 0 19.2 3.5 Z"
    ),

    // 8. GADDI_TURBO — Widebody Aero Coupe + Streaking Slipstream Lines
    GADDI_TURBO: _createKineticGlyph(
        "GADDI_TURBO",
        "scan",
        "M1.0 3.2 L11.0 3.2 L10.2 4.8 L0.2 4.8 Z M13.5 1.8 L22.5 1.8 L21.8 3.4 L12.8 3.4 Z",
        "M1.5 14.5 L4.8 7.2 C5.5 5.8 6.8 5.0 8.4 5.0 L15.6 5.0 C17.2 5.0 18.5 5.8 19.2 7.2 L22.5 14.5 L23.4 15.8 L22.8 20.2 L19.4 20.2 L19.4 18.2 L4.6 18.2 L4.6 20.2 L1.2 20.2 L0.6 15.8 Z M6.8 7.0 L5.0 11.2 L19.0 11.2 L17.2 7.0 Z",
        "M3.0 13.4 L8.4 14.8 L7.9 16.4 L2.5 15.0 Z M21.0 13.4 L15.6 14.8 L16.1 16.4 L21.5 15.0 Z"
    ),

    // 9. TAJ_CROWN — Curved Royal Crown + Levitating Center Diamond & Pearls
    TAJ_CROWN: _createKineticGlyph(
        "TAJ_CROWN",
        "float",
        "M3.5 20.5 L20.5 20.5 C21.2 20.5 21.8 21.1 21.8 21.8 C21.8 22.5 21.2 23.0 20.5 23.0 L3.5 23.0 C2.8 23.0 2.2 22.5 2.2 21.8 C2.2 21.1 2.8 20.5 3.5 20.5 Z",
        "M2.5 18.2 L4.2 7.8 Q8.0 13.2 12.0 4.8 Q16.0 13.2 19.8 7.8 L21.5 18.2 C21.5 19.2 20.6 20.0 19.5 20.0 L4.5 20.0 C3.4 20.0 2.5 19.2 2.5 18.2 Z M12.0 11.5 L14.2 14.2 L12.0 16.8 L9.8 14.2 Z",
        "M4.0 3.8 A1.5 1.5 0 1 0 4.0 6.8 A1.5 1.5 0 1 0 4.0 3.8 Z M12.0 0.8 L13.8 2.8 L12.0 4.8 L10.2 2.8 Z M20.0 3.8 A1.5 1.5 0 1 0 20.0 6.8 A1.5 1.5 0 1 0 20.0 3.8 Z"
    ),

    // 10. JAAM_ELIXIR — Tilted Crystal Coupe + Rising Champagne Fizz Bubbles
    JAAM_ELIXIR: _createKineticGlyph(
        "JAAM_ELIXIR",
        "float",
        "M6.0 1.5 A9.0 9.0 0 0 1 21.0 8.5 L12.0 12.0 Z",
        "M2.2 4.2 L21.8 4.2 L13.2 14.0 L13.2 19.8 L18.0 19.8 L17.4 22.0 L6.6 22.0 L6.0 19.8 L10.8 19.8 L10.8 14.0 Z M5.6 6.4 L9.8 11.2 L18.4 6.4 Z",
        "M10.5 1.2 A1.3 1.3 0 1 0 10.5 3.8 A1.3 1.3 0 1 0 10.5 1.2 Z M14.5 2.0 A1.0 1.0 0 1 0 14.5 4.0 A1.0 1.0 0 1 0 14.5 2.0 Z M12.5 7.5 A1.1 1.1 0 1 0 12.5 9.7 A1.1 1.1 0 1 0 12.5 7.5 Z"
    ),

    // 11. NASHA_PORTAL — Counter-Rotating Sacred Star Rings + Levitating Core
    NASHA_PORTAL: _createKineticGlyph(
        "NASHA_PORTAL",
        "spin",
        "M12 0.8 L15.2 8.8 L23.2 12.0 L15.2 15.2 L12 23.2 L8.8 15.2 L0.8 12.0 L8.8 8.8 Z",
        "M12 2.5 L21.5 12.0 L12 21.5 L2.5 12.0 Z M12 5.8 L5.8 12.0 L12 18.2 L18.2 12.0 Z",
        "M12 8.8 L15.2 12.0 L12 15.2 L8.8 12.0 Z"
    ),

    // 12. ASLA_RETICLE — Rotating Radar Ring + Recoil-Locking Tactical Crosshair
    ASLA_RETICLE: _createKineticGlyph(
        "ASLA_RETICLE",
        "pulse",
        "M12 2.2 A9.8 9.8 0 1 0 12 21.8 A9.8 9.8 0 1 0 12 2.2 Z M12 4.2 A7.8 7.8 0 1 0 12 19.8 A7.8 7.8 0 1 0 12 4.2 Z",
        "M11.0 0.8 L13.0 0.8 L13.0 6.2 L11.0 6.2 Z M11.0 17.8 L13.0 17.8 L13.0 23.2 L11.0 23.2 Z M0.8 11.0 L6.2 11.0 L6.2 13.0 L0.8 13.0 Z M17.8 11.0 L23.2 11.0 L23.2 13.0 L17.8 13.0 Z",
        "M12 9.2 L14.8 12.0 L12 14.8 L9.2 12.0 Z"
    ),

    // 13. SHER_CREST — Cyber-Wolf/Lion Crest + Flaring Eyes & Floating Brow Shard
    SHER_CREST: _createKineticGlyph(
        "SHER_CREST",
        "pulse",
        "M1.5 2.0 L12.0 7.5 L22.5 2.0 L20.5 16.5 L12.0 23.5 L3.5 16.5 Z",
        "M2.8 3.2 L8.5 8.5 L12.0 5.2 L15.5 8.5 L21.2 3.2 L19.5 15.5 L12.0 22.5 L4.5 15.5 Z M9.8 17.2 L12.0 20.0 L14.2 17.2 Z",
        "M6.2 10.8 L10.5 13.0 L8.0 15.0 Z M17.8 10.8 L13.5 13.0 L16.0 15.0 Z M12.0 0.8 L13.6 3.2 L12.0 4.8 L10.4 3.2 Z"
    ),

    // 14. WAQT_CHRONO — Curved Hourglass + Dripping Sand Stream
    WAQT_CHRONO: _createKineticGlyph(
        "WAQT_CHRONO",
        "float",
        "M12 2.0 A10.0 10.0 0 1 0 12 22.0 A10.0 10.0 0 1 0 12 2.0 Z M12 3.5 A8.5 8.5 0 1 0 12 20.5 A8.5 8.5 0 1 0 12 3.5 Z",
        "M4.2 2.0 L19.8 2.0 L19.8 4.2 L14.0 12.0 L19.8 19.8 L19.8 22.0 L4.2 22.0 L4.2 19.8 L10.0 12.0 L4.2 4.2 Z M7.2 4.4 L16.8 4.4 L12.0 10.6 Z",
        "M12.0 12.8 L13.2 15.2 L10.8 15.2 Z M7.5 19.5 L16.5 19.5 L12.0 16.0 Z"
    ),

    // 15. BASS_WAVE — Harmonic Pumping Pill Spectrum Bars
    BASS_WAVE: _createKineticGlyph(
        "BASS_WAVE",
        "pulse",
        "M1.5 10.5 L22.5 10.5 L22.5 13.5 L1.5 13.5 Z",
        "M7.5 4.8 C8.3 4.8 9.0 5.5 9.0 6.3 L9.0 17.7 C9.0 18.5 8.3 19.2 7.5 19.2 C6.7 19.2 6.0 18.5 6.0 17.7 L6.0 6.3 C6.0 5.5 6.7 4.8 7.5 4.8 Z M16.5 4.8 C17.3 4.8 18.0 5.5 18.0 6.3 L18.0 17.7 C18.0 18.5 17.3 19.2 16.5 19.2 C15.7 19.2 15.0 18.5 15.0 17.7 L15.0 6.3 C15.0 5.5 15.7 4.8 16.5 4.8 Z",
        "M3.0 8.5 C3.8 8.5 4.5 9.2 4.5 10.0 L4.5 14.0 C4.5 14.8 3.8 15.5 3.0 15.5 C2.2 15.5 1.5 14.8 1.5 14.0 L1.5 10.0 C1.5 9.2 2.2 8.5 3.0 8.5 Z M12.0 1.5 C12.8 1.5 13.5 2.2 13.5 3.0 L13.5 21.0 C13.5 21.8 12.8 22.5 12.0 22.5 C11.2 22.5 10.5 21.8 10.5 21.0 L10.5 3.0 C10.5 2.2 11.2 1.5 12.0 1.5 Z M21.0 8.5 C21.8 8.5 22.5 9.2 22.5 10.0 L22.5 14.0 C22.5 14.8 21.8 15.5 21.0 15.5 C20.2 15.5 19.5 14.8 19.5 14.0 L19.5 10.0 C19.5 9.2 20.2 8.5 21.0 8.5 Z"
    ),

    // 16. NOOR_COMET — Streaking Shooting Star + 3 Tapered Contrails
    NOOR_COMET: _createKineticGlyph(
        "NOOR_COMET",
        "orbit",
        "M12.5 10.5 L2.2 20.8 L1.0 19.5 L11.2 9.2 Z M15.0 14.2 L6.8 22.4 L5.5 21.0 L13.8 12.8 Z M9.2 7.2 L1.0 15.4 L2.2 16.8 L10.5 8.5 Z",
        "M17.5 1.5 Q17.5 7.5 23.5 7.5 Q17.5 7.5 17.5 13.5 Q17.5 7.5 11.5 7.5 Q17.5 7.5 17.5 1.5 Z",
        "M17.5 5.2 A2.3 2.3 0 1 0 17.5 9.8 A2.3 2.3 0 1 0 17.5 5.2 Z M5.5 3.5 A1.4 1.4 0 1 0 5.5 6.3 A1.4 1.4 0 1 0 5.5 3.5 Z"
    )
};

// Comprehensive Backward-Compatible Map (Supporting both UPPERCASE and lowercase keys)
var GLYPH_OBJECTS = {};
for (var key in KINETIC_GLYPHS) {
    GLYPH_OBJECTS[key] = KINETIC_GLYPHS[key];
    GLYPH_OBJECTS[key.toLowerCase()] = KINETIC_GLYPHS[key];
}

// Map legacy / rhythm fallback motifs seamlessly into the 16 kinetic assemblies
GLYPH_OBJECTS["dhun_play"] = KINETIC_GLYPHS.DHUN_VINYL;
GLYPH_OBJECTS["dhun_music"] = KINETIC_GLYPHS.DHUN_VINYL;
GLYPH_OBJECTS["gaddi_car"] = KINETIC_GLYPHS.GADDI_TURBO;
GLYPH_OBJECTS["jaam_chalice"] = KINETIC_GLYPHS.JAAM_ELIXIR;
GLYPH_OBJECTS["nasha_vortex"] = KINETIC_GLYPHS.NASHA_PORTAL;
GLYPH_OBJECTS["bijli_bolt"] = KINETIC_GLYPHS.ASLA_RETICLE;
GLYPH_OBJECTS["sona_diamond"] = KINETIC_GLYPHS.NOOR_COMET;
GLYPH_OBJECTS["waqt_time"] = KINETIC_GLYPHS.WAQT_CHRONO;
GLYPH_OBJECTS["dard_broken"] = KINETIC_GLYPHS.ISHQ_HEART;
GLYPH_OBJECTS["tanha_solo"] = KINETIC_GLYPHS.RAAT_MOON;
GLYPH_OBJECTS["khwab_cloud"] = KINETIC_GLYPHS.NOOR_COMET;
GLYPH_OBJECTS["kismat_dice"] = KINETIC_GLYPHS.ASLA_RETICLE;
GLYPH_OBJECTS["rhythm_accent"] = KINETIC_GLYPHS.JAAN_SPARKLE;

for (var alias in GLYPH_OBJECTS) {
    KINETIC_GLYPHS[alias] = GLYPH_OBJECTS[alias];
}

// Flat path map for single-string backwards compatibility
var GLYPH_PATHS = {};
for (var pKey in GLYPH_OBJECTS) {
    GLYPH_PATHS[pKey] = GLYPH_OBJECTS[pKey].corePath;
}

function getGlyphObject(motif) {
    if (!motif) return null;
    var mUpper = String(motif).toUpperCase();
    var mLower = String(motif).toLowerCase();
    if (KINETIC_GLYPHS[motif]) return KINETIC_GLYPHS[motif];
    if (KINETIC_GLYPHS[mUpper]) return KINETIC_GLYPHS[mUpper];
    if (KINETIC_GLYPHS[mLower]) return KINETIC_GLYPHS[mLower];
    if (GLYPH_OBJECTS[motif]) return GLYPH_OBJECTS[motif];
    if (GLYPH_OBJECTS[mUpper]) return GLYPH_OBJECTS[mUpper];
    if (GLYPH_OBJECTS[mLower]) return GLYPH_OBJECTS[mLower];
    return null;
}

var RAW_BUCKETS = {
    // 1. ISHQ_HEART
    "ISHQ_HEART": [
        "love", "loving", "lover", "heart", "hearts", "heartbeat",
        "dil", "dila", "dilda", "pyar", "pyaar", "ishq", "ishqe", "mohabbat",
        "chahat", "dhadkan", "dilbar", "diljaniya", "premi", "aashiq", "ashiq", "dilbaro",
        "broken", "break", "hurt", "pain", "bleed", "bleeding", "scar", "scars", "shame", "lie", "lies", "fake",
        "dard", "zakham", "tuta", "toota", "bewafa", "dhoka", "judai",
        "lagdi", "lagge", "lagda", "jachdi", "jachda", "pasand", "tere", "tenu", "tainu",
        "दिल", "प्यार", "इश्क़", "मोहब्बत", "धड़कन", "चाहत", "दर्द", "ज़ख़्म", "जुदाई", "टूटा", "बेवफ़ा",
        "ਲੱਗਦੀ", "ਜਚਦੀ", "ਪਸੰਦ", "ਤੈਨੂੰ", "ਲੱਗਦਾ", "ਜਚਦਾ"
    ],

    // 2. AAG_FIRE
    "AAG_FIRE": [
        "fire", "burn", "burning", "flame", "flames", "smoke", "heat", "hot", "lit", "ashes", "spark", "sparks",
        "aag", "ag", "jal", "jalna", "jale", "dhuan", "dhua", "shola", "angaare", "garmi", "bhula",
        "आग", "धुआँ", "शोला", "गर्मी", "अंगारे"
    ],

    // 3. RAAT_MOON
    "RAAT_MOON": [
        "night", "nights", "tonight", "midnight", "moon", "moonlight", "dark", "darkest", "darkness", "shadow", "shadows",
        "alone", "lonely", "stranger", "tanha", "akela", "akele", "khud", "ajnabi",
        "raat", "rat", "raataan", "ratan", "raatein", "chand", "chaand", "chandni", "andhera",
        "shaam", "sham", "savera",
        "रात", "चाँद", "चाँदनी", "अंधेरा", "शाम", "तन्हा", "अकेला", "अजनबी"
    ],

    // 4. NAINA_EYE
    "NAINA_EYE": [
        "eye", "eyes", "look", "looking", "see", "stare", "gaze", "mirror", "mirrors", "vision", "deed", "sight",
        "naina", "nain", "naino", "akh", "akhiyan", "aankh", "aankhein", "ankhen",
        "nazar", "nazrein", "kajal", "surma", "palak", "palkein", "deeda", "dida", "deedar",
        "नैना", "आँख", "आँखें", "नज़र", "काजल", "दीदार"
    ],

    // 5. DHUN_VINYL
    "DHUN_VINYL": [
        "music", "song", "songs", "beat", "beats", "sound", "sing", "singing", "voice", "dance", "dancing", "move",
        "start", "play", "vinyl", "record", "track", "melody", "tune", "audio", "mic", "microphone",
        "dhun", "geet", "gaana", "gana", "aawaz", "awaz", "sur", "saaz", "raag", "sangeet", "dhol",
        "ताल", "धुन", "गीत", "आवाज़", "संगीत", "राग"
    ],

    // 6. JAAN_SPARKLE
    "JAAN_SPARKLE": [
        "baby", "babe", "darling", "shawty", "honey", "angel", "beautiful", "stunning", "gorgeous", "pretty", "crush",
        "jaan", "jan", "jaanu", "janu", "jana", "piya", "mahiya", "heeriye", "hiriye",
        "sohniye", "sohna", "sajna", "sajan", "sanam", "mehboob", "habibi", "kudi", "kudiye", "billo", "raani", "soniyo",
        "suit", "patola", "punjaban", "punjabi", "jatti", "jattiye", "mutiyar", "sohni", "nakhra", "nakhre", "taur", "shaukeen",
        "हसीन", "जान", "पिया", "सजना", "सनम", "हीरिये", "कुड़ी", "सोहणी", "रक़म", "सूट", "पटोला",
        "ਰਕਮ", "ਸੂਟ", "ਪਟੋਲਾ", "ਪੰਜਾਬਣ", "ਜੱਟੀ", "ਕੁੜੀ", "ਮੁਟਿਆਰ", "ਸੋਹਣੀ", "ਨਖ਼ਰਾ"
    ],

    // 7. BAARISH_DROP
    "BAARISH_DROP": [
        "rain", "raining", "cry", "crying", "tear", "tears", "water", "ocean", "sea", "drown", "pour", "drip", "drops",
        "baarish", "barish", "barsaat", "barsat", "saawan", "sawan", "boondein", "bheega", "bhiga",
        "aansu", "ansu", "samandar", "dariya", "paani", "pani",
        "बारिश", "आँसू", "सावन", "समंदर", "दरिया", "पानी"
    ],

    // 8. GADDI_TURBO
    "GADDI_TURBO": [
        "car", "cars", "drive", "driving", "ride", "riding", "road", "highway", "speed", "fast", "whip", "turbo",
        "motor", "wheels", "drift", "racer", "track", "lane",
        "gaddi", "gaddiyan", "rasta", "raaste", "safar", "rah", "raah", "manzil", "musafir",
        "सफ़र", "रास्ता", "गाड़ी", "मंज़िल", "मुसाफ़िर"
    ],

    // 9. TAJ_CROWN
    "TAJ_CROWN": [
        "king", "queen", "crown", "royal", "throne", "boss", "legend", "lord", "empire", "rule", "ruler",
        "taj", "badshah", "rani", "shah", "sultan", "gabru", "jatt", "sardar", "nawab", "hukam", "raaj",
        "sareyan", "saareyan", "sab", "top", "sira", "sirra", "att", "end", "ghaint", "munda",
        "राज", "ताज", "बादशाह", "रानी", "सरदार", "हुक्म",
        "ਸਿਰਾ", "ਅੱਤ", "ਘੈਂਟ", "ਮੁੰਡਾ", "ਜੱਟ", "ਸਰਦਾਰ"
    ],

    // 10. JAAM_ELIXIR
    "JAAM_ELIXIR": [
        "drink", "drinking", "sip", "cup", "glass", "wine", "liquor", "bottle", "poison", "taste", "cheers", "toast",
        "potion", "cocktail", "bar", "beer", "whiskey", "champagne", "vodka", "rum", "tequila", "shots",
        "sharab", "sharaab", "jaam", "jam", "maikhana", "daaru", "daru", "peg", "zahar", "zeher", "paimana",
        "शराब", "जाम", "ज़हर", "पैमाना", "दारू"
    ],

    // 11. NASHA_PORTAL
    "NASHA_PORTAL": [
        "nasha", "nashe", "madhoshi", "madhosh", "khumar", "fitoor", "fitur", "junoon", "junun",
        "pagal", "deewana", "diwana", "dizzy", "trance", "crazy", "lose", "lost", "mind", "vibe", "vibes",
        "portal", "dimension", "magic", "spell", "trip", "tripping", "illusion", "high",
        "नशा", "नशे", "मदहोशी", "फ़ितूर", "जुनून", "दीवाना", "पागल"
    ],

    // 12. ASLA_RETICLE
    "ASLA_RETICLE": [
        "gun", "guns", "shooter", "aim", "crosshair", "bullet", "shot", "target", "trigger", "weapon", "reticle",
        "lock", "locked", "ammo", "pistol", "rifle", "shoot", "chance", "chances", "luck", "lucky", "dice", "roll", "bet", "gamble", "game", "risk",
        "asla", "bandook", "goli", "nishana", "shikaar", "kismat", "taqdeer", "naseeb", "bazi", "baazi", "khel",
        "शिकार", "निशाना", "बंदूक", "गोली", "असली", "क़िस्मत", "नसीब", "बाज़ी"
    ],

    // 13. SHER_CREST
    "SHER_CREST": [
        "lion", "tiger", "wolf", "beast", "predator", "warrior", "brave", "fierce", "roar", "courage", "danger", "dangerous", "wild",
        "sher", "babbar", "cheetah", "shikari", "jigar", "daleer", "soorma", "anakh",
        "शेर", "बब्बर", "शिकारी", "दिलेर", "सूरमा"
    ],

    // 14. WAQT_CHRONO
    "WAQT_CHRONO": [
        "time", "wait", "waiting", "waitin", "forever", "always", "never", "clock", "hour", "hours", "moment", "moments",
        "past", "future", "chrono", "hourglass", "delay", "ticking",
        "waqt", "lamha", "lamhe", "pal", "sadiyan", "intezaar", "intezar", "hamesha", "zamaana", "zamana",
        "वक़्त", "लम्हा", "पल", "इंतज़ार", "हमेशा", "ज़माना"
    ],

    // 15. BASS_WAVE
    "BASS_WAVE": [
        "bass", "808", "sub", "drop", "tempo", "groove", "kick", "frequency", "wave", "waves", "rhythm",
        "speaker", "speakers", "loud", "heavy", "boom", "bounce",
        "dhak", "thumka", "dhol", "tabla", "beatdrop",
        "karda", "kardi", "karde", "nach", "nachdi", "bhangra", "beat", "club", "party",
        "थाप", "धड़क", "ढोल", "धमाका",
        "ਕਰਦਾ", "ਕਰਦੀ", "ਨੱਚ", "ਭੰਗੜਾ"
    ],

    // 16. NOOR_COMET
    "NOOR_COMET": [
        "star", "stars", "shooting", "comet", "diamond", "diamonds", "shine", "shining", "gold", "golden",
        "glow", "glowing", "beam", "light", "ray", "rays", "bright", "flash", "sparkle", "riches", "wealth", "finesse",
        "money", "cash", "rich", "miracle", "priceless", "treasure", "sky", "skies", "cloud", "clouds", "heaven", "fly", "flying",
        "noor", "nur", "chamak", "roshni", "sitara", "taare", "tare", "heera", "hira", "sona", "sone", "daulat", "paisa",
        "khwab", "khwaab", "sapna", "sapne", "aasman", "asman", "badal", "baadal", "hawa", "hawaein", "parinde",
        "चमक", "रौशनी", "सितारा", "नूर", "हीरा", "सोना", "दौलत", "ख़्वाब", "सपना", "सपने", "आसमान", "बादल", "हवा"
    ]
};

// Build inverted fast lookup map
var KEYWORD_MAP = {};

function initMap() {
    for (var motif in RAW_BUCKETS) {
        var words = RAW_BUCKETS[motif];
        var glyphObj = KINETIC_GLYPHS[motif];
        for (var i = 0; i < words.length; i++) {
            var raw = words[i].trim().toLowerCase();
            if (raw.length > 0) {
                KEYWORD_MAP[raw] = glyphObj;
            }
        }
    }
}
initMap();

/**
 * 1. Convert to lowercase & strip punctuation
 */
function normalizeLyricToken(rawWord) {
    if (!rawWord) return "";
    var s = String(rawWord).toLowerCase().trim();
    s = s.replace(/[.,!?;:'"()\[\]\-\/\`~@#$%^&*+=<>_{}]/g, "");
    return s;
}

/**
 * 2. Hinglish Stretched-Vowel Stemmer
 */
function stemHinglish(token) {
    if (!token || token.length < 3) return token;
    var s = token;
    s = s.replace(/(.)\1{2,}/g, "$1");
    s = s.replace(/aa+/g, "a");
    s = s.replace(/ee+/g, "i");
    s = s.replace(/oo+/g, "u");
    return s;
}

/**
 * 3. Strip common plural/oblique Hinglish suffixes
 */
function stripHinglishSuffix(token) {
    if (!token || token.length <= 3) return token;
    var s = token;
    if (s.endsWith("iyaan") && s.length > 5) return s.slice(0, -5);
    if (s.endsWith("iyan") && s.length > 4) return s.slice(0, -4);
    if (s.endsWith("eyan") && s.length > 4) return s.slice(0, -4);
    if (s.endsWith("aan") && s.length > 3) return s.slice(0, -3);
    if (s.endsWith("ein") && s.length > 3) return s.slice(0, -3);
    if (s.endsWith("on") && s.length > 3) return s.slice(0, -2);
    if (s.endsWith("an") && s.length > 3) return s.slice(0, -2);
    return s;
}

var STOP_WORDS = {
    "he": true, "she": true, "was": true, "is": true, "do": true,
    "what": true, "you": true, "you've": true, "youve": true, "been": true,
    "too": true, "out": true, "in": true, "on": true, "to": true,
    "the": true, "a": true, "an": true, "and": true, "or": true,
    "but": true, "it": true, "for": true, "of": true, "te": true,
    "ne": true, "ko": true, "se": true, "hai": true,
    "सी": true, "है": true, "ने": true
};

function isStopWord(word) {
    if (!word) return true;
    var norm = normalizeLyricToken(word);
    if (!norm) return true;
    return !!STOP_WORDS[norm];
}

/**
 * Lookup glyph by word:
 * Direct -> Stemmed -> Suffix-stripped
 * Returns the multi-layer kinetic object (or null if unmapped / stop word).
 */
function lookupGlyphSingle(rawWord) {
    if (!rawWord) return null;
    var norm = normalizeLyricToken(rawWord);
    if (!norm || STOP_WORDS[norm]) return null;

    if (KEYWORD_MAP[norm]) return KEYWORD_MAP[norm];

    var stemmed = stemHinglish(norm);
    if (STOP_WORDS[stemmed]) return null;
    if (KEYWORD_MAP[stemmed]) return KEYWORD_MAP[stemmed];

    var suffStripped = stripHinglishSuffix(stemmed);
    if (STOP_WORDS[suffStripped]) return null;
    if (KEYWORD_MAP[suffStripped]) return KEYWORD_MAP[suffStripped];

    var directSuff = stripHinglishSuffix(norm);
    if (STOP_WORDS[directSuff]) return null;
    if (KEYWORD_MAP[directSuff]) return KEYWORD_MAP[directSuff];

    return null;
}

function lookupGlyph(rawWord) {
    if (!rawWord) return null;
    var trimmed = String(rawWord).trim();
    if (/\s+/.test(trimmed)) {
        var parts = trimmed.split(/\s+/);
        for (var i = 0; i < parts.length; i++) {
            var g = lookupGlyphSingle(parts[i]);
            if (g) return g;
        }
        return null;
    }
    return lookupGlyphSingle(trimmed);
}
