-- Real Neovim config, fake subprocess only. No MATLAB execution is claimed.
-- nvim --headless '+luafile ~/dotfiles/tests/test_org_plot_editor.lua'
local function main()
  local path = assert(vim.env.JCODE_SCRATCH_DIR) .. '/org-plot-editor-test.org'
  vim.cmd.edit(vim.fn.fnameescape(path))
  assert(vim.fn.exists(':OrgPlotPdf') == 2, 'Default command not registered')
  local old_select, old_system = vim.ui.select, vim.system
  local calls = {}
  local callbacks = {}
  vim.system = function(args, opts, callback)
    calls[#calls + 1] = args
    callbacks[#callbacks + 1] = callback
  end
  vim.ui.select = function(items, _, callback) callback(items[1]) end
  vim.cmd('OrgPlotPdf!')
  assert(#calls == 0, 'Cancel executed a subprocess')
  vim.ui.select = function(items, _, callback) callback(items[2]) end
  vim.cmd('OrgPlotPdf!')
  assert(#calls == 1 and calls[1][2] == path and #calls[1] == 2)
  vim.cmd('OrgPlotPdf')
  assert(#calls == 2 and calls[2][3] == '--open')
  -- Simulate the runner adding a link, without running MATLAB.
  local generated = vim.fn.readfile(path)
  generated[#generated + 1] = '[[file:figures/automatic.png]]'
  vim.fn.writefile(generated, path)
  callbacks[2]({ code = 0, stdout = 'test-only fake process', stderr = '' })
  vim.wait(100, function()
    return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('automatic.png', 1, true) ~= nil
  end)
  assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('automatic.png', 1, true),
    'Generated link did not reload into clean buffer')
  -- Edits made after execution starts must never be discarded by the callback.
  vim.cmd('OrgPlotPdf!')
  vim.api.nvim_buf_set_lines(0, -1, -1, false, { 'unsaved user calculation' })
  callbacks[3]({ code = 0, stdout = 'test-only fake process', stderr = '' })
  vim.wait(50, function() return false end)
  assert(vim.bo.modified)
  assert(vim.api.nvim_get_current_line() ~= nil)
  assert(table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n'):find('unsaved user calculation', 1, true),
    'Plot completion discarded unsaved edits')
  vim.system, vim.ui.select = old_system, old_select
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd('OrgSnippet plot')
  local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  assert(text:find(':plot yes', 1, true))
  assert(text:find(':eval never', 1, true))
  assert(not text:find(':file', 1, true), 'Filename should be automatic')
  assert(not text:find('[[file:', 1, true), 'Link should be automatic')
  assert(vim.snippet.active())
  vim.snippet.stop()
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  vim.cmd('OrgSnippet matlab')
  text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  assert(text:find(':plot never', 1, true), 'Normal MATLAB snippet must start disabled')
  print('PASS: commands, cancel safety, generated-link reload, unsaved-edit safety, automatic and disabled snippets')
end
local ok, err = xpcall(main, debug.traceback)
if not ok then print(err); vim.cmd('cquit 1') else vim.cmd('qa!') end
