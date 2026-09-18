local M = {}

function M.setup(framework)
  framework.register("pytest", {
    filetypes = { "python" },

    build_command = function(options, args)
      local command = { options.runner or "pytest" }
      for _, arg in ipairs(args or {}) do
        table.insert(command, arg)
      end
      return command
    end,

    neotest = {
      plugins = { "nvim-neotest/neotest-python" },
      setup = function(options)
        return require("neotest-python")({ runner = options.runner or "pytest" })
      end,
      debug = {
        supported = true,
        plugins = { "mfussenegger/nvim-dap" },
      },
    },
  })
end

return M
