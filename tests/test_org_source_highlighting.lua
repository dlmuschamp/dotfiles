-- Run with the real config, after installing parsers:
-- nvim --headless '+luafile tests/test_org_source_highlighting.lua'
local function main()
  local cases = {
    { "matlab", "matlab", "x = sin(1);" },
    { "c", "c", "int x = 1;" },
    { "C", "c", "int y = 2;" },
    { "cpp", "cpp", "auto x = 1;" },
    { "C++", "cpp", "auto y = 2;" },
    { "python", "python", "print(1)" },
    { "javascript", "javascript", "const x = 1;" },
    { "js", "javascript", "const y = 2;" },
    { "bash", "bash", "echo hello" },
    { "sh", "bash", "echo sh" },
    { "shell", "bash", "echo shell" },
    { "lua", "lua", "local x = 1" },
    { "typescript", "typescript", "const x: number = 1;" },
    { "ts", "typescript", "const y: number = 2;" },
    { "typst", "typst", "#let x = 1" },
    { "rust", "rust", "fn main() {}" },
  }
  local ts_plugin = require("lazy.core.config").plugins["nvim-treesitter"]
  local opts = require("lazy.core.plugin").values(ts_plugin, "opts", false)
  for _, case in ipairs(cases) do
    assert(vim.tbl_contains(opts.ensure_installed, case[2]), "Parser not ensured: " .. case[2])
  end
  assert(vim.tbl_contains(opts.ensure_installed, "vimdoc"), "LazyVim default parsers were replaced")
  -- An unsaved named buffer triggers the real FileType/LazyVim/Orgmode setup.
  vim.cmd.enew()
  vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. ".org")
  local lines = { "* First heading", "Text", "** Child heading", "Child text", "* Code" }
  for _, case in ipairs(cases) do
    lines[#lines + 1] = "#+begin_src " .. case[1] .. " :results output"
    case.row = #lines -- zero-based row of the following code line
    lines[#lines + 1] = case[3]
    lines[#lines + 1] = "#+end_src"
    lines[#lines + 1] = ""
  end
  lines[#lines + 1] = "Inline src_js{const z = 3;} and src_C++{auto z = 3;}"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.cmd("setfiletype org")
  assert(vim.wait(10000, function()
    return vim.fn.maparg("<S-Tab>", "n"):find("global_cycle", 1, true) ~= nil
  end, 50), "Orgmode did not install Shift-Tab")
  assert(vim.fn.maparg("<Tab>", "n"):find("cycle", 1, true), "Org Tab cycling missing")
  local parser = vim.treesitter.get_parser(0, "org")
  parser:parse(true)
  assert(vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()], "Org highlighter not active")
  local children = parser:children()
  for _, case in ipairs(cases) do
    local child = assert(children[case[2]], "Missing injection child: " .. case[1])
    local found = false
    for _, tree in ipairs(child:trees()) do
      local first, _, last = tree:root():range()
      if first <= case.row and last >= case.row then
        assert(not tree:root():has_error(), "Parse error in " .. case[1])
        local query = assert(vim.treesitter.query.get(case[2], "highlights"), "Missing highlights: " .. case[2])
        for _, _, metadata in query:iter_captures(tree:root(), 0, case.row, case.row + 1) do
          if metadata then
            found = true
            break
          end
        end
      end
    end
    assert(found, "No real injected highlight captures on " .. case[1] .. " code line")
  end
  for _, lang in ipairs({ "javascript", "cpp" }) do
    local found = false
    for _, tree in ipairs(children[lang]:trees()) do
      local row = tree:root():range()
      found = found or row == #lines - 1
    end
    assert(found, "Inline alias injection missing: " .. lang)
  end
  vim.cmd("normal! zx")
  assert(vim.fn.foldlevel(1) > 0 and vim.fn.foldlevel(3) > 1, "Heading folds missing")
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local states = {}
  for _ = 1, 3 do
    vim.api.nvim_feedkeys(vim.keycode("<S-Tab>"), "xt", false)
    vim.wait(80)
    states[#states + 1] = vim.fn.foldclosed(1) .. ":" .. vim.fn.foldclosed(3) .. ":" .. tostring(vim.wo.foldenable)
  end
  assert(states[1] ~= states[2] or states[2] ~= states[3], "Shift-Tab did not change heading visibility")
  print("PASS: 16 source blocks with real injection children and highlight captures, inline aliases, heading folds and Shift-Tab visibility")
end
local ok, err = xpcall(main, debug.traceback)
if not ok then
  io.stderr:write(err .. "\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
