local M = {}
local ns = vim.api.nvim_create_namespace("OrgWritingSpelling")

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Org writing" })
end

-- Resolve from the tracked config, so a freshly bootstrapped machine works too.
local function exporter()
  local root = vim.fn.fnamemodify(vim.uv.fs_realpath(vim.fn.stdpath("config")), ":h")
  local script = root .. "/bin/org-pdf"
  return vim.fn.executable(script) == 1 and script or "org-pdf"
end

local function run(args, done)
  local command = { exporter() }
  vim.list_extend(command, args)
  local ok, err = pcall(vim.system, command, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        notify(vim.trim(result.stderr or "") ~= "" and result.stderr or "Export command failed", vim.log.levels.ERROR)
      elseif done then
        done(vim.trim(result.stdout or ""))
      end
    end)
  end)
  if not ok then
    notify(tostring(err), vim.log.levels.ERROR)
  end
end

function M.choose_template(callback)
  run({ "--list-templates" }, function(output)
    local templates = vim.split(output, "\n", { trimempty = true })
    vim.ui.select(templates, { prompt = "PDF template" }, function(choice)
      if choice then
        callback(choice)
      end
    end)
  end)
end

function M.set_template(name)
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].filetype ~= "org" then
    return notify("Open an Org document first", vim.log.levels.WARN)
  end
  local function apply(choice)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if not vim.bo[buf].modifiable then
      return notify("This document is not modifiable", vim.log.levels.WARN)
    end
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local block
    local found = false
    for i, line in ipairs(lines) do
      local upper = line:upper()
      if not block and upper:match("^%*+%s") then
        break
      end
      if block then
        if upper:match("^%s*#%+END_" .. block .. "%s*$") then
          block = nil
        end
      elseif upper:match("^%s*#%+BEGIN_") then
        block = upper:match("^%s*#%+BEGIN_(%S+)")
      elseif upper:match("^%s*#%+PDF_TEMPLATE:") then
        vim.api.nvim_buf_set_lines(buf, i - 1, i, false, { "#+PDF_TEMPLATE: " .. choice })
        found = true
      end
    end
    if not found then
      vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "#+PDF_TEMPLATE: " .. choice })
    end
  end
  if name and name ~= "" then
    apply(name)
  else
    M.choose_template(apply)
  end
end

function M.new_document()
  M.choose_template(function(template)
    vim.ui.input({ prompt = "New Org file: ", default = vim.fn.getcwd() .. "/", completion = "file" }, function(path)
      if not path or path == "" then
        return
      end
      path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
      if not path:match("%.org$") then
        path = path .. ".org"
      end
      if vim.uv.fs_stat(path) or vim.fn.bufnr(path) ~= -1 then
        return notify("That file or buffer already exists. Open it instead.", vim.log.levels.WARN)
      end
      local title = vim.fn.fnamemodify(path, ":t:r"):gsub("[_-]", " ")
      vim.ui.input({ prompt = "Title: ", default = title }, function(answer)
        if not answer then
          return
        end
        local parent = vim.fn.fnamemodify(path, ":h")
        vim.fn.mkdir(parent, "p")
        -- Recheck after the asynchronous prompt, never overwrite another buffer.
        if vim.uv.fs_stat(path) or vim.fn.bufnr(path) ~= -1 then
          return notify("File was created while the prompt was open", vim.log.levels.WARN)
        end
        vim.cmd.edit(vim.fn.fnameescape(path))
        vim.api.nvim_buf_set_lines(0, 0, -1, false, {
          "#+TITLE: " .. answer,
          "#+AUTHOR: Damian Luciano Muschamp",
          "#+DATE: " .. os.date("%B %d, %Y"),
          "#+PDF_TEMPLATE: " .. template,
          "#+INSTRUCTOR: Instructor Name",
          "#+COURSE: Course Name",
          "#+OPTIONS: toc:nil num:nil",
          "",
          "* Introduction",
          "",
          "",
        })
        vim.api.nvim_win_set_cursor(0, { 10, 0 })
        notify("Write your text, then :OrgPdf. Use $...$ for Typst math.")
      end)
    end)
  end)
end

function M.export(template, open)
  if vim.bo.filetype ~= "org" then
    return notify("PDF export expects an Org file", vim.log.levels.WARN)
  end
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    return notify("Save this document as a .org file first", vim.log.levels.WARN)
  end
  local saved, err = pcall(vim.cmd.update)
  if not saved then
    return notify(tostring(err), vim.log.levels.ERROR)
  end
  local args = { path }
  if template and template ~= "" then
    vim.list_extend(args, { "--template", template })
  end
  if open ~= false then
    table.insert(args, "--open")
  end
  notify("Building PDF…")
  run(args, function(output)
    notify(output ~= "" and output or "PDF exported")
  end)
end

function M.import_template()
  vim.ui.input({ prompt = "Pandoc Typst template (.typ): ", completion = "file" }, function(path)
    if not path or path == "" then
      return
    end
    run({ "--import-template", vim.fn.expand(path) }, function(output)
      notify(output ~= "" and output or "Template imported. Use :OrgTemplate to choose it.")
    end)
  end)
end

-- Return the keyword under the cursor and its exact byte range, without
-- changing registers, selection, search history, or the jump list.
function M.word_at_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local offset = 0
  while offset < #line do
    local match = vim.fn.matchstrpos(line, [[\k\+\%(['’]\k\+\)*]], offset)
    if match[2] < 0 then
      return
    end
    if match[2] <= cursor[2] and cursor[2] < match[3] then
      return { word = match[1], start = match[2], finish = match[3], row = cursor[1] - 1, line = line }
    end
    offset = match[3]
  end
end

function M.spell_suggest()
  local target = M.word_at_cursor()
  if not target then
    return
  end
  local buf = vim.api.nvim_get_current_buf()
  local changedtick = vim.api.nvim_buf_get_changedtick(buf)
  local choices = vim.fn.spellsuggest(target.word, 12)
  if #choices == 0 then
    return notify("No spelling suggestions for " .. target.word)
  end
  vim.ui.select(choices, { prompt = "Replace “" .. target.word .. "” with" }, function(choice)
    if not choice or not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if
      vim.api.nvim_buf_get_changedtick(buf) ~= changedtick
      or vim.api.nvim_buf_get_lines(buf, target.row, target.row + 1, false)[1] ~= target.line
    then
      return notify("Line changed while choosing a correction. Try again.", vim.log.levels.WARN)
    end
    -- Text edits can relocate cursors inside or after the replaced word.
    -- Preserve each window's current view, not the position when the picker opened.
    local views = {}
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      views[win] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
    end
    vim.api.nvim_buf_set_text(buf, target.row, target.start, target.row, target.finish, { choice })
    for win, view in pairs(views) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        vim.api.nvim_win_call(win, function()
          vim.fn.winrestview(view)
        end)
      end
    end
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  end)
end

function M.spell_preview()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if not vim.wo.spell or vim.api.nvim_get_mode().mode ~= "n" then
    return
  end
  local target = M.word_at_cursor()
  -- With no argument spellbadword() searches the buffer and moves the cursor.
  -- Inspect only the word's text so idle previews never navigate the document.
  if not target or vim.fn.spellbadword(target.word)[1] ~= target.word then
    return
  end
  local choices = vim.fn.spellsuggest(target.word, 3)
  if #choices == 0 then
    return
  end
  vim.api.nvim_buf_set_extmark(buf, ns, target.row, 0, {
    virt_text = { { "  → " .. table.concat(choices, " · ") .. "  [z= to choose]", "DiagnosticInfo" } },
    virt_text_pos = "eol",
  })
end

function M.setup()
  vim.api.nvim_create_user_command("OrgNew", M.new_document, {})
  vim.api.nvim_create_user_command("OrgTemplate", function(opts)
    M.set_template(opts.args)
  end, { nargs = "?" })
  vim.api.nvim_create_user_command("OrgTemplateImport", M.import_template, {})
  vim.api.nvim_create_user_command("OrgPdf", function(opts)
    M.export(opts.args, not opts.bang)
  end, { nargs = "?", bang = true })
  vim.api.nvim_create_user_command("SpellSuggest", M.spell_suggest, {})
  local mappings = {
    { "n", M.new_document, "New Org document" },
    {
      "t",
      function()
        M.set_template()
      end,
      "Choose PDF template",
    },
    { "e", M.export, "Export PDF and open" },
    { "i", M.import_template, "Import PDF template" },
    { "s", M.spell_suggest, "Spelling suggestions" },
  }
  for _, mapping in ipairs(mappings) do
    vim.keymap.set("n", "<leader>ow" .. mapping[1], mapping[2], { desc = mapping[3] })
  end
  local ok, wk = pcall(require, "which-key")
  if ok then
    wk.add({ { "<leader>ow", group = "writing" } })
  end
  local group = vim.api.nvim_create_augroup("OrgWriting", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "org", "markdown", "text", "typst" },
    callback = function(event)
      vim.opt_local.spell = true
      vim.opt_local.spelllang = { "en_us" }
      vim.keymap.set("n", "z=", M.spell_suggest, { buffer = event.buf, desc = "Choose spelling correction" })
      vim.api.nvim_create_autocmd("CursorHold", { group = group, buffer = event.buf, callback = M.spell_preview })
      vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
        group = group,
        buffer = event.buf,
        callback = function()
          vim.api.nvim_buf_clear_namespace(event.buf, ns, 0, -1)
        end,
      })
    end,
  })
end

return M
