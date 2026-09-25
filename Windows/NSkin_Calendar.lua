local _, NSkin = ...

local CalendarSkin = NSkin:NewModule("Calendar")

local IDs = {
    Scope = "Calendar",
    Window = "Calendar.Window",
    HeaderControls = "Calendar.HeaderControls",
    Filter = "Calendar.Filter",
    PreviousMonth = "Calendar.PreviousMonth",
    NextMonth = "Calendar.NextMonth",
    Month = "Calendar.Month",
    Year = "Calendar.Year",
    Weekdays = "Calendar.Weekdays",
    Holiday = {
        Scope = "Calendar.Holiday",
        Window = "Calendar.Holiday.Window",
        HeaderControls = "Calendar.Holiday.HeaderControls",
        HeaderText = "Calendar.Holiday.HeaderText",
        BodyText = "Calendar.Holiday.BodyText",
    },
    EventPicker = {
        Scope = "Calendar.EventPicker",
        Window = "Calendar.EventPicker.Window",
        ScrollBar = "Calendar.EventPicker.ScrollBar",
        CloseButton = "Calendar.EventPicker.CloseButton",
        HeaderText = "Calendar.EventPicker.HeaderText",
        Rows = "Calendar.EventPicker.Rows",
    },
    CreateEvent = {
        Scope = "Calendar.CreateEvent",
        Window = "Calendar.CreateEvent.Window",
        HeaderControls = "Calendar.CreateEvent.HeaderControls",
        HeaderText = "Calendar.CreateEvent.HeaderText",
        DateText = "Calendar.CreateEvent.DateText",
        EventIcon = "Calendar.CreateEvent.EventIcon",
        ClassIcons = "Calendar.CreateEvent.ClassIcons",
        TitleInput = "Calendar.CreateEvent.TitleInput",
        InviteInput = "Calendar.CreateEvent.InviteInput",
        DescriptionInput = "Calendar.CreateEvent.DescriptionInput",
        EventTypeDropdown = "Calendar.CreateEvent.EventTypeDropdown",
        HourDropdown = "Calendar.CreateEvent.HourDropdown",
        MinuteDropdown = "Calendar.CreateEvent.MinuteDropdown",
        AMPMDropdown = "Calendar.CreateEvent.AMPMDropdown",
        InviteButton = "Calendar.CreateEvent.InviteButton",
        MassInviteButton = "Calendar.CreateEvent.MassInviteButton",
        CreateButton = "Calendar.CreateEvent.CreateButton",
        LockEvent = "Calendar.CreateEvent.LockEvent",
    },
}

local initialized = false
local calendarShowHooked = false
local holidayShowHooked = false
local holidayScrollBoxHooked = false
local eventPickerShowHooked = false
local eventPickerScrollBoxHooked = false
local createEventShowHooked = false
local createEventLifecycleHooked = false
local weekdayHeadersRegistered = false
local holidayBodyRegistered = false
local eventPickerRowsRegistered = false
local createEventClassIconsRegistered = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Calendar",
})
NSkin:RegisterAppearanceScope(IDs.Holiday.Scope, {
    label = "Holiday",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.EventPicker.Scope, {
    label = "Event Picker",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.CreateEvent.Scope, {
    label = "Create Event",
    parent = IDs.Scope,
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function RefreshElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

local function SuppressRegions(owner, regions)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "calendarDecorations")
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

local function GetMainArtwork()
    local regions = {}
    for _, name in ipairs({
        "CalendarFrameTopLeftTexture",
        "CalendarFrameTopMiddleTexture",
        "CalendarFrameTopRightTexture",
        "CalendarFrameLeftTopTexture",
        "CalendarFrameLeftMiddleTexture",
        "CalendarFrameLeftBottomTexture",
        "CalendarFrameRightTopTexture",
        "CalendarFrameRightMiddleTexture",
        "CalendarFrameRightBottomTexture",
        "CalendarFrameBottomLeftTexture",
        "CalendarFrameBottomMiddleTexture",
        "CalendarFrameBottomRightTexture",
        "CalendarMonthBackground",
        "CalendarYearBackground",
    }) do
        local region = _G[name]
        if region then regions[#regions + 1] = region end
    end
    return regions
end

local function GetHolidayScrollBox(frame)
    local scrollingFont = frame and frame.ScrollingFont
    return scrollingFont and scrollingFont.ScrollBox
end

local function GetEventPickerRows(frame, visibleOnly)
    local rows = {}
    NSkin:ForEachScrollBoxFrame(frame and frame.ScrollBox, function(target)
        if target and target.Title
            and (not visibleOnly or IsVisible(target))
        then
            rows[#rows + 1] = target
        end
    end)
    return rows
end

local function GetHolidayBodyTexts(frame, visibleOnly)
    local texts = {}
    NSkin:ForEachScrollBoxFrame(GetHolidayScrollBox(frame), function(target)
        local text = target and target.FontString
        if text and (not visibleOnly or IsVisible(text)) then
            texts[#texts + 1] = text
        end
    end)
    return texts
end

local function GetWeekdayOwner(frame, index)
    local background = _G["CalendarWeekday" .. index .. "Background"]
    local text = _G["CalendarWeekday" .. index .. "Name"]
    if not background or not text then return nil end

    local data = NSkin:GetSkinData(frame, "calendarWeekdayHeaders")
    data.owners = data.owners or {}
    local owner = data.owners[index]
    if not owner then
        owner = CreateFrame("Frame", nil, frame)
        data.owners[index] = owner
    end
    owner:ClearAllPoints()
    owner:SetAllPoints(background)
    if owner.SetFrameLevel and frame.GetFrameLevel then
        owner:SetFrameLevel(frame:GetFrameLevel())
    end
    owner:Show()
    return owner, background, text
end

local function GetVisibleWeekdayOwners(frame)
    local owners = {}
    for index = 1, 7 do
        local owner = GetWeekdayOwner(frame, index)
        if owner and IsVisible(owner) then owners[#owners + 1] = owner end
    end
    return owners
end

local function GetCreateEventDescription()
    local container = _G.CalendarCreateEventDescriptionContainer
        or _G.CalendarCreateEventDescriptionsContainer
    local scrolling = container and container.ScrollingEditBox
    local editBox = scrolling and scrolling.GetEditBox
        and scrolling:GetEditBox()
        or (scrolling and scrolling.ScrollBox
            and scrolling.ScrollBox.EditBox)
    return editBox, container
end

local function GetCalendarClassButtons(visibleOnly)
    local buttons = {}
    local limit = tonumber(_G.MAX_CLASSES) or 20
    for index = 1, limit do
        local button = _G["CalendarClassButton" .. index]
        if button and (not visibleOnly or IsVisible(button)) then
            buttons[#buttons + 1] = button
        end
    end
    return buttons
end

local function GetCalendarClassIconDescriptors()
    local descriptors = {}
    for _, button in ipairs(GetCalendarClassButtons(false)) do
        descriptors[#descriptors + 1] = {
            target = button,
            textureProvider = function(target)
                return target.GetNormalTexture and target:GetNormalTexture()
            end,
            borderOwner = button,
            borderSize = 1,
            borderPadding = 0,
            hoverRegion = button.GetHighlightTexture
                and button:GetHighlightTexture(),
            nativeDecorationRegions = {
                button.GetHighlightTexture
                    and button:GetHighlightTexture(),
            },
        }
    end
    return descriptors
end

function CalendarSkin:ApplyMainWindowChrome(frame)
    SuppressRegions(frame, GetMainArtwork())
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        closeButton = _G.CalendarCloseButton or frame.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Calendar window",
        kind = "WINDOW",
        module = "Calendar",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function CalendarSkin:ApplyMainControls(frame)
    local applied = false
    local filter = frame.FilterButton
    if filter then
        applied = RefreshElement(NSkin:RegisterDropdown({
            id = IDs.Filter,
            module = "Calendar",
            appearanceWindowID = IDs.Scope,
            label = "Calendar filter",
            window = frame,
            target = filter,
            menus = { "MENU_CALENDAR_FILTER" },
            priority = 20,
            highlightRegions = { filter },
            isEditable = function()
                return IsVisible(frame) and IsVisible(filter)
            end,
        })) ~= nil or applied
    end

    for index, definition in ipairs({
        { IDs.PreviousMonth, "Previous month button",
            _G.CalendarPrevMonthButton, "<" },
        { IDs.NextMonth, "Next month button",
            _G.CalendarNextMonthButton, ">" },
    }) do
        local id, label, button, glyph = unpack(definition)
        if button then
            applied = RefreshElement(NSkin:RegisterTypedElement("BUTTON", {
                id = id,
                module = "Calendar",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = button,
                priority = 20 + index,
                skinOptions = { label = glyph },
                highlightRegions = { button },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            })) ~= nil or applied
        end
    end
    return applied
end

function CalendarSkin:ApplyMainText(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.Month, "Calendar month", _G.CalendarMonthName },
        { IDs.Year, "Calendar year", _G.CalendarYearName },
    }) do
        local id, label, target = unpack(definition)
        if target then
            applied = RefreshElement(NSkin:RegisterTextElement({
                id = id,
                module = "Calendar",
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

function CalendarSkin:ApplyWeekdayHeaders(frame)
    local function Refresh()
        local style = NSkin:GetAppearanceStyle(
            "columnHeader", IDs.Scope, IDs.Weekdays)
        local border = NSkin:GetAppearanceBorderColor(
            "columnHeader", style, IDs.Scope, IDs.Weekdays)
        local applied = false
        for index = 1, 7 do
            local owner, background, text = GetWeekdayOwner(frame, index)
            if owner then
                NSkin:SkinColumnHeader(owner, {
                    style = style,
                    border = border,
                    textRegion = text,
                    artworkRegions = { background },
                })
                applied = true
            end
        end
        return applied
    end

    if not weekdayHeadersRegistered then
        weekdayHeadersRegistered = NSkin:RegisterSkinningElement(
            IDs.Weekdays, {
                module = "Calendar",
                appearanceWindowID = IDs.Scope,
                label = "Calendar weekday headers",
                kind = "COLUMN_HEADER",
                window = frame,
                target = frame,
                priority = 40,
                draggable = false,
                highlightRegions = function()
                    return GetVisibleWeekdayOwners(frame)
                end,
                pixelBorderTargets = function()
                    return GetVisibleWeekdayOwners(frame)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetVisibleWeekdayOwners(frame) > 0
                end,
            }) == true
    end
    local applied = Refresh()
    if weekdayHeadersRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.Weekdays)
    end
    return applied or weekdayHeadersRegistered
end

function CalendarSkin:ApplyHolidayWindowChrome(frame)
    if frame.Border then
        NSkin:ConcealWindowArtwork(frame.Border)
        NSkin:HideTextureRegions(frame.Border)
    end
    if frame.Header then NSkin:HideTextureRegions(frame.Header) end
    SuppressRegions(frame, { frame.Texture })
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Holiday.Scope,
        elementID = IDs.Holiday.Window,
        headerControlsID = IDs.Holiday.HeaderControls,
        -- The title is a separately registered canonical TEXT element.
        title = false,
        closeButton = _G.CalendarViewHolidayCloseButton
            or frame.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.Holiday.Window, {
        label = "Holiday details window",
        kind = "WINDOW",
        module = "Calendar",
        appearanceWindowID = IDs.Holiday.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function CalendarSkin:ApplyHolidayHeaderText(frame)
    local target = frame.Header and frame.Header.Text
    if not target then return false end
    return RefreshElement(NSkin:RegisterTextElement({
        id = IDs.Holiday.HeaderText,
        module = "Calendar",
        appearanceWindowID = IDs.Holiday.Scope,
        label = "Holiday title",
        window = frame,
        target = target,
        priority = 20,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(frame) and IsVisible(target)
        end,
    })) ~= nil
end

function CalendarSkin:StyleHolidayBodyTarget(frame, target)
    local text = target and target.FontString
    if not text then return false end
    return NSkin:SkinText(text, NSkin:GetAppearanceStyle(
        "text", IDs.Holiday.Scope, IDs.Holiday.BodyText)) == true
end

function CalendarSkin:ApplyHolidayBodyText(frame)
    local scrollBox = GetHolidayScrollBox(frame)
    if not scrollBox then return false end
    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        applied = self:StyleHolidayBodyTarget(frame, target) or applied
    end)

    local function Refresh()
        return CalendarSkin:ApplyHolidayBodyText(frame)
    end
    if not holidayBodyRegistered then
        holidayBodyRegistered = NSkin:RegisterSkinningElement(
            IDs.Holiday.BodyText, {
                module = "Calendar",
                appearanceWindowID = IDs.Holiday.Scope,
                label = "Holiday description text",
                kind = "TEXT",
                window = frame,
                target = scrollBox,
                priority = 30,
                draggable = false,
                highlightRegions = function()
                    return GetHolidayBodyTexts(frame, true)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetHolidayBodyTexts(frame, true) > 0
                end,
            }) == true
    end
    if holidayBodyRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.Holiday.BodyText)
    end
    return applied or holidayBodyRegistered
end

function CalendarSkin:HookHolidayScrollBox(frame)
    local scrollBox = GetHolidayScrollBox(frame)
    if not scrollBox or holidayScrollBoxHooked then return false end
    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, target)
                CalendarSkin:StyleHolidayBodyTarget(frame, target)
                if holidayBodyRegistered then
                    NSkin:NotifySkinningElementBoundsChanged(
                        IDs.Holiday.BodyText)
                end
            end, self)
        holidayScrollBoxHooked = true
    elseif _G.hooksecurefunc and type(scrollBox.Update) == "function" then
        _G.hooksecurefunc(scrollBox, "Update", function()
            CalendarSkin:ApplyHolidayBodyText(frame)
        end)
        holidayScrollBoxHooked = true
    end
    return holidayScrollBoxHooked
end

function CalendarSkin:ApplyEventPickerWindowChrome(frame)
    if frame.Border then
        NSkin:ConcealWindowArtwork(frame.Border)
        NSkin:HideTextureRegions(frame.Border)
    end
    if frame.Header then NSkin:HideTextureRegions(frame.Header) end
    SuppressRegions(frame, {
        _G.CalendarEventPickerFrameButtonBackground,
        frame.ButtonBackground,
    })
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.EventPicker.Scope,
        elementID = IDs.EventPicker.Window,
        title = false,
        skinCloseButton = false,
    })
    NSkin:RegisterSkinningElement(IDs.EventPicker.Window, {
        label = "Calendar event picker window",
        kind = "WINDOW",
        module = "Calendar",
        appearanceWindowID = IDs.EventPicker.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function CalendarSkin:ApplyEventPickerControls(frame)
    local applied = false
    local scrollBar = frame.ScrollBar
    if scrollBar then
        applied = RefreshElement(NSkin:RegisterScrollBar({
            id = IDs.EventPicker.ScrollBar,
            module = "Calendar",
            appearanceWindowID = IDs.EventPicker.Scope,
            label = "Event picker scroll bar",
            window = frame,
            target = scrollBar,
            priority = 20,
            highlightRegions = { scrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(scrollBar)
            end,
        })) ~= nil or applied
    end

    local closeButton = frame.CloseButton
        or _G.CalendarEventPickerCloseButton
    if closeButton then
        applied = RefreshElement(NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.EventPicker.CloseButton,
            module = "Calendar",
            appearanceWindowID = IDs.EventPicker.Scope,
            label = "Event picker close button",
            window = frame,
            target = closeButton,
            priority = 21,
            isEditable = function()
                return IsVisible(frame) and IsVisible(closeButton)
            end,
        })) ~= nil or applied
    end
    return applied
end

function CalendarSkin:ApplyEventPickerHeaderText(frame)
    local target = frame.Header and frame.Header.Text
    if not target then return false end
    return RefreshElement(NSkin:RegisterTextElement({
        id = IDs.EventPicker.HeaderText,
        module = "Calendar",
        appearanceWindowID = IDs.EventPicker.Scope,
        label = "Event picker title",
        window = frame,
        target = target,
        priority = 30,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(frame) and IsVisible(target)
        end,
    })) ~= nil
end

function CalendarSkin:StyleEventPickerRow(frame, target)
    if not target or not target.Title then
        if target then NSkin:SkinSectionRow(target, { reset = true }) end
        return false
    end
    local style = NSkin:GetAppearanceStyle(
        "sectionRow", IDs.EventPicker.Scope, IDs.EventPicker.Rows)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionRow", style, IDs.EventPicker.Scope, IDs.EventPicker.Rows)
    local highlight = target.GetHighlightTexture
        and target:GetHighlightTexture() or target.HighlightTexture
    return NSkin:SkinSectionRow(target, {
        style = style,
        border = border,
        height = 0,
        textRegion = target.Title,
        contentRegions = { target.Title },
        contentStyle = NSkin:GetAppearanceStyle(
            "text", IDs.EventPicker.Scope, IDs.EventPicker.Rows),
        hoverRegion = highlight,
        getHovered = function(row)
            return row and row.IsMouseOver and row:IsMouseOver() or false
        end,
        getSelected = function(row)
            return frame.selectedEventButton == row
        end,
    }) ~= nil
end

function CalendarSkin:ApplyEventPickerRows(frame)
    local scrollBox = frame.ScrollBox
    if not scrollBox then return false end
    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        applied = self:StyleEventPickerRow(frame, target) or applied
    end)

    local function Refresh()
        return CalendarSkin:ApplyEventPickerRows(frame)
    end
    if not eventPickerRowsRegistered then
        eventPickerRowsRegistered = NSkin:RegisterSkinningElement(
            IDs.EventPicker.Rows, {
                module = "Calendar",
                appearanceWindowID = IDs.EventPicker.Scope,
                label = "Calendar event picker rows",
                kind = "SECTION_ROW",
                window = frame,
                target = scrollBox,
                priority = 40,
                draggable = false,
                appearanceStyles = { "text" },
                appearanceTypeIDs = { "TEXT" },
                highlightRegions = function()
                    return GetEventPickerRows(frame, true)
                end,
                pixelBorderTargets = function()
                    return GetEventPickerRows(frame, true)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetEventPickerRows(frame, true) > 0
                end,
            }) == true
    end
    if eventPickerRowsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.EventPicker.Rows)
    end
    return applied or eventPickerRowsRegistered
end

function CalendarSkin:HookEventPickerScrollBox(frame)
    local scrollBox = frame and frame.ScrollBox
    if not scrollBox or eventPickerScrollBoxHooked then return false end
    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, target)
                CalendarSkin:StyleEventPickerRow(frame, target)
                if eventPickerRowsRegistered then
                    NSkin:NotifySkinningElementBoundsChanged(
                        IDs.EventPicker.Rows)
                end
            end, self)
        eventPickerScrollBoxHooked = true
    elseif _G.hooksecurefunc and type(scrollBox.Update) == "function" then
        _G.hooksecurefunc(scrollBox, "Update", function()
            CalendarSkin:ApplyEventPickerRows(frame)
        end)
        eventPickerScrollBoxHooked = true
    end
    return eventPickerScrollBoxHooked
end

function CalendarSkin:ApplyCreateEventWindowChrome(frame)
    if frame.Border then
        NSkin:ConcealWindowArtwork(frame.Border)
        NSkin:HideTextureRegions(frame.Border)
    end
    if frame.Header then NSkin:HideTextureRegions(frame.Header) end
    SuppressRegions(frame, {
        _G.CalendarCreateEventFrameButtonBackground,
        frame.ButtonBackground,
    })
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.CreateEvent.Scope,
        elementID = IDs.CreateEvent.Window,
        headerControlsID = IDs.CreateEvent.HeaderControls,
        title = false,
        closeButton = _G.CalendarCreateEventCloseButton
            or frame.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.CreateEvent.Window, {
        label = "Create event window",
        kind = "WINDOW",
        module = "Calendar",
        appearanceWindowID = IDs.CreateEvent.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function CalendarSkin:ApplyCreateEventText(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.CreateEvent.HeaderText, "Create event title",
            frame.Header and frame.Header.Text },
        { IDs.CreateEvent.DateText, "Create event date",
            _G.CalendarCreateEventDateLabel },
    }) do
        local id, label, target = unpack(definition)
        if target then
            applied = RefreshElement(NSkin:RegisterTextElement({
                id = id,
                module = "Calendar",
                appearanceWindowID = IDs.CreateEvent.Scope,
                label = label,
                window = frame,
                target = target,
                priority = 20 + index,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })) ~= nil or applied
        end
    end
    return applied
end

function CalendarSkin:ApplyCreateEventIcons(frame)
    local applied = false
    local eventIcon = _G.CalendarCreateEventIcon
    if eventIcon then
        applied = RefreshElement(NSkin:RegisterIcon({
            id = IDs.CreateEvent.EventIcon,
            module = "Calendar",
            appearanceWindowID = IDs.CreateEvent.Scope,
            label = "Create event icon",
            window = frame,
            target = eventIcon,
            borderOwner = frame,
            priority = 30,
            highlightRegions = { eventIcon },
            isEditable = function()
                return IsVisible(frame) and IsVisible(eventIcon)
            end,
        })) ~= nil or applied
    end

    local container = _G.CalendarClassButtonContainer
    if container and not createEventClassIconsRegistered then
        createEventClassIconsRegistered = NSkin:RegisterIconGroup({
            id = IDs.CreateEvent.ClassIcons,
            module = "Calendar",
            appearanceWindowID = IDs.CreateEvent.Scope,
            label = "Calendar class icons",
            window = frame,
            target = container,
            priority = 31,
            draggable = false,
            children = GetCalendarClassIconDescriptors,
            highlightRegions = function()
                return GetCalendarClassButtons(true)
            end,
            pixelBorderTargets = function()
                return GetCalendarClassButtons(true)
            end,
            isEditable = function()
                return IsVisible(frame) and IsVisible(container)
                    and #GetCalendarClassButtons(true) > 0
            end,
        }) ~= nil
    elseif container then
        NSkin:RefreshIconGroup(IDs.CreateEvent.ClassIcons)
    end
    return applied or createEventClassIconsRegistered
end

function CalendarSkin:ApplyCreateEventInputs(frame)
    local description, descriptionContainer = GetCreateEventDescription()
    local applied = false
    for index, definition in ipairs({
        { IDs.CreateEvent.TitleInput, "Event title input",
            _G.CalendarCreateEventTitleEdit },
        { IDs.CreateEvent.InviteInput, "Event invite input",
            _G.CalendarCreateEventInviteEdit },
        { IDs.CreateEvent.DescriptionInput, "Event description input",
            description, descriptionContainer },
    }) do
        local id, label, target, surface = unpack(definition)
        if target then
            applied = RefreshElement(NSkin:RegisterEditBox({
                id = id,
                module = "Calendar",
                appearanceWindowID = IDs.CreateEvent.Scope,
                label = label,
                window = frame,
                target = target,
                priority = 40 + index,
                skinOptions = surface and { surface = surface } or nil,
                highlightRegions = { surface or target },
                pixelBorderTargets = { surface or target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(surface or target)
                end,
            })) ~= nil or applied
        end
    end
    return applied
end

function CalendarSkin:ApplyCreateEventDropdowns(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.CreateEvent.EventTypeDropdown, "Event type dropdown",
            frame.EventTypeDropdown, "MENU_CALENDAR_EVENT_TYPE" },
        { IDs.CreateEvent.HourDropdown, "Event hour dropdown",
            frame.HourDropdown, "MENU_CALENDAR_HOUR" },
        { IDs.CreateEvent.MinuteDropdown, "Event minute dropdown",
            frame.MinuteDropdown, "MENU_CALENDAR_MINUTE" },
        { IDs.CreateEvent.AMPMDropdown, "Event AM/PM dropdown",
            frame.AMPMDropdown, "MENU_CALENDAR_AMPM" },
    }) do
        local id, label, target, menu = unpack(definition)
        if target then
            applied = RefreshElement(NSkin:RegisterDropdown({
                id = id,
                module = "Calendar",
                appearanceWindowID = IDs.CreateEvent.Scope,
                label = label,
                window = frame,
                target = target,
                menus = { menu },
                priority = 50 + index,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })) ~= nil or applied
        end
    end
    return applied
end

function CalendarSkin:ApplyCreateEventButtons(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.CreateEvent.InviteButton, "Invite player button",
            _G.CalendarCreateEventInviteButton },
        { IDs.CreateEvent.MassInviteButton, "Mass invite button",
            _G.CalendarCreateEventMassInviteButton },
        { IDs.CreateEvent.CreateButton, "Create event button",
            _G.CalendarCreateEventCreateButton },
    }) do
        local id, label, target = unpack(definition)
        if target then
            applied = RefreshElement(NSkin:RegisterTypedElement("BUTTON", {
                id = id,
                module = "Calendar",
                appearanceWindowID = IDs.CreateEvent.Scope,
                label = label,
                window = frame,
                target = target,
                priority = 60 + index,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })) ~= nil or applied
        end
    end

    local checkbox = _G.CalendarCreateEventLockEventCheck
    if checkbox then
        applied = RefreshElement(NSkin:RegisterCheckbox({
            id = IDs.CreateEvent.LockEvent,
            module = "Calendar",
            appearanceWindowID = IDs.CreateEvent.Scope,
            label = "Lock event checkbox",
            window = frame,
            target = checkbox,
            text = checkbox.Text
                or _G.CalendarCreateEventLockEventCheckText,
            priority = 64,
            highlightRegions = { checkbox },
            isEditable = function()
                return IsVisible(frame) and IsVisible(checkbox)
            end,
        })) ~= nil or applied
    end
    return applied
end

function CalendarSkin:ApplyCreateEvent(frame)
    if not frame then return false end
    local applied = self:ApplyCreateEventWindowChrome(frame)
    applied = self:ApplyCreateEventText(frame) or applied
    applied = self:ApplyCreateEventIcons(frame) or applied
    applied = self:ApplyCreateEventInputs(frame) or applied
    applied = self:ApplyCreateEventDropdowns(frame) or applied
    applied = self:ApplyCreateEventButtons(frame) or applied
    return applied
end

function CalendarSkin:ApplyEventPicker(frame)
    if not frame then return false end
    self:HookEventPickerScrollBox(frame)
    local applied = self:ApplyEventPickerWindowChrome(frame)
    applied = self:ApplyEventPickerControls(frame) or applied
    applied = self:ApplyEventPickerHeaderText(frame) or applied
    applied = self:ApplyEventPickerRows(frame) or applied
    return applied
end

function CalendarSkin:ApplyHoliday(frame)
    if not frame then return false end
    self:HookHolidayScrollBox(frame)
    local applied = self:ApplyHolidayWindowChrome(frame)
    applied = self:ApplyHolidayHeaderText(frame) or applied
    applied = self:ApplyHolidayBodyText(frame) or applied
    return applied
end

function CalendarSkin:Apply()
    local frame = _G.CalendarFrame
    if not frame then return false end
    local applied = self:ApplyMainWindowChrome(frame)
    applied = self:ApplyMainControls(frame) or applied
    applied = self:ApplyMainText(frame) or applied
    applied = self:ApplyWeekdayHeaders(frame) or applied

    local holiday = _G.CalendarViewHolidayFrame
    if holiday then
        self:HookHolidayScrollBox(holiday)
        applied = self:ApplyHoliday(holiday) or applied
    end
    local eventPicker = _G.CalendarEventPickerFrame
    if eventPicker then
        self:HookEventPickerScrollBox(eventPicker)
        applied = self:ApplyEventPicker(eventPicker) or applied
    end
    local createEvent = _G.CalendarCreateEventFrame
    if createEvent then
        applied = self:ApplyCreateEvent(createEvent) or applied
    end
    return applied
end

function CalendarSkin:Initialize()
    local frame = _G.CalendarFrame
    if not frame then return false end
    if not calendarShowHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            CalendarSkin:Apply()
        end)
        calendarShowHooked = true
    end
    local holiday = _G.CalendarViewHolidayFrame
    if holiday and not holidayShowHooked and holiday.HookScript then
        holiday:HookScript("OnShow", function()
            CalendarSkin:ApplyHoliday(holiday)
        end)
        holidayShowHooked = true
    end
    if holiday then self:HookHolidayScrollBox(holiday) end
    local eventPicker = _G.CalendarEventPickerFrame
    if eventPicker and not eventPickerShowHooked
        and eventPicker.HookScript
    then
        eventPicker:HookScript("OnShow", function()
            CalendarSkin:ApplyEventPicker(eventPicker)
        end)
        eventPickerShowHooked = true
    end
    if eventPicker then self:HookEventPickerScrollBox(eventPicker) end
    local createEvent = _G.CalendarCreateEventFrame
    if createEvent and not createEventShowHooked
        and createEvent.HookScript
    then
        createEvent:HookScript("OnShow", function()
            CalendarSkin:ApplyCreateEvent(createEvent)
        end)
        createEventShowHooked = true
    end
    if createEvent and not createEventLifecycleHooked
        and _G.hooksecurefunc
        and type(_G.CalendarCreateEventTexture_Update) == "function"
    then
        _G.hooksecurefunc("CalendarCreateEventTexture_Update", function()
            if IsVisible(createEvent) then
                CalendarSkin:ApplyCreateEventIcons(createEvent)
            end
        end)
        createEventLifecycleHooked = true
    end
    initialized = true
    return self:Apply()
end

function CalendarSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    key = "Calendar.Window",
    module = "Calendar",
    addon = "Blizzard_Calendar",
    apply = function()
        return CalendarSkin:Initialize()
    end,
})
