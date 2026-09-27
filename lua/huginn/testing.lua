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

local function append_args(command, args)
  for _, arg in ipairs(args or {}) do
    if type(arg) ~= "string" then
      return false
    end
    table.insert(command, arg)
  end
  return true
end

function M.build_command(args)
  local cfg = config.get()
  local custom = cfg.testing.commands and cfg.testing.commands.test

  if custom then
    local command = vim.deepcopy(custom)
    if not append_args(command, args) then
      vim.notify("Huginn: custom testing.commands.test contains an invalid argument", vim.log.levels.ERROR)
      return nil
    end
    return command
  end

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
  local ok, framework_command = pcall(adapter.build_command, options, args)
  if not ok or type(framework_command) ~= "table" or not vim.tbl_islist(framework_command) then
    vim.notify(
      ("Huginn: framework '%s' returned an invalid test command"):format(cfg.testing.framework),
      vim.log.levels.ERROR
    )
    return nil
  end

  for _, arg in ipairs(framework_command) do
    if type(arg) ~= "string" then
      vim.notify(
        ("Huginn: framework '%s' returned a test command with a non-string argument"):format(cfg.testing.framework),
        vim.log.levels.ERROR
      )
      return nil
    end
    table.insert(command, arg)
  end

  return command
end

function M.build_check_command(args)
  local cfg = config.get()
  local custom = cfg.testing.commands and cfg.testing.commands.check

  if not custom then
    vim.notify("Huginn: testing.commands.check is not configured", vim.log.levels.WARN)
    return nil
  end

  local command = vim.deepcopy(custom)
  if not append_args(command, args) then
    vim.notify("Huginn: custom testing.commands.check contains an invalid argument", vim.log.levels.ERROR)
    return nil
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
