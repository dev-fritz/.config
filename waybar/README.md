# waybar

Status bar. Floats at the top of **every** connected monitor —
[`config.jsonc`](config.jsonc) defines a single bar with no `output` key, and
Waybar replicates it across all screens, adding and removing bars as monitors
are plugged in and out.

![waybar](.assets/preview.png)

## Files

| File | What it is |
|---|---|
| [`config.jsonc`](config.jsonc) | which modules exist, where they sit, what they do |
| [`style.css`](style.css) | the look: the "islands", spacing, states |
| `colors.css` | **generated** by `theme/apply.py` — do not edit |
| [`scripts/weather.py`](scripts/weather.py) | weather via wttr.in, no account needed |
| [`scripts/launch.sh`](scripts/launch.sh) | runs the first available program from a list |

## Layout

```
┌─────────────────────────────────┬──────────────────────┬──────────────────────────────────┐
│ workspaces · submap · title     │  clock · weather     │ media · system · controls ·      │
│                                 │                      │ network · battery · 󰂚 · tray · 󰐥│
└─────────────────────────────────┴──────────────────────┴──────────────────────────────────┘
```

Two groups open as drawers: hovering the temperature slides CPU, RAM and disk
out. The data stays within reach without occupying the bar permanently.

## Things that are not obvious

**Workspaces per monitor.** `all-outputs: false` makes each bar show only its
own screen's workspaces. With three monitors that is the sane choice — the DP-1
bar is not cluttered with the laptop's workspaces.

**Workspaces 1, 2 and 3 are always visible**, even when empty. That does not
come from here: it comes from the `persistent` rules in
[`../hypr/conf/monitors.lua`](../hypr/conf/monitors.lua).

**Temperature by absolute path.** The module uses `hwmon-path-abs` pointing at
`/sys/devices/platform/coretemp.0/hwmon` instead of `/sys/class/hwmon/hwmonN`.
That `N` is assigned in driver load order and changes between reboots — the bar
would end up showing the SSD or the battery temperature.

**The scroll dispatcher uses Lua syntax.** Since the Hyprland config became
Lua, `hyprctl dispatch workspace e+1` is a parse error and the scroll silently
does nothing. The correct form is in `config.jsonc`.

**`exec-if` on the notification module.** If swaync is not installed the command
fails and Waybar simply does not draw the module — no broken icon, no log noise.

## Applying changes

```sh
killall -SIGUSR2 waybar    # reload config and style
```

`style.css` reloads on save by itself (`reload_style_on_change: true`). To see
errors, run `waybar` in a terminal and read the output.

## Dependencies

### Required

| Package | For |
|---|---|
| `waybar` | the bar |
| `ttf-space-mono-nerd` | the icons and the calendar font |
| `python` | the weather script |

### Per module

| Package | Module | Without it |
|---|---|---|
| `wireplumber` | `pulseaudio`, `backlight` | volume and brightness do not respond |
| `brightnessctl` | `backlight` | scrolling brightness does nothing |
| `playerctl` | `mpris` | the media module disappears |
| `bluez-utils` | `bluetooth` | no Bluetooth state |
| `networkmanager` | `network` | no network state |
| `swaync` | `custom/notification` | the module is not drawn (`exec-if`) |
| `wlogout` | `custom/power` | falls back to `systemctl` in a terminal |

### Optional, used by the click actions

`pavucontrol` (mixer), `blueman` (Bluetooth), `nm-connection-editor` (network),
`btop` or `htop` (CPU and RAM). [`scripts/launch.sh`](scripts/launch.sh) tries
each in order and falls back to a terminal alternative if none exist — no click
is ever dead.

## Hardware-specific settings

Two values are tied to this laptop and need changing on another machine:

- `temperature.hwmon-path-abs` → `coretemp.0`, the i9-12900HX sensor
- `backlight.device` → `nvidia_0`

Find the right values with `ls /sys/class/backlight/` and
`ls /sys/class/hwmon/*/name`.
