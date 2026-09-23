local _, NSkin = ...

-- Anchor Groups are editor-only relationships. They neither replace the
-- canonical elements below them nor acquire movement, lifecycle, or reset
-- ownership from those elements.
local anchorGroups = {}
local anchorGroupByElementID = {}

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

-- Structure lives on the existing editor elements, never in a second registry.
-- A member shares its Composite's appearance ID; Container children retain theirs.
function NSkin:InitializeElementComposition(element)
    element.composition = element.composition or { mode = "STANDALONE" }
    if element.compositionParentID then
        element.draggable, element.movable = false, false
    end
    if element.composition.mode ~= "COMPOSITE" then return end
    element.compositionHookedTargets = element.compositionHookedTargets
        or setmetatable({}, { __mode = "k" })
    for _, member in ipairs(element.composition.members) do
        local target = member.target
        if target and not element.compositionHookedTargets[target] then
            element.compositionHookedTargets[target] = true
            local function RefreshBounds()
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
            for _, method in ipairs({ "Show", "Hide", "SetShown", "SetText", "SetFont",
                "SetFormattedText",
                "SetPoint", "SetSize", "SetWidth", "SetHeight", "SetScale" })
            do
                if type(target[method]) == "function" then
                    hooksecurefunc(target, method, RefreshBounds)
                end
            end
        end
    end
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

function NSkin:GetCompositionHighlightRegions(element)
    local composition = element.composition
    if not composition or composition.mode ~= "COMPOSITE" then
        return element.highlightRegions
    end
    local regions = {}
    local provided = element.highlightRegions
    if type(provided) == "function" then provided = provided(element) end
    for i = 1, #(provided or {}) do regions[#regions + 1] = provided[i] end
    for _, member in ipairs(composition.members) do
        for _, target in ipairs(ResolveMemberTargets(member, element, true)) do
            regions[#regions + 1] = target
        end
    end
    return regions
end

-- Resolve presentation from canonical presets, without owning any controls.
function NSkin:GetCompositionEditorOptions(element)
    if not element then return nil end
    local options, seen = {}, {}
    local function Append(definitions, member, optionContext)
        if type(definitions) == "string" then definitions = { definitions } end
        for _, definition in ipairs(definitions or {}) do
            local option = type(definition) == "table" and definition
                or { id = definition }
            local context = optionContext or element
            local lacksPlacementContract = option.id == "shared.movable"
                and (type(context.getPlacement) ~= "function"
                    or type(context.setPlacement) ~= "function"
                    or type(context.resetPlacement) ~= "function")
            if not seen[option.id]
                and not lacksPlacementContract
                and not ((member or element.isAnchorGroup)
                    and (option.category == "POSITION" or option.id == "shared.movable"))
            then
                local copy = {}
                for key, value in pairs(option) do copy[key] = value end
                if member then
                    copy.presentation = "TAB"
                    copy.label = member.label or copy.label
                end
                if optionContext then copy.context = optionContext end
                options[#options + 1], seen[option.id] = copy, true
            end
        end
    end
    if element.isAnchorGroup then
        for _, member in ipairs(self:GetAnchorGroupComponentMembers(element) or {}) do
            local component = self:GetSharedElementType(member.kind)
            if component then
                local optionContext = member.elementCount >= 2
                    and element or member.ownerElement
                if member.role == "PRIMARY" then
                    Append(self:CreateEditorOptionsPreset(component.editorPreset),
                        nil, optionContext)
                else
                    Append(self:CreateEditorOptionsPreset(component.editorPreset),
                        member, optionContext)
                end
            end
        end
        return options
    end
    local composition = element.composition
    if composition and composition.mode == "COMPOSITE" then
        for _, member in ipairs(composition.members) do
            if member.role == "PRIMARY" then
                local component = self:GetSharedElementType(member.kind)
                if component then Append(self:CreateEditorOptionsPreset(component.editorPreset)) end
            end
        end
    end
    Append(element.editorOptions)
    if composition and composition.mode == "COMPOSITE" then
        for _, member in ipairs(composition.members) do
            if member.role == "SECONDARY" then
                local component = self:GetSharedElementType(member.kind)
                if component then
                    Append(self:CreateEditorOptionsPreset(component.editorPreset), member)
                end
            end
        end
    end
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

local function ApplyOffsetRoot(state, target, points)
    if not CanModifyCompositionRoot(target) or InCombatLockdown() then return end
    local scale = state.frame:GetEffectiveScale() / target:GetEffectiveScale()
    target:ClearAllPoints()
    for _, point in ipairs(points) do
        target:SetPoint(point[1], point[2], point[3],
            (point[4] or 0) + state.x * scale,
            (point[5] or 0) + state.y * scale)
    end
end

-- Use only after an adapter's audited Blizzard positioning method has completed.
-- This is a fresh native layout, not a snapshot of an NSkin offset.
function NSkin:ObserveOffsetContainerLayout(id, target)
    local element = self:GetSkinningElement(id)
    local state = element and element.offsetContainer
    if not state or not CanModifyCompositionRoot(target) or InCombatLockdown() then return end
    local points = CaptureOffsetRootPoints(target)
    state.roots[target] = points
    ApplyOffsetRoot(state, target, points)
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

function NSkin:RefreshOffsetContainer(elementOrID)
    local element = type(elementOrID) == "table" and elementOrID
        or self:GetSkinningElement(elementOrID)
    local state = element and element.offsetContainer
    if not state or InCombatLockdown() then return false end
    local current, left, right, bottom, top = {}, nil, nil, nil, nil
    for _, target in ipairs(element.composition.roots() or {}) do
        if CanModifyCompositionRoot(target) and target.GetNumPoints then
            current[target] = true
            local points = state.roots[target]
            if not points then
                points = CaptureOffsetRootPoints(target)
                state.roots[target] = points
                ApplyOffsetRoot(state, target, points)
            end
            if not target.IsVisible or target:IsVisible() then
                local l, r, b, t = self:GetUIParentNormalizedBounds(target)
                if l then
                    left, right = math.min(left or l, l), math.max(right or r, r)
                    bottom, top = math.min(bottom or b, b), math.max(top or t, t)
                end
            end
        end
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
    if not left then return false end
    local scale = UIParent:GetEffectiveScale() / state.frame:GetEffectiveScale()
    local windowLeft, _, _, windowTop = self:GetUIParentNormalizedBounds(element.window)
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
    local state = { frame = frame, roots = setmetatable({}, { __mode = "k" }),
        x = 0, y = 0, baseX = 0, baseY = 0 }
    definition.target, definition.kind = frame, "MOVABLE"
    definition.offsetContainer = state
    definition.composition.movementOwner = frame
    definition.applyPlacement = function(element, placement, options)
        if InCombatLockdown() then return false end
        if not NSkin:LayoutWindowElement(element, placement, { suppressNotify = true }) then return false end
        local left, _, _, top = NSkin:GetUIParentNormalizedBounds(frame)
        local windowLeft, _, _, windowTop = NSkin:GetUIParentNormalizedBounds(element.window)
        if not left or not windowLeft then return false end
        local scale = UIParent:GetEffectiveScale() / frame:GetEffectiveScale()
        state.x = (left - windowLeft) * scale - state.baseX
        state.y = (top - windowTop) * scale - state.baseY
        for target, points in pairs(state.roots) do ApplyOffsetRoot(state, target, points) end
        if element.onLayoutChanged then element.onLayoutChanged(element) end
        if not (options and options.suppressNotify) then
            NSkin:NotifySkinningElementBoundsChanged(element.id)
        end
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
