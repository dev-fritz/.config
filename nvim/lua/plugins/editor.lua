-- Editing and navigation plugins.
--
--   which-key      shows the available keymaps while you type
--   todo-comments  highlights and indexes TODO / FIXME / HACK / NOTE
--   gitsigns       git signs in the gutter plus per-hunk actions
--   neo-tree       file tree in a side panel
--   oil.nvim       edit the filesystem as if it were a buffer
--   mini.pairs     auto-closes brackets and quotes
--   mini.surround  add, change and remove quotes, brackets and tags
--   flash.nvim     jump anywhere on screen
--   grug-far       project-wide search and replace

return {
  -- ── which-key, the keymap menu ───────────────────────────────────────
  -- Hold <leader> for 300ms (the timeoutlen from options.lua) and it lists
  -- everything that can follow.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix", -- vertical panel on the right; also "classic" or "modern"
      delay = function(ctx) return ctx.plugin and 0 or 300 end,
      -- Group names, which turn "<leader>f?" into a labeled menu.
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code / LSP" },
        { "<leader>d", group = "debug (DAP)" },
        { "<leader>dg", group = "debug: language tests" },
        { "<leader>f", group = "files" },
        { "<leader>g", group = "git" },
        { "<leader>gh", group = "hunk" },
        { "<leader>s", group = "search" },
        { "<leader>t", group = "terminal" },
        { "<leader>u", group = "UI toggles" },
        { "<leader>x", group = "diagnostics / lists" },
        { "[", group = "previous" },
        { "]", group = "next" },
        { "g", group = "go to" },
      },
    },
    -- stylua: ignore
    keys = {
      { "<leader>?", function() require("which-key").show({ global = false }) end, desc = "Keymaps for this buffer" },
    },
  },

  -- ── todo-comments, highlight and search tagged comments ──────────────
  -- Recognizes TODO: FIXME: HACK: WARN: PERF: NOTE: TEST:
  -- The trailing colon is required for the highlight to show up.
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      signs = true, -- icon in the sign column
      sign_priority = 8,
      keywords = {
        FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "FIXIT", "ISSUE", "CORRIGIR" } },
        TODO = { icon = " ", color = "info", alt = { "FAZER" } },
        HACK = { icon = " ", color = "warning", alt = { "GAMBIARRA" } },
        WARN = { icon = " ", color = "warning", alt = { "WARNING", "XXX", "ATENCAO" } },
        PERF = { icon = " ", alt = { "OPTIM", "PERFORMANCE", "OPTIMIZE" } },
        NOTE = { icon = " ", color = "hint", alt = { "INFO", "OBS" } },
        TEST = { icon = "⏲ ", color = "test", alt = { "TESTING", "PASSED", "FAILED" } },
      },
      highlight = {
        multiline = true, -- highlight multi-line comments
        keyword = "wide", -- highlight the keyword plus the icon
        after = "fg", -- color the text after the keyword ("" for none)
        pattern = [[.*<(KEYWORDS)\s*:]],
      },
      search = {
        command = "rg",
        args = { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column" },
        pattern = [[\b(KEYWORDS):]],
      },
    },
    -- stylua: ignore
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous TODO" },
      { "<leader>st", function() Snacks.picker.todo_comments() end, desc = "List project TODOs" },
      { "<leader>sT", function() Snacks.picker.todo_comments({ keywords = { "TODO", "FIX", "FIXME" } }) end, desc = "List only TODO/FIX" },
      { "<leader>xt", "<cmd>Trouble todo toggle<CR>", desc = "TODOs in the Trouble panel" },
    },
  },

  -- ── gitsigns, git inside the buffer ──────────────────────────────────
  -- A "hunk" is a contiguous block of changes. You can jump between them,
  -- preview the diff, and stage or reset them one at a time.
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      signs_staged_enable = true,
      current_line_blame = false, -- enable with <leader>gt
      current_line_blame_opts = {
        virt_text_pos = "eol",
        delay = 500,
      },
      current_line_blame_formatter = "  <author>, <author_time:%d/%m/%Y> · <summary>",

      on_attach = function(buf)
        local gs = require("gitsigns")

        local function map(mode, key, fn, desc) vim.keymap.set(mode, key, fn, { buffer = buf, desc = "Git: " .. desc }) end

        -- ── Hunk navigation ────────────────────────────────────────────
        map("n", "]h", function()
          if vim.wo.diff then
            vim.cmd("normal! ]c")
          else
            gs.nav_hunk("next")
          end
        end, "Next change")

        map("n", "[h", function()
          if vim.wo.diff then
            vim.cmd("normal! [c")
          else
            gs.nav_hunk("prev")
          end
        end, "Previous change")

        -- ── Per-hunk actions ───────────────────────────────────────────
        map("n", "<leader>ghs", gs.stage_hunk, "Stage hunk")
        map("n", "<leader>ghr", gs.reset_hunk, "Reset hunk")
        --- Line range of the current visual selection.
        local function range() return { vim.fn.line("."), vim.fn.line("v") } end

        map("v", "<leader>ghs", function() gs.stage_hunk(range()) end, "Stage selection")
        map("v", "<leader>ghr", function() gs.reset_hunk(range()) end, "Reset selection")
        map("n", "<leader>ghp", gs.preview_hunk_inline, "Preview hunk")
        map("n", "<leader>ghS", gs.stage_buffer, "Stage the whole file")
        map("n", "<leader>ghR", gs.reset_buffer, "Reset the whole file")
        map("n", "<leader>ghb", function() gs.blame_line({ full = true }) end, "Full line blame")

        -- ── Diffs ──────────────────────────────────────────────────────
        map("n", "<leader>gd", gs.diffthis, "Diff against the index")
        map("n", "<leader>gD", function() gs.diffthis("~") end, "Diff against the last commit")

        -- ── Toggles ────────────────────────────────────────────────────
        map("n", "<leader>gt", gs.toggle_current_line_blame, "Toggle inline blame")

        -- ── Text object: "ih" is the hunk under the cursor ─────────────
        map({ "o", "x" }, "ih", gs.select_hunk, "Select hunk")
      end,
    },
  },

  -- ── neo-tree, the side file tree ─────────────────────────────────────
  -- Inside the tree: a=create d=delete r=rename x=cut c=copy p=paste
  -- H=show hidden ?=help
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle reveal<CR>", desc = "File explorer" },
      { "<leader>E", "<cmd>Neotree toggle git_status<CR>", desc = "Explorer: git changes" },
      { "<leader>fe", "<cmd>Neotree toggle reveal<CR>", desc = "File explorer" },
    },
    opts = {
      close_if_last_window = true, -- never leave the tree alone on screen
      popup_border_style = "rounded",
      enable_git_status = true,
      enable_diagnostics = true,
      sources = { "filesystem", "buffers", "git_status" },

      default_component_configs = {
        indent = {
          with_expanders = true,
          expander_collapsed = "",
          expander_expanded = "",
        },
        git_status = {
          symbols = {
            added = "",
            modified = "",
            deleted = "✖",
            renamed = "󰁕",
            untracked = "",
            ignored = "",
            unstaged = "󰄱",
            staged = "",
            conflict = "",
          },
        },
      },

      window = {
        width = 32,
        mappings = {
          ["<space>"] = "none", -- free the leader key inside the tree
          ["l"] = "open",
          ["h"] = "close_node",
          ["<CR>"] = "open",
          ["s"] = "open_split",
          ["v"] = "open_vsplit",
          ["Y"] = function(state) -- copy the file path
            local path = state.tree:get_node().path
            vim.fn.setreg("+", path)
            vim.notify("Copied: " .. path, vim.log.levels.INFO)
          end,
        },
      },

      filesystem = {
        bind_to_cwd = false, -- the tree doesn't change Neovim's :pwd
        follow_current_file = { enabled = true }, -- reveal the open file
        use_libuv_file_watcher = true, -- refresh on disk changes
        filtered_items = {
          visible = false, -- H toggles visibility
          hide_dotfiles = false,
          hide_gitignored = true,
          hide_by_name = { "node_modules", ".git" },
        },
      },
    },
  },

  -- ── oil.nvim, the filesystem as an editable buffer ───────────────────
  -- Press `-` and the directory opens as text. Renaming is editing a line,
  -- deleting is deleting a line, creating is writing a new name. Save with :w
  -- to apply everything, so renaming 30 files becomes one `:%s/.../.../`.
  -- It complements neo-tree rather than replacing it.
  {
    "stevearc/oil.nvim",
    lazy = false, -- must be active to open `nvim .` on a directory
    opts = {
      default_file_explorer = true, -- replaces netrw
      delete_to_trash = true, -- deleting moves to the trash instead of vanishing
      skip_confirm_for_simple_edits = false,
      view_options = {
        show_hidden = true,
      },
      keymaps = {
        ["<C-h>"] = false, -- freed up for window navigation
        ["<C-l>"] = false,
        ["q"] = "actions.close",
      },
    },
    -- stylua: ignore
    keys = {
      { "-", "<cmd>Oil<CR>", desc = "Open the parent directory (oil)" },
      { "<leader>fo", function() require("oil").toggle_float() end, desc = "Oil in a floating window" },
    },
  },

  -- ── mini.pairs, auto-closes delimiters ───────────────────────────────
  {
    "echasnovski/mini.pairs",
    event = "InsertEnter",
    opts = {
      modes = { insert = true, command = true, terminal = false },
      -- Do not auto-close when the next character is one of these.
      skip_next = [=[[%w%%%'%[%"%.%`%$]]=],
      skip_ts = { "string" }, -- nor inside strings
      skip_unbalanced = true, -- avoid closing an already closed bracket
      markdown = true, -- handle ``` code fences
    },
  },

  -- ── mini.surround, edit what wraps the text ──────────────────────────
  --   gsa iw "   wrap the word in quotes
  --   gsd "      remove the quotes
  --   gsr " '    swap double quotes for single ones
  {
    "echasnovski/mini.surround",
    keys = {
      { "gsa", desc = "Surround (add)", mode = { "n", "v" } },
      { "gsd", desc = "Surround (delete)" },
      { "gsr", desc = "Surround (replace)" },
      { "gsf", desc = "Go to the start" },
      { "gsF", desc = "Go to the end" },
      { "gsh", desc = "Highlight" },
    },
    opts = {
      mappings = {
        add = "gsa",
        delete = "gsd",
        find = "gsf",
        find_left = "gsF",
        highlight = "gsh",
        replace = "gsr",
        update_n_lines = "gsn",
      },
    },
  },

  -- ── flash.nvim, jump anywhere on screen ──────────────────────────────
  -- Press `s` and type 2 letters: every match gets a label, and typing the
  -- label moves the cursor there.
  --
  --   s   jump (also works after d, c, y — `ds` deletes up to the target)
  --   S   jump by Treesitter node, selecting whole blocks
  --   R   refine the Treesitter selection
  --   r   operator mode: act on a remote target without moving (`yr` yanks
  --       something far away and the cursor comes back on its own)
  --
  -- It also improves the native f/t/;/, which start crossing lines and show
  -- labels when there are many candidates. Native `s` is the same as `cl`,
  -- so nothing of value is lost by rebinding it.
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      modes = {
        -- Enhanced f, t, ; and ,.
        char = {
          enabled = true,
          jump_labels = true, -- show labels when there are many options
          multi_line = false, -- keep the native single-line behavior
        },
        -- During a `/` search, <C-s> labels the results.
        search = { enabled = false }, -- off: it interferes with incsearch
      },
      label = {
        uppercase = false, -- lowercase labels only, less visual noise
        rainbow = { enabled = false },
      },
      jump = { autojump = false }, -- do not jump automatically on a single match
    },
    -- stylua: ignore
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash: jump" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash: jump by Treesitter node" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Flash: operate on a remote target" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Flash: refine selection" },
      { "<C-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Flash: toggle during search" },
    },
  },

  -- ── grug-far.nvim, project-wide search and replace ───────────────────
  -- Opens a buffer with fields for the search, the replacement and path/file
  -- filters. Results update live as you type and are only written to disk
  -- once you confirm.
  --
  -- Inside the buffer:
  --   <leader>r  apply everything    <leader>s  sync a single result
  --   <leader>a  abort               <leader>?  help with every key
  --
  -- Accepts ripgrep regex and capture groups ($1, $2) in the replacement.
  -- Requires `rg`.
  {
    "MagicDuck/grug-far.nvim",
    cmd = { "GrugFar", "GrugFarWithin" },
    opts = {
      headerMaxWidth = 80,
      -- Open in a vertical split so the code stays visible.
      windowCreationCommand = "vsplit",
    },
    -- stylua: ignore
    keys = {
      {
        "<leader>sr",
        function()
          local grug = require("grug-far")
          -- Pre-fills the filter with the current filetype (*.lua, *.go),
          -- the most common case. Clear the field to search everything.
          local ext = vim.fn.expand("%:e")
          grug.open({ transient = true, prefills = { paths = "", filesFilter = ext ~= "" and ("*." .. ext) or "" } })
        end,
        desc = "Search and replace in the project",
      },
      {
        "<leader>sr",
        mode = "x",
        function() require("grug-far").with_visual_selection({ transient = true }) end,
        desc = "Search and replace (from selection)",
      },
      {
        "<leader>sR",
        function() require("grug-far").open({ transient = true }) end,
        desc = "Search and replace (all files)",
      },
    },
  },
}
