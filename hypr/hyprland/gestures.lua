local vars = require("variables")

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
