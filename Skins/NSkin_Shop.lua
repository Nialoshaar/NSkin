local _, NSkin = ...

local ShopSkin = NSkin:NewModule("Shop")

local IDs = {
    Scope = "CatalogShop",
    Window = "CatalogShop.Window",
    HeaderControls = "CatalogShop.HeaderControls",
    Navigation = "CatalogShop.Header.Navigation",
    Search = "CatalogShop.Header.Search",
    ScrollBar = "CatalogShop.ProductList.ScrollBar",
    Cards = "CatalogShop.ProductList.Cards",
    CardNames = "CatalogShop.ProductList.CardNames",
    CardPrices = "CatalogShop.ProductList.CardPrices",
    CardSaleText = "CatalogShop.ProductList.CardSaleText",
    CardIcons = "CatalogShop.ProductList.CardIcons",
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

local function CanSkinShopObject(target)
    if not target then return false end
    if target.IsForbidden then
        local ok, forbidden = pcall(target.IsForbidden, target)
        if not ok or forbidden then return false end
    end
    return true
end

local function IsVisible(target)
    if not CanSkinShopObject(target)
        or type(target.IsVisible) ~= "function"
    then
        return false
    end
    local ok, visible = pcall(target.IsVisible, target)
    return ok and visible == true
end

local function IsShown(target)
    if not CanSkinShopObject(target)
        or type(target.IsShown) ~= "function"
    then
        return false
    end
    local ok, shown = pcall(target.IsShown, target)
    return ok and shown == true
end

local function IsHovered(target)
    if not CanSkinShopObject(target)
        or type(target.IsMouseOver) ~= "function"
    then
        return false
    end
    local ok, hovered = pcall(target.IsMouseOver, target)
    return ok and hovered == true
end

local function SuppressRegion(region)
    if not CanSkinShopObject(region) then return false end
    local state = suppressedRegions[region]
    if not state then
        state = { active = true }
        suppressedRegions[region] = state
    end
    state.active = true
    local function Conceal()
        if not state.active or state.applying
            or not CanSkinShopObject(region)
        then
            return
        end
        state.applying = true
        if type(region.SetAlpha) == "function" then
            pcall(region.SetAlpha, region, 0)
        end
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
    return true
end

local function GetProductContainer(frame)
    if not CanSkinShopObject(frame) then return nil end
    local container = frame.ProductContainerFrame
    return CanSkinShopObject(container) and container or nil
end

local function GetProductsScrollContainer(frame)
    local container = GetProductContainer(frame)
    if not container then return nil end
    local scrollContainer = container.ProductsScrollBoxContainer
    return CanSkinShopObject(scrollContainer) and scrollContainer or nil
end

local function GetProductScrollBox(frame)
    local scrollContainer = GetProductsScrollContainer(frame)
    if not scrollContainer then return nil end
    local scrollBox = scrollContainer.ScrollBox
    return CanSkinShopObject(scrollBox) and scrollBox or nil
end

local function IsProductCard(target)
    -- ScrollBox entries must be rejected before any child field is read.
    if not CanSkinShopObject(target) then return false end
    local background = target.BackgroundContainer
    local foreground = target.ForegroundContainer
    return CanSkinShopObject(background)
        and CanSkinShopObject(foreground)
end

local function ForEachProductCard(frame, callback)
    local scrollBox = GetProductScrollBox(frame)
    if not scrollBox or type(callback) ~= "function" then return false end
    return NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        if not CanSkinShopObject(target) then return end
        if IsProductCard(target) then callback(target) end
    end)
end

local function GetProductCards(frame, visibleOnly)
    local targets = {}
    ForEachProductCard(frame, function(card)
        if not visibleOnly or IsVisible(card) then
            targets[#targets + 1] = card
        end
    end)
    return targets
end

local function GetCardTextTargets(frame, fields)
    local targets = {}
    ForEachProductCard(frame, function(card)
        local foreground = card.ForegroundContainer
        if not CanSkinShopObject(foreground) then return end
        for _, field in ipairs(fields) do
            local target = foreground[field]
            if CanSkinShopObject(target)
                and type(target.GetFont) == "function"
            then
                targets[#targets + 1] = target
            end
        end
    end)
    return targets
end

local function GetCardIconDescriptors(frame)
    local descriptors = {}
    ForEachProductCard(frame, function(card)
        local foreground = card.ForegroundContainer
        if not CanSkinShopObject(foreground) then return end
        for _, field in ipairs({ "RectIcon", "CircleIcon", "ProductIcon" }) do
            local texture = foreground[field]
            if CanSkinShopObject(texture) and IsVisible(texture) then
                descriptors[#descriptors + 1] = {
                    target = card,
                    texture = texture,
                    borderOwner = card,
                }
                break
            end
        end
    end)
    return descriptors
end

local function GetVisibleTargets(provider)
    local targets = {}
    for _, target in ipairs(provider()) do
        if CanSkinShopObject(target) and IsVisible(target) then
            targets[#targets + 1] = target
        end
    end
    return targets
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
    if not CanSkinShopObject(frame) then return false end
    local backgrounds = frame.BackgroundContainer
    local header = frame.HeaderFrame
    SuppressRegion(frame.NineSlice)
    SuppressRegion(frame.TopTitleStreaks)
    SuppressRegion(_G.CatalogShopFrameBg)
    SuppressRegion(backgrounds and backgrounds.Background_1)
    SuppressRegion(backgrounds and backgrounds.Background_2)
    SuppressRegion(backgrounds and backgrounds.LeftShadow)
    SuppressRegion(header and header.Background)
    SuppressRegion(header and header.DisabledBackground)

    local closeButton = CanSkinShopObject(frame.CloseButton)
        and frame.CloseButton or nil
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer
            and frame.TitleContainer.TitleText,
        closeButton = closeButton,
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
        isEditable = function()
            return IsVisible(frame)
        end,
    })
    return true
end

function ShopSkin:ApplyHeader(frame)
    if not CanSkinShopObject(frame) then return false end
    local header = frame.HeaderFrame
    if not CanSkinShopObject(header) then return false end
    local applied = false
    local navigation = header.CatalogShopNavBar
    if CanSkinShopObject(navigation) then
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
    if CanSkinShopObject(searchBox) then
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

function ShopSkin:StyleProductCard(card)
    if not IsProductCard(card) then return false end
    local foreground = card.ForegroundContainer
    if not CanSkinShopObject(foreground) then return false end

    local selectedContainer = card.SelectedContainer
    local selectedRegion
    if CanSkinShopObject(selectedContainer) then
        local candidate = selectedContainer.FrameBackground
        if CanSkinShopObject(candidate) then selectedRegion = candidate end
    end
    local hoverRegion = foreground.HoverTexture
    if not CanSkinShopObject(hoverRegion) then hoverRegion = nil end

    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, IDs.Cards)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, IDs.Cards)
    local decorations = {}
    if selectedRegion then decorations[1] = selectedRegion end
    local state = NSkin:SkinSectionCard(card, {
        style = style,
        border = border,
        height = 0,
        showBackground = false,
        preserveTextLayout = true,
        visualRegion = card,
        nativeDecorationRegions = decorations,
        hoverRegion = hoverRegion,
        selectedRegion = selectedRegion,
        getHovered = IsHovered,
        getSelected = function()
            return IsShown(selectedRegion)
        end,
    })
    return state ~= nil
end

function ShopSkin:ApplyProductCards(frame)
    local function Targets()
        return GetProductCards(frame, true)
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
            ForEachProductCard(frame, function(card)
                applied = self:StyleProductCard(card) or applied
            end)
            return applied
        end,
    })
end

local function SkinTextFamily(id, provider)
    local style = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
    local applied = false
    for _, target in ipairs(provider()) do
        if CanSkinShopObject(target) then
            applied = NSkin:SkinText(target, style) or applied
        end
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
        local fields = definition.fields
        local function Targets()
            return GetCardTextTargets(frame, fields)
        end
        applied = RegisterGroup(frame, {
            id = id,
            label = definition.label,
            kind = "TEXT",
            priority = definition.priority,
            targets = Targets,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            refresh = function()
                return SkinTextFamily(id, Targets)
            end,
        }) or applied
    end
    return applied
end

function ShopSkin:ApplyCardIcons(frame)
    local function Descriptors()
        return GetCardIconDescriptors(frame)
    end
    local function Targets()
        local targets = {}
        for _, descriptor in ipairs(Descriptors()) do
            if CanSkinShopObject(descriptor.target)
                and CanSkinShopObject(descriptor.texture)
            then
                targets[#targets + 1] = descriptor.target
            end
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
            for _, descriptor in ipairs(Descriptors()) do
                if CanSkinShopObject(descriptor.target)
                    and CanSkinShopObject(descriptor.texture)
                    and CanSkinShopObject(descriptor.borderOwner)
                then
                    applied = NSkin:SkinIcon(descriptor.target, {
                        texture = descriptor.texture,
                        borderOwner = descriptor.borderOwner,
                        style = style,
                        border = border,
                    }) or applied
                end
            end
            return applied
        end,
    })
end

function ShopSkin:ApplyProductList(frame)
    local scrollContainer = GetProductsScrollContainer(frame)
    if not scrollContainer then return false end
    local applied = false
    local scrollBar = scrollContainer.ScrollBar
    if CanSkinShopObject(scrollBar) then
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
    applied = self:ApplyProductCards(frame) or applied
    applied = self:ApplyCardText(frame) or applied
    applied = self:ApplyCardIcons(frame) or applied
    return applied
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
                if not CanSkinShopObject(target) then return end
                if IsProductCard(target) then
                    self:StyleProductCard(target)
                    QueueApply()
                end
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
    if not CanSkinShopObject(frame) then return false end
    local applied = self:ApplyWindow(frame)
    applied = self:ApplyHeader(frame) or applied
    applied = self:ApplyProductList(frame) or applied
    return applied
end

function ShopSkin:Initialize()
    local frame = _G.CatalogShopFrame
    if not CanSkinShopObject(frame) then return false end
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
    if IsVisible(frame) then QueueApply() end
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
