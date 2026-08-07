-- Colorschemes.
--
-- All of them are `lazy = true`: lazy.nvim loads a theme plugin on its own the
-- moment the matching `:colorscheme` runs, so every theme is installed but
-- only one is loaded at boot.
--
-- Switch with <leader>ut (picker with preview) or `:Theme <name>`. The choice
-- is saved in ~/.local/state/nvim/theme.json.
--
-- Available variants:
--   catppuccin-latte / -frappe / -macchiato / -mocha
--   tokyonight-night / -storm / -moon / -day
--   gruvbox (light/dark via `:set background=…`)
--   rose-pine-main / -moon / -dawn
--   nord
--   dracula
--
-- Adding another theme is just a matter of adding a spec here; it shows up in
-- the picker automatically. Delete the block to remove one.

return {
  -- ── Catppuccin, the default here ─────────────────────────────
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
    priority = 1000, -- if loaded at boot, it loads before everything else
    opts = {
      flavour = "auto", -- follows `background`: mocha when dark, latte when light
      background = { light = "latte", dark = "mocha" },
      transparent_background = false, -- true uses the terminal background
      show_end_of_buffer = false,
      term_colors = true, -- apply the palette inside :terminal too
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
      },
      -- Per-plugin highlighting; true enables the integration.
      integrations = {
        blink_cmp = true,
        gitsigns = true,
        neotree = true,
        snacks = true,
        treesitter = true,
        which_key = true,
        mason = true,
        markdown = true,
        notify = true,
        lsp_trouble = false,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "undercurl" },
            hints = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
          },
        },
      },
    },
  },

  -- ── Tokyonight ───────────────────────────────────────────────
  {
    "folke/tokyonight.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      style = "moon", -- used by `:colorscheme tokyonight`
      light_style = "day",
      transparent = false,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
    },
  },

  -- ── Gruvbox ──────────────────────────────────────────────────
  {
    "ellisonleao/gruvbox.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      contrast = "", -- "hard", "soft" or "" for medium
      transparent_mode = false,
      italic = { strings = false, comments = true },
      bold = true,
    },
  },

  -- ── Nord, arctic blue ────────────────────────────────────────
  {
    "gbprod/nord.nvim",
    lazy = true,
    priority = 1000,
    opts = {
      transparent = false,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
    },
  },

  -- ── Dracula, vivid purple and pink ───────────────────────────
  {
    "Mofiqul/dracula.nvim",
    name = "dracula",
    lazy = true,
    priority = 1000,
    opts = {
      transparent_bg = false,
      italic_comment = true,
    },
  },

  -- ── Rosé Pine ────────────────────────────────────────────────
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = true,
    priority = 1000,
    opts = {
      variant = "auto", -- main when dark, dawn when light
      dark_variant = "main",
      styles = {
        italic = true,
        transparency = false,
      },
    },
  },
}
