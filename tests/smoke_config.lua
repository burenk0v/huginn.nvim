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


-- The usage hook must tolerate malformed external events without breaking setup.
local usage_autocmd
local original_create_autocmd = vim.api.nvim_create_autocmd
vim.api.nvim_create_autocmd = function(event, opts)
  if event == "User" and opts.pattern == "CodeCompanionChatCreated" then
    usage_autocmd = opts.callback
  end
  return original_create_autocmd(event, opts)
end
usage.setup()
vim.api.nvim_create_autocmd = original_create_autocmd
assert_true(type(usage_autocmd) == "function", "AI usage callback is registered")
usage_autocmd({})
usage_autocmd({ data = {} })
package.loaded["codecompanion"] = {
  buf_get_chat = function()
    error("unexpected malformed buffer lookup")
  end,
}
usage_autocmd({ data = { bufnr = 1 } })

usage.record_chat(10, 2500)
usage.record_chat(10, 3000)
usage.record_chat(11, 1200)
local usage_snapshot = usage.snapshot()
assert_equal(usage_snapshot.tokens, 4200, "usage token count uses per-chat deltas")
assert_equal(usage_snapshot.requests, 3, "usage request count")

write(root .. "/project/.sdet.yaml", [[
ai:
  enabled: true
  provider: missing-provider
]])
config.setup()
assert_equal(config.get().ai.enabled, false, "missing selected AI provider disables AI")

write(root .. "/project/.sdet.yaml", [[
ai:
  enabled: true
  provider: corporate
  providers:
    corporate:
      type: unsupported
]])
config.setup()
assert_equal(config.get().ai.enabled, false, "unsupported AI provider type disables AI")

write(root .. "/project/.sdet.yaml", [[
ai:
  enabled: true
  provider: corporate
  providers:
    corporate:
      type: openai_compatible
      auth:
        type: oidc
        issuer: https://login.example.test
        client_id: huginn
]])
config.setup()
assert_equal(config.get().ai.enabled, false, "missing AI provider endpoint disables AI")

write(root .. "/project/.sdet.yaml", [[
ai:
  enabled: true
  provider: openai
]])
config.setup()
assert_equal(config.get().ai.enabled, true, "built-in OpenAI provider remains valid")
assert_equal(config.get().ai.provider, "openai", "built-in OpenAI provider is selected")

-- Optional AI fields must reject explicit empty strings just like the schema.
write(root .. "/project/.sdet.yaml", [[
ai:
  enabled: true
  provider: openai
  providers:
    unused:
      type: openai_compatible
      endpoint: ""
      model: ""
      auth:
        type: oidc
        issuer: https://login.example.test
        client_id: huginn
        scope: ""
]])
config.setup()
assert_equal(config.get().ai.provider, "openai", "invalid unused provider configuration is ignored")
assert_equal(config.get().ai.providers.unused, nil, "invalid unused provider is not merged")



local defaults = vim.deepcopy(config.defaults)
assert_equal(defaults.python.package_manager, "poetry", "default YAML contract package manager")
assert_equal(defaults.testing.frameworks.pytest.runner, "pytest", "default YAML contract framework runner")
assert_equal(#defaults.testing.profiles.default, 1, "default YAML contract profile")
assert_equal(defaults.ai.usage.budget_tokens, 0, "default AI budget")
assert_equal(defaults.ai.usage.cost_per_million_tokens, 0, "default AI price")

print("Huginn config smoke test passed")
vim.cmd("qa!")
