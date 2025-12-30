return {
  "gbprod/yanky.nvim",
  cmd = "YankyRingHistory",

  config = function()
    local ok, yanky = pcall(require, "yanky")
    if not ok then
      return
    end

    yanky.setup({
      preserve_cursor_position = {
        enabled = false,
      },
      highlight = {
        on_put = true,
        on_yank = true,
        timer = 300,
      },
    })
  end,
}
