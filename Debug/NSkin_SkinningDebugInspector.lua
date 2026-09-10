local _, NSkin = ...

local YELLOW = { 1, 0.82, 0, 1 }
local MUTED = "|cff999999"
local WHITE = "|cffffffff"
local TYPE = "|cffffd100"
local WARNING = "|cffff4040"
local CLOSE = "|r"
local state = { rows = {}, enabled = false }

local function ObjectName(object)
    if not object then return "nil" end
    local name = object.GetDebugName and object:GetDebugName()
        or object.GetName and object:GetName()
    return name or tostring(object)
end

local function ObjectType(object)
    return object and object.GetObjectType and object:GetObjectType() or "unknown"
end

local function CompactValue(value)
    if type(value) == "table" then
        local values = {}
        for i = 1, math.min(#value, 4) do
            values[#values + 1] = string.format("%.2f", tonumber(value[i]) or 0)
        end
        if #values > 0 then return "{" .. table.concat(values, ", ") .. "}" end
        return "{...}"
    end
    if type(value) == "number" then return string.format("%.2f", value) end
    return tostring(value)
end

local function HideTargetHighlight()
    if state.targetHighlight then state.targetHighlight:Hide() end
end

local function ShowTargetHighlight(targets)
    if not state.targetHighlight then
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetFrameStrata("TOOLTIP")
        frame:SetFrameLevel(220)
        frame:EnableMouse(false)
        frame.texture = frame:CreateTexture(nil, "BACKGROUND")
        frame.texture:SetAllPoints()
        frame.texture:SetColorTexture(1, 0.82, 0, 0.10)
        frame.border = NSkin:CreatePixelBorder(frame,
            "NSkinDebugTargetHighlight", 1, YELLOW, true, frame)
        state.targetHighlight = frame
    end
    local left, right, bottom, top
    for _, target in ipairs(targets or {}) do
        if target and (not target.IsShown or target:IsShown()) then
            local l, r, b, t = NSkin:GetUIParentNormalizedBounds(target)
            if l then
                left = left and math.min(left, l) or l
                right = right and math.max(right, r) or r
                bottom = bottom and math.min(bottom, b) or b
                top = top and math.max(top, t) or t
            end
        end
    end
    if not left then return HideTargetHighlight() end
    local frame = state.targetHighlight
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right, bottom)
    frame:Show()
end

local function AcquireRow(parent, index)
    local row = state.rows[index]
    if row then return row end
    row = CreateFrame("Button", nil, parent)
    row:SetHeight(17)
    row:SetPoint("LEFT", 0, 0)
    row:SetPoint("RIGHT", 0, 0)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", 4, 0)
    row.text:SetPoint("RIGHT", -4, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("OnLeave", HideTargetHighlight)
    state.rows[index] = row
    return row
end

local function AddLine(lines, text, targets, isHeader)
    lines[#lines + 1] = {
        text = text, targets = targets, header = isHeader == true,
    }
end

local function AddSection(lines, title)
    if #lines > 0 then AddLine(lines, " ") end
    AddLine(lines, WHITE .. title .. CLOSE, nil, true)
end

local function AddField(lines, label, value, warning, targets)
    local color = warning and WARNING or WHITE
    AddLine(lines, MUTED .. label .. ": " .. CLOSE .. color
        .. CompactValue(value) .. CLOSE, targets)
end

local function CollectRuntimeTargets(element)
    if element.iconGroup and type(element.children) ~= "nil" then
        local children = element.children
        if type(children) == "function" then
            local ok, value = pcall(children, element)
            children = ok and value or nil
        end
        local targets = {}
        for _, child in ipairs(type(children) == "table" and children or {}) do
            if child and child.target then targets[#targets + 1] = child.target end
        end
        return targets
    end
    return element.target and { element.target } or {}
end

local function CollectComponentKinds(element)
    local kinds, seen = {}, {}
    local composition = element.composition
    if composition and composition.mode == "COMPOSITE" then
        for _, member in ipairs(composition.members or {}) do
            if not seen[member.kind] then
                kinds[#kinds + 1] = member.kind
                seen[member.kind] = true
            end
        end
    elseif element.kind then
        kinds[1] = element.kind
    end
    return kinds
end

local function HasTableValues(value)
    return type(value) == "table" and next(value) ~= nil
end

local function AddAppearance(lines, element, kind)
    local component = NSkin:GetSharedElementType(kind)
    local styleName = component and component.style
    if not styleName then
        AddField(lines, kind, "no canonical style", true)
        return
    end
    local profile = NSkin:GetProfile()
    local overrides = profile.appearanceOverrides
    local global = profile.appearance and profile.appearance[styleName]
    local elementOverride = overrides and overrides.elements
        and overrides.elements[element.id]
        and overrides.elements[element.id][styleName]
    local windowOverride
    for _, scopeID in ipairs(NSkin:GetAppearanceScopeChain(
        element.appearanceWindowID) or {})
    do
        local value = overrides and overrides.windows
            and overrides.windows[scopeID]
            and overrides.windows[scopeID][styleName]
        if HasTableValues(value) then windowOverride = value end
    end
    local effective = NSkin:GetAppearanceStyle(styleName,
        element.appearanceWindowID, element.id) or {}
    AddLine(lines, TYPE .. kind .. CLOSE .. MUTED .. "  [" .. styleName .. "]" .. CLOSE)
    AddField(lines, "  global key", "shared " .. kind .. " / " .. styleName)
    AddField(lines, "  window key", element.appearanceWindowID or "none")
    AddField(lines, "  element key", element.id)
    AddField(lines, "  effective context", (element.appearanceWindowID or "global")
        .. " -> " .. element.id)
    AddField(lines, "  global override", HasTableValues(global) and "yes" or "no")
    AddField(lines, "  window override", HasTableValues(windowOverride) and "yes" or "no")
    AddField(lines, "  element override", HasTableValues(elementOverride) and "yes" or "no")
    local preferred = { "width", "height", "size", "crop", "zoom",
        "background", "border", "color", "textSize", "font" }
    for _, key in ipairs(preferred) do
        if effective[key] ~= nil then AddField(lines, "  " .. key, effective[key]) end
    end
end

local function BuildLines(element)
    local lines = {}
    AddSection(lines, "Selected")
    if not element then
        AddField(lines, "status", "No selected element")
        return lines
    end
    AddField(lines, "name", element.label or element.id)
    AddField(lines, "element ID", element.id)
    AddField(lines, "window scope", element.appearanceWindowID or "nil",
        not element.appearanceWindowID)
    AddField(lines, "target", ObjectName(element.target), false,
        element.target and { element.target })

    AddSection(lines, "Structure")
    local composition = element.composition or { mode = "STANDALONE" }
    AddField(lines, "mode", composition.mode or "STANDALONE")
    AddField(lines, "composition parent", element.compositionParentID or "none")
    local movementOwner = NSkin:GetCompositionMovementOwner(element)
    AddField(lines, "movement owner", ObjectName(movementOwner),
        not element.compositionParentID and not movementOwner,
        movementOwner and { movementOwner })
    AddField(lines, "selection target", element.id)
    if element.compositionParentID then
        AddField(lines, "movement suppressed by Container", "yes")
    end
    AddField(lines, "specialized adapter",
        element.iconGroup and "ICON group" or element.refreshAppearance and "yes" or "no")

    AddSection(lines, "Members / Targets")
    if composition.mode == "COMPOSITE" then
        for index, member in ipairs(composition.members or {}) do
            local targets = NSkin:GetCompositionMemberTargets(element, member, false)
            AddLine(lines, string.format("%s%d. %s%s  %s%s%s",
                MUTED, index, TYPE, member.kind or "?", WHITE,
                member.role or "MEMBER", CLOSE), targets)
            AddField(lines, "  appearance ID", member.appearanceID or element.id)
            AddField(lines, "  runtime targets", #targets, false, targets)
            for targetIndex, target in ipairs(targets) do
                AddField(lines, "    " .. targetIndex,
                    ObjectType(target) .. " " .. ObjectName(target), false, { target })
            end
        end
    elseif composition.mode == "CONTAINER" then
        AddField(lines, "container ID", element.id)
        AddField(lines, "child count", #(composition.children or {}))
        for index, childID in ipairs(composition.children or {}) do
            local child = NSkin:GetSkinningElement(childID)
            AddField(lines, index .. " (movement suppressed)", childID
                .. " / " .. (child and child.kind or "not registered"),
                false, child and child.target and { child.target })
        end
    else
        local targets = CollectRuntimeTargets(element)
        AddField(lines, "runtime targets", #targets, false, targets)
        for index, target in ipairs(targets) do
            AddField(lines, tostring(index),
                ObjectType(target) .. " " .. ObjectName(target), false, { target })
        end
    end

    AddSection(lines, "Appearance")
    for _, kind in ipairs(CollectComponentKinds(element)) do
        AddAppearance(lines, element, kind)
    end

    AddSection(lines, "Editor")
    AddField(lines, "movement controls",
        movementOwner and not element.compositionParentID and "yes" or "no")
    AddField(lines, "draggable", element.draggable == true and "yes" or "no")
    local options = NSkin:GetCompositionEditorOptions(element) or {}
    AddField(lines, "option groups", #options)
    if composition.mode == "COMPOSITE" then
        for _, member in ipairs(composition.members or {}) do
            local component = NSkin:GetSharedElementType(member.kind)
            AddField(lines, (member.role or "MEMBER") .. " "
                .. (member.kind or "?"), (component and component.editorPreset
                    or "none") .. " / "
                    .. (member.role == "SECONDARY" and "TAB" or "INLINE"))
        end
    end
    for index, option in ipairs(options) do
        AddField(lines, "  " .. index, option.id .. " / "
            .. (option.presentation or "INLINE"))
    end

    AddSection(lines, "Bounds")
    local left, right, bottom, top = NSkin:GetSkinningElementBounds(element)
    if left then
        AddField(lines, "mode", composition.mode == "COMPOSITE"
            and "combined" or composition.mode == "CONTAINER"
                and "container parent" or "target")
        AddField(lines, "left / top", string.format("%.1f / %.1f", left, top))
        AddField(lines, "width / height", string.format("%.1f / %.1f",
            right - left, top - bottom))
        local regions = NSkin:GetCompositionHighlightRegions(element)
        AddField(lines, "regions", type(regions) == "table" and #regions or 0)
    else
        AddField(lines, "warning", "No visible bounds", true)
    end
    return lines
end

local function PositionInspector()
    local frame, main = state.frame, state.mainDock
    if not frame or not main then return end
    frame:ClearAllPoints()
    local screenRight = UIParent:GetRight() or GetScreenWidth()
    local mainRight = main:GetRight()
    if mainRight and screenRight - mainRight >= frame:GetWidth() + 12 then
        frame:SetPoint("TOPLEFT", main, "TOPRIGHT", 8, 0)
    else
        frame:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 0, -8)
    end
end

local function CreateInspector()
    if state.frame then return state.frame end
    local frame = CreateFrame("Frame", nil, UIParent)
    frame.nskinOwnedGeometry = true
    frame:SetSize(440, 650)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(120)
    NSkin:SkinWindow(frame)
    NSkin:SkinWindowHeader(frame)
    frame.debugBorder = NSkin:CreatePixelBorder(frame,
        "NSkinDebugInspectorBorder", 1, YELLOW, true, frame)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOPLEFT", 12, -6)
    frame.title:SetText("NSkin Debug Inspector")
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT")
    NSkin:SkinFlatButton(close, "x")
    close:SetScript("OnClick", function() NSkin:ToggleSkinningDebugInspector() end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -30)
    scroll:SetPoint("BOTTOMRIGHT", -28, 8)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local range = self:GetVerticalScrollRange() or 0
        local value = self:GetVerticalScroll() - delta * 34
        self:SetVerticalScroll(math.max(0, math.min(range, value)))
    end)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(400, 1)
    scroll:SetScrollChild(content)
    if scroll.ScrollBar then NSkin:SkinScrollBar(scroll.ScrollBar) end
    state.frame, state.scroll, state.content = frame, scroll, content
    frame:Hide()
    return frame
end

function NSkin:IsSkinningDebugInspectorEnabled()
    return state.enabled == true
end

function NSkin:RefreshSkinningDebugInspector(element, mainDock)
    state.element = element
    state.mainDock = mainDock or state.mainDock
    if not state.enabled then return end
    local frame = CreateInspector()
    NSkin:SkinWindow(frame)
    NSkin:SkinWindowHeader(frame)
    NSkin:SetPixelBorderColor(frame.debugBorder, unpack(YELLOW))
    if state.scroll and state.scroll.ScrollBar then
        NSkin:SkinScrollBar(state.scroll.ScrollBar)
    end
    local lines = BuildLines(element)
    for index, definition in ipairs(lines) do
        local row = AcquireRow(state.content, index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -(index - 1) * 17)
        row:SetPoint("TOPRIGHT", 0, -(index - 1) * 17)
        row.text:SetText(definition.text)
        row.text:SetFontObject(definition.header
            and _G.GameFontNormalSmall or _G.GameFontHighlightSmall)
        row.targets = definition.targets
        row:SetScript("OnEnter", definition.targets and function(self)
            ShowTargetHighlight(self.targets)
        end or nil)
        row:Show()
    end
    for index = #lines + 1, #state.rows do state.rows[index]:Hide() end
    state.content:SetHeight(math.max(1, #lines * 17))
    PositionInspector()
    frame:Show()
end

function NSkin:ToggleSkinningDebugInspector(mainDock)
    state.enabled = not state.enabled
    if not state.enabled then
        HideTargetHighlight()
        if state.frame then state.frame:Hide() end
        return false
    end
    state.mainDock = mainDock or state.mainDock
    self:RefreshSkinningDebugInspector(state.element, state.mainDock)
    return true
end

function NSkin:HideSkinningDebugInspector()
    state.enabled = false
    HideTargetHighlight()
    if state.frame then state.frame:Hide() end
end
