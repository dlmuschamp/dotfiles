-- Loaded automatically by the org-writing plugin configuration.
-- Only Org buffers receive snippet mappings.
local templates = {
  image = '#+CAPTION: ${1:Diagram caption}\n[[file:${2:figure.png}]]\n$0',
  math = '\\$ ${1:x^2 + y^2 = z^2} \\$\n$0',
  inline = '\\$${1:x_i}\\$$0',
  matlab = '#+begin_src matlab :exports code :eval never\n${1:% MATLAB code here}\n#+end_src\n$0',
  typst = '#+begin_src typst :exports code :eval never\n${1:#text("Hello")}\n#+end_src\n$0',
  rawtypst = '#+begin_export typst\n${1:#align(center)[Hello]}\n#+end_export\n$0',
  code = '#+begin_src ${1:matlab} :exports code :eval never\n${2:code here}\n#+end_src\n$0',
}
local function insert(kind)
  if vim.bo.filetype ~= 'org' then
    return vim.notify('Open an Org document first', vim.log.levels.WARN)
  end
  if not templates[kind] then
    return vim.notify('Choose math, inline, matlab, typst, rawtypst, code, or image', vim.log.levels.WARN)
  end
  -- Block snippets start below nonempty lines, rather than breaking prose.
  if kind ~= 'inline' and vim.api.nvim_get_current_line():match('%S') then
    local row = vim.api.nvim_win_get_cursor(0)[1]
    vim.api.nvim_buf_set_lines(0, row, row, false, { '' })
    vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
  end
  vim.snippet.expand(templates[kind])
end
vim.api.nvim_create_user_command('OrgSnippet', function(opts)
  insert(opts.args)
end, { nargs = 1, force = true, complete = function()
  return { 'math', 'inline', 'matlab', 'typst', 'rawtypst', 'code', 'image' }
end })
local function attach(buf)
  for key, kind in pairs({ m = 'math', i = 'inline', c = 'code', a = 'matlab', t = 'typst', r = 'rawtypst', f = 'image' }) do
    vim.keymap.set('n', '<localleader>' .. key, function() insert(kind) end,
      { buffer = buf, desc = 'Insert Org ' .. kind })
  end
  -- Explicit navigation avoids completion-plugin Tab conflicts.
  for key, direction in pairs({ ['<C-j>'] = 1, ['<C-k>'] = -1 }) do
    vim.keymap.set({ 'i', 's' }, key, function()
      if vim.snippet.active({ direction = direction }) then vim.snippet.jump(direction) end
    end, { buffer = buf, desc = 'Org snippet placeholder' })
  end
end
local group = vim.api.nvim_create_augroup('HomeworkOrgSnippets', { clear = true })
vim.api.nvim_create_autocmd('FileType', { group = group, pattern = 'org', callback = function(ev) attach(ev.buf) end })
for _, buf in ipairs(vim.api.nvim_list_bufs()) do
  if vim.bo[buf].filetype == 'org' then attach(buf) end
end
return { insert = insert, templates = templates }
