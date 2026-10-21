-- Explicit execution command, intentionally separate from non-executing OrgPdf.
local function export(open)
  if vim.bo.filetype ~= 'org' then
    return vim.notify('Open an Org file first', vim.log.levels.WARN)
  end
  local file = vim.api.nvim_buf_get_name(0)
  local buf = vim.api.nvim_get_current_buf()
  if file == '' then return vim.notify('Save the Org file first', vim.log.levels.WARN) end
  vim.ui.select({ 'Cancel', 'Run opted-in MATLAB blocks and export' }, {
    prompt = 'Run :plot yes blocks, add image paths/links, and export? Only run trusted code.',
  }, function(choice)
    if choice ~= 'Run opted-in MATLAB blocks and export' then return end
    -- Do not execute a different document if the user switched buffers in the prompt.
    if vim.api.nvim_buf_get_name(0) ~= file then
      return vim.notify('Document changed. Run OrgPlotPdf again.', vim.log.levels.WARN)
    end
    local saved, err = pcall(vim.cmd.update)
    if not saved then return vim.notify(tostring(err), vim.log.levels.ERROR) end
    local tick = vim.api.nvim_buf_get_changedtick(buf)
    local root = vim.fn.fnamemodify(vim.uv.fs_realpath(vim.fn.stdpath('config')), ':h')
    local args = { root .. '/bin/org-plot-pdf', file }
    if open then args[#args + 1] = '--open' end
    vim.notify('Running opted-in MATLAB plots, then building PDF...')
    vim.system(args, { text = true }, function(result)
      vim.schedule(function()
        -- The runner adds output headers/links, never MATLAB body edits. Reload
        -- only a buffer untouched since saving. Never discard edits made while
        -- MATLAB was running, or reload a different document.
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == file then
          if not vim.bo[buf].modified and vim.api.nvim_buf_get_changedtick(buf) == tick then
            vim.api.nvim_buf_call(buf, function()
              local autoread = vim.bo.autoread
              vim.bo.autoread = true
              local ok, reload_err = pcall(vim.cmd, 'silent checktime')
              vim.bo.autoread = autoread
              if not ok then vim.notify(tostring(reload_err), vim.log.levels.WARN) end
            end)
          else
            vim.notify('Buffer edited during plotting. Kept your edits. Reconcile any generated links on disk before saving.',
              vim.log.levels.WARN, { title = 'Org plot export' })
          end
        end
        local message = result.code == 0 and result.stdout
          or ((result.stdout or '') .. '\n' .. (result.stderr or ''))
        vim.notify(message,
          result.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR,
          { title = 'Org plot export' })
      end)
    end)
  end)
end
vim.api.nvim_create_user_command('OrgPlotPdf', function(opts) export(not opts.bang) end,
  { bang = true, force = true, desc = 'Confirm and execute opted-in MATLAB plots, then export PDF' })
-- The runner never uses a graphics cache: every opted-in block is rerun.
-- "Clean" means regenerate those outputs, not delete images or run disabled code.
vim.api.nvim_create_user_command('OrgCleanBuild', function(opts) export(not opts.bang) end,
  { bang = true, force = true, desc = 'Regenerate all enabled MATLAB graphics and rebuild PDF' })
vim.keymap.set('n', '<leader>owr', '<cmd>OrgCleanBuild<cr>',
  { desc = 'Clean build: regenerate plots and PDF' })
return { export = export }
