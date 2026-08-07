-- Animations, defined in two steps: `hl.curve` declares an easing curve, and
-- `hl.animation` binds that curve to an animated event ("leaf").
--
-- Leaves are named by Hyprland: `windows`, `workspaces`, `layers`, `fade`,
-- `border`, and so on. The ones ending in In/Out are the enter and exit halves
-- and inherit from their parent leaf when left undefined.
--
-- Curve types: `bezier` takes { points = { {x1,y1}, {x2,y2} } } and behaves
-- like a CSS easing curve; `spring` takes { mass, stiffness, dampening } and
-- overshoots slightly before settling — lower dampening means more bounce.
--
-- `speed` is time in tenths of a second, so speed = 5 is 0.5s. Higher is slower.
-- To disable everything at once set `animations = { enabled = false }` in
-- conf/look.lua rather than deleting anything here.

-- ── Curves ───────────────────────────────────────────────────────

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick", { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

-- Spring used by windows — this is what gives the bounce on open.
hl.curve("easy", { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

-- ── Windows ──────────────────────────────────────────────────────

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows", enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, spring = "easy", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49, bezier = "linear", style = "popin 87%" })

-- ── Opacity ──────────────────────────────────────────────────────

hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03, bezier = "quick" })

-- ── Layers (bar, menus, notifications) ───────────────────────────

hl.animation({ leaf = "layers", enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 4, bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })

-- ── Workspaces ───────────────────────────────────────────────────
-- `style = "fade"` cross-dissolves instead of sliding. With three monitors at
-- different refresh rates (240/165/240 Hz) the fade is steadier than a slide,
-- which can stutter on the slowest screen.

hl.animation({ leaf = "workspaces", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- Overview / magnifier zoom.
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 7, bezier = "quick" })
