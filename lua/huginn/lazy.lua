local config = require("huginn.config")
local framework = require("huginn.framework")
local usage = require("huginn.ai.usage")

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

local cfg = config.get()
local neotest_dependencies = {
  "nvim-lua/plenary.nvim",
  "nvim-treesitter/nvim-treesitter",
}
vim.list_extend(neotest_dependencies, framework.neotest_plugins())
vim.list_extend(neotest_dependencies, framework.neotest_debug_plugins())

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
      local cfg = config.get()
      require("mason").setup()
      require("mason-lspconfig").setup()

      local schema = vim.api.nvim_get_runtime_file("config/schema.json", false)[1]
      if schema and vim.fn.filereadable(schema) == 1 and vim.fn.has("nvim-0.11") == 1 then
        vim.lsp.config("yamlls", {
          settings = {
            yaml = {
              schemas = { [schema] = ".sdet.yaml" },
            },
          },
        })
        vim.lsp.enable("yamlls")
      end

      if cfg.python.type_checker == "ty" and vim.fn.executable("ty") == 1 and vim.fn.has("nvim-0.11") == 1 then
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
      local cfg = config.get()
      local formatter = cfg.python.formatter
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
      local cfg = config.get()
      local linter = cfg.python.linter
      require("lint").linters_by_ft = {
        python = linter ~= "" and { linter } or {},
      }
    end,
  },
  {
    "nvim-neotest/neotest",
    enabled = function()
      return framework.has_neotest(config.get().testing.framework)
    end,
    dependencies = neotest_dependencies,
    ft = framework.filetypes(cfg.testing.framework),
    config = function()
      local cfg = config.get()
      local options = cfg.testing.frameworks[cfg.testing.framework] or {}
      local adapter = framework.neotest_adapter(cfg.testing.framework, options)
      require("neotest").setup({
        adapters = adapter and { adapter } or {},
      })
    end,
  },
  {
    "olimorris/codecompanion.nvim",
    enabled = function()
      return config.get().ai.enabled
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = function()
      local cfg = config.get()
      local adapters = {}
      local auth = require("huginn.ai.auth")

      for name, provider in pairs(cfg.ai.providers or {}) do
        if provider.type == "openai_compatible" then
          adapters.http = adapters.http or {}
          adapters.http[name] = function()
            return require("codecompanion.adapters").extend("openai_compatible", {
              env = {
                url = provider.endpoint,
                api_key = function()
                  local credentials = auth.get(name)
                  return credentials and credentials.access_token or ""
                end,
              },
              schema = {
                model = {
                  default = provider.model or cfg.ai.model,
                },
              },
            })
          end
        end
      end

      return {
        interactions = {
          chat = {
            adapter = cfg.ai.provider,
          },
          inline = {
            adapter = cfg.ai.provider,
          },
        },
        adapters = adapters,
      }
    end,
  },
}, {
  checker = { enabled = true },
})

if config.get().ai.enabled then
  usage.setup()
end
