-- Hammerspoon config, linked from ~/.dotfiles/src/.config/hammerspoon/init.lua.
-- Hammerspoon reads it from ~/.config/hammerspoon because of the MJConfigFile default
-- set by `dotfiles` (see macos_defaults_list in utils.sh).

hs.autoLaunch(true)

-- Caps Lock input switching over Universal Control
--
-- macOS only switches the input source on Caps Lock ("Use Caps Lock to switch to and
-- from U.S.") for keyboards attached to this Mac. Through Universal Control, Caps Lock
-- on the other Mac's keyboard doesn't arrive as the Caps Lock key (key code 57): each
-- press arrives as two blips, one when the key goes down and one when it comes up, each
-- a modifier change with key code 255 that turns caps on and then off within a few
-- milliseconds. This switches the input source on the key-down blip, skips the key-up
-- one, and makes sure caps ends up off. A real Caps Lock key is left to macOS.

local LATIN = "com.apple.keylayout.US" -- the source Caps Lock switches to and from
local DEBUG = false -- print each modifier change to the Hammerspoon console

local lastOther = nil -- the non-Latin source to switch back to

local function otherSource()
  if lastOther then return lastOther end
  for _, layout in ipairs(hs.keycodes.layouts(true)) do
    if layout ~= LATIN then return layout end
  end
  for _, method in ipairs(hs.keycodes.methods(true)) do
    if method ~= LATIN then return method end
  end
end

-- Remember the last non-Latin source, as the built-in switch does
hs.keycodes.inputSourceChanged(function()
  local current = hs.keycodes.currentSourceID()
  if current ~= LATIN then lastOther = current end
end)

local capsWasOn = false
local keyIsDown = false -- the last blip was a key going down, so the next one is it coming up
local lastBlip = 0
local MAX_HOLD = 3 -- seconds; after this, the next blip counts as a new press (so a missed blip can't leave it out of step)

capsLockTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(event)
  local keyCode = event:getKeyCode()
  local capsOn = (event:rawFlags() & hs.eventtap.event.rawFlagMasks.alphaShift) ~= 0
  if DEBUG then
    print(string.format("modifier change: key %d, keyboard type %d, caps %s", keyCode,
      event:getProperty(hs.eventtap.event.properties.keyboardEventKeyboardType), capsOn and "on" or "off"))
  end

  -- Act only when caps turns on: other modifiers pressed while caps is on also
  -- carry the caps flag, and turning it off (by Universal Control or below) doesn't
  -- count as a press
  local turnedOn = capsOn and not capsWasOn
  capsWasOn = capsOn
  if not turnedOn then return false end
  if keyCode == hs.keycodes.map.capslock then return false end -- a real Caps Lock key: macOS handles it

  local now = hs.timer.secondsSinceEpoch()
  local keyComingUp = keyIsDown and now - lastBlip < MAX_HOLD
  keyIsDown = not keyComingUp
  lastBlip = now
  if DEBUG then print(keyComingUp and "  key up: skipped" or "  key down: switching") end
  if keyComingUp then return false end

  local target = hs.keycodes.currentSourceID() == LATIN and otherSource() or LATIN
  if target then hs.keycodes.currentSourceID(target) end
  hs.timer.doAfter(0.05, function() hs.hid.capslock.set(false) end)
  return false
end):start()

-- macOS disables an event tap that's slow to respond; turn it back on
capsLockWatchdog = hs.timer.doEvery(30, function()
  if not capsLockTap:isEnabled() then capsLockTap:start() end
end)
