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
  enabled: false
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

package.loaded["huginn.keymaps"] = {
  setup = function() end,
}

require("huginn").setup()

assert_true(type(captured_specs) == "table", "Huginn initializes the lazy.nvim plugin specification")

local function find_plugin(name)
  for _, spec in ipairs(captured_specs) do
    if spec[1] == name then
      return spec
    end
  end
end

local neotest = find_plugin("nvim-neotest/neotest")
assert_true(neotest ~= nil, "Neotest plugin spec is present")
assert_true(neotest.enabled == true or type(neotest.enabled) == "function", "Neotest plugin is enabled for pytest")
assert_equal(vim.inspect(neotest.ft), '{ "python" }', "Neotest filetypes come from framework")
assert_true(vim.tbl_contains(neotest.dependencies, "nvim-neotest/neotest-python"), "Neotest framework adapter dependency is declared")
assert_true(vim.tbl_contains(neotest.dependencies, "mfussenegger/nvim-dap"), "Neotest debug dependency is declared")

local codecompanion = find_plugin("olimorris/codecompanion.nvim")
assert_true(codecompanion ~= nil, "CodeCompanion plugin spec is present")
assert_true(type(codecompanion.enabled) == "function", "CodeCompanion uses a runtime enable predicate")
assert_equal(codecompanion.enabled(), false, "CodeCompanion is disabled by project configuration")

print("Huginn plugin initialization smoke test: OK")
vim.cmd("qa!")
