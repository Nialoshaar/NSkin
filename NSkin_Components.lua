local _, NSkin = ...

local COMPONENT_STATE = "components"
local tabGroups = {}
local skinningElements = {}
local componentCallbacks = {}

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
    borderColor = borderColor or self:GetBorderAccentColor()

    local background = self:GetFlatBackground(button)
    if not background then
        self:HideTextureRegions(button)
    end

    self:CreateFlatBackground(button, nil, backgroundColor, borderColor)
    self:CreateFlatButtonGlow(button, style.hoverAlpha)
    local text = self:SetFlatButtonLabel(button, label, labelSize, labelOffsetX, labelOffsetY)
    if text then text:SetTextColor(unpack(style.text)) end
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
        frame, "NSkinWindowBorder", style.borderSize, self:GetBorderAccentColor(), false, anchor
    )
    self:SetPixelBorderSize(border, style.borderSize)
    self:SetPixelBorderColor(border, unpack(self:GetBorderAccentColor()))
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
        background = self:CreateFlatBackground(tab, nil, style.background, self:GetBorderAccentColor())
    end

    self:CreateFlatButtonGlow(tab, style.hoverAlpha)
    self:SetPixelBorderColor(self:GetPixelBorder(tab, "NSkinFlatBackgroundBorder"), unpack(self:GetBorderAccentColor()))
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

function NSkin:LayoutWindowElement(element, placement)
    local target = element and element.target
    local window = element and element.window
    if not target or not window or type(placement) ~= "table"
        or not target.ClearAllPoints or not target.SetPoint
        or (target.IsProtected and target:IsProtected())
        or (_G.InCombatLockdown and _G.InCombatLockdown())
    then
        return false
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
    self:NotifySkinningElementBoundsChanged(element.id)
    return true
end

function NSkin:GetSkinningElementBounds(element)
    if not element then return end
    if type(element.getHighlightBounds) == "function" then
        local ok, left, right, bottom, top = pcall(element.getHighlightBounds, element)
        if ok and left and right and bottom and top then return left, right, bottom, top end
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
    return target:GetLeft(), target:GetRight(), target:GetBottom(), target:GetTop()
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

function NSkin:ApplyTabGroupLayout(groupID)
    local group = tabGroups[groupID]
    if not group or (_G.InCombatLockdown and _G.InCombatLockdown()) then return false end
    if type(group.hasPlacement) == "function" and not group.hasPlacement(group) then
        return false
    end

    local options = {
        owner = group.window,
        edge = group.edge,
        orientation = group.orientation,
        spacing = self:GetTabSpacing(),
        placement = self:GetTabGroupPlacement(groupID),
    }
    local applied
    if group.container and group.container.MarkDirty then
        applied = self:LayoutTabSystem(group.container, options) == true
    else
        applied = self:LayoutTabGroup(group.tabs, options) == true
    end
    if applied then FireComponentCallback("TabGroupLayoutApplied", group) end
    return applied
end

function NSkin:RefreshRegisteredTabGroups()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    for groupID in pairs(tabGroups) do
        self:ApplyTabGroupLayout(groupID)
    end
    return true
end
