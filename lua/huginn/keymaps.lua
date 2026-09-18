local config = require("huginn.config")

local M = {}

local function split_args(value)
  return vim.split(value, "%s+", { trimempty = true })
end

local function command_prefix()
  local manager = config.get().python.package_manager

  if manager == "poetry" then
    return { "poetry", "run" }
  elseif manager == "uv" then
    return { "uv", "run" }
  elseif manager == "pipenv" then
    return { "pipenv", "run" }
  elseif manager == "none" or manager == "" then
    return {}
  end

  return { manager }
end

local function run_command(args)
  local command = command_prefix()
  for _, arg in ipairs(args or {}) do
    table.insert(command, arg)
  end

  vim.cmd("botright split | terminal " .. table.concat(vim.tbl_map(vim.fn.shellescape, command), " "))
end

local function run_profile(name)
  local cfg = config.get()
  local profile = cfg.testing.profiles[name]

  if not profile then
    vim.notify(("Huginn: unknown pytest profile '%s'"):format(name), vim.log.levels.ERROR)
    return
  end

  run_command(vim.list_extend({ cfg.testing.runner }, vim.deepcopy(profile)))
end

function M.setup()
  vim.keymap.set("n", "<leader>tt", function()
    run_profile("default")
  end, { desc = "Run default test profile" })

  vim.keymap.set("n", "<leader>tf", function()
    run_command({ config.get().testing.runner, vim.fn.expand("%:p") })
  end, { desc = "Run current test file" })

  vim.keymap.set("n", "<leader>tp", function()
    local names = vim.tbl_keys(config.get().testing.profiles)
    table.sort(names)
    vim.ui.select(names, { prompt = "Test profile" }, function(name)
      if name then
        run_profile(name)
      end
    end)
  end, { desc = "Run test profile" })

  vim.keymap.set("n", "<leader>ta", function()
    local args = vim.fn.input("test args: ")
    if args ~= "" then
      run_command(vim.list_extend({ config.get().testing.runner }, split_args(args)))
    end
  end, { desc = "Run tests with arguments" })

  vim.keymap.set("n", "<leader>tr", function()
    require("neotest").run.run()
  end, { desc = "Run nearest test" })

  vim.keymap.set("n", "<leader>td", function()
    require("neotest").run.run({ strategy = "dap" })
  end, { desc = "Debug nearest test" })

  vim.keymap.set("n", "<leader>aa", "<cmd>CodeCompanionActions<cr>", { desc = "AI actions" })
  vim.keymap.set("v", "<leader>ac", "<cmd>CodeCompanionChat<cr>", { desc = "AI chat" })
end

return M
