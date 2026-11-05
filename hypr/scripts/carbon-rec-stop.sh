#!/bin/sh
# Carbon screen recorder — stop: SIGINT the recording (graceful mux), then tear
# down the null sink + loopbacks. Leaves /tmp/rec.out for the UI to announce.
PID=""
[ -f /tmp/rec.pid ] && PID=$(cat /tmp/rec.pid)

if [ -n "$PID" ]; then
    kill -INT "$PID" 2>/dev/null
fi
pkill -INT -x wf-recorder 2>/dev/null

i=0
while [ $i -lt 10 ]; do
    pgrep -x wf-recorder >/dev/null 2>&1 || break
    sleep 0.5
    i=$((i + 1))
done

pkill -9 -x wf-recorder 2>/dev/null
[ -n "$PID" ] && kill -9 "$PID" 2>/dev/null

# 1. Unload loopbacks first so sink monitors never get disconnected or errored
if [ -f /tmp/rec.loopbacks ]; then
    for mod in $(cat /tmp/rec.loopbacks); do
        [ -n "$mod" ] && pactl unload-module "$mod" 2>/dev/null
    done
    sleep 0.15
fi

# 2. Unload null sink
if [ -f /tmp/rec.sink ]; then
    for mod in $(cat /tmp/rec.sink); do
        [ -n "$mod" ] && pactl unload-module "$mod" 2>/dev/null
    done
fi

# 3. Fallback: if /tmp/rec.mods exists without /tmp/rec.sink, unload in reverse order
if [ ! -f /tmp/rec.sink ] && [ -f /tmp/rec.mods ]; then
    for mod in $(tac /tmp/rec.mods 2>/dev/null || cat /tmp/rec.mods); do
        [ -n "$mod" ] && pactl unload-module "$mod" 2>/dev/null
    done
fi

# 4. Cleanup any orphaned carbon_rec modules safely: loopbacks first, then sink
for mod in $(pactl list short modules 2>/dev/null | grep -i "module-loopback.*carbon_rec" | awk '{print $1}'); do
    [ -n "$mod" ] && pactl unload-module "$mod" 2>/dev/null
done
sleep 0.1
for mod in $(pactl list short modules 2>/dev/null | grep -i "carbon_rec" | awk '{print $1}'); do
    [ -n "$mod" ] && pactl unload-module "$mod" 2>/dev/null
done

OUT=""
[ -f /tmp/rec.out ] && OUT=$(cat /tmp/rec.out)

rm -f /tmp/rec.pid /tmp/rec.mods /tmp/rec.sink /tmp/rec.loopbacks /tmp/rec.out

if [ -n "$OUT" ]; then
    echo "saved: $OUT"
    notify-send -a "Screen Recorder" -i video-x-generic "Recording Saved" "$OUT"
fi
exit 0