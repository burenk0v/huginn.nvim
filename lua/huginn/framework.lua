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

M.register("pytest", {
  build_command = function(cfg, args)
    local command = { cfg.testing.runner }
    for _, arg in ipairs(args or {}) do
      table.insert(command, arg)
    end
    return command
  end,
})

return M
