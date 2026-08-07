-- Autocommands: things that happen automatically in response to events.
-- `:help autocmd-events` lists every available event.
--
-- Each one uses its own group with `clear = true`, so reloading the config
-- (`:source $MYVIMRC`) doesn't register the same autocommand twice.

--- Creates or clears an autocommand group with a standard prefix.
---@param name string
---@return integer
local function group(name) return vim.api.nvim_create_augroup("user_" .. name, { clear = true }) end

-- Briefly highlight yanked text.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = group("highlight_yank"),
  desc = "Flash the yanked region",
  callback = function() vim.hl.on_yank({ higroup = "IncSearch", timeout = 150 }) end,
})

-- Restore the cursor to its last known position in the file.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group("last_location"),
  desc = "Restore the cursor position when reopening a file",
  callback = function(event)
    local exclude = { "gitcommit", "gitrebase", "commit" }
    local buf = event.buf
    if vim.tbl_contains(exclude, vim.bo[buf].filetype) or vim.b[buf].user_last_location then
      return
    end
    vim.b[buf].user_last_location = true

    local mark = vim.api.nvim_buf_get_mark(buf, '"')
    local line_count = vim.api.nvim_buf_line_count(buf)
    if mark[1] > 0 and mark[1] <= line_count then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
      vim.cmd("normal! zz") -- center the view
    end
  end,
})

-- Close throwaway buffers with a single q.
vim.api.nvim_create_autocmd("FileType", {
  group = group("close_with_q"),
  desc = "Close helper windows with q",
  pattern = {
    "help",
    "man",
    "qf",
    "checkhealth",
    "lspinfo",
    "startuptime",
    "notify",
    "query",
    "grug-far",
    "neotest-output",
  },
  callback = function(event)
    vim.bo[event.buf].buflisted = false -- keep it out of the bufferline
    vim.keymap.set("n", "q", "<cmd>close<CR>", {
      buffer = event.buf,
      silent = true,
      desc = "Close window",
    })
  end,
})

-- Create the parent directory when saving a new file.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = group("auto_create_dir"),
  desc = "Create missing directories on save",
  callback = function(event)
    if event.match:match("^%w%w+://") then -- skip oil://, fugitive://, etc.
      return
    end
    local file = vim.uv.fs_realpath(event.match) or event.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Strip trailing whitespace on save, but only for files with no formatter
-- configured in conform.nvim — when there is one, it already handles this.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = group("trim_whitespace"),
  desc = "Remove trailing whitespace",
  callback = function(event)
    local ok, conform = pcall(require, "conform")
    if ok and type(conform.list_formatters_to_run) == "function" then
      local has_formatter = #conform.list_formatters_to_run(event.buf) > 0
      if has_formatter then
        return
      end
    end
    if vim.bo[event.buf].modifiable and not vim.bo[event.buf].binary then
      local view = vim.fn.winsaveview()
      pcall(vim.cmd, [[keeppatterns %s/\s\+$//e]])
      vim.fn.winrestview(view)
    end
  end,
})

-- Re-balance splits when the terminal window is resized.
vim.api.nvim_create_autocmd("VimResized", {
  group = group("resize_splits"),
  desc = "Equalize splits on resize",
  callback = function()
    local current_tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. current_tab)
  end,
})

-- ── Per-filetype settings ────────────────────────────────────────

vim.api.nvim_create_autocmd("FileType", {
  group = group("wrap_prose"),
  desc = "Wrapping and spell check for prose",
  pattern = { "markdown", "gitcommit", "text", "tex", "typst" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group("indent_4"),
  desc = "Languages that conventionally use 4 spaces",
  pattern = { "python", "rust", "c", "cpp", "objc" },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  group = group("indent_tabs"),
  desc = "Go uses real tabs",
  pattern = { "go", "gomod", "make" },
  callback = function()
    vim.opt_local.expandtab = false
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
  end,
})

-- Reload a file that changed outside Neovim.
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = group("checktime"),
  desc = "Reload the file if it changed on disk",
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})
