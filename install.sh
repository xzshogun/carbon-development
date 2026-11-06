#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
HYPR_CONFIG_DIR="${CARBON_HYPR_DIR:-$HOME/.config/hypr}"
QUICKSHELL_DIR="$HOME/.local/share/quickshell/carbon"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
USER_FONT_DIR="$HOME/.local/share/fonts"
DEFAULT_WALLPAPER_DIR="$HOME/Pictures/Wallpapers"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${HOME}/.config/carbon_backup_${TIMESTAMP}"

# Staging / Development Repository Configuration (xzshogun/carbon-development)
STAGING_SERVER_URL="https://ais-pre-clqdsggkf7wyqbb7b7z654-900258437217.asia-east1.run.app"
DEFAULT_GITHUB_DEV_URL="https://github.com/xzshogun/carbon-development.git"
DEFAULT_REMOTE_URL="${CARBON_REMOTE_URL:-$DEFAULT_GITHUB_DEV_URL}"
DEFAULT_TARBALL_URL="${CARBON_TARBALL_URL:-$STAGING_SERVER_URL/carbon-shell-dev.tar.gz}"
REMOTE_URL="$DEFAULT_REMOTE_URL"

AUTO_YES=0
NO_DEPS=0
NO_RELOAD=0
KEYBIND_MODE=""
SHELL_MODE=""
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
  -x, --uninstall      Run uninstaller (./uninstall.sh)
  -s, --start          Start or restart Carbon Shell (./start.sh)
  -y, --yes            Non-interactive mode (accept defaults)
      --keybinds=MODE  Keybinding mode: 'keep' (default) or 'carbon'
      --mode=MODE      Initial shell mode: 'minimal_notch' (default), 'notch', 'pill', or 'vanish'
      --repo=URL       Set staging/dev repository URL for updates (default: $DEFAULT_REMOTE_URL)
      --no-deps        Skip dependency checks
      --no-reload      Do not reload services after install
  -h, --help           Show this message
EOF
    exit 0
}

ORIG_ARGS=("$@")
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        --gui) FORCE_GUI=1; shift ;;
        --cli) FORCE_CLI=1; shift ;;
        --dry-run) DRY_RUN=1; shift ;;
        -u|--update)
            if [[ -f "$REPO_DIR/update.sh" ]]; then
                exec bash "$REPO_DIR/update.sh" "${@:2}"
            else
                die "Updater script not found."
            fi
            ;;
        -x|--uninstall)
            if [[ -f "$REPO_DIR/uninstall.sh" ]]; then
                exec bash "$REPO_DIR/uninstall.sh" "${@:2}"
            else
                die "Uninstaller script not found."
            fi
            ;;
        -s|--start)
            if [[ -f "$REPO_DIR/start.sh" ]]; then
                exec bash "$REPO_DIR/start.sh" "${@:2}"
            else
                die "Launcher script not found."
            fi
            ;;
        -y|--yes) AUTO_YES=1; FORCE_CLI=1; shift ;;
        --keybinds=*) KEYBIND_MODE="${1#*=}"; shift ;;
        --keybinds) KEYBIND_MODE="$2"; shift 2 ;;
        --mode=*) SHELL_MODE="${1#*=}"; shift ;;
        --mode) SHELL_MODE="$2"; shift 2 ;;
        --repo=*) REMOTE_URL="${1#*=}"; shift ;;
        --repo|-R) REMOTE_URL="$2"; shift 2 ;;
        --no-deps) NO_DEPS=1; shift ;;
        --no-reload) NO_RELOAD=1; shift ;;
        *) die "Unknown option: $1" ;;
    esac
done

# If install.sh is invoked standalone without a local checkout, bootstrap into ~/.local/share/carbon-development
if [[ ! -f "$REPO_DIR/quickshell/carbon/shell.qml" && "$DRY_RUN" -eq 0 ]]; then
    BOOTSTRAP_DIR="$HOME/.local/share/carbon-development"
    msg "Bootstrapping Carbon Shell (xzshogun/carbon-development) into $BOOTSTRAP_DIR..."
    mkdir -p "$BOOTSTRAP_DIR"
    if command -v git >/dev/null 2>&1 && git clone "$REMOTE_URL" "$BOOTSTRAP_DIR" 2>/dev/null; then
        ok "Cloned repository from $REMOTE_URL"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "$DEFAULT_TARBALL_URL" | tar -xz -C "$BOOTSTRAP_DIR"
        ok "Downloaded staging tarball from $DEFAULT_TARBALL_URL"
    else
        die "Could not download repository. Please install git or curl."
    fi
    REPO_DIR="$BOOTSTRAP_DIR"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
    SANDBOX_ROOT="${CARBON_SANDBOX_DIR:-/tmp/carbon-sandbox}"
    CONFIG_DIR="$SANDBOX_ROOT/carbon"
    HYPR_CONFIG_DIR="$SANDBOX_ROOT/hypr"
    QUICKSHELL_DIR="$SANDBOX_ROOT/quickshell"
    BIN_DIR="$SANDBOX_ROOT/bin"
    SYSTEMD_USER_DIR="$SANDBOX_ROOT/systemd"
    USER_FONT_DIR="$SANDBOX_ROOT/fonts"
    DEFAULT_WALLPAPER_DIR="$SANDBOX_ROOT/wallpapers"
    BACKUP_DIR="$SANDBOX_ROOT/backups/carbon_backup_${TIMESTAMP}"
    NO_RELOAD=1
    if [[ "$FORCE_GUI" -eq 0 ]]; then
        FORCE_CLI=1
    fi
    warn "Running in sandbox mode ($SANDBOX_ROOT)"
fi

# Launch GUI installer if display is available and not in CLI mode
if [[ "$FORCE_CLI" -eq 0 && ("$FORCE_GUI" -eq 1 || -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}") ]]; then
    if [[ -f "$REPO_DIR/install-gui.py" ]] && python3 -c "import gi; gi.require_version('Gtk', '4.0'); gi.require_version('Adw', '1')" 2>/dev/null; then
        exec python3 "$REPO_DIR/install-gui.py" "${ORIG_ARGS[@]}"
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
        1)
            if [[ "$DRY_RUN" -eq 1 ]]; then
                exec "$REPO_DIR/update.sh" --dry-run
            else
                exec "$REPO_DIR/update.sh"
            fi
            ;;
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

    if [[ ${#MISSING[@]} -gt 0 && "$DRY_RUN" -eq 0 ]]; then
        warn "Missing dependencies: ${MISSING[*]}"
        if prompt_confirm "Install missing packages with pacman/yay? [Y/n]: " "Y"; then
            PKGS=(hyprland quickshell python python-pillow python-gobject gtk4 libadwaita cava playerctl brightnessctl grim slurp socat jq fastfetch pipewire wireplumber ttf-jetbrains-mono-nerd)
            if command -v yay >/dev/null 2>&1; then
                yay -S --needed --noconfirm "${PKGS[@]}" || true
            elif command -v pacman >/dev/null 2>&1; then
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
    printf "    [1] Keep Existing Keybindings (Recommended - Shell triggers + Mode keybinds)\n"
    printf "    [2] Full Carbon Keybindings (Standalone desktop + Mode keybinds)\n\n"
    KB_CHOICE="$(prompt_choice "  Select profile [1/2] (Default: 1): " "1")"
    [[ "$KB_CHOICE" == "2" ]] && KEYBIND_MODE="carbon" || KEYBIND_MODE="keep"
fi
info "Keybinding profile: $KEYBIND_MODE"

# Initial shell mode selection
if [[ -z "$SHELL_MODE" ]]; then
    if [[ "$AUTO_YES" -eq 1 || ! -t 0 ]]; then
        SHELL_MODE="minimal_notch"
    else
        printf "\n  Select initial shell mode:\n"
        printf "    [1] Minimal Island / Tide (Default)\n"
        printf "    [2] Carbon Notch\n"
        printf "    [3] Pill Bar\n"
        printf "    [4] Vanish Hub (Nucleus)\n\n"
        MODE_CHOICE="$(prompt_choice "  Select mode [1-4] (Default: 1): " "1")"
        case "$MODE_CHOICE" in
            2) SHELL_MODE="notch" ;;
            3) SHELL_MODE="pill" ;;
            4) SHELL_MODE="vanish" ;;
            *) SHELL_MODE="minimal_notch" ;;
        esac
    fi
fi

# Normalize SHELL_MODE for JSON state
case "${SHELL_MODE,,}" in
    notch|island) BAR_JSON_MODE="notch"; ISLAND_STYLE="notch" ;;
    pill|waybar) BAR_JSON_MODE="pill"; ISLAND_STYLE="pill" ;;
    vanish|nucleus) BAR_JSON_MODE="nucleus"; ISLAND_STYLE="nucleus" ;;
    *) BAR_JSON_MODE="minimal_notch"; ISLAND_STYLE="minimal" ;;
esac
info "Initial shell mode: $BAR_JSON_MODE"

# Deploy files to ~/.config/carbon (and mirror scripts/configs to ~/.config/hypr for compatibility)
msg "Deploying configuration to $CONFIG_DIR..."
mkdir -p "$CONFIG_DIR/scripts" "$CONFIG_DIR/configs" "$HYPR_CONFIG_DIR/configs" "$HYPR_CONFIG_DIR/scripts"
echo "$REPO_DIR" > "$CONFIG_DIR/repo_path"
cat << EOF > "$CONFIG_DIR/carbon-repo.json"
{
  "channel": "dev",
  "remoteUrl": "$REMOTE_URL",
  "tarballUrl": "$DEFAULT_TARBALL_URL",
  "githubDevUrl": "$DEFAULT_GITHUB_DEV_URL",
  "branch": "main",
  "localPath": "$REPO_DIR"
}
EOF

cp -rf "$REPO_DIR/hypr/scripts/"* "$CONFIG_DIR/scripts/"
chmod +x "$CONFIG_DIR/scripts/"* 2>/dev/null || true

cp -rf "$REPO_DIR/hypr/scripts/"* "$HYPR_CONFIG_DIR/scripts/" 2>/dev/null || true
chmod +x "$HYPR_CONFIG_DIR/scripts/"* 2>/dev/null || true

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

cat << EOF > "$CONFIG_DIR/carbon-bar-mode.json"
{
  "mode": "$BAR_JSON_MODE",
  "islandStyle": "$ISLAND_STYLE",
  "islandPersistent": true,
  "wallpaperAnimation": "cinematic",
  "wallpaperDuration": 800,
  "nucleus": {
    "transition": true,
    "transitionWord": "Wooshh!!"
  }
}
EOF
cp -f "$CONFIG_DIR/carbon-bar-mode.json" "$HYPR_CONFIG_DIR/carbon-bar-mode.json" 2>/dev/null || true

KB_FILE="keybinds-shell-only.conf"
[[ "$KEYBIND_MODE" == "carbon" ]] && KB_FILE="keybinds.conf"

cat << EOF > "$CONFIG_DIR/carbon.conf"
env = CARBON_CONFIG_DIR,\$HOME/.config/carbon
env = PATH,\$HOME/.local/bin:\$PATH

source = ~/.config/carbon/colors.conf
source = ~/.config/carbon/windowrules.conf
source = ~/.config/carbon/blur-exceptions.conf
source = ~/.config/carbon/power.conf
source = ~/.config/carbon/$KB_FILE
source = ~/.config/carbon/configs/current-mode-keybinds.conf

input {
    touchpad {
        natural_scroll = true
        disable_while_typing = true
        tap-to-click = true
    }
}

cursor {
    no_warps = true
}

general {
    snap {
        enabled = true
    }
}

exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE QT_QPA_PLATFORM
exec-once = systemctl --user start carbon-quickshell.service
exec-once = systemctl --user start carbon-hub.service
exec-once = bash -c 'wl-paste --watch cliphist store'
exec-once = bash -c 'wl-paste --type image --watch cliphist store'
exec-once = hypridle -c ~/.config/carbon/hypridle.conf
exec-once = ~/.config/carbon/scripts/portal.sh
exec-once = ~/.config/carbon/scripts/carbon-audio-init.sh
exec-once = ~/.config/carbon/scripts/carbon-snap-top.sh
exec = ~/.config/carbon/scripts/carbon-gestures-init.sh
EOF
ok "Generated $CONFIG_DIR/carbon.conf (Base: $KB_FILE + isolated mode keybinds + touchpad gestures)"

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
if [[ "$DRY_RUN" -eq 0 ]]; then
    mkdir -p "$HOME/.config/quickshell" 2>/dev/null || true
    ln -sfn "$QUICKSHELL_DIR" "$HOME/.config/quickshell/carbon" 2>/dev/null || true
fi
ok "Quickshell components deployed"

# Deploy shell assets
if [[ -d "$REPO_DIR/assets" ]]; then
    mkdir -p "$CONFIG_DIR/assets"
    cp -rf "$REPO_DIR/assets/"* "$CONFIG_DIR/assets/" 2>/dev/null || true
    ok "Shell assets deployed"
fi

# Install fonts
if [[ -d "$REPO_DIR/fonts" ]]; then
    mkdir -p "$USER_FONT_DIR"
    cp -f "$REPO_DIR/fonts/"*.ttf "$USER_FONT_DIR/" 2>/dev/null || true
    if [[ "$DRY_RUN" -eq 0 ]] && command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi
    ok "Fonts installed to $USER_FONT_DIR"
fi

# Deploy user binaries
mkdir -p "$BIN_DIR"
if [[ -f "$REPO_DIR/carbon-update" ]]; then
    cp -f "$REPO_DIR/carbon-update" "$BIN_DIR/carbon-update"
    cp -f "$REPO_DIR/carbon-update" "$BIN_DIR/carbon-shell-update"
elif [[ -f "$REPO_DIR/update.sh" ]]; then
    cp -f "$REPO_DIR/update.sh" "$BIN_DIR/carbon-update"
    cp -f "$REPO_DIR/update.sh" "$BIN_DIR/carbon-shell-update"
fi
if [[ -f "$REPO_DIR/start.sh" ]]; then
    cp -f "$REPO_DIR/start.sh" "$BIN_DIR/carbon-start"
    cp -f "$REPO_DIR/start.sh" "$BIN_DIR/carbon-shell"
fi
if [[ -f "$REPO_DIR/uninstall.sh" ]]; then
    cp -f "$REPO_DIR/uninstall.sh" "$BIN_DIR/carbon-uninstall"
fi
[[ -f "$CONFIG_DIR/scripts/carbon-config-editor" ]] && cp -f "$CONFIG_DIR/scripts/carbon-config-editor" "$BIN_DIR/carbon-config-editor"
[[ -f "$CONFIG_DIR/scripts/carbon-settings-hub" ]] && cp -f "$CONFIG_DIR/scripts/carbon-settings-hub" "$BIN_DIR/carbon-settings-hub"
[[ -f "$CONFIG_DIR/scripts/carbon-pomodoro" ]] && cp -f "$CONFIG_DIR/scripts/carbon-pomodoro" "$BIN_DIR/carbon-pomodoro"

for s in "$CONFIG_DIR/scripts/carbon-screenshot-"*.sh; do
    if [[ -f "$s" ]]; then
        base="$(basename "$s" .sh)"
        cp -f "$s" "$BIN_DIR/$base"
        cp -f "$s" "$BIN_DIR/$base.sh"
    fi
done

# Build & deploy Rust apps and backend daemons (skip compilation during fast --no-deps sandbox runs)
if [[ "$NO_DEPS" -eq 0 ]] && command -v cargo >/dev/null 2>&1; then
    msg "Compiling Carbon apps & backend daemons..."
    for rust_root in "$REPO_DIR/apps" "$REPO_DIR/backend"; do
        [[ -d "$rust_root" ]] || continue
        for app_dir in "$rust_root/"*; do
            if [[ -d "$app_dir" && -f "$app_dir/Cargo.toml" ]]; then
                (cd "$app_dir" && cargo build --release 2>/dev/null && find target/release -maxdepth 1 -type f -executable -exec cp -f {} "$BIN_DIR/" \; 2>/dev/null) || true
            fi
        done
    done
fi

chmod +x "$BIN_DIR/carbon-"* 2>/dev/null || true

# Systemd user services
mkdir -p "$SYSTEMD_USER_DIR"
for srv in carbon-quickshell.service carbon-hub.service; do
    if [[ -f "$REPO_DIR/systemd/$srv" ]]; then
        cp -f "$REPO_DIR/systemd/$srv" "$SYSTEMD_USER_DIR/"
    fi
done
if [[ "$DRY_RUN" -eq 0 ]] && command -v systemctl >/dev/null 2>&1; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user enable carbon-quickshell.service >/dev/null 2>&1 || true
    systemctl --user enable carbon-hub.service >/dev/null 2>&1 || true
fi

# Default wallpaper & initial theme
DEFAULT_WP_SRC="$REPO_DIR/assets/wallpapers/default.png"
DEFAULT_WP_DEST="$DEFAULT_WALLPAPER_DIR/wallhaven-6ly7yw.png"
if [[ -f "$DEFAULT_WP_SRC" && ! -f "$CONFIG_DIR/current_wallpaper" ]]; then
    mkdir -p "$DEFAULT_WALLPAPER_DIR"
    [[ ! -f "$DEFAULT_WP_DEST" ]] && cp -f "$DEFAULT_WP_SRC" "$DEFAULT_WP_DEST"
    cp -f "$DEFAULT_WP_DEST" "$CONFIG_DIR/current_wallpaper"
    cp -f "$DEFAULT_WP_DEST" "$HYPR_CONFIG_DIR/current_wallpaper" 2>/dev/null || true
    echo "$DEFAULT_WP_DEST" > "$CONFIG_DIR/current_wallpaper_path"
    if [[ "$DRY_RUN" -eq 0 && -f "$CONFIG_DIR/scripts/theme-mk.py" ]]; then
        CARBON_CONFIG_DIR="$CONFIG_DIR" python3 "$CONFIG_DIR/scripts/theme-mk.py" "$DEFAULT_WP_DEST" >/dev/null 2>&1 || true
    fi
fi

# Activate initial mode keybinds
if [[ -f "$CONFIG_DIR/scripts/carbon-mode-keybinds.sh" ]]; then
    CARBON_CONFIG_DIR="$CONFIG_DIR" CARBON_HYPR_DIR="$HYPR_CONFIG_DIR" CARBON_NO_RELOAD="$NO_RELOAD" \
        bash "$CONFIG_DIR/scripts/carbon-mode-keybinds.sh" "$BAR_JSON_MODE" >/dev/null 2>&1 || true
    ok "Activated isolated mode keybinds for: $BAR_JSON_MODE"
fi

printf "\n"
msg "Installation complete!"
printf "   Configuration: %s\n" "$CONFIG_DIR"
printf "   Active Mode  : %s\n" "$BAR_JSON_MODE"
printf "   Keybind Base : %s\n" "$KEYBIND_MODE"
printf "   Start Shell  : carbon-start (or ./start.sh)\n"
printf "   Settings Hub : Super + Shift + C (or carbon-settings-hub)\n"
printf "   Config GUI   : Super + C (or carbon-config-editor)\n"
printf "   Focus Mode   : Super + K (or ~/.config/carbon/scripts/carbon-focus.sh)\n"
printf "   Updater      : carbon-update (or ./update.sh)\n"
printf "   Uninstaller  : carbon-uninstall (or ./uninstall.sh)\n\n"

if [[ "$NO_RELOAD" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
    if prompt_confirm "Start Carbon Quickshell and reload Hyprland now? [Y/n]: " "Y"; then
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user restart carbon-quickshell.service >/dev/null 2>&1 || true
            systemctl --user restart carbon-hub.service >/dev/null 2>&1 || true
        fi
        if command -v hyprctl >/dev/null 2>&1; then
            hyprctl reload >/dev/null 2>&1 || true
        fi
        ok "Services restarted"
    fi
fi
