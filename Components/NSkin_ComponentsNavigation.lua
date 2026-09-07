local _, NSkin = ...

local COMPONENT_STATE = "components"
local navigationBarAddButtonHooked = false

local function RefreshNavigationLeftButton(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    local arrow = data and data.navigationLeftArrow
    if not arrow then return end
    -- Blizzard collapses the overflow button by reducing it to zero width
    -- without necessarily hiding the frame. Hide every NSkin-owned region in
    -- that state so its coincident border edges do not leave a divider across
    -- the first breadcrumb button.
    local shown = (not button.IsShown or button:IsShown())
        and (not button.GetWidth or button:GetWidth() > 2)
    local background = NSkin:GetFlatBackground(button)
    if background then background:SetShown(shown) end
    NSkin:SetPixelBorderShown(
        NSkin:GetPixelBorder(button, "NSkinFlatBackgroundBorder"), shown)
    if not shown and data.hoverGlow then data.hoverGlow:Hide() end
    arrow:SetShown(shown)
    if not shown then return end
    local color = data.navigationLeftArrowColor or { 1, 1, 1, 1 }
    local enabled = not button.IsEnabled or button:IsEnabled()
    arrow:SetVertexColor(color[1], color[2], color[3],
        (color[4] or 1) * (enabled and 1 or 0.4))
end

local function GetNavigationLeftButton(navigationBar)
    local button = navigationBar and (
        navigationBar.overflow or navigationBar.Overflow
        or navigationBar.overflowButton or navigationBar.OverflowButton
        or navigationBar.backButton or navigationBar.BackButton)
    if button and button.IsObjectType and button:IsObjectType("Button") then
        return button
    end
    return button and (button.Button or button.button)
end

local function NormalizeNavigationButtonSpacing(navigationBar)
    if not navigationBar then return end
    local home = navigationBar.home or navigationBar.homeButton
    local overflow = navigationBar.overflow or navigationBar.overflowButton
    local changed = false

    -- Blizzard's arrow-shaped navigation art overlaps the following button.
    -- NSkin uses rectangular buttons, so retaining those negative offsets
    -- leaves the home/overflow border inside the next entry.
    if home and home.xoffset ~= 0 then
        home.xoffset = 0
        changed = true
    end
    if overflow and overflow.xoffset ~= 0 then
        overflow.xoffset = 0
        changed = true
    end
    if changed and type(_G.NavBar_CheckLength) == "function" then
        _G.NavBar_CheckLength(navigationBar)
    end
end

function NSkin:SkinNavigationLeftButton(button, style)
    if not button then return false end
    self:SkinActionButton(button, {
        style = {
            background = style.homeBackground,
            border = style.homeBorder,
            text = style.homeText,
            disabledTextAlpha = style.disabledTextAlpha,
            hoverAlpha = style.hoverAlpha,
        },
    })

    local data = self:GetSkinData(button, COMPONENT_STATE)
    if data.label then data.label:SetText("") end
    if not data.navigationLeftArrow then
        local arrow = button:CreateTexture(nil, "OVERLAY", nil, 2)
        arrow:SetSize(14, 14)
        arrow:SetPoint("CENTER", button, "CENTER", 0, 0)
        arrow:SetTexture(self.mediaPath .. "angle-small-down.png")
        self:ConfigureOwnedPixelTexture(arrow)
        data.navigationLeftArrow = arrow
    end
    data.navigationLeftArrow:SetRotation(-math.pi / 2)
    data.navigationLeftArrowColor = style.homeText
    if not data.navigationLeftArrowStateHooked and button.HookScript then
        button:HookScript("OnEnable", RefreshNavigationLeftButton)
        button:HookScript("OnDisable", RefreshNavigationLeftButton)
        button:HookScript("OnShow", RefreshNavigationLeftButton)
        button:HookScript("OnHide", RefreshNavigationLeftButton)
        button:HookScript("OnSizeChanged", RefreshNavigationLeftButton)
        data.navigationLeftArrowStateHooked = true
    end
    RefreshNavigationLeftButton(button)
    return true
end

function NSkin:SkinNavigationBar(navigationBar, style)
    if not navigationBar then return false end
    style = style or self:GetStyle("navigationBar")
    local data = self:GetSkinData(navigationBar, COMPONENT_STATE)
    data.navigationBarStyle = style

    -- Both the bevel and gray edge are baked into Blizzard's tiled regions.
    -- Replace those regions with a borderless NSkin-owned background.
    for _, region in ipairs({ navigationBar:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture")
            and region ~= data.navigationBarBackground
        then
            region:SetAlpha(0)
        end
    end
    if navigationBar.overlay then navigationBar.overlay:SetAlpha(0) end
    if not data.navigationBarBackground then
        local background = navigationBar:CreateTexture(nil, "BACKGROUND", nil, -8)
        background:SetAllPoints(navigationBar)
        self:ConfigureOwnedPixelTexture(background)
        data.navigationBarBackground = background
    end
    data.navigationBarBackground:SetColorTexture(unpack(style.background))

    NormalizeNavigationButtonSpacing(navigationBar)
    self:SkinNavigationLeftButton(
        GetNavigationLeftButton(navigationBar), style)

    local skinnedButtons = setmetatable({}, { __mode = "k" })
    local function SkinNavigationButton(button)
        if not button or skinnedButtons[button] then return end
        skinnedButtons[button] = true
        self:SkinActionButton(button, {
            style = {
                background = style.homeBackground,
                border = style.homeBorder,
                text = style.homeText,
                disabledTextAlpha = style.disabledTextAlpha,
                hoverAlpha = style.hoverAlpha,
            },
        })
        local menuArrow = button.MenuArrowButton
        if menuArrow then
            self:SkinDropdownArrowButton(menuArrow,
                self:GetSharedBorderColor())
            self:HookDropdownMenuSkin(menuArrow, function()
                return {
                    background = style.menuBackground,
                    border = style.menuBorder,
                    textStyle = NSkin:GetStyle("text"),
                }
            end)
        end
    end

    -- The home entry is not guaranteed to be part of navList. Always refresh
    -- it explicitly because Blizzard can restore its tiled artwork while the
    -- breadcrumb list changes.
    SkinNavigationButton(navigationBar.home or navigationBar.homeButton)
    for _, button in ipairs(navigationBar.navList or {}) do
        if button then
            SkinNavigationButton(button)
        end
    end

    if not navigationBarAddButtonHooked and _G.hooksecurefunc
        and type(_G.NavBar_AddButton) == "function"
    then
        _G.hooksecurefunc("NavBar_AddButton", function(bar)
            local barData = NSkin:GetSkinData(bar, COMPONENT_STATE, false)
            if barData and barData.navigationBarStyle then
                NSkin:SkinNavigationBar(bar, barData.navigationBarStyle)
            end
        end)
        navigationBarAddButtonHooked = true
    end
    return true
end

local function RefreshScrollBarArrow(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if data and data.scrollArrow then
        local enabled = not button.IsEnabled or button:IsEnabled()
        data.scrollArrow:SetAlpha(enabled and 1 or 0.35)
    end
end

function NSkin:SkinScrollBar(scrollBar, style)
    if not scrollBar then return end
    style = style or self:GetStyle("scrollBar")
    local trackColor = self:GetResolvedAppearanceColor(style, "track")
    local thumbColor = self:GetResolvedAppearanceColor(style, "thumb")
    local arrowColor = self:GetResolvedAppearanceColor(style, "arrow")
    local track = scrollBar.Track
    local thumb = track and track.Thumb
    local data = self:GetSkinData(scrollBar, COMPONENT_STATE)
    if track then
        for _, texture in ipairs({ track.Begin, track.Middle, track.End }) do
            if texture then texture:SetAlpha(0) end
        end
        if not data.scrollTrack then
            data.scrollTrack = track:CreateTexture(nil, "BACKGROUND", nil, -8)
            data.scrollTrack:SetPoint("TOP", track, "TOP", 0, 0)
            data.scrollTrack:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
            data.scrollTrack:SetWidth(2)
            self:ConfigureOwnedPixelTexture(data.scrollTrack)
        end
        data.scrollTrack:SetColorTexture(unpack(trackColor))
    end
    if thumb then
        for _, texture in ipairs({ thumb.Begin, thumb.Middle, thumb.End }) do
            if texture then texture:SetAlpha(0) end
        end
        if not data.scrollThumb then
            data.scrollThumb = thumb:CreateTexture(nil, "ARTWORK", nil, 7)
            data.scrollThumb:SetPoint("TOP", thumb, "TOP", 0, 0)
            data.scrollThumb:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
            data.scrollThumb:SetWidth(6)
            self:ConfigureOwnedPixelTexture(data.scrollThumb)
        end
        data.scrollThumb:SetColorTexture(unpack(thumbColor))
    end
    for _, entry in ipairs({ { scrollBar.Back, math.pi },
        { scrollBar.Forward, 0 } })
    do
        local button, rotation = entry[1], entry[2]
        if button then
            if button.Texture then button.Texture:SetAlpha(0) end
            local buttonData = self:GetSkinData(button, COMPONENT_STATE)
            if not buttonData.scrollArrow then
                buttonData.scrollArrow = button:CreateTexture(nil, "OVERLAY")
                buttonData.scrollArrow:SetAllPoints(button)
                buttonData.scrollArrow:SetTexture(
                    self.mediaPath .. "angle-small-down.png")
                buttonData.scrollArrow:SetRotation(rotation)
                self:ConfigureOwnedPixelTexture(buttonData.scrollArrow)
            end
            if not buttonData.scrollArrowHooked and button.HookScript then
                button:HookScript("OnEnable", RefreshScrollBarArrow)
                button:HookScript("OnDisable", RefreshScrollBarArrow)
                buttonData.scrollArrowHooked = true
            end
            buttonData.scrollArrow:SetVertexColor(unpack(arrowColor))
            RefreshScrollBarArrow(button)
        end
    end
end

local function RefreshPagingButton(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if data and data.label then
        local enabled = not button.IsEnabled or button:IsEnabled()
        data.label:SetAlpha(enabled and 1 or 0.35)
    end
end

local function SkinPagingButton(button, label, textSize)
    if not button then return end
    NSkin:SkinFlatButton(button, label, nil, nil, textSize)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE)
    if not data.pagingStateHooked and button.HookScript then
        button:HookScript("OnEnable", RefreshPagingButton)
        button:HookScript("OnDisable", RefreshPagingButton)
        data.pagingStateHooked = true
    end
    RefreshPagingButton(button)
end

function NSkin:SkinPagingControls(pagingControls, textSize)
    if not pagingControls then return end

    local previous = pagingControls.PrevPageButton or pagingControls.prevPageButton
    local nextPage = pagingControls.NextPageButton or pagingControls.nextPageButton
    local pageText = pagingControls.PageText or pagingControls.pageText
    SkinPagingButton(previous, "<", textSize)
    SkinPagingButton(nextPage, ">", textSize)
    if pageText then pageText:SetTextColor(unpack(self:GetStyle("button").text)) end
end

-- Windows Skinning

local COMPONENT_INTERNALS = NSkin._componentInternals
local tabGroups = COMPONENT_INTERNALS.tabGroups
local tabGroupOriginalPoints = COMPONENT_INTERNALS.tabGroupOriginalPoints
local skinningElements = COMPONENT_INTERNALS.skinningElements
local SUPPRESS_NOTIFICATION = COMPONENT_INTERNALS.SUPPRESS_NOTIFICATION
local CopyPlacement = COMPONENT_INTERNALS.CopyPlacement
local FireComponentCallback = COMPONENT_INTERNALS.FireComponentCallback
local CaptureFramePoints = COMPONENT_INTERNALS.CaptureFramePoints
local RestoreFramePoints = COMPONENT_INTERNALS.RestoreFramePoints
local GetCurrentWindowPlacement = COMPONENT_INTERNALS.GetCurrentWindowPlacement
local GetSavedMovablePlacement = COMPONENT_INTERNALS.GetSavedMovablePlacement
local ClearSavedMovablePlacement = COMPONENT_INTERNALS.ClearSavedMovablePlacement
local GetControllerState = COMPONENT_INTERNALS.GetControllerState
local PruneControllerState = COMPONENT_INTERNALS.PruneControllerState
local RegisterControllerElement = COMPONENT_INTERNALS.RegisterControllerElement
local function ApplyTabDimensions(tab, style, data)
    local configuredWidth, configuredHeight = tonumber(style.width), tonumber(style.height)
    configuredWidth = configuredWidth and configuredWidth > 0 and configuredWidth or nil
    configuredHeight = configuredHeight and configuredHeight > 0 and configuredHeight or nil
    if configuredWidth or configuredHeight then
        if not data.tabOriginalSize then
            data.tabOriginalSize = { tab:GetWidth(), tab:GetHeight() }
        end
        tab:SetSize(configuredWidth or data.tabOriginalSize[1],
            configuredHeight or data.tabOriginalSize[2])
    elseif data.tabOriginalSize then
        tab:SetSize(data.tabOriginalSize[1], data.tabOriginalSize[2])
        data.tabOriginalSize = nil
    end
end

local function RefreshTabSelection(tab, selected)
    local data = NSkin:GetSkinData(tab, COMPONENT_STATE, false)
    NSkin:SkinTab(tab, selected, data and data.tabStyle, data and data.tabBorderColor)
end

function NSkin:SkinTab(tab, selected, style, borderColor)
    if not tab then return end
    style = style or self:GetStyle("tab")
    local data = self:GetSkinData(tab, COMPONENT_STATE)
    data.tabStyle, data.tabBorderColor = style, borderColor
    ApplyTabDimensions(tab, style, data)

    local background = self:GetFlatBackground(tab)
    if not background then
        if type(tab.SetTabSelected) == "function" and _G.hooksecurefunc then
            _G.hooksecurefunc(tab, "SetTabSelected", RefreshTabSelection)
        end
        self:HideTextureRegions(tab)
        background = self:CreateFlatBackground(tab, nil, style.background,
            borderColor or self:GetResolvedAppearanceColor(style, "border")
                or self:GetComponentBorderColor("tab", style))
    end

    self:CreateFlatButtonGlow(tab, style.hoverAlpha)
    self:SetPixelBorderColor(self:GetPixelBorder(tab, "NSkinFlatBackgroundBorder"),
        unpack(borderColor or self:GetResolvedAppearanceColor(style, "border")
            or self:GetComponentBorderColor("tab", style)))
    local tabBorder = self:GetPixelBorder(tab, "NSkinFlatBackgroundBorder")
    self:SetPixelBorderSize(tabBorder, style.borderSize or 1)
    self:SetPixelBorderPadding(tabBorder, style.borderPadding or 0)
    background:SetColorTexture(unpack(
        selected and self:GetResolvedAppearanceColor(style, "selectedBackground")
            or self:GetResolvedAppearanceColor(style, "background")
    ))
    if tab.Text then
        tab.Text:SetTextColor(unpack(self:GetResolvedAppearanceColor(style, "text")))
        self:ApplyResolvedTypography(tab.Text, style)
    end
end

local SIDE_TAB_BORDER_KEY = "NSkinSideTabBorder"

local function CenterSideTabIcon(tab)
    local icon = tab and tab.Icon
    if not icon then return end
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", tab, "CENTER", 0, 0)
end

local function SuppressSideTabArtwork(tab)
    if tab.Background then tab.Background:SetAlpha(0) end
    if tab.SelectedTexture then tab.SelectedTexture:SetAlpha(0) end
    if tab.HighlightTexture then tab.HighlightTexture:SetAlpha(0) end
    if tab.TabGlow then
        tab.TabGlow:SetAlpha(0)
        tab.TabGlow:Hide()
    end
end

local function CaptureSideTabArtwork(tab, data)
    if data.sideTabArtworkBaseline then return end
    data.sideTabArtworkBaseline = {}
    for _, key in ipairs({ "Background", "SelectedTexture",
        "HighlightTexture", "TabGlow" }) do
        local region = tab[key]
        if region then
            data.sideTabArtworkBaseline[#data.sideTabArtworkBaseline + 1] = {
                region = region,
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = region.IsShown and region:IsShown() or true,
            }
        end
    end
end

function NSkin:RestoreSideTabOriginalState(tab, baselineID)
    local data = tab and self:GetSkinData(tab, COMPONENT_STATE, false)
    if not tab or not data then return false end
    local restored = self:RestoreComponentBaseline(
        baselineID or data.sideTabBaselineID)
    if tab.Icon and data.sideTabOriginalIconPoints then
        RestoreFramePoints(tab.Icon, data.sideTabOriginalIconPoints)
        restored = true
    end
    for _, state in ipairs(data.sideTabArtworkBaseline or {}) do
        if state.region.SetAlpha then state.region:SetAlpha(state.alpha) end
        if state.region.SetShown then state.region:SetShown(state.shown) end
    end
    if data.sideTabBackground then data.sideTabBackground:Hide() end
    if data.hoverGlow then data.hoverGlow:Hide() end
    self:SetPixelBorderShown(
        self:GetPixelBorder(tab, SIDE_TAB_BORDER_KEY), false)
    return restored == true
end

function NSkin:SkinSideTab(tab, style, borderColor)
    if not tab or not tab.CreateTexture then return false end
    style = style or self:GetStyle("sideTab")
    if not style then return false end
    local data = self:GetSkinData(tab, COMPONENT_STATE)
    if not data.sideTabBaselineID then
        data.sideTabBaselineID = "SideTab:" .. tostring(tab)
        self:CaptureComponentBaseline(data.sideTabBaselineID, tab, {
            size = true,
            points = true,
        })
    end
    local baseline = self:GetComponentBaseline(data.sideTabBaselineID)
    local width, height = tonumber(style.width), tonumber(style.height)
    width = width and width > 0 and width or nil
    height = height and height > 0 and height or nil
    if width or height then
        self:MarkComponentGeometryModified(
            data.sideTabBaselineID, "size", true)
        tab:SetSize(width or (baseline and baseline.width) or tab:GetWidth(),
            height or (baseline and baseline.height) or tab:GetHeight())
    elseif baseline and baseline.modified.size then
        self:RestoreComponentBaseline(data.sideTabBaselineID, { size = true })
    end

    if tab.Icon and not data.sideTabOriginalIconPoints then
        data.sideTabOriginalIconPoints = CaptureFramePoints(tab.Icon)
    end
    CaptureSideTabArtwork(tab, data)
    CenterSideTabIcon(tab)
    SuppressSideTabArtwork(tab)

    if not data.sideTabBackground then
        local background = tab:CreateTexture(nil, "BACKGROUND", nil, 7)
        background:SetAllPoints(tab)
        self:ConfigureOwnedPixelTexture(background)
        data.sideTabBackground = background
    end
    data.sideTabBackground:SetColorTexture(unpack(
        self:GetResolvedAppearanceColor(style, "background")))
    data.sideTabBackground:Show()

    local resolvedBorder = borderColor
        or self:GetResolvedAppearanceColor(style, "border")
        or self:GetComponentBorderColor("sideTab", style)
    local border = self:GetPixelBorder(tab, SIDE_TAB_BORDER_KEY)
        or self:CreatePixelEdgeBorder(tab, SIDE_TAB_BORDER_KEY,
            { "top", "right", "bottom" }, 1, resolvedBorder, tab)
    self:SetPixelBorderColor(border, unpack(resolvedBorder))
    self:SetPixelBorderSize(border, 1)
    self:SetPixelBorderPadding(border, 0)
    self:SetPixelBorderShown(border, true)

    local glow = self:CreateFlatButtonGlow(tab, style.hoverAlpha)
    if glow then glow:SetColorTexture(1, 1, 1, style.hoverAlpha or 0.10) end
    if not data.sideTabInteractionHooked and tab.HookScript then
        tab:HookScript("OnMouseDown", CenterSideTabIcon)
        tab:HookScript("OnMouseUp", CenterSideTabIcon)
        tab:HookScript("OnShow", function(shownTab)
            local shownData = NSkin:GetSkinData(
                shownTab, COMPONENT_STATE, false)
            local shownStyle = shownData and shownData.sideTabStyle
            if shownStyle then
                NSkin:SkinSideTab(shownTab, shownStyle,
                    shownData.sideTabBorderColor)
            end
        end)
        data.sideTabInteractionHooked = true
    end
    data.sideTabStyle = style
    data.sideTabBorderColor = resolvedBorder
    return true
end

function NSkin:LayoutTabGroup(tabs, options)
    if type(tabs) ~= "table" then return end
    options = options or {}

    local spacing = tonumber(options.spacing) or self:GetTabSpacing() or 0
    local vertical = options.orientation == "VERTICAL"
    local anchor = options.anchor
    local anchorPoint = anchor and anchor.point
    local anchorRelativeTo = anchor and anchor.relativeTo
    local anchorRelativePoint = anchor and anchor.relativePoint
    local anchorX = anchor and anchor.x or 0
    local anchorY = anchor and anchor.y or 0
    local owner = options.owner
    local edge = options.edge
    local previous

    if owner and not vertical and (edge == "BOTTOM" or edge == "TOP") then
        local layout = options.placement or self:GetStyle("tab").bottom or {}
        if layout.mode == "GRID" then
            anchorPoint = layout.point or "TOPLEFT"
            anchorRelativeTo = owner
            anchorRelativePoint = layout.relativePoint or "TOPLEFT"
            anchorX = tonumber(layout.x) or 0
            anchorY = tonumber(layout.y) or 0
        else
        edge = layout.edge or edge
        local side = layout.side or "OUTSIDE"
        local visibleCount = 0
        local totalWidth = 0
        for i = 1, #tabs do
            local tab = tabs[i]
            if tab and (not tab.IsShown or tab:IsShown()) then
                visibleCount = visibleCount + 1
                totalWidth = totalWidth + (tab.GetWidth and tab:GetWidth() or 0)
            end
        end
        totalWidth = totalWidth + math.max(0, visibleCount - 1) * spacing
        local relativePoint = edge .. "LEFT"
        local alignment = layout.alignment or layout.anchor
        local startX = layout.alongOffset or layout.offsetX or 0
        if alignment == "CENTER" then
            relativePoint = edge
            startX = startX - totalWidth / 2
        elseif alignment == "RIGHT" then
            relativePoint = edge .. "RIGHT"
            startX = startX - totalWidth
        end
        if edge == "TOP" then
            anchorPoint = side == "INSIDE" and "TOPLEFT" or "BOTTOMLEFT"
        else
            anchorPoint = side == "INSIDE" and "BOTTOMLEFT" or "TOPLEFT"
        end
        anchorRelativeTo = owner
        anchorRelativePoint = relativePoint
        anchorX = startX
        anchorY = layout.edgeOffset or layout.offsetY or 0
        end
    end

    for i = 1, #tabs do
        local tab = tabs[i]
        local usable = tab
            and (not tab.IsShown or tab:IsShown())
            and tab.ClearAllPoints and tab.SetPoint
            and not (tab.IsForbidden and tab:IsForbidden())
            and not (tab.IsProtected and tab:IsProtected())
        if usable then
            if not previous then
                if anchorPoint then
                    tab:ClearAllPoints()
                    tab:SetPoint(anchorPoint, anchorRelativeTo,
                        anchorRelativePoint, anchorX, anchorY)
                end
            else
                tab:ClearAllPoints()
                if vertical then
                    tab:SetPoint("TOP", previous, "BOTTOM", 0, -spacing)
                else
                    tab:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
                end
            end
            previous = tab
        end
    end
    return previous ~= nil
end

function NSkin:LayoutTabSystem(tabSystem, options)
    if not tabSystem or type(tabSystem.tabs) ~= "table"
        or not tabSystem.MarkDirty
        or (tabSystem.IsForbidden and tabSystem:IsForbidden())
        or (tabSystem.IsProtected and tabSystem:IsProtected())
    then
        return
    end

    tabSystem.spacing = tonumber(options and options.spacing)
        or self:GetTabSpacing() or tabSystem.spacing or 0
    tabSystem:MarkDirty()

    if options and options.owner
        and (options.edge == "BOTTOM" or options.edge == "TOP")
    then
        local layout = options.placement or self:GetStyle("tab").bottom or {}
        if layout.mode == "GRID" then
            tabSystem:ClearAllPoints()
            tabSystem:SetPoint(layout.point or "TOPLEFT", options.owner,
                layout.relativePoint or "TOPLEFT", tonumber(layout.x) or 0,
                tonumber(layout.y) or 0)
            return true
        end
        local relativeElement = layout.relativeTo and skinningElements[layout.relativeTo]
        if relativeElement and relativeElement.snapTarget
            and relativeElement.window == options.owner and relativeElement.target
            and (not relativeElement.target.IsShown or relativeElement.target:IsShown())
        then
            tabSystem:ClearAllPoints()
            tabSystem:SetPoint(layout.point, relativeElement.target, layout.relativePoint,
                tonumber(layout.offsetX) or 0, tonumber(layout.offsetY) or 0)
            return true
        end
        local edge = layout.edge or options.edge
        local side = layout.side or "OUTSIDE"
        local alignment = layout.alignment or layout.anchor
        local alongOffset = layout.alongOffset or layout.offsetX or 0
        local edgeOffset = layout.edgeOffset or layout.offsetY or 0
        local point
        if edge == "TOP" then
            point = side == "INSIDE" and "TOPLEFT" or "BOTTOMLEFT"
        else
            point = side == "INSIDE" and "BOTTOMLEFT" or "TOPLEFT"
        end
        local relativePoint = edge .. "LEFT"
        if alignment == "CENTER" then
            point = point:gsub("LEFT", "")
            relativePoint = edge
        elseif alignment == "RIGHT" then
            point = point:gsub("LEFT", "RIGHT")
            relativePoint = edge .. "RIGHT"
        end
        tabSystem:ClearAllPoints()
        tabSystem:SetPoint(point, options.owner, relativePoint,
            alongOffset, edgeOffset)
    end
    return true
end

function NSkin:SkinTabSystem(tabSystem, style, borderColor)
    if not tabSystem or not tabSystem.tabs then return end
    style = style or self:GetStyle("tab")

    for i = 1, #tabSystem.tabs do
        local tab = tabSystem.tabs[i]
        local selected = tab and tab.IsSelected and tab:IsSelected()
        self:SkinTab(tab, selected, style, borderColor)
    end
end

local function RefreshTabGroupAppearance(group)
    local tabs = group.container and group.container.tabs or group.tabs
    local style = NSkin:GetAppearanceStyle(
        "tab", group.appearanceWindowID, group.id)
    local borderColor = NSkin:GetAppearanceBorderColor(
        "tab", style, group.appearanceWindowID, group.id)
    for i = 1, #(tabs or {}) do
        local tab = tabs[i]
        if tab then
            local selected = tab.IsSelected and tab:IsSelected()
            NSkin:SkinTab(tab, selected, style, borderColor)
        end
    end
    NSkin:ResnapPixelBordersForElement(group)
    return true
end

function NSkin:RegisterTabGroup(groupID, definition)
    if type(groupID) ~= "string" or groupID == ""
        or type(definition) ~= "table"
        or type(definition.appearanceWindowID) ~= "string"
        or not self:GetAppearanceScope(definition.appearanceWindowID)
        or not (definition.window or definition.owner)
        or definition.orientation ~= "HORIZONTAL"
        or (definition.edge ~= "BOTTOM" and definition.edge ~= "TOP")
        or (not definition.container and type(definition.tabs) ~= "table")
    then
        return false
    end

    if not tabGroupOriginalPoints[groupID] then
        local originals = {}
        local targets = definition.container and { definition.container }
            or definition.tabs
        for i = 1, #(targets or {}) do
            local target = targets[i]
            local points = {}
            if target and target.GetNumPoints then
                for pointIndex = 1, target:GetNumPoints() do
                    points[pointIndex] = { target:GetPoint(pointIndex) }
                end
            end
            originals[i] = { target = target, points = points }
        end
        tabGroupOriginalPoints[groupID] = originals
    end

    if definition.originalSpacing == nil then
        if definition.container and tonumber(definition.container.spacing) then
            definition.originalSpacing = tonumber(definition.container.spacing)
        elseif type(definition.tabs) == "table" and #definition.tabs > 1 then
            local first, second = definition.tabs[1], definition.tabs[2]
            local firstRight = first and first.GetRight and first:GetRight()
            local secondLeft = second and second.GetLeft and second:GetLeft()
            if firstRight and secondLeft then
                definition.originalSpacing = secondLeft - firstRight
            end
        end
    end

    definition.kind = "TAB_GROUP"
    definition.editorOptions = self:CreateEditorOptionsPreset(
        "TAB_GROUP", definition.extraEditorOptions)

    local group = tabGroups[groupID]
    if group then
        for key, value in pairs(definition) do group[key] = value end
    else
        group = definition
        group.id = groupID
        tabGroups[groupID] = group
    end
    group.pixelBorderTargets = function()
        return group.container and group.container.tabs or group.tabs
    end
    group.refreshAppearance = function()
        return RefreshTabGroupAppearance(group)
    end
    group.refreshLayout = function()
        RefreshTabGroupAppearance(group)
        local applied = NSkin:ApplyTabGroupLayout(group.id)
        NSkin:NotifySkinningElementBoundsChanged(group.id)
        return applied
    end
    self:RefreshTabGroupBaseline(groupID, true)
    if type(group.applyPlacement) ~= "function" then
        group.applyPlacement = function(element, placement, applyOptions)
            return NSkin:ApplyTabGroupPlacement(element, placement, applyOptions)
        end
    end
    if type(group.module) == "string" and not group.getPlacement then
        group.hasPlacement = function(element)
            local moduleOptions = NSkin:GetModuleOptions(element.module, false)
            return moduleOptions and moduleOptions.tabPlacements
                and moduleOptions.tabPlacements[element.id] ~= nil
        end
        group.getPlacement = function(element)
            local moduleOptions = NSkin:GetModuleOptions(element.module, false)
            local saved = moduleOptions and moduleOptions.tabPlacements
                and moduleOptions.tabPlacements[element.id]
            if saved then return CopyPlacement(saved) end
            local originals = tabGroupOriginalPoints[element.id]
            local target = originals and originals[1] and originals[1].target
            if target then return GetCurrentWindowPlacement(element.window, target) end
            return CopyPlacement(NSkin:GetTabPlacement())
        end
        group.setPlacement = function(element, placement)
            if not NSkin:ApplyTabGroupPlacement(element, placement,
                { suppressNotify = true })
            then
                return false
            end
            local moduleOptions = NSkin:GetModuleOptions(element.module, true)
            moduleOptions.tabPlacements = moduleOptions.tabPlacements or {}
            moduleOptions.tabPlacements[element.id] = CopyPlacement(placement)
            FireComponentCallback("TabGroupLayoutApplied", element)
            return true
        end
        group.resetPlacement = function(element)
            NSkin:RestoreTabGroupOriginalPlacement(element.id)
            local moduleOptions = NSkin:GetModuleOptions(element.module, false)
            if moduleOptions and moduleOptions.tabPlacements then
                moduleOptions.tabPlacements[element.id] = nil
                if not next(moduleOptions.tabPlacements) then
                    moduleOptions.tabPlacements = nil
                end
                if not next(moduleOptions) then
                    local profile = NSkin:GetProfile()
                    if profile.moduleOptions then
                        profile.moduleOptions[element.module] = nil
                        if not next(profile.moduleOptions) then
                            profile.moduleOptions = nil
                        end
                    end
                end
            end
            FireComponentCallback("TabGroupLayoutApplied", element)
            return true
        end
    end

    self:RegisterSkinningElement(groupID, group)
    return true
end

function NSkin:RefreshTabGroupBaseline(groupID, force)
    local group = tabGroups[groupID]
    if not group then return false end
    if type(group.canCaptureBaseline) == "function"
        and group.canCaptureBaseline(group) ~= true
    then return false end
    if force then
        for i = 1, #(group.tabBaselineIDs or {}) do
            local baseline = self:GetComponentBaseline(group.tabBaselineIDs[i])
            if baseline and next(baseline.modified) then return false end
        end
        local groupBaseline = self:GetComponentBaseline(group.groupBaselineID)
        if groupBaseline and next(groupBaseline.modified) then return false end
    end
    group.tabBaselineIDs = group.tabBaselineIDs or {}
    local tabs = group.container and group.container.tabs or group.tabs
    for i = 1, #(tabs or {}) do
        local tab = tabs[i]
        if tab then
            local id = groupID .. ":tab:" .. i
            group.tabBaselineIDs[i] = id
            self:CaptureComponentBaseline(id, tab, {
                size = true, points = true, force = force == true,
            })
        end
    end
    local groupTarget = group.container or (tabs and tabs[1])
    if groupTarget then
        group.groupBaselineID = groupID .. ":group"
        self:CaptureComponentBaseline(group.groupBaselineID, groupTarget, {
            points = group.container ~= nil,
            spacing = group.container or false,
            force = force == true,
        })
        local baseline = self:GetComponentBaseline(group.groupBaselineID)
        if baseline and baseline.spacing ~= nil then
            group.originalSpacing = baseline.spacing
        end
    end
    return true
end

function NSkin:RegisterSideTab(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string"
        or not definition.target
    then return nil end
    local id = definition.id
    self:CaptureComponentBaseline(id, definition.target, {
        points = true,
        size = true,
    })
    local data = self:GetSkinData(definition.target, COMPONENT_STATE)
    data.sideTabBaselineID = id
    local style = self:GetAppearanceStyle(
        "sideTab", definition.appearanceWindowID, id)
    local borderColor = self:GetAppearanceBorderColor(
        "sideTab", style, definition.appearanceWindowID, id)
    self:SkinSideTab(definition.target, style, borderColor)

    definition.kind = "SIDE_TAB"
    definition.refreshAppearance = function(_, element)
        local appearance = NSkin:GetAppearanceStyle(
            "sideTab", element.appearanceWindowID, element.id)
        local color = NSkin:GetAppearanceBorderColor(
            "sideTab", appearance, element.appearanceWindowID, element.id)
        NSkin:SkinSideTab(element.target, appearance, color)
        NSkin:ResnapPixelBordersForElement(element)
        return true
    end
    definition.refreshLayout = function(owner, element)
        if not definition.refreshAppearance(owner, element) then return false end
        local saved = GetSavedMovablePlacement(element)
        if saved and element.applyPlacement then
            element.applyPlacement(element, saved, SUPPRESS_NOTIFICATION)
        end
        NSkin:NotifySkinningElementBoundsChanged(element.id)
        return true
    end
    definition.supportsResize = true
    definition.restoreGeometry = definition.restoreGeometry or function(element)
        return NSkin:RestoreSideTabOriginalState(element.target, element.id)
    end
    definition.defaultPlacement = definition.defaultPlacement
        or GetCurrentWindowPlacement(definition.window, definition.target)
    if not definition.resetPlacement then
        definition.resetPlacement = function(element)
            local restored
            if element.defaultPlacement then
                restored = element.applyPlacement(element,
                    CopyPlacement(element.defaultPlacement), SUPPRESS_NOTIFICATION)
            else
                restored = NSkin:RestoreMovableElementOriginal(element, true)
            end
            if not restored then return false end
            ClearSavedMovablePlacement(element)
            NSkin:MarkComponentGeometryModified(element.id, "points", false)
            NSkin:NotifySkinningElementBoundsChanged(element.id)
            return true
        end
    end

    local element = self:RegisterSimpleMovableElement(definition)
    if element and not GetSavedMovablePlacement(element)
        and element.defaultPlacement
    then
        element.applyPlacement(element,
            CopyPlacement(element.defaultPlacement), SUPPRESS_NOTIFICATION)
    end
    return element
end

function NSkin:RegisterSideTabGroup(groupID, definition)
    if type(groupID) ~= "string" or groupID == ""
        or type(definition) ~= "table"
        or type(definition.targets) ~= "table"
        or #definition.targets == 0
        or not definition.window
    then return nil end

    local targets = definition.targets
    local primary = targets[1]
    if not primary then return nil end

    local baselineIDs = {}
    local style = self:GetAppearanceStyle(
        "sideTab", definition.appearanceWindowID, groupID)
    local borderColor = self:GetAppearanceBorderColor(
        "sideTab", style, definition.appearanceWindowID, groupID)
    for i = 1, #targets do
        local tab = targets[i]
        if tab then
            local baselineID = groupID .. ":tab:" .. i
            baselineIDs[i] = baselineID
            self:CaptureComponentBaseline(baselineID, tab, {
                points = true,
                size = true,
            })
            local data = self:GetSkinData(tab, COMPONENT_STATE)
            data.sideTabBaselineID = baselineID
            self:SkinSideTab(tab, style, borderColor)
        end
    end

    definition.id = groupID
    definition.target = primary
    definition.kind = "SIDE_TAB"
    definition.pixelBorderTargets = targets
    definition.refreshAppearance = function()
        local appearance = self:GetAppearanceStyle(
            "sideTab", definition.appearanceWindowID, groupID)
        local color = self:GetAppearanceBorderColor(
            "sideTab", appearance, definition.appearanceWindowID, groupID)
        for i = 1, #targets do self:SkinSideTab(targets[i], appearance, color) end
        self:ResnapPixelBordersForElement(definition)
        return true
    end
    definition.refreshLayout = function(owner, element)
        if not definition.refreshAppearance(owner, element) then return false end
        local saved = GetSavedMovablePlacement(element)
        if saved and element.applyPlacement then
            element.applyPlacement(element, saved, SUPPRESS_NOTIFICATION)
        end
        self:NotifySkinningElementBoundsChanged(element.id)
        return true
    end
    definition.highlightRegions = definition.highlightRegions or targets
    definition.defaultPlacement = definition.defaultPlacement
        or GetCurrentWindowPlacement(definition.window, primary)

    definition.applyPlacement = function(element, placement, applyOptions)
        local window = element.window
        if not window or not window.GetLeft or not window.GetTop then return false end

        for i = 1, #targets do
            self:RestoreComponentBaseline(baselineIDs[i], { points = true })
        end
        local windowLeft, windowTop = window:GetLeft(), window:GetTop()
        local primaryLeft, primaryTop = primary:GetLeft(), primary:GetTop()
        if not windowLeft or not windowTop or not primaryLeft or not primaryTop then
            return false
        end

        local originalPositions = {}
        for i = 1, #targets do
            local tab = targets[i]
            local left, top = tab:GetLeft(), tab:GetTop()
            if not left or not top then return false end
            originalPositions[i] = {
                x = left - windowLeft,
                y = top - windowTop,
            }
        end

        if not self:LayoutWindowElement({
            id = element.id,
            window = window,
            target = primary,
        }, placement, SUPPRESS_NOTIFICATION) then
            return false
        end
        local desiredLeft, desiredTop = primary:GetLeft(), primary:GetTop()
        if not desiredLeft or not desiredTop then return false end
        local deltaX = desiredLeft - primaryLeft
        local deltaY = desiredTop - primaryTop

        for i = 1, #targets do
            local tab = targets[i]
            tab:ClearAllPoints()
            tab:SetPoint("TOPLEFT", window, "TOPLEFT",
                originalPositions[i].x + deltaX,
                originalPositions[i].y + deltaY)
            self:MarkComponentGeometryModified(
                baselineIDs[i], "points", true)
        end
        if not (applyOptions and applyOptions.suppressNotify) then
            self:NotifySkinningElementBoundsChanged(element.id)
        end
        return true
    end

    definition.restoreGeometry = function()
        local restored = true
        for i = 1, #targets do
            restored = self:RestoreComponentBaseline(
                baselineIDs[i], { points = true }) and restored
        end
        return restored
    end
    definition.resetPlacement = function(element)
        if not definition.restoreGeometry() then return false end
        ClearSavedMovablePlacement(element)
        self:MarkComponentGeometryModified(element.id, "points", false)
        self:NotifySkinningElementBoundsChanged(element.id)
        return true
    end

    return self:RegisterSimpleMovableElement(definition)
end

function NSkin:RegisterNavigationBar(elementID, definition)
    if type(elementID) ~= "string" or type(definition) ~= "table"
        or not definition.target
    then return nil end
    definition.id = elementID
    definition.kind = "NAVIGATION_BAR"
    definition.refreshAppearance = function(_, element)
        NSkin:SkinNavigationBar(element.target, NSkin:GetAppearanceStyle(
            "navigationBar", element.appearanceWindowID, element.id))
        NSkin:ResnapPixelBordersForElement(element)
        return true
    end
    definition.refreshLayout = function(owner, element)
        if not definition.refreshAppearance(owner, element) then return false end
        local saved = GetSavedMovablePlacement(element)
        if saved and element.applyPlacement then
            element.applyPlacement(element, saved, SUPPRESS_NOTIFICATION)
        end
        NSkin:NotifySkinningElementBoundsChanged(element.id)
        return true
    end
    local style = self:GetAppearanceStyle("navigationBar",
        definition.appearanceWindowID, elementID)
    self:SkinNavigationBar(definition.target, style)

    local data = self:GetSkinData(definition.target, COMPONENT_STATE)
    if not data.navigationBarShowHooked and definition.target.HookScript then
        definition.target:HookScript("OnShow", function(bar)
            NSkin:SkinNavigationBar(bar, NSkin:GetAppearanceStyle(
                "navigationBar", definition.appearanceWindowID, elementID))
        end)
        data.navigationBarShowHooked = true
    end
    return self:RegisterSimpleMovableElement(definition)
end

function NSkin:RegisterPaginationGroup(definition)
    if type(definition) ~= "table" or type(definition.module) ~= "string"
        or type(definition.appearanceWindowID) ~= "string"
        or definition.appearanceWindowID == ""
        or not self:GetAppearanceScope(definition.appearanceWindowID)
        or not definition.window or type(definition.ids) ~= "table"
        or type(definition.controls) ~= "table"
    then return end
    local ids, controls = definition.ids, definition.controls
    if not ids.group or not ids.previous or not ids.next or not ids.text
        or not controls.group or not controls.previous or not controls.next
        or not controls.text
    then return end
    local controller = { module = definition.module,
        appearanceWindowID = definition.appearanceWindowID,
        window = definition.window,
        visibilityFrame = definition.visibilityFrame,
        id = definition.id or ids.group, ids = ids, controls = controls }
    local legacySeparateKey = definition.legacySeparateOptionKey
    local legacyTextKey = definition.legacyTextOptionKey

    function controller:GetSeparateButtons()
        local state, options = GetControllerState(self.module, self.id, false)
        if state and state.separateButtons ~= nil then return state.separateButtons == true end
        return legacySeparateKey and options and options[legacySeparateKey] == true or false
    end
    function controller:GetTextMode()
        local state, options = GetControllerState(self.module, self.id, false)
        local mode = state and state.textMode
        if not mode and legacyTextKey and options then mode = options[legacyTextKey] end
        mode = mode or "GROUPED"
        return mode == "GROUPED" and self:GetSeparateButtons() and "INDEPENDENT" or mode
    end
    function controller:IsVisible()
        local target = self.visibilityFrame or self.controls.group
        return not target or not target.IsVisible or target:IsVisible()
    end
    function controller:NotifyBounds()
        NSkin:NotifySkinningElementBoundsChanged(self.ids.group)
        NSkin:NotifySkinningElementBoundsChanged(self.ids.previous)
        NSkin:NotifySkinningElementBoundsChanged(self.ids.next)
        NSkin:NotifySkinningElementBoundsChanged(self.ids.text)
    end
    function controller:Refresh()
        self.controls.text:SetShown(self:GetTextMode() ~= "HIDDEN")
        local function ApplyMode(id, independent)
            local element = skinningElements[id]
            if not element then return end
            local saved = GetSavedMovablePlacement(element)
            if independent and saved then
                element.applyPlacement(element, saved, SUPPRESS_NOTIFICATION)
            elseif not independent then
                NSkin:RestoreMovableElementOriginal(element, true)
            end
        end
        local separate = self:GetSeparateButtons()
        ApplyMode(self.ids.previous, separate)
        ApplyMode(self.ids.next, separate)
        ApplyMode(self.ids.text, self:GetTextMode() == "INDEPENDENT")
        self:NotifyBounds()
    end
    function controller:UpdateWatcher()
        local state, options = GetControllerState(self.module, self.id, false)
        local active = state and next(state) ~= nil
        if not active and options then
            active = (legacySeparateKey and options[legacySeparateKey])
                or (legacyTextKey and options[legacyTextKey])
        end
        if active and not self.watcher then
            self.watcher = CreateFrame("Frame", nil,
                definition.visibilityFrame or self.controls.group)
            self.watcher:Hide()
            self.watcher:SetScript("OnShow", function() self:Refresh() end)
        end
        if self.watcher then self.watcher:SetShown(not not active) end
    end
    function controller:SetSeparateButtons(value)
        local textMode = value == true and "INDEPENDENT" or self:GetTextMode()
        local state, options = GetControllerState(self.module, self.id, true)
        state.separateButtons = value == true and true or nil
        state.textMode = textMode == "GROUPED" and nil or textMode
        if legacySeparateKey then options[legacySeparateKey] = nil end
        if legacyTextKey then options[legacyTextKey] = nil end
        PruneControllerState(self.module, options, self.id)
        self:UpdateWatcher()
        self:Refresh()
        return true
    end
    function controller:SetTextMode(mode)
        if mode ~= "GROUPED" and mode ~= "INDEPENDENT" and mode ~= "HIDDEN"
            or (mode == "GROUPED" and self:GetSeparateButtons())
        then return false end
        local state, options = GetControllerState(self.module, self.id, true)
        state.textMode = mode == "GROUPED" and nil or mode
        if legacyTextKey then options[legacyTextKey] = nil end
        PruneControllerState(self.module, options, self.id)
        self:UpdateWatcher()
        self:Refresh()
        return true
    end

    local elementDefinitions = definition.elements or {}
    local groupDefinition = elementDefinitions.group or {}
    local previousDefinition = elementDefinitions.previous or {}
    local nextDefinition = elementDefinitions.next or {}
    local textDefinition = elementDefinitions.text or {}
    controller.groupedRegions = { controls.previous, controls.next }
    controller.groupedRegionsWithText = { controls.previous, controls.text, controls.next }
    local groupEditorOptions = NSkin:CreateEditorOptionsPreset(
        "PAGINATION_GROUP", definition.extraEditorOptions)
    local defaultPlacement = definition.defaultPlacement
    local group = RegisterControllerElement(controller, ids.group,
        definition.groupLabel or "Pagination", controls.group, {
            kind = "PAGINATION_GROUP",
            editorOptions = groupEditorOptions,
            defaultPlacement = groupDefinition.defaultPlacement or defaultPlacement,
            priority = groupDefinition.priority or definition.groupPriority or 70,
            anchorHighlight = groupDefinition.anchorHighlight or definition.anchorHighlight,
            highlightRegions = function()
                return controller:GetTextMode() == "GROUPED"
                    and controller.groupedRegionsWithText or controller.groupedRegions
            end,
            applyPlacement = groupDefinition.applyPlacement,
            livePreview = groupDefinition.livePreview,
            draggable = groupDefinition.draggable,
            isEditable = function()
                return controller:IsVisible() and not controller:GetSeparateButtons()
            end,
        })
    local previous = RegisterControllerElement(controller, ids.previous,
        definition.previousLabel or "Previous page button", controls.previous, {
            kind = "PAGINATION_CHILD",
            editorOptions = NSkin:CreateEditorOptionsPreset(
                "PAGINATION_CHILD", definition.childExtraEditorOptions),
            defaultPlacement = previousDefinition.defaultPlacement
                or definition.previousPlacement or defaultPlacement,
            priority = previousDefinition.priority or definition.buttonPriority or 90,
            isEditable = function()
                return controller:IsVisible()
            end,
            applyPlacement = previousDefinition.applyPlacement,
            livePreview = previousDefinition.livePreview,
            draggable = previousDefinition.draggable,
        })
    local nextPage = RegisterControllerElement(controller, ids.next,
        definition.nextLabel or "Next page button", controls.next, {
            kind = "PAGINATION_CHILD",
            editorOptions = NSkin:CreateEditorOptionsPreset(
                "PAGINATION_CHILD", definition.childExtraEditorOptions),
            defaultPlacement = nextDefinition.defaultPlacement
                or definition.nextPlacement or defaultPlacement,
            priority = nextDefinition.priority or definition.buttonPriority or 90,
            isEditable = function()
                return controller:IsVisible()
            end,
            applyPlacement = nextDefinition.applyPlacement,
            livePreview = nextDefinition.livePreview,
            draggable = nextDefinition.draggable,
        })
    local text = RegisterControllerElement(controller, ids.text,
        definition.textLabel or "Page text", controls.text, {
            kind = "PAGINATION_CHILD",
            editorOptions = NSkin:CreateEditorOptionsPreset(
                "PAGINATION_CHILD", definition.childExtraEditorOptions),
            defaultPlacement = textDefinition.defaultPlacement
                or definition.textPlacement or defaultPlacement,
            priority = textDefinition.priority or definition.textPriority or 100,
            isEditable = function()
                return controller:IsVisible()
                    and controller:GetTextMode() == "INDEPENDENT"
            end,
            applyPlacement = textDefinition.applyPlacement,
            livePreview = textDefinition.livePreview,
            draggable = textDefinition.draggable,
        })
    for _, element in ipairs({ group, previous, nextPage, text }) do
        if element then
            element.refreshAppearance = function(_, current)
                return NSkin:RefreshTypedElementAppearance(current)
            end
            element.refreshLayout = function(_, current)
                if not NSkin:RefreshTypedElementLayout(current) then return false end
                controller:Refresh()
                return true
            end
            element.getPaginationSeparateButtons = function() return controller:GetSeparateButtons() end
            element.setPaginationSeparateButtons = function(_, value)
                return controller:SetSeparateButtons(value)
            end
            element.getPaginationTextMode = function() return controller:GetTextMode() end
            element.setPaginationTextMode = function(_, mode)
                return controller:SetTextMode(mode)
            end
        end
    end
    for _, buttonElement in ipairs({ previous, nextPage }) do
        if buttonElement then
            local setPlacement = buttonElement.setPlacement
            buttonElement.setPlacement = function(element, placement)
                if not controller:GetSeparateButtons() then
                    controller:SetSeparateButtons(true)
                end
                return setPlacement(element, placement)
            end
        end
    end
    controller:UpdateWatcher()
    controller:Refresh()
    return controller
end

function NSkin:GetTabGroup(groupID)
    return tabGroups[groupID]
end

function NSkin:GetTabGroupPlacement(groupID)
    local group = tabGroups[groupID]
    if group and type(group.getPlacement) == "function" then
        return group.getPlacement(group)
    end
    return nil
end

function NSkin:SetTabGroupPlacement(groupID, placement)
    local group = tabGroups[groupID]
    if placement and placement.relativeTo
        and self:WouldCreateSkinningPlacementCycle(groupID, placement.relativeTo)
    then return false end
    if not group then return self:SetTabPlacement(placement) end
    if type(group.setPlacement) == "function" then
        return group.setPlacement(group, placement) == true
    end
    return self:SetTabPlacement(placement)
end

function NSkin:ResetTabGroupPlacement(groupID)
    local group = tabGroups[groupID]
    if not group then return self:ResetTabLayout() end
    if type(group.resetPlacement) == "function" then
        return group.resetPlacement(group) == true
    end
    return self:ResetTabLayout()
end

function NSkin:ForEachRegisteredTabGroup(callback)
    if type(callback) ~= "function" then return end
    for _, group in pairs(tabGroups) do callback(group) end
end

local function RestoreTabDimensions(group)
    local tabs = group and group.container and group.container.tabs
        or group and group.tabs
    if type(tabs) ~= "table" then return false end
    local restored = false
    for i = 1, #tabs do
        local tab = tabs[i]
        if tab then
            local baselineID = group.tabBaselineIDs and group.tabBaselineIDs[i]
            if baselineID and NSkin:RestoreComponentBaseline(
                baselineID, { size = true })
            then
                restored = true
            end
            local data = NSkin:GetSkinData(tab, COMPONENT_STATE, false)
            if data and data.tabOriginalSize then
                tab:SetSize(data.tabOriginalSize[1], data.tabOriginalSize[2])
                data.tabOriginalSize = nil
                restored = true
            end
        end
    end
    return restored
end

local function RestoreTabPoints(groupID)
    local group = tabGroups[groupID]
    local restored
    for i = 1, #(group and group.tabBaselineIDs or {}) do
        restored = NSkin:RestoreComponentBaseline(
            group.tabBaselineIDs[i], { points = true }) or restored
    end
    if group and group.groupBaselineID then
        restored = NSkin:RestoreComponentBaseline(
            group.groupBaselineID, { points = true, spacing = true }) or restored
    end
    if restored then return true end
    local originals = tabGroupOriginalPoints[groupID]
    if not originals then return false end
    for i = 1, #originals do
        local original = originals[i]
        if original.target and original.target.ClearAllPoints then
            original.target:ClearAllPoints()
            for pointIndex = 1, #original.points do
                original.target:SetPoint(unpack(original.points[pointIndex]))
            end
        end
    end
    return true
end

local function ApplyTabGeometryWithoutPlacement(group, tabStyle)
    local tabs = group.container and group.container.tabs or group.tabs
    local applied = false
    if type(tabs) == "table" then
        for i = 1, #tabs do
            local tab = tabs[i]
            if tab then
                local hasSize = tonumber(tabStyle and tabStyle.width)
                    or tonumber(tabStyle and tabStyle.height)
                local baselineID = group.tabBaselineIDs and group.tabBaselineIDs[i]
                if baselineID then
                    if hasSize then
                        NSkin:MarkComponentGeometryModified(
                            baselineID, "size", true)
                    else
                        NSkin:RestoreComponentBaseline(
                            baselineID, { size = true })
                    end
                end
                ApplyTabDimensions(tab, tabStyle,
                    NSkin:GetSkinData(tab, COMPONENT_STATE))
                applied = true
            end
        end
    end

    if group.container and group.container.MarkDirty then
        local spacing = tonumber(tabStyle and tabStyle.spacing)
        if spacing ~= nil then
            NSkin:MarkComponentGeometryModified(
                group.groupBaselineID, "spacing", true)
            group.container.spacing = spacing
            group.spacingOverrideApplied = true
        elseif group.spacingOverrideApplied then
            NSkin:RestoreComponentBaseline(
                group.groupBaselineID, { spacing = true })
            group.container.spacing = group.originalSpacing
            group.spacingOverrideApplied = nil
        end
        group.container:MarkDirty()
    else
        local spacing = tonumber(tabStyle and tabStyle.spacing)
        if spacing ~= nil then
            for i = 1, #(group.tabBaselineIDs or {}) do
                NSkin:MarkComponentGeometryModified(
                    group.tabBaselineIDs[i], "points", true)
            end
            if not group.spacingOverrideApplied then
                RestoreTabPoints(group.id)
            end
            NSkin:LayoutTabGroup(tabs, {
                spacing = spacing,
                orientation = group.orientation,
            })
            group.spacingOverrideApplied = true
        elseif group.spacingOverrideApplied then
            RestoreTabPoints(group.id)
            group.spacingOverrideApplied = nil
        end
    end
    return applied
end

function NSkin:ApplyTabGroupPlacement(group, placement, applyOptions)
    if not group or (_G.InCombatLockdown and _G.InCombatLockdown()) then return false end
    local options = group.layoutOptions
    if not options then
        options = {}
        group.layoutOptions = options
    end
    options.element = group
    options.owner = group.window
    options.edge = group.edge
    options.orientation = group.orientation
    local tabStyle = self:GetAppearanceStyle(
        "tab", group.appearanceWindowID, group.id)
    options.spacing = tonumber(tabStyle and tabStyle.spacing)
        or group.originalSpacing or 0
    options.placement = placement
    local applied
    if group.container and group.container.MarkDirty then
        applied = self:LayoutTabSystem(group.container, options) == true
    else
        applied = self:LayoutTabGroup(group.tabs, options) == true
    end
    if applied and group.groupBaselineID then
        self:MarkComponentGeometryModified(
            group.groupBaselineID, "points", group.container ~= nil)
        if tonumber(tabStyle and tabStyle.spacing) ~= nil then
            self:MarkComponentGeometryModified(
                group.groupBaselineID, "spacing", true)
        end
    end
    local tabs = group.container and group.container.tabs or group.tabs
    if applied and type(tabs) == "table" then
        for i = 1, #tabs do
            local tab = tabs[i]
            if tab then
                local baselineID = group.tabBaselineIDs and group.tabBaselineIDs[i]
                if baselineID then
                    NSkin:MarkComponentGeometryModified(
                        baselineID, "points", true)
                    if tonumber(tabStyle and tabStyle.width)
                        or tonumber(tabStyle and tabStyle.height)
                    then
                        NSkin:MarkComponentGeometryModified(
                            baselineID, "size", true)
                    end
                end
                ApplyTabDimensions(tab, tabStyle,
                    self:GetSkinData(tab, COMPONENT_STATE))
            end
        end
    end
    if applied and not (applyOptions and applyOptions.suppressNotify) then
        FireComponentCallback("TabGroupLayoutApplied", group)
    end
    return applied
end

function NSkin:ApplyTabGroupLayout(groupID)
    local group = tabGroups[groupID]
    if not group or (_G.InCombatLockdown and _G.InCombatLockdown()) then return false end
    if type(group.hasPlacement) == "function" and not group.hasPlacement(group) then
        local tabStyle = self:GetAppearanceStyle(
            "tab", group.appearanceWindowID, group.id)
        local applied = ApplyTabGeometryWithoutPlacement(group, tabStyle)
        if applied then FireComponentCallback("TabGroupLayoutApplied", group) end
        return applied
    end
    local placement = self:GetTabGroupPlacement(groupID)
    if type(group.applyPlacement) == "function" then
        local applied = group.applyPlacement(group, placement, { suppressNotify = true }) == true
        if applied then FireComponentCallback("TabGroupLayoutApplied", group) end
        return applied
    end
    return self:ApplyTabGroupPlacement(group, placement)
end

function NSkin:RefreshRegisteredTabGroups()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    for groupID in pairs(tabGroups) do
        self:ApplyTabGroupLayout(groupID)
    end
    return true
end

function NSkin:RestoreTabGroupOriginalPlacement(groupID)
    local group = tabGroups[groupID]
    if not group then return false end
    local refreshed
    if type(group.refreshBlizzardLayout) == "function" then
        refreshed = group.refreshBlizzardLayout(group) == true
    end
    if refreshed then
        for i = 1, #(group.tabBaselineIDs or {}) do
            local baseline = self:GetComponentBaseline(group.tabBaselineIDs[i])
            if baseline then wipe(baseline.modified) end
        end
        local baseline = self:GetComponentBaseline(group.groupBaselineID)
        if baseline then wipe(baseline.modified) end
        self:RefreshTabGroupBaseline(groupID, true)
    elseif not RestoreTabPoints(groupID) then
        return false
    end
    if group then
        RestoreTabDimensions(group)
        group.spacingOverrideApplied = nil
        if group.container and group.container.MarkDirty then
            if group.originalSpacing ~= nil then
                group.container.spacing = group.originalSpacing
            end
            group.container:MarkDirty()
        end
    end
    return true
end
