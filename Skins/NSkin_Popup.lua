local _, NSkin = ...

local PopupSkin = NSkin:NewModule("Popup")

local IDs = {
    Scope = "Popup",
    Splash = {
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
    },
    RolePoll = {
        Scope = "Popup.RolePoll",
        Window = "Popup.RolePoll.Window",
        Title = "Popup.RolePoll.Title",
        CloseButton = "Popup.RolePoll.CloseButton",
        Tank = "Popup.RolePoll.Tank",
        Healer = "Popup.RolePoll.Healer",
        DPS = "Popup.RolePoll.DPS",
        Accept = "Popup.RolePoll.Accept",
    },
    ReadyCheck = {
        Scope = "Popup.ReadyCheck",
        Window = "Popup.ReadyCheck.Window",
        Title = "Popup.ReadyCheck.Title",
        Message = "Popup.ReadyCheck.Message",
        Ready = "Popup.ReadyCheck.Ready",
        NotReady = "Popup.ReadyCheck.NotReady",
    },
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
    Loot = {
        Scope = "Popup.Loot",
        Window = "Popup.Loot.Window",
        CloseButton = "Popup.Loot.CloseButton",
        ScrollBar = "Popup.Loot.ScrollBar",
        ItemRows = "Popup.Loot.ItemRows",
        ItemQualityText = "Popup.Loot.ItemQualityText",
        MoneyRows = "Popup.Loot.MoneyRows",
    },
}

local LFG_ARTWORK_TOP_INSET = 11

local initialized = false
local showHooked = false
local updateHooked = false
local lootInitialized = false
local lootShowHooked = false
local lootScrollBoxHooked = false
local lootRowsRegistered = {}
local lootQualityTextRegistered = false
local readyCheckInitialized = false
local rolePollInitialized = false
local splashInitialized = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Popups",
})
NSkin:RegisterAppearanceScope(IDs.Splash.Scope, {
    label = "Splash", parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.RolePoll.Scope, {
    label = "Role Poll",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.ReadyCheck.Scope, {
    label = "Ready Check",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.LFG.Scope, {
    label = "LFG Dungeon Ready",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.Loot.Scope, {
    label = "Loot",
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
    if lootInitialized then self:ApplyLoot() end
    if readyCheckInitialized then self:ApplyReadyCheck() end
    if rolePollInitialized then self:ApplyRolePoll() end
    if splashInitialized then self:ApplySplash() end
end

local function CanSkinReadyCheckTarget(target)
    return target
        and not (target.IsForbidden and target:IsForbidden())
        and not (target.IsProtected and target:IsProtected())
end

function PopupSkin:ApplyReadyCheckButtons(frame)
    local applied = true
    for _, definition in ipairs({
        { IDs.ReadyCheck.Ready, "ACTION_BUTTON", "Ready button",
            _G.ReadyCheckFrameYesButton },
        { IDs.ReadyCheck.NotReady, "BUTTON", "Not Ready button",
            _G.ReadyCheckFrameNoButton },
    }) do
        local id, kind, label, target = unpack(definition)
        if CanSkinReadyCheckTarget(target) then
            local function ApplyButton()
                if not CanSkinReadyCheckTarget(target) then return false end
                local element = NSkin:RegisterTypedElement(kind, {
                    id = id,
                    module = "Popup",
                    appearanceWindowID = IDs.ReadyCheck.Scope,
                    label = label,
                    window = frame,
                    target = target,
                    priority = kind == "ACTION_BUTTON" and 13 or 14,
                    skinOptions = { label = target:GetText() },
                    highlightRegions = { target },
                    isEditable = function()
                        return IsVisible(frame) and IsVisible(target)
                    end,
                })
                return RefreshElement(element) ~= nil
            end
            local data = NSkin:GetSkinData(target, "readyCheckButton")
            if not data.showHooked and target.HookScript then
                target:HookScript("OnShow", ApplyButton)
                data.showHooked = true
            end
            applied = ApplyButton() and applied
        else
            applied = false
        end
    end
    return applied
end

function PopupSkin:ApplyReadyCheck()
    local frame = _G.ReadyCheckListenerFrame
    if not CanSkinReadyCheckTarget(frame) then return false end
    -- Register the actions independently of title/chrome initialization, and
    -- refresh each button through its own show lifecycle.
    local buttonsApplied = self:ApplyReadyCheckButtons(frame)
    local titleContainer = frame.TitleContainer
    local portraitContainer = frame.PortraitContainer
    if not CanSkinReadyCheckTarget(titleContainer)
        or not CanSkinReadyCheckTarget(portraitContainer)
    then return false end

    local definitions = {
        { IDs.ReadyCheck.Title, "TEXT", "Ready Check title",
            titleContainer.TitleText },
        { IDs.ReadyCheck.Message, "TEXT", "Ready Check message",
            _G.ReadyCheckFrameText },
    }
    for _, definition in ipairs(definitions) do
        if not CanSkinReadyCheckTarget(definition[4]) then return false end
    end
    for _, decoration in pairs({ frame.Bg, frame.NineSlice }) do
        if not CanSkinReadyCheckTarget(decoration) then return false end
    end

    -- The listener owns the visible popup; its outer ReadyCheckFrame remains
    -- Blizzard's unmodified 323x100 layout/visibility owner. Shared chrome hides
    -- the portrait holder; the independent TEXT registration owns the title.
    local chrome = NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.ReadyCheck.Scope,
        elementID = IDs.ReadyCheck.Window,
        title = false,
        skinCloseButton = false,
    })
    if not chrome then return false end
    local applied = NSkin:RegisterSkinningElement(IDs.ReadyCheck.Window, {
        label = "Ready Check window",
        kind = "WINDOW",
        module = "Popup",
        appearanceWindowID = IDs.ReadyCheck.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    }) == true
    for index, definition in ipairs(definitions) do
        local target = definition[4]
        local options = {
            id = definition[1],
            module = "Popup",
            appearanceWindowID = IDs.ReadyCheck.Scope,
            label = definition[3],
            window = frame,
            target = target,
            priority = 10 + index,
            highlightRegions = { target },
            isEditable = function()
                return IsVisible(frame) and IsVisible(target)
            end,
        }
        local element = NSkin:RegisterTypedElement(definition[2], options)
        applied = RefreshElement(element) ~= nil and applied
    end
    readyCheckInitialized = applied and buttonsApplied
    return readyCheckInitialized
end

local function GetRolePollTitle(frame)
    local data = NSkin:GetSkinData(frame, "rolePoll")
    if data.title then return data.title end
    -- RolePoll.xml has one direct ARTWORK FontString, with localized text and
    -- no parentKey. Do not inspect child controls or depend on region order.
    for _, region in ipairs({ frame:GetRegions() }) do
        if CanSkinReadyCheckTarget(region)
            and region:GetObjectType() == "FontString"
            and region:GetText() == _G.SELECT_YOUR_ROLE
        then
            data.title = region
            return region
        end
    end
end

function PopupSkin:ApplyRolePollRole(frame, id, label, button)
    if not CanSkinReadyCheckTarget(button) then return false end
    local checkButton = button.checkButton
    local texture = button:GetNormalTexture()
    if not CanSkinReadyCheckTarget(checkButton)
        or not CanSkinReadyCheckTarget(texture)
    then return false end
    local element = NSkin:GetSkinningElement(id)
    if not element then
        -- Each persistent role has its own composition and appearance ID.
        -- The outer button retains click forwarding; no NSkin input surface.
        element = NSkin:RegisterIconGroup({
            id = id,
            module = "Popup",
            appearanceWindowID = IDs.RolePoll.Scope,
            label = label,
            window = frame,
            target = button,
            priority = 20,
            draggable = false,
            children = function()
                if not CanSkinReadyCheckTarget(button) then return {} end
                return {{ target = button, texture = button:GetNormalTexture(),
                    borderOwner = button }}
            end,
            appearanceStyles = { "button" },
            appearanceTypeIDs = { "CHECKBOX" },
            refreshContent = function()
                if not CanSkinReadyCheckTarget(checkButton) then return end
                NSkin:SkinTypedElement("CHECKBOX", {
                    id = id,
                    appearanceWindowID = IDs.RolePoll.Scope,
                    target = checkButton,
                })
            end,
            editorOptions = {
                { id = "shared.iconAppearance", label = "Role icon",
                    presentation = "INLINE", category = "CUSTOMIZE" },
                { id = "shared.checkboxAppearance", label = "Role selector",
                    category = "CUSTOMIZE" },
            },
            composition = {
                mode = "COMPOSITE",
                movementOwner = button,
                members = {
                    { kind = "ICON", role = "PRIMARY", target = button,
                        label = "Role icon" },
                    { kind = "CHECKBOX", role = "SECONDARY", target = checkButton,
                        label = "Role selector" },
                },
            },
            highlightRegions = { button, checkButton },
            pixelBorderTargets = { button, checkButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(button)
            end,
        })
    else
        NSkin:RefreshIconGroup(element)
    end
    if not element then return false end
    local data = NSkin:GetSkinData(button, "rolePoll")
    if not data.atlasHooked and _G.hooksecurefunc then
        -- Blizzard replaces the role atlas when enabling/disabling a role.
        -- Refresh only this role after that native presentation update.
        _G.hooksecurefunc(button, "SetNormalAtlas", function()
            if CanSkinReadyCheckTarget(button) then
                NSkin:RefreshIconGroup(id)
            end
        end)
        data.atlasHooked = true
    end
    return true
end

function PopupSkin:ApplyRolePoll()
    local frame = _G.RolePollPopup
    if not CanSkinReadyCheckTarget(frame) then return false end
    local title = GetRolePollTitle(frame)
    local closeButton = _G.RolePollPopupCloseButton
    local acceptButton = frame.acceptButton
    if not title or not CanSkinReadyCheckTarget(frame.Border)
        or not CanSkinReadyCheckTarget(closeButton)
        or not CanSkinReadyCheckTarget(acceptButton)
    then return false end
    if not NSkin:SkinStandardWindowChrome({
        frame = frame,
        artworkFrame = frame.Border,
        appearanceWindowID = IDs.RolePoll.Scope,
        elementID = IDs.RolePoll.Window,
        title = false,
        closeButton = closeButton,
        headerControlsID = IDs.RolePoll.CloseButton,
        headerControlsLabel = "Role Poll close button",
        preserveCloseButtonGeometry = true,
    }) then return false end
    local applied = NSkin:RegisterSkinningElement(IDs.RolePoll.Window, {
        label = "Role Poll window", kind = "WINDOW", module = "Popup",
        appearanceWindowID = IDs.RolePoll.Scope,
        window = frame, target = frame, priority = 0, draggable = false,
    }) == true
    applied = RefreshElement(NSkin:RegisterTextElement({
        id = IDs.RolePoll.Title, label = "Select your role", module = "Popup",
        appearanceWindowID = IDs.RolePoll.Scope,
        window = frame, target = title, priority = 10,
        highlightRegions = { title },
        isEditable = function() return IsVisible(frame) and IsVisible(title) end,
    })) ~= nil and applied
    for _, definition in ipairs({
        { IDs.RolePoll.Tank, "Tank role", _G.RolePollPopupRoleButtonTank },
        { IDs.RolePoll.Healer, "Healer role", _G.RolePollPopupRoleButtonHealer },
        { IDs.RolePoll.DPS, "Damage role", _G.RolePollPopupRoleButtonDPS },
    }) do
        applied = self:ApplyRolePollRole(frame, unpack(definition)) and applied
    end
    applied = RefreshElement(NSkin:RegisterActionButton({
        id = IDs.RolePoll.Accept, label = "Accept role", module = "Popup",
        appearanceWindowID = IDs.RolePoll.Scope,
        window = frame, target = acceptButton, priority = 30,
        highlightRegions = { acceptButton },
        isEditable = function()
            return IsVisible(frame) and IsVisible(acceptButton)
        end,
    })) ~= nil and applied
    rolePollInitialized = applied
    return applied
end

function PopupSkin:ApplySplash()
    local frame = _G.SplashFrame
    if not CanSkinReadyCheckTarget(frame) then return false end
    local left, bottom, right = frame.TopLeftFeature,
        frame.BottomLeftFeature, frame.RightFeature
    if not CanSkinReadyCheckTarget(left) or not CanSkinReadyCheckTarget(bottom)
        or not CanSkinReadyCheckTarget(right)
        or not CanSkinReadyCheckTarget(frame.TopCloseButton)
    then return false end
    local definitions = {
        { IDs.Splash.Header, "TEXT", "Splash header", frame.Header },
        { IDs.Splash.Label, "TEXT", "Splash label", frame.Label },
        { IDs.Splash.TopLeftTitle, "TEXT", "Top-left feature title", left.Title },
        { IDs.Splash.TopLeftDescription, "TEXT", "Top-left feature description", left.Description },
        { IDs.Splash.BottomLeftTitle, "TEXT", "Bottom-left feature title", bottom.Title },
        { IDs.Splash.BottomLeftDescription, "TEXT", "Bottom-left feature description", bottom.Description },
        { IDs.Splash.RightTitle, "TEXT", "Right feature title", right.Title },
        { IDs.Splash.RightDescription, "TEXT", "Right feature description", right.Description },
        { IDs.Splash.BottomCloseButton, "BUTTON", "Close splash", frame.BottomCloseButton },
        { IDs.Splash.StartQuest, "ACTION_BUTTON", "Start quest", right.StartQuestButton },
    }
    for _, definition in ipairs(definitions) do
        if not CanSkinReadyCheckTarget(definition[4]) then return false end
    end
    if not CanSkinReadyCheckTarget(right.StartQuestButton.Text) then return false end
    local chrome = NSkin:SkinStandardWindowChrome({
        frame = frame, appearanceWindowID = IDs.Splash.Scope,
        elementID = IDs.Splash.Window, title = false,
        closeButton = frame.TopCloseButton,
        headerControlsID = IDs.Splash.TopCloseButton,
        headerControlsLabel = "Splash top close button",
        preserveCloseButtonGeometry = true,
    })
    if not chrome then return false end
    -- Preserve the patch-specific Left/Right/BottomTexture and BottomLine.
    -- Keep shared chrome behind that artwork, including on local WINDOW edits.
    if chrome.background then chrome.background:SetDrawLayer("BACKGROUND", -8) end
    if chrome.header then chrome.header:SetDrawLayer("BACKGROUND", -7) end
    local applied = NSkin:RegisterSkinningElement(IDs.Splash.Window, {
        label = "Splash window", kind = "WINDOW", module = "Popup",
        appearanceWindowID = IDs.Splash.Scope,
        window = frame, target = frame, priority = 0, draggable = false,
    }) == true
    for index, definition in ipairs(definitions) do
        local id, kind, label, target = unpack(definition)
        local options = {
            id = id, module = "Popup", appearanceWindowID = IDs.Splash.Scope,
            label = label, window = frame, target = target, priority = 10 + index,
            highlightRegions = { target },
            isEditable = function()
                return IsVisible(frame) and IsVisible(target)
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
        applied = RefreshElement(element) ~= nil and applied
    end
    local data = NSkin:GetSkinData(frame, "splash")
    if not data.payloadHooked and _G.hooksecurefunc then
        -- Payload setup auto-scales the right title. Reapply only that TEXT's
        -- explicit typography after Blizzard finishes its own layout.
        _G.hooksecurefunc(right, "Setup", function()
            RefreshElement(NSkin:GetSkinningElement(IDs.Splash.RightTitle))
        end)
        _G.hooksecurefunc(right, "SetStartQuestButtonDisplay", function()
            for _, id in ipairs({ IDs.Splash.RightTitle, IDs.Splash.RightDescription,
                IDs.Splash.StartQuest, IDs.Splash.BottomCloseButton }) do
                NSkin:NotifySkinningElementBoundsChanged(id)
            end
        end)
        data.payloadHooked = true
    end
    splashInitialized = applied
    return applied
end

local function GetLootFrame()
    return _G.LootFrame
end

local function GetLootRowID(row)
    if not row or not row.Item or not row.Text then return nil end
    return row.QualityText and IDs.Loot.ItemRows or IDs.Loot.MoneyRows
end

local function GetLootRows(frame, rowID, visibleOnly)
    local rows = {}
    local scrollBox = frame and frame.ScrollBox
    NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
        if GetLootRowID(row) == rowID
            and (not visibleOnly or IsVisible(row))
        then
            rows[#rows + 1] = row
        end
    end)
    return rows
end

local function CompactLootRegions(...)
    local regions = {}
    for index = 1, select("#", ...) do
        local region = select(index, ...)
        if region then regions[#regions + 1] = region end
    end
    return regions
end

local function GetLootRowStyles(rowID)
    local styles = {
        row = NSkin:GetAppearanceStyle("row", IDs.Loot.Scope, rowID),
        icon = NSkin:GetAppearanceStyle("icon", IDs.Loot.Scope, rowID),
        text = NSkin:GetAppearanceStyle("text", IDs.Loot.Scope, rowID),
    }
    styles.rowBorder = NSkin:GetAppearanceBorderColor(
        "row", styles.row, IDs.Loot.Scope, rowID)
    styles.iconBorder = NSkin:GetAppearanceBorderColor(
        "icon", styles.icon, IDs.Loot.Scope, rowID)
    return styles
end

function PopupSkin:StyleLootRow(row, styles)
    local rowID = GetLootRowID(row)
    if not rowID then return false end
    styles = styles or GetLootRowStyles(rowID)
    -- Blizzard deliberately gives row.Item an expanded hit rectangle and owns
    -- all loot, tooltip, and modified-click behavior there. Keep the pooled
    -- row itself out of mouse hit testing and leave the ItemButton scripts and
    -- hit rectangle untouched.
    if row.EnableMouse then row:EnableMouse(false) end
    if row.Item and row.Item.EnableMouse
        and row.Item.IsMouseEnabled and not row.Item:IsMouseEnabled()
    then
        row.Item:EnableMouse(true)
    end
    local applied = NSkin:SkinRow(row, {
        style = styles.row,
        border = styles.rowBorder,
        hoverRegion = row.HighlightNameFrame,
        selectedRegion = row.PushedNameFrame,
        nativeDecorationRegions = CompactLootRegions(
            row.NameFrame, row.BorderFrame, row.QualityStripe),
        contentRegions = { row.Text },
        contentStyle = styles.text,
    }) ~= nil

    local item = row.Item
    local texture = item and (item.icon or item.Icon or item.IconTexture)
    if item and texture then
        local normalTexture = item.GetNormalTexture
            and item:GetNormalTexture()
        local pushedTexture = item.GetPushedTexture
            and item:GetPushedTexture()
        if normalTexture == texture then normalTexture = nil end
        if pushedTexture == texture then pushedTexture = nil end
        applied = NSkin:SkinIcon(item, {
            style = styles.icon,
            borderColor = styles.iconBorder,
            texture = texture,
            borderOwner = item,
            nativeDecorationRegions = CompactLootRegions(
                item.IconBorder, item.SlotBackground,
                normalTexture, pushedTexture),
        }) == true or applied
    end
    return applied
end

local function GetLootQualityTexts(frame, visibleOnly)
    local texts = {}
    for _, row in ipairs(GetLootRows(frame, IDs.Loot.ItemRows, visibleOnly)) do
        if row.QualityText
            and (not visibleOnly or IsVisible(row.QualityText))
        then
            texts[#texts + 1] = row.QualityText
        end
    end
    return texts
end

function PopupSkin:StyleLootQualityText(row)
    local text = row and row.QualityText
    if not text then return false end
    return NSkin:SkinText(text, NSkin:GetAppearanceStyle(
        "text", IDs.Loot.Scope, IDs.Loot.ItemQualityText)) == true
end

function PopupSkin:ApplyLootQualityText(frame)
    local scrollBox = frame and frame.ScrollBox
    if not scrollBox then return false end
    local applied = false
    for _, row in ipairs(GetLootRows(frame, IDs.Loot.ItemRows, false)) do
        applied = self:StyleLootQualityText(row) or applied
    end

    if not lootQualityTextRegistered then
        local function Refresh()
            return PopupSkin:ApplyLootQualityText(frame)
        end
        lootQualityTextRegistered = NSkin:RegisterSkinningElement(
            IDs.Loot.ItemQualityText, {
                module = "Popup",
                appearanceWindowID = IDs.Loot.Scope,
                label = "Loot item quality text",
                kind = "TEXT",
                window = frame,
                target = scrollBox,
                priority = 32,
                draggable = false,
                highlightRegions = function()
                    return GetLootQualityTexts(frame, true)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetLootQualityTexts(frame, true) > 0
                end,
            }) == true
    end
    if lootQualityTextRegistered then
        NSkin:NotifySkinningElementBoundsChanged(
            IDs.Loot.ItemQualityText)
    end
    return applied or lootQualityTextRegistered
end

function PopupSkin:ApplyLootWindowChrome(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Loot.Scope,
        elementID = IDs.Loot.Window,
        headerControlsID = IDs.Loot.CloseButton,
        headerControlsLabel = "Loot close button",
        title = frame.TitleContainer and frame.TitleContainer.TitleText
            or frame.TitleText or frame.Title,
        closeButton = frame.ClosePanelButton or frame.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.Loot.Window, {
        label = "Loot window",
        kind = "WINDOW",
        module = "Popup",
        appearanceWindowID = IDs.Loot.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function PopupSkin:ApplyLootScrollBar(frame)
    local scrollBar = frame and frame.ScrollBar
    if not scrollBar then return false end
    local element = NSkin:RegisterScrollBar({
        id = IDs.Loot.ScrollBar,
        module = "Popup",
        appearanceWindowID = IDs.Loot.Scope,
        label = "Loot scroll bar",
        window = frame,
        target = scrollBar,
        priority = 20,
        highlightRegions = { scrollBar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(scrollBar)
        end,
    })
    return RefreshElement(element) ~= nil
end

local function GetLootRowHighlightRegions(frame, rowID)
    local regions = {}
    for _, row in ipairs(GetLootRows(frame, rowID, true)) do
        regions[#regions + 1] = row
        if row.Item then regions[#regions + 1] = row.Item end
        if row.Text then regions[#regions + 1] = row.Text end
        if row.QualityText then regions[#regions + 1] = row.QualityText end
    end
    return regions
end

local function GetLootRowBorderTargets(frame, rowID)
    local targets = {}
    for _, row in ipairs(GetLootRows(frame, rowID, true)) do
        targets[#targets + 1] = row
        if row.Item then targets[#targets + 1] = row.Item end
    end
    return targets
end

function PopupSkin:ApplyLootRows(frame, rowID)
    local scrollBox = frame and frame.ScrollBox
    if not scrollBox then return false end
    local styles = GetLootRowStyles(rowID)
    local applied = false
    for _, row in ipairs(GetLootRows(frame, rowID, false)) do
        applied = self:StyleLootRow(row, styles) or applied
    end

    if not lootRowsRegistered[rowID] then
        local label = rowID == IDs.Loot.ItemRows
            and "Loot item rows" or "Loot money rows"
        local function RefreshRows()
            return PopupSkin:ApplyLootRows(frame, rowID)
        end
        lootRowsRegistered[rowID] = NSkin:RegisterSkinningElement(rowID, {
            module = "Popup",
            appearanceWindowID = IDs.Loot.Scope,
            label = label,
            kind = "ROW",
            window = frame,
            target = scrollBox,
            priority = rowID == IDs.Loot.ItemRows and 30 or 31,
            draggable = false,
            appearanceStyles = { "icon", "text" },
            appearanceTypeIDs = { "ICON", "TEXT" },
            highlightRegions = function()
                return GetLootRowHighlightRegions(frame, rowID)
            end,
            pixelBorderTargets = function()
                return GetLootRowBorderTargets(frame, rowID)
            end,
            editorOptions = {
                { id = "shared.rowAppearance", label = "Rows",
                    category = "CUSTOMIZE" },
                { id = "shared.iconAppearance", label = "Row icons",
                    category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Row text",
                    category = "CUSTOMIZE" },
            },
            refreshAppearance = RefreshRows,
            refreshLayout = RefreshRows,
            isEditable = function()
                return IsVisible(frame)
                    and #GetLootRows(frame, rowID, true) > 0
            end,
        }) == true
    end
    if lootRowsRegistered[rowID] then
        NSkin:NotifySkinningElementBoundsChanged(rowID)
    end
    return applied or lootRowsRegistered[rowID]
end

function PopupSkin:ApplyLoot(frame)
    frame = frame or GetLootFrame()
    if not frame then return false end
    local applied = self:ApplyLootWindowChrome(frame)
    applied = self:ApplyLootScrollBar(frame) or applied
    applied = self:ApplyLootRows(frame, IDs.Loot.ItemRows) or applied
    applied = self:ApplyLootQualityText(frame) or applied
    applied = self:ApplyLootRows(frame, IDs.Loot.MoneyRows) or applied
    return applied
end

function PopupSkin:HookLootScrollBox(frame)
    local scrollBox = frame and frame.ScrollBox
    if not scrollBox or lootScrollBoxHooked then return false end
    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, row)
                local rowID = GetLootRowID(row)
                if not rowID then return end
                PopupSkin:StyleLootRow(row)
                if rowID == IDs.Loot.ItemRows then
                    PopupSkin:StyleLootQualityText(row)
                    if lootQualityTextRegistered then
                        NSkin:NotifySkinningElementBoundsChanged(
                            IDs.Loot.ItemQualityText)
                    end
                end
                NSkin:NotifySkinningElementBoundsChanged(rowID)
            end, self)
        lootScrollBoxHooked = true
    elseif _G.hooksecurefunc and type(scrollBox.Update) == "function" then
        _G.hooksecurefunc(scrollBox, "Update", function()
            PopupSkin:ApplyLoot(frame)
        end)
        lootScrollBoxHooked = true
    end
    return lootScrollBoxHooked
end

function PopupSkin:InitializeLoot()
    local frame = GetLootFrame()
    if not frame then return false end
    if not lootShowHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            PopupSkin:ApplyLoot(frame)
        end)
        lootShowHooked = true
    end
    self:HookLootScrollBox(frame)
    lootInitialized = true
    return self:ApplyLoot(frame)
end

NSkin:RegisterWindowSkin({
    key = IDs.LFG.Window,
    module = "Popup",
    addon = "Blizzard_GroupFinder",
    apply = function()
        return PopupSkin:Initialize()
    end,
})

NSkin:RegisterWindowSkin({
    key = IDs.ReadyCheck.Window,
    module = "Popup",
    addon = "Blizzard_FrameXML",
    apply = function()
        return PopupSkin:ApplyReadyCheck()
    end,
})

NSkin:RegisterWindowSkin({
    key = IDs.RolePoll.Window,
    module = "Popup",
    addon = "Blizzard_FrameXML",
    apply = function()
        return PopupSkin:ApplyRolePoll()
    end,
})

NSkin:RegisterWindowSkin({
    key = IDs.Splash.Window,
    module = "Popup",
    addon = "Blizzard_SplashFrame",
    apply = function() return PopupSkin:ApplySplash() end,
})

NSkin:RegisterWindowSkin({
    key = IDs.Loot.Window,
    module = "Popup",
    addon = "Blizzard_UIPanels_Game",
    apply = function()
        return PopupSkin:InitializeLoot()
    end,
})
