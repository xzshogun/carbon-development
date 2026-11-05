# Carbon Shell — Dev Server Startup, Sandbox Audit & External Mode Isolation Plan

This plan resolves the port 3000 development server startup failure and delivers a full audit, bug remediation, and live sandbox test suite for the Carbon Shell installer, updater, and externalized per-mode keybinding architecture.

## User Review & Critical Decisions

> [!IMPORTANT]
> Because Planning Mode is active, code changes and starting the port 3000 server are paused until you approve this plan. Click **Proceed** on this plan to immediately start the port 3000 server, run the sandboxed installer/updater tests, and apply all fixes.

- **Confirmed Decision 1 — Immediate Port 3000 Dev Server Startup**: A lightweight Python FastAPI web server will bind to `0.0.0.0:3000` (with zero npm dependencies so the native Linux repository remains clean), resolving the dev server error and hosting the live Carbon Shell Sandbox Test Runner & Audit Console.
- **Confirmed Decision 2 — Fully Externalized Shell Architecture**: All Carbon Shell runtime configurations, scripts, assets, and active mode keybinds will reside inside the isolated Carbon configuration directory (`~/.config/carbon`), requiring only a single non-destructive `source` hook in the user's Hyprland configuration.
- **Confirmed Decision 3 — Isolated Per-Mode Default Keybindings**: Each of the four shell modes (`Minimal Island / Tide`, `Carbon Notch`, `Pill Bar`, and `Vanish / Nucleus`) will have its own isolated default keybinding layer activated during installation and dynamically swapped on mode switch without colliding with other modes or user base keybinds.

---

## 1. Overview & Core Concept

- **What It Does**:
  1. Starts the interactive **Carbon Shell Sandbox & Architecture Audit Console** on port `3000`.
  2. Fixes critical path, sandbox, and keybinding bugs across the CLI installer, GTK4 GUI installer, updater, mode keybind dispatcher, and Quickshell runtime.
  3. Executes automated sandbox tests across all four shell modes and both keybinding profiles (`Keep Existing` and `Full Carbon`) to verify portability for external machines.
- **Target Audience / Persona**: Carbon Shell maintainers and Linux/Hyprland users installing or updating Carbon Shell on external systems.
- **Key Value**: Eliminates silent broken paths and cross-mode shortcut collisions on fresh machines while providing an interactive visual test runner to verify every installation and update flow.

### Summary of Bugs Identified in the Existing Setup

1. **Split-Brain Script Deployment**: The CLI installer, GUI installer, and updater deploy scripts only to the Carbon configuration directory (`~/.config/carbon/scripts`), while the Quickshell root component, lock screen, idle daemon, mode keybinds, and over a dozen UI modules invoke scripts from `~/.config/hypr/scripts`. On a clean machine without `~/.config/hypr/scripts`, mode switching, Spotlight, Control Center, and screen locking fail silently.
2. **Active Mode Keybinds Never Sourced**: The generated master configuration (`carbon.conf`) never includes the dynamically generated active mode keybind file (`current-mode-keybinds.conf`), meaning mode-specific shortcuts for Minimal Island, Notch, Pill, and Vanish never take effect on fresh installs. Worse, it unconditionally sources Vanish mode shortcuts in all modes.
3. **Missing `Pill` Mode in Dispatcher & Root Shell**: The mode keybind dispatcher script omits `pill` from its mode normalization logic (falling back to `minimal` keybinds), looks for mode templates in the wrong directory, and writes output to the host Hyprland folder instead of the isolated Carbon folder. Meanwhile, the Quickshell root state forcibly coerces `pill` mode into `notch`.
4. **Sandbox (`--dry-run`) Host Leakage**: Running `--dry-run` leaks backup directories, font installations, and child script writes (`theme-mk` and mode keybind dispatch) into the host's real home directory, and diverts to the GTK4 GUI if a display server environment variable is present. The updater scripts lack a sandbox mode entirely and are split between two divergent scripts.
5. **Incomplete Generated Master Config**: The installer-generated master config omits blur exceptions, power button bindings, idle daemon startup, portal initialization, and audio initialization present in the reference config.

---

## 2. User Experience & Visual Design

### Key User Flows

1. **Zero-State Dashboard Load (Port 3000)**:
   - Immediately displays the **Sandbox Test Runner**, **Audit Findings Matrix**, **Per-Mode Keybind Inspector**, and **External Structure Verifier**.
2. **Live Sandbox Execution Flow**:
   - Selecting a shell mode (`Minimal Island`, `Carbon Notch`, `Pill Bar`, or `Vanish Hub`) and keybind profile (`Keep Existing` or `Full Carbon`) and clicking **"Run Sandbox Install & Update Test"** executes the real installer and updater inside an isolated sandbox (`/tmp/carbon-sandbox`).
   - Displays step-by-step pass/fail assertions, execution logs, and the exact generated configuration files.
3. **Mode Keybind Comparison Flow**:
   - Switching between the four mode tabs displays that mode's dedicated default keybindings alongside the universal base profile, confirming zero shortcut collisions across modes.

### Visual Identity & Theme

- **Aesthetic Direction**: Utilitarian systems engineering console tailored to Carbon Shell's dark Material 3 and atomic visual language.
- **Color Palette & Mood**:
  - **60% Dominant Neutral Canvas**: Deep Carbon Obsidian (`--background: #0B0E13`) with clean structural surfaces (`#12161F`).
  - **30% Structural Surfaces**: Slate containers (`#181D29`) bounded by crisp `1px` borders (`#242C3D`), primary text (`#E6E8F0`), and muted metadata (`#8D94A5`).
  - **10% Accent Budget**: Carbon Cyan (`--primary: #38BDF8`) for primary actions and active mode tabs, paired with semantic status indicators (`#16A34A` Nominal/Passed, `#D97706` Warning, `#F38BA8` Error/Failed).
- **Typography & Hierarchy**:
  - **Display & UI Prose**: `Plus Jakarta Sans` (SemiBold 600 for headers, Regular 400 for body copy).
  - **Keybinds, Paths & Telemetry**: `JetBrains Mono` with `tabular-nums` for keybinding tables, sandbox logs, and assertion counters.
- **Component Styling & Layout**:
  - Full 1440px desktop workspace layout with a 3-zone top bar (Brand wordmark, 4 single-line navigation links, and 1 primary `"Run All Sandbox Tests"` CTA button).
  - Single-elevation containers with hairline dividers and zero nested card clutter.
- **Interactive Feedback & Motion**:
  - Instant tab switching (`<150ms`), live progress states during sandbox execution, and toast confirmation upon test completion.

---

## 3. Key Product Decisions & Trade-Offs

- **Decision 1: Two-Layer External Keybind Architecture (`Base Profile` + `Active Mode Layer`)**
  - *Chosen Approach*: The isolated Carbon configuration will load:
    1. **Base Keybind Layer**: Either minimal shell triggers (`Keep Existing` profile) or full desktop window/workspace shortcuts (`Full Carbon` profile).
    2. **Active Mode Keybind Layer**: A single dynamically swapped mode keybind file (`current-mode-keybinds`) populated from the active mode's dedicated template (`Minimal`, `Notch`, `Pill`, or `Vanish`).
  - *Why*: Ensures all four shell modes remain completely separate with their own default keybindings right from installation, preventing key collisions while preparing a clean foundation for future in-app keybind customization.
  - *Alternatives Considered*: Loading all four mode keybind files simultaneously was rejected because Hyprland binds keys globally, causing conflicts on `SUPER + B`, `SUPER + M`, `SUPER + W`, and directional navigation keys.

- **Decision 2: Dual Script Resolution (`~/.config/carbon/scripts` Primary + `~/.config/hypr/scripts` Mirror)**
  - *Chosen Approach*: Standardize Carbon Shell's own scripts and mode keybinds to point to `~/.config/carbon/scripts`, while the installer and updater also synchronize a mirror into `~/.config/hypr/scripts`.
  - *Why*: Makes `~/.config/carbon` 100% self-contained and externalized while guaranteeing zero breakage for any legacy module or custom user script referencing `~/.config/hypr/scripts`.

- **Decision 3: Python FastAPI Web Runner for Port 3000**
  - *Chosen Approach*: Use Python FastAPI + Uvicorn to serve the port 3000 verification console and run native bash/python sandbox tests directly.
  - *Why*: Starts the AI Studio dev server immediately without introducing Node.js/npm build artifacts into a Linux desktop shell repository.

---

## 4. Technical Architecture & Data Strategy *(Technical Reference)*

### Architecture & Component Diagram

```
┌────────────────────────────────────────────────────────────────────────────┐
│                     HOST HYPRLAND CONFIGURATION                            │
│  User Hyprland Config                                                      │
│    └── Single non-destructive source hook ──► Carbon Master Config         │
└─────────────────────────────────────────────────────┬──────────────────────┘
                                                      │
                                                      ▼
┌────────────────────────────────────────────────────────────────────────────┐
│               EXTERNALIZED CARBON RUNTIME (~/.config/carbon)               │
│                                                                            │
│  ┌──────────────────────────┐    ┌──────────────────────────────────────┐  │
│  │ Carbon Master Config     │    │ Active Mode State Store              │  │
│  │  ├─ Dynamic Theme Colors │    │  mode: minimal_notch | notch |       │  │
│  │  ├─ Window & Layer Rules │    │        pill | vanish                 │  │
│  │  ├─ Base Keybind Profile │    └──────────────────┬───────────────────┘  │
│  │  └─ Active Mode Keybinds │                       │                      │
│  └────────────▲─────────────┘                       ▼                      │
│               │                  ┌──────────────────────────────────────┐  │
│               └──────────────────┤ Mode Keybind Dispatcher              │  │
│                                  │  ├─ Minimal Island Default Keybinds  │  │
│                                  │  ├─ Carbon Notch Default Keybinds    │  │
│                                  │  ├─ Pill Bar Default Keybinds        │  │
│                                  │  └─ Vanish / Nucleus Default Binds   │  │
│                                  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┬──────────────────────┘
                                                      │
                                                      ▼
┌────────────────────────────────────────────────────────────────────────────┐
│         PORT 3000 SANDBOX VERIFIER & ARCHITECTURE AUDIT CONSOLE            │
│  FastAPI Server (0.0.0.0:3000)  ◄───►  Interactive Web Console             │
│   ├─ Sandbox Test Executor             ├─ Multi-Mode Sandbox Runner        │
│   ├─ Static & Runtime Auditor          ├─ Audit Findings & Fix Status      │
│   ├─ Keybind Isolation Parser          ├─ Per-Mode Keybind Matrix          │
│   └─ Sandbox File Tree Inspector       └─ Generated Config Inspector       │
└────────────────────────────────────────────────────────────────────────────┘
```

### Data Model & State

- **Sandbox Test Run State**: Tracks test parameters (`mode`, `keybindProfile`, `testType`), execution logs, exit codes, and a structured list of assertion results (verifying isolated directory creation, `carbon.conf` source hooks, mode-specific keybind activation, script permissions, and zero host leakage).
- **Mode Keybind Registry**: Parses and models the default bindings for `Common / Base`, `Minimal Island`, `Carbon Notch`, `Pill Bar`, and `Vanish Hub`, exposing modifier keys, key codes, dispatcher targets, and collision checks.
- **Audit Report Store**: Tracks every identified issue across the Installer, Updater, Mode Dispatcher, and Quickshell structure along with its verification status.

### Interactive Component & State Mapping

- **Sandbox Runner Controls**: Selecting a shell mode (`minimal_notch`, `notch`, `pill`, `vanish`) and keybind profile (`keep`, `carbon`) triggers a backend sandbox execution in `/tmp/carbon-sandbox`, returning real-time assertion checks and file previews.
- **Mode Keybind Matrix Filter**: Clicking any of the four shell mode tabs filters the keybind table to display that mode's isolated bindings and verifies that `current-mode-keybinds` matches the selected mode template.
- **Sandbox File Inspector**: Clicking any generated file in the sandbox tree loads its exact contents so the user can inspect the generated `carbon.conf`, `carbon-bar-mode.json`, and `current-mode-keybinds.conf`.
