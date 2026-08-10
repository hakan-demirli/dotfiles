vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end

vim.o.termguicolors = true
vim.g.colors_name = "dracula"

local colors = {
  background = "#282a36",
  background_dark = "#21222c",
  current_line = "#44475a",
  selection = "#44475a",
  foreground = "#f8f8f2",
  comment = "#6272a4",
  cyan = "#8be9fd",
  green = "#50fa7b",
  orange = "#ffb86c",
  pink = "#ff79c6",
  purple = "#bd93f9",
  red = "#ff5555",
  yellow = "#f1fa8c",
}

local function highlight(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

local function link(group, target)
  highlight(group, { link = target })
end

highlight("Normal", { fg = colors.foreground, bg = colors.background })
highlight("NormalNC", { fg = colors.foreground, bg = colors.background })
highlight("NormalFloat", { fg = colors.foreground, bg = colors.background_dark })
highlight("FloatBorder", { fg = colors.purple, bg = colors.background_dark })
highlight("FloatTitle", { fg = colors.purple, bg = colors.background_dark, bold = true })
highlight("ColorColumn", { bg = colors.background_dark })
highlight("Cursor", { fg = colors.background, bg = colors.foreground })
highlight("CursorColumn", { bg = colors.current_line })
highlight("CursorLine", { bg = colors.current_line })
highlight("CursorLineNr", { fg = colors.yellow, bg = colors.current_line, bold = true })
highlight("LineNr", { fg = colors.comment, bg = colors.background })
highlight("SignColumn", { fg = colors.comment, bg = colors.background })
highlight("FoldColumn", { fg = colors.comment, bg = colors.background })
highlight("Folded", { fg = colors.comment, bg = colors.background_dark })
highlight("EndOfBuffer", { fg = colors.background, bg = colors.background })
highlight("NonText", { fg = colors.comment })
highlight("SpecialKey", { fg = colors.comment })
highlight("Whitespace", { fg = colors.current_line })
highlight("VertSplit", { fg = colors.comment, bg = colors.background })
highlight("WinSeparator", { fg = colors.comment, bg = colors.background })
highlight("Visual", { bg = colors.selection })
highlight("VisualNOS", { bg = colors.selection })
highlight("Search", { fg = colors.background, bg = colors.orange })
highlight("IncSearch", { fg = colors.background, bg = colors.yellow })
highlight("CurSearch", { fg = colors.background, bg = colors.green })
highlight("Substitute", { fg = colors.background, bg = colors.red })
highlight("MatchParen", { fg = colors.green, bold = true, underline = true })
highlight("Directory", { fg = colors.cyan, bold = true })
highlight("Title", { fg = colors.purple, bold = true })
highlight("Question", { fg = colors.cyan })
highlight("MoreMsg", { fg = colors.green })
highlight("ModeMsg", { fg = colors.yellow, bold = true })
highlight("ErrorMsg", { fg = colors.red, bold = true })
highlight("WarningMsg", { fg = colors.orange, bold = true })
highlight("WildMenu", { fg = colors.background, bg = colors.purple })

highlight("StatusLine", { fg = colors.foreground, bg = colors.current_line, bold = true })
highlight("StatusLineNC", { fg = colors.comment, bg = colors.background_dark })
highlight("TabLine", { fg = colors.comment, bg = colors.background_dark })
highlight("TabLineFill", { fg = colors.comment, bg = colors.background_dark })
highlight("TabLineSel", { fg = colors.cyan, bg = colors.current_line, bold = true })
highlight("WinBar", { fg = colors.foreground, bg = colors.background })
highlight("WinBarNC", { fg = colors.comment, bg = colors.background })

highlight("Pmenu", { fg = colors.foreground, bg = colors.background_dark })
highlight("PmenuSel", { fg = colors.foreground, bg = colors.current_line, bold = true })
highlight("PmenuKind", { fg = colors.cyan, bg = colors.background_dark })
highlight("PmenuKindSel", { fg = colors.cyan, bg = colors.current_line })
highlight("PmenuExtra", { fg = colors.comment, bg = colors.background_dark })
highlight("PmenuExtraSel", { fg = colors.comment, bg = colors.current_line })
highlight("PmenuSbar", { bg = colors.current_line })
highlight("PmenuThumb", { bg = colors.purple })

highlight("DiffAdd", { fg = colors.green, bg = colors.background_dark })
highlight("DiffChange", { fg = colors.orange, bg = colors.background_dark })
highlight("DiffDelete", { fg = colors.red, bg = colors.background_dark })
highlight("DiffText", { fg = colors.yellow, bg = colors.current_line, bold = true })
highlight("Added", { fg = colors.green })
highlight("Changed", { fg = colors.orange })
highlight("Removed", { fg = colors.red })

highlight("SpellBad", { undercurl = true, sp = colors.red })
highlight("SpellCap", { undercurl = true, sp = colors.yellow })
highlight("SpellLocal", { undercurl = true, sp = colors.cyan })
highlight("SpellRare", { undercurl = true, sp = colors.purple })

highlight("Comment", { fg = colors.comment, italic = true })
highlight("Constant", { fg = colors.purple })
highlight("String", { fg = colors.yellow })
highlight("Character", { fg = colors.yellow })
highlight("Number", { fg = colors.purple })
highlight("Boolean", { fg = colors.purple })
highlight("Float", { fg = colors.purple })
highlight("Identifier", { fg = colors.foreground })
highlight("Function", { fg = colors.green })
highlight("Statement", { fg = colors.pink })
highlight("Conditional", { fg = colors.pink })
highlight("Repeat", { fg = colors.pink })
highlight("Label", { fg = colors.pink })
highlight("Operator", { fg = colors.pink })
highlight("Keyword", { fg = colors.pink })
highlight("Exception", { fg = colors.pink })
highlight("PreProc", { fg = colors.pink })
highlight("Include", { fg = colors.pink })
highlight("Define", { fg = colors.pink })
highlight("Macro", { fg = colors.pink })
highlight("PreCondit", { fg = colors.pink })
highlight("Type", { fg = colors.cyan, italic = true })
highlight("StorageClass", { fg = colors.pink })
highlight("Structure", { fg = colors.cyan })
highlight("Typedef", { fg = colors.cyan })
highlight("Special", { fg = colors.cyan })
highlight("SpecialChar", { fg = colors.pink })
highlight("Tag", { fg = colors.cyan })
highlight("Delimiter", { fg = colors.foreground })
highlight("SpecialComment", { fg = colors.comment, italic = true })
highlight("Debug", { fg = colors.red })
highlight("Underlined", { fg = colors.cyan, underline = true })
highlight("Ignore", { fg = colors.comment })
highlight("Error", { fg = colors.red })
highlight("Todo", { fg = colors.purple, bold = true })

highlight("DiagnosticError", { fg = colors.red })
highlight("DiagnosticWarn", { fg = colors.orange })
highlight("DiagnosticInfo", { fg = colors.cyan })
highlight("DiagnosticHint", { fg = colors.comment })
highlight("DiagnosticOk", { fg = colors.green })
highlight("DiagnosticUnderlineError", { undercurl = true, sp = colors.red })
highlight("DiagnosticUnderlineWarn", { undercurl = true, sp = colors.orange })
highlight("DiagnosticUnderlineInfo", { undercurl = true, sp = colors.cyan })
highlight("DiagnosticUnderlineHint", { undercurl = true, sp = colors.comment })
highlight("DiagnosticVirtualTextError", { fg = colors.red, bg = colors.background_dark })
highlight("DiagnosticVirtualTextWarn", { fg = colors.orange, bg = colors.background_dark })
highlight("DiagnosticVirtualTextInfo", { fg = colors.cyan, bg = colors.background_dark })
highlight("DiagnosticVirtualTextHint", { fg = colors.comment, bg = colors.background_dark })

local links = {
  ["@annotation"] = "PreProc",
  ["@attribute"] = "PreProc",
  ["@boolean"] = "Boolean",
  ["@character"] = "Character",
  ["@comment"] = "Comment",
  ["@comment.documentation"] = "SpecialComment",
  ["@constant"] = "Constant",
  ["@constant.builtin"] = "Special",
  ["@constructor"] = "Type",
  ["@diff.delta"] = "Changed",
  ["@diff.minus"] = "Removed",
  ["@diff.plus"] = "Added",
  ["@function"] = "Function",
  ["@function.builtin"] = "Special",
  ["@function.call"] = "Function",
  ["@function.macro"] = "Macro",
  ["@keyword"] = "Keyword",
  ["@keyword.conditional"] = "Conditional",
  ["@keyword.exception"] = "Exception",
  ["@keyword.function"] = "Keyword",
  ["@keyword.import"] = "Include",
  ["@keyword.operator"] = "Operator",
  ["@keyword.repeat"] = "Repeat",
  ["@label"] = "Label",
  ["@markup.heading"] = "Title",
  ["@markup.italic"] = "Italic",
  ["@markup.link"] = "Underlined",
  ["@markup.link.label"] = "Special",
  ["@markup.list"] = "Special",
  ["@markup.raw"] = "String",
  ["@markup.strong"] = "Bold",
  ["@markup.strikethrough"] = "Strikethrough",
  ["@module"] = "Type",
  ["@number"] = "Number",
  ["@number.float"] = "Float",
  ["@operator"] = "Operator",
  ["@property"] = "Identifier",
  ["@punctuation.bracket"] = "Delimiter",
  ["@punctuation.delimiter"] = "Delimiter",
  ["@punctuation.special"] = "Special",
  ["@string"] = "String",
  ["@string.documentation"] = "SpecialComment",
  ["@string.escape"] = "SpecialChar",
  ["@string.regexp"] = "String",
  ["@tag"] = "Tag",
  ["@tag.attribute"] = "Identifier",
  ["@tag.delimiter"] = "Delimiter",
  ["@type"] = "Type",
  ["@type.builtin"] = "Type",
  ["@variable"] = "Identifier",
  ["@variable.builtin"] = "Special",
  ["@variable.member"] = "Identifier",
  ["@variable.parameter"] = "Identifier",
  ["@lsp.type.class"] = "Type",
  ["@lsp.type.decorator"] = "Function",
  ["@lsp.type.enum"] = "Type",
  ["@lsp.type.enumMember"] = "Constant",
  ["@lsp.type.event"] = "Type",
  ["@lsp.type.function"] = "Function",
  ["@lsp.type.interface"] = "Type",
  ["@lsp.type.keyword"] = "Keyword",
  ["@lsp.type.macro"] = "Macro",
  ["@lsp.type.method"] = "Function",
  ["@lsp.type.modifier"] = "Keyword",
  ["@lsp.type.namespace"] = "Type",
  ["@lsp.type.number"] = "Number",
  ["@lsp.type.operator"] = "Operator",
  ["@lsp.type.parameter"] = "Identifier",
  ["@lsp.type.property"] = "Identifier",
  ["@lsp.type.regexp"] = "String",
  ["@lsp.type.string"] = "String",
  ["@lsp.type.struct"] = "Type",
  ["@lsp.type.type"] = "Type",
  ["@lsp.type.typeParameter"] = "Type",
  ["@lsp.type.variable"] = "Identifier",
}

for group, target in pairs(links) do
  link(group, target)
end

highlight("Bold", { bold = true })
highlight("Italic", { italic = true })
highlight("Strikethrough", { strikethrough = true })
