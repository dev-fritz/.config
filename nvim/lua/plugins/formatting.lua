-- conform.nvim, the formatter.
--
-- It is a separate plugin from the LSP because the LSP formatter isn't always
-- the one the project uses — the team runs prettier while tsserver formats
-- differently. conform calls the real binary and respects .prettierrc,
-- .stylua.toml, pyproject.toml and similar files.
--
-- Formats on save. To turn that off, <leader>uF toggles it globally for the
-- session, or use :FormatDisable / :FormatEnable (:FormatDisable! affects only
-- the current buffer).
--
-- <leader>cf formats right now, including a visual selection, and
-- :ConformInfo shows which formatter would run for this file and why.

return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },

  -- stylua: ignore
  keys = {
    { "<leader>cf", function() require("conform").format({ async = true, lsp_format = "fallback" }) end, mode = { "n", "x" }, desc = "Format file or selection" },
    -- NvChad's name for the same thing.
    { "<leader>fm", function() require("conform").format({ async = true, lsp_format = "fallback" }) end, mode = { "n", "x" }, desc = "Format file or selection" },
    { "<leader>uF", function() vim.cmd(vim.g.disable_autoformat and "FormatEnable" or "FormatDisable") end, desc = "Toggle format on save" },
  },

  ---@module "conform"
  ---@type conform.setupOpts
  opts = {
    -- ── Which formatter for which filetype ─────────────────────────
    -- A plain list runs all of them, in order. A list with stop_after_first
    -- uses the first one that is installed.
    formatters_by_ft = {
      lua = { "stylua" },

      -- prettierd is prettier running as a daemon, which is much faster;
      -- it falls back to plain prettier when not installed.
      javascript = { "prettierd", "prettier", stop_after_first = true },
      javascriptreact = { "prettierd", "prettier", stop_after_first = true },
      typescript = { "prettierd", "prettier", stop_after_first = true },
      typescriptreact = { "prettierd", "prettier", stop_after_first = true },
      css = { "prettierd", "prettier", stop_after_first = true },
      scss = { "prettierd", "prettier", stop_after_first = true },
      html = { "prettierd", "prettier", stop_after_first = true },
      json = { "prettierd", "prettier", stop_after_first = true },
      jsonc = { "prettierd", "prettier", stop_after_first = true },
      yaml = { "prettierd", "prettier", stop_after_first = true },
      markdown = { "prettierd", "prettier", stop_after_first = true },

      -- ruff does both jobs: organizing imports and formatting.
      python = { "ruff_organize_imports", "ruff_format" },

      -- goimports fixes the imports, gofumpt formats more strictly.
      go = { "goimports", "gofumpt" },

      rust = { "rustfmt" },

      c = { "clang_format" },
      cpp = { "clang_format" },

      sh = { "shfmt" },
      bash = { "shfmt" },

      -- "*" runs on every filetype; "_" only on those without one above.
      ["_"] = { "trim_whitespace" },
    },

    -- ── Format on save ─────────────────────────────────────────────
    format_on_save = function(bufnr)
      -- Honors the <leader>uF and :FormatDisable flags.
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return
      end

      -- Never format third-party files opened just to read them.
      local path = vim.api.nvim_buf_get_name(bufnr)
      for _, pattern in ipairs({ "/node_modules/", "/%.venv/", "/vendor/", "/target/" }) do
        if path:find(pattern) then
          return
        end
      end

      return {
        timeout_ms = 1000,
        lsp_format = "fallback", -- with no external formatter, use the LSP's
      }
    end,

    -- Per-formatter options.
    formatters = {
      shfmt = { prepend_args = { "-i", "2", "-ci" } }, -- 2 spaces, indent case
      clang_format = {
        prepend_args = { "--style={BasedOnStyle: LLVM, IndentWidth: 4}" },
      },
    },
  },

  init = function()
    -- Makes `gq` use conform, handy for formatting just a region.
    vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"

    local function announce(on, scope)
      vim.notify(
        ("Format on save: %s (%s)"):format(on and "on" or "off", scope),
        vim.log.levels.INFO,
        { title = "conform.nvim" }
      )
    end

    vim.api.nvim_create_user_command("FormatDisable", function(args)
      if args.bang then
        vim.b.disable_autoformat = true -- this buffer only
        announce(false, "this buffer")
      else
        vim.g.disable_autoformat = true
        announce(false, "global")
      end
    end, { desc = "Disable format on save", bang = true })

    vim.api.nvim_create_user_command("FormatEnable", function()
      vim.b.disable_autoformat = false
      vim.g.disable_autoformat = false
      announce(true, "global")
    end, { desc = "Re-enable format on save" })
  end,
}
