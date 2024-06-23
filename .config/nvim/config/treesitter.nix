{
  plugins.treesitter = {
    enable = true;
    folding = true;
    indent = true;
    nixvimInjections = true;
    incrementalSelection.enable = true;
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
