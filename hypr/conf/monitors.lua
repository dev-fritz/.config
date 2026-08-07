-- Monitor layout. Run `hyprctl monitors` to list connected outputs, or
-- `hyprctl monitors all` to also see disconnected ones and every supported mode.
--
--   output    output name
--   mode      "WIDTHxHEIGHT@RATE", or "preferred" for the native mode
--   position  "XxY" in the global pixel space — this is what decides which
--             screen sits left of which
--   scale     1 = no scaling; use 1.25/1.5 on very dense screens
--
-- Current arrangement, left to right: eDP-1 at 0x0, DP-1 at 2560x0,
-- HDMI-A-1 at 5120x0.

-- Laptop screen.
hl.monitor({
  output = "eDP-1",
  mode = "2560x1600@240",
  position = "0x0",
  scale = "1",
})

-- Main external monitor.
hl.monitor({
  output = "DP-1",
  mode = "2560x1440@165",
  position = "2560x0",
  scale = "1",
})

-- Secondary external monitor.
hl.monitor({
  output = "HDMI-A-1",
  mode = "1920x1080@240",
  position = "5120x0",
  scale = "1",
})

-- Catch-all: any monitor not listed above gets its preferred mode and is
-- placed to the right of the others. Without this an unknown screen would
-- stack at 0x0 on top of eDP-1.
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto-right",
  scale = "1",
})

-- ── Which workspace lives on which screen ────────────────────────
--
-- Without these rules Hyprland hands out workspaces in the order it detects
-- the outputs, not in the order the screens sit on the desk. That is why
-- workspace 1 kept landing on DP-1 and the laptop ended up on 3.
--
--   monitor     the screen this workspace belongs to
--   default     this is the workspace the monitor opens with, and where an
--               unassigned window on that screen goes
--   persistent  keep it alive even when empty, so Waybar always draws it
--               (the bars use `all-outputs: false`, each shows only its own)
--
-- The numbering follows the physical order, left to right.
local areas = {
  { workspace = "1", monitor = "eDP-1" }, -- laptop, on the left
  { workspace = "2", monitor = "DP-1" }, -- main monitor, in the middle
  { workspace = "3", monitor = "HDMI-A-1" }, -- secondary, on the right
}

for _, area in ipairs(areas) do
  hl.workspace_rule({
    workspace = area.workspace,
    monitor = area.monitor,
    default = true,
    persistent = true,
  })
end

-- Workspaces 4 to 10 are deliberately left unbound: they open on whichever
-- screen has focus, which makes them useful as scratch space. To give each
-- monitor a fixed range instead, replace the table above with one entry per
-- workspace (1-3 on eDP-1, 4-6 on DP-1, 7-9 on HDMI-A-1, for example) and add
-- the matching `persistent-workspaces` block to ~/.config/waybar/config.jsonc.
