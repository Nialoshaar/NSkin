local _, NSkin = ...

local ItemUpgradeSkin = NSkin:NewModule("ItemUpgrade")

local IDs = {
    Scope = "ItemUpgrade",
    Window = "ItemUpgrade.Window",
    HeaderControls = "ItemUpgrade.HeaderControls",
    UpgradeButton = "ItemUpgrade.UpgradeButton",
}

local initialized = false
local applyPending = false
local lifecycleHooked = false
local concealedWindowArtwork = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Item Upgrade",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        ItemUpgradeSkin:Apply()
    end)
end

function ItemUpgradeSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    if not concealedWindowArtwork[frame] then
        -- The upgrade panel owns several decorative textures directly on the
        -- root frame in addition to its inherited portrait-frame artwork.
        -- Conceal them before NSkin creates its own chrome textures.
        NSkin:HideTextureRegions(frame)
        concealedWindowArtwork[frame] = true
    end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Item Upgrade window",
        kind = "WINDOW",
        module = "ItemUpgrade",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function ItemUpgradeSkin:ApplyUpgradeButton(frame)
    local button = frame and frame.UpgradeButton
    if not button then return false end

    return NSkin:RegisterActionButton({
        id = IDs.UpgradeButton,
        module = "ItemUpgrade",
        appearanceWindowID = IDs.Scope,
        label = "Upgrade item button",
        window = frame,
        target = button,
        priority = 70,
        highlightRegions = { button },
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    }) ~= nil
end

function ItemUpgradeSkin:Apply()
    local frame = _G.ItemUpgradeFrame
    if not frame then return false end

    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyUpgradeButton(frame) or applied
    return applied
end

function ItemUpgradeSkin:Initialize()
    local frame = _G.ItemUpgradeFrame
    if not frame then return false end

    if not lifecycleHooked and frame.HookScript then
        frame:HookScript("OnShow", QueueApply)
        lifecycleHooked = true
    end
    initialized = true
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function ItemUpgradeSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "ItemUpgrade",
    addon = "Blizzard_ItemUpgradeUI",
    apply = function() return ItemUpgradeSkin:Initialize() end,
})
