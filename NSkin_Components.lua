local _, NSkin = ...

local COMPONENT_STATE = "components"
local tabGroups = {}
local skinningElements = {}
local componentCallbacks = {}
local movableOriginalPoints = {}
local movableElementsByWindow = setmetatable({}, { __mode = "k" })
local movableWatchers = setmetatable({}, { __mode = "k" })
local registeredWindows = setmetatable({}, { __mode = "k" })
local windowSequence = 0
local SUPPRESS_NOTIFICATION = { suppressNotify = true }

local function CopyPlacement(placement)
    local copy = {}
    for key, value in pairs(placement or {}) do copy[key] = value end
    return copy
end

function NSkin:RegisterComponentCallback(event, callback, owner)
    if type(event) ~= "string" or type(callback) ~= "function" then return false end
    local listeners = componentCallbacks[event]
    if not listeners then
        listeners = {}
        componentCallbacks[event] = listeners
    end
    listeners[#listeners + 1] = { callback = callback, owner = owner }
    return true
end

function NSkin:UnregisterComponentCallbacks(owner)
    if owner == nil then return false end
    for _, listeners in pairs(componentCallbacks) do
        for i = #listeners, 1, -1 do
            if listeners[i].owner == owner then table.remove(listeners, i) end
        end
    end
    return true
end

local function FireComponentCallback(event, ...)
    local listeners = componentCallbacks[event]
    if not listeners then return end
    for i = 1, #listeners do
        local listener = listeners[i]
        listener.callback(listener.owner, ...)
    end
end

function NSkin:CreateOptionsSlider(parent, options)
    if not parent then return nil end
    options = options or {}
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetSize(options.width or 280, options.height or 18)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(options.min or 0, options.max or 100)
    slider:SetValueStep(options.step or 1)
    slider:SetObeyStepOnDrag(options.obeyStep ~= false)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(4)
    track:SetColorTexture(0.35, 0.35, 0.35, 1)

    local accent = self:GetAccentColor()
    local fillGlows = {}
    local glowHeights = { 12, 8, 4 }
    local glowAlphas = { 0.10, 0.18, 0.34 }
    for i = 1, 3 do
        local glow = slider:CreateTexture(nil, "ARTWORK", nil, -2 + i)
        glow:SetPoint("LEFT", slider, "LEFT", 0, 0)
        glow:SetHeight(glowHeights[i])
        glow:SetBlendMode("ADD")
        glow:SetColorTexture(accent[1], accent[2], accent[3], glowAlphas[i])
        fillGlows[i] = glow
    end

    local fill = slider:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("LEFT", slider, "LEFT", 0, 0)
    fill:SetHeight(4)
    fill:SetColorTexture(unpack(accent))

    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local marker = slider:GetThumbTexture()
    marker:SetSize(3, 14)
    marker:SetColorTexture(unpack(accent))
    local markerGlowOuter = slider:CreateTexture(nil, "ARTWORK")
    markerGlowOuter:SetPoint("CENTER", marker, "CENTER", 0, 0)
    markerGlowOuter:SetSize(7, 17)
    markerGlowOuter:SetBlendMode("ADD")
    markerGlowOuter:SetColorTexture(accent[1], accent[2], accent[3], 0.12)
    local markerGlowInner = slider:CreateTexture(nil, "ARTWORK", nil, 1)
    markerGlowInner:SetPoint("CENTER", marker, "CENTER", 0, 0)
    markerGlowInner:SetSize(3, 13)
    markerGlowInner:SetBlendMode("ADD")
    markerGlowInner:SetColorTexture(accent[1], accent[2], accent[3], 0.30)

    local minimum, maximum = options.min or 0, options.max or 100
    local function RefreshSliderVisual(value)
        local range = maximum - minimum
        local ratio = range > 0 and math.max(0, math.min(1,
            ((tonumber(value) or minimum) - minimum) / range)) or 0
        local width = math.max(0.001, slider:GetWidth() * ratio)
        fill:SetWidth(width)
        for i = 1, 3 do fillGlows[i]:SetWidth(width) end
    end
    local function RefreshSlider(_, value)
        RefreshSliderVisual(value)
        if type(options.onValueChanged) == "function" then
            options.onValueChanged(slider, value)
        end
        if not slider.nskinDragging
            and type(options.onValueCommitted) == "function"
        then
            options.onValueCommitted(slider, value)
        end
    end
    slider:SetScript("OnMouseDown", function(self) self.nskinDragging = true end)
    slider:SetScript("OnMouseUp", function(self)
        if not self.nskinDragging then return end
        self.nskinDragging = nil
        if type(options.onValueCommitted) == "function" then
            options.onValueCommitted(self, self:GetValue())
        end
    end)
    slider:SetScript("OnValueChanged", RefreshSlider)
    RefreshSliderVisual(slider:GetValue())
    return slider
end

-- Buttons Skinning
local function ShowFlatButtonGlow(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if data and data.hoverGlow and (not button.IsEnabled or button:IsEnabled()) then
        data.hoverGlow:Show()
    end
end

local function HideFlatButtonGlow(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if data and data.hoverGlow then data.hoverGlow:Hide() end
end

function NSkin:CreateFlatButtonGlow(button, alpha)
    if not button or not button.CreateTexture then return nil end
    local data = self:GetSkinData(button, COMPONENT_STATE)
    if data.hoverGlow then
        data.hoverGlow:SetColorTexture(1, 1, 1, alpha or 0.10)
        return data.hoverGlow
    end

    local glow = button:CreateTexture(nil, "OVERLAY", nil, -1)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, alpha or 0.10)
    glow:Hide()
    data.hoverGlow = glow

    if button.HookScript then
        button:HookScript("OnEnter", ShowFlatButtonGlow)
        button:HookScript("OnLeave", HideFlatButtonGlow)
    end

    return glow
end

function NSkin:SetFlatButtonLabel(button, label, size, offsetX, offsetY)
    if not button or not button.CreateFontString then return nil end

    local data = self:GetSkinData(button, COMPONENT_STATE)
    local text = data.label
    if not text then
        text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        data.label = text
    end

    text:ClearAllPoints()
    text:SetPoint("CENTER", button, "CENTER", offsetX or 0, offsetY or 0)
    text:SetText(label or "")

    if size then
        local font, _, flags = text:GetFont()
        if font then text:SetFont(font, size, flags) end
    end

    text:SetAlpha(1)
    text:Show()
    return text
end

function NSkin:SkinFlatButton(button, label, backgroundColor, borderColor,
    labelSize, labelOffsetX, labelOffsetY)
    if not button or not button.CreateTexture or not button.CreateFontString then return end

    local style = self:GetStyle("button")
    backgroundColor = backgroundColor or style.background
    borderColor = borderColor or self:GetComponentBorderColor("button", style)

    local background = self:GetFlatBackground(button)
    if not background then
        self:HideTextureRegions(button)
    end

    self:CreateFlatBackground(button, nil, backgroundColor, borderColor)
    self:CreateFlatButtonGlow(button, style.hoverAlpha)
    local text = self:SetFlatButtonLabel(button, label, labelSize, labelOffsetX, labelOffsetY)
    if text then text:SetTextColor(unpack(style.text)) end
end

function NSkin:SkinSearchBox(searchBox, style, borderColor)
    if not searchBox then return end

    local searchData = self:GetSkinData(searchBox, COMPONENT_STATE)
    local searchIcon = searchBox.SearchIcon or searchBox.searchIcon
    if not self:GetFlatBackground(searchBox) then
        self:HideTextureRegions(searchBox, searchIcon)
    end
    style = style or self:GetStyle("searchBox")
    local configuredWidth, configuredHeight = tonumber(style.width), tonumber(style.height)
    configuredWidth = configuredWidth and configuredWidth > 0 and configuredWidth or nil
    configuredHeight = configuredHeight and configuredHeight > 0 and configuredHeight or nil
    if configuredWidth or configuredHeight then
        if not searchData.searchOriginalSize then
            searchData.searchOriginalSize = { searchBox:GetWidth(), searchBox:GetHeight() }
        end
        local originalSize = searchData.searchOriginalSize
        searchBox:SetSize(configuredWidth or originalSize[1],
            configuredHeight or originalSize[2])
    elseif searchData.searchOriginalSize then
        searchBox:SetSize(searchData.searchOriginalSize[1],
            searchData.searchOriginalSize[2])
        searchData.searchOriginalSize = nil
    end
    self:CreateFlatBackground(
        searchBox, nil, self:GetResolvedAppearanceColor(style, "background"),
        borderColor or self:GetResolvedAppearanceColor(style, "border")
            or self:GetComponentBorderColor("searchBox", style)
    )
    local searchBorder = self:GetPixelBorder(searchBox, "NSkinFlatBackgroundBorder")
    self:SetPixelBorderSize(searchBorder, style.borderSize or 1)
    self:SetPixelBorderPadding(searchBorder, style.borderPadding or 0)
    if searchBox.SetTextColor then
        searchBox:SetTextColor(unpack(self:GetResolvedAppearanceColor(style, "text")))
    end
    local font, size, outline = self:GetResolvedTypography(style)
    if searchBox.SetFont and font and size then searchBox:SetFont(font, size, outline) end
    if searchBox.GetTextInsets and searchBox.SetTextInsets then
        if not searchData.searchTextInsets then
            searchData.searchTextInsets = { searchBox:GetTextInsets() }
        end
        local insets = searchData.searchTextInsets
        local offsetX, offsetY = style.textOffsetX or 0, style.textOffsetY or 0
        searchBox:SetTextInsets((insets[1] or 0) + offsetX,
            (insets[2] or 0) - offsetX, (insets[3] or 0) - offsetY,
            (insets[4] or 0) + offsetY)
    end
    local instructions = searchBox.Instructions or searchBox.instructions
    if instructions then
        instructions:SetTextColor(unpack(
            self:GetResolvedAppearanceColor(style, "placeholderText")))
        local placeholderFont, placeholderSize, placeholderOutline =
            self:GetResolvedTypography(style, "placeholder")
        if instructions.SetFont and placeholderFont and placeholderSize then
            instructions:SetFont(placeholderFont, placeholderSize, placeholderOutline)
        end
        local data = self:GetSkinData(instructions, COMPONENT_STATE)
        if not data.searchPlaceholderPoints then
            data.searchPlaceholderPoints = {}
            for i = 1, instructions:GetNumPoints() do
                data.searchPlaceholderPoints[i] = { instructions:GetPoint(i) }
            end
        end
        instructions:ClearAllPoints()
        for i = 1, #data.searchPlaceholderPoints do
            local point = data.searchPlaceholderPoints[i]
            instructions:SetPoint(point[1], point[2], point[3],
                (point[4] or 0) + (style.placeholderOffsetX or 0),
                (point[5] or 0) + (style.placeholderOffsetY or 0))
        end
    end
    if searchIcon then searchIcon:Show() end
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
    SkinPagingButton(previous, "<", textSize or 16)
    SkinPagingButton(nextPage, ">", textSize or 16)
    if pageText then pageText:SetTextColor(unpack(self:GetStyle("button").text)) end
end

-- Windows Skinning

function NSkin:ApplyGlobalTypography(frame)
    if not frame then return end
    local typography = self:GetStyle("typography")
    local font, size, outline = typography.font, typography.size, typography.outline
    if not font or not size then return end

    local function Apply(target)
        if target.GetObjectType and target:GetObjectType() == "FontString" then
            target:SetFont(font, size, outline)
        elseif target.GetObjectType and target:GetObjectType() == "EditBox"
            and target.SetFont
        then
            target:SetFont(font, size, outline)
        end
        if target.GetRegions then
            for _, region in ipairs({ target:GetRegions() }) do
                if region.GetObjectType and region:GetObjectType() == "FontString" then
                    region:SetFont(font, size, outline)
                end
            end
        end
        if target.GetChildren then
            for _, child in ipairs({ target:GetChildren() }) do Apply(child) end
        end
    end

    Apply(frame)
end

function NSkin:SkinWindow(frame, backgroundAnchor, style, borderColor)
    if not frame then return nil end

    style = style or self:GetStyle("window")
    local anchor = backgroundAnchor or frame
    local data = self:GetSkinData(frame, COMPONENT_STATE)
    local background = data.windowBackground
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        background:SetAllPoints(anchor)
        data.windowBackground = background
    end
    background:SetColorTexture(unpack(self:GetResolvedAppearanceColor(style, "background")))

    local border = self:CreatePixelBorder(
        frame, "NSkinWindowBorder", style.borderSize,
        borderColor or self:GetWindowBorderColor(), false, anchor
    )
    self:SetPixelBorderSize(border, style.borderSize)
    self:SetPixelBorderPadding(border, style.borderPadding or 0)
    self:SetPixelBorderColor(border, unpack(borderColor or self:GetWindowBorderColor()))
    return background, border
end

function NSkin:SkinWindowHeader(frame, style)
    if not frame then return nil end

    style = style or self:GetStyle("window").header
    local data = self:GetSkinData(frame, COMPONENT_STATE)
    local background = data.windowHeaderBackground
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
        background:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        background:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        data.windowHeaderBackground = background
    end
    background:SetHeight(style.height)
    background:SetColorTexture(unpack(self:GetResolvedAppearanceColor(style, "background")))
    return background
end

-- Tab Skinning

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
        local font, size, outline = self:GetResolvedTypography(style)
        if font and size then tab.Text:SetFont(font, size, outline) end
    end
end

function NSkin:LayoutTabGroup(tabs, options)
    if type(tabs) ~= "table" then return end
    options = options or {}

    local spacing = tonumber(options.spacing) or self:GetTabSpacing()
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
        local layout = options.placement or self:GetStyle("tab").bottom
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

    tabSystem.spacing = tonumber(options and options.spacing) or self:GetTabSpacing()
    tabSystem:MarkDirty()

    if options and options.owner
        and (options.edge == "BOTTOM" or options.edge == "TOP")
    then
        local layout = options.placement or self:GetStyle("tab").bottom
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

function NSkin:RegisterTabGroup(groupID, definition)
    if type(groupID) ~= "string" or groupID == ""
        or type(definition) ~= "table"
        or not (definition.window or definition.owner)
        or definition.orientation ~= "HORIZONTAL"
        or (definition.edge ~= "BOTTOM" and definition.edge ~= "TOP")
        or (not definition.container and type(definition.tabs) ~= "table")
    then
        return false
    end

    local group = tabGroups[groupID]
    if group then
        for key, value in pairs(definition) do group[key] = value end
    else
        group = definition
        group.id = groupID
        tabGroups[groupID] = group
    end
    if type(group.applyPlacement) ~= "function" then
        group.applyPlacement = function(element, placement, applyOptions)
            return NSkin:ApplyTabGroupPlacement(element, placement, applyOptions)
        end
    end
    if type(group.module) == "string" and not group.getPlacement then
        group.getPlacement = function(element)
            local moduleOptions = NSkin:GetModuleOptions(element.module, false)
            local saved = moduleOptions and moduleOptions.tabPlacements
                and moduleOptions.tabPlacements[element.id]
            return CopyPlacement(saved or NSkin:GetTabPlacement())
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
            local placement = NSkin:GetTabPlacement()
            if not NSkin:ApplyTabGroupPlacement(element, placement,
                { suppressNotify = true })
            then
                return false
            end
            local moduleOptions = NSkin:GetModuleOptions(element.module, false)
            if moduleOptions and moduleOptions.tabPlacements then
                moduleOptions.tabPlacements[element.id] = nil
                if not next(moduleOptions.tabPlacements) then
                    moduleOptions.tabPlacements = nil
                end
            end
            FireComponentCallback("TabGroupLayoutApplied", element)
            return true
        end
    end

    self:RegisterSkinningElement(groupID, group)
    return true
end

function NSkin:RegisterSkinningElement(elementID, definition)
    if type(elementID) ~= "string" or elementID == ""
        or type(definition) ~= "table"
        or not (definition.window or definition.owner)
    then
        return false
    end

    definition.window = definition.window or definition.owner
    definition.target = definition.target or definition.container or definition.owner
    definition.appearanceWindowID = definition.appearanceWindowID or definition.module
    definition.owner = nil
    definition.priority = tonumber(definition.priority) or 0
    definition.highlightPadding = tonumber(definition.highlightPadding) or 0
    if not registeredWindows[definition.window] then
        windowSequence = windowSequence + 1
        registeredWindows[definition.window] = windowSequence
    end

    local element = skinningElements[elementID]
    if element then
        for key, value in pairs(definition) do element[key] = value end
    else
        element = definition
        element.id = elementID
        skinningElements[elementID] = element
    end
    FireComponentCallback("SkinningElementRegistered", element)
    return true
end

function NSkin:MarkSkinningWindowActive(window)
    if not window then return false end
    windowSequence = windowSequence + 1
    registeredWindows[window] = windowSequence
    return true
end

function NSkin:GetMostRecentVisibleSkinningWindow(excludedWindow)
    local bestWindow, bestSequence
    for window, sequence in pairs(registeredWindows) do
        if window ~= excludedWindow and window.IsShown and window:IsShown()
            and (not bestSequence or sequence > bestSequence)
        then
            bestWindow, bestSequence = window, sequence
        end
    end
    return bestWindow
end

function NSkin:ForEachRegisteredSkinningElement(callback)
    if type(callback) ~= "function" then return end
    for _, element in pairs(skinningElements) do callback(element) end
end

function NSkin:GetSkinningElement(elementID)
    return skinningElements[elementID]
end

function NSkin:IsSkinningElementEditable(element)
    if not element then return false end
    return type(element.isEditable) ~= "function" or element.isEditable(element) == true
end

function NSkin:LayoutWindowElement(element, placement, options)
    local target = element and element.target
    local window = element and element.window
    if not target or not window or type(placement) ~= "table"
        or not target.ClearAllPoints or not target.SetPoint
        or (target.IsProtected and target:IsProtected())
        or (_G.InCombatLockdown and _G.InCombatLockdown())
    then
        return false
    end
    if placement.mode == "GRID" then
        target:ClearAllPoints()
        target:SetPoint(placement.point or "TOPLEFT", window,
            placement.relativePoint or "TOPLEFT", tonumber(placement.x) or 0,
            tonumber(placement.y) or 0)
        if not (options and options.suppressNotify) then
            self:NotifySkinningElementBoundsChanged(element.id)
        end
        return true
    end
    local relativeElement = placement.relativeTo and skinningElements[placement.relativeTo]
    if relativeElement and relativeElement.snapTarget and relativeElement.window == window
        and relativeElement.target and (not relativeElement.target.IsShown
            or relativeElement.target:IsShown())
    then
        target:ClearAllPoints()
        target:SetPoint(placement.point, relativeElement.target, placement.relativePoint,
            tonumber(placement.offsetX) or 0, tonumber(placement.offsetY) or 0)
        if not (options and options.suppressNotify) then
            self:NotifySkinningElementBoundsChanged(element.id)
        end
        return true
    end
    local edge = placement.edge
    local side = placement.side
    local alignment = placement.alignment
    if (edge ~= "TOP" and edge ~= "BOTTOM")
        or (side ~= "INSIDE" and side ~= "OUTSIDE")
        or (alignment ~= "LEFT" and alignment ~= "CENTER" and alignment ~= "RIGHT")
    then return false end
    local point
    if edge == "TOP" then point = side == "INSIDE" and "TOP" or "BOTTOM"
    else point = side == "INSIDE" and "BOTTOM" or "TOP" end
    local relativePoint = edge
    if alignment ~= "CENTER" then
        point = point .. alignment
        relativePoint = relativePoint .. alignment
    end
    target:ClearAllPoints()
    target:SetPoint(point, window, relativePoint,
        tonumber(placement.alongOffset) or 0, tonumber(placement.edgeOffset) or 0)
    if not (options and options.suppressNotify) then
        self:NotifySkinningElementBoundsChanged(element.id)
    end
    return true
end

local function GetSavedMovablePlacement(element)
    local options = NSkin:GetModuleOptions(element.module, false)
    return options and options.movablePlacements
        and options.movablePlacements[element.id]
end

local function EnsureMovableWatcher(window)
    local watcher = movableWatchers[window]
    if not watcher then
        watcher = CreateFrame("Frame", nil, window)
        watcher:Hide()
        watcher:SetScript("OnShow", function()
            local elements = movableElementsByWindow[window]
            for i = 1, #(elements or {}) do
                local element = elements[i]
                local placement = GetSavedMovablePlacement(element)
                if placement and NSkin:IsSkinningElementEditable(element) then
                    element.applyPlacement(element, placement)
                end
            end
        end)
        movableWatchers[window] = watcher
    end
    watcher:Show()
end

function NSkin:GetSavedMovableElementPlacement(elementID)
    local element = skinningElements[elementID]
    local placement = element and element.module and GetSavedMovablePlacement(element)
    return placement and CopyPlacement(placement) or nil
end

function NSkin:RestoreMovableElementOriginal(elementOrID, suppressNotify)
    local element = type(elementOrID) == "table"
        and elementOrID or skinningElements[elementOrID]
    local points = element and movableOriginalPoints[element.id]
    if not element or not points or not element.target then return false end
    element.target:ClearAllPoints()
    for i = 1, #points do element.target:SetPoint(unpack(points[i])) end
    if not suppressNotify then self:NotifySkinningElementBoundsChanged(element.id) end
    return true
end

function NSkin:RegisterMovableElement(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string"
        or type(definition.module) ~= "string" or not definition.window
        or not definition.target or type(definition.defaultPlacement) ~= "table"
    then return false end
    local id = definition.id
    if not movableOriginalPoints[id] then
        local points = {}
        for i = 1, definition.target:GetNumPoints() do
            points[i] = { definition.target:GetPoint(i) }
        end
        movableOriginalPoints[id] = points
    end
    local customApply = definition.applyPlacement
    definition.kind = definition.kind or "MOVABLE"
    definition.draggable = definition.draggable ~= false
    definition.movable = true
    definition.getPlacement = definition.getPlacement or function(element)
        return CopyPlacement(GetSavedMovablePlacement(element) or element.defaultPlacement)
    end
    definition.applyPlacement = customApply or function(element, placement, applyOptions)
        return NSkin:LayoutWindowElement(element, placement, applyOptions)
    end
    definition.setPlacement = definition.setPlacement or function(element, placement)
        if placement.relativeTo
            and NSkin:WouldCreateSkinningPlacementCycle(element.id, placement.relativeTo)
        then return false end
        if not element.applyPlacement(element, placement) then return false end
        local options = NSkin:GetModuleOptions(element.module, true)
        options.movablePlacements = options.movablePlacements or {}
        options.movablePlacements[element.id] = CopyPlacement(placement)
        EnsureMovableWatcher(element.window)
        return true
    end
    definition.resetPlacement = definition.resetPlacement or function(element)
        if not NSkin:RestoreMovableElementOriginal(element) then return false end
        local options = NSkin:GetModuleOptions(element.module, false)
        if options and options.movablePlacements then
            options.movablePlacements[element.id] = nil
            if not next(options.movablePlacements) then options.movablePlacements = nil end
            if not next(options) then
                local profile = NSkin:GetProfile()
                if profile.moduleOptions then
                    profile.moduleOptions[element.module] = nil
                    if not next(profile.moduleOptions) then profile.moduleOptions = nil end
                end
            end
        end
        return true
    end
    self:RegisterSkinningElement(id, definition)
    local element = skinningElements[id]
    local elements = movableElementsByWindow[element.window]
    if not elements then
        elements = {}
        movableElementsByWindow[element.window] = elements
    end
    local alreadyRegistered
    for i = 1, #elements do
        if elements[i] == element then alreadyRegistered = true break end
    end
    if not alreadyRegistered then elements[#elements + 1] = element end
    local saved = GetSavedMovablePlacement(element)
    if saved and self:IsSkinningElementEditable(element) then
        if element.applyPlacement(element, saved) then EnsureMovableWatcher(element.window) end
    end
    return true
end

local PROGRESS_COMPONENT_STATE = "progressBarComponent"
local PROGRESS_BACKGROUND_KEY = "NSkinProgressBarBackground"

local function HideProgressBarArtwork(region, fill)
    if region == fill or not region or not region.IsObjectType
        or not region:IsObjectType("Texture")
    then return end
    region:SetAlpha(0)
    region:SetTexture(nil)
    region:Hide()
end

local function CenterProgressBarText(bar, region, offsetX, offsetY)
    if not region or not region.IsObjectType or not region:IsObjectType("FontString") then
        return
    end
    region:ClearAllPoints()
    region:SetPoint("CENTER", bar, "CENTER", offsetX, offsetY)
end

function NSkin:SkinProgressBar(bar, options)
    if not bar or not bar.GetObjectType or bar:GetObjectType() ~= "StatusBar"
        or not bar.SetStatusBarTexture or (bar.IsForbidden and bar:IsForbidden())
    then return false end
    options = options or {}
    local data = self:GetSkinData(bar, PROGRESS_COMPONENT_STATE)
    local height = tonumber(options.height)
    if height and height > 0 then bar:SetHeight(height) end

    local fill = bar:GetStatusBarTexture()
    if type(options.artworkRegions) == "table" then
        for i = 1, #options.artworkRegions do
            HideProgressBarArtwork(options.artworkRegions[i], fill)
        end
    elseif options.stripArtwork and not data.artworkStripped and bar.GetRegions then
        local regions = { bar:GetRegions() }
        for i = 1, #regions do HideProgressBarArtwork(regions[i], fill) end
        data.artworkStripped = true
    end

    local texture = options.texture
    if options.useThemeTexture then texture = self:GetStatusBarTexture() end
    if type(texture) == "string" and texture ~= "" then
        bar:SetStatusBarTexture(texture)
        fill = bar:GetStatusBarTexture()
        if fill then
            fill:Show()
            if fill.SetHorizTile then fill:SetHorizTile(false) end
            if fill.SetVertTile then fill:SetVertTile(false) end
        end
    end

    if options.background then
        local style = self:GetStyle("progressBar")
        self:CreateFlatBackground(bar, PROGRESS_BACKGROUND_KEY,
            options.backgroundColor or style.background,
            options.borderColor or self:GetWindowBorderColor())
    end

    if options.centerText then
        local offsetX = tonumber(options.textOffsetX) or 0
        local offsetY = tonumber(options.textOffsetY) or 0
        if type(options.textRegions) == "table" then
            for i = 1, #options.textRegions do
                CenterProgressBarText(bar, options.textRegions[i], offsetX, offsetY)
            end
        else
            CenterProgressBarText(bar, bar.Label, offsetX, offsetY)
            if bar.GetRegions then
                local regions = { bar:GetRegions() }
                for i = 1, #regions do
                    CenterProgressBarText(bar, regions[i], offsetX, offsetY)
                end
            end
        end
    end
    return true
end

local function GetCurrentWindowPlacement(window, target)
    local windowLeft, windowTop = window:GetLeft(), window:GetTop()
    local targetLeft, targetTop = target:GetLeft(), target:GetTop()
    if windowLeft and windowTop and targetLeft and targetTop then
        return { mode = "GRID", point = "TOPLEFT", relativePoint = "TOPLEFT",
            x = targetLeft - windowLeft, y = targetTop - windowTop }
    end
    return { edge = "TOP", side = "INSIDE", alignment = "CENTER",
        alongOffset = 0, edgeOffset = -46 }
end

local function GetControllerState(module, id, create)
    local options = NSkin:GetModuleOptions(module, create == true)
    if not options then return end
    if create and not options.componentStates then options.componentStates = {} end
    local states = options.componentStates
    if not states then return nil, options end
    if create and not states[id] then states[id] = {} end
    return states[id], options
end

local function PruneControllerState(module, options, id)
    local states = options and options.componentStates
    local state = states and states[id]
    if state and not next(state) then states[id] = nil end
    if states and not next(states) then options.componentStates = nil end
    if options and not next(options) then
        local profile = NSkin:GetProfile()
        if profile.moduleOptions then
            profile.moduleOptions[module] = nil
            if not next(profile.moduleOptions) then profile.moduleOptions = nil end
        end
    end
end

local function RegisterControllerElement(controller, id, label, target, options)
    if not id or not target then return end
    options = options or {}
    NSkin:RegisterMovableElement({
        id = id,
        module = controller.module,
        appearanceWindowID = controller.appearanceWindowID or controller.module,
        label = label,
        window = controller.window,
        target = target,
        editorOptions = options.editorOptions,
        defaultPlacement = CopyPlacement(options.defaultPlacement
            or GetCurrentWindowPlacement(controller.window, target)),
        priority = options.priority,
        anchorHighlight = options.anchorHighlight,
        highlightRegions = options.highlightRegions,
        isEditable = options.isEditable,
        applyPlacement = options.applyPlacement,
        snapTarget = options.snapTarget,
        livePreview = options.livePreview,
        draggable = options.draggable,
    })
    return skinningElements[id]
end

function NSkin:RegisterPaginationGroup(definition)
    if type(definition) ~= "table" or type(definition.module) ~= "string"
        or not definition.window or type(definition.ids) ~= "table"
        or type(definition.controls) ~= "table"
    then return end
    local ids, controls = definition.ids, definition.controls
    if not ids.group or not ids.previous or not ids.next or not ids.text
        or not controls.group or not controls.previous or not controls.next
        or not controls.text
    then return end
    local controller = { module = definition.module,
        appearanceWindowID = definition.appearanceWindowID or definition.module,
        window = definition.window,
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
    local editorOptions = definition.editorOptions or {
        { id = "shared.paginationPosition", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.paginationLayout", label = "Layout",
            presentation = "INLINE", category = "LAYOUT" },
    }
    local defaultPlacement = definition.defaultPlacement
    local group = RegisterControllerElement(controller, ids.group,
        definition.groupLabel or "Pagination", controls.group, {
            editorOptions = editorOptions,
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
            isEditable = function() return not controller:GetSeparateButtons() end,
        })
    local previous = RegisterControllerElement(controller, ids.previous,
        definition.previousLabel or "Previous page button", controls.previous, {
            editorOptions = editorOptions,
            defaultPlacement = previousDefinition.defaultPlacement
                or definition.previousPlacement or defaultPlacement,
            priority = previousDefinition.priority or definition.buttonPriority or 90,
            isEditable = function() return controller:GetSeparateButtons() end,
            applyPlacement = previousDefinition.applyPlacement,
            livePreview = previousDefinition.livePreview,
            draggable = previousDefinition.draggable,
        })
    local nextPage = RegisterControllerElement(controller, ids.next,
        definition.nextLabel or "Next page button", controls.next, {
            editorOptions = editorOptions,
            defaultPlacement = nextDefinition.defaultPlacement
                or definition.nextPlacement or defaultPlacement,
            priority = nextDefinition.priority or definition.buttonPriority or 90,
            isEditable = function() return controller:GetSeparateButtons() end,
            applyPlacement = nextDefinition.applyPlacement,
            livePreview = nextDefinition.livePreview,
            draggable = nextDefinition.draggable,
        })
    local text = RegisterControllerElement(controller, ids.text,
        definition.textLabel or "Page text", controls.text, {
            editorOptions = editorOptions,
            defaultPlacement = textDefinition.defaultPlacement
                or definition.textPlacement or defaultPlacement,
            priority = textDefinition.priority or definition.textPriority or 100,
            isEditable = function() return controller:GetTextMode() == "INDEPENDENT" end,
            applyPlacement = textDefinition.applyPlacement,
            livePreview = textDefinition.livePreview,
            draggable = textDefinition.draggable,
        })
    for _, element in ipairs({ group, previous, nextPage, text }) do
        if element then
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
    controller:UpdateWatcher()
    controller:Refresh()
    return controller
end

function NSkin:RegisterAccessoryGroup(definition)
    if type(definition) ~= "table" or type(definition.module) ~= "string"
        or not definition.window or not definition.primary or not definition.accessory
        or type(definition.ids) ~= "table" or not definition.ids.primary
        or not definition.ids.accessory or type(definition.anchorGrouped) ~= "function"
    then return end
    local controller = { module = definition.module,
        appearanceWindowID = definition.appearanceWindowID or definition.module,
        window = definition.window,
        id = definition.id or definition.ids.primary, ids = definition.ids,
        primary = definition.primary, accessory = definition.accessory }
    local legacyOptionKey = definition.legacyOptionKey
    function controller:GetMode()
        local state, options = GetControllerState(self.module, self.id, false)
        if state and state.mode then return state.mode end
        return legacyOptionKey and options and options[legacyOptionKey] or "GROUPED"
    end
    function controller:AnchorGrouped()
        return definition.anchorGrouped(self.primary, self.accessory) == true
    end
    function controller:ApplyPrimary(element, placement, applyOptions)
        if self:GetMode() == "GROUPED"
            and (placement.relativeTo == self.ids.accessory
                or placement.relativeTo == self.ids.primary)
        then
            placement = CopyPlacement(definition.primaryPlacement)
        end
        if not NSkin:LayoutWindowElement(element, placement, SUPPRESS_NOTIFICATION) then
            return false
        end
        if self:GetMode() == "GROUPED" then self:AnchorGrouped() end
        if not (applyOptions and applyOptions.suppressNotify) then
            NSkin:NotifySkinningElementBoundsChanged(element.id)
        end
        return true
    end
    function controller:NotifyBounds()
        NSkin:NotifySkinningElementBoundsChanged(self.ids.primary)
        NSkin:NotifySkinningElementBoundsChanged(self.ids.accessory)
    end
    function controller:Refresh()
        local mode = self:GetMode()
        self.accessory:SetShown(mode ~= "HIDDEN")
        if mode == "GROUPED" then
            local primaryElement = skinningElements[self.ids.primary]
            local saved = primaryElement and GetSavedMovablePlacement(primaryElement)
            if saved then
                primaryElement.applyPlacement(primaryElement, saved, SUPPRESS_NOTIFICATION)
            else
                NSkin:RestoreMovableElementOriginal(self.ids.accessory, true)
                if primaryElement then
                    primaryElement.applyPlacement(primaryElement,
                        CopyPlacement(definition.primaryPlacement), SUPPRESS_NOTIFICATION)
                end
            end
        elseif mode == "INDEPENDENT" then
            local element = skinningElements[self.ids.accessory]
            local saved = element and GetSavedMovablePlacement(element)
            if saved then element.applyPlacement(element, saved, SUPPRESS_NOTIFICATION) end
        end
        self:NotifyBounds()
    end
    function controller:UpdateWatcher()
        local state, options = GetControllerState(self.module, self.id, false)
        local active = state and next(state) ~= nil
        if not active and legacyOptionKey and options then active = options[legacyOptionKey] end
        if active and not self.watcher then
            self.watcher = CreateFrame("Frame", nil,
                definition.visibilityFrame or self.primary:GetParent() or self.window)
            self.watcher:Hide()
            self.watcher:SetScript("OnShow", function() self:Refresh() end)
        end
        if self.watcher then self.watcher:SetShown(not not active) end
    end
    function controller:SetMode(mode)
        if mode ~= "GROUPED" and mode ~= "INDEPENDENT" and mode ~= "HIDDEN" then
            return false
        end
        local state, options = GetControllerState(self.module, self.id, true)
        state.mode = mode == "GROUPED" and nil or mode
        if legacyOptionKey then options[legacyOptionKey] = nil end
        PruneControllerState(self.module, options, self.id)
        self:UpdateWatcher()
        self:Refresh()
        return true
    end

    local elementDefinitions = definition.elements or {}
    local primaryDefinition = elementDefinitions.primary or {}
    local accessoryDefinition = elementDefinitions.accessory or {}
    controller.groupedHighlightRegions = { controller.primary, controller.accessory }
    controller.primaryHighlightRegion = { controller.primary }
    local editorOptions = definition.editorOptions or {
        { id = "shared.searchPosition", label = "Position",
            presentation = "INLINE", category = "POSITION" },
        { id = "shared.searchBoxAppearance", label = "Search Box",
            presentation = "INLINE", category = "APPEARANCE" },
        { id = "shared.searchTextAppearance", label = "Search Text" },
        { id = "shared.placeholderTextAppearance", label = "Placeholder Text" },
    }
    local accessory = RegisterControllerElement(controller, definition.ids.accessory,
        definition.accessoryLabel or "Search accessory", definition.accessory, {
            editorOptions = accessoryDefinition.editorOptions or editorOptions,
            defaultPlacement = accessoryDefinition.defaultPlacement
                or definition.accessoryPlacement,
            priority = accessoryDefinition.priority or definition.accessoryPriority or 90,
            isEditable = function() return controller:GetMode() == "INDEPENDENT" end,
            applyPlacement = accessoryDefinition.applyPlacement,
            livePreview = accessoryDefinition.livePreview,
            draggable = accessoryDefinition.draggable,
        })
    local primary = RegisterControllerElement(controller, definition.ids.primary,
        definition.primaryLabel or "Search", definition.primary, {
            editorOptions = primaryDefinition.editorOptions or editorOptions,
            defaultPlacement = primaryDefinition.defaultPlacement or definition.primaryPlacement,
            priority = primaryDefinition.priority or definition.primaryPriority or 80,
            snapTarget = definition.snapTarget,
            applyPlacement = function(element, placement, applyOptions)
                if primaryDefinition.applyPlacement then
                    if not primaryDefinition.applyPlacement(element, placement,
                        applyOptions)
                    then return false end
                    if controller:GetMode() == "GROUPED" then controller:AnchorGrouped() end
                    if not (applyOptions and applyOptions.suppressNotify) then
                        NSkin:NotifySkinningElementBoundsChanged(element.id)
                    end
                    return true
                end
                return controller:ApplyPrimary(element, placement, applyOptions)
            end,
            livePreview = primaryDefinition.livePreview,
            draggable = primaryDefinition.draggable,
            highlightRegions = function()
                return controller:GetMode() == "GROUPED"
                    and controller.groupedHighlightRegions
                    or controller.primaryHighlightRegion
            end,
        })
    for _, element in ipairs({ primary, accessory }) do
        if element then
            element.getSearchAccessoryMode = function() return controller:GetMode() end
            element.setSearchAccessoryMode = function(_, mode) return controller:SetMode(mode) end
        end
    end
    if primary then
        local resetPrimary = primary.resetPlacement
        primary.resetPlacement = function(element)
            NSkin:RestoreMovableElementOriginal(controller.ids.accessory, true)
            local reset = resetPrimary(element)
            controller:Refresh()
            return reset
        end
    end
    controller:UpdateWatcher()
    controller:Refresh()
    return controller
end

function NSkin:WouldCreateSkinningPlacementCycle(elementID, relativeTo)
    local visited = {}
    local current = relativeTo
    while current do
        if current == elementID or visited[current] then return true end
        visited[current] = true
        local element = skinningElements[current]
        if not element or type(element.getPlacement) ~= "function" then return false end
        local placement = element.getPlacement(element)
        current = placement and placement.relativeTo
    end
    return false
end

function NSkin:GetUIParentNormalizedBounds(region, left, right, bottom, top)
    if not region or not region.GetEffectiveScale or not UIParent
        or not UIParent.GetEffectiveScale
    then
        return
    end
    left = left or (region.GetLeft and region:GetLeft())
    right = right or (region.GetRight and region:GetRight())
    bottom = bottom or (region.GetBottom and region:GetBottom())
    top = top or (region.GetTop and region:GetTop())
    if not left or not right or not bottom or not top then return end
    local parentScale = UIParent:GetEffectiveScale()
    local regionScale = region:GetEffectiveScale()
    if not parentScale or parentScale == 0 or not regionScale then return end
    local scale = regionScale / parentScale
    return left * scale, right * scale, bottom * scale, top * scale
end

function NSkin:GetSkinningElementBounds(element)
    if not element then return end
    local regions = element.highlightRegions
    if type(regions) == "function" then regions = regions(element) end
    if type(regions) == "table" then
        local left, right, bottom, top
        for i = 1, #regions do
            local region = regions[i]
            if region and (not region.IsShown or region:IsShown()) then
                local regionLeft, regionRight, regionBottom, regionTop =
                    self:GetUIParentNormalizedBounds(region)
                if regionLeft then
                    left = not left and regionLeft or math.min(left, regionLeft)
                    right = not right and regionRight or math.max(right, regionRight)
                    bottom = not bottom and regionBottom or math.min(bottom, regionBottom)
                    top = not top and regionTop or math.max(top, regionTop)
                end
            end
        end
        if left then return left, right, bottom, top end
    end
    if type(element.getHighlightBounds) == "function" then
        local ok, left, right, bottom, top = pcall(element.getHighlightBounds, element)
        if ok and left and right and bottom and top then
            return self:GetUIParentNormalizedBounds(
                element.target or element.window, left, right, bottom, top
            )
        end
    end

    if element.kind == "TAB_GROUP" then
        local tabs = element.container and element.container.tabs or element.tabs
        local left, right, bottom, top
        if type(tabs) == "table" then
            for i = 1, #tabs do
                local tab = tabs[i]
                if tab and (not tab.IsShown or tab:IsShown()) then
                    local tabLeft, tabRight = tab:GetLeft(), tab:GetRight()
                    local tabBottom, tabTop = tab:GetBottom(), tab:GetTop()
                    if tabLeft and tabRight and tabBottom and tabTop then
                        tabLeft, tabRight, tabBottom, tabTop =
                            self:GetUIParentNormalizedBounds(
                                tab, tabLeft, tabRight, tabBottom, tabTop
                            )
                        left = not left and tabLeft or math.min(left, tabLeft)
                        right = not right and tabRight or math.max(right, tabRight)
                        bottom = not bottom and tabBottom or math.min(bottom, tabBottom)
                        top = not top and tabTop or math.max(top, tabTop)
                    end
                end
            end
        end
        if left then return left, right, bottom, top end
    end

    local target = element.target
    if not target or (target.IsShown and not target:IsShown()) then return end
    if not target.GetLeft then return end
    return self:GetUIParentNormalizedBounds(target)
end

function NSkin:NotifySkinningElementBoundsChanged(elementID)
    local element = skinningElements[elementID]
    if not element then return false end
    FireComponentCallback("SkinningElementBoundsChanged", element)
    return true
end

function NSkin:GetTabGroup(groupID)
    return tabGroups[groupID]
end

function NSkin:GetTabGroupPlacement(groupID)
    local group = tabGroups[groupID]
    if group and type(group.getPlacement) == "function" then
        return group.getPlacement(group)
    end
    return self:GetTabPlacement()
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
        "tab", group.appearanceWindowID or group.module, group.id)
    options.spacing = tonumber(tabStyle and tabStyle.spacing) or self:GetTabSpacing()
    options.placement = placement
    local applied
    if group.container and group.container.MarkDirty then
        applied = self:LayoutTabSystem(group.container, options) == true
    else
        applied = self:LayoutTabGroup(group.tabs, options) == true
    end
    local tabs = group.container and group.container.tabs or group.tabs
    if applied and type(tabs) == "table" then
        for i = 1, #tabs do
            local tab = tabs[i]
            if tab then
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
        return false
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
