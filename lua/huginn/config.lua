local M = {}

M.defaults = {
  python = {
    package_manager = "poetry",
    formatter = "ruff",
    linter = "ruff",
    type_checker = "ty",
  },
  testing = {
    runner = "pytest",
    profiles = {
      default = { "tests" },
    },
  },
  ai = {
    enabled = true,
    provider = "openai",
    model = "gpt-5",
    instructions = {},
  },
}

M.options = vim.deepcopy(M.defaults)

local function merge(dst, src)
  for key, value in pairs(src or {}) do
    if type(value) == "table" and type(dst[key]) == "table" then
      merge(dst[key], value)
    else
      dst[key] = value
    end
  end
end

local function notify_invalid(path, message)
  vim.notify(("Huginn: invalid configuration in %s: %s"):format(path, message), vim.log.levels.ERROR)
end

local function validate_string(value, path)
  if type(value) ~= "string" or value == "" then
    return false, ("%s must be a non-empty string"):format(path)
  end
  return true
end

local function validate_profiles(value)
  if type(value) ~= "table" or vim.tbl_islist(value) then
    return false, "testing.profiles must be an object"
  end

  for name, profile in pairs(value) do
    if type(name) ~= "string" or name == "" then
      return false, "testing.profiles keys must be non-empty strings"
    end
    if type(profile) ~= "table" or not vim.tbl_islist(profile) then
      return false, ("testing.profiles.%s must be an array"):format(name)
    end
    for index, arg in ipairs(profile) do
      local ok, err = validate_string(arg, ("testing.profiles.%s[%d]"):format(name, index))
      if not ok then
        return false, err
      end
    end
  end

  return true
end

local function validate_section(section, value)
  if type(value) ~= "table" or vim.tbl_islist(value) then
    return false, ("%s must be an object"):format(section)
  end

  local allowed = {
    python = {
      package_manager = true,
      formatter = true,
      linter = true,
      type_checker = true,
    },
    testing = {
      runner = true,
      profiles = true,
    },
    ai = {
      enabled = true,
      provider = true,
      model = true,
      instructions = true,
    },
  }

  for key, item in pairs(value) do
    if not allowed[section][key] then
      return false, ("unknown key '%s.%s'"):format(section, key)
    end

    if section == "testing" and key == "profiles" then
      local ok, err = validate_profiles(item)
      if not ok then
        return false, err
      end
    elseif section == "ai" and key == "enabled" then
      if type(item) ~= "boolean" then
        return false, "ai.enabled must be a boolean"
      end
    elseif section == "ai" and key == "instructions" then
      if type(item) ~= "table" or not vim.tbl_islist(item) then
        return false, "ai.instructions must be an array"
      end
      for index, instruction in ipairs(item) do
        local ok, err = validate_string(instruction, ("ai.instructions[%d]"):format(index))
        if not ok then
          return false, err
        end
      end
    else
      local ok, err = validate_string(item, ("%s.%s"):format(section, key))
      if not ok then
        return false, err
      end
    end
  end

  return true
end

local function validate(data)
  if type(data) ~= "table" or vim.tbl_islist(data) then
    return false, "configuration root must be an object"
  end

  local allowed = {
    python = true,
    testing = true,
    ai = true,
  }

  for section, value in pairs(data) do
    if not allowed[section] then
      return false, ("unknown top-level key '%s'"):format(section)
    end

    local ok, err = validate_section(section, value)
    if not ok then
      return false, err
    end
  end

  return true
end

local function read_yaml(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end

  local ok, yaml = pcall(require, "yaml")
  if not ok then
    notify_invalid(path, "YAML parser is unavailable")
    return nil
  end

  local data, err = yaml.read(path)
  if not data then
    notify_invalid(path, err or "failed to parse YAML")
    return nil
  end

  local valid, validation_error = validate(data)
  if not valid then
    notify_invalid(path, validation_error)
    return nil
  end

  return data
end

local function project_root()
  return vim.fs.root(0, { ".sdet.yaml", "pyproject.toml", ".git" }) or vim.fn.getcwd()
end

function M.setup()
  M.options = vim.deepcopy(M.defaults)

  local root = project_root()
  local project_config = root .. "/.sdet.yaml"
  merge(M.options, read_yaml(project_config))

  local local_config = vim.fn.stdpath("config") .. "/huginn.local.yaml"
  merge(M.options, read_yaml(local_config))

  M.options._project_root = root
end

function M.get()
  return M.options
end

function M.project_root()
  return M.options._project_root
end

return M
