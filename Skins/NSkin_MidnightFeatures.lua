local _, NSkin = ...

local MidnightFeaturesSkin = NSkin:NewModule("MidnightFeatures")

local IDs = {
    Scope = "MidnightFeatures",
    OmniumFolioWindow = "MidnightFeatures.OmniumFolio.Window",
    OmniumFolioHeaderControls =
        "MidnightFeatures.OmniumFolio.HeaderControls",
    GenericTrait = {
        Scope = "MidnightFeatures.GenericTrait",
        Window = "MidnightFeatures.GenericTrait.Window",
        HeaderControls = "MidnightFeatures.GenericTrait.HeaderControls",
        Icons = "MidnightFeatures.GenericTrait.Icons",
        Title = "MidnightFeatures.GenericTrait.Title",
    },
}

local initialized = false
local genericTraitInitialized = false
local applyPending = false
local lifecycleHooked = false
local genericTraitLifecycleHooked = false
local genericTraitIconsRegistered = false
local registryCallbackRegistered = false
local concealedArtwork = setmetatable({}, { __mode = "k" })
local hookedOverlays = setmetatable({}, { __mode = "k" })
local suppressedRegions = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Midnight Features",
})
NSkin:RegisterAppearanceScope(IDs.GenericTrait.Scope, {
    label = "Generic Trait",
    parent = IDs.Scope,
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function SuppressRegion(region)
    if not region then return end
    local state = suppressedRegions[region]
    if not state then
        state = {
            alpha = region.GetAlpha and region:GetAlpha() or 1,
            shown = region.IsShown and region:IsShown() or nil,
            active = true,
        }
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

local function GetOmniumFolio()
    local landingPage = _G.ExpansionLandingPage
    local overlayContainer = landingPage and landingPage.Overlay
    return overlayContainer and overlayContainer.MidnightLandingOverlay
        or landingPage and landingPage.overlayFrame
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        MidnightFeaturesSkin:Apply()
    end)
end

function MidnightFeaturesSkin:ApplyOmniumFolioChrome()
    local folio = GetOmniumFolio()
    if not folio then return false end

    if not concealedArtwork[folio] then
        -- The Folio's native background and ornamental border are direct
        -- texture regions. Strip only those root regions so the talent-tree
        -- artwork and controls beneath RunesOfPowerFrame remain untouched.
        NSkin:HideTextureRegions(folio)
        NSkin:HideTextureRegions(folio.Border)
        concealedArtwork[folio] = true
    end

    local title = folio.Header and folio.Header.Title
    local chrome = NSkin:SkinStandardWindowChrome({
        frame = folio,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.OmniumFolioWindow,
        headerControlsID = IDs.OmniumFolioHeaderControls,
        title = title,
        closeButton = folio.CloseButton,
    })
    if title and chrome and chrome.header then
        title:ClearAllPoints()
        title:SetPoint("CENTER", chrome.header, "CENTER", 0, 0)
    end

    NSkin:RegisterSkinningElement(IDs.OmniumFolioWindow, {
        label = "Omnium Folio window",
        kind = "WINDOW",
        module = "MidnightFeatures",
        appearanceWindowID = IDs.Scope,
        window = folio,
        target = folio,
        priority = 0,
        draggable = false,
    })

    if not hookedOverlays[folio] and folio.HookScript then
        folio:HookScript("OnShow", QueueApply)
        hookedOverlays[folio] = true
    end
    return true
end

local function GetGenericTraitButtons(frame, visibleOnly)
    local buttons = {}
    if not frame or type(frame.EnumerateAllTalentButtons) ~= "function" then
        return buttons
    end
    for button in frame:EnumerateAllTalentButtons() do
        local visible = IsVisible(button)
            and (not button.GetAlpha or button:GetAlpha() > 0)
        if button and button.Icon and (not visibleOnly or visible) then
            buttons[#buttons + 1] = button
        end
    end
    return buttons
end

local function GetGenericTraitIconDescriptors(frame)
    local descriptors = {}
    for _, button in ipairs(GetGenericTraitButtons(frame, false)) do
        descriptors[#descriptors + 1] = {
            target = button,
            texture = button.Icon,
            borderOwner = button,
            hoverRegion = button.GetHighlightTexture
                and button:GetHighlightTexture() or button.StateBorderHover,
            getHovered = function(target)
                return target and target.IsMouseOver
                    and target:IsMouseOver() or false
            end,
        }
    end
    return descriptors
end

function MidnightFeaturesSkin:ApplyGenericTraitWindow(frame)
    SuppressRegion(frame.Background)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.GenericTrait.Scope,
        elementID = IDs.GenericTrait.Window,
        headerControlsID = IDs.GenericTrait.HeaderControls,
        title = false,
        closeButton = frame.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.GenericTrait.Window, {
        label = "Generic trait window",
        kind = "WINDOW",
        module = "MidnightFeatures",
        appearanceWindowID = IDs.GenericTrait.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function MidnightFeaturesSkin:ApplyGenericTraitTitle(frame)
    local title = frame.Header and frame.Header.Title
    if not title then return false end
    local element = NSkin:RegisterTextElement({
        id = IDs.GenericTrait.Title,
        module = "MidnightFeatures",
        appearanceWindowID = IDs.GenericTrait.Scope,
        label = "Generic trait title",
        window = frame,
        target = title,
        priority = 20,
        highlightRegions = { title },
        isEditable = function()
            return IsVisible(frame) and IsVisible(title)
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element ~= nil
end

function MidnightFeaturesSkin:ApplyGenericTraitIcons(frame)
    local parent = frame.ButtonsParent
    if not parent then return false end
    if not genericTraitIconsRegistered then
        genericTraitIconsRegistered = NSkin:RegisterIconGroup({
            id = IDs.GenericTrait.Icons,
            module = "MidnightFeatures",
            appearanceWindowID = IDs.GenericTrait.Scope,
            label = "Generic trait icons",
            window = frame,
            target = parent,
            priority = 30,
            children = function()
                return GetGenericTraitIconDescriptors(frame)
            end,
            highlightRegions = function()
                return GetGenericTraitButtons(frame, true)
            end,
            pixelBorderTargets = function()
                return GetGenericTraitButtons(frame, true)
            end,
            isEditable = function()
                return IsVisible(frame)
                    and #GetGenericTraitButtons(frame, true) > 0
            end,
        }) ~= nil
    else
        NSkin:RefreshIconGroup(IDs.GenericTrait.Icons)
    end
    if genericTraitIconsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.GenericTrait.Icons)
    end
    return genericTraitIconsRegistered
end

function MidnightFeaturesSkin:ApplyGenericTrait()
    local frame = _G.GenericTraitFrame
    if not frame then return false end
    local applied = self:ApplyGenericTraitWindow(frame)
    applied = self:ApplyGenericTraitTitle(frame) or applied
    applied = self:ApplyGenericTraitIcons(frame) or applied
    return applied
end

function MidnightFeaturesSkin:Apply()
    local applied = self:ApplyOmniumFolioChrome()
    applied = self:ApplyGenericTrait() or applied
    return applied
end

local function RegisterOverlayCallback()
    if registryCallbackRegistered or not _G.EventRegistry then return end
    _G.EventRegistry:RegisterCallback(
        "ExpansionLandingPage.OverlayChanged",
        QueueApply,
        MidnightFeaturesSkin)
    registryCallbackRegistered = true
end

function MidnightFeaturesSkin:Initialize()
    local landingPage = _G.ExpansionLandingPage
    if not landingPage then return false end

    if not lifecycleHooked then
        if landingPage.HookScript then
            landingPage:HookScript("OnShow", QueueApply)
        end
        if _G.hooksecurefunc
            and type(landingPage.RefreshExpansionOverlay) == "function"
        then
            _G.hooksecurefunc(
                landingPage, "RefreshExpansionOverlay", QueueApply)
        end
        lifecycleHooked = true
    end
    RegisterOverlayCallback()
    initialized = true
    self:Apply()
    if landingPage:IsShown() then QueueApply() end

    -- The Midnight overlay can be created after this module initializes.
    -- Its lifecycle callbacks above will apply the skin when that happens.
    return true
end

function MidnightFeaturesSkin:InitializeGenericTrait()
    local frame = _G.GenericTraitFrame
    if not frame then return false end

    if not genericTraitLifecycleHooked then
        if frame.HookScript then frame:HookScript("OnShow", QueueApply) end
        if _G.hooksecurefunc then
            for _, method in ipairs({
                "AcquireTalentButton",
                "ReleaseTalentButton",
                "ReleaseAllTalentButtons",
                "ApplyLayout",
            }) do
                if type(frame[method]) == "function" then
                    _G.hooksecurefunc(frame, method, QueueApply)
                end
            end
        end
        genericTraitLifecycleHooked = true
    end
    genericTraitInitialized = true
    local applied = self:ApplyGenericTrait()
    if frame:IsShown() then QueueApply() end
    return applied
end

function MidnightFeaturesSkin:RefreshAppearance()
    if initialized then self:ApplyOmniumFolioChrome() end
    if genericTraitInitialized then self:ApplyGenericTrait() end
end

NSkin:RegisterWindowSkin({
    module = "MidnightFeatures",
    addon = "Blizzard_ExpansionLandingPage",
    apply = function() return MidnightFeaturesSkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "MidnightFeatures.GenericTrait",
    module = "MidnightFeatures",
    addon = "Blizzard_GenericTraitUI",
    apply = function()
        return MidnightFeaturesSkin:InitializeGenericTrait()
    end,
})
