return {
  "ibhagwan/fzf-lua",
  cmd = "FzfLua",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },

  config = function()
    vim.keymap.set("n", "<leader>ff", "<cmd>FzfLua files<CR>")
  end,
}
