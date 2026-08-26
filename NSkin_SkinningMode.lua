local _, NSkin = ...

local controller
local ALIGNMENT_ORDER = { "LEFT", "CENTER", "RIGHT" }
local EDGE_ORDER = { "TOP", "BOTTOM" }
local SIDE_ORDER = { "INSIDE", "OUTSIDE" }
local DROP_TARGETS = {}
for edgeIndex = 1, #EDGE_ORDER do
    for sideIndex = 1, #SIDE_ORDER do
        for alignmentIndex = 1, #ALIGNMENT_ORDER do
            local edge = EDGE_ORDER[edgeIndex]
            local side = SIDE_ORDER[sideIndex]
            local alignment = ALIGNMENT_ORDER[alignmentIndex]
            DROP_TARGETS[#DROP_TARGETS + 1] = {
                edge = edge,
                side = side,
                alignment = alignment,
                label = edge .. " " .. side .. " " .. alignment,
            }
        end
    end
end
local TRANSPARENT = { 0, 0, 0, 0 }
local StopDrag

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

local function PointInFrame(x, y, frame)
    local left, right = frame:GetLeft(), frame:GetRight()
    local bottom, top = frame:GetBottom(), frame:GetTop()
    return left and right and bottom and top
        and x >= left and x <= right and y >= bottom and y <= top
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
    inspector:SetHeight(math.min(maximumHeight, math.max(130, contentHeight + 92)))
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

local function UpdateDrag()
    local x, y = GetCursorUIPosition()
    controller.ghost:ClearAllPoints()
    controller.ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    controller.hoveredDropTarget = nil
    local style = NSkin:GetStyle("skinningMode")
    local hoveredZone
    local closestDistance
    for i = 1, #DROP_TARGETS do
        local target = DROP_TARGETS[i]
        local zone = controller.dropZones[i]
        local hovered = PointInFrame(x, y, zone)
        zone.texture:SetColorTexture(unpack(style.dropZone))
        if hovered then
            local zoneX, zoneY = zone:GetCenter()
            local distance = zoneX and zoneY
                and ((x - zoneX) * (x - zoneX) + (y - zoneY) * (y - zoneY))
            if distance and (not closestDistance or distance < closestDistance) then
                closestDistance = distance
                hoveredZone = zone
                controller.hoveredDropTarget = target
            end
        end
    end
    if hoveredZone then hoveredZone.texture:SetColorTexture(unpack(style.activeDropZone)) end
end

local function BeginDrag(element)
    if not element or element.kind ~= "TAB_GROUP" or controller.dragging then return end
    controller.dragging = true
    RefreshAllOverlayAppearances()
    local overlay = controller.overlays[element.id]
    controller.ghost:SetSize(math.max(80, overlay and overlay:GetWidth() or 80),
        math.max(20, overlay and overlay:GetHeight() or 20))
    controller.ghost.texture:SetColorTexture(unpack(NSkin:GetStyle("skinningMode").ghost))
    controller.ghost:Show()

    local window = element.window
    local zoneWidth = controller.ghost:GetWidth()
    local zoneHeight = controller.ghost:GetHeight()
    for i = 1, #DROP_TARGETS do
        local target = DROP_TARGETS[i]
        local zone = controller.dropZones[i]
        local verticalPoint
        if target.edge == "TOP" then
            verticalPoint = target.side == "INSIDE" and "TOP" or "BOTTOM"
        else
            verticalPoint = target.side == "INSIDE" and "BOTTOM" or "TOP"
        end
        zone:ClearAllPoints()
        zone:SetSize(zoneWidth, zoneHeight)
        if target.alignment == "LEFT" then
            zone:SetPoint(verticalPoint .. "LEFT", window, target.edge .. "LEFT", 0, 0)
        elseif target.alignment == "CENTER" then
            zone:SetPoint(verticalPoint, window, target.edge, 0, 0)
        else
            zone:SetPoint(verticalPoint .. "RIGHT", window, target.edge .. "RIGHT", 0, 0)
        end
        zone:Show()
    end
    controller.dragFrame:SetScript("OnUpdate", UpdateDrag)
end

StopDrag = function(apply)
    if not controller.dragging then return end
    local target = controller.hoveredDropTarget
    controller.dragging = false
    controller.dragFrame:SetScript("OnUpdate", nil)
    controller.ghost:Hide()
    for i = 1, #DROP_TARGETS do controller.dropZones[i]:Hide() end
    controller.hoveredDropTarget = nil
    RefreshAllOverlayAppearances()
    if apply and target then
        local placement = NSkin:GetTabPlacement()
        placement.edge = target.edge
        placement.side = target.side
        placement.alignment = target.alignment
        placement.alongOffset = 0
        placement.edgeOffset = 0
        local element = controller.selectedElement
        local view = element and controller.optionViews[element.editorOptions]
        if view then view:SetValues(placement) end
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
    if element.kind == "TAB_GROUP" then
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
    if AnchorOverlay(overlay, element) then overlay:Show() else overlay:Hide() end
end

local function CreateController()
    if controller then return controller end
    controller = {
        optionViews = {},
        overlays = {},
        overlayElements = {},
        dropZones = {},
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
    controller.inspector = inspector

    local scrollFrame = CreateFrame("ScrollFrame", nil, inspector)
    scrollFrame:SetPoint("TOPLEFT", inspector, "TOPLEFT", 24, -66)
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
    ghost.texture = ghost:CreateTexture(nil, "BACKGROUND")
    ghost.texture:SetAllPoints()
    ghost:Hide()
    controller.ghost = ghost

    for i = 1, #DROP_TARGETS do
        local zone = CreateFrame("Frame", nil, UIParent)
        zone:SetFrameStrata("TOOLTIP")
        zone.texture = zone:CreateTexture(nil, "BACKGROUND")
        zone.texture:SetAllPoints()
        zone.label = zone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        zone.label:SetPoint("CENTER")
        zone.label:SetText(DROP_TARGETS[i].label)
        zone:Hide()
        controller.dropZones[i] = zone
    end

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
