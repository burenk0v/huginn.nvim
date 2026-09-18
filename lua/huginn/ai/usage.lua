local config = require("huginn.config")

local M = {
  setup_done = false,
  total_tokens = 0,
  requests = 0,
  chat_tokens = {},
}

function M.record(tokens)
  tokens = tonumber(tokens)
  if not tokens or tokens < 0 then
    return
  end
  M.total_tokens = M.total_tokens + tokens
  M.requests = M.requests + 1
end

function M.record_chat(bufnr, tokens)
  tokens = tonumber(tokens)
  if not tokens or tokens < 0 then
    return
  end

  local previous = M.chat_tokens[bufnr] or 0
  if tokens < previous then
    previous = 0
  end

  local delta = tokens - previous
  M.chat_tokens[bufnr] = tokens

  if delta > 0 then
    M.record(delta)
  end
end

function M.snapshot()
  local cfg = config.get()
  local usage = cfg.ai.usage or {}
  local configured_budget = tonumber(usage.budget_tokens)
  local budget = configured_budget and configured_budget > 0 and configured_budget or nil
  local cost_per_million = tonumber(usage.cost_per_million_tokens) or 0
  local cost = M.total_tokens / 1000000 * cost_per_million

  return {
    requests = M.requests,
    tokens = M.total_tokens,
    cost = cost,
    budget_tokens = budget,
    remaining_tokens = budget and math.max(0, budget - M.total_tokens) or nil,
  }
end

function M.setup()
  if M.setup_done then
    return
  end
  M.setup_done = true
  vim.api.nvim_create_autocmd("User", {
    pattern = "CodeCompanionChatCreated",
    callback = function(args)
      local bufnr = args.data.bufnr
      local chat = require("codecompanion").buf_get_chat(bufnr)
      if not chat then
        return
      end

      chat:add_callback("on_checkpoint", function(_, data)
        M.record_chat(bufnr, data.reported_tokens or data.estimated_tokens)
      end)
    end,
  })
end

function M.status()
  local data = M.snapshot()
  local remaining = data.remaining_tokens and (", remaining: " .. data.remaining_tokens) or ""
  vim.notify(
    ("Huginn AI: %d requests, %d tokens, cost: %.4f%s"):format(
      data.requests,
      data.tokens,
      data.cost,
      remaining
    ),
    vim.log.levels.INFO
  )
end

return M
