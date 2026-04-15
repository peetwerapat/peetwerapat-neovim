local M = {}

-- ==============================
-- CONFIG
-- ==============================

local OLLAMA_HOST = vim.env.OLLAMA_HOST or "http://localhost:11434"

local MODELS = {
  ask           = vim.env.OLLAMA_MODEL_ASK or "qwen2.5-coder:7b",
  code          = vim.env.OLLAMA_MODEL_CODE or "qwen2.5-coder:14b",
  claude        = "claude",
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

local chat_win = nil
local chat_buf = nil
local is_waiting = false

function M.get_current_model()
  return current_model
end

-- ==============================
-- WINDOW
-- ==============================

local function ensure_chat_vsplit()
  if chat_win and vim.api.nvim_win_is_valid(chat_win) then
    return chat_win
  end

  vim.cmd("vsplit")
  vim.cmd("wincmd l")
  vim.cmd("vertical resize 60")

  chat_win = vim.api.nvim_get_current_win()

  if not chat_buf or not vim.api.nvim_buf_is_valid(chat_buf) then
    chat_buf = vim.api.nvim_create_buf(false, true)
  end

  vim.api.nvim_win_set_buf(chat_win, chat_buf)
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
  if chan_valid(current_chan) then
    vim.fn.chansend(current_chan, "\003")
  end
  current_chan = nil
  current_model = nil
  current_provider = nil
  is_waiting = false
end

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

providers.ollama = function(model)
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
        current_chan = nil
        current_model = nil
        current_provider = nil
        is_waiting = false
        notify("Ollama session exited", vim.log.levels.INFO)
      end,
    }
  )
end

providers.claude = function()
  return vim.fn.termopen(
    { "bash", "-c", "claude" },
    {
      buffer = chat_buf,
      on_exit = function()
        current_chan = nil
        current_model = nil
        current_provider = nil
        is_waiting = false
        notify("Claude session exited", vim.log.levels.INFO)
      end,
    }
  )
end

providers.claude_ollama = function(model)
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
        current_chan = nil
        current_model = nil
        current_provider = nil
        is_waiting = false
        notify("Claude (Ollama) session exited", vim.log.levels.INFO)
      end,
    }
  )
end

-- ==============================
-- CORE LAUNCH
-- ==============================

local function launch(provider, model)
  stop_current()

  local win = ensure_chat_vsplit()

  chat_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(chat_buf, "AI: " .. (model or provider))
  vim.api.nvim_win_set_buf(win, chat_buf)

  current_provider = provider
  current_model = model

  if provider == "ollama" then
    current_chan = providers.ollama(model)
  elseif provider == "claude" then
    current_chan = providers.claude()
  elseif provider == "claude_ollama" then
    current_chan = providers.claude_ollama(model)
  end

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

  -- ✅ FIX: ใส่ system prompt หลัง declare parts
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
    return notify(err or "OllamaAsk: missing prompt", vim.log.levels.ERROR)
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
    return notify(err or "OllamaCode: missing prompt", vim.log.levels.ERROR)
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

-- ==============================
-- USER COMMANDS
-- ==============================

vim.api.nvim_create_user_command(
  "OllamaAsk",
  function(opts) M.ask(opts) end,
  { nargs = "*", range = true }
)

vim.api.nvim_create_user_command(
  "OllamaCode",
  function(opts) M.code(opts) end,
  { nargs = "*", range = true }
)

vim.api.nvim_create_user_command("OllamaChat1", function() M.chat1() end, {})
vim.api.nvim_create_user_command("OllamaChat2", function() M.chat2() end, {})
vim.api.nvim_create_user_command("OllamaChat3", function() M.chat3() end, {})
vim.api.nvim_create_user_command("OllamaChat4", function() M.chat4() end, {})
vim.api.nvim_create_user_command("OllamaStop", function() M.stop() end, {})

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
end, { desc = "Claude via Ollama (qwen3-coder-next:cloud)" })

vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { silent = true })

return M
