-- Native key repeat drives actions. The timer only releases a cooldown, so
-- releasing a key cannot leave a queued launch/close running afterwards.
return function(keys, description, dispatcher, interval)
  local ready = true
  local cooldown
  cooldown = hl.timer(function()
    ready = true
    cooldown:set_enabled(false)
  end, { timeout = interval, type = "repeat" })
  cooldown:set_enabled(false)

  hl.unbind(keys)
  o.bind(keys, description, function()
    if not ready then return end
    ready = false
    cooldown:set_enabled(true)
    hl.dispatch(dispatcher)
  end, { repeating = true })

  -- Fast deliberate taps should each act, even within the cooldown window.
  hl.bind(keys, function()
    ready = true
    cooldown:set_enabled(false)
  end, { release = true })
end
