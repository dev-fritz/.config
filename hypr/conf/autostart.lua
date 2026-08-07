-- Programs started with the session.
--
-- `hl.on("hyprland.start", ...)` runs once when Hyprland starts, not on every
-- `hyprctl reload` — which is why reloading doesn't spawn a second Waybar.
-- Changes here need a logout to take effect, or start the program by hand.

local apps = require("conf.programs")

hl.on("hyprland.start", function()
  -- Wallpaper daemon first, otherwise the background stays black.
  hl.exec_cmd(apps.wallpaper)

  -- Then restore the last chosen image. The sleep is there because the daemon
  -- takes a moment before it accepts commands.
  hl.exec_cmd("sh -c 'sleep 1; " .. apps.wallpaper_picker .. " restore'")

  -- Status bar.
  hl.exec_cmd(apps.bar)

  -- Notification daemon. Without it no app can send notifications and the
  -- Waybar bell does nothing.
  hl.exec_cmd(apps.notifications)

  -- Clipboard history. cliphist is only a database — it does not watch the
  -- clipboard itself. These two processes listen and record every copy, one
  -- for text and one for images. Without them SUPER+V shows an empty list.
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")

  -- Polkit agent: shows the password prompt when an app needs privileges
  -- (mounting a disk, updating the system). Without it those requests fail
  -- silently.
  hl.exec_cmd("systemctl --user start hyprpolkitagent")

  -- Blue-light filter. Times and temperatures live in ../hyprsunset.conf; the
  -- daemon applies the profile for the current hour as soon as it starts.
  --
  -- The `command -v` is here because the package is optional: without the
  -- guard, anyone cloning this config without installing hyprsunset would get
  -- an error in the log on every login, with no visible effect to explain it.
  hl.exec_cmd("sh -c 'command -v hyprsunset >/dev/null && hyprsunset'")
end)
