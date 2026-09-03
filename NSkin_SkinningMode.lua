local _, NSkin = ...

local controller
local GRID_SIZES = { 2, 4, 8, 16 }
local VALID_GRID_SIZES = { [2] = true, [4] = true, [8] = true, [16] = true }
local TRANSPARENT = { 0, 0, 0, 0 }
-- Keep semantic left/center/right placement internally, but hide its broad
-- visual zones until drag interaction is fully stabilized.
local SHOW_DROP_ALIGNMENT_ZONES = false
local StopDrag
local RefreshGrid
local HideGrid

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
    if not overlay.usesAbsoluteBounds
        and element and element.kind ~= "TAB_GROUP"
        and type(element.highlightRegions) ~= "table"
        and type(element.highlightRegions) ~= "function"
        and type(element.getHighlightBounds) ~= "function"
        and element.target and element.target.IsShown and element.target:IsShown()
    then
        -- Ordinary movable elements already expose the exact frame to
        -- highlight. Anchoring directly avoids applying a scaled window's
        -- coordinate conversion twice.
        local padding = tonumber(element.highlightPadding) or 0
        overlay:SetPoint("TOPLEFT", element.target, "TOPLEFT", -padding, padding)
        overlay:SetPoint("BOTTOMRIGHT", element.target, "BOTTOMRIGHT",
            padding, -padding)
        return true
    end
    local left, right, bottom, top = GetElementBounds(element)
    if not left then return false end
    overlay:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    overlay:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMLEFT", right, bottom)
    return true
end

local function RefreshOverlayAppearance(element)
    if not controller then return end
    local overlay = controller.overlays[element.id]
    if not overlay then return end
    local style = NSkin:GetStyle("skinningMode")
    local selected = controller.selectedElement == element
    local hovered = overlay.hovered == true
    -- dragHidden is transient. Never let an interrupted drag leave an
    -- otherwise selected/hovered element permanently invisible.
    local visible = not (controller.dragging and overlay.dragHidden)
        and (selected or (not controller.dragging and hovered))
    overlay.texture:SetColorTexture(unpack(visible and style.highlight or TRANSPARENT))
    NSkin:SetPixelBorderColor(overlay.border, unpack(style.hover))
    NSkin:SetPixelBorderShown(overlay.border, visible)
end

local function RefreshAllOverlayAppearances()
    for _, element in pairs(controller.overlayElements) do
        RefreshOverlayAppearance(element)
    end
end

local function RefreshInspector()
    if controller and controller.dockedWindow then
        controller.dockedWindow:Refresh(controller.selectedElement)
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

local function SelectElement(element)
    if not element then return end
    if controller.dragging then StopDrag(false) end
    NSkin:MarkSkinningWindowActive(element.window)
    local previous = controller.selectedElement
    controller.selectedElement = element
    for id, overlay in pairs(controller.overlays) do
        if id ~= element.id then overlay.hovered = nil end
        overlay.dragHidden = nil
    end
    if previous ~= element then controller.dockedWindow:ResetScroll() end
    if previous and previous ~= element then RefreshOverlayAppearance(previous) end
    RefreshAllOverlayAppearances()
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
    for i = 1, #(pool.alignmentZones or {}) do pool.alignmentZones[i]:Hide() end
    controller.activeGridPool = nil
end

RefreshGrid = function(window)
    if controller.activeGridPool then HideGrid() end
    local pool = controller.gridPools[window]
    if not pool then
        pool = { vertical = {}, horizontal = {}, borders = {}, alignmentZones = {} }
        controller.gridPools[window] = pool
    end
    controller.activeGridPool = pool
    local visualGridSize = 32
    local width, height = window:GetWidth(), window:GetHeight()
    local marginX, marginY = 30, 30
    local style = NSkin:GetStyle("skinningMode")
    local gridAlpha = tonumber(style.gridAlpha) or 0.4
    if SHOW_DROP_ALIGNMENT_ZONES and #pool.alignmentZones == 0 then
        local labels = { "LEFT", "CENTER", "RIGHT" }
        for i = 1, 3 do
            local zone = CreateFrame("Frame", nil, window)
            zone:SetFrameLevel(window:GetFrameLevel() + 20)
            zone.texture = zone:CreateTexture(nil, "OVERLAY")
            zone.texture:SetAllPoints()
            zone.label = zone:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            zone.label:SetPoint("CENTER")
            zone.label:SetText(labels[i])
            zone.label:SetTextColor(1, 1, 1, 0.85)
            pool.alignmentZones[i] = zone
        end
    end
    if SHOW_DROP_ALIGNMENT_ZONES then
        for i = 1, 3 do
            local zone = pool.alignmentZones[i]
            zone:ClearAllPoints()
            zone:SetPoint("TOPLEFT", window, "TOPLEFT", (i - 1) * width / 3, 0)
            zone:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", i * width / 3, 0)
            zone.texture:SetColorTexture(style.activeDropZone[1],
                style.activeDropZone[2], style.activeDropZone[3], 0.05)
            zone:Show()
        end
    end
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
    if SHOW_DROP_ALIGNMENT_ZONES and controller.activeGridPool then
        for i = 1, 3 do
            local zone = controller.activeGridPool.alignmentZones[i]
            local alpha = i == alignmentIndex and 0.22 or 0.05
            local color = NSkin:GetStyle("skinningMode").activeDropZone
            zone.texture:SetColorTexture(color[1], color[2], color[3], alpha)
            zone.label:SetAlpha(i == alignmentIndex and 1 or 0.45)
        end
    end
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
        or controller.dragging then return end
    controller.dragging = true
    controller.dragMouseState = {}
    -- While dragging, only the selected overlay may receive mouse input.
    -- Other highlights otherwise steal the release/click and make a drag
    -- appear to select the window instead.
    for id, otherOverlay in pairs(controller.overlays) do
        local enabled = true
        if otherOverlay.IsMouseEnabled then
            enabled = otherOverlay:IsMouseEnabled()
        end
        local headerEnabled
        if otherOverlay.headerHitTarget then
            headerEnabled = otherOverlay.headerHitTarget:IsMouseEnabled()
            otherOverlay.headerHitTarget:EnableMouse(id == element.id)
        end
        controller.dragMouseState[id] = { overlay = enabled,
            header = headerEnabled }
        otherOverlay:EnableMouse(id == element.id)
    end
    local overlay = controller.overlays[element.id]
    local coordinateScale = 1
    if overlay and overlay.usesAbsoluteBounds then
        coordinateScale = UIParent:GetEffectiveScale() / element.window:GetEffectiveScale()
    end
    controller.dragWidth = math.max(1,
        (overlay and overlay:GetWidth() or 1) * coordinateScale)
    controller.dragHeight = math.max(1,
        (overlay and overlay:GetHeight() or 1) * coordinateScale)
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
    local left = overlay and overlay:GetLeft()
    local top = overlay and overlay:GetTop()
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
    if controller.dragMouseState then
        for id, state in pairs(controller.dragMouseState) do
            local otherOverlay = controller.overlays[id]
            if otherOverlay then
                otherOverlay:EnableMouse(state.overlay == true)
                if otherOverlay.headerHitTarget and state.header ~= nil then
                    otherOverlay.headerHitTarget:EnableMouse(state.header == true)
                end
            end
        end
        controller.dragMouseState = nil
    end
    controller.originalPlacement = nil
    controller.previewPlacement = nil
    controller.dropAlignmentIndex = nil
    controller.previewApplied = nil
    controller.previewX, controller.previewY = nil, nil
    RefreshElementInspectorViews(element)
    RefreshAllOverlayAppearances()
end

local function RefreshAbsoluteWindowOverlays(window)
    if not controller.enabled or not window:IsShown() then return end
    local selectionLost
    for id, element in pairs(controller.overlayElements) do
        local overlay = controller.overlays[id]
        if element.window == window and overlay and overlay.usesAbsoluteBounds then
            if NSkin:IsSkinningElementEditable(element)
                and AnchorOverlay(overlay, element)
            then
                overlay:Show()
            else
                overlay:Hide()
                if controller.selectedElement == element then selectionLost = true end
            end
        end
    end
    if selectionLost then DockWithoutSelection() end
end

local function EnsureAbsoluteWindowLifecycle(window)
    if controller.absoluteWindowLifecycles[window] then return end
    local watcher = CreateFrame("Frame", nil, window)
    watcher:SetScript("OnShow", function() RefreshAbsoluteWindowOverlays(window) end)
    watcher:SetScript("OnHide", function()
        for id, element in pairs(controller.overlayElements) do
            local overlay = controller.overlays[id]
            if element.window == window and overlay and overlay.usesAbsoluteBounds then
                overlay:Hide()
            end
        end
    end)
    watcher:Show()
    controller.absoluteWindowLifecycles[window] = watcher
    local refresh = function() RefreshAbsoluteWindowOverlays(window) end
    for _, method in ipairs({ "SetPoint", "SetScale", "SetSize", "StopMovingOrSizing" }) do
        if type(window[method]) == "function" then hooksecurefunc(window, method, refresh) end
    end
end

local function CreateOverlay(element)
    local usesAbsoluteBounds = element.kind == "TAB_GROUP"
        or element.movable == true
        or type(element.highlightRegions) == "table"
        or type(element.highlightRegions) == "function"
        or type(element.getHighlightBounds) == "function"
    local parent = UIParent
    if not usesAbsoluteBounds then
        parent = element.target and element.target.GetParent
            and element.target:GetParent() or element.window
    end
    local overlay = CreateFrame("Button", nil, parent)
    overlay.usesAbsoluteBounds = usesAbsoluteBounds
    -- A full-window hit target must never eclipse its registered children.
    -- Frame levels are only reliably comparable within the same frame strata,
    -- especially when overlays have different parents, so element overlays use
    -- a dedicated higher strata instead of relying on priority alone.
    overlay:SetFrameStrata(element.kind == "WINDOW"
        and "DIALOG" or "FULLSCREEN_DIALOG")
    -- The window owns hover/clicks only in empty space. Its click handler
    -- resolves the highest-priority registered child under the cursor, while
    -- child overlays themselves live on the higher FULLSCREEN_DIALOG strata.
    -- This preserves window selection without stealing element selection.
    overlay:EnableMouse(true)
    overlay:SetFrameLevel(math.max(1,
        (element.window:GetFrameLevel() or 0) + 10 + (element.priority or 0)))
    overlay:RegisterForClicks("LeftButtonUp")
    overlay.texture = overlay:CreateTexture(nil, "BACKGROUND")
    overlay.texture:SetAllPoints()
    overlay.texture:SetColorTexture(unpack(TRANSPARENT))
    overlay.border = NSkin:CreatePixelBorder(
        overlay, "NSkinSkinningModeHighlight", 1,
        NSkin:GetStyle("skinningMode").hover, false, overlay
    )
    NSkin:SetPixelBorderShown(overlay.border, false)
    overlay:SetScript("OnEnter", function(self)
        self.hovered = true
        RefreshOverlayAppearance(element)
    end)
    overlay:SetScript("OnLeave", function(self)
        self.hovered = nil
        RefreshOverlayAppearance(element)
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
                local left, right, bottom, top = GetElementBounds(candidate)
                if left and cursorX >= left and cursorX <= right
                    and cursorY >= bottom and cursorY <= top
                then
                    local priority = tonumber(candidate.priority) or 0
                    local area = math.max(0, right - left) * math.max(0, top - bottom)
                    if not best or priority > bestPriority
                        or (priority == bestPriority and area < bestArea)
                    then
                        best, bestPriority, bestArea = candidate, priority, area
                    end
                end
            end
        end
        return best or element
    end

    overlay:SetScript("OnClick", function()
        SelectElement(ResolvePointerElement())
    end)
    if element.kind == "WINDOW" then
        local headerHitTarget = CreateFrame("Button", nil, overlay)
        headerHitTarget:SetPoint("TOPLEFT")
        headerHitTarget:SetPoint("TOPRIGHT")
        headerHitTarget:SetHeight(22)
        headerHitTarget:RegisterForClicks("LeftButtonUp")
        headerHitTarget:SetScript("OnClick", function() SelectElement(element) end)
        headerHitTarget:SetScript("OnEnter", function()
            overlay.hovered = true
            RefreshOverlayAppearance(element)
        end)
        headerHitTarget:SetScript("OnLeave", function()
            overlay.hovered = nil
            RefreshOverlayAppearance(element)
        end)
        overlay.headerHitTarget = headerHitTarget
    end
    if element.kind == "TAB_GROUP" or element.draggable then
        overlay:RegisterForDrag("LeftButton")
        overlay:SetScript("OnDragStart", function()
            local pointerElement = ResolvePointerElement()
            SelectElement(pointerElement)
            if pointerElement.kind == "TAB_GROUP" or pointerElement.draggable then
                BeginDrag(pointerElement)
            end
        end)
        overlay:SetScript("OnDragStop", function() StopDrag(true) end)
    end
    overlay:SetScript("OnShow", function(self)
        if not controller.activatingOverlays then
            NSkin:MarkSkinningWindowActive(element.window)
        end
        AnchorOverlay(self, element)
        RefreshOverlayAppearance(element)
    end)
    overlay:SetScript("OnHide", function()
        if controller.enabled and controller.selectedElement == element
            and (not element.window:IsShown()
                or (element.target and element.target.IsVisible
                    and not element.target:IsVisible()))
        then
            StopDrag(false)
            DockWithoutSelection(element.window)
        end
    end)
    controller.overlays[element.id] = overlay
    controller.overlayElements[element.id] = element
    if usesAbsoluteBounds then EnsureAbsoluteWindowLifecycle(element.window) end
    return overlay
end

local function ShowElementOverlay(element)
    if not controller or not controller.enabled then return end
    local overlay = controller.overlays[element.id] or CreateOverlay(element)
    if not NSkin:IsSkinningElementEditable(element) then
        overlay:Hide()
        return
    end
    local anchored = AnchorOverlay(overlay, element)
    RefreshOverlayAppearance(element)
    -- Window-parented overlays can remain logically shown and inherit window
    -- visibility. UIParent overlays must be hidden explicitly with the window.
    overlay:SetShown(anchored
        and (not overlay.usesAbsoluteBounds or element.window:IsShown()))
    if not controller.selectedElement and element.window:IsShown() then DockInspector(element) end
end

local function HandleSkinningElementRegistered(_, element)
    ShowElementOverlay(element)
end

local function HandleSkinningElementContextChanged(_, element)
    ShowElementOverlay(element)
    if controller and controller.selectedElement == element then
        DockInspector(element)
        RefreshInspector()
    end
end

local function HandleElementBoundsChanged(_, element)
    local overlay = controller and controller.overlays[element.id]
    if not overlay then return end
    if not NSkin:IsSkinningElementEditable(element)
        or (overlay.usesAbsoluteBounds and not element.window:IsShown())
    then
        overlay:Hide()
        if controller.selectedElement == element then
            DockWithoutSelection()
        end
        return
    end
    if AnchorOverlay(overlay, element) then
        overlay:Show()
    else
        overlay:Hide()
        if controller.selectedElement == element then DockWithoutSelection() end
    end
end

local function CreateController()
    if controller then return controller end
    controller = {
        overlays = {},
        overlayElements = {},
        gridPools = setmetatable({}, { __mode = "k" }),
        absoluteWindowLifecycles = setmetatable({}, { __mode = "k" }),
        previewOptions = { preview = true, suppressNotify = true },
    }

    NSkin:CreateDockedWindow(controller)

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

function NSkin:RefreshSkinningModeAppearance()
    if not controller or not controller.enabled then return end
    controller.dockedWindow:RefreshAppearance()
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
            "SkinningElementContextChanged",
            HandleSkinningElementContextChanged, controller
        )
        self:RegisterComponentCallback(
            "TabGroupLayoutApplied", HandleElementBoundsChanged, controller
        )
        self:RegisterComponentCallback(
            "SkinningElementBoundsChanged", HandleElementBoundsChanged, controller
        )
        controller.dockedWindow.frame:Show()
        DockWithoutSelection()
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
        for _, overlay in pairs(controller.overlays) do overlay:Hide() end
        controller.dockedWindow.frame:Hide()
        controller.selectedElement = nil
        self:Print("Skinning Mode disabled.")
    end
    return true
end

function NSkin:ToggleSkinningMode()
    return self:SetSkinningModeEnabled(not (controller and controller.enabled))
end
