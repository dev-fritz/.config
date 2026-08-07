# wlogout

Power menu: lock, log out, suspend, reboot, shut down.

![wlogout](.assets/preview.png)

## Opening it

`SUPER + X`, or the 󰐥 button at the far right of Waybar.

## Files

| File | What it is |
|---|---|
| [`layout`](layout) | the buttons and what each one runs |
| [`style.css`](style.css) | the look |
| `colors.css` | **generated** by `theme/apply.py` — do not edit |

`layout` is **not valid JSON**: it is a sequence of JSON objects one after
another, with no commas and no surrounding brackets. That is the format wlogout
expects; an array breaks it.

## Buttons

| Button | Key | Command |
|---|---|---|
| Lock | `l` | `hyprlock` |
| Logout | `o` | `hyprctl dispatch 'hl.dsp.exit()'` |
| Suspend | `s` | `systemctl suspend` |
| Reboot | `r` | `systemctl reboot` |
| Shutdown | `d` | `systemctl poweroff` |

`Esc` exits without doing anything.

## Important detail: the logout syntax

Since the Hyprland config became Lua, `hyprctl dispatch` evaluates a **Lua
expression**. The old form, `hyprctl dispatch exit`, is a parse error and the
button silently does nothing. Hence `hyprctl dispatch 'hl.dsp.exit()'`.

The same applies to any script of yours that calls `hyprctl dispatch`.

## Dependencies

| Package | For | Required |
|---|---|---|
| `wlogout` | the menu (from the AUR: `paru -S wlogout`) | yes |
| `hyprlock` | the lock button | yes |
| `systemd` | suspend, reboot, shut down | yes |
| `ttf-space-mono-nerd` | the button icons | yes |

While wlogout is not installed, the Waybar click falls back to a terminal
alternative via [`../waybar/scripts/launch.sh`](../waybar/scripts/launch.sh) —
the button is never dead.
