-- ==============================================================================
-- CARBON SHELL — LOOK AND FEEL CONFIGURATION (LUA)
-- Location: ~/.config/hypr/carbon/looknfeel.lua
-- ==============================================================================

local c = {
    outline            = "rgba(899296ff)",
    outline_variant    = "rgba(40484bff)",
    on_secondary_container = "rgba(cee6f0ff)",
    secondary          = "rgba(b3cad3ff)",
    source_color       = "rgba(0e3c48ff)",
}

hl.config({
    general = {
        gaps_in         = 5,
        gaps_out        = 5,
        border_size     = 1,
        col = {
            active_border   = c.outline,
            inactive_border = c.outline_variant,
        },
        resize_on_border = false,
        allow_tearing    = true,
        layout           = "dwindle",
    },

    decoration = {
        rounding         = 12,
        rounding_power   = 2,
        active_opacity   = 0.88,
        inactive_opacity = 0.82,
        dim_inactive     = false,
        dim_special      = 0.3,

        shadow = {
            enabled      = false,
            range        = 8,
            render_power = 2,
            color        = "rgba(00000088)",
        },

        blur = {
            enabled           = true,
            size              = 6,
            passes            = 3,
            ignore_opacity    = true,
            new_optimizations = true,
            popups            = true,
            xray              = false,
            noise             = 0.0,
            brightness        = 1.25,
            contrast          = 1.05,
            vibrancy          = 0.30,
            vibrancy_darkness = 0.0,
        },
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})
