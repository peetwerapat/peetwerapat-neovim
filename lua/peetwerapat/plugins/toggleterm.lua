return {
  "akinsho/toggleterm.nvim",
  version = "*",
  keys = {
    { "<leader>tt", "<cmd>ToggleTerm<CR>", desc = "Toggle terminal", mode = "n" },
  },
  config = function()
    require("toggleterm").setup({
      open_mapping = nil,
      direction = "horizontal",
      size = 15,
    })

    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { silent = true })
  end,
}
