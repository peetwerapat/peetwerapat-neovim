local M = {}

-- ==============================
-- CONFIG
-- ==============================

local OLLAMA_HOST = vim.env.OLLAMA_HOST or "http://localhost:11434"

local MODELS = {
  ask           = vim.env.OLLAMA_MODEL_ASK or "qwen2.5-coder:7b",
  code          = vim.env.OLLAMA_MODEL_CODE or "qwen2.5-coder:14b",
  claude        = "claude",
  codex         = "codex",
  antigravity   = "agy",
  claude_ollama = "qwen3-coder-next:cloud",
}

local MAX_FILES = tonumber(vim.env.AI_MAX_FILES or "5")
local MAX_FILE_CHARS = tonumber(vim.env.AI_MAX_FILE_CHARS or "12000")
local MAX_TOTAL_CHARS = tonumber(vim.env.AI_MAX_TOTAL_CHARS or "40000")

-- ==============================
-- STATE
-- ==============================

local current_chan = nil
local current_model = nil
local current_provider = nil
local session_generation = 0

local chat_win = nil
local chat_buf = nil
local quota_win = nil
local quota_buf = nil
local usage_timer = nil
local usage_state = { text = "Quota  —", level = "muted" }
local usage_refreshing = false
local usage_retry_count = 0
local is_waiting = false

local usage = require("peetwerapat.core.ai_usage")

function M.get_current_model()
  return current_model
end

function M.get_usage_text()
  local rows = usage.display_rows(usage_state)
  local lines = {}
  for _, row in ipairs(rows) do
    table.insert(lines, row.text)
  end
  return table.concat(lines, "\n")
end

-- ==============================
-- WINDOW
-- ==============================

local header_ns = vim.api.nvim_create_namespace("ai_quota_footer")
local header_colors = {
  good = "#43d9a3",
  medium = "#f5c76b",
  low = "#ff6b82",
  muted = "#8792a2",
}

local function set_header_highlights()
  vim.api.nvim_set_hl(0, "AIQuotaBackground", { bg = "#1a1a1a" })
  for level, fg in pairs(header_colors) do
    vim.api.nvim_set_hl(0, "AIQuota" .. level, { fg = fg, bg = "#1a1a1a" })
  end
  vim.api.nvim_set_hl(0, "AIQuotaTitle", { fg = "#00bfff", bg = "#1a1a1a", bold = true })
  vim.api.nvim_set_hl(0, "AIQuotaLive", { fg = "#43d9a3", bg = "#1a1a1a", bold = true })
  vim.api.nvim_set_hl(0, "AIQuotaLabel", { fg = "#b7c7dc", bg = "#1a1a1a", bold = true })
end
set_header_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_header_highlights })

local function footer_heading(width)
  if not current_model then
    return "", "", ""
  end
  local left = "  🤖  " .. current_model:gsub("^%l", string.upper)
  if current_model ~= current_provider then
    left = left .. "  ·  " .. current_provider:gsub("^%l", string.upper)
  end
  local right = "●  AUTO SYNC  "
  if vim.fn.strdisplaywidth(left .. right) + 2 > width then
    right = ""
  end
  local space = string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(left .. right)))
  return left, space, right
end

local function render_footer()
  if not quota_win or not vim.api.nvim_win_is_valid(quota_win)
      or not quota_buf or not vim.api.nvim_buf_is_valid(quota_buf) then
    return
  end
  local left, space, right = footer_heading(vim.api.nvim_win_get_width(quota_win))
  local lines = { left .. space .. right, "", "", "" }
  if current_model then
    for index, row in ipairs(usage.display_rows(usage_state)) do
      if index > 2 then
        break
      end
      lines[index + 2] = "  " .. row.text
    end
  end
  if not vim.deep_equal(vim.api.nvim_buf_get_lines(quota_buf, 0, -1, false), lines) then
    vim.bo[quota_buf].modifiable = true
    vim.api.nvim_buf_set_lines(quota_buf, 0, -1, false, lines)
    vim.bo[quota_buf].modifiable = false
  end
  if vim.api.nvim_win_get_height(quota_win) ~= 4 then
    pcall(vim.api.nvim_win_set_height, quota_win, 4)
  end
  vim.api.nvim_win_set_cursor(quota_win, { 1, 0 })
  vim.api.nvim_win_call(quota_win, function() vim.fn.winrestview({ topline = 1 }) end)
end

local function render_header()
  vim.schedule(function()
    render_footer()
    if chat_win and vim.api.nvim_win_is_valid(chat_win) then
      vim.wo[chat_win].winbar = ""
      vim.wo[chat_win].statusline = "%#AIQuotaBackground# "
      vim.cmd("redraw!")
    end
  end)
end

vim.api.nvim_set_decoration_provider(header_ns, {
  on_win = function(_, win, buf)
    if win ~= quota_win or buf ~= quota_buf or not current_model then
      return
    end
    local rows = usage.display_rows(usage_state)
    local width = vim.api.nvim_win_get_width(win)
    local left, space, right = footer_heading(width)
    local heading = {
      { left, "AIQuotaTitle" },
      { space, "AIQuotaBackground" },
      { right, "AIQuotaLive" },
    }
    vim.api.nvim_buf_set_extmark(buf, header_ns, 0, 0, {
      virt_text = heading,
      virt_text_pos = "overlay",
      hl_mode = "replace",
      ephemeral = true,
    })
    for index, row in ipairs(rows) do
      local line = index + 1
      if line >= 4 then
        break
      end
      local chunks
      if row.bar then
        chunks = {
          { "  " .. string.format("%-3s", row.label) .. "  ", "AIQuotaLabel" },
          { row.filled_bar, "AIQuota" .. row.level },
          { row.empty_bar, "AIQuotamuted" },
          { "  " .. string.format("%3s", row.percent), "AIQuota" .. row.level },
          { row.reset and ("   ↻ " .. row.reset) or "", "AIQuotamuted" },
        }
      else
        chunks = { { "  " .. row.text, "AIQuota" .. row.level } }
      end
      table.insert(chunks, { string.rep(" ", width), "AIQuotaBackground" })
      vim.api.nvim_buf_set_extmark(buf, header_ns, line, 0, {
        virt_text = chunks,
        virt_text_pos = "overlay",
        hl_mode = "replace",
        ephemeral = true,
      })
    end
  end,
})

local function ensure_quota_footer()
  if quota_win and vim.api.nvim_win_is_valid(quota_win) then
    return
  end
  vim.api.nvim_set_current_win(chat_win)
  vim.cmd("belowright 4split")
  quota_win = vim.api.nvim_get_current_win()
  quota_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(quota_buf, 0, -1, false, { "", "", "", "" })
  vim.bo[quota_buf].buflisted = false
  vim.bo[quota_buf].bufhidden = "wipe"
  vim.bo[quota_buf].filetype = "ai_quota"
  vim.bo[quota_buf].modifiable = false
  vim.b[quota_buf].ai_chat = true
  vim.api.nvim_win_set_buf(quota_win, quota_buf)
  vim.wo[quota_win].winfixheight = true
  vim.wo[quota_win].number = false
  vim.wo[quota_win].relativenumber = false
  vim.wo[quota_win].signcolumn = "no"
  vim.wo[quota_win].foldcolumn = "0"
  vim.wo[quota_win].wrap = false
  vim.wo[quota_win].scrolloff = 0
  vim.wo[quota_win].cursorline = false
  vim.wo[quota_win].statusline = "%#AIQuotaBackground# "
  vim.wo[quota_win].winhighlight = "Normal:AIQuotaBackground,EndOfBuffer:AIQuotaBackground,StatusLine:AIQuotaBackground,StatusLineNC:AIQuotaBackground"
  vim.api.nvim_set_current_win(chat_win)
end

local function ensure_chat_vsplit()
  if chat_win and vim.api.nvim_win_is_valid(chat_win) then
    ensure_quota_footer()
    vim.api.nvim_set_current_win(chat_win)
    return chat_win
  end

  vim.cmd("vsplit")
  vim.cmd("wincmd l")
  vim.cmd("vertical resize 60")

  chat_win = vim.api.nvim_get_current_win()
  vim.wo[chat_win].winhighlight = "WinBar:AIQuotaBackground,WinBarNC:AIQuotaBackground"
  vim.wo[chat_win].statusline = "%#AIQuotaBackground# "

  if not chat_buf or not vim.api.nvim_buf_is_valid(chat_buf) then
    chat_buf = vim.api.nvim_create_buf(false, true)
  end

  vim.api.nvim_win_set_buf(chat_win, chat_buf)
  ensure_quota_footer()
  return chat_win
end

-- ==============================
-- UTIL
-- ==============================

local function notify(msg, level)
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.INFO)
  end)
end

local function chan_valid(chan)
  if type(chan) ~= "number" then
    return false
  end
  local ok = pcall(vim.fn.chansend, chan, "")
  return ok
end

local function stop_current()
  session_generation = session_generation + 1
  if usage_timer then
    usage_timer:stop()
    usage_timer:close()
    usage_timer = nil
  end
  if chan_valid(current_chan) then
    vim.fn.chansend(current_chan, "\003")
  end
  current_chan = nil
  current_model = nil
  current_provider = nil
  is_waiting = false
  usage_refreshing = false
  usage_retry_count = 0
  usage_state = { text = "Quota  —", level = "muted" }
  render_header()
end

local function provider_exited(provider, generation)
  if generation ~= session_generation then
    return
  end
  stop_current()
  notify(provider .. " session exited", vim.log.levels.INFO)
end

local function refresh_usage()
  if not current_provider or usage_refreshing then
    return
  end
  usage_refreshing = true
  local generation = session_generation
  usage.refresh(current_provider, current_model, OLLAMA_HOST, function(state)
    if generation ~= session_generation then
      return
    end
    usage_refreshing = false
    if state.retryable and usage_retry_count < 2 then
      usage_retry_count = usage_retry_count + 1
      usage_state = { text = "Quota  checking…  ·  retry " .. usage_retry_count .. "/2", level = "muted" }
      render_header()
      vim.defer_fn(function()
        if generation == session_generation then
          refresh_usage()
        end
      end, 3000)
      return
    end
    usage_retry_count = 0
    usage_state = state
    render_header()
  end)
end

vim.api.nvim_create_autocmd("WinClosed", {
  callback = function(event)
    if tonumber(event.match) == quota_win then
      quota_win = nil
      quota_buf = nil
      return
    end
    if tonumber(event.match) ~= chat_win then
      return
    end
    vim.schedule(function()
      stop_current()
      chat_win = nil
      if quota_win and vim.api.nvim_win_is_valid(quota_win) then
        vim.api.nvim_win_close(quota_win, true)
      end
      quota_win = nil
      quota_buf = nil
    end)
  end,
})

vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
  callback = function()
    if quota_win then
      vim.schedule(render_footer)
    end
  end,
})

local function shell_escape(value)
  return vim.fn.shellescape(value)
end

local function normalize_path(path)
  return vim.fn.fnamemodify(vim.fn.expand(path), ":p")
end

local function truncate_content(content, max_chars)
  if #content <= max_chars then
    return content, false
  end
  return content:sub(1, max_chars) .. "\n\n...[truncated]...", true
end

local function read_file(path)
  local expanded = normalize_path(path)

  if vim.fn.filereadable(expanded) ~= 1 then
    return nil, "Cannot read file: " .. expanded
  end

  local f = io.open(expanded, "r")
  if not f then
    return nil, "Cannot open file: " .. expanded
  end

  local content = f:read("*a")
  f:close()

  if not content then
    return nil, "Cannot read file content: " .. expanded
  end

  local truncated
  content, truncated = truncate_content(content, MAX_FILE_CHARS)

  return {
    path = expanded,
    content = content,
    truncated = truncated,
  }
end

local function get_current_buffer_content()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return nil, "Current buffer has no file name"
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local content = table.concat(lines, "\n")
  local truncated
  content, truncated = truncate_content(content, MAX_FILE_CHARS)

  return {
    path = normalize_path(name),
    content = content,
    truncated = truncated,
  }
end

local function collect_files_from_folder(folder, pattern)
  local root = normalize_path(folder)
  local glob_pattern = pattern or "**/*"
  local glob = root .. "/" .. glob_pattern
  local matches = vim.fn.glob(glob, true, true)

  local files = {}

  for _, file in ipairs(matches) do
    local full = normalize_path(file)
    if vim.fn.filereadable(full) == 1 then
      table.insert(files, full)
    end
  end

  table.sort(files)

  local result = {}
  for i, file in ipairs(files) do
    if i > MAX_FILES then
      break
    end

    local item, err = read_file(file)
    if item then
      table.insert(result, item)
    else
      notify(err, vim.log.levels.WARN)
    end
  end

  return result, #files
end

local function format_file_block(file)
  return table.concat({
    "<file path=\"" .. file.path .. "\">",
    file.content,
    "</file>",
  }, "\n")
end
local function strip_token(input, pattern)
  local out = input:gsub(pattern, "")
  out = out:gsub("%s+", " ")
  out = out:gsub("^%s+", "")
  out = out:gsub("%s+$", "")
  return out
end

local function parse_contexts(input)
  local parts = {}
  local total_chars = 0

  if input:match("@buffer") then
    local file, err = get_current_buffer_content()
    if not file then
      return nil, err
    end

    local block = format_file_block(file)
    total_chars = total_chars + #block
    if total_chars > MAX_TOTAL_CHARS then
      return nil, "Context too large: current buffer exceeds limit"
    end

    table.insert(parts, block)
    input = strip_token(input, "@buffer")
  end

  local file_paths = {}
  for path in input:gmatch("@file%s+([^%s]+)") do
    table.insert(file_paths, path)
  end

  for _, path in ipairs(file_paths) do
    local file, err = read_file(path)
    if not file then
      return nil, err
    end

    local block = format_file_block(file)
    total_chars = total_chars + #block
    if total_chars > MAX_TOTAL_CHARS then
      return nil, "Context too large: too many file contents"
    end

    table.insert(parts, block)
  end

  input = strip_token(input, "@file%s+([^%s]+)")

  local folder_requests = {}
  for folder, pattern in input:gmatch("@folder%s+([^%s]+)%s+([^%s]+)") do
    table.insert(folder_requests, { folder = folder, pattern = pattern })
  end

  for _, req in ipairs(folder_requests) do
    local files, total_found = collect_files_from_folder(req.folder, req.pattern)

    if total_found == 0 then
      return nil, "No files matched in folder: " .. req.folder .. " pattern: " .. req.pattern
    end

    if total_found > MAX_FILES then
      table.insert(parts, string.format(
        "Note: matched %d files in %s, only first %d were included.",
        total_found,
        normalize_path(req.folder),
        MAX_FILES
      ))
    end

    for _, file in ipairs(files) do
      local block = format_file_block(file)
      total_chars = total_chars + #block
      if total_chars > MAX_TOTAL_CHARS then
        table.insert(parts, "\n[Stopped adding more files: total context limit reached]")
        break
      end
      table.insert(parts, block)
    end
  end

  input = strip_token(input, "@folder%s+([^%s]+)%s+([^%s]+)")

  return {
    cleaned_input = input,
    parts = parts,
  }
end

-- ==============================
-- SPAWNERS
-- ==============================

local providers = {}

providers.ollama = function(model, generation)
  return vim.fn.termopen(
    {
      "bash",
      "-c",
      string.format(
        "export OLLAMA_HOST=%s && ollama run %s",
        shell_escape(OLLAMA_HOST),
        shell_escape(model)
      ),
    },
    {
      buffer = chat_buf,
      on_exit = function()
        provider_exited("Ollama", generation)
      end,
    }
  )
end

providers.claude = function(_, generation)
  return vim.fn.termopen(
    { "bash", "-c", "claude" },
    {
      buffer = chat_buf,
      on_exit = function()
        provider_exited("Claude", generation)
      end,
    }
  )
end

providers.claude_ollama = function(model, generation)
  return vim.fn.termopen(
    {
      "bash",
      "-lc",
      string.format(
        "export OLLAMA_HOST=%s && ollama launch claude --model %s",
        shell_escape(OLLAMA_HOST),
        shell_escape(model)
      ),
    },
    {
      buffer = chat_buf,
      on_exit = function()
        provider_exited("Claude (Ollama)", generation)
      end,
    }
  )
end

providers.codex = function(_, generation)
  return vim.fn.termopen(
    { "bash", "-lc", "codex" },
    {
      buffer = chat_buf,
      on_exit = function()
        provider_exited("Codex", generation)
      end,
    }
  )
end

providers.antigravity = function(_, generation)
  return vim.fn.termopen(
    { "bash", "-lc", "agy" },
    {
      buffer = chat_buf,
      on_exit = function()
        provider_exited("Antigravity", generation)
      end,
    }
  )
end

-- ==============================
-- CHAT BUFFER KEYMAPS
-- ==============================

local function setup_chat_keymaps(buf)
  -- Disabled: <Esc> was passed through to the AI CLI, which interrupts the
  -- running response. Falls back to the global "t" mapping (<Esc> -> normal mode).
  -- vim.keymap.set("t", "<Esc>", "<Esc>", {
  --   buffer = buf,
  --   silent = true,
  --   desc = "Send Esc to AI CLI",
  -- })
  local _ = buf
end

-- ==============================
-- CORE LAUNCH
-- ==============================

local function launch(provider, model)
  stop_current()

  local win = ensure_chat_vsplit()

  chat_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[chat_buf].buflisted = false
  vim.bo[chat_buf].bufhidden = "wipe"
  vim.api.nvim_win_set_buf(win, chat_buf)
  setup_chat_keymaps(chat_buf)

  current_provider = provider
  current_model = model
  local generation = session_generation
  usage_state = { text = "Quota  checking…", level = "muted" }
  render_header()

  if provider == "ollama" then
    current_chan = providers.ollama(model, generation)
  elseif provider == "claude" then
    current_chan = providers.claude(model, generation)
  elseif provider == "claude_ollama" then
    current_chan = providers.claude_ollama(model, generation)
  elseif provider == "codex" then
    current_chan = providers.codex(model, generation)
  elseif provider == "antigravity" then
    current_chan = providers.antigravity(model, generation)
  end

  vim.bo[chat_buf].buflisted = false
  vim.bo[chat_buf].filetype = "ai_chat"
  vim.b[chat_buf].ai_chat = true
  refresh_usage()
  usage_timer = vim.uv.new_timer()
  local usage_tick = 0
  usage_timer:start(60000, 60000, vim.schedule_wrap(function()
    usage_tick = usage_tick + 1
    if usage_tick % 2 == 0 then
      refresh_usage()
    else
      render_header()
    end
  end))
  vim.cmd("startinsert")
end

-- ==============================
-- PROMPT BUILDER
-- ==============================

local function build_prompt(opts)
  local input = opts.args or ""
  local selection = ""

  if opts.range == 2 then
    selection = table.concat(vim.fn.getline(opts.line1, opts.line2), "\n")
  end

  if input == "" then
    return nil
  end

  local ctx, err = parse_contexts(input)
  if not ctx then
    return nil, err
  end

  local parts = {}

  -- NOTE: the system prompt must be inserted after `parts` is declared
  table.insert(parts, [[
You are a senior software engineer.
You can read and analyze the provided file contents.
The code is already given to you inside <file> tags.
Do NOT say you cannot access files.
Answer directly based only on the provided code.
]])

  -- =====================

  for _, part in ipairs(ctx.parts) do
    table.insert(parts, part)
  end

  if selection ~= "" then
    local selected = selection
    local was_truncated
    selected, was_truncated = truncate_content(selected, MAX_FILE_CHARS)

    table.insert(parts, "Selected code:")
    if was_truncated then
      table.insert(parts, "[selection truncated]")
    end
    table.insert(parts, "```")
    table.insert(parts, selected)
    table.insert(parts, "```")
  end

  if ctx.cleaned_input == "" then
    return nil, "Missing task after context tags"
  end

  table.insert(parts, "Task:")
  table.insert(parts, ctx.cleaned_input)

  return table.concat(parts, "\n\n")
end

local function send_prompt(prompt)
  if not chan_valid(current_chan) then
    return notify("No active AI session", vim.log.levels.ERROR)
  end

  is_waiting = true
  notify("AI is thinking...", vim.log.levels.INFO)

  vim.fn.chansend(current_chan, prompt .. "\n")
  vim.defer_fn(refresh_usage, 5000)

  vim.defer_fn(function()
    if is_waiting then
      notify("Prompt sent", vim.log.levels.INFO)
      is_waiting = false
    end
  end, 150)
end

-- ==============================
-- COMMANDS
-- ==============================

function M.ask(opts)
  local prompt, err = build_prompt(opts)
  if not prompt then
    return notify(err or "AIAsk: missing prompt", vim.log.levels.ERROR)
  end

  if not chan_valid(current_chan) or current_model ~= MODELS.ask or current_provider ~= "ollama" then
    launch("ollama", MODELS.ask)
  end

  vim.defer_fn(function()
    send_prompt(prompt)
  end, 80)
end

function M.code(opts)
  local prompt, err = build_prompt(opts)
  if not prompt then
    return notify(err or "AICode: missing prompt", vim.log.levels.ERROR)
  end

  if not chan_valid(current_chan) or current_model ~= MODELS.code or current_provider ~= "ollama" then
    launch("ollama", MODELS.code)
  end

  vim.defer_fn(function()
    send_prompt(prompt)
  end, 80)
end

function M.chat1()
  launch("ollama", MODELS.ask)
end

function M.chat2()
  launch("ollama", MODELS.code)
end

function M.chat3()
  launch("claude", MODELS.claude)
end

function M.chat4()
  launch("codex", MODELS.codex)
end

function M.chat5()
  launch("antigravity", MODELS.antigravity)
end

function M.chat6()
  launch("claude_ollama", MODELS.claude_ollama)
end

function M.stop()
  if chan_valid(current_chan) then
    stop_current()
    notify("AI stopped", vim.log.levels.INFO)
  else
    notify("No AI session running", vim.log.levels.WARN)
  end
end

function M.usage()
  if not chan_valid(current_chan) then
    return notify("No active AI session", vim.log.levels.WARN)
  end
  refresh_usage()
  local command = usage.native_command(current_provider)
  if command then
    vim.fn.chansend(current_chan, command .. "\n")
  else
    notify("This provider has no account quota command", vim.log.levels.INFO)
  end
end

-- ==============================
-- USER COMMANDS
-- ==============================

vim.api.nvim_create_user_command(
  "AIAsk",
  function(opts) M.ask(opts) end,
  { nargs = "*", range = true }
)

vim.api.nvim_create_user_command(
  "AICode",
  function(opts) M.code(opts) end,
  { nargs = "*", range = true }
)

vim.api.nvim_create_user_command("AIChat1", function() M.chat1() end, {})
vim.api.nvim_create_user_command("AIChat2", function() M.chat2() end, {})
vim.api.nvim_create_user_command("AIChat3", function() M.chat3() end, {})
vim.api.nvim_create_user_command("AIChat4", function() M.chat4() end, {})
vim.api.nvim_create_user_command("AIChat5", function() M.chat5() end, {})
vim.api.nvim_create_user_command("AIChat6", function() M.chat6() end, {})
vim.api.nvim_create_user_command("AIStop", function() M.stop() end, {})
vim.api.nvim_create_user_command("AIUsage", function() M.usage() end, {})

-- ==============================
-- KEYMAPS
-- ==============================

vim.keymap.set("n", "<leader>ac1", function()
  M.chat1()
end, { desc = "AI Chat (qwen2.5-coder:7b)" })

vim.keymap.set("n", "<leader>ac2", function()
  M.chat2()
end, { desc = "AI Chat (qwen2.5-coder:14b)" })

vim.keymap.set("n", "<leader>ac3", function()
  M.chat3()
end, { desc = "Claude CLI Chat" })

vim.keymap.set("n", "<leader>ac4", function()
  M.chat4()
end, { desc = "Codex CLI Chat" })

vim.keymap.set("n", "<leader>ac5", function()
  M.chat5()
end, { desc = "Antigravity CLI Chat" })

vim.keymap.set("n", "<leader>ac6", function()
  M.chat6()
end, { desc = "Claude via Ollama (qwen3-coder-next:cloud)" })

vim.keymap.set("n", "<leader>au", function()
  M.usage()
end, { desc = "Show AI provider quota" })

vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { silent = true })

return M
