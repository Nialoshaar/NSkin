local _, NSkin = ...

-- Anchor Groups are editor-only relationships. They neither replace the
-- canonical elements below them nor acquire movement, lifecycle, or reset
-- ownership from those elements.
local anchorGroups = {}
local anchorGroupByElementID = {}

-- Forward declaration: exact-member position contexts are constructed before
-- the movement-target helper is defined later in this file.
local GetCompositeMemberMovementTarget

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = type(value) == "table" and CopyTable(value) or value
    end
    return copy
end

local function GetCanonicalMembers(element)
    local members = {}
    local composition = element and element.composition
    if composition and composition.mode == "COMPOSITE" then
        for _, member in ipairs(composition.members or {}) do
            if member.kind then
                members[#members + 1] = {
                    kind = member.kind,
                    role = member.role or "SECONDARY",
                    label = member.label,
                }
            end
        end
    elseif element and element.kind then
        members[#members + 1] = {
            kind = element.kind, role = "PRIMARY",
        }
        for _, kind in ipairs(element.appearanceTypeIDs or {}) do
            if kind ~= element.kind then
                members[#members + 1] = {
                    kind = kind, role = "SECONDARY",
                }
            end
        end
    end
    return members
end

local function ElementExposesKind(element, kind)
    for _, member in ipairs(GetCanonicalMembers(element)) do
        if member.kind == kind then return true end
    end
    return false
end

local function GetSortedGroupMembers(group)
    local members = {}
    for _, element in pairs(group.membersByID or {}) do
        members[#members + 1] = element
    end
    table.sort(members, function(left, right) return left.id < right.id end)
    return members
end

local function CountGroupKind(group, kind)
    local count = 0
    for _, element in ipairs(GetSortedGroupMembers(group)) do
        if ElementExposesKind(element, kind) then count = count + 1 end
    end
    return count
end

local function GetGroupComponentMembers(group)
    local byKind = {}
    for _, element in ipairs(GetSortedGroupMembers(group)) do
        for _, member in ipairs(GetCanonicalMembers(element)) do
            local current = byKind[member.kind]
            if not current then
                current = {
                    kind = member.kind, role = member.role,
                    label = member.label, ownerElement = element,
                    elementCount = 1, elementIDs = { [element.id] = true },
                }
                byKind[member.kind] = current
            else
                if not current.elementIDs[element.id] then
                    current.elementIDs[element.id] = true
                    current.elementCount = current.elementCount + 1
                end
                if member.role == "PRIMARY" then current.role = "PRIMARY" end
            end
        end
    end
    local members = {}
    for _, member in pairs(byKind) do members[#members + 1] = member end
    table.sort(members, function(left, right)
        local leftOrder = left.role == "PRIMARY" and 1 or 2
        local rightOrder = right.role == "PRIMARY" and 1 or 2
        return leftOrder == rightOrder and left.kind < right.kind
            or leftOrder < rightOrder
    end)
    return members
end

local function MigrateAnchorGroupOverrides(group)
    local profile = NSkin:GetProfile()
    local elements = profile.appearanceOverrides
        and profile.appearanceOverrides.elements
    if not elements then return end
    for _, member in ipairs(GetGroupComponentMembers(group)) do
        if CountGroupKind(group, member.kind) >= 2 then
            local component = NSkin:GetSharedElementType(member.kind)
            local styleName = component and component.style
            local target = elements[group.id]
            if styleName and not (target and target[styleName]) then
                local candidates = GetSortedGroupMembers(group)
                if group.appearanceSourceID then
                    table.sort(candidates, function(left, right)
                        if left.id == group.appearanceSourceID then return true end
                        if right.id == group.appearanceSourceID then return false end
                        return left.id < right.id
                    end)
                end
                for _, element in ipairs(candidates) do
                    local source = elements[element.id]
                    if ElementExposesKind(element, member.kind)
                        and source and source[styleName]
                    then
                        elements[group.id] = elements[group.id] or {}
                        elements[group.id][styleName] = CopyTable(source[styleName])
                        break
                    end
                end
            end
        end
    end
end

local function GetAnchorGroupMovementRoots(group)
    local candidates, candidateSet = {}, {}
    for _, member in ipairs(GetSortedGroupMembers(group)) do
        local target = NSkin:GetCompositionMovementOwner(member) or member.target
        if target and target.GetNumPoints and target.ClearAllPoints
            and target.SetPoint and not candidateSet[target]
        then
            candidates[#candidates + 1] = target
            candidateSet[target] = true
        end
    end

    local roots = {}
    for _, target in ipairs(candidates) do
        local anchoredToMember
        for pointIndex = 1, target:GetNumPoints() do
            local _, relativeTo = target:GetPoint(pointIndex)
            if relativeTo and relativeTo ~= target and candidateSet[relativeTo] then
                anchoredToMember = true
                break
            end
        end
        if not anchoredToMember then roots[#roots + 1] = target end
    end
    if #roots == 0 then roots = candidates end
    return roots
end

local function RefreshAnchorGroupMovementContract(group, virtual)
    local members = GetSortedGroupMembers(group)
    virtual.module = virtual.module or (members[1] and members[1].module)
    if type(virtual.module) ~= "string" or virtual.module == "" then return end

    local roots = GetAnchorGroupMovementRoots(group)
    virtual.anchorGroupMovementRoots = {}
    for index, target in ipairs(roots) do
        local baselineID = virtual.id .. ":MovementRoot:" .. index
        NSkin:CaptureComponentBaseline(baselineID, target, {
            points = true,
            canCapture = function(frame)
                return frame.GetNumPoints and frame:GetNumPoints() > 0
            end,
        })
        local baseline = NSkin:GetComponentBaseline(baselineID)
        if baseline and type(baseline.points) == "table"
            and #baseline.points > 0
        then
            virtual.anchorGroupMovementRoots[#virtual.anchorGroupMovementRoots + 1] = {
                target = target,
                baselineID = baselineID,
            }
        end
    end
    if #virtual.anchorGroupMovementRoots == 0 then return end

    virtual.getPlacement = function(element)
        local options = NSkin:GetModuleOptions(element.module, false)
        local saved = options and options.movablePlacements
            and options.movablePlacements[element.id]
        if saved then return CopyTable(saved) end
        return { mode = "OFFSET", alongOffset = 0, edgeOffset = 0 }
    end
    virtual.applyPlacement = function(element, placement, applyOptions)
        if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
        local offsetX = tonumber(placement.alongOffset or placement.x) or 0
        local offsetY = tonumber(placement.edgeOffset or placement.y) or 0
        local applied
        for _, root in ipairs(element.anchorGroupMovementRoots or {}) do
            local target = root.target
            local baseline = NSkin:GetComponentBaseline(root.baselineID)
            local points = baseline and baseline.points
            if target and type(points) == "table" and #points > 0
                and target.ClearAllPoints and target.SetPoint
            then
                target:ClearAllPoints()
                for i = 1, #points do
                    local point = points[i]
                    target:SetPoint(point[1], point[2], point[3],
                        (tonumber(point[4]) or 0) + offsetX,
                        (tonumber(point[5]) or 0) + offsetY)
                end
                applied = true
            end
        end
        if applied and not (applyOptions and applyOptions.suppressNotify) then
            for _, member in ipairs(NSkin:GetAnchorGroupMembers(element) or {}) do
                NSkin:NotifySkinningElementBoundsChanged(member.id)
            end
        end
        return applied == true
    end
    virtual.setPlacement = function(element, placement)
        if not element.applyPlacement(element, placement) then return false end
        local options = NSkin:GetModuleOptions(element.module, true)
        options.movablePlacements = options.movablePlacements or {}
        options.movablePlacements[element.id] = {
            mode = "OFFSET",
            alongOffset = tonumber(placement.alongOffset or placement.x) or 0,
            edgeOffset = tonumber(placement.edgeOffset or placement.y) or 0,
        }
        for _, root in ipairs(element.anchorGroupMovementRoots or {}) do
            NSkin:MarkComponentGeometryModified(root.baselineID, "points", true)
        end
        return true
    end
    virtual.resetPlacement = function(element)
        local restored
        for _, root in ipairs(element.anchorGroupMovementRoots or {}) do
            restored = NSkin:RestoreComponentBaseline(root.baselineID) or restored
        end
        local options = NSkin:GetModuleOptions(element.module, false)
        if options and options.movablePlacements then
            options.movablePlacements[element.id] = nil
            if not next(options.movablePlacements) then
                options.movablePlacements = nil
            end
        end
        if restored then
            for _, member in ipairs(NSkin:GetAnchorGroupMembers(element) or {}) do
                NSkin:NotifySkinningElementBoundsChanged(member.id)
            end
        end
        return restored == true
    end
    virtual.movable = true
end

local function RefreshAnchorGroup(group)
    local members = GetSortedGroupMembers(group)
    local virtual = group.editorElement
    if not virtual then
        virtual = {
            id = group.id, anchorGroupID = group.id,
            isAnchorGroup = true,
            draggable = false, movable = false,
        }
        group.editorElement = virtual
    end
    virtual.label = group.label or group.id
    virtual.window = group.window
    virtual.appearanceWindowID = group.appearanceWindowID
    virtual.defaultShape = group.defaultShape
    virtual.target = nil
    virtual.priority = group.priority or 0
    virtual.anchorGroupMembers = members
    virtual.isEditable = function()
        for _, element in ipairs(GetSortedGroupMembers(group)) do
            if NSkin:IsSkinningElementEditable(element) then return true end
        end
        return false
    end
    virtual.getHighlightBounds = function()
        local left, right, bottom, top
        for _, element in ipairs(GetSortedGroupMembers(group)) do
            if NSkin:IsSkinningElementEditable(element) then
                local l, r, b, t = NSkin:GetSkinningElementBounds(element)
                if l then
                    left = left and math.min(left, l) or l
                    right = right and math.max(right, r) or r
                    bottom = bottom and math.min(bottom, b) or b
                    top = top and math.max(top, t) or t
                end
            end
        end
        return left, right, bottom, top
    end
    virtual.highlightBoundsAreNormalized = true
    RefreshAnchorGroupMovementContract(group, virtual)
end

function NSkin:InitializeElementAnchorGroup(element)
    local previousID = element._registeredAnchorGroupID
    if previousID and previousID ~= element.anchorGroupID then
        local previous = anchorGroups[previousID]
        if previous then previous.membersByID[element.id] = nil end
        anchorGroupByElementID[element.id] = nil
    end
    local id = element.anchorGroupID
    if type(id) ~= "string" or id == "" then
        element._registeredAnchorGroupID = nil
        return
    end
    local group = anchorGroups[id]
    if not group then
        group = { id = id, membersByID = {} }
        anchorGroups[id] = group
    end
    group.label = element.anchorGroupLabel or group.label or id
    group.window = group.window or element.window
    group.appearanceWindowID = group.appearanceWindowID
        or element.appearanceWindowID
    group.appearanceSourceID = element.anchorGroupAppearanceSource
        or group.appearanceSourceID
    group.defaultShape = element.defaultShape
        or (element.skinOptions and element.skinOptions.defaultShape)
        or group.defaultShape
    group.priority = math.max(group.priority or 0, element.priority or 0)
    local newMember = group.membersByID[element.id] == nil
    group.membersByID[element.id] = element
    anchorGroupByElementID[element.id] = group
    element._registeredAnchorGroupID = id
    RefreshAnchorGroup(group)
    MigrateAnchorGroupOverrides(group)
    if newMember and #GetSortedGroupMembers(group) > 1 then
        for _, member in ipairs(GetSortedGroupMembers(group)) do
            if member ~= element and type(member.refreshAppearance) == "function" then
                member.refreshAppearance(NSkin, member)
            end
        end
    end
end

function NSkin:GetAnchorGroup(elementOrID)
    if type(elementOrID) == "table" and elementOrID.isAnchorGroup then
        return anchorGroups[elementOrID.anchorGroupID]
    end
    local id = type(elementOrID) == "table" and elementOrID.id or elementOrID
    return anchorGroupByElementID[id] or anchorGroups[id]
end

function NSkin:GetAnchorGroupMembers(elementOrID)
    local group = self:GetAnchorGroup(elementOrID)
    return group and GetSortedGroupMembers(group) or nil
end

function NSkin:GetAnchorGroupComponentMembers(elementOrID)
    local group = self:GetAnchorGroup(elementOrID)
    return group and GetGroupComponentMembers(group) or nil
end

function NSkin:GetSkinningEditorElement(element)
    local group = self:GetAnchorGroup(element)
    return group and group.editorElement or element
end

function NSkin:GetElementAppearanceID(elementOrID, kind)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    if element and element.isAnchorGroup then return element.id end
    local registered = element and self:GetSkinningElement(element.id)
    local canonicalElement = registered or element
    local group = self:GetAnchorGroup(canonicalElement or elementOrID)
    if not group or not kind or not canonicalElement
        or not ElementExposesKind(canonicalElement, kind)
        or CountGroupKind(group, kind) < 2
    then
        return element and element.id or elementOrID
    end
    return group.id
end

-- Composition is authoritative structural metadata on registered editor elements.
-- It does not replace canonical atomic appearance registrations.
local COMPOSITION_MODES = {
    STANDALONE = true,
    COMPOSITE = true,
    CONTAINER = true,
}
local compositeTypes = {
    REGULAR = {},
}
local editorGroups = {}
local editorGroupByElementID = {}
local appearanceParentByID = {}
local appearanceOwnerByID = {}
local appearanceMemberByID = {}
local appearanceStateByID = {}
local compositeAppearanceFamilyMembersByID = {}
local containerSurfaceByAppearanceID = {}
local containerParentByChildID = {}
local compositeTagByElementID = {}
local compositeElementsByTag = {}
local compositeTagByAppearanceID = {}

local function NormalizeCompositeTag(tag)
    if type(tag) ~= "string" then return nil end
    tag = tag:match("^%s*(.-)%s*$")
    return tag ~= "" and tag or nil
end

local CONTENT_TYPES = {
    TEXT = true,
    ICON = true,
    TEXTURE = true,
    ATLAS = true,
    GLYPH = true,
}

local partTypes = {
    TRACK = {},
    THUMB = {},
}

local function NormalizePresentationTag(tag)
    if type(tag) ~= "string" then return nil end
    tag = tag:match("^%s*(.-)%s*$")
    return tag ~= "" and tag or nil
end

local function MakeStablePresentationNodeID(
    ownerID, node, prefix, index, used)
    local explicit = node.id or node.key
    if type(explicit) == "string" and explicit ~= "" then
        if used[explicit] then return nil end
        used[explicit] = true
        return explicit
    end

    local base = tostring(ownerID) .. "." .. prefix .. tostring(index)
    local candidate, suffix = base, 2
    while used[candidate] do
        candidate = base .. suffix
        suffix = suffix + 1
    end
    used[candidate] = true
    return candidate
end

local function NormalizePresentationNodes(
    ownerID, definitions, prefix, isValidType)
    if type(definitions) ~= "table" then return nil, nil end

    local normalized, byID, used = {}, {}, {}
    for index, source in ipairs(definitions) do
        if type(source) == "table" then
            local typeID = tostring(
                source.type or source.contentType or source.partType or ""):upper()
            if isValidType(typeID) then
                local id = MakeStablePresentationNodeID(
                    ownerID, source, prefix, index, used)
                if id then
                    source.id = id
                    source.type = typeID
                    normalized[#normalized + 1] = source
                    byID[id] = source
                end
            end
        end
    end

    return normalized, byID
end

local function NormalizeStatePresentation(ownerID, states)
    if type(states) ~= "table" then return end
    for _, state in ipairs(states) do
        if type(state) == "table"
            and type(state.id) == "string" and state.id ~= ""
        then
            state.content, state.contentByID = NormalizePresentationNodes(
                ownerID .. ".State." .. state.id,
                state.content, "Content",
                function(typeID) return CONTENT_TYPES[typeID] == true end)
        end
    end
end

local function NormalizeElementPresentation(definition, ownerID)
    if type(definition) ~= "table"
        or type(ownerID) ~= "string" or ownerID == ""
    then return end

    if type(definition.elementType) == "string"
        and definition.elementType ~= ""
    then
        definition.elementType = definition.elementType:upper()
    else
        definition.elementType = nil
    end
    definition.tag = NormalizePresentationTag(definition.tag)

    definition.content, definition.contentByID = NormalizePresentationNodes(
        ownerID, definition.content, "Content",
        function(typeID) return CONTENT_TYPES[typeID] == true end)
    definition.parts, definition.partsByID = NormalizePresentationNodes(
        ownerID, definition.parts, "Part",
        function(typeID) return partTypes[typeID] ~= nil end)
    NormalizeStatePresentation(ownerID, definition.states)
end

local function NormalizeCompositionPresentation(element, composition)
    composition.content, composition.contentByID = NormalizePresentationNodes(
        element.id, composition.content, "Content",
        function(typeID) return CONTENT_TYPES[typeID] == true end)
    composition.parts, composition.partsByID = NormalizePresentationNodes(
        element.id, composition.parts, "Part",
        function(typeID) return partTypes[typeID] ~= nil end)
end

function NSkin:IsContentType(typeID)
    typeID = type(typeID) == "string" and typeID:upper() or nil
    return typeID ~= nil and CONTENT_TYPES[typeID] == true
end

function NSkin:RegisterPartType(typeID, definition)
    if type(typeID) ~= "string" or typeID == ""
        or type(definition) ~= "table"
    then return false end
    typeID = typeID:upper()
    if partTypes[typeID] then return false end
    partTypes[typeID] = definition
    return true
end

function NSkin:GetPartType(typeID)
    typeID = type(typeID) == "string" and typeID:upper() or nil
    return typeID and partTypes[typeID] or nil
end

function NSkin:GetElementType(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    return element and (element.elementType or element.kind) or nil
end

function NSkin:GetElementTag(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    return element and element.tag or nil
end

function NSkin:GetElementContent(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    return element and element.content or nil
end

function NSkin:GetElementParts(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    return element and element.parts or nil
end

function NSkin:GetStateContent(elementOrMember, stateID)
    if type(elementOrMember) ~= "table"
        or type(stateID) ~= "string" or stateID == ""
    then return nil end
    for _, state in ipairs(elementOrMember.states or {}) do
        if state.id == stateID then return state.content end
    end
end

function NSkin:GetCompositionContent(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local composition = element and element.composition
    return composition and composition.content or nil
end

function NSkin:GetCompositionParts(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local composition = element and element.composition
    return composition and composition.parts or nil
end

function NSkin:GetCompositeTagAppearanceID(tag)
    tag = NormalizeCompositeTag(tag)
    if not tag then return nil end
    local token = tag:gsub("[^%w_%-]", "_")
    local id = "CompositeTag." .. token
    compositeTagByAppearanceID[id] = tag
    return id
end

function NSkin:GetCompositeTag(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    return element and compositeTagByElementID[element.id] or nil
end

local function RegisterCompositeTag(element)
    if not element then return end
    local oldTag = compositeTagByElementID[element.id]
    if oldTag and compositeElementsByTag[oldTag] then
        compositeElementsByTag[oldTag][element.id] = nil
        if not next(compositeElementsByTag[oldTag]) then
            compositeElementsByTag[oldTag] = nil
        end
    end
    local composition = element.composition
    local tag = composition and composition.mode == "COMPOSITE"
        and NormalizeCompositeTag(composition.tag) or nil
    compositeTagByElementID[element.id] = tag
    if not tag then return end
    composition.tag = tag
    compositeElementsByTag[tag] = compositeElementsByTag[tag] or {}
    compositeElementsByTag[tag][element.id] = true
    NSkin:GetCompositeTagAppearanceID(tag)
end

function NSkin:RefreshCompositeTagAppearance(change)
    local tag = change and compositeTagByAppearanceID[change.elementID]
    local members = tag and compositeElementsByTag[tag]
    if not members then return false end
    local refreshed
    for elementID in pairs(members) do
        local element = self:GetSkinningElement(elementID)
        if element and element.rowFamily
            and type(self.RefreshRowFamilySurfaceAppearance) == "function"
        then
            refreshed = self:RefreshRowFamilySurfaceAppearance(
                element, change) or refreshed
        elseif element and type(element.refreshAppearance) == "function" then
            element.refreshAppearance(self, element)
            refreshed = true
        end
    end
    return refreshed == true
end

function NSkin:GetAppearanceParentID(elementID)
    return appearanceParentByID[elementID]
end

function NSkin:GetAppearanceOwnerElementID(elementID)
    return appearanceOwnerByID[elementID]
end

local function NormalizeContainerSurface(element, composition)
    local surface = composition and composition.surface
    if type(surface) ~= "table" then
        composition.surface = nil
        return
    end

    local appearanceID = surface.appearanceID
        or (element.id .. ".Surface")
    if type(appearanceID) ~= "string" or appearanceID == "" then
        composition.surface = nil
        return
    end

    surface.appearanceID = appearanceID
    surface.appearanceWindowID =
        surface.appearanceWindowID or element.appearanceWindowID
    surface.surfaceAppearanceKey =
        surface.surfaceAppearanceKey or surface.appearanceKey
    surface.includeGeometry = surface.includeGeometry ~= false

    if type(surface.appearanceParentID) == "string"
        and surface.appearanceParentID ~= ""
        and surface.appearanceParentID ~= appearanceID
    then
        appearanceParentByID[appearanceID] =
            surface.appearanceParentID
    end
    appearanceOwnerByID[appearanceID] = element.id
    containerSurfaceByAppearanceID[appearanceID] = element.id
end

function NSkin:GetContainerSurfaceAppearanceContext(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local composition = element and element.composition
    local surface = composition
        and composition.mode == "CONTAINER" and composition.surface
    if not element or not surface then return nil end

    local context = surface._editorContext or {}
    surface._editorContext = context
    context.id = surface.appearanceID
    context.label = surface.label or "Surface"
    context.kind = surface.kind or "BUTTON"
    context.module = element.module
    context.window = element.window
    context.target = surface.target or element.target
    context.appearanceWindowID =
        surface.appearanceWindowID or element.appearanceWindowID
    context.surfaceStyle = surface.surfaceStyle
    context.surfaceAppearanceKey = surface.surfaceAppearanceKey
    context.containerOwner = element
    context.containerSurface = surface
    return context
end

function NSkin:RefreshContainerSurfaceAppearance(change)
    local elementID = change
        and containerSurfaceByAppearanceID[change.elementID]
    if not elementID then return false end

    local element = self:GetSkinningElement(elementID)
    local composition = element and element.composition
    local surface = composition
        and composition.mode == "CONTAINER" and composition.surface
    if not element or not surface then return false end

    if type(surface.refreshAppearance) == "function" then
        local ok, refreshed = pcall(
            surface.refreshAppearance, element, surface, change)
        if ok and refreshed ~= false then return true end
    end
    return false
end

local function RegisterCompositeMemberAppearance(
    element, member, appearanceID)
    if not element or not member
        or type(appearanceID) ~= "string" or appearanceID == ""
    then return end
    appearanceMemberByID[appearanceID] = {
        elementID = element.id,
        memberID = member.id,
    }
end

local function RegisterCompositeAppearanceFamilyMember(
    appearanceID, element, member)
    if type(appearanceID) ~= "string" or appearanceID == ""
        or not element or not member
    then return end
    local members = compositeAppearanceFamilyMembersByID[appearanceID]
    if not members then
        members = {}
        compositeAppearanceFamilyMembersByID[appearanceID] = members
    end
    local token = element.id .. "\031" .. member.id
    members[token] = {
        elementID = element.id,
        memberID = member.id,
    }
end

function NSkin:RefreshCompositeAppearanceFamily(change)
    local members = change
        and compositeAppearanceFamilyMembersByID[change.elementID]
    if not members then return false end
    local refreshed
    for _, entry in pairs(members) do
        refreshed = self:RefreshCompositeMemberByIDAppearance(
            entry.elementID, entry.memberID, change) or refreshed
    end
    return refreshed == true
end

local SURFACE_APPEARANCE_KEYS = {
    width = true,
    height = true,
    showBackground = true,
    showBorder = true,
    showHighlight = true,
    background = true,
    backgroundMode = true,
    backgroundOpacity = true,
    selectedBackground = true,
    selectedBackgroundMode = true,
    selectedBackgroundOpacity = true,
    border = true,
    borderMode = true,
    borderSize = true,
    borderPadding = true,
    highlight = true,
    highlightMode = true,
    hoverAlpha = true,
}

local function IsSurfaceOnlyAppearanceChange(change, styleName)
    if not change then return false end
    local entries = change.changes or { change }
    if #entries == 0 then return false end
    for i = 1, #entries do
        local entry = entries[i]
        if entry.style and styleName and entry.style ~= styleName then
            return false
        end
        local path = entry.path
        local key = type(path) == "string"
            and path:match("([^.]+)$") or nil
        if not key or not SURFACE_APPEARANCE_KEYS[key] then
            return false
        end
    end
    return true
end

local function IsComponentAppearanceChange(change, styleName)
    if not change or type(styleName) ~= "string" or styleName == "" then
        return false
    end
    local entries = change.changes or { change }
    if #entries == 0 then return false end
    for i = 1, #entries do
        if entries[i].style ~= styleName then return false end
    end
    return true
end

local function RefreshCompositeAtomicMemberAppearance(
    self, element, member, change)
    local component = member.kind
        and self:GetSharedElementType(member.kind)
    if not component
        or not IsComponentAppearanceChange(change, component.style)
    then
        return false
    end

    local targets
    if change and type(change.elementID) == "string" then
        local exact = self:GetCompositeMemberTargetForAppearanceID(
            element, member, change.elementID)
        if exact then targets = { exact } end
    end
    targets = targets
        or self:GetCompositionMemberTargets(element, member, false)
        or {}

    local refreshed
    for _, target in ipairs(targets) do
        local definition = {}
        for key, value in pairs(member) do
            definition[key] = value
        end
        definition.id = self:GetCompositeMemberTargetAppearanceID(
            element, member, target)
            or member.appearanceID or member.id
        definition.target = target
        definition.appearanceWindowID =
            member.appearanceWindowID or element.appearanceWindowID
        if self:SkinTypedElement(member.kind, definition) then
            refreshed = true
        end
    end
    return refreshed == true
end

local function RefreshCompositeAtomicMemberSurface(
    self, element, member, change)
    local component = member.kind
        and self:GetSharedElementType(member.kind)
    if not component or component.surfaceCapability ~= true
        or not IsSurfaceOnlyAppearanceChange(change, component.style)
    then
        return false
    end
    return RefreshCompositeAtomicMemberAppearance(
        self, element, member, change)
end

function NSkin:RefreshCompositeMemberByIDAppearance(
    elementOrID, memberID, change)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element
        and self:GetCompositeMember(element, memberID)
    if not element or not member then return false end

    -- A Composite group Surface may use a non-interactive presentation owner
    -- (for example a plain Frame spanning several Blizzard controls). Its
    -- adapter-owned renderer is authoritative and must run before canonical
    -- atomic dispatch; treating that presentation owner as the member's
    -- BUTTON/CHECKBOX kind can install unsupported scripts on it.
    if member.editorSurface == true
        and type(member.refreshAppearance) == "function"
    then
        local ok, refreshed = pcall(
            member.refreshAppearance, element, member, change)
        if ok and refreshed ~= false then return true end
    end

    -- Surface-capable atomic members get a specialized Surface-only refresh
    -- before their broader component refresh. This prevents a local Surface
    -- edit from re-running member layout/content or the owning Composite.
    if member.editorSurface ~= true then
        local component = member.kind
            and self:GetSharedElementType(member.kind)
        if component and component.surfaceCapability == true
            and IsSurfaceOnlyAppearanceChange(change, component.style)
        then
            if type(member.refreshSurfaceAppearance) == "function" then
                local ok, refreshed = pcall(
                    member.refreshSurfaceAppearance,
                    element, member, change)
                if ok and refreshed ~= false then return true end
            end
            if RefreshCompositeAtomicMemberSurface(
                self, element, member, change)
            then
                return true
            end
        end
    end

    local component = member.kind
        and self:GetSharedElementType(member.kind)
    if component
        and IsComponentAppearanceChange(change, component.style)
    then
        if type(member.refreshComponentAppearance) == "function" then
            local ok, refreshed = pcall(
                member.refreshComponentAppearance,
                element, member, change)
            if ok and refreshed ~= false then return true end
        end
        if RefreshCompositeAtomicMemberAppearance(
            self, element, member, change)
        then
            return true
        end
    end

    if type(member.refreshAppearance) == "function" then
        local ok, refreshed = pcall(
            member.refreshAppearance, element, member, change)
        return ok and refreshed ~= false
    end

    -- Surface is a shared capability, so ordinary Composite surfaces must not
    -- require every window adapter to provide a bespoke refresh callback.
    -- Prefer the narrowest existing owner contract and reserve broad
    -- compatibility refresh for genuinely unsupported/structural elements.
    if member.editorSurface == true then
        if member.rowFamilySurface == true
            and type(self.RefreshRowFamilySurfaceAppearance) == "function"
        then
            local ok, refreshed = pcall(
                self.RefreshRowFamilySurfaceAppearance,
                self, element, change)
            if ok and refreshed ~= false then return true end
        end

        if type(element.refreshAppearance) == "function" then
            local ok, refreshed = pcall(
                element.refreshAppearance, self, element, change)
            if ok and refreshed ~= false then return true end
        end

        if element.typedRegistration
            and type(self.RefreshTypedElementAppearance) == "function"
        then
            local ok, refreshed = pcall(
                self.RefreshTypedElementAppearance, self, element)
            if ok and refreshed ~= false then return true end
        end
    end
    return false
end

function NSkin:RefreshCompositeMemberAppearance(change)
    local entry = change and appearanceMemberByID[change.elementID]
    if not entry then return false end
    return self:RefreshCompositeMemberByIDAppearance(
        entry.elementID, entry.memberID, change)
end

function NSkin:RegisterAppearanceParentID(elementID, parentID, ownerID)
    if type(elementID) ~= "string" or elementID == ""
        or type(parentID) ~= "string" or parentID == ""
        or elementID == parentID
    then
        return false
    end
    appearanceParentByID[elementID] = parentID
    if type(ownerID) == "string" and ownerID ~= "" then
        appearanceOwnerByID[elementID] = ownerID
    end
    return true
end

function NSkin:RefreshCompositeMemberStateAppearance(change)
    local entry = change and appearanceStateByID[change.elementID]
    if not entry then return false end

    local element = self:GetSkinningElement(entry.elementID)
    local member = element
        and self:GetCompositeMember(element, entry.memberID)
    if not element or not member then return false end

    local stateDefinition
    for _, candidate in ipairs(member.states or {}) do
        if candidate.id == entry.stateID then
            stateDefinition = candidate
            break
        end
    end
    if not stateDefinition then return false end

    if type(member.refreshStateAppearance) == "function" then
        local ok, refreshed = pcall(
            member.refreshStateAppearance,
            element, member, stateDefinition, change)
        if ok and refreshed ~= false then return true end
    end

    -- Selection state is composition behavior, not a visual component type.
    -- Participating atomic members therefore use their normal targeted
    -- component renderer when a shared Selected/Unselected state changes.
    if member.selectionParticipant == true then
        return self:RefreshCompositeMemberByIDAppearance(
            element, member.id, change)
    end
    return false
end

function NSkin:GetCompositeMemberTargetAppearanceID(
    elementOrID, memberOrID, target)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return nil end

    local appearanceID
    if target and type(member.getTargetAppearanceID) == "function" then
        local ok, resolved = pcall(
            member.getTargetAppearanceID, element, member, target)
        if ok and type(resolved) == "string" and resolved ~= "" then
            appearanceID = resolved
        end
    end
    appearanceID = appearanceID or member.appearanceID or member.id

    local memberAppearanceID = member.appearanceID or member.id
    RegisterCompositeMemberAppearance(element, member, appearanceID)
    if appearanceID ~= memberAppearanceID then
        self:RegisterAppearanceParentID(
            appearanceID, memberAppearanceID, element.id)
    end

    if member.selectionParticipant == true and target then
        local stateID = self:GetCompositeMemberRuntimeState(
            element, member, target)
        if stateID then
            local stateAppearanceID
            for _, definition in ipairs(member.states or {}) do
                if definition.id == stateID then
                    stateAppearanceID = definition.appearanceID
                    break
                end
            end
            stateAppearanceID = stateAppearanceID
                or (memberAppearanceID .. ".State." .. stateID)
            local targetStateAppearanceID =
                appearanceID .. ".State." .. stateID
            RegisterCompositeMemberAppearance(
                element, member, targetStateAppearanceID)
            self:RegisterAppearanceParentID(
                targetStateAppearanceID, stateAppearanceID, element.id)
            return targetStateAppearanceID
        end
    end
    return appearanceID
end

function NSkin:GetCompositeMemberTargetForAppearanceID(
    elementOrID, memberOrID, appearanceID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member or type(appearanceID) ~= "string" then
        return nil
    end
    for _, target in ipairs(
        self:GetCompositionMemberTargets(element, member, false) or {})
    do
        if self:GetCompositeMemberTargetAppearanceID(
            element, member, target) == appearanceID
        then
            return target
        end
    end
end

local function GetCompositionMemberState(element, member, create)
    if not element or not member or type(element.module) ~= "string" then
        return nil
    end
    local options = NSkin:GetModuleOptions(element.module, create == true)
    if not options then return nil end
    local all = options.compositionMembers
    if not all and create then
        all = {}
        options.compositionMembers = all
    end
    local owner = all and all[element.id]
    if not owner and create then
        owner = {}
        all[element.id] = owner
    end
    local state = owner and owner[member.id]
    if not state and create then
        state = {}
        owner[member.id] = state
    end
    return state, owner, all, options
end

local function PruneCompositionMemberState(element, member)
    local state, owner, all, options =
        GetCompositionMemberState(element, member, false)
    if not state then return end
    if next(state) then return end
    owner[member.id] = nil
    if not next(owner) then all[element.id] = nil end
    if not next(all) then options.compositionMembers = nil end
end


local function GetCompositePropertyOverrideStore(element, create)
    if not element or type(element.module) ~= "string" then return nil end
    local moduleOptions = NSkin:GetModuleOptions(element.module, create == true)
    if not moduleOptions then return nil end
    local all = moduleOptions.compositePropertyOverrides
    if not all and create then
        all = {}
        moduleOptions.compositePropertyOverrides = all
    end
    local store = all and all[element.id]
    if not store and create then
        store = {}
        all[element.id] = store
    end
    return store, all, moduleOptions
end


local function GetCompositeTargetOffsetStore(element, create)
    if not element or type(element.module) ~= "string" then return nil end
    local moduleOptions = NSkin:GetModuleOptions(element.module, create == true)
    if not moduleOptions then return nil end
    local all = moduleOptions.compositeTargetOffsets
    if not all and create then
        all = {}
        moduleOptions.compositeTargetOffsets = all
    end
    local store = all and all[element.id]
    if not store and create then
        store = {}
        all[element.id] = store
    end
    return store, all, moduleOptions
end

function NSkin:GetCompositeMemberTargetOffset(
    elementOrID, memberOrID, appearanceID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member or type(appearanceID) ~= "string" then
        return 0, 0
    end
    local store = GetCompositeTargetOffsetStore(element, false)
    local memberStore = store and store[member.id]
    local saved = memberStore and memberStore[appearanceID]
    return tonumber(saved and saved.x) or 0,
        tonumber(saved and saved.y) or 0
end

function NSkin:GetCompositeMemberEffectiveTargetOffset(
    elementOrID, memberOrID, appearanceID, familyX, familyY)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member or type(appearanceID) ~= "string" then
        return tonumber(familyX) or 0, tonumber(familyY) or 0
    end

    local exactX, exactY = self:GetCompositeMemberTargetOffset(
        element, member, appearanceID)
    local overrideX = self:HasCompositeMemberPositionOverride(
        element, member, appearanceID, "alongOffset")
    local overrideY = self:HasCompositeMemberPositionOverride(
        element, member, appearanceID, "edgeOffset")
    return overrideX and (tonumber(exactX) or 0)
            or (tonumber(familyX) or 0),
        overrideY and (tonumber(exactY) or 0)
            or (tonumber(familyY) or 0)
end

function NSkin:SetCompositeMemberTargetOffset(
    elementOrID, memberOrID, appearanceID, x, y)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member or type(appearanceID) ~= "string"
        or appearanceID == ""
    then return false end

    x, y = tonumber(x) or 0, tonumber(y) or 0
    local store = GetCompositeTargetOffsetStore(element, true)
    store[member.id] = store[member.id] or {}
    local memberStore = store[member.id]
    local saved = memberStore[appearanceID]
    if saved and (tonumber(saved.x) or 0) == x
        and (tonumber(saved.y) or 0) == y
    then return false end
    if x == 0 and y == 0 then
        memberStore[appearanceID] = nil
        if not next(memberStore) then store[member.id] = nil end
    else
        memberStore[appearanceID] = { x = x, y = y }
    end
    self:NotifySkinningElementBoundsChanged(element.id)
    return true
end

local function GetCompositeFamilyOffsetStore(element, create)
    if not element or type(element.module) ~= "string" then return nil end
    local moduleOptions = NSkin:GetModuleOptions(element.module, create == true)
    if not moduleOptions then return nil end
    local all = moduleOptions.compositeFamilyOffsets
    if not all and create then
        all = {}
        moduleOptions.compositeFamilyOffsets = all
    end
    local store = all and all[element.id]
    if not store and create then
        store = {}
        all[element.id] = store
    end
    return store, all, moduleOptions
end

local function GetCompositeMemberFamilyKey(member)
    if not member then return nil end
    local key = member.movementFamilyID
        or (member.editorSurface == true
            and ("SURFACE:" .. tostring(member.kind))
            or member.kind)
    return type(key) == "string" and key ~= "" and key or nil
end

local function PruneCompositeFamilyOffsetStore(element)
    local store, all, moduleOptions =
        GetCompositeFamilyOffsetStore(element, false)
    if not store then return end
    if not next(store) then
        all[element.id] = nil
        if not next(all) then
            moduleOptions.compositeFamilyOffsets = nil
        end
    end
end

local function HasCompositePositionOverrideMetadata(
    element, memberID, propertyKey)
    local store = GetCompositePropertyOverrideStore(element, false)
    for _, entry in pairs(store or {}) do
        if entry.memberID == memberID
            and entry.groupID == "shared.movable"
            and entry.propertyKey == propertyKey
        then
            return true
        end
    end
    return false
end

local function HasCompositePositionOverrideForAppearance(
    element, memberID, propertyKey, appearanceID)
    local store = GetCompositePropertyOverrideStore(element, false)
    for _, entry in pairs(store or {}) do
        if entry.memberID == memberID
            and entry.groupID == "shared.movable"
            and entry.propertyKey == propertyKey
            and entry.appearanceID == appearanceID
        then
            return true
        end
    end
    return false
end

function NSkin:HasCompositeMemberPositionOverride(
    elementOrID, memberOrID, appearanceID, propertyKey)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return false end
    return HasCompositePositionOverrideForAppearance(
        element, member.id, propertyKey, appearanceID)
end

local function MakeCompositePropertyOverrideKey(
    memberID, groupID, propertyKey, appearanceID)
    return table.concat({
        memberID, groupID, propertyKey, appearanceID or "",
    }, "\031")
end

function NSkin:GetCompositePropertyOverrides(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local store = element and GetCompositePropertyOverrideStore(element, false)
    local entries = {}
    for token, entry in pairs(store or {}) do
        local member = self:GetCompositeMember(element, entry.memberID)
        if member then
            local copy = CopyTable(entry)
            copy.token = token
            copy.member = member
            entries[#entries + 1] = copy
        end
    end
    table.sort(entries, function(left, right)
        local leftLabel = tostring(left.label or left.propertyLabel or left.token)
        local rightLabel = tostring(right.label or right.propertyLabel or right.token)
        return leftLabel < rightLabel
    end)
    return entries
end

function NSkin:HasCompositeMemberOverride(elementOrID, memberOrID, target)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return false end

    local state = GetCompositionMemberState(element, member, false)
    if state and state.overrideSpecific == true then return true end

    local targetAppearanceID = target
        and self:GetCompositeMemberTargetAppearanceID(
            element, member, target) or nil
    local store = GetCompositePropertyOverrideStore(element, false)
    for _, entry in pairs(store or {}) do
        if entry.memberID == member.id then
            if not target then return true end
            if entry.appearanceID == targetAppearanceID then return true end
            if entry.appearanceID == nil and not member.getTargetAppearanceID then
                return true
            end
        end
    end
    return false
end

function NSkin:GetCompositeMemberFamily(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    local composition = element and element.composition
    if not element or not member or not composition
        or composition.mode ~= "COMPOSITE"
    then return nil end

    local key = GetCompositeMemberFamilyKey(member)
    local family = {}
    for _, candidate in ipairs(composition.members or {}) do
        if GetCompositeMemberFamilyKey(candidate) == key then
            family[#family + 1] = candidate
        end
    end
    if #family == 0 then family[1] = member end
    return family
end


function NSkin:AddCompositePropertyOverride(
    elementOrID, memberID, groupID, propertyKey, propertyLabel, target)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and self:GetCompositeMember(element, memberID)
    if not element or not member
        or type(groupID) ~= "string" or groupID == ""
        or type(propertyKey) ~= "string" or propertyKey == ""
    then return false end

    local appearanceID = self:GetCompositeMemberTargetAppearanceID(
        element, member, target)
    local exactAppearanceID = appearanceID ~= (member.appearanceID or member.id)
        and appearanceID or nil
    local store = GetCompositePropertyOverrideStore(element, true)
    local token = MakeCompositePropertyOverrideKey(
        member.id, groupID, propertyKey, exactAppearanceID)
    if store[token] then return true end

    -- Position overrides are absolute on their overridden axis. Seed the
    -- exact value from the currently resolved family position so adding an
    -- override never causes the target to jump.
    local seedPosition =
        groupID == "shared.movable"
        and (propertyKey == "alongOffset" or propertyKey == "edgeOffset")
    local familyX, familyY, exactX, exactY
    if seedPosition then
        familyX, familyY =
            self:GetCompositeMemberFamilyOffset(element, member)
        if exactAppearanceID then
            exactX, exactY = self:GetCompositeMemberTargetOffset(
                element, member, exactAppearanceID)
        else
            exactX, exactY = self:GetCompositeMemberOffset(element, member)
        end
    end

    store[token] = {
        memberID = member.id,
        groupID = groupID,
        propertyKey = propertyKey,
        propertyLabel = propertyLabel or propertyKey,
        appearanceID = exactAppearanceID,
        label = (member.label or member.id) .. " - "
            .. (propertyLabel or propertyKey),
    }

    if seedPosition then
        if propertyKey == "alongOffset" then
            exactX = (tonumber(familyX) or 0) + (tonumber(exactX) or 0)
        else
            exactY = (tonumber(familyY) or 0) + (tonumber(exactY) or 0)
        end
        if exactAppearanceID then
            self:SetCompositeMemberTargetOffset(
                element, member, exactAppearanceID, exactX, exactY)
        else
            self:SetCompositeMemberOffset(
                element, member, exactX, exactY)
        end
    end

    self:NotifySkinningElementBoundsChanged(element.id)
    return true
end

function NSkin:RemoveCompositePropertyOverrideMetadata(
    elementOrID, memberID, groupID, propertyKey, appearanceID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    if not element then return false end
    local store, all, moduleOptions =
        GetCompositePropertyOverrideStore(element, false)
    if not store then return false end
    local token = MakeCompositePropertyOverrideKey(
        memberID, groupID, propertyKey, appearanceID)
    if not store[token] and appearanceID == nil then
        token = table.concat(
            { memberID, groupID, propertyKey }, "\031")
    end
    if not store[token] then return false end
    store[token] = nil
    if not next(store) then
        all[element.id] = nil
        if not next(all) then
            moduleOptions.compositePropertyOverrides = nil
        end
    end
    self:NotifySkinningElementBoundsChanged(element.id)
    return true
end

function NSkin:GetCompositeMemberExactAppearanceContext(
    elementOrID, memberOrID, targetOrAppearanceID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return nil end

    local target
    local appearanceID
    if type(targetOrAppearanceID) == "string" then
        appearanceID = targetOrAppearanceID
        target = self:GetCompositeMemberTargetForAppearanceID(
            element, member, appearanceID)
    else
        target = targetOrAppearanceID or member._editorRuntimeTarget
        if not target then
            local targets = self:GetCompositionMemberTargets(
                element, member, false)
            target = member.movementOwner or targets[1]
        end
        appearanceID = self:GetCompositeMemberTargetAppearanceID(
            element, member, target)
    end
    appearanceID = appearanceID or member.appearanceID or member.id
    if appearanceID ~= (member.appearanceID or member.id) then
        self:RegisterAppearanceParentID(
            appearanceID, member.appearanceID or member.id, element.id)
    end

    member._exactAppearanceEditorContexts =
        member._exactAppearanceEditorContexts or {}
    local context = member._exactAppearanceEditorContexts[appearanceID] or {}
    member._exactAppearanceEditorContexts[appearanceID] = context
    context.id = appearanceID
    context.label = member.label or member.id
    context.kind = member.kind
    context.module = element.module
    context.window = element.window
    context.target = target
    context.appearanceWindowID =
        member.appearanceWindowID or element.appearanceWindowID
    context.compositeOwner = element
    context.compositeMember = member
    context.surfaceStyle = member.surfaceStyle
    context.surfaceAppearanceKey = member.surfaceAppearanceKey
    context.compositeTag = self:GetCompositeTag(element)
    context.exactMemberOverride = true
    context.exactAppearanceID = appearanceID
    return context
end

function NSkin:GetCompositeMemberExactPositionContext(
    elementOrID, memberOrID, targetOrAppearanceID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return nil end

    local target
    local appearanceID
    if type(targetOrAppearanceID) == "string" then
        appearanceID = targetOrAppearanceID
        target = self:GetCompositeMemberTargetForAppearanceID(
            element, member, appearanceID)
    else
        target = targetOrAppearanceID or member._editorRuntimeTarget
        appearanceID = target and self:GetCompositeMemberTargetAppearanceID(
            element, member, target) or nil
    end

    -- Repeated pooled members use a stable target appearance ID. Ordinary
    -- members keep the existing member-wide offset behavior.
    if appearanceID
        and appearanceID ~= (member.appearanceID or member.id)
    then
        member._exactPositionEditorContexts =
            member._exactPositionEditorContexts or {}
        local context =
            member._exactPositionEditorContexts[appearanceID] or {}
        member._exactPositionEditorContexts[appearanceID] = context
        context.id = appearanceID .. ":Position"
        context.label = member.label or member.id
        context.kind = member.kind
        context.module = element.module
        context.window = element.window
        context.target = target
        context.appearanceWindowID =
            member.appearanceWindowID or element.appearanceWindowID
        context.compositeOwner = element
        context.compositeMember = member
        context.exactMemberOverride = true
        context.exactAppearanceID = appearanceID
        context.getPlacement = function()
            local x, y = NSkin:GetCompositeMemberTargetOffset(
                element, member, appearanceID)
            return {
                mode = "OFFSET",
                alongOffset = x,
                edgeOffset = y,
            }
        end
        context.setPlacement = function(_, placement)
            local x = tonumber(placement and
                (placement.alongOffset or placement.x)) or 0
            local y = tonumber(placement and
                (placement.edgeOffset or placement.y)) or 0
            local changed = NSkin:SetCompositeMemberTargetOffset(
                element, member, appearanceID, x, y)
            if type(member.applyTargetOffset) == "function" then
                pcall(member.applyTargetOffset,
                    element, member, target, appearanceID, x, y)
            elseif changed and type(element.refreshLayout) == "function" then
                element.refreshLayout(NSkin, element)
            end
            return changed
        end
        context.resetPlacement = function()
            local changed = NSkin:SetCompositeMemberTargetOffset(
                element, member, appearanceID, 0, 0)
            if type(member.applyTargetOffset) == "function" then
                pcall(member.applyTargetOffset,
                    element, member, target, appearanceID, 0, 0)
            elseif changed and type(element.refreshLayout) == "function" then
                element.refreshLayout(NSkin, element)
            end
            return changed
        end
        return context
    end

    local context = member._exactPositionEditorContext or {}
    member._exactPositionEditorContext = context
    context.id = (member.appearanceID or member.id) .. ":Position"
    context.label = member.label or member.id
    context.kind = member.kind
    context.module = element.module
    context.window = element.window
    context.target = GetCompositeMemberMovementTarget(element, member)
    context.appearanceWindowID =
        member.appearanceWindowID or element.appearanceWindowID
    context.compositeOwner = element
    context.compositeMember = member
    context.exactMemberOverride = true
    context.getPlacement = function()
        local x, y = NSkin:GetCompositeMemberOffset(element, member)
        return {
            mode = "OFFSET",
            alongOffset = tonumber(x) or 0,
            edgeOffset = tonumber(y) or 0,
        }
    end
    context.setPlacement = function(_, placement)
        return NSkin:SetCompositeMemberOffset(
            element, member,
            tonumber(placement and
                (placement.alongOffset or placement.x)) or 0,
            tonumber(placement and
                (placement.edgeOffset or placement.y)) or 0)
    end
    context.resetPlacement = function()
        return NSkin:ResetCompositeMemberOffset(element, member)
    end
    return context
end

function NSkin:ResetCompositePropertyOverrides(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local composition = element and element.composition
    if not element or not composition or composition.mode ~= "COMPOSITE" then
        return false
    end

    local changed
    for _, member in ipairs(composition.members or {}) do
        changed = self:ResetElementAppearanceOverride(
            member.appearanceID or member.id) or changed
        local state = GetCompositionMemberState(element, member, false)
        if state and state.overrideSpecific ~= nil then
            state.overrideSpecific = nil
            PruneCompositionMemberState(element, member)
            changed = true
        end
        if member.attached == false then
            changed = self:SetCompositeMemberAttached(
                element, member, true) or changed
        end
        local x, y = self:GetCompositeMemberOffset(element, member)
        if (tonumber(x) or 0) ~= 0 or (tonumber(y) or 0) ~= 0 then
            changed = self:ResetCompositeMemberOffset(
                element, member) or changed
        end
    end

    local resetFamilies = {}
    for _, member in ipairs(composition.members or {}) do
        local key = GetCompositeMemberFamilyKey(member)
        if key and not resetFamilies[key] then
            resetFamilies[key] = true
            changed = self:ResetCompositeMemberFamilyOffset(
                element, member) or changed
        end
    end

    local store, all, moduleOptions =
        GetCompositePropertyOverrideStore(element, false)
    if store then
        all[element.id] = nil
        if not next(all) then
            moduleOptions.compositePropertyOverrides = nil
        end
        changed = true
    end

    if changed and type(element.refreshAppearance) == "function" then
        element.refreshAppearance(self, element)
    end
    if changed and type(element.refreshLayout) == "function" then
        element.refreshLayout(self, element)
    end
    return changed == true
end

local function MakeStableMemberID(element, member, index, used)
    local explicit = member.id or member.memberID
    if type(explicit) == "string" and explicit ~= "" then
        if used[explicit] then return nil end
        used[explicit] = true
        return explicit
    end

    local token = member.key or member.kind or ("Member" .. index)
    token = tostring(token):gsub("[^%w_%-]", "")
    if token == "" then token = "Member" .. index end
    local base = element.id .. ".Member." .. token
    local candidate, suffix = base, 2
    while used[candidate] do
        candidate = base .. suffix
        suffix = suffix + 1
    end
    used[candidate] = true
    return candidate
end

local function GetCompositeSurfaceEditorOptions()
    return {
        {
            id = "shared.surfaceGeometry",
            label = "Surface",
            category = "CUSTOMIZE",
            contextualInline = true,
        },
        {
            id = "shared.surfaceBackground",
            label = "Background",
            category = "CUSTOMIZE",
            contextualInline = false,
            headerToggleKey = "showBackground",
        },
        {
            id = "shared.surfaceBorder",
            label = "Border",
            category = "CUSTOMIZE",
            contextualInline = false,
            headerToggleKey = "showBorder",
        },
        {
            id = "shared.surfaceHighlight",
            label = "Highlight",
            category = "CUSTOMIZE",
            contextualInline = false,
            headerToggleKey = "showHighlight",
        },
    }
end

function NSkin:GetCompositeSurfaceEditorOptions(includeGeometry)
    local options = {}
    for _, definition in ipairs(GetCompositeSurfaceEditorOptions()) do
        if includeGeometry ~= false
            or definition.id ~= "shared.surfaceGeometry"
        then
            local copy = {}
            for key, value in pairs(definition) do copy[key] = value end
            options[#options + 1] = copy
        end
    end
    return options
end

local DEFAULT_COMPOSITE_SELECTION_STATES = {
    { id = "Selected", label = "Selected", previewRuntimeState = false },
    { id = "Unselected", label = "Unselected", previewRuntimeState = false },
}

local function CopyCompositeSelectionStates(selection)
    local source = type(selection.states) == "table"
        and #selection.states > 0
        and selection.states or DEFAULT_COMPOSITE_SELECTION_STATES
    local states = {}
    for _, definition in ipairs(source) do
        if type(definition) == "table"
            and type(definition.id) == "string"
            and definition.id ~= ""
        then
            local copy = {}
            for key, value in pairs(definition) do copy[key] = value end
            states[#states + 1] = copy
        end
    end
    return states
end

local function PrepareCompositeSelectionMember(
    element, composition, member)
    local selection = composition and composition.selection
    if member.selectionParticipant ~= true
        or type(selection) ~= "table"
        or type(selection.getStateID) ~= "function"
    then
        return
    end

    if type(member.states) ~= "table" or #member.states == 0 then
        member.states = CopyCompositeSelectionStates(selection)
    end
    if type(member.getStateID) ~= "function" then
        member.getStateID = function(currentElement, currentMember, target)
            local itemTarget = target
            if type(selection.resolveItemTarget) == "function" then
                local ok, resolved = pcall(
                    selection.resolveItemTarget,
                    currentElement, currentMember, target)
                if ok and resolved then itemTarget = resolved end
            end
            local ok, stateID = pcall(
                selection.getStateID,
                currentElement, itemTarget, currentMember, target)
            return ok and stateID or nil
        end
    end
end

local function NormalizeCompositeMembers(element, composition)
    local normalized, byID, used = {}, {}, {}
    for index, source in ipairs(composition.members or {}) do
        if type(source) == "table" then
            local member = source
            local id = MakeStableMemberID(element, member, index, used)
            if id then
                member.id = id
                member.memberID = nil
                member.role = member.role == "PRIMARY" and "PRIMARY" or "SECONDARY"
                member.appearanceWindowID =
                    member.appearanceWindowID or element.appearanceWindowID
                member.appearanceID =
                    member.appearanceID or member.elementID or member.id
                NormalizeElementPresentation(member, member.id)
                PrepareCompositeSelectionMember(
                    element, composition, member)
                -- TEXT and CHECKBOX are canonical shared components. Every
                -- registered member gets the same exact-property override
                -- system regardless of which Composite/window registered it.
                if member.kind == "TEXT" or member.kind == "CHECKBOX" then
                    member.allowOverrides = true
                end
                if member.editorSurface == true then
                    member.allowOverrides = true
                    if not member.surfaceAppearanceKey then
                        local component = member.kind
                            and NSkin:GetSharedElementType(member.kind)
                        member.surfaceAppearanceKey =
                            component and component.style or nil
                    end
                    if type(member.editorOptions) ~= "table"
                        or #member.editorOptions == 0
                    then
                        member.editorOptions =
                            GetCompositeSurfaceEditorOptions()
                    end
                end
                local familyAppearanceID
                if type(member.appearanceParentID) == "string"
                    and member.appearanceParentID ~= ""
                    and member.appearanceParentID ~= member.appearanceID
                then
                    familyAppearanceID = member.appearanceParentID
                    appearanceParentByID[member.appearanceID] =
                        familyAppearanceID
                    RegisterCompositeAppearanceFamilyMember(
                        familyAppearanceID, element, member)
                end
                appearanceOwnerByID[member.appearanceID] = element.id
                RegisterCompositeMemberAppearance(
                    element, member, member.appearanceID)
                for _, stateDefinition in ipairs(member.states or {}) do
                    local stateID = stateDefinition.appearanceID
                        or (member.appearanceID .. ".State."
                            .. tostring(stateDefinition.id))
                    stateDefinition.appearanceID = stateID
                    local stateParentID = member.appearanceID
                    if familyAppearanceID then
                        local familyStateID = familyAppearanceID
                            .. ".State." .. tostring(stateDefinition.id)
                        appearanceParentByID[familyStateID] =
                            familyAppearanceID
                        RegisterCompositeAppearanceFamilyMember(
                            familyStateID, element, member)
                        stateParentID = familyStateID
                    end
                    appearanceParentByID[stateID] = stateParentID
                    appearanceOwnerByID[stateID] = element.id
                    appearanceStateByID[stateID] = {
                        elementID = element.id,
                        memberID = member.id,
                        stateID = stateDefinition.id,
                    }
                end
                if member.attached == nil then member.attached = true end
                local saved = GetCompositionMemberState(element, member, false)
                if saved then
                    if saved.attached ~= nil then
                        member.attached = saved.attached == true
                    end
                    member.localX = tonumber(saved.x) or 0
                    member.localY = tonumber(saved.y) or 0
                else
                    member.localX = tonumber(member.localX) or 0
                    member.localY = tonumber(member.localY) or 0
                end
                normalized[#normalized + 1] = member
                byID[id] = member
            end
        end
    end
    local hasSurface
    for _, member in ipairs(normalized) do
        if member.editorSurface == true then
            hasSurface = true
            break
        end
    end
    if not hasSurface and element.target then
        local component = element.kind
            and NSkin:GetSharedElementType(element.kind)
        local surfaceID = element.id .. ".Surface"
        if not used[surfaceID] then
            local surface = {
                id = surfaceID,
                kind = element.kind or "BUTTON",
                role = "PRIMARY",
                label = (composition.editorLabel
                    or element.label or element.id) .. " Surface",
                target = element.target,
                appearanceWindowID = element.appearanceWindowID,
                appearanceID = surfaceID,
                appearanceParentID = element.id,
                editorSurface = true,
                surfaceAppearanceKey = component and component.style or nil,
                allowOverrides = true,
                editorOptions = GetCompositeSurfaceEditorOptions(),
                movable = false,
            }
            table.insert(normalized, 1, surface)
            byID[surfaceID] = surface
            used[surfaceID] = true
            if surface.appearanceParentID ~= surface.appearanceID then
                appearanceParentByID[surface.appearanceID] =
                    surface.appearanceParentID
            end
            appearanceOwnerByID[surface.appearanceID] = element.id
            RegisterCompositeMemberAppearance(
                element, surface, surface.appearanceID)
        end
    end

    composition.members = normalized
    composition.membersByID = byID
end

local function MigrateCompositeFamilyOffsets(element, composition)
    local existing = GetCompositeFamilyOffsetStore(element, false)
    local families = {}
    for _, member in ipairs(composition.members or {}) do
        local key = GetCompositeMemberFamilyKey(member)
        if key then
            local family = families[key]
            if not family then
                family = {}
                families[key] = family
            end
            family[#family + 1] = member
        end
    end

    for key, members in pairs(families) do
        local savedFamily = existing and existing[key]
        local familyX = savedFamily and tonumber(savedFamily.x) or nil
        local familyY = savedFamily and tonumber(savedFamily.y) or nil

        if not savedFamily then
            local firstX, firstY, uniform
            for index, member in ipairs(members) do
                local state = GetCompositionMemberState(
                    element, member, false)
                local hasExactX = HasCompositePositionOverrideMetadata(
                    element, member.id, "alongOffset")
                local hasExactY = HasCompositePositionOverrideMetadata(
                    element, member.id, "edgeOffset")
                if hasExactX or hasExactY then
                    uniform = false
                    break
                end
                local x = state and tonumber(state.x) or 0
                local y = state and tonumber(state.y) or 0
                if index == 1 then
                    firstX, firstY, uniform = x, y, true
                elseif x ~= firstX or y ~= firstY then
                    uniform = false
                end
            end
            if uniform and ((firstX or 0) ~= 0 or (firstY or 0) ~= 0) then
                local store = GetCompositeFamilyOffsetStore(element, true)
                store[key] = { x = firstX or 0, y = firstY or 0 }
                existing = store
                familyX, familyY = firstX or 0, firstY or 0
            end
        end

        familyX, familyY = familyX or 0, familyY or 0
        for _, member in ipairs(members) do
            local state = GetCompositionMemberState(element, member, false)
            local exactX = state and tonumber(state.x) or 0
            local exactY = state and tonumber(state.y) or 0
            local keepX = HasCompositePositionOverrideMetadata(
                element, member.id, "alongOffset")
            local keepY = HasCompositePositionOverrideMetadata(
                element, member.id, "edgeOffset")

            if state then
                if not keepX then state.x = nil; exactX = 0 end
                if not keepY then state.y = nil; exactY = 0 end
                PruneCompositionMemberState(element, member)
            end
            member.localX = familyX + exactX
            member.localY = familyY + exactY
        end
    end
end

local function NormalizeContainerChildren(element, composition)
    for childID, parentID in pairs(containerParentByChildID) do
        if parentID == element.id then
            containerParentByChildID[childID] = nil
        end
    end

    local children, seen = {}, {}
    for _, child in ipairs(composition.children or {}) do
        local id = type(child) == "table" and (child.id or child.elementID)
            or child
        if type(id) == "string" and id ~= "" and not seen[id] then
            seen[id] = true
            children[#children + 1] = id
            containerParentByChildID[id] = element.id
        end
    end
    composition.children = children
end

local COMPOSITE_LAYOUT_ORIENTATIONS = {
    HORIZONTAL = true,
    VERTICAL = true,
}

local COMPOSITE_LAYOUT_DISTRIBUTIONS = {
    EQUAL_SLOTS = true,
}

local function NormalizeCompositeLayout(composition)
    local layout = composition and composition.layout
    if type(layout) ~= "table" then
        composition.layout = nil
        return
    end

    local orientation =
        tostring(layout.orientation or "HORIZONTAL"):upper()
    local distribution =
        tostring(layout.distribution or "EQUAL_SLOTS"):upper()
    if not COMPOSITE_LAYOUT_ORIENTATIONS[orientation]
        or not COMPOSITE_LAYOUT_DISTRIBUTIONS[distribution]
    then
        composition.layout = nil
        return
    end

    layout.orientation = orientation
    layout.distribution = distribution
end

local function NormalizeComposition(element)
    local composition = element.composition
    if type(composition) ~= "table" then composition = {} end
    local mode = tostring(composition.mode or "STANDALONE"):upper()
    if not COMPOSITION_MODES[mode] then mode = "STANDALONE" end
    composition.mode = mode

    NormalizeElementPresentation(element, element.id)
    NormalizeCompositionPresentation(element, composition)

    if mode == "COMPOSITE" then
        local compositeType = tostring(composition.type or "REGULAR"):upper()
        if not compositeTypes[compositeType] then compositeType = "REGULAR" end
        composition.type = compositeType
        NormalizeCompositeMembers(element, composition)
        NormalizeCompositeLayout(composition)
        MigrateCompositeFamilyOffsets(element, composition)
    elseif mode == "CONTAINER" then
        NormalizeContainerChildren(element, composition)
        NormalizeContainerSurface(element, composition)
    end

    element.composition = composition
    return composition
end

function NSkin:RegisterCompositeType(typeID, definition)
    if type(typeID) ~= "string" or typeID == ""
        or type(definition) ~= "table"
    then return false end
    typeID = typeID:upper()
    if typeID == "REGULAR" then return false end
    compositeTypes[typeID] = definition
    return true
end

function NSkin:GetCompositeType(typeID)
    typeID = type(typeID) == "string" and typeID:upper() or "REGULAR"
    return compositeTypes[typeID] or compositeTypes.REGULAR
end

function NSkin:GetElementComposition(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    return element and element.composition or nil
end

function NSkin:SetElementComposition(elementOrID, composition)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    if not element or type(composition) ~= "table" then return nil end
    element.composition = composition
    self:InitializeElementComposition(element)
    return element.composition
end

function NSkin:GetCompositeMember(elementOrID, memberID)
    local composition = self:GetElementComposition(elementOrID)
    return composition and composition.mode == "COMPOSITE"
        and composition.membersByID and composition.membersByID[memberID] or nil
end

function NSkin:GetCompositeMembers(elementOrID)
    local composition = self:GetElementComposition(elementOrID)
    return composition and composition.mode == "COMPOSITE"
        and composition.members or nil
end

function NSkin:GetCompositionMemberAppearanceContext(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    if not element then return nil end
    local member = type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID)
    if not member then return nil end
    return {
        appearanceWindowID =
            member.appearanceWindowID or element.appearanceWindowID,
        appearanceID = member.appearanceID or member.id,
        kind = member.kind,
        memberID = member.id,
    }
end

function NSkin:GetContainerChildren(elementOrID)
    local composition = self:GetElementComposition(elementOrID)
    if not composition or composition.mode ~= "CONTAINER" then return nil end
    local children = {}
    for _, id in ipairs(composition.children or {}) do
        local child = self:GetSkinningElement(id)
        if child then children[#children + 1] = child end
    end
    return children
end

function NSkin:GetCompositionContainerParent(elementOrID)
    local id = type(elementOrID) == "table" and elementOrID.id or elementOrID
    local parentID = id and containerParentByChildID[id]
    return parentID and self:GetSkinningElement(parentID) or nil
end

function NSkin:GetCompositeFamilyID(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local composition = element and element.composition
    if not composition or composition.mode ~= "COMPOSITE" then return nil end
    return composition.familyID or element.id
end

function NSkin:GetCompositeFamilyLabel(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local composition = element and element.composition
    if not composition or composition.mode ~= "COMPOSITE" then return nil end
    return composition.familyLabel
        or composition.editorLabel
        or composition.groupLabel
        or element.label
        or element.id
end

function NSkin:GetContainerCompositeFamilies(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local composition = element and element.composition
    if not composition or composition.mode ~= "CONTAINER" then return nil end

    local families, byID = {}, {}
    for _, child in ipairs(self:GetContainerChildren(element) or {}) do
        local childComposition = child.composition
        if childComposition and childComposition.mode == "COMPOSITE" then
            local familyID = self:GetCompositeFamilyID(child)
            local family = familyID and byID[familyID]
            if not family and familyID then
                family = {
                    id = familyID,
                    label = self:GetCompositeFamilyLabel(child),
                    representative = child,
                    elements = {},
                }
                byID[familyID] = family
                families[#families + 1] = family
            end
            if family then
                family.elements[#family.elements + 1] = child
            end
        end
    end
    return families
end

local function GetCompositeMemberFamilyAppearanceID(member)
    return member and (member.appearanceParentID
        or member.appearanceID or member.id) or nil
end

function NSkin:CompositeMembersShareContainerFamily(
    leftElementOrID, leftMemberOrID, rightElementOrID, rightMemberOrID)
    local leftElement = type(leftElementOrID) == "table"
        and leftElementOrID or self:GetSkinningElement(leftElementOrID)
    local rightElement = type(rightElementOrID) == "table"
        and rightElementOrID or self:GetSkinningElement(rightElementOrID)
    local leftMember = leftElement and (type(leftMemberOrID) == "table"
        and leftMemberOrID or self:GetCompositeMember(
            leftElement, leftMemberOrID))
    local rightMember = rightElement and (type(rightMemberOrID) == "table"
        and rightMemberOrID or self:GetCompositeMember(
            rightElement, rightMemberOrID))
    if not leftElement or not rightElement or not leftMember or not rightMember
        or leftMember.kind ~= rightMember.kind
    then
        return false
    end

    local leftParent = self:GetCompositionContainerParent(leftElement)
    local rightParent = self:GetCompositionContainerParent(rightElement)
    if not leftParent or leftParent ~= rightParent then return false end

    local leftFamily = GetCompositeMemberFamilyAppearanceID(leftMember)
    local rightFamily = GetCompositeMemberFamilyAppearanceID(rightMember)
    return leftFamily ~= nil and leftFamily == rightFamily
end

function NSkin:GetContainerCompositeMemberFamily(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table"
        and memberOrID or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return nil end

    local container = self:GetCompositionContainerParent(element)
    if not container then
        return { { element = element, member = member } }
    end

    local family = {}
    for _, child in ipairs(self:GetContainerChildren(container) or {}) do
        local composition = child.composition
        if composition and composition.mode == "COMPOSITE" then
            for _, candidate in ipairs(composition.members or {}) do
                if self:CompositeMembersShareContainerFamily(
                    element, member, child, candidate)
                then
                    family[#family + 1] = {
                        element = child,
                        member = candidate,
                    }
                end
            end
        end
    end
    if #family == 0 then
        family[1] = { element = element, member = member }
    end
    return family
end

local function GetSortedEditorGroupMembers(group)
    local members = {}
    for _, element in pairs(group.membersByID or {}) do
        members[#members + 1] = element
    end
    table.sort(members, function(left, right) return left.id < right.id end)
    return members
end

function NSkin:RegisterEditorGroup(definition)
    if type(definition) ~= "table" or type(definition.id) ~= "string"
        or definition.id == ""
    then return nil end
    local group = editorGroups[definition.id]
    if not group then
        group = { id = definition.id, membersByID = {} }
        editorGroups[definition.id] = group
    end
    group.label = definition.label or group.label or definition.id
    group.window = definition.window or group.window
    group.appearanceWindowID =
        definition.appearanceWindowID or group.appearanceWindowID
    group.priority = tonumber(definition.priority) or group.priority or 0

    for _, member in ipairs(definition.members or {}) do
        local element = type(member) == "table" and member
            or self:GetSkinningElement(member)
        if element and type(element.id) == "string" then
            local previous = editorGroupByElementID[element.id]
            if previous and previous ~= group then
                previous.membersByID[element.id] = nil
            end
            group.membersByID[element.id] = element
            editorGroupByElementID[element.id] = group
        end
    end
    return group
end

function NSkin:GetEditorGroup(elementOrID)
    if type(elementOrID) == "table" and elementOrID.membersByID
        and editorGroups[elementOrID.id] == elementOrID
    then return elementOrID end
    local id = type(elementOrID) == "table" and elementOrID.id or elementOrID
    return editorGroupByElementID[id] or editorGroups[id]
end

function NSkin:GetEditorGroupMembers(elementOrID)
    local group = self:GetEditorGroup(elementOrID)
    return group and GetSortedEditorGroupMembers(group) or nil
end

local function QueueCompositionBoundsRefresh(element)
    if element.compositionBoundsRefreshPending then return end
    element.compositionBoundsRefreshPending = true
    local function NotifyOnce()
        element.compositionBoundsRefreshPending = nil
        if NSkin:GetSkinningElement(element.id) == element then
            NSkin:NotifySkinningElementBoundsChanged(element.id)
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, NotifyOnce)
    else
        NotifyOnce()
    end
end

local ApplyCompositeMemberGeometry
local RefreshCompositeSurfaceAnchorMode

local function HookCompositionTarget(element, target)
    if not target or element.compositionHookedTargets[target] then return end
    element.compositionHookedTargets[target] = true
    for _, method in ipairs({
        "Show", "Hide", "SetShown", "SetText", "SetFont",
        "SetFormattedText", "SetPoint", "SetSize", "SetWidth",
        "SetHeight", "SetScale",
    }) do
        if type(target[method]) == "function" then
            hooksecurefunc(target, method, function()
                QueueCompositionBoundsRefresh(element)
            end)
        end
    end
end

function NSkin:InitializeElementComposition(element)
    local composition = NormalizeComposition(element)
    RegisterCompositeTag(element)
    if composition.mode == "COMPOSITE"
        and type(element.module) == "string"
    then
        local options = self:GetModuleOptions(element.module, false)
        if options and options.movablePlacements
            and options.movablePlacements[element.id]
        then
            options.movablePlacements[element.id] = nil
            if not next(options.movablePlacements) then
                options.movablePlacements = nil
            end
        end
    end
    if element.compositionParentID then
        element.draggable, element.movable = false, false
    end
    if composition.mode ~= "COMPOSITE" then return composition end

    element.compositionHookedTargets = element.compositionHookedTargets
        or setmetatable({}, { __mode = "k" })
    if RefreshCompositeSurfaceAnchorMode then
        RefreshCompositeSurfaceAnchorMode(element)
    end
    for _, member in ipairs(composition.members or {}) do
        local targets = self:GetCompositionMemberTargets(element, member, false)
        for _, target in ipairs(targets) do
            HookCompositionTarget(element, target)
        end
        if ApplyCompositeMemberGeometry
            and (member.attached == false
                or (tonumber(member.localX) or 0) ~= 0
                or (tonumber(member.localY) or 0) ~= 0)
        then
            ApplyCompositeMemberGeometry(element, member,
                tonumber(member.localX) or 0,
                tonumber(member.localY) or 0)
        end
    end
    return composition
end

function NSkin:GetCompositionParent(element)
    return element and element.compositionParentID
        and self:GetSkinningElement(element.compositionParentID) or nil
end

function NSkin:GetCompositionMovementOwner(element)
    if not element or element.compositionParentID then return nil end
    local composition = element.composition
    return composition and composition.movementOwner or element.target
end


local function ResolveMemberTargets(member, element, visibleOnly)
    local provider = member and (member.targets or member.regions)
    local targets
    if type(provider) == "function" then
        local ok, resolved = pcall(provider, element, member)
        if ok and type(resolved) == "table" then targets = resolved end
    elseif type(provider) == "table" then
        targets = provider
    elseif member and member.target then
        targets = { member.target }
    end
    local result = {}
    for i = 1, #(targets or {}) do
        local target = targets[i]
        if target and (not visibleOnly
            or ((not target.IsVisible or target:IsVisible())
                and (not target.IsShown or target:IsShown())))
        then
            result[#result + 1] = target
        end
    end
    return result
end

function NSkin:GetCompositionMemberTargets(element, member, visibleOnly)
    return ResolveMemberTargets(member, element, visibleOnly == true)
end

local function ResolveCompositeLayoutTargets(element, composition)
    local layout = composition and composition.layout
    if not layout then return {} end

    local provider = layout.targets
    local targets
    if type(provider) == "function" then
        local ok, resolved = pcall(provider, element, layout)
        if ok and type(resolved) == "table" then
            targets = resolved
        end
    elseif type(provider) == "table" then
        targets = provider
    elseif type(layout.memberID) == "string"
        and composition.membersByID
    then
        targets = ResolveMemberTargets(
            composition.membersByID[layout.memberID], element, true)
    end

    local result = {}
    for _, target in ipairs(targets or {}) do
        if target and target.ClearAllPoints and target.SetPoint
            and (not target.IsVisible or target:IsVisible())
        then
            result[#result + 1] = target
        end
    end
    return result
end

local function ResolveCompositeLayoutSurface(element, composition)
    local layout = composition and composition.layout
    if not layout then return nil end

    local member = layout.surfaceMemberID
        and composition.membersByID
        and composition.membersByID[layout.surfaceMemberID]
    if not member then
        for _, candidate in ipairs(composition.members or {}) do
            if candidate.editorSurface == true then
                member = candidate
                break
            end
        end
    end
    if not member then return nil end

    local targets = ResolveMemberTargets(member, element, false)
    return targets[1]
end

function NSkin:ApplyCompositeLayout(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local composition = element and element.composition
    local layout = composition and composition.layout
    if not element or not layout
        or layout.distribution ~= "EQUAL_SLOTS"
    then return false end

    local surface = ResolveCompositeLayoutSurface(element, composition)
    local targets = ResolveCompositeLayoutTargets(element, composition)
    local count = #targets
    if not surface or count == 0 then return false end

    local horizontal = layout.orientation == "HORIZONTAL"
    local extent = horizontal
        and tonumber(surface:GetWidth())
        or tonumber(surface:GetHeight())
    if not extent or extent <= 0 then return false end

    local slot = extent / count
    for index, target in ipairs(targets) do
        local along = slot * (index - 0.5)
        target:ClearAllPoints()
        if horizontal then
            target:SetPoint("CENTER", surface, "LEFT", along, 0)
        else
            target:SetPoint("CENTER", surface, "TOP", 0, -along)
        end
    end

    self:NotifySkinningElementBoundsChanged(element.id)
    return true
end


GetCompositeMemberMovementTarget = function(element, member)
    if member.movementOwner then return member.movementOwner end
    local targets = ResolveMemberTargets(member, element, false)
    return targets[1]
end

local function GetCompositeMemberBaselineID(element, member)
    return element.id .. ":CompositeMember:" .. member.id
end

local function EnsureCompositeMemberBaseline(element, member)
    local target = GetCompositeMemberMovementTarget(element, member)
    if not target or not target.GetNumPoints then return nil, nil end
    local baselineID = GetCompositeMemberBaselineID(element, member)
    NSkin:CaptureComponentBaseline(baselineID, target, {
        points = true,
        canCapture = function(frame)
            return frame.GetNumPoints and frame:GetNumPoints() > 0
        end,
    })
    local baseline = NSkin:GetComponentBaseline(baselineID)
    if not baseline or type(baseline.points) ~= "table"
        or #baseline.points == 0
    then return nil, nil end
    member._baselineID = baselineID
    return target, baseline
end

local function CaptureStableMemberAnchor(element, member, target)
    if member._stableBasePoints then return true end
    local parent = target.GetParent and target:GetParent()
        or element.window
    if not parent then parent = element.window end

    local left, _, _, top = NSkin:GetUIParentNormalizedBounds(target)
    local parentLeft, _, _, parentTop =
        NSkin:GetUIParentNormalizedBounds(parent)
    if not left or not top or not parentLeft or not parentTop then
        return false
    end

    local uiScale = UIParent and UIParent:GetEffectiveScale() or 1
    local parentScale = parent.GetEffectiveScale
        and parent:GetEffectiveScale() or uiScale
    if not uiScale or uiScale == 0
        or not parentScale or parentScale == 0
    then
        return false
    end

    local scale = uiScale / parentScale
    member._stableBasePoints = {
        { "TOPLEFT", parent, "TOPLEFT",
            (left - parentLeft) * scale,
            (top - parentTop) * scale },
    }
    return true
end

local function RestoreCompositeMemberBaseline(element, member)
    local target, baseline = EnsureCompositeMemberBaseline(element, member)
    if not target or not baseline or not target.ClearAllPoints
        or not target.SetPoint
    then return false end

    target:ClearAllPoints()
    for _, point in ipairs(baseline.points or {}) do
        target:SetPoint(point[1], point[2], point[3],
            tonumber(point[4]) or 0, tonumber(point[5]) or 0)
    end
    member._stableBasePoints = nil
    member._detachedBasePoints = nil
    member.localX, member.localY = 0, 0
    NSkin:MarkComponentGeometryModified(
        member._baselineID, "points", false)
    return true
end

RefreshCompositeSurfaceAnchorMode = function(element)
    local composition = element and element.composition
    if not composition or composition.mode ~= "COMPOSITE" then
        return false
    end

    local active
    for _, member in ipairs(composition.members or {}) do
        if member.editorSurface == true then
            local state = GetCompositionMemberState(
                element, member, false)
            if state and ((tonumber(state.x) or 0) ~= 0
                or (tonumber(state.y) or 0) ~= 0)
            then
                active = true
                break
            end
        end
    end

    local changed
    for _, member in ipairs(composition.members or {}) do
        if member.editorSurface == true then
            local target = GetCompositeMemberMovementTarget(
                element, member)
            if active then
                if target and CaptureStableMemberAnchor(
                    element, member, target)
                then
                    member._forceStableAnchor = true
                    local x, y = NSkin:GetCompositeMemberOffset(
                        element, member)
                    target:ClearAllPoints()
                    for _, point in ipairs(member._stableBasePoints) do
                        target:SetPoint(point[1], point[2], point[3],
                            (tonumber(point[4]) or 0) + (tonumber(x) or 0),
                            (tonumber(point[5]) or 0) + (tonumber(y) or 0))
                    end
                    changed = true
                end
            elseif member._forceStableAnchor then
                member._forceStableAnchor = nil
                changed = RestoreCompositeMemberBaseline(
                    element, member) or changed
            end
        end
    end
    return changed == true
end

ApplyCompositeMemberGeometry = function(element, member, x, y)
    if not element or not member
        or (_G.InCombatLockdown and _G.InCombatLockdown())
    then return false end
    local target, baseline = EnsureCompositeMemberBaseline(element, member)
    if not target or not target.ClearAllPoints or not target.SetPoint then
        return false
    end

    x, y = tonumber(x) or 0, tonumber(y) or 0
    local points = baseline.points
    if member.attached == false then
        if not CaptureStableMemberAnchor(element, member, target) then
            return false
        end
        member._detachedBasePoints = member._stableBasePoints
        points = member._detachedBasePoints
    elseif member.kind == "TEXT" then
        member._detachedBasePoints = nil
        member._stableBasePoints = nil
        points = baseline.points
    elseif member._forceStableAnchor or x ~= 0 or y ~= 0 then
        if not CaptureStableMemberAnchor(element, member, target) then
            return false
        end
        member._detachedBasePoints = nil
        points = member._stableBasePoints
    else
        member._detachedBasePoints = nil
        member._stableBasePoints = nil
    end

    target:ClearAllPoints()
    for _, point in ipairs(points) do
        target:SetPoint(point[1], point[2], point[3],
            (tonumber(point[4]) or 0) + x,
            (tonumber(point[5]) or 0) + y)
    end
    NSkin:MarkComponentGeometryModified(
        member._baselineID, "points",
        member.attached == false or x ~= 0 or y ~= 0)
    member.localX, member.localY = x, y
    QueueCompositionBoundsRefresh(element)
    return true
end

function NSkin:GetCompositeMemberBounds(elementOrID, memberOrID, visibleOnly)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    if not element then return nil end
    local member = type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID)
    if not member then return nil end

    local left, right, bottom, top
    for _, target in ipairs(ResolveMemberTargets(
        member, element, visibleOnly ~= false))
    do
        local l, r, b, t = self:GetUIParentNormalizedBounds(target)
        if l then
            left = left and math.min(left, l) or l
            right = right and math.max(right, r) or r
            bottom = bottom and math.min(bottom, b) or b
            top = top and math.max(top, t) or t
        end
    end
    return left, right, bottom, top
end

function NSkin:GetCompositionBounds(elementOrID, visibleOnly)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local composition = element and element.composition
    if not composition or composition.mode ~= "COMPOSITE" then return nil end

    local left, right, bottom, top
    for _, member in ipairs(composition.members or {}) do
        if member.attached ~= false then
            local l, r, b, t = self:GetCompositeMemberBounds(
                element, member, visibleOnly)
            if l then
                left = left and math.min(left, l) or l
                right = right and math.max(right, r) or r
                bottom = bottom and math.min(bottom, b) or b
                top = top and math.max(top, t) or t
            end
        end
    end
    return left, right, bottom, top
end

local function GetCompositeMemberFamilyStorageOwner(element, member)
    if not element or not member then return element, nil end
    local container = NSkin:GetCompositionContainerParent(element)
    local appearanceFamily = member.appearanceParentID
    if container and type(appearanceFamily) == "string"
        and appearanceFamily ~= ""
    then
        return container, "APPEARANCE:" .. appearanceFamily
    end
    return element, GetCompositeMemberFamilyKey(member)
end

function NSkin:GetCompositeMemberFamilyOffset(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return nil end
    local owner, key = GetCompositeMemberFamilyStorageOwner(element, member)
    if not owner or not key then return nil end
    local store = GetCompositeFamilyOffsetStore(owner, false)
    local saved = store and store[key]
    return saved and tonumber(saved.x) or 0,
        saved and tonumber(saved.y) or 0
end

function NSkin:ApplyCompositeMemberFamilyOffset(
    elementOrID, memberOrID, x, y)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return false end
    x, y = tonumber(x) or 0, tonumber(y) or 0

    local family = self:GetContainerCompositeMemberFamily(element, member)
        or { { element = element, member = member } }
    local applied
    for _, entry in ipairs(family) do
        local currentElement, currentMember = entry.element, entry.member
        if type(currentMember.applyFamilyOffset) == "function" then
            local ok, result = pcall(
                currentMember.applyFamilyOffset,
                currentElement, currentMember, x, y)
            applied = (ok and result == true) or applied
        else
            local exactX, exactY =
                self:GetCompositeMemberOffset(currentElement, currentMember)
            local overrideX = HasCompositePositionOverrideForAppearance(
                currentElement, currentMember.id, "alongOffset", nil)
            local overrideY = HasCompositePositionOverrideForAppearance(
                currentElement, currentMember.id, "edgeOffset", nil)
            local resolvedX = overrideX
                and (tonumber(exactX) or 0)
                or x + (tonumber(exactX) or 0)
            local resolvedY = overrideY
                and (tonumber(exactY) or 0)
                or y + (tonumber(exactY) or 0)
            applied = ApplyCompositeMemberGeometry(
                currentElement, currentMember,
                resolvedX, resolvedY) or applied
            self:NotifySkinningElementBoundsChanged(currentElement.id)
        end
    end
    return applied == true
end

function NSkin:SetCompositeMemberFamilyOffset(
    elementOrID, memberOrID, x, y)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return false end
    local owner, key = GetCompositeMemberFamilyStorageOwner(element, member)
    if not owner or not key then return false end
    x, y = tonumber(x) or 0, tonumber(y) or 0

    local store = GetCompositeFamilyOffsetStore(owner, true)
    local previous = store[key]
    if x == 0 and y == 0 then
        store[key] = nil
    else
        store[key] = { x = x, y = y }
    end

    if not self:ApplyCompositeMemberFamilyOffset(
        element, member, x, y)
    then
        store[key] = previous
        PruneCompositeFamilyOffsetStore(owner)
        return false
    end

    PruneCompositeFamilyOffsetStore(owner)
    self:NotifySkinningElementBoundsChanged(element.id)
    return true
end

function NSkin:ResetCompositeMemberFamilyOffset(elementOrID, memberOrID)
    return self:SetCompositeMemberFamilyOffset(
        elementOrID, memberOrID, 0, 0)
end

function NSkin:GetCompositeMemberOffset(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return nil end
    local state = GetCompositionMemberState(element, member, false)
    return state and tonumber(state.x) or 0,
        state and tonumber(state.y) or 0
end

function NSkin:ApplyCompositeMemberOffset(elementOrID, memberOrID, x, y)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return false end
    local familyX, familyY =
        self:GetCompositeMemberFamilyOffset(element, member)
    local overrideX = HasCompositePositionOverrideForAppearance(
        element, member.id, "alongOffset", nil)
    local overrideY = HasCompositePositionOverrideForAppearance(
        element, member.id, "edgeOffset", nil)
    local resolvedX = overrideX
        and (tonumber(x) or 0)
        or (tonumber(familyX) or 0) + (tonumber(x) or 0)
    local resolvedY = overrideY
        and (tonumber(y) or 0)
        or (tonumber(familyY) or 0) + (tonumber(y) or 0)
    return ApplyCompositeMemberGeometry(
        element, member, resolvedX, resolvedY)
end

function NSkin:SetCompositeMemberOffset(elementOrID, memberOrID, x, y)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return false end

    x, y = tonumber(x) or 0, tonumber(y) or 0
    local state = GetCompositionMemberState(element, member, true)
    state.x, state.y = x, y
    if x == 0 then state.x = nil end
    if y == 0 then state.y = nil end

    -- Surface buttons are often chained to one another by Blizzard. Freeze the
    -- whole surface family in place before applying one exact delta so moving
    -- one card does not drag its siblings.
    if member.editorSurface == true then
        RefreshCompositeSurfaceAnchorMode(element)
    end

    if not self:ApplyCompositeMemberOffset(element, member, x, y) then
        return false
    end

    PruneCompositionMemberState(element, member)
    if member.editorSurface == true then
        RefreshCompositeSurfaceAnchorMode(element)
    end
    self:NotifySkinningElementBoundsChanged(element.id)
    return true
end

function NSkin:ResetCompositeMemberOffset(elementOrID, memberOrID)
    return self:SetCompositeMemberOffset(elementOrID, memberOrID, 0, 0)
end

function NSkin:IsCompositeMemberAttached(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    return member and member.attached ~= false or false
end

function NSkin:SetCompositeMemberAttached(elementOrID, memberOrID, attached)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not member then return false end

    attached = attached ~= false
    if member.attached == attached then return true end
    if not attached then
        local target = GetCompositeMemberMovementTarget(element, member)
        if not target or not CaptureDetachedMemberAnchor(
            element, member, target)
        then return false end
    end
    member.attached = attached
    if not ApplyCompositeMemberGeometry(
        element, member,
        tonumber(member.localX) or 0,
        tonumber(member.localY) or 0)
    then
        member.attached = not attached
        return false
    end

    local state = GetCompositionMemberState(element, member, true)
    state.attached = attached and nil or false
    PruneCompositionMemberState(element, member)
    self:NotifySkinningElementBoundsChanged(element.id)
    return true
end

function NSkin:IsCompositeMemberSpecificOverrideEnabled(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return false end
    local state = GetCompositionMemberState(element, member, false)
    return state and state.overrideSpecific == true or false
end

function NSkin:SetCompositeMemberSpecificOverride(
    elementOrID, memberOrID, enabled)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return false end

    enabled = enabled == true
    local current = self:IsCompositeMemberSpecificOverrideEnabled(
        element, member)
    if current == enabled then return true end

    local state = GetCompositionMemberState(element, member, true)
    state.overrideSpecific = enabled and true or nil
    if not enabled then
        -- Turning the opt-in off means "return to Composite shared styling".
        -- Remove the exact-member sparse layer instead of leaving an invisible
        -- override behind that would still win during appearance resolution.
        self:ResetElementAppearanceOverride(
            member.appearanceID or member.id)
    end
    PruneCompositionMemberState(element, member)

    if type(element.refreshAppearance) == "function" then
        element.refreshAppearance(self, element)
    end
    if type(element.refreshLayout) == "function" then
        element.refreshLayout(self, element)
    end
    if type(self.RefreshSkinningCompositeMemberEditor) == "function" then
        self:RefreshSkinningCompositeMemberEditor(element, member.id)
    end
    return true
end

function NSkin:GetCompositeMemberEditorContext(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return nil end
    if member.movable == false then return nil end

    -- Every movable member kind, including Surface, edits its shared family
    -- position. Runtime pooled families opt out explicitly.
    -- Exact-member X/Y remains available only through sparse overrides.
    local context = member._editorContext or {}
    member._editorContext = context
    context.id = element.id .. ":Family:" .. tostring(
        member.movementFamilyID or member.kind)
    context.label = member.label or member.id
    context.kind = member.kind
    context.module = element.module
    context.window = element.window
    context.target = GetCompositeMemberMovementTarget(element, member)
    context.appearanceWindowID =
        member.appearanceWindowID or element.appearanceWindowID
    context.compositeOwner = element
    context.compositeMember = member
    context.getPlacement = function()
        local localX, localY =
            NSkin:GetCompositeMemberFamilyOffset(element, member)
        return {
            mode = "OFFSET",
            alongOffset = localX or 0,
            edgeOffset = localY or 0,
        }
    end
    context.setPlacement = function(_, placement)
        return NSkin:SetCompositeMemberFamilyOffset(
            element, member,
            tonumber(placement and
                (placement.alongOffset or placement.x)) or 0,
            tonumber(placement and
                (placement.edgeOffset or placement.y)) or 0)
    end
    context.resetPlacement = function()
        return NSkin:ResetCompositeMemberFamilyOffset(element, member)
    end
    return context
end

local function GetCompositeMemberStateDefinition(member, stateID)
    if not member or type(stateID) ~= "string" then return nil end
    for _, definition in ipairs(member.states or {}) do
        if definition.id == stateID then return definition end
    end
end

function NSkin:GetCompositeMemberRuntimeState(
    elementOrID, memberOrID, target)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member or not target then return nil end
    if type(member.getStateID) == "function" then
        local ok, stateID = pcall(
            member.getStateID, element, member, target)
        if ok and GetCompositeMemberStateDefinition(member, stateID) then
            return stateID
        end
    end
end

function NSkin:GetCompositeMemberEditorState(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member or #(member.states or {}) == 0 then
        return nil, nil
    end
    if member._editorStateID == nil then
        return nil, nil
    end
    local stateID = member._editorStateID
    local definition = GetCompositeMemberStateDefinition(member, stateID)
    if not definition then
        member._editorStateID = nil
        return nil, nil
    end
    return stateID, definition
end

function NSkin:ClearCompositeMemberEditorPreview(
    elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return false end

    local cleared
    local function Clear(candidateElement, candidateMember)
        local target = candidateMember._editorPreviewTarget
        if target and type(candidateMember.clearPreviewState) == "function" then
            local ok, result = pcall(
                candidateMember.clearPreviewState,
                candidateElement, candidateMember, target)
            cleared = (ok and result ~= false) or cleared
        end
        candidateMember._editorPreviewTarget = nil
        candidateMember._editorPreviewStateID = nil
    end

    Clear(element, member)
    for _, entry in ipairs(
        self:GetContainerCompositeMemberFamily(element, member) or {})
    do
        if entry.member ~= member then
            Clear(entry.element, entry.member)
        end
    end
    return cleared == true
end

function NSkin:SetCompositeMemberEditorState(
    elementOrID, memberOrID, stateID, target, preview)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    local allStates = stateID == nil or stateID == "__ALL"
    local definition = not allStates and member
        and GetCompositeMemberStateDefinition(member, stateID) or nil
    if not element or not member
        or (not allStates and not definition)
    then return false end

    self:ClearCompositeMemberEditorPreview(element, member)

    local nextStateID = allStates and nil or stateID
    local stateChanged = member._editorStateID ~= nextStateID
    local targetChanged = target ~= nil
        and member._editorStateTarget ~= target
    member._editorStateID = nextStateID
    if target ~= nil or allStates then
        member._editorStateTarget = target
    end

    for _, entry in ipairs(
        self:GetContainerCompositeMemberFamily(element, member) or {})
    do
        local familyMember = entry.member
        if familyMember ~= member then
            if allStates
                or GetCompositeMemberStateDefinition(
                    familyMember, nextStateID)
            then
                familyMember._editorStateID = nextStateID
                familyMember._editorStateTarget = nil
            end
        end
    end

    local previewed
    if not allStates
        and preview == true and member.previewRuntimeState ~= false
        and type(member.previewState) == "function"
        and member._editorStateTarget
    then
        local ok, result = pcall(member.previewState, element, member,
            member._editorStateTarget, stateID)
        previewed = ok and result ~= false
        if previewed then
            member._editorPreviewTarget = member._editorStateTarget
            member._editorPreviewStateID = stateID
        end
    end

    return stateChanged or targetChanged or previewed == true
end

function NSkin:GetCompositeMemberAppearanceContext(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return nil end

    local context = member._appearanceEditorContext or {}
    member._appearanceEditorContext = context
    local specific = self:IsCompositeMemberSpecificOverrideEnabled(
        element, member)
    local baseAppearanceID = specific
        and (member.appearanceID or member.id)
        or (member.appearanceParentID or element.id)
    local stateID, stateDefinition =
        self:GetCompositeMemberEditorState(element, member)
    if stateDefinition then
        context.id = specific
            and (stateDefinition.appearanceID
                or (baseAppearanceID .. ".State." .. stateID))
            or (baseAppearanceID .. ".State." .. stateID)
    else
        context.id = baseAppearanceID
    end
    context.label = member.label or member.id
    context.kind = member.kind
    context.module = element.module
    context.window = element.window
    context.target = member._editorStateTarget
        or GetCompositeMemberMovementTarget(element, member)
    context.componentStateID = stateID
    context.componentState = stateDefinition
    context.appearanceWindowID =
        member.appearanceWindowID or element.appearanceWindowID
    context.compositeOwner = element
    context.compositeMember = member
    context.surfaceStyle = member.surfaceStyle
    context.surfaceAppearanceKey = member.surfaceAppearanceKey
    context.compositeTag = self:GetCompositeTag(element)
    context.specificElementOverride = specific
    return context
end

local function EditorDefinitionsContainID(definitions, wantedID)
    for _, definition in ipairs(definitions or {}) do
        local id = type(definition) == "table"
            and definition.id or definition
        if id == wantedID then return true end
        if type(definition) == "table" then
            if EditorDefinitionsContainID(definition.tabs, wantedID)
                or EditorDefinitionsContainID(definition.groups, wantedID)
            then
                return true
            end
        end
    end
    return false
end

local function CopyMemberEditorDefinition(
    definition, placementContext, appearanceContext)
    if type(definition) ~= "table" then return definition end

    local copy = {}
    for key, value in pairs(definition) do
        if (key == "tabs" or key == "groups")
            and type(value) == "table"
        then
            local children = {}
            for index, child in ipairs(value) do
                children[index] = CopyMemberEditorDefinition(
                    child, placementContext, appearanceContext)
            end
            copy[key] = children
        else
            copy[key] = value
        end
    end

    if copy.contextRole == "PLACEMENT" then
        copy.context = placementContext
    elseif copy.contextRole == "APPEARANCE" then
        copy.context = appearanceContext
    end
    copy.contextRole = nil
    return copy
end

function NSkin:GetCompositeMemberEditorOptions(elementOrID, memberOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return nil, nil end

    local component = member.kind
        and self:GetSharedElementType(member.kind)
    if not component then return nil, nil end

    local placementContext =
        self:GetCompositeMemberEditorContext(element, member)
    local appearanceContext =
        self:GetCompositeMemberAppearanceContext(element, member)
    local definitions = member.editorOptions
        or self:CreateEditorOptionsPreset(component.editorPreset)
        or {}
    local options = {}

    local navigationOwnsPlacement =
        EditorDefinitionsContainID(definitions, "shared.movable")
    if not navigationOwnsPlacement and placementContext
        and type(placementContext.getPlacement) == "function"
        and type(placementContext.setPlacement) == "function"
        and type(placementContext.resetPlacement) == "function"
    then
        options[#options + 1] = {
            id = "shared.movable",
            label = "Position",
            presentation = "INLINE",
            category = "POSITION",
            context = placementContext,
            contextualInline = true,
        }
    end

    local labels = element.editorOptionLabels
        or (element.composition and element.composition.editorOptionLabels)
    for _, definition in ipairs(definitions) do
        local id = type(definition) == "table"
            and definition.id or definition
        local category = type(definition) == "table"
            and definition.category
        local navigation = type(definition) == "table"
            and definition.presentation == "NAV_TABS"
        if type(id) == "string"
            and (navigation
                or (id ~= "shared.movable"
                    and category ~= "POSITION"
                    and category ~= "LAYOUT"))
        then
            local copy = type(definition) == "table"
                and CopyMemberEditorDefinition(
                    definition, placementContext, appearanceContext)
                or { id = id }
            copy.id = id
            if copy.context == nil then
                copy.context = appearanceContext or element
            end
            if not navigation then
                if copy.contextualInline == nil then
                    copy.contextualInline = true
                end
                if copy.contextualInline then
                    copy.presentation = "INLINE"
                end
            end
            if labels and labels[id] then copy.label = labels[id] end
            options[#options + 1] = copy
        end
    end
    return options, placementContext
end

function NSkin:ResetCompositeMemberCustomizations(elementOrID, memberOrID)
    local element = type(elementOrID) == "table"
        and elementOrID or self:GetSkinningElement(elementOrID)
    local member = element and (type(memberOrID) == "table" and memberOrID
        or self:GetCompositeMember(element, memberOrID))
    if not element or not member then return false end

    local placementContext =
        self:GetCompositeMemberEditorContext(element, member)
    local specific = self:IsCompositeMemberSpecificOverrideEnabled(
        element, member)

    local function ResetDefinitions(definitions, inheritedContext)
        local changed
        for _, definition in ipairs(definitions or {}) do
            if type(definition) == "table"
                and definition.presentation == "NAV_TABS"
                and type(definition.tabs) == "table"
            then
                local navigationContext =
                    definition.context or inheritedContext
                for _, tab in ipairs(definition.tabs) do
                    local tabContext = type(tab) == "table"
                        and (tab.context or navigationContext)
                        or navigationContext
                    if type(tab) == "table" then
                        changed = ResetDefinitions(
                            tab.groups, tabContext) or changed
                        changed = ResetDefinitions(
                            tab.tabs, tabContext) or changed
                    end
                end
            else
                local id = type(definition) == "table"
                    and definition.id or definition
                local category = type(definition) == "table"
                    and definition.category
                local context = type(definition) == "table"
                    and (definition.context or inheritedContext)
                    or inheritedContext
                if type(id) == "string"
                    and id ~= "shared.movable"
                    and category ~= "POSITION"
                    and category ~= "LAYOUT"
                    and context
                then
                    changed = self:ResetOptionGroup(
                        id, context) or changed
                end
            end
        end
        return changed == true
    end

    local editorOptions =
        self:GetCompositeMemberEditorOptions(element, member)
    ResetDefinitions(editorOptions, element)

    if specific then
        self:SetCompositeMemberSpecificOverride(element, member, false)
    end
    self:SetCompositeMemberAttached(element, member, true)
    self:ResetCompositeMemberOffset(element, member)

    if type(element.refreshAppearance) == "function" then
        element.refreshAppearance(self, element)
    end
    if type(element.refreshLayout) == "function" then
        element.refreshLayout(self, element)
    end
    return placementContext ~= nil
end

function NSkin:GetCompositionHighlightRegions(element)
    local composition = element.composition
    if not composition or composition.mode ~= "COMPOSITE" then
        return element.highlightRegions
    end

    -- Row-family composites expose a presentation Surface that may be narrower
    -- than Blizzard's pooled row frame. The Composite highlight/hit regions
    -- must follow that Surface, otherwise the native row width leaves a stale
    -- clickable strip that can select/drag the semantic parent.
    if element.rowFamily then
        for _, member in ipairs(composition.members or {}) do
            if member.rowFamilySurface == true
                and member.attached ~= false
                and type(member.highlightTargets) == "function"
            then
                local ok, resolved = pcall(
                    member.highlightTargets, element, member)
                if ok and type(resolved) == "table" and #resolved > 0 then
                    return resolved
                end
            end
        end
    end

    -- An adapter may provide explicit Composite surfaces which are larger than
    -- the atomic members. These surfaces own the regular Composite highlight
    -- and the empty-space click target; member targets remain separate.
    local provided = element.highlightRegions
    if type(provided) == "function" then provided = provided(element) end
    if type(provided) == "table" and #provided > 0 then
        return provided
    end

    local regions = {}
    for _, member in ipairs(composition.members or {}) do
        if member.attached ~= false then
            for _, target in ipairs(
                ResolveMemberTargets(member, element, true))
            do
                regions[#regions + 1] = target
            end
        end
    end
    return regions
end

-- Resolve presentation from canonical presets, without owning any controls.
function NSkin:GetCompositionEditorOptions(element)
    if not element then return nil end
    local options, seen = {}, {}

    local function Append(definitions, optionContext)
        if type(definitions) == "string" then definitions = { definitions } end
        for _, definition in ipairs(definitions or {}) do
            local option = type(definition) == "table" and definition
                or { id = definition }
            local context = optionContext or element
            local lacksPlacementContract = option.id == "shared.movable"
                and (type(context.getPlacement) ~= "function"
                    or type(context.setPlacement) ~= "function"
                    or type(context.resetPlacement) ~= "function")
            if not seen[option.id] and not lacksPlacementContract then
                local copy = {}
                for key, value in pairs(option) do copy[key] = value end
                local labels = element.editorOptionLabels
                    or (element.composition
                        and element.composition.editorOptionLabels)
                if labels and labels[copy.id] then
                    copy.label = labels[copy.id]
                end
                if optionContext then copy.context = optionContext end
                options[#options + 1] = copy
                seen[option.id] = true
            end
        end
    end

    if element.isAnchorGroup then
        for _, member in ipairs(
            self:GetAnchorGroupComponentMembers(element) or {})
        do
            local component = self:GetSharedElementType(member.kind)
            if component then
                local optionContext = member.elementCount >= 2
                    and element or member.ownerElement
                Append(self:CreateEditorOptionsPreset(
                    component.editorPreset), optionContext)
            end
        end
        return options
    end

    local composition = element.composition
    if composition and composition.mode == "CONTAINER"
        and composition.surface
    then
        local surfaceContext =
            self:GetContainerSurfaceAppearanceContext(element)
        Append(self:GetCompositeSurfaceEditorOptions(
            composition.surface.includeGeometry), surfaceContext)
    end

    Append(element.editorOptions)
    return options
end

local function CanModifyCompositionRoot(target)
    return target and not (target.IsForbidden and target:IsForbidden())
        and not (target.IsProtected and target:IsProtected() and InCombatLockdown())
end

local function CaptureOffsetRootPoints(target)
    local points = {}
    for i = 1, target:GetNumPoints() do points[i] = { target:GetPoint(i) } end
    return points
end

local function OffsetRootDependsOnSibling(state, points)
    local roots = state and state.activeRoots
    if not roots then return false end
    for _, point in ipairs(points or {}) do
        local relativeTo = point[2]
        if relativeTo and roots[relativeTo] then return true end
    end
    return false
end

local function ApplyOffsetRoot(state, target, points)
    if not CanModifyCompositionRoot(target) or InCombatLockdown() then return end
    local scale = state.frame:GetEffectiveScale() / target:GetEffectiveScale()
    local applyGroupOffset = not OffsetRootDependsOnSibling(state, points)
    local offsetX = applyGroupOffset and state.x * scale or 0
    local offsetY = applyGroupOffset and state.y * scale or 0
    target:ClearAllPoints()
    for _, point in ipairs(points) do
        target:SetPoint(point[1], point[2], point[3],
            (point[4] or 0) + offsetX,
            (point[5] or 0) + offsetY)
    end
end

-- Use only after an adapter's audited Blizzard positioning method has completed.
-- This is a fresh native layout, not a snapshot of an NSkin offset.
function NSkin:ObserveOffsetContainerLayout(id, target)
    local element = self:GetSkinningElement(id)
    local state = element and element.offsetContainer
    if not state or not CanModifyCompositionRoot(target) or InCombatLockdown() then return end
    state.roots[target] = CaptureOffsetRootPoints(target)
    self:RefreshOffsetContainer(element)
end

-- Call before a provider releases a root, or after native layout transfers it
-- to a different owner. Never restore stale anchors onto a recycled frame.
function NSkin:ReleaseOffsetContainerRoot(id, target, restore)
    local element = self:GetSkinningElement(id)
    local state = element and element.offsetContainer
    local points = state and state.roots[target]
    if not points then return end
    if restore then
        local x, y = state.x, state.y
        state.x, state.y = 0, 0
        ApplyOffsetRoot(state, target, points)
        state.x, state.y = x, y
    end
    state.roots[target] = nil
end

local function GetOffsetContainerLayoutStore(element, create)
    if not element or type(element.module) ~= "string" then return nil end
    local options = NSkin:GetModuleOptions(element.module, create == true)
    if not options then return nil end
    local layouts = options.containerLayouts
    if not layouts and create then
        layouts = {}
        options.containerLayouts = layouts
    end
    return layouts, options
end

local function GetOffsetContainerSavedLayout(element)
    local layouts = GetOffsetContainerLayoutStore(element, false)
    return layouts and layouts[element.id] or nil
end

local function RoundContainerSpacing(value)
    value = tonumber(value) or 0
    if value >= 0 then return math.floor(value + 0.5) end
    return math.ceil(value - 0.5)
end

local function GetOffsetContainerRootGap(roots, direction)
    if #roots < 2 then return 0 end
    local first, second = roots[1], roots[2]
    local l1, r1, b1, t1 = NSkin:GetUIParentNormalizedBounds(first)
    local l2, r2, b2, t2 = NSkin:GetUIParentNormalizedBounds(second)
    if not l1 or not l2 then return 0 end
    local gap = direction == "HORIZONTAL"
        and (l2 - r1) or (b1 - t2)
    local scale = UIParent:GetEffectiveScale()
        / math.max(0.01, first:GetEffectiveScale())
    return RoundContainerSpacing(gap * scale)
end

local function ApplyOffsetContainerLayout(roots, direction, spacing)
    if #roots < 2 then return end
    local previous = roots[1]
    for index = 2, #roots do
        local target = roots[index]
        if CanModifyCompositionRoot(target) then
            target:ClearAllPoints()
            if direction == "HORIZONTAL" then
                target:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
            else
                target:SetPoint("TOP", previous, "BOTTOM", 0, -spacing)
            end
            previous = target
        end
    end
end

function NSkin:GetContainerLayout(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local state = element and element.offsetContainer
    if not state then return nil end
    local saved = GetOffsetContainerSavedLayout(element)
    return {
        direction = saved and saved.direction or state.defaultDirection,
        spacing = saved and tonumber(saved.spacing)
            or tonumber(state.defaultSpacing) or 0,
    }
end

function NSkin:SetContainerLayout(elementOrID, values)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local state = element and element.offsetContainer
    if not state or type(values) ~= "table" then return false end
    local current = self:GetContainerLayout(element) or {}
    local direction = string.upper(tostring(
        values.direction or current.direction or state.defaultDirection))
    if direction ~= "HORIZONTAL" and direction ~= "VERTICAL" then
        return false
    end
    local spacing = tonumber(values.spacing)
    if spacing == nil then spacing = tonumber(current.spacing) or 0 end
    spacing = math.max(-100, math.min(200, spacing))

    local defaultSpacing = tonumber(state.defaultSpacing) or 0
    local isDefault = direction == state.defaultDirection
        and math.abs(spacing - defaultSpacing) < 0.001
    local layouts, options = GetOffsetContainerLayoutStore(element, true)
    local previous = layouts[element.id]
    if isDefault then
        layouts[element.id] = nil
    else
        layouts[element.id] = { direction = direction, spacing = spacing }
    end
    if not next(layouts) then options.containerLayouts = nil end

    local changed = (previous == nil) ~= isDefault
        or (previous and (previous.direction ~= direction
            or tonumber(previous.spacing) ~= spacing))
    if changed then self:RefreshOffsetContainer(element) end
    return changed == true
end

function NSkin:ResetContainerLayout(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    if not element then return false end
    local layouts, options = GetOffsetContainerLayoutStore(element, false)
    if not layouts or not layouts[element.id] then return false end
    layouts[element.id] = nil
    if not next(layouts) then options.containerLayouts = nil end
    self:RefreshOffsetContainer(element)
    return true
end

function NSkin:RefreshOffsetContainer(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local state = element and element.offsetContainer
    if not state or InCombatLockdown() then return false end

    local current, roots = {}, {}
    for _, target in ipairs(element.composition.roots() or {}) do
        if CanModifyCompositionRoot(target) and target.GetNumPoints then
            current[target] = true
            roots[#roots + 1] = target
            if not state.roots[target] then
                state.roots[target] = CaptureOffsetRootPoints(target)
            end
        end
    end
    state.activeRoots = current
    for _, target in ipairs(roots) do
        ApplyOffsetRoot(state, target, state.roots[target])
    end
    for target, points in pairs(state.roots) do
        if not current[target] then
            local x, y = state.x, state.y
            state.x, state.y = 0, 0
            ApplyOffsetRoot(state, target, points)
            state.x, state.y = x, y
            state.roots[target] = nil
        end
    end
    if #roots == 0 then return false end

    if state.defaultSpacing == nil then
        state.defaultSpacing = GetOffsetContainerRootGap(
            roots, state.defaultDirection)
    end
    local savedLayout = GetOffsetContainerSavedLayout(element)
    if savedLayout then
        ApplyOffsetContainerLayout(
            roots,
            savedLayout.direction or state.defaultDirection,
            tonumber(savedLayout.spacing) or state.defaultSpacing or 0)
    end

    local left, right, bottom, top
    for _, target in ipairs(roots) do
        if not target.IsVisible or target:IsVisible() then
            local l, r, b, t = self:GetUIParentNormalizedBounds(target)
            if l then
                left, right = math.min(left or l, l), math.max(right or r, r)
                bottom, top = math.min(bottom or b, b), math.max(top or t, t)
            end
        end
    end
    if not left then return false end

    local scale = UIParent:GetEffectiveScale() / state.frame:GetEffectiveScale()
    local windowLeft, _, _, windowTop =
        self:GetUIParentNormalizedBounds(element.window)
    if not windowLeft then return false end
    state.baseX = (left - windowLeft) * scale - state.x
    state.baseY = (top - windowTop) * scale - state.y
    state.frame:SetSize((right - left) * scale, (top - bottom) * scale)
    state.frame:ClearAllPoints()
    state.frame:SetPoint("TOPLEFT", element.window, "TOPLEFT",
        state.baseX + state.x, state.baseY + state.y)
    self:NotifySkinningElementBoundsChanged(element.id)
    return true
end

-- A virtual movement owner for semantic roots which share a Blizzard parent.
-- Roots retain parents and native relative anchors; edges anchored to roots follow.
function NSkin:RegisterOffsetContainer(definition)
    if type(definition) ~= "table" or not definition.composition
        or definition.composition.mode ~= "CONTAINER"
        or definition.composition.movementStrategy ~= "OFFSET_ROOTS"
        or type(definition.composition.roots) ~= "function"
    then return nil end
    local existing = self:GetSkinningElement(definition.id)
    if existing then self:RefreshOffsetContainer(existing); return existing end
    local frame = CreateFrame("Frame", nil, definition.layoutParent or definition.window)
    frame:EnableMouse(false)
    frame:SetSize(1, 1)
    frame:SetPoint("TOPLEFT", definition.window, "TOPLEFT")
    local defaultDirection = string.upper(tostring(
        definition.composition.defaultDirection or "VERTICAL"))
    if defaultDirection ~= "HORIZONTAL" and defaultDirection ~= "VERTICAL" then
        defaultDirection = "VERTICAL"
    end
    local state = {
        frame = frame,
        roots = setmetatable({}, { __mode = "k" }),
        x = 0, y = 0, baseX = 0, baseY = 0,
        defaultDirection = defaultDirection,
        defaultSpacing = nil,
    }
    definition.target, definition.kind = frame, "MOVABLE"
    definition.offsetContainer = state
    definition.composition.movementOwner = frame

    local moduleOptions = self:GetModuleOptions(definition.module, true)
    moduleOptions.movablePlacements = moduleOptions.movablePlacements or {}
    local oldPlacement = moduleOptions.movablePlacements[definition.id]
    if oldPlacement and oldPlacement.mode ~= "OFFSET_ROOTS" then
        moduleOptions.movablePlacements[definition.id] = nil
    end
    if not next(moduleOptions.movablePlacements) then
        moduleOptions.movablePlacements = nil
    end

    definition.getPlacement = function()
        return {
            mode = "OFFSET",
            alongOffset = state.x,
            edgeOffset = state.y,
        }
    end
    definition.applyPlacement = function(element, placement, options)
        if InCombatLockdown() then return false end
        state.x = tonumber(placement and
            (placement.alongOffset or placement.x)) or 0
        state.y = tonumber(placement and
            (placement.edgeOffset or placement.y)) or 0
        if not NSkin:RefreshOffsetContainer(element) then return false end
        if element.onLayoutChanged then element.onLayoutChanged(element) end
        if not (options and options.suppressNotify) then
            NSkin:NotifySkinningElementBoundsChanged(element.id)
        end
        return true
    end
    definition.setPlacement = function(element, placement)
        if not element.applyPlacement(element, placement) then return false end
        local options = NSkin:GetModuleOptions(element.module, true)
        options.movablePlacements = options.movablePlacements or {}
        options.movablePlacements[element.id] = {
            mode = "OFFSET_ROOTS",
            alongOffset = state.x,
            edgeOffset = state.y,
        }
        return true
    end
    definition.resetPlacement = function(element)
        if InCombatLockdown() then return false end
        state.x, state.y = 0, 0
        for target, points in pairs(state.roots) do ApplyOffsetRoot(state, target, points) end
        local options = NSkin:GetModuleOptions(element.module, false)
        if options and options.movablePlacements then options.movablePlacements[element.id] = nil end
        local result = NSkin:RefreshOffsetContainer(element)
        if element.onLayoutChanged then element.onLayoutChanged(element) end
        return result
    end
    -- Resolve the base bounds before RegisterMovableElement reapplies saved placement.
    self:RefreshOffsetContainer(definition)
    return self:RegisterSimpleMovableElement(definition)
end
