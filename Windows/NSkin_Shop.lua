local _, NSkin = ...

local ShopSkin = NSkin:NewModule("Shop")

local IDs = {
    Scope = "CatalogShop",
    Window = "CatalogShop.Window",
    HeaderControls = "CatalogShop.HeaderControls",
}

local initialized = false
local lifecycleHooked = false
local applyPending = false
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
    SuppressRegion(frame.NineSlice)
    SuppressRegion(frame.TopTitleStreaks)
    SuppressRegion(_G.CatalogShopFrameBg)

    local titleContainer = frame.TitleContainer
    local title = CanSkinShopObject(titleContainer)
        and CanSkinShopObject(titleContainer.TitleText)
        and titleContainer.TitleText or nil
    local closeButton = CanSkinShopObject(frame.CloseButton)
        and frame.CloseButton or nil
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = title,
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

function ShopSkin:Apply()
    local frame = _G.CatalogShopFrame
    if not CanSkinShopObject(frame) then return false end
    return self:ApplyWindow(frame)
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
