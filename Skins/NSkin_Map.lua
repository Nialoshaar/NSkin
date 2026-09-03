local _, NSkin = ...

local MapSkin = NSkin:NewModule("Map")

local IDs = {
    Scope = "Map",
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

    initialized = true
    self:ApplyScrollBar()
    if map:IsShown() then self:QueueScrollBarApply() end
    return true
end

function MapSkin:RefreshAppearance()
    if initialized then self:ApplyScrollBar() end
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
