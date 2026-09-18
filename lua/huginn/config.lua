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

local function read_yaml(path)
  if vim.fn.filereadable(path) ~= 1 then
    return nil
  end

  local ok, yaml = pcall(require, "yaml")
  if not ok then
    vim.notify("Huginn: YAML parser is unavailable", vim.log.levels.ERROR)
    return nil
  end

  local data, err = yaml.read(path)
  if not data then
    vim.notify(("Huginn: failed to parse %s: %s"):format(path, err or "unknown error"), vim.log.levels.ERROR)
    return nil
  end

  if type(data) ~= "table" then
    vim.notify(("Huginn: %s must contain a YAML object"):format(path), vim.log.levels.ERROR)
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
