local _, NSkin = ...

local PVESkin = NSkin:NewModule("PVE")

local IDs = {
    Scope = "PVE",
    Window = "PVE.Window",
    HeaderControls = "PVE.HeaderControls",
    TypeDropdown = "PVE.DungeonFinder.TypeDropdown",
    FindGroupButton = "PVE.DungeonFinder.FindGroupButton",
    SpecificScrollBar = "PVE.DungeonFinder.SpecificScrollBar",
    BottomTabs = "PVE.BottomTabs",
    DungeonSections = "PVE.DungeonFinder.DungeonSectionCheckboxes",
    SpecificDungeons = "PVE.DungeonFinder.SpecificDungeonCheckboxes",
    RaidFinder = {
        Scope = "PVE.RaidFinder",
        SelectionDropdown = "PVE.RaidFinder.SelectionDropdown",
        FindGroupButton = "PVE.RaidFinder.FindGroupButton",
        Roles = {
            Tank = "PVE.RaidFinder.Role.Tank",
            Healer = "PVE.RaidFinder.Role.Healer",
            Damage = "PVE.RaidFinder.Role.Damage",
            Leader = "PVE.RaidFinder.Role.Leader",
        },
    },
    PremadeGroups = {
        Scope = "PVE.PremadeGroups",
        CategoryStartGroupButton =
            "PVE.PremadeGroups.Category.StartGroupButton",
        CategoryFindGroupButton =
            "PVE.PremadeGroups.Category.FindGroupButton",
        BackButton = "PVE.PremadeGroups.Search.BackButton",
        SignUpButton = "PVE.PremadeGroups.Search.SignUpButton",
        EmptyStartGroupButton =
            "PVE.PremadeGroups.Search.EmptyStartGroupButton",
        SearchBox = "PVE.PremadeGroups.Search.SearchBox",
        FilterButton = "PVE.PremadeGroups.Search.FilterButton",
        ScrollBar = "PVE.PremadeGroups.Search.ScrollBar",
    },
    PVP = {
        Scope = "PVE.PVP",
        RoleCheckboxes = "PVE.PVP.QuickMatch.RoleCheckboxes",
        TypeDropdown = "PVE.PVP.QuickMatch.TypeDropdown",
        QueueButton = "PVE.PVP.QuickMatch.QueueButton",
    },
    Roles = {
        Tank = "PVE.DungeonFinder.Role.Tank",
        Healer = "PVE.DungeonFinder.Role.Healer",
        Damage = "PVE.DungeonFinder.Role.Damage",
        Leader = "PVE.DungeonFinder.Role.Leader",
    },
}

local initialized = false
local showHooked = false
local applyPending = false
local tabsRegistered = false
local hookedControls = setmetatable({}, { __mode = "k" })
local hookedShowControls = setmetatable({}, { __mode = "k" })
local hookedScrollBoxes = setmetatable({}, { __mode = "k" })
local dungeonCheckboxBaselines = setmetatable({}, { __mode = "k" })
local dungeonCheckboxGroupByTarget = setmetatable({}, { __mode = "k" })
local dungeonCheckboxTargets = {
    Sections = setmetatable({}, { __mode = "k" }),
    Dungeons = setmetatable({}, { __mode = "k" }),
}
local dungeonGroupAnchors = {}
local dungeonGroupsRegistered = false
local pvpRoleCheckboxes = setmetatable({}, { __mode = "k" })
local pvpRoleCheckboxBaselines = setmetatable({}, { __mode = "k" })
local pvpRoleGroupAnchor
local pvpRoleGroupRegistered = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Dungeons & Raids",
})
NSkin:RegisterAppearanceScope(IDs.RaidFinder.Scope, {
    label = "Raid Finder",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.PremadeGroups.Scope, {
    label = "Premade Groups",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.PVP.Scope, {
    label = "Player vs. Player",
    parent = IDs.Scope,
})

local function HidePVEChromeArtwork(frame)
    for _, name in ipairs({
        "PVEFrameBlueBg",
        "PVEFrameTLCorner",
        "PVEFrameTRCorner",
        "PVEFrameBRCorner",
        "PVEFrameBLCorner",
        "PVEFrameLLVert",
        "PVEFrameRLVert",
        "PVEFrameBottomLine",
        "PVEFrameTopLine",
        "PVEFrameTopFiligree",
        "PVEFrameBottomFiligree",
    }) do
        local region = _G[name]
        if region then
            region:SetAlpha(0)
            region:Hide()
        end
    end
    local shadows = frame.shadows or frame.Shadows
    if shadows then
        shadows:SetAlpha(0)
        shadows:Hide()
    end
end

local function HookRefresh(control)
    if not control or hookedControls[control] or not control.HookScript then return end
    control:HookScript("OnClick", function()
        PVESkin:QueueApply()
    end)
    hookedControls[control] = true
end

local function RegisterCheckbox(
    id, label, checkButton, visibilityOwner, appearanceWindowID)
    local frame = _G.PVEFrame
    if not frame or not checkButton then return false end
    appearanceWindowID = appearanceWindowID or IDs.Scope

    NSkin:SkinCheckButton(checkButton, {
        style = NSkin:GetAppearanceStyle("button", appearanceWindowID, id),
    })
    NSkin:RegisterSimpleMovableElement({
        id = id,
        module = "PVE",
        appearanceWindowID = appearanceWindowID,
        label = label,
        kind = "CHECKBOX",
        window = frame,
        target = checkButton,
        priority = 82,
        highlightRegions = { checkButton },
        isEditable = function()
            return frame:IsVisible()
                and (not visibilityOwner or visibilityOwner:IsVisible())
                and checkButton:IsVisible()
        end,
    })
    return true
end

local function GetRoleDefinitions()
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return {} end
    return {
        { IDs.Roles.Tank, "Dungeon Finder tank role checkbox",
            _G.LFDQueueFrameRoleButtonTank or queueFrame.RoleButtonTank },
        { IDs.Roles.Healer, "Dungeon Finder healer role checkbox",
            _G.LFDQueueFrameRoleButtonHealer or queueFrame.RoleButtonHealer },
        { IDs.Roles.Damage, "Dungeon Finder damage role checkbox",
            _G.LFDQueueFrameRoleButtonDPS or queueFrame.RoleButtonDPS },
        { IDs.Roles.Leader, "Dungeon Finder leader role checkbox",
            _G.LFDQueueFrameRoleButtonLeader or queueFrame.RoleButtonLeader },
    }
end

function PVESkin:ApplyRoleCheckboxes()
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return false end
    local applied = false
    for _, definition in ipairs(GetRoleDefinitions()) do
        local roleButton = definition[3]
        local checkButton = roleButton and roleButton.checkButton
        if RegisterCheckbox(definition[1], definition[2], checkButton, queueFrame) then
            applied = true
        end
    end
    return applied
end

function PVESkin:ApplyTypeDropdown()
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    local dropdown = queueFrame and queueFrame.TypeDropdown
    if not frame or not dropdown then return false end

    NSkin:SkinDropdown(dropdown, { style = NSkin:GetAppearanceStyle(
        "button", IDs.Scope, IDs.TypeDropdown) })
    NSkin:RegisterSimpleMovableElement({
        id = IDs.TypeDropdown,
        module = "PVE",
        appearanceWindowID = IDs.Scope,
        label = "Dungeon Finder type dropdown",
        kind = "DROPDOWN",
        window = frame,
        target = dropdown,
        priority = 80,
        highlightRegions = { dropdown },
        isEditable = function()
            return frame:IsVisible() and queueFrame:IsVisible()
                and dropdown:IsVisible()
        end,
    })
    HookRefresh(dropdown)
    return true
end

function PVESkin:ApplyFindGroupButton()
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    local button = _G.LFDQueueFrameFindGroupButton
        or (queueFrame and queueFrame.FindGroupButton)
    if not frame or not queueFrame or not button then return false end

    NSkin:SkinActionButton(button, { style = NSkin:GetAppearanceStyle(
        "button", IDs.Scope, IDs.FindGroupButton) })
    NSkin:RegisterSimpleMovableElement({
        id = IDs.FindGroupButton,
        module = "PVE",
        appearanceWindowID = IDs.Scope,
        label = "Dungeon Finder find group button",
        kind = "ACTION_BUTTON",
        window = frame,
        target = button,
        priority = 80,
        highlightRegions = { button },
        isEditable = function()
            return frame:IsVisible() and queueFrame:IsVisible()
                and button:IsVisible()
        end,
    })
    HookRefresh(button)
    return true
end

function PVESkin:ApplySpecificScrollBar()
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    local specific = queueFrame and queueFrame.Specific
    local scrollBar = specific and specific.ScrollBar
    if not frame or not scrollBar then return false end

    NSkin:SkinScrollBar(scrollBar, NSkin:GetAppearanceStyle(
        "scrollBar", IDs.Scope, IDs.SpecificScrollBar))
    NSkin:RegisterSimpleMovableElement({
        id = IDs.SpecificScrollBar,
        module = "PVE",
        appearanceWindowID = IDs.Scope,
        label = "Specific dungeon scroll bar",
        kind = "SCROLLBAR",
        window = frame,
        target = scrollBar,
        priority = 80,
        highlightRegions = { scrollBar },
        isEditable = function()
            return frame:IsVisible() and specific:IsVisible()
                and scrollBar:IsVisible()
        end,
    })
    if not hookedShowControls[scrollBar] and scrollBar.HookScript then
        scrollBar:HookScript("OnShow", function()
            PVESkin:QueueApply()
        end)
        hookedShowControls[scrollBar] = true
    end
    return true
end

function PVESkin:ApplyRaidFinderControls()
    local frame = _G.PVEFrame
    local raidFinder = _G.RaidFinderFrame
    local queueFrame = _G.RaidFinderQueueFrame
    if not frame or not raidFinder or not queueFrame then return false end

    local scopeID = IDs.RaidFinder.Scope
    local roleDefinitions = {
        { IDs.RaidFinder.Roles.Tank, "Raid Finder tank role checkbox",
            _G.RaidFinderQueueFrameRoleButtonTank
                or queueFrame.RoleButtonTank },
        { IDs.RaidFinder.Roles.Healer, "Raid Finder healer role checkbox",
            _G.RaidFinderQueueFrameRoleButtonHealer
                or queueFrame.RoleButtonHealer },
        { IDs.RaidFinder.Roles.Damage, "Raid Finder damage role checkbox",
            _G.RaidFinderQueueFrameRoleButtonDPS
                or queueFrame.RoleButtonDPS },
        { IDs.RaidFinder.Roles.Leader, "Raid Finder leader role checkbox",
            _G.RaidFinderQueueFrameRoleButtonLeader
                or queueFrame.RoleButtonLeader },
    }
    for _, definition in ipairs(roleDefinitions) do
        local roleButton = definition[3]
        RegisterCheckbox(definition[1], definition[2],
            roleButton and roleButton.checkButton, queueFrame, scopeID)
    end

    local dropdown = queueFrame.SelectionDropdown
        or _G.RaidFinderQueueFrameSelectionDropdown
    if dropdown then
        NSkin:SkinDropdown(dropdown, { style = NSkin:GetAppearanceStyle(
            "button", scopeID, IDs.RaidFinder.SelectionDropdown) })
        NSkin:RegisterSimpleMovableElement({
            id = IDs.RaidFinder.SelectionDropdown,
            module = "PVE",
            appearanceWindowID = scopeID,
            label = "Raid Finder selection dropdown",
            kind = "DROPDOWN",
            window = frame,
            target = dropdown,
            priority = 80,
            highlightRegions = { dropdown },
            isEditable = function()
                return frame:IsVisible() and queueFrame:IsVisible()
                    and dropdown:IsVisible()
            end,
        })
        HookRefresh(dropdown)
    end

    local button = _G.RaidFinderFrameFindRaidButton
        or raidFinder.FindRaidButton
    if button then
        NSkin:SkinActionButton(button, { style = NSkin:GetAppearanceStyle(
            "button", scopeID, IDs.RaidFinder.FindGroupButton) })
        NSkin:RegisterSimpleMovableElement({
            id = IDs.RaidFinder.FindGroupButton,
            module = "PVE",
            appearanceWindowID = scopeID,
            label = "Raid Finder find group button",
            kind = "ACTION_BUTTON",
            window = frame,
            target = button,
            priority = 80,
            highlightRegions = { button },
            isEditable = function()
                return frame:IsVisible() and raidFinder:IsVisible()
                    and button:IsVisible()
            end,
        })
        HookRefresh(button)
    end

    if not hookedShowControls[raidFinder] and raidFinder.HookScript then
        raidFinder:HookScript("OnShow", function()
            PVESkin:QueueApply()
        end)
        hookedShowControls[raidFinder] = true
    end
    return dropdown ~= nil or button ~= nil
end

local function ApplyPremadeActionButton(id, label, button, visibilityOwner)
    local frame = _G.PVEFrame
    local listFrame = _G.LFGListFrame
    if not frame or not listFrame or not button then return false end

    local scopeID = IDs.PremadeGroups.Scope
    NSkin:SkinActionButton(button, { style = NSkin:GetAppearanceStyle(
        "button", scopeID, id) })
    NSkin:RegisterSimpleMovableElement({
        id = id,
        module = "PVE",
        appearanceWindowID = scopeID,
        label = label,
        kind = "ACTION_BUTTON",
        window = frame,
        target = button,
        priority = 80,
        highlightRegions = { button },
        isEditable = function()
            return frame:IsVisible() and listFrame:IsVisible()
                and (not visibilityOwner or visibilityOwner:IsVisible())
                and button:IsVisible()
        end,
    })
    HookRefresh(button)
    return true
end

function PVESkin:ApplyPremadeGroupControls()
    local frame = _G.PVEFrame
    local listFrame = _G.LFGListFrame
    if not frame or not listFrame then return false end

    local ids = IDs.PremadeGroups
    local scopeID = ids.Scope
    local category = listFrame.CategorySelection
    local searchPanel = listFrame.SearchPanel
    local scrollBox = searchPanel and searchPanel.ScrollBox
    local applied = false

    if category then
        applied = ApplyPremadeActionButton(ids.CategoryStartGroupButton,
            "Premade Groups category start group button",
            category.StartGroupButton, category) or applied
        applied = ApplyPremadeActionButton(ids.CategoryFindGroupButton,
            "Premade Groups category find group button",
            category.FindGroupButton, category) or applied
    end

    if searchPanel then
        applied = ApplyPremadeActionButton(ids.BackButton,
            "Premade Groups back button", searchPanel.BackButton,
            searchPanel) or applied
        applied = ApplyPremadeActionButton(ids.SignUpButton,
            "Premade Groups sign up button", searchPanel.SignUpButton,
            searchPanel) or applied
        applied = ApplyPremadeActionButton(ids.EmptyStartGroupButton,
            "Premade Groups empty-results start group button",
            scrollBox and scrollBox.StartGroupButton, searchPanel) or applied

        local searchBox = searchPanel.SearchBox
        if searchBox then
            local style = NSkin:GetAppearanceStyle(
                "searchBox", scopeID, ids.SearchBox)
            NSkin:SkinSearchBox(searchBox, style,
                NSkin:GetAppearanceBorderColor(
                    "searchBox", style, scopeID, ids.SearchBox))
            NSkin:RegisterSimpleMovableElement({
                id = ids.SearchBox,
                module = "PVE",
                appearanceWindowID = scopeID,
                label = "Premade Groups search bar",
                kind = "SEARCH_GROUP",
                window = frame,
                target = searchBox,
                priority = 82,
                highlightRegions = { searchBox },
                isEditable = function()
                    return frame:IsVisible() and searchPanel:IsVisible()
                        and searchBox:IsVisible()
                end,
            })
            applied = true
        end

        local filterButton = searchPanel.FilterButton
        if filterButton then
            NSkin:SkinDropdown(filterButton, {
                style = NSkin:GetAppearanceStyle(
                    "button", scopeID, ids.FilterButton),
            })
            NSkin:RegisterSimpleMovableElement({
                id = ids.FilterButton,
                module = "PVE",
                appearanceWindowID = scopeID,
                label = "Premade Groups filter",
                kind = "DROPDOWN",
                window = frame,
                target = filterButton,
                priority = 81,
                highlightRegions = { filterButton },
                isEditable = function()
                    return frame:IsVisible() and searchPanel:IsVisible()
                        and filterButton:IsVisible()
                end,
            })
            HookRefresh(filterButton)
            applied = true
        end

        local scrollBar = searchPanel.ScrollBar
            or (scrollBox and scrollBox.ScrollBar)
        if scrollBar then
            NSkin:SkinScrollBar(scrollBar, NSkin:GetAppearanceStyle(
                "scrollBar", scopeID, ids.ScrollBar))
            NSkin:RegisterSimpleMovableElement({
                id = ids.ScrollBar,
                module = "PVE",
                appearanceWindowID = scopeID,
                label = "Premade Groups results scroll bar",
                kind = "SCROLLBAR",
                window = frame,
                target = scrollBar,
                priority = 80,
                highlightRegions = { scrollBar },
                isEditable = function()
                    return frame:IsVisible() and searchPanel:IsVisible()
                        and scrollBar:IsVisible()
                end,
            })
            applied = true
        end
    end

    local showOwners = { listFrame }
    if category then showOwners[#showOwners + 1] = category end
    if searchPanel then showOwners[#showOwners + 1] = searchPanel end
    for _, owner in ipairs(showOwners) do
        if owner and not hookedShowControls[owner] and owner.HookScript then
            owner:HookScript("OnShow", function() PVESkin:QueueApply() end)
            hookedShowControls[owner] = true
        end
    end
    return applied
end

local function CopyPlacement(placement)
    local copy = {}
    for key, value in pairs(placement or {}) do copy[key] = value end
    return copy
end

local function GetDungeonGroupID(groupName)
    return groupName == "Sections"
        and IDs.DungeonSections or IDs.SpecificDungeons
end

local function GetDungeonGroupPlacement(groupName)
    local options = NSkin:GetModuleOptions("PVE", false)
    local placements = options and options.checkboxGroupPlacements
    local saved = placements and placements[GetDungeonGroupID(groupName)]
    return saved and CopyPlacement(saved) or {
        edge = "TOP", side = "INSIDE", alignment = "LEFT",
        alongOffset = 0, edgeOffset = 0,
    }
end

local function CaptureDungeonCheckboxBaseline(checkButton)
    local baseline = dungeonCheckboxBaselines[checkButton]
    if baseline then return baseline end
    baseline = {}
    for i = 1, checkButton:GetNumPoints() do
        baseline[i] = { checkButton:GetPoint(i) }
    end
    dungeonCheckboxBaselines[checkButton] = baseline
    return baseline
end

local function ApplyDungeonGroupPlacement(groupName, placement)
    local x = tonumber(placement and (placement.alongOffset or placement.x)) or 0
    local y = tonumber(placement and (placement.edgeOffset or placement.y)) or 0
    for checkButton in pairs(dungeonCheckboxTargets[groupName]) do
        local baseline = CaptureDungeonCheckboxBaseline(checkButton)
        checkButton:ClearAllPoints()
        for i = 1, #baseline do
            local point = baseline[i]
            checkButton:SetPoint(point[1], point[2], point[3],
                (tonumber(point[4]) or 0) + x,
                (tonumber(point[5]) or 0) + y)
        end
    end
    NSkin:NotifySkinningElementBoundsChanged(GetDungeonGroupID(groupName))
    return true
end

local function SetDungeonGroupPlacement(groupName, placement)
    if not ApplyDungeonGroupPlacement(groupName, placement) then return false end
    local options = NSkin:GetModuleOptions("PVE", true)
    options.checkboxGroupPlacements = options.checkboxGroupPlacements or {}
    options.checkboxGroupPlacements[GetDungeonGroupID(groupName)] =
        CopyPlacement(placement)
    return true
end

local function ResetDungeonGroupPlacement(groupName)
    ApplyDungeonGroupPlacement(groupName, {
        alongOffset = 0, edgeOffset = 0,
    })
    local options = NSkin:GetModuleOptions("PVE", false)
    local placements = options and options.checkboxGroupPlacements
    if placements then
        placements[GetDungeonGroupID(groupName)] = nil
        if not next(placements) then options.checkboxGroupPlacements = nil end
    end
    return true
end

local function GetDungeonGroupRegions(groupName)
    local topmost, top
    for checkButton in pairs(dungeonCheckboxTargets[groupName]) do
        local buttonTop = checkButton:IsVisible() and checkButton:GetTop()
        if buttonTop and (not top or buttonTop > top) then
            topmost, top = checkButton, buttonTop
        end
    end
    return topmost and { topmost } or {}
end

local function GetDungeonGroupAnchor(groupName)
    local anchor = dungeonGroupAnchors[groupName]
    if anchor then return anchor end
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return nil end
    anchor = CreateFrame("Frame", nil, queueFrame)
    anchor:SetSize(1, 1)
    anchor:SetPoint("TOPLEFT")
    anchor:EnableMouse(false)
    anchor:Show()
    dungeonGroupAnchors[groupName] = anchor
    return anchor
end

local function RegisterDungeonCheckboxGroup(
    groupName, id, label, frame, queueFrame)
    local anchor = GetDungeonGroupAnchor(groupName)
    return NSkin:RegisterSkinningElement(id, {
        label = label,
        kind = "CHECKBOX",
        module = "PVE",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = anchor,
        priority = 82,
        draggable = false,
        editorOptions = NSkin:CreateEditorOptionsPreset("MOVABLE"),
        highlightRegions = function()
            return GetDungeonGroupRegions(groupName)
        end,
        isEditable = function()
            return frame:IsVisible() and queueFrame:IsVisible()
                and #GetDungeonGroupRegions(groupName) > 0
        end,
        getPlacement = function()
            return GetDungeonGroupPlacement(groupName)
        end,
        applyPlacement = function(_, placement)
            return ApplyDungeonGroupPlacement(groupName, placement)
        end,
        setPlacement = function(_, placement)
            return SetDungeonGroupPlacement(groupName, placement)
        end,
        resetPlacement = function()
            return ResetDungeonGroupPlacement(groupName)
        end,
    })
end

function PVESkin:RegisterDungeonCheckboxGroups()
    if dungeonGroupsRegistered then return true end
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    if not frame or not queueFrame then return false end
    RegisterDungeonCheckboxGroup("Sections", IDs.DungeonSections,
        "Dungeon section checkboxes", frame, queueFrame)
    RegisterDungeonCheckboxGroup("Dungeons", IDs.SpecificDungeons,
        "Specific dungeon checkboxes", frame, queueFrame)
    dungeonGroupsRegistered = true
    return true
end

function PVESkin:StyleDungeonChoice(_, _, choice)
    local checkButton = choice and choice.enableButton
    local dungeonID = choice and choice.id
    if not checkButton or not dungeonID then return false end
    local isHeader = type(_G.LFGIsIDHeader) == "function"
        and _G.LFGIsIDHeader(dungeonID)
    local groupName = isHeader and "Sections" or "Dungeons"
    local previousGroup = dungeonCheckboxGroupByTarget[checkButton]
    if previousGroup and previousGroup ~= groupName then
        dungeonCheckboxTargets[previousGroup][checkButton] = nil
    end
    dungeonCheckboxGroupByTarget[checkButton] = groupName
    dungeonCheckboxTargets[groupName][checkButton] = true
    CaptureDungeonCheckboxBaseline(checkButton)
    local id = GetDungeonGroupID(groupName)
    NSkin:SkinCheckButton(checkButton, {
        style = NSkin:GetAppearanceStyle("button", IDs.Scope, id),
    })
    ApplyDungeonGroupPlacement(groupName, GetDungeonGroupPlacement(groupName))
    return true
end

function PVESkin:ApplyDungeonSelectionCheckboxes()
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return false end
    self:RegisterDungeonCheckboxGroups()
    local applied = false
    for _, definition in ipairs({
        { "Specific", queueFrame.Specific },
        { "Follower", queueFrame.Follower },
    }) do
        local listName, owner = definition[1], definition[2]
        local scrollBox = owner and owner.ScrollBox
        if scrollBox and scrollBox.ForEachFrame then
            scrollBox:ForEachFrame(function(choice)
                if self:StyleDungeonChoice(listName, owner, choice) then
                    applied = true
                end
            end)
        end
    end
    return applied
end

local function GetPVPRoleGroupPlacement()
    local options = NSkin:GetModuleOptions("PVE", false)
    local placements = options and options.checkboxGroupPlacements
    local saved = placements and placements[IDs.PVP.RoleCheckboxes]
    return saved and CopyPlacement(saved) or {
        edge = "TOP", side = "INSIDE", alignment = "LEFT",
        alongOffset = 0, edgeOffset = 0,
    }
end

local function CapturePVPRoleCheckboxBaseline(checkButton)
    local baseline = pvpRoleCheckboxBaselines[checkButton]
    if baseline then return baseline end
    baseline = {}
    for i = 1, checkButton:GetNumPoints() do
        baseline[i] = { checkButton:GetPoint(i) }
    end
    pvpRoleCheckboxBaselines[checkButton] = baseline
    return baseline
end

local function ApplyPVPRoleGroupPlacement(placement)
    local x = tonumber(placement and (placement.alongOffset or placement.x)) or 0
    local y = tonumber(placement and (placement.edgeOffset or placement.y)) or 0
    for checkButton in pairs(pvpRoleCheckboxes) do
        local baseline = CapturePVPRoleCheckboxBaseline(checkButton)
        checkButton:ClearAllPoints()
        for i = 1, #baseline do
            local point = baseline[i]
            checkButton:SetPoint(point[1], point[2], point[3],
                (tonumber(point[4]) or 0) + x,
                (tonumber(point[5]) or 0) + y)
        end
    end
    NSkin:NotifySkinningElementBoundsChanged(IDs.PVP.RoleCheckboxes)
    return true
end

local function SetPVPRoleGroupPlacement(placement)
    ApplyPVPRoleGroupPlacement(placement)
    local options = NSkin:GetModuleOptions("PVE", true)
    options.checkboxGroupPlacements = options.checkboxGroupPlacements or {}
    options.checkboxGroupPlacements[IDs.PVP.RoleCheckboxes] =
        CopyPlacement(placement)
    return true
end

local function ResetPVPRoleGroupPlacement()
    ApplyPVPRoleGroupPlacement({ alongOffset = 0, edgeOffset = 0 })
    local options = NSkin:GetModuleOptions("PVE", false)
    local placements = options and options.checkboxGroupPlacements
    if placements then
        placements[IDs.PVP.RoleCheckboxes] = nil
        if not next(placements) then options.checkboxGroupPlacements = nil end
    end
    return true
end

local function GetPVPRoleGroupRegions()
    local regions = {}
    for checkButton in pairs(pvpRoleCheckboxes) do
        if checkButton:IsVisible() then regions[#regions + 1] = checkButton end
    end
    return regions
end

local function RegisterPVPRoleGroup(frame, honorFrame)
    if pvpRoleGroupRegistered then return true end
    if not pvpRoleGroupAnchor then
        pvpRoleGroupAnchor = CreateFrame("Frame", nil, honorFrame)
        pvpRoleGroupAnchor:SetSize(1, 1)
        pvpRoleGroupAnchor:SetPoint("TOPLEFT")
        pvpRoleGroupAnchor:EnableMouse(false)
        pvpRoleGroupAnchor:Show()
    end
    pvpRoleGroupRegistered = NSkin:RegisterSkinningElement(
        IDs.PVP.RoleCheckboxes, {
            label = "PvP Quick Match role checkboxes",
            kind = "CHECKBOX",
            module = "PVE",
            appearanceWindowID = IDs.PVP.Scope,
            window = frame,
            target = pvpRoleGroupAnchor,
            priority = 82,
            draggable = false,
            editorOptions = NSkin:CreateEditorOptionsPreset("MOVABLE"),
            highlightRegions = GetPVPRoleGroupRegions,
            isEditable = function()
                return frame:IsVisible() and honorFrame:IsVisible()
                    and #GetPVPRoleGroupRegions() > 0
            end,
            getPlacement = GetPVPRoleGroupPlacement,
            applyPlacement = function(_, placement)
                return ApplyPVPRoleGroupPlacement(placement)
            end,
            setPlacement = function(_, placement)
                return SetPVPRoleGroupPlacement(placement)
            end,
            resetPlacement = ResetPVPRoleGroupPlacement,
        }) == true
    return pvpRoleGroupRegistered
end

function PVESkin:ApplyPVPControls()
    local frame = _G.PVEFrame
    local pvpFrame = _G.PVPUIFrame
    local honorFrame = _G.HonorFrame
    if not frame or not pvpFrame or not honorFrame then return false end

    local ids = IDs.PVP
    local roleList = honorFrame.RoleList
    local applied = false
    if roleList then
        for _, roleButton in ipairs({
            roleList.TankIcon,
            roleList.HealerIcon,
            roleList.DPSIcon,
        }) do
            local checkButton = roleButton
                and (roleButton.checkButton or roleButton.CheckButton)
            if checkButton then
                pvpRoleCheckboxes[checkButton] = true
                CapturePVPRoleCheckboxBaseline(checkButton)
                NSkin:SkinCheckButton(checkButton, {
                    style = NSkin:GetAppearanceStyle(
                        "button", ids.Scope, ids.RoleCheckboxes),
                })
                applied = true
            end
        end
        if applied then
            RegisterPVPRoleGroup(frame, honorFrame)
            ApplyPVPRoleGroupPlacement(GetPVPRoleGroupPlacement())
        end
    end

    local dropdown = honorFrame.TypeDropdown or _G.HonorFrameTypeDropdown
    if dropdown then
        NSkin:SkinDropdown(dropdown, { style = NSkin:GetAppearanceStyle(
            "button", ids.Scope, ids.TypeDropdown) })
        NSkin:RegisterSimpleMovableElement({
            id = ids.TypeDropdown,
            module = "PVE",
            appearanceWindowID = ids.Scope,
            label = "PvP Quick Match type dropdown",
            kind = "DROPDOWN",
            window = frame,
            target = dropdown,
            priority = 80,
            highlightRegions = { dropdown },
            isEditable = function()
                return frame:IsVisible() and honorFrame:IsVisible()
                    and dropdown:IsVisible()
            end,
        })
        HookRefresh(dropdown)
        applied = true
    end

    local queueButton = honorFrame.QueueButton or _G.HonorFrameQueueButton
    if queueButton then
        NSkin:SkinActionButton(queueButton, { style = NSkin:GetAppearanceStyle(
            "button", ids.Scope, ids.QueueButton) })
        NSkin:RegisterSimpleMovableElement({
            id = ids.QueueButton,
            module = "PVE",
            appearanceWindowID = ids.Scope,
            label = "PvP Quick Match join battle button",
            kind = "ACTION_BUTTON",
            window = frame,
            target = queueButton,
            priority = 80,
            highlightRegions = { queueButton },
            isEditable = function()
                return frame:IsVisible() and honorFrame:IsVisible()
                    and queueButton:IsVisible()
            end,
        })
        HookRefresh(queueButton)
        applied = true
    end

    for _, owner in ipairs({ pvpFrame, honorFrame }) do
        if not hookedShowControls[owner] and owner.HookScript then
            owner:HookScript("OnShow", function() PVESkin:QueueApply() end)
            hookedShowControls[owner] = true
        end
    end
    return applied
end

function PVESkin:ApplyBottomTabs()
    local frame = _G.PVEFrame
    if not frame then return false end
    local tabs = {
        frame.tab1 or _G.PVEFrameTab1,
        frame.tab2 or _G.PVEFrameTab2,
        frame.tab3 or _G.PVEFrameTab3,
    }
    for i = 1, #tabs do
        if not tabs[i] then return false end
    end

    local style = NSkin:GetAppearanceStyle("tab", IDs.Scope, IDs.BottomTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, IDs.BottomTabs)
    local selected = _G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(frame)
    for i = 1, #tabs do
        NSkin:SkinTab(tabs[i], i == selected, style, border)
        HookRefresh(tabs[i])
    end
    if not tabsRegistered then
        NSkin:RegisterTabGroup(IDs.BottomTabs, {
            label = "Dungeons & Raids bottom tabs",
            kind = "TAB_GROUP",
            module = "PVE",
            appearanceWindowID = IDs.Scope,
            window = frame,
            tabs = tabs,
            priority = 50,
            orientation = "HORIZONTAL",
            edge = "BOTTOM",
        })
        tabsRegistered = true
    end
    NSkin:ApplyTabGroupLayout(IDs.BottomTabs)
    return true
end

function PVESkin:HookDungeonScrollBoxes()
    local queueFrame = _G.LFDQueueFrame
    local scrollEvents = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if not queueFrame then return false end
    for _, definition in ipairs({
        { "Specific", queueFrame.Specific },
        { "Follower", queueFrame.Follower },
    }) do
        local listName, owner = definition[1], definition[2]
        local scrollBox = owner and owner.ScrollBox
        if scrollBox and not hookedScrollBoxes[scrollBox] then
            if scrollBox.RegisterCallback and scrollEvents
                and scrollEvents.OnInitializedFrame
            then
                scrollBox:RegisterCallback(scrollEvents.OnInitializedFrame,
                    function(_, choice)
                        PVESkin:StyleDungeonChoice(listName, owner, choice)
                    end, self)
            end
            if type(scrollBox.Update) == "function" then
                hooksecurefunc(scrollBox, "Update", function()
                    PVESkin:ApplyDungeonSelectionCheckboxes()
                end)
            end
            hookedScrollBoxes[scrollBox] = true
        end
    end
    return true
end

function PVESkin:ApplyWindowChrome()
    local frame = _G.PVEFrame
    if not frame then return false end

    HidePVEChromeArtwork(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Dungeons & Raids window",
        kind = "WINDOW",
        module = "PVE",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function PVESkin:QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        PVESkin:ApplyWindowChrome()
        PVESkin:ApplyRoleCheckboxes()
        PVESkin:ApplyTypeDropdown()
        PVESkin:ApplyFindGroupButton()
        PVESkin:ApplySpecificScrollBar()
        PVESkin:ApplyRaidFinderControls()
        PVESkin:ApplyPremadeGroupControls()
        PVESkin:ApplyPVPControls()
        PVESkin:ApplyDungeonSelectionCheckboxes()
        PVESkin:ApplyBottomTabs()
    end)
end

function PVESkin:Initialize()
    if initialized then return true end
    local frame = _G.PVEFrame
    if not frame then return false end

    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            PVESkin:QueueApply()
        end)
        showHooked = true
    end

    initialized = true
    self:ApplyWindowChrome()
    self:HookDungeonScrollBoxes()
    self:ApplyRoleCheckboxes()
    self:ApplyTypeDropdown()
    self:ApplyFindGroupButton()
    self:ApplySpecificScrollBar()
    self:ApplyRaidFinderControls()
    self:ApplyPremadeGroupControls()
    self:ApplyPVPControls()
    self:ApplyDungeonSelectionCheckboxes()
    self:ApplyBottomTabs()
    if frame:IsShown() then self:QueueApply() end
    return true
end

function PVESkin:RefreshAppearance()
    if not initialized then return end
    self:ApplyWindowChrome()
    self:ApplyRoleCheckboxes()
    self:ApplyTypeDropdown()
    self:ApplyFindGroupButton()
    self:ApplySpecificScrollBar()
    self:ApplyRaidFinderControls()
    self:ApplyPremadeGroupControls()
    self:ApplyPVPControls()
    self:ApplyDungeonSelectionCheckboxes()
    self:ApplyBottomTabs()
end

NSkin:RegisterWindowSkin({
    module = "PVE",
    addon = "Blizzard_GroupFinder",
    apply = function() return PVESkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "PVE.PVP",
    module = "PVE",
    addon = "Blizzard_PVPUI",
    apply = function() return PVESkin:ApplyPVPControls() end,
})
