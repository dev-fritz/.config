-- Keybindings.
--
--   hl.bind("MOD + KEY", hl.dsp.something(), { options })
--
-- Options: `locked` keeps the bind working on the lock screen, `repeating`
-- repeats while the key is held, `mouse` marks the bind as a mouse button.
-- Run `hyprctl binds` to list everything currently active.

local apps = require("conf.programs")

local mod = "SUPER" -- the Windows key
local modShift = mod .. " + SHIFT"
local modCtrl = mod .. " + CTRL"

-- ── Applications ─────────────────────────────────────────────────

hl.bind(mod .. " + T", hl.dsp.exec_cmd(apps.terminal))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(apps.browser))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(apps.file_manager))
hl.bind(mod .. " + A", hl.dsp.exec_cmd(apps.menu))
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(apps.terminal)) -- same as SUPER+T

-- ── Session ──────────────────────────────────────────────────────

hl.bind(mod .. " + L", hl.dsp.exec_cmd(apps.lock)) -- lock the screen
hl.bind(mod .. " + X", hl.dsp.exec_cmd(apps.power_menu)) -- power menu
hl.bind(mod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw")) -- notification center
hl.bind(modShift .. " + N", hl.dsp.exec_cmd("swaync-client -d -sw")) -- do not disturb

-- Quit the session directly, skipping the menu. Behind SHIFT so it doesn't
-- happen by accident.
hl.bind(modShift .. " + X", hl.dsp.exit())

-- ── Focused window ───────────────────────────────────────────────

hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())

-- "maximized" keeps the gaps and the bar visible; "fullscreen" covers
-- the whole screen. Those two spellings are the only ones accepted.
hl.bind(modShift .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))

hl.bind(mod .. " + U", hl.dsp.window.pseudo()) -- pseudo-tiling (dwindle only)
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit")) -- rotate the split (dwindle only)
hl.bind(mod .. " + C", hl.dsp.window.center()) -- center a floating window
hl.bind(modShift .. " + U", hl.dsp.window.pin()) -- pin across all workspaces

-- Force kill: the cursor becomes a crosshair, click the frozen window.
hl.bind(modShift .. " + Q", hl.dsp.window.kill())

-- ── Focus: arrows and hjkl ───────────────────────────────────────

local direcoes = {
  { tecla = "left", vim = "H", dir = "left" },
  { tecla = "right", vim = "L", dir = "right" },
  { tecla = "up", vim = "K", dir = "up" },
  { tecla = "down", vim = "J", dir = "down" },
}

for _, d in ipairs(direcoes) do
  -- Move the focus.
  hl.bind(mod .. " + " .. d.tecla, hl.dsp.focus({ direction = d.dir }))

  -- Move the window itself.
  hl.bind(modShift .. " + " .. d.tecla, hl.dsp.window.move({ direction = d.dir }))

  -- Resize in 40px steps.
  local dx = (d.dir == "left" and -40) or (d.dir == "right" and 40) or 0
  local dy = (d.dir == "up" and -40) or (d.dir == "down" and 40) or 0
  hl.bind(modCtrl .. " + " .. d.tecla, hl.dsp.window.resize({ x = dx, y = dy }), { repeating = true })
end

-- Vim keys for focus only. SUPER+J and SUPER+L are already taken
-- (togglesplit and lock screen), so down and right stay on the arrow keys.
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))

-- ── Resize mode (submap) ─────────────────────────────────────────
-- SUPER+R enters the mode, where arrows and hjkl resize without holding any
-- modifier. Esc or Enter leaves. Waybar shows the mode name while it's active.

hl.define_submap("resize", function()
  local passo = 40
  hl.bind("right", hl.dsp.window.resize({ x = passo, y = 0 }), { repeating = true })
  hl.bind("left", hl.dsp.window.resize({ x = -passo, y = 0 }), { repeating = true })
  hl.bind("up", hl.dsp.window.resize({ x = 0, y = -passo }), { repeating = true })
  hl.bind("down", hl.dsp.window.resize({ x = 0, y = passo }), { repeating = true })

  hl.bind("L", hl.dsp.window.resize({ x = passo, y = 0 }), { repeating = true })
  hl.bind("H", hl.dsp.window.resize({ x = -passo, y = 0 }), { repeating = true })
  hl.bind("K", hl.dsp.window.resize({ x = 0, y = -passo }), { repeating = true })
  hl.bind("J", hl.dsp.window.resize({ x = 0, y = passo }), { repeating = true })

  hl.bind("escape", hl.dsp.submap("reset"))
  hl.bind("Return", hl.dsp.submap("reset"))
end)

hl.bind(mod .. " + R", hl.dsp.submap("resize"))

-- ── Workspaces ───────────────────────────────────────────────────

-- SUPER + 1..0 switches workspace, SUPER + SHIFT + 1..0 takes the window along.
for i = 1, 10 do
  local tecla = i % 10 -- workspace 10 sits on the 0 key
  hl.bind(mod .. " + " .. tecla, hl.dsp.focus({ workspace = i }))
  hl.bind(modShift .. " + " .. tecla, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace ("scratchpad"): a drawer that overlays the current screen.
hl.bind(mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(modShift .. " + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Cycle workspaces with the scroll wheel.
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Cycle workspaces from the keyboard.
hl.bind(modCtrl .. " + period", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(modCtrl .. " + comma", hl.dsp.focus({ workspace = "e-1" }))

-- ── Monitors ─────────────────────────────────────────────────────
-- Moving focus "right" already crosses screens, so these move the whole
-- workspace to another monitor instead.

hl.bind(modCtrl .. " + SHIFT + right", hl.dsp.workspace.move({ monitor = "+1" }))
hl.bind(modCtrl .. " + SHIFT + left", hl.dsp.workspace.move({ monitor = "-1" }))

-- ── Mouse ────────────────────────────────────────────────────────
-- 272 = left button, 273 = right button.

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ── Screenshots ──────────────────────────────────────────────────
-- Every capture goes to the clipboard immediately and then opens swappy for
-- annotation. Ctrl+C in swappy re-copies the edited version, Esc quits and
-- keeps the original. A copy is saved to ~/Images/Screenshots.

hl.bind(mod .. " + P", hl.dsp.exec_cmd(apps.screenshot .. " area"))
hl.bind(modShift .. " + P", hl.dsp.exec_cmd(apps.screenshot .. " full"))
hl.bind(modCtrl .. " + P", hl.dsp.exec_cmd(apps.screenshot .. " window"))

-- The Print key does the same thing.
hl.bind("Print", hl.dsp.exec_cmd(apps.screenshot .. " area"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(apps.screenshot .. " full"))

-- ── Clipboard, wallpaper and theme ───────────────────────────────

-- Searchable clipboard history. Needs the cliphist watchers started in
-- conf/autostart.lua.
hl.bind(mod .. " + V", hl.dsp.exec_cmd(apps.clipboard))

-- Wallpaper picker with thumbnails of the images in ~/Images/Pictures.
hl.bind(modShift .. " + W", hl.dsp.exec_cmd(apps.wallpaper_picker))

-- Switch the Catppuccin variant across every app at once.
hl.bind(modShift .. " + T", hl.dsp.exec_cmd(apps.theme_picker))

-- ── Media and hardware keys ──────────────────────────────────────
-- `locked = true` keeps these working while the screen is locked.

local travado = { locked = true, repeating = true }

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(apps.volume_up), travado)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(apps.volume_down), travado)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(apps.volume_mute), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(apps.mic_mute), { locked = true })

hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(apps.brightness_up), travado)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(apps.brightness_down), travado)

-- Media control, requires playerctl.
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
