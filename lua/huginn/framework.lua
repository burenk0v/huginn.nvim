local M = {}

local adapters = {}

function M.register(name, adapter)
  assert(type(name) == "string" and name ~= "", "framework adapter name must be a non-empty string")
  assert(type(adapter) == "table", "framework adapter must be a table")
  assert(type(adapter.build_command) == "function", "framework adapter must provide build_command")
  adapters[name] = adapter
end

function M.get(name)
  return adapters[name]
end

function M.neotest_plugins()
  local plugins = {}
  local seen = {}

  for _, adapter in pairs(adapters) do
    local neotest = adapter.neotest
    if neotest and type(neotest.plugin) == "string" and not seen[neotest.plugin] then
      table.insert(plugins, neotest.plugin)
      seen[neotest.plugin] = true
    end
  end

  table.sort(plugins)
  return plugins
end

function M.neotest_adapter(name, cfg)
  local adapter = M.get(name)
  local neotest = adapter and adapter.neotest
  if not neotest or type(neotest.setup) ~= "function" then
    return nil
  end

  return neotest.setup(cfg)
end

M.register("pytest", {
  build_command = function(cfg, args)
    local command = { cfg.testing.runner }
    for _, arg in ipairs(args or {}) do
      table.insert(command, arg)
    end
    return command
  end,

  neotest = {
    plugin = "nvim-neotest/neotest-python",
    setup = function(cfg)
      return require("neotest-python")({ runner = cfg.testing.runner })
    end,
  },
})

return M
