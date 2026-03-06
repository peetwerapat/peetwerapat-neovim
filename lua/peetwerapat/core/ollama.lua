local M = {}

-- ==============================
-- CONFIG
-- ==============================

local OLLAMA_HOST = vim.env.OLLAMA_HOST or "http://localhost:11434"

local MODELS = {
  ask    = vim.env.OLLAMA_MODEL_ASK or "phi3:mini",
  code   = vim.env.OLLAMA_MODEL_CODE or "qwen2.5-coder:3b",
  claude = "claude", -- CLI command
}

-- ==============================
-- STATE
-- ==============================

local current_chan = nil
local current_model = nil
local current_provider = nil

local chat_win = nil
local chat_buf = nil

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
end

-- ==============================
-- SPAWNERS
-- ==============================

local providers = {}

-- ---- OLLAMA ----
providers.ollama = function(model)
  return vim.fn.termopen(
    {
      "bash",
      "-c",
      string.format(
        "export OLLAMA_HOST=%s && ollama run %s",
        OLLAMA_HOST,
        model
      ),
    },
    {
      buffer = chat_buf,
      on_exit = function()
        current_chan = nil
        current_model = nil
        current_provider = nil
        vim.schedule(function()
          vim.notify("Ollama session exited", vim.log.levels.INFO)
        end)
      end,
    }
  )
end

-- ---- CLAUDE ----
providers.claude = function()
  return vim.fn.termopen(
    { "bash", "-c", "claude" },
    {
      buffer = chat_buf,
      on_exit = function()
        current_chan = nil
        current_model = nil
        current_provider = nil
        vim.schedule(function()
          vim.notify("Claude session exited", vim.log.levels.INFO)
        end)
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

  if selection ~= "" then
    return "Code:\n" .. selection .. "\n\nTask:\n" .. input
  end

  return input
end

-- ==============================
-- COMMANDS
-- ==============================

function M.ask(opts)
  local prompt = build_prompt(opts)
  if not prompt then
    return vim.notify("OllamaAsk: missing prompt", vim.log.levels.ERROR)
  end

  if not chan_valid(current_chan)
      or current_model ~= MODELS.ask
  then
    launch("ollama", MODELS.ask)
  end

  vim.defer_fn(function()
    if chan_valid(current_chan) then
      vim.fn.chansend(current_chan, prompt .. "\n")
    end
  end, 50)
end

function M.code(opts)
  local prompt = build_prompt(opts)
  if not prompt then
    return vim.notify("OllamaCode: missing prompt", vim.log.levels.ERROR)
  end

  if not chan_valid(current_chan)
      or current_model ~= MODELS.code
  then
    launch("ollama", MODELS.code)
  end

  vim.defer_fn(function()
    if chan_valid(current_chan) then
      vim.fn.chansend(current_chan, prompt .. "\n")
    end
  end, 50)
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

function M.stop()
  if chan_valid(current_chan) then
    stop_current()
    vim.notify("AI stopped", vim.log.levels.INFO)
  else
    vim.notify("No AI session running", vim.log.levels.WARN)
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
vim.api.nvim_create_user_command("OllamaStop", function() M.stop() end, {})

-- ==============================
-- KEYMAPS
-- ==============================

vim.keymap.set("n", "<leader>ac1", function()
  M.chat1()
end, { desc = "AI Chat (phi3)" })

vim.keymap.set("n", "<leader>ac2", function()
  M.chat2()
end, { desc = "AI Chat (qwen coder)" })

vim.keymap.set("n", "<leader>ac3", function()
  M.chat3()
end, { desc = "Claude CLI Chat" })

vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { silent = true })

return M
