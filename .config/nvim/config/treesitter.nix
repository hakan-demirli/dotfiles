{
  plugins.treesitter = {
    enable = true;
    folding = false;
    nixvimInjections = true;
    settings = {
      incremental_selection = {
        enable = true;
        keymaps = {
          # init_selection = "<cr>"; # Press <Enter> to start selecting the node under the cursor
          node_incremental = "+";
          scope_incremental = "g;";
          node_decremental = "-";
        };
      };
      indent.enable = true;
    };
  };

  # Show code context, e.g. what function current line is under
  # plugins.treesitter-context = {
  #   enable = true;
  #   settings = {
  #     max_lines = 2;
  #     min_window_height = 100;
  #   };
  # };
}
