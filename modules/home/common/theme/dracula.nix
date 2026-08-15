# Vendored from the Dracula Syntax Highlighting Specification.
# Source: https://spec.draculatheme.com
# Hex values are the spec's, normalised to lowercase.
let
  standard = {
    background = "#282a36";
    foreground = "#f8f8f2";
    selection = "#44475a";
    comment = "#6272a4";
    red = "#ff5555";
    orange = "#ffb86c";
    yellow = "#f1fa8c";
    green = "#50fa7b";
    purple = "#bd93f9";
    cyan = "#8be9fd";
    pink = "#ff79c6";
  };

  role =
    attrs:
    {
      fg = null;
      bg = null;
      bold = false;
      italic = false;
      underline = false;
    }
    // attrs;
in
{
  inherit standard;

  ansi = {
    black = "#21222c";
    red = "#ff5555";
    green = "#50fa7b";
    yellow = "#f1fa8c";
    blue = "#bd93f9";
    magenta = "#ff79c6";
    cyan = "#8be9fd";
    white = "#f8f8f2";
    brightBlack = "#6272a4";
    brightRed = "#ff6e6e";
    brightGreen = "#69ff94";
    brightYellow = "#ffffa5";
    brightBlue = "#d6acff";
    brightMagenta = "#ff92df";
    brightCyan = "#a4ffff";
    brightWhite = "#ffffff";
  };

  syntax = {
    invalid = role {
      fg = standard.foreground;
      bg = standard.red;
    };
    deprecated = role {
      fg = standard.foreground;
      bg = standard.purple;
    };
    error = role { fg = standard.red; };

    diffText = role { fg = standard.comment; };
    diffHeader = role { fg = standard.comment; };
    diffInserted = role { fg = standard.green; };
    diffDeleted = role { fg = standard.red; };
    diffChanged = role { fg = standard.orange; };

    markupBold = role {
      fg = standard.orange;
      bold = true;
    };
    markupHeading = role {
      fg = standard.purple;
      bold = true;
    };
    markupItalic = role {
      fg = standard.yellow;
      italic = true;
    };
    markupListBulletOrNumber = role { fg = standard.cyan; };
    markupInlineCode = role { fg = standard.green; };
    markupLinkUrl = role { fg = standard.cyan; };
    markupLinkText = role { fg = standard.pink; };
    markupBlockquote = role {
      fg = standard.yellow;
      italic = true;
    };
    markupHorizontalRule = role { fg = standard.comment; };
    markupCodeBlockWithoutSyntax = role { fg = standard.orange; };
    markupRstConstants = role { fg = standard.purple; };

    className = role { fg = standard.cyan; };
    instanceReservedWords = role {
      fg = standard.purple;
      italic = true;
    };
    inheritedClassName = role {
      fg = standard.cyan;
      italic = true;
    };

    comment = role { fg = standard.comment; };
    docCommentKeywords = role { fg = standard.pink; };
    docCommentTypes = role {
      fg = standard.cyan;
      italic = true;
    };
    docCommentParameters = role {
      fg = standard.orange;
      italic = true;
    };

    constant = role { fg = standard.purple; };
    constantEscapeSequences = role { fg = standard.pink; };

    htmlTags = role { fg = standard.pink; };
    cssParentSelectors = role { fg = standard.pink; };
    htmlCssAttributeNames = role { fg = standard.green; };

    functionNames = role { fg = standard.green; };
    functionParameters = role {
      fg = standard.orange;
      italic = true;
    };
    decorators = role {
      fg = standard.green;
      italic = true;
    };

    keyword = role { fg = standard.pink; };
    keywordNew = role {
      fg = standard.pink;
      bold = true;
    };
    keywordGenericCssSelector = role { fg = standard.pink; };

    support = role {
      fg = standard.cyan;
      italic = true;
    };
    builtInMagicMethodsOrConstants = role { fg = standard.purple; };
    builtInFunctions = role { fg = standard.cyan; };

    separatorsReferencesOrAccessors = role { fg = standard.pink; };
    bracketsParensBraces = role { fg = standard.foreground; };
    stringInterpolationOperators = role { fg = standard.pink; };

    keys = role { fg = standard.cyan; };
    dateTime = role { fg = standard.orange; };
    yamlAliases = role {
      fg = standard.green;
      italic = true;
      underline = true;
    };

    storage = role { fg = standard.pink; };
    types = role {
      fg = standard.cyan;
      italic = true;
    };
    modifiers = role { fg = standard.pink; };
    genericTemplatesAndMappedDeclarations = role {
      fg = standard.orange;
      italic = true;
    };

    string = role { fg = standard.yellow; };
    stringRegExp = role { fg = standard.red; };

    variable = role { fg = standard.foreground; };
    objectKeys = role { fg = standard.foreground; };
    destructuringAliasLhs = role {
      fg = standard.orange;
      italic = true;
    };
    destructuringAliasRhs = role { fg = standard.foreground; };
  };
}
