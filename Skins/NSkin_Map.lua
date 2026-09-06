local _, NSkin = ...

local MapSkin = NSkin:NewModule("Map")

local IDs = {
    Scope = "Map",
    Window = "Map.Window",
    HeaderControls = "Map.HeaderControls",
    Fullscreen = "Map.FullscreenButton",
    NavigationBar = "Map.NavigationBar",
    QuestLogSearchBox = "Map.QuestLog.SearchBox",
    QuestLogScrollBar = "Map.QuestLog.ScrollBar",
    QuestLogSectionCards = "Map.QuestLog.SectionCards",
    QuestLogCheckboxes = "Map.QuestLog.Checkboxes",
    CampaignOverviewCard = "Map.QuestLog.CampaignOverviewCard",
    EventSectionCards = "Map.Events.SectionCards",
    EventsScrollBar = "Map.Events.ScrollBar",
    MapLegendScrollBar = "Map.Legend.ScrollBar",
    SideTabs = "Map.SideTabs",
}

local initialized = false
local showHooked = false
local applyPending = false
local questLogSectionCardsHooked = false
local questLogSectionCardsRegistered = false
local questLogCheckboxesRegistered = false
local campaignOverviewCardHooked = false
local campaignOverviewCardRegistered = false
local eventSectionCardsHooked = false
local eventSectionCardsRegistered = false
local hookedScrollBars = setmetatable({}, { __mode = "k" })
local hookedQuestLogHeaders = setmetatable({}, { __mode = "k" })
local hookedQuestLogCollapseButtons = setmetatable({}, { __mode = "k" })
local hookedCampaignOverviewCards = setmetatable({}, { __mode = "k" })
local hookedEventSectionCards = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Map & Quest Log",
})

local function GetMapScrollBar()
    local questScrollFrame = _G.QuestScrollFrame
    return questScrollFrame and questScrollFrame.ScrollBar
end

local function GetMapSearchBox()
    local questScrollFrame = _G.QuestScrollFrame
    return questScrollFrame and questScrollFrame.SearchBox
end

local function ForEachActiveQuestLogCheckbox(callback)
    local scrollFrame = _G.QuestScrollFrame
    local pool = scrollFrame and scrollFrame.titleFramePool
    if not pool or type(pool.EnumerateActive) ~= "function" then return end
    for questButton in pool:EnumerateActive() do
        local checkBox = questButton and questButton.Checkbox
        if checkBox then callback(checkBox, questButton) end
    end
end

local function GetVisibleQuestLogCheckboxes()
    local checkBoxes = {}
    ForEachActiveQuestLogCheckbox(function(checkBox)
        if checkBox.IsShown and checkBox:IsShown() then
            checkBoxes[#checkBoxes + 1] = checkBox
        end
    end)
    return checkBoxes
end

local function IsQuestLogCheckboxChecked(checkBox)
    local questButton = checkBox and checkBox.GetParent
        and checkBox:GetParent()
    local questID = questButton and questButton.questID
    if questID and _G.C_QuestLog and _G.C_QuestLog.GetQuestWatchType then
        return _G.C_QuestLog.GetQuestWatchType(questID) ~= nil
    end
    local checkMark = checkBox and checkBox.CheckMark
    return checkMark and checkMark.IsShown and checkMark:IsShown() or false
end

local function GetQuestLogHeaderPools()
    local questScrollFrame = _G.QuestScrollFrame
    if not questScrollFrame then return nil end
    local pools = {}
    for _, definition in ipairs({
        { key = "headerFramePool" },
        { key = "campaignHeaderFramePool", preserveHeight = true },
        { key = "campaignHeaderMinimalFramePool", preserveHeight = true },
        { key = "covenantCallingsHeaderFramePool" },
    }) do
        local pool = questScrollFrame[definition.key]
        if pool then
            pools[#pools + 1] = {
                pool = pool,
                preserveHeight = definition.preserveHeight,
            }
        end
    end
    return pools
end

local function ForEachActiveQuestLogHeader(callback)
    local pools = GetQuestLogHeaderPools()
    if not pools then return end
    for i = 1, #pools do
        local definition = pools[i]
        local pool = definition.pool
        if pool and type(pool.EnumerateActive) == "function" then
            for header in pool:EnumerateActive() do
                callback(header, definition.preserveHeight)
            end
        end
    end
end

local function GetVisibleQuestLogSectionCards()
    local cards = {}
    ForEachActiveQuestLogHeader(function(header)
        if header and header.IsShown and header:IsShown() then
            cards[#cards + 1] = header
        end
    end)
    return cards
end

local function GetQuestLogHeaderCollapseButton(header)
    if header and type(header.GetCollapseButton) == "function" then
        local ok, button = pcall(header.GetCollapseButton, header)
        if ok and button then return button end
    end
    return header and header.CollapseButton
end

local function GetQuestLogHeaderArtwork(header)
    local artwork = {}
    local function Add(region)
        if region then artwork[#artwork + 1] = region end
    end
    Add(header.Background)
    Add(header.Highlight)
    Add(header.HighlightTexture)
    Add(header.SelectedHighlight)
    Add(header.SelectedTexture)
    Add(header.Divider)
    for _, method in ipairs({
        "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture",
        "GetDisabledTexture",
    }) do
        if type(header[method]) == "function" then
            local ok, texture = pcall(header[method], header)
            if ok then Add(texture) end
        end
    end
    local collapseButton = GetQuestLogHeaderCollapseButton(header)
    if collapseButton then
        Add(collapseButton.Icon)
        for _, method in ipairs({
            "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture",
            "GetDisabledTexture",
        }) do
            if type(collapseButton[method]) == "function" then
                local ok, texture = pcall(collapseButton[method], collapseButton)
                if ok then Add(texture) end
            end
        end
    end
    return artwork
end

local function GetQuestLogHeaderText(header)
    if header and type(header.GetTitleRegion) == "function" then
        local ok, title = pcall(header.GetTitleRegion, header)
        if ok and title then return title end
    end
    return header and (header.ButtonText or header.Text or header.Title)
end

local function IsQuestLogHeaderExpanded(header)
    local collapseButton = GetQuestLogHeaderCollapseButton(header)
    if collapseButton and type(collapseButton.collapsed) == "boolean" then
        return not collapseButton.collapsed
    end
    local questLogIndex = header and header.questLogIndex
    if questLogIndex and _G.C_QuestLog and _G.C_QuestLog.GetInfo then
        local info = _G.C_QuestLog.GetInfo(questLogIndex)
        if info and type(info.isCollapsed) == "boolean" then
            return not info.isCollapsed
        end
    end
    return nil
end

local function GetEventsScrollBar()
    local questMapFrame = _G.QuestMapFrame
    local eventsFrame = questMapFrame and questMapFrame.EventsFrame
    return eventsFrame and eventsFrame.ScrollBar, eventsFrame
end

local HideDecorativeTexture

local function GetEventsFrame()
    local questMapFrame = _G.QuestMapFrame
    return questMapFrame and questMapFrame.EventsFrame
end

local function GetCampaignOverview()
    local questMapFrame = _G.QuestMapFrame
    local questsFrame = questMapFrame and questMapFrame.QuestsFrame
    return questsFrame and questsFrame.CampaignOverview
end

local function IsEventSectionCard(frame)
    if not frame or not frame.Background then return false end

    -- Event entries expose Name.  The two category headers expose Label and
    -- are taller than the date-divider template, which also has Label and
    -- Background but should keep its timeline presentation.
    if frame.Name then return true end
    if not frame.Label or not frame.GetHeight then return false end
    return frame:GetHeight() > 23
end

local function ForEachEventSectionCard(callback)
    local eventsFrame = GetEventsFrame()
    local scrollBox = eventsFrame and eventsFrame.ScrollBox
    if not scrollBox or type(scrollBox.ForEachFrame) ~= "function" then return end
    scrollBox:ForEachFrame(function(frame)
        if IsEventSectionCard(frame) then callback(frame) end
    end)
end

local function GetVisibleEventSectionCards()
    local cards = {}
    ForEachEventSectionCard(function(card)
        if card.IsShown and card:IsShown() then
            cards[#cards + 1] = card
        end
    end)
    return cards
end

local function GetEventSectionCardArtwork(card)
    local artwork = {}
    local function Add(region)
        if region then artwork[#artwork + 1] = region end
    end
    Add(card.Background)
    Add(card.Background2)
    Add(card.Highlight)
    return artwork
end

local function SuppressEventSectionCardArtwork(card)
    for _, region in ipairs(GetEventSectionCardArtwork(card)) do
        HideDecorativeTexture(region)
    end
end

local function HookEventSectionCardArtwork(card)
    if not card or hookedEventSectionCards[card] then return end
    if card.HookScript then
        for _, script in ipairs({ "OnShow", "OnEnter", "OnLeave" }) do
            card:HookScript(script, SuppressEventSectionCardArtwork)
        end
    end
    hookedEventSectionCards[card] = true
    SuppressEventSectionCardArtwork(card)
end

local function GetCampaignOverviewCardArtwork(header)
    local artwork = {}
    local function Add(region)
        if region then artwork[#artwork + 1] = region end
    end
    Add(header.Background)
    Add(header.HighlightTexture)
    Add(header.TopFiligree)
    return artwork
end

local function SuppressCampaignOverviewCardArtwork(header)
    for _, region in ipairs(GetCampaignOverviewCardArtwork(header)) do
        HideDecorativeTexture(region)
    end
end

local function HookCampaignOverviewCardArtwork(header)
    if not header or hookedCampaignOverviewCards[header] then return end
    if header.HookScript then
        for _, script in ipairs({ "OnShow", "OnEnter", "OnLeave" }) do
            header:HookScript(script, SuppressCampaignOverviewCardArtwork)
        end
    end
    hookedCampaignOverviewCards[header] = true
    SuppressCampaignOverviewCardArtwork(header)
end

local function GetMapLegendScrollBar()
    local legend = _G.MapLegendScrollFrame
    return legend and legend.ScrollBar, legend
end

HideDecorativeTexture = function(texture)
    if not texture then return end
    if texture.SetAlpha then texture:SetAlpha(0) end
    if texture.Hide then texture:Hide() end
end

local function SuppressQuestLogHeaderArtwork(header)
    for _, texture in ipairs(GetQuestLogHeaderArtwork(header)) do
        HideDecorativeTexture(texture)
    end
end

local function HookQuestLogHeaderArtwork(header)
    if not header then return end
    if not hookedQuestLogHeaders[header] and header.HookScript then
        for _, script in ipairs({ "OnShow", "OnEnter", "OnLeave" }) do
            header:HookScript(script, SuppressQuestLogHeaderArtwork)
        end
        if _G.hooksecurefunc
            and type(header.UpdateCollapsedState) == "function"
        then
            pcall(_G.hooksecurefunc, header, "UpdateCollapsedState",
                SuppressQuestLogHeaderArtwork)
        end
        hookedQuestLogHeaders[header] = true
    end

    local collapseButton = GetQuestLogHeaderCollapseButton(header)
    if collapseButton and not hookedQuestLogCollapseButtons[collapseButton]
        and _G.hooksecurefunc
    then
        for _, method in ipairs({
            "UpdateCollapsedState", "SetHighlightAtlas", "SetNormalAtlas",
            "SetPushedAtlas", "SetDisabledAtlas",
        }) do
            if type(collapseButton[method]) == "function" then
                pcall(_G.hooksecurefunc, collapseButton, method, function()
                    SuppressQuestLogHeaderArtwork(header)
                end)
            end
        end
        hookedQuestLogCollapseButtons[collapseButton] = true
    end
    SuppressQuestLogHeaderArtwork(header)
end

local function GetMapNavigationBar(map)
    local borderFrame = map and map.BorderFrame
    return map and (map.NavBar or map.navBar or map.NavigationBar)
        or (borderFrame and (borderFrame.NavBar
            or borderFrame.navBar or borderFrame.NavigationBar))
end

local function GetMapSideTabs()
    local questMapFrame = _G.QuestMapFrame
    if not questMapFrame then return nil end
    return {
        questMapFrame.QuestsTab,
        questMapFrame.EventsTab,
        questMapFrame.MapLegendTab,
    }
end

local function GetMapChromeParts(map)
    local borderFrame = map and map.BorderFrame
    local title = borderFrame and (borderFrame.TitleText
        or (borderFrame.TitleContainer and borderFrame.TitleContainer.TitleText))
        or (map and map.TitleContainer and map.TitleContainer.TitleText)
    local closeButton = borderFrame and borderFrame.CloseButton
        or (map and map.CloseButton)
    return borderFrame, title, closeButton
end

local function ResolveMapResizeButtons(map, borderFrame)
    local resizeFrame = borderFrame and (
        borderFrame.MaximizeMinimizeButton
        or borderFrame.MaximizeMinimizeFrame
        or borderFrame.MaximizeMinimizeButtonFrame)
        or (map and (map.MaximizeMinimizeButton
            or map.MaximizeMinimizeFrame
            or map.MaximizeMinimizeButtonFrame))
    local maximizeButton = resizeFrame and (
        resizeFrame.MaximizeButton or resizeFrame.maximizeButton)
        or (borderFrame and borderFrame.MaximizeButton)
    local minimizeButton = resizeFrame and (
        resizeFrame.MinimizeButton or resizeFrame.minimizeButton)
        or (borderFrame and borderFrame.MinimizeButton)
    local singleButton
    if not maximizeButton and not minimizeButton and resizeFrame
        and resizeFrame.IsObjectType
        and resizeFrame:IsObjectType("Button")
    then
        singleButton = resizeFrame
    end
    return maximizeButton, minimizeButton, singleButton
end

local function GetMapHeaderControlTargets(map, borderFrame)
    local maximizeButton, minimizeButton, singleButton =
        ResolveMapResizeButtons(map, borderFrame)
    local targets = {}
    if maximizeButton then
        targets[#targets + 1] = {
            target = maximizeButton,
            glyph = "maximize",
        }
    end
    if minimizeButton then
        targets[#targets + 1] = {
            target = minimizeButton,
            glyph = "minimize",
        }
    end
    if singleButton then
        targets[#targets + 1] = {
            target = singleButton,
            glyph = "fullscreen",
        }
    end
    return targets
end

function MapSkin:ApplyWindowChrome()
    local map = _G.WorldMapFrame
    if not map then return false end

    local borderFrame, title, closeButton = GetMapChromeParts(map)
    local resizeTargets = GetMapHeaderControlTargets(map, borderFrame)
    NSkin:SkinStandardWindowChrome({
        frame = map,
        artworkFrame = borderFrame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        title = title,
        closeButton = closeButton,
        headerControlsID = IDs.HeaderControls,
        headerControls = {
            {
                id = IDs.Fullscreen,
                targets = resizeTargets,
            },
        },
    })
    return true
end

local function RegisterMapScrollBar(id, label, scrollBar, owner, priority)
    local map = _G.WorldMapFrame
    if not map or not owner or not scrollBar then return false end

    NSkin:RegisterScrollBar({
        id = id,
        module = "Map",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = map,
        target = scrollBar,
        priority = priority,
        highlightRegions = { scrollBar },
        isEditable = function()
            return map:IsVisible() and owner:IsVisible()
                and scrollBar:IsVisible()
        end,
    })
    if not hookedScrollBars[scrollBar] and scrollBar.HookScript then
        scrollBar:HookScript("OnShow", function()
            MapSkin:QueueScrollBarApply()
        end)
        hookedScrollBars[scrollBar] = true
    end
    return true
end

function MapSkin:ApplyScrollBar()
    local scrollBar = GetMapScrollBar()
    return RegisterMapScrollBar(IDs.QuestLogScrollBar,
        "Map quest log scroll bar", scrollBar, _G.QuestScrollFrame, 80)
end

function MapSkin:ApplyPanelScrollBars()
    local eventsScrollBar, eventsFrame = GetEventsScrollBar()
    local legendScrollBar, legendFrame = GetMapLegendScrollBar()
    local applied = RegisterMapScrollBar(IDs.EventsScrollBar,
        "Map events scroll bar", eventsScrollBar, eventsFrame, 81)
    return RegisterMapScrollBar(IDs.MapLegendScrollBar,
        "Map legend scroll bar", legendScrollBar, legendFrame, 82) or applied
end

function MapSkin:ApplySearchBox()
    local map = _G.WorldMapFrame
    local searchBox = GetMapSearchBox()
    if not map or not searchBox then return false end

    NSkin:RegisterSearchBox({
        id = IDs.QuestLogSearchBox,
        module = "Map",
        appearanceWindowID = IDs.Scope,
        label = "Map quest log search bar",
        window = map,
        target = searchBox,
        priority = 70,
        highlightRegions = { searchBox },
        isEditable = function()
            return map:IsVisible() and searchBox:IsVisible()
        end,
    })
    return true
end

function MapSkin:ApplyQuestListSurface()
    local scrollFrame = _G.QuestScrollFrame
    if not scrollFrame then return false end

    -- Keep the quest rows and scrolling controls intact; only suppress the
    -- Blizzard artwork that forms the ornamental panel behind them.
    HideDecorativeTexture(scrollFrame.Background)
    HideDecorativeTexture(scrollFrame.Edge)

    local borderFrame = scrollFrame.BorderFrame
    if borderFrame and borderFrame.GetRegions then
        local regions = { borderFrame:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region.IsObjectType and region:IsObjectType("Texture") then
                HideDecorativeTexture(region)
            end
        end
    end

    local contents = scrollFrame.Contents
    local separator = contents and contents.Separator
    HideDecorativeTexture(separator and separator.Divider)
    return true
end

function MapSkin:ApplyQuestLogSectionCards()
    local map = _G.WorldMapFrame
    local scrollFrame = _G.QuestScrollFrame
    local pools = GetQuestLogHeaderPools()
    if not map or not scrollFrame or not pools then return false end

    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, IDs.QuestLogSectionCards)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, IDs.QuestLogSectionCards)
    local applied = false
    ForEachActiveQuestLogHeader(function(header, preserveHeight)
        NSkin:SkinSectionCard(header, {
            style = style,
            border = border,
            collapsible = true,
            height = preserveHeight and 0 or nil,
            visualRegion = preserveHeight and header.Background or nil,
            preserveTextLayout = preserveHeight == true,
            getExpanded = IsQuestLogHeaderExpanded,
            textRegion = GetQuestLogHeaderText(header),
            artworkRegions = GetQuestLogHeaderArtwork(header),
        })
        HookQuestLogHeaderArtwork(header)
        applied = true
    end)

    if not questLogSectionCardsRegistered then
        questLogSectionCardsRegistered = NSkin:RegisterSkinningElement(
            IDs.QuestLogSectionCards, {
                module = "Map",
                appearanceWindowID = IDs.Scope,
                label = "Quest log section cards",
                kind = "SECTION_CARD",
                window = map,
                target = scrollFrame.Contents,
                priority = 79,
                draggable = false,
                highlightRegions = GetVisibleQuestLogSectionCards,
                editorOptions = {
                    { id = "shared.sectionCardAppearance",
                        label = "Section cards", category = "CUSTOMIZE" },
                },
                isEditable = function()
                    return map:IsVisible() and scrollFrame:IsVisible()
                        and #GetVisibleQuestLogSectionCards() > 0
                end,
            }) == true
    end
    if questLogSectionCardsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.QuestLogSectionCards)
    end
    return applied or questLogSectionCardsRegistered
end

function MapSkin:ApplyCampaignOverviewCard()
    local map = _G.WorldMapFrame
    local overview = GetCampaignOverview()
    local header = overview and overview.Header
    local background = header and header.Background
    if not map or not overview or not header or not background then return false end

    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, IDs.CampaignOverviewCard)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, IDs.CampaignOverviewCard)
    NSkin:SkinSectionCard(header, {
        style = style,
        border = border,
        collapsible = false,
        height = 0,
        visualRegion = background,
        preserveTextLayout = true,
        textRegion = header.Text,
        artworkRegions = GetCampaignOverviewCardArtwork(header),
    })
    HookCampaignOverviewCardArtwork(header)

    if not campaignOverviewCardRegistered then
        campaignOverviewCardRegistered = NSkin:RegisterSkinningElement(
            IDs.CampaignOverviewCard, {
                module = "Map",
                appearanceWindowID = IDs.Scope,
                label = "Campaign overview card",
                kind = "SECTION_CARD",
                window = map,
                target = header,
                priority = 76,
                draggable = false,
                highlightRegions = { header },
                editorOptions = {
                    { id = "shared.sectionCardAppearance",
                        label = "Section cards", category = "CUSTOMIZE" },
                },
                isEditable = function()
                    return map:IsVisible() and overview:IsVisible()
                        and header:IsVisible()
                end,
            }) == true
    end
    if campaignOverviewCardRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.CampaignOverviewCard)
    end
    return true
end

function MapSkin:ApplyEventSectionCards()
    local map = _G.WorldMapFrame
    local eventsFrame = GetEventsFrame()
    local scrollBox = eventsFrame and eventsFrame.ScrollBox
    if not map or not eventsFrame or not scrollBox then return false end

    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, IDs.EventSectionCards)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, IDs.EventSectionCards)
    local applied = false
    ForEachEventSectionCard(function(card)
        NSkin:SkinSectionCard(card, {
            style = style,
            border = border,
            collapsible = false,
            height = 0,
            preserveTextLayout = true,
            textRegion = card.Name or card.Label,
            icon = card.Icon,
            artworkRegions = GetEventSectionCardArtwork(card),
        })
        HookEventSectionCardArtwork(card)
        applied = true
    end)

    if not eventSectionCardsRegistered then
        eventSectionCardsRegistered = NSkin:RegisterSkinningElement(
            IDs.EventSectionCards, {
                module = "Map",
                appearanceWindowID = IDs.Scope,
                label = "Event section cards",
                kind = "SECTION_CARD",
                window = map,
                target = scrollBox,
                priority = 77,
                draggable = false,
                highlightRegions = GetVisibleEventSectionCards,
                editorOptions = {
                    { id = "shared.sectionCardAppearance",
                        label = "Section cards", category = "CUSTOMIZE" },
                },
                isEditable = function()
                    return map:IsVisible() and eventsFrame:IsVisible()
                        and #GetVisibleEventSectionCards() > 0
                end,
            }) == true
    end
    if eventSectionCardsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.EventSectionCards)
    end
    return applied or eventSectionCardsRegistered
end

function MapSkin:ApplyQuestLogCheckboxes()
    local map = _G.WorldMapFrame
    local scrollFrame = _G.QuestScrollFrame
    local pool = scrollFrame and scrollFrame.titleFramePool
    if not map or not scrollFrame or not pool then return false end

    local style = NSkin:GetAppearanceStyle(
        "button", IDs.Scope, IDs.QuestLogCheckboxes)
    local applied = false
    ForEachActiveQuestLogCheckbox(function(checkBox)
        NSkin:SkinCheckButton(checkBox, {
            style = style,
            getChecked = IsQuestLogCheckboxChecked,
        })
        applied = true
    end)

    if not questLogCheckboxesRegistered then
        questLogCheckboxesRegistered = NSkin:RegisterSkinningElement(
            IDs.QuestLogCheckboxes, {
                module = "Map",
                appearanceWindowID = IDs.Scope,
                label = "Quest log tracking checkboxes",
                kind = "CHECKBOX",
                window = map,
                target = scrollFrame.Contents,
                priority = 78,
                draggable = false,
                editorOptions = {},
                highlightRegions = GetVisibleQuestLogCheckboxes,
                isEditable = function()
                    return map:IsVisible() and scrollFrame:IsVisible()
                        and #GetVisibleQuestLogCheckboxes() > 0
                end,
            }) == true
    end
    if questLogCheckboxesRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.QuestLogCheckboxes)
    end
    return applied or questLogCheckboxesRegistered
end

function MapSkin:ApplySideTabs()
    local map = _G.WorldMapFrame
    local tabs = GetMapSideTabs()
    if not map or not tabs then return false end

    for i = 1, #tabs do
        if not tabs[i] then return false end
    end
    return NSkin:RegisterSideTabGroup(IDs.SideTabs, {
        module = "Map",
        appearanceWindowID = IDs.Scope,
        label = "Map side tabs",
        window = map,
        targets = tabs,
        priority = 60,
        isEditable = function()
            if not map:IsVisible() then return false end
            for i = 1, #tabs do
                if tabs[i]:IsVisible() then return true end
            end
            return false
        end,
    }) ~= nil
end

function MapSkin:ApplyNavigationBar()
    local map = _G.WorldMapFrame
    local navigationBar = GetMapNavigationBar(map)
    if not map or not navigationBar then return false end

    NSkin:RegisterNavigationBar(IDs.NavigationBar, {
        module = "Map",
        appearanceWindowID = IDs.Scope,
        label = "Map navigation bar",
        window = map,
        target = navigationBar,
        priority = 40,
        highlightRegions = { navigationBar },
        isEditable = function()
            return map:IsVisible() and navigationBar:IsVisible()
        end,
    })
    return true
end

function MapSkin:QueueScrollBarApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        MapSkin:ApplyWindowChrome()
        MapSkin:ApplyNavigationBar()
        MapSkin:ApplySideTabs()
        MapSkin:ApplySearchBox()
        MapSkin:ApplyQuestListSurface()
        MapSkin:ApplyQuestLogSectionCards()
        MapSkin:ApplyQuestLogCheckboxes()
        MapSkin:ApplyCampaignOverviewCard()
        MapSkin:ApplyEventSectionCards()
        MapSkin:ApplyScrollBar()
        MapSkin:ApplyPanelScrollBars()
    end)
end

function MapSkin:Initialize()
    if initialized then return true end
    local map = _G.WorldMapFrame
    if not map then return false end
    if not showHooked and map and map.HookScript then
        map:HookScript("OnShow", function()
            MapSkin:QueueScrollBarApply()
        end)
        showHooked = true
    end

    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Map & Quest Log window",
        kind = "WINDOW",
        module = "Map",
        appearanceWindowID = IDs.Scope,
        window = map,
        target = map,
        priority = 0,
        draggable = false,
    })

    initialized = true
    if not questLogSectionCardsHooked and _G.hooksecurefunc
        and type(_G.QuestLogQuests_Update) == "function"
    then
        _G.hooksecurefunc("QuestLogQuests_Update", function()
            MapSkin:ApplyQuestLogSectionCards()
            MapSkin:ApplyQuestLogCheckboxes()
        end)
        questLogSectionCardsHooked = true
    end
    local campaignOverview = GetCampaignOverview()
    if not campaignOverviewCardHooked and campaignOverview then
        if campaignOverview.HookScript then
            campaignOverview:HookScript("OnShow", function()
                MapSkin:ApplyCampaignOverviewCard()
            end)
        end
        if _G.hooksecurefunc
            and type(campaignOverview.SetCampaign) == "function"
        then
            _G.hooksecurefunc(campaignOverview, "SetCampaign", function()
                MapSkin:ApplyCampaignOverviewCard()
            end)
        end
        campaignOverviewCardHooked = true
    end
    local eventsFrame = GetEventsFrame()
    if not eventSectionCardsHooked and eventsFrame and _G.hooksecurefunc
        and type(eventsFrame.Refresh) == "function"
    then
        _G.hooksecurefunc(eventsFrame, "Refresh", function()
            MapSkin:ApplyEventSectionCards()
        end)
        eventSectionCardsHooked = true
    end
    self:ApplyWindowChrome()
    self:ApplyNavigationBar()
    self:ApplySideTabs()
    self:ApplySearchBox()
    self:ApplyQuestListSurface()
    self:ApplyQuestLogSectionCards()
    self:ApplyQuestLogCheckboxes()
    self:ApplyCampaignOverviewCard()
    self:ApplyEventSectionCards()
    self:ApplyScrollBar()
    self:ApplyPanelScrollBars()
    if map:IsShown() then self:QueueScrollBarApply() end
    return true
end

function MapSkin:RefreshAppearance()
    if initialized then
        self:ApplyWindowChrome()
        self:ApplyNavigationBar()
        self:ApplySideTabs()
        self:ApplySearchBox()
        self:ApplyQuestListSurface()
        self:ApplyQuestLogSectionCards()
        self:ApplyQuestLogCheckboxes()
        self:ApplyCampaignOverviewCard()
        self:ApplyEventSectionCards()
        self:ApplyScrollBar()
        self:ApplyPanelScrollBars()
    end
end

local function IsAddOnLoaded(addonName)
    if _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded then
        return _G.C_AddOns.IsAddOnLoaded(addonName)
    end
    return _G.IsAddOnLoaded and _G.IsAddOnLoaded(addonName) or false
end

local function IsShown(frame)
    return frame and frame.IsShown and frame:IsShown() or false
end

function MapSkin:Debug()
    local map = _G.WorldMapFrame
    local questScrollFrame = _G.QuestScrollFrame
    local scrollBar = GetMapScrollBar()
    local track = scrollBar and scrollBar.Track
    local thumb = track and track.Thumb

    NSkin:Print(("mapdebug enabled=%s addonLoaded=%s initialized=%s "
        .. "showHooked=%s applyPending=%s"):format(
        tostring(NSkin:IsModuleEnabled("Map")),
        tostring(IsAddOnLoaded("Blizzard_WorldMap")),
        tostring(initialized), tostring(showHooked), tostring(applyPending)))
    NSkin:Print(("mapdebug map=%s mapShown=%s questScrollFrame=%s "
        .. "scrollBar=%s scrollBarShown=%s"):format(
        tostring(map), tostring(IsShown(map)), tostring(questScrollFrame),
        tostring(scrollBar), tostring(IsShown(scrollBar))))
    NSkin:Print(("mapdebug parts track=%s thumb=%s back=%s forward=%s"):format(
        tostring(track), tostring(thumb),
        tostring(scrollBar and scrollBar.Back),
        tostring(scrollBar and scrollBar.Forward)))

    local applied = self:ApplyScrollBar()
    local element = NSkin:GetSkinningElement(IDs.QuestLogScrollBar)
    local data = scrollBar and NSkin:GetSkinData(
        scrollBar, "components", false)
    local ownedTrack = data and data.scrollTrack
    local ownedThumb = data and data.scrollThumb
    NSkin:Print(("mapdebug apply=%s registered=%s targetMatch=%s kind=%s"):format(
        tostring(applied), tostring(element ~= nil),
        tostring(element and element.target == scrollBar),
        tostring(element and element.kind)))
    NSkin:Print(("mapdebug ownedTrack=%s trackShown=%s ownedThumb=%s "
        .. "thumbShown=%s"):format(
        tostring(ownedTrack), tostring(IsShown(ownedTrack)),
        tostring(ownedThumb), tostring(IsShown(ownedThumb))))
end

NSkin:RegisterWindowSkin({
    module = "Map",
    addon = "Blizzard_WorldMap",
    apply = function() return MapSkin:Initialize() end,
})
