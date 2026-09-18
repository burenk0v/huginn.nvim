local M = {}

local function poetry_pytest(args)
  local command = { "poetry", "run", "pytest" }
  for _, arg in ipairs(args or {}) do
    table.insert(command, arg)
  end
  vim.cmd("botright split | terminal " .. table.concat(vim.tbl_map(vim.fn.shellescape, command), " "))
end

function M.setup()
  vim.keymap.set("n", "<leader>tt", function()
    poetry_pytest({ "tests" })
  end, { desc = "Run all tests" })

  vim.keymap.set("n", "<leader>tf", function()
    poetry_pytest({ vim.fn.expand("%:p") })
  end, { desc = "Run current test file" })

  vim.keymap.set("n", "<leader>ta", function()
    local args = vim.fn.input("pytest args: ")
    if args ~= "" then
      poetry_pytest(vim.split(args, " ", { trimempty = true }))
    end
  end, { desc = "Run pytest with arguments" })

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
