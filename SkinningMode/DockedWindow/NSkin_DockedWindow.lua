local _, NSkin = ...

local RESET_CONFIRMATION_DIALOG = "NSKIN_CONFIRM_INHERITED_RESET"
local RESET_ELEMENT_DIALOG = "NSKIN_CONFIRM_ELEMENT_RESET"
local CLEAR_OVERRIDES_DIALOG = "NSKIN_CONFIRM_CLEAR_OVERRIDES"
local state
local INSPECTOR_THEME = {
    background = { 0.035, 0.051, 0.071, 1 },
    panel = { 0.075, 0.110, 0.149, 1 },
    input = { 0.047, 0.075, 0.106, 1 },
    border = { 0.157, 0.220, 0.290, 1 },
    text = { 0.83, 0.91, 0.98, 1 },
    muted = { 0.49, 0.61, 0.73, 1 },
    accent = { 0.05, 0.76, 0.96, 1 },
}

local function InspectorFont(label, size, color)
    local font = GameFontNormal:GetFont()
    label:SetFont(font, size, "")
    label:SetTextColor(unpack(color or INSPECTOR_THEME.text))
end

local function InspectorSurface(frame, color, bordered)
    local background = NSkin:GetFlatBackground(frame)
        or NSkin:CreateFlatBackground(frame, nil, color, INSPECTOR_THEME.border)
    NSkin:SetOwnedTextureColor(background, unpack(color))
    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(frame, "NSkinFlatBackgroundBorder"),
        unpack(INSPECTOR_THEME.border))
    NSkin:SetPixelBorderShown(NSkin:GetPixelBorder(frame, "NSkinFlatBackgroundBorder"), bordered == true)
end

local function RefreshInspectorScrollBar()
    local bar = state.inspector.scrollBar
    if not bar then return end
    local range = state.scrollFrame:GetVerticalScrollRange() or 0
    bar.syncing = true
    bar:SetMinMaxValues(0, math.max(1, range))
    bar:SetValue(state.scrollFrame:GetVerticalScroll())
    bar.syncing = nil
    bar:SetShown(range > 0)
end

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
    local headerHeight = state.inspectorHeaderHeight or 59
    local minimumHeight = headerHeight + 63
    local maximumHeight = math.max(
        minimumHeight, math.min(screenLimit, anchoredLimit))
    local inspectorHeight = NSkin:SnapToPhysicalPixel(inspector,
        math.max(minimumHeight, math.min(704, maximumHeight)))
    local snappedContentHeight = NSkin:SnapToPhysicalPixel(
        state.scrollChild, math.max(1, contentHeight))
    inspector:SetHeight(inspectorHeight)
    state.scrollChild:SetHeight(snappedContentHeight)
    if state.scrollFrame.UpdateScrollChildRect then
        state.scrollFrame:UpdateScrollChildRect()
    end
    local range = state.scrollFrame:GetVerticalScrollRange() or 0
    if contentHeight + headerHeight <= maximumHeight then
        state.scrollFrame:SetVerticalScroll(0)
    elseif state.scrollFrame:GetVerticalScroll() > range then
        state.scrollFrame:SetVerticalScroll(range)
    end
    RefreshInspectorScrollBar()
end

local RefreshInspector
local LayoutContextualInspector
local RefreshContextualPairSource
local RefreshContextualSectionPresentation
local RefreshDebugLauncher
local IsContextualInspectorElement
local IsContextualInspectorMember

local function ResolveEditorContext(definition, element)
    if definition.contextID then
        return NSkin:GetSkinningElement(definition.contextID)
    end
    return definition.context or element
end

local function GetContextualCompositeMember(element)
    if not element then return nil end
    local member = state.focusedCompositeMemberID
        and NSkin:GetCompositeMember(
            element, state.focusedCompositeMemberID)
    if member then return member end
    local composition = element.composition
    for _, candidate in ipairs(
        composition and composition.members or {})
    do
        if candidate.editorSurface == true then return candidate end
    end
    if IsContextualInspectorElement and IsContextualInspectorElement(element) then
        for _, candidate in ipairs(composition and composition.members or {}) do
            if candidate.contextualInspector ~= false then return candidate end
        end
    end
    return nil
end

local function ResetCompositeSelection(element)
    local member = GetContextualCompositeMember(element)
    if not member then return false end
    local options = NSkin:GetCompositeMemberEditorOptions(
        element, member)
    local changed

    local function ResetDefinitions(definitions, inheritedContext)
        for _, definition in ipairs(definitions or {}) do
            if type(definition) == "table"
                and definition.presentation == "NAV_TABS"
                and type(definition.tabs) == "table"
            then
                local navigationContext =
                    ResolveEditorContext(definition, inheritedContext)
                for _, tab in ipairs(definition.tabs) do
                    local tabContext = type(tab) == "table"
                        and ResolveEditorContext(tab, navigationContext)
                        or navigationContext
                    if type(tab) == "table" then
                        ResetDefinitions(tab.groups, tabContext)
                        ResetDefinitions(tab.tabs, tabContext)
                    end
                end
            else
                local id = type(definition) == "table"
                    and definition.id or definition
                local context = type(definition) == "table"
                    and ResolveEditorContext(
                        definition, inheritedContext)
                    or inheritedContext
                if type(id) == "string" and context then
                    changed = NSkin:ResetOptionGroup(
                        id, context) or changed
                end
            end
        end
    end

    ResetDefinitions(options, element)
    NSkin:NotifySkinningElementBoundsChanged(element.id)
    NSkin:ResnapPixelBordersForElement(element)
    return changed == true
end

local function ResetElementCustomizations(element)
    if not element then return false end
    local composition = element.composition
    local resetGroups = {}
    local function CollectResetGroups(definitions, context)
        for _, definition in ipairs(definitions or {}) do
            local id = type(definition) == "table"
                and definition.id or definition
            if type(definition) == "table"
                and type(definition.tabs) == "table"
            then
                for _, tab in ipairs(definition.tabs) do
                    local tabContext = ResolveEditorContext(tab, context)
                    if type(tab.tabs) == "table" then
                        CollectResetGroups({
                            {
                                id = tostring(definition.id)
                                    .. "." .. tostring(tab.id),
                                tabs = tab.tabs,
                            },
                        }, tabContext)
                    end
                    for _, child in ipairs(tab.groups or {}) do
                        local childID = type(child) == "table"
                            and child.id or child
                        local childContext = type(child) == "table"
                            and ResolveEditorContext(child, tabContext)
                            or tabContext
                        if type(childID) == "string" and childContext then
                            resetGroups[childID] = childContext
                        end
                    end
                end
            elseif type(id) == "string" then
                resetGroups[id] = type(definition) == "table"
                    and ResolveEditorContext(definition, context) or context
            end
        end
    end

    local editorOptions = NSkin:GetCompositionEditorOptions(element)
    if type(editorOptions) == "string" then
        resetGroups[editorOptions] = element
    elseif type(editorOptions) == "table" then
        CollectResetGroups(editorOptions, element)
    end
    for id, context in pairs(resetGroups) do
        NSkin:ResetOptionGroup(id, context)
    end

    -- Clear anything not represented by the visible compact subsets too.
    NSkin:ResetElementAppearanceOverride(element.id)
    if type(element.resetPlacement) == "function" then
        element.resetPlacement(element)
    elseif type(element.restoreGeometry) == "function" then
        element.restoreGeometry(element)
    end
    if element.kind == "TAB_GROUP" then
        NSkin:RestoreTabGroupOriginalPlacement(element.id)
    end
    NSkin:NotifySkinningElementBoundsChanged(element.id)
    NSkin:ResnapPixelBordersForElement(element)
    return true
end

local function SnapInspectorOffset(value)
    return NSkin:SnapToPhysicalPixel(state.scrollChild, value)
end

local function ApplyInspectorTextStyle(frame)
    if not frame then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            InspectorFont(region, 10)
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        ApplyInspectorTextStyle(child)
    end
end

local function IsInlineEditorDefinition(definition)
    return type(definition) == "table"
        and definition.contextualInline == true
end

local function GetPreferredEditorSectionID(element, memberID)
    if not element then return nil end
    local member = memberID and NSkin:GetCompositeMember(element, memberID)
    if member then
        local component = member.kind
            and NSkin:GetSharedElementType(member.kind)
        if component then
            for _, definition in ipairs(
                NSkin:CreateEditorOptionsPreset(component.editorPreset) or {})
            do
                local id = type(definition) == "table"
                    and definition.id or definition
                local category = type(definition) == "table"
                    and definition.category
                if type(id) == "string" and id ~= "shared.movable"
                    and category ~= "POSITION" and category ~= "LAYOUT"
                then
                    return id
                end
            end
        end
    end
    local composition = element.composition
    return composition and composition.primaryEditorOptionID
end

local function GetDockMemberLabel(element, member)
    if not element or not member then return nil end
    local composition = element.composition
    if not composition or composition.mode ~= "COMPOSITE" then
        return element.label or element.id
    end
    if member.editorSurface == true then return "Surface" end

    local memberLabel = member.editorLabel
    if not memberLabel then
        local labels = composition.memberEditorLabels
        memberLabel = labels
            and (labels[member.id] or labels[member.kind])
    end
    memberLabel = memberLabel or member.label or member.id

    local groupLabel = composition.groupLabel
        or composition.editorLabel or element.label or element.id
    -- Member labels historically often embedded the Composite label
    -- ("Dungeons & Raids Cards Text"). The header already provides the
    -- group, so normalize that globally to "Group - Text".
    if type(groupLabel) == "string" and type(memberLabel) == "string"
        and #memberLabel >= #groupLabel
        and memberLabel:sub(1, #groupLabel):lower()
            == groupLabel:lower()
    then
        local remainder = memberLabel:sub(#groupLabel + 1)
            :gsub("^%s*[-:–—]?%s*", "")
        if remainder ~= "" then memberLabel = remainder end
    end
    return memberLabel
end

local function GetDockContainerLabel(element)
    local label = tostring(element.label or element.id)
    if label:lower():match("%s+group$") then return label end
    return label .. " Group"
end

local function GetDockSelectionLabel(element)
    if not element then return nil end
    local parent = NSkin:GetCompositionContainerParent(element)
    if parent then
        local families = NSkin:GetContainerCompositeFamilies(parent) or {}
        if #families > 1 then
            return GetDockContainerLabel(parent) .. " > "
                .. (NSkin:GetCompositeFamilyLabel(element)
                    or element.label or element.id)
        end
        return GetDockContainerLabel(parent)
    end
    local composition = element.composition
    if composition and composition.mode == "CONTAINER" then
        return GetDockContainerLabel(element)
    end
    if composition and composition.mode == "COMPOSITE" then
        return composition.groupLabel
            or composition.editorLabel or element.label or element.id
    end
    return element.label or element.id
end

local function GetCompositeDockMemberFamilyKey(member)
    if not member then return nil end
    if type(member.editorTabID) == "string"
        and member.editorTabID ~= ""
    then
        return member.editorTabID
    end

    local owner = member.appearanceParentID
        or member.appearanceID or member.id
    local prefix = member.editorSurface == true
        and "SURFACE" or tostring(member.kind or "MEMBER")
    return prefix .. "\031" .. tostring(owner)
end

local function GetCompositeDockMembers(element, includeContainer)
    local composition = element and element.composition
    if not composition or composition.mode ~= "COMPOSITE" then return {} end

    local result, seen = {}, {}
    if includeContainer then
        local parent = NSkin:GetCompositionContainerParent(element)
        if parent then
            result[#result + 1] = {
                container = true,
                label = GetDockContainerLabel(parent),
                familyKey = "__CONTAINER",
                element = parent,
            }
        end
    end
    for _, member in ipairs(composition.members or {}) do
        local targets = NSkin:GetCompositionMemberTargets(
            element, member, false)
        local familyKey = #targets > 0
            and GetCompositeDockMemberFamilyKey(member) or nil
        if familyKey and not seen[familyKey] then
            seen[familyKey] = true
            result[#result + 1] = {
                element = element,
                member = member,
                familyKey = familyKey,
            }
        end
    end

    table.sort(result, function(left, right)
        if left.container ~= right.container then
            return left.container == true
        end
        if left.container then return false end
        local leftSurface = left.member.editorSurface == true
        local rightSurface = right.member.editorSurface == true
        if leftSurface ~= rightSurface then return leftSurface end
        return false
    end)
    return result
end

local function GetElementDockNavigation(element)
    if element and element.contextualInspector == true
        and element.kind == "SCROLLBAR"
    then return nil end
    local options = element and NSkin:GetCompositionEditorOptions(element)
    if type(options) ~= "table" then return nil end
    for _, definition in ipairs(options) do
        if type(definition) == "table"
            and definition.presentation == "NAV_TABS"
            and type(definition.tabs) == "table"
            and #definition.tabs > 0
        then
            return definition
        end
    end
    return nil
end

local function GetDirectChildDockMembers(element, parent)
    local definition = GetElementDockNavigation(element)
    if not definition or not parent then return nil end

    local key = element.id .. "\031" .. tostring(definition.id)
    local selected = math.min(
        state.selectedEditorSubtabs[key] or 1, #definition.tabs)
    state.selectedEditorSubtabs[key] = selected

    local result = {
        {
            container = true,
            label = GetDockContainerLabel(parent),
            familyKey = "__CONTAINER",
            element = parent,
        },
    }
    for index, tab in ipairs(definition.tabs) do
        result[#result + 1] = {
            editorNavigation = true,
            label = tab.label or tab.id,
            familyKey = "__EDITOR_NAV\031" .. tostring(tab.id),
            element = element,
            navigationKey = key,
            navigationIndex = index,
        }
    end
    return result, "__EDITOR_NAV\031"
        .. tostring(definition.tabs[selected].id)
end

local function GetContainerDockMembers(element)
    local composition = element and element.composition
    if not composition or composition.mode ~= "CONTAINER" then return {} end

    local families = NSkin:GetContainerCompositeFamilies(element) or {}
    local directChildren = {}
    for _, child in ipairs(NSkin:GetContainerChildren(element) or {}) do
        local childComposition = child.composition
        if not childComposition or childComposition.mode ~= "COMPOSITE" then
            directChildren[#directChildren + 1] = child
        end
    end
    if #families == 0 and #directChildren == 0 then return {} end

    local result = {
        {
            container = true,
            label = GetDockContainerLabel(element),
            familyKey = "__CONTAINER",
            element = element,
        },
    }

    if #families > 1 then
        for _, family in ipairs(families) do
            result[#result + 1] = {
                compositeFamily = true,
                label = family.label,
                familyKey = "__COMPOSITE_FAMILY\031" .. tostring(family.id),
                element = family.representative,
            }
        end
    elseif #families == 1 then
        local seen = {}
        for _, child in ipairs(families[1].elements or {}) do
            for _, entry in ipairs(GetCompositeDockMembers(child, false)) do
                if not seen[entry.familyKey] then
                    seen[entry.familyKey] = true
                    result[#result + 1] = entry
                end
            end
        end
    end

    for _, child in ipairs(directChildren) do
        result[#result + 1] = {
            directChild = true,
            label = child.composition and child.composition.mode == "CONTAINER"
                and GetDockContainerLabel(child)
                or child.containerDockLabel or child.label or child.id,
            familyKey = "__CHILD\031" .. tostring(child.id),
            element = child,
        }
    end
    return result
end

local function RefreshCompositeMemberTabs(element)
    local inspector = state.inspector
    local bar = inspector and inspector.memberTabs
    if not bar then return false end

    local composition = element and element.composition
    local parent = NSkin:GetCompositionContainerParent(element)
    local members, directChildSelectedKey
    if composition and composition.mode == "CONTAINER" then
        members = GetContainerDockMembers(element)
    elseif composition and composition.mode == "COMPOSITE" then
        members = GetCompositeDockMembers(element, true)
    elseif parent then
        members, directChildSelectedKey =
            GetDirectChildDockMembers(element, parent)
        members = members or GetContainerDockMembers(parent)
    else
        members = {}
    end
    if #members == 0 then
        bar:Hide()
        for _, button in ipairs(bar.buttons or {}) do button:Hide() end
        state.memberTabsShown = nil
        return false
    end

    local focused = GetContextualCompositeMember(element)
    local selectedFamilyKey
    if composition and composition.mode == "CONTAINER" then
        selectedFamilyKey = "__CONTAINER"
    elseif directChildSelectedKey then
        selectedFamilyKey = directChildSelectedKey
    elseif parent and (not composition or composition.mode ~= "COMPOSITE") then
        selectedFamilyKey = "__CHILD\031" .. tostring(element.id)
    else
        selectedFamilyKey = GetCompositeDockMemberFamilyKey(focused)
    end
    local totalWidth = math.max(1, (inspector:GetWidth() or 520) - 24)
    local buttonWidth = totalWidth / #members

    for index, entry in ipairs(members) do
        local member = entry.member
        local button = bar.buttons[index]
        if not button then
            button = CreateFrame("Button", nil, bar)
            button.label = button:CreateFontString(
                nil, "OVERLAY", "GameFontNormal")
            button.label:SetPoint("CENTER")
            -- SkinTab consumes the conventional Text field used by Blizzard
            -- tab buttons. Keep label as the Docked Window's local handle.
            button.Text = button.label
            button:SetScript("OnClick", function(self)
                if self.editorNavigationTab then
                    if self.navigationKey and self.navigationIndex then
                        state.selectedEditorSubtabs[self.navigationKey] =
                            self.navigationIndex
                        RefreshInspector()
                    end
                    return
                end
                if self.containerTab or self.compositeFamilyTab
                    or self.directChildTab
                then
                    if self.elementID and NSkin.SelectSkinningElement then
                        NSkin:SelectSkinningElement(self.elementID)
                    end
                    return
                end
                if not self.memberID or not self.elementID then return end
                NSkin:SelectSkinningCompositeMember(
                    self.elementID, self.memberID, nil)
            end)
            bar.buttons[index] = button
        end

        local selected = entry.familyKey == selectedFamilyKey
        button.containerTab = entry.container == true
        button.compositeFamilyTab = entry.compositeFamily == true
        button.directChildTab = entry.directChild == true
        button.editorNavigationTab = entry.editorNavigation == true
        button.navigationKey = entry.navigationKey
        button.navigationIndex = entry.navigationIndex
        button.memberID = member and member.id or nil
        button.elementID = entry.element and entry.element.id or nil
        button.familyKey = entry.familyKey
        button.label:SetText(entry.label
            or GetDockMemberLabel(entry.element or element, member)
            or (member and (member.label or member.id))
            or "Group")
        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT", bar, "TOPLEFT",
            (index - 1) * buttonWidth, 0)
        button:SetSize(buttonWidth, 24)
        NSkin:SkinTab(button, selected)
        button:Show()
    end
    for index = #members + 1, #(bar.buttons or {}) do
        bar.buttons[index]:Hide()
    end
    bar:Show()
    state.memberTabsShown = true
    return true
end

local GetValidatedFocusedRuntimeTarget

local function RefreshStateSelector(element, member)
    local inspector = state.inspector
    if not inspector then return end
    local states = member and member.states or nil
    local hasStates = states and #states > 0
    local exact = IsContextualInspectorMember(element, member)
        and state.contextualInspectorDetails[element.id .. "\031" .. member.id]
            == "__OVERRIDES"
    inspector.stateLabel:SetText(exact and "State: All states" or "State:")
    inspector.stateLabel:SetShown(hasStates == true)
    inspector.selection:Show()

    local stateY = state.contextualInspectorHeader
        and -71 or (state.memberTabsShown and -84 or -48)
    inspector.stateLabel:ClearAllPoints()
    inspector.stateLabel:SetPoint(
        "TOPLEFT", inspector, "TOPLEFT", 12, stateY)

    for _, button in ipairs(inspector.stateButtons or {}) do
        button:Hide()
    end
    if not hasStates or exact then return end

    local selectedState = NSkin:GetCompositeMemberEditorState(
        element, member)
    local definitions = {
        {
            id = "__ALL",
            label = member.editorStateBaseLabel or "All",
            allStates = true,
        },
    }
    for _, definition in ipairs(states) do
        definitions[#definitions + 1] = definition
    end

    local x = 58
    for index, definition in ipairs(definitions) do
        local button = inspector.stateButtons[index]
        if not button then
            button = CreateButton(inspector, "", 70, function(self)
                local currentElement = state.selectedElement
                local currentMember = currentElement
                    and state.focusedCompositeMemberID
                    and NSkin:GetCompositeMember(
                        currentElement, state.focusedCompositeMemberID)
                if not currentElement or not currentMember then return end
                local target = state.focusedCompositeRuntimeTarget
                if IsContextualInspectorMember(currentElement, currentMember) then
                    target = GetValidatedFocusedRuntimeTarget(
                        currentElement, currentMember)
                end
                NSkin:SetCompositeMemberEditorState(
                    currentElement, currentMember, self.stateID, target,
                    IsContextualInspectorMember(currentElement, currentMember)
                        or target ~= nil)
                if not (NSkin.RefreshSkinningCompositeMemberEditor
                    and NSkin:RefreshSkinningCompositeMemberEditor(
                        currentElement, currentMember.id))
                then
                    RefreshInspector()
                end
            end)
            inspector.stateButtons[index] = button
        end
        local label = definition.label or definition.id
        button.stateID = definition.id
        button:SetWidth(math.max(58, #tostring(label) * 7 + 18))
        NSkin:SkinFlatButton(button, label, nil, nil, 12)
        button:ClearAllPoints()
        button:SetPoint(
            "TOPLEFT", inspector, "TOPLEFT", x,
            state.contextualInspectorHeader
                and -68
                or (state.memberTabsShown and -81 or -45))
        local selected = definition.allStates == true
            and selectedState == nil
            or definition.id == selectedState
        button.inspectorSelected = selected
        button:SetAlpha(selected and 1 or 0.55)
        local fontString = button.GetFontString and button:GetFontString()
        if fontString then
            NSkin:SetFontStringColor(fontString,
                selected and NSkin:GetAccentColor()
                    or { 1, 1, 1, 1 })
        end
        button:SetScript("OnEnter", function(self)
            if self.stateID == "__ALL" and GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("All states")
                GameTooltip:AddLine(
                    "Edits the base appearance inherited by states unless overridden. State previews do not change Blizzard's checked state.",
                    1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            if GameTooltip then GameTooltip:Hide() end
        end)
        button:Show()
        x = x + button:GetWidth() + 4
    end
end

local function LayoutInspectorChrome(element, member)
    local inspector = state.inspector
    local hasStates = member and #(member.states or {}) > 0
    local headerHeight = hasStates and 212 or 166
    if not state.contextualInspectorHeader and state.memberTabsShown then headerHeight = headerHeight + 28 end
    state.inspectorHeaderHeight = headerHeight
    inspector.title:Show()
    InspectorFont(inspector.title, 14)
    inspector.title:SetText("NSkin")
    inspector.title:ClearAllPoints()
    inspector.title:SetPoint("LEFT", inspector.logo, "RIGHT", 8, 0)
    inspector.subtitle:Show()
    InspectorFont(inspector.subtitle, 9, INSPECTOR_THEME.muted)
    InspectorFont(inspector.editingLabel, 10, INSPECTOR_THEME.muted)
    InspectorFont(inspector.designLabel, 12, INSPECTOR_THEME.accent)
    state.inspectorDragRegion:SetHeight(38)
    local headerStyle = CopyTable(NSkin:GetStyle("window").header)
    headerStyle.height = 38
    headerStyle.showBackground, headerStyle.showBorder = false, false
    NSkin:SkinWindowHeader(inspector, headerStyle)
    inspector.selection:ClearAllPoints()
    inspector.selection:SetPoint("TOPLEFT", inspector, "TOPLEFT", 34, -54)
    inspector.selection:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -26, -54)
    inspector.memberPicker:ClearAllPoints()
    inspector.memberPicker:SetPoint("TOPLEFT", inspector, "TOPLEFT", 68, -91)
    inspector.memberPicker:SetSize(124, 28)
    InspectorSurface(inspector.memberPicker, INSPECTOR_THEME.input, true)
    local pickerBackground = NSkin:GetFlatBackground(inspector.memberPicker, "NSkinOptionsDropdown")
    if pickerBackground then NSkin:SetOwnedTextureColor(pickerBackground, unpack(INSPECTOR_THEME.input)) end
    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(inspector.memberPicker, "NSkinOptionsDropdownBorder"), unpack(INSPECTOR_THEME.border))
    local pickerText = inspector.memberPicker.text or inspector.memberPicker.Text
    if pickerText then InspectorFont(pickerText, 10) end
    if inspector.memberPicker.nskinArrow then
        inspector.memberPicker.nskinArrow:SetSize(10, 10)
        inspector.memberPicker.nskinArrow:SetVertexColor(unpack(INSPECTOR_THEME.muted))
    end
    inspector.editingLabel:SetShown(inspector.memberPicker:IsShown())
    inspector.contextScope:Hide()
    inspector.resetElement:ClearAllPoints()
    inspector.resetElement:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -24, -93)
    inspector.resetElement:SetSize(106, 24)
    InspectorSurface(inspector.resetElement, { 0, 0, 0, 0 }, false)
    local resetText = inspector.resetElement:GetFontString()
    if resetText then
        InspectorFont(resetText, 9, INSPECTOR_THEME.muted)
        resetText:ClearAllPoints()
        resetText:SetPoint("LEFT", inspector.resetElement, "LEFT", 19, 0)
        resetText:SetPoint("RIGHT", inspector.resetElement, "RIGHT", -2, 0)
        resetText:SetJustifyH("RIGHT")
    end
    inspector.addOverride:ClearAllPoints()
    inspector.addOverride:SetPoint("RIGHT", inspector.resetElement, "LEFT", -4, 0)
    inspector.addOverride:SetSize(20, 24)
    NSkin:SkinFlatButton(inspector.addOverride, "+", INSPECTOR_THEME.input, INSPECTOR_THEME.border, 11)
    inspector.stateLabel:ClearAllPoints()
    inspector.stateLabel:SetPoint("TOPLEFT", inspector, "TOPLEFT", 30, -139)
    inspector.stateLabel:SetText("State")
    InspectorFont(inspector.stateLabel, 10, INSPECTOR_THEME.muted)
    inspector.stateTrack:SetShown(hasStates and inspector.stateLabel:IsShown())
    inspector.stateTrack:ClearAllPoints()
    inspector.stateTrack:SetPoint("TOPLEFT", inspector, "TOPLEFT", 68, -133)
    inspector.stateTrack:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -24, -133)
    inspector.stateTrack:SetHeight(32)
    local shown = {}
    for _, button in ipairs(inspector.stateButtons) do
        if button:IsShown() then shown[#shown + 1] = button end
    end
    local buttonWidth = math.max(1, (inspector:GetWidth() - 98) / math.max(1, #shown))
    for index, button in ipairs(shown) do
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", inspector.stateTrack, "TOPLEFT", 3 + (index-1)*buttonWidth, -3)
        button:SetSize(buttonWidth, 26)
        button:SetAlpha(1)
        InspectorSurface(button, button.inspectorSelected and { 0.065, 0.20, 0.26, 1 }
            or { 0, 0, 0, 0 }, false)
        local label = button:GetFontString()
        if label then InspectorFont(label, 10, button.inspectorSelected and INSPECTOR_THEME.accent or INSPECTOR_THEME.muted) end
    end
    inspector.designBar:ClearAllPoints()
    inspector.designBar:SetPoint("TOPLEFT", inspector, "TOPLEFT", 12, -(headerHeight - 40))
    inspector.designBar:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -12, -(headerHeight - 40))
    inspector.designBar:SetHeight(40)
    inspector.breadcrumbLine:ClearAllPoints()
    inspector.breadcrumbLine:SetPoint("TOPLEFT", inspector.panel, "TOPLEFT", 0, -32)
    inspector.breadcrumbLine:SetPoint("TOPRIGHT", inspector.panel, "TOPRIGHT", 0, -32)
    if state.memberTabsShown then
        inspector.memberTabs:ClearAllPoints()
        inspector.memberTabs:SetPoint("TOPLEFT", inspector, "TOPLEFT", 24, -122)
        inspector.memberTabs:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -24, -122)
    end
    state.scrollFrame:ClearAllPoints()
    state.scrollFrame:SetPoint("TOPLEFT", inspector, "TOPLEFT", 14, -headerHeight)
    state.scrollFrame:SetPoint("BOTTOMRIGHT", inspector, "BOTTOMRIGHT", -26, 32)
    state.scrollChild:SetWidth(inspector:GetWidth() - 40)
    RefreshInspectorScrollBar()
end

local function RefreshHeaderActions(element)
    local inspector = state.inspector
    if not inspector then return end
    local composition = element and element.composition
    local composite = composition and composition.mode == "COMPOSITE"

    local overrideMember = composite
        and GetContextualCompositeMember(element) or nil
    inspector.addOverride:SetShown(
        composite == true
            and (not overrideMember
                or overrideMember.allowOverrides ~= false))
    inspector.resetElement:SetShown(element ~= nil)
    if composite then
        local member = GetContextualCompositeMember(element)
        local label = member and member.resetLabel or "Reset Surface"
        if not (member and member.resetLabel) then
            if member and member.kind == "ICON" then
                label = "Reset Icon"
            elseif member and member.kind == "CHECKBOX" then
                label = "Reset Checkbox"
            elseif member and member.kind == "TEXT" then
                label = "Reset Text"
            elseif member and member.kind == "BUTTON" and not member.editorSurface then
                label = "Reset Button"
            end
        end
        NSkin:SkinFlatButton(inspector.resetElement, label, nil, nil, 12)
        inspector.resetElement.resetLabel = label
    else
        NSkin:SkinFlatButton(
            inspector.resetElement, "Reset All", nil, nil, 12)
        inspector.resetElement.resetLabel = "Reset All"
    end

    local contextualOwner = IsContextualInspectorElement(element) and not composite
    if IsContextualInspectorMember(element, overrideMember) or contextualOwner then
        state.contextualInspectorHeader = true
        state.memberTabsShown = nil
        inspector.memberTabs:Hide()
        for _, button in ipairs(inspector.memberTabs.buttons or {}) do
            button:Hide()
        end

        local member = overrideMember
        inspector.title:Hide()
        local headerStyle = {}
        for key, value in pairs(NSkin:GetStyle("window").header) do
            headerStyle[key] = value
        end
        headerStyle.height = 0
        headerStyle.showBackground, headerStyle.showBorder = false, false
        NSkin:SkinWindowHeader(inspector, headerStyle)
        state.inspectorDragRegion:SetHeight(26)
        inspector.memberPicker.navigationEntries = nil
        inspector.memberPicker.element = element
        inspector.memberPicker.member = member
        inspector.memberPicker:SetShown(member ~= nil or contextualOwner)
        if member then
            inspector.memberPicker:SetDefaultText(
                GetDockMemberLabel(element, member) or member.label or member.id)
            inspector.memberPicker.element = element
            inspector.memberPicker.member = member
        elseif contextualOwner then
            local parent = NSkin:GetCompositionContainerParent(element)
            local entries, selectedKey
            if element.kind == "SCROLLBAR" then
                -- Parts are accordion sections on one page; the breadcrumb
                -- already provides navigation back to the owning group.
                inspector.memberPicker:Hide()
            elseif composition and composition.mode == "CONTAINER" then
                entries, selectedKey = GetContainerDockMembers(element), "__CONTAINER"
            elseif parent then
                entries, selectedKey = GetDirectChildDockMembers(element, parent)
                entries = entries or GetContainerDockMembers(parent)
                selectedKey = selectedKey or ("__CHILD\031" .. element.id)
            end
            inspector.memberPicker.navigationEntries = entries or {}
            inspector.memberPicker.navigationSelectedKey = selectedKey
            inspector.memberPicker:SetShown(#(entries or {}) > 0)
            inspector.memberPicker:SetDefaultText(element.label or element.id)
            for _, entry in ipairs(entries or {}) do
                if entry.familyKey == selectedKey then
                    inspector.memberPicker:SetDefaultText(entry.label)
                    break
                end
            end
        end
        local detailKey = member and (element.id .. "\031" .. member.id)
        local exact = detailKey and state.contextualInspectorDetails[detailKey]
            == "__OVERRIDES"
        inspector.contextScope:SetText("Specific overrides")
        inspector.contextScope:SetShown(exact)
        if exact then
            NSkin:SkinFlatButton(inspector.resetElement, "Clear Overrides", nil, nil, 12)
            inspector.resetElement.resetLabel = "Clear Overrides"
        end

        local hasStates = member and #(member.states or {}) > 0
        state.inspectorHeaderHeight = hasStates and 98 or 70
        inspector.selection:ClearAllPoints()
        inspector.selection:SetPoint("TOPLEFT", inspector, "TOPLEFT", 12, -6)
        inspector.selection:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -32, -6)
        inspector.memberPicker:ClearAllPoints()
        inspector.memberPicker:SetPoint("TOPLEFT", inspector, "TOPLEFT", 12, -32)
        inspector.memberPicker:SetSize(158, 26)
        inspector.contextScope:ClearAllPoints()
        inspector.contextScope:SetPoint("LEFT", inspector.memberPicker, "RIGHT", 10, 0)
        inspector.contextScope:SetPoint("RIGHT", inspector, "TOPRIGHT", -12, -45)
        inspector.contextScope:SetJustifyH("LEFT")
        inspector.resetElement:ClearAllPoints()
        inspector.resetElement:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -12,
            hasStates and -68 or -6)
        inspector.addOverride:ClearAllPoints()
        inspector.addOverride:SetPoint("RIGHT", inspector.resetElement, "LEFT", -4, 0)
        -- Non-state members keep their actions on a separate context row.
        if not hasStates then
            state.inspectorHeaderHeight = 98
            inspector.resetElement:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -12, -68)
        end
        if RefreshDebugLauncher then RefreshDebugLauncher(true) end

        local exactTargetAvailable = true
        if member and type(member.getTargetAppearanceID) == "function" then
            exactTargetAvailable =
                GetValidatedFocusedRuntimeTarget(element, member) ~= nil
        end
        if inspector.addOverride.SetEnabled then
            inspector.addOverride:SetEnabled(exactTargetAvailable)
        end
        inspector.addOverride:SetAlpha(
            exactTargetAvailable and 1 or 0.45)

        if state.scrollFrame then
            state.scrollFrame:ClearAllPoints()
            state.scrollFrame:SetPoint(
                "TOPLEFT", inspector, "TOPLEFT", 1,
                -(state.inspectorHeaderHeight - 1))
            state.scrollFrame:SetPoint(
                "BOTTOMRIGHT", inspector, "BOTTOMRIGHT", -1, 1)
        end
        RefreshStateSelector(element, member)
        LayoutInspectorChrome(element, member)
        return
    end

    state.contextualInspectorHeader = nil
    inspector.title:Show()
    NSkin:SkinWindowHeader(inspector)
    state.inspectorDragRegion:SetHeight(22)
    if RefreshDebugLauncher then RefreshDebugLauncher(false) end
    inspector.addOverride:ClearAllPoints()
    inspector.addOverride:SetPoint("RIGHT", inspector.resetElement, "LEFT", -4, 0)
    inspector.memberPicker:Hide()
    inspector.contextScope:Hide()
    if inspector.addOverride.SetEnabled then
        inspector.addOverride:SetEnabled(true)
    end
    inspector.addOverride:SetAlpha(1)

    local hasMemberTabs = RefreshCompositeMemberTabs(element)
    local hasStates = overrideMember
        and #(overrideMember.states or {}) > 0
    if hasMemberTabs then
        state.inspectorHeaderHeight = hasStates and 110 or 84
    else
        state.inspectorHeaderHeight = hasStates and 78 or 59
    end

    inspector.selection:ClearAllPoints()
    inspector.selection:SetPoint(
        "TOPLEFT", inspector, "TOPLEFT", 12, -29)
    local rightTarget = composite
        and inspector.addOverride or inspector.resetElement
    inspector.selection:SetPoint(
        "RIGHT", rightTarget, "LEFT", -8, 0)

    inspector.resetElement:ClearAllPoints()
    inspector.resetElement:SetPoint(
        "TOPRIGHT", inspector, "TOPRIGHT", -12,
        hasMemberTabs and -27 or (hasStates and -40 or -27))

    if state.scrollFrame then
        state.scrollFrame:ClearAllPoints()
        state.scrollFrame:SetPoint(
            "TOPLEFT", inspector, "TOPLEFT", 1,
            -(state.inspectorHeaderHeight - 1))
        state.scrollFrame:SetPoint(
            "BOTTOMRIGHT", inspector, "BOTTOMRIGHT", -1, 1)
    end
    RefreshStateSelector(element, overrideMember)
    LayoutInspectorChrome(element, overrideMember)
end

local function FocusEditorSection(element, memberID)
    if not element then return end
    local prefix = element.id .. "\031"
    for key in pairs(state.expandedEditorSections) do
        if key:sub(1, #prefix) == prefix
            and key ~= prefix .. "composition.overrideList"
        then
            state.expandedEditorSections[key] = nil
        end
    end
    local composition = element.composition
    if composition and composition.mode == "COMPOSITE" then return end
    local preferred = GetPreferredEditorSectionID(element, memberID)
    if preferred then
        state.expandedEditorSections[prefix .. preferred] = true
    end
end

local function GetMemberAppearanceOptionGroups(member)
    local component = member and member.kind
        and NSkin:GetSharedElementType(member.kind)
    if not component then return {} end
    local groups, seen = {}, {}
    local function Add(definition)
        local id = type(definition) == "table"
            and definition.id or definition
        local category = type(definition) == "table"
            and definition.category
        if type(id) == "string" and id ~= "shared.movable"
            and category ~= "POSITION" and category ~= "LAYOUT"
            and NSkin:GetOptionGroupDefinition(id) and not seen[id]
        then
            seen[id] = true
            groups[#groups + 1] = id
        end
    end
    if type(member.editorOptions) == "table"
        and #member.editorOptions > 0
    then
        for _, definition in ipairs(member.editorOptions) do
            if type(definition) == "table"
                and type(definition.tabs) == "table"
            then
                for _, tab in ipairs(definition.tabs) do
                    for _, groupID in ipairs(
                        tab.groups or { tab.id })
                    do
                        Add(groupID)
                    end
                end
            else
                Add(definition)
            end
        end
        return groups
    end
    for _, definition in ipairs(
        NSkin:CreateEditorOptionsPreset(component.editorPreset) or {})
    do
        Add(definition)
    end
    return groups
end

local SURFACE_OVERRIDE_PROPERTY_CATEGORY = {
    showBackground = "BACKGROUND",
    background = "BACKGROUND",
    backgroundMode = "BACKGROUND",
    backgroundOpacity = "BACKGROUND",
    selectedBackground = "BACKGROUND",
    selectedBackgroundMode = "BACKGROUND",
    selectedBackgroundOpacity = "BACKGROUND",

    showBorder = "BORDER",
    border = "BORDER",
    borderMode = "BORDER",
    borderSize = "BORDER",
    borderPadding = "BORDER",

    showHighlight = "HIGHLIGHT",
    highlight = "HIGHLIGHT",
    highlightMode = "HIGHLIGHT",
    hoverAlpha = "HIGHLIGHT",
}

local OVERRIDE_CATEGORIES = {
    { id = "SPECIFIC" },
    { id = "BACKGROUND", label = "Background" },
    { id = "BORDER", label = "Border" },
    { id = "HIGHLIGHT", label = "Highlight" },
}

local function ClassifyOverrideProperty(groupID, propertyKey)
    if groupID == "shared.surfaceBackground" then return "BACKGROUND" end
    if groupID == "shared.surfaceBorder" then return "BORDER" end
    if groupID == "shared.surfaceHighlight" then return "HIGHLIGHT" end
    if groupID == "shared.surfaceAppearance" then
        return SURFACE_OVERRIDE_PROPERTY_CATEGORY[propertyKey] or "SPECIFIC"
    end
    return "SPECIFIC"
end

local function GetOverridePropertiesForMember(member, categoryID)
    local properties = {}
    local function AddGroup(groupID)
        for _, property in ipairs(
            NSkin:GetOptionGroupOverrideProperties(groupID))
        do
            local category = ClassifyOverrideProperty(
                groupID, property.key)
            if not categoryID or category == categoryID then
                properties[#properties + 1] = {
                    groupID = groupID,
                    propertyKey = property.key,
                    propertyLabel = property.label,
                }
            end
        end
    end

    AddGroup("shared.movable")
    for _, groupID in ipairs(GetMemberAppearanceOptionGroups(member)) do
        AddGroup(groupID)
    end
    table.sort(properties, function(left, right)
        return tostring(left.propertyLabel)
            < tostring(right.propertyLabel)
    end)
    return properties
end

local function GetOverrideCategoriesForMember(element, member)
    local categories = {}
    for _, category in ipairs(OVERRIDE_CATEGORIES) do
        if #GetOverridePropertiesForMember(member, category.id) > 0 then
            categories[#categories + 1] = {
                id = category.id,
                label = category.id == "SPECIFIC"
                    and (GetDockMemberLabel(element, member)
                        or member.label or member.id)
                    or category.label,
            }
        end
    end
    return categories
end

local function GetOverrideSubsetID(element, entry)
    local member = entry.member
        or NSkin:GetCompositeMember(element, entry.memberID)
    if not member then return nil end
    return NSkin:EnsureOptionGroupPropertySubset(
        entry.groupID, member.id, entry.propertyKey,
        entry.label or ((member.label or member.id) .. " - "
            .. (entry.propertyLabel or entry.propertyKey)))
end

local function GetOverrideEntryContext(element, member, entry)
    if not element or not member or not entry then return nil end
    if entry.groupID == "shared.movable" then
        return NSkin:GetCompositeMemberExactPositionContext(
            element, member, entry.appearanceID)
    end
    return NSkin:GetCompositeMemberExactAppearanceContext(
        element, member, entry.appearanceID)
end

local function GetFocusedOverrideAppearanceID(element, member, runtimeTarget)
    if not element or not member or not runtimeTarget then return nil end
    local appearanceID = NSkin:GetCompositeMemberTargetAppearanceID(
        element, member, runtimeTarget)
    if appearanceID == (member.appearanceID or member.id) then
        return nil
    end
    return appearanceID
end

local function OverrideEntryMatchesRuntimeTarget(
    element, member, entry, runtimeTarget)
    if not element or not member or not entry
        or entry.memberID ~= member.id
    then return false end
    if type(member.getTargetAppearanceID) ~= "function" then
        return entry.appearanceID == nil
    end
    return entry.appearanceID == GetFocusedOverrideAppearanceID(
        element, member, runtimeTarget)
end

local function ClearCompositeOverrides(element, memberID, runtimeTarget)
    if not element or not memberID then return false end
    local member = NSkin:GetCompositeMember(element, memberID)
    if not member then return false end
    local entries = {}
    for _, entry in ipairs(
        NSkin:GetCompositePropertyOverrides(element))
    do
        if OverrideEntryMatchesRuntimeTarget(
            element, member, entry, runtimeTarget)
        then
            entries[#entries + 1] = entry
        end
    end
    local changed
    for _, entry in ipairs(entries) do
        local member = NSkin:GetCompositeMember(
            element, entry.memberID)
        local subsetID = member
            and GetOverrideSubsetID(element, entry)
        local context = member
            and GetOverrideEntryContext(element, member, entry)
        NSkin:RemoveCompositePropertyOverrideMetadata(
            element, entry.memberID, entry.groupID,
            entry.propertyKey, entry.appearanceID)
        if subsetID and context then
            changed = NSkin:ResetOptionGroup(
                subsetID, context) or changed
        end
    end
    RefreshInspector()
    return changed == true or #entries > 0
end

local function HideOverrideViewLabels(view)
    for _, region in ipairs({ view:GetRegions() }) do
        if region.GetObjectType
            and region:GetObjectType() == "FontString"
        then
            region:Hide()
        end
    end
end

local function LayoutOverrideRowControl(row, view, propertyKey)
    if not row or not view then return 34 end
    HideOverrideViewLabels(view)
    view:ClearAllPoints()
    view:SetPoint("TOPLEFT", row.valueCell, "TOPLEFT", 0, 0)
    view:SetPoint("RIGHT", row.valueCell, "RIGHT", 0, 0)

    local control = view.controlByKey
        and view.controlByKey[propertyKey]
    local valueLabel = view.valueByKey
        and view.valueByKey[propertyKey]

    if control then
        control:ClearAllPoints()
        if valueLabel then
            valueLabel:ClearAllPoints()
            valueLabel:SetPoint(
                "RIGHT", row.valueCell, "RIGHT", -2, 0)
            control:SetPoint(
                "LEFT", row.valueCell, "LEFT", 8, 0)
            control:SetPoint(
                "RIGHT", valueLabel, "LEFT", -8, 0)
            if control.SetWidth then
                control:SetWidth(math.max(80,
                    (row.valueCell:GetWidth() or 250) - 84))
            end
        else
            control:SetPoint("LEFT", row.valueCell, "LEFT", 8, 0)
            control:SetPoint("RIGHT", row.valueCell, "RIGHT", -8, 0)
            if control.SetWidth then
                control:SetWidth(math.max(80,
                    (row.valueCell:GetWidth() or 250) - 16))
            end
        end
    end

    view:SetHeight(34)
    return 34
end

local function RefreshOverrideListView(
    frame, element, memberID, runtimeTarget)
    frame.rows = frame.rows or {}
    local entries = {}
    local member = memberID
        and NSkin:GetCompositeMember(element, memberID)
    for _, entry in ipairs(
        NSkin:GetCompositePropertyOverrides(element))
    do
        if member and OverrideEntryMatchesRuntimeTarget(
            element, member, entry, runtimeTarget)
        then
            entries[#entries + 1] = entry
        end
    end
    local expected = member and runtimeTarget
        and NSkin:GetCompositeMemberTargetAppearanceID(element, member, runtimeTarget)
    local function TargetStillValid()
        if not IsContextualInspectorMember(element, member) then return true end
        local target, current = GetValidatedFocusedRuntimeTarget(element, member)
        return target == runtimeTarget and current == expected
            and state.selectedElement == element
            and state.focusedCompositeMemberID == member.id
    end
    local y = 0
    local rowWidth = math.max(1, frame:GetWidth() or 502)
    local nameWidth = math.floor(rowWidth * 0.46)
    local valueWidth = rowWidth - nameWidth

    for index, entry in ipairs(entries) do
        local row = frame.rows[index]
        if not row then
            row = CreateFrame("Frame", nil, frame)
            row.nameCell = CreateFrame("Frame", nil, row)
            row.nameCell:SetPoint("TOPLEFT")
            row.valueCell = CreateFrame("Frame", nil, row)
            row.valueCell:SetPoint(
                "TOPLEFT", row.nameCell, "TOPRIGHT", 0, 0)
            row.label = row.nameCell:CreateFontString(
                nil, "OVERLAY", "GameFontNormal")
            row.label:SetPoint(
                "LEFT", row.nameCell, "LEFT", 8, 0)
            row.label:SetPoint(
                "RIGHT", row.nameCell, "RIGHT", -30, 0)
            row.label:SetJustifyH("LEFT")
            row.label:SetWordWrap(false)
            row.remove = CreateButton(
                row.nameCell, "×", 20, function(self)
                    local current = self.overrideEntry
                    local owner = self.overrideOwner
                    if not current or not owner then return end
                    if self.validateContext and not self.validateContext() then return end
                    local member = NSkin:GetCompositeMember(
                        owner, current.memberID)
                    local subsetID =
                        GetOverrideSubsetID(owner, current)
                    local context = member
                        and GetOverrideEntryContext(
                            owner, member, current)
                    NSkin:RemoveCompositePropertyOverrideMetadata(
                        owner, current.memberID, current.groupID,
                        current.propertyKey, current.appearanceID)
                    if subsetID and context then
                        NSkin:ResetOptionGroup(subsetID, context)
                    end
                    RefreshInspector()
                end)
            row.remove:SetPoint(
                "RIGHT", row.nameCell, "RIGHT", -4, 0)
            frame.rows[index] = row
        end

        row:SetWidth(rowWidth)
        row.nameCell:SetSize(nameWidth, 34)
        row.valueCell:SetSize(valueWidth, 34)
        row.label:SetText(entry.label
            or ((entry.member and
                (entry.member.label or entry.member.id)
                or entry.memberID) .. " - "
                .. (entry.propertyLabel or entry.propertyKey)))

        local member = NSkin:GetCompositeMember(element, entry.memberID)
        local subsetID = member and GetOverrideSubsetID(element, entry)
        local context = member
            and GetOverrideEntryContext(element, member, entry)
        if subsetID and context then
            if row.viewID ~= subsetID then
                if row.view then row.view:Hide() end
                row.view = NSkin:CreateOptionGroupView(
                    row.valueCell, subsetID, "COMPACT", context)
                row.viewID = subsetID
            else
                row.view:SetContext(context)
            end
            row.view.isSkinningModeInspector = IsContextualInspectorMember(element, member)
            row.view.preserveInspectorContext = IsContextualInspectorMember(element, member)
            row.view.validateContext = TargetStillValid
            row.view.onValueCommitted = function()
                row.view:Refresh()
            end
            row.view:SetExternalEnabled(TargetStillValid())
            row.remove.validateContext = TargetStillValid
            row.view:Show()
            local height = LayoutOverrideRowControl(
                row, row.view, entry.propertyKey)
            row.remove.overrideEntry = entry
            row.remove.overrideOwner = element
            row.remove:Show()
            row:SetHeight(height)
            row.nameCell:SetHeight(height)
            row.valueCell:SetHeight(height)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -y)
            row:Show()
            y = y + height
        else
            row:Hide()
        end
    end

    for index = #entries + 1, #frame.rows do
        frame.rows[index]:Hide()
    end
    frame:SetHeight(math.max(1, y))
    return y
end

local function OpenOverridePopup(element, preferredMemberID)
    local popup = state.overridePopup
    if not popup or not element then return end
    local preferred = preferredMemberID
        and NSkin:GetCompositeMember(element, preferredMemberID)
    if IsContextualInspectorMember(element, preferred)
        and type(preferred.getTargetAppearanceID) == "function"
        and not GetValidatedFocusedRuntimeTarget(element, preferred)
    then return end
    popup:Open(element, preferred and { preferred } or nil)
end


IsContextualInspectorElement = function(element)
    local composition = element and element.composition
    return element and element.contextualInspector == true or (composition
        and composition.mode == "COMPOSITE"
        and composition.contextualInspector == true)
end

IsContextualInspectorMember = function(element, member)
    return IsContextualInspectorElement(element)
        and member
        and member.contextualInspector ~= false
end

local function HideContextualInspectorRows()
    for _, row in pairs(state.contextualSummaryRows or {}) do
        row:Hide()
        if row.body then row.body:Hide() end
    end
    for _, row in pairs(state.contextualPropertyRows or {}) do
        row:Hide()
        if row.view then row.view:Hide() end
    end
    if state.contextualDetailHeader then state.contextualDetailHeader:Hide() end
    if state.contextualOverrideView then state.contextualOverrideView:Hide() end
    if state.contextualUnavailable then state.contextualUnavailable:Hide() end
end

local function HideLegacyInspectorRows()
    for _, view in pairs(state.optionViews or {}) do
        view:SetContext(nil)
        view:Hide()
    end
    for i = 1, #(state.editorSections or {}) do
        local section = state.editorSections[i]
        section:Hide()
        if section.tabBar then section.tabBar:Hide() end
        if section.overrideListView then section.overrideListView:Hide() end
    end
    for _, bar in pairs(state.editorNavigationBars or {}) do bar:Hide() end
end

local function GetContextualDetailKey(element, member)
    return element.id .. "\031" .. (member and member.id or "__OWNER")
end

GetValidatedFocusedRuntimeTarget = function(element, member)
    local expected = state.focusedCompositeRuntimeAppearanceID
    local target = state.focusedCompositeRuntimeTarget
    if state.selectedElement ~= element
        or GetContextualCompositeMember(element) ~= member
    then return nil, expected end
    if not target or not expected then return nil, expected end
    if target.IsForbidden and target:IsForbidden() then return nil, expected end
    if target.IsVisible and not target:IsVisible() then return nil, expected end
    local declared
    for _, candidate in ipairs(
        NSkin:GetCompositionMemberTargets(element, member, true) or {})
    do
        if candidate == target then declared = true; break end
    end
    if not declared then return nil, expected end
    local current = NSkin:GetCompositeMemberTargetAppearanceID(
        element, member, target)
    if current ~= expected then return nil, expected end
    if type(member.getTargetAppearanceID) == "function"
        and current == (member.appearanceID or member.id)
    then return nil, expected end
    return target, expected
end

local function GetContextualOverrideEntries(element, member)
    local entries = {}
    local _, expected = GetValidatedFocusedRuntimeTarget(element, member)
    if not expected then return entries end
    for _, entry in ipairs(
        NSkin:GetCompositePropertyOverrides(element) or {})
    do
        if entry.memberID == member.id
            and entry.appearanceID == expected
        then
            entries[#entries + 1] = entry
        end
    end
    return entries
end

local function CollectContextualOptionGroups(element, member)
    local definitions = (member and NSkin:GetCompositeMemberEditorOptions(
        element, member) or NSkin:GetCompositionEditorOptions(element)) or {}
    local navigation = not member and GetElementDockNavigation(element)
    local groups, seen = {}, {}

    local function Add(definition, inheritedContext)
        if type(definition) == "string" then
            definition = { id = definition }
        end
        if type(definition) ~= "table" then return end
        local context = definition.context or inheritedContext
        if type(definition.groups) == "table" then
            for _, child in ipairs(definition.groups) do Add(child, context) end
            return
        end
        if definition.presentation == "NAV_TABS"
            and type(definition.tabs) == "table"
        then
            local selected = navigation and navigation.id == definition.id and math.min(
                state.selectedEditorSubtabs[element.id .. "\031" .. tostring(definition.id)] or 1,
                #definition.tabs)
            for index, tab in ipairs(definition.tabs) do
                if not selected or index == selected then
                    local tabContext = type(tab) == "table"
                        and (tab.context or context) or context
                    for _, child in ipairs(
                        type(tab) == "table" and tab.groups or {})
                    do
                        Add(child, tabContext)
                    end
                    for _, child in ipairs(
                        type(tab) == "table" and tab.tabs or {})
                    do
                        Add(child, tabContext)
                    end
                end
            end
            return
        end
        if type(definition.id) ~= "string"
            or not NSkin:GetOptionGroupDefinition(definition.id)
        then return end
        -- Reuse canonical subsets for the compact inspector; storage and reset
        -- ownership still belong to the original shared appearance contract.
        local subsets = {
            ["shared.buttonAppearance"] = { "shared.buttonGeometry", "shared.buttonContent" },
            ["shared.checkboxAppearance"] = { "shared.checkboxGeometry", "shared.checkboxContent" },
            ["shared.surfaceAppearance"] = { "shared.surfaceGeometry", "shared.surfaceBackground",
                "shared.surfaceBorder", "shared.surfaceHighlight" },
        }
        if subsets[definition.id] then
            for _, id in ipairs(subsets[definition.id]) do Add({ id = id }, context) end
            return
        end
        local token = definition.id .. "\031"
            .. tostring(context and context.id or context)
        if seen[token] then return end
        seen[token] = true
        groups[#groups + 1] = {
            id = definition.id,
            label = definition.label,
            category = definition.category,
            context = context,
        }
    end

    for _, definition in ipairs(definitions) do Add(definition, element) end
    local ordered = {}
    for _, group in ipairs(groups) do
        if group.id == "shared.movable" or group.category == "POSITION" then
            ordered[#ordered + 1] = group
        end
    end
    for _, group in ipairs(groups) do
        if group.id ~= "shared.movable" and group.category ~= "POSITION" then
            ordered[#ordered + 1] = group
        end
    end
    return ordered
end

local CONTEXTUAL_GROUP_LABELS = {
    ["shared.movable"] = "Position",
    ["shared.checkboxGeometry"] = "Geometry",
    ["shared.checkboxContent"] = "Content",
    ["shared.buttonGeometry"] = "Geometry",
    ["shared.buttonContent"] = "Content",
    ["shared.scrollBarBar"] = "Bar",
    ["shared.scrollBarThumb"] = "Thumb",
    ["shared.scrollBarArrowAll"] = "Arrow · All states",
    ["shared.scrollBarArrowDisabled"] = "Arrow · Disabled",
    ["shared.scrollBarArrowEnabled"] = "Arrow · Enabled",
    ["shared.textAppearance"] = "Text",
    ["shared.surfaceGeometry"] = "Geometry",
    ["shared.surfaceBackground"] = "Background",
    ["shared.surfaceBorder"] = "Border",
    ["shared.surfaceHighlight"] = "Highlight",
    ["shared.windowSpecificAppearance"] = "Window",
    ["shared.windowSurfaceBackground"] = "Background",
    ["shared.windowSurfaceBorder"] = "Border",
    ["shared.windowSurfaceHighlight"] = "Highlight",
    ["shared.iconAppearance"] = "Icon",
    ["shared.containerLayout"] = "Layout",
}

local function FormatContextualSummary(group)
    local definition = NSkin:GetOptionGroupDefinition(group.id)
    local values = definition and group.context
        and definition.get(group.context) or {}
    if group.id == "shared.movable" then
        return string.format("X %.1f · Y %.1f",
            tonumber(values.alongOffset) or 0,
            tonumber(values.edgeOffset) or 0)
    elseif group.id == "shared.checkboxGeometry" then
        local shape = tostring(values.shape or "square")
        shape = shape:sub(1, 1):upper() .. shape:sub(2)
        return shape .. " · "
            .. tostring(math.floor((tonumber(values.size) or 0) + 0.5))
            .. " px"
    elseif group.id == "shared.checkboxContent" then
        return "Checkmark · inset "
            .. tostring(math.floor(
                (tonumber(values.checkedInset) or 0) + 0.5)) .. " px"
    elseif group.id == "shared.textAppearance" then
        local size = tonumber(values.textSize)
        return size and (tostring(math.floor(size + 0.5)) .. " px")
            or "Typography & color"
    elseif group.id == "shared.surfaceGeometry" or group.id == "shared.buttonGeometry" then
        return tostring(math.floor((tonumber(values.width) or 0) + 0.5))
            .. " × "
            .. tostring(math.floor((tonumber(values.height) or 0) + 0.5))
            .. " px"
    elseif group.id == "shared.buttonContent" then
        return "Button content"
    elseif group.id == "shared.surfaceBackground" then
        return (values.showBackground == false and "Off" or "On")
            .. " · "
            .. tostring(math.floor(
                (tonumber(values.backgroundOpacity) or 0) * 100 + 0.5))
            .. "%"
    elseif group.id == "shared.surfaceBorder" then
        return (values.showBorder == false and "Off" or "On")
            .. " · "
            .. tostring(math.floor(
                (tonumber(values.borderSize) or 0) + 0.5)) .. " px"
    elseif group.id == "shared.surfaceHighlight" then
        return (values.showHighlight == false and "Off" or "On")
            .. " · "
            .. tostring(math.floor(
                (tonumber(values.hoverAlpha) or 0) * 100 + 0.5)) .. "%"
    end
    return "Edit"
end

local function EnsureContextualSummaryRow(index)
    state.contextualSummaryRows = state.contextualSummaryRows or {}
    local row = state.contextualSummaryRows[index]
    if row then return row end

    row = CreateFrame("Button", nil, state.scrollChild)
    row:SetHeight(34)
    row.body = CreateFrame("Frame", nil, state.scrollChild)
    row.body:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -1)
    row.body:Hide()
    row.cells = {}
    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 12, 0)
    row.sectionIcon = row:CreateTexture(nil, "OVERLAY")
    row.sectionIcon:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.sectionIcon:SetSize(13, 13)
    row.sectionIcon:SetTexture("Interface\\AddOns\\NSkin\\Media\\grid-alt.png")
    row.sectionIcon:SetVertexColor(unpack(INSPECTOR_THEME.accent))
    row.label:ClearAllPoints()
    row.label:SetPoint("LEFT", row.sectionIcon, "RIGHT", 10, 0)
    row.enabledToggle = NSkin:CreateOwnedOptionsCheckbox(row)
    row.enabledToggle:SetSize(22, 12)
    row.enabledToggle:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.enabledToggle:SetFrameLevel(row:GetFrameLevel() + 1)
    row.enabledToggle.Text:Hide()
    row.enabledToggle:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.enabledToggle:Hide()
    row.enabledToggle:SetScript("OnClick", function(self, button)
        local cell = row.headerToggleCell
        if not cell then return end
        if button == "RightButton" then
            cell.reset:GetScript("OnClick")(cell.reset)
        else
            NSkin:SetOptionGroupValues(cell.subsetID, cell.context,
                { [cell.property.key] = self:GetChecked() == true }, true)
            RefreshContextualSectionPresentation(row)
        end
    end)
    row.enabledToggle:SetScript("OnEnter", function(self)
        local cell = row.headerToggleCell
        if cell and GameTooltip then
            local source = NSkin:GetOptionGroupPropertyInheritance(
                cell.groupID, cell.context, cell.property)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Enable " .. row.label:GetText())
            GameTooltip:AddLine(source and source.label or "", 1, 1, 1)
            GameTooltip:AddLine("Right-click to reset Enabled.", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    row.enabledToggle:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    row.value = row:CreateFontString(
        nil, "OVERLAY", "GameFontHighlightSmall")
    row.value:SetPoint("RIGHT", row, "RIGHT", -28, 0)
    row.value:SetJustifyH("RIGHT")
    row.arrow = row:CreateTexture(nil, "OVERLAY")
    row.arrow:SetSize(12, 12)
    row.arrow:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.arrow:SetTexture(
        "Interface\\AddOns\\NSkin\\Media\\angle-small-down.png")
    row.arrow:SetRotation(-math.pi / 2)
    NSkin:CreateFlatBackground(row, nil,
        { 0, 0, 0, 0 }, NSkin:GetStyle("window").header.divider)
    InspectorSurface(row, { 0, 0, 0, 0 }, false)
    row.divider = row:CreateTexture(nil, "BACKGROUND")
    row.divider:SetPoint("TOPLEFT")
    row.divider:SetPoint("TOPRIGHT")
    row.divider:SetHeight(1)
    row.divider:SetColorTexture(unpack(INSPECTOR_THEME.border))
    row:SetScript("OnClick", function(self)
        if not self.detailKey or not self.groupID then return end
        if self.groupID == "__OVERRIDES" then
            state.contextualInspectorDetails[self.detailKey] = "__OVERRIDES"
            RefreshInspector()
            return
        end
        state.contextualAccordionExpansion = state.contextualAccordionExpansion or {}
        local expanded = state.contextualAccordionExpansion
        expanded[self.expansionKey] = not expanded[self.expansionKey]
        LayoutContextualInspector()
    end)
    row:SetScript("OnEnter", function(self)
        self.label:SetTextColor(unpack(INSPECTOR_THEME.accent))
    end)
    row:SetScript("OnLeave", function(self)
        self.label:SetTextColor(unpack(INSPECTOR_THEME.text))
    end)
    state.contextualSummaryRows[index] = row
    return row
end

local function GetContextualPropertySourceLabel(source)
    -- Source tags are deliberately omitted from the current Design presentation.
    return ""
end

local function LayoutContextualPropertyHeading(row, width, centered)
    local available = math.max(1, width - 24)
    -- Measure the complete text using the current font, not the previous
    -- constrained heading widths. Only the source may be truncated.
    row.label:ClearAllPoints()
    row.label:SetWidth(0)
    row.source:ClearAllPoints()
    row.source:SetWidth(0)
    local labelWidth = math.ceil(row.label:GetStringWidth()) + 2
    local hasSource = (row.source:GetText() or "") ~= ""
    local sourceWidth = hasSource and math.min(math.ceil(row.source:GetStringWidth()) + 2,
        math.max(1, available - labelWidth - 6)) or 0
    local headingWidth = labelWidth + (hasSource and (6 + sourceWidth) or 0)
    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT",
        centered and math.max(0, (available - headingWidth) / 2) or 0, -4)
    row.label:SetSize(labelWidth, 16)
    row.label:SetJustifyV("BOTTOM")
    row.source:ClearAllPoints()
    row.source:SetPoint("BOTTOMLEFT", row.label, "BOTTOMRIGHT", 6, 0)
    row.source:SetSize(math.max(1, sourceWidth), 14)
    row.source:SetJustifyV("BOTTOM")
end

local function RefreshContextualPropertySource(row)
    if not row or not row.groupID or not row.context
        or not row.property
    then return end
    local source = NSkin:GetOptionGroupPropertyInheritance(
        row.groupID, row.context, row.property)
    row.source:SetText(GetContextualPropertySourceLabel(source))
    if not row.pairRow or row.pairRow.mixedSources then
        LayoutContextualPropertyHeading(row, row:GetWidth())
    end
    if row.pairRow then RefreshContextualPairSource(row.pairRow) end
end

RefreshContextualSectionPresentation = function(section)
    section.value:SetText((FormatContextualSummary(section.group):gsub("^O[nf]+ · ", "")))
    local cell = section.headerToggleCell
    section.enabledToggle:SetShown(cell ~= nil)
    if cell then
        local definition = NSkin:GetOptionGroupDefinition(cell.groupID)
        local values = definition.get(cell.context)
        section.enabledToggle:SetChecked(values[cell.property.key] == true)
    end
    InspectorFont(section.label, 12)
    InspectorFont(section.value, 9, INSPECTOR_THEME.muted)
    section.value:ClearAllPoints()
    section.value:SetPoint("RIGHT", section, "RIGHT", cell and -66 or -28, 0)
    section.arrow:ClearAllPoints()
    section.arrow:SetPoint("RIGHT", section, "RIGHT", cell and -38 or -8, 0)
    section.arrow:SetVertexColor(unpack(INSPECTOR_THEME.accent))
    local toggle = section.enabledToggle
    InspectorSurface(toggle, INSPECTOR_THEME.input, true)
    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(toggle, "NSkinOptionsCheckboxBorder"), unpack(INSPECTOR_THEME.border))
    -- A square switch uses the canonical CheckButton's checked state and click handler.
    local checked = toggle:GetCheckedTexture()
    if checked then
        checked:ClearAllPoints()
        checked:SetPoint("TOPLEFT", toggle, "TOPLEFT", 1, -1)
        checked:SetPoint("BOTTOMRIGHT", toggle, "BOTTOMRIGHT", -1, 1)
        checked:SetColorTexture(unpack(INSPECTOR_THEME.accent))
    end
end

local function EnsureContextualPropertyRow(key)
    state.contextualPropertyRows = state.contextualPropertyRows or {}
    local cell = state.contextualPropertyRows[key]
    if cell then return cell end
    cell = CreateFrame("Frame", nil, state.scrollChild)
    cell.label = cell:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cell.label:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, -4)
    cell.label:SetPoint("TOPRIGHT", cell, "TOPRIGHT", -24, -4)
    cell.label:SetHeight(16)
    cell.label:SetJustifyH("LEFT")
    cell.label:SetWordWrap(false)
    cell.source = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.source:SetPoint("LEFT", cell.label, "RIGHT", 6, 0)
    cell.source:SetHeight(14)
    cell.source:SetJustifyH("LEFT")
    cell.source:SetWordWrap(false)
    cell.valueCell = CreateFrame("Frame", nil, cell)
    cell.valueCell:SetPoint("TOPLEFT", cell, "TOPLEFT", 0, -25)
    cell.valueCell:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 0, -25)
    cell.valueCell:SetHeight(30)
    cell.reset = CreateFrame("Button", nil, cell)
    cell.reset:SetSize(20, 20)
    cell.reset:SetPoint("TOPRIGHT", cell, "TOPRIGHT", 0, -1)
    cell.reset.icon = NSkin:CreateCenteredButtonGlyph(cell.reset,
        "contextualPropertyReset", {
            texture = "Interface\\AddOns\\NSkin\\Media\\rotate-right.png",
            size = 12,
        })
    cell.reset:SetScript("OnEnter", function(self)
        NSkin:SetCenteredButtonGlyphColor(self.icon, NSkin:GetAccentColor())
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Reset " .. (cell.property.label or cell.property.key))
            GameTooltip:AddLine("Clears only this property's overrides at the current scope and state.",
                1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    cell.reset:SetScript("OnLeave", function(self)
        NSkin:SetCenteredButtonGlyphColor(self.icon, INSPECTOR_THEME.muted)
        if GameTooltip then GameTooltip:Hide() end
    end)
    cell.reset:SetScript("OnClick", function()
        if not cell.subsetID or not cell.context then return end
        NSkin:RunWithLiveInspectorAppearanceChange(cell.context.id, function()
            NSkin:ResetOptionGroup(cell.subsetID, cell.context)
        end)
        if cell.view then cell.view:Refresh() end
        RefreshContextualPropertySource(cell)
        if cell.section then RefreshContextualSectionPresentation(cell.section) end
    end)
    state.contextualPropertyRows[key] = cell
    return cell
end

RefreshContextualPairSource = function(pair)
    local left, right = pair.cells[1], pair.cells[2]
    local leftSource = NSkin:GetOptionGroupPropertyInheritance(
        left.groupID, left.context, left.property)
    local rightSource = NSkin:GetOptionGroupPropertyInheritance(
        right.groupID, right.context, right.property)
    local a, b = leftSource and leftSource.label or "", rightSource and rightSource.label or ""
    local mixed = a ~= b
    pair.label:SetText(pair.title)
    pair.source:SetText(not mixed and GetContextualPropertySourceLabel(leftSource) or "")
    LayoutContextualPropertyHeading(pair, pair:GetWidth(), true)
    left.source:SetShown(mixed)
    right.source:SetShown(mixed)
    local changed = pair.mixedSources ~= nil and pair.mixedSources ~= mixed
    pair.mixedSources = mixed
    if changed then LayoutContextualInspector() end
end

local function EnsureContextualPairRow(section, left, right)
    section.pairRows = section.pairRows or {}
    local key = left.property.editorPair
    local pair = section.pairRows[key]
    if not pair then
        pair = CreateFrame("Frame", nil, section.body)
        pair.label = pair:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        pair.label:SetPoint("TOPLEFT", pair, "TOPLEFT", 0, -4)
        pair.label:SetPoint("TOPRIGHT", pair, "TOPRIGHT", -24, -4)
        pair.label:SetHeight(16)
        pair.label:SetJustifyH("CENTER")
        pair.label:SetWordWrap(false)
        pair.source = pair:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        pair.source:SetJustifyH("LEFT")
        pair.source:SetWordWrap(false)
        pair.source:SetTextColor(0.65, 0.65, 0.65, 1)
        pair.reset = CreateFrame("Button", nil, pair)
        pair.reset:SetSize(20, 20)
        pair.reset:SetPoint("TOPRIGHT")
        pair.reset.icon = NSkin:CreateCenteredButtonGlyph(pair.reset,
            "contextualPairReset", {
                texture = "Interface\\AddOns\\NSkin\\Media\\rotate-right.png",
                size = 12,
            })
        pair.reset:SetScript("OnClick", function()
            -- One explicit action over two existing logical resets; no new
            -- appearance identity or reset ownership is introduced.
            for _, cell in ipairs(pair.cells) do
                cell.reset:GetScript("OnClick")(cell.reset)
            end
        end)
        pair.reset:SetScript("OnEnter", function(self)
            NSkin:SetCenteredButtonGlyphColor(self.icon, NSkin:GetAccentColor())
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Reset " .. pair.title)
                GameTooltip:AddLine("Clears " .. pair.cells[1].property.label
                    .. " and " .. pair.cells[2].property.label
                    .. " at the current scope.", 1, 1, 1, true)
                GameTooltip:Show()
            end
        end)
        pair.reset:SetScript("OnLeave", function(self)
            NSkin:SetCenteredButtonGlyphColor(self.icon, { 1, 1, 1, 1 })
            if GameTooltip then GameTooltip:Hide() end
        end)
        section.pairRows[key] = pair
    end
    pair.title = left.property.editorPairLabel
    pair.cells = { left, right }
    left.pairRow, right.pairRow = pair, pair
    return pair
end

LayoutContextualInspector = function()
    local width = math.max(1, (state.scrollChild:GetWidth() or 518) - 16)
    local expanded = state.contextualAccordionExpansion or {}
    local y = 8
    for _, section in ipairs(state.contextualActiveSections or {}) do
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT", 8, -y)
        section:SetWidth(width)
        local open = expanded[section.expansionKey] == true
            and section.groupID ~= "__OVERRIDES"
        section.arrow:SetRotation(open and 0 or math.pi / 2)
        section.body:SetWidth(width)
        section.body:SetShown(open)
        y = y + 35
        local bodyY, index = 8, 1
        for _, pair in pairs(section.pairRows or {}) do pair:Hide() end
        while index <= #section.cells do
            local cell = section.cells[index]
            local nextCell = section.cells[index + 1]
            local hasPair = nextCell and cell.property.editorPair
                and cell.property.editorPair == nextCell.property.editorPair
            local paired = width >= 330 and hasPair
            local sharedHeading = false
            local pair = sharedHeading and EnsureContextualPairRow(section, cell, nextCell)
            local cellWidth = paired and (width - 36) / 2 or width - 20
            if pair then
                pair:ClearAllPoints()
                pair:SetPoint("TOPLEFT", section.body, "TOPLEFT", 10, -bodyY)
                pair:SetSize(width - 20, 24)
                pair:Show()
                -- Source changes can relayout after commits; avoid reentrancy
                -- while already computing the layout.
                pair.mixedSources = nil
                RefreshContextualPairSource(pair)
                bodyY = bodyY + 24
            end
            local cellHeight = 66
            local function Place(current, x)
                current:ClearAllPoints()
                current:SetPoint("TOPLEFT", section.body, "TOPLEFT", x, -bodyY)
                current:SetSize(cellWidth, cellHeight)
                current.label:ClearAllPoints()
                current.valueCell:ClearAllPoints()
                if pair and not pair.mixedSources then
                    local key = current.property.key
                    current.label:SetText(key == "alongOffset" and "X"
                        or (key == "edgeOffset" and "Y" or ""))
                    current.label:SetPoint("TOPLEFT", current, "TOPLEFT", 0, -10)
                    current.label:SetSize(18, 20)
                    current.label:SetShown(key == "alongOffset" or key == "edgeOffset")
                    current.reset:Hide()
                    local inset = current.label:IsShown() and 22 or 0
                    current.valueCell:SetPoint("TOPLEFT", current, "TOPLEFT", inset, -6)
                    current.valueCell:SetPoint("TOPRIGHT", current, "TOPRIGHT", 0, -6)
                    current.valueCell:SetWidth(cellWidth - inset)
                else
                    if not pair then current.pairRow = nil end
                    current.label:SetText(current.property.label or current.property.key)
                    InspectorFont(current.label, 10)
                    LayoutContextualPropertyHeading(current, cellWidth)
                    current.label:Show()
                    current.source:Hide()
                    current.reset:SetShown(not pair)
                    current.valueCell:SetPoint("TOPLEFT", current, "TOPLEFT", 0, -25)
                    current.valueCell:SetPoint("TOPRIGHT", current, "TOPRIGHT", 0, -25)
                    current.valueCell:SetWidth(cellWidth)
                end
                current.view:ClearAllPoints()
                current.view:SetAllPoints(current.valueCell)
                NSkin:LayoutOptionPropertyView(current.view, current.property,
                    current.valueCell:GetWidth(), INSPECTOR_THEME)
            end
            Place(cell, 10)
            if hasPair then
                if not paired then bodyY = bodyY + cellHeight + 4 end
                Place(nextCell, paired and (26 + cellWidth) or 10)
            end
            bodyY = bodyY + cellHeight + 4
            index = index + (hasPair and 2 or 1)
        end
        if section.actionView then
            section.actionView:ClearAllPoints()
            section.actionView:SetPoint("TOPLEFT", section.body, "TOPLEFT", 10, -bodyY)
            section.actionView:SetWidth(width - 20)
            bodyY = bodyY + section.actionView:GetHeight() + 4
        end
        section.body:SetHeight(bodyY)
        if open then y = y + bodyY end
        y = y + 6
    end
    ResizeInspector(nil, y)
end

local function EnsureContextualDetailHeader()
    if state.contextualDetailHeader then
        return state.contextualDetailHeader
    end
    local frame = CreateFrame("Frame", nil, state.scrollChild)
    frame:SetHeight(30)
    frame.back = CreateButton(frame, "‹ Overview", 92, function()
        local element = state.selectedElement
        local member = element and state.focusedCompositeMemberID
            and NSkin:GetCompositeMember(
                element, state.focusedCompositeMemberID)
        if not element or not member then return end
        state.contextualInspectorDetails[
            GetContextualDetailKey(element, member)] = nil
        state.scrollFrame:SetVerticalScroll(0)
        RefreshInspector()
    end)
    frame.back:SetPoint("LEFT", frame, "LEFT", 8, 0)
    frame.title = frame:CreateFontString(
        nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("LEFT", frame.back, "RIGHT", 12, 0)
    state.contextualDetailHeader = frame
    return frame
end

local function ShowContextualUnavailable(message, y)
    local label = state.contextualUnavailable
    if not label then
        label = state.scrollChild:CreateFontString(
            nil, "OVERLAY", "GameFontHighlight")
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        state.contextualUnavailable = label
    end
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT", 16, -y)
    label:SetPoint("RIGHT", state.scrollChild, "RIGHT", -16, 0)
    label:SetText(message)
    label:Show()
end

local function LoadContextualInspector(element, member)
    HideLegacyInspectorRows()
    HideContextualInspectorRows()

    state.contextualInspectorDetails =
        state.contextualInspectorDetails or {}
    local detailKey = GetContextualDetailKey(element, member)
    local detail = state.contextualInspectorDetails[detailKey]
    local groups = CollectContextualOptionGroups(element, member)
    local y = 8
    state.contextualActiveSections = {}
    if detail == "__OVERRIDES" then
        local header = EnsureContextualDetailHeader()
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT", 0, -y)
        header:SetPoint("RIGHT", state.scrollChild, "RIGHT", 0, 0)
        header.title:SetText("Specific overrides")
        header:Show()
        y = y + 34
        local target, expected = GetValidatedFocusedRuntimeTarget(element, member)
        if not target then
            ShowContextualUnavailable(expected
                and ((element.composition.contextualTargetLabel or "This target")
                    .. " is no longer available. Return to Overview for family editing.")
                or "Select a visible instance to edit its overrides.", y + 8)
            ResizeInspector(nil, y + 72)
            return
        end
        local view = state.contextualOverrideView
        if not view then
            view = CreateFrame("Frame", nil, state.scrollChild)
            state.contextualOverrideView = view
        end
        view:ClearAllPoints()
        view:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT", 8, -y)
        view:SetPoint("RIGHT", state.scrollChild, "RIGHT", -8, 0)
        view:Show()
        y = y + RefreshOverrideListView(view, element, member.id, target)
        ResizeInspector(nil, y)
        return
    end
    state.contextualInspectorDetails[detailKey] = nil
    state.contextualAccordionExpansion = state.contextualAccordionExpansion or {}
    state.contextualDesignInitialized = state.contextualDesignInitialized or {}
    local initializeExpansion = not state.contextualDesignInitialized[detailKey]
    state.contextualDesignInitialized[detailKey] = true
    for groupIndex, group in ipairs(groups) do
        local key = detailKey .. "\031" .. group.id
        if initializeExpansion and state.contextualAccordionExpansion[key] == nil then
            state.contextualAccordionExpansion[key] = groupIndex <= 4
        end
        local section = EnsureContextualSummaryRow(key)
        section.detailKey, section.expansionKey = detailKey, key
        section.groupID, section.group = group.id, group
        local definition = NSkin:GetOptionGroupDefinition(group.id)
        local label = group.label or CONTEXTUAL_GROUP_LABELS[group.id] or group.id
        section.label:SetText(label)
        section.value:SetText(FormatContextualSummary(group))
        section.cells = {}
        section.headerToggleCell = nil
        section.enabledToggle:Hide()
        if section.actionView then section.actionView:Hide() end
        local actionsID = NSkin:EnsureOptionGroupInspectorActions(group.id)
        if actionsID then
            if not section.actionView then
                section.actionView = NSkin:CreateOptionGroupView(
                    section.body, actionsID, "FULL", group.context)
                section.actionView.isSkinningModeInspector = true
                section.actionView.preserveInspectorContext = true
            else
                section.actionView:SetContext(group.context)
            end
            section.actionView:Show()
        end
        section:Show()
        state.contextualActiveSections[#state.contextualActiveSections + 1] = section
        for _, property in ipairs(NSkin:GetOptionGroupOverrideProperties(group.id, true)) do
            local subsetID = NSkin:EnsureOptionGroupPropertySubset(
                group.id, member and member.id or element.id, property.key, property.label)
            if subsetID then
                local cell = EnsureContextualPropertyRow(key .. "\031" .. property.key)
                cell:SetParent(section.body)
                cell.groupID, cell.context, cell.property = group.id, group.context, property
                cell.subsetID, cell.section = subsetID, section
                cell.pairRow = nil
                cell.label:SetText(property.label or property.key)
                if property.control.editorHeaderToggle then
                    section.headerToggleCell = cell
                    cell:Hide()
                    RefreshContextualSectionPresentation(section)
                else
                    if not cell.view then
                        cell.view = NSkin:CreateOptionGroupView(
                            cell.valueCell, subsetID, "FULL", group.context)
                        cell.view.isSkinningModeInspector = true
                        cell.view.preserveInspectorContext = true
                        cell.view.boundContextID = group.context and group.context.id
                        cell.view.onValueCommitted = function()
                            RefreshContextualPropertySource(cell)
                            RefreshContextualSectionPresentation(section)
                        end
                    else
                        cell.view:SetContext(group.context)
                    end
                    cell.view:Show()
                    cell:Show()
                    RefreshContextualPropertySource(cell)
                    section.cells[#section.cells + 1] = cell
                end
            end
        end
        RefreshContextualSectionPresentation(section)
    end
    local overrides = member and GetContextualOverrideEntries(element, member) or {}
    if #overrides > 0 then
        local key = detailKey .. "\031__OVERRIDES"
        local section = EnsureContextualSummaryRow(key)
        section.detailKey, section.expansionKey = detailKey, key
        section.groupID = "__OVERRIDES"
        section.cells = {}
        section.label:SetText("Specific overrides")
        section.value:SetText(tostring(#overrides) .. " properties")
        section:Show()
        state.contextualActiveSections[#state.contextualActiveSections + 1] = section
    end
    LayoutContextualInspector()
end

local function LoadEditorOptions(element)
    local focusedMember = element and state.focusedCompositeMemberID
        and NSkin:GetCompositeMember(element, state.focusedCompositeMemberID)
    local contextualMember = GetContextualCompositeMember(element)
    local composition = element and element.composition
    if not contextualMember and composition
        and composition.mode == "COMPOSITE"
    then
        for _, member in ipairs(composition.members or {}) do
            if member.editorSurface == true then
                contextualMember = member
                break
            end
        end
    end

    local memberOptions, memberContext
    if contextualMember then
        memberOptions, memberContext =
            NSkin:GetCompositeMemberEditorOptions(
                element, contextualMember)
    end

    if IsContextualInspectorMember(element, contextualMember) then
        return LoadContextualInspector(element, contextualMember)
    end
    if IsContextualInspectorElement(element) and not contextualMember then
        return LoadContextualInspector(element, nil)
    end
    HideContextualInspectorRows()

    for _, view in pairs(state.optionViews) do
        view:SetContext(nil)
        view:Hide()
    end
    for i = 1, #state.editorSections do
        local section = state.editorSections[i]
        section:Hide()
        if section.tabBar then section.tabBar:Hide() end
        if section.overrideListView then
            section.overrideListView:Hide()
        end
    end
    local editorOptions = memberOptions
        or NSkin:GetCompositionEditorOptions(element)
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
    if not groups then groups = {} end

    local navigationRows = {}
    local function AppendNavigationGroups(
        definitions, context, keyPrefix, output, depth)
        depth = tonumber(depth) or 0
        for _, definition in ipairs(definitions or {}) do
            if type(definition) == "table"
                and definition.presentation == "NAV_TABS"
                and type(definition.tabs) == "table"
                and #definition.tabs > 0
            then
                local key = keyPrefix .. "\031" .. tostring(definition.id)
                local selected = math.min(
                    state.selectedEditorSubtabs[key] or 1,
                    #definition.tabs)
                state.selectedEditorSubtabs[key] = selected
                if depth > 0
                    or definition.inspectorNavigation == true
                then
                    navigationRows[#navigationRows + 1] = {
                        key = key,
                        tabs = definition.tabs,
                        selected = selected,
                    }
                end
                local tab = definition.tabs[selected]
                local tabContext = ResolveEditorContext(tab, context)
                if type(tab.tabs) == "table" and #tab.tabs > 0 then
                    AppendNavigationGroups({
                        {
                            id = tostring(definition.id)
                                .. "." .. tostring(tab.id),
                            presentation = "NAV_TABS",
                            tabs = tab.tabs,
                        },
                    }, tabContext, key, output, depth + 1)
                else
                    for _, child in ipairs(tab.groups or {}) do
                        if type(child) == "string" then
                            output[#output + 1] = {
                                id = child,
                                context = tabContext,
                            }
                        elseif type(child) == "table" then
                            local copy = {}
                            for childKey, value in pairs(child) do
                                copy[childKey] = value
                            end
                            if not copy.context and not copy.contextID then
                                copy.context = tabContext
                            end
                            output[#output + 1] = copy
                        end
                    end
                end
            else
                output[#output + 1] = definition
            end
        end
    end

    local resolvedGroups = {}
    AppendNavigationGroups(
        groups, element, element.id, resolvedGroups, 0)
    groups = resolvedGroups

    local overrideEntries = {}
    if element and focusedMember then
        for _, entry in ipairs(
            NSkin:GetCompositePropertyOverrides(element))
        do
            if OverrideEntryMatchesRuntimeTarget(
                element, focusedMember, entry,
                state.focusedCompositeRuntimeTarget)
            then
                overrideEntries[#overrideEntries + 1] = entry
            end
        end
    end
    if element and #overrideEntries == 0 then
        state.expandedEditorSections[
            element.id .. "\031composition.overrideList"] = nil
    end
    if #overrideEntries > 0 then
        local withOverrides = {}
        for i = 1, #groups do withOverrides[i] = groups[i] end
        withOverrides[#withOverrides + 1] = {
            id = "composition.overrideList",
            label = "Overrides",
            customOverrideList = true,
        }
        groups = withOverrides
    end

    local placementContext = memberContext or element
    local canEditPlacement = not memberOptions and placementContext
        and type(placementContext.getPlacement) == "function"
        and type(placementContext.setPlacement) == "function"
        and type(placementContext.resetPlacement) == "function"
    if canEditPlacement then
        local hasMovable
        for i = 1, #groups do
            local definition = groups[i]
            local id = type(definition) == "table"
                and definition.id or definition
            if id == "shared.movable" then
                hasMovable = true
                break
            end
        end
        if not hasMovable then
            local withPlacement = {
                {
                    id = "shared.movable",
                    label = "Position",
                    presentation = "INLINE",
                    category = "POSITION",
                    context = placementContext,
                },
            }
            for i = 1, #groups do
                withPlacement[#withPlacement + 1] = groups[i]
            end
            groups = withPlacement
        end
    end

    if #groups == 0 then
        ResizeInspector(nil)
        return
    end

    local y = SnapInspectorOffset(8)
    local sectionIndex = 0

    state.editorNavigationBars = state.editorNavigationBars or {}
    for _, bar in pairs(state.editorNavigationBars) do
        bar:Hide()
    end
    for _, row in ipairs(navigationRows) do
        local bar = state.editorNavigationBars[row.key]
        if not bar then
            bar = CreateFrame("Frame", nil, state.scrollChild)
            bar.buttons = {}
            state.editorNavigationBars[row.key] = bar
        end
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT",
            SnapInspectorOffset(8), -SnapInspectorOffset(y))
        local totalWidth = math.max(
            1, state.scrollChild:GetWidth() - 16)
        local count = math.max(1, #row.tabs)
        local buttonWidth = math.floor(totalWidth / count)
        bar:SetSize(totalWidth, 24)
        for tabIndex, tabDefinition in ipairs(row.tabs) do
            local button = bar.buttons[tabIndex]
            if not button then
                button = CreateButton(bar, "", buttonWidth, function(self)
                    state.selectedEditorSubtabs[self.navigationKey] =
                        self.tabIndex
                    RefreshInspector()
                end)
                bar.buttons[tabIndex] = button
            end
            button.navigationKey = row.key
            button.tabIndex = tabIndex
            button:SetText(tabDefinition.label or tabDefinition.id)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", bar, "TOPLEFT",
                (tabIndex - 1) * buttonWidth, 0)
            button:SetSize(
                tabIndex == count
                    and totalWidth - buttonWidth * (count - 1)
                    or buttonWidth,
                24)
            button:SetAlpha(
                tabIndex == row.selected and 1 or 0.65)
            button:Show()
        end
        for tabIndex = #row.tabs + 1, #bar.buttons do
            bar.buttons[tabIndex]:Hide()
        end
        bar:Show()
        y = SnapInspectorOffset(y + 27)
    end

    for i = 1, #groups do
        local definition = groups[i]
        local label = type(definition) == "table" and definition.label
        local id = type(definition) == "table" and definition.id or definition
        local optionContext = type(definition) == "table"
            and ResolveEditorContext(definition, element) or element
        local inline = IsInlineEditorDefinition(definition)
        if type(id) == "string" and inline then
            local view = state.optionViews[id]
            if not view then
                view = NSkin:CreateOptionGroupView(
                    state.scrollChild, id, "COMPACT", optionContext)
                state.optionViews[id] = view
            else
                view:SetContext(optionContext)
            end
            if view then
                view.isSkinningModeInspector = true
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
        local optionContext = type(definition) == "table"
            and ResolveEditorContext(definition, element) or element
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
                section.power = CreateFrame("Button", nil, section)
                section.power:SetSize(22, 22)
                section.power:SetPoint(
                    "LEFT", section.label, "RIGHT", 6, 0)
                section.power.icon = NSkin:CreateCenteredButtonGlyph(
                    section.power, "sectionPower", {
                        texture = "Interface\\AddOns\\NSkin\\Media\\power.png",
                        size = 15,
                    })
                section.power:SetScript("OnClick", function(self)
                    if not self.optionGroupID or not self.context
                        or not self.toggleKey
                    then return end
                    local definition =
                        NSkin:GetOptionGroupDefinition(self.optionGroupID)
                    local values = definition
                        and definition.get(self.context)
                    if not values then return end
                    NSkin:SetOptionGroupValues(
                        self.optionGroupID, self.context, {
                            [self.toggleKey] =
                                values[self.toggleKey] ~= true,
                        }, true)
                    RefreshInspector()
                end)
                section.power:SetScript("OnEnter", function(self)
                    if GameTooltip then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(
                            self.toggleTooltip or "Enable/disable")
                        GameTooltip:Show()
                    end
                end)
                section.power:SetScript("OnLeave", function()
                    if GameTooltip then GameTooltip:Hide() end
                end)
                section.icon = section:CreateTexture(nil, "OVERLAY")
                section.icon:SetSize(18, 18)
                section.icon:SetPoint("RIGHT", section, "RIGHT", -12, 0)
                section.icon:SetTexture(
                    "Interface\\AddOns\\NSkin\\Media\\angle-small-down.png")
                section.reset = CreateFrame("Button", nil, section)
                section.reset:SetSize(24, 24)
                section.reset:SetPoint("RIGHT", section.icon, "LEFT", -4, 0)
                section.reset.icon = NSkin:CreateCenteredButtonGlyph(
                    section.reset, "sectionReset", {
                        texture = "Interface\\AddOns\\NSkin\\Media\\rotate-right.png",
                        size = 16,
                    })
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
                    NSkin:SetCenteredButtonGlyphColor(
                        self.icon, NSkin:GetAccentColor())
                    if GameTooltip then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(self.tooltip or "Reset to window defaults")
                        GameTooltip:Show()
                    end
                end)
                section.reset:SetScript("OnLeave", function(self)
                    NSkin:SetCenteredButtonGlyphColor(
                        self.icon, { 1, 1, 1, 1 })
                    if GameTooltip then GameTooltip:Hide() end
                end)
                section.trash = CreateFrame("Button", nil, section)
                section.trash:SetSize(24, 24)
                section.trash:SetPoint(
                    "RIGHT", section.icon, "LEFT", -4, 0)
                section.trash.icon = NSkin:CreateCenteredButtonGlyph(
                    section.trash, "overrideTrash", {
                        texture = "Interface\\AddOns\\NSkin\\Media\\trash.png",
                        size = 16,
                    })
                section.trash:SetScript("OnClick", function(self)
                    if self.overrideOwner
                        and self.overrideMemberID
                    then
                        StaticPopup_Show(
                            CLEAR_OVERRIDES_DIALOG,
                            self.overrideOwner.label
                                or self.overrideOwner.id,
                            nil, {
                                element = self.overrideOwner,
                                memberID = self.overrideMemberID,
                                runtimeTarget =
                                    self.overrideRuntimeTarget,
                            })
                    end
                end)
                section.trash:SetScript("OnEnter", function(self)
                    NSkin:SetCenteredButtonGlyphColor(
                        self.icon, NSkin:GetAccentColor())
                    if GameTooltip then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText("Clear all overrides")
                        GameTooltip:AddLine(
                            "Removes every exact override for the current selection.",
                            1, 1, 1, true)
                        GameTooltip:Show()
                    end
                end)
                section.trash:SetScript("OnLeave", function(self)
                    NSkin:SetCenteredButtonGlyphColor(
                        self.icon, { 1, 1, 1, 1 })
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
            local customOverrideList =
                type(definition) == "table"
                and definition.customOverrideList == true
            local optionDefinition = not customOverrideList
                and NSkin:GetOptionGroupDefinition(id) or nil
            local hasInheritedReset = optionDefinition
                and optionDefinition.inheritedReset == true
            local headerToggleKey = type(definition) == "table"
                and definition.headerToggleKey
            section.power.optionGroupID = id
            section.power.context = optionContext
            section.power.toggleKey = headerToggleKey
            section.power.toggleTooltip = headerToggleKey
                and ("Toggle " .. tostring(
                    type(definition) == "table"
                        and (definition.label or id) or id))
                or nil
            local toggleValues = headerToggleKey and optionDefinition
                and optionDefinition.get(optionContext)
            local toggleEnabled = toggleValues
                and toggleValues[headerToggleKey] == true
            section.power:SetShown(headerToggleKey ~= nil)
            if headerToggleKey then
                NSkin:SetCenteredButtonGlyphColor(
                    section.power.icon,
                    toggleEnabled and NSkin:GetAccentColor()
                        or { 0.45, 0.45, 0.45, 1 })
            end
            section.reset.optionGroupID = id
            section.reset.context = optionContext
            section.reset.sectionLabel = type(definition) == "table"
                and (definition.label or id) or id
            section.reset.tooltip = optionDefinition
                and optionDefinition.inheritedResetLabel
            section.reset:SetShown(hasInheritedReset)
            section.trash.overrideOwner =
                customOverrideList and element or nil
            section.trash.overrideMemberID =
                customOverrideList and focusedMember
                    and focusedMember.id or nil
            section.trash.overrideRuntimeTarget =
                customOverrideList
                    and state.focusedCompositeRuntimeTarget or nil
            section.trash:SetShown(
                customOverrideList
                    and focusedMember ~= nil)
            section.label:SetText(type(definition) == "table"
                and (definition.label or id) or "Options")
            section.icon:SetRotation(expanded and math.pi or 0)
            NSkin:SetPixelBorderColor(
                NSkin:GetPixelBorder(section, "NSkinFlatBackgroundBorder"),
                unpack(expanded and NSkin:GetAccentColor()
                    or NSkin:GetStyle("window").header.divider))
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT", 0,
                -SnapInspectorOffset(y))
            section:SetPoint("RIGHT", state.scrollChild, "RIGHT", 0, 0)
            section:Show()
            y = SnapInspectorOffset(y + 47)

            if expanded then
                if customOverrideList then
                    local view = section.overrideListView
                    if not view then
                        view = CreateFrame("Frame", nil, state.scrollChild)
                        view:SetWidth(502)
                        section.overrideListView = view
                    end
                    view:ClearAllPoints()
                    view:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT",
                        SnapInspectorOffset(8), -SnapInspectorOffset(y))
                    view:Show()
                    local height = RefreshOverrideListView(
                        view, element,
                        focusedMember and focusedMember.id or nil,
                        state.focusedCompositeRuntimeTarget)
                    y = SnapInspectorOffset(y + height)
                else
                local tabs = type(definition) == "table" and definition.tabs
                local viewIDs, viewContext = { id }, optionContext
                if type(tabs) == "table" and #tabs > 0 then
                    local selected = state.selectedEditorSubtabs[key] or 1
                    selected = math.min(selected, #tabs)
                    state.selectedEditorSubtabs[key] = selected
                    local tab = tabs[selected]
                    viewIDs = tab.groups or { tab.id }
                    viewContext = ResolveEditorContext(
                        tab, optionContext)
                    local bar = section.tabBar
                    if not bar then
                        bar = CreateFrame("Frame", nil, state.scrollChild)
                        section.tabBar = bar
                        bar.buttons = {}
                    end
                    bar:ClearAllPoints()
                    bar:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT",
                        SnapInspectorOffset(8), -SnapInspectorOffset(y))
                    bar:SetSize(math.max(1, state.scrollChild:GetWidth() - 16), 24)
                    for tabIndex, tabDefinition in ipairs(tabs) do
                        local button = bar.buttons[tabIndex]
                        if not button then
                            button = CreateButton(bar, tabDefinition.label, 80,
                                function(self)
                                    state.selectedEditorSubtabs[self.sectionKey] = self.tabIndex
                                    RefreshInspector()
                                end)
                            bar.buttons[tabIndex] = button
                        end
                        button.sectionKey, button.tabIndex = key, tabIndex
                        button:ClearAllPoints()
                        button:SetPoint("TOPLEFT", bar, "TOPLEFT",
                            (tabIndex - 1) * 84, 0)
                        button:Show()
                        button:SetAlpha(tabIndex == selected and 1 or 0.65)
                    end
                    for tabIndex = #tabs + 1, #bar.buttons do
                        bar.buttons[tabIndex]:Hide()
                    end
                    bar:Show()
                    y = SnapInspectorOffset(y + 27)
                end
                for _, viewID in ipairs(viewIDs) do
                    local view = viewContext and state.optionViews[viewID]
                    if not view then
                        if viewContext then
                            view = NSkin:CreateOptionGroupView(
                                state.scrollChild, viewID, "COMPACT", viewContext)
                            state.optionViews[viewID] = view
                        end
                    else
                        view:SetContext(viewContext)
                    end
                    if view then
                        view.isSkinningModeInspector = true
                        if view.SetExternalEnabled then
                            view:SetExternalEnabled(
                                headerToggleKey == nil or toggleEnabled)
                        end
                        view:ClearAllPoints()
                        view:SetPoint("TOPLEFT", state.scrollChild, "TOPLEFT",
                            SnapInspectorOffset(8), -SnapInspectorOffset(y))
                        view:Show()
                        y = SnapInspectorOffset(y + view:GetHeight() - 1)
                    end
                end
                end
            end
        end
    end
    ResizeInspector(nil, y)
end

RefreshInspector = function()
    if not state then return end
    local element = state.selectedElement
    local member = element and state.focusedCompositeMemberID
        and NSkin:GetCompositeMember(
            element, state.focusedCompositeMemberID)
    local selectionLabel = GetDockSelectionLabel(element)
    if IsContextualInspectorElement(element) then
        local composition = element.composition or {}
        selectionLabel = tostring(
            composition.editorLabel or composition.groupLabel
                or (composition.mode == "CONTAINER" and GetDockContainerLabel(element))
                or element.label or element.id)
        local parent = NSkin:GetCompositionContainerParent(element)
        if parent then
            selectionLabel = GetDockContainerLabel(parent) .. " > " .. selectionLabel
        end
    end
    state.inspector.selection:SetText(
        selectionLabel or "Select an element"
    )
    RefreshHeaderActions(element)
    LoadEditorOptions(element)
    NSkin:ApplyGlobalTypography(state.inspector)
    ApplyInspectorTextStyle(state.inspector)
    local selection = state.inspector.selection
    local parent = element and NSkin:GetCompositionContainerParent(element)
    local breadcrumb = IsContextualInspectorElement(element) and parent ~= nil
    selection.label:SetShown(not breadcrumb)
    selection.parentButton:SetShown(breadcrumb)
    selection.separator:SetShown(breadcrumb)
    selection.currentLabel:SetShown(breadcrumb)
    if breadcrumb then
        selection.parentButton.label:SetText(GetDockContainerLabel(parent))
        selection.parentButton:SetWidth(
            math.ceil(selection.parentButton.label:GetStringWidth()) + 2)
        local composition = element.composition or {}
        selection.currentLabel:SetText(composition.editorLabel
            or composition.groupLabel or element.label or element.id)
        selection.currentLabel:SetTextColor(unpack(NSkin:GetAccentColor()))
    end
    local activeMember = GetContextualCompositeMember(element)
    selection.memberSeparator:SetShown(activeMember ~= nil)
    selection.memberLabel:SetShown(activeMember ~= nil)
    InspectorFont(selection.label, 10, INSPECTOR_THEME.muted)
    InspectorFont(selection.parentButton.label, 10, INSPECTOR_THEME.muted)
    InspectorFont(selection.separator, 10, INSPECTOR_THEME.muted)
    InspectorFont(selection.currentLabel, 10, activeMember and INSPECTOR_THEME.muted or INSPECTOR_THEME.accent)
    InspectorFont(selection.memberSeparator, 10, INSPECTOR_THEME.muted)
    InspectorFont(selection.memberLabel, 10, INSPECTOR_THEME.accent)
    selection.currentLabel:ClearAllPoints()
    selection.currentLabel:SetPoint("LEFT", selection.separator, "RIGHT", 6, 0)
    selection.label:ClearAllPoints()
    selection.label:SetPoint("LEFT")
    local ownerLabel = breadcrumb and selection.currentLabel or selection.label
    if activeMember then
        selection.memberLabel:SetText(GetDockMemberLabel(element, activeMember) or activeMember.label or activeMember.id)
        local parentWidth = breadcrumb and math.min(selection:GetWidth() * 0.43,
            math.ceil(selection.parentButton.label:GetStringWidth()) + 2) or 0
        if breadcrumb then selection.parentButton:SetWidth(parentWidth) end
        local memberWidth = math.ceil(selection.memberLabel:GetStringWidth()) + 2
        ownerLabel:SetWidth(math.max(1, math.min(math.ceil(ownerLabel:GetStringWidth()) + 2,
            selection:GetWidth() - parentWidth - memberWidth - 28)))
        selection.memberSeparator:ClearAllPoints()
        selection.memberSeparator:SetPoint("LEFT", ownerLabel, "RIGHT", 6, 0)
        selection.memberLabel:ClearAllPoints()
        selection.memberLabel:SetPoint("LEFT", selection.memberSeparator, "RIGHT", 6, 0)
        selection.memberLabel:SetPoint("RIGHT")
    else
        ownerLabel:SetWidth(math.max(1, selection:GetWidth()
            - (breadcrumb and selection.parentButton:GetWidth() + 16 or 0)))
    end
    if IsContextualInspectorElement(element) then
        state.inspector.contextScope:SetTextColor(0.75, 0.75, 0.75, 1)
        for _, section in ipairs(state.contextualActiveSections or {}) do
            RefreshContextualSectionPresentation(section)
            for _, pair in pairs(section.pairRows or {}) do
                pair.source:SetTextColor(0.65, 0.65, 0.65, 1)
                LayoutContextualPropertyHeading(pair, pair:GetWidth(), true)
            end
            for _, cell in ipairs(section.cells) do
                InspectorFont(cell.label, 10)
                cell.source:Hide()
                NSkin:SetCenteredButtonGlyphColor(cell.reset.icon, INSPECTOR_THEME.muted)
                cell.source:SetTextColor(0.65, 0.65, 0.65, 1)
                if not cell.pairRow or cell.pairRow.mixedSources then
                    LayoutContextualPropertyHeading(cell, cell:GetWidth())
                end
            end
        end
    end
    RefreshHeaderActions(element)
    if state.contextualInspectorHeader and #(state.contextualActiveSections or {}) > 0 then
        LayoutContextualInspector()
    end
    NSkin:ResnapPixelBordersForTarget(state.inspector)
    NSkin:ResnapPixelBordersForTarget(state.scrollChild)
    if element then NSkin:ResnapPixelBordersForElement(element) end
    if not state.contextualInspectorHeader and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if state then
                ResizeInspector(nil,
                    math.max(0, (state.scrollChild:GetHeight() or 1) - 1))
                NSkin:ResnapPixelBordersForTarget(state.inspector)
                NSkin:ResnapPixelBordersForTarget(state.scrollChild)
                if state.selectedElement then
                    NSkin:ResnapPixelBordersForElement(state.selectedElement)
                end
            end
        end)
    end
end




local DockedWindow = {}
DockedWindow.__index = DockedWindow

function DockedWindow:OpenOverridePopup(element, memberID)
    OpenOverridePopup(element, memberID)
end

function DockedWindow:Refresh(element, memberID, runtimeTarget)
    local contextChanged = state.selectedElement ~= element
        or state.focusedCompositeMemberID ~= memberID
    state.selectedElement = element
    state.focusedCompositeMemberID = memberID

    local member = element and memberID
        and NSkin:GetCompositeMember(element, memberID)
    if runtimeTarget ~= nil then
        state.focusedCompositeRuntimeTarget = runtimeTarget
        state.focusedCompositeRuntimeAppearanceID = member
            and NSkin:GetCompositeMemberTargetAppearanceID(
                element, member, runtimeTarget) or nil
    elseif contextChanged then
        state.focusedCompositeRuntimeTarget = nil
        state.focusedCompositeRuntimeAppearanceID = nil
    end

    local focusedTarget = state.focusedCompositeRuntimeTarget
    if IsContextualInspectorMember(element, member) and focusedTarget then
        focusedTarget = GetValidatedFocusedRuntimeTarget(element, member)
        if not focusedTarget then
            NSkin:ClearCompositeMemberEditorPreview(element, member)
            member._editorStateTarget = nil
        end
    end
    if member then member._editorRuntimeTarget = focusedTarget end
    if member and focusedTarget and #(member.states or {}) > 0
        and not IsContextualInspectorMember(element, member)
    then
        local runtimeState = NSkin:GetCompositeMemberRuntimeState(
            element, member, focusedTarget)
        if runtimeState then
            NSkin:SetCompositeMemberEditorState(
                element, member, runtimeState, focusedTarget, false)
        end
    end
    if contextChanged then
        FocusEditorSection(element, memberID)
    end
    RefreshInspector()
end

function DockedWindow:Dock(window)
    local inspector = state.inspector
    if state.inspectorManuallyPositioned then return end
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
    if RefreshDebugLauncher then
        RefreshDebugLauncher(state.contextualInspectorHeader == true)
    end
end

function DockedWindow:ResetScroll()
    state.scrollFrame:SetVerticalScroll(0)
end

function DockedWindow:RefreshAppearance()
    NSkin:SkinWindow(state.inspector, nil, state.inspector.inspectorStyle, INSPECTOR_THEME.border)
    NSkin:SkinWindowHeader(state.inspector)
    NSkin:ApplyGlobalTypography(state.inspector)
    ApplyInspectorTextStyle(state.inspector)
    if state.debugToggle then NSkin:SkinFlatButton(state.debugToggle, "Debug") end
    if state.inspector.addOverride then
        NSkin:SkinFlatButton(state.inspector.addOverride, "+ Override")
    end
    if state.overridePopup then
        NSkin:RefreshSelectionPopupAppearance(state.overridePopup)
    end
    RefreshInspector()
end

function NSkin:CreateDockedWindow(owner)
    state = owner
    state.optionViews = state.optionViews or {}
    state.editorSections = state.editorSections or {}
    state.expandedEditorSections = state.expandedEditorSections or {}
    state.selectedEditorSubtabs = state.selectedEditorSubtabs or {}
    state.contextualInspectorDetails =
        state.contextualInspectorDetails or {}
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
    if not StaticPopupDialogs[CLEAR_OVERRIDES_DIALOG] then
        StaticPopupDialogs[CLEAR_OVERRIDES_DIALOG] = {
            text = "Clear all exact overrides for %s?\n\nShared Surface, Icon, Text, and family position settings are kept.",
            button1 = YES,
            button2 = NO,
            OnAccept = function(_, data)
                if data and data.element and data.memberID then
                    local member = NSkin:GetCompositeMember(data.element, data.memberID)
                    if data.appearanceID then
                        local target, expected = GetValidatedFocusedRuntimeTarget(data.element, member)
                        if target ~= data.runtimeTarget or expected ~= data.appearanceID then return end
                    end
                    ClearCompositeOverrides(
                        data.element, data.memberID,
                        data.runtimeTarget)
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end
    if not StaticPopupDialogs[RESET_ELEMENT_DIALOG] then
        StaticPopupDialogs[RESET_ELEMENT_DIALOG] = {
            text = "Reset all customizations for %s?\n\nIts Blizzard layout will be restored while the default NSkin skin remains applied.",
            button1 = YES,
            button2 = NO,
            OnAccept = function(_, target)
                if target and target.compositeOwner
                    and target.compositeMember
                then
                    NSkin:ResetCompositeMemberCustomizations(
                        target.compositeOwner, target.compositeMember)
                    RefreshInspector()
                elseif target then
                    ResetElementCustomizations(target)
                    RefreshInspector()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
    end

    local inspector = CreateFrame("Frame", nil, UIParent)
    inspector.nskinOwnedGeometry = true
    inspector:SetSize(432, 704)
    inspector:SetFrameStrata("DIALOG")
    inspector:SetMovable(true)
    inspector:SetClampedToScreen(true)
    local inspectorStyle = CopyTable(NSkin:GetStyle("window"))
    inspectorStyle.background = INSPECTOR_THEME.background
    inspectorStyle.backgroundOpacity = 1
    inspectorStyle.backgroundSource = "REGULAR"
    inspectorStyle.showBackground, inspectorStyle.showBorder = true, true
    inspectorStyle.borderSize, inspectorStyle.borderPadding = 1, 0
    inspector.inspectorStyle = inspectorStyle
    NSkin:SkinWindow(inspector, nil, inspectorStyle, INSPECTOR_THEME.border)
    NSkin:SkinWindowHeader(inspector)

    local dragRegion = CreateFrame("Frame", nil, inspector)
    dragRegion:SetPoint("TOPLEFT", inspector, "TOPLEFT", 1, -1)
    dragRegion:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -1, -1)
    dragRegion:SetHeight(22)
    dragRegion:EnableMouse(true)
    dragRegion:RegisterForDrag("LeftButton")
    dragRegion:SetScript("OnDragStart", function()
        inspector:StartMoving()
    end)
    dragRegion:SetScript("OnDragStop", function()
        inspector:StopMovingOrSizing()
        state.inspectorManuallyPositioned = true
        if RefreshDebugLauncher then
            RefreshDebugLauncher(state.contextualInspectorHeader == true)
        end
    end)
    state.inspectorDragRegion = dragRegion

    inspector.title = CreateLabel(inspector, "Skinning Mode", "TOPLEFT", inspector, "TOPLEFT", 12, -5)
    inspector.logo = inspector:CreateTexture(nil, "OVERLAY")
    inspector.logo:SetTexture("Interface\\AddOns\\NSkin\\Media\\logo.png")
    inspector.logo:SetSize(18, 18)
    inspector.logo:SetPoint("TOPLEFT", inspector, "TOPLEFT", 14, -12)
    inspector.subtitle = CreateLabel(inspector, "Blizzard window · Docked/Floating",
        "TOPLEFT", inspector, "TOPLEFT", 96, -17)
    InspectorFont(inspector.subtitle, 9, INSPECTOR_THEME.muted)
    inspector.panel = CreateFrame("Frame", nil, inspector)
    inspector.panel:SetPoint("TOPLEFT", inspector, "TOPLEFT", 12, -48)
    inspector.panel:SetPoint("BOTTOMRIGHT", inspector, "BOTTOMRIGHT", -12, 32)
    inspector.panel:SetFrameLevel(inspector:GetFrameLevel())
    InspectorSurface(inspector.panel, INSPECTOR_THEME.panel, true)
    inspector.breadcrumbLine = inspector:CreateTexture(nil, "ARTWORK")
    inspector.breadcrumbLine:SetHeight(1)
    inspector.breadcrumbLine:SetColorTexture(unpack(INSPECTOR_THEME.border))
    inspector.breadcrumbIcon = inspector:CreateTexture(nil, "OVERLAY")
    inspector.breadcrumbIcon:SetTexture("Interface\\AddOns\\NSkin\\Media\\grid-alt.png")
    inspector.breadcrumbIcon:SetSize(11, 11)
    inspector.breadcrumbIcon:SetPoint("TOPLEFT", inspector, "TOPLEFT", 22, -59)
    inspector.breadcrumbIcon:SetVertexColor(unpack(INSPECTOR_THEME.muted))
    inspector.editingLabel = CreateLabel(inspector, "Editing", "TOPLEFT", inspector, "TOPLEFT", 30, -100)
    InspectorFont(inspector.editingLabel, 10, INSPECTOR_THEME.muted)
    inspector.stateTrack = CreateFrame("Frame", nil, inspector)
    inspector.stateTrack:SetFrameLevel(inspector:GetFrameLevel())
    InspectorSurface(inspector.stateTrack, INSPECTOR_THEME.input, true)
    inspector.designBar = CreateFrame("Frame", nil, inspector)
    inspector.designBar:SetFrameLevel(inspector:GetFrameLevel())
    inspector.designLabel = CreateLabel(inspector.designBar, "Design", "LEFT", inspector.designBar, "LEFT", 18, 0)
    InspectorFont(inspector.designLabel, 12, INSPECTOR_THEME.accent)
    inspector.designUnderline = inspector.designBar:CreateTexture(nil, "ARTWORK")
    inspector.designUnderline:SetPoint("BOTTOMLEFT", inspector.designBar, "BOTTOMLEFT", 18, 0)
    inspector.designUnderline:SetSize(40, 2)
    inspector.designUnderline:SetColorTexture(unpack(INSPECTOR_THEME.accent))
    local designDivider = inspector.designBar:CreateTexture(nil, "BACKGROUND")
    designDivider:SetPoint("TOPLEFT")
    designDivider:SetPoint("TOPRIGHT")
    designDivider:SetHeight(1)
    designDivider:SetColorTexture(unpack(INSPECTOR_THEME.border))
    local close = CreateButton(inspector, "", 22, function()
        NSkin:SetSkinningModeEnabled(false)
    end)
    NSkin:CreateCenteredButtonGlyph(close, "inspectorClose", {
        glyph = "close",
    })
    close:SetFrameLevel(dragRegion:GetFrameLevel() + 1)
    close:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -10, -9)
    InspectorSurface(close, { 0, 0, 0, 0 }, false)
    inspector.closeButton = close
    local debugToggle = CreateFrame("Button", nil, inspector)
    debugToggle:SetFrameLevel(dragRegion:GetFrameLevel() + 1)
    debugToggle:SetSize(52, 22)
    debugToggle:SetPoint("RIGHT", close, "LEFT", -4, 0)
    NSkin:SkinFlatButton(debugToggle, "Debug")
    debugToggle:SetScript("OnClick", function()
        NSkin:ToggleSkinningDebugInspector(inspector)
    end)
    debugToggle:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Toggle debug inspector")
            GameTooltip:AddLine("Shows the selected element's composition, runtime targets, appearance layers, editor options, and bounds.",
                1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    debugToggle:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    state.debugToggle = debugToggle
    local dockToggle = CreateButton(inspector, "", 20, function()
        state.inspectorManuallyPositioned = not state.inspectorManuallyPositioned
        if not state.inspectorManuallyPositioned and state.selectedElement then
            state.dockedWindow:Dock(state.selectedElement.window)
        end
    end)
    dockToggle:SetFrameLevel(dragRegion:GetFrameLevel() + 1)
    dockToggle:SetPoint("RIGHT", close, "LEFT", -6, 0)
    InspectorSurface(dockToggle, { 0, 0, 0, 0 }, false)
    dockToggle.icon = dockToggle:CreateTexture(nil, "OVERLAY")
    dockToggle.icon:SetTexture("Interface\\AddOns\\NSkin\\Media\\grid-alt.png")
    dockToggle.icon:SetSize(12, 12)
    dockToggle.icon:SetPoint("CENTER")
    dockToggle.icon:SetVertexColor(unpack(INSPECTOR_THEME.muted))
    dockToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(state.inspectorManuallyPositioned and "Dock inspector" or "Float inspector")
        GameTooltip:Show()
    end)
    dockToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local debugLauncher = CreateButton(inspector, "", 20, function()
        NSkin:ToggleSkinningDebugInspector(inspector)
    end)
    debugLauncher:SetFrameLevel(inspector:GetFrameLevel() + 20)
    debugLauncher:SetSize(20, 30)
    debugLauncher.arrow = debugLauncher:CreateTexture(nil, "OVERLAY")
    debugLauncher.arrow:SetTexture("Interface\\AddOns\\NSkin\\Media\\angle-small-down.png")
    debugLauncher.arrow:SetSize(12, 12)
    debugLauncher.arrow:SetPoint("CENTER")
    debugLauncher:SetScript("OnEnter", debugToggle:GetScript("OnEnter"))
    debugLauncher:SetScript("OnLeave", debugToggle:GetScript("OnLeave"))
    debugLauncher:Hide()
    RefreshDebugLauncher = function(contextual)
        debugLauncher:SetShown(true)
        debugToggle:Hide()
        if inspector then
            local left, right = NSkin:GetUIParentNormalizedBounds(inspector)
            local screenRight = UIParent:GetRight() or UIParent:GetWidth()
            local rightSpace = screenRight - (right or screenRight)
            local towardRight = rightSpace >= 140 or rightSpace >= (left or 0)
            debugLauncher:ClearAllPoints()
            debugLauncher:SetPoint(towardRight and "LEFT" or "RIGHT", inspector,
                towardRight and "RIGHT" or "LEFT", towardRight and 1 or -1, 0)
            debugLauncher.arrow:SetRotation(towardRight and math.pi / 2 or -math.pi / 2)
        end
    end

    local selection = CreateFrame("Button", nil, inspector)
    selection:SetFrameLevel(dragRegion:GetFrameLevel() + 1)
    selection:SetHeight(20)
    selection:RegisterForDrag("LeftButton")
    selection:SetScript("OnDragStart", function()
        inspector:StartMoving()
    end)
    selection:SetScript("OnDragStop", function()
        state.inspectorDragRegion:GetScript("OnDragStop")()
    end)
    selection:SetPoint("TOPLEFT", inspector, "TOPLEFT", 12, -25)
    selection.label = selection:CreateFontString(
        nil, "OVERLAY", "GameFontNormal")
    selection.label:SetAllPoints(selection)
    selection.label:SetJustifyH("LEFT")
    selection.label:SetText("Select an element")
    function selection:SetText(value)
        self.label:SetText(value)
    end
    function selection:SetJustifyH(value)
        self.label:SetJustifyH(value)
    end
    selection:SetScript("OnClick", function()
        local element = state.selectedElement
        local parent = element
            and NSkin:GetCompositionContainerParent(element)
        if parent and NSkin.SelectSkinningElement then
            NSkin:SelectSkinningElement(parent)
        end
    end)
    selection:SetScript("OnEnter", function(self)
        local element = state.selectedElement
        if element and NSkin:GetCompositionContainerParent(element) then
            self.label:SetTextColor(unpack(NSkin:GetAccentColor()))
        end
    end)
    selection:SetScript("OnLeave", function(self)
        self.label:SetTextColor(1, 1, 1, 1)
    end)
    selection.parentButton = CreateFrame("Button", nil, selection)
    selection.parentButton:SetPoint("LEFT")
    selection.parentButton:SetHeight(20)
    selection.parentButton.label = selection.parentButton:CreateFontString(
        nil, "OVERLAY", "GameFontNormal")
    selection.parentButton.label:SetPoint("LEFT")
    selection.parentButton:SetScript("OnClick", selection:GetScript("OnClick"))
    selection.parentButton:SetScript("OnEnter", function(self)
        self.label:SetTextColor(unpack(NSkin:GetAccentColor()))
    end)
    selection.parentButton:SetScript("OnLeave", function(self)
        self.label:SetTextColor(1, 1, 1, 1)
    end)
    selection.separator = selection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selection.separator:SetText(">")
    selection.separator:SetPoint("LEFT", selection.parentButton, "RIGHT", 4, 0)
    selection.currentLabel = selection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selection.currentLabel:SetPoint("LEFT", selection.separator, "RIGHT", 4, 0)
    selection.currentLabel:SetPoint("RIGHT")
    selection.currentLabel:SetJustifyH("LEFT")
    selection.currentLabel:SetWordWrap(false)
    selection.memberSeparator = selection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selection.memberSeparator:SetText(">")
    selection.memberLabel = selection:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selection.memberLabel:SetWordWrap(false)
    selection.memberSeparator:Hide()
    selection.memberLabel:Hide()
    selection.parentButton:Hide()
    selection.separator:Hide()
    selection.currentLabel:Hide()
    inspector.selection = selection
    inspector.stateLabel = CreateLabel(
        inspector, "State:", "TOPLEFT", inspector, "TOPLEFT", 12, -48)
    inspector.stateLabel:Hide()
    inspector.stateButtons = {}
    local resetElement = CreateButton(inspector, "Reset All", 96,
        function()
            local element = state.selectedElement
            if not element then return end
            local composition = element.composition
            local member = GetContextualCompositeMember(element)
            local exact = IsContextualInspectorMember(element, member)
                and state.contextualInspectorDetails[
                    element.id .. "\031" .. member.id] == "__OVERRIDES"
            if exact then
                local target, expected = GetValidatedFocusedRuntimeTarget(element, member)
                if not target then return end
                StaticPopup_Show(CLEAR_OVERRIDES_DIALOG,
                    composition.contextualTargetLabel or "this target", nil, {
                        element = element, memberID = member.id,
                        runtimeTarget = target, appearanceID = expected,
                    })
            elseif composition and composition.mode == "COMPOSITE" then
                ResetCompositeSelection(element)
                RefreshInspector()
            else
                StaticPopup_Show(RESET_ELEMENT_DIALOG,
                    element.label or element.id, nil, element)
            end
        end)
    resetElement.inspectorResetIcon = resetElement:CreateTexture(nil, "OVERLAY")
    resetElement.inspectorResetIcon:SetTexture("Interface\\AddOns\\NSkin\\Media\\rotate-right.png")
    resetElement.inspectorResetIcon:SetSize(12, 12)
    resetElement.inspectorResetIcon:SetPoint("LEFT", resetElement, "LEFT", 3, 0)
    resetElement.inspectorResetIcon:SetVertexColor(unpack(INSPECTOR_THEME.muted))
    resetElement:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -12, -27)
    resetElement:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(
                self.resetLabel or "Reset All")
            GameTooltip:AddLine(self.resetLabel == "Clear Overrides"
                and "Clears the selected target's exact overrides. Shared family settings are kept."
                or "Resets the selected shared editor family without removing exact-member overrides.",
                1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    resetElement:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    resetElement:Hide()

    local addOverride = CreateButton(inspector, "+ Override", 92,
        function()
            local element = state.selectedElement
            if not element then return end
            OpenOverridePopup(element, state.focusedCompositeMemberID)
        end)
    addOverride:SetPoint("RIGHT", resetElement, "LEFT", -4, 0)
    addOverride:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Add specific override")
            GameTooltip:AddLine(self:IsEnabled()
                and "Choose one member and one or more properties to make sparse exceptions to the Composite's shared appearance."
                or "Select this member on a visible instance before adding a specific override.",
                1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    addOverride:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    addOverride:Hide()

    local memberTabs = CreateFrame("Frame", nil, inspector)
    memberTabs:SetPoint(
        "TOPLEFT", inspector, "TOPLEFT", 12, -55)
    memberTabs:SetPoint(
        "TOPRIGHT", inspector, "TOPRIGHT", -12, -55)
    memberTabs:SetHeight(24)
    memberTabs.buttons = {}
    memberTabs:Hide()
    inspector.memberTabs = memberTabs

    local menus = NSkin._componentOptionMenus
    local memberPicker = menus.CreateOwnedDropdown(inspector)
    menus.SkinAddonDropdown(memberPicker)
    memberPicker:SetupMenu(function(self, root)
        local element = self.element
        if self.navigationEntries then
            for _, entry in ipairs(self.navigationEntries) do
                root:CreateRadio(entry.label,
                    function() return self.navigationSelectedKey == entry.familyKey end,
                    function()
                        if entry.editorNavigation then
                            state.selectedEditorSubtabs[entry.navigationKey] = entry.navigationIndex
                            RefreshInspector()
                        elseif entry.member then
                            NSkin:SelectSkinningCompositeMember(
                                entry.element, entry.member.id, nil)
                        else
                            NSkin:SelectSkinningElement(entry.element)
                        end
                    end)
            end
            return
        end
        for _, member in ipairs(element and element.composition.members or {}) do
            root:CreateRadio(GetDockMemberLabel(element, member)
                    or member.label or member.id,
                function() return self.member == member end,
                function()
                    NSkin:SelectSkinningCompositeMember(element, member.id, nil)
                end)
        end
    end)
    memberPicker:Hide()
    inspector.memberPicker = memberPicker

    local contextScope = CreateLabel(
        inspector, "", "TOPLEFT", inspector, "TOPLEFT", 240, -55)
    contextScope:SetTextColor(0.75, 0.75, 0.75, 1)
    contextScope:Hide()
    inspector.contextScope = contextScope

    inspector.selection:SetPoint("RIGHT", resetElement, "LEFT", -8, 0)
    inspector.selection:SetJustifyH("LEFT")
    inspector.resetElement = resetElement
    inspector.addOverride = addOverride
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
    scrollChild:SetSize(392, 1)
    scrollFrame:SetScrollChild(scrollChild)
    state.scrollFrame = scrollFrame
    state.scrollChild = scrollChild
    inspector.scrollBar = CreateFrame("Slider", nil, inspector)
    local scrollBar = inspector.scrollBar
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetWidth(7)
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 10, -8)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 10, 8)
    scrollBar:SetMinMaxValues(0, 1)
    scrollBar:SetValueStep(1)
    scrollBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    scrollBar:GetThumbTexture():SetSize(3, 60)
    scrollBar:GetThumbTexture():SetColorTexture(unpack(INSPECTOR_THEME.muted))
    scrollBar:SetScript("OnValueChanged", function(self, value)
        if not self.syncing then scrollFrame:SetVerticalScroll(value) end
    end)
    scrollFrame:HookScript("OnVerticalScroll", RefreshInspectorScrollBar)
    scrollFrame:HookScript("OnScrollRangeChanged", RefreshInspectorScrollBar)
    scrollBar:Hide()

    local overridePopup = NSkin:CreateSelectionPopup({
        title = "Add Override",
        width = 760,
        height = 360,
        confirmLabel = "Add Override",
        cancelLabel = "Cancel",
        columns = {
            {
                label = "Element",
                items = function(element)
                    local composition = element and element.composition
                    return composition and composition.members or {}
                end,
                getID = function(member)
                    return member and member.id
                end,
                getLabel = function(member)
                    return member and (member.label or member.id)
                end,
            },
            {
                label = "Category",
                items = function(element, selections)
                    return GetOverrideCategoriesForMember(
                        element, selections and selections[1])
                end,
                getID = function(category)
                    return category and category.id
                end,
                getLabel = function(category)
                    return category and category.label
                end,
            },
            {
                label = "Option",
                multiSelect = true,
                items = function(_, selections)
                    local category = selections and selections[2]
                    return GetOverridePropertiesForMember(
                        selections and selections[1],
                        category and category.id)
                end,
                getID = function(property)
                    return property and (
                        tostring(property.groupID) .. "\031"
                        .. tostring(property.propertyKey))
                end,
                getLabel = function(property)
                    return property and property.propertyLabel
                end,
            },
        },
        canConfirm = function(element, selections)
            local member = selections and selections[1]
            if IsContextualInspectorElement(element) then
                if not member or member.id ~= state.focusedCompositeMemberID
                    or not GetValidatedFocusedRuntimeTarget(element, member)
                then return false end
            end
            return element ~= nil
                and selections
                and selections[1] ~= nil
                and selections[2] ~= nil
                and type(selections[3]) == "table"
                and #selections[3] > 0
        end,
        onConfirm = function(element, selections)
            local member = selections and selections[1]
            local properties = selections and selections[3]
            if not element or not member
                or type(properties) ~= "table" or #properties == 0
            then return end

            local runtimeTarget = state.focusedCompositeRuntimeTarget
            if IsContextualInspectorMember(element, member) then
                if element ~= state.selectedElement
                    or member.id ~= state.focusedCompositeMemberID
                then return end
                runtimeTarget = GetValidatedFocusedRuntimeTarget(element, member)
                if not runtimeTarget then return end
            end
            local exactAppearanceID =
                NSkin:GetCompositeMemberTargetAppearanceID(
                    element, member, runtimeTarget)
            if exactAppearanceID == (member.appearanceID or member.id) then
                exactAppearanceID = nil
            end

            local changed
            for _, property in ipairs(properties) do
                if NSkin:AddCompositePropertyOverride(
                    element, member.id, property.groupID,
                    property.propertyKey, property.propertyLabel,
                    runtimeTarget)
                then
                    local entry = {
                        memberID = member.id,
                        groupID = property.groupID,
                        propertyKey = property.propertyKey,
                        propertyLabel = property.propertyLabel,
                        appearanceID = exactAppearanceID,
                        label = (member.label or member.id)
                            .. " - " .. property.propertyLabel,
                    }
                    GetOverrideSubsetID(element, entry)
                    changed = true
                end
            end

            if changed then
                if IsContextualInspectorMember(element, member) then
                    state.contextualInspectorDetails[
                        GetContextualDetailKey(element, member)] =
                        "__OVERRIDES"
                else
                    local prefix = element.id .. "\031"
                    for key in pairs(state.expandedEditorSections) do
                        if key:sub(1, #prefix) == prefix then
                            state.expandedEditorSections[key] = nil
                        end
                    end
                    state.expandedEditorSections[
                        prefix .. "composition.overrideList"] = true
                end
                RefreshInspector()
            end
        end,
    })
    state.overridePopup = overridePopup

    inspector:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    inspector:Hide()
    local docked = setmetatable({ frame = inspector }, DockedWindow)
    state.dockedWindow = docked
    return docked
end
