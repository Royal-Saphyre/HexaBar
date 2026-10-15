-- QuickBind.lua (standalone - no HexaBar needed)
-- Adds a "Quick Bind" button to the Game Menu (Esc menu). Clicking it closes
-- the menu and puts every reskinned action button into bind mode: hover a
-- slot, press a key (modifiers included), then choose whether it goes on
-- Key 1 or Key 2 (same slots as the default Key Bindings window).

local BAR_DEFS_BUTTONS = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarLeftButton", "MultiBarRightButton",
}

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd200QuickBind:|r " .. tostring(msg))
end

local bindModeActive = false
local hoveredButton = nil

local keyListenerFrame = CreateFrame("Frame", "QuickBindKeyListener")
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
    if not button.qbOverlay then
        local tex = button:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints(button)
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:SetVertexColor(1, 0.9, 0.4, 0.35)
        tex:SetBlendMode("ADD")
        button.qbOverlay = tex
    end
    button.qbOverlay:Show()
    if not button.qbBindPrompt then
        local fs = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("CENTER")
        fs:SetText("+")
        button.qbBindPrompt = fs
    end
    button.qbBindPrompt:Show()
end

local function FlashOff(button)
    if button.qbOverlay then button.qbOverlay:Hide() end
    if button.qbBindPrompt then button.qbBindPrompt:Hide() end
end

-- ---------------------------------------------------------------------
-- Binding logic
-- ---------------------------------------------------------------------

-- Map default button names to their binding command names.
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

local function BuildKeyString(key)
    local parts = {}
    if IsShiftKeyDown() then table.insert(parts, "SHIFT-") end
    if IsControlKeyDown() then table.insert(parts, "CTRL-") end
    if IsAltKeyDown() then table.insert(parts, "ALT-") end
    table.insert(parts, key)
    return table.concat(parts)
end

local function PrettyCommandName(command)
    return _G["BINDING_NAME_" .. command] or command
end

-- Update the little hotkey text on the button right away.
local function RefreshHotkeyText(button, command)
    local hotkey = _G[button:GetName() .. "HotKey"]
    if not hotkey then return end
    local key = GetBindingKey(command)
    if key then
        hotkey:SetText(GetBindingText(key, "KEY_", 1))
        hotkey:Show()
    else
        hotkey:SetText("")
    end
end

-- slot = 1 -> new key becomes Key 1 (the old Key 1 is replaced, Key 2 is kept)
-- slot = 2 -> new key becomes Key 2 (Key 1 is kept, the old Key 2 is replaced)
local function ApplyBinding(button, command, keyString, slot)
    local key1, key2 = GetBindingKey(command)

    if slot == 1 then
        if key1 then SetBinding(key1) end
        if key2 then SetBinding(key2) end
        SetBinding(keyString, command)
        -- put the old Key 2 back so it stays in the second slot
        if key2 and key2 ~= keyString then
            SetBinding(key2, command)
        end
    else
        if key1 == keyString then
            Print(keyString .. " is already on Key 1 of this slot.")
            return
        end
        if key2 then SetBinding(key2) end
        SetBinding(keyString, command)
        if not key1 then
            Print("Slot had no Key 1, so " .. keyString .. " went on Key 1.")
        end
    end

    SaveBindings(GetCurrentBindingSet())
    RefreshHotkeyText(button, command)

    local newKey1, newKey2 = GetBindingKey(command)
    local slotUsed = (newKey1 == keyString) and 1 or 2
    Print(keyString .. " bound to Key " .. slotUsed .. ".")
end

-- Overwrite warning (only shown when the key is used by another command)
StaticPopupDialogs["QUICKBIND_CONFIRM_REBIND"] = {
    text = "\"%s\" is already bound to %s.\nOverwrite it and bind to this slot instead?",
    button1 = "Overwrite",
    button2 = "Cancel",
    OnAccept = function(self, data)
        if data then
            ApplyBinding(data.button, data.command, data.keyString, data.slot)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

local function TryBind(button, command, keyString, slot)
    local existing = GetBindingAction(keyString)
    if existing and existing ~= "" and existing ~= command then
        StaticPopup_Show("QUICKBIND_CONFIRM_REBIND", keyString, PrettyCommandName(existing),
            { button = button, command = command, keyString = keyString, slot = slot })
        return
    end
    ApplyBinding(button, command, keyString, slot)
end

-- ---------------------------------------------------------------------
-- "Key 1 or Key 2?" chooser
-- ---------------------------------------------------------------------

local chooser

local function CreateChooser()
    local f = CreateFrame("Frame", "QuickBindSlotChooser", UIParent)
    f:SetWidth(320)
    f:SetHeight(120)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:EnableMouse(true)
    f:Hide()

    f.text = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    f.text:SetPoint("TOP", f, "TOP", 0, -22)
    f.text:SetWidth(280)

    local function MakeButton(label, point, x)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetWidth(90)
        b:SetHeight(24)
        b:SetPoint(point, f, "BOTTOM", x, 20)
        b:SetText(label)
        return b
    end

    f.key1Button = MakeButton("Key 1", "BOTTOM", -100)
    f.key2Button = MakeButton("Key 2", "BOTTOM", 0)
    f.cancelButton = MakeButton("Cancel", "BOTTOM", 100)

    local function Choose(slot)
        local button, command, keyString = f.button, f.command, f.keyString
        f:Hide()
        if button and command and keyString then
            TryBind(button, command, keyString, slot)
        end
    end

    f.key1Button:SetScript("OnClick", function() Choose(1) end)
    f.key2Button:SetScript("OnClick", function() Choose(2) end)
    f.cancelButton:SetScript("OnClick", function() f:Hide() end)

    return f
end

local function ShowChooser(button, command, keyString)
    if not chooser then chooser = CreateChooser() end
    chooser.button = button
    chooser.command = command
    chooser.keyString = keyString

    local k1, k2 = GetBindingKey(command)
    local function Show(k) return k and GetBindingText(k, "KEY_") or "Not Bound" end
    chooser.text:SetText("Bind |cffffd200" .. keyString .. "|r to " ..
        PrettyCommandName(command) .. "?\n\nCurrent: Key 1 = " .. Show(k1) ..
        ", Key 2 = " .. Show(k2))
    chooser:SetHeight(140)
    chooser:Show()
end

-- ---------------------------------------------------------------------
-- Enter / exit bind mode
-- ---------------------------------------------------------------------

local function ExitBindMode()
    bindModeActive = false
    keyListenerFrame:Hide()
    if chooser then chooser:Hide() end
    ForEachActionButton(FlashOff)
    hoveredButton = nil
    Print("Quick Bind closed.")
end

local function EnterBindMode()
    bindModeActive = true
    keyListenerFrame:Show()
    ForEachActionButton(function(button)
        FlashOn(button)
        if not button.qbBindHooked then
            button:HookScript("OnEnter", function(self) if bindModeActive then hoveredButton = self end end)
            button:HookScript("OnLeave", function(self) if bindModeActive and hoveredButton == self then hoveredButton = nil end end)
            button.qbBindHooked = true
        end
    end)
    Print("Quick Bind active. Hover a slot and press a key. Escape to finish.")
end

keyListenerFrame:SetScript("OnKeyDown", function(self, key)
    -- while the Key 1 / Key 2 chooser is open, Escape just closes it
    if chooser and chooser:IsShown() then
        if key == "ESCAPE" then chooser:Hide() end
        return
    end

    if key == "ESCAPE" then
        ExitBindMode()
        return
    end

    if key == "UNKNOWN" or not hoveredButton then return end

    -- ignore bare modifier presses; wait for the actual key
    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then
        return
    end

    local command = BINDING_COMMAND_MAP[hoveredButton:GetName()]
    if not command then return end

    ShowChooser(hoveredButton, command, BuildKeyString(key))
end)

-- ---------------------------------------------------------------------
-- Game menu button injection
-- ---------------------------------------------------------------------

local function InsertGameMenuButton()
    if QuickBindMenuButton then return end

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

    local btn = CreateFrame("Button", "QuickBindMenuButton", GameMenuFrame, "GameMenuButtonTemplate")
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

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function() InitQuickBind() end)
