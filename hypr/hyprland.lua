-- Entry point. Only defines which modules load and in what order.
-- `programs` must come first (autostart and keybinds read from it), and
-- `look` before `animations` (animations need animations.enabled set).
--
-- Reload with `hyprctl reload`, check for mistakes with `hyprctl configerrors`.

require("conf.programs") -- default apps (terminal, browser, launcher)
require("conf.monitors") -- display layout
require("conf.env") -- environment variables
require("conf.look") -- gaps, borders, colors, blur, shadows
require("conf.animations") -- animation curves
require("conf.layouts") -- dwindle / master / scrolling + misc options
require("conf.input") -- keyboard, mouse, touchpad, gestures
require("conf.keybinds") -- all keybindings
require("conf.windowrules") -- window, workspace and layer rules
require("conf.autostart") -- programs started with the session
