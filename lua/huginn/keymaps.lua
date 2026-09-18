local config = require("huginn.config")
local testing = require("huginn.testing")
local auth = require("huginn.ai.auth")
local usage = require("huginn.ai.usage")

local M = {}

local function run_terminal(command)
  vim.cmd("botright split | terminal " .. table.concat(vim.tbl_map(vim.fn.shellescape, command), " "))
end

local function run_command(args)
  run_terminal(testing.build_command(args))
end

local function run_profile(name)
  local command = testing.build_profile_command(name)
  if not command then
    vim.notify(("Huginn: unknown pytest profile '%s'"):format(name), vim.log.levels.ERROR)
    return
  end
  run_terminal(command)
end

local function ai_provider()
  local cfg = config.get()
  if not cfg.ai.enabled then
    vim.notify("Huginn: AI integration is disabled", vim.log.levels.WARN)
    return nil
  end

  local provider = cfg.ai.providers[cfg.ai.provider]
  if not provider then
    vim.notify(("Huginn: AI provider '%s' is not configured for authentication"):format(cfg.ai.provider), vim.log.levels.ERROR)
    return nil
  end
  return cfg.ai.provider, provider
end

function M.setup()
  vim.keymap.set("n", "<leader>tt", function() run_profile("default") end, { desc = "Run default test profile" })

  vim.keymap.set("n", "<leader>tf", function()
    run_command({ config.get().testing.runner, vim.fn.expand("%:p") })
  end, { desc = "Run current test file" })

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
      run_command(vim.list_extend({ config.get().testing.runner }, testing.split_args(args)))
    end
  end, { desc = "Run tests with arguments" })

  vim.keymap.set("n", "<leader>tr", function() require("neotest").run.run() end, { desc = "Run nearest test" })
  vim.keymap.set("n", "<leader>td", function() require("neotest").run.run({ strategy = "dap" }) end, { desc = "Debug nearest test" })

  if not config.get().ai.enabled then
    return
  end

  vim.keymap.set("n", "<leader>aa", "<cmd>CodeCompanionActions<cr>", { desc = "AI actions" })
  vim.keymap.set("v", "<leader>ac", "<cmd>CodeCompanionChat<cr>", { desc = "AI chat" })

  vim.api.nvim_create_user_command("HuginnAIAuth", function()
    local name, provider = ai_provider()
    if name and provider then
      auth.login(name, provider)
    end
  end, { desc = "Authenticate the configured Huginn AI provider" })

  vim.api.nvim_create_user_command("HuginnAIStatus", function()
    local name, provider = ai_provider()
    if not name or not provider then return end
    local authenticated = auth.status(name)
    vim.notify(
      ("Huginn: AI provider '%s' is %s"):format(name, authenticated and "authenticated" or "not authenticated"),
      authenticated and vim.log.levels.INFO or vim.log.levels.WARN
    )
  end, { desc = "Show Huginn AI authentication status" })

  vim.api.nvim_create_user_command("HuginnAIUsage", function()
    usage.status()
  end, { desc = "Show Huginn AI token usage and cost" })

  vim.api.nvim_create_user_command("HuginnAILogout", function()
    local name = ai_provider()
    if name then
      auth.logout(name)
      vim.notify(("Huginn: logged out from AI provider '%s'"):format(name), vim.log.levels.INFO)
    end
  end, { desc = "Remove Huginn AI credentials" })
end

return M
