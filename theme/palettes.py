"""
Palettes: the single source of color for the whole system.

This is the only file with hand-written hex values. Waybar, swaync, rofi, kitty,
Hyprland, hyprlock, wlogout, satty and the GTK apps all get color files
generated from here by apply.py.

To switch themes, run `~/.config/theme/apply.py <theme>` or use the rofi menu
(SUPER + SHIFT + T).

To add a theme:

  1. Copy a PALETTES block and fill in all 26 names. The names come from
     Catppuccin but act as ROLES, not literal colors: `peach` is "the theme's
     orange" and `mauve` is "its purple". Every generator in apply.py uses these
     roles, so a new theme works across all apps without touching anything else.

  2. Register it in IS_DARK, NVIM_COLORSCHEME and WALLHAVEN_COLOR.

  3. Create its wallpaper folder: mkdir -p ~/Images/Pictures/<theme>

Neovim also needs the matching colorscheme installed; see
~/.config/nvim/lua/plugins/colorscheme.lua.

The 26 roles:
    Backgrounds, darkest to lightest:
        crust  mantle  base  surface0  surface1  surface2
    Text, faintest to strongest:
        overlay0  overlay1  overlay2  subtext0  subtext1  text
    Accents:
        red  maroon  peach  yellow  green  teal  sky  sapphire  blue
        lavender  mauve  pink  flamingo  rosewater
"""

PALETTES: dict[str, dict[str, str]] = {
    # ── Catppuccin: soft pastels, the most popular palette of recent years ─
    "catppuccin-mocha": {
        "rosewater": "f5e0dc", "flamingo": "f2cdcd", "pink": "f5c2e7",
        "mauve": "cba6f7", "red": "f38ba8", "maroon": "eba0ac",
        "peach": "fab387", "yellow": "f9e2af", "green": "a6e3a1",
        "teal": "94e2d5", "sky": "89dceb", "sapphire": "74c7ec",
        "blue": "89b4fa", "lavender": "b4befe",
        "text": "cdd6f4", "subtext1": "bac2de", "subtext0": "a6adc8",
        "overlay2": "9399b2", "overlay1": "7f849c", "overlay0": "6c7086",
        "surface2": "585b70", "surface1": "45475a", "surface0": "313244",
        "base": "1e1e2e", "mantle": "181825", "crust": "11111b",
    },
    "catppuccin-macchiato": {
        "rosewater": "f4dbd6", "flamingo": "f0c6c6", "pink": "f5bde6",
        "mauve": "c6a0f6", "red": "ed8796", "maroon": "ee99a0",
        "peach": "f5a97f", "yellow": "eed49f", "green": "a6da95",
        "teal": "8bd5ca", "sky": "91d7e3", "sapphire": "7dc4e4",
        "blue": "8aadf4", "lavender": "b7bdf8",
        "text": "cad3f5", "subtext1": "b8c0e0", "subtext0": "a5adcb",
        "overlay2": "939ab7", "overlay1": "8087a2", "overlay0": "6e738d",
        "surface2": "5b6078", "surface1": "494d64", "surface0": "363a4f",
        "base": "24273a", "mantle": "1e2030", "crust": "181926",
    },
    "catppuccin-latte": {
        "rosewater": "dc8a78", "flamingo": "dd7878", "pink": "ea76cb",
        "mauve": "8839ef", "red": "d20f39", "maroon": "e64553",
        "peach": "fe640b", "yellow": "df8e1d", "green": "40a02b",
        "teal": "179299", "sky": "04a5e5", "sapphire": "209fb5",
        "blue": "1e66f5", "lavender": "7287fd",
        "text": "4c4f69", "subtext1": "5c5f77", "subtext0": "6c6f85",
        "overlay2": "7c7f93", "overlay1": "8c8fa1", "overlay0": "9ca0b0",
        "surface2": "acb0be", "surface1": "bcc0cc", "surface0": "ccd0da",
        "base": "eff1f5", "mantle": "e6e9ef", "crust": "dce0e8",
    },

    # ── Tokyo Night: the purple-blue of a city at night ────────────────────
    "tokyonight-night": {
        "rosewater": "c0caf5", "flamingo": "ff9e64", "pink": "ff007c",
        "mauve": "bb9af7", "red": "f7768e", "maroon": "f7768e",
        "peach": "ff9e64", "yellow": "e0af68", "green": "9ece6a",
        "teal": "73daca", "sky": "7dcfff", "sapphire": "2ac3de",
        "blue": "7aa2f7", "lavender": "bb9af7",
        "text": "c0caf5", "subtext1": "a9b1d6", "subtext0": "9aa5ce",
        "overlay2": "9aa5ce", "overlay1": "737aa2", "overlay0": "565f89",
        "surface2": "545c7e", "surface1": "3b4261", "surface0": "292e42",
        "base": "1a1b26", "mantle": "16161e", "crust": "0f0f14",
    },
    "tokyonight-day": {
        "rosewater": "3760bf", "flamingo": "b15c00", "pink": "d20065",
        "mauve": "9854f1", "red": "f52a65", "maroon": "c64343",
        "peach": "b15c00", "yellow": "8c6c3e", "green": "587539",
        "teal": "118c74", "sky": "007197", "sapphire": "007197",
        "blue": "2e7de9", "lavender": "9854f1",
        "text": "3760bf", "subtext1": "6172b0", "subtext0": "848cb5",
        "overlay2": "848cb5", "overlay1": "9099b2", "overlay0": "a1a6c5",
        "surface2": "c4c8da", "surface1": "d5d9e4", "surface0": "e1e2e7",
        "base": "e1e2e7", "mantle": "d0d5e3", "crust": "c4c8da",
    },

    # ── Gruvbox: warm earth tones, high contrast, a classic ────────────────
    "gruvbox-dark": {
        "rosewater": "ebdbb2", "flamingo": "fe8019", "pink": "d3869b",
        "mauve": "d3869b", "red": "fb4934", "maroon": "cc241d",
        "peach": "fe8019", "yellow": "fabd2f", "green": "b8bb26",
        "teal": "8ec07c", "sky": "83a598", "sapphire": "83a598",
        "blue": "83a598", "lavender": "d3869b",
        "text": "ebdbb2", "subtext1": "d5c4a1", "subtext0": "bdae93",
        "overlay2": "a89984", "overlay1": "928374", "overlay0": "7c6f64",
        "surface2": "665c54", "surface1": "504945", "surface0": "3c3836",
        "base": "282828", "mantle": "1d2021", "crust": "141617",
    },

    # ── Rosé Pine: dusty rose and pine green, understated and elegant ──────
    "rose-pine": {
        "rosewater": "ebbcba", "flamingo": "ebbcba", "pink": "ebbcba",
        "mauve": "c4a7e7", "red": "eb6f92", "maroon": "eb6f92",
        "peach": "ebbcba", "yellow": "f6c177", "green": "9ccfd8",
        "teal": "9ccfd8", "sky": "9ccfd8", "sapphire": "31748f",
        "blue": "31748f", "lavender": "c4a7e7",
        "text": "e0def4", "subtext1": "cdcbe0", "subtext0": "908caa",
        "overlay2": "9d99b5", "overlay1": "908caa", "overlay0": "6e6a86",
        "surface2": "403d52", "surface1": "2f2b45", "surface0": "26233a",
        "base": "191724", "mantle": "1f1d2e", "crust": "16141f",
    },

    # ── Nord: arctic blue, cold and sober ──────────────────────────────────
    "nord": {
        "rosewater": "eceff4", "flamingo": "d08770", "pink": "b48ead",
        "mauve": "b48ead", "red": "bf616a", "maroon": "bf616a",
        "peach": "d08770", "yellow": "ebcb8b", "green": "a3be8c",
        "teal": "8fbcbb", "sky": "88c0d0", "sapphire": "81a1c1",
        "blue": "5e81ac", "lavender": "b48ead",
        "text": "eceff4", "subtext1": "e5e9f0", "subtext0": "d8dee9",
        "overlay2": "8fbcbb", "overlay1": "7b88a1", "overlay0": "616e88",
        "surface2": "4c566a", "surface1": "434c5e", "surface0": "3b4252",
        "base": "2e3440", "mantle": "292e39", "crust": "242933",
    },

    # ── Dracula: vivid purple and pink over blue-grey ──────────────────────
    "dracula": {
        "rosewater": "f8f8f2", "flamingo": "ffb86c", "pink": "ff79c6",
        "mauve": "bd93f9", "red": "ff5555", "maroon": "ff5555",
        "peach": "ffb86c", "yellow": "f1fa8c", "green": "50fa7b",
        "teal": "8be9fd", "sky": "8be9fd", "sapphire": "62d6e8",
        "blue": "6272a4", "lavender": "bd93f9",
        "text": "f8f8f2", "subtext1": "e2e2dc", "subtext0": "c8c8c2",
        "overlay2": "969ec4", "overlay1": "7b88b8", "overlay0": "6272a4",
        "surface2": "565872", "surface1": "4d5066", "surface0": "44475a",
        "base": "282a36", "mantle": "21222c", "crust": "191a21",
    },
}

#: Whether the variant is dark or light. Drives `background` in Neovim, GTK's
#: `prefer-dark`, and the contrast of a few highlights.
IS_DARK = {
    "catppuccin-mocha": True,
    "catppuccin-macchiato": True,
    "catppuccin-latte": False,
    "tokyonight-night": True,
    "tokyonight-day": False,
    "gruvbox-dark": True,
    "rose-pine": True,
    "nord": True,
    "dracula": True,
}

#: The matching Neovim colorscheme. Its plugin must be listed in
#: ~/.config/nvim/lua/plugins/colorscheme.lua.
NVIM_COLORSCHEME = {
    "catppuccin-mocha": "catppuccin-mocha",
    "catppuccin-macchiato": "catppuccin-macchiato",
    "catppuccin-latte": "catppuccin-latte",
    "tokyonight-night": "tokyonight-night",
    "tokyonight-day": "tokyonight-day",
    "gruvbox-dark": "gruvbox",
    "rose-pine": "rose-pine",
    "nord": "nord",
    "dracula": "dracula",
}

#: Dominant color used when searching wallhaven for wallpapers. It must be one
#: of their fixed palette colors; see baixar-wallpapers.py.
WALLHAVEN_COLOR = {
    "catppuccin-mocha": "663399",   # purple
    "catppuccin-macchiato": "993399",
    "catppuccin-latte": "ffffff",   # light
    "tokyonight-night": "333399",   # deep blue
    "tokyonight-day": "cccccc",     # light
    "gruvbox-dark": "cc6633",       # earthy orange
    "rose-pine": "ea4c88",          # pink
    "nord": "0066cc",               # cold blue
    "dracula": "663399",            # purple
}

#: Short label shown in the picker.
DESCRICAO = {
    "catppuccin-mocha": "dark · pastel",
    "catppuccin-macchiato": "dark · soft pastel",
    "catppuccin-latte": "light · pastel",
    "tokyonight-night": "dark · night blue",
    "tokyonight-day": "light · blue",
    "gruvbox-dark": "dark · earthy",
    "rose-pine": "dark · rose and pine",
    "nord": "dark · arctic blue",
    "dracula": "dark · vivid purple",
}

DEFAULT = "catppuccin-mocha"


def get(variant: str) -> dict[str, str]:
    """Returns the theme's palette, falling back to the default on a bad name."""
    return PALETTES.get(variant, PALETTES[DEFAULT])


def variants() -> list[str]:
    """The order themes appear in the menu."""
    return list(PALETTES.keys())
