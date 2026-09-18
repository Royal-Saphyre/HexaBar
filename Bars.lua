-- Bars.lua
-- HexaBar deliberately does NOT create new secure action buttons.
-- Spawning fresh SecureActionButtons for spellcasting is a common source
-- of taint/action-blocked bugs in 3.3.5. Instead this file RESKINS the
-- existing default Blizzard action buttons in place: same secure buttons,
-- same protected click handlers, same default screen position AND size --
-- only the button texture shape changes (square -> hexagon). Bars can
-- optionally be dragged to a new position via the minimap unlock menu,
-- but nothing is resized or re-spaced automatically.

local TEX_PATH = "Interface\\AddOns\\HexaBar\\Textures\\"

-- Each default bar: the frame that can be repositioned as a whole, and
-- the list of its child button names in order (for spacing/retexture).
local BAR_DEFS = {
  { frame = "MainMenuBar",         buttons = "ActionButton",          count = 12, isMain = true, vertical = false },
  { frame = "MultiBarBottomLeft",  buttons = "MultiBarBottomLeftButton",  count = 12, vertical = false },
  { frame = "MultiBarBottomRight", buttons = "MultiBarBottomRightButton", count = 12, vertical = false },
  { frame = "MultiBarLeft",        buttons = "MultiBarLeftButton",        count = 12, vertical = true },
  { frame = "MultiBarRight",       buttons = "MultiBarRightButton",       count = 12, vertical = true },
}

-- ---------------------------------------------------------------------
-- Retexture a single default action button as a hex slot
-- ---------------------------------------------------------------------

local function SkinButton(button)
  if not button or button.hexaBarSkinned then return end

  -- deliberately NOT resizing or repositioning - keep Blizzard's own
  -- size/anchors exactly as-is. Only the texture shape changes.

  local name = button:GetName()
  local normalTex = _G[name .. "NormalTexture"]
  if normalTex then normalTex:SetTexture(nil) end

  local icon = _G[name .. "Icon"]
  if icon then
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  end

  button:SetNormalTexture(TEX_PATH .. "hexagon-normal")
  button:SetPushedTexture(TEX_PATH .. "hexagon-pushed")
  button:SetHighlightTexture(TEX_PATH .. "hexagon-highlight", "ADD")
  button:SetCheckedTexture(TEX_PATH .. "hexagon-checked", "ADD")

  local border = button:CreateTexture(name .. "HexaBarBorder", "ARTWORK")
  border:SetAllPoints(button)
  border:SetTexture(TEX_PATH .. "hexagon-border")
  button.hexaBarBorder = border

  button.hexaBarSkinned = true
end

-- ---------------------------------------------------------------------
-- Lay out one bar's buttons: tight spacing, optional honeycomb offset
-- ---------------------------------------------------------------------

local function LayoutBar(def)
  for i = 1, def.count do
    local button = _G[def.buttons .. i]
    if button then
      SkinButton(button)
    end
  end
end

-- ---------------------------------------------------------------------
-- Gold gryphon endcaps -- main bar only, points at Blizzard's own art
-- ---------------------------------------------------------------------

local gryphonLeft, gryphonRight

local function ApplyGryphons()
  if not HexaBar.db.showGryphon then
    if gryphonLeft then gryphonLeft:Hide() end
    if gryphonRight then gryphonRight:Hide() end
    return
  end

  local firstButton = _G["ActionButton1"]
  local lastButton   = _G["ActionButton12"]
  if not firstButton or not lastButton then return end

  if not gryphonLeft then
    gryphonLeft = MainMenuBar:CreateTexture("HexaBarGryphonLeft", "OVERLAY")
    gryphonLeft:SetTexture("Interface\\MainMenuBar\\UI-MainMenuBar-Small-GryphonLeft")
    gryphonLeft:SetSize(60, 52)
  end
  if not gryphonRight then
    gryphonRight = MainMenuBar:CreateTexture("HexaBarGryphonRight", "OVERLAY")
    gryphonRight:SetTexture("Interface\\MainMenuBar\\UI-MainMenuBar-Small-GryphonRight")
    gryphonRight:SetSize(60, 52)
  end

  gryphonLeft:ClearAllPoints()
  gryphonLeft:SetPoint("RIGHT", firstButton, "LEFT", 4, -6)
  gryphonRight:ClearAllPoints()
  gryphonRight:SetPoint("LEFT", lastButton, "RIGHT", -4, -6)

  gryphonLeft:Show()
  gryphonRight:Show()
end

-- ---------------------------------------------------------------------
-- Drag-to-move per bar frame, gated by HexaBar.db.barsLocked
-- ---------------------------------------------------------------------

local function ApplyDrag(barFrame, def)
  barFrame:SetMovable(true)
  barFrame:EnableMouse(not HexaBar.db.barsLocked)
  barFrame:RegisterForDrag("LeftButton")

  barFrame:SetScript("OnDragStart", function(self)
    if not HexaBar.db.barsLocked then
      self:StartMoving()
    end
  end)

  barFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    HexaBar.db.barPositions[def.frame] = { point = point, relativePoint = relPoint, x = x, y = y }
  end)
end

local function RestorePosition(barFrame, def)
  local saved = HexaBar.db.barPositions[def.frame]
  if saved then
    barFrame:ClearAllPoints()
    barFrame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
  end
  -- if nothing saved, leave the bar at its default Blizzard anchor
end

-- ---------------------------------------------------------------------
-- Public: called by Minimap.lua's lock/unlock menu entry
-- ---------------------------------------------------------------------

function HexaBar:SetBarsLocked(locked)
  self.db.barsLocked = locked
  for _, def in ipairs(BAR_DEFS) do
    local barFrame = _G[def.frame]
    if barFrame then
      barFrame:EnableMouse(not locked)
    end
  end
  self:Print(locked and "Bars locked." or "Bars unlocked - drag to reposition.")
end

-- ---------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------

local function LayoutAllBars()
  for _, def in ipairs(BAR_DEFS) do
    LayoutBar(def)
  end
  ApplyGryphons()
end

-- exposed so Minimap.lua's settings panel can re-run layout live
-- after the user drags a size/spacing slider or flips a checkbox
HexaBar.LayoutAllBars = LayoutAllBars

local function InitBars()
  for _, def in ipairs(BAR_DEFS) do
    local barFrame = _G[def.frame]
    if barFrame then
      RestorePosition(barFrame, def)
      ApplyDrag(barFrame, def)
    end
  end
  LayoutAllBars()
end

HexaBar:RegisterInit(InitBars)
