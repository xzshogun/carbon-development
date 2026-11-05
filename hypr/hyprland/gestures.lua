local vars = require("variables")

hl.config({
    gestures = {
        workspace_swipe_distance                 = 700,
        workspace_swipe_cancel_ratio             = 0.15,
        workspace_swipe_min_speed_to_force       = 5,
        workspace_swipe_direction_lock           = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new               = true,
        workspace_swipe_invert                   = false,
    },
})

hl.gesture({ fingers = vars.workspaceSwipeFingers, direction = "horizontal", action = "workspace" })
-- 3-finger UP swipe is now handled natively by hyprexpo (workspace overview)
-- hl.gesture({
--     fingers   = vars.gestureFingers,
--     direction = "up",
--     action    = function()
--         hl.exec_cmd("sh ~/.config/hypr/scripts/carbon-ipc.sh toggle-overview")
--     end,
-- })
hl.gesture({
    fingers   = vars.gestureFingers,
    direction = "down",
    action    = function()
        hl.exec_cmd("sh ~/.config/hypr/scripts/carbon-screenshot-full.sh")
    end,
})
hl.gesture({
    fingers   = vars.gestureFingers,
    direction = "right",
    action    = function()
        hl.dispatch(hl.dsp.focus({ workspace = "+1" }))
    end,
})
hl.gesture({
    fingers   = vars.gestureFingers,
    direction = "left",
    action    = function()
        hl.dispatch(hl.dsp.focus({ workspace = "-1" }))
    end,
})
hl.gesture({
    fingers   = vars.gestureFingersMore,
    direction = "down",
    action    = function()
        hl.exec_cmd(vars.sleepGestureCmd)
    end,
})

