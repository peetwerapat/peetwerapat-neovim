return {
  "hrsh7th/nvim-cmp",
  event = "InsertEnter",
  dependencies = {
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-buffer",
    { "hrsh7th/cmp-cmdline", event = "CmdlineEnter" },

    -- Snippets
    {
      "L3MON4D3/LuaSnip",
      dependencies = { "rafamadriz/friendly-snippets" },
      opts = {},
    },
    "saadparwaiz1/cmp_luasnip",

    -- Autopairs
    "windwp/nvim-autopairs",
  },

  config = function()
    local cmp = require("cmp")
    local luasnip = require("luasnip")

    -- Load VSCode snippets
    require("luasnip.loaders.from_vscode").lazy_load()

    local kind_icons = {
      Text = "",
      Method = "󰆧",
      Function = "󰊕",
      Constructor = "",
      Field = "󰇽",
      Variable = "󰂡",
      Class = "󰠱",
      Interface = "",
      Module = "",
      Property = "󰜢",
      Unit = "",
      Value = "󰎠",
      Enum = "",
      Keyword = "󰌋",
      Snippet = "",
      Color = "󰏘",
      File = "󰈙",
      Reference = "",
      Folder = "󰉋",
      EnumMember = "",
      Constant = "󰏿",
      Struct = "󰙅",
      Event = "",
      Operator = "󰆕",
      TypeParameter = "󰅲",
    }

    cmp.setup({
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },

      mapping = cmp.mapping.preset.insert({
        ["<Tab>"] = function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          else
            fallback()
          end
        end,

        ["<S-Tab>"] = function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end,

        ["<CR>"] = cmp.mapping.confirm({ select = true }),
        ["<C-e>"] = cmp.mapping.abort(),
        ["<Esc>"] = cmp.mapping.close(),
        ["<C-d>"] = cmp.mapping.scroll_docs(-4),
        ["<C-f>"] = cmp.mapping.scroll_docs(4),
      }),

      sources = {
        { name = "nvim_lsp" },
        { name = "luasnip" },
        { name = "path" },
        { name = "buffer", keyword_length = 2 },
      },

      completion = {
        keyword_length = 1,
        completeopt = "menu,noselect",
      },

      formatting = {
        format = function(entry, vim_item)
          vim_item.kind = string.format(
            "%s %s",
            kind_icons[vim_item.kind] or "",
            vim_item.kind
          )
          vim_item.menu = ({
            nvim_lsp = "[LSP]",
            luasnip = "[SNIP]",
            buffer = "[BUF]",
            path = "[PATH]",
          })[entry.source.name]
          return vim_item
        end,
      },
    })

    -- Filetype specific
    cmp.setup.filetype("tex", {
      sources = {
        { name = "luasnip" },
        { name = "buffer", keyword_length = 2 },
        { name = "path" },
      },
    })

    -- Cmdline
    cmp.setup.cmdline("/", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = { { name = "buffer" } },
    })

    cmp.setup.cmdline(":", {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources(
        { { name = "path" } },
        { { name = "cmdline" } }
      ),
    })

    -- Highlight
    vim.cmd([[
      highlight! link CmpItemMenu Comment
      highlight! CmpItemAbbrDeprecated gui=strikethrough guifg=#808080
      highlight! CmpItemAbbrMatch guifg=#569CD6
      highlight! CmpItemAbbrMatchFuzzy guifg=#569CD6
    ]])

    -- autopairs integration
    local cmp_autopairs = require("nvim-autopairs.completion.cmp")
    cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
  end,
}
