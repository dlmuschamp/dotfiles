-- Workspace fullscreen preserves column widths, but scrolling can still refit
-- its viewport on exit, particularly when the fullscreen column is the last.
-- Remember the actual screen anchor, not a guessed column width or neighbour.
local saved = {}
local pending
local timer
local attempts = 0
timer = hl.timer(function()
  local restore = pending
  local w = hl.get_active_window()
  if not restore or not w or w.address ~= restore.address or w.fullscreen ~= 0 then
    pending = nil
    timer:set_enabled(false)
    return
  end
  local delta = restore.x - w.at.x
  if math.abs(delta) > 1 then
    hl.dispatch(hl.dsp.layout("move " .. tostring(delta)))
  end
  attempts = attempts + 1
  if attempts >= 4 then
    pending = nil
    timer:set_enabled(false)
  end
end, { timeout = 100, type = "repeat" })
timer:set_enabled(false)

return function(mode)
  return function()
    pending = nil
    timer:set_enabled(false)
    local w = hl.get_active_window()
    if not w then return end
    local address = w.address
    if w.fullscreen == 0 then
      saved[address] = { address = address, x = w.at.x }
    end
    hl.dispatch(hl.dsp.window.fullscreen({ mode = mode, layout_aware = false }))
    if w.fullscreen == 0 and saved[address] then
      pending = saved[address]
      saved[address] = nil
      attempts = 0
      timer:set_enabled(true)
    end
  end
end
