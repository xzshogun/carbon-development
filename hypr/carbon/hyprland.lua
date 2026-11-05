-- ==============================================================================
-- CARBON SHELL — HYPRLAND MASTER CONFIGURATION (LUA)
-- Location: ~/.config/hypr/carbon/hyprland.lua
-- Activated by shell-switcher (option 2 / carbon)
-- ==============================================================================

-- Colors
local c = {
    outline            = "rgba(899296ff)",
    outline_variant    = "rgba(40484bff)",
    on_secondary_container = "rgba(cee6f0ff)",
    secondary          = "rgba(b3cad3ff)",
    source_color       = "rgba(0e3c48ff)",
}

-- Monitor
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, sdrsaturation = 1.3 })

-- Programs
local terminal    = "kitty"
local fileManager = "nautilus"

-- Autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon --format argb")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Hyprland")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal-hyprland")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal")
    hl.exec_cmd("pactl set-card-profile alsa_card.pci-0000_00_1b.0 output:analog-stereo+input:analog-stereo")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("bash -c 'wl-paste --watch cliphist store'")
    hl.exec_cmd("bash -c 'wl-paste --type image --watch cliphist store --max-items 500'")
    hl.exec_cmd("systemctl --user start carbon-quickshell.service")
end)

-- Environment
hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "capitaine-cursors")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("LIBVA_DRIVER_NAME", "i965")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("XDG_DESKTOP_PORTAL", "hyprland")

-- Animations & Curves
hl.config({
    animations = {
        enabled = true,
    },
})
hl.curve("myBezier",    { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("been",        { type = "bezier", points = { {0.24, 0.9}, {0.25, 0.91} } })
hl.curve("been2",       { type = "bezier", points = { {0, 0.94}, {0.5, 0.99} } })
hl.curve("menu_decel",  { type = "bezier", points = { {0.1, 1}, {0, 1} } })
hl.curve("linear",      { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("wind",        { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.curve("winIn",       { type = "bezier", points = { {0.1, 1.1}, {0.1, 1.1} } })
hl.curve("winOut",      { type = "bezier", points = { {0.3, -0.3}, {0, 1} } })
hl.curve("slow",        { type = "bezier", points = { {0, 0.85}, {0.3, 1} } })
hl.curve("overshot",    { type = "bezier", points = { {0.7, 0.6}, {0.1, 1.1} } })
hl.curve("bounce",      { type = "bezier", points = { {1.1, 1.6}, {0.1, 0.85} } })
hl.curve("sligshot",    { type = "bezier", points = { {1, -1}, {0.15, 1.25} } })

hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4,  bezier = "slow",     style = "popin" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 5,  bezier = "been",     style = "popin 70%" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 4,  bezier = "wind",     style = "slide" })
hl.animation({ leaf = "border",        enabled = true, speed = 1,  bezier = "linear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 4,  bezier = "overshot" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 4,  bezier = "wind" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4,  bezier = "bounce",   style = "popin" })

-- Input & Touchpad
hl.config({
    input = {
        kb_layout      = "us",
        follow_mouse   = 1,
        sensitivity    = 0.0,
        accel_profile  = "adaptive",
        force_no_accel = false,
        touchpad = {
            natural_scroll = true,
        },
    },
})

hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- Load GUI options then override with Modular Carbon Shell Configurations
pcall(require, "hyprland-gui")

local home = os.getenv("HOME") or ""
dofile(home .. "/.config/hypr/carbon/looknfeel.lua")
dofile(home .. "/.config/hypr/carbon/windowrules.lua")
dofile(home .. "/.config/hypr/carbon/keybinds.lua")
pcall(dofile, home .. "/.config/hypr/current-mode-keybinds.lua")
