return {
  "akinsho/toggleterm.nvim",
  cmd = "ToggleTerm",
  opts = {},

  config = function(_, opts)
    require("toggleterm").setup(opts)

    vim.keymap.set("n", "<leader>tt", "<cmd>ToggleTerm<CR>")

    vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], {
      silent = true,
    })
  end,
}
