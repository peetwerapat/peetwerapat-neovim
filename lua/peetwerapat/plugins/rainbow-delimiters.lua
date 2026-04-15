return {
  "HiPhish/rainbow-delimiters.nvim",
  event = "BufReadPost",
  config = function()
    vim.g.rainbow_delimiters = {
      strategy = {
        [""] = function(bufnr)
          local ft = vim.bo[bufnr].filetype
          local bt = vim.bo[bufnr].buftype

          if ft == "toggleterm" or ft == "NvimTree" then
            return nil
          end

          if bt == "terminal" or bt == "nofile" or bt == "prompt" or bt == "help" then
            return nil
          end

          return "rainbow-delimiters.strategy.global"
        end,
      },
      query = {
        [""] = "rainbow-delimiters",
        lua = "rainbow-blocks",
      },
      highlight = {
        "RainbowDelimiterRed",
        "RainbowDelimiterYellow",
        "RainbowDelimiterBlue",
        "RainbowDelimiterOrange",
        "RainbowDelimiterGreen",
        "RainbowDelimiterViolet",
        "RainbowDelimiterCyan",
      },
    }
  end,
}
