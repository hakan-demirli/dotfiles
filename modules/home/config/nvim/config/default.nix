{ pkgs, ... }:
{
  extraPackages = [ pkgs.ripgrep ];
  imports = [
    ./bufferline.nix
    ./treesitter.nix
    ./whichkey.nix
    ./telescope.nix
    ./harpoon2.nix
    ./lsp.nix
    ./nvim-cmp.nix
    ./gitsigns.nix
    ./visuals.nix
    ./web-devicons.nix
  ];

  colorschemes.dracula.enable = true;

  globals.mapleader = " ";

  opts = {
    number = true;
    relativenumber = true;

    shiftwidth = 2;
  };

  keymaps = [
    {
      mode = "v";
      key = "<leader>p";
      action = "\"_dP";
      options.desc = "paste and keep content";
    }

    {
      mode = "n";
      key = "<leader>y";
      action = "\"+y";
      options.desc = "yank to clipboard";
    }
    {
      mode = "n";
      key = "<leader>Y";
      action = "\"+Y";
      options.desc = "yank to clipboard";
    }
    {
      mode = "n";
      key = "<leader>/";
      action.__raw = "liveGrepInProject()";
      options.desc = "Live grep in project";
    }
    {
      mode = "n";
      key = "gp";
      action = "<cmd>bprevious<cr>";
      options.desc = "Go to [p]revious buffer";
    }
    {
      mode = "n";
      key = "gn";
      action = "<cmd>bnext<cr>";
      options.desc = "Go to [n]ext buffer";
    }
  ];

  extraConfigLuaPre = ''
    function liveGrepInProject()
      return function()
        require("telescope.builtin").grep_string({
          path_display = { 'smart' },
          only_sort_text = true,
          word_match = "-w",
          search = "",
        })
      end
    end
  '';
}
