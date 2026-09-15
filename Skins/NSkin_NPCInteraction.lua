local _, NSkin = ...

local NPCInteractionSkin = NSkin:NewModule("NPCInteraction")

local IDs = {
    Scope = "Gossip",
    Window = "Gossip.Window",
    HeaderControls = "Gossip.HeaderControls",
    ScrollBar = "Gossip.ScrollBar",
    GoodbyeButton = "Gossip.GoodbyeButton",
    GreetingText = "Gossip.GreetingText",
    OptionRows = "Gossip.OptionRows",
}

local gossipInitialized = false
local showHooked = false
local scrollBoxHooked = false
local greetingTextRegistered = false
local optionRowsRegistered = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Gossip",
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function GetGreetingPanel(frame)
    return frame and frame.GreetingPanel
end

local function GetScrollBox(frame)
    local panel = GetGreetingPanel(frame)
    return panel and panel.ScrollBox
end

local function GetButtonTexture(button, method, field)
    if not button then return nil end
    if type(button[method]) == "function" then
        local texture = button[method](button)
        if texture then return texture end
    end
    return button[field]
end

local function IsHovered(target)
    return target and target.IsMouseOver and target:IsMouseOver() or false
end

local function IsOptionRow(target)
    return target and not target.GreetingText and target.Icon
        and type(target.GetFontString) == "function"
        and target:GetFontString() ~= nil
end

local function GetVisibleGreetingTexts(frame)
    local texts = {}
    NSkin:ForEachScrollBoxFrame(GetScrollBox(frame), function(target)
        if target.GreetingText and IsVisible(target.GreetingText) then
            texts[#texts + 1] = target.GreetingText
        end
    end)
    return texts
end

local function GetVisibleOptionRows(frame)
    local rows = {}
    NSkin:ForEachScrollBoxFrame(GetScrollBox(frame), function(target)
        if IsOptionRow(target) and IsVisible(target) then
            rows[#rows + 1] = target
        end
    end)
    return rows
end

local function SuppressDecorations(owner, regions)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "gossipDecorations")
    data.states = data.states or {}
    for _, region in ipairs(regions or {}) do
        if region then
            local state = data.states[region]
            if not state then
                state = {
                    alpha = region.GetAlpha and region:GetAlpha() or 1,
                    shown = region.IsShown and region:IsShown() or nil,
                }
                data.states[region] = state
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
    end
end

function NPCInteractionSkin:ApplyWindowChrome(frame)
    local panel = GetGreetingPanel(frame)
    local inset = _G.GossipFrameInset or frame.Inset
    local insetNineSlice = inset and inset.NineSlice
    SuppressDecorations(frame, {
        frame.Background,
        panel and panel.MaterialTopLeft,
        _G.GossipFrameGreetingPanelMaterialTopRight,
        _G.GossipFrameGreetingPanelMaterialBotLeft,
        _G.GossipFrameGreetingPanelMaterialBotRight,
        inset and inset.Bg,
        insetNineSlice and insetNineSlice.TopEdge,
        insetNineSlice and insetNineSlice.BottomEdge,
        insetNineSlice and insetNineSlice.RightEdge,
        insetNineSlice and insetNineSlice.LeftEdge,
    })
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Gossip window",
        kind = "WINDOW",
        module = "NPCInteraction",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function NPCInteractionSkin:ApplyControls(frame)
    local panel = GetGreetingPanel(frame)
    if not panel then return false end
    local applied = false
    if panel.ScrollBar then
        local element = NSkin:RegisterScrollBar({
            id = IDs.ScrollBar,
            module = "NPCInteraction",
            appearanceWindowID = IDs.Scope,
            label = "Gossip scroll bar",
            window = frame,
            target = panel.ScrollBar,
            priority = 30,
            highlightRegions = { panel.ScrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(panel.ScrollBar)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end
    if panel.GoodbyeButton then
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.GoodbyeButton,
            module = "NPCInteraction",
            appearanceWindowID = IDs.Scope,
            label = "Goodbye button",
            window = frame,
            target = panel.GoodbyeButton,
            priority = 40,
            isEditable = function()
                return IsVisible(frame) and IsVisible(panel.GoodbyeButton)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end
    return applied
end

function NPCInteractionSkin:StyleGreetingText(target)
    local text = target and target.GreetingText
    if not text then return false end
    local style = NSkin:GetAppearanceStyle(
        "text", IDs.Scope, IDs.GreetingText)
    return NSkin:SkinText(text, style) == true
end

function NPCInteractionSkin:ApplyGreetingText(frame)
    local scrollBox = GetScrollBox(frame)
    if not scrollBox then return false end
    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        applied = self:StyleGreetingText(target) or applied
    end)

    local function Refresh()
        return NPCInteractionSkin:ApplyGreetingText(frame)
    end
    if not greetingTextRegistered then
        greetingTextRegistered = NSkin:RegisterSkinningElement(
            IDs.GreetingText, {
                module = "NPCInteraction",
                appearanceWindowID = IDs.Scope,
                label = "Gossip greeting text",
                kind = "TEXT",
                window = frame,
                target = scrollBox,
                priority = 50,
                draggable = false,
                highlightRegions = function()
                    return GetVisibleGreetingTexts(frame)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetVisibleGreetingTexts(frame) > 0
                end,
            }) == true
    end
    if greetingTextRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.GreetingText)
    end
    return applied or greetingTextRegistered
end

function NPCInteractionSkin:StyleOptionRow(target)
    if not IsOptionRow(target) then
        if target then NSkin:SkinSectionRow(target, { reset = true }) end
        return false
    end
    local text = target:GetFontString()
    local style = NSkin:GetAppearanceStyle(
        "sectionRow", IDs.Scope, IDs.OptionRows)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionRow", style, IDs.Scope, IDs.OptionRows)
    return NSkin:SkinSectionRow(target, {
        style = style,
        border = border,
        height = 0,
        textRegion = text,
        contentRegions = { text },
        contentStyle = NSkin:GetAppearanceStyle(
            "text", IDs.Scope, IDs.OptionRows),
        hoverRegion = GetButtonTexture(
            target, "GetHighlightTexture", "HighlightTexture"),
        getHovered = IsHovered,
    }) ~= nil
end

function NPCInteractionSkin:ApplyOptionRows(frame)
    local scrollBox = GetScrollBox(frame)
    if not scrollBox then return false end
    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        applied = self:StyleOptionRow(target) or applied
    end)

    local function Refresh()
        return NPCInteractionSkin:ApplyOptionRows(frame)
    end
    if not optionRowsRegistered then
        optionRowsRegistered = NSkin:RegisterSkinningElement(
            IDs.OptionRows, {
                module = "NPCInteraction",
                appearanceWindowID = IDs.Scope,
                label = "Gossip quest and option rows",
                kind = "SECTION_ROW",
                window = frame,
                target = scrollBox,
                priority = 60,
                draggable = false,
                appearanceStyles = { "text" },
                appearanceTypeIDs = { "TEXT" },
                highlightRegions = function()
                    return GetVisibleOptionRows(frame)
                end,
                pixelBorderTargets = function()
                    return GetVisibleOptionRows(frame)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetVisibleOptionRows(frame) > 0
                end,
            }) == true
    end
    if optionRowsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.OptionRows)
    end
    return applied or optionRowsRegistered
end

function NPCInteractionSkin:StyleScrollBoxTarget(frame, target)
    if target and target.GreetingText then
        self:StyleGreetingText(target)
    else
        self:StyleOptionRow(target)
    end
    if greetingTextRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.GreetingText)
    end
    if optionRowsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.OptionRows)
    end
end

function NPCInteractionSkin:HookScrollBox(frame)
    local scrollBox = GetScrollBox(frame)
    if not scrollBox or scrollBoxHooked then return false end
    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, target)
                NPCInteractionSkin:StyleScrollBoxTarget(frame, target)
            end, self)
        scrollBoxHooked = true
    elseif _G.hooksecurefunc and type(scrollBox.Update) == "function" then
        _G.hooksecurefunc(scrollBox, "Update", function()
            NPCInteractionSkin:ApplyGreetingText(frame)
            NPCInteractionSkin:ApplyOptionRows(frame)
        end)
        scrollBoxHooked = true
    end
    return scrollBoxHooked
end

function NPCInteractionSkin:ApplyGossip()
    local frame = _G.GossipFrame
    if not frame then return false end
    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyControls(frame) or applied
    applied = self:ApplyGreetingText(frame) or applied
    applied = self:ApplyOptionRows(frame) or applied
    return applied
end

function NPCInteractionSkin:InitializeGossip()
    local frame = _G.GossipFrame
    if not frame then return false end
    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            NPCInteractionSkin:ApplyGossip()
        end)
        showHooked = true
    end
    self:HookScrollBox(frame)
    gossipInitialized = true
    return self:ApplyGossip()
end

NSkin:RegisterWindowSkin({
    key = "NPCInteraction.Gossip",
    module = "NPCInteraction",
    addon = "Blizzard_UIPanels_Game",
    apply = function() return NPCInteractionSkin:InitializeGossip() end,
})

local QuestIDs = {
    Scope = "Quest",
    Window = "Quest.Window",
    HeaderControls = "Quest.HeaderControls",
    Title = "Quest.Title",
    Description = "Quest.Description",
    ObjectivesHeader = "Quest.ObjectivesHeader",
    Objectives = "Quest.Objectives",
    RewardsHeader = "Quest.RewardsHeader",
    RewardsChoice = "Quest.RewardsChoice",
    RewardsReceive = "Quest.RewardsReceive",
    RewardsGold = "Quest.RewardsGold",
    RewardsSilver = "Quest.RewardsSilver",
    RewardsCopper = "Quest.RewardsCopper",
    RewardIcon = "Quest.RewardIcon",
    DetailsScrollBar = "Quest.DetailsScrollBar",
    AcceptButton = "Quest.AcceptButton",
    DeclineButton = "Quest.DeclineButton",
}

local questInitialized = false
local questShowHooked = false
local questDetailHooked = false
local questDisplayHooked = false
local questTextRegistered = {}

NSkin:RegisterAppearanceScope(QuestIDs.Scope, {
    label = "Quest",
})

local function RefreshElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

local function RegisterQuestText(frame, id, label, target, priority)
    if not target then return false end
    NSkin:SkinText(target,
        NSkin:GetAppearanceStyle("text", QuestIDs.Scope, id))
    if not questTextRegistered[id] then
        questTextRegistered[id] = NSkin:RegisterSkinningElement(id, {
            module = "NPCInteraction",
            appearanceWindowID = QuestIDs.Scope,
            label = label,
            kind = "TEXT",
            window = frame,
            target = target,
            priority = priority,
            refreshAppearance = function()
                NSkin:SkinText(target,
                    NSkin:GetAppearanceStyle("text", QuestIDs.Scope, id))
                return true
            end,
            isEditable = function()
                return IsVisible(frame) and IsVisible(target)
            end,
        }) == true
    end
    if questTextRegistered[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return true
end

local function ResolveQuestRewardIcon()
    local rewards = _G.QuestInfoRewardsFrame
    local texture = _G.QuestInfoRewardsFrameIconTexture
        or (rewards and (rewards.IconTexture or rewards.Icon))
    local owner = texture and texture.GetParent and texture:GetParent() or nil
    if texture then return owner or rewards, texture end

    local button = rewards and rewards.RewardButtons
        and rewards.RewardButtons[1]
    texture = button and (button.Icon or button.icon or button.IconTexture)
    return button, texture
end

function NPCInteractionSkin:ApplyQuestWindowChrome(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = QuestIDs.Scope,
        elementID = QuestIDs.Window,
        headerControlsID = QuestIDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(QuestIDs.Window, {
        label = "Quest window",
        kind = "WINDOW",
        module = "NPCInteraction",
        appearanceWindowID = QuestIDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function NPCInteractionSkin:ApplyQuestTexts(frame)
    local rewards = _G.QuestInfoRewardsFrame
    local applied = false
    for _, definition in ipairs({
        { QuestIDs.Title, "Quest title", _G.QuestInfoTitleHeader, 30 },
        {
            QuestIDs.Description, "Quest description",
            _G.QuestFrameDescriptionText or _G.QuestInfoDescriptionText, 31,
        },
        {
            QuestIDs.ObjectivesHeader, "Quest objectives header",
            _G.QuestInfoObjectivesHeader, 32,
        },
        {
            QuestIDs.Objectives, "Quest objectives",
            _G.QuestInfoObjectivesText, 33,
        },
        {
            QuestIDs.RewardsHeader, "Quest rewards header",
            rewards and rewards.Header, 34,
        },
        {
            QuestIDs.RewardsChoice, "Quest reward choices",
            rewards and rewards.ItemChooseText, 35,
        },
        {
            QuestIDs.RewardsReceive, "Quest rewards received",
            rewards and rewards.ItemReceiveText, 36,
        },
        {
            QuestIDs.RewardsGold, "Quest reward gold",
            _G.QuestInfoMoneyFrameGoldButtonText, 37,
        },
        {
            QuestIDs.RewardsSilver, "Quest reward silver",
            _G.QuestInfoMoneyFrameSilverButtonText, 38,
        },
        {
            QuestIDs.RewardsCopper, "Quest reward copper",
            _G.QuestInfoMoneyFrameCopperButtonText, 39,
        },
    }) do
        applied = RegisterQuestText(
            frame, definition[1], definition[2], definition[3], definition[4])
            or applied
    end
    return applied
end

function NPCInteractionSkin:ApplyQuestIcon(frame)
    local owner, texture = ResolveQuestRewardIcon()
    if not owner or not texture then return false end
    local nativeDecorations = {}
    for _, region in ipairs({ owner.IconBorder, owner.SlotBackground }) do
        if region then nativeDecorations[#nativeDecorations + 1] = region end
    end
    local element = NSkin:RegisterIcon({
        id = QuestIDs.RewardIcon,
        module = "NPCInteraction",
        appearanceWindowID = QuestIDs.Scope,
        label = "Quest reward icon",
        window = frame,
        target = owner,
        texture = texture,
        borderOwner = owner,
        nativeDecorationRegions = nativeDecorations,
        hoverRegion = GetButtonTexture(
            owner, "GetHighlightTexture", "HighlightTexture"),
        getHovered = IsHovered,
        priority = 50,
        isEditable = function()
            return IsVisible(frame) and IsVisible(owner)
        end,
    })
    return RefreshElement(element) ~= nil
end

function NPCInteractionSkin:ApplyQuestControls(frame)
    local scrollFrame = _G.QuestDetailsScrollFrame
        or _G.QuestDetailScrollFrame
    local scrollBar = scrollFrame and scrollFrame.ScrollBar
    local applied = false
    if scrollBar then
        applied = RefreshElement(NSkin:RegisterScrollBar({
            id = QuestIDs.DetailsScrollBar,
            module = "NPCInteraction",
            appearanceWindowID = QuestIDs.Scope,
            label = "Quest details scroll bar",
            window = frame,
            target = scrollBar,
            priority = 60,
            isEditable = function()
                return IsVisible(frame) and IsVisible(scrollBar)
            end,
        })) ~= nil or applied
    end
    for _, definition in ipairs({
        {
            QuestIDs.AcceptButton, "Quest accept button",
            _G.QuestFrameAcceptButton, 70,
        },
        {
            QuestIDs.DeclineButton, "Quest decline button",
            _G.QuestFrameDeclineButton, 71,
        },
    }) do
        local target = definition[3]
        if target then
            applied = RefreshElement(NSkin:RegisterTypedElement("BUTTON", {
                id = definition[1],
                module = "NPCInteraction",
                appearanceWindowID = QuestIDs.Scope,
                label = definition[2],
                window = frame,
                target = target,
                priority = definition[4],
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })) ~= nil or applied
        end
    end
    return applied
end

function NPCInteractionSkin:ApplyQuestContent(frame)
    local applied = self:ApplyQuestTexts(frame)
    applied = self:ApplyQuestIcon(frame) or applied
    applied = self:ApplyQuestControls(frame) or applied
    return applied
end

function NPCInteractionSkin:ApplyQuest()
    local frame = _G.QuestFrame
    if not frame then return false end
    local applied = self:ApplyQuestWindowChrome(frame)
    applied = self:ApplyQuestContent(frame) or applied
    return applied
end

function NPCInteractionSkin:InitializeQuest()
    local frame = _G.QuestFrame
    if not frame then return false end
    if not questShowHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            NPCInteractionSkin:ApplyQuest()
        end)
        questShowHooked = true
    end
    local detailPanel = _G.QuestFrameDetailPanel
    if not questDetailHooked and detailPanel and detailPanel.HookScript then
        detailPanel:HookScript("OnShow", function()
            NPCInteractionSkin:ApplyQuestContent(frame)
        end)
        questDetailHooked = true
    end
    if not questDisplayHooked and _G.hooksecurefunc
        and type(_G.QuestInfo_Display) == "function"
    then
        _G.hooksecurefunc("QuestInfo_Display", function()
            NPCInteractionSkin:ApplyQuestContent(frame)
        end)
        questDisplayHooked = true
    end
    questInitialized = true
    return self:ApplyQuest()
end

NSkin:RegisterWindowSkin({
    key = "NPCInteraction.Quest",
    module = "NPCInteraction",
    addon = "Blizzard_UIPanels_Game",
    apply = function() return NPCInteractionSkin:InitializeQuest() end,
})

local QuestModelSceneIDs = {
    Scope = "NPCInteraction.QuestModelScene",
    Window = "NPCInteraction.QuestModelScene.Window",
    Name = "NPCInteraction.QuestModelScene.Name",
    Description = "NPCInteraction.QuestModelScene.Description",
    ScrollBar = "NPCInteraction.QuestModelScene.ScrollBar",
}

local questModelSceneInitialized = false
local questModelSceneShowHooked = false
local questModelSceneDisplayHooked = false
local questModelSceneMixinHooked = false

NSkin:RegisterAppearanceScope(QuestModelSceneIDs.Scope, {
    label = "Quest Model Scene",
    parent = QuestIDs.Scope,
})

function NPCInteractionSkin:ApplyQuestModelSceneWindow(scene)
    local textFrame = scene.ModelTextFrame
    local modelBackground = scene.ModelBackground
    local textBackground = textFrame and textFrame.TextBackground
    SuppressDecorations(scene, {
        scene.Border,
        scene.TopBarBg,
        scene.ModelNameDivider,
        scene.ModelNameBackground,
        textBackground,
    })

    local style = NSkin:GetAppearanceStyle("window",
        QuestModelSceneIDs.Scope, QuestModelSceneIDs.Window)
    local borderColor = NSkin:GetAppearanceBorderColor("window", style,
        QuestModelSceneIDs.Scope, QuestModelSceneIDs.Window)
    local backgroundColor = NSkin:GetResolvedAppearanceColor(
        style, "background")
    if modelBackground and textBackground then
        local chromeState = NSkin:GetSkinData(
            scene, "questModelSceneChrome")
        local bounds = chromeState.bounds
        if not bounds then
            bounds = CreateFrame("Frame", nil, scene)
            bounds:EnableMouse(false)
            chromeState.bounds = bounds
        end
        bounds:ClearAllPoints()
        bounds:SetPoint("TOPLEFT", modelBackground, "TOPLEFT", -9, 27)
        bounds:SetPoint("BOTTOMRIGHT", textBackground,
            "BOTTOMRIGHT", 10, -6)
        bounds:Show()

        local outerBackground = chromeState.background
        if not outerBackground then
            outerBackground = scene:CreateTexture(
                nil, "BACKGROUND", nil, -8)
            chromeState.background = outerBackground
        end
        outerBackground:ClearAllPoints()
        outerBackground:SetAllPoints(bounds)
        outerBackground:SetColorTexture(unpack(backgroundColor))
        outerBackground:Show()

        local descriptionBackground = chromeState.textBackground
        if not descriptionBackground then
            descriptionBackground = scene:CreateTexture(
                nil, "BACKGROUND", nil, -7)
            chromeState.textBackground = descriptionBackground
        end
        descriptionBackground:ClearAllPoints()
        descriptionBackground:SetAllPoints(textBackground)
        descriptionBackground:SetColorTexture(unpack(backgroundColor))
        descriptionBackground:Show()

        local oldBorder = NSkin:GetPixelBorder(
            scene, "NSkinQuestModelSceneBorder")
        if oldBorder then NSkin:SetPixelBorderShown(oldBorder, false) end
        local border = NSkin:CreatePixelBorder(scene,
            "NSkinQuestModelSceneBoundsBorder", style.borderSize,
            borderColor, false, bounds)
        NSkin:SetPixelBorderSize(border, style.borderSize)
        NSkin:SetPixelBorderPadding(border, 0)
        NSkin:SetPixelBorderColor(border, unpack(borderColor))
        NSkin:SetPixelBorderShown(border, true)
    end

    if textFrame then
        local oldTextBackground = NSkin:GetFlatBackground(
            textFrame, "NSkinQuestModelSceneTextBackground")
        if oldTextBackground then oldTextBackground:Hide() end
        local oldTextBorder = NSkin:GetPixelBorder(
            textFrame, "NSkinQuestModelSceneTextBackgroundBorder")
        if oldTextBorder then NSkin:SetPixelBorderShown(oldTextBorder, false) end
    end

    NSkin:RegisterSkinningElement(QuestModelSceneIDs.Window, {
        label = "Quest model scene window",
        kind = "WINDOW",
        module = "NPCInteraction",
        appearanceWindowID = QuestModelSceneIDs.Scope,
        window = scene,
        target = scene,
        priority = 0,
        draggable = false,
        refreshAppearance = function()
            return NPCInteractionSkin:ApplyQuestModelSceneWindow(scene)
        end,
        refreshLayout = function()
            return NPCInteractionSkin:ApplyQuestModelSceneWindow(scene)
        end,
        isEditable = function()
            return IsVisible(scene)
        end,
    })
    return true
end

function NPCInteractionSkin:ApplyQuestModelSceneContent(scene)
    local applied = false
    for _, definition in ipairs({
        { QuestModelSceneIDs.Name, "Quest model NPC name",
            _G.QuestNPCModelNameText, 20 },
        { QuestModelSceneIDs.Description, "Quest model description",
            _G.QuestNPCModelText, 21 },
    }) do
        local id, label, target, priority = unpack(definition)
        if target then
            local element = NSkin:RegisterTextElement({
                id = id,
                module = "NPCInteraction",
                appearanceWindowID = QuestModelSceneIDs.Scope,
                label = label,
                window = scene,
                target = target,
                priority = priority,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(scene) and IsVisible(target)
                end,
            })
            applied = RefreshElement(element) ~= nil or applied
        end
    end

    local scrollFrame = _G.QuestNPCModelTextScrollFrame
    local scrollBar = scrollFrame and scrollFrame.ScrollBar
    if scrollBar then
        local element = NSkin:RegisterScrollBar({
            id = QuestModelSceneIDs.ScrollBar,
            module = "NPCInteraction",
            appearanceWindowID = QuestModelSceneIDs.Scope,
            label = "Quest model description scroll bar",
            window = scene,
            target = scrollBar,
            priority = 30,
            highlightRegions = { scrollBar },
            isEditable = function()
                return IsVisible(scene) and IsVisible(scrollBar)
            end,
        })
        applied = RefreshElement(element) ~= nil or applied
    end
    return applied
end

function NPCInteractionSkin:ApplyQuestModelScene()
    local scene = _G.QuestModelScene
    if not scene then return false end
    local applied = self:ApplyQuestModelSceneWindow(scene)
    applied = self:ApplyQuestModelSceneContent(scene) or applied
    return applied
end

function NPCInteractionSkin:InitializeQuestModelScene()
    local scene = _G.QuestModelScene
    if not scene then return false end
    if not questModelSceneShowHooked and scene.HookScript then
        scene:HookScript("OnShow", function()
            NPCInteractionSkin:ApplyQuestModelScene()
        end)
        questModelSceneShowHooked = true
    end
    if not questModelSceneDisplayHooked and _G.hooksecurefunc
        and type(_G.QuestFrame_ShowQuestPortrait) == "function"
    then
        _G.hooksecurefunc("QuestFrame_ShowQuestPortrait", function()
            NPCInteractionSkin:ApplyQuestModelScene()
        end)
        questModelSceneDisplayHooked = true
    end
    local mixin = _G.QuestFrameModelSceneMixin
    if not questModelSceneMixinHooked and mixin and _G.hooksecurefunc
        and type(mixin.OnShow) == "function"
    then
        _G.hooksecurefunc(mixin, "OnShow", function(owner)
            if owner == _G.QuestModelScene then
                NPCInteractionSkin:ApplyQuestModelScene()
            end
        end)
        questModelSceneMixinHooked = true
    end
    questModelSceneInitialized = true
    return self:ApplyQuestModelScene()
end

NSkin:RegisterWindowSkin({
    key = "NPCInteraction.QuestModelScene",
    module = "NPCInteraction",
    addon = "Blizzard_UIPanels_Game",
    apply = function()
        return NPCInteractionSkin:InitializeQuestModelScene()
    end,
})

local TrainerIDs = {
    Scope = "ClassTrainer",
    Window = "ClassTrainer.Window",
    HeaderControls = "ClassTrainer.HeaderControls",
    ProgressBar = "ClassTrainer.ProgressBar",
    Filter = "ClassTrainer.Filter",
    ScrollBar = "ClassTrainer.ScrollBar",
    TrainButton = "ClassTrainer.TrainButton",
    MoneyGold = "ClassTrainer.MoneyGold",
    MoneySilver = "ClassTrainer.MoneySilver",
    MoneyCopper = "ClassTrainer.MoneyCopper",
    SkillStep = "ClassTrainer.SkillStep",
    Rows = "ClassTrainer.Rows",
}

local trainerInitialized = false
local trainerShowHooked = false
local trainerScrollBoxHooked = false
local trainerSkillStepRegistered = false
local trainerRowsRegistered = false

NSkin:RegisterAppearanceScope(TrainerIDs.Scope, {
    label = "Class Trainer",
})

local function GetTrainerScrollBox(frame)
    return frame and frame.ScrollBox
end

local function GetTrainerProgressBar()
    local background = _G.ClassTrainerStatusBarBackground
    if background and background.GetObjectType
        and background:GetObjectType() == "StatusBar"
    then
        return background, nil
    end
    local parent = background and background.GetParent
        and background:GetParent()
    if parent and parent.GetObjectType
        and parent:GetObjectType() == "StatusBar"
    then
        return parent, background
    end
    local bar = _G.ClassTrainerStatusBar
    if bar and bar.GetObjectType and bar:GetObjectType() == "StatusBar" then
        return bar, background
    end
end

local function GetTrainerRowRegion(row, field, suffix)
    if not row then return nil end
    local lowerField = string.lower(string.sub(field, 1, 1))
        .. string.sub(field, 2)
    local target = row[field] or row[lowerField]
    if target then return target end
    local name = row.GetName and row:GetName()
    return name and _G[name .. suffix] or nil
end

local function GetTrainerRowIcon(row)
    return GetTrainerRowRegion(row, "Icon", "Icon")
        or GetTrainerRowRegion(row, "IconTexture", "IconTexture")
end

local function GetTrainerRowTexts(row)
    return {
        GetTrainerRowRegion(row, "Name", "Name"),
        GetTrainerRowRegion(row, "SubText", "SubText"),
    }
end

local function GetVisibleTrainerRows(frame)
    local rows = {}
    NSkin:ForEachScrollBoxFrame(GetTrainerScrollBox(frame), function(row)
        if IsVisible(row) then rows[#rows + 1] = row end
    end)
    return rows
end

local function GetTrainerRowStyles()
    local styles = {
        row = NSkin:GetAppearanceStyle(
            "row", TrainerIDs.Scope, TrainerIDs.Rows),
        icon = NSkin:GetAppearanceStyle(
            "icon", TrainerIDs.Scope, TrainerIDs.Rows),
        text = NSkin:GetAppearanceStyle(
            "text", TrainerIDs.Scope, TrainerIDs.Rows),
    }
    styles.rowBorder = NSkin:GetAppearanceBorderColor(
        "row", styles.row, TrainerIDs.Scope, TrainerIDs.Rows)
    styles.iconBorder = NSkin:GetAppearanceBorderColor(
        "icon", styles.icon, TrainerIDs.Scope, TrainerIDs.Rows)
    return styles
end

function NPCInteractionSkin:ApplyTrainerWindowChrome(frame)
    local bottomInset = _G.ClassTrainerFrameBottomInset
        or frame.BottomInset
    local bottomInsetNineSlice = bottomInset and bottomInset.NineSlice
    local scrollBox = GetTrainerScrollBox(frame)
    local scrollBoxShadows = scrollBox and scrollBox.Shadows
    SuppressDecorations(frame, {
        _G.ClassTrainerFrameBG or frame.BG,
        scrollBoxShadows,
        scrollBoxShadows and scrollBoxShadows.Upper,
        scrollBoxShadows and scrollBoxShadows.Lower,
        bottomInset and bottomInset.Bg,
        bottomInsetNineSlice and bottomInsetNineSlice.TopEdge,
        bottomInsetNineSlice and bottomInsetNineSlice.BottomEdge,
        bottomInsetNineSlice and bottomInsetNineSlice.LeftEdge,
        bottomInsetNineSlice and bottomInsetNineSlice.RightEdge,
        bottomInsetNineSlice and bottomInsetNineSlice.TopLeftCorner,
        bottomInsetNineSlice and bottomInsetNineSlice.TopRightCorner,
        bottomInsetNineSlice and bottomInsetNineSlice.BottomLeftCorner,
        bottomInsetNineSlice and bottomInsetNineSlice.BottomRightCorner,
        _G.ClassTrainerFrameMoneyBg or frame.MoneyBg,
    })
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = TrainerIDs.Scope,
        elementID = TrainerIDs.Window,
        headerControlsID = TrainerIDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText
            or _G.ClassTrainerFrameTitleText,
        closeButton = frame.CloseButton or _G.ClassTrainerFrameCloseButton,
    })
    NSkin:RegisterSkinningElement(TrainerIDs.Window, {
        label = "Class Trainer window",
        kind = "WINDOW",
        module = "NPCInteraction",
        appearanceWindowID = TrainerIDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function NPCInteractionSkin:ApplyTrainerProgressBar(frame)
    local bar = GetTrainerProgressBar()
    if not bar then return false end
    local skinOptions = {
        stripArtwork = true,
        useAppearanceTexture = true,
        background = true,
    }
    NSkin:SkinProgressBar(bar, skinOptions)
    local element = NSkin:RegisterProgressBarElement({
        id = TrainerIDs.ProgressBar,
        module = "NPCInteraction",
        appearanceWindowID = TrainerIDs.Scope,
        label = "Trainer skill progress bar",
        window = frame,
        target = bar,
        priority = 20,
        draggable = false,
        skinOptions = skinOptions,
        highlightRegions = { bar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(bar)
        end,
    })
    return element ~= nil
end

function NPCInteractionSkin:ApplyTrainerControls(frame)
    local applied = false
    local filter = frame.FilterDropdown
        or _G.ClassTrainerFrameFilterDropdown
        or _G.ClassTrainerFrameFilterDropDown
    if filter then
        applied = RefreshElement(NSkin:RegisterDropdown({
            id = TrainerIDs.Filter,
            module = "NPCInteraction",
            appearanceWindowID = TrainerIDs.Scope,
            label = "Trainer filter",
            window = frame,
            target = filter,
            menus = { "MENU_TRAINER_FILTER" },
            priority = 30,
            highlightRegions = { filter },
            isEditable = function()
                return IsVisible(frame) and IsVisible(filter)
            end,
        })) ~= nil or applied
    end

    local scrollBar = frame.ScrollBar
    if scrollBar then
        applied = RefreshElement(NSkin:RegisterScrollBar({
            id = TrainerIDs.ScrollBar,
            module = "NPCInteraction",
            appearanceWindowID = TrainerIDs.Scope,
            label = "Trainer scroll bar",
            window = frame,
            target = scrollBar,
            priority = 40,
            highlightRegions = { scrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(scrollBar)
            end,
        })) ~= nil or applied
    end

    local trainButton = _G.ClassTrainerTrainButton or frame.TrainButton
    if trainButton then
        applied = RefreshElement(NSkin:RegisterTypedElement("BUTTON", {
            id = TrainerIDs.TrainButton,
            module = "NPCInteraction",
            appearanceWindowID = TrainerIDs.Scope,
            label = "Train button",
            window = frame,
            target = trainButton,
            priority = 50,
            isEditable = function()
                return IsVisible(frame) and IsVisible(trainButton)
            end,
        })) ~= nil or applied
    end

    for _, definition in ipairs({
        { TrainerIDs.MoneyGold, "Trainer gold text",
            _G.ClassTrainerFrameMoneyFrameGoldButtonText },
        { TrainerIDs.MoneySilver, "Trainer silver text",
            _G.ClassTrainerFrameMoneyFrameSilverButtonText },
        { TrainerIDs.MoneyCopper, "Trainer copper text",
            _G.ClassTrainerFrameMoneyFrameCopperButtonText },
    }) do
        local id, label, target = unpack(definition)
        if target then
            applied = RefreshElement(NSkin:RegisterTextElement({
                id = id,
                module = "NPCInteraction",
                appearanceWindowID = TrainerIDs.Scope,
                label = label,
                window = frame,
                target = target,
                priority = 60,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })) ~= nil or applied
        end
    end

    return applied
end

function NPCInteractionSkin:StyleTrainerSkillStep(skillStep)
    if not skillStep then return false end
    local styles = {
        row = NSkin:GetAppearanceStyle(
            "row", TrainerIDs.Scope, TrainerIDs.SkillStep),
        icon = NSkin:GetAppearanceStyle(
            "icon", TrainerIDs.Scope, TrainerIDs.SkillStep),
        text = NSkin:GetAppearanceStyle(
            "text", TrainerIDs.Scope, TrainerIDs.SkillStep),
    }
    styles.rowBorder = NSkin:GetAppearanceBorderColor(
        "row", styles.row, TrainerIDs.Scope, TrainerIDs.SkillStep)
    styles.iconBorder = NSkin:GetAppearanceBorderColor(
        "icon", styles.icon, TrainerIDs.Scope, TrainerIDs.SkillStep)

    local nativeDecorations = {}
    for _, region in pairs({
        GetButtonTexture(skillStep, "GetNormalTexture", "NormalTexture"),
        skillStep.selectedTex
            or _G.ClassTrainerFrameSkillStepButtonSelectedTex,
    }) do
        if region then nativeDecorations[#nativeDecorations + 1] = region end
    end
    local applied = NSkin:SkinRow(skillStep, {
        style = styles.row,
        border = styles.rowBorder,
        nativeDecorationRegions = nativeDecorations,
        hoverRegion = GetButtonTexture(
            skillStep, "GetHighlightTexture", "HighlightTexture"),
        getHovered = IsHovered,
    }) ~= nil

    local icon = GetTrainerRowIcon(skillStep)
        or _G.ClassTrainerFrameSkillStepButtonIcon
    if icon then
        applied = NSkin:SkinIcon(skillStep, {
            style = styles.icon,
            borderColor = styles.iconBorder,
            texture = icon,
            borderOwner = skillStep,
        }) == true or applied
    end
    for _, text in pairs(GetTrainerRowTexts(skillStep)) do
        if text then
            applied = NSkin:SkinText(text, styles.text) == true or applied
        end
    end
    return applied
end

function NPCInteractionSkin:ApplyTrainerSkillStep(frame)
    local skillStep = frame.SkillStepButton
        or frame.skillStepButton
        or _G.ClassTrainerFrameSkillStepButton
    if not skillStep then return false end
    local applied = self:StyleTrainerSkillStep(skillStep)
    if not trainerSkillStepRegistered then
        local function RefreshSkillStep()
            return NPCInteractionSkin:StyleTrainerSkillStep(skillStep)
        end
        trainerSkillStepRegistered = NSkin:RegisterSkinningElement(
            TrainerIDs.SkillStep, {
                module = "NPCInteraction",
                appearanceWindowID = TrainerIDs.Scope,
                label = "Selected trainer skill row",
                kind = "ROW",
                window = frame,
                target = skillStep,
                priority = 70,
                draggable = false,
                appearanceStyles = { "icon", "text" },
                appearanceTypeIDs = { "ICON", "TEXT" },
                highlightRegions = { skillStep },
                pixelBorderTargets = { skillStep },
                editorOptions = {
                    { id = "shared.rowAppearance", label = "Row",
                        category = "CUSTOMIZE" },
                    { id = "shared.iconAppearance", label = "Row icon",
                        category = "CUSTOMIZE" },
                    { id = "shared.textAppearance", label = "Row text",
                        category = "CUSTOMIZE" },
                },
                refreshAppearance = RefreshSkillStep,
                refreshLayout = RefreshSkillStep,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(skillStep)
                end,
            }) == true
    end
    if trainerSkillStepRegistered then
        NSkin:NotifySkinningElementBoundsChanged(TrainerIDs.SkillStep)
    end
    return applied or trainerSkillStepRegistered
end

function NPCInteractionSkin:StyleTrainerRow(row, styles)
    if not row then return false end
    styles = styles or GetTrainerRowStyles()
    local normalTexture = GetButtonTexture(
        row, "GetNormalTexture", "NormalTexture")
    local applied = NSkin:SkinRow(row, {
        style = styles.row,
        border = styles.rowBorder,
        nativeDecorationRegions = normalTexture
            and { normalTexture } or nil,
        hoverRegion = GetButtonTexture(
            row, "GetHighlightTexture", "HighlightTexture"),
        selectedRegion = GetButtonTexture(
            row, "GetCheckedTexture", "SelectedTexture")
            or row.selectedTex,
        getHovered = IsHovered,
        getSelected = function(target)
            if target and target.GetChecked then
                return target:GetChecked() == true
            end
            return target and (target.selected == true
                or target.isSelected == true) or false
        end,
    }) ~= nil

    local icon = GetTrainerRowIcon(row)
    if icon then
        local nativeDecorations = {}
        local iconBorder = row.IconBorder or row.iconBorder
        if iconBorder then nativeDecorations[1] = iconBorder end
        applied = NSkin:SkinIcon(row, {
            style = styles.icon,
            borderColor = styles.iconBorder,
            texture = icon,
            borderOwner = row,
            nativeDecorationRegions = nativeDecorations,
        }) == true or applied
    end
    for _, text in pairs(GetTrainerRowTexts(row)) do
        if text then
            applied = NSkin:SkinText(text, styles.text) == true or applied
        end
    end
    return applied
end

function NPCInteractionSkin:ApplyTrainerRows(frame)
    local scrollBox = GetTrainerScrollBox(frame)
    if not scrollBox then return false end
    local styles = GetTrainerRowStyles()
    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
        applied = self:StyleTrainerRow(row, styles) or applied
    end)

    if not trainerRowsRegistered then
        local function RefreshRows()
            return NPCInteractionSkin:ApplyTrainerRows(frame)
        end
        trainerRowsRegistered = NSkin:RegisterSkinningElement(
            TrainerIDs.Rows, {
                module = "NPCInteraction",
                appearanceWindowID = TrainerIDs.Scope,
                label = "Trainer skill rows",
                kind = "ROW",
                window = frame,
                target = scrollBox,
                priority = 80,
                draggable = false,
                appearanceStyles = { "icon", "text" },
                appearanceTypeIDs = { "ICON", "TEXT" },
                highlightRegions = function()
                    return GetVisibleTrainerRows(frame)
                end,
                pixelBorderTargets = function()
                    return GetVisibleTrainerRows(frame)
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
                        and #GetVisibleTrainerRows(frame) > 0
                end,
            }) == true
    end
    if trainerRowsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(TrainerIDs.Rows)
    end
    return applied or trainerRowsRegistered
end

function NPCInteractionSkin:HookTrainerScrollBox(frame)
    local scrollBox = GetTrainerScrollBox(frame)
    if not scrollBox or trainerScrollBoxHooked then return false end
    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, row)
                NPCInteractionSkin:StyleTrainerRow(row)
                if trainerRowsRegistered then
                    NSkin:NotifySkinningElementBoundsChanged(TrainerIDs.Rows)
                end
            end, self)
        trainerScrollBoxHooked = true
    elseif _G.hooksecurefunc and type(scrollBox.Update) == "function" then
        _G.hooksecurefunc(scrollBox, "Update", function()
            NPCInteractionSkin:ApplyTrainerRows(frame)
        end)
        trainerScrollBoxHooked = true
    end
    return trainerScrollBoxHooked
end

function NPCInteractionSkin:ApplyClassTrainer()
    local frame = _G.ClassTrainerFrame
    if not frame then return false end
    local applied = self:ApplyTrainerWindowChrome(frame)
    applied = self:ApplyTrainerProgressBar(frame) or applied
    applied = self:ApplyTrainerControls(frame) or applied
    applied = self:ApplyTrainerSkillStep(frame) or applied
    applied = self:ApplyTrainerRows(frame) or applied
    return applied
end

function NPCInteractionSkin:InitializeClassTrainer()
    local frame = _G.ClassTrainerFrame
    if not frame then return false end
    if not trainerShowHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            NPCInteractionSkin:ApplyClassTrainer()
        end)
        trainerShowHooked = true
    end
    self:HookTrainerScrollBox(frame)
    trainerInitialized = true
    return self:ApplyClassTrainer()
end

function NPCInteractionSkin:RefreshAppearance()
    if gossipInitialized then self:ApplyGossip() end
    if questInitialized then self:ApplyQuest() end
    if questModelSceneInitialized then self:ApplyQuestModelScene() end
    if trainerInitialized then self:ApplyClassTrainer() end
end

NSkin:RegisterWindowSkin({
    key = "NPCInteraction.ClassTrainer",
    module = "NPCInteraction",
    addon = "Blizzard_TrainerUI",
    apply = function()
        return NPCInteractionSkin:InitializeClassTrainer()
    end,
})
