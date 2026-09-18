local config = require("huginn.config")
local framework = require("huginn.framework")

local M = {}

local function command_prefix(manager)
  if manager == "poetry" then
    return { "poetry", "run" }
  elseif manager == "uv" then
    return { "uv", "run" }
  elseif manager == "pipenv" then
    return { "pipenv", "run" }
  elseif manager == "none" or manager == "" then
    return {}
  end

  return { manager }
end

function M.build_command(args)
  local cfg = config.get()
  local adapter = framework.get(cfg.testing.framework)

  if not adapter then
    vim.notify(
      ("Huginn: unknown test framework '%s'"):format(cfg.testing.framework),
      vim.log.levels.ERROR
    )
    return nil
  end

  local options = cfg.testing.frameworks[cfg.testing.framework] or {}
  local command = command_prefix(cfg.python.package_manager)
  local framework_command = adapter.build_command(options, args)

  for _, arg in ipairs(framework_command) do
    table.insert(command, arg)
  end

  return command
end

function M.build_profile_command(name)
  local cfg = config.get()
  local profile = cfg.testing.profiles[name]

  if not profile then
    return nil
  end

  return M.build_command(profile)
end

function M.split_args(value)
  return vim.split(value, "%s+", { trimempty = true })
end

return M
