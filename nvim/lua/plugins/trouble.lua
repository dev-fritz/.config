-- trouble.nvim, the list panel.
--
-- The native quickfix is a list of lines with no context. Trouble shows the
-- same information grouped by file, with a preview, and lets you jump straight
-- into the code without closing the panel. It handles diagnostics, LSP
-- references, symbols (outline), TODOs, quickfix and loclist through one
-- interface.
--
-- Picker versus Trouble: use Snacks.picker (<leader>s) when you want to find
-- one thing and go to it, and Trouble (<leader>x) when you want to walk
-- through an entire list.
--
-- Inside the panel: <CR> opens, o/O split, q closes, ? shows help, s sorts,
-- zM folds everything.

return {
  "folke/trouble.nvim",
  cmd = { "Trouble" },

  opts = {
    focus = true, -- move the cursor into the panel when it opens
    warn_no_results = false, -- don't complain when the list is empty
    open_no_results = true, -- open even when empty, so you can see it cleared

    modes = {
      -- Custom mode: diagnostics and symbols side by side, useful for
      -- reviewing a large file in one pass.
      diagnostics_and_symbols = {
        mode = "diagnostics",
        win = { position = "right", size = 0.3 },
      },
      -- A leaner outline: only the essentials of the file's structure.
      symbols = {
        desc = "file structure",
        win = { position = "right", size = 0.25 },
        filter = {
          any = {
            { ft = "help", lang = "vimdoc" },
            {
              ft = "lua",
              kind = { "Class", "Constructor", "Enum", "Field", "Function", "Interface", "Method", "Module", "Struct" },
            },
            -- For other filetypes, hide variables and packages, otherwise
            -- the outline becomes a huge list of irrelevant entries.
            {
              kind = {
                "Class",
                "Constructor",
                "Enum",
                "Function",
                "Interface",
                "Method",
                "Module",
                "Namespace",
                "Struct",
                "Trait",
              },
            },
          },
        },
      },
    },
  },

  -- stylua: ignore
  keys = {
    { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", desc = "Project diagnostics" },
    { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Diagnostics for this file" },
    { "<leader>xs", "<cmd>Trouble symbols toggle<CR>", desc = "File structure (outline)" },
    { "<leader>xr", "<cmd>Trouble lsp toggle win.position=right<CR>", desc = "References and definitions (LSP)" },
    { "<leader>xq", "<cmd>Trouble qflist toggle<CR>", desc = "Quickfix list" },
    { "<leader>xl", "<cmd>Trouble loclist toggle<CR>", desc = "Location list" },
    { "<leader>xc", "<cmd>Trouble close<CR>", desc = "Close the panel" },

    -- Walk the list without leaving the file; the panel can even be closed.
    { "]x", function() require("trouble").next({ skip_groups = true, jump = true }) end, desc = "Next Trouble item" },
    { "[x", function() require("trouble").prev({ skip_groups = true, jump = true }) end, desc = "Previous Trouble item" },
  },
}
