local config = require("huginn.config")
local testing = require("huginn.testing")

local M = {}

M.CHECK_TAG = "huginn_check"

local function start(command, name)
  if not command then
    return
  end

  local task = require("overseer").new_task({
    name = name,
    cmd = command,
  })
  task:start()
end

function M.run(args)
  start(testing.build_command(args), "Huginn: tests")
end

function M.run_profile(name)
  local command = testing.build_profile_command(name)
  if not command then
    vim.notify(("Huginn: unknown test profile '%s'"):format(name), vim.log.levels.ERROR)
    return
  end

  start(command, ("Huginn: test profile %s"):format(name))
end

function M.run_default()
  M.run_profile("default")
end

function M.run_current_file()
  M.run({ vim.fn.expand("%:p") })
end

function M.run_with_args()
  local args = vim.fn.input("test args: ")
  if args ~= "" then
    M.run(testing.split_args(args))
  end
end

function M.select_profile()
  local names = vim.tbl_keys(config.get().testing.profiles)
  table.sort(names)
  vim.ui.select(names, { prompt = "Test profile" }, function(name)
    if name then
      M.run_profile(name)
    end
  end)
end

function M.run_check()
  require("overseer").run_task({
    tags = { M.CHECK_TAG },
  }, function(_, err)
    if err then
      vim.notify(("Huginn: no check task found: %s"):format(err), vim.log.levels.WARN)
    end
  end)
end

return M
