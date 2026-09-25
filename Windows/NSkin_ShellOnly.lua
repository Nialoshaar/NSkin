local _, NSkin = ...

local ShopSkin = NSkin:NewModule("Shop")
local SplashSkin = NSkin:NewModule("Popup")

-- This file groups window adapters whose support is intentionally limited
-- primarily to shared window chrome. Explicitly safe canonical child controls
-- may still be registered when Blizzard exposes them.

local ShopIDs = {
    Scope = "CatalogShop",
    Window = "CatalogShop.Window",
    HeaderControls = "CatalogShop.HeaderControls",
}

local initialized = false
local lifecycleHooked = false
local applyPending = false
local suppressedRegions = setmetatable({}, { __mode = "k" })

local SplashIDs = {
    Scope = "Splash",
    Window = "Splash.Window",
    Header = "Splash.Header",
    Label = "Splash.Label",
    TopCloseButton = "Splash.TopCloseButton",
    BottomCloseButton = "Splash.BottomCloseButton",
    TopLeftTitle = "Splash.TopLeft.Title",
    TopLeftDescription = "Splash.TopLeft.Description",
    BottomLeftTitle = "Splash.BottomLeft.Title",
    BottomLeftDescription = "Splash.BottomLeft.Description",
    RightTitle = "Splash.Right.Title",
    RightDescription = "Splash.Right.Description",
    StartQuest = "Splash.Right.StartQuest",
}

local SPLASH_CHROME_INSET_X = 10
local SPLASH_CHROME_INSET_Y = 9
local splashInitialized = false

NSkin:RegisterAppearanceScope(SplashIDs.Scope, {
    label = "Splash",
})

local function IsSplashVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function RefreshSplashElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

local function CanSkinSplashTarget(target)
    return target
        and not (target.IsForbidden and target:IsForbidden())
        and not (target.IsProtected and target:IsProtected())
end

NSkin:RegisterAppearanceScope(ShopIDs.Scope, {
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
        appearanceWindowID = ShopIDs.Scope,
        elementID = ShopIDs.Window,
        headerControlsID = ShopIDs.HeaderControls,
        title = title,
        closeButton = closeButton,
    })
    NSkin:RegisterSkinningElement(ShopIDs.Window, {
        label = "Catalog Shop window",
        kind = "WINDOW",
        module = "Shop",
        appearanceWindowID = ShopIDs.Scope,
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


local function GetSplashChromeAnchor(frame)
    local data = NSkin:GetSkinData(frame, "splash")
    local anchor = data.chromeAnchor
    if not anchor then
        anchor = _G.CreateFrame("Frame", nil, frame)
        anchor:EnableMouse(false)
        data.chromeAnchor = anchor
    end
    anchor:ClearAllPoints()
    anchor:SetPoint("TOPLEFT", frame, "TOPLEFT",
        SPLASH_CHROME_INSET_X, -SPLASH_CHROME_INSET_Y)
    anchor:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT",
        -SPLASH_CHROME_INSET_X, SPLASH_CHROME_INSET_Y)
    return anchor
end

function SplashSkin:ApplySplash()
    local frame = _G.SplashFrame
    if not CanSkinSplashTarget(frame) then return false end
    local left, bottom, right = frame.TopLeftFeature,
        frame.BottomLeftFeature, frame.RightFeature
    if not CanSkinSplashTarget(left) or not CanSkinSplashTarget(bottom)
        or not CanSkinSplashTarget(right)
        or not CanSkinSplashTarget(frame.TopCloseButton)
    then return false end
    local definitions = {
        { SplashIDs.Header, "TEXT", "Splash header", frame.Header },
        { SplashIDs.Label, "TEXT", "Splash label", frame.Label },
        { SplashIDs.TopLeftTitle, "TEXT", "Top-left feature title", left.Title },
        { SplashIDs.TopLeftDescription, "TEXT", "Top-left feature description", left.Description },
        { SplashIDs.BottomLeftTitle, "TEXT", "Bottom-left feature title", bottom.Title },
        { SplashIDs.BottomLeftDescription, "TEXT", "Bottom-left feature description", bottom.Description },
        { SplashIDs.RightTitle, "TEXT", "Right feature title", right.Title },
        { SplashIDs.RightDescription, "TEXT", "Right feature description", right.Description },
        { SplashIDs.BottomCloseButton, "BUTTON", "Close splash", frame.BottomCloseButton },
        { SplashIDs.StartQuest, "ACTION_BUTTON", "Start quest", right.StartQuestButton },
    }
    for _, definition in ipairs(definitions) do
        if not CanSkinSplashTarget(definition[4]) then return false end
    end
    if not CanSkinSplashTarget(right.StartQuestButton.Text) then return false end
    local chromeAnchor = GetSplashChromeAnchor(frame)
    local chrome = NSkin:SkinStandardWindowChrome({
        frame = frame, appearanceWindowID = SplashIDs.Scope,
        elementID = SplashIDs.Window, title = false,
        backgroundAnchor = chromeAnchor,
        borderOwner = chromeAnchor,
        borderAnchor = chromeAnchor,
        headerAnchor = chromeAnchor,
        closeButton = frame.TopCloseButton,
        headerControlsID = SplashIDs.TopCloseButton,
        headerControlsLabel = "Splash top close button",
        preserveCloseButtonGeometry = true,
    })
    if not chrome then return false end
    frame.TopCloseButton:ClearAllPoints()
    frame.TopCloseButton:SetPoint(
        "TOPRIGHT", chromeAnchor, "TOPRIGHT", 0, 0)
    -- Preserve the patch-specific Left/Right/BottomTexture and BottomLine.
    -- Keep shared chrome behind that artwork. The native splash atlases carry
    -- transparent padding around their visible edge, so the NSkin border uses
    -- a small inset anchor instead of the full 882x584 layout frame.
    if chrome.background then chrome.background:SetDrawLayer("BACKGROUND", -8) end
    if chrome.header then chrome.header:SetDrawLayer("BACKGROUND", -7) end
    local applied = NSkin:RegisterSkinningElement(SplashIDs.Window, {
        label = "Splash window", kind = "WINDOW", module = "Popup",
        appearanceWindowID = SplashIDs.Scope,
        window = frame, target = frame, priority = 0, draggable = false,
        pixelBorderTargets = { chromeAnchor },
    }) == true
    for index, definition in ipairs(definitions) do
        local id, kind, label, target = unpack(definition)
        local options = {
            id = id, module = "Popup", appearanceWindowID = SplashIDs.Scope,
            label = label, window = frame, target = target, priority = 10 + index,
            highlightRegions = { target },
            isEditable = function()
                return IsSplashVisible(frame) and IsSplashVisible(target)
            end,
        }
        if kind == "ACTION_BUTTON" then
            options.skinOptions = {
                textRegion = target.Text, preserveTextGeometry = true,
            }
        elseif kind == "BUTTON" then
            options.skinOptions = { label = target:GetText() }
        end
        local element = NSkin:RegisterTypedElement(kind, options)
        applied = RefreshSplashElement(element) ~= nil and applied
    end
    local data = NSkin:GetSkinData(frame, "splash")
    if not data.payloadHooked and _G.hooksecurefunc then
        -- Payload setup auto-scales the right title. Reapply only that TEXT's
        -- explicit typography after Blizzard finishes its own layout.
        _G.hooksecurefunc(right, "Setup", function()
            RefreshSplashElement(NSkin:GetSkinningElement(SplashIDs.RightTitle))
        end)
        _G.hooksecurefunc(right, "SetStartQuestButtonDisplay", function()
            for _, id in ipairs({ SplashIDs.RightTitle, SplashIDs.RightDescription,
                SplashIDs.StartQuest, SplashIDs.BottomCloseButton }) do
                NSkin:NotifySkinningElementBoundsChanged(id)
            end
        end)
        data.payloadHooked = true
    end
    splashInitialized = applied
    return applied
end

function SplashSkin:RefreshAppearance()
    if splashInitialized then self:ApplySplash() end
end

NSkin:RegisterWindowSkin({
    key = SplashIDs.Window,
    module = "Popup",
    addon = "Blizzard_SplashFrame",
    apply = function() return SplashSkin:ApplySplash() end,
})
