local _, NSkin = ...

local controller
local GRID_SIZES = { 2, 4, 8, 16 }
local VALID_GRID_SIZES = { [2] = true, [4] = true, [8] = true, [16] = true }
local TRANSPARENT = { 0, 0, 0, 0 }
local StopDrag
local RefreshGrid

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

local function CreateLabel(parent, text, point, relativeTo, relativePoint, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    label:SetText(text)
    return label
end

local function CreateButton(parent, text, width, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 60, 22)
    NSkin:SkinFlatButton(button, text, nil, nil, 12)
    button:SetScript("OnClick", callback)
    return button
end

local function GetCursorUIPosition()
    local scale = UIParent:GetEffectiveScale()
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
    local visible = selected or (not controller.dragging and overlay.hovered == true)
    overlay.texture:SetColorTexture(unpack(visible and style.highlight or TRANSPARENT))
    NSkin:SetPixelBorderColor(overlay.border, unpack(style.hover))
    NSkin:SetPixelBorderShown(overlay.border, visible)
end

local function RefreshAllOverlayAppearances()
    for _, element in pairs(controller.overlayElements) do
        RefreshOverlayAppearance(element)
    end
end

local function ResizeInspector(view)
    local inspector = controller.inspector
    local contentHeight = view and view:GetHeight() or 1
    local screenHeight = UIParent:GetHeight() or 700
    local maximumHeight = math.max(180, math.min(600, screenHeight - 40))
    inspector:SetHeight(math.min(maximumHeight, math.max(174, contentHeight + 136)))
    controller.scrollChild:SetHeight(math.max(1, contentHeight))
    controller.scrollFrame:SetVerticalScroll(0)
end

local function LoadEditorOptions(element)
    for _, view in pairs(controller.optionViews) do
        view:SetContext(nil)
        view:Hide()
    end
    local id = element and element.editorOptions
    if not id then
        ResizeInspector(nil)
        return
    end
    local view = controller.optionViews[id]
    if not view then
        view = NSkin:CreateOptionGroupView(controller.scrollChild, id, "COMPACT", element)
        if not view then
            ResizeInspector(nil)
            return
        end
        view:SetPoint("TOPLEFT", controller.scrollChild, "TOPLEFT", 0, 0)
        controller.optionViews[id] = view
    else
        view:SetContext(element)
    end
    view:Show()
    ResizeInspector(view)
end

local function RefreshInspector()
    if not controller then return end
    local element = controller.selectedElement
    controller.inspector.selection:SetText(
        element and ("Selected: " .. (element.label or element.id)) or "Select an element"
    )
    LoadEditorOptions(element)
end

local function DockInspector(element)
    local inspector = controller.inspector
    local window = element.window
    inspector:ClearAllPoints()
    local screenRight = UIParent:GetRight() or GetScreenWidth()
    local roomOnRight = screenRight - (window:GetRight() or 0)
    if roomOnRight >= inspector:GetWidth() + 12 then
        inspector:SetPoint("TOPLEFT", window, "TOPRIGHT", 8, 0)
    else
        inspector:SetPoint("TOPRIGHT", window, "TOPLEFT", -8, 0)
    end
end

local function DockWithoutSelection(excludedWindow)
    local previous = controller.selectedElement
    controller.selectedElement = nil
    if previous then RefreshOverlayAppearance(previous) end
    local visibleElement
    NSkin:ForEachRegisteredSkinningElement(function(element)
        if not visibleElement and element.window ~= excludedWindow and element.window:IsShown() then
            visibleElement = element
        end
    end)
    if visibleElement then
        DockInspector(visibleElement)
    else
        controller.inspector:ClearAllPoints()
        controller.inspector:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    RefreshInspector()
end

local function SelectElement(element)
    if not element then return end
    local previous = controller.selectedElement
    controller.selectedElement = element
    if previous and previous ~= element then RefreshOverlayAppearance(previous) end
    RefreshOverlayAppearance(element)
    DockInspector(element)
    RefreshInspector()
end

local function RoundToGrid(value, size)
    if value >= 0 then return math.floor(value / size + 0.5) * size end
    return math.ceil(value / size - 0.5) * size
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

RefreshGrid = function(window)
    local grid = controller.grid
    local visualGridSize = 32
    local width, height = window:GetWidth(), window:GetHeight()
    local marginX, marginY = 30, 30
    grid:ClearAllPoints()
    grid:SetPoint("TOPLEFT", window, "TOPLEFT", -marginX, marginY)
    grid:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", marginX, -marginY)
    local style = NSkin:GetStyle("skinningMode")
    local firstX = math.ceil(-marginX / visualGridSize)
    local lastX = math.floor((width + marginX) / visualGridSize)
    local verticalCount = 0
    for gridIndex = firstX, lastX do
        verticalCount = verticalCount + 1
        local line = controller.verticalGridLines[verticalCount]
        if not line then
            line = grid:CreateTexture(nil, "OVERLAY")
            controller.verticalGridLines[verticalCount] = line
        end
        local x = gridIndex * visualGridSize
        line:ClearAllPoints()
        line:SetPoint("TOP", grid, "TOP", x - width / 2, 0)
        line:SetPoint("BOTTOM", grid, "BOTTOM", x - width / 2, 0)
        line:SetWidth(1)
        line:SetColorTexture(unpack(style.activeDropZone))
        line:Show()
    end
    for i = verticalCount + 1, #controller.verticalGridLines do
        controller.verticalGridLines[i]:Hide()
    end
    local firstY = math.ceil(-marginY / visualGridSize)
    local lastY = math.floor((height + marginY) / visualGridSize)
    local horizontalCount = 0
    for gridIndex = firstY, lastY do
        horizontalCount = horizontalCount + 1
        local line = controller.horizontalGridLines[horizontalCount]
        if not line then
            line = grid:CreateTexture(nil, "OVERLAY")
            controller.horizontalGridLines[horizontalCount] = line
        end
        local y = -gridIndex * visualGridSize
        line:ClearAllPoints()
        line:SetPoint("LEFT", grid, "LEFT", 0, y + height / 2)
        line:SetPoint("RIGHT", grid, "RIGHT", 0, y + height / 2)
        line:SetHeight(1)
        line:SetColorTexture(unpack(style.activeDropZone))
        line:Show()
    end
    for i = horizontalCount + 1, #controller.horizontalGridLines do
        controller.horizontalGridLines[i]:Hide()
    end
    controller.borderLeft:ClearAllPoints()
    controller.borderRight:ClearAllPoints()
    controller.borderTop:ClearAllPoints()
    controller.borderBottom:ClearAllPoints()
    controller.borderLeft:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    controller.borderLeft:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
    controller.borderRight:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    controller.borderRight:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    controller.borderTop:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    controller.borderTop:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    controller.borderBottom:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
    controller.borderBottom:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    grid:Show()
end

local function UpdateDrag()
    local element = controller.selectedElement
    local window = element and element.window
    if not window then return end
    local cursorX, cursorY = GetCursorUIPosition()
    local localX = cursorX - controller.grabOffsetX - window:GetLeft()
    local localY = cursorY + controller.grabOffsetY - window:GetTop()
    if not IsShiftKeyDown() then
        local size = NSkin:GetSkinningGridSize()
        local width, height = window:GetWidth(), window:GetHeight()
        local ghostWidth, ghostHeight = controller.ghost:GetWidth(), controller.ghost:GetHeight()
        local threshold = math.max(6, size)
        local snappedX, borderSnappedX = SnapToNearest(localX, threshold,
            0, -ghostWidth, width, width - ghostWidth)
        local snappedY, borderSnappedY = SnapToNearest(localY, threshold,
            0, ghostHeight, -height, -height + ghostHeight)
        localX = borderSnappedX and snappedX or RoundToGrid(localX, size)
        localY = borderSnappedY and snappedY or RoundToGrid(localY, size)
    end
    controller.gridX, controller.gridY = localX, localY
    controller.ghost:ClearAllPoints()
    controller.ghost:SetPoint("TOPLEFT", window, "TOPLEFT", localX, localY)
end

local function BeginDrag(element)
    if not element or (element.kind ~= "TAB_GROUP" and not element.draggable)
        or controller.dragging then return end
    controller.dragging = true
    RefreshAllOverlayAppearances()
    local overlay = controller.overlays[element.id]
    controller.ghost:SetSize(math.max(80, overlay and overlay:GetWidth() or 80),
        math.max(20, overlay and overlay:GetHeight() or 20))
    controller.ghost.texture:SetColorTexture(unpack(NSkin:GetStyle("skinningMode").ghost))
    controller.ghost:Show()
    local cursorX, cursorY = GetCursorUIPosition()
    local left = overlay and overlay:GetLeft() or cursorX
    local top = overlay and overlay:GetTop() or cursorY
    controller.grabOffsetX = cursorX - left
    controller.grabOffsetY = top - cursorY
    RefreshGrid(element.window)
    UpdateDrag()
    controller.dragFrame:SetScript("OnUpdate", UpdateDrag)
end

StopDrag = function(apply)
    if not controller.dragging then return end
    local gridX, gridY = controller.gridX, controller.gridY
    controller.dragging = false
    controller.dragFrame:SetScript("OnUpdate", nil)
    controller.ghost:Hide()
    controller.grid:Hide()
    RefreshAllOverlayAppearances()
    if apply and gridX and gridY then
        local element = controller.selectedElement
        local view = element and controller.optionViews[element.editorOptions]
        local placement = view and view.definition.get(view.context)
            or NSkin:GetTabPlacement()
        placement.mode = "GRID"
        placement.point = "TOPLEFT"
        placement.relativePoint = "TOPLEFT"
        placement.x, placement.y = gridX, gridY
        placement.alongOffset, placement.edgeOffset = gridX, gridY
        placement.relativeTo = nil
        placement.offsetX, placement.offsetY = nil, nil
        if view then
            view:SetValues(placement)
        elseif element and type(element.setPlacement) == "function" then
            element.setPlacement(element, placement)
        elseif element and type(element.applyPlacement) == "function" then
            element.applyPlacement(element, placement)
        end
    end
end

local function CreateOverlay(element)
    local overlay = CreateFrame("Button", nil, element.window)
    overlay:SetFrameStrata("DIALOG")
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
    overlay:SetScript("OnClick", function() SelectElement(element) end)
    if element.kind == "TAB_GROUP" or element.draggable then
        overlay:RegisterForDrag("LeftButton")
        overlay:SetScript("OnDragStart", function()
            SelectElement(element)
            BeginDrag(element)
        end)
        overlay:SetScript("OnDragStop", function() StopDrag(true) end)
    end
    overlay:SetScript("OnShow", function(self)
        AnchorOverlay(self, element)
        RefreshOverlayAppearance(element)
    end)
    overlay:SetScript("OnHide", function()
        if controller.enabled and controller.selectedElement == element
            and not element.window:IsShown()
        then
            StopDrag(false)
            DockWithoutSelection(element.window)
        end
    end)
    controller.overlays[element.id] = overlay
    controller.overlayElements[element.id] = element
    return overlay
end

local function ShowElementOverlay(element)
    if not controller or not controller.enabled then return end
    local overlay = controller.overlays[element.id] or CreateOverlay(element)
    if not NSkin:IsSkinningElementEditable(element) then
        overlay:Hide()
        return
    end
    AnchorOverlay(overlay, element)
    RefreshOverlayAppearance(element)
    -- Keep it logically shown while its parent is hidden so its effective
    -- OnShow can re-anchor after Blizzard lays out the window.
    overlay:Show()
    if not controller.selectedElement and element.window:IsShown() then DockInspector(element) end
end

local function HandleSkinningElementRegistered(_, element)
    ShowElementOverlay(element)
end

local function HandleElementBoundsChanged(_, element)
    local overlay = controller and controller.overlays[element.id]
    if not overlay then return end
    if not NSkin:IsSkinningElementEditable(element) then
        overlay:Hide()
        return
    end
    if AnchorOverlay(overlay, element) then overlay:Show() else overlay:Hide() end
end

local function CreateController()
    if controller then return controller end
    controller = {
        optionViews = {},
        overlays = {},
        overlayElements = {},
        verticalGridLines = {},
        horizontalGridLines = {},
    }

    local inspector = CreateFrame("Frame", nil, UIParent)
    inspector:SetSize(250, 130)
    inspector:SetFrameStrata("DIALOG")
    NSkin:SkinWindow(inspector)
    NSkin:SkinWindowHeader(inspector)
    CreateLabel(inspector, "Skinning Mode", "TOPLEFT", inspector, "TOPLEFT", 12, -5)
    local close = CreateButton(inspector, "x", 22, function()
        NSkin:SetSkinningModeEnabled(false)
    end)
    close:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", 0, 0)
    inspector.selection = CreateLabel(
        inspector, "Select an element", "TOPLEFT", inspector, "TOPLEFT", 12, -34
    )
    local gridLabel = CreateLabel(
        inspector, "Grid size", "TOPLEFT", inspector, "TOPLEFT", 12, -58
    )
    local gridDropdown = CreateFrame(
        "DropdownButton", nil, inspector, "WowStyle1DropdownTemplate"
    )
    gridDropdown:SetSize(110, 24)
    gridDropdown:SetPoint("LEFT", gridLabel, "RIGHT", 8, 0)
    gridDropdown:SetDefaultText("8 px")
    gridDropdown:SetupMenu(function(_, rootDescription)
        for i = 1, #GRID_SIZES do
            local size = GRID_SIZES[i]
            rootDescription:CreateRadio(size .. " px",
                function(value) return NSkin:GetSkinningGridSize() == value end,
                function(value) NSkin:SetSkinningGridSize(value) end, size)
        end
    end)
    controller.gridDropdown = gridDropdown
    local gridHint = CreateLabel(
        inspector, "Hold Shift for free movement", "TOPLEFT", inspector, "TOPLEFT", 12, -84
    )
    gridHint:SetFontObject(GameFontHighlightSmall)
    controller.inspector = inspector

    local scrollFrame = CreateFrame("ScrollFrame", nil, inspector)
    scrollFrame:SetPoint("TOPLEFT", inspector, "TOPLEFT", 24, -110)
    scrollFrame:SetPoint("BOTTOMRIGHT", inspector, "BOTTOMRIGHT", -24, 14)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local maximum = math.max(0, controller.scrollChild:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.max(0, math.min(maximum,
            self:GetVerticalScroll() - delta * 30)))
    end)
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(202, 1)
    scrollFrame:SetScrollChild(scrollChild)
    controller.scrollFrame = scrollFrame
    controller.scrollChild = scrollChild

    local ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetFrameLevel(101)
    ghost.texture = ghost:CreateTexture(nil, "BACKGROUND")
    ghost.texture:SetAllPoints()
    ghost:Hide()
    controller.ghost = ghost

    local grid = CreateFrame("Frame", nil, UIParent)
    grid:SetFrameStrata("TOOLTIP")
    grid:SetFrameLevel(100)
    grid:EnableMouse(false)
    grid:Hide()
    controller.grid = grid
    local borderColor = NSkin:GetStyle("skinningMode").activeDropZone
    local function CreateBorderLine(width, height)
        local line = grid:CreateTexture(nil, "OVERLAY")
        line:SetSize(width, height)
        line:SetColorTexture(unpack(borderColor))
        return line
    end
    controller.borderLeft = CreateBorderLine(3, 1)
    controller.borderRight = CreateBorderLine(3, 1)
    controller.borderTop = CreateBorderLine(1, 3)
    controller.borderBottom = CreateBorderLine(1, 3)

    controller.dragFrame = CreateFrame("Frame")
    controller.eventFrame = CreateFrame("Frame")
    controller.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then NSkin:SetSkinningModeEnabled(false) end
    end)
    inspector:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    inspector:Hide()
    return controller
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
        self:RegisterComponentCallback(
            "SkinningElementRegistered", HandleSkinningElementRegistered, controller
        )
        self:RegisterComponentCallback(
            "TabGroupLayoutApplied", HandleElementBoundsChanged, controller
        )
        self:RegisterComponentCallback(
            "SkinningElementBoundsChanged", HandleElementBoundsChanged, controller
        )
        controller.inspector:Show()
        DockWithoutSelection()
        self:ForEachRegisteredSkinningElement(ShowElementOverlay)
        controller.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:Print("Skinning Mode enabled. Select a highlighted element.")
    else
        StopDrag(false)
        self:UnregisterComponentCallbacks(controller)
        controller.eventFrame:UnregisterAllEvents()
        for _, overlay in pairs(controller.overlays) do overlay:Hide() end
        controller.inspector:Hide()
        controller.selectedElement = nil
        self:Print("Skinning Mode disabled.")
    end
    return true
end

function NSkin:ToggleSkinningMode()
    return self:SetSkinningModeEnabled(not (controller and controller.enabled))
end
