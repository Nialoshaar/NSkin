local _, NSkin = ...

-- Structure lives on the existing editor elements, never in a second registry.
-- A member shares its Composite's appearance ID; Container children retain theirs.
function NSkin:InitializeElementComposition(element)
    element.composition = element.composition or { mode = "STANDALONE" }
    if element.compositionParentID then
        element.draggable, element.movable = false, false
        element.applyPlacement, element.setPlacement, element.resetPlacement = nil, nil, nil
    end
    if element.composition.mode ~= "COMPOSITE" then return end
    element.compositionHookedTargets = element.compositionHookedTargets
        or setmetatable({}, { __mode = "k" })
    for _, member in ipairs(element.composition.members) do
        local target = member.target
        if target and not element.compositionHookedTargets[target] then
            element.compositionHookedTargets[target] = true
            local function RefreshBounds()
                NSkin:NotifySkinningElementBoundsChanged(element.id)
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
        local target = member.target
        if target and (not target.IsVisible or target:IsVisible())
            and (not target.IsShown or target:IsShown())
        then regions[#regions + 1] = target end
    end
    return regions
end

-- Resolve presentation from canonical presets, without owning any controls.
function NSkin:GetCompositionEditorOptions(element)
    if not element then return nil end
    local options, seen = {}, {}
    local function Append(definitions, member)
        if type(definitions) == "string" then definitions = { definitions } end
        for _, definition in ipairs(definitions or {}) do
            local option = type(definition) == "table" and definition
                or { id = definition }
            if not seen[option.id]
                and not ((element.compositionParentID or member)
                    and (option.category == "POSITION" or option.id == "shared.movable"))
            then
                local copy = {}
                for key, value in pairs(option) do copy[key] = value end
                if member then
                    copy.presentation = "TAB"
                    copy.label = member.label or copy.label
                end
                options[#options + 1], seen[option.id] = copy, true
            end
        end
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
