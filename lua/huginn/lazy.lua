local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Failed to clone lazy.nvim:\n" .. out)
  end
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "jedi-knights/yaml.nvim",
    lazy = false,
    opts = {},
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "mason-org/mason.nvim",
      "mason-org/mason-lspconfig.nvim",
    },
    ft = { "python", "yaml" },
    config = function()
      local config = require("huginn.config").get()

      require("mason").setup()
      require("mason-lspconfig").setup()

      local schema = vim.fn.stdpath("config") .. "/config/schema.json"

      if vim.fn.filereadable(schema) == 1 and vim.fn.has("nvim-0.11") == 1 then
        vim.lsp.config("yamlls", {
          settings = {
            yaml = {
              schemas = {
                [schema] = ".sdet.yaml",
              },
            },
          },
        })
        vim.lsp.enable("yamlls")
      end

      if config.python.type_checker == "ty" and vim.fn.executable("ty") == 1 and vim.fn.has("nvim-0.11") == 1 then
        vim.lsp.config("ty", {
          cmd = { "ty", "server" },
          filetypes = { "python" },
          root_markers = { "pyproject.toml", ".git" },
        })
        vim.lsp.enable("ty")
      end
    end,
  },
  {
    "stevearc/conform.nvim",
    ft = "python",
    config = function()
      local config = require("huginn.config").get()
      local formatter = config.python.formatter
      require("conform").setup({
        formatters_by_ft = {
          python = formatter ~= "" and { formatter == "ruff" and "ruff_format" or formatter } or {},
        },
      })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    ft = "python",
    config = function()
      local config = require("huginn.config").get()
      local linter = config.python.linter
      local lint = require("lint")
      lint.linters_by_ft = {
        python = linter ~= "" and { linter } or {},
      }
    end,
  },
  {
    "mfussenegger/nvim-dap",
  },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/neotest-python",
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    ft = "python",
    config = function()
      local config = require("huginn.config").get()
      require("neotest").setup({
        adapters = {
          require("neotest-python")({
            runner = config.testing.runner,
          }),
        },
      })
    end,
  },
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = function()
      local config = require("huginn.config").get()
      return {
        strategies = {
          chat = {
            adapter = config.ai.provider,
          },
          inline = {
            adapter = config.ai.provider,
          },
        },
        adapters = {
          http = {
            [config.ai.provider] = {
              model = config.ai.model,
            },
          },
        },
      }
    end,
  },
}, {
  checker = { enabled = true },
})
