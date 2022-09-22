
local frequency = 0.8 -- Speed in seconds to check for clipboard changes. If you check too frequently, you will loose performance, if you check sparsely you will loose copies
local historySize = 300 -- How many items to keep on history
local labelLength = 70 -- How wide (in characters) the dropdown menu should be. Copies larger than this will have their label truncated and end with "…" (unicode for elipsis ...)
local honorClearContent = false --asmagill request. If any application clears the pasteboard, we also remove it from the history https://groups.google.com/d/msg/hammerspoon/skEeypZHOmM/Tg8QnEj_N68J
local pasteOnSelect = true -- Auto-type on click
local clipboardHistoryDeduplicated = true
local disallowCopyBlank = true
--local allowSelectOnDelete = true

local jumpcut = hs.menubar.new()
jumpcut:setTooltip("Clipboard History")
local pasteboard = require("hs.pasteboard") -- http://www.hammerspoon.org/docs/hs.pasteboard.html
local settings = require("hs.settings") -- http://www.hammerspoon.org/docs/hs.settings.html
local lastChanged = pasteboard.changeCount() -- displays how many times the pasteboard owner has changed // Indicates a new copy has been made

--Array to store the clipboard history
local clipboardHistory = settings.get("com.hs.clipboardhistory") or {} --If no history is saved on the system, create an empty history

function RemoveDuplicated(item)
  -- check duplicates first
  local duplicate_index = indexOf(clipboardHistory, item)
  if (duplicate_index ~= nil) then
    table.remove(clipboardHistory, duplicate_index)
  end
end

-- Append a history counter to the menu
function RefreshMenubarTitle()
  if (#clipboardHistory == 0) then
    jumpcut:setTitle("✂") -- Unicode magic
    return
  end

  jumpcut:setTitle("✂ ("..#clipboardHistory..")") -- updates the menu counter
end

function PutToPasteboard(item)
  pasteboard.setContents(item)
  hs.eventtap.keyStrokes(item)
  lastChanged = pasteboard.changeCount() -- Updates last_change to prevent item duplication when putting on paste
end

function ClipboardToPastboard(item, key)
  RemoveDuplicated(item)
  table.insert(clipboardHistory, item)
  ReloadData(clipboardHistory)

  if (pasteOnSelect) then
    PutToPasteboard(item)
    return
  end

  if (key.alt == true) then -- If the option/alt key is active when clicking on the menu, perform a "direct paste", without changing the clipboard
    hs.eventtap.keyStrokes(item) -- Defeating paste blocking http://www.hammerspoon.org/go/#pasteblock
    return
  end

  PutToPasteboard(item) -- Updates last_change to prevent item duplication when putting on paste
end

-- Clears the clipboard and history
function ClearAll()
  pasteboard.clearContents()
  clipboardHistory = {}
  ReloadData(clipboardHistory)
  hs.alert.show("Clipboard Cleared!", alertStyle)
end

-- Clears the last added to the history
function ClearLastItem()
  table.remove(clipboardHistory, #clipboardHistory)
  ReloadData(clipboardHistory)
end

function PasteboardToClipboard(item)
  -- check duplicates first
  if (clipboardHistoryDeduplicated == true) then
    RemoveDuplicated(item)
  end

  table.insert(clipboardHistory, item)

  if (#clipboardHistory > historySize) then
    local _clipboardHistory = {
      table.unpack(clipboardHistory, #clipboardHistory - historySize, #clipboardHistory)
    }
    clipboardHistory = _clipboardHistory
  end

  --Loop to enforce limit on qty of elements in history. Removes the oldest items
  --while (#clipboardHistory >= historySize) do
  --  table.remove(clipboardHistory, 1)
  --end

  if (#clipboardHistory == 0) then
  else
    hs.alert.show('⎘', alertStyle)
  end
  ReloadData(clipboardHistory)
end

function ReloadData(newHistory)
  settings.set("com.hs.clipboardhistory", newHistory) -- updates the saved history
  RefreshMenubarTitle() -- updates the menu counter
end

-- If the pasteboard owner has changed, we add the current item to our history and update the counter.
function HandlePasteboardEvent()
  local now = pasteboard.changeCount()
  if (now > lastChanged) then
    local currentClipboard = pasteboard.getContents()

    if (disallowCopyBlank and isBlankString(currentClipboard)) then
      -- Do nothing when disallow copy blank content
      return
    end

    -- asmagill requested this feature. It prevents the history from keeping items removed by password managers
    if (currentClipboard == nil and honorClearContent) then
      ClearLastItem()
    else
      PasteboardToClipboard(currentClipboard)
    end
    lastChanged = now -- save last updated time
  end
end

-- Dynamic menu by cmsj https://github.com/Hammerspoon/hammerspoon/issues/61#issuecomment-64826257
local jumpcutMenuLayoutFn = function(key)
  local menuData = {}
  if (#clipboardHistory == 0) then
    table.insert(menuData, {title="None", disabled = true}) -- If the history is empty, display "None"
  else
    for k, v in pairs(clipboardHistory) do
      if (string.len(v) > labelLength) then
        table.insert(
        menuData,
        1,
        { title=subStringUTF8(v,0,labelLength).."…", fn = function() ClipboardToPastboard(v,key) end }
      ) -- Truncate long strings for displaying
      else
        table.insert(menuData, 1, { title=v, fn = function() ClipboardToPastboard(v,key) end })
      end
    end
  end
  -- footer
  table.insert(menuData, { title="-" })
  table.insert(menuData, { title="Clear All", fn = function() ClearAll() end })
  -- if (key.alt == true or pasteOnSelect) then
  --    table.insert(menuData, { title="Direct Paste Mode ✍", disabled=true })
  --    hs.alert.show('Direct Paste Mode', alertStyle)
  -- end
  --if (key.ctrl == true or allowSelectOnDelete) then
  --   -- RemoveDuplicated(menuData)
  --   -- table.insert(menuData, { title="Direct Paste Mode ✍", disabled=true })
  --end
  return menuData
end

-- Checks for changes on the pasteboard. Is it possible to replace with eventtap?
PasteboardWatcher = hs.timer.new(frequency, HandlePasteboardEvent)
PasteboardWatcher:start()

RefreshMenubarTitle() --Avoid wrong title if the user already has something on his saved history
jumpcut:setMenu(jumpcutMenuLayoutFn)

hs.hotkey.bind({"cmd", "shift"}, "v", function()
  jumpcut:popupMenu(hs.mouse.absolutePosition())
end)
