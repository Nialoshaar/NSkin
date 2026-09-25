local _, NSkin = ...

local TradingPostSkin = NSkin:NewModule("TradingPost")

local IDs = {
    Scope = "TradingPost",
    Window = "TradingPost.Window",
    FilterDropdown = "TradingPost.FilterDropdown",
    ProductsScrollBar = "TradingPost.ProductsScrollBar",
    LeaveButton = "TradingPost.LeaveButton",
    AddToCartButton = "TradingPost.AddToCartButton",
    PurchaseButton = "TradingPost.PurchaseButton",
    ViewCartButton = "TradingPost.ViewCartButton",
    HidePlayerCheckbox = "TradingPost.HidePlayerCheckbox",
    MountSpecialCheckbox = "TradingPost.MountSpecialCheckbox",
}

local initialized = false
local applyPending = false
local lifecycleHooked = false
local concealedWindowArtwork = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Trading Post",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        TradingPostSkin:Apply()
    end)
end

local function GetProductsFrame(frame)
    return frame and frame.ProductsFrame
end

local function GetProductsContainer(frame)
    local products = GetProductsFrame(frame)
    return products and products.ProductsScrollBoxContainer
end

function TradingPostSkin:ApplyWindowChrome(frame)
    local container = GetProductsContainer(frame)
    if not container then return false end

    if not concealedWindowArtwork[container] then
        -- PerksProgramFrame fills the screen so it can own the model scene.
        -- The scroll container is the actual left-hand Trading Post window.
        NSkin:HideTextureRegions(container)
        NSkin:ConcealWindowArtwork(container.Border)
        concealedWindowArtwork[container] = true
    end

    NSkin:SkinStandardWindowChrome({
        frame = container,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        skinCloseButton = false,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Trading Post window",
        kind = "WINDOW",
        module = "TradingPost",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = container,
        priority = 0,
        draggable = false,
    })
    return true
end

function TradingPostSkin:ApplyListControls(frame)
    local products = GetProductsFrame(frame)
    local container = GetProductsContainer(frame)
    local filter = products and products.PerksProgramFilter
    local scrollBar = container and container.ScrollBar
    if not products or not container then return false end

    local applied = NSkin:RegisterDropdown({
        id = IDs.FilterDropdown,
        module = "TradingPost",
        appearanceWindowID = IDs.Scope,
        label = "Trading Post filter",
        window = frame,
        target = filter,
        menus = { "MENU_PERKS_PROGRAM_DEBUG" },
        priority = 50,
        highlightRegions = { filter },
        isEditable = function()
            return IsVisible(frame) and IsVisible(filter)
        end,
    }) ~= nil
    applied = NSkin:RegisterScrollBar({
        id = IDs.ProductsScrollBar,
        module = "TradingPost",
        appearanceWindowID = IDs.Scope,
        label = "Trading Post product list scroll bar",
        window = frame,
        target = scrollBar,
        priority = 51,
        highlightRegions = { scrollBar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(container)
                and IsVisible(scrollBar)
        end,
    }) ~= nil or applied
    return applied
end

local function RegisterActionButton(frame, footer, id, key, label, priority)
    local button = footer and footer[key]
    return NSkin:RegisterActionButton({
        id = id,
        module = "TradingPost",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = button,
        priority = priority,
        highlightRegions = { button },
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    }) ~= nil
end

function TradingPostSkin:ApplyFooterButtons(frame)
    local footer = frame and frame.FooterFrame
    if not footer then return false end

    local applied = RegisterActionButton(frame, footer,
        IDs.LeaveButton, "LeaveButton", "Leave Trading Post button", 60)
    applied = RegisterActionButton(frame, footer,
        IDs.AddToCartButton, "AddToCartButton", "Add to cart button", 61)
        or applied
    applied = RegisterActionButton(frame, footer,
        IDs.PurchaseButton, "PurchaseButton", "Buy Trading Post item button", 62)
        or applied
    applied = RegisterActionButton(frame, footer,
        IDs.ViewCartButton, "ViewCartButton", "Trading Post cart button", 63)
        or applied
    return applied
end

local function RegisterCheckbox(frame, footer, id, key, label, priority)
    local checkBox = footer and footer[key]
    return NSkin:RegisterCheckbox({
        id = id,
        module = "TradingPost",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = checkBox,
        text = checkBox and checkBox.Text,
        priority = priority,
        highlightRegions = { checkBox },
        isEditable = function()
            return IsVisible(frame) and IsVisible(checkBox)
        end,
    }) ~= nil
end

function TradingPostSkin:ApplyPreviewCheckboxes(frame)
    local footer = frame and frame.FooterFrame
    if not footer then return false end

    local applied = RegisterCheckbox(frame, footer,
        IDs.HidePlayerCheckbox, "TogglePlayerPreview",
        "Hide player checkbox", 70)
    applied = RegisterCheckbox(frame, footer,
        IDs.MountSpecialCheckbox, "ToggleMountSpecial",
        "Mount Special Animation checkbox", 71) or applied
    return applied
end

function TradingPostSkin:Apply()
    local frame = _G.PerksProgramFrame
    if not frame then return false end

    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyListControls(frame) or applied
    applied = self:ApplyFooterButtons(frame) or applied
    applied = self:ApplyPreviewCheckboxes(frame) or applied
    return applied
end

function TradingPostSkin:Initialize()
    local frame = _G.PerksProgramFrame
    if not frame then return false end

    if not lifecycleHooked then
        if frame.HookScript then frame:HookScript("OnShow", QueueApply) end
        local products = frame.ProductsFrame
        if products and products.HookScript then
            products:HookScript("OnShow", QueueApply)
        end
        lifecycleHooked = true
    end

    initialized = true
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function TradingPostSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "TradingPost",
    addon = "Blizzard_PerksProgram",
    apply = function() return TradingPostSkin:Initialize() end,
})
