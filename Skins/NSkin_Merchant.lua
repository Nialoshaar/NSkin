local _, NSkin = ...

local MerchantSkin = NSkin:NewModule("Merchant")

local IDs = {
    Scope = "Merchant",
    Window = "Merchant.Window",
    HeaderControls = "Merchant.HeaderControls",
    FilterDropdown = "Merchant.FilterDropdown",
}

local initialized = false
local showHooked = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Merchant",
})

function MerchantSkin:ApplyWindowChrome()
    local frame = _G.MerchantFrame
    if not frame then return false end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Merchant window",
        kind = "WINDOW",
        module = "Merchant",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function MerchantSkin:ApplyFilterDropdown()
    local frame = _G.MerchantFrame
    local dropdown = frame and frame.FilterDropdown
    if not frame or not dropdown then return false end

    NSkin:RegisterDropdown({
        id = IDs.FilterDropdown,
        module = "Merchant",
        appearanceWindowID = IDs.Scope,
        label = "Merchant filter dropdown",
        window = frame,
        target = dropdown,
        menus = { "MENU_MERCHANT_FRAME" },
        priority = 80,
        highlightRegions = { dropdown },
        isEditable = function()
            return frame:IsVisible() and dropdown:IsVisible()
        end,
    })
    return true
end

function MerchantSkin:Apply()
    local frame = _G.MerchantFrame
    if not frame then return false end
    self:ApplyWindowChrome()
    self:ApplyFilterDropdown()
    return true
end

function MerchantSkin:Initialize()
    local frame = _G.MerchantFrame
    if not frame then return false end

    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            C_Timer.After(0, function() MerchantSkin:Apply() end)
        end)
        showHooked = true
    end

    initialized = true
    return self:Apply()
end

function MerchantSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "Merchant",
    addon = "Blizzard_UIPanels_Game",
    apply = function() return MerchantSkin:Initialize() end,
})
