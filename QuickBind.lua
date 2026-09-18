-- QuickBind.lua
-- Adds a "Quick Bind" button to the Game Menu (Esc menu). Clicking it closes
-- the menu and puts every reskinned action button into bind mode: hover a
-- slot, press a key (modifiers included), and it's bound immediately.

local BAR_DEFS_BUTTONS = {
  "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
  "MultiBarLeftButton", "MultiBarRightButton",
}

local bindModeActive = false
local hoveredButton = nil
local keyListenerFrame = CreateFrame("Frame", "HexaBarKeyListener")
keyListenerFrame:Hide()
keyListenerFrame:EnableKeyboard(true)

-- ---------------------------------------------------------------------
-- Visual "press a key" state on hex slots while bind mode is active
-- ---------------------------------------------------------------------

local function ForEachActionButton(fn)
  for _, prefix in ipairs(BAR_DEFS_BUTTONS) do
    for i = 1, 12 do
      local button = _G[prefix .. i]
      if button then fn(button) end
    end
  end
end

local function FlashOn(button)
  if button.hexaBarBorder then
    button.hexaBarBorder:SetVertexColor(1, 0.9, 0.4)
  end
  if not button.hexaBarBindPrompt then
    local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText("+")
    button.hexaBarBindPrompt = fs
  end
  button.hexaBarBindPrompt:Show()
end

local function FlashOff(button)
  if button.hexaBarBorder then
    button.hexaBarBorder:SetVertexColor(1, 1, 1)
  end
  if button.hexaBarBindPrompt then
    button.hexaBarBindPrompt:Hide()
  end
end

-- ---------------------------------------------------------------------
-- Binding logic
-- ---------------------------------------------------------------------

local function GetActionSlotBindingName(button)
  -- Default Blizzard buttons already carry a binding action name via
  -- their action ID, e.g. "ACTIONBUTTON1", "MULTIACTIONBAR1BUTTON1".
  -- We read it straight off the button so we bind the same command
  -- the default keybind UI would.
  return button:GetAttribute("*type1") == "action" and button.bindingAction or nil
end

-- Map default button names to their binding command names, since not
-- every frame exposes `.bindingAction` directly on retail-3.3.5 XML.
local BINDING_COMMAND_MAP = {}
do
  for i = 1, 12 do
    BINDING_COMMAND_MAP["ActionButton" .. i] = "ACTIONBUTTON" .. i
    BINDING_COMMAND_MAP["MultiBarBottomLeftButton" .. i] = "MULTIACTIONBAR1BUTTON" .. i
    BINDING_COMMAND_MAP["MultiBarBottomRightButton" .. i] = "MULTIACTIONBAR2BUTTON" .. i
    BINDING_COMMAND_MAP["MultiBarLeftButton" .. i] = "MULTIACTIONBAR3BUTTON" .. i
    BINDING_COMMAND_MAP["MultiBarRightButton" .. i] = "MULTIACTIONBAR4BUTTON" .. i
  end
end

local function BuildKeyString()
  local key = keyListenerFrame.pendingKey
  if not key then return nil end
  local parts = {}
  if IsShiftKeyDown() then table.insert(parts, "SHIFT-") end
  if IsControlKeyDown() then table.insert(parts, "CTRL-") end
  if IsAltKeyDown() then table.insert(parts, "ALT-") end
  table.insert(parts, key)
  return table.concat(parts)
end

local function RefreshHotkeyText(button)
  if ActionButton_UpdateHotkeys then
    ActionButton_UpdateHotkeys(button, button:GetName())
  end
end

local function DoBind(button, keyString)
  local command = BINDING_COMMAND_MAP[button:GetName()]
  if not command then return end

  local existingCommand = GetBindingAction(keyString)
  if existingCommand and existingCommand ~= "" and existingCommand ~= command then
    StaticPopupDialogs["HEXABAR_CONFIRM_REBIND"] = {
      text = "\"%s\" is already bound to %s.\nOverwrite it and bind to this slot instead?",
      button1 = "Overwrite",
      button2 = "Cancel",
      OnAccept = function()
        SetBinding(keyString, command)
        SaveBindings(GetCurrentBindingSet())
        RefreshHotkeyText(button)
        HexaBar:Print(keyString .. " rebound.")
      end,
      timeout = 0,
      whileDead = true,
      hideOnEscape = true,
    }
    StaticPopup_Show("HEXABAR_CONFIRM_REBIND", keyString, existingCommand)
    return
  end

  SetBinding(keyString, command)
  SaveBindings(GetCurrentBindingSet())
  RefreshHotkeyText(button)
  HexaBar:Print(keyString .. " bound.")
end

-- ---------------------------------------------------------------------
-- Enter / exit bind mode
-- ---------------------------------------------------------------------

local function ExitBindMode()
  bindModeActive = false
  keyListenerFrame:Hide()
  ForEachActionButton(FlashOff)
  hoveredButton = nil
  HexaBar:Print("Quick Bind closed.")
end

local function EnterBindMode()
  bindModeActive = true
  keyListenerFrame:Show()
  ForEachActionButton(function(button)
    FlashOn(button)
    if not button.hexaBarBindHooked then
      button:HookScript("OnEnter", function(self) if bindModeActive then hoveredButton = self end end)
      button:HookScript("OnLeave", function(self) if bindModeActive and hoveredButton == self then hoveredButton = nil end end)
      button.hexaBarBindHooked = true
    end
  end)
  HexaBar:Print("Quick Bind active. Hover a slot and press a key. Escape to finish.")
end

keyListenerFrame:SetScript("OnKeyDown", function(self, key)
  if key == "ESCAPE" then
    ExitBindMode()
    return
  end
  if key == "UNKNOWN" or not hoveredButton then return end
  -- ignore bare modifier presses; wait for the actual key
  if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
    return
  end

  self.pendingKey = key
  local keyString = BuildKeyString()
  self.pendingKey = nil
  if keyString then
    DoBind(hoveredButton, keyString)
  end
end)

-- ---------------------------------------------------------------------
-- Game menu button injection
-- ---------------------------------------------------------------------

local function InsertGameMenuButton()
  if HexaBarQuickBindButton then return end

  local logoutButton = GameMenuButtonLogout
  if not logoutButton then return end

  -- known default GameMenuFrame button order for 3.3.5. Some of these
  -- may not exist/be shown depending on context (e.g. Store, WhatsNew) -
  -- we skip anything nil or hidden.
  local order = {
    "GameMenuButtonHelp", "GameMenuButtonWhatsNew", "GameMenuButtonStore",
    "GameMenuButtonOptions", "GameMenuButtonUIOptions", "GameMenuButtonKeybindings",
    "GameMenuButtonMacros", "GameMenuButtonAddons", "GameMenuButtonLogout", "GameMenuButtonQuit",
  }

  -- find Logout's position in that list so we know what to anchor Quick
  -- Bind directly under, then re-anchor everything AFTER Logout below
  -- our new button instead.
  local logoutIndex
  for idx, name in ipairs(order) do
    if _G[name] == logoutButton then
      logoutIndex = idx
      break
    end
  end

  local btn = CreateFrame("Button", "HexaBarQuickBindButton", GameMenuFrame, "GameMenuButtonTemplate")
  btn:SetText("Quick Bind")
  btn:SetPoint("TOP", logoutButton, "BOTTOM", 0, -1)
  btn:SetScript("OnClick", function()
    HideUIPanel(GameMenuFrame)
    EnterBindMode()
  end)

  local prev = btn
  if logoutIndex then
    for idx = logoutIndex + 1, #order do
      local f = _G[order[idx]]
      if f and f:IsShown() then
        f:ClearAllPoints()
        f:SetPoint("TOP", prev, "BOTTOM", 0, -1)
        prev = f
      end
    end
  end

  GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + btn:GetHeight() + 1)
end

-- ---------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------

local function InitQuickBind()
  if GameMenuFrame then
    GameMenuFrame:HookScript("OnShow", InsertGameMenuButton)
  end
end

HexaBar:RegisterInit(InitQuickBind)
