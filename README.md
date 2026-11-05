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

## Installation

Clone the repository and run the installer:

```bash
git clone https://github.com/xzshogun/carbon-shell.git
cd carbon-shell
chmod +x install.sh
./install.sh
```

The installer will:
1. Verify and prompt for required dependencies.
2. Deploy shell configurations to `~/.config/carbon` and Quickshell components to `~/.local/share/quickshell/carbon`.
3. Provide an option to keep your existing keybindings or merge Carbon defaults.
4. Enable the user systemd service for automatic startup.

---

## Updating

Update to the latest release at any time:

```bash
cd carbon-shell
./update.sh
```

Or run `carbon-update` from anywhere if the CLI tools were linked during install.

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
