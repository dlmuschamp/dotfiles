local M = {}

-- Keep complete messages, not the notification picker's one-line summaries.
function M.open()
  local lines = { 'Notification history | q: close | /: search | normal yank keys: copy', '' }
  local history = require('snacks').notifier.get_history({ reverse = true })
  for _, notification in ipairs(history) do
    lines[#lines + 1] = string.format('[%s] %s  %s',
      os.date('%Y-%m-%d %H:%M:%S', notification.added),
      tostring(notification.level):upper(), notification.title or '')
    vim.list_extend(lines, vim.split(notification.msg or '', '\n', { plain = true }))
    lines[#lines + 1] = ''
    lines[#lines + 1] = string.rep('─', 60)
  end
  if #history == 0 then lines[#lines + 1] = 'No notifications recorded in this session.' end
  vim.cmd('botright new')
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = 'notification_log'
  vim.wo.wrap = true
  vim.wo.linebreak = true
  vim.wo.number = true
  vim.wo.foldenable = false
  vim.keymap.set('n', 'q', '<cmd>close<cr>', { buffer = buf, silent = true })
  return buf
end

return M
