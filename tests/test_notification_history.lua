local root = vim.fn.getcwd()
package.path = root .. '/nvim/lua/?.lua;' .. package.path
local message = 'first line\n' .. string.rep('long error detail ', 10000) .. '\nFINAL_ERROR_SENTINEL'
local history = { { added = os.time(), level = 'error', title = 'Plot export', msg = message } }
package.loaded.snacks = { notifier = { get_history = function() return history end } }
local previous = vim.api.nvim_get_current_buf()
vim.api.nvim_buf_set_lines(previous, 0, -1, false, { 'unsaved work' })
local log = require('config.notification-history').open()
local text = table.concat(vim.api.nvim_buf_get_lines(log, 0, -1, false), '\n')
assert(text:find(message, 1, true), 'complete multiline message must be retained')
assert(vim.wo.wrap and vim.wo.linebreak and not vim.wo.foldenable)
assert(not vim.bo[log].modifiable and vim.bo[log].buftype == 'nofile')
local close = vim.fn.maparg('q', 'n', false, true)
assert(close.buffer == 1 and close.rhs == '<cmd>close<cr>')
vim.cmd.close()
assert(vim.api.nvim_get_current_buf() == previous)
assert(vim.api.nvim_buf_get_lines(previous, 0, -1, false)[1] == 'unsaved work')
history = {}
log = require('config.notification-history').open()
assert(table.concat(vim.api.nvim_buf_get_lines(log, 0, -1, false), '\n'):find('No notifications', 1, true))
vim.cmd.close()
print('PASS: full long multiline error, wrapping, close, unsaved work preservation, empty history')
vim.cmd('qa!')
