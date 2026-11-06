-- Hammerspoon config, linked from ~/.dotfiles/src/.config/hammerspoon/init.lua.
-- Hammerspoon reads it from ~/.config/hammerspoon because of the MJConfigFile default
-- set by `dotfiles` (see macos_defaults_list in utils.sh).

hs.autoLaunch(true)

-- Caps Lock input switching over Universal Control
--
-- macOS only switches the input source on Caps Lock ("Use Caps Lock to switch to and
-- from U.S.") for keyboards attached to this Mac. Keys typed on another Mac's keyboard
-- through Universal Control arrive as events posted by a process, so Caps Lock only
-- toggles caps there. This switches the input source for those presses and turns caps
-- back off. Presses from a real keyboard come from the hardware (source pid 0) and are
-- left to macOS.

local LATIN = "com.apple.keylayout.US" -- the source Caps Lock switches to and from
local DEBUG = false -- print each Caps Lock event to the Hammerspoon console

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

capsLockTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(event)
  if event:getKeyCode() ~= hs.keycodes.map.capslock then return false end

  local pid = event:getProperty(hs.eventtap.event.properties.eventSourceUnixProcessID)
  local capsOn = (event:rawFlags() & hs.eventtap.event.rawFlagMasks.alphaShift) ~= 0
  if DEBUG then print(string.format("caps lock event from pid %d, caps %s", pid, capsOn and "on" or "off")) end
  if pid == 0 then return false end -- a real keyboard: macOS handles it

  -- Caps is turned back off after every switch, so each press turns it on.
  -- A key release or that reset arrives with caps off: skip it, so every
  -- press switches once however fast they come
  if not capsOn then return false end

  local target = hs.keycodes.currentSourceID() == LATIN and otherSource() or LATIN
  if target then hs.keycodes.currentSourceID(target) end
  hs.timer.doAfter(0.05, function() hs.hid.capslock.set(false) end)
  return false
end):start()

-- macOS disables an event tap that's slow to respond; turn it back on
capsLockWatchdog = hs.timer.doEvery(30, function()
  if not capsLockTap:isEnabled() then capsLockTap:start() end
end)
