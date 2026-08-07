-- Environment variables. These only apply to processes Hyprland starts after
-- reading the config — already running programs keep the old values, and
-- `hyprctl reload` does not reapply them. Log out and back in to be sure.

-- ── Cursor ───────────────────────────────────────────────────────

-- Both must match: XCURSOR is for X11/XWayland apps, HYPRCURSOR for apps
-- using Hyprland's newer cursor format.
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ── Toolkits ─────────────────────────────────────────────────────

-- Make Qt apps run on native Wayland and follow the system theme.
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")

-- Tell apps the session is Wayland.
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- GTK backend: Wayland, falling back to X11.
hl.env("GDK_BACKEND", "wayland,x11")

-- Fixes blurry text in Java/Swing apps.
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- ── NVIDIA ───────────────────────────────────────────────────────

-- Recommended by the Hyprland wiki to avoid black screens and freezes with
-- the proprietary driver. Safe to comment out on nouveau or Intel-only.
hl.env("LIBVA_DRIVER_NAME", "nvidia") -- video acceleration
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

-- Runs Electron apps (VS Code, Discord, Spotify) on native Wayland, which
-- fixes blurry scaling on high-density screens.
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
