local _, NSkin = ...

local controller
local GRID_SIZES = { 2, 4, 8, 16 }
local VALID_GRID_SIZES = { [2] = true, [4] = true, [8] = true, [16] = true }
local TRANSPARENT = { 0, 0, 0, 0 }
local StopDrag
local RefreshGrid
local HideGrid
local RefreshModalInputOwnership
local RefreshWindowFallbackAppearance
local SelectElement

function NSkin:GetSkinningGridSize()
    local profile = self:GetProfile()
    local size = profile.editor and tonumber(profile.editor.gridSize)
    return VALID_GRID_SIZES[size] and size or 8
end

function NSkin:SetSkinningGridSize(size)
    size = tonumber(size)
    if not VALID_GRID_SIZES[size] then return false end
    local profile = self:GetProfile()
    if size == 8 then
        if profile.editor then
            profile.editor.gridSize = nil
            if not next(profile.editor) then profile.editor = nil end
        end
    else
        profile.editor = profile.editor or {}
        profile.editor.gridSize = size
    end
    if controller and controller.gridDropdown and controller.gridDropdown.GenerateMenu then
        controller.gridDropdown:GenerateMenu()
    end
    if controller and controller.dragging and controller.selectedElement then
        RefreshGrid(controller.selectedElement.window)
    end
    return true
end

local function GetCursorPositionForWindow(window)
    local scale = window and window:GetEffectiveScale() or UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

local function GetElementBounds(element)
    local left, right, bottom, top = NSkin:GetSkinningElementBounds(element)
    if not left then return end
    local padding = element.highlightPadding or 0
    return left - padding, right + padding, bottom - padding, top + padding
end

local function AnchorOverlay(overlay, element)
    overlay:ClearAllPoints()
    if element and type(element.anchorHighlight) == "function"
        and element.anchorHighlight(element, overlay) == true
    then
        return true
    end
    if element and element.kind ~= "TAB_GROUP"
        and not (element.composition and element.composition.mode == "COMPOSITE")
        and type(element.highlightRegions) ~= "table"
        and type(element.highlightRegions) ~= "function"
        and type(element.getHighlightBounds) ~= "function"
        and element.target and element.target.IsShown and element.target:IsShown()
    then
        -- Ordinary movable elements already expose the exact frame to
        -- highlight. Anchoring directly avoids applying a scaled window's
        -- coordinate conversion twice.
        overlay:SetAllPoints(element.target)
        return true
    end
    local left, right, bottom, top = GetElementBounds(element)
    if not left then return false end
    overlay:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    overlay:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right, bottom)
    return true
end

local function GetEditorElement(element)
    return element and NSkin.GetSkinningEditorElement
        and NSkin:GetSkinningEditorElement(element) or element
end

local function EditorElementBelongsToParent(element, parent)
    if not element or not parent then return false end
    if NSkin:GetCompositionParent(element) == parent then return true end
    if not element.isAnchorGroup then return false end
    for _, member in ipairs(NSkin:GetAnchorGroupMembers(element) or {}) do
        if NSkin:GetCompositionParent(member) == parent then return true end
    end
    return false
end

local FRAME_STRATA_ORDER = {
    BACKGROUND = 1,
    LOW = 2,
    MEDIUM = 3,
    HIGH = 4,
    DIALOG = 5,
    FULLSCREEN = 6,
    FULLSCREEN_DIALOG = 7,
    TOOLTIP = 8,
}

local function GetFrameOrder(frame)
    if not frame then return 0, 0 end
    local strata = "MEDIUM"
    local level = 0
    if type(frame.GetFrameStrata) == "function" then
        local ok, value = pcall(frame.GetFrameStrata, frame)
        if ok and type(value) == "string" then strata = value end
    end
    if type(frame.GetFrameLevel) == "function" then
        local ok, value = pcall(frame.GetFrameLevel, frame)
        if ok and tonumber(value) then level = tonumber(value) end
    end
    return FRAME_STRATA_ORDER[strata] or 3, level
end

local function IsFrameWithin(frame, ancestor)
    if not frame or not ancestor then return false end
    local current = frame
    for _ = 1, 32 do
        if current == ancestor then return true end
        if type(current.GetParent) ~= "function" then break end
        local ok, parent = pcall(current.GetParent, current)
        if not ok or not parent or parent == current then break end
        current = parent
    end
    return false
end

local function GetMouseFociSafe()
    local result = {}
    if type(_G.GetMouseFoci) == "function" then
        local packed = { pcall(_G.GetMouseFoci) }
        if packed[1] then
            if type(packed[2]) == "table" then
                for _, focus in ipairs(packed[2]) do
                    result[#result + 1] = focus
                end
            else
                for i = 2, #packed do
                    if packed[i] then result[#result + 1] = packed[i] end
                end
            end
        end
    elseif type(_G.GetMouseFocus) == "function" then
        local ok, focus = pcall(_G.GetMouseFocus)
        if ok and focus then result[1] = focus end
    end
    return result
end

local function IsAnyStaticPopupShown()
    local count = tonumber(_G.STATICPOPUP_NUMDIALOGS) or 4
    for index = 1, count do
        local popup = _G["StaticPopup" .. index]
        if popup and popup.IsShown and popup:IsShown() then return true end
    end
    return false
end

local function IsCursorOverStaticPopup()
    local count = tonumber(_G.STATICPOPUP_NUMDIALOGS) or 4
    for index = 1, count do
        local popup = _G["StaticPopup" .. index]
        if popup and popup.IsShown and popup:IsShown()
            and popup.IsMouseOver and popup:IsMouseOver()
        then
            return true
        end
    end
    return false
end

local function GetOverlayOrderSource(element)
    local target = element and element.target
    if target and type(target.GetFrameStrata) == "function"
        and type(target.GetFrameLevel) == "function"
    then
        return target
    end
    return element and element.window
end

local function ConfigureVisualOverlayStacking(frame, element)
    if not frame then return end
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(math.max(1,
        100 + (tonumber(element and element.priority) or 0)
            + (element and element.compositionParentID and 1000 or 0)))
end

local function ConfigureVisualOverlayBelowModal(frame)
    if not frame then return end
    local bestPopup, bestStrata, bestLevel
    local count = tonumber(_G.STATICPOPUP_NUMDIALOGS) or 4
    for index = 1, count do
        local popup = _G["StaticPopup" .. index]
        if popup and popup.IsShown and popup:IsShown() then
            local strata, level = GetFrameOrder(popup)
            if not bestPopup or strata > bestStrata
                or (strata == bestStrata and level > bestLevel)
            then
                bestPopup, bestStrata, bestLevel = popup, strata, level
            end
        end
    end
    if not bestPopup then return false end
    local strataName = bestPopup.GetFrameStrata
        and bestPopup:GetFrameStrata() or "DIALOG"
    frame:SetFrameStrata(strataName)
    frame:SetFrameLevel(math.max(1, (bestLevel or 1) - 1))
    return true
end

local function ConfigureInputOverlayStacking(frame, element)
    if not frame then return end
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    local level
    if element and element.kind == "WINDOW" then
        -- Window selection is the fallback editor hit surface. Keep it below
        -- every registered child/semantic hit target so empty window areas
        -- select the window without stealing child selection.
        level = 1
    else
        level = 50 + (tonumber(element and element.priority) or 0)
            + (element and element.compositionParentID and 1000 or 0)
            + (element and element.isAnchorGroup and 2000 or 0)
    end
    frame:SetFrameLevel(math.max(1, level))
end

local function GetTopUnderlyingMouseFocus(inputTarget)
    for _, focus in ipairs(GetMouseFociSafe()) do
        if focus and focus ~= inputTarget
            and not focus.nskinSkinningInput
            and not focus.nskinSkinningOverlay
            and not IsFrameWithin(focus, inputTarget)
            and not IsFrameWithin(inputTarget, focus)
        then
            return focus
        end
    end
end

function NSkin:IsSkinningOverlayInteractive(element, inputTarget)
    if not controller or not controller.enabled or controller.dragging
        or controller.modalInputBlocked
        or not element or not inputTarget
        or not element.window or not element.window:IsShown()
        or not self:IsSkinningElementEditable(element)
    then
        return false
    end
    if inputTarget.IsShown and not inputTarget:IsShown() then return false end
    if inputTarget.IsMouseOver and not inputTarget:IsMouseOver() then return false end
    if IsCursorOverStaticPopup() then return false end

    local underlying = GetTopUnderlyingMouseFocus(inputTarget)
    if not underlying or underlying == _G.WorldFrame
        or underlying == UIParent
    then
        return true
    end
    return IsFrameWithin(underlying, element.window)
        or IsFrameWithin(element.window, underlying)
end

local function SetElementOverlayShown(overlay, shown)
    if not overlay then return end
    overlay:SetShown(shown == true)
    if overlay.inputTarget then
        overlay.inputTarget:SetShown(shown == true)
        overlay.inputTarget:EnableMouse(
            shown == true and not (controller and controller.modalInputBlocked))
    end
end

local function IsPointerWithinElementBounds(element)
    if not element or not _G.GetCursorPosition then return false end
    local left, right, bottom, top = GetElementBounds(element)
    if not left then return false end
    local scale = UIParent and UIParent:GetEffectiveScale() or 1
    if not scale or scale == 0 then return false end
    local x, y = _G.GetCursorPosition()
    x, y = x / scale, y / scale
    return x >= left and x <= right and y >= bottom and y <= top
end

local function RefreshAnchorGroupOverlay(element)
    if not controller or not element or not element.isAnchorGroup then return end
    local overlay = controller.anchorGroupOverlays[element.id]
    if not overlay then
        overlay = CreateFrame("Frame", nil, UIParent)
        ConfigureVisualOverlayStacking(overlay, element)
        overlay:EnableMouse(false)
        overlay.texture = overlay:CreateTexture(nil, "BACKGROUND")
        overlay.texture:SetAllPoints()
        overlay.border = NSkin:CreatePixelBorder(
            overlay, "NSkinSkinningModeAnchorGroupHighlight", 1,
            NSkin:GetStyle("skinningMode").hover, false, overlay)
        overlay.element = element

        local inputTarget = CreateFrame("Button", nil, UIParent)
        inputTarget.nskinSkinningInput = true
        inputTarget.nskinSkinningElement = element
        inputTarget:RegisterForClicks("LeftButtonUp")
        if inputTarget.SetPropagateMouseMotion then
            inputTarget:SetPropagateMouseMotion(true)
        end
        if inputTarget.SetPropagateMouseClicks then
            inputTarget:SetPropagateMouseClicks(true)
        end
        ConfigureInputOverlayStacking(inputTarget, element)
        inputTarget:SetAllPoints(overlay)
        overlay.inputTarget = inputTarget

        local function RefreshGroupInput(self)
            ConfigureInputOverlayStacking(self, element)
            ConfigureVisualOverlayStacking(overlay, element)
            local interactive = NSkin:IsSkinningOverlayInteractive(element, self)
            if self.SetPropagateMouseClicks then
                self:SetPropagateMouseClicks(not interactive)
            end
            if interactive then
                controller.hoveredElement = element
            elseif controller.hoveredElement == element then
                controller.hoveredElement = nil
            end
            RefreshAnchorGroupOverlay(element)
            if RefreshWindowFallbackAppearance then
                RefreshWindowFallbackAppearance(element.window)
            end
            return interactive
        end

        inputTarget:SetScript("OnEnter", RefreshGroupInput)
        inputTarget:SetScript("OnLeave", function()
            if controller.hoveredElement == element
                and not IsPointerWithinElementBounds(element)
            then
                controller.hoveredElement = nil
            end
            RefreshAnchorGroupOverlay(element)
            if RefreshWindowFallbackAppearance then
                RefreshWindowFallbackAppearance(element.window)
            end
        end)
        inputTarget:SetScript("OnMouseDown", RefreshGroupInput)
        inputTarget:SetScript("OnClick", function(self)
            if not RefreshGroupInput(self) then return end
            SelectElement(element)
        end)

        controller.anchorGroupOverlays[element.id] = overlay
    end

    local style = NSkin:GetStyle("skinningMode")
    local eligible = controller.enabled and element.window:IsShown()
        and NSkin:IsSkinningElementEditable(element)
        and AnchorOverlay(overlay, element)
    local selected = controller.selectedElement == element
    local visible = eligible
        and (selected
            or (not controller.modalInputBlocked
                and not controller.dragging
                and controller.hoveredElement == element))

    overlay.texture:SetColorTexture(unpack(visible and style.highlight or TRANSPARENT))
    NSkin:SetPixelBorderColor(overlay.border, unpack(style.hover))
    NSkin:SetPixelBorderShown(overlay.border, visible)
    overlay:SetShown(eligible == true)
    overlay:SetAlpha(controller.modalInputBlocked and not selected and 0 or 1)

    local inputTarget = overlay.inputTarget
    if inputTarget then
        inputTarget:SetShown(eligible == true)
        inputTarget:EnableMouse(
            eligible == true and not controller.modalInputBlocked)
        if controller.modalInputBlocked
            and inputTarget.SetPropagateMouseClicks
        then
            inputTarget:SetPropagateMouseClicks(true)
        end
    end
end

local function RefreshOverlayAppearance(element)
    if not controller then return end
    local editorElement = GetEditorElement(element)
    if editorElement ~= element then
        local overlay = controller.overlays[element.id]
        if overlay then
            overlay.texture:SetColorTexture(unpack(TRANSPARENT))
            NSkin:SetPixelBorderShown(overlay.border, false)
        end
        RefreshAnchorGroupOverlay(editorElement)
        return
    elseif element.isAnchorGroup then
        RefreshAnchorGroupOverlay(element)
        return
    end
    local overlay = controller.overlays[element.id]
    if not overlay then return end
    local style = NSkin:GetStyle("skinningMode")
    local selected = controller.selectedElement == element
    local visible = not overlay.dragHidden
        and (selected or (not controller.dragging and overlay.hovered == true))
    local hovered = controller.hoveredElement
    if hovered and (EditorElementBelongsToParent(hovered, element)
        or EditorElementBelongsToParent(element, hovered))
    then
        visible = false
    elseif element.kind == "WINDOW" then
        local selectedElement = controller.selectedElement
        local childHovered = hovered and hovered ~= element
            and hovered.window == element.window
        local childSelected = selectedElement and selectedElement ~= element
            and selectedElement.window == element.window
        if childHovered
            or (childSelected and overlay.hovered ~= true)
        then
            visible = false
        end
    end
    overlay.texture:SetColorTexture(unpack(visible and style.highlight or TRANSPARENT))
    NSkin:SetPixelBorderColor(overlay.border, unpack(style.hover))
    NSkin:SetPixelBorderShown(overlay.border, visible)
end

RefreshWindowFallbackAppearance = function(window)
    if not controller or not window then return end
    for _, candidate in pairs(controller.overlayElements) do
        if candidate.window == window and candidate.kind == "WINDOW" then
            RefreshOverlayAppearance(candidate)
            return
        end
    end
end

local function RefreshAllOverlayAppearances()
    for _, element in pairs(controller.overlayElements) do
        RefreshOverlayAppearance(element)
    end
end

RefreshModalInputOwnership = function()
    if not controller then return end
    local blocked = IsAnyStaticPopupShown()
    controller.modalInputBlocked = blocked

    for id, overlay in pairs(controller.overlays) do
        local element = controller.overlayElements[id]
        local selected = element and controller.selectedElement == element
        local inputTarget = overlay.inputTarget
        if inputTarget then
            inputTarget:EnableMouse(
                controller.enabled and overlay:IsShown() and not blocked)
            if inputTarget.SetPropagateMouseClicks then
                inputTarget:SetPropagateMouseClicks(true)
            end
        end
        if blocked and selected then
            ConfigureVisualOverlayBelowModal(overlay)
            overlay:SetAlpha(1)
        else
            ConfigureVisualOverlayStacking(overlay, element)
            overlay:SetAlpha(blocked and 0 or 1)
        end
        if blocked and overlay.hovered then overlay.hovered = nil end
    end

    for _, overlay in pairs(controller.anchorGroupOverlays) do
        local element = overlay.element
        local selected = element and controller.selectedElement == element
        if blocked and selected then
            ConfigureVisualOverlayBelowModal(overlay)
            overlay:SetAlpha(1)
        else
            ConfigureVisualOverlayStacking(overlay, element)
            overlay:SetAlpha(blocked and 0 or 1)
        end
        if overlay.inputTarget then
            overlay.inputTarget:EnableMouse(
                controller.enabled and overlay:IsShown() and not blocked)
            if overlay.inputTarget.SetPropagateMouseClicks then
                overlay.inputTarget:SetPropagateMouseClicks(true)
            end
        end
    end

    if blocked then
        controller.hoveredElement = nil
    end
    RefreshAllOverlayAppearances()
end

local function RefreshInspector()
    if controller and controller.dockedWindow then
        controller.dockedWindow:Refresh(controller.selectedElement)
        if NSkin.RefreshSkinningDebugInspector then
            NSkin:RefreshSkinningDebugInspector(controller.selectedElement,
                controller.dockedWindow.frame)
        end
    end
end

local function DockInspector(element)
    if controller and controller.dockedWindow then
        controller.dockedWindow:Dock(element and element.window)
    end
end

local function DockWithoutSelection(excludedWindow)
    local previous = controller.selectedElement
    controller.selectedElement = nil
    if previous then RefreshOverlayAppearance(previous) end
    local activeWindow = NSkin:GetMostRecentVisibleSkinningWindow(excludedWindow)
    local visibleElement
    NSkin:ForEachRegisteredSkinningElement(function(element)
        if not visibleElement and element.window == activeWindow then
            visibleElement = element
        end
    end)
    if visibleElement then
        DockInspector(visibleElement)
    else
        controller.dockedWindow:Dock(nil)
    end
    RefreshInspector()
end

SelectElement = function(element)
    if not element then return end
    local clickedElement = element
    element = GetEditorElement(element)
    if element.isAnchorGroup then element.clickedAnchorMember = clickedElement end
    NSkin:MarkSkinningWindowActive(element.window)
    local previous = controller.selectedElement
    controller.selectedElement = element
    if previous ~= element then controller.dockedWindow:ResetScroll() end
    if previous and previous ~= element then RefreshOverlayAppearance(previous) end
    RefreshOverlayAppearance(element)
    RefreshWindowFallbackAppearance(element.window)
    DockInspector(element)
    RefreshInspector()
end

local function RoundToGrid(value, size)
    if value >= 0 then return math.floor(value / size + 0.5) * size end
    return math.ceil(value / size - 0.5) * size
end

local function RoundOne(value)
    if value >= 0 then return math.floor(value * 10 + 0.5) / 10 end
    return math.ceil(value * 10 - 0.5) / 10
end

local function CopyPlacement(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function GetElementPlacement(element)
    if type(element.getPlacement) == "function" then
        return element.getPlacement(element)
    end
    if element.kind == "TAB_GROUP" then
        return NSkin:GetTabGroupPlacement(element.id)
    end
end

local function ApplyElementPlacement(element, placement, applyOptions)
    if type(element.applyPlacement) == "function" then
        return element.applyPlacement(element, placement, applyOptions) == true
    end
    return false
end

local function SnapToNearest(value, threshold, ...)
    local best, bestDistance
    for i = 1, select("#", ...) do
        local candidate = select(i, ...)
        local distance = math.abs(value - candidate)
        if distance <= threshold and (not bestDistance or distance < bestDistance) then
            best, bestDistance = candidate, distance
        end
    end
    return best or value, best ~= nil
end

local function RefreshDragInspectorOffsets(element, placement)
    if not controller or not element or not placement then return end
    local x = RoundOne(tonumber(placement.alongOffset) or 0)
    local y = RoundOne(tonumber(placement.edgeOffset) or 0)
    for _, view in pairs(controller.optionViews) do
        if view.context == element and view.SetPreviewValue then
            view:SetPreviewValue("alongOffset", x, 1)
            view:SetPreviewValue("edgeOffset", y, 1)
        end
    end
end

local function RefreshElementInspectorViews(element)
    if not controller or not element then return end
    for _, view in pairs(controller.optionViews) do
        if view.context == element and view.Refresh then view:Refresh() end
    end
end

local function SetSemanticPlacementFromLocal(placement, window, localX, localY,
    elementWidth, elementHeight, alignmentIndex)
    local windowWidth, windowHeight = window:GetWidth(), window:GetHeight()
    local centerY = localY - elementHeight / 2
    local edge = centerY > -windowHeight / 2 and "TOP" or "BOTTOM"
    local side = centerY <= 0 and centerY >= -windowHeight and "INSIDE" or "OUTSIDE"
    local alignment = alignmentIndex == 1 and "LEFT"
        or (alignmentIndex == 2 and "CENTER" or "RIGHT")
    local alongOffset = alignment == "LEFT" and localX
        or (alignment == "CENTER" and localX + elementWidth / 2 - windowWidth / 2
            or localX + elementWidth - windowWidth)
    local edgeOffset = edge == "TOP"
        and (side == "INSIDE" and localY or localY - elementHeight)
        or (side == "INSIDE" and localY - elementHeight + windowHeight
            or localY + windowHeight)
    placement.mode = nil
    placement.point, placement.relativePoint = nil, nil
    placement.x, placement.y, placement.relativeTo = nil, nil, nil
    placement.offsetX, placement.offsetY = nil, nil
    placement.edge, placement.side, placement.alignment = edge, side, alignment
    placement.alongOffset, placement.edgeOffset = alongOffset, edgeOffset
end

HideGrid = function()
    local pool = controller and controller.activeGridPool
    if not pool then return end
    for i = 1, #pool.vertical do pool.vertical[i]:Hide() end
    for i = 1, #pool.horizontal do pool.horizontal[i]:Hide() end
    for i = 1, #pool.borders do pool.borders[i]:Hide() end
    controller.activeGridPool = nil
end

RefreshGrid = function(window)
    if controller.activeGridPool then HideGrid() end
    local pool = controller.gridPools[window]
    if not pool then
        pool = { vertical = {}, horizontal = {}, borders = {} }
        controller.gridPools[window] = pool
    end
    controller.activeGridPool = pool
    local visualGridSize = 32
    local width, height = window:GetWidth(), window:GetHeight()
    local marginX, marginY = 30, 30
    local style = NSkin:GetStyle("skinningMode")
    local gridAlpha = tonumber(style.gridAlpha) or 0.4
    local firstX = math.ceil(-marginX / visualGridSize)
    local lastX = math.floor((width + marginX) / visualGridSize)
    local verticalCount = 0
    for gridIndex = firstX, lastX do
        verticalCount = verticalCount + 1
        local line = pool.vertical[verticalCount]
        if not line then
            line = window:CreateTexture(nil, "BORDER", nil, -8)
            pool.vertical[verticalCount] = line
        end
        local x = gridIndex * visualGridSize
        line:ClearAllPoints()
        line:SetPoint("TOP", window, "TOPLEFT", x, marginY)
        line:SetPoint("BOTTOM", window, "BOTTOMLEFT", x, -marginY)
        line:SetWidth(1)
        line:SetColorTexture(style.activeDropZone[1], style.activeDropZone[2],
            style.activeDropZone[3], 1)
        line:SetAlpha(gridAlpha)
        line:Show()
    end
    for i = verticalCount + 1, #pool.vertical do
        pool.vertical[i]:Hide()
    end
    local firstY = math.ceil(-marginY / visualGridSize)
    local lastY = math.floor((height + marginY) / visualGridSize)
    local horizontalCount = 0
    for gridIndex = firstY, lastY do
        horizontalCount = horizontalCount + 1
        local line = pool.horizontal[horizontalCount]
        if not line then
            line = window:CreateTexture(nil, "BORDER", nil, -8)
            pool.horizontal[horizontalCount] = line
        end
        local y = -gridIndex * visualGridSize
        line:ClearAllPoints()
        line:SetPoint("LEFT", window, "TOPLEFT", -marginX, y)
        line:SetPoint("RIGHT", window, "TOPRIGHT", marginX, y)
        line:SetHeight(1)
        line:SetColorTexture(style.activeDropZone[1], style.activeDropZone[2],
            style.activeDropZone[3], 1)
        line:SetAlpha(gridAlpha)
        line:Show()
    end
    for i = horizontalCount + 1, #pool.horizontal do
        pool.horizontal[i]:Hide()
    end
    if #pool.borders == 0 then
        for i = 1, 4 do
            pool.borders[i] = window:CreateTexture(nil, "BORDER", nil, -7)
            pool.borders[i]:SetColorTexture(style.activeDropZone[1],
                style.activeDropZone[2], style.activeDropZone[3], 1)
        end
        pool.borders[1]:SetWidth(3)
        pool.borders[2]:SetWidth(3)
        pool.borders[3]:SetHeight(3)
        pool.borders[4]:SetHeight(3)
    end
    local left, right, top, bottom = unpack(pool.borders)
    left:ClearAllPoints(); right:ClearAllPoints(); top:ClearAllPoints(); bottom:ClearAllPoints()
    left:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
    right:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    top:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    bottom:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    for i = 1, 4 do
        pool.borders[i]:SetColorTexture(style.activeDropZone[1],
            style.activeDropZone[2], style.activeDropZone[3], 1)
        pool.borders[i]:SetAlpha(gridAlpha)
        pool.borders[i]:Show()
    end
end

local function UpdateDrag()
    local element = controller.selectedElement
    local window = element and element.window
    if not window then return end
    local cursorX, cursorY = GetCursorPositionForWindow(window)
    local localX = cursorX - controller.grabOffsetX - window:GetLeft()
    local localY = cursorY + controller.grabOffsetY - window:GetTop()
    if not IsShiftKeyDown() then
        local size = NSkin:GetSkinningGridSize()
        local width, height = window:GetWidth(), window:GetHeight()
        local ghostWidth, ghostHeight = controller.dragWidth, controller.dragHeight
        local threshold = math.max(6, size)
        local snappedX, borderSnappedX = SnapToNearest(localX, threshold,
            0, -ghostWidth, (width - ghostWidth) / 2, width, width - ghostWidth)
        local snappedY, borderSnappedY = SnapToNearest(localY, threshold,
            0, ghostHeight, -height, -height + ghostHeight)
        localX = borderSnappedX and snappedX or RoundToGrid(localX, size)
        localY = borderSnappedY and snappedY or RoundToGrid(localY, size)
    end
    controller.gridX, controller.gridY = localX, localY
    local centerX = localX + controller.dragWidth / 2
    local alignmentIndex = centerX < window:GetWidth() / 3 and 1
        or (centerX < window:GetWidth() * 2 / 3 and 2 or 3)
    controller.dropAlignmentIndex = alignmentIndex
    if localX == controller.previewX and localY == controller.previewY then return end
    controller.previewX, controller.previewY = localX, localY
    local placement = controller.previewPlacement
    SetSemanticPlacementFromLocal(placement, window, localX, localY,
        controller.dragWidth, controller.dragHeight, alignmentIndex)
    RefreshDragInspectorOffsets(element, placement)
    if element.livePreview ~= false
        and ApplyElementPlacement(element, placement, controller.previewOptions)
    then
        controller.previewApplied = true
        controller.ghost:Hide()
        if AnchorOverlay(controller.dragHighlight, element) then
            controller.dragHighlight:Show()
        end
    else
        controller.previewApplied = nil
        controller.ghost:ClearAllPoints()
        controller.ghost:SetPoint("TOPLEFT", window, "TOPLEFT", localX, localY)
        controller.ghost:Show()
        controller.dragHighlight:ClearAllPoints()
        controller.dragHighlight:SetAllPoints(controller.ghost)
        controller.dragHighlight:Show()
    end
end

local function BeginDrag(element)
    if not element or (element.kind ~= "TAB_GROUP" and not element.draggable)
        or not NSkin:GetCompositionMovementOwner(element)
        or controller.dragging then return end
    controller.dragging = true
    local overlay = controller.overlays[element.id]
    local movementOwner = NSkin:GetCompositionMovementOwner(element)
    local composite = element.composition
        and element.composition.mode == "COMPOSITE"
    local coordinateScale = 1
    local ownerLeft, ownerTop, ownerWidth, ownerHeight
    if composite then
        local windowScale = element.window:GetEffectiveScale()
        local ownerScale = movementOwner and movementOwner.GetEffectiveScale
            and movementOwner:GetEffectiveScale() or windowScale
        coordinateScale = ownerScale / windowScale
        ownerLeft = movementOwner and movementOwner.GetLeft
            and movementOwner:GetLeft()
        ownerTop = movementOwner and movementOwner.GetTop
            and movementOwner:GetTop()
        ownerWidth = movementOwner and movementOwner.GetWidth
            and movementOwner:GetWidth()
        ownerHeight = movementOwner and movementOwner.GetHeight
            and movementOwner:GetHeight()
    elseif overlay and overlay.usesAbsoluteBounds then
        coordinateScale = UIParent:GetEffectiveScale()
            / element.window:GetEffectiveScale()
    end
    controller.dragWidth = math.max(1,
        (ownerWidth or (overlay and overlay:GetWidth()) or 1) * coordinateScale)
    controller.dragHeight = math.max(1,
        (ownerHeight or (overlay and overlay:GetHeight()) or 1) * coordinateScale)
    -- Keep the ghost in the edited window's coordinate space. A UIParent
    -- ghost is the wrong size and offset when Blizzard scales the window.
    controller.ghost:SetParent(element.window)
    controller.ghost:SetScale(1)
    controller.ghost:SetSize(controller.dragWidth, controller.dragHeight)
    controller.ghost.texture:SetColorTexture(unpack(NSkin:GetStyle("skinningMode").ghost))
    controller.ghost:Hide()
    controller.originalPlacement = CopyPlacement(GetElementPlacement(element))
    controller.previewPlacement = CopyPlacement(controller.originalPlacement)
    controller.previewX, controller.previewY = nil, nil
    if overlay then
        overlay.hovered = nil
        overlay.dragHidden = true
    end
    RefreshAllOverlayAppearances()
    local cursorX, cursorY = GetCursorPositionForWindow(element.window)
    local left = composite and ownerLeft or overlay and overlay:GetLeft()
    local top = composite and ownerTop or overlay and overlay:GetTop()
    left = left and left * coordinateScale or cursorX
    top = top and top * coordinateScale or cursorY
    controller.grabOffsetX = cursorX - left
    controller.grabOffsetY = top - cursorY
    RefreshGrid(element.window)
    UpdateDrag()
    controller.dragFrame:EnableKeyboard(true)
    controller.dragFrame:SetPropagateKeyboardInput(true)
    controller.dragFrame:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            StopDrag(false)
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    controller.dragFrame:SetScript("OnUpdate", UpdateDrag)
end

StopDrag = function(apply)
    if not controller.dragging then return end
    local gridX = controller.gridX and RoundOne(controller.gridX)
    local gridY = controller.gridY and RoundOne(controller.gridY)
    controller.dragging = false
    controller.dragFrame:SetScript("OnUpdate", nil)
    controller.dragFrame:SetScript("OnKeyDown", nil)
    controller.dragFrame:EnableKeyboard(false)
    controller.ghost:Hide()
    controller.dragHighlight:Hide()
    HideGrid()
    local element = controller.selectedElement
    local overlay = element and controller.overlays[element.id]
    if apply and gridX and gridY and element then
        local placement = controller.previewPlacement
        SetSemanticPlacementFromLocal(placement, element.window, gridX, gridY,
            controller.dragWidth, controller.dragHeight,
            controller.dropAlignmentIndex or 1)
        placement.alongOffset = RoundOne(placement.alongOffset)
        placement.edgeOffset = RoundOne(placement.edgeOffset)
        local persisted = type(element.setPlacement) == "function"
            and element.setPlacement(element, placement) == true
        if persisted and element.editorOptions then
            local definitions = type(element.editorOptions) == "table"
                and element.editorOptions or { element.editorOptions }
            for i = 1, #definitions do
                local definition = definitions[i]
                local id = type(definition) == "table" and definition.id or definition
                if type(id) == "string" then NSkin:NotifyOptionGroupChanged(id) end
            end
        end
        if not persisted and controller.originalPlacement then
            ApplyElementPlacement(element, controller.originalPlacement)
        end
    elseif element and controller.originalPlacement then
        local restored = ApplyElementPlacement(element, controller.originalPlacement)
        if not restored and _G.InCombatLockdown and _G.InCombatLockdown() then
            controller.pendingRollback = {
                element = element,
                placement = CopyPlacement(controller.originalPlacement),
            }
        end
    end
    if overlay then
        overlay.dragHidden = nil
        AnchorOverlay(overlay, element)
    end
    controller.originalPlacement = nil
    controller.previewPlacement = nil
    controller.dropAlignmentIndex = nil
    controller.previewApplied = nil
    controller.previewX, controller.previewY = nil, nil
    RefreshElementInspectorViews(element)
    RefreshAllOverlayAppearances()
end

local function RefreshWindowOverlays(window)
    if not controller.enabled or not window:IsShown() then return end
    local selectionLost
    for id, element in pairs(controller.overlayElements) do
        local overlay = controller.overlays[id]
        if element.window == window and overlay then
            ConfigureVisualOverlayStacking(overlay, element)
            if overlay.inputTarget then
                ConfigureInputOverlayStacking(overlay.inputTarget, element)
            end
            if NSkin:IsSkinningElementEditable(element)
                and AnchorOverlay(overlay, element)
            then
                SetElementOverlayShown(overlay, true)
            else
                SetElementOverlayShown(overlay, false)
                if controller.selectedElement == element then selectionLost = true end
            end
        end
    end
    for _, groupOverlay in pairs(controller.anchorGroupOverlays) do
        local group = groupOverlay.element
        if group and group.window == window then
            RefreshAnchorGroupOverlay(group)
        end
    end
    if selectionLost then DockWithoutSelection(window) end
end

local function EnsureAbsoluteWindowLifecycle(window)
    if controller.absoluteWindowLifecycles[window] then return end
    local watcher = CreateFrame("Frame", nil, window)
    watcher:SetScript("OnShow", function() RefreshWindowOverlays(window) end)
    watcher:SetScript("OnHide", function()
        for id, element in pairs(controller.overlayElements) do
            local overlay = controller.overlays[id]
            if element.window == window and overlay then
                SetElementOverlayShown(overlay, false)
                overlay.hovered = nil
            end
        end
        for _, overlay in pairs(controller.anchorGroupOverlays) do
            local group = overlay.element
            if group and group.window == window then
                overlay:Hide()
                if overlay.inputTarget then overlay.inputTarget:Hide() end
            end
        end
        if controller.hoveredElement
            and controller.hoveredElement.window == window
        then
            controller.hoveredElement = nil
        end
        if controller.selectedElement
            and controller.selectedElement.window == window
        then
            StopDrag(false)
            DockWithoutSelection(window)
        else
            RefreshAllOverlayAppearances()
        end
    end)
    watcher:Show()
    controller.absoluteWindowLifecycles[window] = watcher
    local refresh = function() RefreshWindowOverlays(window) end
    for _, method in ipairs({
        "SetPoint", "SetScale", "SetSize", "StopMovingOrSizing",
    }) do
        if type(window[method]) == "function" then hooksecurefunc(window, method, refresh) end
    end
end

local function CreateOverlay(element)
    local usesAbsoluteBounds = element.kind == "TAB_GROUP"
        or (element.composition and element.composition.mode == "COMPOSITE")
        or type(element.highlightRegions) == "table"
        or type(element.highlightRegions) == "function"
        or type(element.getHighlightBounds) == "function"
    local parent = UIParent
    if not usesAbsoluteBounds then
        parent = element.target and element.target.GetParent
            and element.target:GetParent() or element.window
    end

    -- Visual presentation and interaction ownership are intentionally split.
    -- The highlight follows the element's real frame order but never owns the
    -- mouse. A separate input target lives in the element's native window tree,
    -- so Blizzard dialogs and unrelated windows can occlude it normally.
    local overlay = CreateFrame("Frame", nil, parent)
    overlay.usesAbsoluteBounds = usesAbsoluteBounds
    overlay.nskinSkinningOverlay = true
    overlay:EnableMouse(false)
    ConfigureVisualOverlayStacking(overlay, element)
    overlay.texture = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.texture:SetAllPoints()
    overlay.texture:SetColorTexture(unpack(TRANSPARENT))
    overlay.border = NSkin:CreatePixelBorder(
        overlay, "NSkinSkinningModeHighlight", 1,
        NSkin:GetStyle("skinningMode").hover, false, overlay
    )
    NSkin:SetPixelBorderShown(overlay.border, false)

    local inputTarget = CreateFrame("Button", nil, UIParent)
    inputTarget.nskinSkinningInput = true
    inputTarget.nskinSkinningElement = element
    inputTarget:RegisterForClicks("LeftButtonUp")
    inputTarget:EnableMouse(not controller.modalInputBlocked)
    if inputTarget.SetPropagateMouseMotion then
        inputTarget:SetPropagateMouseMotion(true)
    end
    if inputTarget.SetPropagateMouseClicks then
        inputTarget:SetPropagateMouseClicks(true)
    end
    ConfigureInputOverlayStacking(inputTarget, element)
    -- Every semantic element, including WINDOW, owns its complete editor
    -- bounds. Registered child hit targets sit above the WINDOW fallback.
    inputTarget:SetAllPoints(overlay)
    overlay.inputTarget = inputTarget

    local function SetHovered(hovered)
        local editorElement = GetEditorElement(element)
        overlay.hovered = hovered == true or nil
        if overlay.hovered then
            controller.hoveredElement = editorElement
        elseif controller.hoveredElement == editorElement then
            if not (editorElement and editorElement.isAnchorGroup
                and IsPointerWithinElementBounds(editorElement))
            then
                controller.hoveredElement = nil
            end
        end
        RefreshOverlayAppearance(element)
        RefreshWindowFallbackAppearance(element.window)
        local parentElement = NSkin:GetCompositionParent(element)
        if parentElement then RefreshOverlayAppearance(parentElement) end
        local selected = controller.selectedElement
        if selected and NSkin:GetCompositionParent(selected) == element then
            RefreshOverlayAppearance(selected)
        end
    end

    local function RefreshInputEligibility(self)
        ConfigureInputOverlayStacking(self, element)
        ConfigureVisualOverlayStacking(overlay, element)
        local interactive = NSkin:IsSkinningOverlayInteractive(element, self)
        if self.SetPropagateMouseClicks then
            self:SetPropagateMouseClicks(not interactive)
        end
        SetHovered(interactive)
        return interactive
    end

    inputTarget:SetScript("OnEnter", function(self)
        RefreshInputEligibility(self)
    end)
    inputTarget:SetScript("OnLeave", function()
        SetHovered(false)
    end)

    local function ResolvePointerElement()
        if not _G.GetCursorPosition then return element end
        local cursorX, cursorY = _G.GetCursorPosition()
        local parentScale = UIParent and UIParent:GetEffectiveScale() or 1
        if not cursorX or not cursorY or not parentScale or parentScale == 0 then
            return element
        end
        cursorX, cursorY = cursorX / parentScale, cursorY / parentScale
        local best, bestPriority, bestArea
        for _, candidate in pairs(controller.overlayElements) do
            if candidate.kind ~= "WINDOW" and candidate.window == element.window
                and NSkin:IsSkinningElementEditable(candidate)
            then
                local left, right, bottom, top =
                    NSkin:GetSkinningElementBounds(candidate)
                if left and cursorX >= left and cursorX <= right
                    and cursorY >= bottom and cursorY <= top
                then
                    local priority = (tonumber(candidate.priority) or 0)
                        + (candidate.compositionParentID and 1000 or 0)
                    local area = math.max(0, right - left)
                        * math.max(0, top - bottom)
                    -- Development selection policy: children win over their
                    -- Container. Structure itself makes no selection decision.
                    if not best or candidate.compositionParentID == best.id
                        or (best.compositionParentID ~= candidate.id
                            and (priority > bestPriority
                                or (priority == bestPriority and area < bestArea)))
                    then
                        best, bestPriority, bestArea =
                            candidate, priority, area
                    end
                end
            end
        end
        return best or element
    end

    inputTarget:SetScript("OnMouseDown", function(self)
        RefreshInputEligibility(self)
    end)
    inputTarget:SetScript("OnClick", function(self)
        if not RefreshInputEligibility(self) then return end
        SelectElement(ResolvePointerElement())
    end)
    if element.kind == "TAB_GROUP" or element.draggable then
        inputTarget:RegisterForDrag("LeftButton")
        inputTarget:SetScript("OnDragStart", function(self)
            if not RefreshInputEligibility(self) then return end
            local pointerElement = ResolvePointerElement()
            SelectElement(pointerElement)
            if GetEditorElement(pointerElement) == pointerElement
                and (pointerElement.kind == "TAB_GROUP" or pointerElement.draggable)
            then
                BeginDrag(pointerElement)
            end
        end)
        inputTarget:SetScript("OnDragStop", function() StopDrag(true) end)
    end

    overlay:SetScript("OnShow", function(self)
        if not controller.activatingOverlays then
            NSkin:MarkSkinningWindowActive(element.window)
        end
        AnchorOverlay(self, element)
        ConfigureVisualOverlayStacking(self, element)
        ConfigureInputOverlayStacking(inputTarget, element)
        RefreshOverlayAppearance(element)
    end)
    overlay:SetScript("OnHide", function()
        inputTarget:Hide()
        if controller.hoveredElement == GetEditorElement(element) then
            controller.hoveredElement = nil
            overlay.hovered = nil
            local parentElement = NSkin:GetCompositionParent(element)
            if parentElement then RefreshOverlayAppearance(parentElement) end
        end
        if controller.enabled and controller.selectedElement == element
            and (not element.window:IsShown()
                or (element.target and element.target.IsVisible
                    and not element.target:IsVisible()))
        then
            StopDrag(false)
            DockWithoutSelection(element.window)
        end
    end)

    overlay:Hide()
    inputTarget:Hide()
    controller.overlays[element.id] = overlay
    controller.overlayElements[element.id] = element
    EnsureAbsoluteWindowLifecycle(element.window)
    return overlay
end

local function ShowElementOverlay(element)
    if not controller or not controller.enabled then return end
    local overlay = controller.overlays[element.id] or CreateOverlay(element)
    if not NSkin:IsSkinningElementEditable(element) then
        SetElementOverlayShown(overlay, false)
        return
    end
    local anchored = AnchorOverlay(overlay, element)
    RefreshOverlayAppearance(element)
    -- Window-parented overlays can remain logically shown and inherit window
    -- visibility. UIParent overlays must be hidden explicitly with the window.
    SetElementOverlayShown(overlay, anchored
        and (not overlay.usesAbsoluteBounds or element.window:IsShown()))
    local editorElement = GetEditorElement(element)
    if editorElement ~= element then RefreshAnchorGroupOverlay(editorElement) end
    if not controller.selectedElement and element.window:IsShown() then DockInspector(element) end
end

local function HandleSkinningElementRegistered(_, element)
    ShowElementOverlay(element)
    local editorElement = GetEditorElement(element)
    if controller and controller.selectedElement == editorElement then
        controller.dockedWindow:Refresh(editorElement)
    end
    if controller and controller.selectedElement == editorElement
        and NSkin.RefreshSkinningDebugInspector
    then
        NSkin:RefreshSkinningDebugInspector(editorElement,
            controller.dockedWindow.frame)
    end
end

local function HandleElementBoundsChanged(_, element)
    local overlay = controller and controller.overlays[element.id]
    if not overlay then return end
    local editorElement = GetEditorElement(element)
    if not NSkin:IsSkinningElementEditable(element)
        or (overlay.usesAbsoluteBounds and not element.window:IsShown())
    then
        SetElementOverlayShown(overlay, false)
        if editorElement ~= element then
            RefreshAnchorGroupOverlay(editorElement)
        end
        if controller.selectedElement == element then
            DockWithoutSelection()
        end
        return
    end
    if AnchorOverlay(overlay, element) then
        SetElementOverlayShown(overlay, true)
    else
        SetElementOverlayShown(overlay, false)
        if controller.selectedElement == element then DockWithoutSelection() end
    end
    if editorElement ~= element then RefreshAnchorGroupOverlay(editorElement) end
    if controller.selectedElement == editorElement
        and NSkin.RefreshSkinningDebugInspector
    then
        NSkin:RefreshSkinningDebugInspector(editorElement,
            controller.dockedWindow.frame)
    end
end

local function CreateController()
    if controller then return controller end
    controller = {
        overlays = {},
        overlayElements = {},
        anchorGroupOverlays = {},
        gridPools = setmetatable({}, { __mode = "k" }),
        absoluteWindowLifecycles = setmetatable({}, { __mode = "k" }),
        previewOptions = { preview = true, suppressNotify = true },
    }

    NSkin:CreateDockedWindow(controller)

    local popupCount = tonumber(_G.STATICPOPUP_NUMDIALOGS) or 4
    for index = 1, popupCount do
        local popup = _G["StaticPopup" .. index]
        if popup and popup.HookScript then
            popup:HookScript("OnShow", RefreshModalInputOwnership)
            popup:HookScript("OnHide", RefreshModalInputOwnership)
        end
    end
    RefreshModalInputOwnership()

    local ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetFrameLevel(101)
    ghost.texture = ghost:CreateTexture(nil, "BACKGROUND")
    ghost.texture:SetAllPoints()
    ghost:Hide()
    controller.ghost = ghost

    local dragHighlight = CreateFrame("Frame", nil, UIParent)
    dragHighlight:SetFrameStrata("TOOLTIP")
    dragHighlight:SetFrameLevel(103)
    dragHighlight.border = NSkin:CreatePixelBorder(
        dragHighlight, "NSkinSkinningModeDragHighlight", 1,
        { 1, 1, 1, 1 }, true, dragHighlight
    )
    dragHighlight:Hide()
    controller.dragHighlight = dragHighlight

    controller.dragFrame = CreateFrame("Frame")
    controller.eventFrame = CreateFrame("Frame")
    controller.eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then
            NSkin:SetSkinningModeEnabled(false)
        elseif event == "PLAYER_REGEN_ENABLED" and controller.pendingRollback then
            local rollback = controller.pendingRollback
            controller.pendingRollback = nil
            ApplyElementPlacement(rollback.element, rollback.placement)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        end
    end)
    return controller
end

function NSkin:RefreshSkinningModeAppearance(change)
    if not controller or not controller.enabled then return end
    if change and change.scope == "element" then
        local selected = controller.selectedElement
        if selected and selected.id == change.elementID
            and self:ShouldRefreshSkinningModeInspector(change, selected.id)
        then
            controller.dockedWindow:Refresh(selected)
        end
        if selected and selected.id == change.elementID
            and self.RefreshSkinningDebugInspector
        then
            self:RefreshSkinningDebugInspector(selected,
                controller.dockedWindow.frame)
        end
        return
    end
    controller.dockedWindow:RefreshAppearance()
    if self.RefreshSkinningDebugInspector then
        self:RefreshSkinningDebugInspector(controller.selectedElement,
            controller.dockedWindow.frame)
    end
end

function NSkin:SetSkinningModeEnabled(enabled)
    enabled = enabled == true
    if enabled and _G.InCombatLockdown and _G.InCombatLockdown() then
        self:Print("Skinning Mode cannot be activated during combat.")
        return false
    end
    if not enabled and not controller then return true end

    CreateController()
    if controller.enabled == enabled then return true end
    controller.enabled = enabled
    if enabled then
        self:RefreshSkinningModeAppearance()
        self:RegisterComponentCallback(
            "SkinningElementRegistered", HandleSkinningElementRegistered, controller
        )
        self:RegisterComponentCallback(
            "TabGroupLayoutApplied", HandleElementBoundsChanged, controller
        )
        self:RegisterComponentCallback(
            "SkinningElementBoundsChanged", HandleElementBoundsChanged, controller
        )
        controller.dockedWindow.frame:Show()
        DockWithoutSelection()
        RefreshModalInputOwnership()
        controller.activatingOverlays = true
        self:ForEachRegisteredSkinningElement(ShowElementOverlay)
        controller.activatingOverlays = nil
        controller.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:Print("Skinning Mode enabled. Select a highlighted element.")
    else
        StopDrag(false)
        self:UnregisterComponentCallbacks(controller)
        controller.eventFrame:UnregisterAllEvents()
        if controller.pendingRollback then
            controller.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
        for _, overlay in pairs(controller.overlays) do
            SetElementOverlayShown(overlay, false)
        end
        for _, overlay in pairs(controller.anchorGroupOverlays) do
            overlay:Hide()
            if overlay.inputTarget then overlay.inputTarget:Hide() end
        end
        controller.dockedWindow.frame:Hide()
        if self.HideSkinningDebugInspector then
            self:HideSkinningDebugInspector()
        end
        controller.selectedElement = nil
        self:Print("Skinning Mode disabled.")
    end
    return true
end

function NSkin:ToggleSkinningMode()
    return self:SetSkinningModeEnabled(not (controller and controller.enabled))
end
