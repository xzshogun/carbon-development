# Carbon Shell — Full Architecture Review, Sandbox Audit & External Mode Isolation Plan

This plan presents the complete audit of the Carbon Shell setup (Installer, Updater, Hyprland integration, and Quickshell runtime), details the bugs discovered during static and sandbox analysis, and outlines the remediation to make Carbon Shell 100% externalized and portable across machines with isolated per-mode keybindings, alongside a live Sandbox Test Runner & Audit Dashboard served on port 3000.

## User Review & Critical Decisions

> [!IMPORTANT]
> Below is the complete diagnosis of the installer, updater, and shell structure issues found during our review, followed by the architectural plan to make every shell mode (`minimal_notch`, `notch`, `pill`, `vanish`) cleanly separated with its own default keybindings during installation and runtime switching.

- **Confirmed Decision 1 — Fully Externalized Shell Configuration**: All Carbon Shell runtime configs, scripts, assets, and active mode keybinds will reside inside the isolated Carbon configuration directory (`~/.config/carbon`), requiring only a single non-destructive `source = ~/.config/carbon/carbon.conf` line in the host's Hyprland config.
- **Confirmed Decision 2 — Separate Per-Mode Default Keybindings**: All four shell modes (`Minimal Island / Tide`, `Carbon Notch`, `Pill Bar`, and `Vanish / Nucleus`) will maintain separate, isolated keybinding definitions that are automatically activated at install time and hot-swapped whenever the user switches modes, preventing cross-mode key collisions before custom keybind editing is added later.
- **Confirmed Decision 3 — Live Sandbox Test Runner on Port 3000**: To fix the AI Studio dev server startup error without polluting the repository with Node/npm files, a Python FastAPI verification dashboard will run on port `3000` to execute real sandboxed install/update tests (`/tmp/carbon-sandbox`), validate mode keybind isolation, and display the interactive architecture audit.

---

## 1. Overview & Comprehensive Audit Findings

### A. Critical Bugs Found in the Installer & Updater

1. **Split-Brain Script Deployment (`~/.config/carbon/scripts` vs `~/.config/hypr/scripts`)**
   - **Issue**: Both the CLI installer and GUI installer deploy runtime scripts exclusively into `~/.config/carbon/scripts`, whereas the Quickshell root shell, mode keybind templates (`Notch`, `Pill`, `Vanish`, `Common`), lock screen config, idle daemon config, and over a dozen QML modules invoke scripts from `~/.config/hypr/scripts`.
   - **Impact on Other Machines**: On a fresh machine where `~/.config/hypr/scripts` does not pre-exist, switching bar modes, launching Spotlight, toggling the Control Center, locking the screen, or running media/weather helpers silently fails.

2. **Mode Keybinds (`current-mode-keybinds.conf`) Are Never Sourced by Generated `carbon.conf`**
   - **Issue**: While the installer runs the mode keybind dispatcher at the end of installation, the generated `carbon.conf` only sources `colors.conf`, `windowrules.conf`, the base keybind file (`keybinds-shell-only.conf` or `keybinds.conf`), and `configs/vanish-keybinds.conf`. It never sources `current-mode-keybinds.conf`.
   - **Impact on Other Machines**: Mode-specific shortcuts for Minimal Island, Notch, Pill, and Vanish are completely ignored by Hyprland after installation. Additionally, sourcing `vanish-keybinds.conf` unconditionally in `carbon.conf` binds Vanish shortcuts even when the user is in Minimal, Notch, or Pill mode.

3. **Broken Mode Dispatcher & Missing `pill` Mode Handling**
   - **Issue**: In the mode keybind dispatcher script, the mode normalization `case` statement handles `notch|island`, `vanish|nucleus`, and `minimal|minimal_notch`, but omits `pill`. Selecting `pill` falls through to the `*)` wildcard and activates `minimal` keybinds instead.
   - **Path Mismatch**: The dispatcher looks for mode keybind templates in the top-level `~/.config/carbon/keybinds-<mode>.conf` instead of `~/.config/carbon/configs/keybinds-<mode>.conf` where the installer places them, and writes `current-mode-keybinds.conf` into `~/.config/hypr/configs/` rather than `~/.config/carbon/configs/`.
   - **QML Mode Coercion**: The root Quickshell state coerces `"pill"` into `"notch"` during mode reload and mode switching, preventing Pill Bar mode from retaining its own distinct mode state and keybind profile.

4. **Sandbox (`--dry-run`) Leakage into Host `$HOME`**
   - **Issue**: In `--dry-run` mode, the CLI installer evaluates the backup path and user font directory using `$HOME` rather than the sandbox root, does not pass `--mode` selection via CLI flags, and invokes helper scripts (`theme-mk` and the mode keybind dispatcher) without overriding `CARBON_CONFIG_DIR` or `HOME`. Furthermore, if `DISPLAY` or `WAYLAND_DISPLAY` is set on the host, running `--dry-run` without `--cli` diverts execution into the GTK4 GUI instead of running the CLI sandbox test.
   - **Updater Sandbox**: The updater scripts lack a `--dry-run` / sandbox mode altogether and diverge between two separate scripts (`update.sh` and `carbon-update`), where the installer overwrites the more feature-complete `carbon-update` binary with `update.sh`.

5. **Incomplete `carbon.conf` Generation & Missing Backend Daemons**
   - **Issue**: The `carbon.conf` generated by the CLI and GUI installers omits `blur-exceptions.conf`, `power.conf`, `hypridle`, portal initialization, and audio initialization that exist in the template configuration. Additionally, the GUI installer forgets to deploy shell assets (`assets/`) and neither installer compiles the Rust backend crates (`cairo-engine` and `carbon-hub-daemon`).

### B. Structural Review of the Quickshell Setup

- **Strengths**:
  - Clean separation of QML Singletons (`Theme`, `GlobalState`, `ShellConfig`, `UserConfig`, `SysBackend`, `WeatherService`, `LyricsService`) from visual modules.
  - Zero-symlink deployment philosophy ensures git operations in the repository never break a running desktop session until explicitly synchronized.
  - Material You dynamic palette extraction (`theme-mk`) cleanly bridges Quickshell, Hyprland borders, GTK3/4, and Fastfetch.
- **Structural Weaknesses to Fix**:
  - **Hardcoded Path Scatter**: QML modules and mode keybind files mix `~/.config/hypr/scripts`, `~/.config/carbon/scripts`, and `~/carbon-shell/hypr/scripts`. All scripts and configs must resolve through `~/.config/carbon` (with a compatibility mirror in `~/.config/hypr/scripts` so legacy user configs never break).
  - **Keybind Layering Ambiguity**: Base desktop keybinds (`keep` vs `carbon` profile) and mode-specific shell keybinds (`minimal`, `notch`, `pill`, `vanish`) need a strict two-layer contract so switching modes only swaps the active mode's keybind layer without touching the user's base window/workspace shortcuts.

---

## 2. User Experience & Visual Design (Port 3000 Sandbox & Audit Console)

### Key User Flows

1. **Automated Sandbox Test Suite Execution**:
   - Opening the web interface on port `3000` displays the live status of the Carbon Shell repository alongside a one-click **"Run Full Sandbox Verification"** action.
   - Users can trigger isolated sandbox runs for any combination of **Shell Mode** (`Minimal Island`, `Carbon Notch`, `Pill Bar`, `Vanish Hub`), **Keybind Profile** (`Keep Existing` vs `Full Carbon`), and **Lifecycle Action** (`Fresh Install`, `Update`, `Mode Switch`, `Rollback`).
2. **Interactive Mode & Keybind Isolation Explorer**:
   - Users can switch between the four shell modes to inspect the exact Hyprland keybindings active in that mode, compare them against the base profile, and verify that zero conflicting bindings exist across modes.
3. **Architecture & File Integrity Inspector**:
   - Displays the live audit checklist (Installer, Updater, Mode Dispatcher, QML Path Resolution, Systemd Units) with real-time verification results from `/tmp/carbon-sandbox`.

### Visual Identity & Theme

- **Aesthetic Direction**: High-precision Linux systems engineering console inspired by Carbon Shell's own dark Material 3 / Bohr-atom aesthetic.
- **Color Palette & Mood**:
  - Dominant 60% Canvas: Deep Carbon Obsidian (`#0B0E13`) with subtle structural panels (`#131720`) and crisp `1px` borders (`#222936`).
  - 30% Structural Surfaces: Elevated slate containers (`#191E2B`) with high-contrast text (`#E6E8F0`) and muted technical metadata (`#8D94A5`).
  - 10% Accent Budget: Carbon Cyan (`#38BDF8`) for primary actions and active mode indicators, paired with semantic status indicators — Emerald (`#16A34A`) for passing sandbox assertions, Amber (`#D97706`) for warnings, and Coral (`#F38BA8`) for errors.
- **Typography & Hierarchy**:
  - Display & UI Navigation: `Plus Jakarta Sans` (loaded directly from the repository's fonts) with clean typographic hierarchy.
  - Data, Keybinds & Sandbox Logs: `JetBrains Mono` with `tabular-nums` for keybind matrices, file paths, exit codes, and execution timings.

---

## 3. Key Product Decisions & Trade-Offs

- **Decision 1: Two-Layer External Keybind Architecture (`Base Profile` + `Active Mode Layer`)**
  - *Chosen Approach*: `carbon.conf` will source two distinct keybind files inside `~/.config/carbon`:
    1. `source = ~/.config/carbon/<base-keybinds>.conf` (`keybinds-shell-only.conf` for `keep` mode, or `keybinds.conf` for `carbon` mode — holding only universal window/workspace/hardware shortcuts).
    2. `source = ~/.config/carbon/configs/current-mode-keybinds.conf` (dynamically populated by `carbon-mode-keybinds.sh` with the active mode's exclusive bindings: `keybinds-minimal.conf`, `keybinds-notch.conf`, `keybinds-pill.conf`, or `keybinds-vanish.conf`).
  - *Why*: Guarantees that installing Carbon Shell on any external machine keeps the user's chosen base keybind profile intact while giving all four shell modes their own isolated default keybindings immediately upon install and across live mode switches.
  - *Alternatives Considered*: Sourcing all mode keybinds simultaneously and filtering inside bash scripts was rejected because Hyprland binds keys globally, causing `SUPER + B`, `SUPER + M`, `SUPER + W`, and `SUPER + Arrow` collisions across modes.

- **Decision 2: Unified Sandbox Flag (`--dry-run` / `CARBON_SANDBOX_DIR`) Across Installer, Updater & Dispatcher**
  - *Chosen Approach*: Standardize `CARBON_SANDBOX_DIR` (defaulting to `/tmp/carbon-sandbox` when `--dry-run` is passed) across `install.sh`, `install-gui.py`, `update.sh`, `carbon-update`, and `carbon-mode-keybinds.sh`.
  - *Why*: Allows deterministic, zero-risk automated testing of every installation and update code path without touching the host's `$HOME` directory or requiring a live Wayland session.

- **Decision 3: Pure Python FastAPI Web Runner on Port 3000**
  - *Chosen Approach*: Serve the interactive Sandbox Test Runner and Audit Console from a lightweight Python FastAPI server (`app.py`) on port `3000` with zero npm dependencies.
  - *Why*: Starts the AI Studio preview server cleanly while keeping the native Linux/Quickshell repository free of extraneous `node_modules` or frontend build artifacts.

---

## 4. Technical Architecture & Data Strategy

### Architecture & Component Diagram

```
┌────────────────────────────────────────────────────────────────────────────┐
│                     HOST HYPRLAND CONFIGURATION                            │
│  ~/.config/hypr/hyprland.conf                                              │
│    └── source = ~/.config/carbon/carbon.conf  (Single External Hook)       │
└─────────────────────────────────────┬──────────────────────────────────────┘
                                      │
                                      ▼
┌────────────────────────────────────────────────────────────────────────────┐
│               EXTERNALIZED CARBON RUNTIME (~/.config/carbon)               │
│                                                                            │
│  ┌──────────────────────────┐    ┌──────────────────────────────────────┐  │
│  │ carbon.conf              │    │ carbon-bar-mode.json                 │  │
│  │  ├─ colors.conf          │    │  mode: minimal_notch | notch |       │  │
│  │  ├─ windowrules.conf     │    │        pill | vanish                 │  │
│  │  ├─ blur-exceptions.conf │    └──────────────────┬───────────────────┘  │
│  │  ├─ power.conf           │                       │                      │
│  │  ├─ <base-keybinds>.conf │                       ▼                      │
│  │  └─ configs/current-     │◄───┌──────────────────────────────────────┐  │
│  │     mode-keybinds.conf   │    │ scripts/carbon-mode-keybinds.sh      │  │
│  └──────────────────────────┘    │  ├─ configs/keybinds-minimal.conf    │  │
│                                  │  ├─ configs/keybinds-notch.conf      │  │
│                                  │  ├─ configs/keybinds-pill.conf       │  │
│                                  │  └─ configs/keybinds-vanish.conf     │  │
│                                  └──────────────────────────────────────┘  │
└─────────────────────────────────────┬──────────────────────────────────────┘
                                      │
                                      ▼
┌────────────────────────────────────────────────────────────────────────────┐
│         PORT 3000 SANDBOX VERIFIER & ARCHITECTURE AUDIT CONSOLE            │
│  FastAPI Backend (app.py)  ◄───►  Interactive Web UI (0.0.0.0:3000)        │
│   ├─ POST /api/sandbox/run        ├─ Live Sandbox Test Runner (4 Modes)    │
│   ├─ GET  /api/audit/report       ├─ Installer & Updater Bug Audit Matrix  │
│   ├─ GET  /api/modes/keybinds     ├─ Per-Mode Isolated Keybind Inspector   │
│   └─ GET  /api/sandbox/files      └─ Generated Sandbox File Viewer         │
└────────────────────────────────────────────────────────────────────────────┘
```

### Interactive Component & State Mapping

1. **Installer & Updater Remediation (`install.sh`, `install-gui.py`, `update.sh`, `carbon-update`)**:
   - Add `--mode=<minimal_notch|notch|pill|vanish>` CLI flag to `install.sh` (defaulting to `minimal_notch` in non-interactive mode or prompting in interactive CLI, matching `install-gui.py`).
   - Fix `--dry-run` so it forces CLI mode unless `--gui` is explicitly passed, scopes all paths (`BACKUP_DIR`, `USER_FONT_DIR`, `CONFIG_DIR`, `HYPR_CONFIG_DIR`, `QUICKSHELL_DIR`, `BIN_DIR`, `SYSTEMD_USER_DIR`, `DEFAULT_WALLPAPER_DIR`) strictly inside `/tmp/carbon-sandbox`, and exports `CARBON_CONFIG_DIR` and `CARBON_HYPR_DIR` to child scripts.
   - Deploy runtime scripts to `$CONFIG_DIR/scripts` AND mirror them to `$HYPR_CONFIG_DIR/scripts` so both new externalized paths and legacy `~/.config/hypr/scripts` references work seamlessly on any machine.
   - Unify `update.sh` and `carbon-update` so both support `--dry-run`, preserve user configurations via `.dist` backups, synchronize `configs/keybinds-*.conf`, and refresh the active mode's keybinds via `carbon-mode-keybinds.sh`.

2. **Per-Mode Keybind Isolation (`carbon-mode-keybinds.sh`, `carbon.conf`, `shell.qml`, `configs/keybinds-*.conf`)**:
   - Update `carbon-mode-keybinds.sh` to support all four modes distinctly:
     - `minimal` / `minimal_notch` → copies `configs/keybinds-minimal.conf`
     - `notch` / `island` → copies `configs/keybinds-notch.conf`
     - `pill` → copies `configs/keybinds-pill.conf`
     - `vanish` / `nucleus` → copies `configs/keybinds-vanish.conf` (and appends user custom vanish shortcuts if present)
   - Write `current-mode-keybinds.conf` to both `$CARBON_DIR/configs/current-mode-keybinds.conf` and `$HYPR_CONFIGS/current-mode-keybinds.conf`.
   - Update `carbon.conf` generation in `install.sh`, `install-gui.py`, and `hypr/carbon.conf` to source `~/.config/carbon/configs/current-mode-keybinds.conf` instead of hardcoding `vanish-keybinds.conf`.
   - Fix `shell.qml` so `"pill"` mode is preserved as a first-class mode rather than coerced into `"notch"`, and invokes `carbon-mode-keybinds.sh` from `$CARBON_CONFIG_DIR/scripts/carbon-mode-keybinds.sh`.

3. **Sandbox Verification & Audit Web App (`app.py`)**:
   - Executes real subprocess sandbox tests (`./install.sh --dry-run --cli -y --no-deps --keybinds=<keep|carbon> --mode=<mode>` and `./update.sh --dry-run -y --no-reload`) and verifies every generated file, permission bit, `carbon.conf` source directive, and mode keybind dispatch.
