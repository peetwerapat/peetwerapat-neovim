return {
  "brenoprata10/nvim-highlight-colors",
  event = "BufReadPost",
  config = function()
    local ok, highlight_colors = pcall(require, "nvim-highlight-colors")
    if not ok then
      return
    end

    highlight_colors.setup({
      -- Render style: 'background' | 'foreground' | 'virtual'
      render = "background",

      -- Virtual text (used only if render = 'virtual')
      virtual_symbol = "■",
      virtual_symbol_prefix = "",
      virtual_symbol_suffix = " ",
      virtual_symbol_position = "inline", -- inline | eol | eow

      -- Color formats
      enable_hex = true,
      enable_short_hex = true,
      enable_rgb = true,
      enable_hsl = true,
      enable_hsl_without_function = false,
      enable_ansi = true,

      -- CSS / framework
      enable_var_usage = true,
      enable_named_colors = false,
      enable_tailwind = false,

      -- Exclude
      exclude_filetypes = {},
      exclude_buftypes = {},

      -- Skip very large files (prevent lag)
      exclude_buffer = function(bufnr)
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name == "" then
          return false
        end
        return vim.fn.getfsize(name) > 1 * 1024 * 1024 -- 1MB
      end,
    })
  end,
}
