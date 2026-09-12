local _, NSkin = ...

local StorageSkin = NSkin:NewModule("Storage")

local IDs = {
    Scope = "Storage",
    Window = "Storage.CombinedBags.Window",
    HeaderControls = "Storage.CombinedBags.HeaderControls",
    SearchBox = "Storage.CombinedBags.SearchBox",
    CleanupButton = "Storage.CombinedBags.CleanupButton",
    GoldText = "Storage.CombinedBags.GoldText",
    SilverText = "Storage.CombinedBags.SilverText",
    CombinedItems = "Storage.CombinedBags.Items",
    IndividualWindow = "Storage.ContainerFrame6.Window",
    IndividualHeaderControls = "Storage.ContainerFrame6.HeaderControls",
    IndividualItems = "Storage.ContainerFrame6.Items",
}

local initialized = false
local currencyHooked = false
local tokenLifecycleHooked = false
local containerShowHooks = setmetatable({}, { __mode = "k" })
local containerItemHooks = setmetatable({}, { __mode = "k" })
local registeredItemGroups = {}

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Storage",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function CompactRegions(...)
    local regions = {}
    for index = 1, select("#", ...) do
        local region = select(index, ...)
        if region then regions[#regions + 1] = region end
    end
    return regions
end

local function SetDecorationsSuppressed(owner, key, regions, suppressed)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "storageDecorations")
    data[key] = data[key] or { states = {} }
    local group = data[key]
    local active = {}
    if suppressed then
        for _, region in ipairs(regions or {}) do
            if region then active[region] = true end
        end
    end

    for region, state in pairs(group.states) do
        state.active = active[region] == true
        if not state.active then
            state.applying = true
            if region.SetAlpha then region:SetAlpha(state.alpha) end
            if state.shown ~= nil and region.SetShown then
                region:SetShown(state.shown)
            end
            state.applying = nil
        end
    end
    for region in pairs(active) do
        local state = group.states[region]
        if not state then
            state = {
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = region.IsShown and region:IsShown() or nil,
            }
            group.states[region] = state
        end
        state.active = true
        local function Conceal()
            if not state.active or state.applying then return end
            state.applying = true
            if region.SetAlpha then region:SetAlpha(0) end
            state.applying = nil
        end
        Conceal()
        if not state.hooked and _G.hooksecurefunc then
            for _, method in ipairs({ "SetAlpha", "SetShown", "Show" }) do
                if type(region[method]) == "function" then
                    pcall(_G.hooksecurefunc, region, method, Conceal)
                end
            end
            state.hooked = true
        end
    end
end

local function GetCurrencyBorderRegions(container)
    local border = container and container.Border
    if not border then return {} end
    return { border.Left, border.Middle, border.Right }
end

local function GetMoneyText(moneyFrame, denomination)
    local button = moneyFrame and moneyFrame[denomination .. "Button"]
    return button and (button.Text or button.text)
end

local function GetCleanupButtonIcon(button)
    local data = NSkin:GetSkinData(button, "storageCleanupButton")
    if data.icon then return data.icon end

    local icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 5, -5)
    icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
    NSkin:ConfigureOwnedPixelTexture(icon)
    icon:SetTexture(NSkin.mediaPath .. "broom.png")
    icon:SetVertexColor(1, 1, 1, 1)
    data.icon = icon
    return icon
end

local function SkinCleanupButton(_, button, style, borderColor)
    local icon = GetCleanupButtonIcon(button)
    NSkin:SkinFlatButton(button, nil, { 0, 0, 0, 0 }, borderColor,
        nil, nil, nil, icon)
    local background = NSkin:GetFlatBackground(button)
    if background then NSkin:SetOwnedTextureColor(background, 0, 0, 0, 0) end
    local border = NSkin:GetPixelBorder(button, "NSkinFlatBackgroundBorder")
    if border then NSkin:SetPixelBorderSize(border, 1) end
end

local function GetContainerItemButtons(frame, visibleOnly)
    local buttons = {}
    if not frame then return buttons end
    if type(frame.EnumerateValidItems) == "function" then
        for _, button in frame:EnumerateValidItems() do
            if button and (not visibleOnly or IsVisible(button)) then
                buttons[#buttons + 1] = button
            end
        end
    else
        for _, button in ipairs(frame.Items or {}) do
            if button and (not visibleOnly or IsVisible(button)) then
                buttons[#buttons + 1] = button
            end
        end
    end
    return buttons
end

local function GetContainerItemTexture(button)
    return button and (button.IconTexture or button.Icon or button.icon)
end

local function ContainerItemHasItem(button)
    if not button or not _G.C_Container
        or type(_G.C_Container.GetContainerItemInfo) ~= "function"
        or type(button.GetBagID) ~= "function"
        or type(button.GetID) ~= "function"
    then return false end
    return _G.C_Container.GetContainerItemInfo(
        button:GetBagID(), button:GetID()) ~= nil
end

local function UpdateContainerItemEmptyArtwork(button)
    local icon = GetContainerItemTexture(button)
    if not icon then return end
    local data = NSkin:GetSkinData(button, "storageEmptySlotArtwork")
    if data.icon ~= icon then
        data.icon = icon
        data.alpha = icon.GetAlpha and icon:GetAlpha() or 1
        if data.alpha == 0 then data.alpha = 1 end
        data.hooked = nil
    end

    data.empty = not ContainerItemHasItem(button)
    local function MaintainEmptyState()
        if not data.empty or data.applying then return end
        data.applying = true
        icon:SetAlpha(0)
        data.applying = nil
    end
    if not data.hooked and _G.hooksecurefunc
        and type(icon.SetAlpha) == "function" then
        pcall(_G.hooksecurefunc, icon, "SetAlpha", MaintainEmptyState)
        data.hooked = true
    end
    if data.empty then
        MaintainEmptyState()
    elseif data.wasEmpty then
        data.applying = true
        icon:SetAlpha(data.alpha or 1)
        data.applying = nil
    end
    data.wasEmpty = data.empty
end

local function GetContainerItemQuality(button)
    if not button or not _G.C_Container
        or type(_G.C_Container.GetContainerItemInfo) ~= "function"
        or type(button.GetBagID) ~= "function"
        or type(button.GetID) ~= "function"
    then return nil end
    local info = _G.C_Container.GetContainerItemInfo(
        button:GetBagID(), button:GetID())
    return info and info.quality
end

local function GetContainerItemDescriptors(frame)
    local descriptors = {}
    for _, button in ipairs(GetContainerItemButtons(frame, false)) do
        SetDecorationsSuppressed(button, "ItemSlotBackground",
            CompactRegions(button.ItemSlotBackground), true)
        UpdateContainerItemEmptyArtwork(button)
        descriptors[#descriptors + 1] = {
            target = button,
            textureProvider = GetContainerItemTexture,
            borderOwner = button,
            borderSize = 1,
            borderPadding = 0,
            qualityProvider = GetContainerItemQuality,
            hoverRegion = button.HighlightTexture
                or (button.GetHighlightTexture
                    and button:GetHighlightTexture()),
            nativeDecorationRegions = CompactRegions(
                button.ItemSlotBackground,
                button.NormalTexture
                    or (button.GetNormalTexture
                        and button:GetNormalTexture()),
                button.PushedTexture
                    or (button.GetPushedTexture
                        and button:GetPushedTexture()),
                button.IconBorder),
        }
    end
    return descriptors
end

function StorageSkin:ApplyWindowChrome(frame, elementID, headerControlsID, label)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = elementID,
        headerControlsID = headerControlsID,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(elementID, {
        label = label,
        kind = "WINDOW",
        module = "Storage",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function StorageSkin:ApplyItemIcons(frame, id, label)
    if not frame then return false end
    if not registeredItemGroups[id] then
        registeredItemGroups[id] = NSkin:RegisterIconGroup({
            id = id,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = label,
            window = frame,
            target = frame,
            priority = 40,
            draggable = false,
            children = function()
                return GetContainerItemDescriptors(frame)
            end,
            highlightRegions = function()
                return GetContainerItemButtons(frame, true)
            end,
            pixelBorderTargets = function()
                return GetContainerItemButtons(frame, true)
            end,
            isEditable = function()
                return IsVisible(frame)
                    and #GetContainerItemButtons(frame, true) > 0
            end,
        }) ~= nil
    else
        NSkin:RefreshIconGroup(id)
    end
    return registeredItemGroups[id]
end

function StorageSkin:HookContainerFrame(frame, itemID, itemLabel)
    if not frame then return end
    if not containerShowHooks[frame] and frame.HookScript then
        frame:HookScript("OnShow", function()
            StorageSkin:Apply()
        end)
        containerShowHooks[frame] = true
    end
    if not containerItemHooks[frame] and _G.hooksecurefunc
        and type(frame.UpdateItems) == "function" then
        pcall(_G.hooksecurefunc, frame, "UpdateItems", function()
            StorageSkin:ApplyItemIcons(frame, itemID, itemLabel)
        end)
        containerItemHooks[frame] = true
    end
end

function StorageSkin:ApplyControls(frame)
    local searchBox = _G.BagItemSearchBox
    local cleanupButton = _G.BagItemAutoSortButton
    local applied = false
    if searchBox then
        applied = NSkin:RegisterSearchBox({
            id = IDs.SearchBox,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Combined Bags search box",
            window = frame,
            target = searchBox,
            priority = 20,
            highlightRegions = { searchBox },
            isEditable = function()
                return IsVisible(frame) and IsVisible(searchBox)
                    and searchBox:GetParent() == frame
            end,
        }) ~= nil or applied
    end
    if cleanupButton then
        applied = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.CleanupButton,
            module = "Storage",
            appearanceWindowID = IDs.Scope,
            label = "Clean up bags button",
            window = frame,
            target = cleanupButton,
            skinAdapter = SkinCleanupButton,
            priority = 21,
            highlightRegions = { cleanupButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(cleanupButton)
                    and cleanupButton:GetParent() == frame
            end,
        }) ~= nil or applied
    end
    return applied
end

function StorageSkin:ApplyCurrency(frame)
    local moneyFrame = frame and frame.MoneyFrame
    if not moneyFrame then return false end
    SetDecorationsSuppressed(moneyFrame, "MoneyBorder",
        GetCurrencyBorderRegions(moneyFrame), true)

    local applied = false
    for index, definition in ipairs({
        { IDs.GoldText, "Combined Bags gold", "Gold", "GOLD" },
        { IDs.SilverText, "Combined Bags silver", "Silver" },
    }) do
        local id, label, denomination, numberFormat = unpack(definition)
        local text = GetMoneyText(moneyFrame, denomination)
        if text then
            applied = NSkin:RegisterTextElement({
                id = id,
                module = "Storage",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = text,
                priority = 30 + index,
                numberFormat = numberFormat,
                highlightRegions = { text },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(text)
                end,
            }) ~= nil or applied
        end
    end
    return applied
end

function StorageSkin:ApplyTokenFrame()
    local tokenFrame = _G.BackpackTokenFrame
    if not tokenFrame then return false end
    local combined = tokenFrame.IsCombined and tokenFrame:IsCombined() == true
    SetDecorationsSuppressed(tokenFrame, "TokenBorder",
        GetCurrencyBorderRegions(tokenFrame), combined)

    if not tokenLifecycleHooked and _G.hooksecurefunc
        and type(tokenFrame.SetIsCombinedInventory) == "function" then
        pcall(_G.hooksecurefunc, tokenFrame, "SetIsCombinedInventory", function()
            StorageSkin:ApplyTokenFrame()
        end)
        tokenLifecycleHooked = true
    end
    return true
end

function StorageSkin:Apply()
    local combinedFrame = _G.ContainerFrameCombinedBags
    local individualFrame = _G.ContainerFrame6
    if not combinedFrame and not individualFrame then return false end
    local applied = false
    if combinedFrame then
        applied = self:ApplyWindowChrome(combinedFrame, IDs.Window,
            IDs.HeaderControls, "Combined Bags window") or applied
        applied = self:ApplyControls(combinedFrame) or applied
        applied = self:ApplyCurrency(combinedFrame) or applied
        applied = self:ApplyTokenFrame() or applied
        applied = self:ApplyItemIcons(combinedFrame, IDs.CombinedItems,
            "Combined Bags items") or applied
    end
    if individualFrame then
        applied = self:ApplyWindowChrome(individualFrame,
            IDs.IndividualWindow, IDs.IndividualHeaderControls,
            "ContainerFrame6 window") or applied
        applied = self:ApplyItemIcons(individualFrame, IDs.IndividualItems,
            "ContainerFrame6 items") or applied
    end
    return applied
end

function StorageSkin:Initialize()
    local combinedFrame = _G.ContainerFrameCombinedBags
    local individualFrame = _G.ContainerFrame6
    if not combinedFrame and not individualFrame then return false end
    self:HookContainerFrame(combinedFrame, IDs.CombinedItems,
        "Combined Bags items")
    self:HookContainerFrame(individualFrame, IDs.IndividualItems,
        "ContainerFrame6 items")
    if combinedFrame and not currencyHooked and _G.hooksecurefunc
        and type(combinedFrame.UpdateCurrencyFrames) == "function" then
        pcall(_G.hooksecurefunc, combinedFrame,
            "UpdateCurrencyFrames", function()
            StorageSkin:ApplyCurrency(combinedFrame)
            StorageSkin:ApplyTokenFrame()
        end)
        currencyHooked = true
    end
    initialized = true
    return self:Apply()
end

function StorageSkin:InitializeTokens()
    self:ApplyTokenFrame()
    if initialized then self:Apply() end
    return true
end

function StorageSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "Storage",
    addon = "Blizzard_UIPanels_Game",
    apply = function() return StorageSkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "Storage.Tokens",
    module = "Storage",
    addon = "Blizzard_TokenUI",
    apply = function() return StorageSkin:InitializeTokens() end,
})
