-- Entry point. Sets the leader keys and loads the modules in order.
--
--   lua/config/options.lua   native Neovim options (vim.opt)
--   lua/config/keymaps.lua   keymaps that don't depend on a plugin
--   lua/config/autocmds.lua  autocommands
--   lua/config/theme.lua     theme switching and persistence
--   lua/config/lazy.lua      plugin manager bootstrap
--   lua/plugins/*.lua        one file per area, each returning plugin specs
--
-- Run `:checkhealth` to see what's missing on the system.

-- The leader must be set before any plugin loads, otherwise <leader>x maps
-- registered by plugins point at the wrong key.
vim.g.mapleader = " " -- <leader> is Space
vim.g.maplocalleader = "\\" -- <localleader> is backslash

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy") -- last: installs and loads the plugins
