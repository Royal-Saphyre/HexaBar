-- Minimap.lua
-- Minimap button via LibDataBroker + LibDBIcon (standard approach so it
-- behaves like every other minimap button: shift-drag to move by hand,
-- other broker-aware addons can list/hide it, etc). Left-click opens a
-- small dropdown with "Lock/Unlock Bars" and "Settings".

local LDB    = LibStub and LibStub:GetLibrary("LibDataBroker-1.1", true)
local LDBIcon = LibStub and LibStub:GetLibrary("LibDBIcon-1.0", true)

local dropdownFrame = CreateFrame("Frame", "HexaBarDropdown", UIParent, "UIDropDownMenuTemplate")

-- ---------------------------------------------------------------------
-- Settings panel (very small first pass: slot size / spacing / gryphon /
-- honeycomb toggle. A fuller options panel can replace this later.)
-- ---------------------------------------------------------------------

local settingsFrame

local function BuildSettingsFrame()
  if settingsFrame then return settingsFrame end

  local f = CreateFrame("Frame", "HexaBarSettingsFrame", UIParent)
  f:SetSize(260, 220)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -16)
  title:SetText("HexaBar Settings")

  local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -4, -4)

  -- Gryphon toggle
  local gryphonCheck = CreateFrame("CheckButton", "HexaBarGryphonCheck", f, "UICheckButtonTemplate")
  gryphonCheck:SetPoint("TOPLEFT", 20, -50)
  _G[gryphonCheck:GetName() .. "Text"]:SetText("Show gold gryphon endcaps")
  gryphonCheck:SetScript("OnClick", function(self)
    HexaBar.db.showGryphon = self:GetChecked() and true or false
    HexaBar:RefreshBars()
  end)

  -- Honeycomb toggle
  local honeyCheck = CreateFrame("CheckButton", "HexaBarHoneycombCheck", f, "UICheckButtonTemplate")
  honeyCheck:SetPoint("TOPLEFT", 20, -80)
  _G[honeyCheck:GetName() .. "Text"]:SetText("Honeycomb offset rows")
  honeyCheck:SetScript("OnClick", function(self)
    HexaBar.db.honeycomb = self:GetChecked() and true or false
    HexaBar:RefreshBars()
  end)

  -- Slot size slider
  local sizeSlider = CreateFrame("Slider", "HexaBarSizeSlider", f, "OptionsSliderTemplate")
  sizeSlider:SetPoint("TOPLEFT", 24, -120)
  sizeSlider:SetWidth(200)
  sizeSlider:SetMinMaxValues(24, 48)
  sizeSlider:SetValueStep(1)
  _G[sizeSlider:GetName() .. "Low"]:SetText("24")
  _G[sizeSlider:GetName() .. "High"]:SetText("48")
  _G[sizeSlider:GetName() .. "Text"]:SetText("Slot size")
  sizeSlider:SetScript("OnValueChanged", function(self, value)
    HexaBar.db.slotSize = math.floor(value)
    HexaBar:RefreshBars()
  end)

  -- Spacing slider
  local spaceSlider = CreateFrame("Slider", "HexaBarSpaceSlider", f, "OptionsSliderTemplate")
  spaceSlider:SetPoint("TOPLEFT", 24, -170)
  spaceSlider:SetWidth(200)
  spaceSlider:SetMinMaxValues(0, 16)
  spaceSlider:SetValueStep(1)
  _G[spaceSlider:GetName() .. "Low"]:SetText("0")
  _G[spaceSlider:GetName() .. "High"]:SetText("16")
  _G[spaceSlider:GetName() .. "Text"]:SetText("Spacing")
  spaceSlider:SetScript("OnValueChanged", function(self, value)
    HexaBar.db.slotSpacing = math.floor(value)
    HexaBar:RefreshBars()
  end)

  f.gryphonCheck = gryphonCheck
  f.honeyCheck = honeyCheck
  f.sizeSlider = sizeSlider
  f.spaceSlider = spaceSlider

  settingsFrame = f
  return f
end

local function ToggleSettings()
  local f = BuildSettingsFrame()
  if f:IsShown() then
    f:Hide()
    return
  end
  -- sync widgets to current saved values before showing
  f.gryphonCheck:SetChecked(HexaBar.db.showGryphon)
  f.honeyCheck:SetChecked(HexaBar.db.honeycomb)
  f.sizeSlider:SetValue(HexaBar.db.slotSize)
  f.spaceSlider:SetValue(HexaBar.db.slotSpacing)
  f:Show()
end

-- ---------------------------------------------------------------------
-- Dropdown menu (left-click on the minimap button)
-- ---------------------------------------------------------------------

local function DropdownInit(self, level)
  local info = UIDropDownMenu_CreateInfo()

  info.text = HexaBar.db.barsLocked and "Unlock Bars" or "Lock Bars"
  info.notCheckable = true
  info.func = function()
    HexaBar:SetBarsLocked(not HexaBar.db.barsLocked)
  end
  UIDropDownMenu_AddButton(info, level)

  info = UIDropDownMenu_CreateInfo()
  info.text = "Settings"
  info.notCheckable = true
  info.func = ToggleSettings
  UIDropDownMenu_AddButton(info, level)

  info = UIDropDownMenu_CreateInfo()
  info.text = "Close"
  info.notCheckable = true
  info.func = function() CloseDropDownMenus() end
  UIDropDownMenu_AddButton(info, level)
end

UIDropDownMenu_Initialize(dropdownFrame, DropdownInit, "MENU")

-- ---------------------------------------------------------------------
-- LibDataBroker launcher object
-- ---------------------------------------------------------------------

local function InitMinimap()
  if not LDB or not LDBIcon then
    HexaBar:Print("LibDataBroker or LibDBIcon missing - minimap button disabled.")
    return
  end

  local launcher = LDB:NewDataObject("HexaBar", {
    type = "launcher",
    text = "HexaBar",
    icon = "Interface\\AddOns\\HexaBar\\Textures\\minimap-icon",
    OnClick = function(self, buttonPressed)
      ToggleDropDownMenu(1, nil, dropdownFrame, self, 0, 0)
    end,
    OnTooltipShow = function(tooltip)
      tooltip:AddLine("HexaBar")
      tooltip:AddLine("|cffeda55fClick|r to open menu", 1, 1, 1)
    end,
  })

  LDBIcon:Register("HexaBar", launcher, HexaBar.db.minimap)
end

HexaBar:RegisterInit(InitMinimap)

-- ---------------------------------------------------------------------
-- Shared refresh hook so Bars.lua's layout re-runs after a settings change
-- ---------------------------------------------------------------------

function HexaBar:RefreshBars()
  -- Bars.lua registers its layout function under this name at init time.
  if self.LayoutAllBars then
    self:LayoutAllBars()
  end
end
