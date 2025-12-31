local M = {}

-- ===== CONFIG =====
local OLLAMA_HOST = vim.env.OLLAMA_HOST or "http://localhost:11434"

local MODELS = {
  ask  = vim.env.OLLAMA_MODEL_ASK or "phi3:mini",
  code = vim.env.OLLAMA_MODEL_CODE or "qwen2.5-coder:3b",
}

-- ===== STATE =====
local current_chan = nil
local chat_win = nil
local chat_buf = nil
local current_model = nil

function M.get_current_model()
  return current_model
end

-- ===== CHAT WINDOW (SAFE VSPLIT) =====
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

-- ===== CHAN VALID =====
local function chan_valid(chan)
  if type(chan) ~= "number" then
    return false
  end

  local ok = pcall(vim.fn.chansend, chan, "")
  return ok
end

-- ===== SPAWN =====
local function spawn_ollama(model)
  return vim.fn.termopen(
    {
      "bash", "-c",
      string.format(
        "export OLLAMA_HOST=%s && ollama run %s",
        OLLAMA_HOST,
        model
      )
    },
    {
      buffer = chat_buf,
      on_exit = function()
        current_chan = nil
        current_model = nil
        vim.schedule(function()
          vim.notify("Ollama session exited", vim.log.levels.INFO)
        end)
      end,
    }
  )
end

-- ===== CORE RUN =====
local function run_ollama(model, prompt)
  local win = ensure_chat_vsplit()
  vim.api.nvim_set_current_win(win)

  if not chat_buf or not vim.api.nvim_buf_is_valid(chat_buf) then
    chat_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win, chat_buf)
  end

  if not chan_valid(current_chan) or current_model ~= model then
    if chan_valid(current_chan) then
      vim.fn.chansend(current_chan, "\003")
    end
    current_chan = spawn_ollama(model)
    current_model = model
  end

  if prompt then
    vim.defer_fn(function()
      if chan_valid(current_chan) then
        vim.fn.chansend(current_chan, prompt .. "\n")
      end
    end, 50)
  end

  vim.cmd("startinsert")
end

-- ===== RESTART =====
local function restart_with(model)
  if chan_valid(current_chan) then
    vim.fn.chansend(current_chan, "\003")
  end
  current_chan = nil

  local win = ensure_chat_vsplit()

  chat_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(chat_buf, "Ollama: " .. model)
  vim.api.nvim_win_set_buf(win, chat_buf)

  current_model = model
  current_chan = spawn_ollama(model)

  vim.cmd("startinsert")
end

-- ===== STOP =====
function M.stop()
  if chan_valid(current_chan) then
    vim.fn.chansend(current_chan, "\003")
    current_chan = nil
    vim.notify("Ollama stopped", vim.log.levels.INFO)
  else
    current_chan = nil
    vim.notify("No Ollama session running", vim.log.levels.WARN)
  end
end

-- ===== PROMPT =====
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

-- ===== COMMANDS =====
function M.ask(opts)
  local prompt = build_prompt(opts)
  if not prompt then
    return vim.notify("OllamaAsk: missing prompt", vim.log.levels.ERROR)
  end
  run_ollama(MODELS.ask, prompt)
end

function M.code(opts)
  local prompt = build_prompt(opts)
  if not prompt then
    return vim.notify("OllamaCode: missing prompt", vim.log.levels.ERROR)
  end
  run_ollama(MODELS.code, prompt)
end

function M.chat1()
  restart_with(MODELS.ask)
end

function M.chat2()
  restart_with(MODELS.code)
end

-- ===== REGISTER =====
vim.api.nvim_create_user_command("OllamaAsk", function(opts) M.ask(opts) end, { nargs = "*", range = true })
vim.api.nvim_create_user_command("OllamaCode", function(opts) M.code(opts) end, { nargs = "*", range = true })
vim.api.nvim_create_user_command("OllamaChat1", function() M.chat1() end, {})
vim.api.nvim_create_user_command("OllamaChat2", function() M.chat2() end, {})
vim.api.nvim_create_user_command("OllamaStop", function() M.stop() end, {})

-- ===== KEYMAPS =====
vim.keymap.set("n", "<leader>ac1", function()
  M.chat1()
end, { desc = "Ollama Chat (phi3)" })

vim.keymap.set("n", "<leader>ac2", function()
  M.chat2()
end, { desc = "Ollama Chat (qwen coder)" })

-- ===== TERMINAL UX =====
vim.keymap.set("t", "<Esc>", "<C-\\><C-n>", { silent = true })

return M
