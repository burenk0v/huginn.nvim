local project = vim.fn.tempname()
local config_home = vim.fn.tempname()

vim.fn.mkdir(project .. "/tests", "p")
vim.fn.mkdir(config_home .. "/nvim", "p")

vim.fn.writefile({
  "python:",
  "  package_manager: uv",
  "  formatter: black",
  "testing:",
  "  runner: pytest",
  "  profiles:",
  "    default:",
  "      - tests",
  "    smoke:",
  "      - tests/smoke",
  "ai:",
  "  model: project-model",
}, project .. "/.sdet.yaml")

vim.fn.writefile({
  "python:",
  "  formatter: ruff",
  "testing:",
  "  profiles:",
  "    smoke:",
  "      - tests/smoke",
  "    integration:",
  "      - tests/integration",
  "ai:",
  "  instructions:",
  "    - local instruction",
}, config_home .. "/nvim/huginn.local.yaml")

vim.fn.writefile({ "def test_placeholder():", "    pass" }, project .. "/tests/test_sample.py")

vim.cmd("edit " .. vim.fn.fnameescape(project .. "/tests/test_sample.py"))

package.loaded["huginn.config"] = nil
local config = require("huginn.config")
config.setup()

local options = config.get()

assert(options._project_root == project, "project root was not detected")
assert(options.python.package_manager == "uv", "project package manager was not loaded")
assert(options.python.formatter == "ruff", "local config did not override formatter")
assert(options.python.linter == "ruff", "default linter was lost")
assert(options.testing.runner == "pytest", "pytest runner was not preserved")
assert(vim.deep_equal(options.testing.profiles.default, { "tests" }), "default profile is wrong")
assert(vim.deep_equal(options.testing.profiles.smoke, { "tests/smoke" }), "project/local smoke profile is wrong")
assert(vim.deep_equal(options.testing.profiles.integration, { "tests/integration" }), "local integration profile was not merged")
assert(options.ai.model == "project-model", "project AI model was not preserved")
assert(vim.deep_equal(options.ai.instructions, { "local instruction" }), "local AI instructions were not loaded")

print("Huginn config smoke tests: PASS")
