-- toggleterm.nvim, terminals inside Neovim.
--
--   <C-\>       toggle the floating terminal (the main one)
--   <leader>tf  floating terminal
--   <leader>th  horizontal terminal, at the bottom
--   <leader>tv  vertical terminal, on the right
--   <leader>tp  Python REPL
--   <leader>tn  Node REPL
--   <leader>tt  pick an already open terminal
--
-- Inside a terminal, <Esc><Esc> returns to normal mode (a bare Esc belongs to
-- the TUI running there), <C-h/j/k/l> move to the neighboring windows, and
-- <C-\> closes it.
--
-- For several terminals at once, prefix with a number: 2<C-\> toggles terminal
-- 2, 3<C-\> toggles terminal 3, and so on.
--
-- lazygit is not here: it runs through snacks.nvim (<leader>gg), which already
-- injects the current Neovim theme into its interface.

return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = { "ToggleTerm", "TermExec", "ToggleTermToggleAll" },

  keys = {
    { [[<C-\>]], desc = "Floating terminal" },
    { "<leader>tf", "<cmd>ToggleTerm direction=float<CR>", desc = "Floating terminal" },
    { "<leader>th", "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Terminal horizontal" },
    { "<leader>tv", "<cmd>ToggleTerm direction=vertical<CR>", desc = "Terminal vertical" },
    { "<leader>tt", "<cmd>TermSelect<CR>", desc = "Pick an open terminal" },
    { "<leader>ta", "<cmd>ToggleTermToggleAll<CR>", desc = "Toggle all of them" },
  },

  opts = {
    -- Main key. Accepts a count: `3<C-\>` is terminal number 3.
    open_mapping = [[<C-\>]],

    direction = "float", -- floating is the default here
    float_opts = {
      border = "rounded",
      width = function() return math.floor(vim.o.columns * 0.85) end,
      height = function() return math.floor(vim.o.lines * 0.8) end,
      winblend = 0, -- 0 is opaque; 10-20 gives slight transparency
      title_pos = "center",
    },

    -- Size of the non-floating terminals.
    size = function(term)
      if term.direction == "horizontal" then
        return math.floor(vim.o.lines * 0.3)
      elseif term.direction == "vertical" then
        return math.floor(vim.o.columns * 0.4)
      end
    end,

    shade_terminals = false, -- don't darken the background, let the theme show
    start_in_insert = true,
    insert_mappings = true, -- <C-\> also works in insert mode
    terminal_mappings = true, -- and inside the terminal itself
    persist_size = true,
    persist_mode = false, -- always come back in insert mode
    close_on_exit = true, -- close the window when the shell exits
    auto_scroll = true,

    -- Inherit the background from the active theme instead of a fixed Normal.
    highlights = {
      Normal = { link = "Normal" },
      NormalFloat = { link = "NormalFloat" },
      FloatBorder = { link = "FloatBorder" },
    },

    responsiveness = {
      horizontal_breakpoint = 135, -- on narrow screens, vertical becomes horizontal
    },
  },

  config = function(_, opts)
    require("toggleterm").setup(opts)

    -- ── Keymaps that only apply inside a terminal buffer ─────────────
    vim.api.nvim_create_autocmd("TermOpen", {
      group = vim.api.nvim_create_augroup("user_toggleterm", { clear = true }),
      pattern = "term://*toggleterm#*",
      callback = function(event)
        local function map(key, action, desc) vim.keymap.set("t", key, action, { buffer = event.buf, desc = desc }) end

        map("<Esc><Esc>", [[<C-\><C-n>]], "Leave to normal mode")
        map("<C-h>", [[<Cmd>wincmd h<CR>]], "Left window")
        map("<C-j>", [[<Cmd>wincmd j<CR>]], "Window below")
        map("<C-k>", [[<Cmd>wincmd k<CR>]], "Window above")
        map("<C-l>", [[<Cmd>wincmd l<CR>]], "Right window")

        -- No line numbers or sign column in a terminal.
        vim.opt_local.number = false
        vim.opt_local.relativenumber = false
        vim.opt_local.signcolumn = "no"
        vim.opt_local.spell = false
      end,
    })

    -- ── Dedicated terminals ───────────────────────────────────────────
    -- Each has its own `count`, so they coexist without interfering.
    local Terminal = require("toggleterm.terminal").Terminal

    --- Creates a terminal on demand and returns a toggle function.
    ---@param cmd string command run on open
    ---@param count integer unique identifier for the terminal
    local function make_toggle(cmd, count)
      local term ---@type table?
      return function()
        term = term
          or Terminal:new({
            cmd = cmd,
            count = count,
            direction = "float",
            hidden = true,
            close_on_exit = false, -- lets you read the output before closing
          })
        term:toggle()
      end
    end

    vim.keymap.set("n", "<leader>tp", make_toggle("python3", 91), { desc = "Python REPL" })
    vim.keymap.set("n", "<leader>tn", make_toggle("node", 92), { desc = "Node REPL" })
  end,
}
