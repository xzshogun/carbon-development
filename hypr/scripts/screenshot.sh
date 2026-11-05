#!/usr/bin/env bash
# ==============================================================================
# Carbon Universal Screenshot Dispatcher
# Usage:
#   screenshot.sh                 -> Region screenshot with instant screen freeze
#   screenshot.sh --region / -s   -> Region screenshot with instant screen freeze
#   screenshot.sh --full / -m     -> Fullscreen screenshot
#   screenshot.sh --window / -w   -> Active focused window screenshot
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "$1" in
    --full|-m|-f)
        exec "$SCRIPT_DIR/carbon-screenshot-full.sh"
        ;;
    --window|-w)
        exec "$SCRIPT_DIR/carbon-screenshot-window.sh"
        ;;
    --region|-s|*)
        exec "$SCRIPT_DIR/carbon-screenshot-region.sh"
        ;;
esac
