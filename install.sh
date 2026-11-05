#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
HYPR_CONFIG_DIR="$HOME/.config/hypr"
QUICKSHELL_DIR="$HOME/.local/share/quickshell/carbon"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
DEFAULT_WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${HOME}/.config/carbon_backup_${TIMESTAMP}"

AUTO_YES=0
NO_DEPS=0
NO_RELOAD=0
KEYBIND_MODE=""
FORCE_CLI=0
FORCE_GUI=0
DRY_RUN=0

if [[ -t 1 ]]; then
    C_BLUE="\033[1;34m"; C_GREEN="\033[1;32m"; C_YELLOW="\033[1;33m"
    C_RED="\033[1;31m"; C_BOLD="\033[1m"; C_DIM="\033[2m"; C_RESET="\033[0m"
else
    C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""; C_DIM=""; C_RESET=""
fi

msg()    { printf "${C_BLUE}::${C_RESET} ${C_BOLD}%s${C_RESET}\n" "$*"; }
info()   { printf " ${C_GREEN}->${C_RESET} %s\n" "$*"; }
warn()   { printf " ${C_YELLOW}!${C_RESET} %s\n" "$*"; }
err()    { printf " ${C_RED}error:${C_RESET} %s\n" "$*" >&2; }
ok()     { printf "   ${C_GREEN}[✓]${C_RESET} %s\n" "$*"; }
fail()   { printf "   ${C_RED}[✗]${C_RESET} %s\n" "$*"; }
die()    { err "$@"; exit 1; }

prompt_confirm() {
    local prompt_msg="$1"
    local default_val="${2:-Y}"
    local choice=""

    if [[ "$AUTO_YES" -eq 1 || ! -t 0 ]]; then
        [[ "$default_val" =~ ^[Yy]$ ]] && return 0 || return 1
    fi

    printf "%s" "$prompt_msg" >&2
    read -r choice
    choice="${choice:-$default_val}"
    [[ "$choice" =~ ^[Yy]$ ]] && return 0 || return 1
}

prompt_choice() {
    local prompt_msg="$1"
    local default_val="$2"
    local choice=""

    if [[ "$AUTO_YES" -eq 1 || ! -t 0 ]]; then
        echo "$default_val"
        return
    fi

    printf "%s" "$prompt_msg" >&2
    read -r choice
    echo "${choice:-$default_val}"
}

usage() {
    cat << EOF
Usage: ./install.sh [OPTIONS]

Options:
  --gui                Launch GTK4 Libadwaita installer
  --cli                Force CLI installer
  --dry-run            Simulate installation in /tmp/carbon-sandbox
  -u, --update         Run updater (./update.sh)
  -y, --yes            Non-interactive mode (accept defaults)
      --keybinds=MODE  Keybinding mode: 'keep' (default) or 'carbon'
      --no-deps        Skip dependency checks
      --no-reload      Do not reload services after install
  -h, --help           Show this message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        --gui) FORCE_GUI=1; shift ;;
        --cli) FORCE_CLI=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -u|--update)
            if [[ -x "$REPO_DIR/update.sh" ]]; then
                exec "$REPO_DIR/update.sh" "${@:2}"
            else
                die "Updater script not found."
            fi
            ;;
        -y|--yes) AUTO_YES=1; FORCE_CLI=1; shift ;;
        --keybinds=*) KEYBIND_MODE="${1#*=}"; shift ;;
        --keybinds) KEYBIND_MODE="$2"; shift 2 ;;
        --no-deps) NO_DEPS=1; shift ;;
        --no-reload) NO_RELOAD=1; shift ;;
        *) die "Unknown option: $1" ;;
    esac
done

if [[ "$DRY_RUN" -eq 1 ]]; then
    CONFIG_DIR="/tmp/carbon-sandbox/carbon"
    HYPR_CONFIG_DIR="/tmp/carbon-sandbox/hypr"
    QUICKSHELL_DIR="/tmp/carbon-sandbox/quickshell"
    BIN_DIR="/tmp/carbon-sandbox/bin"
    SYSTEMD_USER_DIR="/tmp/carbon-sandbox/systemd"
    DEFAULT_WALLPAPER_DIR="/tmp/carbon-sandbox/wallpapers"
    NO_RELOAD=1
    warn "Running in sandbox mode (/tmp/carbon-sandbox)"
fi

# Launch GUI installer if display is available and not in CLI mode
if [[ "$FORCE_CLI" -eq 0 && ("$FORCE_GUI" -eq 1 || -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}") ]]; then
    if [[ -f "$REPO_DIR/install-gui.py" ]] && python3 -c "import gi; gi.require_version('Gtk', '4.0'); gi.require_version('Adw', '1')" 2>/dev/null; then
        exec python3 "$REPO_DIR/install-gui.py" "$@"
    fi
fi

printf "\n"
msg "Carbon Shell Installer"
printf "   Repository: %s\n" "$REPO_DIR"
printf "   Target:     %s\n\n" "$CONFIG_DIR"

if [[ -d "$CONFIG_DIR" && -z "$KEYBIND_MODE" && "$AUTO_YES" -eq 0 ]]; then
    warn "Existing Carbon Shell installation detected at $CONFIG_DIR"
    printf "  [1] Update existing installation\n"
    printf "  [2] Reinstall / Fresh setup\n"
    printf "  [3] Cancel\n\n"
    EXISTING_CHOICE="$(prompt_choice "  Select option [1-3] (Default: 1): " "1")"
    case "$EXISTING_CHOICE" in
        1) exec "$REPO_DIR/update.sh" ;;
        2) info "Proceeding with fresh installation." ;;
        *) info "Cancelled."; exit 0 ;;
    esac
fi

# Dependency check
if [[ "$NO_DEPS" -eq 0 ]]; then
    msg "Checking dependencies..."
    CORE_DEPS=(
        "hyprland" "quickshell" "python3" "playerctl"
        "brightnessctl" "grim" "slurp" "socat" "jq" "fastfetch"
    )
    MISSING=()
    for cmd in "${CORE_DEPS[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            ok "$cmd"
        else
            MISSING+=("$cmd")
            fail "$cmd"
        fi
    done

    for mod in "PIL" "gi"; do
        if python3 -c "import $mod" >/dev/null 2>&1; then
            ok "python module: $mod"
        else
            MISSING+=("python-$mod")
            fail "python module: $mod"
        fi
    done

    if [[ ${#MISSING[@]} -gt 0 ]]; then
        warn "Missing dependencies: ${MISSING[*]}"
        if prompt_confirm "Install missing packages with pacman/yay? [Y/n]: " "Y"; then
            PKGS=(hyprland quickshell python python-pillow python-gobject gtk4 libadwaita cava playerctl brightnessctl grim slurp socat jq fastfetch pipewire wireplumber ttf-jetbrains-mono-nerd)
            if command -v yay >/dev/null 2>&1; then
                yay -S --needed --noconfirm "${PKGS[@]}" || true
            else
                sudo pacman -S --needed --noconfirm "${PKGS[@]}" || true
            fi
        fi
    fi
fi

# Backup existing config
if [[ -d "$CONFIG_DIR" || -d "$QUICKSHELL_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
    [[ -d "$CONFIG_DIR" ]] && cp -rf "$CONFIG_DIR" "$BACKUP_DIR/carbon_config"
    [[ -d "$QUICKSHELL_DIR" ]] && cp -rf "$QUICKSHELL_DIR" "$BACKUP_DIR/quickshell_carbon"
    ok "Created backup at $BACKUP_DIR"
fi

# Keybinding mode selection
if [[ -z "$KEYBIND_MODE" ]]; then
    printf "\n  Select keybinding profile:\n"
    printf "    [1] Keep Existing Keybindings (Recommended - Shell only)\n"
    printf "    [2] Full Carbon Keybindings\n\n"
    KB_CHOICE="$(prompt_choice "  Select profile [1/2] (Default: 1): " "1")"
    [[ "$KB_CHOICE" == "2" ]] && KEYBIND_MODE="carbon" || KEYBIND_MODE="keep"
fi
info "Keybinding profile: $KEYBIND_MODE"

# Deploy files to ~/.config/carbon
msg "Deploying configuration to $CONFIG_DIR..."
mkdir -p "$CONFIG_DIR/scripts" "$CONFIG_DIR/configs" "$HYPR_CONFIG_DIR/configs"
echo "$REPO_DIR" > "$CONFIG_DIR/repo_path"

cp -rf "$REPO_DIR/hypr/scripts/"* "$CONFIG_DIR/scripts/"
chmod +x "$CONFIG_DIR/scripts/"* 2>/dev/null || true

cp -rf "$REPO_DIR/hypr/configs/"* "$CONFIG_DIR/configs/"
cp -rf "$REPO_DIR/hypr/configs/"* "$HYPR_CONFIG_DIR/configs/" 2>/dev/null || true

for j in "$REPO_DIR/hypr/"*.json; do
    [[ -f "$j" ]] || continue
    target="$CONFIG_DIR/$(basename "$j")"
    [[ ! -f "$target" ]] && cp -f "$j" "$target"
done

for conf in blur-exceptions.conf cava-island.conf cava-lock.conf power.conf hypridle.conf hyprlock.conf colors.conf windowrules.conf looknfeel.conf keybinds.conf keybinds-shell-only.conf; do
    src="$REPO_DIR/hypr/$conf"
    dst="$CONFIG_DIR/$conf"
    [[ -f "$src" && ! -f "$dst" ]] && cp -f "$src" "$dst"
done

if [[ ! -f "$CONFIG_DIR/carbon-bar-mode.json" ]]; then
    cat << 'EOF' > "$CONFIG_DIR/carbon-bar-mode.json"
{
  "mode": "minimal_notch",
  "islandStyle": "minimal",
  "islandPersistent": true,
  "wallpaperAnimation": "cinematic",
  "wallpaperDuration": 800,
  "nucleus": {
    "transition": true,
    "transitionWord": "Wooshh!!"
  }
}
EOF
fi

KB_FILE="keybinds-shell-only.conf"
[[ "$KEYBIND_MODE" == "carbon" ]] && KB_FILE="keybinds.conf"

cat << EOF > "$CONFIG_DIR/carbon.conf"
env = CARBON_CONFIG_DIR,\$HOME/.config/carbon
env = PATH,\$HOME/.local/bin:\$PATH

source = ~/.config/carbon/colors.conf
source = ~/.config/carbon/windowrules.conf
source = ~/.config/carbon/$KB_FILE
source = ~/.config/carbon/configs/vanish-keybinds.conf

cursor {
    no_warps = true
}

exec-once = systemctl --user start carbon-quickshell.service
exec-once = bash -c 'wl-paste --watch cliphist store'
exec-once = bash -c 'wl-paste --type image --watch cliphist store'
EOF
ok "Generated $CONFIG_DIR/carbon.conf"

# Integrate with Hyprland without overwriting
HYPR_MAIN="$HYPR_CONFIG_DIR/hyprland.conf"
CARBON_SRC="source = ~/.config/carbon/carbon.conf"
if [[ -f "$HYPR_MAIN" ]]; then
    if ! grep -Fq "$CARBON_SRC" "$HYPR_MAIN"; then
        cp -f "$HYPR_MAIN" "$HYPR_MAIN.backup_$TIMESTAMP"
        printf "\n# Carbon Shell Integration\n%s\n" "$CARBON_SRC" >> "$HYPR_MAIN"
        ok "Safely appended source entry to $HYPR_MAIN"
    else
        ok "Carbon Shell already sourced in $HYPR_MAIN"
    fi
else
    mkdir -p "$HYPR_CONFIG_DIR"
    printf "# Hyprland Main Configuration\n%s\n" "$CARBON_SRC" > "$HYPR_MAIN"
    ok "Created starter $HYPR_MAIN"
fi

# Deploy Quickshell assets
msg "Deploying Quickshell assets..."
mkdir -p "$QUICKSHELL_DIR"
cp -rf "$REPO_DIR/quickshell/carbon/"* "$QUICKSHELL_DIR/"
chmod +x "$QUICKSHELL_DIR/scripts/"* 2>/dev/null || true
ok "Quickshell components deployed"

# Deploy shell assets
if [[ -d "$REPO_DIR/assets" ]]; then
    mkdir -p "$CONFIG_DIR/assets"
    cp -rf "$REPO_DIR/assets/"* "$CONFIG_DIR/assets/" 2>/dev/null || true
    ok "Shell assets deployed"
fi

# Install fonts
if [[ -d "$REPO_DIR/fonts" ]]; then
    USER_FONT_DIR="$HOME/.local/share/fonts"
    mkdir -p "$USER_FONT_DIR"
    cp -f "$REPO_DIR/fonts/"*.ttf "$USER_FONT_DIR/" 2>/dev/null || true
    command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null 2>&1 || true
fi

# Deploy user binaries
mkdir -p "$BIN_DIR"
[[ -f "$REPO_DIR/update.sh" ]] && cp -f "$REPO_DIR/update.sh" "$BIN_DIR/carbon-update"
[[ -f "$CONFIG_DIR/scripts/carbon-config-editor" ]] && cp -f "$CONFIG_DIR/scripts/carbon-config-editor" "$BIN_DIR/carbon-config-editor"
[[ -f "$CONFIG_DIR/scripts/carbon-pomodoro" ]] && cp -f "$CONFIG_DIR/scripts/carbon-pomodoro" "$BIN_DIR/carbon-pomodoro"

for s in "$CONFIG_DIR/scripts/carbon-screenshot-"*.sh; do
    if [[ -f "$s" ]]; then
        base="$(basename "$s" .sh)"
        cp -f "$s" "$BIN_DIR/$base"
        cp -f "$s" "$BIN_DIR/$base.sh"
    fi
done

# Build & deploy Rust apps
if command -v cargo >/dev/null 2>&1 && [[ -d "$REPO_DIR/apps" ]]; then
    msg "Compiling Carbon backend apps..."
    for app_dir in "$REPO_DIR/apps/"*; do
        if [[ -d "$app_dir" && -f "$app_dir/Cargo.toml" ]]; then
            (cd "$app_dir" && cargo build --release 2>/dev/null && cp -f target/release/carbon-* "$BIN_DIR/" 2>/dev/null) || true
        fi
    done
fi

chmod +x "$BIN_DIR/carbon-"* 2>/dev/null || true

# Systemd user service
if [[ -f "$REPO_DIR/systemd/carbon-quickshell.service" ]]; then
    mkdir -p "$SYSTEMD_USER_DIR"
    cp -f "$REPO_DIR/systemd/carbon-quickshell.service" "$SYSTEMD_USER_DIR/"
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        systemctl --user enable carbon-quickshell.service >/dev/null 2>&1 || true
    fi
fi

# Default wallpaper & initial theme
DEFAULT_WP_SRC="$REPO_DIR/assets/wallpapers/default.png"
DEFAULT_WP_DEST="$DEFAULT_WALLPAPER_DIR/wallhaven-6ly7yw.png"
if [[ -f "$DEFAULT_WP_SRC" && ! -f "$CONFIG_DIR/current_wallpaper" ]]; then
    mkdir -p "$DEFAULT_WALLPAPER_DIR"
    [[ ! -f "$DEFAULT_WP_DEST" ]] && cp -f "$DEFAULT_WP_SRC" "$DEFAULT_WP_DEST"
    ln -sfn "$DEFAULT_WP_DEST" "$CONFIG_DIR/current_wallpaper"
    echo "$DEFAULT_WP_DEST" > "$CONFIG_DIR/current_wallpaper_path"
    if [[ -f "$CONFIG_DIR/scripts/theme-mk.py" ]]; then
        python3 "$CONFIG_DIR/scripts/theme-mk.py" >/dev/null 2>&1 || true
    fi
fi

# Activate initial mode keybinds
if [[ -f "$CONFIG_DIR/scripts/carbon-mode-keybinds.sh" ]]; then
    bash "$CONFIG_DIR/scripts/carbon-mode-keybinds.sh" minimal_notch >/dev/null 2>&1 || true
fi

printf "\n"
msg "Installation complete!"
printf "   Configuration: %s\n" "$CONFIG_DIR"
printf "   Settings GUI : Super + C (or carbon-config-editor)\n"
printf "   Updater      : carbon-update (or ./update.sh)\n\n"

if [[ "$NO_RELOAD" -eq 0 ]]; then
    if prompt_confirm "Start Carbon Quickshell and reload Hyprland now? [Y/n]: " "Y"; then
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user restart carbon-quickshell.service >/dev/null 2>&1 || true
        fi
        if command -v hyprctl >/dev/null 2>&1; then
            hyprctl reload >/dev/null 2>&1 || true
        fi
        ok "Services restarted"
    fi
fi
