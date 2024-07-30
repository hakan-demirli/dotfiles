{
  plugins.treesitter = {
    enable = true;
    folding = false;
    nixvimInjections = true;
    settings = {
      incremental_selection.enable = true;
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
