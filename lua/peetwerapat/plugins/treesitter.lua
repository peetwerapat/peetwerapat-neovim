return {
  "nvim-treesitter/nvim-treesitter",
  lazy = false,
  build = ":TSUpdate",
  dependencies = {
    "windwp/nvim-ts-autotag",
  },

  config = function()
    require("nvim-treesitter.config").setup({
      parser_install_dir = vim.fn.stdpath("data") .. "/site",

      ensure_installed = {
        "lua",
        "vim",
        "vimdoc",
        "query",
        "javascript",
        "typescript",
        "tsx",
        "html",
        "css",
        "json",
        "yaml",
        "go",
        "markdown",
        "markdown_inline",
      },

      highlight = { enable = true },
      indent = { enable = true },
    })

    require("nvim-ts-autotag").setup({})
  end,
}
