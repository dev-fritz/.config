-- Window, workspace and layer rules.
--
-- To find a window's data: `hyprctl clients` lists everything open, and
-- `hyprctl activewindow` shows only the focused one. The fields that matter
-- are `class` (the app) and `title`. Both accept regex — `^...$` anchors the
-- match so similarly named apps don't get caught.
--
-- Every rule has a `name`. It doesn't change behavior; it just lets you
-- identify the rule and disable it at runtime:
--   local r = hl.window_rule({...})
--   r:set_enabled(false)

-- ── General fixes ────────────────────────────────────────────────

-- Ignore "maximize" requests coming from apps — in a tiling compositor an app
-- deciding on its own that it wants the whole screen just gets in the way.
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fixes drag-and-drop in XWayland apps: the invisible window XWayland creates
-- during a drag was stealing focus.
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Put the `hyprland-run` window in the bottom corner.
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },
	move = "20 monitor_h-120",
	float = true,
})

-- ── Dialogs and utilities: float and center ──────────────────────
-- These windows are small and temporary; tiling them only disturbs the layout.

local flutuantes = {
	"^(pavucontrol)$",
	"^(pwvucontrol)$",
	"^(blueman-manager)$",
	"^(nm-connection-editor)$",
	"^(org.pulseaudio.pavucontrol)$",
	"^(qt6ct|qt5ct)$",
	"^(nwg-look)$",
	"^(file-roller|org.gnome.FileRoller)$",
	"^(galculator|gnome-calculator)$",
}

for _, classe in ipairs(flutuantes) do
	hl.window_rule({
		name = "float-" .. classe:gsub("[^%w]", ""),
		match = { class = classe },
		float = true,
		center = true,
		size = "900 600",
	})
end

-- Open/save file dialogs from any app.
hl.window_rule({
	name = "float-file-dialogs",
	match = { title = "^(Open File|Save File|Save As|Abrir|Salvar como|Escolher arquivos)" },
	float = true,
	center = true,
	size = "1000 650",
})

-- Authentication (polkit) windows — they need immediate attention, so they
-- float, center and stay pinned on top.
hl.window_rule({
	name = "float-polkit",
	match = {
		class = "^(polkit-gnome-authentication-agent-1|hyprpolkitagent|org.kde.polkit-kde-authentication-agent-1)$",
	},
	float = true,
	center = true,
	pin = true,
})

-- Picture-in-picture: floats, stays on top and never takes focus.
hl.window_rule({
	name = "float-pip",
	match = { title = "^(Picture-in-Picture|Imagem em imagem)$" },
	float = true,
	pin = true,
	size = "640 360",
	move = "monitor_w-660 monitor_h-400",
})

-- ── Performance ──────────────────────────────────────────────────

-- Games and fullscreen apps get no blur, no shadow and no rounding. Those
-- effects cost GPU time and aren't even visible on a window covering everything.
hl.window_rule({
	name = "no-effects-fullscreen",
	match = { fullscreen = true },
	no_blur = true,
	no_shadow = true,
	rounding = 0,
})

-- Steam's friends list is a ghost window that breaks the tiling layout.
hl.window_rule({
	name = "steam-friends-float",
	match = { class = "^(steam)$", title = "^(Friends List|Lista de amigos)$" },
	float = true,
	size = "400 700",
})

-- ── Screen sharing ───────────────────────────────────────────────

-- The xdg-desktop-portal window picker has to float and stay on top,
-- otherwise you can't choose what to share.
hl.window_rule({
	name = "float-share-picker",
	match = { class = "^(xdg-desktop-portal-gtk|org.freedesktop.impl.portal.desktop.hyprland)$" },
	float = true,
	center = true,
})

-- ── Layer rules ──────────────────────────────────────────────────
-- Layers are the surfaces that aren't windows: Waybar, rofi, notifications,
-- the lock screen. Run `hyprctl layers` to see the active namespaces.

-- Blur what's behind the bar and the launcher so their transparency stays
-- readable over any wallpaper.
hl.layer_rule({
	name = "blur-waybar",
	match = { namespace = "^waybar$" },
	blur = true,
	ignore_alpha = 0.2,
})

hl.layer_rule({
	name = "blur-rofi",
	match = { namespace = "^rofi$" },
	blur = true,
})

hl.layer_rule({
	name = "blur-notifications",
	match = { namespace = "^swaync-(control-center|notification-window)$" },
	blur = true,
	ignore_alpha = 0.3,
})

-- The lock screen must not animate: any delay there is time the screen is
-- still visible.
hl.layer_rule({
	name = "no-anim-hyprlock",
	match = { namespace = "^hyprlock$" },
	no_anim = true,
})

-- ── Workspace rules ──────────────────────────────────────────────
--
-- Smart gaps are deliberately NOT used here. The usual recipe is
-- `workspace = w[tv1], gapsout:0`, which removes the spacing when a workspace
-- holds a single window. The problem is that Waybar keeps its margins, so the
-- bar looks detached while the window doesn't — and opening a second window
-- makes the whole layout jump inward.
--
-- Constant spacing means the frame around the screen never changes size. The
-- values come from conf/look.lua (gaps_in / gaps_out).
--
-- To bring the frameless version back, uncomment this and drop Waybar's margins:
--   hl.workspace_rule({ workspace = "w[tv1]", gaps_out = 0, gaps_in = 0 })
--   hl.window_rule({
--     name = "no-gaps-single-window",
--     match = { float = false, workspace = "w[tv1]" },
--     border_size = 0,
--     rounding = 0,
--   })

-- Real fullscreen (SUPER+F) is different: the window must cover everything.
-- f[1] = a workspace with one fullscreen window.
hl.workspace_rule({ workspace = "f[1]", gaps_out = 0, gaps_in = 0 })

-- Fullscreen windows get no border and no rounding.
hl.window_rule({
	name = "no-gaps-fullscreen",
	match = { float = false, workspace = "f[1]" },
	border_size = 0,
	rounding = 0,
})

-- Spotify opens floating and centered.
hl.window_rule({
	name = "float-spotify",
	match = { class = "^(Spotify|spotify)$" },
	float = true,
	center = true,
	size = "1000 700",
})
