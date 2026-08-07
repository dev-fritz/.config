# swaync

SwayNotificationCenter: the notification daemon **and** a control center that
keeps the history. Without it no application can send notifications and the
Waybar bell does nothing.

![swaync](.assets/preview.png)

## Files

| File | What it is |
|---|---|
| [`config.json`](config.json) | position, sizes, timeouts, controls |
| [`style.css`](style.css) | the look |
| `colors.css` | **generated** by `theme/apply.py` — do not edit |

`config.json` is plain JSON and accepts **no comments**. The documentation lives
in `"//"` keys, which swaync ignores.

## Opening it

| Where | Action |
|---|---|
| `SUPER + N` | toggle the center |
| `SUPER + SHIFT + N` | do not disturb |
| Waybar bell | click toggles; right click is do not disturb |
| Command line | `swaync-client -t -sw` |

## Details

**The center opens right below the bell.** The bar sits at the top with the bell
on the right, so `control-center-margin-top` is 44 — the bar height (38) plus
its margin (6).

**`layer: "overlay"`** puts notifications above even fullscreen windows, so a
warning is not missed while gaming or watching something. The center itself
sits at `top`, which is the expected behavior for a panel.

**The blur behind the center** comes from a Hyprland layer rule, not from here —
see `blur-notifications` in
[`../hypr/conf/windowrules.lua`](../hypr/conf/windowrules.lua).

## Applying changes

```sh
swaync -c ~/.config/swaync/config.json   # validate the JSON
swaync-client -R                          # reload the config
swaync-client -rs                         # reload the CSS
```

Testing a notification:

```sh
notify-send "Title" "Body of the message"
notify-send -u critical "Urgent" "This one does not dismiss itself"
```

## Dependencies

| Package | For | Required |
|---|---|---|
| `swaync` | the daemon and the center | yes |
| `libnotify` | `notify-send`, used by the scripts | yes |
| `ttf-space-mono-nerd` | the icons | yes |

The daemon starts with the session, in
[`../hypr/conf/autostart.lua`](../hypr/conf/autostart.lua).

There can only be **one** notification daemon per session. If `dunst` or `mako`
are installed and running, one of them wins and the other stays silent.
