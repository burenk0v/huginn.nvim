local config = require("huginn.config")
local framework = require("huginn.framework")
local testing = require("huginn.testing")
local auth = require("huginn.ai.auth")
local usage = require("huginn.ai.usage")

local M = {}
local setup_done = false

local function run_terminal(command)
  if not command then
    return
  end
  vim.cmd("botright split | terminal " .. table.concat(vim.tbl_map(vim.fn.shellescape, command), " "))
end

local function run_command(args)
  run_terminal(testing.build_command(args))
end

local function run_check()
  run_terminal(testing.build_check_command())
end

local function run_profile(name)
  local command = testing.build_profile_command(name)
  if not command then
    vim.notify(("Huginn: unknown test profile '%s'"):format(name), vim.log.levels.ERROR)
    return
  end
  run_terminal(command)
end

local function create_user_command(name, callback, opts)
  if vim.fn.exists(":" .. name) == 2 then
    return
  end
  vim.api.nvim_create_user_command(name, callback, opts)
end

local function set_optional_keymap(mode, lhs, rhs, opts)
  if lhs and lhs ~= "" then
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

local function ai_provider()
  local cfg = config.get()
  if not cfg.ai.enabled then
    vim.notify("Huginn: AI integration is disabled", vim.log.levels.WARN)
    return nil
  end

  if cfg.ai.provider == "openai" then
    vim.notify("Huginn: the built-in OpenAI provider does not use Huginn OIDC authentication", vim.log.levels.WARN)
    return nil
  end

  local provider = cfg.ai.providers[cfg.ai.provider]
  if not provider then
    vim.notify(("Huginn: AI provider '%s' is not configured"):format(cfg.ai.provider), vim.log.levels.ERROR)
    return nil
  end
  return cfg.ai.provider, provider
end

function M.setup()
  if setup_done then
    return
  end

  local cfg = config.get()

  vim.keymap.set("n", "<leader>tt", function() run_profile("default") end, { desc = "Run default test profile" })
  vim.keymap.set("n", "<leader>tf", function() run_command({ vim.fn.expand("%:p") }) end, { desc = "Run current test file" })
  vim.keymap.set("n", "<leader>tp", function()
    local names = vim.tbl_keys(config.get().testing.profiles)
    table.sort(names)
    vim.ui.select(names, { prompt = "Test profile" }, function(name)
      if name then run_profile(name) end
    end)
  end, { desc = "Run test profile" })
  vim.keymap.set("n", "<leader>ta", function()
    local args = vim.fn.input("test args: ")
    if args ~= "" then
      run_command(testing.split_args(args))
    end
  end, { desc = "Run tests with arguments" })
  vim.keymap.set("n", "<leader>tc", run_check, { desc = "Run configured checks" })

  vim.keymap.set("n", "<leader>tr", function()
    local name = config.get().testing.framework
    if not framework.has_neotest(name) then
      vim.notify(("Huginn: framework '%s' does not provide Neotest support"):format(name), vim.log.levels.WARN)
      return
    end
    require("neotest").run.run()
  end, { desc = "Run nearest test" })

  vim.keymap.set("n", "<leader>td", function()
    local name = config.get().testing.framework
    if not framework.supports_debug(name) then
      vim.notify(("Huginn: framework '%s' does not provide debug support"):format(name), vim.log.levels.WARN)
      return
    end
    require("neotest").run.run({ strategy = "dap" })
  end, { desc = "Debug nearest test" })

  if cfg.keymaps.preset == "notepadpp" then
    set_optional_keymap("n", cfg.keymaps.run, function() run_profile("default") end, { desc = "Huginn: run default tests" })
    set_optional_keymap("n", cfg.keymaps.run_file, function() run_command({ vim.fn.expand("%:p") }) end, { desc = "Huginn: run current test file" })
    set_optional_keymap("n", cfg.keymaps.check, run_check, { desc = "Huginn: run configured checks" })
    set_optional_keymap("n", cfg.keymaps.profile, function()
      local names = vim.tbl_keys(config.get().testing.profiles)
      table.sort(names)
      vim.ui.select(names, { prompt = "Test profile" }, function(name)
        if name then run_profile(name) end
      end)
    end, { desc = "Huginn: choose test profile" })
    set_optional_keymap("n", cfg.keymaps.nearest, function()
      local name = config.get().testing.framework
      if framework.has_neotest(name) then
        require("neotest").run.run()
      end
    end, { desc = "Huginn: run nearest test" })
    set_optional_keymap("n", cfg.keymaps.debug, function()
      local name = config.get().testing.framework
      if framework.supports_debug(name) then
        require("neotest").run.run({ strategy = "dap" })
      end
    end, { desc = "Huginn: debug nearest test" })
    set_optional_keymap("n", cfg.keymaps.args, function()
      local args = vim.fn.input("test args: ")
      if args ~= "" then
        run_command(testing.split_args(args))
      end
    end, { desc = "Huginn: run tests with arguments" })
  end

  if not cfg.ai.enabled then
    setup_done = true
    return
  end

  vim.keymap.set("n", "<leader>aa", "<cmd>CodeCompanionActions<cr>", { desc = "AI actions" })
  vim.keymap.set("v", "<leader>ac", "<cmd>CodeCompanionChat<cr>", { desc = "AI chat" })

  create_user_command("HuginnAIAuth", function()
    local name, provider = ai_provider()
    if name and provider then auth.login(name, provider) end
  end, { desc = "Authenticate the configured Huginn AI provider" })

  create_user_command("HuginnAIStatus", function()
    local name, provider = ai_provider()
    if not name or not provider then return end
    local authenticated = auth.status(name)
    vim.notify(
      ("Huginn: AI provider '%s' is %s"):format(name, authenticated and "authenticated" or "not authenticated"),
      authenticated and vim.log.levels.INFO or vim.log.levels.WARN
    )
  end, { desc = "Show authentication status" })

  create_user_command("HuginnAIUsage", function() usage.status() end, { desc = "Show AI token usage and cost" })

  create_user_command("HuginnAILogout", function()
    local name = ai_provider()
    if name and auth.logout(name) then
      vim.notify(("Huginn: logged out from AI provider '%s'"):format(name), vim.log.levels.INFO)
    end
  end, { desc = "Remove locally stored Huginn AI credentials" })

  setup_done = true
end

return M
