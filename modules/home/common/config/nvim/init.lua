vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.filetype.add({
  extension = {
    v = "verilog",
    vh = "verilog",
    sv = "systemverilog",
    svh = "systemverilog",
  },
})

local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.softtabstop = 4
opt.smartindent = true
opt.termguicolors = true
opt.background = "dark"
opt.ignorecase = true
opt.smartcase = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.colorcolumn = "80"
opt.signcolumn = "yes"
opt.splitbelow = true
opt.splitright = true
opt.undofile = true
opt.updatetime = 250
opt.timeoutlen = 500
opt.laststatus = 3
opt.showmode = false
opt.completeopt = { "menuone", "noselect", "popup" }
opt.grepprg = "rg --vimgrep --smart-case"
opt.grepformat = "%f:%l:%c:%m"
opt.list = true
opt.listchars = {
  tab = "> ",
  trail = ".",
  extends = ">",
  precedes = "<",
}

vim.cmd.colorscheme("dracula")

local mode_names = {
  n = "NORMAL",
  no = "NORMAL",
  nov = "NORMAL",
  noV = "NORMAL",
  ["no\22"] = "NORMAL",
  niI = "NORMAL",
  niR = "NORMAL",
  niV = "NORMAL",
  nt = "NORMAL",
  v = "SELECT",
  V = "SELECT",
  ["\22"] = "SELECT",
  s = "SELECT",
  S = "SELECT",
  ["\19"] = "SELECT",
  i = "INSERT",
  ic = "INSERT",
  ix = "INSERT",
  R = "REPLACE",
  Rc = "REPLACE",
  Rx = "REPLACE",
  Rv = "REPLACE",
  Rvc = "REPLACE",
  Rvx = "REPLACE",
  c = "COMMAND",
  cv = "COMMAND",
  ce = "COMMAND",
  r = "PROMPT",
  rm = "MORE",
  ["r?"] = "CONFIRM",
  t = "TERMINAL",
}

function _G.dotfiles_status_mode()
  local mode = vim.fn.mode(1)
  return mode_names[mode] or mode:upper()
end

-- tmux_harpoon_{add,update}.sh parse this mode/path/line format.
vim.o.statusline = " %{v:lua.dotfiles_status_mode()} %f %m %= %l:%c "

local map = vim.keymap.set

map("n", "<C-s>", "<cmd>write<cr>", { desc = "Write buffer" })
map("n", "<leader>e", "<cmd>Explore<cr>", { desc = "File explorer" })
map("n", "<leader>f", ":find ", { desc = "Find file" })
map("n", "<leader>b", ":buffer ", { desc = "Select buffer" })
map("n", "<leader>/", ":grep ", { desc = "Grep workspace" })
map("n", "<leader>=", function()
  vim.lsp.buf.format({ async = false })
end, { desc = "Format buffer" })

local function update_tmux_harpoon()
  if vim.env.TMUX and vim.fn.executable("tmux_harpoon_update.sh") == 1 then
    vim.fn.jobstart({ "tmux_harpoon_update.sh" }, { detach = true })
  end
end

map("n", "gn", function()
  update_tmux_harpoon()
  vim.cmd.bnext()
end, { desc = "Next buffer" })

map("n", "gp", function()
  update_tmux_harpoon()
  vim.cmd.bprevious()
end, { desc = "Previous buffer" })

map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gy", vim.lsp.buf.type_definition, { desc = "Go to type definition" })
map("n", "gr", vim.lsp.buf.references, { desc = "Go to references" })
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })

map("i", "<Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true, desc = "Next completion" })
map("i", "<S-Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true, desc = "Previous completion" })
map("i", "<CR>", function()
  return vim.fn.pumvisible() == 1 and "<C-y>" or "<CR>"
end, { expr = true, desc = "Accept completion" })

vim.diagnostic.config({
  severity_sort = true,
  virtual_text = true,
  float = { border = "rounded" },
})

local lsp_group = vim.api.nvim_create_augroup("dotfiles.lsp", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
  group = lsp_group,
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method("textDocument/completion") then
      vim.lsp.completion.enable(true, client.id, event.buf, { autotrigger = true })
    end
  end,
})

vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--all-scopes-completion",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
    "--function-arg-placeholders",
    "--pch-storage=memory",
    "--offset-encoding=utf-8",
    "--fallback-style=LLVM",
    "--compile-commands-dir=build",
  },
})

vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = {
      check = {
        command = "clippy",
      },
    },
  },
})

local wanted_lsps = {
  "asm_lsp",
  "bashls",
  "clangd",
  "cmake",
  "cssls",
  "html",
  "jsonls",
  "lua_ls",
  "marksman",
  "nixd",
  "pyright",
  "ruff",
  "rust_analyzer",
  "taplo",
  "texlab",
  "verible",
  "yamlls",
}

vim.api.nvim_create_autocmd("VimEnter", {
  group = lsp_group,
  once = true,
  callback = function()
    local enabled = {}

    for _, name in ipairs(wanted_lsps) do
      local config = vim.lsp.config[name]
      local command = config and config.cmd
      if type(command) == "table" and vim.fn.executable(command[1]) == 1 then
        enabled[#enabled + 1] = name
      end
    end

    if #enabled > 0 then
      vim.lsp.enable(enabled)
    end
  end,
})

local todo_file = vim.env.NVIM_TODO_PATH or vim.fn.expand("~/Desktop/infra/state/scratchpads/todo.md")
local todo_path = vim.uv.fs_realpath(todo_file)

vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("dotfiles.todo-limit", { clear = true }),
  callback = function(event)
    local path = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(event.buf))
    if not todo_path or path ~= todo_path then
      return
    end

    local lines = vim.api.nvim_buf_get_lines(event.buf, 0, -1, false)
    if #lines > 10 then
      error(("todo.md has %d lines; maximum is 10"):format(#lines), 0)
    end

    for line_number, line in ipairs(lines) do
      local length = vim.fn.strchars(line)
      if length > 100 then
        error(("todo.md line %d has %d characters; maximum is 100"):format(line_number, length), 0)
      end
    end
  end,
})
