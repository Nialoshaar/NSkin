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

function NPCInteractionSkin:RefreshAppearance()
    if gossipInitialized then self:ApplyGossip() end
    if questInitialized then self:ApplyQuest() end
end

NSkin:RegisterWindowSkin({
    key = "NPCInteraction.Quest",
    module = "NPCInteraction",
    addon = "Blizzard_UIPanels_Game",
    apply = function() return NPCInteractionSkin:InitializeQuest() end,
})
