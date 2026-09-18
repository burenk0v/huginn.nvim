local config = require("huginn.config")
local framework = require("huginn.framework")
local testing = require("huginn.testing")
local usage = require("huginn.ai.usage")

local function assert_equal(actual, expected, message)
  assert(actual == expected, ("%s: expected %s, got %s"):format(message, tostring(expected), tostring(actual)))
end

local function assert_true(value, message)
  assert(value == true, message)
end

local function write(path, content)
  local file = assert(io.open(path, "w"))
  file:write(content)
  file:close()
end

local root = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.mkdir(root .. "/project", "p")
write(root .. "/project/.sdet.yaml", [[
python:
  package_manager: none
  formatter: ruff
testing:
  framework: pytest
  frameworks:
    pytest:
      runner: pytest
  profiles:
    default:
      - tests
    unit:
      - tests/unit
ai:
  enabled: true
  provider: corporate
  model: company-model
  instructions:
    - use the project framework
  providers:
    corporate:
      type: openai_compatible
      endpoint: https://ai.example.test/v1
      model: company-model
      auth:
        type: oidc
        issuer: https://login.example.test
        client_id: huginn
  usage:
    budget_tokens: 1000000
    cost_per_million_tokens: 2
]])

vim.cmd("cd " .. vim.fn.fnameescape(root .. "/project"))
config.setup()

local cfg = config.get()
assert_equal(cfg.testing.framework, "pytest", "framework")
assert_equal(cfg.python.package_manager, "none", "package manager")
assert_equal(cfg.python.formatter, "ruff", "formatter")
assert_equal(cfg.testing.frameworks.pytest.runner, "pytest", "framework runner")

local command = testing.build_profile_command("unit")
assert_equal(table.concat(command, " "), "pytest tests/unit", "framework command")

local file_command = testing.build_command({ "tests/test_example.py" })
assert_equal(table.concat(file_command, " "), "pytest tests/test_example.py", "current file command")

local plugins = framework.neotest_plugins()
assert_equal(#plugins, 1, "neotest plugin count")
assert_equal(plugins[1], "nvim-neotest/neotest-python", "pytest neotest plugin")
assert_equal(#framework.neotest_debug_plugins(), 1, "neotest debug plugin count")
assert_equal(framework.neotest_debug_plugins()[1], "mfussenegger/nvim-dap", "pytest debug plugin")
assert_equal(framework.has_neotest("pytest"), true, "pytest neotest support")
assert_equal(vim.inspect(framework.filetypes("pytest")), '{ "python" }', "pytest filetypes")
assert_equal(framework.supports_debug("pytest"), true, "pytest debug support")

local custom_adapter = {
  build_command = function(options, args)
    return vim.list_extend({ options.runner or "custom-runner" }, vim.deepcopy(args))
  end,
}
framework.register("custom", custom_adapter)
cfg.testing.framework = "custom"
cfg.testing.frameworks.custom = { runner = "custom-command" }
local custom_command = testing.build_profile_command("unit")
assert_equal(table.concat(custom_command, " "), "custom-command tests/unit", "custom framework adapter")
assert_equal(framework.neotest_adapter("custom", cfg.testing.frameworks.custom), nil, "framework without neotest adapter")
assert_equal(framework.has_neotest("custom"), false, "framework without neotest support")
assert_equal(framework.supports_debug("custom"), false, "framework without debug support")
assert_equal(#framework.filetypes("custom"), 0, "framework without filetypes")

local duplicate_ok = pcall(framework.register, "custom", custom_adapter)
assert_equal(duplicate_ok, false, "duplicate framework registration is rejected")

local names = vim.fn.getcompletion("", "file")
assert_true(type(names) == "table", "headless runtime")

usage.record_chat(10, 2500)
usage.record_chat(10, 3000)
usage.record_chat(11, 1200)
local usage_snapshot = usage.snapshot()
assert_equal(usage_snapshot.tokens, 4200, "usage token count uses per-chat deltas")
assert_equal(usage_snapshot.requests, 3, "usage request count")

print("Huginn config smoke test passed")
vim.cmd("qa!")
