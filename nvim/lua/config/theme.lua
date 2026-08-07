-- Theme manager. The chosen theme is stored in a state file, so it survives
-- closing Neovim and no .lua file has to be edited to change colors.
--
--   <leader>ut               picker with live preview
--   <leader>uB               toggle between light and dark background
--   :Theme                   show the current theme
--   :Theme tokyonight-day    apply and save directly
--
-- The state file is ~/.local/state/nvim/theme.json.
--
-- That same file is written by ~/.config/theme/apply.py, which is what
-- SUPER+SHIFT+T calls. Because the file is watched (see M.watch), switching the
-- system theme recolors an already open Neovim — no :Theme, no restart. The
-- reverse is not true: :Theme only affects Neovim, not the rest of the system.

local M = {}

--- Where the chosen theme is persisted.
M.state_file = vim.fs.joinpath(vim.fn.stdpath("state"), "theme.json")

--- Theme used on first run, or if the state file is corrupt.
M.fallback = { colorscheme = "catppuccin-mocha", background = "dark" }

-- ── Persistence ──────────────────────────────────────────────────

--- Reads the saved theme from disk.
---
--- With `strict`, returns nil when the file can't be read instead of falling
--- back to the default. That's what the file watcher (M.watch) uses: it can
--- wake up mid-write and see a half-written file, where "don't know" is the
--- right answer — falling back would flash Mocha on screen in the middle of a
--- switch to another theme.
---@param strict? boolean
---@return { colorscheme: string, background: string }|nil
function M.read(strict)
  local function falhou()
    if strict then
      return nil
    end
    return vim.deepcopy(M.fallback)
  end

  local fd = io.open(M.state_file, "r")
  if not fd then
    return falhou()
  end
  local content = fd:read("*a")
  fd:close()

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= "table" or type(decoded.colorscheme) ~= "string" then
    return falhou()
  end
  return {
    colorscheme = decoded.colorscheme,
    background = decoded.background == "light" and "light" or "dark",
  }
end

--- Writes the theme to disk.
---@param theme { colorscheme: string, background: string }
function M.write(theme)
  local fd = io.open(M.state_file, "w")
  if not fd then
    vim.notify("Could not save the theme to " .. M.state_file, vim.log.levels.WARN)
    return
  end
  fd:write(vim.json.encode(theme))
  fd:close()
end

-- ── Applying ─────────────────────────────────────────────────────

--- Applies a colorscheme. Returns false without breaking anything if it
--- doesn't exist, which happens when a theme is removed from
--- lua/plugins/colorscheme.lua but is still named in the state file.
---@param name string
---@param background? "dark"|"light"
---@return boolean ok
function M.apply(name, background)
  if background then
    vim.o.background = background
  end
  local ok, err = pcall(vim.cmd.colorscheme, name)
  if not ok then
    vim.notify(("Theme '%s' not found.\n%s"):format(name, err), vim.log.levels.WARN, { title = "Theme" })
    return false
  end
  return true
end

--- Name of the last theme this instance applied. Acts as a guard for the file
--- watcher: when we are the ones who wrote the state, the watcher wakes up and
--- finds nothing to do.
M.current = nil

--- Applies a theme and saves the choice.
---
--- When `background` is not given, nothing is forced: the colorscheme decides
--- (catppuccin-latte, tokyonight-day and rose-pine-dawn set background=light
--- themselves) and the result is saved. Forcing the old value would make a
--- light theme inherit "dark" from the previous one.
---@param name string
---@param background? "dark"|"light"
function M.set(name, background)
  if not M.apply(name, background) then
    return
  end
  -- The requested name is saved rather than `vim.g.colors_name`, because some
  -- themes only report the family (rose-pine returns "rose-pine" even when
  -- "rose-pine-dawn" was requested) and the variant would be lost on next boot.
  M.current = name
  M.write({ colorscheme = name, background = vim.o.background })
end

--- Loads the saved theme. Called once at the end of config/lazy.lua.
function M.load()
  local theme = M.read()
  if M.apply(theme.colorscheme, theme.background) then
    M.current = theme.colorscheme
  else
    -- The saved theme is gone: fall back to the default and rewrite the state.
    M.set(M.fallback.colorscheme, M.fallback.background)
  end
  M.watch()
end

-- ── Follow the system theme ──────────────────────────────────────
-- SUPER+SHIFT+T (~/.config/theme/apply.py) rewrites the same theme.json used
-- as state here. Watching the file means an already open Neovim changes color
-- along with Waybar and kitty.

local vigia, debounce

--- Starts watching the state file. Idempotent.
function M.watch()
  if vigia then
    return
  end

  -- The directory is watched, not the file. A watcher bound to a file dies if
  -- something replaces it (writing to a temp file and renaming over the top is
  -- the usual safe-write pattern), and Neovim would silently stop following
  -- the theme.
  local dir = vim.fs.dirname(M.state_file)
  local alvo = vim.fs.basename(M.state_file)

  vigia = vim.uv.new_fs_event()
  debounce = vim.uv.new_timer()
  if not (vigia and debounce) then
    vigia, debounce = nil, nil
    return
  end

  local ok = vigia:start(dir, {}, function(err, arquivo)
    if err or (arquivo and arquivo ~= alvo) then
      return
    end
    -- A single write fires several events (create, write, chmod). Without the
    -- debounce the colorscheme would be applied three or four times in a row
    -- and the screen would flicker.
    debounce:stop()
    debounce:start(60, 0, function()
      vim.schedule(function()
        local theme = M.read(true)
        if not theme then
          return -- half-written file; the next event brings the good version
        end
        -- We wrote it ourselves (via :Theme or <leader>ut): nothing to do.
        if theme.colorscheme == M.current and theme.background == vim.o.background then
          return
        end
        if M.apply(theme.colorscheme, theme.background) then
          M.current = theme.colorscheme
        end
      end)
    end)
  end)

  if not ok then
    vigia:close()
    vigia = nil
    return
  end

  vim.api.nvim_create_autocmd("VimLeavePre", {
    desc = "Stop the theme watcher",
    callback = function()
      M.unwatch()
    end,
  })
end

--- Stops watching the state file.
function M.unwatch()
  if debounce then
    debounce:stop()
    debounce:close()
    debounce = nil
  end
  if vigia then
    vigia:stop()
    vigia:close()
    vigia = nil
  end
end

--- Toggles between light and dark background, keeping the same theme. Themes
--- that ship separate variants (catppuccin-latte, tokyonight-day,
--- rose-pine-dawn) are swapped for their counterpart.
function M.toggle_background()
  -- Read from the saved state rather than `vim.g.colors_name`, which loses the
  -- variant on some themes (see the comment in M.set).
  local current = M.read().colorscheme
  local target = vim.o.background == "dark" and "light" or "dark"

  -- Light/dark pairs for themes that use a distinct colorscheme per variant.
  local pairs_map = {
    ["catppuccin-mocha"] = "catppuccin-latte",
    ["catppuccin-macchiato"] = "catppuccin-latte",
    ["catppuccin-frappe"] = "catppuccin-latte",
    ["catppuccin-latte"] = "catppuccin-mocha",
    ["tokyonight-night"] = "tokyonight-day",
    ["tokyonight-storm"] = "tokyonight-day",
    ["tokyonight-moon"] = "tokyonight-day",
    ["tokyonight-day"] = "tokyonight-night",
    ["rose-pine-main"] = "rose-pine-dawn",
    ["rose-pine-moon"] = "rose-pine-dawn",
    ["rose-pine-dawn"] = "rose-pine-main",
  }

  M.set(pairs_map[current] or current, target)
  vim.notify(("Background: %s (%s)"):format(target, vim.g.colors_name), vim.log.levels.INFO, { title = "Theme" })
end

-- ── Picker ───────────────────────────────────────────────────────

--- Opens the theme picker.
---
--- Uses Snacks.picker, which already applies each theme live while browsing
--- and restores the previous one on <Esc>. The only change is `confirm`, which
--- also writes the choice to disk. Falls back to vim.ui.select without snacks.
function M.pick()
  local ok, snacks = pcall(require, "snacks")
  if ok and snacks.picker then
    return snacks.picker.colorschemes({
      confirm = function(picker, item)
        picker:close()
        if not item then
          return
        end
        -- Clearing the preview state is what stops the WinClosed handler from
        -- restoring the old theme over our choice.
        if picker.preview and picker.preview.state then
          picker.preview.state.colorscheme = nil
        end
        vim.schedule(function() M.set(item.text) end)
      end,
    })
  end

  vim.ui.select(vim.fn.getcompletion("", "color"), { prompt = "Theme: " }, function(choice)
    if choice then
      M.set(choice)
    end
  end)
end

-- ── :Theme command ───────────────────────────────────────────────

vim.api.nvim_create_user_command("Theme", function(cmd)
  if cmd.args == "" then
    local saved = M.read()
    vim.notify(
      ("Current theme: %s (background %s)\nSaved in: %s"):format(vim.g.colors_name, vim.o.background, M.state_file),
      vim.log.levels.INFO,
      { title = "Theme" }
    )
    return saved
  end
  M.set(cmd.args)
end, {
  nargs = "?",
  desc = "Show or set the theme (persistent)",
  complete = function(arg_lead)
    return vim.tbl_filter(
      function(name) return name:find(arg_lead, 1, true) == 1 end,
      vim.fn.getcompletion("", "color")
    )
  end,
})

return M
