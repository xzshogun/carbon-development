#!/bin/sh
# Animated lock-screen greeting: a waving hand sways across "hie hieee".
# hyprlock refreshes this label on a timer, so the hand visually waves.

fr=$(date +%N)
s=$(date +%s)
i=$(( (s * 1000 + 10#$fr / 1000000) / 130 % 4 ))

case "$i" in
  0) printf '👋 hie hieee'              ;;
  1) printf ' 👋 hie hieee'             ;;
  2) printf '  👋 hie hieee'            ;;
  3) printf ' 👋 hie hieee~'            ;;
esac