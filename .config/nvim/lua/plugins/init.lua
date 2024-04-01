return {
  -- Delete buffers without closing the window they're in.
  "famiu/bufdelete.nvim",

  --
  {
    "saecki/crates.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require('crates').setup()
    end,
  },

  -- Bufferline
  {
    "noib3/nvim-cokeline",
    requires = { "kyazdani42/nvim-web-devicons" },
    config = function()
      require("plug-config/cokeline")
    end,
  },

  -- Useful plugin to show you pending keybinds.
  {
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    config = function() -- This is the function that runs, AFTER loading
      require('which-key').setup()

      -- Document existing key chains
      require('which-key').register {
        ['<leader>c'] = { name = '[C]ode', _ = 'which_key_ignore' },
        ['<leader>d'] = { name = '[D]ocument', _ = 'which_key_ignore' },
        ['<leader>r'] = { name = '[R]ename', _ = 'which_key_ignore' },
        ['<leader>s'] = { name = '[S]earch', _ = 'which_key_ignore' },
        ['<leader>w'] = { name = '[W]orkspace', _ = 'which_key_ignore' },
      }
    end,
  },

  -- Highlights hex-formatted color strings in the color they represent.
  {
    "norcalli/nvim-colorizer.lua",
    config = function()
      require("colorizer").setup(
        { "*" },
        { names = false }
      )
    end
  },

  -- Qutebrowser-like buffer navigation.
  {
    "phaazon/hop.nvim",
    branch = "v2",
    config = function()
      require("hop").setup({})
      vim.keymap.set("n", "f", "<Cmd>HopWord<CR>")
    end,
  },

  -- Reopen files at the last edit position.
  {
    "ethanholz/nvim-lastplace",
    config = function()
      require("nvim-lastplace").setup({})
    end,
  },

  -- Default configs for many LSPs.
  "neovim/nvim-lspconfig",

  -- Telescope.
  {
    "nvim-telescope/telescope.nvim",
    enabled = true,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
      },
    },
    config = function()
      local project_dir = function()
        local is_under_git = vim.fn.system("git status"):find("fatal") ~= nil
        if is_under_git then
          return vim.fn.systemlist("git rev-parse --show-toplevel")[1]
        else
          return vim.fn.expand("%:p:h")
        end
      end

      local ts = require("telescope")

      local builtin = require("telescope.builtin")

      ts.setup({
        defaults = {
          sorting_strategy = "ascending",
          layout_config = {
            prompt_position = "top",
            horizontal = {
              width_padding = 0.04,
              height_padding = 0.1,
              preview_width = 0.6,
            },
            vertical = {
              width_padding = 0.05,
              height_padding = 1,
              preview_height = 0.5,
            },
          },
        },
      })

      ts.load_extension("fzf")

      vim.keymap.set('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
      vim.keymap.set('n', '<leader>f', builtin.find_files, { desc = '[S]earch [F]iles' })
      vim.keymap.set('n', '<leader>ss', builtin.builtin, { desc = '[S]earch [S]elect Telescope' })
      vim.keymap.set('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
      vim.keymap.set('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
      vim.keymap.set('n', '<leader>sd', builtin.diagnostics, { desc = '[S]earch [D]iagnostics' })
      vim.keymap.set('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
      vim.keymap.set('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
      vim.keymap.set('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })
    end,
  },

  -- Dracula colorscheme.
  {
    'Mofiqul/dracula.nvim',
    lazy = false,
    priority = 1000,
    config = function()
      local dracula = require "dracula"

      dracula.setup({
        transparent = true,
        plugins = {
          ["nvim-treesitter"] = true,
          ["nvim-lspconfig"] = true,
          -- ["nvim-tree.lua"] = true,
          ["lazy.nvim"] = true,
          ["telescope.nvim"] = true,
        },
      })
      vim.cmd.colorscheme 'dracula'
      -- vim.cmd.colorscheme 'dracula-soft'
    end
  },

  {
    "nvim-treesitter/nvim-treesitter",
    dependencies = {
      "nvim-treesitter/playground",
      "JoosepAlviste/nvim-ts-context-commentstring",
      "RRethy/nvim-treesitter-endwise",
    },
    config = function()
      require("nvim-treesitter/configs").setup({
        ensure_installed = "all",
        context_commentstring = {
          enable = true,
        },
        endwise = {
          enable = true,
        },
        highlight = {
          enable = true,
        },
        playground = {
          enable = true
        },
      })
    end
  },
}
