{
  opts = {
    list = true;
    listchars = {
      tab = "» ";
      trail = "·";
      extends = "›";
      precedes = "‹";
      eol = "↩";
      space = "·";
    };
  };

  plugins.indent-blankline = {
    enable = true;
    settings = {
      indent = {
        char = "╎";
      };
      scope = {
        enabled = false;
      };
    };
  };
}
