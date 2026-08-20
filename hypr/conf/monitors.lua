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
--
-- ── Why this file checks the hardware first ──────────────────────
--
-- The three screens below belong to one specific laptop. On another machine
-- "eDP-1" is a different panel — 1920x1080, not 2560x1600 at 240 Hz — and
-- pinning a mode a screen cannot do means Hyprland falls back to whatever it
-- likes, at a position calculated for a screen that is not there.
--
-- So each entry is applied only when the machine really has that output *and*
-- that output really supports that mode. Anything else falls through to the
-- catch-all at the bottom, which gives every unknown screen its preferred mode
-- and places it to the right of the others. The same file therefore works on
-- this laptop, on a single-monitor desktop and on a virtual machine.
--
-- The check reads /sys/class/drm, where the kernel keeps one directory per
-- connector (card1-eDP-1, card0-HDMI-A-1, ...) holding a `status` file that
-- says "connected" or "disconnected" and a `modes` file listing every
-- resolution the screen reports. No process is spawned: these are plain file
-- reads at config-parse time.

local DRM = "/sys/class/drm"
local CARDS = 8 -- card0..card8; more GPUs than any of these machines has

-- Opens <DRM>/card<N>-<output>/<file> for the first card that has it. The card
-- number depends on driver load order (card0 on one boot, card1 on the next),
-- which is exactly why it is searched instead of hardcoded.
local function open_connector(output, file)
  for card = 0, CARDS do
    local handle = io.open(string.format("%s/card%d-%s/%s", DRM, card, output, file), "r")
    if handle then
      return handle
    end
  end
  return nil
end

-- Is a screen physically plugged into this output right now?
local function connected(output)
  local handle = open_connector(output, "status")
  if not handle then
    return false -- the connector does not exist on this machine
  end

  local status = handle:read("l")
  handle:close()
  return status == "connected"
end

-- Does the screen on this output accept this mode? Only the resolution is
-- compared: `modes` lists "2560x1600" without the refresh rate, and a panel
-- that reports the resolution at all will do it at one of its rates.
local function mode_supported(output, mode)
  local resolution = mode:match("^(%d+x%d+)")
  if not resolution then
    return true -- "preferred" and friends are always fine
  end

  local handle = open_connector(output, "modes")
  if not handle then
    return false
  end

  for line in handle:lines() do
    if line == resolution then
      handle:close()
      return true
    end
  end

  handle:close()
  return false
end

-- ── The screens of this machine ──────────────────────────────────
--
-- `workspace` is the one that opens on that screen and stays alive even when
-- empty, so Waybar always draws it (each bar uses `all-outputs: false` and
-- shows only its own). The numbering follows the physical order, left to
-- right: without these rules Hyprland hands out workspaces in the order it
-- detects the outputs, which is why workspace 1 kept landing on DP-1 and the
-- laptop ended up on 3.

local screens = {
  -- Laptop screen.
  {
    output = "eDP-1",
    mode = "2560x1600@240",
    position = "0x0",
    scale = "1",
    workspace = "1",
  },

  -- Main external monitor.
  {
    output = "DP-1",
    mode = "2560x1440@165",
    position = "2560x0",
    scale = "1",
    workspace = "2",
  },

  -- Secondary external monitor.
  {
    output = "HDMI-A-1",
    mode = "1920x1080@240",
    position = "5120x0",
    scale = "1",
    workspace = "3",
  },
}

for _, screen in ipairs(screens) do
  if connected(screen.output) and mode_supported(screen.output, screen.mode) then
    hl.monitor({
      output = screen.output,
      mode = screen.mode,
      position = screen.position,
      scale = screen.scale,
    })

    hl.workspace_rule({
      workspace = screen.workspace,
      monitor = screen.output,
      default = true, -- the workspace this monitor opens with
      persistent = true, -- keep it alive when empty, so the bar draws it
    })
  end
end

-- Catch-all: any monitor not handled above — unknown output, different panel,
-- or a machine with a single screen — gets its preferred mode and is placed to
-- the right of the others. Without this an unmatched screen would stack at 0x0
-- on top of whatever is already there.
hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto-right",
  scale = "1",
})

-- Workspaces 4 to 10 are deliberately left unbound: they open on whichever
-- screen has focus, which makes them useful as scratch space. To give each
-- monitor a fixed range instead, add one entry per workspace to the table
-- above (1-3 on eDP-1, 4-6 on DP-1, 7-9 on HDMI-A-1, for example) and add the
-- matching `persistent-workspaces` block to ~/.config/waybar/config.jsonc.
