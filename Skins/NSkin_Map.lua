local _, NSkin = ...

local MapSkin = NSkin:NewModule("Map")

local IDs = {
    Scope = "Map",
    Window = "Map.Window",
    HeaderControls = "Map.HeaderControls",
    Fullscreen = "Map.FullscreenButton",
    QuestLogScrollBar = "Map.QuestLog.ScrollBar",
}

local initialized = false
local showHooked = false
local applyPending = false
local hookedScrollBar

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Map & Quest Log",
})

local function GetMapScrollBar()
    local questScrollFrame = _G.QuestScrollFrame
    return questScrollFrame and questScrollFrame.ScrollBar
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

function MapSkin:ApplyScrollBar()
    local map = _G.WorldMapFrame
    local scrollBar = GetMapScrollBar()
    if not map or not scrollBar then return false end

    NSkin:SkinScrollBar(scrollBar, NSkin:GetAppearanceStyle(
        "scrollBar", IDs.Scope, IDs.QuestLogScrollBar))

    NSkin:RegisterSimpleMovableElement({
        id = IDs.QuestLogScrollBar,
        module = "Map",
        appearanceWindowID = IDs.Scope,
        label = "Map quest log scroll bar",
        kind = "SCROLLBAR",
        window = map,
        target = scrollBar,
        priority = 80,
        highlightRegions = { scrollBar },
        isEditable = function()
            return map:IsVisible() and scrollBar:IsVisible()
        end,
    })
    if hookedScrollBar ~= scrollBar and scrollBar.HookScript then
        scrollBar:HookScript("OnShow", function()
            MapSkin:QueueScrollBarApply()
        end)
        hookedScrollBar = scrollBar
    end
    return true
end

function MapSkin:QueueScrollBarApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        MapSkin:ApplyWindowChrome()
        MapSkin:ApplyScrollBar()
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
    self:ApplyScrollBar()
    if map:IsShown() then self:QueueScrollBarApply() end
    return true
end

function MapSkin:RefreshAppearance()
    if initialized then
        self:ApplyWindowChrome()
        self:ApplyScrollBar()
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
