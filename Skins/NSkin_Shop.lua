local _, NSkin = ...

local ShopSkin = NSkin:NewModule("Shop")

local IDs = {
    Scope = "CatalogShop",
    Window = "CatalogShop.Window",
    HeaderControls = "CatalogShop.HeaderControls",
    Navigation = "CatalogShop.Header.Navigation",
    Search = "CatalogShop.Header.Search",
    ScrollBar = "CatalogShop.ProductList.ScrollBar",
    SectionHeaders = "CatalogShop.ProductList.SectionHeaders",
    Cards = "CatalogShop.ProductList.Cards",
    CardNames = "CatalogShop.ProductList.CardNames",
    CardPrices = "CatalogShop.ProductList.CardPrices",
    CardSaleText = "CatalogShop.ProductList.CardSaleText",
    CardIcons = "CatalogShop.ProductList.CardIcons",
    NoSearchResults = "CatalogShop.ProductList.NoSearchResults",
    FormButtons = "CatalogShop.Preview.FormButtons",
}

local initialized = false
local lifecycleHooked = false
local scrollBoxHooked = false
local applyPending = false
local registeredGroups = {}
local suppressedRegions = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Catalog Shop",
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function IsHovered(target)
    return target and target.IsMouseOver and target:IsMouseOver() or false
end

local function SuppressRegion(region)
    if not region then return end
    local state = suppressedRegions[region]
    if not state then
        state = { active = true }
        suppressedRegions[region] = state
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

local function GetHeader(frame)
    return frame and frame.HeaderFrame
end

local function GetProductContainer(frame)
    return frame and frame.ProductContainerFrame
end

local function GetProductScrollBox(frame)
    local container = GetProductContainer(frame)
    return container and container.ScrollBox
end

local function IsSectionHeader(target)
    return target and target.headerText ~= nil
end

local function IsProductCard(target)
    return target and target.BackgroundContainer
        and target.ForegroundContainer
end

local function ForEachProductEntry(frame, callback)
    return NSkin:ForEachScrollBoxFrame(
        GetProductScrollBox(frame), callback)
end

local function GetVisibleEntries(frame, predicate)
    local targets = {}
    ForEachProductEntry(frame, function(target)
        if predicate(target) and IsVisible(target) then
            targets[#targets + 1] = target
        end
    end)
    return targets
end

local function GetCardTextTargets(frame, fields)
    local targets = {}
    ForEachProductEntry(frame, function(card)
        if not IsProductCard(card) then return end
        local foreground = card.ForegroundContainer
        for _, field in ipairs(fields) do
            local target = foreground and foreground[field]
            if target and target.GetFont then
                targets[#targets + 1] = target
            end
        end
    end)
    return targets
end

local function GetCardIconDescriptors(frame)
    local descriptors = {}
    ForEachProductEntry(frame, function(card)
        if not IsProductCard(card) then return end
        local foreground = card.ForegroundContainer
        local rectIcon = foreground and foreground.RectIcon
        local circleIcon = foreground and foreground.CircleIcon
        local productIcon = foreground and foreground.ProductIcon
        local texture = IsVisible(rectIcon) and rectIcon
            or IsVisible(circleIcon) and circleIcon
            or IsVisible(productIcon) and productIcon
        if texture then
            descriptors[#descriptors + 1] = {
                target = card,
                texture = texture,
                borderOwner = card,
                hoverRegion = foreground.HoverTexture,
            }
        end
    end)
    return descriptors
end

local function GetVisibleTargets(provider)
    local visible = {}
    for _, target in ipairs(provider()) do
        if IsVisible(target) then visible[#visible + 1] = target end
    end
    return visible
end

local function RegisterGroup(frame, definition)
    local id = definition.id
    local function VisibleTargets()
        return GetVisibleTargets(definition.targets)
    end
    if not registeredGroups[id] then
        registeredGroups[id] = NSkin:RegisterSkinningElement(id, {
            label = definition.label,
            kind = definition.kind,
            module = "Shop",
            appearanceWindowID = IDs.Scope,
            window = frame,
            target = definition.owner or frame,
            priority = definition.priority,
            draggable = false,
            appearanceStyles = definition.appearanceStyles,
            appearanceTypeIDs = definition.appearanceTypeIDs,
            highlightRegions = VisibleTargets,
            pixelBorderTargets = definition.pixelBorders
                and VisibleTargets or nil,
            refreshAppearance = definition.refresh,
            refreshLayout = definition.refresh,
            isEditable = function()
                return IsVisible(frame) and #VisibleTargets() > 0
            end,
        }) == true
    end
    local applied = definition.refresh()
    if registeredGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or registeredGroups[id]
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        ShopSkin:Apply()
    end)
end

function ShopSkin:ApplyWindow(frame)
    local backgrounds = frame.BackgroundContainer
    local header = GetHeader(frame)
    SuppressRegion(frame.NineSlice)
    SuppressRegion(frame.TopTitleStreaks)
    SuppressRegion(_G.CatalogShopFrameBg)
    SuppressRegion(backgrounds and backgrounds.Background_1)
    SuppressRegion(backgrounds and backgrounds.Background_2)
    SuppressRegion(backgrounds and backgrounds.LeftShadow)
    SuppressRegion(header and header.Background)
    SuppressRegion(header and header.DisabledBackground)

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
        closeButton = frame.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Catalog Shop window",
        kind = "WINDOW",
        module = "Shop",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function ShopSkin:ApplyHeader(frame)
    local header = GetHeader(frame)
    if not header then return false end
    local applied = false
    local navigation = header.CatalogShopNavBar
    if navigation then
        applied = NSkin:RegisterNavigationBar(IDs.Navigation, {
            module = "Shop",
            appearanceWindowID = IDs.Scope,
            label = "Catalog Shop navigation",
            window = frame,
            target = navigation,
            priority = 20,
            highlightRegions = { navigation },
            isEditable = function()
                return IsVisible(frame) and IsVisible(navigation)
            end,
        }) ~= nil or applied
    end
    local searchBox = header.SearchBox
    if searchBox then
        local element = NSkin:RegisterSearchBox({
            id = IDs.Search,
            module = "Shop",
            appearanceWindowID = IDs.Scope,
            label = "Catalog Shop search",
            window = frame,
            target = searchBox,
            priority = 21,
            highlightRegions = { searchBox },
            isEditable = function()
                return IsVisible(frame) and IsVisible(searchBox)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end
    return applied
end

function ShopSkin:StyleSectionHeader(header)
    if not IsSectionHeader(header) then return false end
    SuppressRegion(header.sectionHeaderRule)
    local text = header.headerText
    if text then
        NSkin:SkinText(text, NSkin:GetAppearanceStyle(
            "text", IDs.Scope, IDs.SectionHeaders))
    end
    return text ~= nil
end

function ShopSkin:ApplySectionHeaders(frame)
    local function Targets()
        local targets = {}
        ForEachProductEntry(frame, function(header)
            if IsSectionHeader(header) and header.headerText then
                targets[#targets + 1] = header.headerText
            end
        end)
        return targets
    end
    return RegisterGroup(frame, {
        id = IDs.SectionHeaders,
        label = "Catalog Shop section headers",
        kind = "SECTION_HEADER",
        priority = 40,
        targets = Targets,
        appearanceStyles = { "text" },
        appearanceTypeIDs = { "TEXT" },
        refresh = function()
            local applied = false
            ForEachProductEntry(frame, function(header)
                applied = self:StyleSectionHeader(header) or applied
            end)
            return applied
        end,
    })
end

function ShopSkin:StyleProductCard(card)
    if not IsProductCard(card) then return false end
    local background = card.BackgroundContainer
    local foreground = card.ForegroundContainer
    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, IDs.Cards)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, IDs.Cards)
    NSkin:SkinSectionCard(card, {
        style = style,
        border = border,
        height = 0,
        preserveTextLayout = true,
        visualRegion = background or card,
        nativeDecorationRegions = {
            background and background.Background,
        },
        hoverRegion = foreground and foreground.HoverTexture,
        getHovered = IsHovered,
    })
    return true
end

function ShopSkin:ApplyProductCards(frame)
    local function Targets()
        return GetVisibleEntries(frame, IsProductCard)
    end
    return RegisterGroup(frame, {
        id = IDs.Cards,
        label = "Catalog Shop product cards",
        kind = "SECTION_CARD",
        priority = 50,
        targets = Targets,
        pixelBorders = true,
        refresh = function()
            local applied = false
            ForEachProductEntry(frame, function(card)
                applied = self:StyleProductCard(card) or applied
            end)
            return applied
        end,
    })
end

local function SkinTextFamily(frame, id, provider)
    local style = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
    local applied = false
    for _, target in ipairs(provider()) do
        applied = NSkin:SkinText(target, style) or applied
    end
    return applied
end

function ShopSkin:ApplyCardText(frame)
    local definitions = {
        {
            id = IDs.CardNames,
            label = "Catalog Shop product names",
            fields = { "Name" },
            priority = 51,
        },
        {
            id = IDs.CardPrices,
            label = "Catalog Shop product prices",
            fields = { "Price", "DiscountPrice", "OriginalPrice" },
            priority = 52,
        },
        {
            id = IDs.CardSaleText,
            label = "Catalog Shop product sale and status text",
            fields = { "DiscountAmount", "TimeRemaining",
                "ProductCounterText", "QuantityInBundleText" },
            priority = 53,
        },
    }
    local applied = false
    for _, definition in ipairs(definitions) do
        local id = definition.id
        local label = definition.label
        local fields = definition.fields
        local priority = definition.priority
        local function Targets()
            return GetCardTextTargets(frame, fields)
        end
        applied = RegisterGroup(frame, {
            id = id,
            label = label,
            kind = "TEXT",
            priority = priority,
            targets = Targets,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            refresh = function()
                return SkinTextFamily(frame, id, Targets)
            end,
        }) or applied
    end
    return applied
end

function ShopSkin:ApplyCardIcons(frame)
    local function Targets()
        local targets = {}
        for _, descriptor in ipairs(GetCardIconDescriptors(frame)) do
            targets[#targets + 1] = descriptor.target
        end
        return targets
    end
    return RegisterGroup(frame, {
        id = IDs.CardIcons,
        label = "Catalog Shop product icons",
        kind = "ICON",
        priority = 54,
        targets = Targets,
        pixelBorders = true,
        refresh = function()
            local style = NSkin:GetAppearanceStyle(
                "icon", IDs.Scope, IDs.CardIcons)
            local border = NSkin:GetAppearanceBorderColor(
                "icon", style, IDs.Scope, IDs.CardIcons)
            local applied = false
            for _, descriptor in ipairs(GetCardIconDescriptors(frame)) do
                applied = NSkin:SkinIcon(descriptor.target, {
                    texture = descriptor.texture,
                    borderOwner = descriptor.borderOwner,
                    style = style,
                    border = border,
                }) or applied
            end
            return applied
        end,
    })
end

function ShopSkin:ApplyProductList(frame)
    local container = GetProductContainer(frame)
    if not container then return false end
    local applied = false
    local scrollBar = container.ScrollBar
        or container.ScrollBox and container.ScrollBox.ScrollBar
    if scrollBar then
        local element = NSkin:RegisterScrollBar({
            id = IDs.ScrollBar,
            module = "Shop",
            appearanceWindowID = IDs.Scope,
            label = "Catalog Shop product list scroll bar",
            window = frame,
            target = scrollBar,
            priority = 30,
            highlightRegions = { scrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(scrollBar)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end
    local noResults = container.NoSearchResults
    if noResults then
        local element = NSkin:RegisterTextElement({
            id = IDs.NoSearchResults,
            module = "Shop",
            appearanceWindowID = IDs.Scope,
            label = "Catalog Shop no search results text",
            window = frame,
            target = noResults,
            priority = 31,
            highlightRegions = { noResults },
            isEditable = function()
                return IsVisible(frame) and IsVisible(noResults)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end
    applied = self:ApplySectionHeaders(frame) or applied
    applied = self:ApplyProductCards(frame) or applied
    applied = self:ApplyCardText(frame) or applied
    applied = self:ApplyCardIcons(frame) or applied
    return applied
end

function ShopSkin:ApplyFormButtons(frame)
    local modelContainer = frame.ModelSceneContainerFrame
    local buttons = modelContainer and {
        modelContainer.NormalFormButton,
        modelContainer.AlternateFormButton,
    } or {}
    local function Descriptors()
        local descriptors = {}
        for _, button in pairs(buttons) do
            local texture = button and (button.Icon or button.icon)
            if texture then
                descriptors[#descriptors + 1] = {
                    target = button,
                    texture = texture,
                    selectedRegion = button.GetCheckedTexture
                        and button:GetCheckedTexture(),
                }
            end
        end
        return descriptors
    end
    local function Targets()
        local targets = {}
        for _, descriptor in ipairs(Descriptors()) do
            targets[#targets + 1] = descriptor.target
        end
        return targets
    end
    return RegisterGroup(frame, {
        id = IDs.FormButtons,
        label = "Catalog Shop preview form buttons",
        kind = "CHECKBOX",
        priority = 70,
        targets = Targets,
        pixelBorders = true,
        appearanceStyles = { "icon" },
        appearanceTypeIDs = { "ICON" },
        refresh = function()
            local style = NSkin:GetAppearanceStyle(
                "icon", IDs.Scope, IDs.FormButtons)
            local border = NSkin:GetAppearanceBorderColor(
                "icon", style, IDs.Scope, IDs.FormButtons)
            local applied = false
            for _, descriptor in ipairs(Descriptors()) do
                local button = descriptor.target
                applied = NSkin:SkinIcon(button, {
                    texture = descriptor.texture,
                    borderOwner = button,
                    style = style,
                    border = border,
                    selectedRegion = descriptor.selectedRegion,
                    getHovered = IsHovered,
                    getSelected = function(target)
                        return target.GetChecked and target:GetChecked() or false
                    end,
                }) or applied
            end
            return applied
        end,
    })
end

function ShopSkin:HookProductScrollBox(frame)
    local scrollBox = GetProductScrollBox(frame)
    if not scrollBox or scrollBoxHooked then return false end
    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, target)
                if IsSectionHeader(target) then
                    self:StyleSectionHeader(target)
                elseif IsProductCard(target) then
                    self:StyleProductCard(target)
                end
                QueueApply()
            end, self)
        scrollBoxHooked = true
    elseif _G.hooksecurefunc and type(scrollBox.Update) == "function" then
        _G.hooksecurefunc(scrollBox, "Update", QueueApply)
        scrollBoxHooked = true
    end
    return scrollBoxHooked
end

function ShopSkin:Apply()
    local frame = _G.CatalogShopFrame
    if not frame then return false end
    local applied = self:ApplyWindow(frame)
    applied = self:ApplyHeader(frame) or applied
    applied = self:ApplyProductList(frame) or applied
    applied = self:ApplyFormButtons(frame) or applied
    return applied
end

function ShopSkin:Initialize()
    local frame = _G.CatalogShopFrame
    if not frame then return false end
    if not lifecycleHooked then
        if frame.HookScript then frame:HookScript("OnShow", QueueApply) end
        if _G.hooksecurefunc then
            for _, method in ipairs({ "Refresh", "Update", "SetCategory" }) do
                if type(frame[method]) == "function" then
                    _G.hooksecurefunc(frame, method, QueueApply)
                end
            end
        end
        lifecycleHooked = true
    end
    self:HookProductScrollBox(frame)
    initialized = true
    local applied = self:Apply()
    if frame:IsShown() then QueueApply() end
    return applied
end

function ShopSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "Shop",
    addon = "Blizzard_CatalogShop",
    apply = function() return ShopSkin:Initialize() end,
})
