local _, NSkin = ...

local RESET_CONFIRMATION_DIALOG = "NSKIN_CONFIRM_INHERITED_RESET"
local RESET_ELEMENT_DIALOG = "NSKIN_CONFIRM_ELEMENT_RESET"
local CLEAR_OVERRIDES_DIALOG = "NSKIN_CONFIRM_CLEAR_OVERRIDES"
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
    local headerHeight = state.inspectorHeaderHeight or 59
    local minimumHeight = headerHeight + 63
    local maximumHeight = math.max(
        minimumHeight, math.min(screenLimit, anchoredLimit))
    local inspectorHeight = NSkin:SnapToPhysicalPixel(inspector,
        math.max(minimumHeight,
            math.min(contentHeight + headerHeight, maximumHeight)))
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
end

local RefreshInspector

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
    return nil
end

local function ResetCompositeSelection(element)
    local member = GetContextualCompositeMember(element)
    if not member then return false end
    local options = NSkin:GetCompositeMemberEditorOptions(
        element, member)
    local changed
    for _, definition in ipairs(options or {}) do
        local id = type(definition) == "table"
            and definition.id or definition
        local context = type(definition) == "table"
            and ResolveEditorContext(definition, element) or element
        if type(id) == "string" and context then
            changed = NSkin:ResetOptionGroup(
                id, context) or changed
        end
    end
    NSkin:NotifySkinningElementBoundsChanged(element.id)
    NSkin:ResnapPixelBordersForElement(element)
    return changed == true
end

local function ResetElementCustomizations(element)
    if not element then return false end
    local composition = element.composition
    local resetGroups = {}
    local editorOptions = NSkin:GetCompositionEditorOptions(element)
    if type(editorOptions) == "string" then
        resetGroups[editorOptions] = element
    elseif type(editorOptions) == "table" then
        for i = 1, #editorOptions do
            local definition = editorOptions[i]
            local id = type(definition) == "table" and definition.id or definition
            if type(definition) == "table" and type(definition.tabs) == "table" then
                for _, tab in ipairs(definition.tabs) do
                    local context = ResolveEditorContext(tab, element)
                    for _, groupID in ipairs(tab.groups or { tab.id }) do
                        if type(groupID) == "string" and context then
                            NSkin:ResetOptionGroup(groupID, context)
                        end
                    end
                end
            elseif type(id) == "string" then
                resetGroups[id] = type(definition) == "table"
                    and ResolveEditorContext(definition, element) or element
            end
        end
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

local function GetDockSelectionLabel(element, member)
    if not element then return nil end
    local composition = element.composition
    if composition and composition.mode == "COMPOSITE" then
        local groupLabel = composition.groupLabel
            or composition.editorLabel or element.label or element.id
        if not member or member.editorSurface == true then
            return groupLabel
        end

        local stateID, stateDefinition =
            NSkin:GetCompositeMemberEditorState(element, member)
        if stateID and stateDefinition then
            local stateLabel = stateDefinition.selectedLabel
                or ((stateDefinition.label or stateDefinition.id) .. " button")
            return groupLabel .. " - " .. stateLabel
        end

        local memberLabel = member.editorLabel
        if not memberLabel then
            local labels = composition.memberEditorLabels
            memberLabel = labels
                and (labels[member.id] or labels[member.kind])
        end
        memberLabel = memberLabel or member.label or member.id

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

        return groupLabel .. " - " .. memberLabel
    end
    return element.label or element.id
end

local function RefreshStateSelector(element, member)
    local inspector = state.inspector
    if not inspector then return end
    local states = member and member.states or nil
    local hasStates = states and #states > 0
    inspector.stateLabel:SetShown(hasStates == true)
    inspector.selection:Show()

    for _, button in ipairs(inspector.stateButtons or {}) do
        button:Hide()
    end
    if not hasStates then return end

    local selectedState = NSkin:GetCompositeMemberEditorState(
        element, member)
    local x = 58
    for index, definition in ipairs(states) do
        local button = inspector.stateButtons[index]
        if not button then
            button = CreateButton(inspector, "", 70, function(self)
                local currentElement = state.selectedElement
                local currentMember = currentElement
                    and state.focusedCompositeMemberID
                    and NSkin:GetCompositeMember(
                        currentElement, state.focusedCompositeMemberID)
                if not currentElement or not currentMember then return end
                NSkin:SetCompositeMemberEditorState(
                    currentElement, currentMember,
                    self.stateID, state.focusedCompositeRuntimeTarget, true)
                RefreshInspector()
            end)
            inspector.stateButtons[index] = button
        end
        local label = definition.label or definition.id
        button.stateID = definition.id
        button:SetWidth(math.max(58, #tostring(label) * 7 + 18))
        NSkin:SkinFlatButton(button, label, nil, nil, 12)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", inspector, "TOPLEFT", x, -45)
        button:SetAlpha(definition.id == selectedState and 1 or 0.55)
        local fontString = button.GetFontString and button:GetFontString()
        if fontString then
            NSkin:SetFontStringColor(fontString,
                definition.id == selectedState
                    and NSkin:GetAccentColor() or { 1, 1, 1, 1 })
        end
        button:Show()
        x = x + button:GetWidth() + 4
    end
    -- Selected text is refreshed after state switches so it reflects
    -- Collapse button / Expand button immediately.
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
        local label = "Reset Surface"
        if member and member.kind == "ICON" then
            label = "Reset Icon"
        elseif member and member.kind == "TEXT" then
            label = "Reset Text"
        end
        NSkin:SkinFlatButton(inspector.resetElement, label, nil, nil, 12)
        inspector.resetElement.resetLabel = label
    else
        NSkin:SkinFlatButton(
            inspector.resetElement, "Reset All", nil, nil, 12)
        inspector.resetElement.resetLabel = "Reset All"
    end

    local hasStates = overrideMember
        and #(overrideMember.states or {}) > 0
    state.inspectorHeaderHeight = hasStates and 78 or 59

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
        hasStates and -40 or -27)

    if state.scrollFrame then
        state.scrollFrame:ClearAllPoints()
        state.scrollFrame:SetPoint(
            "TOPLEFT", inspector, "TOPLEFT", 1,
            -(state.inspectorHeaderHeight - 1))
        state.scrollFrame:SetPoint(
            "BOTTOMRIGHT", inspector, "BOTTOMRIGHT", -1, 1)
    end
    RefreshStateSelector(element, overrideMember)
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
    local groups = {}
    for _, definition in ipairs(
        NSkin:CreateEditorOptionsPreset(component.editorPreset) or {})
    do
        local id = type(definition) == "table"
            and definition.id or definition
        local category = type(definition) == "table"
            and definition.category
        if type(id) == "string" and id ~= "shared.movable"
            and category ~= "POSITION" and category ~= "LAYOUT"
            and NSkin:GetOptionGroupDefinition(id)
        then
            groups[#groups + 1] = id
        end
    end
    return groups
end

local function GetOverridePropertiesForMember(member)
    local properties = {}
    for _, property in ipairs(
        NSkin:GetOptionGroupOverrideProperties("shared.movable"))
    do
        properties[#properties + 1] = {
            groupID = "shared.movable",
            propertyKey = property.key,
            propertyLabel = property.label,
        }
    end
    for _, groupID in ipairs(GetMemberAppearanceOptionGroups(member)) do
        for _, property in ipairs(
            NSkin:GetOptionGroupOverrideProperties(groupID))
        do
            properties[#properties + 1] = {
                groupID = groupID,
                propertyKey = property.key,
                propertyLabel = property.label,
            }
        end
    end
    table.sort(properties, function(left, right)
        return tostring(left.propertyLabel)
            < tostring(right.propertyLabel)
    end)
    return properties
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

local function ClearCompositeOverrides(element, memberID)
    if not element or not memberID then return false end
    local entries = {}
    for _, entry in ipairs(
        NSkin:GetCompositePropertyOverrides(element))
    do
        if entry.memberID == memberID then
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

local function RefreshOverrideListView(frame, element, memberID)
    frame.rows = frame.rows or {}
    local entries = {}
    for _, entry in ipairs(
        NSkin:GetCompositePropertyOverrides(element))
    do
        if memberID and entry.memberID == memberID then
            entries[#entries + 1] = entry
        end
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
    popup:Open(element, preferred and { preferred } or nil)
end

local function LoadEditorOptions(element)
    local focusedMember = element and state.focusedCompositeMemberID
        and NSkin:GetCompositeMember(element, state.focusedCompositeMemberID)
    local contextualMember = focusedMember
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

    local overrideEntries = {}
    if element and focusedMember then
        for _, entry in ipairs(
            NSkin:GetCompositePropertyOverrides(element))
        do
            if entry.memberID == focusedMember.id then
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
                            "Removes every exact-member override in this Composite.",
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
                        focusedMember and focusedMember.id or nil)
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
                    viewContext = ResolveEditorContext(tab, element)
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
    local selectionLabel = GetDockSelectionLabel(element, member)
    state.inspector.selection:SetText(
        selectionLabel or "Select an element"
    )
    LoadEditorOptions(element)
    NSkin:ApplyGlobalTypography(state.inspector)
    SetInspectorTextWhite(state.inspector)
    RefreshHeaderActions(element)
    NSkin:ResnapPixelBordersForTarget(state.inspector)
    NSkin:ResnapPixelBordersForTarget(state.scrollChild)
    if element then NSkin:ResnapPixelBordersForElement(element) end
    if C_Timer and C_Timer.After then
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
    state.focusedCompositeRuntimeTarget = runtimeTarget
    local member = element and memberID
        and NSkin:GetCompositeMember(element, memberID)
    if member then member._editorRuntimeTarget = runtimeTarget end
    if member and runtimeTarget and #(member.states or {}) > 0 then
        local runtimeState = NSkin:GetCompositeMemberRuntimeState(
            element, member, runtimeTarget)
        if runtimeState then
            NSkin:SetCompositeMemberEditorState(
                element, member, runtimeState, runtimeTarget, false)
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
    if state.debugToggle then NSkin:SkinFlatButton(state.debugToggle, "Debug") end
    if state.inspector.addOverride then
        NSkin:SkinFlatButton(state.inspector.addOverride, "+ Override")
    end
    if state.overridePopup then
        NSkin:RefreshSelectionPopupAppearance(state.overridePopup)
    end
    RefreshHeaderActions(state.selectedElement)
end

function NSkin:CreateDockedWindow(owner)
    state = owner
    state.optionViews = state.optionViews or {}
    state.editorSections = state.editorSections or {}
    state.expandedEditorSections = state.expandedEditorSections or {}
    state.selectedEditorSubtabs = state.selectedEditorSubtabs or {}
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
                    ClearCompositeOverrides(
                        data.element, data.memberID)
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
    inspector:SetSize(520, 130)
    inspector:SetFrameStrata("DIALOG")
    inspector:SetMovable(true)
    inspector:SetClampedToScreen(true)
    NSkin:SkinWindow(inspector)
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
    end)
    state.inspectorDragRegion = dragRegion

    CreateLabel(inspector, "Skinning Mode", "TOPLEFT", inspector, "TOPLEFT", 12, -5)
    local close = CreateButton(inspector, "", 22, function()
        NSkin:SetSkinningModeEnabled(false)
    end)
    NSkin:CreateCenteredButtonGlyph(close, "inspectorClose", {
        glyph = "close",
    })
    close:SetFrameLevel(dragRegion:GetFrameLevel() + 1)
    close:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", 0, 0)
    local gridToggle = CreateFrame("Button", nil, inspector)
    gridToggle:SetFrameLevel(dragRegion:GetFrameLevel() + 1)
    gridToggle:SetSize(22, 22)
    gridToggle:SetPoint("RIGHT", close, "LEFT", -4, 0)
    gridToggle.icon = NSkin:CreateCenteredButtonGlyph(
        gridToggle, "gridToggle", {
            texture = "Interface\\AddOns\\NSkin\\Media\\grid-alt.png",
            size = 16,
        })
    local function RefreshGridToggle()
        NSkin:SetCenteredButtonGlyphColor(
            gridToggle.icon,
            NSkin:IsCompactGridDebugEnabled() and NSkin:GetAccentColor()
                or { 1, 1, 1, 1 })
    end
    gridToggle.RefreshState = RefreshGridToggle
    gridToggle:SetScript("OnClick", function()
        NSkin:SetCompactGridDebugEnabled(
            not NSkin:IsCompactGridDebugEnabled())
        RefreshGridToggle()
    end)
    gridToggle:SetScript("OnEnter", function(self)
        NSkin:SetCenteredButtonGlyphColor(
            self.icon, NSkin:GetAccentColor())
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
    local debugToggle = CreateFrame("Button", nil, inspector)
    debugToggle:SetFrameLevel(dragRegion:GetFrameLevel() + 1)
    debugToggle:SetSize(52, 22)
    debugToggle:SetPoint("RIGHT", close, "LEFT", -4, 0)
    gridToggle:ClearAllPoints()
    gridToggle:SetPoint("RIGHT", debugToggle, "LEFT", -4, 0)
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
    inspector.selection = CreateLabel(
        inspector, "Select an element",
        "TOPLEFT", inspector, "TOPLEFT", 12, -29)
    inspector.stateLabel = CreateLabel(
        inspector, "State:", "TOPLEFT", inspector, "TOPLEFT", 12, -48)
    inspector.stateLabel:Hide()
    inspector.stateButtons = {}
    local resetElement = CreateButton(inspector, "Reset All", 96,
        function()
            local element = state.selectedElement
            if not element then return end
            local composition = element.composition
            if composition and composition.mode == "COMPOSITE" then
                ResetCompositeSelection(element)
                RefreshInspector()
            else
                StaticPopup_Show(RESET_ELEMENT_DIALOG,
                    element.label or element.id, nil, element)
            end
        end)
    resetElement:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -12, -27)
    resetElement:SetScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(
                self.resetLabel or "Reset All")
            GameTooltip:AddLine(
                "Resets the selected shared editor family without removing exact-member overrides.",
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
            GameTooltip:AddLine("Choose one member and one property to make a sparse exception to the Composite's shared appearance.",
                1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    addOverride:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    addOverride:Hide()

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
    scrollChild:SetSize(518, 1)
    scrollFrame:SetScrollChild(scrollChild)
    state.scrollFrame = scrollFrame
    state.scrollChild = scrollChild

    local overridePopup = NSkin:CreateSelectionPopup({
        title = "Add Override",
        width = 520,
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
                label = "Option",
                items = function(_, selections)
                    return GetOverridePropertiesForMember(
                        selections and selections[1])
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
            return element ~= nil
                and selections
                and selections[1] ~= nil
                and selections[2] ~= nil
        end,
        onConfirm = function(element, selections)
            local member = selections and selections[1]
            local property = selections and selections[2]
            if not element or not member or not property then return end
            local runtimeTarget = state.focusedCompositeRuntimeTarget
            if NSkin:AddCompositePropertyOverride(
                element, member.id, property.groupID,
                property.propertyKey, property.propertyLabel, runtimeTarget)
            then
                local exactAppearanceID =
                    NSkin:GetCompositeMemberTargetAppearanceID(
                        element, member, runtimeTarget)
                if exactAppearanceID == (member.appearanceID or member.id) then
                    exactAppearanceID = nil
                end
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
                local prefix = element.id .. "\031"
                for key in pairs(state.expandedEditorSections) do
                    if key:sub(1, #prefix) == prefix then
                        state.expandedEditorSections[key] = nil
                    end
                end
                state.expandedEditorSections[
                    prefix .. "composition.overrideList"] = true
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
