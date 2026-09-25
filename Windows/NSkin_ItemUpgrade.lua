local _, NSkin = ...

local ItemUpgradeSkin = NSkin:NewModule("ItemUpgrade")

local IDs = {
    Scope = "ItemUpgrade",
    Window = "ItemUpgrade.Window",
    HeaderControls = "ItemUpgrade.HeaderControls",
    UpgradeButton = "ItemUpgrade.UpgradeButton",
    CatalystWindow = "ItemUpgrade.Catalyst.Window",
    CatalystHeaderControls = "ItemUpgrade.Catalyst.HeaderControls",
    CatalystActionButton = "ItemUpgrade.Catalyst.ActionButton",
    CatalystInputIcon = "ItemUpgrade.Catalyst.InputIcon",
    CatalystOutputIcon = "ItemUpgrade.Catalyst.OutputIcon",
    CatalystDescription = "ItemUpgrade.Catalyst.Description",
    CatalystEquipmentFlyout = "ItemUpgrade.Catalyst.EquipmentFlyout",
    CatalystEquipmentFlyoutIcons =
        "ItemUpgrade.Catalyst.EquipmentFlyout.Icons",
    CatalystEquipmentFlyoutPrevious =
        "ItemUpgrade.Catalyst.EquipmentFlyout.PreviousButton",
    CatalystEquipmentFlyoutNext =
        "ItemUpgrade.Catalyst.EquipmentFlyout.NextButton",
}

local initialized = false
local applyPending = false
local lifecycleHooked = false
local catalystInitialized = false
local catalystLifecycleHooked = false
local concealedWindowArtwork = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Item Upgrade",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function RefreshTypedElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

local function IsHovered(target)
    return target and target.IsMouseOver and target:IsMouseOver() or false
end

local function GetButtonHighlight(button)
    if not button then return nil end
    return button.HighlightTexture
        or (button.GetHighlightTexture and button:GetHighlightTexture())
end

local function GetButtonPushedTexture(button)
    if not button then return nil end
    return button.PushedTexture
        or (button.GetPushedTexture and button:GetPushedTexture())
end

local function GetButtonNormalTexture(button)
    if not button then return nil end
    return button.NormalTexture
        or (button.GetNormalTexture and button:GetNormalTexture())
end

local function SuppressCatalystRegions(owner, key, regions)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "catalystDecorations")
    data[key] = data[key] or { states = {} }
    local group = data[key]
    local declared = {}
    for _, region in ipairs(regions or {}) do
        if region then declared[region] = true end
    end
    for region, state in pairs(group.states) do
        if state.active and not declared[region] then
            state.active = nil
            state.applying = true
            if region.SetAlpha then region:SetAlpha(state.alpha) end
            if state.shown ~= nil and region.SetShown then
                region:SetShown(state.shown)
            end
            state.applying = nil
        end
    end
    for region in pairs(declared) do
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
            if state.active and not state.applying then
                state.applying = true
                if region.SetAlpha then region:SetAlpha(0) end
                state.applying = nil
            end
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

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        ItemUpgradeSkin:Apply()
    end)
end

function ItemUpgradeSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    if not concealedWindowArtwork[frame] then
        -- The upgrade panel owns several decorative textures directly on the
        -- root frame in addition to its inherited portrait-frame artwork.
        -- Conceal them before NSkin creates its own chrome textures.
        NSkin:HideTextureRegions(frame)
        concealedWindowArtwork[frame] = true
    end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Item Upgrade window",
        kind = "WINDOW",
        module = "ItemUpgrade",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function ItemUpgradeSkin:ApplyUpgradeButton(frame)
    local button = frame and frame.UpgradeButton
    if not button then return false end

    return NSkin:RegisterActionButton({
        id = IDs.UpgradeButton,
        module = "ItemUpgrade",
        appearanceWindowID = IDs.Scope,
        label = "Upgrade item button",
        window = frame,
        target = button,
        priority = 70,
        highlightRegions = { button },
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    }) ~= nil
end

function ItemUpgradeSkin:ApplyCatalystWindow(frame, conversion)
    if not frame or not conversion then return false end
    SuppressCatalystRegions(frame, "Background", {
        frame.Background,
    })
    SuppressCatalystRegions(frame, "NormalTexture", {})
    local inset = frame.Inset
    SuppressCatalystRegions(inset, "Artwork", {
        inset and inset.Bg,
        inset and inset.NineSlice,
    })
    SuppressCatalystRegions(conversion, "BackgroundFlashes", {
        conversion.Background_Flash,
        conversion.Background_Flash2,
    })
    local buttonFrame = frame and frame.ButtonFrame
    SuppressCatalystRegions(buttonFrame, "Artwork", {
        buttonFrame and buttonFrame.BlackBorder,
        buttonFrame and buttonFrame.ButtonBorder,
        buttonFrame and buttonFrame.ButtonBottomBorder,
        buttonFrame and buttonFrame.MoneyFrameEdge,
    })

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.CatalystWindow,
        headerControlsID = IDs.CatalystHeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(IDs.CatalystWindow, {
        label = "Catalyst window",
        kind = "WINDOW",
        module = "ItemUpgrade",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 10,
        draggable = false,
        isEditable = function()
            return IsVisible(frame) and IsVisible(conversion)
        end,
    })
    return true
end

function ItemUpgradeSkin:ApplyCatalystButton(frame, conversion)
    local button = frame and frame.ButtonFrame
        and frame.ButtonFrame.ActionButton
    if not button then return false end
    local element = NSkin:RegisterActionButton({
        id = IDs.CatalystActionButton,
        module = "ItemUpgrade",
        appearanceWindowID = IDs.Scope,
        label = "Catalyst action button",
        window = frame,
        target = button,
        priority = 70,
        highlightRegions = { button },
        isEditable = function()
            return IsVisible(frame) and IsVisible(conversion)
                and IsVisible(button)
        end,
    })
    return RefreshTypedElement(element) ~= nil
end

local function GetCatalystSlotDecorations(slot, isInput)
    if not slot then return {} end
    local normal = GetButtonNormalTexture(slot)
    local pushed = GetButtonPushedTexture(slot)
    if isInput then
        return {
            slot.ButtonFrame,
            slot.InputSlot_Flash,
            slot.InputSlot_Flash2,
            slot.Glow and slot.Glow.EmptySlotGlow,
            pushed,
        }
    end
    return {
        slot.ButtonFrame,
        slot.OutputSlot_Flash,
        slot.OutputSlot_Flash2,
        normal,
        pushed,
    }
end

local function GetCatalystSlotTexture(slot)
    if not slot then return nil end
    local texture = slot.Icon or slot.icon
        or slot.IconTexture or slot.iconTexture
    if texture and texture.SetTexCoord then return texture end
    if type(_G.GetItemButtonIconTexture) == "function" then
        texture = _G.GetItemButtonIconTexture(slot)
        if texture and texture.SetTexCoord then return texture end
    end
end

local function GetCatalystItemQuality()
    local frame = _G.ItemInteractionFrame
    local itemLocation = frame and type(frame.GetItemLocation) == "function"
        and frame:GetItemLocation()
    if not itemLocation or not _G.C_Item
        or type(_G.C_Item.GetItemQuality) ~= "function" then
        return nil
    end
    return _G.C_Item.GetItemQuality(itemLocation)
end

local ConstrainCatalystNormalTexture
ConstrainCatalystNormalTexture = function(slot, anchor)
    local normal = GetButtonNormalTexture(slot)
    if not normal or not anchor then return end
    local data = NSkin:GetSkinData(slot, "catalystNormalTexture")
    data.anchor = anchor
    if data.applying then return end
    data.applying = true
    normal:ClearAllPoints()
    normal:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    normal:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
    data.applying = nil
    if not data.hooked and _G.hooksecurefunc then
        for _, method in ipairs({ "SetNormalTexture", "SetNormalAtlas" }) do
            if type(slot[method]) == "function" then
                pcall(_G.hooksecurefunc, slot, method, function()
                    ConstrainCatalystNormalTexture(slot, data.anchor)
                end)
            end
        end
        data.hooked = true
    end
end

local function ApplyCatalystSlotBackground(frame, slot, texture, isInput)
    if not slot or type(slot.CreateTexture) ~= "function" then return end
    local data = NSkin:GetSkinData(slot, "catalystSlotPresentation")
    if not data.background then
        data.background = slot:CreateTexture(nil, "BACKGROUND", nil, 7)
        data.background:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
        data.background:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
        NSkin:ConfigureOwnedPixelTexture(data.background)
    end
    NSkin:SetOwnedTextureColor(data.background, 0, 0, 0, 1)
    data.background:Show()

    local hasItem = frame and type(frame.GetItemLocation) == "function"
        and frame:GetItemLocation() ~= nil
    if not hasItem and texture then
        texture:SetColorTexture(0, 0, 0, 0)
        texture:Show()
    end
end

function ItemUpgradeSkin:ApplyCatalystIcons(frame, conversion)
    if not conversion then return false end
    local applied = false
    for index, definition in ipairs({
        {
            IDs.CatalystInputIcon,
            "Catalyst input slot",
            conversion.ItemConversionInputSlot,
            true,
        },
        {
            IDs.CatalystOutputIcon,
            "Catalyst output slot",
            conversion.ItemConversionOutputSlot,
            false,
        },
    }) do
        local id, label, slot, isInput = unpack(definition)
        local texture = GetCatalystSlotTexture(slot)
        if slot and texture then
            if isInput then
                SuppressCatalystRegions(slot, "EmptySlotGlow", {
                    slot.Glow,
                })
            end
            ApplyCatalystSlotBackground(frame, slot, texture, isInput)
            local element = NSkin:RegisterIcon({
                id = id,
                module = "ItemUpgrade",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = slot,
                texture = texture,
                borderOwner = slot,
                qualityProvider = GetCatalystItemQuality,
                nativeDecorationRegions =
                    GetCatalystSlotDecorations(slot, isInput),
                hoverRegion = GetButtonHighlight(slot),
                getHovered = IsHovered,
                priority = 80 + index,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(conversion)
                        and IsVisible(slot)
                end,
            })
            applied = RefreshTypedElement(element) ~= nil or applied
            if isInput then
                ConstrainCatalystNormalTexture(slot, texture)
            end
        end
    end
    return applied
end

function ItemUpgradeSkin:ApplyCatalystText(frame, conversion)
    local description = frame and frame.Description
    if not description then return false end
    local element = NSkin:RegisterTextElement({
        id = IDs.CatalystDescription,
        module = "ItemUpgrade",
        appearanceWindowID = IDs.Scope,
        label = "Catalyst description",
        window = frame,
        target = description,
        priority = 90,
        highlightRegions = { description },
        isEditable = function()
            return IsVisible(frame) and IsVisible(conversion)
                and IsVisible(description)
        end,
    })
    return RefreshTypedElement(element) ~= nil
end

function ItemUpgradeSkin:ApplyCatalystEquipmentFlyout(frame, conversion)
    local flyout = _G.EquipmentFlyoutFrame
    local input = conversion and conversion.ItemConversionInputSlot
    if not flyout or not input then return false end
    return NSkin:RegisterEquipmentFlyoutPopup({
        root = flyout,
        module = "ItemUpgrade",
        appearanceWindowID = IDs.Scope,
        windowLabel = "Catalyst equipment flyout",
        iconsLabel = "Catalyst equipment choices",
        ids = {
            window = IDs.CatalystEquipmentFlyout,
            icons = IDs.CatalystEquipmentFlyoutIcons,
            previousButton = IDs.CatalystEquipmentFlyoutPrevious,
            nextButton = IDs.CatalystEquipmentFlyoutNext,
        },
        isActive = function(currentFlyout)
            return currentFlyout and currentFlyout.button == input
        end,
    })
end

function ItemUpgradeSkin:ApplyCatalyst()
    local frame = _G.ItemInteractionFrame
    local conversion = frame and frame.ItemConversionFrame
    if not frame or not conversion then return false end
    local applied = self:ApplyCatalystWindow(frame, conversion)
    applied = self:ApplyCatalystButton(frame, conversion) or applied
    applied = self:ApplyCatalystIcons(frame, conversion) or applied
    applied = self:ApplyCatalystText(frame, conversion) or applied
    applied = self:ApplyCatalystEquipmentFlyout(frame, conversion) or applied
    return applied
end

function ItemUpgradeSkin:InitializeCatalyst()
    local frame = _G.ItemInteractionFrame
    local conversion = frame and frame.ItemConversionFrame
    if not frame or not conversion then return false end

    if not catalystLifecycleHooked then
        if frame.HookScript then
            frame:HookScript("OnShow", function()
                ItemUpgradeSkin:ApplyCatalyst()
            end)
        end
        if _G.hooksecurefunc then
            for _, method in ipairs({
                "LoadInteractionFrameData",
                "SetInteractionItem",
                "UpdateDescriptionColor",
            }) do
                if type(frame[method]) == "function" then
                    pcall(_G.hooksecurefunc, frame, method, function()
                        ItemUpgradeSkin:ApplyCatalyst()
                    end)
                end
            end
            for _, slot in ipairs({
                conversion.ItemConversionInputSlot,
                conversion.ItemConversionOutputSlot,
            }) do
                if slot and type(slot.RefreshIcon) == "function" then
                    pcall(_G.hooksecurefunc, slot, "RefreshIcon", function()
                        ItemUpgradeSkin:ApplyCatalystIcons(frame, conversion)
                    end)
                end
            end
        end
        catalystLifecycleHooked = true
    end
    catalystInitialized = true
    return self:ApplyCatalyst()
end

function ItemUpgradeSkin:Apply()
    local frame = _G.ItemUpgradeFrame
    if not frame then return false end

    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyUpgradeButton(frame) or applied
    return applied
end

function ItemUpgradeSkin:Initialize()
    local frame = _G.ItemUpgradeFrame
    if not frame then return false end

    if not lifecycleHooked and frame.HookScript then
        frame:HookScript("OnShow", QueueApply)
        lifecycleHooked = true
    end
    initialized = true
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function ItemUpgradeSkin:RefreshAppearance()
    if initialized then self:Apply() end
    if catalystInitialized then self:ApplyCatalyst() end
end

NSkin:RegisterWindowSkin({
    module = "ItemUpgrade",
    addon = "Blizzard_ItemUpgradeUI",
    apply = function() return ItemUpgradeSkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "ItemUpgrade.Catalyst",
    module = "ItemUpgrade",
    addon = "Blizzard_ItemInteractionUI",
    apply = function() return ItemUpgradeSkin:InitializeCatalyst() end,
})
