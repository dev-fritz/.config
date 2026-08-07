-- Keyboard, mouse, touchpad and gestures.
-- Run `hyprctl devices` to get the exact device names used by `hl.device`.

hl.config({
	input = {
		-- ── Keyboard ─────────────────────────────────────────────────
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_rules = "",

		-- `kb_options`, comma separated.
		--
		-- caps:escape  Caps Lock acts as Esc. Caps is the best-positioned key
		--              on the keyboard and the least used; in nvim, where Esc
		--              is pressed constantly, the swap pays for itself on the
		--              first day. Delete it here to go back.
		--
		-- Other useful values:
		--   "grp:alt_shift_toggle"   switch layouts with Alt+Shift
		--   "compose:ralt"           right AltGr becomes the compose key
		kb_options = "caps:escape",

		-- Key repeat: wait 250ms, then repeat 40 times per second.
		repeat_delay = 250,
		repeat_rate = 40,

		-- ── Focus ────────────────────────────────────────────────────
		-- 1 = focus follows the mouse, 0 = click to focus,
		-- 2 = follows the mouse but the keyboard stays on the clicked window.
		follow_mouse = 1,

		-- Do not change focus when a window appears under the cursor on its own.
		mouse_refocus = false,

		-- ── Mouse ────────────────────────────────────────────────────
		-- libinput acceleration, -1.0 to 1.0 (0 = unchanged). This affects
		-- response, not sensor DPI.
		sensitivity = 0.9,
		accel_profile = "flat", -- "flat" = 1:1, no acceleration

		-- ── Touchpad ─────────────────────────────────────────────────
		touchpad = {
			natural_scroll = false, -- true = inverted, phone-style scrolling
			disable_while_typing = true,
			tap_to_click = true,
			drag_lock = true, -- tap-and-drag keeps going after lifting the finger
			scroll_factor = 0.8, -- below 1 makes scrolling slower
			clickfinger_behavior = true, -- 2 fingers = right click, 3 = middle
		},
	},

	-- ── Cursor ───────────────────────────────────────────────────────
	cursor = {
		inactive_timeout = 3, -- hide the cursor after 3s idle
		hide_on_key_press = true,
		no_hardware_cursors = false, -- true fixes invisible cursors in some games
	},
})

-- ── Touchpad gestures ────────────────────────────────────────────

-- Three-finger horizontal swipe switches workspace.
hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

-- ── Per-device overrides ─────────────────────────────────────────

-- External mouse, with its own acceleration separate from the touchpad.
hl.device({
	name = "pebble-m350s-mouse",
	sensitivity = 1,
	accel_profile = "flat",
})
