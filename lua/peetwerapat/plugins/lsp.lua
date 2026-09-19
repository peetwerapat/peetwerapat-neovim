return {
  "neovim/nvim-lspconfig",
  event = { "BufReadPre", "BufNewFile" },

  dependencies = {
    "nvim-lua/plenary.nvim",
    "pmizio/typescript-tools.nvim",
    "mfussenegger/nvim-jdtls",
  },

  config = function()
    local typescript_tools = require("typescript-tools")
    local jdtls = require("jdtls")

    -- =========================
    -- Diagnostics UI (global)
    -- =========================
    vim.diagnostic.config({
      virtual_text = true,
      signs = true,
      underline = true,
      update_in_insert = false,
      severity_sort = true,
      float = {
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
      },
    })

    -- =========================
    -- Utils
    -- =========================
    local function executable(cmd)
      return vim.fn.executable(cmd) == 1
    end

    local function disable_formatting(client)
      if client.server_capabilities then
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
      end
    end

    -- =========================
    -- on_attach (shared)
    -- =========================
    local function on_attach(client, bufnr)
      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer = bufnr,
          silent = true,
          desc = desc,
        })
      end

      map("n", "gd", vim.lsp.buf.definition, "Go to definition")
      map("n", "<C-]>", vim.lsp.buf.definition, "Go to definition")
      map("n", "K", vim.lsp.buf.hover, "Hover")
      map("n", "<C-k>", vim.lsp.buf.signature_help, "Signature help")
      map("n", "<space>rn", vim.lsp.buf.rename, "Rename")
      map("n", "<space>ca", vim.lsp.buf.code_action, "Code action")

      map("n", "<leader>D", function()
        vim.diagnostic.open_float(nil, {
          focusable = false,
          border = "rounded",
          source = "always",
          scope = "cursor",
        })
      end, "Line diagnostics")

      -- document highlight
      if client.server_capabilities.documentHighlightProvider then
        local group =
            vim.api.nvim_create_augroup("lsp_document_highlight_" .. bufnr, { clear = true })

        vim.api.nvim_create_autocmd("CursorHold", {
          group = group,
          buffer = bufnr,
          callback = vim.lsp.buf.document_highlight,
        })

        vim.api.nvim_create_autocmd("CursorMoved", {
          group = group,
          buffer = bufnr,
          callback = vim.lsp.buf.clear_references,
        })
      end
    end

    -- =========================
    -- Capabilities (cmp)
    -- =========================
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    local ok, cmp_lsp = pcall(require, "cmp_nvim_lsp")
    if ok then
      capabilities = cmp_lsp.default_capabilities(capabilities)
    end

    -- =========================
    -- Generic LSP servers (NEW API)
    -- =========================
    local servers = {
      lua_ls = "lua-language-server",
      vimls = "vim-language-server",
      bashls = "bash-language-server",
    }

    for name, bin in pairs(servers) do
      if executable(bin) then
        vim.lsp.config(name, {
          capabilities = capabilities,
          on_attach = on_attach,
          root_dir = vim.fs.root(0, { ".git" }),
        })
        vim.lsp.enable(name)
      end
    end

    -- =========================
    -- TypeScript / JavaScript
    -- (the plugin still uses the old pattern)
    -- =========================
    if executable("node") then
      typescript_tools.setup({
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          disable_formatting(client)
          on_attach(client, bufnr)
        end,
        settings = {
          separate_diagnostic_server = true,
          publish_diagnostic_on = "insert_leave",
          expose_as_code_action = "all",
          tsserver_file_preferences = {
            includeInlayParameterNameHints = "all",
            includeInlayVariableTypeHints = true,
            includeInlayFunctionLikeReturnTypeHints = true,
            includeInlayEnumMemberValueHints = true,
          },
        },
      })
    end

    -- =========================
    -- Go (gopls)
    -- =========================
    if executable("gopls") then
      vim.lsp.config("gopls", {
        capabilities = capabilities,
        on_attach = function(client, bufnr)
          disable_formatting(client)
          on_attach(client, bufnr)
        end,
        settings = {
          gopls = {
            gofumpt = true,
            analyses = { unusedparams = true },
            staticcheck = true,
          },
        },
      })
      vim.lsp.enable("gopls")
    end

    -- =========================
    -- Java (jdtls) + Spring Boot
    -- IntelliJ IDEA formatter profile lives at <config>/Default.xml
    -- =========================
    local java_format_profile = vim.fn.stdpath("config") .. "/Default.xml"

    -- Pick the highest-version lombok jar from the local Maven repo so jdtls
    -- can see generated getters/setters/builders. Returns nil if none found.
    local function find_lombok_jar()
      local dir = vim.fn.expand("~/.m2/repository/org/projectlombok/lombok")
      if vim.fn.isdirectory(dir) == 0 then return nil end
      local jars = vim.fn.glob(dir .. "/*/lombok-*.jar", true, true)
      local candidates = {}
      for _, jar in ipairs(jars) do
        if not jar:match("%-sources%.jar$") and not jar:match("%-javadoc%.jar$") then
          table.insert(candidates, jar)
        end
      end
      if #candidates == 0 then return nil end
      table.sort(candidates)
      return candidates[#candidates]
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "java",
      callback = function(args)
        local root = vim.fs.root(0, {
          ".git", "pom.xml", "build.gradle", "build.gradle.kts", "mvnw", "gradlew",
        })
        if not root then return end

        -- IntelliJ defaults: 4-space indent, no tabs
        vim.bo[args.buf].tabstop = 4
        vim.bo[args.buf].shiftwidth = 4
        vim.bo[args.buf].softtabstop = 4
        vim.bo[args.buf].expandtab = true

        local project = vim.fn.fnamemodify(root, ":t")
        local workspace_dir = vim.fn.stdpath("data") .. "/java-workspace/" .. project
        vim.fn.mkdir(workspace_dir, "p")

        local cmd = { "jdtls", "-data", workspace_dir }
        local lombok_jar = find_lombok_jar()
        if lombok_jar then
          table.insert(cmd, "--jvm-arg=-javaagent:" .. lombok_jar)
        end

        jdtls.start_or_attach({
          cmd = cmd,
          root_dir = root,
          capabilities = capabilities,
          on_attach = function(client, bufnr)
            on_attach(client, bufnr)

            -- Format on save using jdtls (uses Default.xml profile below)
            local fmt_grp = vim.api.nvim_create_augroup(
              "jdtls_format_on_save_" .. bufnr, { clear = true }
            )
            vim.api.nvim_create_autocmd("BufWritePre", {
              group = fmt_grp,
              buffer = bufnr,
              callback = function()
                vim.lsp.buf.format({ async = false, id = client.id, timeout_ms = 3000 })
              end,
            })
          end,
          settings = {
            java = {
              format = {
                enabled = true,
                settings = {
                  url = java_format_profile,
                  profile = "Default",
                },
              },
              signatureHelp = { enabled = true },
              contentProvider = { preferred = "fernflower" },
              completion = {
                favoriteStaticMembers = {
                  "org.junit.jupiter.api.Assertions.*",
                  "org.junit.jupiter.api.Assumptions.*",
                  "org.mockito.Mockito.*",
                  "org.mockito.ArgumentMatchers.*",
                  "org.hamcrest.MatcherAssert.*",
                  "org.hamcrest.Matchers.*",
                  "org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*",
                  "org.springframework.test.web.servlet.result.MockMvcResultMatchers.*",
                  "org.springframework.test.web.servlet.result.MockMvcResultHandlers.*",
                },
                -- IntelliJ default import grouping
                importOrder = { "java", "javax", "jakarta", "org", "com", "" },
              },
              references = { includeAccessors = true },
              sources = {
                organizeImports = {
                  starThreshold = 99,
                  staticStarThreshold = 99,
                },
              },
              configuration = {
                updateBuildConfiguration = "interactive",
              },
              maven = { downloadSources = true },
              eclipse = { downloadSources = true },
            },
          },
          init_options = {
            extendedClientCapabilities = vim.tbl_deep_extend(
              "force",
              jdtls.extendedClientCapabilities or {},
              { resolveAdditionalTextEditsSupport = true }
            ),
          },
        })
      end,
    })
  end,
}
