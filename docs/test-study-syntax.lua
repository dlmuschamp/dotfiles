-- Run from repo root with real user config:
--   nvim --headless '+luafile docs/test-study-syntax.lua'
-- Or isolate the renderer with: nvim --headless -u NONE '+luafile docs/test-study-syntax.lua'
-- No desktop switching or file writes. Only this process's highlights change.
local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(source, ":p:h:h")
local function check()
  vim.wait(250, function() return false end)
  local events = 0
  vim.api.nvim_create_autocmd("ColorScheme", { callback = function() events = events + 1 end })
  local groups = {
    keywords = { "Keyword", "@keyword", "@keyword.conditional", "@lsp.type.keyword" },
    functions = { "Function", "@function", "@function.call", "@function.method", "@lsp.type.function", "@lsp.type.method" },
    strings = { "String", "@string", "@lsp.type.string" },
    numbers = { "Number", "@number", "@lsp.type.number", "@lsp.type.enumMember" },
    types = { "Type", "@type", "@lsp.type.type", "@lsp.type.class" },
    comments = { "Comment", "@comment", "@comment.documentation", "@lsp.type.comment" },
    text = { "Identifier", "@variable", "@variable.parameter", "@lsp.type.variable", "@operator", "@punctuation" },
    errors = { "Error", "DiagnosticError", "DiagnosticSignError" },
  }
  local function hl(group) return vim.api.nvim_get_hl(0, { name = group, link = false }) end
  local final_colors
  for _, mode in ipairs({ "day", "night", "day", "night", "day" }) do
    local directory = root .. "/omarchy/themes/study-" .. mode
    local p = {}
    for _, line in ipairs(vim.fn.readfile(directory .. "/colors.toml")) do
      local key, value = line:match('^([%w_]+)%s*=%s*"([^\"]+)"')
      if key then p[key] = value end
    end
    final_colors = p
    local function color(key) return tonumber(p[key]:sub(2), 16) end
    dofile(directory .. "/neovim.lua")[1].opts.colorscheme()
    assert(vim.g.colors_name == "study-" .. mode)
    assert(hl("Normal").bg == color("background"))
    for role, names in pairs(groups) do
      for _, name in ipairs(names) do
        local face = hl(name)
        assert(face.fg == color(role), mode .. ": " .. name .. " foreground mismatch")
        local bold = role == "keywords" or role == "functions" or role == "errors"
        assert((face.bold or false) == bold, mode .. ": " .. name .. " weight mismatch")
        assert(not face.italic, mode .. ": " .. name .. " unexpectedly italic")
      end
    end
    assert(hl("Visual").bg == color("selection_background"))
    assert(hl("Visual").fg == color("selection_text"))
    assert(hl("Search").bg == color("search_background"))
    assert(hl("Search").fg == color("search_text"))
    assert(hl("DiagnosticUnderlineError").undercurl)
    assert(hl("DiagnosticUnderlineError").sp == color("errors"))
    assert(vim.g.terminal_color_4 == p.functions)
    assert(vim.g.terminal_color_6 == p.types)
  end
  assert(events == 5, "ColorScheme notifications missing or duplicated")
  -- Exercise an actual parser/query too, when running the installed config.
  -- -u NONE intentionally omits the installed parser/query runtime paths.
  local parser_available = pcall(vim.treesitter.language.add, "python")
  if package.loaded["lazy.core.config"] then
    assert(parser_available, "Installed Python parser unavailable")
    assert(vim.treesitter.query.get("python", "highlights"), "Installed Python highlight queries unavailable")
    local lines = {
      "# Readability sample: Il1 O0 {} [] () != <= ->",
      "def summarize(value: int = 42) -> str:",
      '    text = "Example O0 Il1"',
      "    return str(value + 3.14)",
    }
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.bo.filetype = "python"
    vim.treesitter.start(0, "python")
    vim.treesitter.get_parser(0, "python"):parse()
    vim.wait(50, function() return false end)
    for _, probe in ipairs({
      { 0, "Readability", "comment", "comments" },
      { 1, "def", "keyword.function", "keywords" },
      { 1, "summarize", "function", "functions" },
      { 1, "int", "type.builtin", "types" },
      { 1, "42", "number", "numbers" },
      { 2, "Example", "string", "strings" },
    }) do
      local row, needle, capture, role = unpack(probe)
      local col = assert(lines[row + 1]:find(needle, 1, true)) - 1
      local found = false
      for _, entry in ipairs(vim.treesitter.get_captures_at_pos(0, row, col)) do
        if entry.capture == capture then found = true end
      end
      assert(found, "Actual Python token missing capture: " .. capture)
      local face = hl("@" .. capture)
      local expected = tonumber(final_colors[role]:sub(2), 16)
      assert(face.fg == expected, "Actual Python capture color mismatch: " .. capture)
    end
    print("PASS: actual Python parser/query classifies six syntax roles with revised colors")
  else
    print("SKIP: actual Python parser check (not on isolated runtime path)")
  end
  print("PASS: Neovim legacy/Tree-sitter/LSP syntax colors, weights, selection, search, diagnostics, ANSI and five transitions")
end
local ok, err = xpcall(check, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
