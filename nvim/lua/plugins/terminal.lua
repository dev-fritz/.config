-- toggleterm.nvim, terminals inside Neovim. The main keys follow NvChad:
--
--   <A-i>       toggle the floating terminal
--   <A-h>       toggle the horizontal terminal, at the bottom
--   <A-v>       toggle the vertical terminal, on the right
--   <leader>h   new horizontal terminal (a fresh one on every press)
--   <leader>v   new vertical terminal
--   <leader>pt  pick one of the terminals already open
--
-- The three <A-…> terminals are persistent and independent: each one has its
-- own id (1, 2 and 3), so closing and reopening returns to the same shell,
-- and the same key works from normal, insert and terminal mode.
--
-- Inside a terminal, <C-x> returns to normal mode (NvChad's key; <Esc><Esc>
-- also works, since a bare <Esc> belongs to the TUI running there) and
-- <C-h/j/k/l> move to the neighboring windows.
--
-- Extras kept from the previous setup:
--
--   <C-\>       toggle the floating terminal; accepts a count, 3<C-\> is nr 3
--   <leader>tf  floating terminal          <leader>tt  pick an open terminal
--   <leader>tv  vertical terminal          <leader>ta  toggle all of them
--   <leader>tp  Python REPL                <leader>tn  Node REPL
--
-- lazygit is not here: it runs through snacks.nvim (<leader>gg), which already
-- injects the current Neovim theme into its interface.

-- toggleterm cannot open a split while the cursor sits in a floating window,
-- and it always splits the most recently opened terminal window. So before
-- opening a split terminal, any floating one is closed: without this, <A-h>
-- pressed inside the <A-i> float does nothing at all.
local function close_open_floats(keep_id)
  for _, term in pairs(require("toggleterm.terminal").get_all(true)) do
    if term.id ~= keep_id and term:is_open() and term:is_float() then term:close() end
  end
end

--- Toggle for one of the three persistent terminals. `count` is the terminal's
--- id, which is what makes <A-i> always come back to the same shell — and what
--- lets `2<C-\\>` reach the horizontal one as well.
---@param direction "horizontal"|"vertical"|"float"
---@param count integer
local terms = {} ---@type table<integer, table>
local function toggle_term(direction, count)
  return function()
    local term = terms[count]
    if not term then
      term = require("toggleterm.terminal").Terminal:new({ direction = direction, count = count })
      terms[count] = term
    end
    if not term:is_open() and direction ~= "float" then close_open_floats(count) end
    term:toggle()
  end
end

--- Opens a brand new terminal, without reusing any of the existing ones.
---@param direction "horizontal"|"vertical"|"float"
local function new_term(direction)
  return function()
    if direction ~= "float" then close_open_floats() end
    require("toggleterm.terminal").Terminal:new({ direction = direction }):toggle()
  end
end

return {
  "akinsho/toggleterm.nvim",
  version = "*",
  cmd = { "ToggleTerm", "TermExec", "TermSelect", "ToggleTermToggleAll" },

  -- stylua: ignore
  keys = {
    -- ── NvChad keys ────────────────────────────────────────────────
    -- The count picks the terminal, so <A-i> always comes back to the same
    -- floating shell even if a horizontal one is open on top of it.
    { "<A-i>", toggle_term("float", 1),      mode = { "n", "i", "t" }, desc = "Terminal: floating" },
    { "<A-h>", toggle_term("horizontal", 2), mode = { "n", "i", "t" }, desc = "Terminal: horizontal" },
    { "<A-v>", toggle_term("vertical", 3),   mode = { "n", "i", "t" }, desc = "Terminal: vertical" },

    { "<leader>h",  new_term("horizontal"), desc = "New horizontal terminal" },
    { "<leader>v",  new_term("vertical"),   desc = "New vertical terminal" },
    { "<leader>pt", "<cmd>TermSelect<CR>",  desc = "Pick an open terminal" },

    -- ── The <leader>t group, kept from before ──────────────────────
    { [[<C-\>]], desc = "Floating terminal" },
    { "<leader>tf", toggle_term("float", 1),    desc = "Floating terminal" },
    { "<leader>tv", toggle_term("vertical", 3), desc = "Vertical terminal" },
    { "<leader>tt", "<cmd>TermSelect<CR>",                       desc = "Pick an open terminal" },
    { "<leader>ta", "<cmd>ToggleTermToggleAll<CR>",              desc = "Toggle all of them" },
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

        map("<C-x>", [[<C-\><C-n>]], "Leave to normal mode") -- NvChad's key
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
