local config = require("huginn.config")

local M = {}

function M.setup()
  config.setup()
  require("huginn.lazy")
  require("huginn.keymaps").setup()
end

return M
