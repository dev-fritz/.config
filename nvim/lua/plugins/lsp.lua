-- LSP setup with Mason and nvim-lspconfig.
--
--   1. mason.nvim        downloads the servers (`:Mason` opens the UI)
--   2. mason-lspconfig   makes sure the list below is installed
--   3. nvim-lspconfig    provides each server's base configuration
--   4. vim.lsp.config()  applies the customizations on top of that base
--   5. vim.lsp.enable()  turns the servers on
--
-- Steps 4 and 5 use the native Neovim 0.11+ API; there is no
-- `require("lspconfig").server.setup{}` anymore.
--
-- To add a server, add an entry to the `servers` table below. `{}` is enough
-- when no customization is needed, and Mason installs it on the next
-- `:Lazy sync` or restart. Valid names are listed in `:help lspconfig-all`.
--
-- Useful commands:
--   :checkhealth vim.lsp  what is attached to this buffer and why
--   :LspInfo              the same, summarized
--   :Mason                install or remove servers by hand
--   :LspRestart           restart the server for the current buffer

-- ── Servers ────────────────────────────────────────────────────────────
-- Key is the server name in nvim-lspconfig, value is a config table merged
-- over the default. The special `mason = false` field skips installing
-- through Mason, for binaries that come from the system toolchain.
local servers = {
  -- ── Lua / Neovim ────────────────────────────────────────────────────
  lua_ls = {
    settings = {
      Lua = {
        workspace = { checkThirdParty = false },
        codeLens = { enable = true },
        hint = { enable = true, arrayIndex = "Disable" },
        doc = { privateName = { "^_" } },
        -- lazydev.nvim (below) handles the Neovim API, so lua_ls doesn't
        -- have to scan the whole runtime.
        diagnostics = { globals = { "vim", "Snacks" } },
        format = { enable = false }, -- stylua does the formatting (conform.nvim)
      },
    },
  },

  -- ── Web: TypeScript / JavaScript / React ────────────────────────────
  -- vtsls wraps the official tsserver and is much faster than ts_ls.
  vtsls = {
    settings = {
      typescript = {
        updateImportsOnFileMove = { enabled = "always" },
        inlayHints = {
          parameterNames = { enabled = "literals" },
          parameterTypes = { enabled = true },
          variableTypes = { enabled = false },
          propertyDeclarationTypes = { enabled = true },
          functionLikeReturnTypes = { enabled = true },
        },
      },
      javascript = {
        updateImportsOnFileMove = { enabled = "always" },
      },
      vtsls = {
        experimental = { completion = { enableServerSideFuzzyMatch = true } },
      },
    },
  },
  eslint = {
    -- Fixes what it can on save, independently of conform.nvim.
    settings = { workingDirectories = { mode = "auto" } },
  },
  html = {},
  cssls = {},
  jsonls = {},
  tailwindcss = {},

  -- ── Python ──────────────────────────────────────────────────────────
  -- basedpyright is a pyright fork with inlay hints and stricter checking.
  basedpyright = {
    settings = {
      basedpyright = {
        analysis = {
          typeCheckingMode = "standard", -- "off", "basic", "standard" or "strict"
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticMode = "openFilesOnly", -- "workspace" is far heavier
        },
      },
    },
  },
  -- ruff is a linter and formatter written in Rust, extremely fast.
  ruff = {
    -- basedpyright owns hover, so the docs are not shown twice.
    on_attach = function(client) client.server_capabilities.hoverProvider = false end,
  },

  -- ── Go ──────────────────────────────────────────────────────────────
  gopls = {
    settings = {
      gopls = {
        gofumpt = true,
        usePlaceholders = true,
        analyses = {
          unusedparams = true,
          shadow = true,
          nilness = true,
        },
        hints = {
          assignVariableTypes = true,
          compositeLiteralFields = true,
          constantValues = true,
          functionTypeParameters = true,
          parameterNames = true,
          rangeVariableTypes = true,
        },
      },
    },
  },

  -- ── Rust ────────────────────────────────────────────────────────────
  -- Installed through Mason. You can use rustup's copy instead with
  -- `rustup component add rust-analyzer` plus `mason = false` here, but the
  -- binary has to really exist: the /usr/lib/rustup/bin/rust-analyzer shim is
  -- always present and fails silently when the component isn't installed.
  rust_analyzer = {
    settings = {
      ["rust-analyzer"] = {
        cargo = { allFeatures = true },
        checkOnSave = true,
        check = { command = "clippy" },
        inlayHints = { closureReturnTypeHints = { enable = "always" } },
      },
    },
  },

  -- ── C / C++ ─────────────────────────────────────────────────────────
  -- Already on the system (the `clang` package), so it skips Mason.
  clangd = {
    mason = false,
    cmd = {
      "clangd",
      "--background-index",
      "--clang-tidy",
      "--header-insertion=iwyu",
      "--completion-style=detailed",
      "--function-arg-placeholders=true", -- clangd 22+ needs the explicit value
    },
    init_options = { fallbackFlags = { "-std=c++20" } },
  },
}

-- ── Extra tools installed by Mason ─────────────────────────────────────
-- Formatters and linters. These names are Mason package names; `:Mason` shows
-- the full list.
local tools = {
  "stylua", -- Lua
  "prettierd", -- JS/TS/JSON/CSS/HTML/Markdown/YAML (daemon, so it is fast)
  "goimports", -- Go: organizes imports
  "gofumpt", -- Go: stricter formatting than gofmt
  "shfmt", -- shell script
}

return {
  -- ── Mason, the package manager for LSP tooling ───────────────────────
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonLog" },
    keys = {
      { "<leader>cM", "<cmd>Mason<CR>", desc = "Mason (manage LSP servers)" },
    },
    build = ":MasonUpdate",
    opts = {
      ui = {
        border = "rounded",
        icons = { package_installed = "✓", package_pending = "➜", package_uninstalled = "✗" },
      },
    },
  },

  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason-org/mason.nvim" },
    event = "VeryLazy",
    opts = {
      ensure_installed = tools,
      run_on_start = true,
      auto_update = false,
      start_delay = 3000, -- keeps it out of the way at startup
    },
  },

  -- ── lazydev, completion and types for the Neovim API ─────────────────
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        -- Load the types only when the file actually uses the library.
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { path = "snacks.nvim", words = { "Snacks" } },
        { path = "lazy.nvim", words = { "LazySpec" } },
      },
    },
  },

  -- Registers lazydev as a blink.cmp source; the high score puts it first.
  {
    "saghen/blink.cmp",
    opts = {
      sources = {
        default = { "lazydev" }, -- added to the list in completion.lua
        providers = {
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            score_offset = 100,
          },
        },
      },
    },
  },

  -- ── nvim-lspconfig, the base configuration for each server ───────────
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
    },
    config = function()
      -- ── 1. Diagnostics ───────────────────────────────────────────────
      vim.diagnostic.config({
        underline = true,
        update_in_insert = false, -- don't flicker while typing
        severity_sort = true,
        float = {
          border = "rounded",
          source = true, -- show which server produced the message
        },
        virtual_text = {
          spacing = 4,
          prefix = "●",
          -- Only show inline text from WARN up; HINT and INFO stay in the
          -- gutter sign so the buffer doesn't get noisy.
          severity = { min = vim.diagnostic.severity.WARN },
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = " ",
            [vim.diagnostic.severity.WARN] = " ",
            [vim.diagnostic.severity.HINT] = " ",
            [vim.diagnostic.severity.INFO] = " ",
          },
        },
      })

      -- ── 2. Capabilities: what the client can do ──────────────────────
      -- blink.cmp adds snippet support, lazy documentation resolution and so
      -- on. `vim.lsp.config("*")` applies this to every server.
      local capabilities = vim.lsp.protocol.make_client_capabilities()
      local ok_blink, blink = pcall(require, "blink.cmp")
      if ok_blink then
        capabilities = blink.get_lsp_capabilities(capabilities)
      end
      vim.lsp.config("*", { capabilities = capabilities })

      -- ── 3. Keymaps, set when a server attaches to the buffer ─────────
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("user_lsp_attach", { clear = true }),
        callback = function(event)
          local buf = event.buf
          local client = vim.lsp.get_client_by_id(event.data.client_id)

          local function map(keys, fn, desc, mode)
            vim.keymap.set(mode or "n", keys, fn, { buffer = buf, desc = "LSP: " .. desc })
          end

          -- Navigation, using the snacks picker (a list with preview).
          map("gd", function() Snacks.picker.lsp_definitions() end, "Go to definition")
          map("gr", function() Snacks.picker.lsp_references() end, "References")
          map("gI", function() Snacks.picker.lsp_implementations() end, "Implementations")
          map("gy", function() Snacks.picker.lsp_type_definitions() end, "Type definition")
          map("gD", vim.lsp.buf.declaration, "Go to declaration")

          -- Actions.
          map("<leader>cn", vim.lsp.buf.rename, "Rename symbol")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action", { "n", "x" })
          map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
          map("<leader>ci", "<cmd>LspInfo<CR>", "LSP information")
          map("<leader>cs", vim.lsp.buf.signature_help, "Function signature")

          -- Code lenses (Go, Rust, Lua): "run test", "generate interface".
          if client and client:supports_method("textDocument/codeLens") then
            map("<leader>cc", vim.lsp.codelens.run, "Run code lens")
            vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
              buffer = buf,
              callback = function() vim.lsp.codelens.refresh({ bufnr = buf }) end,
            })
          end

          -- Inlay hints on by default; toggle with <leader>uh.
          if client and client:supports_method("textDocument/inlayHint") then
            vim.lsp.inlay_hint.enable(true, { bufnr = buf })
          end
        end,
      })

      -- Neovim 0.11+ already provides these without any configuration:
      --   K    hover            grn  rename
      --   gra  code action      grr  references
      --   gri  implementation   grt  type definition
      --   gO   document symbols
      -- The maps above are just more comfortable alternatives.

      -- ── 4. rust-analyzer code lenses: "Run" and "Debug" ──────────────
      --
      -- The grey labels above `fn main` and above tests are code lenses. Put
      -- the cursor on the line and press <leader>cc to trigger one; if the
      -- line has more than one, a menu appears.
      --
      -- They fire rust-analyzer's own commands, which Neovim cannot run by
      -- itself — each needs a handler in `vim.lsp.commands`. Out of the box,
      -- nvim-lspconfig registers a `runSingle` handler that uses proc:wait(),
      -- freezing Neovim until cargo finishes and then dumping all the output
      -- into a notification, and no `debugSingle` handler at all.
      --
      -- Both are registered inside LspAttach because nvim-lspconfig's
      -- `before_init` (which installs the blocking version) runs earlier, so
      -- registering here is what makes these versions win.
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("user_rust_codelens", { clear = true }),
        callback = function(event)
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if not client or client.name ~= "rust_analyzer" then
            return
          end

          -- Run: executes in a floating terminal, with live output and
          -- without freezing the editor.
          vim.lsp.commands["rust-analyzer.runSingle"] = function(command)
            local args = command.arguments[1].args
            local cmd = vim.list_extend({ "cargo" }, args.cargoArgs)
            if args.executableArgs and #args.executableArgs > 0 then
              vim.list_extend(cmd, { "--" })
              vim.list_extend(cmd, args.executableArgs)
            end

            require("toggleterm.terminal").Terminal
              :new({
                cmd = table.concat(cmd, " "),
                dir = args.workspaceRoot or args.cwd,
                direction = "float",
                close_on_exit = false, -- lets you read the output before closing
              })
              :toggle()
          end

          -- Debug: builds, finds the produced binary and hands it to DAP.
          --
          -- cargo doesn't report the executable path when running, so the
          -- action is swapped for one that only builds, asking for JSON
          -- output where each compiled line carries an `executable` field.
          vim.lsp.commands["rust-analyzer.debugSingle"] = function(command)
            local args = command.arguments[1].args
            local cargo = vim.deepcopy(args.cargoArgs)

            if cargo[1] == "run" then
              cargo[1] = "build"
            elseif cargo[1] == "test" then
              table.insert(cargo, "--no-run") -- build the test without running it
            end
            table.insert(cargo, "--message-format=json")

            vim.notify("Building for debugging…", vim.log.levels.INFO, { title = "Rust" })

            vim.system(
              vim.list_extend({ "cargo" }, cargo),
              { cwd = args.workspaceRoot or args.cwd, text = true },
              function(res)
                -- vim.system callbacks run in a restricted context, so
                -- anything touching the UI has to go through vim.schedule.
                vim.schedule(function()
                  if res.code ~= 0 then
                    vim.notify("cargo failed:\n" .. (res.stderr or ""), vim.log.levels.ERROR, { title = "Rust" })
                    return
                  end

                  local exe
                  for line in (res.stdout or ""):gmatch("[^\n]+") do
                    local ok, msg = pcall(vim.json.decode, line)
                    if ok and type(msg) == "table" and msg.executable and msg.executable ~= vim.NIL then
                      exe = msg.executable
                    end
                  end

                  if not exe then
                    vim.notify(
                      "Could not find the executable produced by cargo.",
                      vim.log.levels.ERROR,
                      { title = "Rust" }
                    )
                    return
                  end

                  require("dap").run({
                    name = command.title or "Rust: debug",
                    type = "codelldb", -- installed by mason-nvim-dap
                    request = "launch",
                    program = exe,
                    args = args.executableArgs or {},
                    cwd = args.workspaceRoot or args.cwd,
                    stopOnEntry = false,
                  })
                end)
              end
            )
          end
        end,
      })

      -- ── 5. Apply the customizations and enable the servers ───────────
      local enable, mason_ensure = {}, {}
      for name, config in pairs(servers) do
        local use_mason = config.mason ~= false
        config.mason = nil -- our own field, Neovim doesn't know it
        -- `on_attach`, when present, is called by Neovim itself.
        vim.lsp.config(name, config)
        table.insert(enable, name)
        if use_mason then
          table.insert(mason_ensure, name)
        end
      end

      require("mason-lspconfig").setup({
        ensure_installed = mason_ensure,
        -- vim.lsp.enable() is called below with the complete list, including
        -- the servers that don't come from Mason.
        automatic_enable = false,
      })

      vim.lsp.enable(enable)
    end,
  },
}
