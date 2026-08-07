-- Native Neovim options. See `:help option-list`, or `:help 'name'` (with the
-- single quotes) for any specific option.

local opt = vim.opt

-- ── Appearance ───────────────────────────────────────────────────

opt.number = true -- current line number
opt.relativenumber = true -- other lines relative, which helps with 5j, 12k
opt.cursorline = true -- highlight the cursor line
opt.signcolumn = "yes" -- always show the sign column, so text doesn't jump
opt.termguicolors = true -- 24-bit color, required by modern themes
opt.showmode = false -- the mode is already shown in lualine
opt.laststatus = 3 -- one global statusline instead of one per window
opt.pumheight = 10 -- max visible items in the completion menu
opt.winborder = "rounded" -- default border for every floating window (0.11+)
opt.wrap = false -- don't wrap long lines
opt.linebreak = true -- when wrap is on, break at word boundaries
opt.scrolloff = 8 -- keep 8 lines of context above and below the cursor
opt.sidescrolloff = 8 -- same, horizontally
opt.list = true -- show invisible characters
opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
opt.fillchars = {
  foldopen = "▾",
  foldclose = "▸",
  fold = " ",
  foldsep = " ",
  diff = "╱",
  eob = " ", -- hide the "~" past the end of the buffer
}

-- ── Window splits ────────────────────────────────────────────────

opt.splitbelow = true -- :split opens below
opt.splitright = true -- :vsplit opens to the right
opt.splitkeep = "screen" -- don't let text jump when splits open or close

-- ── Indentation ──────────────────────────────────────────────────

opt.expandtab = true -- Tab inserts spaces
opt.shiftwidth = 2 -- indent width for >>, << and autoindent
opt.tabstop = 2 -- visual width of a literal Tab
opt.softtabstop = 2 -- how many spaces Tab/Backspace move over
opt.smartindent = true -- auto-indent when opening a block
opt.breakindent = true -- wrapped lines keep their indentation

-- ── Search ───────────────────────────────────────────────────────

opt.ignorecase = true -- search ignores case…
opt.smartcase = true -- …unless the query contains an uppercase letter
opt.hlsearch = true -- highlight matches (clear with <Esc>)
opt.incsearch = true -- highlight while typing
opt.inccommand = "split" -- live preview of :s/foo/bar in a split

-- ── Files, history and performance ───────────────────────────────

opt.undofile = true -- undo survives closing the file
opt.undolevels = 10000
opt.swapfile = false -- no .swp files; undofile already covers crashes
opt.backup = false
opt.writebackup = false
opt.autowrite = true -- save when switching buffers with :next, :make, etc.
opt.confirm = true -- ask instead of failing when quitting with changes
opt.updatetime = 200 -- faster CursorHold, used by gitsigns and LSP highlight
opt.timeoutlen = 300 -- how long to wait for a key sequence (which-key)

-- ── Clipboard: wl-clipboard on Wayland ───────────────────────────
--
-- Declared explicitly instead of letting Neovim guess, for two reasons:
-- autodetection scans wl-copy → xclip → xsel → … and costs startup time, and
-- in a Wayland session with XWayland active (both WAYLAND_DISPLAY and DISPLAY
-- set) it can pick an X11 tool, sending `y` to the wrong clipboard.
--
-- `cache_enabled = 1` keeps the wl-copy process alive and detached after a
-- yank. Without it wl-copy dies with Neovim and the copied text disappears
-- when the editor closes — on Wayland the clipboard is served by the process
-- that copied.
--
-- Register + is the normal clipboard, register * the primary selection
-- (middle-click paste). Over SSH, use `vim.g.clipboard = "osc52"` instead,
-- which copies through the terminal itself.
if vim.fn.executable("wl-copy") == 1 and vim.env.WAYLAND_DISPLAY then
  vim.g.clipboard = {
    name = "wl-clipboard",
    copy = {
      ["+"] = { "wl-copy", "--type", "text/plain" },
      ["*"] = { "wl-copy", "--primary", "--type", "text/plain" },
    },
    paste = {
      ["+"] = { "wl-paste", "--no-newline" },
      ["*"] = { "wl-paste", "--no-newline", "--primary" },
    },
    cache_enabled = 1,
  }
end

-- Makes y, d, c and p use the system clipboard without the "+ prefix.
opt.clipboard = "unnamedplus"

-- ── Treesitter folds ─────────────────────────────────────────────

opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
opt.foldtext = "" -- use the real line text, with highlighting
opt.foldlevel = 99 -- start fully unfolded (za/zc/zR/zM to control)
opt.foldcolumn = "0" -- no fold column; the snacks statuscolumn handles it

-- ── Misc ─────────────────────────────────────────────────────────

-- In a terminal the font comes from the emulator (~/.config/kitty), so this
-- only applies to GUI clients like Neovide or nvim-qt.
opt.guifont = "SpaceMono Nerd Font Mono:h12"

opt.mouse = "a" -- mouse enabled in every mode
opt.virtualedit = "block" -- visual-block can go past the end of a line
opt.jumpoptions = "view" -- <C-o>/<C-i> also restore the screen position
opt.completeopt = "menu,menuone,noselect"
opt.shortmess:append("cI") -- no completion messages and no intro screen

-- ── Spell checking ───────────────────────────────────────────────
--
-- Asking for a language whose .spl file doesn't exist makes Neovim open a
-- blocking prompt ("Cannot find spell file… download it?") every time you open
-- a .md, .txt or commit message — exactly where autocmds.lua enables spelling.
-- It also swallows any keys typed while the prompt is up, so the list below is
-- built from what is actually installed.
--
-- To write in Portuguese, drop the dictionary where Neovim reads it and it
-- joins the list on the next start:
--
--   mkdir -p ~/.local/share/nvim/site/spell
--   curl -fL -o ~/.local/share/nvim/site/spell/pt.utf-8.spl \
--        https://ftp.nluug.nl/pub/vim/runtime/spell/pt.utf-8.spl
--
-- Arch's `vim-spell-pt` package installs into /usr/share/vim/, which is not on
-- Neovim's runtimepath, hence the direct download.
local idiomas = {}
for _, lang in ipairs({ "pt", "en" }) do
  if #vim.api.nvim_get_runtime_file("spell/" .. lang .. ".*.spl", false) > 0 then
    table.insert(idiomas, lang)
  end
end
opt.spelllang = #idiomas > 0 and idiomas or { "en" }

-- No Perl or Ruby plugins are used; disabling the providers saves startup time.
vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0
