local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(("%s\nexpected: %s\nactual: %s"):format(
      message,
      vim.inspect(expected),
      vim.inspect(actual)
    ))
  end
end

local function assert_true(value, message)
  assert(value == true, message)
end

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.cmd("cd " .. vim.fn.fnameescape(root))

vim.fn.writefile(vim.split([[
testing:
  framework: pytest
  frameworks:
    pytest:
      runner: pytest
ai:
  enabled: true
]], "\n", { plain = true }), root .. "/.sdet.yaml")

-- Keep the smoke test offline: emulate lazy.nvim's setup boundary while
-- executing Huginn's complete plugin-spec construction.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.fn.mkdir(lazypath, "p")

local captured_specs
package.loaded["lazy"] = {
  setup = function(specs)
    captured_specs = specs
  end,
}


require("huginn").setup()
require("huginn").setup()

assert_true(type(captured_specs) == "table", "Huginn initializes the lazy.nvim plugin specification")

local function find_plugin(name)
  for _, spec in ipairs(captured_specs) do
    if spec[1] == name then
      return spec
    end
  end
end

local lspconfig = find_plugin("neovim/nvim-lspconfig")
assert_true(lspconfig ~= nil, "LSP plugin spec is present")

package.loaded["mason"] = { setup = function() end }
package.loaded["mason-lspconfig"] = { setup = function() end }

local captured_lsp_config
vim.lsp.config = function(name, options)
  if name == "yamlls" then
    captured_lsp_config = options
  end
end
vim.lsp.enable = function() end

lspconfig.config()

local schema = vim.api.nvim_get_runtime_file("config/schema.json", false)[1]
assert_true(schema ~= nil, "Huginn YAML schema is available on the runtime path")
assert_equal(
  captured_lsp_config.settings.yaml.schemas[schema],
  ".sdet.yaml",
  "YAML schema is resolved from the Huginn runtime path"
)

local neotest = find_plugin("nvim-neotest/neotest")
assert_true(neotest ~= nil, "Neotest plugin spec is present")
assert_true(type(neotest.enabled) == "function", "Neotest uses a runtime capability predicate")
assert_equal(neotest.enabled(), true, "Neotest is enabled for pytest")
assert_equal(vim.inspect(neotest.ft), '{ "python" }', "Neotest filetypes come from framework")
assert_true(vim.tbl_contains(neotest.dependencies, "nvim-neotest/neotest-python"), "Neotest framework adapter dependency is declared")
assert_true(vim.tbl_contains(neotest.dependencies, "mfussenegger/nvim-dap"), "Neotest debug dependency is declared")

local codecompanion = find_plugin("olimorris/codecompanion.nvim")
assert_true(codecompanion ~= nil, "CodeCompanion plugin spec is present")
assert_true(type(codecompanion.enabled) == "function", "CodeCompanion uses a runtime enable predicate")
assert_equal(codecompanion.enabled(), false, "CodeCompanion is disabled by project configuration")

print("Huginn plugin initialization smoke test: OK")
vim.cmd("qa!")
