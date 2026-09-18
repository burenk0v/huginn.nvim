local function assert_equal(actual, expected, message)
  local ok = vim.deep_equal(actual, expected)
  if not ok then
    error(("%s\nexpected: %s\nactual: %s"):format(
      message,
      vim.inspect(expected),
      vim.inspect(actual)
    ))
  end
end

local function write(path, content)
  local parent = vim.fs.dirname(path)
  vim.fn.mkdir(parent, "p")
  vim.fn.writefile(vim.split(content, "\n", { plain = true }), path)
end

local root = vim.fn.tempname()
local config_home = vim.fn.tempname()
vim.fn.mkdir(root, "p")
vim.fn.mkdir(config_home, "p")
vim.env.XDG_CONFIG_HOME = config_home
vim.cmd("cd " .. vim.fn.fnameescape(root))

local config = require("huginn.config")
local testing = require("huginn.testing")
local usage = require("huginn.ai.usage")

write(root .. "/.sdet.yaml", [[
python:
  package_manager: uv
  formatter: ruff
testing:
  runner: pytest
  profiles:
    default:
      - tests
    smoke:
      - tests/smoke
      - -q
ai:
  provider: corporate
  model: project-model
  providers:
    corporate:
      type: openai_compatible
      endpoint: https://ai.example.test/v1
      model: corporate-model
      auth:
        type: oidc
        issuer: https://login.example.test
        client_id: huginn
]])

write(config_home .. "/huginn.local.yaml", [[
python:
  linter: ruff
ai:
  instructions:
    - "Use the project framework documentation."
]])

config.setup()
local cfg = config.get()

assert_equal(cfg._project_root, root, "project root")
assert_equal(cfg.python.package_manager, "uv", "project package manager")
assert_equal(cfg.python.formatter, "ruff", "project formatter")
assert_equal(cfg.python.linter, "ruff", "default linter preserved")
assert_equal(cfg.testing.runner, "pytest", "pytest runner")
assert_equal(cfg.testing.profiles.smoke, { "tests/smoke", "-q" }, "custom profile")
assert_equal(cfg.ai.provider, "corporate", "project AI provider")
assert_equal(cfg.ai.model, "project-model", "project AI model")
assert_equal(cfg.ai.providers.corporate.type, "openai_compatible", "AI provider type")
assert_equal(cfg.ai.providers.corporate.auth.type, "oidc", "AI auth type")
assert_equal(cfg.ai.providers.corporate.auth.client_id, "huginn", "OIDC client id")
assert_equal(cfg.ai.usage.budget_tokens, 0, "default usage budget")
assert_equal(cfg.ai.usage.cost_per_million_tokens, 0, "default token cost")
assert_equal(cfg.ai.instructions, { "Use the project framework documentation." }, "local AI instructions")

cfg.python.package_manager = "poetry"
assert_equal(testing.build_command({ "pytest", "tests" }), { "poetry", "run", "pytest", "tests" }, "poetry command")

cfg.python.package_manager = "uv"
assert_equal(testing.build_command({ "pytest", "tests" }), { "uv", "run", "pytest", "tests" }, "uv command")

cfg.python.package_manager = "pipenv"
assert_equal(testing.build_command({ "pytest", "tests" }), { "pipenv", "run", "pytest", "tests" }, "pipenv command")

cfg.python.package_manager = "none"
assert_equal(testing.build_command({ "pytest", "tests" }), { "pytest", "tests" }, "direct command")

cfg.python.package_manager = "rye"
assert_equal(testing.build_command({ "pytest", "tests" }), { "rye", "pytest", "tests" }, "custom executable prefix")

assert_equal(testing.build_profile_command("smoke"), { "rye", "pytest", "tests/smoke", "-q" }, "profile command")

usage.record(2500)
local usage_snapshot = usage.snapshot()
assert_equal(usage_snapshot.tokens, 2500, "usage token count")
assert_equal(usage_snapshot.requests, 1, "usage request count")

local notifications = {}
local original_notify = vim.notify
vim.notify = function(message, level)
  table.insert(notifications, { message = message, level = level })
end

write(root .. "/.sdet.yaml", [[
python:
  package_manager: uv
unknown:
  value: rejected
]])
config.setup()

vim.notify = original_notify

cfg = config.get()
assert_equal(cfg.python.package_manager, "poetry", "invalid project layer must be ignored")
assert_equal(cfg.testing.profiles.default, { "tests" }, "defaults survive invalid project layer")
assert_equal(#notifications, 1, "invalid configuration emits one notification")
assert_equal(
  notifications[1].message:match("unknown top%-level key 'unknown'") ~= nil,
  true,
  "invalid configuration explains the rejected key"
)

print("Huginn configuration and command-generation smoke tests: OK")
vim.cmd("qa!")
