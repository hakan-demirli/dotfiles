{
  plugins.treesitter = {
    enable = true;
    folding = false;
    nixvimInjections = true;
    settings = {
      incremental_selection = {
        enable = true;
        keymaps = {
          node_incremental = "+";
          scope_incremental = "g;";
          node_decremental = "-";
        };
      };
      indent.enable = true;
    };
  };
}
