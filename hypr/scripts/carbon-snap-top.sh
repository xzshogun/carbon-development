#!/usr/bin/env bash
# ==============================================================================
# carbon-snap-top.sh
#
# Drag a floating window up until it hits the top edge of the screen and it
# "snaps" to cover the screen — Windows-style drag-to-top = maximize.
#
# Unlike real fullscreen, the window is NOT put into a fullscreen state: it
# stays a normal floating window that is simply moved + resized to cover the
# monitor it is on. The target rectangle is read live from that monitor
# (`hyprctl monitors`): its native resolution minus any space reserved by
# bars/panels (the `reserved` area). So nothing is hardcoded, resolution
# changes just work, and if a top bar is present the window stops *below* the
# bar instead of hiding underneath it.
#
# Hyprland (0.56) can't do this natively (upstream feature request still open)
# and socket2 emits nothing during window drags, so this tiny daemon polls
# window geometry and snaps the window the moment its top crosses INTO a thin
# band at the top of the usable area. With `general:snap` enabled (edge snapping
# for floating windows) the drag snaps to the edge precisely.
#
# Only the downward crossing counts (a transition), so windows that merely
# rest near the top are never touched. Already-fullscreen windows (hyprctl
# `fullscreen` field 2/3 = real fullscreen) are skipped.
#
# Started via `exec-once` in carbon.conf. Exits when the Hyprland session
# disappears. Idempotent.
# ==============================================================================

set -u

[[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || exit 0

readonly HYS="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE"
readonly THRESH=18   # px below the top of the usable area that counts as "hitting the top"
readonly POLL=0.12   # poll interval (seconds)

# Last observed top-y per window address (transition tracking).
declare -A PREV_Y=()

while true; do
    # Hyprland session gone (logout / restart) -> stop cleanly.
    [[ -d "$HYS" ]] || exit 0

    # Live usable area per monitor: id -> "x y width height".
    # Usable area = monitor rectangle shrunk by the space reserved by bars/panels.
    # `reserved` is [left, top, right, bottom] in that order. With no bars this is
    # simply the whole monitor at its native resolution.
    declare -A MON=()
    while IFS=$'\t' read -r mid mx my mw mh; do
        MON["$mid"]="$mx $my $mw $mh"
    done < <(hyprctl monitors -j 2>/dev/null | jq -r '.[] |
        "\(.id)\t\(.x + .reserved[0])\t\(.y + .reserved[1])\t\(.width - .reserved[0] - .reserved[2])\t\(.height - .reserved[1] - .reserved[3])"')

    # Candidates: floating, mapped, not on a special (scratchpad) workspace,
    # and not in real fullscreen.
    data="$(hyprctl clients -j 2>/dev/null | jq -r '.[] |
        select(.floating == true
            and .mapped == true
            and ((.special // false) == false)
            and ((.fullscreen // 0) < 2)) |
        "\(.address) \(.at[1]) \(.monitor)"')"

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        set -- $line
        addr="$1"
        y="$2"
        mon="$3"

        geom="${MON[$mon]:-}"
        if [[ -n "$geom" && -n "${PREV_Y[$addr]+set}" ]]; then
            read -r mx my mw mh <<< "$geom"
            prev="${PREV_Y[$addr]}"
            thr=$(( my + THRESH ))
            # Window top crossed INTO the top band -> snap to cover usable area.
            if (( y <= thr && prev > thr )); then
                # Resize + move the floating window to cover the monitor, using
                # the monitor's own native size / usable area (no hardcoded res).
                hyprctl dispatch resizewindowpixel "exact $mw $mh,address:$addr" >/dev/null 2>&1
                hyprctl dispatch movewindowpixel "exact $mx $my,address:$addr" >/dev/null 2>&1
            fi
        fi
        # First sighting only records the position (no spurious trigger).
        PREV_Y[$addr]="$y"
    done <<< "$data"

    # Drop stale state if windows churn a lot.
    (( ${#PREV_Y[@]} > 256 )) && PREV_Y=()

    sleep "$POLL"
done
