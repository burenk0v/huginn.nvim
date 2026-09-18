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

function M.setup()
  local project = vim.fn.getcwd() .. "/.sdet.yaml"
  if vim.fn.filereadable(project) == 1 then
    vim.notify("Huginn: .sdet.yaml detected; YAML loading will be enabled in the next config layer.", vim.log.levels.INFO)
  end

  M.options = vim.deepcopy(M.defaults)
end

function M.get()
  return M.options
end

return M
