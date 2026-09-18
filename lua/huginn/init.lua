local config = require("huginn.config")

local M = {}
local setup_done = false

function M.setup()
  if setup_done then
    return
  end
  setup_done = true

  config.setup()
  require("huginn.lazy")
  require("huginn.keymaps").setup()
end

return M
