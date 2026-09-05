local _, NSkin = ...

local CharacterSkin = NSkin:NewModule("Character")

local IDs = {
    Scope = "Character",
    Window = "Character.Window",
    HeaderControls = "Character.HeaderControls",
    BottomTabs = "Character.BottomTabs",
    TitleScrollBar = "Character.Titles.ScrollBar",
    Equipment = {
        ScrollBar = "Character.EquipmentManager.ScrollBar",
        EquipButton = "Character.EquipmentManager.EquipButton",
        SaveButton = "Character.EquipmentManager.SaveButton",
    },
    ReputationDropdown = "Character.Reputation.FilterDropdown",
    CurrencyDropdown = "Character.Currency.FilterDropdown",
}

local initialized = false
local showHooked = false
local toggleHooked = false
local tabsRegistered = false
local applyPending = false
local hookedTabs = setmetatable({}, { __mode = "k" })
local hookedShowOwners = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Character",
})

local function GetTabs()
    return {
        _G.CharacterFrameTab1,
        _G.CharacterFrameTab2,
        _G.CharacterFrameTab3,
    }
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        CharacterSkin:Apply()
    end)
end

local function HookTabRefresh(tab)
    if not tab or hookedTabs[tab] or not tab.HookScript then return end
    tab:HookScript("OnClick", QueueApply)
    hookedTabs[tab] = true
end

local function HookOwnerRefresh(owner)
    if not owner or hookedShowOwners[owner] or not owner.HookScript then
        return
    end
    owner:HookScript("OnShow", QueueApply)
    hookedShowOwners[owner] = true
end

function CharacterSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = _G.CharacterFrameTitleText,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Character window",
        kind = "WINDOW",
        module = "Character",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function CharacterSkin:ApplyTabs(frame)
    if not frame then return false end
    local tabs = GetTabs()
    for i = 1, #tabs do
        if not tabs[i] then return false end
    end

    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Scope, IDs.BottomTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, IDs.BottomTabs)
    local selected = _G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(frame)
    for i = 1, #tabs do
        NSkin:SkinTab(tabs[i], i == selected, style, border)
        HookTabRefresh(tabs[i])
    end

    if not tabsRegistered then
        tabsRegistered = NSkin:RegisterTabGroup(IDs.BottomTabs, {
            label = "Character bottom tabs",
            kind = "TAB_GROUP",
            module = "Character",
            appearanceWindowID = IDs.Scope,
            window = frame,
            tabs = tabs,
            priority = 50,
            orientation = "HORIZONTAL",
            edge = "BOTTOM",
        }) == true
    end
    NSkin:ApplyTabGroupLayout(IDs.BottomTabs)
    return true
end

function CharacterSkin:ApplyPaperDollControls(frame)
    local paperDoll = _G.PaperDollFrame
    if not frame or not paperDoll then return false end

    local titles = paperDoll.TitleManagerPane
    local equipment = paperDoll.EquipmentManagerPane
    local titleScrollBar = titles and titles.ScrollBar
    local equipmentScrollBar = equipment and equipment.ScrollBar
    local equipButton = equipment and equipment.EquipSet
    local saveButton = equipment and equipment.SaveSet
    local applied = NSkin:RegisterScrollBar({
        id = IDs.TitleScrollBar, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Character titles scroll bar", window = frame,
        target = titleScrollBar, priority = 80,
        highlightRegions = { titleScrollBar },
        isEditable = function()
            return frame:IsVisible() and titles:IsVisible()
                and titleScrollBar:IsVisible()
        end,
    }) ~= nil
    applied = NSkin:RegisterScrollBar({
        id = IDs.Equipment.ScrollBar, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Equipment manager scroll bar", window = frame,
        target = equipmentScrollBar, priority = 81,
        highlightRegions = { equipmentScrollBar },
        isEditable = function()
            return frame:IsVisible() and equipment:IsVisible()
                and equipmentScrollBar:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.Equipment.EquipButton, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Equipment manager equip button", window = frame,
        target = equipButton, priority = 82,
        highlightRegions = { equipButton },
        isEditable = function()
            return frame:IsVisible() and equipment:IsVisible()
                and equipButton:IsVisible()
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.Equipment.SaveButton, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Equipment manager save button", window = frame,
        target = saveButton, priority = 83,
        highlightRegions = { saveButton },
        isEditable = function()
            return frame:IsVisible() and equipment:IsVisible()
                and saveButton:IsVisible()
        end,
    }) ~= nil or applied
    HookOwnerRefresh(titles)
    HookOwnerRefresh(equipment)
    return applied
end

function CharacterSkin:ApplyReputationDropdown(frame)
    local reputation = _G.ReputationFrame
    local dropdown = reputation and reputation.filterDropdown
    local result = NSkin:RegisterDropdown({
        id = IDs.ReputationDropdown, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Reputation filter dropdown", window = frame,
        target = dropdown, priority = 84,
        highlightRegions = { dropdown },
        isEditable = function()
            return frame:IsVisible() and reputation:IsVisible()
                and dropdown:IsVisible()
        end,
    })
    if result then HookOwnerRefresh(reputation) end
    return result ~= nil
end

function CharacterSkin:ApplyCurrencyDropdown(frame)
    local currency = _G.TokenFrame
    local dropdown = currency and currency.filterDropdown
    local result = NSkin:RegisterDropdown({
        id = IDs.CurrencyDropdown, module = "Character",
        appearanceWindowID = IDs.Scope,
        label = "Currency filter dropdown", window = frame,
        target = dropdown, priority = 85,
        highlightRegions = { dropdown },
        isEditable = function()
            return frame:IsVisible() and currency:IsVisible()
                and dropdown:IsVisible()
        end,
    })
    if result then HookOwnerRefresh(currency) end
    return result ~= nil
end

function CharacterSkin:Apply()
    local frame = _G.CharacterFrame
    if not frame then return false end
    self:ApplyWindowChrome(frame)
    self:ApplyTabs(frame)
    self:ApplyPaperDollControls(frame)
    self:ApplyReputationDropdown(frame)
    self:ApplyCurrencyDropdown(frame)
    return true
end

function CharacterSkin:Initialize()
    local frame = _G.CharacterFrame
    if not frame then return false end

    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", QueueApply)
        showHooked = true
    end
    if not toggleHooked and _G.hooksecurefunc and _G.ToggleCharacter then
        _G.hooksecurefunc("ToggleCharacter", QueueApply)
        toggleHooked = true
    end

    initialized = true
    return self:Apply()
end

function CharacterSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

function CharacterSkin:InitializeCurrency()
    local frame = _G.CharacterFrame
    if not frame or not _G.TokenFrame then return false end
    HookOwnerRefresh(_G.TokenFrame)
    return self:ApplyCurrencyDropdown(frame)
end

NSkin:RegisterWindowSkin({
    module = "Character",
    addon = "Blizzard_UIPanels_Game",
    apply = function() return CharacterSkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "Character.Currency",
    module = "Character",
    addon = "Blizzard_TokenUI",
    apply = function() return CharacterSkin:InitializeCurrency() end,
})
