-- Default programs, in one place. The keybind and autostart modules read from
-- here, so changing something here changes it everywhere:
--   local apps = require("conf.programs")
--   hl.bind("SUPER + T", hl.dsp.exec_cmd(apps.terminal))

local M = {}

-- ── Applications ─────────────────────────────────────────────────

M.terminal = "kitty"
M.browser = "firefox"
M.file_manager = "kitty yazi" -- yazi is a terminal file manager
M.menu = "rofi -show drun"
M.editor = "kitty nvim"

-- ── Desktop components ───────────────────────────────────────────

M.bar = "waybar" -- status bar (~/.config/waybar)
M.wallpaper = "awww-daemon" -- wallpaper daemon
M.notifications = "swaync" -- notification daemon (~/.config/swaync)
M.lock = "hyprlock" -- lock screen (./hyprlock.conf)
M.power_menu = "wlogout" -- power menu (~/.config/wlogout)

-- ── Local scripts (~/.config/hypr/scripts/) ──────────────────────

local scripts = os.getenv("HOME") .. "/.config/hypr/scripts"

-- Screenshot: captures, copies to the clipboard immediately and opens swappy
-- to annotate. Modes: area, full, window, all.
M.screenshot = scripts .. "/screenshot.sh"

-- Clipboard history (cliphist + rofi).
M.clipboard = scripts .. "/clipboard.sh"

-- Wallpaper picker with thumbnails (rofi + awww).
M.wallpaper_picker = scripts .. "/wallpaper.sh"

-- Catppuccin variant picker (rofi + ~/.config/theme/apply.py).
M.theme_picker = scripts .. "/theme.sh"

-- ── Audio and brightness (same commands Waybar uses) ─────────────

M.volume_up = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
M.volume_down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
M.volume_mute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
M.mic_mute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
M.brightness_up = "brightnessctl -e4 -n2 set 5%+"
M.brightness_down = "brightnessctl -e4 -n2 set 5%-"

return M
