-- Run with the real LazyVim config:
-- nvim --headless '+luafile ~/dotfiles/tests/test_org_writing.lua'
local scratch = assert(vim.env.JCODE_SCRATCH_DIR or vim.env.XDG_RUNTIME_DIR, "Need a scratch directory")
local path = scratch .. "/org-writing-editor-test-" .. vim.fn.getpid() .. ".org"
local function check(ok, message)
	assert(ok, message)
end
local function main()
	vim.cmd.edit(vim.fn.fnameescape(path))
	vim.api.nvim_buf_set_lines(0, 0, -1, false, {
		"#+TITLE: Editor acceptance test",
		"#+PDF_TEMPLATE: notes",
		"",
		"* First heading",
		"This is teh paragraph.",
		"** Child heading",
		"Child paragraph.",
		"* Second heading",
		"Another paragraph.",
	})
	vim.cmd.write()
	vim.wait(10000, function()
		return pcall(vim.treesitter.get_parser, 0, "org")
	end, 50)
	check(vim.bo.filetype == "org", "Org filetype not detected")
	check(vim.wo.spell, "Spell checking not enabled")
	check(vim.fn.maparg("<S-Tab>", "n"):find("global_cycle", 1, true), "Missing global cycling key")
	check(vim.fn.maparg("<Tab>", "n"):find("cycle", 1, true), "Missing local cycling key")
	vim.cmd("normal! zx")
	vim.api.nvim_win_set_cursor(0, { 4, 0 })
	check(vim.fn.foldlevel(4) > 0, "Org headings do not form folds")
	local states = {}
	for _ = 1, 3 do
		vim.api.nvim_feedkeys(vim.keycode("<S-Tab>"), "xt", false)
		vim.wait(80)
		states[#states + 1] = vim.fn.foldclosed(4) .. ":" .. vim.fn.foldclosed(6) .. ":" .. tostring(vim.wo.foldenable)
	end
	check(states[1] ~= states[2] or states[2] ~= states[3], "Shift Tab did not change real fold visibility")
	vim.cmd("normal! zR")
	local original_select = vim.ui.select
	local picked = false
	vim.ui.select = function(items, _, callback)
		check(
			vim.tbl_contains(items, "essay") and vim.tbl_contains(items, "report"),
			"Template picker missing builtins"
		)
		callback("report")
		picked = true
	end
	vim.cmd("OrgTemplate")
	check(
		vim.wait(5000, function()
			return picked
		end, 50),
		"Template picker did not finish"
	)
	vim.ui.select = original_select
	check(
		vim.api.nvim_buf_get_lines(0, 1, 2, false)[1] == "#+PDF_TEMPLATE: report",
		"Template choice not saved in Org metadata"
	)
	vim.api.nvim_win_set_cursor(0, { 5, 9 })
	vim.api.nvim_exec_autocmds("CursorHold", { buffer = 0 })
	local ns = vim.api.nvim_create_namespace("OrgWritingSpelling")
	local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })
	check(#marks > 0 and marks[1][4].virt_text[1][1]:find("the", 1, true), "Visible spelling corrections not produced")
	local select = vim.ui.select
	vim.ui.select = function(items, _, callback)
		check(vim.tbl_contains(items, "the"), "Correct spelling not offered")
		callback("the")
	end
	vim.api.nvim_feedkeys(vim.keycode("z="), "xt", false)
	vim.ui.select = select
	check(vim.api.nvim_get_current_line() == "This is the paragraph.", "Spelling replacement failed")
	-- A real async export through the editor, not just the CLI.
	vim.cmd("OrgPdf!")
	local pdf = path:gsub("%.org$", ".pdf")
	check(
		vim.wait(30000, function()
			return vim.fn.filereadable(pdf) == 1
		end, 100),
		"Editor PDF export did not finish"
	)
	local new_path = scratch .. "/org-writing-new-" .. vim.fn.getpid() .. ".org"
	local input = vim.ui.input
	local prompt_count = 0
	vim.ui.select = function(items, _, callback)
		check(vim.tbl_contains(items, "essay"), "New document picker missing essay")
		callback("essay")
	end
	vim.ui.input = function(_, callback)
		prompt_count = prompt_count + 1
		callback(prompt_count == 1 and new_path or "New essay acceptance test")
	end
	vim.cmd("OrgNew")
	check(
		vim.wait(5000, function()
			return vim.api.nvim_buf_get_name(0) == new_path
		end, 50),
		"New Org document creation did not finish"
	)
	vim.ui.input = input
	vim.ui.select = original_select
	check(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "#+TITLE: New essay acceptance test", "New title missing")
	check(vim.api.nvim_buf_get_lines(0, 3, 4, false)[1] == "#+PDF_TEMPLATE: essay", "New template missing")
	check(vim.fn.filereadable(new_path) == 0, "New document was unexpectedly written before save")
	local writing = require("config.org-writing")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "don't" })
	vim.api.nvim_win_set_cursor(0, { 1, 1 })
	check(writing.word_at_cursor().word == "don't", "Spelling must not split contractions")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "recieve", "recieve" })
	local pending
	vim.ui.select = function(_, _, callback)
		pending = callback
	end
	writing.spell_suggest()
	check(pending ~= nil, "Spelling picker callback missing")
	vim.api.nvim_buf_set_lines(0, 0, 1, false, {})
	pending("receive")
	vim.ui.select = original_select
	check(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "recieve", "Stale spell picker changed a different line")
	print(
		"PASS: Org parser, actual Shift-Tab visibility, template metadata, visible spelling suggestions, selected correction, editor PDF export"
	)
end
local ok, err = xpcall(main, debug.traceback)
if not ok then
	io.stderr:write(err .. "\n")
	vim.cmd("cquit 1")
else
	vim.cmd("qa!")
end
