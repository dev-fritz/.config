# fastfetch

The system summary shown when a new terminal opens.

![fastfetch](.assets/preview.png)

## Where the hook lives

In `~/.zshrc`, **not** here and not in kitty. kitty opens zsh, so the zsh hook
already covers both — duplicating it would print twice.

The hook has four guards so it does not show up where it gets in the way:

| Guard | Prevents it from appearing |
|---|---|
| `-o interactive` | in scripts and in `zsh -c "command"` |
| `$FASTFETCH_SHOWN` | more than once per terminal (a nested zsh inherits it and skips) |
| `$NVIM` | inside Neovim's `:terminal` |
| `-t 1` | when the output is a pipe rather than a screen |

Skip it just once: `FASTFETCH_SHOWN=1 kitty`
Run it again: `ff` (alias in `.zshrc`)
Turn it off for good: comment the block in `.zshrc`.

## Colors

Colors are given by **name** (`"blue"`, `"magenta"`), which map to the
terminal's 16 colors. Since kitty already carries the active theme, they come
out in the right palette automatically — and this config stays valid in any
terminal, with no hardcoded hex.

## Useful commands

```sh
fastfetch                   # run with this config
fastfetch --list-modules    # every available module
fastfetch --list-logos      # every built-in logo
fastfetch -s cpu            # test a single module
fastfetch --gen-config      # generate a full example config
```

Reference: <https://github.com/fastfetch-cli/fastfetch/wiki/Configuration>

## Dependencies

| Package | For | Required |
|---|---|---|
| `fastfetch` | the program | yes |
| `ttf-space-mono-nerd` | the key icons and the bars | yes |

The `.zshrc` hook checks that `fastfetch` exists before calling it, so
uninstalling does not break terminal startup.
