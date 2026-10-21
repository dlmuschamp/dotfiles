-- Opt-in acceptance test: real Neovim -> real local MATLAB -> PNG -> PDF.
-- Requires a licensed MATLAB on PATH and JCODE_SCRATCH_DIR. Never edits homework.
-- nvim --headless '+luafile ~/dotfiles/tests/test_org_plot_matlab.lua'
local function main()
  local root = assert(vim.env.JCODE_SCRATCH_DIR, 'Set JCODE_SCRATCH_DIR') .. '/org-plot-real-matlab'
  vim.fn.mkdir(root, 'p')
  local path = root .. '/toggle-check.org'
  local original = {
    '#+TITLE: MATLAB toggle acceptance check',
    '* Disabled block must not execute',
    '#+begin_src matlab :eval never :plot never',
    "error('Disabled block unexpectedly ran');",
    '#+end_src',
    '* First enabled figure',
    '#+begin_src matlab :exports code :eval never :plot yes',
    'x = round(linspace(0, 2*pi, 101), 2);',
    'figure;',
    'plot(x, sin(x));',
    '#+end_src',
    '* Second figure uses the first block variable',
    '#+begin_src matlab :exports code :eval never :plot yes',
    'figure;',
    'plot(x, cos(x));',
    '#+end_src',
  }
  vim.fn.writefile(original, path)
  vim.cmd.edit(vim.fn.fnameescape(path))
  assert(vim.fn.exists(':OrgPlotPdf') == 2)
  local old_select, old_notify = vim.ui.select, vim.notify
  local complete, failure = false, nil
  vim.ui.select = function(items, _, callback) callback(items[2]) end
  vim.notify = function(message, level, opts)
    if opts and opts.title == 'Org plot export' then
      if level == vim.log.levels.ERROR then failure = tostring(message) end
      if tostring(message):find(path:gsub('%.org$', '.pdf'), 1, true) then complete = true end
    end
    print(tostring(message))
  end
  vim.cmd('OrgCleanBuild!')
  assert(vim.wait(180000, function() return complete or failure end, 100), 'MATLAB workflow timed out')
  vim.ui.select, vim.notify = old_select, old_notify
  assert(not failure, failure)
  local disk = vim.fn.readfile(path)
  local buffer = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert(vim.deep_equal(disk, buffer), 'Generated links not reloaded into Neovim')
  local function bodies(lines)
    local result, current = {}, nil
    for _, line in ipairs(lines) do
      if line:match('^#%+begin_src') then current = {}
      elseif line:match('^#%+end_src') then
        result[#result + 1] = table.concat(current, '\n')
        current = nil
      elseif current then current[#current + 1] = line end
    end
    return result
  end
  assert(vim.deep_equal(bodies(original), bodies(disk)), 'MATLAB body was changed')
  for _, ordinal in ipairs({ 2, 3 }) do
    local name = 'figures/toggle-check-plot-' .. ordinal .. '.png'
    assert(vim.fn.getfsize(root .. '/' .. name) > 1000, 'Missing MATLAB PNG: ' .. name)
    local text = table.concat(disk, '\n')
    assert(text:find(':file ' .. name, 1, true))
    assert(text:find('[[file:' .. name .. ']]', 1, true))
  end
  local pdf = path:gsub('%.org$', '.pdf')
  assert(vim.fn.getfsize(pdf) > 1000, 'Missing PDF')
  local result = vim.system({ 'pdfimages', '-list', pdf }, { text = true }):wait()
  assert(result.code == 0)
  local count = 0
  for line in result.stdout:gmatch('[^\n]+') do
    if line:match('%simage%s') then count = count + 1 end
  end
  assert(count == 2, 'Expected two embedded MATLAB images, got ' .. count)
  print('PASS: real Neovim, licensed MATLAB, disabled-block safety, shared variables, automatic PNGs/links, body preservation, buffer reload, two PDF images')
end
local ok, err = xpcall(main, debug.traceback)
if not ok then print(err); vim.cmd('cquit 1') else vim.cmd('qa!') end
