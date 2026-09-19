local M = {}

M.defaults = {
  python = {
    package_manager = "poetry",
    formatter = "ruff",
    linter = "ruff",
    type_checker = "ty",
  },
  testing = {
    framework = "pytest",
    frameworks = {
      pytest = {
        runner = "pytest",
      },
    },
    profiles = {
      default = { "tests" },
    },
  },
  ai = {
    enabled = true,
    provider = "openai",
    model = "gpt-5",
    instructions = {},
    providers = {},
    usage = {
      budget_tokens = 0,
      cost_per_million_tokens = 0,
    },
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

local function validate_string(value, path, allow_empty)
  if type(value) ~= "string" then
    return false, ("%s must be a string"):format(path)
  end
  if not allow_empty and value == "" then
    return false, ("%s must be a non-empty string"):format(path)
  end
  return true
end

local function validate_profiles(value)
  if type(value) ~= "table" or vim.tbl_islist(value) then
    return false, "testing.profiles must be an object"
  end
  for name, profile in pairs(value) do
    if type(name) ~= "string" or name == "" then return false, "testing.profiles keys must be non-empty strings" end
    if type(profile) ~= "table" or not vim.tbl_islist(profile) then
      return false, ("testing.profiles.%s must be an array"):format(name)
    end
    for index, arg in ipairs(profile) do
      local ok, err = validate_string(arg, ("testing.profiles.%s[%d]"):format(name, index))
      if not ok then return false, err end
    end
  end
  return true
end

local function validate_frameworks(value)
  if type(value) ~= "table" or vim.tbl_islist(value) then
    return false, "testing.frameworks must be an object"
  end
  for name, options in pairs(value) do
    if type(name) ~= "string" or name == "" or type(options) ~= "table" or vim.tbl_islist(options) then
      return false, "testing.frameworks must contain named objects"
    end
    for key in pairs(options) do
      if key ~= "runner" then
        return false, ("unknown key 'testing.frameworks.%s.%s'"):format(name, key)
      end
    end
    if options.runner ~= nil then
      local ok, err = validate_string(options.runner, ("testing.frameworks.%s.runner"):format(name))
      if not ok then return false, err end
    end
  end
  return true
end

local function validate_auth(provider_name, auth)
  if type(auth) ~= "table" or vim.tbl_islist(auth) then
    return false, ("ai.providers.%s.auth must be an object"):format(provider_name)
  end
  for key in pairs(auth) do
    if key ~= "type" and key ~= "issuer" and key ~= "client_id" and key ~= "scope" then
      return false, ("unknown key 'ai.providers.%s.auth.%s'"):format(provider_name, key)
    end
  end
  local ok, err = validate_string(auth.type, ("ai.providers.%s.auth.type"):format(provider_name))
  if not ok then return false, err end
  if auth.type ~= "oidc" then
    return false, ("ai.providers.%s.auth.type must be oidc"):format(provider_name)
  end
  if auth.type == "oidc" then
    ok, err = validate_string(auth.issuer, ("ai.providers.%s.auth.issuer"):format(provider_name))
    if not ok then return false, err end
    ok, err = validate_string(auth.client_id, ("ai.providers.%s.auth.client_id"):format(provider_name))
    if not ok then return false, err end
    if auth.scope then
      ok, err = validate_string(auth.scope, ("ai.providers.%s.auth.scope"):format(provider_name))
      if not ok then return false, err end
    end
  end
  return true
end

local function validate_ai_providers(value)
  if type(value) ~= "table" or vim.tbl_islist(value) then return false, "ai.providers must be an object" end
  for name, provider in pairs(value) do
    if type(name) ~= "string" or name == "" or type(provider) ~= "table" or vim.tbl_islist(provider) then
      return false, "ai.providers must contain named objects"
    end
    for key in pairs(provider) do
      if key ~= "type" and key ~= "endpoint" and key ~= "model" and key ~= "auth" then
        return false, ("unknown key 'ai.providers.%s.%s'"):format(name, key)
      end
    end
    local ok, err = validate_string(provider.type, ("ai.providers.%s.type"):format(name))
    if not ok then return false, err end
    if provider.type ~= "openai_compatible" then
      return false, ("ai.providers.%s.type must be openai_compatible"):format(name)
    end
    if provider.endpoint then
      ok, err = validate_string(provider.endpoint, ("ai.providers.%s.endpoint"):format(name))
      if not ok then return false, err end
    end
    if provider.model then
      ok, err = validate_string(provider.model, ("ai.providers.%s.model"):format(name))
      if not ok then return false, err end
    end
    if provider.auth then
      ok, err = validate_auth(name, provider.auth)
      if not ok then return false, err end
    end
  end
  return true
end

local function validate_section(section, value)
  if type(value) ~= "table" or vim.tbl_islist(value) then return false, ("%s must be an object"):format(section) end
  local allowed = {
    python = { package_manager = true, formatter = true, linter = true, type_checker = true },
    testing = { framework = true, frameworks = true, profiles = true },
    ai = { enabled = true, provider = true, model = true, instructions = true, providers = true, usage = true },
  }
  for key, item in pairs(value) do
    if not allowed[section][key] then return false, ("unknown key '%s.%s'"):format(section, key) end
    if section == "testing" and key == "profiles" then
      local ok, err = validate_profiles(item)
      if not ok then return false, err end
    elseif section == "testing" and key == "frameworks" then
      local ok, err = validate_frameworks(item)
      if not ok then return false, err end
    elseif section == "ai" and key == "enabled" then
      if type(item) ~= "boolean" then return false, "ai.enabled must be a boolean" end
    elseif section == "ai" and key == "instructions" then
      if type(item) ~= "table" or not vim.tbl_islist(item) then return false, "ai.instructions must be an array" end
      for index, instruction in ipairs(item) do
        local ok, err = validate_string(instruction, ("ai.instructions[%d]"):format(index))
        if not ok then return false, err end
      end
    elseif section == "ai" and key == "providers" then
      local ok, err = validate_ai_providers(item)
      if not ok then return false, err end
    elseif section == "ai" and key == "usage" then
      if type(item) ~= "table" or vim.tbl_islist(item) then return false, "ai.usage must be an object" end
      for usage_key, usage_value in pairs(item) do
        if usage_key ~= "budget_tokens" and usage_key ~= "cost_per_million_tokens" then
          return false, ("unknown key 'ai.usage.%s'"):format(usage_key)
        end
        if type(usage_value) ~= "number" or usage_value < 0 then
          return false, ("ai.usage.%s must be a non-negative number"):format(usage_key)
        end
      end
    else
      local ok, err = validate_string(item, ("%s.%s"):format(section, key), section == "python")
      if not ok then return false, err end
    end
  end
  return true
end

local function validate_effective_ai(ai)
  if not ai.enabled then
    return true
  end

  if ai.provider == "openai" then
    return true
  end

  local provider = ai.providers and ai.providers[ai.provider]
  if not provider then
    return false, ("ai.provider '%s' is not configured in ai.providers"):format(ai.provider)
  end
  if provider.type ~= "openai_compatible" then
    return false, ("ai.providers.%s.type must be openai_compatible"):format(ai.provider)
  end
  if not provider.endpoint or provider.endpoint == "" then
    return false, ("ai.providers.%s.endpoint is required"):format(ai.provider)
  end
  if not provider.auth or provider.auth.type ~= "oidc" then
    return false, ("ai.providers.%s.auth.type must be oidc"):format(ai.provider)
  end

  return true
end

local function validate(data)
  if type(data) ~= "table" or vim.tbl_islist(data) then return false, "configuration root must be an object" end
  local allowed = { python = true, testing = true, ai = true }
  for section, value in pairs(data) do
    if not allowed[section] then return false, ("unknown top-level key '%s'"):format(section) end
    local ok, err = validate_section(section, value)
    if not ok then return false, err end
  end
  return true
end

local function read_yaml(path)
  if vim.fn.filereadable(path) ~= 1 then return nil end
  local ok, yaml = pcall(require, "yaml")
  if not ok then notify_invalid(path, "YAML parser is unavailable"); return nil end
  local data, err = yaml.read(path)
  if not data then notify_invalid(path, err or "failed to parse YAML"); return nil end
  local valid, validation_error = validate(data)
  if not valid then notify_invalid(path, validation_error); return nil end
  return data
end

local function project_root()
  return vim.fs.root(0, { ".sdet.yaml", "pyproject.toml", ".git" }) or vim.fn.getcwd()
end

function M.setup()
  M.options = vim.deepcopy(M.defaults)
  local root = project_root()
  merge(M.options, read_yaml(root .. "/.sdet.yaml"))
  merge(M.options, read_yaml(vim.fn.stdpath("config") .. "/huginn.local.yaml"))

  local valid, validation_error = validate_effective_ai(M.options.ai)
  if not valid then
    notify_invalid("effective ai configuration", validation_error)
    M.options.ai.enabled = false
  end

  M.options._project_root = root
end

function M.get()
  return M.options
end

function M.project_root()
  return M.options._project_root
end

return M
