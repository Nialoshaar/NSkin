local _, NSkin = ...

local TimeManagerSkin = NSkin:NewModule("TimeManager")

local IDs = {
    Scope = "TimeManager",
    Window = "TimeManager.Window",
    HeaderControls = "TimeManager.HeaderControls",
    TickerPlacement = "TimeManager.Ticker:HeaderPlacement",
    Stopwatch = "TimeManager.Stopwatch",
    AlarmTimeLabel = "TimeManager.AlarmTimeLabel",
    AlarmMessageLabel = "TimeManager.AlarmMessageLabel",
    AlarmEnabled = "TimeManager.AlarmEnabled",
    MilitaryTime = "TimeManager.MilitaryTime",
    LocalTime = "TimeManager.LocalTime",
    AlarmMessageInput = "TimeManager.AlarmMessageInput",
    HourDropdown = "TimeManager.HourDropdown",
    MinuteDropdown = "TimeManager.MinuteDropdown",
    AMPMDropdown = "TimeManager.AMPMDropdown",
    StopwatchFrame = {
        Scope = "TimeManager.StopwatchFrame",
        Window = "TimeManager.StopwatchFrame.Window",
        HeaderControls = "TimeManager.StopwatchFrame.HeaderControls",
        Tab = "TimeManager.StopwatchFrame.Tab",
        Time = "TimeManager.StopwatchFrame.Time",
        ResetButton = "TimeManager.StopwatchFrame.ResetButton",
        PlayPauseButton = "TimeManager.StopwatchFrame.PlayPauseButton",
    },
}

local initialized = false
local showHooked = false
local stopwatchRegistered = false
local stopwatchFrameShowHooked = false
local stopwatchTabRegistered = false
local stopwatchTimeRegistered = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Time Manager",
})
NSkin:RegisterAppearanceScope(IDs.StopwatchFrame.Scope, {
    label = "Stopwatch",
    parent = IDs.Scope,
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function RefreshElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

local function CompactRegions(...)
    local regions = {}
    for index = 1, select("#", ...) do
        local region = select(index, ...)
        if region then regions[#regions + 1] = region end
    end
    return regions
end

local function SuppressRegions(owner, regions)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "timeManagerDecorations")
    data.states = data.states or {}
    for _, region in ipairs(regions or {}) do
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

local function GetNativeTitle(frame, ticker)
    if not frame or not frame.GetRegions then return nil end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region ~= ticker and region.GetObjectType
            and region:GetObjectType() == "FontString"
            and region.GetText and region:GetText() == _G.TIMEMANAGER_TITLE
        then
            return region
        end
    end
end

local function GetStopwatchArtwork(frame)
    if not frame then return {} end
    local data = NSkin:GetSkinData(frame, "stopwatchWindowDecorations")
    if not data.nativeRegions then
        data.nativeRegions = {}
        for _, region in ipairs({ frame:GetRegions() }) do
            if region.GetObjectType
                and region:GetObjectType() == "Texture"
            then
                data.nativeRegions[#data.nativeRegions + 1] = region
            end
        end
    end
    return data.nativeRegions
end

local function GetStopwatchTimeTexts(visibleOnly)
    local ticker = _G.StopwatchTicker
    local texts = {}
    if not ticker or not ticker.GetRegions then return texts end
    for _, region in ipairs({ ticker:GetRegions() }) do
        if region.GetObjectType
            and region:GetObjectType() == "FontString"
            and (not visibleOnly or IsVisible(region))
        then
            texts[#texts + 1] = region
        end
    end
    return texts
end

local function PlaceTickerInHeader(frame, ticker, windowStyle)
    if not frame or not ticker then return false end
    NSkin:CaptureComponentBaseline(IDs.TickerPlacement, ticker, {
        points = true,
        canCapture = function(target)
            return target.GetNumPoints and target:GetNumPoints() > 0
        end,
    })
    local header = windowStyle and windowStyle.header or {}
    local height = tonumber(header.height) or 22
    ticker:ClearAllPoints()
    ticker:SetPoint("CENTER", frame, "TOP", 0, -height / 2)
    NSkin:MarkComponentGeometryModified(
        IDs.TickerPlacement, "points", true)
    return true
end

function TimeManagerSkin:ApplyWindowChrome(frame)
    local ticker = _G.TimeManagerFrameTicker
    SuppressRegions(frame, CompactRegions(
        _G.TimeManagerGlobe,
        GetNativeTitle(frame, ticker)))
    local chrome = NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = ticker,
        closeButton = frame.CloseButton
            or _G.TimeManagerFrameCloseButton,
    })
    PlaceTickerInHeader(frame, ticker, chrome and chrome.style)
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Time Manager window",
        kind = "WINDOW",
        module = "TimeManager",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function TimeManagerSkin:ApplyStopwatch(frame)
    local button = _G.TimeManagerStopwatchCheck
    local text = _G.TimeManagerStopwatchFrameText
    local icon = button and button.GetNormalTexture
        and button:GetNormalTexture()
    if not button or not icon or not text then return false end

    if not stopwatchRegistered then
        stopwatchRegistered = NSkin:RegisterIconGroup({
            id = IDs.Stopwatch,
            module = "TimeManager",
            appearanceWindowID = IDs.Scope,
            label = "Show stopwatch",
            window = frame,
            target = button,
            priority = 20,
            children = {
                {
                    target = button,
                    texture = icon,
                    borderOwner = button,
                    hoverRegion = button.GetHighlightTexture
                        and button:GetHighlightTexture(),
                    selectedRegion = button.GetCheckedTexture
                        and button:GetCheckedTexture(),
                    getHovered = function(target)
                        return target.IsMouseOver and target:IsMouseOver()
                            or false
                    end,
                    getSelected = function(target)
                        return target.GetChecked
                            and target:GetChecked() == true or false
                    end,
                    nativeDecorationRegions = CompactRegions(
                        button.GetHighlightTexture
                            and button:GetHighlightTexture(),
                        button.GetCheckedTexture
                            and button:GetCheckedTexture()),
                },
            },
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            editorOptions = {
                { id = "shared.iconAppearance", label = "Icon",
                    presentation = "INLINE", category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Text",
                    category = "CUSTOMIZE" },
            },
            refreshContent = function()
                local appearanceID = NSkin:GetElementAppearanceID(
                    IDs.Stopwatch, "TEXT")
                return NSkin:SkinText(text, NSkin:GetAppearanceStyle(
                    "text", IDs.Scope, appearanceID)) == true
            end,
            highlightRegions = { button, text },
            pixelBorderTargets = { button },
            composition = {
                mode = "COMPOSITE",
                movementOwner = button,
                members = {
                    { kind = "ICON", role = "PRIMARY", target = button,
                        label = "Icon" },
                    { kind = "TEXT", role = "SECONDARY", target = text,
                        label = "Text" },
                },
            },
            isEditable = function()
                return IsVisible(frame) and IsVisible(button)
            end,
        }) ~= nil
    else
        NSkin:RefreshIconGroup(IDs.Stopwatch)
    end
    return stopwatchRegistered
end

function TimeManagerSkin:ApplyText(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.AlarmTimeLabel, "Alarm time label",
            _G.TimeManagerAlarmTimeLabel },
        { IDs.AlarmMessageLabel, "Alarm message label",
            _G.TimeManagerAlarmMessageLabel },
    }) do
        local id, label, target = unpack(definition)
        if target then
            applied = RefreshElement(NSkin:RegisterTextElement({
                id = id,
                module = "TimeManager",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = target,
                priority = 30 + index,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })) ~= nil or applied
        end
    end
    return applied
end

function TimeManagerSkin:ApplyCheckboxes(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.AlarmEnabled, "Alarm enabled",
            _G.TimeManagerAlarmEnabledButton,
            _G.TimeManagerAlarmEnabledButtonText },
        { IDs.MilitaryTime, "24-hour time",
            _G.TimeManagerMilitaryTimeCheck
                or _G.TimeManagerMillitaryTimeCheck,
            _G.TimeManagerMilitaryTimeCheckText },
        { IDs.LocalTime, "Local time",
            _G.TimeManagerLocalTimeCheck,
            _G.TimeManagerLocalTimeCheckText },
    }) do
        local id, label, target, text = unpack(definition)
        if target then
            applied = RefreshElement(NSkin:RegisterCheckbox({
                id = id,
                module = "TimeManager",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = target,
                text = text or target.Text,
                priority = 40 + index,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })) ~= nil or applied
        end
    end
    return applied
end

function TimeManagerSkin:ApplyInputs(frame)
    local target = _G.TimeManagerAlarmMessageEditBox
    if not target then return false end
    return RefreshElement(NSkin:RegisterEditBox({
        id = IDs.AlarmMessageInput,
        module = "TimeManager",
        appearanceWindowID = IDs.Scope,
        label = "Alarm message input",
        window = frame,
        target = target,
        priority = 50,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(frame) and IsVisible(target)
        end,
    })) ~= nil
end

function TimeManagerSkin:ApplyDropdowns(frame)
    local alarmTime = frame.AlarmTimeFrame
        or _G.TimeManagerAlarmTimeFrame
    if not alarmTime then return false end
    local applied = false
    for index, definition in ipairs({
        { IDs.HourDropdown, "Alarm hour dropdown",
            alarmTime.HourDropdown, "MENU_TIME_MANAGER_HOUR" },
        { IDs.MinuteDropdown, "Alarm minute dropdown",
            alarmTime.MinuteDropdown, "MENU_TIME_MANAGER_MINUTE" },
        { IDs.AMPMDropdown, "Alarm AM/PM dropdown",
            alarmTime.AMPMDropdown, "MENU_TIME_MANAGER_AMPM" },
    }) do
        local id, label, target, menu = unpack(definition)
        if target then
            applied = RefreshElement(NSkin:RegisterDropdown({
                id = id,
                module = "TimeManager",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = target,
                menus = { menu },
                priority = 60 + index,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })) ~= nil or applied
        end
    end
    return applied
end

function TimeManagerSkin:ApplyStopwatchWindowChrome(frame)
    SuppressRegions(frame, GetStopwatchArtwork(frame))
    local tab = _G.StopwatchTabFrame
    local closeButton = _G.StopwatchCloseButton
        or (tab and tab.CloseButton)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.StopwatchFrame.Scope,
        elementID = IDs.StopwatchFrame.Window,
        headerControlsID = IDs.StopwatchFrame.HeaderControls,
        title = false,
        closeButton = closeButton,
    })
    NSkin:RegisterSkinningElement(IDs.StopwatchFrame.Window, {
        label = "Stopwatch window",
        kind = "WINDOW",
        module = "TimeManager",
        appearanceWindowID = IDs.StopwatchFrame.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function TimeManagerSkin:ApplyStopwatchTab(frame)
    local tab = _G.StopwatchTabFrame
    local title = _G.StopwatchTitle
    if not tab then return false end
    -- The Blizzard title is a direct FontString rather than a parentKey.
    -- Expose it through the canonical tab text slot without changing ownership.
    tab.Text = title
    if not stopwatchTabRegistered then
        stopwatchTabRegistered = NSkin:RegisterTabGroup(
            IDs.StopwatchFrame.Tab, {
                label = "Stopwatch title tab",
                kind = "TAB_GROUP",
                module = "TimeManager",
                appearanceWindowID = IDs.StopwatchFrame.Scope,
                window = frame,
                owner = frame,
                tabs = { tab },
                priority = 20,
                orientation = "HORIZONTAL",
                edge = "TOP",
                getSelected = function()
                    return true
                end,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(tab)
                end,
            }) == true
    end
    if stopwatchTabRegistered then
        NSkin:ApplyTabGroupLayout(IDs.StopwatchFrame.Tab)
    end
    return stopwatchTabRegistered
end

function TimeManagerSkin:ApplyStopwatchTime(frame)
    local ticker = _G.StopwatchTicker
    if not ticker then return false end
    local function Refresh()
        local style = NSkin:GetAppearanceStyle(
            "text", IDs.StopwatchFrame.Scope, IDs.StopwatchFrame.Time)
        local applied = false
        for _, text in ipairs(GetStopwatchTimeTexts(false)) do
            applied = NSkin:SkinText(text, style) == true or applied
        end
        return applied
    end
    local applied = Refresh()
    if not stopwatchTimeRegistered then
        stopwatchTimeRegistered = NSkin:RegisterSkinningElement(
            IDs.StopwatchFrame.Time, {
                label = "Stopwatch time",
                kind = "TEXT",
                module = "TimeManager",
                appearanceWindowID = IDs.StopwatchFrame.Scope,
                window = frame,
                target = ticker,
                priority = 30,
                draggable = false,
                highlightRegions = function()
                    return GetStopwatchTimeTexts(true)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetStopwatchTimeTexts(true) > 0
                end,
            }) == true
    end
    if stopwatchTimeRegistered then
        NSkin:NotifySkinningElementBoundsChanged(
            IDs.StopwatchFrame.Time)
    end
    return applied or stopwatchTimeRegistered
end

function TimeManagerSkin:ApplyStopwatchButtons(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.StopwatchFrame.ResetButton, "Reset stopwatch button",
            _G.StopwatchResetButton },
        { IDs.StopwatchFrame.PlayPauseButton,
            "Play or pause stopwatch button",
            _G.StopwatchPlayPauseButton },
    }) do
        local id, label, button = unpack(definition)
        if button then
            local icon = button.GetNormalTexture
                and button:GetNormalTexture()
            applied = RefreshElement(NSkin:RegisterTypedElement("BUTTON", {
                id = id,
                module = "TimeManager",
                appearanceWindowID = IDs.StopwatchFrame.Scope,
                label = label,
                window = frame,
                target = button,
                preserveTexture = icon,
                priority = 40 + index,
                highlightRegions = { button },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            })) ~= nil or applied
        end
    end
    return applied
end

function TimeManagerSkin:ApplyStopwatchFrame()
    local frame = _G.StopwatchFrame
    if not frame then return false end
    local applied = self:ApplyStopwatchWindowChrome(frame)
    applied = self:ApplyStopwatchTab(frame) or applied
    applied = self:ApplyStopwatchTime(frame) or applied
    applied = self:ApplyStopwatchButtons(frame) or applied
    return applied
end

function TimeManagerSkin:Apply()
    local frame = _G.TimeManagerFrame
    if not frame then return false end
    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyStopwatch(frame) or applied
    applied = self:ApplyText(frame) or applied
    applied = self:ApplyCheckboxes(frame) or applied
    applied = self:ApplyInputs(frame) or applied
    applied = self:ApplyDropdowns(frame) or applied
    applied = self:ApplyStopwatchFrame() or applied
    return applied
end

function TimeManagerSkin:Initialize()
    local frame = _G.TimeManagerFrame
    if not frame then return false end
    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            TimeManagerSkin:Apply()
        end)
        showHooked = true
    end
    local stopwatchFrame = _G.StopwatchFrame
    if stopwatchFrame and not stopwatchFrameShowHooked
        and stopwatchFrame.HookScript
    then
        stopwatchFrame:HookScript("OnShow", function()
            TimeManagerSkin:ApplyStopwatchFrame()
        end)
        stopwatchFrameShowHooked = true
    end
    initialized = true
    return self:Apply()
end

function TimeManagerSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    key = "TimeManager.Window",
    module = "TimeManager",
    addon = "Blizzard_TimeManager",
    apply = function()
        return TimeManagerSkin:Initialize()
    end,
})
