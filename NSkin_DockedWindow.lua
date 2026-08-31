local _, NSkin = ...

local RESET_CONFIRMATION_DIALOG = "NSKIN_CONFIRM_INHERITED_RESET"
local state

local function CreateLabel(parent, text, point, relativeTo, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    label:SetText(text)
    label:SetTextColor(1, 1, 1, 1)
    return label
end

local function CreateButton(parent, text, width, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 60, 22)
    NSkin:SkinFlatButton(button, text, nil, nil, 12)
    button:SetScript("OnClick", callback)
    return button
end


local function ResizeInspector(view, extraHeight)
    local inspector = state.inspector
    local contentHeight = (view and view:GetHeight() or 1) + (extraHeight or 0)
    local screenLimit = (UIParent:GetHeight() or 768) - 40
    local anchoredLimit = (inspector:GetTop() or screenLimit) - 20
    local maximumHeight = math.max(122, math.min(screenLimit, anchoredLimit))
    local inspectorHeight = NSkin:SnapToPhysicalPixel(inspector,
        math.max(122, math.min(contentHeight + 59, maximumHeight)))
    local snappedContentHeight = NSkin:SnapToPhysicalPixel(
        state.scrollChild, math.max(1, contentHeight))
    inspector:SetHeight(inspectorHeight)
    state.scrollChild:SetHeight(snappedContentHeight)
    if state.scrollFrame.UpdateScrollChildRect then
        state.scrollFrame:UpdateScrollChildRect()
    end
    local range = state.scrollFrame:GetVerticalScrollRange() or 0
    if contentHeight + 59 <= maximumHeight then
        state.scrollFrame:SetVerticalScroll(0)
    elseif state.scrollFrame:GetVerticalScroll() > range then
        state.scrollFrame:SetVerticalScroll(range)
    end
end

local RefreshInspector

local function SnapInspectorOffset(value)
    return NSkin:SnapToPhysicalPixel(state.scrollChild, value)
end

local function SetInspectorTextWhite(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            region:SetTextColor(1, 1, 1, 1)
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        SetInspectorTextWhite(child)
    end
end

local function IsInlineEditorDefinition(definition)
    if type(definition) ~= "table" then return false end
    if definition.presentation ~= nil then
        return definition.presentation == "INLINE"
    end
    if definition.inline ~= nil then return definition.inline == true end
    return definition.category == "POSITION" or definition.category == "LAYOUT"
end

local function LoadEditorOptions(element)
    for _, view in pairs(state.optionViews) do
        view:SetContext(nil)
        view:Hide()
    end
    for i = 1, #state.editorSections do
        local section = state.editorSections[i]
        section:Hide()
    end

    local editorOptions = element and element.editorOptions
    if not editorOptions then
        ResizeInspector(nil)
        return
    end
    local groups
    if type(editorOptions) == "string" then
        groups = { { id = editorOptions } }
    elseif type(editorOptions) == "table" then
        groups = editorOptions
    end
    if not groups or #groups == 0 then
        ResizeInspector(nil)
        return
    end

    local y = SnapInspectorOffset(8)
    local sectionIndex = 0
    for i = 1, #groups do
        local definition = groups[i]
        local label = type(definition) == "table" and definition.label
        local id = type(definition) == "table" and definition.id or definition
        local inline = IsInlineEditorDefinition(definition)
        if type(id) == "string" and inline then
            local view = state.optionViews[id]
            if not view then
                view = NSkin:CreateOptionGroupView(
                    state.scrollChild, id, "COMPACT", element)
                state.optionViews[id] = view
            else
                view:SetContext(element)
            end
            if view then
                view:ClearAllPoints()
                view:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT",
                    SnapInspectorOffset(8), -SnapInspectorOffset(y))
                view:Show()
                y = SnapInspectorOffset(y + view:GetHeight() - 1)
            end
        end
    end

    for i = 1, #groups do
        local definition = groups[i]
        local label = type(definition) == "table" and definition.label
        local id = type(definition) == "table" and definition.id or definition
        local inline = IsInlineEditorDefinition(definition)
        if type(id) == "string" and not inline then
            sectionIndex = sectionIndex + 1
            local section = state.editorSections[sectionIndex]
            if not section then
                section = CreateFrame("Button", nil, state.scrollChild)
                section:SetHeight(48)
                section.label = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                section.label:SetPoint("LEFT", section, "LEFT", 12, 0)
                section.label:SetTextColor(1, 1, 1, 1)
                section.icon = section:CreateTexture(nil, "OVERLAY")
                section.icon:SetSize(18, 18)
                section.icon:SetPoint("RIGHT", section, "RIGHT", -12, 0)
                section.icon:SetTexture(
                    "Interface\\AddOns\\NSkin\\Media\\angle-small-down.png")
                section.reset = CreateFrame("Button", nil, section)
                section.reset:SetSize(24, 24)
                section.reset:SetPoint("RIGHT", section.icon, "LEFT", -4, 0)
                section.reset.icon = section.reset:CreateTexture(nil, "ARTWORK")
                section.reset.icon:SetSize(16, 16)
                section.reset.icon:SetPoint("CENTER")
                section.reset.icon:SetTexture(
                    "Interface\\AddOns\\NSkin\\Media\\rotate-right.png")
                section.reset:SetScript("OnClick", function(self)
                    if self.optionGroupID and self.context then
                        StaticPopup_Show(RESET_CONFIRMATION_DIALOG,
                            self.sectionLabel or "these options", nil, {
                                id = self.optionGroupID,
                                context = self.context,
                            })
                    end
                end)
                section.reset:SetScript("OnEnter", function(self)
                    self.icon:SetVertexColor(unpack(NSkin:GetAccentColor()))
                    if GameTooltip then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(self.tooltip or "Reset to window defaults")
                        GameTooltip:Show()
                    end
                end)
                section.reset:SetScript("OnLeave", function(self)
                    self.icon:SetVertexColor(1, 1, 1, 1)
                    if GameTooltip then GameTooltip:Hide() end
                end)
                NSkin:CreateFlatBackground(section, nil,
                    { 0, 0, 0, 0 }, NSkin:GetAccentColor())
                section:SetScript("OnClick", function(self)
                    state.expandedEditorSections[self.sectionKey] =
                        not state.expandedEditorSections[self.sectionKey]
                    RefreshInspector()
                end)
                state.editorSections[sectionIndex] = section
            end
            local key = element.id .. "\031" .. id
            local expanded = state.expandedEditorSections[key] == true
            section:SetHeight(SnapInspectorOffset(48))
            section.sectionKey = key
            local optionDefinition = NSkin:GetOptionGroupDefinition(id)
            local hasInheritedReset = optionDefinition
                and optionDefinition.inheritedReset == true
            section.reset.optionGroupID = id
            section.reset.context = element
            section.reset.sectionLabel = type(definition) == "table"
                and (definition.label or id) or id
            section.reset.tooltip = optionDefinition
                and optionDefinition.inheritedResetLabel
            section.reset:SetShown(hasInheritedReset)
            section.label:SetText(type(definition) == "table"
                and (definition.label or id) or "Options")
            section.icon:SetRotation(expanded and math.pi or 0)
            NSkin:SetPixelBorderColor(
                NSkin:GetPixelBorder(section, "NSkinFlatBackgroundBorder"),
                unpack(NSkin:GetAccentColor()))
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT", 0,
                -SnapInspectorOffset(y))
            section:SetPoint("RIGHT", state.scrollChild, "RIGHT", 0, 0)
            section:Show()
            y = SnapInspectorOffset(y + 47)

            if expanded then
                local view = state.optionViews[id]
                if not view then
                    view = NSkin:CreateOptionGroupView(
                        state.scrollChild, id, "COMPACT", element)
                    state.optionViews[id] = view
                else
                    view:SetContext(element)
                end
                if view then
                    view:ClearAllPoints()
                    view:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT",
                        SnapInspectorOffset(8), -SnapInspectorOffset(y))
                    view:Show()
                    y = SnapInspectorOffset(y + view:GetHeight() - 1)
                end
            end
        end
    end
    ResizeInspector(nil, y)
end

RefreshInspector = function()
    if not state then return end
    local element = state.selectedElement
    state.inspector.selection:SetText(
        element and ("Selected: " .. (element.label or element.id)) or "Select an element"
    )
    LoadEditorOptions(element)
    NSkin:ApplyGlobalTypography(state.inspector)
    SetInspectorTextWhite(state.inspector)
    NSkin:ResnapAllPixelBorders()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if state then
                ResizeInspector(nil,
                    math.max(0, (state.scrollChild:GetHeight() or 1) - 1))
                NSkin:ResnapAllPixelBorders()
            end
        end)
    end
end




local DockedWindow = {}
DockedWindow.__index = DockedWindow

function DockedWindow:Refresh(element)
    state.selectedElement = element
    RefreshInspector()
end

function DockedWindow:Dock(window)
    local inspector = state.inspector
    inspector:ClearAllPoints()
    if not window then
        inspector:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        return
    end
    local screenRight = UIParent:GetRight() or GetScreenWidth()
    local _, windowRight = NSkin:GetUIParentNormalizedBounds(window)
    if screenRight - (windowRight or 0) >= inspector:GetWidth() + 12 then
        inspector:SetPoint("TOPLEFT", window, "TOPRIGHT", 8, 0)
    else
        inspector:SetPoint("TOPRIGHT", window, "TOPLEFT", -8, 0)
    end
end

function DockedWindow:ResetScroll()
    state.scrollFrame:SetVerticalScroll(0)
end

function DockedWindow:RefreshAppearance()
    NSkin:SkinWindow(state.inspector)
    NSkin:SkinWindowHeader(state.inspector)
    NSkin:ApplyGlobalTypography(state.inspector)
    SetInspectorTextWhite(state.inspector)
    if state.gridToggle and state.gridToggle.RefreshState then
        state.gridToggle:RefreshState()
    end
end

function NSkin:CreateDockedWindow(owner)
    state = owner
    state.optionViews = state.optionViews or {}
    state.editorSections = state.editorSections or {}
    state.expandedEditorSections = state.expandedEditorSections or {}
    if not StaticPopupDialogs[RESET_CONFIRMATION_DIALOG] then
        StaticPopupDialogs[RESET_CONFIRMATION_DIALOG] = {
            text = "Reset %s to window defaults?",
            button1 = YES,
            button2 = NO,
            OnAccept = function(_, data)
                if data and data.id and data.context then
                    NSkin:ResetOptionGroup(data.id, data.context)
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    local inspector = CreateFrame("Frame", nil, UIParent)
    inspector:SetSize(520, 130)
    inspector:SetFrameStrata("DIALOG")
    NSkin:SkinWindow(inspector)
    NSkin:SkinWindowHeader(inspector)
    CreateLabel(inspector, "Skinning Mode", "TOPLEFT", inspector, "TOPLEFT", 12, -5)
    local close = CreateButton(inspector, "x", 22, function()
        NSkin:SetSkinningModeEnabled(false)
    end)
    close:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", 0, 0)
    local gridToggle = CreateFrame("Button", nil, inspector)
    gridToggle:SetSize(22, 22)
    gridToggle:SetPoint("RIGHT", close, "LEFT", -4, 0)
    gridToggle.icon = gridToggle:CreateTexture(nil, "ARTWORK")
    gridToggle.icon:SetSize(16, 16)
    gridToggle.icon:SetPoint("CENTER")
    gridToggle.icon:SetTexture("Interface\\AddOns\\NSkin\\Media\\grid-alt.png")
    local function RefreshGridToggle()
        gridToggle.icon:SetVertexColor(unpack(
            NSkin:IsCompactGridDebugEnabled() and NSkin:GetAccentColor()
                or { 1, 1, 1, 1 }))
    end
    gridToggle.RefreshState = RefreshGridToggle
    gridToggle:SetScript("OnClick", function()
        NSkin:SetCompactGridDebugEnabled(
            not NSkin:IsCompactGridDebugEnabled())
        RefreshGridToggle()
    end)
    gridToggle:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(unpack(NSkin:GetAccentColor()))
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Toggle layout grid")
            GameTooltip:Show()
        end
    end)
    gridToggle:SetScript("OnLeave", function()
        RefreshGridToggle()
        if GameTooltip then GameTooltip:Hide() end
    end)
    RefreshGridToggle()
    state.gridToggle = gridToggle
    inspector.selection = CreateLabel(
        inspector, "Select an element", "TOPLEFT", inspector, "TOPLEFT", 12, -34
    )
    state.inspector = inspector

    local scrollFrame = CreateFrame("ScrollFrame", nil, inspector)
    scrollFrame:SetPoint("TOPLEFT", inspector, "TOPLEFT", 1, -58)
    scrollFrame:SetPoint("BOTTOMRIGHT", inspector, "BOTTOMRIGHT", -1, 1)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local nextValue = self:GetVerticalScroll() - delta * 36
        self:SetVerticalScroll(math.max(0, math.min(range, nextValue)))
    end)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(518, 1)
    scrollFrame:SetScrollChild(scrollChild)
    state.scrollFrame = scrollFrame
    state.scrollChild = scrollChild


    inspector:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    inspector:Hide()
    local docked = setmetatable({ frame = inspector }, DockedWindow)
    state.dockedWindow = docked
    return docked
end
