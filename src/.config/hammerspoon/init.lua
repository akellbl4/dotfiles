-- Hammerspoon config, linked from ~/.dotfiles/src/.config/hammerspoon/init.lua.
-- Hammerspoon reads it from ~/.config/hammerspoon because of the MJConfigFile default
-- set by `dotfiles` (see macos_defaults_list in utils.sh).

hs.autoLaunch(true)

-- Input source switching with Caps Lock, also over Universal Control
--
-- Universal Control doesn't send Caps Lock to the other Mac as a key: it copies the
-- Caps Lock on/off state, so the other Mac only sees caps toggle. `dotfiles capslock`
-- remaps Caps Lock to F18 on the Mac whose keyboard you type on; Universal Control sends
-- F18 as an ordinary key, and F18 here switches between U.S. and the last other input
-- source, like macOS's own Caps Lock switch, on whichever Mac you're typing into.

local LATIN = "com.apple.keylayout.US" -- the source F18 switches to and from

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

-- Right after a switch, macOS can still report the previous source for a moment, so
-- quick presses would "switch" to the source that's already on. Trust the source we
-- just switched to for a second instead.
local lastTarget, lastSwitchAt = nil, 0

local function switchInputSource()
  local now = hs.timer.secondsSinceEpoch()
  local current = (lastTarget and now - lastSwitchAt < 1) and lastTarget or hs.keycodes.currentSourceID()
  local target = current == LATIN and otherSource() or LATIN
  if not target then return end
  hs.keycodes.currentSourceID(target)
  lastTarget, lastSwitchAt = target, now
end

inputSourceHotkey = hs.hotkey.bind({}, "f18", switchInputSource)
