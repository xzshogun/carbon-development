# Carbon Shell Hyprland Configuration

This directory contains the independent, modular configuration files for **Carbon Shell**.

## Structure

- **`hyprland.lua`**: Master entrypoint loaded when Carbon Shell is selected in `shell-switcher`.
- **`keybinds.conf`**: Standard Hyprland-format keybindings (`bind = ...`).
  - You can edit this file directly with any text editor!
  - It is also editable live from the **Carbon Config Editor** GUI (`SUPER + C`).
- **`keybinds.lua`**: Lua-based keybindings and bindings registry.
- **`looknfeel.lua`**: Window gaps, borders, opacity, blur, vibrancy, and shadows.
- **`windowrules.lua`**: Window opacity rules, dialog rules, and Carbon blur layer rules.

## Opening Carbon Settings
You can open settings anytime via:
1. **Shortcut**: Press `SUPER + C` (or `SUPER + ,`)
2. **GUI**: Click the gear icon (`⚙`) in the Quick Settings panel
3. **Menu**: Search "Carbon Settings" in the Carbon app launcher (`SUPER + R`) or rofi
4. **Terminal**: Run `~/.config/hypr/scripts/carbon-config-editor`

## Switching Shells
Run `shell-switcher` in your terminal to toggle between **Carbon Shell** and **Tide Island**.
