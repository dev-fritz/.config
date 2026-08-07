-- Layout settings and general behavior options.
--
-- Hyprland ships three window layouts. The active one is set by
-- `general.layout` in conf/look.lua — currently `dwindle`.
--
--   dwindle    each new window splits the focused window's space in half,
--              alternating between horizontal and vertical cuts
--   master     one large window on the left plus a stack beside it
--   scrolling  side-by-side columns on a horizontally scrolling strip
--
-- All three are configured below even though only one is active, so switching
-- `general.layout` works without touching anything else.

-- ── dwindle (active) ─────────────────────────────────────────────

hl.config({
  dwindle = {
    -- Keep the split direction when sibling windows open or close. Without
    -- this the layout rotates on its own and you lose your bearings.
    preserve_split = true,

    -- New windows go to the right/bottom side of the split instead of taking
    -- the current window's place.
    force_split = 2,

    smart_split = false,
    smart_resizing = true,
  },
})

-- ── master ───────────────────────────────────────────────────────

hl.config({
  master = {
    -- Where a new window lands: "master" makes it the main one, "slave" sends
    -- it to the stack, "inherit" follows the previous window.
    new_status = "master",
    new_on_top = false,
    mfact = 0.55, -- fraction of the screen the master takes
  },
})

-- ── scrolling ────────────────────────────────────────────────────

hl.config({
  scrolling = {
    fullscreen_on_one_column = true,
  },
})

-- ── Misc ─────────────────────────────────────────────────────────

hl.config({
  misc = {
    -- Skip Hyprland's built-in wallpaper; awww-daemon handles that.
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,

    -- Don't steal focus when a new window opens, so a popup can't swallow
    -- what you were typing.
    focus_on_activate = false,

    -- Variable refresh rate off — with three monitors at different rates it
    -- tends to flicker. Use 1 (always) or 2 (fullscreen only) to enable.
    vrr = 0,

    mouse_move_focuses_monitor = true,
  },

  ecosystem = {
    -- Silence the update and donation notices.
    no_update_news = true,
    no_donation_nag = true,
  },
})
