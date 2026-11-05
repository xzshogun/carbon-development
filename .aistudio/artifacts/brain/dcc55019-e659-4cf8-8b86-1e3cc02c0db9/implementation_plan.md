# Carbon Shell — Dev Server Startup, Sandbox Audit & External Mode Isolation Plan

This plan resolves the port 3000 development server startup failure and delivers a full audit, bug remediation, and live sandbox test suite for the Carbon Shell installer, updater, and externalized per-mode keybinding architecture.

## User Review & Critical Decisions

- **Confirmed Decision 1 — Immediate Port 3000 Dev Server Startup**: A lightweight Python HTTP web server binds to `0.0.0.0:3000` (with zero npm dependencies so the native Linux repository remains clean), resolving the dev server error and hosting the live Carbon Shell Sandbox Test Runner & Audit Console.
- **Confirmed Decision 2 — Fully Externalized Shell Architecture**: All Carbon Shell runtime configurations, scripts, assets, and active mode keybinds reside inside the isolated Carbon configuration directory (`~/.config/carbon`), requiring only a single non-destructive `source` hook in the user's Hyprland configuration.
- **Confirmed Decision 3 — Isolated Per-Mode Default Keybindings**: Each of the four shell modes (`Minimal Island / Tide`, `Carbon Notch`, `Pill Bar`, and `Vanish / Nucleus`) has its own isolated default keybinding layer activated during installation and dynamically swapped on mode switch without colliding with other modes or user base keybinds.
