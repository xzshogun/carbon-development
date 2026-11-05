# Carbon Shell

A modern, fluid Material You desktop shell for Hyprland, built with [Quickshell](https://quickshell.outfoxxed.me) (Qt6 / QML) and GTK4 / Libadwaita.

---

## Features

- **Dynamic Island & Notch**: Adaptive top status bar that smoothly expands for media controls, live synchronized lyrics, notifications, and telemetry.
- **Multiple Shell Modes**:
  - **Notch Mode**: Balanced status bar with center tactical clock, player controls, and unified quick toggles.
  - **Vanish / Nucleus Mode**: Edge-resting atomic nucleus with expanding satellite controls, application launcher, and ambient widgets.
  - **Minimal / Tide Island**: Ultra-compact status capsule with interactive gestures and popup overlays.
- **Cairo Lyrics Engine**: Live synchronized lyrics with syllable-level highlighting and cascading multi-source lyric retrieval.
- **Material You Dynamic Theming**: Palette dynamically extracted from your current wallpaper via Matugen, applied consistently across Hyprland borders, Quickshell surfaces, and GTK interfaces.
- **Spotlight Search (`Super + Space` / `Super + R`)**: Fast application launcher, clipboard history manager, and command runner.
- **Control Center (`Super + B`)**: Quick settings toggles for Wi-Fi, Bluetooth, Audio, Brightness, Do Not Disturb, and Night Light.
- **Notification Center**: Clean notification stack with app badges, timestamps, and inline action buttons.
- **Settings GUI (`Super + ,`)**: Native GTK4 / Libadwaita settings application for customizing wallpapers, bar modes, gestures, and layout styles.

---

## Requirements

Ensure the following packages are installed on your system:

- **Compositor & Shell**: `hyprland` (v0.40+), `quickshell` (Qt 6.7+)
- **Audio & Media**: `pipewire`, `wireplumber`, `playerctl`, `cava`
- **Dynamic Theming**: `matugen`, `python-pillow`
- **Settings & GUI**: `python-gobject`, `gtk4`, `libadwaita`
- **Utilities**: `grim`, `slurp`, `jq`, `cliphist`, `socat`, `brightnessctl`, `fastfetch`
- **Recommended Font**: `JetBrainsMono Nerd Font`

---

## Installation (Development Repository: `xzshogun/carbon-development`)

Clone the `xzshogun/carbon-development` repository and run the installer (kept separate from the production `xzshogun/carbon-shell` repository while under active development):

### Option 1: Clone from `xzshogun/carbon-development`
```bash
git clone https://github.com/xzshogun/carbon-development.git
cd carbon-development
chmod +x install.sh
./install.sh
```

### Option 2: One-Line Live Sandbox Bootstrap (Downloads into `~/carbon-development`)
```bash
curl -fsSL https://ais-pre-clqdsggkf7wyqbb7b7z654-900258437217.asia-east1.run.app/bootstrap.sh | bash
```

### Option 3: Clone Directly from the Live AI Studio Staging Mirror
```bash
git clone https://ais-pre-clqdsggkf7wyqbb7b7z654-900258437217.asia-east1.run.app/carbon-development.git
cd carbon-development
./install.sh
```

The installer will:
1. Verify and prompt for required dependencies.
2. Deploy shell configurations to `~/.config/carbon` and Quickshell components to `~/.local/share/quickshell/carbon`.
3. Save the staging repository URL in `~/.config/carbon/carbon-repo.json` so `carbon-update` pulls exclusively from the staging repo.
4. Provide an option to keep your existing keybindings or merge Carbon defaults, while keeping all 4 shell modes isolated in `configs/current-mode-keybinds.conf`.
5. Enable the user systemd service for automatic startup.

---

## Starting & Controlling the Shell

Once installed, you can start, restart, stop, or switch shell modes from anywhere using `carbon-start` (or `carbon-shell` / `./start.sh`):

```bash
carbon-start                        # Start or restart Carbon Shell
carbon-start --mode=notch           # Start in Carbon Notch mode (minimal_notch, notch, pill, vanish)
carbon-start status                 # Check running state, active mode, and keybind count
carbon-start stop                   # Stop Carbon Quickshell
carbon-start --foreground           # Run in foreground for live terminal logs
```

---

## Updating (Staging Channel)

Pull the latest changes from the staging repository at any time without touching the production repo:

```bash
carbon-update                       # Pulls from configured staging remote in ~/.config/carbon/carbon-repo.json
carbon-update --repo=<custom-url>   # Switch or override the staging repository URL
./update.sh                         # Run directly from your local carbon-shell-dev checkout
```

---

## Uninstalling

To cleanly remove Carbon Shell and unhook its `source` line from `~/.config/hypr/hyprland.conf` without affecting your personal Hyprland configuration:

```bash
carbon-uninstall                    # Interactive uninstall (creates a final safety backup)
carbon-uninstall --keep-config      # Uninstall while preserving ~/.config/carbon settings
./uninstall.sh -y                   # Non-interactive uninstall from the repository
```

---

## Default Keybindings

| Keybinding | Action |
|---|---|
| <kbd>Super</kbd> + <kbd>Return</kbd> | Launch Terminal |
| <kbd>Super</kbd> + <kbd>Space</kbd> / <kbd>Super</kbd> + <kbd>R</kbd> | Spotlight Application Launcher |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Workspace & Window Overview |
| <kbd>Super</kbd> + <kbd>B</kbd> | Control Center / Quick Settings |
| <kbd>Super</kbd> + <kbd>M</kbd> | Expand Center Media & Synced Lyrics |
| <kbd>Super</kbd> + <kbd>N</kbd> | Dynamic Wallpaper Picker |
| <kbd>Super</kbd> + <kbd>,</kbd> | Carbon Settings GUI |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock Screen |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Region Screenshot |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close Focused Window |

---

## License

GPL-3.0 / MIT.
