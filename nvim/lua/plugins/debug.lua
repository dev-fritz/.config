-- nvim-dap, the debugger: real breakpoints instead of print statements.
--
-- DAP is the Debug Adapter Protocol, the same one VS Code uses. Neovim is the
-- client, and each language has an adapter that talks to its native debugger
-- (delve for Go, debugpy for Python, lldb for C).
--
--   nvim-dap               the client
--   nvim-dap-ui            panels for variables, stack, breakpoints and REPL
--   nvim-dap-virtual-text  variable values inline, next to the code
--   mason-nvim-dap         installs and registers the adapters
--   nvim-dap-go / -python  integrations that find the test under the cursor
--
-- Typical flow: <leader>db sets a breakpoint, <leader>dc starts or continues,
-- the UI opens on its own, <leader>dO steps over and <leader>di steps in,
-- <leader>de evaluates the expression under the cursor, and <leader>dt ends
-- the session. F5/F10/F11/F12 do the same, following the VS Code convention.

return {
  -- ── Core ─────────────────────────────────────────────────────────────
  {
    "mfussenegger/nvim-dap",

    dependencies = {
      -- The UI panels.
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        opts = {
          layouts = {
            {
              -- Left panel: what you look at all the time.
              elements = {
                { id = "scopes", size = 0.4 }, -- variables in the current scope
                { id = "stacks", size = 0.3 }, -- call stack
                { id = "breakpoints", size = 0.15 },
                { id = "watches", size = 0.15 }, -- expressions you pinned
              },
              size = 46,
              position = "left",
            },
            {
              -- Bottom panel: program output and interactive console.
              elements = { "repl", "console" },
              size = 0.28,
              position = "bottom",
            },
          },
          controls = {
            enabled = true,
            element = "repl", -- the ▶ ⏭ ⏹ buttons appear in the REPL
          },
          floating = { border = "rounded" },
        },
      },

      -- Shows variable values as virtual text on the line itself.
      {
        "theHamsta/nvim-dap-virtual-text",
        opts = {
          virt_text_pos = "eol",
          highlight_changed_variables = true,
          all_frames = false, -- current frame only, otherwise it gets noisy
        },
      },

      -- Installs the adapters through Mason and registers them with dap.
      {
        "jay-babu/mason-nvim-dap.nvim",
        dependencies = { "mason-org/mason.nvim" },
        opts = {
          -- These are mason-nvim-dap adapter names, not Mason package names.
          -- `:h mason-nvim-dap-settings` lists them all.
          ensure_installed = {
            "codelldb", -- C, C++ and Rust
            "delve", -- Go
            "python", -- debugpy
            "js", -- Node and TypeScript
          },
          automatic_installation = true,
          handlers = {
            -- Generic handler: registers each adapter with its default
            -- config. To customize one, add `name = function(cfg) … end`.
            function(config) require("mason-nvim-dap").default_setup(config) end,
          },
        },
      },
    },

    -- stylua: ignore
    keys = {
      -- ── Execution control ─────────────────────────────────────────
      { "<leader>dc", function() require("dap").continue() end, desc = "Start / continue" },
      { "<leader>dO", function() require("dap").step_over() end, desc = "Step over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step into" },
      { "<leader>do", function() require("dap").step_out() end, desc = "Step out" },
      { "<leader>dC", function() require("dap").run_to_cursor() end, desc = "Run to cursor" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "Rerun the last session" },
      { "<leader>dt", function() require("dap").terminate() end, desc = "Terminate the session" },
      { "<leader>dp", function() require("dap").pause() end, desc = "Pause" },

      -- VS Code style keys, working alongside the ones above.
      { "<F5>", function() require("dap").continue() end, desc = "Debug: continue" },
      { "<F10>", function() require("dap").step_over() end, desc = "Debug: step over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Debug: step into" },
      { "<F12>", function() require("dap").step_out() end, desc = "Debug: step out" },

      -- ── Breakpoints ───────────────────────────────────────────────
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Breakpoint on/off" },
      { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Conditional breakpoint" },
      { "<leader>dL", function() require("dap").set_breakpoint(nil, nil, vim.fn.input("Log message: ")) end, desc = "Logpoint (logs without stopping)" },
      { "<leader>dx", function() require("dap").clear_breakpoints() end, desc = "Clear all breakpoints" },

      -- ── Inspection ────────────────────────────────────────────────
      { "<leader>de", function() require("dapui").eval(nil, { enter = true }) end, mode = { "n", "x" }, desc = "Evaluate expression or selection" },
      { "<leader>dw", function() require("dapui").elements.watches.add(vim.fn.expand("<cexpr>")) end, desc = "Watch the expression" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle the panels" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "Interactive console (REPL)" },
      { "<leader>ds", function() require("dap").session() end, desc = "Session information" },
    },

    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- ── Gutter icons ─────────────────────────────────────────────────
      local signs = {
        DapBreakpoint = { text = "", texthl = "DiagnosticError" },
        DapBreakpointCondition = { text = "", texthl = "DiagnosticWarn" },
        DapLogPoint = { text = "", texthl = "DiagnosticInfo" },
        DapStopped = { text = "", texthl = "DiagnosticWarn", linehl = "Visual" },
        DapBreakpointRejected = { text = "", texthl = "DiagnosticError" },
      }
      for name, opts in pairs(signs) do
        vim.fn.sign_define(name, opts)
      end

      -- ── The UI opens and closes along with the session ───────────────
      dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui"] = function() dapui.close() end

      -- ── Launch configurations ────────────────────────────────────────
      -- mason-nvim-dap already registers the basics for each language; only
      -- the worthwhile extras live here.

      -- C, C++ and Rust share the codelldb adapter. This config asks which
      -- binary to run, with file completion.
      local codelldb_launch = {
        name = "Run a binary (ask for the path)",
        type = "codelldb",
        request = "launch",
        program = function() return vim.fn.input("Executable path: ", vim.fn.getcwd() .. "/", "file") end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
      }
      for _, ft in ipairs({ "c", "cpp", "rust" }) do
        dap.configurations[ft] = dap.configurations[ft] or {}
        table.insert(dap.configurations[ft], codelldb_launch)
      end

      -- TypeScript reuses JavaScript's configurations.
      for _, ft in ipairs({ "typescript", "typescriptreact", "javascriptreact" }) do
        dap.configurations[ft] = dap.configurations[ft] or dap.configurations.javascript
      end

      -- A `.vscode/launch.json` in the project is read automatically by
      -- nvim-dap, on demand. Calling `dap.ext.vscode.load_launchjs` is neither
      -- needed nor advisable: it is deprecated and only produced a startup
      -- warning. See `:help dap-providers`.
    end,
  },

  -- ── Go: can debug the test under the cursor ──────────────────────────
  {
    "leoluz/nvim-dap-go",
    ft = "go",
    dependencies = { "mfussenegger/nvim-dap" },
    opts = {},
    -- stylua: ignore
    keys = {
      { "<leader>dgt", function() require("dap-go").debug_test() end, ft = "go", desc = "Debug the test under the cursor" },
      { "<leader>dgl", function() require("dap-go").debug_last_test() end, ft = "go", desc = "Rerun the last debugged test" },
    },
  },

  -- ── Python: uses the debugpy that Mason installed ────────────────────
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    dependencies = { "mfussenegger/nvim-dap" },
    config = function()
      -- Mason's debugpy lives in its own virtualenv, so point straight at
      -- that python; otherwise dap tries the system one and fails.
      local debugpy = vim.fs.joinpath(vim.fn.stdpath("data"), "mason", "packages", "debugpy", "venv", "bin", "python")
      require("dap-python").setup(vim.uv.fs_stat(debugpy) and debugpy or "python3")
    end,
    -- stylua: ignore
    keys = {
      { "<leader>dgt", function() require("dap-python").test_method() end, ft = "python", desc = "Debug the test method" },
      { "<leader>dgc", function() require("dap-python").test_class() end, ft = "python", desc = "Debug the test class" },
      { "<leader>dgs", function() require("dap-python").debug_selection() end, mode = "x", ft = "python", desc = "Debug the selection" },
    },
  },
}
