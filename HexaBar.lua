-- HexaBar.lua
-- Core bootstrap: saved variable defaults, event registration, addon init.
-- Bars.lua / QuickBind.lua / Minimap.lua all read from the HexaBar table
-- this file sets up, and hook into HexaBar:OnInit() to build their pieces
-- once saved variables are guaranteed loaded.

HexaBar = {}
HexaBar.version = GetAddOnMetadata("HexaBar", "Version") or "0.1.0"

-- ---------------------------------------------------------------------
-- Defaults
-- ---------------------------------------------------------------------

local defaults = {
  slotSize    = 36,   -- px, width/height of each hex button
  slotSpacing = 4,     -- px gap between hex buttons
  honeycomb   = true,   -- offset alternating rows for a true hex-grid look
  showGryphon = true,    -- gold gryphon endcaps on the main bar
  barsLocked  = true,     -- drag-to-move disabled until unlocked via minimap menu
  barPositions = {},       -- [barName] = { point, relativeTo, relativePoint, x, y }
}

local charDefaults = {
  quickBindLastUsed = nil,
}

local minimapDefaults = {
  hide = false,
  minimapPos = 220, -- angle in degrees around the minimap
}

-- ---------------------------------------------------------------------
-- Deep-copy helper so we never hand out references into `defaults`
-- ---------------------------------------------------------------------

local function CopyDefaults(src, dst)
  dst = dst or {}
  for k, v in pairs(src) do
    if type(v) == "table" then
      dst[k] = CopyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
  return dst
end

-- ---------------------------------------------------------------------
-- Event handlers (referenced directly from HexaBar.xml)
-- ---------------------------------------------------------------------

function HexaBar_OnLoad(self)
  self:RegisterEvent("ADDON_LOADED")
  self:RegisterEvent("PLAYER_LOGIN")
end

function HexaBar_OnEvent(self, event, ...)
  if event == "ADDON_LOADED" then
    local loadedAddon = ...
    if loadedAddon == "HexaBar" then
      HexaBar:InitSavedVariables()
      self:UnregisterEvent("ADDON_LOADED")
    end
  elseif event == "PLAYER_LOGIN" then
    HexaBar:OnInit()
  end
end

-- ---------------------------------------------------------------------
-- Saved variable bootstrap
-- ---------------------------------------------------------------------

function HexaBar:InitSavedVariables()
  HexaBarDB = CopyDefaults(defaults, HexaBarDB)
  HexaBarDB.minimap = CopyDefaults(minimapDefaults, HexaBarDB.minimap)

  HexaBarCharDB = CopyDefaults(charDefaults, HexaBarCharDB)

  self.db = HexaBarDB
  self.charDb = HexaBarCharDB
end

-- ---------------------------------------------------------------------
-- Post-login init. Bars.lua, QuickBind.lua and Minimap.lua each register
-- a callback here instead of hooking PLAYER_LOGIN themselves, so init
-- order is explicit and saved variables are guaranteed ready first.
-- ---------------------------------------------------------------------

HexaBar.initCallbacks = {}

function HexaBar:RegisterInit(callback)
  table.insert(self.initCallbacks, callback)
end

function HexaBar:OnInit()
  if not self.db then
    -- ADDON_LOADED should always fire before PLAYER_LOGIN, but guard anyway
    self:InitSavedVariables()
  end

  for _, callback in ipairs(self.initCallbacks) do
    local ok, err = pcall(callback)
    if not ok then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff4040HexaBar:|r error during init - " .. tostring(err))
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage(string.format("|cffc9a55cHexaBar|r v%s loaded.", self.version))
end

-- ---------------------------------------------------------------------
-- Small shared utility other files use
-- ---------------------------------------------------------------------

function HexaBar:Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffc9a55cHexaBar:|r " .. tostring(msg))
end
