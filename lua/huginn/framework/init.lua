local M = {}

local adapters = {}

function M.register(name, adapter)
  assert(type(name) == "string" and name ~= "", "framework adapter name must be a non-empty string")
  assert(type(adapter) == "table", "framework adapter must be a table")
  assert(type(adapter.build_command) == "function", "framework adapter must provide build_command")
  assert(adapters[name] == nil, ("framework adapter '%s' is already registered"):format(name))
  adapters[name] = adapter
end

function M.get(name)
  return adapters[name]
end

local function collect_neotest_plugins(field)
  local plugins = {}
  local seen = {}

  for _, adapter in pairs(adapters) do
    local neotest = adapter.neotest
    local entries = neotest and neotest[field]
    for _, plugin in ipairs(entries or {}) do
      if type(plugin) == "string" and not seen[plugin] then
        table.insert(plugins, plugin)
        seen[plugin] = true
      end
    end
  end

  table.sort(plugins)
  return plugins
end

function M.neotest_plugins()
  return collect_neotest_plugins("plugins")
end

function M.neotest_debug_plugins()
  local plugins = {}
  local seen = {}

  for _, adapter in pairs(adapters) do
    local debug = adapter.neotest and adapter.neotest.debug
    for _, plugin in ipairs(debug and debug.plugins or {}) do
      if type(plugin) == "string" and not seen[plugin] then
        table.insert(plugins, plugin)
        seen[plugin] = plugin
      end
    end
  end

  table.sort(plugins)
  return plugins
end

function M.neotest_adapter(name, options)
  local adapter = M.get(name)
  local neotest = adapter and adapter.neotest
  if not neotest or type(neotest.setup) ~= "function" then
    return nil
  end

  return neotest.setup(options or {})
end

function M.has_neotest(name)
  local adapter = M.get(name)
  return adapter and type(adapter.neotest) == "table" and type(adapter.neotest.setup) == "function" or false
end

function M.filetypes(name)
  local adapter = M.get(name)
  local filetypes = adapter and adapter.filetypes or {}
  return vim.deepcopy(filetypes)
end

function M.supports_debug(name)
  local adapter = M.get(name)
  local debug = adapter and adapter.neotest and adapter.neotest.debug
  return debug and debug.supported == true or false
end

return M
