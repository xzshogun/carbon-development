#!/usr/bin/env bash
# ==============================================================================
# Carbon Shell — Launcher & Lifecycle Controller (carbon-start / carbon-shell)
# Starts, restarts, stops, or checks the status of Carbon Quickshell and syncs
# the active mode's Hyprland keybindings.
# ==============================================================================

set -euo pipefail

CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
HYPR_CONFIG_DIR="${CARBON_HYPR_DIR:-$HOME/.config/hypr}"
QUICKSHELL_DIR="$HOME/.local/share/quickshell/carbon"
BIN_DIR="$HOME/.local/bin"

ACTION="start"
MODE=""
FOREGROUND=0
DRY_RUN=0
NO_RELOAD=0

if [[ -t 1 ]]; then
    C_BLUE="\033[1;34m"; C_GREEN="\033[1;32m"; C_YELLOW="\033[1;33m"
    C_RED="\033[1;31m"; C_BOLD="\033[1m"; C_RESET="\033[0m"
else
    C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""; C_RESET=""
fi

msg()    { printf "${C_BLUE}::${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$*"; }
info()   { printf " ${C_GREEN}->${C_RESET} %s\n" "$*"; }
warn()   { printf " ${C_YELLOW}!${C_RESET} %s\n" "$*"; }
err()    { printf " ${C_RED}error:${C_RESET} %s\n" "$*" >&2; }
ok()     { printf "   ${C_GREEN}[✓]${C_RESET} %s\n" "$*"; }
die()    { err "$@"; exit 1; }

usage() {
    cat << EOF
Usage: carbon-start [COMMAND] [OPTIONS]
   or: ./start.sh [COMMAND] [OPTIONS]

Commands:
  start             Start Carbon Shell (or restart if already running) [default]
  restart           Restart Carbon Shell and reload Hyprland keybindings
  stop              Stop running Carbon Quickshell instance
  status            Show current Carbon Shell status and active mode

Options:
  -m, --mode=MODE   Set shell mode before starting: 'minimal_notch', 'notch', 'pill', or 'vanish'
  -f, --foreground  Run Quickshell in the foreground (useful for debugging logs)
      --no-reload   Do not reload Hyprland configuration
      --dry-run     Simulate start/status inside /tmp/carbon-sandbox
  -h, --help        Show this message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        start|restart|stop|status)
            ACTION="$1"
            shift
            ;;
        -m|--mode)
            [[ -n "${2:-}" ]] || die "Option $1 requires a mode name"
            MODE="$2"
            shift 2
            ;;
        --mode=*)
            MODE="${1#*=}"
            shift
            ;;
        -f|--foreground)
            FOREGROUND=1
            shift
            ;;
        --no-reload)
            NO_RELOAD=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            die "Unknown option or command: $1 (see --help)"
            ;;
    esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    SANDBOX_ROOT="${CARBON_SANDBOX_DIR:-/tmp/carbon-sandbox}"
    CONFIG_DIR="$SANDBOX_ROOT/carbon"
    HYPR_CONFIG_DIR="$SANDBOX_ROOT/hypr"
    QUICKSHELL_DIR="$SANDBOX_ROOT/quickshell"
    BIN_DIR="$SANDBOX_ROOT/bin"
    NO_RELOAD=1
fi

# Fallback to repo quickshell path if not yet installed to ~/.local/share/quickshell/carbon
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$QUICKSHELL_DIR/shell.qml" && -f "$SCRIPT_DIR/quickshell/carbon/shell.qml" ]]; then
    QUICKSHELL_DIR="$SCRIPT_DIR/quickshell/carbon"
fi

get_active_mode() {
    local mode_file="$CONFIG_DIR/carbon-bar-mode.json"
    if [[ -f "$mode_file" ]]; then
        python3 -c "import json, sys; print(json.load(open(sys.argv[1])).get('mode', 'minimal_notch'))" "$mode_file" 2>/dev/null || echo "minimal_notch"
    else
        echo "minimal_notch"
    fi
}

set_active_mode() {
    local req_mode="$1"
    local norm_mode="minimal_notch"
    local style="minimal"
    case "${req_mode,,}" in
        notch|island) norm_mode="notch"; style="notch" ;;
        pill|waybar) norm_mode="pill"; style="pill" ;;
        vanish|nucleus) norm_mode="nucleus"; style="nucleus" ;;
        minimal|minimal_notch|tide) norm_mode="minimal_notch"; style="minimal" ;;
        *) die "Invalid mode '$req_mode'. Valid modes: minimal_notch, notch, pill, vanish" ;;
    esac

    mkdir -p "$CONFIG_DIR" "$HYPR_CONFIG_DIR"
    python3 -c '
import json, os, sys
mode, style = sys.argv[1], sys.argv[2]
for p in [sys.argv[3], sys.argv[4]]:
    try:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        d = json.load(open(p)) if os.path.exists(p) else {}
        d["mode"] = mode
        d["islandStyle"] = style
        with open(p, "w") as f:
            json.dump(d, f, indent=2)
    except Exception:
        pass
' "$norm_mode" "$style" "$CONFIG_DIR/carbon-bar-mode.json" "$HYPR_CONFIG_DIR/carbon-bar-mode.json"
    ok "Set active shell mode to: $norm_mode"
}

if [[ "$ACTION" == "status" ]]; then
    msg "Carbon Shell Status"
    ACTIVE_MODE="$(get_active_mode)"
    info "Config Dir   : $CONFIG_DIR"
    info "Quickshell   : $QUICKSHELL_DIR"
    info "Active Mode  : $ACTIVE_MODE"
    if [[ -f "$CONFIG_DIR/configs/current-mode-keybinds.conf" ]]; then
        BIND_COUNT="$(grep -cE '^bind' "$CONFIG_DIR/configs/current-mode-keybinds.conf" 2>/dev/null || echo 0)"
        info "Mode Keybinds: $BIND_COUNT active bindings in current-mode-keybinds.conf"
    fi
    if pgrep -x quickshell >/dev/null 2>&1; then
        ok "Quickshell process is running"
    else
        warn "Quickshell process is not currently running"
    fi
    exit 0
fi

if [[ "$ACTION" == "stop" ]]; then
    msg "Stopping Carbon Shell..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
        ok "[Dry-Run] Stopped Carbon Quickshell service and processes"
        exit 0
    fi
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user stop carbon-quickshell.service >/dev/null 2>&1 || true
    fi
    pkill -x quickshell >/dev/null 2>&1 || true
    ok "Carbon Shell stopped"
    exit 0
fi

# For start or restart:
msg "Starting Carbon Shell..."

if [[ ! -f "$QUICKSHELL_DIR/shell.qml" ]]; then
    die "Quickshell configuration not found at $QUICKSHELL_DIR/shell.qml. Run ./install.sh first."
fi

if [[ -n "$MODE" ]]; then
    set_active_mode "$MODE"
fi

CURRENT_MODE="$(get_active_mode)"
info "Active mode: $CURRENT_MODE"

# Ensure isolated mode keybinds are synced before launching
MODE_SCRIPT="$CONFIG_DIR/scripts/carbon-mode-keybinds.sh"
if [[ ! -f "$MODE_SCRIPT" && -f "$SCRIPT_DIR/hypr/scripts/carbon-mode-keybinds.sh" ]]; then
    MODE_SCRIPT="$SCRIPT_DIR/hypr/scripts/carbon-mode-keybinds.sh"
fi

if [[ -f "$MODE_SCRIPT" ]]; then
    CARBON_CONFIG_DIR="$CONFIG_DIR" CARBON_HYPR_DIR="$HYPR_CONFIG_DIR" CARBON_NO_RELOAD="$NO_RELOAD" \
        bash "$MODE_SCRIPT" "$CURRENT_MODE" >/dev/null 2>&1 || true
    ok "Synchronized isolated keybinds for mode: $CURRENT_MODE"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    mkdir -p "$CONFIG_DIR"
    echo "started:$CURRENT_MODE" > "$CONFIG_DIR/last_start_state"
    ok "[Dry-Run] Verified Quickshell entrypoint ($QUICKSHELL_DIR/shell.qml) and launched mode '$CURRENT_MODE'"
    exit 0
fi

# Auto-detect Wayland & Hyprland sockets if missing from caller shell
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    for sock in "$RUNTIME_DIR"/wayland-*; do
        if [[ -S "$sock" ]]; then
            export WAYLAND_DISPLAY="$(basename "$sock")"
            break
        fi
    done
fi
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" && -d "$RUNTIME_DIR/hypr" ]]; then
    for hdir in "$RUNTIME_DIR"/hypr/*; do
        if [[ -d "$hdir" ]]; then
            export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$hdir")"
            break
        fi
    done
fi

export CARBON_CONFIG_DIR="$CONFIG_DIR"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Hyprland}"
export PATH="$BIN_DIR:$PATH"

# Symlink ~/.config/quickshell/carbon -> $QUICKSHELL_DIR so both -p and -c carbon work
mkdir -p "$HOME/.config/quickshell" 2>/dev/null || true
ln -sfn "$QUICKSHELL_DIR" "$HOME/.config/quickshell/carbon" 2>/dev/null || true

# Export display environment into systemd user session
if command -v dbus-update-activation-environment >/dev/null 2>&1; then
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM CARBON_CONFIG_DIR PATH >/dev/null 2>&1 || true
fi
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM CARBON_CONFIG_DIR PATH >/dev/null 2>&1 || true
fi

# Apply touchpad & 3-finger gesture configuration if available
if [[ -x "$CONFIG_DIR/scripts/carbon-gestures-init.sh" ]]; then
    bash "$CONFIG_DIR/scripts/carbon-gestures-init.sh" >/dev/null 2>&1 || true
fi

# Reload Hyprland if running
if [[ "$NO_RELOAD" -eq 0 ]] && command -v hyprctl >/dev/null 2>&1; then
    if hyprctl instances >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
        ok "Hyprland configuration reloaded"
    fi
fi

# Find quickshell binary
QS_BIN=""
if [[ -x "$BIN_DIR/quickshell" ]]; then
    QS_BIN="$BIN_DIR/quickshell"
elif command -v quickshell >/dev/null 2>&1; then
    QS_BIN="$(command -v quickshell)"
elif [[ -x "/usr/bin/quickshell" ]]; then
    QS_BIN="/usr/bin/quickshell"
fi

if [[ "$FOREGROUND" -eq 1 ]]; then
    [[ -n "$QS_BIN" ]] || die "quickshell binary not found in PATH"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user stop carbon-quickshell.service >/dev/null 2>&1 || true
    fi
    pkill -x quickshell >/dev/null 2>&1 || true
    sleep 0.3
    info "Running Quickshell in foreground (Ctrl+C to stop)..."
    exec "$QS_BIN" -p "$QUICKSHELL_DIR"
fi

# Ensure Settings Hub backend daemon is listening on /tmp/carbon-hub.sock
if [[ ! -S "/tmp/carbon-hub.sock" ]]; then
    if [[ -x "$BIN_DIR/carbon-hub-daemon" ]] && ! pgrep -x carbon-hub-daemon >/dev/null 2>&1; then
        nohup "$BIN_DIR/carbon-hub-daemon" >/dev/null 2>&1 &
    elif [[ -f "$CONFIG_DIR/scripts/carbon-hub-daemon.py" ]] && ! pgrep -f "carbon-hub-daemon.py" >/dev/null 2>&1; then
        nohup python3 "$CONFIG_DIR/scripts/carbon-hub-daemon.py" >/dev/null 2>&1 &
    elif command -v systemctl >/dev/null 2>&1 && systemctl --user list-unit-files carbon-hub.service >/dev/null 2>&1; then
        systemctl --user restart carbon-hub.service >/dev/null 2>&1 || true
    fi
fi

if command -v systemctl >/dev/null 2>&1 && systemctl --user list-unit-files carbon-quickshell.service >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    if systemctl --user restart carbon-quickshell.service >/dev/null 2>&1; then
        sleep 1.0
        if pgrep -x quickshell >/dev/null 2>&1; then
            ok "Carbon Shell started via systemd (carbon-quickshell.service)"
            exit 0
        else
            warn "systemd carbon-quickshell.service exited early; launching Quickshell directly..."
            systemctl --user stop carbon-quickshell.service >/dev/null 2>&1 || true
        fi
    fi
fi

[[ -n "$QS_BIN" ]] || die "quickshell binary not found. Please install quickshell first."
pkill -x quickshell >/dev/null 2>&1 || true
sleep 0.3
nohup "$QS_BIN" -p "$QUICKSHELL_DIR" >/tmp/carbon-quickshell.log 2>&1 &
QS_PID=$!
sleep 0.8
if kill -0 "$QS_PID" >/dev/null 2>&1; then
    ok "Carbon Shell started in background (PID $QS_PID, logs: /tmp/carbon-quickshell.log)"
else
    err "Quickshell exited unexpectedly. Last log lines from /tmp/carbon-quickshell.log:"
    tail -n 20 /tmp/carbon-quickshell.log >&2 || true
    exit 1
fi
