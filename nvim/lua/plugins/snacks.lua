-- snacks.nvim, a toolbox plugin that replaces a dozen others. Each module is
-- turned on or off with `enabled = true/false`, so you only pay for what you
-- use. Here it provides:
--
--   picker        fuzzy finder (files, grep, symbols, git)
--   dashboard     start screen
--   notifier      styled notifications, replacing the raw messages
--   input         vim.ui.input in a floating window
--   indent        indent guides plus scope highlighting
--   statuscolumn  nicer number/sign/fold column
--   bigfile       disables LSP and treesitter in huge files
--   quickfile     renders the file before loading the plugins
--   words         highlights other occurrences of the word under the cursor
--   lazygit       opens lazygit in a floating window, already themed
--   scope         improves scope-based textobjects and motions
--   bufdelete     closes buffers without destroying the window layout
--
-- See `:h snacks.nvim`, and `:lua Snacks.picker()` lists every picker.

return {
  "folke/snacks.nvim",
  priority = 900,
  lazy = false, -- required by the startup modules (bigfile, quickfile)
  ---@type snacks.Config
  opts = {
    -- ── Enabled modules ────────────────────────────────────────
    bigfile = { enabled = true }, -- over 1.5MB, drop syntax/LSP to stay responsive
    quickfile = { enabled = true }, -- show the file before loading plugins
    input = { enabled = true },
    scope = { enabled = true },
    words = { enabled = true }, -- ]] and [[ jump between references of the word

    notifier = {
      enabled = true,
      timeout = 3000,
      style = "compact",
    },

    indent = {
      enabled = true,
      indent = { char = "│" },
      scope = { char = "│" }, -- highlight the current block
      animate = { enabled = false }, -- animation costs CPU; enable if you like it
    },

    statuscolumn = {
      enabled = true,
      left = { "mark", "sign" },
      right = { "fold", "git" },
      folds = { open = true, git_hl = true },
    },

    picker = {
      enabled = true,
      -- Makes vim.ui.select use the picker, which affects LSP code actions.
      ui_select = true,
      layout = { preset = "default" }, -- also "ivy", "vscode", "telescope"
      matcher = { frecency = true }, -- ranks what you open most often first
      win = {
        input = {
          keys = {
            ["<Esc>"] = { "close", mode = { "n", "i" } },
          },
        },
      },
    },

    dashboard = {
      enabled = true,
      preset = {
        header = [[
    ███╗   ██╗ ███████╗ ██████╗  ██╗   ██╗ ██╗ ███╗   ███╗
    ████╗  ██║ ██╔════╝██╔═══██╗ ██║   ██║ ██║ ████╗ ████║
    ██╔██╗ ██║ █████╗  ██║   ██║ ██║   ██║ ██║ ██╔████╔██║
    ██║╚██╗██║ ██╔══╝  ██║   ██║ ╚██╗ ██╔╝ ██║ ██║╚██╔╝██║
    ██║ ╚████║ ███████╗╚██████╔╝  ╚████╔╝  ██║ ██║ ╚═╝ ██║
    ╚═╝  ╚═══╝ ╚══════╝ ╚═════╝    ╚═══╝   ╚═╝ ╚═╝     ╚═╝
]],
        keys = {
          { icon = " ", key = "f", desc = "Find file", action = ":lua Snacks.dashboard.pick('files')" },
          { icon = " ", key = "n", desc = "New file", action = ":ene | startinsert" },
          { icon = " ", key = "g", desc = "Find text", action = ":lua Snacks.dashboard.pick('live_grep')" },
          { icon = " ", key = "r", desc = "Recent files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
          {
            icon = " ",
            key = "c",
            desc = "Config",
            action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })",
          },
          { icon = "󰒲 ", key = "l", desc = "Plugins (Lazy)", action = ":Lazy" },
          { icon = " ", key = "m", desc = "LSPs (Mason)", action = ":Mason" },
          { icon = " ", key = "q", desc = "Quit", action = ":qa" },
        },
      },
      sections = {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      },
    },

    lazygit = {
      enabled = true,
      configure = true, -- pushes Neovim's current theme into lazygit
    },

    -- ── Modules deliberately turned off ────────────────────────
    explorer = { enabled = false }, -- neo-tree is used instead (plugins/editor.lua)
    terminal = { enabled = false }, -- toggleterm is used instead (plugins/terminal.lua)
    scroll = { enabled = false }, -- smooth scrolling looks nice but costs CPU
  },

  -- ── Keymaps ──────────────────────────────────────────────────
  -- stylua: ignore
  -- (stylua would split each entry across 5 lines because of the anonymous
  --  functions; the table is easier to read compact)
  keys = {
    -- ── Main search ───────────────────────────────────────────
    { "<leader><space>", function() Snacks.picker.smart() end, desc = "Smart file search" },
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Files" },
    { "<leader>fg", function() Snacks.picker.git_files() end, desc = "Git-tracked files" },
    { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent files" },
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Open buffers" },
    { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Config files" },
    { "<leader>fp", function() Snacks.picker.projects() end, desc = "Projects" },

    -- NvChad names for the same pickers, so the muscle memory carries over.
    { "<leader>fa", function() Snacks.picker.files({ hidden = true, ignored = true }) end, desc = "All files (hidden and ignored)" },
    { "<leader>fw", function() Snacks.picker.grep() end, desc = "Grep the project (live grep)" },
    { "<leader>fh", function() Snacks.picker.help() end, desc = "Help pages" },
    { "<leader>fo", function() Snacks.picker.recent() end, desc = "Recent files (oldfiles)" },
    { "<leader>fz", function() Snacks.picker.lines() end, desc = "Search the current buffer" },
    { "<leader>ma", function() Snacks.picker.marks() end, desc = "Marks" },
    { "<leader>cm", function() Snacks.picker.git_log() end, desc = "Git commits" },
    { "<leader>gt", function() Snacks.picker.git_status() end, desc = "Git status" },

    -- ── Content search ────────────────────────────────────────
    { "<leader>sg", function() Snacks.picker.grep() end, desc = "Grep the project" },
    { "<leader>sw", function() Snacks.picker.grep_word() end, desc = "Grep the word or selection", mode = { "n", "x" } },
    { "<leader>sb", function() Snacks.picker.lines() end, desc = "Search the current buffer" },
    { "<leader>sB", function() Snacks.picker.grep_buffers() end, desc = "Grep the open buffers" },

    -- ── Vim and help ──────────────────────────────────────────
    { "<leader>sh", function() Snacks.picker.help() end, desc = "Help pages" },
    { "<leader>sk", function() Snacks.picker.keymaps() end, desc = "Keymaps" },
    { "<leader>sc", function() Snacks.picker.commands() end, desc = "Commands" },
    { "<leader>s:", function() Snacks.picker.command_history() end, desc = "Command history" },
    { "<leader>sm", function() Snacks.picker.marks() end, desc = "Marks" },
    { "<leader>s\"", function() Snacks.picker.registers() end, desc = "Registers" },
    { "<leader>su", function() Snacks.picker.undo() end, desc = "Undo tree" },
    { "<leader>sn", function() Snacks.picker.notifications() end, desc = "Notifications" },
    { "<leader>sl", function() Snacks.picker.resume() end, desc = "Resume the last search" },
    { "<leader>sq", function() Snacks.picker.qflist() end, desc = "Quickfix list" },

    -- ── Diagnostics and symbols (LSP) ─────────────────────────
    -- These are for finding one item; to walk the whole list use Trouble on
    -- <leader>xx (see lua/plugins/trouble.lua).
    { "<leader>sd", function() Snacks.picker.diagnostics() end, desc = "Project diagnostics" },
    { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end, desc = "Buffer diagnostics" },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end, desc = "Document symbols" },
    { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Workspace symbols" },

    -- ── Git ───────────────────────────────────────────────────
    { "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit (floating)" },
    { "<leader>gf", function() Snacks.lazygit.log_file() end, desc = "Lazygit: file history" },
    { "<leader>gl", function() Snacks.picker.git_log() end, desc = "Git log" },
    { "<leader>gL", function() Snacks.picker.git_log_line() end, desc = "Line log" },
    { "<leader>gs", function() Snacks.picker.git_status() end, desc = "Git status" },
    { "<leader>gb", function() Snacks.picker.git_branches() end, desc = "Branches" },
    { "<leader>gB", function() Snacks.gitbrowse() end, desc = "Open in the browser (GitHub)", mode = { "n", "x" } },

    -- ── Buffers ───────────────────────────────────────────────
    { "<leader>x", function() Snacks.bufdelete() end, desc = "Close buffer (keeps the layout)" },
    { "<leader>Bd", function() Snacks.bufdelete() end, desc = "Close buffer (keeps the layout)" },
    { "<leader>Bo", function() Snacks.bufdelete.other() end, desc = "Close the other buffers" },

    -- ── Utilities ─────────────────────────────────────────────
    { "<leader>cR", function() Snacks.rename.rename_file() end, desc = "Rename file (notifies the LSP)" },
    { "<leader>un", function() Snacks.notifier.hide() end, desc = "Hide notifications" },
    { "<leader>uz", function() Snacks.zen() end, desc = "Zen mode" },
    { "]]", function() Snacks.words.jump(vim.v.count1) end, desc = "Next reference", mode = { "n", "t" } },
    { "[[", function() Snacks.words.jump(-vim.v.count1) end, desc = "Previous reference", mode = { "n", "t" } },
  },

  init = function()
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      callback = function()
        -- Makes `Snacks` available as a global (used by the keys above) and
        -- improves the output of :lua and vim.print.
        _G.dd = function(...) Snacks.debug.inspect(...) end
        vim.print = _G.dd
      end,
    })
  end,
}
