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
