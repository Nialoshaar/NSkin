local _, NSkin = ...

local controller
local ALIGNMENT_ORDER = { "LEFT", "CENTER", "RIGHT" }
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

local function LoadEditorOptions(group)
    for _, view in pairs(controller.optionViews) do
        view:SetContext(nil)
        view:Hide()
    end
    local id = group and group.editorOptions
    if not id then return end
    local view = controller.optionViews[id]
    if not view then
        view = NSkin:CreateOptionGroupView(controller.inspector, id, "COMPACT", group)
        if not view then return end
        view:SetPoint("TOPLEFT", controller.inspector, "TOPLEFT", 24, -70)
        controller.optionViews[id] = view
    else
        view:SetContext(group)
    end
    view:Show()
end

local function RefreshInspector()
    if not controller then return end
    local group = controller.selectedGroup
    controller.inspector.selection:SetText(
        group and ("Selected : " .. (group.label or group.id)) or "Select an element"
    )
    LoadEditorOptions(group)
end

local function DockInspector(group)
    local inspector = controller.inspector
    inspector:ClearAllPoints()
    local screenRight = UIParent:GetRight() or GetScreenWidth()
    local roomOnRight = screenRight - (group.owner:GetRight() or 0)
    if roomOnRight >= inspector:GetWidth() + 12 then
        inspector:SetPoint("TOPLEFT", group.owner, "TOPRIGHT", 8, 0)
    else
        inspector:SetPoint("TOPRIGHT", group.owner, "TOPLEFT", -8, 0)
    end
end

local function DockWithoutSelection(excludedGroup)
    controller.selectedGroup = nil
    local visibleGroup
    NSkin:ForEachRegisteredTabGroup(function(group)
        if not visibleGroup and group ~= excludedGroup and group.owner:IsShown() then
            visibleGroup = group
        end
    end)
    if visibleGroup then
        DockInspector(visibleGroup)
    else
        controller.inspector:ClearAllPoints()
        controller.inspector:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    RefreshInspector()
end

local function SelectGroup(group)
    controller.selectedGroup = group
    DockInspector(group)
    RefreshInspector()
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

StopDrag = function(apply)
    if not controller.dragging then return end
    local alignment = controller.hoveredAlignment
    controller.dragging = false
    controller.dragFrame:SetScript("OnUpdate", nil)
    controller.ghost:Hide()
    for i = 1, #ALIGNMENT_ORDER do
        controller.dropZones[ALIGNMENT_ORDER[i]]:Hide()
    end
    controller.hoveredAlignment = nil
    if apply and alignment then
        local placement = NSkin:GetBottomTabPlacement()
        placement.alignment = alignment
        placement.alongOffset = 0
        local group = controller.selectedGroup
        local view = group and controller.optionViews[group.editorOptions]
        if view then view:SetValues(placement) end
    end
end

local function UpdateDrag()
    local x, y = GetCursorUIPosition()
    controller.ghost:ClearAllPoints()
    controller.ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    controller.hoveredAlignment = nil
    for i = 1, #ALIGNMENT_ORDER do
        local alignment = ALIGNMENT_ORDER[i]
        local zone = controller.dropZones[alignment]
        local hovered = PointInFrame(x, y, zone)
        zone.texture:SetColorTexture(0, 0.65, 1, hovered and 0.55 or 0.22)
        if hovered then controller.hoveredAlignment = alignment end
    end
end

local function BeginDrag()
    local group = controller.selectedGroup
    if not group or controller.dragging then return end
    controller.dragging = true
    local overlay = controller.overlays[group.id]
    local height = math.max(20, overlay and overlay:GetHeight() or 20)
    controller.ghost:SetSize(math.max(80, overlay and overlay:GetWidth() or 80), height)
    controller.ghost:Show()

    local owner = group.owner
    local zoneWidth = (owner:GetWidth() or 0) / 3
    for i = 1, #ALIGNMENT_ORDER do
        local alignment = ALIGNMENT_ORDER[i]
        local zone = controller.dropZones[alignment]
        zone:ClearAllPoints()
        zone:SetSize(zoneWidth, math.max(28, height + 8))
        if alignment == "LEFT" then
            zone:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, 0)
        elseif alignment == "CENTER" then
            zone:SetPoint("TOP", owner, "BOTTOM", 0, 0)
        else
            zone:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, 0)
        end
        zone:Show()
    end
    controller.dragFrame:SetScript("OnUpdate", UpdateDrag)
end

local function GetGroupTabs(group)
    if group.container and type(group.container.tabs) == "table" then
        return group.container.tabs
    end
    return group.tabs
end

local function AnchorOverlay(overlay, group)
    overlay:ClearAllPoints()
    local tabs = GetGroupTabs(group)
    local firstTab
    local lastTab
    if type(tabs) == "table" then
        for i = 1, #tabs do
            local tab = tabs[i]
            if tab and (not tab.IsShown or tab:IsShown()) then
                firstTab = firstTab or tab
                lastTab = tab
            end
        end
    end
    if firstTab and lastTab then
        overlay:SetPoint("TOPLEFT", firstTab, "TOPLEFT", -2, 2)
        overlay:SetPoint("BOTTOMRIGHT", lastTab, "BOTTOMRIGHT", 2, -2)
    elseif group.container then
        overlay:SetAllPoints(group.container)
    end
end

local function CreateOverlay(group)
    local overlay = CreateFrame("Button", nil, group.owner)
    AnchorOverlay(overlay, group)
    overlay:SetFrameStrata("DIALOG")
    local anchorFrame = group.container or group.owner
    overlay:SetFrameLevel((anchorFrame:GetFrameLevel() or 0) + 20)
    overlay:RegisterForClicks("LeftButtonUp")
    overlay:RegisterForDrag("LeftButton")
    overlay.texture = overlay:CreateTexture(nil, "OVERLAY")
    overlay.texture:SetAllPoints()
    overlay.texture:SetColorTexture(0, 0.65, 1, 0.16)
    overlay:SetScript("OnEnter", function(self)
        self.texture:SetColorTexture(0, 0.65, 1, 0.28)
    end)
    overlay:SetScript("OnLeave", function(self)
        self.texture:SetColorTexture(0, 0.65, 1, 0.16)
    end)
    overlay:SetScript("OnClick", function() SelectGroup(group) end)
    overlay:SetScript("OnDragStart", function()
        SelectGroup(group)
        BeginDrag()
    end)
    overlay:SetScript("OnDragStop", function() StopDrag(true) end)
    overlay:SetScript("OnHide", function()
        if controller.enabled and controller.selectedGroup == group
            and not group.owner:IsShown()
        then
            StopDrag(false)
            DockWithoutSelection(group)
        end
    end)
    overlay:Hide()
    controller.overlays[group.id] = overlay
    return overlay
end

local function ShowGroupOverlay(group)
    if not controller or not controller.enabled then return end
    local overlay = controller.overlays[group.id] or CreateOverlay(group)
    AnchorOverlay(overlay, group)
    overlay:Show()
end

local function CreateController()
    if controller then return controller end
    controller = { optionViews = {}, overlays = {}, dropZones = {} }

    local inspector = CreateFrame("Frame", nil, UIParent)
    inspector:SetSize(250, 310)
    inspector:SetFrameStrata("DIALOG")
    NSkin:SkinWindow(inspector)
    NSkin:SkinWindowHeader(inspector)
    CreateLabel(inspector, "Skinning Mode", "TOPLEFT", inspector, "TOPLEFT", 12, -5)
    local close = CreateButton(inspector, "x", 22, function()
        NSkin:SetSkinningModeEnabled(false)
    end)
    close:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", 0, 0)
    inspector.selection = CreateLabel(inspector, "Select an element", "TOPLEFT", inspector, "TOPLEFT", 12, -34)
    controller.inspector = inspector

    local ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost.texture = ghost:CreateTexture(nil, "BACKGROUND")
    ghost.texture:SetAllPoints()
    ghost.texture:SetColorTexture(0, 0.65, 1, 0.35)
    ghost:Hide()
    controller.ghost = ghost

    for i = 1, #ALIGNMENT_ORDER do
        local zone = CreateFrame("Frame", nil, UIParent)
        zone:SetFrameStrata("DIALOG")
        zone.texture = zone:CreateTexture(nil, "BACKGROUND")
        zone.texture:SetAllPoints()
        zone:Hide()
        controller.dropZones[ALIGNMENT_ORDER[i]] = zone
    end

    controller.dragFrame = CreateFrame("Frame")
    controller.eventFrame = CreateFrame("Frame")
    controller.eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then NSkin:SetSkinningModeEnabled(false) end
    end)
    inspector:ClearAllPoints()
    inspector:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    inspector:Hide()
    RefreshInspector()
    return controller
end

local function HandleTabGroupRegistered(group)
    ShowGroupOverlay(group)
    if controller and controller.enabled and not controller.selectedGroup
        and group.owner:IsShown()
    then
        DockInspector(group)
    end
end

local function HandleTabGroupLayoutApplied(group)
    if not controller then return end
    local overlay = controller.overlays[group.id]
    if overlay then AnchorOverlay(overlay, group) end
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
        self.OnTabGroupRegistered = HandleTabGroupRegistered
        self.OnTabGroupLayoutApplied = HandleTabGroupLayoutApplied
        controller.inspector:Show()
        DockWithoutSelection()
        self:ForEachRegisteredTabGroup(ShowGroupOverlay)
        controller.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:Print("Skinning Mode enabled. Select a highlighted element.")
    else
        StopDrag(false)
        self.OnTabGroupRegistered = nil
        self.OnTabGroupLayoutApplied = nil
        controller.eventFrame:UnregisterAllEvents()
        for _, overlay in pairs(controller.overlays) do overlay:Hide() end
        controller.inspector:Hide()
        controller.selectedGroup = nil
        self:Print("Skinning Mode disabled.")
    end
    return true
end

function NSkin:ToggleSkinningMode()
    return self:SetSkinningModeEnabled(not (controller and controller.enabled))
end
