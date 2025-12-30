return {
  "scottmckendry/cyberdream.nvim",
  priority = 1000,
  config = function()
    vim.cmd("colorscheme cyberdream")

    local black_bg = { bg = "#000000" }

    -- Main UI
    vim.api.nvim_set_hl(0, "Normal", black_bg)
    vim.api.nvim_set_hl(0, "NormalNC", black_bg)
    vim.api.nvim_set_hl(0, "VertSplit", black_bg)
    vim.api.nvim_set_hl(0, "StatusLine", black_bg)
    vim.api.nvim_set_hl(0, "SignColumn", black_bg)
    vim.api.nvim_set_hl(0, "EndOfBuffer", black_bg)
    vim.api.nvim_set_hl(0, "LineNr", black_bg)
    vim.api.nvim_set_hl(0, "FoldColumn", black_bg)

    vim.api.nvim_set_hl(0, "YankColor", {
      fg = "#34495E",
      bg = "#2ECC71",
      ctermfg = 59,
      ctermbg = 41,
    })

    vim.api.nvim_create_autocmd("TextYankPost", {
      callback = function()
        vim.highlight.on_yank({
          higroup = "YankColor",
          timeout = 200,
        })
      end,
    })

    vim.api.nvim_set_hl(0, "DashboardHeader", { fg = "#1e90ff", bold = true })
    vim.api.nvim_set_hl(0, "DashboardFooter", { fg = "#ffcba4", italic = true })

    vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#3c3836' })

    vim.api.nvim_create_autocmd("FileType", {
      callback = function()
        pcall(vim.treesitter.start)
      end,
    })
  end,
}
