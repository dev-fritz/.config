-- Bootstrap and configuration for lazy.nvim, the plugin manager.
--
--   :Lazy          main panel (install, update, remove, profile)
--   :Lazy sync     install what's missing and remove what's left over
--   :Lazy update   update everything and refresh lazy-lock.json
--   :Lazy profile  show how much each plugin costs at startup
--
-- lazy-lock.json pins the exact version of every plugin and should be
-- committed — it's what makes this config behave the same on another machine.
-- `:Lazy restore` goes back to the pinned versions.

-- ── Bootstrap: download lazy.nvim on first run ───────────────────

local lazypath = vim.fs.joinpath(vim.fn.stdpath("data"), "lazy", "lazy.nvim")
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- ── Setup ────────────────────────────────────────────────────────

require("lazy").setup({
  -- Import every .lua file under lua/plugins/. Dropping a new file in there
  -- is enough to have it loaded.
  spec = { { import = "plugins" } },

  -- Theme used on the install screen, before the real themes exist.
  install = { colorscheme = { "habamax" } },

  -- Check for updates in the background, without notifications.
  checker = { enabled = true, notify = false },

  -- Reload automatically when a config file is edited.
  change_detection = { enabled = true, notify = false },

  ui = {
    border = "rounded",
    backdrop = 100, -- don't dim the background
  },

  performance = {
    rtp = {
      -- Disable built-in Vim plugins that aren't used, for a faster startup.
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "netrwPlugin", -- replaced by neo-tree / oil.nvim
      },
    },
  },
})

-- Must come after setup: lazy.nvim loads the theme plugin on demand when
-- `:colorscheme` runs.
require("config.theme").load()
