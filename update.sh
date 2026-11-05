#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${CARBON_CONFIG_DIR:-$HOME/.config/carbon}"
QUICKSHELL_DIR="$HOME/.local/share/quickshell/carbon"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
REPO_PATH_FILE="$CONFIG_DIR/repo_path"

FORCE=0
AUTO_YES=0
NO_RELOAD=0
CHECK_ONLY=0
ROLLBACK=0
BRANCH=""

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

usage() {
    cat << EOF
Usage: ./update.sh [OPTIONS]
   or: carbon-update [OPTIONS]

Options:
  -c, --check       Check for available updates without applying
  -y, --yes         Non-interactive mode
  -f, --force       Force update even if working tree has changes
  -b, --branch <b>  Pull from specified branch
  -r, --rollback    Restore previous safety backup
      --no-reload   Skip reloading services after update
  -h, --help        Show this message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -c|--check) CHECK_ONLY=1; shift ;;
        -r|--rollback|--restore) ROLLBACK=1; shift ;;
        -y|--yes) AUTO_YES=1; shift ;;
        -f|--force) FORCE=1; shift ;;
        -b|--branch) [[ -n "${2:-}" ]] || die "Option requires branch name"; BRANCH="$2"; shift 2 ;;
        --no-reload) NO_RELOAD=1; shift ;;
        *) die "Unknown option: $1" ;;
    esac
done

if [[ "$ROLLBACK" -eq 1 ]]; then
    BACKUP_DIR="$CONFIG_DIR/backups"
    LATEST="$(ls -1t "$BACKUP_DIR"/carbon-backup-*.tar.gz 2>/dev/null | head -n 1 || true)"
    [[ -z "$LATEST" || ! -f "$LATEST" ]] && die "No backup archive found in $BACKUP_DIR"
    msg "Restoring backup: $(basename "$LATEST")..."
    tar -xzf "$LATEST" -C "$HOME"
    ok "Rollback complete"
    if [[ "$NO_RELOAD" -eq 0 ]]; then
        systemctl --user restart carbon-quickshell.service 2>/dev/null || true
        command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
    fi
    exit 0
fi

create_safety_backup() {
    local bdir="$CONFIG_DIR/backups"
    local bfile="$bdir/carbon-backup-$(date +'%Y%m%d_%H%M%S').tar.gz"
    mkdir -p "$bdir"
    tar -czf "$bfile" -C "$HOME" ".local/share/quickshell/carbon" ".config/carbon" 2>/dev/null || true
    if [[ -f "$bfile" ]]; then
        ok "Safety backup created: $(basename "$bfile")"
        ls -1t "$bdir"/carbon-backup-*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f
    fi
}

printf "\n"
msg "Carbon Shell Updater"

REPO_DIR=""
if [[ -n "${CARBON_REPO_DIR:-}" && -d "$CARBON_REPO_DIR/.git" ]]; then
    REPO_DIR="$CARBON_REPO_DIR"
elif [[ -f "$REPO_PATH_FILE" ]]; then
    SAVED="$(head -n 1 "$REPO_PATH_FILE" 2>/dev/null || true)"
    [[ -n "$SAVED" && -d "$SAVED/.git" ]] && REPO_DIR="$SAVED"
fi

if [[ -z "$REPO_DIR" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -d "$SCRIPT_DIR/.git" && -f "$SCRIPT_DIR/quickshell/carbon/shell.qml" ]]; then
        REPO_DIR="$SCRIPT_DIR"
    elif [[ -d "$PWD/.git" && -f "$PWD/quickshell/carbon/shell.qml" ]]; then
        REPO_DIR="$PWD"
    fi
fi

if [[ -z "$REPO_DIR" ]]; then
    DEFAULT_CLONE="$HOME/.local/share/carbon-shell"
    if [[ -d "$DEFAULT_CLONE/.git" ]]; then
        REPO_DIR="$DEFAULT_CLONE"
    else
        if prompt_confirm "Clone repository to $DEFAULT_CLONE? [Y/n]: " "Y"; then
            mkdir -p "$(dirname "$DEFAULT_CLONE")"
            git clone "${CARBON_REMOTE_URL:-https://github.com/xzshogun/carbon-shell.git}" "$DEFAULT_CLONE"
            REPO_DIR="$DEFAULT_CLONE"
        else
            die "Cannot update without local repository."
        fi
    fi
    mkdir -p "$CONFIG_DIR"
    echo "$REPO_DIR" > "$REPO_PATH_FILE"
fi

info "Repository: $REPO_DIR"
cd "$REPO_DIR"

if [[ -n "$BRANCH" ]]; then
    git checkout "$BRANCH" 2>/dev/null || die "Could not checkout $BRANCH"
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
TRACKED_REMOTE="$(git config "branch.${CURRENT_BRANCH}.remote" 2>/dev/null || true)"
UPSTREAM="${TRACKED_REMOTE:-origin}"
git remote get-url "$UPSTREAM" >/dev/null 2>&1 || UPSTREAM="$(git remote 2>/dev/null | head -n 1 || echo "origin")"
REMOTE_TARGET="${BRANCH:-$CURRENT_BRANCH}"
git rev-parse --verify "$UPSTREAM/$REMOTE_TARGET" >/dev/null 2>&1 || REMOTE_TARGET="main"

git fetch "$UPSTREAM" "$REMOTE_TARGET" --quiet 2>/dev/null || warn "Could not reach remote repository."

LOCAL_HASH="$(git rev-parse HEAD 2>/dev/null || echo "")"
REMOTE_HASH="$(git rev-parse --verify "$UPSTREAM/$REMOTE_TARGET^{commit}" 2>/dev/null || echo "$LOCAL_HASH")"
COMMITS_AHEAD="$(git rev-list --count HEAD.."$UPSTREAM/$REMOTE_TARGET" 2>/dev/null || echo 0)"

if [[ "$COMMITS_AHEAD" -eq 0 ]]; then
    if [[ "$CHECK_ONLY" -eq 1 ]]; then
        ok "Carbon Shell is up to date (${LOCAL_HASH:0:8})"
        exit 0
    fi
    if [[ "$FORCE" -eq 0 ]]; then
        ok "Carbon Shell is already up to date (${LOCAL_HASH:0:8})"
        if ! prompt_confirm "Re-synchronize assets and restart services anyway? [y/N]: " "N"; then
            exit 0
        fi
    fi
else
    msg "Updates available ($COMMITS_AHEAD new commits):"
    printf "   Current: %s\n   Latest : %s\n\n" "${LOCAL_HASH:0:8}" "${REMOTE_HASH:0:8}"
    git log --oneline --no-merges -n 5 "HEAD..$UPSTREAM/$REMOTE_TARGET" 2>/dev/null | sed 's/^/   * /' || true
    printf "\n"
    [[ "$CHECK_ONLY" -eq 1 ]] && exit 0
    prompt_confirm "Apply updates now? [Y/n]: " "Y" || exit 0
fi

if [[ "$COMMITS_AHEAD" -gt 0 ]]; then
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        git add -A
        git commit -m "chore(local): auto-snapshot before update ($(date +'%Y-%m-%d %H:%M:%S'))" --quiet
    fi
    create_safety_backup

    if [[ "$CURRENT_BRANCH" != "$REMOTE_TARGET" ]]; then
        git merge --no-edit "$UPSTREAM/$REMOTE_TARGET" --quiet 2>/dev/null || {
            git merge --abort 2>/dev/null || true
            die "Merge conflict detected. Update aborted without modifying working branch."
        }
    else
        if git merge-base --is-ancestor HEAD "$REMOTE_HASH" 2>/dev/null; then
            git merge --ff-only "$REMOTE_HASH" --quiet
        else
            git merge --no-edit "$REMOTE_HASH" --quiet 2>/dev/null || git pull "$UPSTREAM" "$REMOTE_TARGET" --quiet
        fi
    fi
    ok "Working tree updated"
else
    create_safety_backup
fi

# Synchronize Quickshell components
msg "Updating Quickshell components..."
mkdir -p "$QUICKSHELL_DIR"
cp -rf "$REPO_DIR/quickshell/carbon/"* "$QUICKSHELL_DIR/"
chmod +x "$QUICKSHELL_DIR/scripts/"* 2>/dev/null || true
ok "Quickshell updated"

# Synchronize shell assets
if [[ -d "$REPO_DIR/assets" ]]; then
    mkdir -p "$CONFIG_DIR/assets"
    cp -rf "$REPO_DIR/assets/"* "$CONFIG_DIR/assets/" 2>/dev/null || true
    ok "Assets updated"
fi

# Synchronize runtime scripts & configs
msg "Updating configurations..."
mkdir -p "$CONFIG_DIR/scripts" "$CONFIG_DIR/configs"
echo "$REPO_DIR" > "$REPO_PATH_FILE"

cp -rf "$REPO_DIR/hypr/scripts/"* "$CONFIG_DIR/scripts/"
chmod +x "$CONFIG_DIR/scripts/"* 2>/dev/null || true

# Config templates: copy if missing, save .dist if exists
for src in "$REPO_DIR/hypr/configs/"*; do
    [[ -f "$src" ]] || continue
    name="$(basename "$src")"
    dst="$CONFIG_DIR/configs/$name"
    if [[ ! -f "$dst" ]]; then
        cp -f "$src" "$dst"
    else
        cp -f "$src" "$dst.dist" 2>/dev/null || true
    fi
done

for conf in windowrules.conf looknfeel.conf keybinds.conf keybinds-shell-only.conf vanish-keybinds.conf blur-exceptions.conf; do
    src="$REPO_DIR/hypr/$conf"
    dst="$CONFIG_DIR/$conf"
    if [[ -f "$src" ]]; then
        if [[ ! -f "$dst" ]]; then
            cp -f "$src" "$dst"
        else
            cp -f "$src" "$dst.dist" 2>/dev/null || true
        fi
    fi
done

for j in "$REPO_DIR/hypr/"*.json; do
    [[ -f "$j" ]] || continue
    target="$CONFIG_DIR/$(basename "$j")"
    [[ ! -f "$target" ]] && cp -f "$j" "$target"
done

# Synchronize binaries
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
chmod +x "$BIN_DIR/carbon-"* 2>/dev/null || true

# Refresh fonts
if [[ -d "$REPO_DIR/fonts" ]]; then
    mkdir -p "$HOME/.local/share/fonts"
    cp -f "$REPO_DIR/fonts/"*.ttf "$HOME/.local/share/fonts/" 2>/dev/null || true
fi

# Refresh mode keybinds
if [[ -f "$CONFIG_DIR/scripts/carbon-mode-keybinds.sh" ]]; then
    bash "$CONFIG_DIR/scripts/carbon-mode-keybinds.sh" >/dev/null 2>&1 || true
fi

# Build & deploy Rust apps
if command -v cargo >/dev/null 2>&1 && [[ -d "$REPO_DIR/apps" ]]; then
    msg "Compiling Carbon backend apps..."
    for app_dir in "$REPO_DIR/apps/"*; do
        if [[ -d "$app_dir" && -f "$app_dir/Cargo.toml" ]]; then
            (cd "$app_dir" && cargo build --release 2>/dev/null && cp -f target/release/carbon-* "$BIN_DIR/" 2>/dev/null) || true
        fi
    done
fi

# Reload services
if [[ "$NO_RELOAD" -eq 0 ]]; then
    if prompt_confirm "Restart Carbon Quickshell and reload Hyprland now? [Y/n]: " "Y"; then
        if command -v systemctl >/dev/null 2>&1 && systemctl --user is-enabled carbon-quickshell.service >/dev/null 2>&1; then
            systemctl --user restart carbon-quickshell.service >/dev/null 2>&1 || true
        else
            pkill -x quickshell 2>/dev/null || true
            sleep 0.5
            nohup quickshell --config "$QUICKSHELL_DIR" >/dev/null 2>&1 &
        fi
        command -v hyprctl >/dev/null 2>&1 && hyprctl reload >/dev/null 2>&1 || true
        ok "Services reloaded"
    fi
fi

printf "\n"
msg "Carbon Shell update complete!"
