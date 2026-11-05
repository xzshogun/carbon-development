-- Auto-synchronized from ~/.config/hypr/carbon/keybinds.conf
local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "nautilus"
local homeDir = os.getenv("HOME") or ""

-- 
-- CARBON SHELL — DEDICATED HYPRLAND KEYBINDINGS
-- Location: ~/.config/hypr/carbon/keybinds.conf
-- 
-- You can freely edit this file! Any changes here are applied whenever you:
-- 1. Press SUPER + SHIFT + R (or run 'hyprctl reload')
-- 2. Use the Carbon Config Editor GUI (SUPER + C or QuickSettings gear icon)
-- 

local mainMod = "SUPER"
local terminal = "kitty"
local fileManager = "nautilus"

-- ==============================================================================
-- APPLICATIONS & WINDOW CONTROL
-- ==============================================================================
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("kitty"))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + Return", hl.dsp.exec_cmd("[float; size 800 550] kitty"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind("ALT" .. " + F4", hl.dsp.window.close())
hl.bind("CTRL" .. " + " .. "ALT" .. " + Delete", hl.dsp.exec_cmd("hyprctl dispatch exit 0"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + " .. "SHIFT" .. " + F", hl.dsp.exec_cmd(homeDir .. "/.config/hypr/scripts/carbon-focus.sh"))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + S", hl.dsp.exec_cmd("hyprshot -m region"))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + Q", hl.dsp.exec_cmd("~/.config/hypr/scripts/KillActiveProcess.sh"))

-- ==============================================================================
-- CARBON SHELL FEATURES & CONTROLS (COMMON)
-- Mode-specific shell controls (SUPER+C, SUPER+R, SUPER+N, etc.) are loaded
-- dynamically from ~/.config/hypr/current-mode-keybinds.lua
-- ==============================================================================
-- Carbon Config Editor GUI (Settings)
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd(homeDir .. "/.config/hypr/scripts/carbon-config-editor"))

-- Carbon Pomodoro Timer
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("~/.config/hypr/scripts/carbon-pomodoro"))

-- Lock Screen (Hyprlock with Carbon ornament)
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("~/.config/hypr/scripts/hyprlock.sh"))

-- Clipboard Manager (Cliphist + Rofi)
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("bash -c 'cliphist list | rofi -dmenu | cliphist decode | wl-copy'"))

-- ==============================================================================
-- NAVIGATION & WINDOW MOVEMENT
-- ==============================================================================
-- Move focus (Arrow keys)
hl.bind(mainMod .. " + left", hl.dsp.exec_cmd("hyprctl dispatch movefocus l"))
hl.bind(mainMod .. " + right", hl.dsp.exec_cmd("hyprctl dispatch movefocus r"))
hl.bind(mainMod .. " + up", hl.dsp.exec_cmd("hyprctl dispatch movefocus u"))
hl.bind(mainMod .. " + down", hl.dsp.exec_cmd("hyprctl dispatch movefocus d"))

-- Move windows (WASD - dedicated sole movement keys)
hl.bind(mainMod .. " + A", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + D", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + W", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + S", hl.dsp.window.move({ direction = "d" }))

-- Resize active window (SUPER + SHIFT + Arrow keys)
hl.bind(mainMod .. " + " .. "SHIFT" .. " + left", hl.dsp.exec_cmd("hyprctl dispatch resizeactive -50 0"), { repeating = true })
hl.bind(mainMod .. " + " .. "SHIFT" .. " + right", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 50 0"), { repeating = true })
hl.bind(mainMod .. " + " .. "SHIFT" .. " + up", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 -50"), { repeating = true })
hl.bind(mainMod .. " + " .. "SHIFT" .. " + down", hl.dsp.exec_cmd("hyprctl dispatch resizeactive 0 50"), { repeating = true })

-- ==============================================================================
-- WORKSPACES
-- ==============================================================================
-- Switch to workspace 1-10
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Move active window to workspace 1-10
hl.bind(mainMod .. " + " .. "SHIFT" .. " + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + " .. "SHIFT" .. " + 0", hl.dsp.window.move({ workspace = 10 }))

-- Scroll workspaces with mouse wheel
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move / resize windows with mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ==============================================================================
-- HARDWARE & MEDIA KEYS
-- ==============================================================================
local homeDir = os.getenv("HOME") or ""
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(homeDir .. "/.config/hypr/scripts/volume.sh --inc"), { repeating = true, locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(homeDir .. "/.config/hypr/scripts/volume.sh --dec"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(homeDir .. "/.config/hypr/scripts/volume.sh --toggle"), { repeating = true, locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), { repeating = true, locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { repeating = true, locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
