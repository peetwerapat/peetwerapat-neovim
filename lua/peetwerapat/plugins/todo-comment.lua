return {
  "folke/todo-comments.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    keywords = {
      TODO = {
        icon = " ",
        color = "#FF8C00",
      },
    },
    highlight = {
      before = "",
      keyword = "wide",
      after = "fg",
    },
  },
}
