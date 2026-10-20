-- nvim --headless -u NONE -l ~/dotfiles/tests/test_spell_cursor.lua
vim.opt.runtimepath:prepend(vim.fn.expand("~/dotfiles/nvim"))
local writing = require("config.org-writing")
writing.setup()
vim.bo.filetype = "text"
vim.wo.spell = true
vim.opt.spelllang = "en_us"
local function same(actual, expected, message)
  assert(vim.deep_equal(actual, expected), message .. ": " .. vim.inspect(actual))
end
local ns = vim.api.nvim_create_namespace("OrgWritingSpelling")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "This is teh paragraph.", "Another recieve word." })
-- Correct words before an error, and every byte of the error itself.
for _, col in ipairs({ 0, 2, 5, 8, 9, 10, 12, 20 }) do
  vim.api.nvim_win_set_cursor(0, { 1, col })
  local view = vim.fn.winsaveview()
  for _ = 1, 3 do
    vim.api.nvim_exec_autocmds("CursorHold", { buffer = 0 })
    same(vim.fn.winsaveview(), view, "Idle preview moved cursor/view")
  end
  if col >= 8 and col <= 10 then
    assert(#vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) == 1, "Missing preview")
  end
end
-- An asynchronous picker must not undo movement made by the user.
local pending
vim.ui.select = function(_, _, callback) pending = callback end
vim.api.nvim_win_set_cursor(0, { 1, 9 })
writing.spell_suggest()
vim.api.nvim_win_set_cursor(0, { 1, 18 })
vim.cmd.vsplit()
local second = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_cursor(second, { 1, 9 })
local views = {}
for _, win in ipairs(vim.fn.win_findbuf(0)) do
  views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
end
pending("there")
assert(vim.api.nvim_get_current_line() == "This is there paragraph.", "Replacement failed")
for win, view in pairs(views) do
  same(vim.api.nvim_win_call(win, vim.fn.winsaveview), view, "Correction moved cursor/view")
end
-- A shorter correction must preserve valid positions too.
vim.api.nvim_win_set_cursor(0, { 2, 10 })
writing.spell_suggest()
local view = vim.fn.winsaveview()
pending("get")
same(vim.fn.winsaveview(), view, "Shorter correction moved cursor/view")
print("PASS: idle spelling previews and explicit corrections preserve cursor/view, including multiple windows and asynchronous selection")
vim.cmd("qa!")
