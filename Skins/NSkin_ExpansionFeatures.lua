local _, NSkin = ...

local ExpansionFeaturesSkin = NSkin:NewModule("ExpansionFeatures")

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
    PlayerChoice = {
        Scope = "PlayerChoice",
        Window = "PlayerChoice.Window",
        CloseButton = "PlayerChoice.CloseButton",
        Title = "PlayerChoice.Title",
        Description = "PlayerChoice.Description",
        Headers = "PlayerChoice.Options.Headers",
        HeaderIcons = "PlayerChoice.Options.HeaderIcons",
        Descriptions = "PlayerChoice.Options.Descriptions",
        SubHeaders = "PlayerChoice.Options.SubHeaders",
        ActionButtons = "PlayerChoice.Options.ActionButtons",
        RewardIcons = "PlayerChoice.Options.RewardIcons",
        RewardText = "PlayerChoice.Options.RewardText",
        Paging = {
            Group = "PlayerChoice.Paging",
            Previous = "PlayerChoice.Paging.Previous",
            Next = "PlayerChoice.Paging.Next",
            Text = "PlayerChoice.Paging.Text",
        },
        Grid = {
            NoSelectionHeader = "PlayerChoice.Grid.NoSelectionHeader",
            NoSelectionDescription =
                "PlayerChoice.Grid.NoSelectionDescription",
            SelectionHeader = "PlayerChoice.Grid.SelectionHeader",
            SelectionDescription = "PlayerChoice.Grid.SelectionDescription",
        },
    },
    CovenantMission = {
        Scope = "CovenantMission",
        Window = "CovenantMission.Window",
        CloseButton = "CovenantMission.CloseButton",
        Title = "CovenantMission.Title",
    },
    AdventureMapQuestChoice = {
        Scope = "AdventureMapQuestChoice",
        Window = "AdventureMapQuestChoice.Window",
        CloseButton = "AdventureMapQuestChoice.CloseButton",
        QuestTitle = "AdventureMapQuestChoice.Title",
        Description = "AdventureMapQuestChoice.Description",
        ObjectivesHeader = "AdventureMapQuestChoice.ObjectivesHeader",
        ObjectivesText = "AdventureMapQuestChoice.Objectives",
        ScrollBar = "AdventureMapQuestChoice.ScrollBar",
        RewardsHeader = "AdventureMapQuestChoice.RewardsHeader",
        RewardIcons = "AdventureMapQuestChoice.RewardIcons",
        RewardNames = "AdventureMapQuestChoice.RewardNames",
        RewardCounts = "AdventureMapQuestChoice.RewardCounts",
        AcceptButton = "AdventureMapQuestChoice.Accept",
        DeclineButton = "AdventureMapQuestChoice.Decline",
    },
}

local initialized = false
local genericTraitInitialized = false
local playerChoiceInitialized = false
local covenantMissionInitialized = false
local adventureMapQuestChoiceInitialized = false
local applyPending = false
local playerChoiceApplyPending = false
local covenantMissionApplyPending = false
local adventureMapQuestChoiceApplyPending = false
local lifecycleHooked = false
local genericTraitLifecycleHooked = false
local playerChoiceLifecycleHooked = false
local covenantMissionLifecycleHooked = false
local adventureMapQuestChoiceLifecycleHooked = false
local genericTraitIconsRegistered = false
local playerChoicePaginationController
local registryCallbackRegistered = false
local concealedArtwork = setmetatable({}, { __mode = "k" })
local hookedOverlays = setmetatable({}, { __mode = "k" })
local suppressedRegions = setmetatable({}, { __mode = "k" })
local registeredPlayerChoiceGroups = {}
local registeredAdventureMapQuestChoiceGroups = {}
local hookedPlayerChoicePools = setmetatable({}, { __mode = "k" })
local hookedAdventureMapRewardPools = setmetatable({}, { __mode = "k" })
local hookedCovenantMissionLifecycleTargets =
    setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Midnight Features",
})
NSkin:RegisterAppearanceScope(IDs.GenericTrait.Scope, {
    label = "Generic Trait",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.PlayerChoice.Scope, {
    label = "Player Choice",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.CovenantMission.Scope, {
    label = "Covenant Mission",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.AdventureMapQuestChoice.Scope, {
    label = "Adventure Map Quest Choice",
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
        ExpansionFeaturesSkin:Apply()
    end)
end

function ExpansionFeaturesSkin:ApplyOmniumFolioChrome()
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
        module = "ExpansionFeatures",
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

local function QueuePlayerChoiceApply()
    if playerChoiceApplyPending then return end
    playerChoiceApplyPending = true
    C_Timer.After(0, function()
        playerChoiceApplyPending = false
        ExpansionFeaturesSkin:ApplyPlayerChoice()
    end)
end

local function QueueCovenantMissionApply()
    if covenantMissionApplyPending then return end
    covenantMissionApplyPending = true
    C_Timer.After(0, function()
        covenantMissionApplyPending = false
        ExpansionFeaturesSkin:ApplyCovenantMission()
    end)
end

local function QueueAdventureMapQuestChoiceApply()
    if adventureMapQuestChoiceApplyPending then return end
    adventureMapQuestChoiceApplyPending = true
    C_Timer.After(0, function()
        adventureMapQuestChoiceApplyPending = false
        ExpansionFeaturesSkin:ApplyAdventureMapQuestChoice()
    end)
end

local function AddUnique(list, seen, target)
    if not target or seen[target] then return end
    seen[target] = true
    list[#list + 1] = target
end

local function AddArrayValues(list, seen, values)
    if type(values) ~= "table" or values.GetObjectType then return end
    for _, value in pairs(values) do
        if type(value) == "table" or type(value) == "userdata" then
            AddUnique(list, seen, value)
        end
    end
end

local function AddPoolValues(list, seen, pool)
    if not pool or type(pool.EnumerateActive) ~= "function" then return end
    for value in pool:EnumerateActive() do AddUnique(list, seen, value) end
end

local function AddActiveOptionsByTemplate(list, seen, frame)
    local pools = frame and frame.optionPools
    local template = frame and frame.optionFrameTemplate
    if not pools or not template
        or type(pools.EnumerateActiveByTemplate) ~= "function"
    then
        return false
    end
    for option in pools:EnumerateActiveByTemplate(template) do
        AddUnique(list, seen, option)
    end
    return true
end

local function AddChildren(list, seen, container, predicate)
    if not container or type(container.GetChildren) ~= "function" then return end
    local children = { container:GetChildren() }
    for _, child in ipairs(children) do
        if not predicate or predicate(child) then AddUnique(list, seen, child) end
    end
end

local function HasPlayerChoiceOptionStructure(option)
    return option and (option.Header or option.OptionHeader or option.OptionText
        or option.SubHeader or option.Buttons or option.OptionButtons
        or option.Rewards or option.RewardFrame or option.Artwork)
end

local function GetPlayerChoiceOptions(frame, visibleOnly)
    local options, seen = {}, {}
    AddActiveOptionsByTemplate(options, seen, frame)
    for _, values in ipairs({
        frame and frame.Options,
        frame and frame.options,
        frame and frame.OptionFrames,
        frame and frame.optionFrames,
    }) do
        AddArrayValues(options, seen, values)
    end
    for _, pool in ipairs({
        frame and frame.optionFramePool,
        frame and frame.optionPool,
        frame and frame.OptionFramePool,
        frame and frame.OptionsPool,
    }) do
        AddPoolValues(options, seen, pool)
    end
    for _, container in ipairs({
        frame and frame.OptionFrameContainer,
        frame and frame.OptionsFrame,
        frame and frame.Options,
        frame and frame.Content,
    }) do
        AddChildren(options, seen, container, HasPlayerChoiceOptionStructure)
    end
    if not visibleOnly then return options end
    local visible = {}
    for _, option in ipairs(options) do
        if IsVisible(option) then visible[#visible + 1] = option end
    end
    return visible
end

local function AddFontRegions(list, seen, target)
    if not target then return end
    local objectType = target.GetObjectType and target:GetObjectType()
    if objectType == "FontString" then
        AddUnique(list, seen, target)
        return
    end
    if objectType == "SimpleHTML" then
        AddUnique(list, seen, target)
        return
    end
    for _, child in ipairs({
        target.String, target.Text, target.Label, target.Description,
    }) do
        local childType = child and child.GetObjectType
            and child:GetObjectType()
        if childType == "FontString" or childType == "SimpleHTML" then
            AddUnique(list, seen, child)
        end
    end
    if type(target.GetRegions) == "function" then
        for _, region in ipairs({ target:GetRegions() }) do
            if region and region.GetObjectType
                and region:GetObjectType() == "FontString"
            then
                AddUnique(list, seen, region)
            end
        end
    end
end

local function GetPlayerChoiceHeaderTexts(frame)
    local targets, seen = {}, {}
    for _, option in ipairs(GetPlayerChoiceOptions(frame, false)) do
        local header = option.Header or option.OptionHeader
        local contents = header and header.Contents
        AddFontRegions(targets, seen, contents and contents.Text)
        AddFontRegions(targets, seen,
            header and (header.Text or header.Title) or header)
        AddFontRegions(targets, seen, option.HeaderText)
    end
    return targets
end

local function GetPlayerChoiceDescriptionTexts(frame)
    local targets, seen = {}, {}
    for _, option in ipairs(GetPlayerChoiceOptions(frame, false)) do
        local description = option.OptionText or option.Description
        AddFontRegions(targets, seen, description)
        if description then
            AddFontRegions(targets, seen, description.String)
            AddFontRegions(targets, seen, description.HTML)
            AddFontRegions(targets, seen, description.SimpleHTML)
        end
    end
    return targets
end

local function GetPlayerChoiceSubHeaderTexts(frame)
    local targets, seen = {}, {}
    for _, option in ipairs(GetPlayerChoiceOptions(frame, false)) do
        local subHeader = option.SubHeader or option.OptionSubHeader
        AddFontRegions(targets, seen,
            subHeader and (subHeader.Text or subHeader.Title) or subHeader)
        AddFontRegions(targets, seen, option.SubHeaderText)
    end
    return targets
end

local function IsButton(target)
    if not target then return false end
    local objectType = target.GetObjectType and target:GetObjectType()
    return objectType == "Button" or target.GetScript and target:GetScript("OnClick")
end

local function GetPlayerChoiceActionButtons(frame)
    local buttons, seen = {}, {}
    for _, option in ipairs(GetPlayerChoiceOptions(frame, false)) do
        local optionButtons = option.OptionButtonsContainer
        local buttonFramePool = optionButtons and optionButtons.buttonFramePool
        if buttonFramePool
            and type(buttonFramePool.EnumerateActive) == "function"
        then
            for buttonFrame in buttonFramePool:EnumerateActive() do
                AddUnique(buttons, seen,
                    buttonFrame and buttonFrame.Button)
            end
        end
        for _, values in ipairs({ option.Buttons, option.OptionButtons,
            option.buttons }) do
            AddArrayValues(buttons, seen, values)
        end
        for _, pool in ipairs({ option.buttonPool, option.ButtonPool,
            option.optionButtonPool }) do
            AddPoolValues(buttons, seen, pool)
        end
        for _, container in ipairs({ option.ButtonContainer,
            option.ButtonsContainer, option.ButtonFrame, option.Buttons,
            option.OptionButtons, option.OptionButtonsContainer }) do
            AddChildren(buttons, seen, container, IsButton)
        end
        if IsButton(option.Button) then AddUnique(buttons, seen, option.Button) end
    end
    return buttons
end

local function GetPlayerChoiceRewards(frame)
    local rewards, seen = {}, {}
    for _, option in ipairs(GetPlayerChoiceOptions(frame, false)) do
        for _, values in ipairs({ option.Rewards, option.rewards,
            option.RewardFrames }) do
            AddArrayValues(rewards, seen, values)
        end
        for _, pool in ipairs({ option.rewardPool, option.RewardPool,
            option.itemRewardPool, option.currencyRewardPool,
            option.reputationRewardPool }) do
            AddPoolValues(rewards, seen, pool)
        end
        for _, container in ipairs({ option.RewardFrame, option.RewardsFrame,
            option.RewardContainer, option.Rewards }) do
            AddChildren(rewards, seen, container)
        end
    end
    return rewards
end

local function GetPlayerChoiceRewardIcons(frame)
    local descriptors = {}
    for _, reward in ipairs(GetPlayerChoiceRewards(frame)) do
        local texture = reward.Icon or reward.icon or reward.ItemIcon
            or reward.CurrencyIcon
        if texture then
            descriptors[#descriptors + 1] = {
                target = reward,
                texture = texture,
                borderOwner = reward,
                hoverRegion = reward.GetHighlightTexture
                    and reward:GetHighlightTexture() or reward.Highlight,
            }
        end
    end
    return descriptors
end

local function GetPlayerChoiceRewardText(frame)
    local targets, seen = {}, {}
    for _, reward in ipairs(GetPlayerChoiceRewards(frame)) do
        AddFontRegions(targets, seen, reward)
        for _, target in ipairs({ reward.Text, reward.Name, reward.Label,
            reward.Quantity, reward.Amount, reward.ReputationText }) do
            AddFontRegions(targets, seen, target)
        end
    end
    return targets
end

local function GetVisibleTargets(provider)
    local visible = {}
    for _, target in ipairs(provider()) do
        if IsVisible(target) then visible[#visible + 1] = target end
    end
    return visible
end

local function RegisterPlayerChoiceGroup(frame, definition)
    local id = definition.id
    local function VisibleTargets()
        return GetVisibleTargets(definition.targets)
    end
    if not registeredPlayerChoiceGroups[id] then
        registeredPlayerChoiceGroups[id] = NSkin:RegisterSkinningElement(id, {
            label = definition.label,
            kind = definition.kind,
            module = "ExpansionFeatures",
            appearanceWindowID = IDs.PlayerChoice.Scope,
            window = frame,
            target = definition.owner or frame,
            priority = definition.priority,
            draggable = false,
            appearanceStyles = definition.appearanceStyles,
            appearanceTypeIDs = definition.appearanceTypeIDs,
            highlightRegions = VisibleTargets,
            pixelBorderTargets = definition.pixelBorders
                and VisibleTargets or nil,
            refreshAppearance = definition.refresh,
            refreshLayout = definition.refresh,
            isEditable = function()
                return IsVisible(frame) and #VisibleTargets() > 0
            end,
        }) == true
    end
    local applied = definition.refresh()
    if registeredPlayerChoiceGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or registeredPlayerChoiceGroups[id]
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

function ExpansionFeaturesSkin:ApplyGenericTraitWindow(frame)
    SuppressRegion(frame.Background)
    SuppressRegion(frame.BorderOverlay)
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
        module = "ExpansionFeatures",
        appearanceWindowID = IDs.GenericTrait.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function ExpansionFeaturesSkin:ApplyGenericTraitTitle(frame)
    local title = frame.Header and frame.Header.Title
    if not title then return false end
    local element = NSkin:RegisterTextElement({
        id = IDs.GenericTrait.Title,
        module = "ExpansionFeatures",
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

function ExpansionFeaturesSkin:ApplyGenericTraitIcons(frame)
    local parent = frame.ButtonsParent
    if not parent then return false end
    if not genericTraitIconsRegistered then
        genericTraitIconsRegistered = NSkin:RegisterIconGroup({
            id = IDs.GenericTrait.Icons,
            module = "ExpansionFeatures",
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

function ExpansionFeaturesSkin:ApplyGenericTrait()
    local frame = _G.GenericTraitFrame
    if not frame then return false end
    local applied = self:ApplyGenericTraitWindow(frame)
    applied = self:ApplyGenericTraitTitle(frame) or applied
    applied = self:ApplyGenericTraitIcons(frame) or applied
    return applied
end

local function GetPlayerChoiceHeaderIcons(frame)
    local descriptors = {}
    for _, option in ipairs(GetPlayerChoiceOptions(frame, false)) do
        local header = option.Header or option.OptionHeader
        local icon = header and header.Icon or option.HeaderIcon
        if icon then
            descriptors[#descriptors + 1] = {
                target = header or option,
                texture = icon,
                borderOwner = header or option,
            }
        end
    end
    return descriptors
end

local function GetDescriptorTargets(provider)
    local targets = {}
    for _, descriptor in ipairs(provider()) do
        targets[#targets + 1] = descriptor.target
    end
    return targets
end

local function SkinPlayerChoiceTextFamily(id, provider)
    local style = NSkin:GetAppearanceStyle(
        "text", IDs.PlayerChoice.Scope, id)
    local applied = false
    for _, target in ipairs(provider()) do
        if target.GetObjectType and target:GetObjectType() == "SimpleHTML" then
            local data = NSkin:GetSkinData(target, "playerChoiceHTMLText")
            data.fonts = data.fonts or {}
            local color = NSkin:GetResolvedAppearanceColor(style, "color")
            local font, size, outline = NSkin:GetResolvedTypography(style)
            for _, element in ipairs({ "p", "h1", "h2", "h3" }) do
                if not data.fonts[element] and target.GetFont then
                    local ok, originalFont, originalSize, originalOutline =
                        pcall(target.GetFont, target, element)
                    if ok and originalFont then
                        data.fonts[element] = {
                            originalFont, originalSize, originalOutline,
                        }
                    end
                end
                local original = data.fonts[element]
                if original and target.SetFont then
                    pcall(target.SetFont, target, element,
                        font or original[1], tonumber(size) or original[2],
                        outline ~= nil and outline or original[3])
                end
                if color and target.SetTextColor then
                    pcall(target.SetTextColor, target, element, unpack(color))
                end
            end
            if not data.textHooked and _G.hooksecurefunc
                and type(target.SetText) == "function"
            then
                _G.hooksecurefunc(target, "SetText", QueuePlayerChoiceApply)
                data.textHooked = true
            end
            applied = true
        else
            applied = NSkin:SkinText(target, style) or applied
        end
    end
    return applied
end

local function SkinPlayerChoiceIconFamily(id, provider)
    local style = NSkin:GetAppearanceStyle(
        "icon", IDs.PlayerChoice.Scope, id)
    local border = NSkin:GetAppearanceBorderColor(
        "icon", style, IDs.PlayerChoice.Scope, id)
    local applied = false
    for _, descriptor in ipairs(provider()) do
        NSkin:SkinIcon(descriptor.target, {
            texture = descriptor.texture,
            style = style,
            border = border,
            borderOwner = descriptor.borderOwner,
            hoverRegion = descriptor.hoverRegion,
        })
        applied = true
    end
    return applied
end

local function SuppressPlayerChoiceFrameArtwork(frame)
    local header = frame.Header
    local title = frame.Title
    local background = frame.Background
    local closeButton = frame.CloseButton
    for _, region in ipairs({
        header and header.Texture,
        title and title.Left,
        title and title.Middle,
        title and title.Right,
        background and background.BackgroundTile,
        closeButton and closeButton.Border,
        frame.BorderOverlay,
        frame.NineSlice,
    }) do
        SuppressRegion(region)
    end
end

local function SuppressPlayerChoiceOptionArtwork(option)
    if not option then return end
    local header = option.Header or option.OptionHeader
    SuppressRegion(option.Background)
    SuppressRegion(option.ArtworkBorder)
    SuppressRegion(header and header.Ribbon)
end

local function SuppressPlayerChoiceArtwork(frame)
    SuppressPlayerChoiceFrameArtwork(frame)
    for _, option in ipairs(GetPlayerChoiceOptions(frame, false)) do
        SuppressPlayerChoiceOptionArtwork(option)
    end
end

local function RegisterPlayerChoiceText(frame, id, label, target, priority,
    appearanceWindowID)
    if not target then return false end
    local element = NSkin:RegisterTextElement({
        id = id,
        module = "ExpansionFeatures",
        appearanceWindowID = appearanceWindowID or IDs.PlayerChoice.Scope,
        label = label,
        window = frame,
        target = target,
        priority = priority,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(frame) and IsVisible(target)
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element ~= nil
end

function ExpansionFeaturesSkin:ApplyPlayerChoiceWindow(frame)
    SuppressPlayerChoiceArtwork(frame)
    local titleContainer = frame.Title
    local title = titleContainer and (titleContainer.Text
        or titleContainer.Title)
        or titleContainer and titleContainer.GetFont and titleContainer
        or frame.TitleText
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.PlayerChoice.Scope,
        elementID = IDs.PlayerChoice.Window,
        headerControlsID = IDs.PlayerChoice.CloseButton,
        title = title,
        closeButton = frame.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.PlayerChoice.Window, {
        label = "Player choice window",
        kind = "WINDOW",
        module = "ExpansionFeatures",
        appearanceWindowID = IDs.PlayerChoice.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    local applied = RegisterPlayerChoiceText(frame, IDs.PlayerChoice.Title,
        "Player choice title", title, 20)
    local description = frame.MainDescription or frame.MainDescriptionText
        or frame.Description or frame.DescriptionText
    local function GetDescriptionTargets()
        local targets, seen = {}, {}
        AddFontRegions(targets, seen, description)
        return targets
    end
    applied = RegisterPlayerChoiceGroup(frame, {
        id = IDs.PlayerChoice.Description,
        label = "Player choice main description",
        kind = "TEXT",
        priority = 21,
        targets = GetDescriptionTargets,
        appearanceStyles = { "text" },
        appearanceTypeIDs = { "TEXT" },
        refresh = function()
            return SkinPlayerChoiceTextFamily(
                IDs.PlayerChoice.Description, GetDescriptionTargets)
        end,
    }) or applied
    return applied or true
end

function ExpansionFeaturesSkin:ApplyPlayerChoiceOptions(frame)
    local definitions = {
        {
            id = IDs.PlayerChoice.Headers,
            label = "Player choice option headers",
            kind = "TEXT",
            priority = 30,
            targets = function() return GetPlayerChoiceHeaderTexts(frame) end,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            refresh = function()
                return SkinPlayerChoiceTextFamily(
                    IDs.PlayerChoice.Headers,
                    function() return GetPlayerChoiceHeaderTexts(frame) end)
            end,
        },
        {
            id = IDs.PlayerChoice.HeaderIcons,
            label = "Player choice header icons",
            kind = "ICON",
            priority = 31,
            targets = function()
                return GetDescriptorTargets(
                    function() return GetPlayerChoiceHeaderIcons(frame) end)
            end,
            pixelBorders = true,
            refresh = function()
                return SkinPlayerChoiceIconFamily(
                    IDs.PlayerChoice.HeaderIcons,
                    function() return GetPlayerChoiceHeaderIcons(frame) end)
            end,
        },
        {
            id = IDs.PlayerChoice.Descriptions,
            label = "Player choice option descriptions",
            kind = "TEXT",
            priority = 32,
            targets = function()
                return GetPlayerChoiceDescriptionTexts(frame)
            end,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            refresh = function()
                return SkinPlayerChoiceTextFamily(
                    IDs.PlayerChoice.Descriptions,
                    function() return GetPlayerChoiceDescriptionTexts(frame) end)
            end,
        },
        {
            id = IDs.PlayerChoice.SubHeaders,
            label = "Player choice option subheaders",
            kind = "TEXT",
            priority = 33,
            targets = function()
                return GetPlayerChoiceSubHeaderTexts(frame)
            end,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            refresh = function()
                return SkinPlayerChoiceTextFamily(
                    IDs.PlayerChoice.SubHeaders,
                    function() return GetPlayerChoiceSubHeaderTexts(frame) end)
            end,
        },
    }
    local applied = false
    for _, definition in ipairs(definitions) do
        applied = RegisterPlayerChoiceGroup(frame, definition) or applied
    end

    local function RefreshActionButtons()
        local style = NSkin:GetAppearanceStyle(
            "button", IDs.PlayerChoice.Scope,
            IDs.PlayerChoice.ActionButtons)
        local border = NSkin:GetAppearanceBorderColor(
            "button", style, IDs.PlayerChoice.Scope,
            IDs.PlayerChoice.ActionButtons)
        local refreshed = false
        for _, button in ipairs(GetPlayerChoiceActionButtons(frame)) do
            NSkin:SkinActionButton(button, { style = style, border = border })
            refreshed = true
        end
        return refreshed
    end
    applied = RegisterPlayerChoiceGroup(frame, {
        id = IDs.PlayerChoice.ActionButtons,
        label = "Player choice action buttons",
        kind = "ACTION_BUTTON",
        priority = 34,
        targets = function() return GetPlayerChoiceActionButtons(frame) end,
        pixelBorders = true,
        refresh = RefreshActionButtons,
    }) or applied

    applied = RegisterPlayerChoiceGroup(frame, {
        id = IDs.PlayerChoice.RewardIcons,
        label = "Player choice reward icons",
        kind = "ICON",
        priority = 35,
        targets = function()
            return GetDescriptorTargets(
                function() return GetPlayerChoiceRewardIcons(frame) end)
        end,
        pixelBorders = true,
        refresh = function()
            return SkinPlayerChoiceIconFamily(
                IDs.PlayerChoice.RewardIcons,
                function() return GetPlayerChoiceRewardIcons(frame) end)
        end,
    }) or applied
    applied = RegisterPlayerChoiceGroup(frame, {
        id = IDs.PlayerChoice.RewardText,
        label = "Player choice reward text",
        kind = "TEXT",
        priority = 36,
        targets = function() return GetPlayerChoiceRewardText(frame) end,
        appearanceStyles = { "text" },
        appearanceTypeIDs = { "TEXT" },
        refresh = function()
            return SkinPlayerChoiceTextFamily(
                IDs.PlayerChoice.RewardText,
                function() return GetPlayerChoiceRewardText(frame) end)
        end,
    }) or applied
    return applied
end

local function ResolvePlayerChoicePaging(frame)
    local group = frame.PagingControls or frame.PagingFrame
        or frame.PaginationControls
    if not group then return end
    return group,
        group.PrevPageButton or group.PreviousPageButton or group.PreviousButton
            or group.PrevButton,
        group.NextPageButton or group.NextButton,
        group.PageText or group.PageNumber or group.Text
end

function ExpansionFeaturesSkin:ApplyPlayerChoicePaging(frame)
    local group, previous, nextButton, pageText =
        ResolvePlayerChoicePaging(frame)
    if not group or not previous or not nextButton or not pageText then
        return false
    end
    NSkin:SkinPagingControls(group)
    if not playerChoicePaginationController then
        playerChoicePaginationController = NSkin:RegisterPaginationGroup({
            module = "ExpansionFeatures",
            appearanceWindowID = IDs.PlayerChoice.Scope,
            window = frame,
            ids = {
                group = IDs.PlayerChoice.Paging.Group,
                previous = IDs.PlayerChoice.Paging.Previous,
                next = IDs.PlayerChoice.Paging.Next,
                text = IDs.PlayerChoice.Paging.Text,
            },
            controls = {
                group = group,
                previous = previous,
                next = nextButton,
                text = pageText,
            },
            groupLabel = "Player choice pagination",
            groupPriority = 40,
            visibilityFrame = group,
        })
    else
        playerChoicePaginationController:Refresh()
    end
    return true
end

local function ResolvePlayerChoiceGrid(frame)
    return frame.GridLayoutFrame or frame.GridLayout or frame.Grid
        or frame.GridFrame
end

function ExpansionFeaturesSkin:ApplyPlayerChoiceGridText(frame)
    local grid = ResolvePlayerChoiceGrid(frame)
    if not grid then return false end
    local definitions = {
        { IDs.PlayerChoice.Grid.NoSelectionHeader,
            "Player choice grid no-selection header",
            grid.NoSelectionHeader or grid.NoSelectionHeaderText
                or frame.NoSelectionHeader or frame.NoSelectionHeaderText },
        { IDs.PlayerChoice.Grid.NoSelectionDescription,
            "Player choice grid no-selection description",
            grid.NoSelectionDescription or grid.NoSelectionDescriptionText
                or frame.NoSelectionDescription
                or frame.NoSelectionDescriptionText },
        { IDs.PlayerChoice.Grid.SelectionHeader,
            "Player choice grid selection header",
            grid.SelectionHeader or grid.SelectionHeaderText
                or frame.SelectionHeader or frame.SelectionHeaderText },
        { IDs.PlayerChoice.Grid.SelectionDescription,
            "Player choice grid selection description",
            grid.SelectionDescription or grid.SelectionDescriptionText
                or frame.SelectionDescription or frame.SelectionDescriptionText },
    }
    local applied = false
    for index, definition in ipairs(definitions) do
        local target = definition[3]
        if target and not target.GetFont then
            target = target.Text or target.String
        end
        applied = RegisterPlayerChoiceText(frame, definition[1],
            definition[2], target, 50 + index) or applied
    end
    return applied
end

local function HookPlayerChoicePool(pool)
    if not pool or hookedPlayerChoicePools[pool] or not _G.hooksecurefunc then
        return
    end
    for _, method in ipairs({
        "Acquire", "Release", "ReleaseAll", "ReleaseAllByTemplate",
    }) do
        if type(pool[method]) == "function" then
            _G.hooksecurefunc(pool, method, QueuePlayerChoiceApply)
        end
    end
    hookedPlayerChoicePools[pool] = true
end


local function HookPlayerChoicePoolCollection(pools)
    if not pools then return end
    if type(pools.EnumerateActiveByTemplate) == "function" then
        HookPlayerChoicePool(pools)
        return
    end
    if type(pools) ~= "table" then return end
    for _, pool in pairs(pools) do HookPlayerChoicePool(pool) end
end

function ExpansionFeaturesSkin:ApplyPlayerChoice()
    local frame = _G.PlayerChoiceFrame
    if not frame then return false end
    local applied = self:ApplyPlayerChoiceWindow(frame)
    applied = self:ApplyPlayerChoiceOptions(frame) or applied
    applied = self:ApplyPlayerChoicePaging(frame) or applied
    applied = self:ApplyPlayerChoiceGridText(frame) or applied
    for _, pool in ipairs({ frame.optionFramePool, frame.optionPool,
        frame.OptionFramePool, frame.OptionsPool }) do
        HookPlayerChoicePool(pool)
    end
    HookPlayerChoicePoolCollection(frame.optionPools)
    for _, option in ipairs(GetPlayerChoiceOptions(frame, false)) do
        local optionButtons = option.OptionButtonsContainer
        for _, pool in ipairs({ option.buttonPool, option.ButtonPool,
            option.optionButtonPool, option.rewardPool, option.RewardPool,
            option.itemRewardPool, option.currencyRewardPool,
            option.reputationRewardPool,
            optionButtons and optionButtons.buttonFramePool }) do
            HookPlayerChoicePool(pool)
        end
    end
    return applied
end

function ExpansionFeaturesSkin:ApplyCovenantMission()
    local frame = _G.CovenantMissionFrame
    if not frame then return false end
    SuppressRegion(frame.Border)
    local title = frame.TitleText
        or frame.Header and (frame.Header.Title or frame.Header.Text)
        or frame.Title and frame.Title.GetFont and frame.Title
    local style = NSkin:GetAppearanceStyle("window",
        IDs.CovenantMission.Scope, IDs.CovenantMission.Window)
    local borderColor = NSkin:GetAppearanceBorderColor("window", style,
        IDs.CovenantMission.Scope, IDs.CovenantMission.Window)
    local mapTab = frame.MapTab
    local borderAnchor = mapTab and mapTab.ScrollContainer
    if borderAnchor then
        local oldBorder = NSkin:GetPixelBorder(frame, "NSkinWindowBorder")
        if oldBorder then NSkin:SetPixelBorderShown(oldBorder, false) end
        local oldMapBorder = NSkin:GetPixelBorder(
            frame, "NSkinCovenantMissionMapBorder")
        if oldMapBorder then
            NSkin:SetPixelBorderShown(oldMapBorder, false)
        end

        local chromeState = NSkin:GetSkinData(
            frame, "covenantMissionChrome")
        local chrome = chromeState.overlay
        if not chrome then
            chrome = CreateFrame("Frame", nil, frame)
            chrome:SetAllPoints(frame)
            chrome:EnableMouse(false)
            chromeState.overlay = chrome
        end
        local contentLevel = frame:GetFrameLevel()
        if mapTab and mapTab.GetFrameLevel then
            contentLevel = math.max(contentLevel, mapTab:GetFrameLevel())
        end
        if borderAnchor.GetFrameLevel then
            contentLevel = math.max(
                contentLevel, borderAnchor:GetFrameLevel())
        end
        chrome:SetFrameLevel(contentLevel + 10)
        chrome:Show()

        local border = NSkin:CreatePixelBorder(chrome,
            "NSkinCovenantMissionMapBorder", style.borderSize,
            borderColor, false, borderAnchor)
        NSkin:SetPixelBorderSize(border, style.borderSize)
        NSkin:SetPixelBorderPadding(border, style.borderPadding or 0)
        NSkin:SetPixelBorderColor(border, unpack(borderColor))
        NSkin:SetPixelBorderShown(border, true)
    end

    -- CovenantMissionFrame's MapTab is a full-window content canvas. Keep
    -- any previously-created shared window surfaces out of that canvas.
    local componentState = NSkin:GetSkinData(frame, "components", false)
    if componentState then
        if componentState.windowBackground then
            componentState.windowBackground:Hide()
        end
        if componentState.windowHeaderBackground then
            componentState.windowHeaderBackground:Hide()
        end
    end

    local closeButton = frame.CloseButton
    if closeButton then
        local closeStyle = NSkin:GetAppearanceStyle("windowHeaderButton",
            IDs.CovenantMission.Scope, IDs.CovenantMission.CloseButton)
        local closeBorder = NSkin:GetAppearanceBorderColor(
            "windowHeaderButton", closeStyle,
            IDs.CovenantMission.Scope, IDs.CovenantMission.CloseButton)
        NSkin:SkinWindowHeaderButton(closeButton, { glyph = "close" }, {
            style = closeStyle,
            border = closeBorder,
        })
        local closePixelBorder = NSkin:GetPixelBorder(
            closeButton, "NSkinFlatBackgroundBorder")
        NSkin:SetPixelBorderSize(closePixelBorder, style.borderSize)
        NSkin:SetPixelBorderPadding(closePixelBorder, 0)
        NSkin:RegisterWindowHeaderControls({
            id = IDs.CovenantMission.CloseButton,
            window = frame,
            closeButton = closeButton,
            borderSize = style.borderSize,
        })
        if not NSkin:GetSkinningElement(IDs.CovenantMission.CloseButton) then
            NSkin:RegisterSkinningElement(IDs.CovenantMission.CloseButton, {
                label = "Covenant mission close button",
                kind = "WINDOW_HEADER_CONTROLS",
                module = "ExpansionFeatures",
                appearanceWindowID = IDs.CovenantMission.Scope,
                window = frame,
                target = closeButton,
                priority = 95,
                draggable = false,
                highlightRegions = function()
                    return NSkin:GetWindowHeaderControlRegions(frame,
                        IDs.CovenantMission.CloseButton)
                end,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(closeButton)
                end,
                refreshAppearance = function()
                    return ExpansionFeaturesSkin:ApplyCovenantMission()
                end,
                refreshLayout = function()
                    return ExpansionFeaturesSkin:ApplyCovenantMission()
                end,
            })
        else
            NSkin:NotifySkinningElementBoundsChanged(
                IDs.CovenantMission.CloseButton)
        end
    end
    NSkin:RegisterSkinningElement(IDs.CovenantMission.Window, {
        label = "Covenant mission window",
        kind = "WINDOW",
        module = "ExpansionFeatures",
        appearanceWindowID = IDs.CovenantMission.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
        refreshAppearance = function()
            return ExpansionFeaturesSkin:ApplyCovenantMission()
        end,
        refreshLayout = function()
            return ExpansionFeaturesSkin:ApplyCovenantMission()
        end,
    })
    if title then
        RegisterPlayerChoiceText(frame, IDs.CovenantMission.Title,
            "Covenant mission title", title, 20,
            IDs.CovenantMission.Scope)
    end
    return true
end

local function GetAdventureMapQuestChoiceRewards(dialog, visibleOnly)
    local rewards = {}
    local pool = dialog and dialog.rewardPool
    if pool and type(pool.EnumerateActive) == "function" then
        for reward in pool:EnumerateActive() do
            if not visibleOnly or IsVisible(reward) then
                rewards[#rewards + 1] = reward
            end
        end
    end
    return rewards
end

local function RegisterAdventureMapQuestChoiceGroup(dialog, definition)
    local id = definition.id
    local function VisibleTargets()
        return GetVisibleTargets(definition.targets)
    end
    if not registeredAdventureMapQuestChoiceGroups[id] then
        registeredAdventureMapQuestChoiceGroups[id] =
            NSkin:RegisterSkinningElement(id, {
                label = definition.label,
                kind = definition.kind,
                module = "ExpansionFeatures",
                appearanceWindowID = IDs.AdventureMapQuestChoice.Scope,
                window = dialog,
                target = definition.owner or dialog,
                priority = definition.priority,
                draggable = false,
                appearanceStyles = definition.appearanceStyles,
                appearanceTypeIDs = definition.appearanceTypeIDs,
                highlightRegions = VisibleTargets,
                pixelBorderTargets = definition.pixelBorders
                    and VisibleTargets or nil,
                refreshAppearance = definition.refresh,
                refreshLayout = definition.refresh,
                isEditable = function()
                    return IsVisible(dialog) and #VisibleTargets() > 0
                end,
            }) == true
    end
    local applied = definition.refresh()
    if registeredAdventureMapQuestChoiceGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or registeredAdventureMapQuestChoiceGroups[id]
end

local function SkinAdventureMapTextFamily(id, provider)
    local style = NSkin:GetAppearanceStyle(
        "text", IDs.AdventureMapQuestChoice.Scope, id)
    local applied = false
    for _, target in ipairs(provider()) do
        applied = NSkin:SkinText(target, style) or applied
    end
    return applied
end

local function SuppressAdventureMapQuestChoiceArtwork(dialog)
    SuppressRegion(dialog.Background)
    SuppressRegion(dialog.Rewards)
    for _, reward in ipairs(GetAdventureMapQuestChoiceRewards(dialog, false)) do
        SuppressRegion(reward.ItemNameBG)
    end
end

function ExpansionFeaturesSkin:ApplyAdventureMapQuestChoiceWindow(dialog)
    SuppressAdventureMapQuestChoiceArtwork(dialog)
    NSkin:SkinStandardWindowChrome({
        frame = dialog,
        appearanceWindowID = IDs.AdventureMapQuestChoice.Scope,
        elementID = IDs.AdventureMapQuestChoice.Window,
        headerControlsID = IDs.AdventureMapQuestChoice.CloseButton,
        title = false,
        closeButton = dialog.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.AdventureMapQuestChoice.Window, {
        label = "Adventure Map quest choice window",
        kind = "WINDOW",
        module = "ExpansionFeatures",
        appearanceWindowID = IDs.AdventureMapQuestChoice.Scope,
        window = dialog,
        target = dialog,
        priority = 0,
        draggable = false,
    })
    return true
end

function ExpansionFeaturesSkin:ApplyAdventureMapQuestChoiceText(dialog)
    local details = dialog.Details
    local child = details and details.Child
    local definitions = {
        { IDs.AdventureMapQuestChoice.QuestTitle,
            "Adventure Map quest title", child and child.TitleHeader,
            "TEXT" },
        { IDs.AdventureMapQuestChoice.Description,
            "Adventure Map quest description", child and child.DescriptionText,
            "TEXT" },
        { IDs.AdventureMapQuestChoice.ObjectivesHeader,
            "Adventure Map quest objectives header",
            child and child.ObjectivesHeader, "SECTION_HEADER" },
        { IDs.AdventureMapQuestChoice.ObjectivesText,
            "Adventure Map quest objectives", child and child.ObjectivesText,
            "TEXT" },
        { IDs.AdventureMapQuestChoice.RewardsHeader,
            "Adventure Map quest rewards header", dialog.RewardsHeader,
            "SECTION_HEADER" },
    }
    local applied = false
    for index, definition in ipairs(definitions) do
        local id, label, target, kind = unpack(definition)
        if target then
            if kind == "TEXT" then
                applied = RegisterPlayerChoiceText(dialog, id, label,
                    target, 20 + index,
                    IDs.AdventureMapQuestChoice.Scope) or applied
            else
                local function Targets() return { target } end
                applied = RegisterAdventureMapQuestChoiceGroup(dialog, {
                    id = id,
                    label = label,
                    kind = kind,
                    priority = 20 + index,
                    targets = Targets,
                    appearanceStyles = { "text" },
                    appearanceTypeIDs = { "TEXT" },
                    refresh = function()
                        return SkinAdventureMapTextFamily(id, Targets)
                    end,
                }) or applied
            end
        end
    end
    return applied
end

function ExpansionFeaturesSkin:ApplyAdventureMapQuestChoiceRewards(dialog)
    local function RewardIcons()
        local targets = {}
        for _, reward in ipairs(
            GetAdventureMapQuestChoiceRewards(dialog, false))
        do
            if reward.Icon then targets[#targets + 1] = reward end
        end
        return targets
    end
    local function RefreshRewardIcons()
        local style = NSkin:GetAppearanceStyle("icon",
            IDs.AdventureMapQuestChoice.Scope,
            IDs.AdventureMapQuestChoice.RewardIcons)
        local border = NSkin:GetAppearanceBorderColor("icon", style,
            IDs.AdventureMapQuestChoice.Scope,
            IDs.AdventureMapQuestChoice.RewardIcons)
        local applied = false
        for _, reward in ipairs(
            GetAdventureMapQuestChoiceRewards(dialog, false))
        do
            if reward.Icon then
                NSkin:SkinIcon(reward, {
                    texture = reward.Icon,
                    style = style,
                    border = border,
                    borderOwner = reward,
                })
                SuppressRegion(reward.ItemNameBG)
                applied = true
            end
        end
        return applied
    end
    local function RewardNames()
        local targets = {}
        for _, reward in ipairs(
            GetAdventureMapQuestChoiceRewards(dialog, false))
        do
            if reward.Name then targets[#targets + 1] = reward.Name end
        end
        return targets
    end
    local function RewardCounts()
        local targets = {}
        for _, reward in ipairs(
            GetAdventureMapQuestChoiceRewards(dialog, false))
        do
            if reward.Count then targets[#targets + 1] = reward.Count end
        end
        return targets
    end
    local applied = RegisterAdventureMapQuestChoiceGroup(dialog, {
        id = IDs.AdventureMapQuestChoice.RewardIcons,
        label = "Adventure Map quest reward icons",
        kind = "ICON",
        priority = 40,
        targets = RewardIcons,
        pixelBorders = true,
        refresh = RefreshRewardIcons,
    })
    for _, definition in ipairs({
        { IDs.AdventureMapQuestChoice.RewardNames,
            "Adventure Map quest reward names", RewardNames, 41 },
        { IDs.AdventureMapQuestChoice.RewardCounts,
            "Adventure Map quest reward counts", RewardCounts, 42 },
    }) do
        local id, label, provider, priority = unpack(definition)
        applied = RegisterAdventureMapQuestChoiceGroup(dialog, {
            id = id,
            label = label,
            kind = "TEXT",
            priority = priority,
            targets = provider,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            refresh = function()
                return SkinAdventureMapTextFamily(id, provider)
            end,
        }) or applied
    end
    return applied
end

function ExpansionFeaturesSkin:ApplyAdventureMapQuestChoiceControls(dialog)
    local applied = false
    local scrollBar = dialog.Details and dialog.Details.ScrollBar
    if scrollBar then
        local element = NSkin:RegisterScrollBar({
            id = IDs.AdventureMapQuestChoice.ScrollBar,
            module = "ExpansionFeatures",
            appearanceWindowID = IDs.AdventureMapQuestChoice.Scope,
            label = "Adventure Map quest details scroll bar",
            window = dialog,
            target = scrollBar,
            priority = 50,
            highlightRegions = { scrollBar },
            isEditable = function()
                return IsVisible(dialog) and IsVisible(scrollBar)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end
    if dialog.AcceptButton then
        applied = NSkin:RegisterActionButton({
            id = IDs.AdventureMapQuestChoice.AcceptButton,
            module = "ExpansionFeatures",
            appearanceWindowID = IDs.AdventureMapQuestChoice.Scope,
            label = "Adventure Map accept quest button",
            window = dialog,
            target = dialog.AcceptButton,
            priority = 51,
            highlightRegions = { dialog.AcceptButton },
            isEditable = function()
                return IsVisible(dialog) and IsVisible(dialog.AcceptButton)
            end,
        }) ~= nil or applied
    end
    if dialog.DeclineButton then
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.AdventureMapQuestChoice.DeclineButton,
            module = "ExpansionFeatures",
            appearanceWindowID = IDs.AdventureMapQuestChoice.Scope,
            label = "Adventure Map decline quest button",
            window = dialog,
            target = dialog.DeclineButton,
            priority = 52,
            highlightRegions = { dialog.DeclineButton },
            isEditable = function()
                return IsVisible(dialog) and IsVisible(dialog.DeclineButton)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end
    return applied
end

function ExpansionFeaturesSkin:ApplyAdventureMapQuestChoice()
    local dialog = _G.AdventureMapQuestChoiceDialog
    if not dialog then return false end
    local applied = self:ApplyAdventureMapQuestChoiceWindow(dialog)
    applied = self:ApplyAdventureMapQuestChoiceText(dialog) or applied
    applied = self:ApplyAdventureMapQuestChoiceRewards(dialog) or applied
    applied = self:ApplyAdventureMapQuestChoiceControls(dialog) or applied
    return applied
end

local function HookAdventureMapRewardPool(pool)
    if not pool or hookedAdventureMapRewardPools[pool]
        or not _G.hooksecurefunc
    then
        return
    end
    for _, method in ipairs({ "Acquire", "Release", "ReleaseAll" }) do
        if type(pool[method]) == "function" then
            _G.hooksecurefunc(pool, method,
                QueueAdventureMapQuestChoiceApply)
        end
    end
    hookedAdventureMapRewardPools[pool] = true
end

function ExpansionFeaturesSkin:Apply()
    local applied = self:ApplyOmniumFolioChrome()
    applied = self:ApplyGenericTrait() or applied
    applied = self:ApplyPlayerChoice() or applied
    applied = self:ApplyCovenantMission() or applied
    applied = self:ApplyAdventureMapQuestChoice() or applied
    return applied
end

local function RegisterOverlayCallback()
    if registryCallbackRegistered or not _G.EventRegistry then return end
    _G.EventRegistry:RegisterCallback(
        "ExpansionLandingPage.OverlayChanged",
        QueueApply,
        ExpansionFeaturesSkin)
    registryCallbackRegistered = true
end

function ExpansionFeaturesSkin:Initialize()
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

function ExpansionFeaturesSkin:InitializeGenericTrait()
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

function ExpansionFeaturesSkin:InitializePlayerChoice()
    local frame = _G.PlayerChoiceFrame
    if not frame then return false end

    if not playerChoiceLifecycleHooked then
        if frame.HookScript then frame:HookScript("OnShow", QueuePlayerChoiceApply) end
        if _G.hooksecurefunc then
            for _, method in ipairs({
                "Setup",
                "SetupOptions",
                "SetUpOptions",
                "UpdateOptions",
                "Refresh",
                "Update",
                "SetupPlayerChoice",
            }) do
                if type(frame[method]) == "function" then
                    _G.hooksecurefunc(frame, method, QueuePlayerChoiceApply)
                end
            end
            local frameMixin = _G.PlayerChoiceFrameMixin
            if frameMixin and type(frameMixin.SetupFrame) == "function" then
                _G.hooksecurefunc(frameMixin, "SetupFrame", function(owner)
                    SuppressPlayerChoiceFrameArtwork(owner)
                end)
            end
            local optionMixin = _G.PlayerChoiceNormalOptionTemplateMixin
            if optionMixin then
                if type(optionMixin.SetupHeader) == "function" then
                    _G.hooksecurefunc(optionMixin, "SetupHeader",
                        function(option)
                            SuppressRegion(option.Header
                                and option.Header.Ribbon)
                            QueuePlayerChoiceApply()
                        end)
                end
                if type(optionMixin.SetupFrame) == "function" then
                    _G.hooksecurefunc(optionMixin, "SetupFrame",
                        function(option)
                            SuppressPlayerChoiceOptionArtwork(option)
                        end)
                end
            end
        end
        playerChoiceLifecycleHooked = true
    end
    playerChoiceInitialized = true
    local applied = self:ApplyPlayerChoice()
    if frame:IsShown() then QueuePlayerChoiceApply() end
    return applied
end

function ExpansionFeaturesSkin:InitializeCovenantMission()
    if not covenantMissionLifecycleHooked and _G.hooksecurefunc then
        for _, mixin in ipairs({
            _G.CovenantMissionFrameMixin,
            _G.CovenantMissionFrameMapTabMixin,
            _G.CovenantMissionMapTabMixin,
        }) do
            if mixin then
                for _, method in ipairs({
                    "OnShow", "Refresh", "Update", "UpdateMap",
                    "OnMapChanged",
                }) do
                    if type(mixin[method]) == "function" then
                        _G.hooksecurefunc(mixin, method,
                            QueueCovenantMissionApply)
                    end
                end
            end
        end
        covenantMissionLifecycleHooked = true
    end

    local frame = _G.CovenantMissionFrame
    if not frame then return false end

    local function HookLifecycleTarget(target)
        if not target or hookedCovenantMissionLifecycleTargets[target] then
            return
        end
        if target.HookScript then
            target:HookScript("OnShow", QueueCovenantMissionApply)
        end
        if _G.hooksecurefunc then
            for _, method in ipairs({
                "Refresh", "Update", "OnShow", "UpdateMap", "OnMapChanged",
            }) do
                if type(target[method]) == "function" then
                    _G.hooksecurefunc(target, method,
                        QueueCovenantMissionApply)
                end
            end
        end
        hookedCovenantMissionLifecycleTargets[target] = true
    end

    HookLifecycleTarget(frame)
    local mapTab = frame.MapTab
    HookLifecycleTarget(mapTab)
    HookLifecycleTarget(mapTab and mapTab.ScrollContainer)
    covenantMissionInitialized = true
    local applied = self:ApplyCovenantMission()
    if frame:IsShown() or IsVisible(mapTab) then
        QueueCovenantMissionApply()
    end
    return applied
end

function ExpansionFeaturesSkin:InitializeAdventureMapQuestChoice()
    local dialog = _G.AdventureMapQuestChoiceDialog
    if not dialog then return false end
    if not adventureMapQuestChoiceLifecycleHooked then
        if dialog.HookScript then
            dialog:HookScript("OnShow", QueueAdventureMapQuestChoiceApply)
        end
        if _G.hooksecurefunc then
            for _, method in ipairs({
                "ShowWithQuest", "Refresh", "RefreshRewards",
                "RefreshDetails",
            }) do
                if type(dialog[method]) == "function" then
                    _G.hooksecurefunc(dialog, method,
                        QueueAdventureMapQuestChoiceApply)
                end
            end
        end
        adventureMapQuestChoiceLifecycleHooked = true
    end
    HookAdventureMapRewardPool(dialog.rewardPool)
    adventureMapQuestChoiceInitialized = true
    local applied = self:ApplyAdventureMapQuestChoice()
    if dialog:IsShown() then QueueAdventureMapQuestChoiceApply() end
    return applied
end

function ExpansionFeaturesSkin:RefreshAppearance()
    if initialized then self:ApplyOmniumFolioChrome() end
    if genericTraitInitialized then self:ApplyGenericTrait() end
    if playerChoiceInitialized then self:ApplyPlayerChoice() end
    if covenantMissionInitialized then self:ApplyCovenantMission() end
    if adventureMapQuestChoiceInitialized then
        self:ApplyAdventureMapQuestChoice()
    end
end

NSkin:RegisterWindowSkin({
    module = "ExpansionFeatures",
    addon = "Blizzard_ExpansionLandingPage",
    apply = function() return ExpansionFeaturesSkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "MidnightFeatures.GenericTrait",
    module = "ExpansionFeatures",
    addon = "Blizzard_GenericTraitUI",
    apply = function()
        return ExpansionFeaturesSkin:InitializeGenericTrait()
    end,
})

NSkin:RegisterWindowSkin({
    key = "MidnightFeatures.CovenantMission",
    module = "ExpansionFeatures",
    addon = "Blizzard_GarrisonUI",
    apply = function()
        return ExpansionFeaturesSkin:InitializeCovenantMission()
    end,
})

NSkin:RegisterWindowSkin({
    key = "MidnightFeatures.AdventureMapQuestChoice",
    module = "ExpansionFeatures",
    addon = "Blizzard_AdventureMap",
    apply = function()
        return ExpansionFeaturesSkin:InitializeAdventureMapQuestChoice()
    end,
})

NSkin:RegisterWindowSkin({
    key = "MidnightFeatures.PlayerChoice",
    module = "ExpansionFeatures",
    addon = "Blizzard_PlayerChoice",
    apply = function()
        return ExpansionFeaturesSkin:InitializePlayerChoice()
    end,
})
