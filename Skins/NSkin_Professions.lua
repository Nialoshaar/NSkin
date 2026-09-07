local _, NSkin = ...

local ProfessionsSkin = NSkin:NewModule("Professions")

local IDs = {
    Scope = "Professions",
    Window = "Professions.Window",
    HeaderControls = "Professions.HeaderControls",
    ProgressBars = "Professions.ProgressBars",
}

local PROFESSION_FRAME_NAMES = {
    "PrimaryProfession1",
    "PrimaryProfession2",
    "SecondaryProfession1",
    "SecondaryProfession2",
    "SecondaryProfession3",
}

local PROGRESS_BAR_STYLE = {
    stripArtwork = true,
    useAppearanceTexture = true,
    background = true,
}

local initialized = false
local applyPending = false
local lifecycleHooked = false
local progressBarsRegistered = false
local windowArtworkConcealed = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Professions",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function GetProfessionBars(visibleOnly)
    local bars = {}
    for i = 1, #PROFESSION_FRAME_NAMES do
        local profession = _G[PROFESSION_FRAME_NAMES[i]]
        local bar = profession and profession.statusBar
            or _G[PROFESSION_FRAME_NAMES[i] .. "StatusBar"]
        if bar and (not visibleOnly or IsVisible(bar)) then
            bars[#bars + 1] = bar
        end
    end
    return bars
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        ProfessionsSkin:Apply()
    end)
end

function ProfessionsSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    if not windowArtworkConcealed then
        NSkin:HideTextureRegions(frame)
        windowArtworkConcealed = true
    end
    NSkin:ConcealWindowArtwork(frame.Inset)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Profession book window",
        kind = "WINDOW",
        module = "Professions",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function ProfessionsSkin:ApplyProgressBars(frame)
    local bars = GetProfessionBars(false)
    if not frame or #bars == 0 then return false end

    for i = 1, #bars do
        NSkin:SkinProgressBar(bars[i], PROGRESS_BAR_STYLE)
    end

    if not progressBarsRegistered then
        progressBarsRegistered = NSkin:RegisterProgressBarElement({
            id = IDs.ProgressBars,
            module = "Professions",
            appearanceWindowID = IDs.Scope,
            label = "Profession skill progress bars",
            window = frame,
            target = _G.ProfessionsContentFrame or frame,
            priority = 80,
            draggable = false,
            skinOptions = PROGRESS_BAR_STYLE,
            highlightRegions = function()
                return GetProfessionBars(true)
            end,
            isEditable = function()
                return IsVisible(frame) and #GetProfessionBars(true) > 0
            end,
        }) ~= nil
    end
    if progressBarsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.ProgressBars)
    end
    return true
end

function ProfessionsSkin:Apply()
    local frame = _G.ProfessionsBookFrame
    if not frame then return false end

    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyProgressBars(frame) or applied
    return applied
end

function ProfessionsSkin:Initialize()
    local frame = _G.ProfessionsBookFrame
    if not frame then return false end

    if not lifecycleHooked then
        if frame.HookScript then frame:HookScript("OnShow", QueueApply) end
        if _G.hooksecurefunc
            and type(_G.ProfessionsBookFrame_Update) == "function"
        then
            _G.hooksecurefunc("ProfessionsBookFrame_Update", QueueApply)
        end
        lifecycleHooked = true
    end

    initialized = true
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function ProfessionsSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "Professions",
    addon = "Blizzard_ProfessionsBook",
    apply = function() return ProfessionsSkin:Initialize() end,
})
