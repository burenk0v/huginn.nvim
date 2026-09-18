local function assert_equal(actual, expected, message)
  if not vim.deep_equal(actual, expected) then
    error(("%s\nexpected: %s\nactual: %s"):format(
      message,
      vim.inspect(expected),
      vim.inspect(actual)
    ))
  end
end

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.cmd("cd " .. vim.fn.fnameescape(root))

local config = require("huginn.config")
local keymaps_called = false

package.loaded["huginn.lazy"] = {}
package.loaded["huginn.keymaps"] = {
  setup = function()
    keymaps_called = true
  end,
}

vim.fn.writefile(vim.split([[
ai:
  enabled: false
  provider: disabled
]], "\n", { plain = true }), root .. "/.sdet.yaml")

require("huginn").setup()

local cfg = config.get()
assert_equal(cfg.ai.enabled, false, "configuration is loaded before integrations")
assert_equal(cfg.ai.provider, "disabled", "project AI settings are applied before integrations")
assert_equal(keymaps_called, true, "keymaps setup is invoked after configuration")

print("Huginn initialization-order smoke test: OK")
vim.cmd("qa!")
