#!/bin/sh
# Carbon screen recorder — start.
# Usage: carbon-rec-start.sh <full|region> <0|1 mic> <0|1 appaudio>
# Full screen uses the focused monitor; region pops slurp for an interactive area.
# Mic + app audio are mixed through a temporary null sink so wf-recorder only
# needs one audio device (its monitor). Output lands in ~/Videos.
MODE="$1"
MIC="$2"
APP="$3"

GEO=""
case "$MODE" in
    full)
        GEO=$(hyprctl monitors -j 2>/dev/null | python3 -c 'import json,sys
d=[m for m in json.load(sys.stdin) if m.get("focused")]
if d: print("%d,%d %dx%d" % (d[0]["x"], d[0]["y"], d[0]["width"], d[0]["height"]), flush=True)
')
        [ -z "$GEO" ] && exit 3
        ;;
    region)
        GEO=$(slurp -f "%x,%y %wx%h" 2>/dev/null)
        [ -z "$GEO" ] && exit 2
        ;;
    *) exit 4 ;;
esac

OUTDIR="$HOME/Videos"
mkdir -p "$OUTDIR"
OUT="$OUTDIR/rec-$(date +%Y%m%d-%H%M%S).mp4"

AUDIO=""
MODS=""
LOOPBACKS=""
SINK=""

if [ "$MIC" = "1" ] && [ "$APP" = "1" ]; then
    MIX="carbon_rec_$$"
    sink_id=$(pactl load-module module-null-sink sink_name="$MIX" sink_properties=device.description=CarbonRecordingMix 2>/dev/null)
    [ -n "$sink_id" ] && SINK="$sink_id"
    src_mic=$(pactl get-default-source 2>/dev/null)
    src_app="$(pactl get-default-sink 2>/dev/null).monitor"
    m_id=$(pactl load-module module-loopback source="$src_mic" sink="$MIX" 2>/dev/null)
    [ -n "$m_id" ] && LOOPBACKS="$LOOPBACKS $m_id"
    a_id=$(pactl load-module module-loopback source="$src_app" sink="$MIX" 2>/dev/null)
    [ -n "$a_id" ] && LOOPBACKS="$LOOPBACKS $a_id"
    AUDIO="--audio=$MIX.monitor"
    MODS="$LOOPBACKS $SINK"
elif [ "$MIC" = "1" ]; then
    src_mic=$(pactl get-default-source 2>/dev/null)
    [ -n "$src_mic" ] && AUDIO="--audio=$src_mic"
elif [ "$APP" = "1" ]; then
    src_app="$(pactl get-default-sink 2>/dev/null).monitor"
    [ -n "$src_app" ] && AUDIO="--audio=$src_app"
fi

echo "$OUT" > /tmp/rec.out
echo "$LOOPBACKS" > /tmp/rec.loopbacks
echo "$SINK" > /tmp/rec.sink
echo "$MODS" > /tmp/rec.mods
nohup wf-recorder -g "$GEO" $AUDIO -f "$OUT" >/dev/null 2>&1 &
echo $! > /tmp/rec.pid
exit 0