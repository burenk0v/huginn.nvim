local config = require("huginn.config")

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
  local command = command_prefix(cfg.python.package_manager)

  for _, arg in ipairs(args or {}) do
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

  return M.build_command(vim.list_extend({ cfg.testing.runner }, vim.deepcopy(profile)))
end

function M.split_args(value)
  return vim.split(value, "%s+", { trimempty = true })
end

return M
