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

-- ===== CHAT WINDOW (SAFE VSPLIT) =====
local function ensure_chat_vsplit()
  if chat_win and vim.api.nvim_win_is_valid(chat_win) then
    return chat_win
  end

  vim.cmd("vsplit")
  vim.cmd("wincmd l")
  vim.cmd("vertical resize 60")

  chat_win = vim.api.nvim_get_current_win()
  return chat_win
end


-- ===== CORE RUN =====
local function run_ollama(model, prompt, enter_terminal)
  local source_win = vim.api.nvim_get_current_win()
  local win = ensure_chat_vsplit()

  vim.api.nvim_set_current_win(win)

  if not current_chan then
    current_chan = vim.fn.termopen(
      {
        "bash", "-c",
        string.format(
          "export OLLAMA_HOST=%s && ollama run %s",
          OLLAMA_HOST,
          model
        )
      },
      { buffer = chat_buf }
    )
  end

  if prompt then
    vim.defer_fn(function()
      if current_chan then
        vim.fn.chansend(current_chan, prompt .. "\n")
      end
    end, 50)
  end

  if enter_terminal then
    vim.cmd("startinsert")
  else
    vim.api.nvim_set_current_win(source_win)
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
  run_ollama(MODELS.ask, prompt, false)
end

function M.code(opts)
  local prompt = build_prompt(opts)
  if not prompt then
    return vim.notify("OllamaCode: missing prompt", vim.log.levels.ERROR)
  end
  run_ollama(MODELS.code, prompt, false)
end

local function restart_with(model)
  if current_chan then
    vim.fn.chansend(current_chan, "\003")
    current_chan = nil
  end

  local win = ensure_chat_vsplit()

  chat_buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_name(chat_buf, "Ollama: " .. model)

  vim.api.nvim_win_set_buf(win, chat_buf)

  current_model = model

  current_chan = vim.fn.termopen(
    {
      "bash", "-c",
      string.format(
        "export OLLAMA_HOST=%s && ollama run %s",
        OLLAMA_HOST,
        model
      )
    },
    { buffer = chat_buf }
  )

  vim.cmd("startinsert")
end

function M.chat1()
  restart_with(MODELS.ask)
end

function M.chat2()
  restart_with(MODELS.code)
end

function M.stop()
  if current_chan then
    vim.fn.chansend(current_chan, "\003")
    current_chan = nil
    vim.notify("Ollama stopped (session reset)", vim.log.levels.INFO)
  else
    vim.notify("No Ollama session running", vim.log.levels.WARN)
  end
end

function M.get_current_model()
  return current_model
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
