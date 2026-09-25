local _, NSkin = ...

local GreatVaultSkin = NSkin:NewModule("GreatVault")

local IDs = {
    Scope = "GreatVault",
    Window = "GreatVault.Window",
    HeaderControls = "GreatVault.HeaderControls",
}

local initialized = false
local showHooked = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Great Vault",
})

local function Conceal(region)
    if not region then return end
    region:SetAlpha(0)
    region:Hide()
end

local function ConcealOuterArtwork(frame)
    Conceal(frame.Background)
    Conceal(frame.BorderShadow)
    Conceal(frame.BorderContainer)
    Conceal(frame.ModelScene)

    local header = frame.HeaderFrame
    if header then Conceal(header.HeaderDivider) end
end

local function PreserveActivityImages(frame)
    for _, activityFrame in ipairs({
        frame.RaidFrame,
        frame.MythicFrame,
        frame.WorldFrame,
    }) do
        local background = activityFrame and activityFrame.Background
        if background then
            background:SetAlpha(1)
            background:Show()
        end
    end
end

local function GetWindowStyle(frame)
    local source = NSkin:GetAppearanceStyle("window", IDs.Scope, IDs.Window)
    if tonumber(source.header and source.header.height) then return source end

    local style, header = {}, {}
    for key, value in pairs(source) do style[key] = value end
    for key, value in pairs(source.header or {}) do header[key] = value end
    header.height = frame.CloseButton and frame.CloseButton:GetHeight() or 22
    style.header = header
    return style
end

function GreatVaultSkin:ApplyWindowChrome()
    local frame = _G.WeeklyRewardsFrame
    if not frame then return false end

    ConcealOuterArtwork(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        style = GetWindowStyle(frame),
    })
    PreserveActivityImages(frame)

    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Great Vault window",
        kind = "WINDOW",
        module = "GreatVault",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function GreatVaultSkin:Initialize()
    local frame = _G.WeeklyRewardsFrame
    if not frame then return false end

    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            C_Timer.After(0, function()
                GreatVaultSkin:ApplyWindowChrome()
            end)
        end)
        showHooked = true
    end

    initialized = true
    return self:ApplyWindowChrome()
end

function GreatVaultSkin:RefreshAppearance()
    if initialized then self:ApplyWindowChrome() end
end

NSkin:RegisterWindowSkin({
    module = "GreatVault",
    addon = "Blizzard_WeeklyRewards",
    apply = function() return GreatVaultSkin:Initialize() end,
})
