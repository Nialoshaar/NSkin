local _, NSkin = ...

local PopupSkin = NSkin:NewModule("Popup")

local IDs = {
    Scope = "Popup",
    LFG = {
        Scope = "Popup.LFGDungeonReady",
        Window = "Popup.LFGDungeonReady.Window",
        CloseButton = "Popup.LFGDungeonReady.CloseButton",
        MainLabel = "Popup.LFGDungeonReady.MainLabel",
        InstanceName = "Popup.LFGDungeonReady.InstanceName",
        YourRoleLabel = "Popup.LFGDungeonReady.YourRoleLabel",
        RoleLabel = "Popup.LFGDungeonReady.RoleLabel",
        RoleIcon = "Popup.LFGDungeonReady.RoleIcon",
        RewardsLabel = "Popup.LFGDungeonReady.RewardsLabel",
        Rewards = "Popup.LFGDungeonReady.Rewards",
        RandomInProgress = "Popup.LFGDungeonReady.RandomInProgress",
        EnterButton = "Popup.LFGDungeonReady.EnterButton",
        LeaveButton = "Popup.LFGDungeonReady.LeaveButton",
        ArtworkPlacement = "Popup.LFGDungeonReady.ArtworkPlacement",
    },
}

local LFG_ARTWORK_TOP_INSET = 11

local initialized = false
local showHooked = false
local updateHooked = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Popups",
})
NSkin:RegisterAppearanceScope(IDs.LFG.Scope, {
    label = "LFG Dungeon Ready",
    parent = IDs.Scope,
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function RefreshElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

local function GetPopup()
    return _G.LFGDungeonReadyPopup
end

local function GetDialog()
    return _G.LFGDungeonReadyDialog
end

local function GetRoleIcon()
    return _G.LFGDungeonReadyDialogRoleIcon
end

local function GetRoleTexture()
    local icon = GetRoleIcon()
    return _G.LFGDungeonReadyDialogRoleIconTexture
        or (icon and (icon.Texture or icon.texture))
end

local function GetRewardsFrame()
    return _G.LFGDungeonReadyDialogRewardsFrame
end

local function GetRewardText(reward)
    return reward and (reward.Count or reward.count or reward.Quantity
        or reward.quantity or reward.Text or reward.text)
end

local function GetRewardSlots(visibleOnly)
    local rewards = GetRewardsFrame()
    if not rewards then return {} end
    local slots, seen = {}, {}
    local function Add(slot)
        if not slot or seen[slot] or (visibleOnly and not IsVisible(slot)) then
            return
        end
        seen[slot] = true
        slots[#slots + 1] = slot
    end
    for _, slot in ipairs(rewards.Rewards or {}) do Add(slot) end
    for index = 1, (_G.LFD_MAX_REWARDS or 2) do
        Add(_G["LFGDungeonReadyDialogRewardsFrameReward" .. index])
    end
    return slots
end

local function GetRewardDescriptors()
    local descriptors = {}
    for _, reward in ipairs(GetRewardSlots(false)) do
        local texture = reward.texture or reward.Texture or reward.Icon
        if texture then
            local nativeDecorations = {}
            local border = reward.border or reward.Border
            if border then nativeDecorations[#nativeDecorations + 1] = border end
            descriptors[#descriptors + 1] = {
                target = reward,
                texture = texture,
                borderOwner = reward,
                nativeDecorationRegions = nativeDecorations,
                text = GetRewardText(reward),
            }
        end
    end
    return descriptors
end

local function GetRandomInProgressFrame()
    local dialog = GetDialog()
    return dialog and dialog.randomInProgress
        or _G.LFGDungeonReadyDialogRandomInProgressFrame
end

local function GetRandomInProgressText()
    local frame = GetRandomInProgressFrame()
    return frame and (frame.StatusText or frame.statusText or frame.Text
        or frame.text)
        or _G.LFGDungeonReadyDialogRandomInProgressFrameStatusText
end

local function GetRandomInProgressIcon()
    local frame = GetRandomInProgressFrame()
    return frame and (frame.Icon or frame.icon or frame.Texture or frame.texture)
end

local function RegisterText(frame, id, label, target, priority)
    if not target then return false end
    local element = NSkin:RegisterTextElement({
        id = id,
        module = "Popup",
        appearanceWindowID = IDs.LFG.Scope,
        label = label,
        window = frame,
        target = target,
        priority = priority,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(frame) and IsVisible(target)
        end,
    })
    return RefreshElement(element) ~= nil
end

local function SyncLFGChromeSize(popup, dialog, anchor)
    local randomInProgress = dialog.randomInProgress
    if randomInProgress and randomInProgress:IsShown() then
        local width, height = dialog:GetWidth(), popup:GetHeight()
        anchor:ClearAllPoints()
        anchor:SetPoint("TOPLEFT", dialog, "TOPLEFT")
        if width and width > 0 and height and height > 0 then
            anchor:SetSize(width, height)
        end
    else
        anchor:ClearAllPoints()
        anchor:SetAllPoints(dialog)
    end
end

local function GetLFGChromeAnchor(frame, dialog)
    local data = NSkin:GetSkinData(dialog, "lfgReadyChrome")
    local anchor = data.anchor
    if not anchor then
        anchor = _G.CreateFrame("Frame", nil, dialog)
        anchor:EnableMouse(false)
        data.anchor = anchor
    end
    if not data.popupSizeHooked and frame.HookScript then
        frame:HookScript("OnSizeChanged", function()
            SyncLFGChromeSize(frame, dialog, anchor)
        end)
        data.popupSizeHooked = true
    end
    SyncLFGChromeSize(frame, dialog, anchor)
    return anchor
end

local function RemoveLFGArtworkTopGap(dialog)
    local background = dialog.background
    if not background then return end
    local baseline = NSkin:CaptureComponentBaseline(
        IDs.LFG.ArtworkPlacement, background, {
            points = true,
            canCapture = function(region)
                return region.GetNumPoints and region:GetNumPoints() > 0
            end,
        })
    if not baseline then return end

    background:ClearAllPoints()
    for _, point in ipairs(baseline.points) do
        background:SetPoint(
            point[1], point[2], point[3], point[4],
            (tonumber(point[5]) or 0) + LFG_ARTWORK_TOP_INSET)
    end
    NSkin:MarkComponentGeometryModified(
        IDs.LFG.ArtworkPlacement, "points", true)
end

local function LayerLFGDialogArtwork(dialog, chrome)
    if chrome.background and chrome.background.SetDrawLayer then
        chrome.background:SetDrawLayer("BACKGROUND", -8)
    end
    if chrome.header and chrome.header.SetDrawLayer then
        chrome.header:SetDrawLayer("BACKGROUND", -7)
    end
    RemoveLFGArtworkTopGap(dialog)
end

function PopupSkin:ApplyWindowChrome(frame, dialog)
    local chromeAnchor = GetLFGChromeAnchor(frame, dialog)
    local chrome = NSkin:SkinStandardWindowChrome({
        frame = dialog,
        artworkFrame = dialog.Border,
        backgroundAnchor = chromeAnchor,
        borderOwner = chromeAnchor,
        appearanceWindowID = IDs.LFG.Scope,
        elementID = IDs.LFG.Window,
        headerControlsID = IDs.LFG.CloseButton,
        headerControlsLabel = "LFG ready close button",
        closeButton = dialog.CloseButton or dialog.closeButton
            or _G.LFGDungeonReadyDialogCloseButton,
        preserveCloseButtonGeometry = true,
    })
    if chrome then
        LayerLFGDialogArtwork(dialog, chrome)
    end
    NSkin:RegisterSkinningElement(IDs.LFG.Window, {
        label = "LFG Dungeon Ready window",
        kind = "WINDOW",
        module = "Popup",
        appearanceWindowID = IDs.LFG.Scope,
        window = dialog,
        target = dialog,
        priority = 0,
        draggable = false,
        pixelBorderTargets = { chromeAnchor },
    })
    return true
end

function PopupSkin:ApplyLabels(frame, dialog)
    local applied = false
    for index, definition in ipairs({
        { IDs.LFG.MainLabel, "Ready message", dialog and dialog.label },
        { IDs.LFG.InstanceName, "Instance name",
            dialog and dialog.instanceInfo and dialog.instanceInfo.name },
        { IDs.LFG.YourRoleLabel, "Your role label",
            _G.LFGDungeonReadyDialogYourRoleDescription },
        { IDs.LFG.RoleLabel, "Role label",
            _G.LFGDungeonReadyDialogRoleLabel },
        { IDs.LFG.RewardsLabel, "Rewards label",
            _G.LFGDungeonReadyDialogRewardsFrameLabel },
    }) do
        applied = RegisterText(frame, definition[1], definition[2],
            definition[3], 10 + index) or applied
    end
    return applied
end

function PopupSkin:ApplyRoleIcon(frame)
    local icon, texture = GetRoleIcon(), GetRoleTexture()
    if not icon or not texture then return false end
    local element = NSkin:RegisterIcon({
        id = IDs.LFG.RoleIcon,
        module = "Popup",
        appearanceWindowID = IDs.LFG.Scope,
        label = "Role icon",
        window = frame,
        target = icon,
        texture = texture,
        borderOwner = icon,
        priority = 20,
        highlightRegions = { texture },
        isEditable = function()
            return IsVisible(frame) and IsVisible(icon)
        end,
    })
    return RefreshElement(element) ~= nil
end

function PopupSkin:ApplyRewards(frame)
    local rewards = GetRewardsFrame()
    if not rewards then return false end
    local element = NSkin:RegisterIconGroup({
        id = IDs.LFG.Rewards,
        module = "Popup",
        appearanceWindowID = IDs.LFG.Scope,
        label = "LFG rewards",
        window = frame,
        target = rewards,
        priority = 30,
        draggable = false,
        appearanceStyles = { "icon", "text" },
        appearanceTypeIDs = { "ICON", "TEXT" },
        children = GetRewardDescriptors,
        refreshContent = function(_, descriptors)
            local style = NSkin:GetAppearanceStyle(
                "text", IDs.LFG.Scope, IDs.LFG.Rewards)
            for _, descriptor in ipairs(descriptors) do
                if descriptor.text then NSkin:SkinText(descriptor.text, style) end
            end
        end,
        highlightRegions = function()
            local regions = GetRewardSlots(true)
            for _, reward in ipairs(GetRewardSlots(true)) do
                local text = GetRewardText(reward)
                if text then regions[#regions + 1] = text end
            end
            return regions
        end,
        pixelBorderTargets = function()
            return GetRewardSlots(true)
        end,
        editorOptions = {
            { id = "shared.iconAppearance", label = "Reward icons",
                category = "CUSTOMIZE" },
            { id = "shared.textAppearance", label = "Reward text",
                category = "CUSTOMIZE" },
        },
        isEditable = function()
            return IsVisible(frame) and #GetRewardSlots(true) > 0
        end,
    })
    return element ~= nil
end

function PopupSkin:ApplyRandomInProgress(frame)
    local content = GetRandomInProgressFrame()
    if not content then return false end
    local element = NSkin:RegisterIconGroup({
        id = IDs.LFG.RandomInProgress,
        module = "Popup",
        appearanceWindowID = IDs.LFG.Scope,
        label = "Dungeon in progress content",
        window = frame,
        target = content,
        priority = 35,
        draggable = false,
        appearanceStyles = { "icon", "text" },
        appearanceTypeIDs = { "ICON", "TEXT" },
        children = function()
            local icon = GetRandomInProgressIcon()
            if not icon then return {} end
            return {{
                target = content,
                texture = icon,
                borderOwner = content,
            }}
        end,
        refreshContent = function()
            local text = GetRandomInProgressText()
            if text then
                NSkin:SkinText(text, NSkin:GetAppearanceStyle(
                    "text", IDs.LFG.Scope, IDs.LFG.RandomInProgress))
            end
        end,
        highlightRegions = function()
            local regions = {}
            local text, icon = GetRandomInProgressText(),
                GetRandomInProgressIcon()
            if text and IsVisible(text) then regions[#regions + 1] = text end
            if icon and IsVisible(icon) then regions[#regions + 1] = icon end
            return regions
        end,
        pixelBorderTargets = function()
            return GetRandomInProgressIcon() and { content } or {}
        end,
        editorOptions = {
            { id = "shared.textAppearance", label = "Progress text",
                category = "CUSTOMIZE" },
            { id = "shared.iconAppearance", label = "Progress icon",
                category = "CUSTOMIZE" },
        },
        isEditable = function()
            return IsVisible(frame) and IsVisible(content)
        end,
    })
    return element ~= nil
end

function PopupSkin:ApplyButtons(frame, dialog)
    local applied = false
    local enterButton = dialog and dialog.enterButton
    if enterButton then
        local element = NSkin:RegisterActionButton({
            id = IDs.LFG.EnterButton,
            module = "Popup",
            appearanceWindowID = IDs.LFG.Scope,
            label = "Enter dungeon button",
            window = frame,
            target = enterButton,
            priority = 40,
            highlightRegions = { enterButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(enterButton)
            end,
        })
        applied = RefreshElement(element) ~= nil or applied
    end
    local leaveButton = dialog and dialog.leaveButton
    if leaveButton then
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.LFG.LeaveButton,
            module = "Popup",
            appearanceWindowID = IDs.LFG.Scope,
            label = "Leave queue button",
            window = frame,
            target = leaveButton,
            priority = 41,
            highlightRegions = { leaveButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(leaveButton)
            end,
        })
        applied = RefreshElement(element) ~= nil or applied
    end
    return applied
end

function PopupSkin:Apply()
    local frame, dialog = GetPopup(), GetDialog()
    if not frame or not dialog then return false end
    local applied = self:ApplyWindowChrome(frame, dialog)
    applied = self:ApplyLabels(dialog, dialog) or applied
    applied = self:ApplyRoleIcon(dialog) or applied
    applied = self:ApplyRewards(dialog) or applied
    applied = self:ApplyRandomInProgress(dialog) or applied
    applied = self:ApplyButtons(dialog, dialog) or applied
    return applied
end

function PopupSkin:Initialize()
    local frame = GetPopup()
    if not frame then return false end
    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            PopupSkin:Apply()
        end)
        showHooked = true
    end
    if not updateHooked and _G.hooksecurefunc
        and type(_G.LFGDungeonReadyPopup_Update) == "function"
    then
        _G.hooksecurefunc("LFGDungeonReadyPopup_Update", function()
            PopupSkin:Apply()
        end)
        updateHooked = true
    end
    initialized = true
    return self:Apply()
end

function PopupSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    key = IDs.LFG.Window,
    module = "Popup",
    addon = "Blizzard_GroupFinder",
    apply = function()
        return PopupSkin:Initialize()
    end,
})
