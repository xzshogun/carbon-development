-- ==============================================================================
-- CARBON SHELL — WINDOW RULES AND LAYER RULES (LUA)
-- Location: ~/.config/hypr/carbon/windowrules.lua
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Layer Rules for Carbon Shell (Dynamic Universal Blur)
-- ------------------------------------------------------------------------------
local blur_enabled = true
local home = os.getenv("HOME") or ""
local bp_file = io.open(home .. "/.config/hypr/carbon-bar-position.json", "r")
if bp_file then
    local content = bp_file:read("*a")
    bp_file:close()
    if content:find('"shellBlur":%s*false') then
        blur_enabled = false
    end
end

local carbon_layers = {
    "carbon-.*",
    "carbon-bar-minimal",
    "carbon-bar-pill-full",
    "carbon-bar-pill-vert",
    "carbon-bar-notch",
    "carbon-bar-notch-center",
    "carbon-controls",
    "carbon-spotlight",
    "carbon-launcher",
    "carbon-music",
    "carbon-music-small",
    "carbon-overview",
    "carbon-wallpaper-picker",
    "carbon-mixer",
    "carbon-brightness",
    "carbon-battery",
    "carbon-wifi",
    "carbon-bluetooth",
    "carbon-tray",
    "carbon-calendar",
    "carbon-center-dashboard",
    "carbon-power",
    "carbon-sensor",
    "carbon-osd",
    "quickshell",
    "tide-island"
}

for _, ns in ipairs(carbon_layers) do
    hl.layer_rule({ name = "blur-" .. ns, match = { namespace = ns }, blur = blur_enabled, ignore_alpha = 0.2 })
end
hl.layer_rule({ name = "carbon-noanim",          match = { namespace = "carbon-.*" },       no_anim = true })
hl.layer_rule({ name = "blur-logout-dialog",     match = { namespace = "logout_dialog" },   blur = blur_enabled })

-- ------------------------------------------------------------------------------
-- Window Rules
-- ------------------------------------------------------------------------------
-- Opacity
hl.window_rule({ name = "opacity-nautilus", match = { class = "org.gnome.Nautilus" }, opacity = "0.85 override 0.85 override" })
hl.window_rule({ name = "opacity-kitty", match = { class = "kitty" }, opacity = "0.88 override 0.82 override" })
hl.window_rule({ name = "opacity-gedit", match = { class = "gedit" }, opacity = "0.90 override 0.84 override" })
hl.window_rule({ name = "opacity-mousepad", match = { class = "mousepad" }, opacity = "0.90 override 0.84 override" })
hl.window_rule({ name = "opacity-texteditor", match = { class = "org.gnome.TextEditor" }, opacity = "0.90 override 0.84 override" })
hl.window_rule({ name = "opacity-discord", match = { class = "discord" }, opacity = "0.90 override 0.80 override 1.0 override" })
hl.window_rule({ name = "opacity-vesktop", match = { class = "vesktop" }, opacity = "0.90 override 0.80 override 1.0 override" })
hl.window_rule({ name = "opacity-spotify", match = { class = "Spotify" }, opacity = "0.85 override 0.70 override 1.0 override" })

-- Dialogs & Floating
hl.window_rule({ match = { class = "org.pulseaudio.pavucontrol" }, float = true, size = "50% 60%" })
hl.window_rule({ match = { class = "pwvucontrol" },                float = true, size = "50% 60%" })
hl.window_rule({ match = { title = "Save As" },                    float = true, size = "50% 60%", center = true })
hl.window_rule({ match = { title = "Save a File" },                float = true, size = "50% 60%", center = true })
hl.window_rule({ match = { title = "Pick Files" },                 float = true, size = "50% 60%", center = true })
hl.window_rule({ match = { initial_title = "Open Files" },         float = true, size = "70% 60%" })


-- Carbon Config Editor GUI floating window
hl.window_rule({ match = { class = "carbon-config-editor.*" }, float = true, size = "920 680", center = true })
hl.window_rule({ match = { class = "org.carbon.configeditor" }, float = true, size = "920 680", center = true })
hl.window_rule({ match = { title = "Settings" }, float = true, size = "920 680", center = true })

-- Tiling & Maximize suppression (forces all apps to tile cleanly side-by-side)
hl.window_rule({ name = "suppress-maximize",  match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "fix-xwayland-drags", match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true })
