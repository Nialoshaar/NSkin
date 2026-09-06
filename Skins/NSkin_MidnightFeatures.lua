local _, NSkin = ...

local MidnightFeaturesSkin = NSkin:NewModule("MidnightFeatures")

local IDs = {
    Scope = "MidnightFeatures",
    OmniumFolioWindow = "MidnightFeatures.OmniumFolio.Window",
    OmniumFolioHeaderControls =
        "MidnightFeatures.OmniumFolio.HeaderControls",
}

local initialized = false
local applyPending = false
local lifecycleHooked = false
local registryCallbackRegistered = false
local concealedArtwork = setmetatable({}, { __mode = "k" })
local hookedOverlays = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Midnight Features",
})

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

function MidnightFeaturesSkin:Apply()
    return self:ApplyOmniumFolioChrome()
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

function MidnightFeaturesSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "MidnightFeatures",
    addon = "Blizzard_ExpansionLandingPage",
    apply = function() return MidnightFeaturesSkin:Initialize() end,
})
