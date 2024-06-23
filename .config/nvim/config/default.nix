{
  imports = [
    ./bufferline.nix
    ./telescope.nix
    # ./harpoon.nix
    # ./treesitter.nix
    ./whichkey.nix
  ];

  colorschemes.dracula.enable = true;

  globals.mapleader = " "; # Sets the leader key to comma

  opts = {
    number = true; # Show line numbers
    relativenumber = true; # Show relative line numbers

    shiftwidth = 2; # Tab width should be 2
  };

  keymaps = [
    {
      mode = "v";
      key = "<leader>p";
      action = "\"_dP";
      options.desc = "paste and keep content";
    }

    {
      mode = "n"; # also for v
      key = "<leader>y";
      action = "\"+y";
      options.desc = "yank to clipboard";
    }
    {
      mode = "n"; # also for v
      key = "<leader>Y";
      action = "\"+Y";
      options.desc = "yank to clipboard";
    }
  ];
}
