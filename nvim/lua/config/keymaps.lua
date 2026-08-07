-- Keymaps that don't depend on a plugin. Plugin keymaps live in that plugin's
-- own file, inside its `keys = { … }` table, so everything about a plugin
-- stays in one place.
--
-- Leader group convention:
--   <leader>f  find/file
--   <leader>g  git
--   <leader>b  buffer
--   <leader>c  code (LSP, formatting, actions)
--   <leader>s  search (grep, symbols, diagnostics)
--   <leader>t  terminal / toggle
--   <leader>u  UI toggles
--   <leader>x  diagnostics and lists (trouble, quickfix)

local map = vim.keymap.set

-- ── Basics ───────────────────────────────────────────────────────

-- <Esc> also clears the search highlight.
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- j/k move by visual line on wrapped lines, unless a count was given.
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true })

-- Save from any mode with Ctrl-s.
map({ "i", "x", "n", "s" }, "<C-s>", "<cmd>w<CR><Esc>", { desc = "Save file" })

-- Quick save and quit.
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Close window" })
map("n", "<leader>Q", "<cmd>qa<CR>", { desc = "Quit Neovim" })

-- ── Window navigation ────────────────────────────────────────────

map("n", "<C-h>", "<C-w>h", { desc = "Go to the left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Go to the window below" })
map("n", "<C-k>", "<C-w>k", { desc = "Go to the window above" })
map("n", "<C-l>", "<C-w>l", { desc = "Go to the right window" })

-- Resize with Ctrl + arrows.
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase width" })

-- Splits.
map("n", "<leader>-", "<C-w>s", { desc = "Horizontal split" })
map("n", "<leader>|", "<C-w>v", { desc = "Vertical split" })

-- ── Buffers ──────────────────────────────────────────────────────

map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "<leader>bb", "<cmd>e #<CR>", { desc = "Switch to the last buffer" })

-- <leader>bd and <leader>bo live in plugins/snacks.lua: Snacks.bufdelete closes
-- a buffer without disturbing the window layout, which :bdelete does not.

-- ── Editing ──────────────────────────────────────────────────────

-- Move the selected lines up and down, keeping the indentation.
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- Indent without losing the selection.
map("v", "<", "<gv", { desc = "Unindent" })
map("v", ">", ">gv", { desc = "Indent" })

-- Paste over a selection without overwriting the register.
map("x", "p", [["_dP]], { desc = "Paste without yanking the replaced text" })

-- Delete into the black hole register. Uses uppercase D because <leader>d is
-- the debugger (DAP) prefix.
map({ "n", "v" }, "<leader>D", [["_d]], { desc = "Delete without yanking" })

-- Keep the cursor centered when jumping half a page or through search results.
map("n", "<C-d>", "<C-d>zz", { desc = "Half page down (centered)" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half page up (centered)" })
map("n", "n", "nzzzv", { desc = "Next match (centered)" })
map("n", "N", "Nzzzv", { desc = "Previous match (centered)" })

-- Replace the word under the cursor throughout the file.
map("n", "<leader>cr", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], {
  desc = "Replace the word under the cursor",
})

-- Create undo points at punctuation, so undo works sentence by sentence.
for _, char in ipairs({ ",", ".", ";", "(", "[", "{" }) do
  map("i", char, char .. "<C-g>u")
end

-- ── Diagnostics (buffer-local LSP maps live in lsp.lua) ──────────

--- Returns a function that jumps to the next or previous diagnostic.
---@param count 1|-1  1 = forward, -1 = backward
---@param severity? integer  filter by severity (vim.diagnostic.severity.*)
local function diag_jump(count, severity)
  return function() vim.diagnostic.jump({ count = count, float = true, severity = severity }) end
end

local ERROR = vim.diagnostic.severity.ERROR

map("n", "]d", diag_jump(1), { desc = "Next diagnostic" })
map("n", "[d", diag_jump(-1), { desc = "Previous diagnostic" })
map("n", "]e", diag_jump(1, ERROR), { desc = "Next error" })
map("n", "[e", diag_jump(-1, ERROR), { desc = "Previous error" })

map("n", "<leader>xd", vim.diagnostic.open_float, { desc = "Line diagnostics (float)" })

-- The list views (<leader>xx, xq, xl) belong to trouble.nvim — see plugins/trouble.lua.

-- ── UI toggles (<leader>u) ───────────────────────────────────────

--- Toggles a boolean option and reports the new state.
---@param option string  option name, e.g. "wrap"
---@param label  string  text shown in the notification
local function toggle_opt(option, label)
  return function()
    vim.opt_local[option] = not vim.opt_local[option]:get()
    local state = vim.opt_local[option]:get() and "on" or "off"
    vim.notify(label .. ": " .. state, vim.log.levels.INFO, { title = "Options" })
  end
end

-- Theme switching, see lua/config/theme.lua.
local theme = function() return require("config.theme") end

map("n", "<leader>ut", function() theme().pick() end, { desc = "Switch theme (with preview)" })
map("n", "<leader>uB", function() theme().toggle_background() end, { desc = "Toggle light/dark background" })

map("n", "<leader>uw", toggle_opt("wrap", "Line wrap"), { desc = "Toggle line wrap" })
map("n", "<leader>us", toggle_opt("spell", "Spell check"), { desc = "Toggle spell check" })
map("n", "<leader>ul", toggle_opt("relativenumber", "Relative numbers"), { desc = "Toggle relative numbers" })

map("n", "<leader>uh", function()
  local on = not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
  vim.lsp.inlay_hint.enable(on, { bufnr = 0 })
  vim.notify("Inlay hints: " .. (on and "on" or "off"), vim.log.levels.INFO, { title = "LSP" })
end, { desc = "Toggle inlay hints" })

map("n", "<leader>ud", function()
  local on = not vim.diagnostic.is_enabled()
  vim.diagnostic.enable(on)
  vim.notify("Diagnostics: " .. (on and "on" or "off"), vim.log.levels.INFO, { title = "LSP" })
end, { desc = "Toggle diagnostics" })

-- ── Terminal mode (toggleterm has its own maps) ──────────────────

-- Leave terminal mode with Esc-Esc; a single Esc is used by TUIs like lazygit.
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })
