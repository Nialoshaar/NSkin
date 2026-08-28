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
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetSize(options.width or 280, options.height or 18)
    slider:SetMinMaxValues(options.min or 0, options.max or 100)
    slider:SetValueStep(options.step or 1)
    slider:SetObeyStepOnDrag(options.obeyStep ~= false)
    if slider.Low then slider.Low:SetText(tostring(options.min or 0)) end
    if slider.High then slider.High:SetText(tostring(options.max or 100)) end
    if slider.Text then slider.Text:SetText(options.text or "") end
    if type(options.onValueChanged) == "function" then
        slider:SetScript("OnValueChanged", options.onValueChanged)
    end
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
    borderColor = borderColor or self:GetSharedBorderColor()

    local background = self:GetFlatBackground(button)
    if not background then
        self:HideTextureRegions(button)
    end

    self:CreateFlatBackground(button, nil, backgroundColor, borderColor)
    self:CreateFlatButtonGlow(button, style.hoverAlpha)
    local text = self:SetFlatButtonLabel(button, label, labelSize, labelOffsetX, labelOffsetY)
    if text then text:SetTextColor(unpack(style.text)) end
end

function NSkin:SkinSearchBox(searchBox)
    if not searchBox then return end

    local searchIcon = searchBox.SearchIcon or searchBox.searchIcon
    if not self:GetFlatBackground(searchBox) then
        self:HideTextureRegions(searchBox, searchIcon)
    end
    local style = self:GetStyle("searchBox")
    self:CreateFlatBackground(
        searchBox, nil, style.background, self:GetSharedBorderColor()
    )
    if searchBox.SetTextColor then searchBox:SetTextColor(unpack(style.text)) end
    local instructions = searchBox.Instructions or searchBox.instructions
    if instructions then
        instructions:SetTextColor(unpack(style.placeholderText))
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

function NSkin:SkinWindow(frame, backgroundAnchor)
    if not frame then return nil end

    local style = self:GetStyle("window")
    local anchor = backgroundAnchor or frame
    local data = self:GetSkinData(frame, COMPONENT_STATE)
    local background = data.windowBackground
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        background:SetAllPoints(anchor)
        data.windowBackground = background
    end
    background:SetColorTexture(unpack(style.background))

    local border = self:CreatePixelBorder(
        frame, "NSkinWindowBorder", style.borderSize, self:GetWindowBorderColor(), false, anchor
    )
    self:SetPixelBorderSize(border, style.borderSize)
    self:SetPixelBorderColor(border, unpack(self:GetWindowBorderColor()))
    return background, border
end

function NSkin:SkinWindowHeader(frame)
    if not frame then return nil end

    local style = self:GetStyle("window").header
    local data = self:GetSkinData(frame, COMPONENT_STATE)
    local background = data.windowHeaderBackground
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
        background:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        background:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        data.windowHeaderBackground = background
    end
    background:SetHeight(style.height)
    background:SetColorTexture(unpack(style.background))
    return background
end

-- Tab Skinning

local function RefreshTabSelection(tab, selected)
    NSkin:SkinTab(tab, selected)
end

function NSkin:SkinTab(tab, selected, style)
    if not tab then return end
    style = style or self:GetStyle("tab")

    local background = self:GetFlatBackground(tab)
    if not background then
        if type(tab.SetTabSelected) == "function" and _G.hooksecurefunc then
            _G.hooksecurefunc(tab, "SetTabSelected", RefreshTabSelection)
        end
        self:HideTextureRegions(tab)
        background = self:CreateFlatBackground(tab, nil, style.background,
            self:GetSharedBorderColor())
    end

    self:CreateFlatButtonGlow(tab, style.hoverAlpha)
    self:SetPixelBorderColor(self:GetPixelBorder(tab, "NSkinFlatBackgroundBorder"),
        unpack(self:GetSharedBorderColor()))
    background:SetColorTexture(unpack(
        selected and style.selectedBackground or style.background
    ))
    if tab.Text then tab.Text:SetTextColor(unpack(style.text)) end
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

function NSkin:SkinTabSystem(tabSystem, style)
    if not tabSystem or not tabSystem.tabs then return end
    style = style or self:GetStyle("tab")

    for i = 1, #tabSystem.tabs do
        local tab = tabSystem.tabs[i]
        local selected = tab and tab.IsSelected and tab:IsSelected()
        self:SkinTab(tab, selected, style)
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
    options.spacing = self:GetTabSpacing()
    options.placement = placement
    local applied
    if group.container and group.container.MarkDirty then
        applied = self:LayoutTabSystem(group.container, options) == true
    else
        applied = self:LayoutTabGroup(group.tabs, options) == true
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
