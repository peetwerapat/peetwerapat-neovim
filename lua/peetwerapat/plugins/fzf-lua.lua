return {
  "ibhagwan/fzf-lua",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },
  keys = {
    { "<leader>ff", "<cmd>FzfLua files<CR>", desc = "Find files" },
  },
  config = function()
    require("fzf-lua").setup({})
  end,
}
