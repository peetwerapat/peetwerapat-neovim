return {
  "nvimtools/none-ls.nvim",
  dependencies = {
    "nvimtools/none-ls-extras.nvim",
  },
  config = function()
    local null_ls = require("null-ls")
    null_ls.setup({
      sources = {
        require("none-ls.diagnostics.eslint_d"),
        require("none-ls.formatting.eslint_d"),
        null_ls.builtins.formatting.goimports,
        null_ls.builtins.diagnostics.golangci_lint
      },
    })
  end,
}
