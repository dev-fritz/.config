-- Treesitter builds a real syntax tree for the file, which gives correct
-- highlighting (rather than regex guesswork), folds that respect the code
-- structure, smarter indentation and semantic text objects such as "delete the
-- whole function".
--
-- This uses the `main` branch, the plugin rewrite and the only version
-- supported on Neovim 0.12+. It is far more manual than the old `master`
-- branch — nothing is enabled automatically, hence the FileType autocommand
-- below.
--
-- System dependencies: `tree-sitter-cli` and a C compiler.
-- On Arch: sudo pacman -S tree-sitter-cli gcc
--
-- Commands:
--   :TSInstall <lang>  install a parser
--   :TSUpdate          update all of them (run after `:Lazy update`)
--   :InspectTree       view the syntax tree of the current file
--   :Inspect           view which highlight is under the cursor

-- Parsers installed automatically. Full list:
-- https://github.com/nvim-treesitter/nvim-treesitter/blob/main/SUPPORTED_LANGUAGES.md
local parsers = {
  -- Essentials, used by Neovim for help, commits and so on.
  "bash",
  "diff",
  "git_config",
  "git_rebase",
  "gitcommit",
  "gitignore",
  "markdown",
  "markdown_inline",
  "query", -- treesitter's own queries
  "regex",
  "toml",
  "vim",
  "vimdoc",
  "yaml",

  -- Lua / Neovim
  "lua",
  "luadoc",

  -- Web
  "css",
  "html",
  "javascript",
  "jsdoc",
  "json",
  "scss",
  "tsx",
  "typescript",

  -- Python
  "python",

  -- Go
  "go",
  "gomod",
  "gosum",
  "gowork",

  -- Rust
  "rust",

  -- C / C++
  "c",
  "cpp",
  "cmake",
  "make",

  -- Extras that come up day to day
  "dockerfile",
  "sql",
}

return {
  -- ── Core ─────────────────────────────────────────────────────────────
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false, -- the main branch does not support lazy-loading
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({
        install_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site"),
      })

      -- Async install, so the first run doesn't block Neovim.
      require("nvim-treesitter").install(parsers)

      -- On the `main` branch nothing enables itself. This autocommand turns
      -- on highlighting, folds and indentation for any filetype with an
      -- installed parser.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("user_treesitter", { clear = true }),
        desc = "Enable Treesitter when a parser exists for the filetype",
        callback = function(event)
          local ft = vim.bo[event.buf].filetype
          local lang = vim.treesitter.language.get_lang(ft)
          if not lang then
            return
          end

          -- `language.add` returns false when the parser isn't installed.
          -- Kept silent on purpose: opening a .zig without a parser should
          -- not raise an error.
          local ok = pcall(vim.treesitter.language.add, lang)
          if not ok then
            return
          end

          pcall(vim.treesitter.start, event.buf, lang)

          -- Treesitter-based indentation. The plugin marks this experimental,
          -- so comment the line out if a language indents strangely.
          vim.bo[event.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })
    end,
  },

  -- ── Semantic text objects ────────────────────────────────────────────
  -- Makes "the function", "the argument" and "the class" valid targets:
  --   daf  delete the whole function
  --   cia  change the argument under the cursor
  --   ]f   jump to the next function
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    event = { "BufReadPost", "BufNewFile" },
    init = function()
      -- Disable the per-filetype maps Neovim defines (]], [m and friends).
      -- Without this, Python's ftplugin hijacks keys used here.
      vim.g.no_plugin_maps = true
    end,
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          lookahead = true, -- jump to the next target when none is under the cursor
          selection_modes = {
            ["@function.outer"] = "V", -- selecting a function uses linewise mode
            ["@class.outer"] = "V",
          },
        },
        move = { set_jumps = true }, -- record in the jumplist, so <C-o> goes back
      })

      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")
      local swap = require("nvim-treesitter-textobjects.swap")

      -- ── Select, used with d, c, y, v ─────────────────────────────────
      local objects = {
        f = { "@function.outer", "@function.inner", "function" },
        c = { "@class.outer", "@class.inner", "class" },
        a = { "@parameter.outer", "@parameter.inner", "argument" },
        l = { "@loop.outer", "@loop.inner", "loop" },
        i = { "@conditional.outer", "@conditional.inner", "conditional" },
        ["/"] = { "@comment.outer", "@comment.inner", "comment" },
      }

      for key, spec in pairs(objects) do
        local outer, inner, label = spec[1], spec[2], spec[3]
        vim.keymap.set(
          { "x", "o" },
          "a" .. key,
          function() select.select_textobject(outer, "textobjects") end,
          { desc = "Around the " .. label }
        )
        vim.keymap.set(
          { "x", "o" },
          "i" .. key,
          function() select.select_textobject(inner, "textobjects") end,
          { desc = "Inside the " .. label }
        )
      end

      -- ── Movement ─────────────────────────────────────────────────────
      local moves = {
        ["]f"] = { move.goto_next_start, "@function.outer", "Next function" },
        ["]F"] = { move.goto_next_end, "@function.outer", "End of the next function" },
        ["[f"] = { move.goto_previous_start, "@function.outer", "Previous function" },
        ["[F"] = { move.goto_previous_end, "@function.outer", "End of the previous function" },
        ["]a"] = { move.goto_next_start, "@parameter.inner", "Next argument" },
        ["[a"] = { move.goto_previous_start, "@parameter.inner", "Previous argument" },
      }

      for key, spec in pairs(moves) do
        local fn, query, desc = spec[1], spec[2], spec[3]
        vim.keymap.set({ "n", "x", "o" }, key, function() fn(query, "textobjects") end, { desc = desc })
      end

      -- ]c and [c move between classes, but inside a diff (:diffthis, git
      -- mergetool) they fall back to "next change", the native Vim behavior
      -- and what you expect there.
      vim.keymap.set({ "n", "x", "o" }, "]c", function()
        if vim.wo.diff then
          return vim.cmd("normal! ]c")
        end
        move.goto_next_start("@class.outer", "textobjects")
      end, { desc = "Next class (or diff)" })

      vim.keymap.set({ "n", "x", "o" }, "[c", function()
        if vim.wo.diff then
          return vim.cmd("normal! [c")
        end
        move.goto_previous_start("@class.outer", "textobjects")
      end, { desc = "Previous class (or diff)" })

      -- ── Swap ─────────────────────────────────────────────────────────
      vim.keymap.set(
        "n",
        "<leader>cA",
        function() swap.swap_next("@parameter.inner") end,
        { desc = "Move the argument right" }
      )

      vim.keymap.set(
        "n",
        "<leader>cS",
        function() swap.swap_previous("@parameter.inner") end,
        { desc = "Move the argument left" }
      )
    end,
  },
}
