local has_telescope, telescope = pcall("telescope")
local has_cokeline, _ = pcall("cokeline")

vim.g.mapleader = " "

--- Closes a window or deletes a buffer or closes Neovim, in that order.
local close_ctx = function()
  vim.cmd("q")
end

local keymaps = {
  --[[normal keymaps]]--
  -- Move line with cursor up
  {mode = "n",          lhs = "K", rhs = 'ddkP'},
  -- Move line with cursor down
  {mode = "n",          lhs = "J", rhs = 'ddjP'},
  -- Redo
  {mode = "n",          lhs = "U", rhs = '<C-r>'},
  -- TODO: fix
  -- {mode = "n",          lhs = "<C-c>", rhs = '<cmd>CommentToggle<CR>'},

  --[[g (goto) menu]]--
  -- Jump to the first non-whitespace character in the displayed line.
  {mode = { "n", "v" }, lhs = "gs", rhs = "g^"},
  -- Jump to the end of the displayed line.
  {mode = { "n", "v" }, lhs = "gl", rhs = "g$"},
  -- Jump to the beginning of the displayed line.
  {mode = { "n", "v" }, lhs = "gh", rhs = "0"},
  -- Jump to the end of the file.
  {mode = { "n", "v" }, lhs = "ge", rhs = "G"},
  {mode = "n",          lhs = "gd", rhs = vim.lsp.buf.definition},
  {mode = "n",          lhs = "gt", rhs = vim.lsp.buf.type_definition},

  --[[leader (space) menu]]--
  {mode = "n", lhs = "<leader>r", rhs = vim.lsp.buf.rename},
  {mode = "n", lhs = "<leader>a", rhs = vim.lsp.buf.code_action},
  {mode = "n", lhs = "<leader>k", rhs = vim.lsp.buf.hover},



  -- Toggle Nvimtree
  {
    mode = { "n" },
    lhs = "<C-n>",
    rhs = ":NvimTreeToggle<CR>",
  },
  -- -- Disable "s".
  -- {
  --   mode = { "n", "v" },
  --   lhs = "s",
  --   rhs = "",
  -- },

  -- -- Close the current context.
  -- {
  --   mode = "n",
  --   lhs = "<C-w>",
  --   rhs = close_ctx,
  -- },


  -- Move between displayed lines instead of logical ones, taking count of
  -- soft wrapping.
  {
    mode = { "n", "v" },
    lhs = "<Up>",
    rhs = "g<Up>",
    opts = {
      noremap = true,
    },
  },
  {
    mode = { "n", "v" },
    lhs = "<Down>",
    rhs = "g<Down>",
    opts = {
      noremap = true,
    },
  },
  {
    mode = "i",
    lhs = "<Up>",
    rhs = "<C-o>g<Up>",
    opts = {
      noremap = true,
    },
  },
  {
    mode = "i",
    lhs = "<Down>",
    rhs = "<C-o>g<Down>",
    opts = {
      noremap = true,
    },
  },

  -- Navigate window splits.
  {
    mode = "n",
    lhs = "<S-Up>",
    rhs = "<C-w>k",
    opts = {
      noremap = true,
    },
  },
  {
    mode = "n",
    lhs = "<S-Down>",
    rhs = "<C-w>j",
    opts = {
      noremap = true,
    },
  },
  {
    mode = "n",
    lhs = "<S-Left>",
    rhs = "<C-w>h",
    opts = {
      noremap = true,
    },
  },
  {
    mode = "n",
    lhs = "<S-Right>",
    rhs = "<C-w>l",
    opts = {
      noremap = true,
    },
  },

  -- Delete the previous word in insert mode.
  {
    mode = "n",
    lhs = "<M-BS>",
    rhs = "<C-w>",
    opts = {
      noremap = true,
    },
  },

  -- Substitute globally and in the visually selected region.
  {
    mode = "n",
    lhs = "ss",
    rhs = ":%s///g<Left><Left><Left>",
  },
  {
    mode = "v",
    lhs = "ss",
    rhs = ":s///g<Left><Left><Left>",
  },

  -- Display the diagnostics in a floating window.
  {
    mode = "n",
    lhs = "?",
    rhs = vim.diagnostic.open_float,
  },

  -- Navigate to the next/previous diagnostic
  {
    mode = "n",
    lhs = "dn",
    rhs = vim.diagnostic.goto_next,
  },
  {
    mode = "n",
    lhs = "dp",
    rhs = vim.diagnostic.goto_prev,
  },


}

if has_telescope then
  local project_dir = function()
    local is_under_git = vim.fn.system("git status"):find("fatal") ~= nil
    if is_under_git then
      return vim.fn.systemlist("git rev-parse --show-toplevel")[0]
    else
      return vim.fn.expand("%:p:h")
    end
  end

  table.insert(keymaps, {})
end

if has_cokeline then
    keymap.set("n", "<Tab>", "<Plug>(cokeline-focus-next)")
    keymap.set("n", "<S-Tab>", "<Plug>(cokeline-focus-prev)")
    keymap.set("n", "<Leader>p", "<Plug>(cokeline-switch-prev)")
    keymap.set("n", "<Leader>n", "<Plug>(cokeline-switch-next)")
    keymap.set("n", "<Leader>a", "<Plug>(cokeline-pick-focus)")
    keymap.set("n", "<Leader>b", "<Plug>(cokeline-pick-close)")
    for i = 1, 9 do
      keymap.set(
        "n",
        ("<F%s>"):format(i),
        ("<Plug>(cokeline-focus-%s)"):format(i)
      )
    end
end
return keymaps
