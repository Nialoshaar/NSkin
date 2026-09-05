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
    EventsScrollBar = "Map.Events.ScrollBar",
    MapLegendScrollBar = "Map.Legend.ScrollBar",
    SideTabs = "Map.SideTabs",
}

local initialized = false
local showHooked = false
local applyPending = false
local hookedScrollBars = setmetatable({}, { __mode = "k" })

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

local function GetEventsScrollBar()
    local questMapFrame = _G.QuestMapFrame
    local eventsFrame = questMapFrame and questMapFrame.EventsFrame
    return eventsFrame and eventsFrame.ScrollBar, eventsFrame
end

local function GetMapLegendScrollBar()
    local legend = _G.MapLegendScrollFrame
    return legend and legend.ScrollBar, legend
end

local function HideDecorativeTexture(texture)
    if not texture then return end
    if texture.SetAlpha then texture:SetAlpha(0) end
    if texture.Hide then texture:Hide() end
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
    self:ApplyWindowChrome()
    self:ApplyNavigationBar()
    self:ApplySideTabs()
    self:ApplySearchBox()
    self:ApplyQuestListSurface()
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
