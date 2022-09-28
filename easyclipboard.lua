
local pasteboard = hs.pasteboard

local settings = hs.settings
local sharedClipboardHistoryKey = "com.hs.clipboardHistoryDemo"
local clipboardHistory = settings.get(sharedClipboardHistoryKey) or {}

local jumpcut = hs.menubar.new()
jumpcut:setTooltip("EasyClipboard")
jumpcut:setTitle("✂")

local function reloadData()
  settings.set(sharedClipboardHistoryKey, clipboardHistory)
end

local function pasteboardToClipboard(item)
  hs.alert.show("⎘")
  table.insert(clipboardHistory, item)
  reloadData()
end

local function handlePastboardEvent()
  local item = pasteboard.getContents()
  pasteboardToClipboard(item)
end

local function clipboardToPasteboard(item)
  pasteboard.setContents(item)
  hs.eventtap.keyStroke({ "cmd" }, "v")
end

local function clearAll()
  pasteboard.clearContents()
  clipboardHistory = {}
  reloadData()
  hs.alert.show("Clipboard Cleared!")
end

local clipboardLayoutFn = function(key)
  local menuData = {}
  if (#clipboardHistory == 0) then
    table.insert(menuData, { title="None", disabled = true })
  else
    for k, v in pairs(clipboardHistory) do
      table.insert(menuData, 1, { title=v, fn = function() clipboardToPasteboard(v) end })
    end
  end
  table.insert(menuData, { title="-" } )
  table.insert(menuData, { title="Clear All", fn = function() clearAll() end })
  return menuData
end
jumpcut:setMenu(clipboardLayoutFn)


reloadData()
PasteboardWatcher = hs.pasteboard.watcher.new(handlePastboardEvent)
PasteboardWatcher:start()

hs.hotkey.bind({"cmd", "shift"}, "v", function()
  jumpcut:popupMenu(hs.mouse.absolutePosition(), true)
end)
