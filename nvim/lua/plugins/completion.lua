-- blink.cmp, the autocompletion engine.
--
-- Chosen over nvim-cmp because its fuzzy matcher is written in Rust (SIMD),
-- taking roughly 0.5ms per keystroke against ~20ms for nvim-cmp on large
-- projects, and because LSP, snippets, path, buffer, cmdline, signature help
-- and auto-brackets all ship together instead of needing eight plugins.
-- `version = "1.*"` downloads a prebuilt Rust binary, so cargo isn't required
-- — though blink compiles locally when cargo is available, which is better.
--
-- Keys:
--   <C-space>     open the menu / open the documentation
--   <C-n> <C-p>   next / previous
--   <C-y>         accept
--   <C-e>         cancel
--   <C-k>         show the function signature
--   <Tab> <S-Tab> move between snippet fields
--
-- Docs: https://cmp.saghen.dev

return {
  "saghen/blink.cmp",
  version = "1.*", -- stable tag, so it uses the prebuilt release binaries
  event = { "InsertEnter", "CmdlineEnter" },

  dependencies = {
    -- A large collection of ready-made VSCode-style snippets for dozens of
    -- languages. blink reads them directly, without needing LuaSnip.
    "rafamadriz/friendly-snippets",
  },

  ---@module "blink.cmp"
  ---@type blink.cmp.Config
  opts = {
    keymap = {
      -- "enter" makes <Enter> accept the selected item; with nothing
      -- selected it falls back to inserting a newline. Pick an item with
      -- <C-n>/<C-p> or the arrow keys. Alternatives are "default" (only <C-y>
      -- accepts) and "super-tab" (<Tab> accepts).
      preset = "enter",

      -- The "enter" preset does not map <C-y>. Since that is the classic
      -- accept key (and nvim-cmp's default), it is added here as a second way.
      ["<C-y>"] = { "accept", "fallback" },
    },

    appearance = {
      -- "mono" for regular Nerd Fonts, "normal" for Nerd Font Mono.
      nerd_font_variant = "mono",
    },

    completion = {
      -- Documentation window beside the selected item.
      documentation = {
        auto_show = true,
        auto_show_delay_ms = 200,
        window = { border = "rounded" },
      },

      menu = {
        border = "rounded",
        draw = {
          -- Highlight suggestions with Treesitter, matching the code colors.
          treesitter = { "lsp" },
          columns = {
            { "label", "label_description", gap = 1 },
            { "kind_icon", "kind", gap = 1 },
          },
        },
      },

      -- Insert ( ) automatically when accepting a function.
      accept = { auto_brackets = { enabled = true } },

      -- `preselect = false` is the right partner for the "enter" preset:
      -- nothing is selected on its own, so <Enter> only completes when you
      -- picked an item with <C-n>/<C-p> or the arrows. Otherwise the first
      -- item would always be preselected and <Enter> would accept a
      -- suggestion when you only wanted a newline. Set `preselect = true` to
      -- have the first item selected instead.
      list = { selection = { preselect = false, auto_insert = false } },

      -- Ghost text (Copilot style) previewing what will be inserted.
      ghost_text = { enabled = false },
    },

    -- Function signature shown while typing the arguments.
    signature = {
      enabled = true,
      window = { border = "rounded" },
    },

    sources = {
      -- Order barely matters (the score decides), but the list defines what exists.
      default = { "lsp", "path", "snippets", "buffer" },
      providers = {
        -- Lower the buffer score so LSP suggestions always come first.
        buffer = { score_offset = -3 },
        path = { score_offset = 3 },
      },
    },

    -- Completion in the command line too (:e, :h, :Lazy).
    cmdline = {
      enabled = true,
      completion = { menu = { auto_show = true } },
    },

    fuzzy = {
      -- Use the Rust matcher; if the binary is missing, warn and fall back to Lua.
      implementation = "prefer_rust_with_warning",
      -- Learns from what you accept and ranks those items higher.
      frecency = { enabled = true },
      -- Boosts items that appear near the cursor in the file.
      use_proximity = true,
    },
  },

  -- Lets other files add sources without overwriting the list.
  opts_extend = { "sources.default" },
}
