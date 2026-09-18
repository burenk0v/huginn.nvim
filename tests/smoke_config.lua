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
assert_equal(cfg.testing.runner, "pytest", "runner")

local command = testing.build_profile_command("unit")
assert_equal(table.concat(command, " "), "pytest tests/unit", "framework command")

framework.register("custom", {
  build_command = function(_, args)
    return vim.list_extend({ "custom-runner" }, vim.deepcopy(args))
  end,
})
cfg.testing.framework = "custom"
local custom_command = testing.build_profile_command("unit")
assert_equal(table.concat(custom_command, " "), "custom-runner tests/unit", "custom framework adapter")

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
