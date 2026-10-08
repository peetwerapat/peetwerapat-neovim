local M = {}

local native_commands = {
  claude = "/usage",
  claude_ollama = "/usage",
  codex = "/status",
}

local function unavailable(provider, retryable)
  local command = native_commands[provider]
  if command then
    return { text = "Quota  —  ·  " .. command .. " in chat", level = "muted", retryable = retryable }
  end
  return { text = "Quota  —  ·  provider does not report a balance", level = "muted" }
end

local function percent(value)
  value = tonumber(value)
  if not value or value ~= value then
    return nil
  end
  return math.max(0, math.min(100, math.floor(value + 0.5)))
end

local function quota_line(windows)
  local valid = {}
  local lowest = 100
  for _, window in ipairs(windows) do
    local remaining = percent(window.remaining_percent)
    if remaining then
      lowest = math.min(lowest, remaining)
      table.insert(valid, {
        label = window.label or "quota",
        remaining_percent = remaining,
        resets_at = tonumber(window.resets_at),
      })
    end
  end
  if #valid == 0 then
    return nil
  end
  local level = lowest <= 15 and "low" or (lowest <= 40 and "medium" or "good")
  return { windows = valid, level = level }
end

local function countdown(reset_at, now)
  if not reset_at then
    return nil
  end
  local minutes = math.max(0, math.ceil((reset_at - now) / 60))
  local days = math.floor(minutes / 1440)
  local hours = math.floor(minutes % 1440 / 60)
  local parts = {}
  if days > 0 then
    table.insert(parts, days .. "d")
  end
  if hours > 0 or days > 0 then
    table.insert(parts, hours .. "h")
  end
  table.insert(parts, (minutes % 60) .. "m")
  return table.concat(parts, " ")
end

function M.display_rows(state, now)
  if type(state.windows) ~= "table" then
    return { { text = state.text or "Quota  —", level = state.level or "muted" } }
  end
  now = now or os.time()
  local rows = {}
  for _, window in ipairs(state.windows) do
    local value = window.remaining_percent
    local filled = math.floor(value / 10 + 0.5)
    local level = value <= 15 and "low" or (value <= 40 and "medium" or "good")
    local filled_bar = string.rep("━", filled)
    local empty_bar = string.rep("─", 10 - filled)
    local reset = countdown(window.resets_at, now)
    table.insert(rows, {
      label = window.label,
      bar = filled_bar .. empty_bar,
      filled_bar = filled_bar,
      empty_bar = empty_bar,
      percent = value .. "%",
      reset = reset,
      level = level,
      text = string.format("%s  %s  %d%%%s", window.label,
        filled_bar .. empty_bar, value, reset and ("  ↻ in " .. reset) or ""),
    })
  end
  return rows
end

local function from_codex(result)
  if type(result) ~= "table" then
    return nil
  end
  if result.ordinaryUsageAllowed == false then
    return { text = "Quota  unavailable  ·  check /status", level = "low" }
  end
  local limits = result.rateLimitsByLimitId and result.rateLimitsByLimitId.codex or result.rateLimits
  if type(limits) ~= "table" then
    return nil
  end
  local windows = {}
  for _, key in ipairs({ "primary", "secondary" }) do
    local window = limits[key]
    if type(window) == "table" and percent(window.usedPercent) then
      local minutes = tonumber(window.windowDurationMins)
      local label = key
      if minutes then
        label = minutes >= 1440 and (math.floor(minutes / 1440) .. "d")
            or (minutes >= 60 and (math.floor(minutes / 60) .. "h") or (minutes .. "m"))
      end
      table.insert(windows, {
        label = label,
        remaining_percent = 100 - tonumber(window.usedPercent),
        resets_at = window.resetsAt,
      })
    end
  end
  return quota_line(windows)
end

local function from_command(output)
  local ok, data = pcall(vim.json.decode, output)
  if not ok or type(data) ~= "table" then
    return nil
  end
  if type(data.windows) == "table" then
    return quota_line(data.windows)
  end
  return quota_line({ data })
end

local function codex_quota(done)
  if vim.fn.executable("codex") ~= 1 then
    done(nil)
    return
  end

  local job, pending = nil, ""
  local finished = false
  local timer = vim.uv.new_timer()
  local function finish(value)
    if finished then
      return
    end
    finished = true
    timer:stop()
    timer:close()
    if job and job > 0 then
      vim.fn.jobstop(job)
    end
    done(value)
  end
  local function send(id, method, params)
    vim.fn.chansend(job, vim.json.encode({ id = id, method = method, params = params }) .. "\n")
  end

  job = vim.fn.jobstart({ "codex", "app-server", "--stdio" }, {
    on_stdout = function(_, data)
      for index, chunk in ipairs(data or {}) do
        pending = pending .. chunk
        if index < #data then
          local line = pending
          pending = ""
          local ok, message = pcall(vim.json.decode, line)
          if ok and type(message) == "table" then
            if message.id == 1 and message.result then
              vim.fn.chansend(job, vim.json.encode({ method = "initialized", params = vim.empty_dict() }) .. "\n")
              send(2, "account/rateLimits/read", vim.empty_dict())
            elseif message.id == 1 and message.error then
              finish(nil)
              return
            elseif message.id == 2 then
              finish(from_codex(message.result))
              return
            end
          end
        end
      end
    end,
    on_exit = function()
      finish(nil)
    end,
  })
  if job <= 0 then
    finish(nil)
    return
  end
  timer:start(15000, 0, vim.schedule_wrap(function() finish(nil) end))
  send(1, "initialize", {
    clientInfo = { name = "nvim-ai-quota", title = "Neovim AI quota", version = "1.0.0" },
    capabilities = vim.empty_dict(),
  })
end

function M.native_command(provider)
  return native_commands[provider]
end

function M.refresh(provider, model, _, done)
  local commands = vim.g.ai_usage_commands
  local command = type(commands) == "table" and commands[provider]
  if type(command) == "table" and #command > 0 then
    local ok = pcall(vim.system, command, { text = true, timeout = 7000 }, function(result)
      vim.schedule(function()
        local value = result.code == 0 and from_command(result.stdout or "") or nil
        done(value or unavailable(provider))
      end)
    end)
    if not ok then
      done(unavailable(provider))
    end
    return
  end

  if provider == "ollama" and not model:match(":cloud$") then
    done({ text = "Quota  ∞  ·  local model", level = "good" })
  elseif provider == "codex" then
    codex_quota(function(value) done(value or unavailable(provider, true)) end)
  else
    done(unavailable(provider))
  end
end

M._from_codex = from_codex
M._from_command = from_command

return M
