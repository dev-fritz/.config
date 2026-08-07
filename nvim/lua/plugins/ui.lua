-- Interface plugins.
--
--   mini.icons   filetype icons (needs a Nerd Font)
--   lualine      status line
--   bufferline   buffer tabs along the top
--
-- lualine and bufferline use `theme = "auto"`, so they follow the active
-- colorscheme and need no reconfiguring when <leader>ut switches themes.
--
-- Without a Nerd Font installed and selected in the terminal the icons render
-- as boxes. On Arch: sudo pacman -S ttf-jetbrains-mono-nerd

return {
  -- ── Icons ────────────────────────────────────────────────────────────
  {
    "echasnovski/mini.icons",
    lazy = true,
    opts = {},
    init = function()
      -- Several plugins still require `nvim-web-devicons`. This makes
      -- mini.icons answer in its place, so that plugin isn't needed.
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },

  -- ── lualine, the status line ─────────────────────────────────────────
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function()
      return {
        options = {
          theme = "auto", -- follows the active colorscheme
          globalstatus = true, -- one bar total, even with several splits
          component_separators = { left = "│", right = "│" },
          section_separators = { left = "", right = "" },
          disabled_filetypes = {
            statusline = { "snacks_dashboard", "neo-tree" },
          },
        },

        sections = {
          -- ── Left ────────────────────────────────────────────────────
          lualine_a = { { "mode", fmt = string.lower } },
          lualine_b = {
            { "branch", icon = "" },
            {
              "diff",
              symbols = { added = " ", modified = " ", removed = " " },
            },
          },
          lualine_c = {
            {
              "filename",
              path = 1, -- path relative to the cwd
              symbols = { modified = " ●", readonly = " ", unnamed = "[no name]" },
            },
            {
              -- LSP diagnostics, using the same icons as plugins/lsp.lua.
              "diagnostics",
              symbols = { error = " ", warn = " ", info = " ", hint = " " },
            },
          },

          -- ── Right ───────────────────────────────────────────────────
          lualine_x = {
            {
              -- LSP servers attached to this buffer.
              function()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients == 0 then
                  return ""
                end
                local names = vim.tbl_map(function(c) return c.name end, clients)
                return "  " .. table.concat(names, ", ")
              end,
              -- No fixed `color` on purpose, so it follows the theme.
            },
            {
              -- Shown when format-on-save is disabled.
              function() return "  no autoformat" end,
              cond = function() return vim.g.disable_autoformat or vim.b.disable_autoformat end,
            },
            {
              "encoding",
              cond = function() return (vim.bo.fileencoding or "") ~= "utf-8" end,
            },
            {
              "fileformat",
              cond = function() return vim.bo.fileformat ~= "unix" end,
            },
            { "filetype", icon_only = true, separator = "" },
          },
          lualine_y = { { "progress", separator = " " } },
          lualine_z = { { "location", padding = { left = 0, right = 1 } } },
        },

        extensions = { "lazy", "mason", "neo-tree", "quickfix", "toggleterm" },
      }
    end,
  },

  -- ── bufferline, the buffer tabs ──────────────────────────────────────
  -- <S-h> / <S-l> cycle buffers (set in config/keymaps.lua) and
  -- <leader>1..9 jump straight to tab N.
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>bp", "<cmd>BufferLineTogglePin<CR>", desc = "Pin or unpin buffer" },
      { "<leader>bP", "<cmd>BufferLineGroupClose ungrouped<CR>", desc = "Close unpinned buffers" },
      { "<leader>bl", "<cmd>BufferLineCloseRight<CR>", desc = "Close buffers to the right" },
      { "<leader>bh", "<cmd>BufferLineCloseLeft<CR>", desc = "Close buffers to the left" },
      { "<leader>b<", "<cmd>BufferLineMovePrev<CR>", desc = "Move buffer left" },
      { "<leader>b>", "<cmd>BufferLineMoveNext<CR>", desc = "Move buffer right" },
    },
    opts = {
      options = {
        mode = "buffers",
        themable = true,
        close_command = function(n) Snacks.bufdelete(n) end,
        right_mouse_command = function(n) Snacks.bufdelete(n) end,
        diagnostics = "nvim_lsp",
        diagnostics_indicator = function(_, _, diag)
          local icons = { Error = " ", Warn = " ", Info = " " }
          local out = ""
          for key, icon in pairs(icons) do
            if diag[key:lower()] then
              out = out .. icon .. diag[key:lower()] .. " "
            end
          end
          return vim.trim(out)
        end,
        offsets = {
          {
            filetype = "neo-tree",
            text = "Explorer",
            highlight = "Directory",
            text_align = "left",
            separator = true,
          },
        },
        separator_style = "thin",
        show_buffer_close_icons = true,
        show_close_icon = false,
        always_show_bufferline = false, -- hidden when only one buffer is open
      },
    },
    config = function(_, opts)
      require("bufferline").setup(opts)

      -- Number shortcuts, <leader>1 through <leader>9.
      for i = 1, 9 do
        vim.keymap.set(
          "n",
          "<leader>" .. i,
          function() require("bufferline").go_to(i, true) end,
          { desc = "Go to buffer " .. i }
        )
      end

      -- When another plugin deletes a buffer (Snacks.bufdelete, neo-tree),
      -- the bufferline has to be redrawn on the next tick.
      vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
        group = vim.api.nvim_create_augroup("user_bufferline", { clear = true }),
        callback = function()
          vim.schedule(function() pcall(nvim_bufferline) end)
        end,
      })
    end,
  },
}
