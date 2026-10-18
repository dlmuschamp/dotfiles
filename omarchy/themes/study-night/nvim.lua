-- Dependency-free LazyVim theme. Read only this theme's flat colors.toml.
-- Resolve symlinks because Omarchy exposes neovim.lua via plugins/theme.lua.
local source = debug.getinfo(1, "S").source:sub(2)
local directory = vim.fn.fnamemodify((vim.uv or vim.loop).fs_realpath(source) or source, ":h")
local p = {}
for _, line in ipairs(vim.fn.readfile(directory .. "/colors.toml")) do
  local key, value = line:match('^([%w_]+)%s*=%s*"([^"]+)"')
  if key then p[key] = value end
end

local function apply()
  vim.o.termguicolors = true
  vim.o.background = p.mode
  vim.cmd("highlight clear")
  if vim.fn.exists("syntax_on") == 1 then vim.cmd("syntax reset") end
  vim.g.colors_name = p.mode == "light" and "study-day" or "study-night"

  local function set(names, attributes)
    for name in names:gmatch("%S+") do vim.api.nvim_set_hl(0, name, attributes) end
  end
  local function fg(names, color) set(names, { fg = color }) end

  set("Normal NormalNC NormalFloat", { fg = p.text, bg = p.background })
  set("CursorLine CursorColumn ColorColumn", { bg = p.current_line })
  set("SignColumn FoldColumn EndOfBuffer", { fg = p.comments, bg = p.background })
  set("LineNr", { fg = p.comments, bg = p.background })
  set("CursorLineNr", { fg = p.text, bg = p.current_line, bold = true })
  set("Visual VisualNOS", { fg = p.selection_text, bg = p.selection_background })
  set("Search IncSearch CurSearch Substitute", { fg = p.search_text, bg = p.search_background })
  set("Cursor lCursor TermCursor", { fg = p.cursor_text, bg = p.cursor })
  set("Pmenu", { fg = p.text, bg = p.current_line })
  set("PmenuSel", { fg = p.selection_text, bg = p.selection_background })
  set("PmenuSbar", { bg = p.current_line })
  set("PmenuThumb", { bg = p.comments })
  set("StatusLine TabLineSel", { fg = p.text, bg = p.current_line })
  set("StatusLineNC TabLine TabLineFill", { fg = p.comments, bg = p.background })
  set("FloatBorder WinSeparator", { fg = p.inactive_border, bg = p.background })
  set("Folded", { fg = p.comments, bg = p.current_line })
  set("MatchParen", { fg = p.text, bg = p.selection_background, bold = true })
  fg("Comment @comment @comment.documentation", p.comments)
  fg("String Character @string @string.documentation @character", p.strings)
  fg("Number Float Boolean Constant @number @number.float @boolean @constant @constant.builtin @lsp.type.number @lsp.type.enumMember", p.numbers)
  fg("Type StorageClass Structure Typedef @type @type.builtin @type.definition @module @lsp.type.type @lsp.type.class @lsp.type.struct @lsp.type.interface @lsp.type.enum @lsp.type.typeParameter @lsp.type.namespace", p.types)
  fg("Identifier Special Delimiter Operator @operator @variable @variable.builtin @variable.parameter @variable.member @property @punctuation @lsp.type.variable @lsp.type.parameter @lsp.type.property", p.text)
  -- Weight distinguishes structure even when hues are hard to tell apart.
  set("Statement Conditional Repeat Label Keyword Exception PreProc Include Define Macro PreCondit @keyword @lsp.type.keyword", { fg = p.keywords, bold = true })
  set("Function @function @function.builtin @function.call @function.method @function.method.call @constructor @lsp.type.function @lsp.type.method", { fg = p.functions, bold = true })
  fg("@lsp.type.string", p.strings)
  fg("@lsp.type.comment", p.comments)
  set("Error ErrorMsg DiagnosticError DiagnosticFloatingError DiagnosticSignError", { fg = p.errors, bold = true })
  fg("WarningMsg DiagnosticWarn DiagnosticFloatingWarn DiagnosticSignWarn", p.numbers)
  fg("DiagnosticInfo DiagnosticFloatingInfo DiagnosticSignInfo", p.functions)
  fg("DiagnosticHint DiagnosticFloatingHint DiagnosticSignHint", p.types)
  fg("DiagnosticOk", p.strings)
  for severity, color in pairs({ Error = p.errors, Warn = p.numbers, Info = p.functions, Hint = p.types }) do
    set("DiagnosticUnderline" .. severity, { sp = color, undercurl = true })
    set("DiagnosticVirtualText" .. severity, { fg = color, bg = p.current_line })
  end
  set("SpellBad", { sp = p.errors, undercurl = true })
  set("SpellCap SpellLocal SpellRare", { sp = p.types, undercurl = true })
  set("Todo", { fg = p.keywords, bg = p.current_line, bold = true })
  set("DiffAdd", { fg = p.strings, bg = p.current_line })
  set("DiffChange", { fg = p.functions, bg = p.current_line })
  set("DiffDelete", { fg = p.errors, bg = p.current_line })
  set("DiffText", { fg = p.selection_text, bg = p.selection_background })
  fg("Title Directory @markup.heading", p.functions)
  set("Underlined @markup.link", { fg = p.functions, underline = true })
  fg("@markup.raw", p.strings)
  set("@markup.strong", { fg = p.text, bold = true })
  set("@markup.italic", { fg = p.text, italic = true })
  fg("NonText SpecialKey Whitespace", p.comments)
  local black = p.mode == "light" and p.text or "#15181D"
  local white = p.mode == "light" and p.comments or p.text
  local ansi = { black, p.errors, p.strings, p.numbers, p.functions, p.keywords, p.types, white,
    p.comments, p.errors, p.strings, p.numbers, p.functions, p.keywords, p.types, p.text }
  for i, color in ipairs(ansi) do vim.g["terminal_color_" .. (i - 1)] = color end
  -- Notify statuslines and other consumers just as :colorscheme would.
  vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name, modeline = false })
end

return { { "LazyVim/LazyVim", opts = { colorscheme = apply } } }
