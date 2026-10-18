-- Run from repository root: lua hypr/tests/repeat_bind_test.lua
local timers, presses, releases, actions = {}, {}, {}, {}
hl = {
  timer = function(callback, options)
    local timer = { enabled = true, callback = callback, options = options }
    function timer:set_enabled(value) self.enabled = value end
    timers[#timers + 1] = timer
    return timer
  end,
  unbind = function() end,
  bind = function(keys, callback, options)
    assert(options.release == true)
    releases[keys] = callback
  end,
  dispatch = function(action) actions[#actions + 1] = action end,
}
o = { bind = function(keys, description, callback, options)
  assert(options.repeating == true)
  presses[keys] = callback
end }
local bind = dofile("hypr/repeat_bind.lua")
bind("SUPER + W", "Close", "normal-close", 350)
assert(not timers[1].enabled and timers[1].options.timeout == 350)
presses["SUPER + W"]()
assert(#actions == 1 and actions[1] == "normal-close" and timers[1].enabled)
for _ = 1, 40 do presses["SUPER + W"]() end
assert(#actions == 1, "Repeated events must be throttled")
timers[1].callback()
assert(#actions == 1 and not timers[1].enabled, "Timers must never dispatch actions")
presses["SUPER + W"]()
assert(#actions == 2)
releases["SUPER + W"]()
assert(not timers[1].enabled, "Release must stop cooldown")
presses["SUPER + W"]()
assert(#actions == 3, "Fast deliberate taps must still work")
bind("SUPER + RETURN", "Terminal", "spawn-terminal", 350)
presses["SUPER + RETURN"]()
assert(#actions == 4 and actions[4] == "spawn-terminal", "Cooldowns must be independent")
releases["SUPER + RETURN"]()
assert(not timers[2].enabled)
print("PASS immediate action, repeat throttle, cooldown rearm, release cancellation, quick taps and independent bindings")
