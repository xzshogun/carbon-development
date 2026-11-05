#!/usr/bin/env bash
# ==============================================================================
#  Carbon Shell Audio Initializer
#  Ensures ALSA Realtek ALC hardware audio channels (Speaker, Headphone)
#  are unmuted and PipeWire sinks are active.
# ==============================================================================

# Unmute core hardware controls
for ctl in "Master" "Speaker" "Headphone"; do
    amixer -q sset "$ctl" unmute 100% 2>/dev/null || true
done

# Disable Auto-Mute Mode which can silence speakers when headphone jack impedance is detected
amixer -q sset "Auto-Mute Mode" Disabled 2>/dev/null || true

# Ensure PipeWire default sink is unmuted
if command -v wpctl >/dev/null 2>&1; then
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null || true
fi
