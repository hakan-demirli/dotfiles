local has_lspconfig, lspconfig = pcall(require, "lspconfig")

-- If `https://github.com/neovim/nvim-lspconfig` is not available we return
-- early.
if not has_lspconfig then
  return
end

local api = vim.api
local keymap = vim.keymap
local lsp = vim.lsp

local lsp_augroup_id = api.nvim_create_augroup("Lsp", {})

local on_attach = function(_ --[[ client ]], bufnr)
  local opts = { buffer = bufnr }

  -- All keymaps are set in keymaps.lua

  -- Display infos about the symbol under the cursor in a floating window.
  -- keymap.set("n", "K", lsp.buf.hover, opts)

  -- Rename the symbol under the cursor.
  -- keymap.set("n", "rn", lsp.buf.rename, opts)

  -- Selects a code action available at the current cursor position.
  -- keymap.set("n", "ca", lsp.buf.code_action, opts)

  -- Jumps to the definition of the symbol under the cursor.
  -- keymap.set("n", "gd", lsp.buf.definition, opts)

  -- Jumps to the definition of the type of the symbol under the cursor.
  -- keymap.set("n", "gtd", lsp.buf.type_definition, opts)

  -- Format buffer on save w/ a 1s timeout.
  api.nvim_create_autocmd(
    "BufWritePre",
    {
      group = lsp_augroup_id,
      buffer = bufnr,
      desc = "Formats the buffer before saving it to disk",
      callback = function() lsp.buf.format({}, 100) end,
    }
  )
end

-- Lua -> https://github.com/sumneko/lua-language-server
local rtp = vim.split(package.path, ";")
table.insert(rtp, "lua/?.lua")
table.insert(rtp, "lua/?/init.lua")

lspconfig.lua_ls.setup({
  on_attach = on_attach,
  settings = {
    ["Lua"] = {
      runtime = {
        version = "LuaJIT",
        path = rtp,
      },
      diagnostics = {
        globals = { "vim" }
      },
      workspace = {
        library = api.nvim_get_runtime_file("", true),
      },
      telemetry = {
        enable = false,
      },
    },
  }
})

-- Nix -> https://github.com/nix-community/nixd
lspconfig.nixd.setup({
  on_attach = on_attach,
})

-- Python -> https://github.com/microsoft/pyright
lspconfig.pyright.setup({
  on_attach = on_attach,
})
-- Python -> https://github.com/astral-sh/ruff-lsp
lspconfig.ruff_lsp.setup({
  on_attach = on_attach,
})

-- Rust -> https://github.com/rust-lang/rust-analyzer
lspconfig.rust_analyzer.setup({
  on_attach = on_attach,
  settings = {
    ["rust-analyzer"] = {
      -- checkOnSave = { command = "clippy" },
      procMacro = { enable = true },
    }
  }
})

-- Scala -> https://github.com/scalameta/metals
lspconfig.metals.setup({
  on_attach = on_attach
})
