return {
  "akinsho/bufferline.nvim",
  event = "BufAdd",
  version = "*",

  config = function()
    local bufferline = require("bufferline")

    bufferline.setup({
      options = {
        diagnostics = "nvim_lsp",
        show_buffer_close_icons = false,
        custom_filter = function(buf)
          if vim.b[buf].ai_chat then
            return false
          end
          if vim.api.nvim_buf_get_name(buf) == "" and not vim.bo[buf].modified
              and vim.api.nvim_buf_line_count(buf) == 1
              and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == "" then
            return false
          end
          return true
        end,
      },
    })

    -- pick buffer
    vim.keymap.set("n", "<leader>bp", function()
      bufferline.pick_buffer()
    end, { desc = "Pick buffer" })

    -- delete other buffers
    vim.keymap.set("n", "<leader>bo", function()
      local current = vim.api.nvim_get_current_buf()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if buf ~= current
            and vim.api.nvim_buf_is_loaded(buf)
            and vim.bo[buf].buflisted
        then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
    end, { desc = "Delete other buffers" })
  end,
}
