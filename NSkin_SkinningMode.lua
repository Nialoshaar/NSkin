local _, NSkin = ...

local editableTabGroups = {}
local controller

local ALIGNMENTS = { LEFT = true, CENTER = true, RIGHT = true }
local ALIGNMENT_ORDER = { "LEFT", "CENTER", "RIGHT" }

local function IsSafeFrame(frame)
    return frame
        and not (frame.IsForbidden and frame:IsForbidden())
        and not (frame.IsProtected and frame:IsProtected())
end

local function GetDefaultPlacement(group)
    local moduleDefaults = NSkin.defaultModuleOptions[group.module]
    local groupDefaults = moduleDefaults and moduleDefaults.tabGroups
        and moduleDefaults.tabGroups[group.optionKey]
    local declared = groupDefaults and groupDefaults.placement or {}
    local shared = NSkin:GetStyle("tab").bottom
    return {
        -- Until a group-specific override is saved, retain the placement that
        -- existing profiles already receive from the shared bottom-tab style.
        alignment = shared.anchor or declared.alignment or "LEFT",
        alongOffset = shared.offsetX or declared.alongOffset or 0,
        edgeOffset = shared.offsetY or declared.edgeOffset or 0,
    }
end

local function CopyPlacement(placement)
    local alongOffset = tonumber(placement and placement.alongOffset) or 0
    local edgeOffset = tonumber(placement and placement.edgeOffset) or 0
    alongOffset = math.max(-100, math.min(100, math.floor(alongOffset + 0.5)))
    edgeOffset = math.max(-100, math.min(100, math.floor(edgeOffset + 0.5)))
    return {
        alignment = ALIGNMENTS[placement and placement.alignment]
            and placement.alignment or "LEFT",
        alongOffset = alongOffset,
        edgeOffset = edgeOffset,
    }
end

local function PlacementsMatch(a, b)
    return a.alignment == b.alignment
        and a.alongOffset == b.alongOffset
        and a.edgeOffset == b.edgeOffset
end

function NSkin:RegisterEditableTabGroup(groupID, definition)
    if type(groupID) ~= "string" or groupID == ""
        or type(definition) ~= "table"
        or type(definition.module) ~= "string"
        or type(definition.optionKey) ~= "string"
        or definition.orientation ~= "HORIZONTAL"
        or definition.edge ~= "BOTTOM"
        or not definition.owner
        or not definition.container
    then
        return false
    end

    local existing = editableTabGroups[groupID]
    if existing then
        existing.owner = definition.owner
        existing.container = definition.container
        return true
    end

    definition.id = groupID
    editableTabGroups[groupID] = definition
    return true
end

function NSkin:IsEditableTabGroupRegistered(groupID)
    return editableTabGroups[groupID] ~= nil
end

function NSkin:GetTabGroupPlacement(groupID)
    local group = editableTabGroups[groupID]
    if not group then return nil end

    local defaults = GetDefaultPlacement(group)
    local options = self:GetModuleOptions(group.module, false)
    local saved = options and options.tabGroups and options.tabGroups[group.optionKey]
        and options.tabGroups[group.optionKey].placement
    local placement = CopyPlacement(defaults)
    if saved then
        if ALIGNMENTS[saved.alignment] then placement.alignment = saved.alignment end
        if tonumber(saved.alongOffset) then placement.alongOffset = tonumber(saved.alongOffset) end
        if tonumber(saved.edgeOffset) then placement.edgeOffset = tonumber(saved.edgeOffset) end
    end
    return placement
end

local function RemoveEmptyModuleOptions(moduleName)
    local profile = NSkin:GetProfile()
    local moduleOptions = profile.moduleOptions and profile.moduleOptions[moduleName]
    if moduleOptions and not next(moduleOptions) then
        profile.moduleOptions[moduleName] = nil
    end
    if profile.moduleOptions and not next(profile.moduleOptions) then
        profile.moduleOptions = nil
    end
end

function NSkin:SetTabGroupPlacement(groupID, placement)
    local group = editableTabGroups[groupID]
    if not group or type(placement) ~= "table" then return false end

    local normalized = CopyPlacement(placement)
    local defaults = CopyPlacement(GetDefaultPlacement(group))
    local options = self:GetModuleOptions(group.module, false)
    if PlacementsMatch(normalized, defaults) then
        local tabGroups = options and options.tabGroups
        if tabGroups then
            tabGroups[group.optionKey] = nil
            if not next(tabGroups) then options.tabGroups = nil end
            RemoveEmptyModuleOptions(group.module)
        end
    else
        options = self:GetModuleOptions(group.module, true)
        options.tabGroups = options.tabGroups or {}
        options.tabGroups[group.optionKey] = { placement = normalized }
    end

    return self:ApplyTabGroupLayout(groupID)
end

function NSkin:ApplyTabGroupLayout(groupID)
    local group = editableTabGroups[groupID]
    if (_G.InCombatLockdown and _G.InCombatLockdown())
        or not group or not group.owner
        or (group.owner.IsForbidden and group.owner:IsForbidden())
        or type(group.container.tabs) ~= "table"
    then
        return false
    end

    local placement = self:GetTabGroupPlacement(groupID)
    if IsSafeFrame(group.container) then
        group.container.spacing = self:GetTabSpacing()
        if group.container.MarkDirty then group.container:MarkDirty() end
    end
    return self:LayoutTabGroup(group.container.tabs, {
        owner = group.owner,
        orientation = group.orientation,
        edge = group.edge,
        spacing = self:GetTabSpacing(),
        placement = placement,
    }) == true
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

local function RefreshInspector()
    if not controller or not controller.selectedGroup then return end
    local placement = NSkin:GetTabGroupPlacement(controller.selectedGroup.id)
    if not placement then return end
    controller.inspector.alongValue:SetText(tostring(placement.alongOffset))
    controller.inspector.edgeValue:SetText(tostring(placement.edgeOffset))
    controller.inspector.selection:SetText(
        "Selected: Spellbook tabs\nAlignment: " .. placement.alignment
    )
end

local function ApplyPlacementChange(change)
    local group = controller and controller.selectedGroup
    if not group then return end
    local placement = NSkin:GetTabGroupPlacement(group.id)
    change(placement)
    NSkin:SetTabGroupPlacement(group.id, placement)
    RefreshInspector()
end

local function DockInspector(group)
    local inspector = controller.inspector
    inspector:ClearAllPoints()
    local screenWidth = UIParent:GetRight() or GetScreenWidth()
    local roomOnRight = screenWidth - (group.owner:GetRight() or 0)
    if roomOnRight >= inspector:GetWidth() + 12 then
        inspector:SetPoint("TOPLEFT", group.owner, "TOPRIGHT", 8, 0)
    else
        inspector:SetPoint("TOPRIGHT", group.owner, "TOPLEFT", -8, 0)
    end
end

local function SelectGroup(group)
    controller.selectedGroup = group
    DockInspector(group)
    controller.inspector:Show()
    RefreshInspector()
end

local function GetCursorUIPosition()
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

local function PointInFrame(x, y, frame)
    local left, right, bottom, top = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    return left and right and bottom and top
        and x >= left and x <= right and y >= bottom and y <= top
end

local function StopDrag(apply)
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
        ApplyPlacementChange(function(placement)
            placement.alignment = alignment
            placement.alongOffset = 0
        end)
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
    local width = math.max(80, group.container:GetWidth() or 80)
    local height = math.max(20, group.container:GetHeight() or 20)
    controller.ghost:SetSize(width, height)
    controller.ghost:Show()

    local owner = group.owner
    local ownerWidth = owner:GetWidth() or 0
    local zoneWidth = ownerWidth / 3
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

local function CreateController()
    if controller then return controller end
    controller = { overlays = {}, dropZones = {} }

    local inspector = CreateFrame("Frame", nil, UIParent)
    inspector:SetSize(250, 220)
    inspector:SetFrameStrata("DIALOG")
    NSkin:SkinWindow(inspector)
    NSkin:SkinWindowHeader(inspector)
    CreateLabel(inspector, "NialoSkin Skinning Mode", "TOPLEFT", inspector, "TOPLEFT", 12, -5)
    inspector.selection = CreateLabel(inspector, "Select a tab group", "TOPLEFT", inspector, "TOPLEFT", 12, -34)

    local x = 12
    for i = 1, #ALIGNMENT_ORDER do
        local alignment = ALIGNMENT_ORDER[i]
        local button = CreateButton(inspector, alignment:sub(1, 1) .. alignment:sub(2):lower(), 68,
            function() ApplyPlacementChange(function(p) p.alignment = alignment end) end)
        button:SetPoint("TOPLEFT", inspector, "TOPLEFT", x, -78)
        x = x + 75
    end

    CreateLabel(inspector, "Along-edge offset", "TOPLEFT", inspector, "TOPLEFT", 12, -112)
    inspector.alongValue = CreateLabel(inspector, "0", "TOP", inspector, "TOP", 0, -137)
    local alongMinus = CreateButton(inspector, "-", 30,
        function() ApplyPlacementChange(function(p) p.alongOffset = p.alongOffset - 2 end) end)
    alongMinus:SetPoint("TOPLEFT", inspector, "TOPLEFT", 12, -130)
    local alongPlus = CreateButton(inspector, "+", 30,
        function() ApplyPlacementChange(function(p) p.alongOffset = p.alongOffset + 2 end) end)
    alongPlus:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -12, -130)

    CreateLabel(inspector, "Distance from window edge", "TOPLEFT", inspector, "TOPLEFT", 12, -162)
    inspector.edgeValue = CreateLabel(inspector, "0", "TOP", inspector, "TOP", 0, -187)
    local edgeMinus = CreateButton(inspector, "-", 30,
        function() ApplyPlacementChange(function(p) p.edgeOffset = p.edgeOffset - 2 end) end)
    edgeMinus:SetPoint("TOPLEFT", inspector, "TOPLEFT", 12, -180)
    local edgePlus = CreateButton(inspector, "+", 30,
        function() ApplyPlacementChange(function(p) p.edgeOffset = p.edgeOffset + 2 end) end)
    edgePlus:SetPoint("TOPRIGHT", inspector, "TOPRIGHT", -12, -180)

    local reset = CreateButton(inspector, "Reset", 58, function()
        local group = controller.selectedGroup
        if group then NSkin:SetTabGroupPlacement(group.id, GetDefaultPlacement(group)) end
        RefreshInspector()
    end)
    reset:SetPoint("BOTTOM", inspector, "BOTTOM", 0, 10)
    inspector:Hide()
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
    return controller
end

local function CreateOverlay(group)
    local overlay = CreateFrame("Button", nil, group.owner)
    local tabs = group.container.tabs
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
    else
        overlay:SetAllPoints(group.container)
    end
    overlay:SetFrameStrata("DIALOG")
    overlay:SetFrameLevel((group.container:GetFrameLevel() or 0) + 20)
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
        if controller.enabled and not group.owner:IsShown() then
            NSkin:SetSkinningModeEnabled(false)
        end
    end)
    overlay:Hide()
    controller.overlays[group.id] = overlay
    return overlay
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
        local visibleCount = 0
        for groupID, group in pairs(editableTabGroups) do
            if group.owner:IsShown() then
                local overlay = controller.overlays[groupID] or CreateOverlay(group)
                overlay:Show()
                visibleCount = visibleCount + 1
            end
        end
        if visibleCount == 0 then
            controller.enabled = false
            self:Print("Open the enabled Spellbook window before entering Skinning Mode.")
            return false
        end
        controller.eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:Print("Skinning Mode enabled. Click or drag the highlighted Spellbook tabs.")
    else
        StopDrag(false)
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
