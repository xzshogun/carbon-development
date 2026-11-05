#!/usr/bin/env bash
# ==============================================================================
# Carbon Shell — Non-Destructive Uninstaller (uninstall.sh / carbon-uninstall)
# Safely unhooks Carbon Shell from Hyprland, stops services, creates a final
# safety backup, and removes deployed Carbon Shell runtime files.
# ==============================================================================

set -euo pipefail

CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
HYPR_CONFIG_DIR="${CARBON_HYPR_DIR:-$HOME/.config/hypr}"
QUICKSHELL_DIR="$HOME/.local/share/quickshell/carbon"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
FINAL_BACKUP_DIR="${HOME}/.config/carbon_uninstall_backup_${TIMESTAMP}"

AUTO_YES=0
KEEP_CONFIG=0
NO_BACKUP=0
NO_RELOAD=0
DRY_RUN=0

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

prompt_confirm() {
    local prompt_msg="$1"
    local default_val="${2:-N}"
    local choice=""

    if [[ "$AUTO_YES" -eq 1 || ! -t 0 ]]; then
        [[ "$default_val" =~ ^[Yy]$ ]] && return 0 || return 1
    fi

    printf "%s" "$prompt_msg" >&2
    read -r choice
    choice="${choice:-$default_val}"
    [[ "$choice" =~ ^[Yy]$ ]] && return 0 || return 1
}

usage() {
    cat << EOF
Usage: ./uninstall.sh [OPTIONS]
   or: carbon-uninstall [OPTIONS]

Safely removes Carbon Shell from your system and cleans up its single source
line in ~/.config/hypr/hyprland.conf without touching your personal Hyprland config.

Options:
  -y, --yes          Non-interactive mode (confirm uninstall)
      --keep-config  Keep ~/.config/carbon user JSON settings & themes
      --no-backup    Skip creating a final backup archive before removal
      --no-reload    Do not reload Hyprland after uninstalling
      --dry-run      Simulate uninstallation inside /tmp/carbon-sandbox
  -h, --help         Show this message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -y|--yes) AUTO_YES=1; shift ;;
        --keep-config) KEEP_CONFIG=1; shift ;;
        --no-backup) NO_BACKUP=1; shift ;;
        --no-reload) NO_RELOAD=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        *) die "Unknown option: $1 (see --help)" ;;
    esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    SANDBOX_ROOT="${CARBON_SANDBOX_DIR:-/tmp/carbon-sandbox}"
    CONFIG_DIR="$SANDBOX_ROOT/carbon"
    HYPR_CONFIG_DIR="$SANDBOX_ROOT/hypr"
    QUICKSHELL_DIR="$SANDBOX_ROOT/quickshell"
    BIN_DIR="$SANDBOX_ROOT/bin"
    SYSTEMD_USER_DIR="$SANDBOX_ROOT/systemd"
    FINAL_BACKUP_DIR="$SANDBOX_ROOT/backups/carbon-uninstall-backup-${TIMESTAMP}"
    NO_RELOAD=1
    warn "Running uninstaller in sandbox mode ($SANDBOX_ROOT)"
fi

printf "\n"
msg "Carbon Shell Uninstaller"
printf "   Config Dir : %s\n" "$CONFIG_DIR"
printf "   Quickshell : %s\n\n" "$QUICKSHELL_DIR"

if [[ "$AUTO_YES" -eq 0 ]]; then
    if ! prompt_confirm "Are you sure you want to uninstall Carbon Shell? [y/N]: " "N"; then
        info "Uninstall cancelled."
        exit 0
    fi
fi

# 1. Create final safety backup before removing anything
if [[ "$NO_BACKUP" -eq 0 && ( -d "$CONFIG_DIR" || -d "$QUICKSHELL_DIR" ) ]]; then
    mkdir -p "$FINAL_BACKUP_DIR"
    [[ -d "$CONFIG_DIR" ]] && cp -rf "$CONFIG_DIR" "$FINAL_BACKUP_DIR/carbon_config" 2>/dev/null || true
    [[ -f "$HYPR_CONFIG_DIR/hyprland.conf" ]] && cp -f "$HYPR_CONFIG_DIR/hyprland.conf" "$FINAL_BACKUP_DIR/hyprland.conf.bak" 2>/dev/null || true
    ok "Created safety backup at $FINAL_BACKUP_DIR"
fi

# 2. Stop and disable systemd user services
msg "Stopping Carbon Shell services..."
if [[ "$DRY_RUN" -eq 0 ]] && command -v systemctl >/dev/null 2>&1; then
    for srv in carbon-quickshell.service carbon-hub.service; do
        systemctl --user stop "$srv" >/dev/null 2>&1 || true
        systemctl --user disable "$srv" >/dev/null 2>&1 || true
    done
    pkill -x quickshell >/dev/null 2>&1 || true
fi

for srv in carbon-quickshell.service carbon-hub.service; do
    if [[ -f "$SYSTEMD_USER_DIR/$srv" ]]; then
        rm -f "$SYSTEMD_USER_DIR/$srv"
        ok "Removed systemd unit: $srv"
    fi
done

if [[ "$DRY_RUN" -eq 0 ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
fi

# 3. Cleanly unhook Carbon Shell from ~/.config/hypr/hyprland.conf
HYPR_MAIN="$HYPR_CONFIG_DIR/hyprland.conf"
if [[ -f "$HYPR_MAIN" ]]; then
    python3 -c '
import sys
path = sys.argv[1]
with open(path, "r", encoding="utf-8", errors="replace") as f:
    lines = f.readlines()

cleaned = []
for line in lines:
    stripped = line.strip()
    if stripped == "# Carbon Shell Integration":
        continue
    if "source" in stripped and ".config/carbon/carbon.conf" in stripped:
        continue
    cleaned.append(line)

with open(path, "w", encoding="utf-8") as f:
    f.writelines(cleaned)
' "$HYPR_MAIN"
    ok "Removed Carbon source hook from $HYPR_MAIN (user config preserved)"
fi

# 4. Remove Quickshell components
if [[ -d "$QUICKSHELL_DIR" ]]; then
    rm -rf "$QUICKSHELL_DIR"
    ok "Removed Quickshell components ($QUICKSHELL_DIR)"
fi

# 5. Remove mirrored mode keybind & script files in ~/.config/hypr
rm -f "$HYPR_CONFIG_DIR/configs/current-mode-keybinds.conf" \
      "$HYPR_CONFIG_DIR/configs/keybinds-minimal.conf" \
      "$HYPR_CONFIG_DIR/configs/keybinds-notch.conf" \
      "$HYPR_CONFIG_DIR/configs/keybinds-pill.conf" \
      "$HYPR_CONFIG_DIR/configs/keybinds-vanish.conf" \
      "$HYPR_CONFIG_DIR/current-mode-keybinds.lua" \
      "$HYPR_CONFIG_DIR/carbon-bar-mode.json" 2>/dev/null || true

if [[ -d "$HYPR_CONFIG_DIR/scripts" ]]; then
    for s in "$HYPR_CONFIG_DIR/scripts/carbon-"* "$HYPR_CONFIG_DIR/scripts/theme-mk.py"; do
        [[ -e "$s" ]] && rm -f "$s" || true
    done
    ok "Cleaned mirrored Carbon scripts from $HYPR_CONFIG_DIR/scripts"
fi

# 6. Remove Carbon CLI binaries from ~/.local/bin
CARBON_BINS=(
    "carbon-start"
    "carbon-shell"
    "carbon-update"
    "carbon-shell-update"
    "carbon-uninstall"
    "carbon-config-editor"
    "carbon-settings-hub"
    "carbon-pomodoro"
    "carbon-screenshot-full"
    "carbon-screenshot-full.sh"
    "carbon-screenshot-region"
    "carbon-screenshot-region.sh"
    "carbon-screenshot-window"
    "carbon-screenshot-window.sh"
    "carbon-drop"
    "carbon-focus"
    "carbon-radar"
    "carbon-hub-daemon"
)
REMOVED_BINS=0
for b in "${CARBON_BINS[@]}"; do
    if [[ -f "$BIN_DIR/$b" ]]; then
        rm -f "$BIN_DIR/$b"
        REMOVED_BINS=$((REMOVED_BINS + 1))
    fi
done
ok "Removed $REMOVED_BINS Carbon CLI utilities from $BIN_DIR"

# 7. Remove ~/.config/carbon (unless --keep-config was passed)
if [[ "$KEEP_CONFIG" -eq 1 ]]; then
    info "Preserved user configuration directory at $CONFIG_DIR (--keep-config)"
else
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        ok "Removed Carbon configuration directory ($CONFIG_DIR)"
    fi
fi

# 8. Reload Hyprland if active
if [[ "$NO_RELOAD" -eq 0 && "$DRY_RUN" -eq 0 ]] && command -v hyprctl >/dev/null 2>&1; then
    if hyprctl instances >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
        ok "Hyprland configuration reloaded"
    fi
fi

printf "\n"
msg "Carbon Shell has been uninstalled."
[[ -d "$FINAL_BACKUP_DIR" ]] && printf "   Safety Backup: %s\n\n" "$FINAL_BACKUP_DIR"
exit 0
