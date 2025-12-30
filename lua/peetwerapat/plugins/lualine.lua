return {
  "nvim-lualine/lualine.nvim",
  event = "BufReadPre",

  config = function()
    local ok, lualine = pcall(require, "lualine")
    if not ok then
      return
    end

    -- =========================
    -- Custom theme
    -- =========================
    local cyberdream_bright_blue = {
      normal = {
        a = { fg = "#0f0f0f", bg = "#00bfff", gui = "bold" },
        b = { fg = "#c0c0c0", bg = "#005f87" },
        c = { fg = "#b3b3b3", bg = "#1a1a1a" },
      },
      insert = {
        a = { fg = "#0f0f0f", bg = "#40e0d0", gui = "bold" },
        b = { fg = "#c0c0c0", bg = "#008080" },
        c = { fg = "#b3b3b3", bg = "#1a1a1a" },
      },
      visual = {
        a = { fg = "#0f0f0f", bg = "#00ced1", gui = "bold" },
        b = { fg = "#c0c0c0", bg = "#006666" },
        c = { fg = "#b3b3b3", bg = "#1a1a1a" },
      },
      replace = {
        a = { fg = "#0f0f0f", bg = "#1e90ff", gui = "bold" },
        b = { fg = "#c0c0c0", bg = "#004080" },
        c = { fg = "#b3b3b3", bg = "#1a1a1a" },
      },
      command = {
        a = { fg = "#0f0f0f", bg = "#00bfff", gui = "bold" },
        b = { fg = "#c0c0c0", bg = "#005f87" },
        c = { fg = "#b3b3b3", bg = "#1a1a1a" },
      },
    }

    lualine.setup({
      options = {
        icons_enabled = true,
        theme = cyberdream_bright_blue,
        component_separators = { left = "|", right = "|" },
        section_separators = "",
      },

      sections = {
        lualine_a = {
          { "mode", icon = "" },
        },
        lualine_b = {
          { "branch", icon = "" },
          "diff",
        },
        lualine_c = {
          {
            "filename",
            path = 1,
            symbols = {
              modified = "[+]",
              readonly = "[🔒]",
              unnamed = "[No Name]",
            },
          },
        },
        lualine_x = {
          {
            "diagnostics",
            sources = { "nvim_diagnostic" },
            symbols = {
              error = "🆇 ",
              warn = "⚠️ ",
              info = "ℹ️ ",
              hint = " ",
            },
          },
          {
            function()
              local clients = vim.lsp.get_clients({ bufnr = 0 })
              if not clients or vim.tbl_isempty(clients) then
                return "🚫"
              end
              return "  " .. clients[1].name
            end,
          },
        },
        lualine_y = { "filetype" },
        lualine_z = { "location", "progress" },
      },

      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "location" },
        lualine_y = {},
        lualine_z = {},
      },

      extensions = { "quickfix", "fugitive", "nvim-tree" },
    })
  end,
}
