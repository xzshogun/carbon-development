local vars = require("variables")

hl.config({
    gestures = {
        workspace_swipe                          = true,
        workspace_swipe_fingers                  = vars.workspaceSwipeFingers or 3,
        workspace_swipe_distance                 = 400,
        workspace_swipe_cancel_ratio             = 0.15,
        workspace_swipe_min_speed_to_force       = 5,
        workspace_swipe_direction_lock           = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new               = true,
        workspace_swipe_invert                   = false,
    },
})

hl.gesture({ fingers = vars.workspaceSwipeFingers or 3, direction = "horizontal", action = "workspace" })
hl.gesture({
    fingers   = vars.gestureFingers or 3,
    direction = "up",
    action    = function()
        hl.exec_cmd("sh ~/.config/carbon/scripts/carbon-ipc.sh toggle-overview")
    end,
})
hl.gesture({
    fingers   = vars.gestureFingers or 3,
    direction = "down",
    action    = function()
        hl.exec_cmd("sh ~/.config/carbon/scripts/carbon-ipc.sh spatial-canvas")
    end,
})
hl.gesture({
    fingers   = vars.gestureFingersMore or 4,
    direction = "down",
    action    = function()
        hl.exec_cmd(vars.sleepGestureCmd)
    end,
})
