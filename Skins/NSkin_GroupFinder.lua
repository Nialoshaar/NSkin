local _, NSkin = ...

local PVESkin = NSkin:NewModule("GroupFinder")

local IDs = {
    Scope = "GroupFinder",
    Window = "GroupFinder.Window",
    HeaderControls = "GroupFinder.HeaderControls",
    TypeDropdown = "GroupFinder.DungeonFinder.TypeDropdown",
    FindGroupButton = "GroupFinder.DungeonFinder.FindGroupButton",
    SpecificScrollBar = "GroupFinder.DungeonFinder.SpecificScrollBar",
    BottomTabs = "GroupFinder.BottomTabs",
    DungeonSections = "GroupFinder.DungeonFinder.DungeonSectionCheckboxes",
    SpecificDungeons = "GroupFinder.DungeonFinder.SpecificDungeonCheckboxes",
    RaidFinder = {
        Scope = "GroupFinder.RaidFinder",
        SelectionDropdown = "GroupFinder.RaidFinder.SelectionDropdown",
        FindGroupButton = "GroupFinder.RaidFinder.FindGroupButton",
        Roles = {
            Tank = "GroupFinder.RaidFinder.Role.Tank",
            Healer = "GroupFinder.RaidFinder.Role.Healer",
            Damage = "GroupFinder.RaidFinder.Role.Damage",
            Leader = "GroupFinder.RaidFinder.Role.Leader",
        },
    },
    PremadeGroups = {
        Scope = "GroupFinder.PremadeGroups",
        CategoryStartGroupButton =
            "GroupFinder.PremadeGroups.Category.StartGroupButton",
        CategoryFindGroupButton =
            "GroupFinder.PremadeGroups.Category.FindGroupButton",
        BackButton = "GroupFinder.PremadeGroups.Search.BackButton",
        SignUpButton = "GroupFinder.PremadeGroups.Search.SignUpButton",
        EmptyStartGroupButton =
            "GroupFinder.PremadeGroups.Search.EmptyStartGroupButton",
        SearchBox = "GroupFinder.PremadeGroups.Search.SearchBox",
        FilterButton = "GroupFinder.PremadeGroups.Search.FilterButton",
        ScrollBar = "GroupFinder.PremadeGroups.Search.ScrollBar",
    },
    PVP = {
        Scope = "GroupFinder.PVP",
        RoleCheckboxes = "GroupFinder.PVP.QuickMatch.RoleCheckboxes",
        TypeDropdown = "GroupFinder.PVP.QuickMatch.TypeDropdown",
        QueueButton = "GroupFinder.PVP.QuickMatch.QueueButton",
    },
    CompactRaidManager = {
        Scope = "GroupFinder.CompactRaidFrameManager",
        Window = "GroupFinder.CompactRaidFrameManager.Window",
        HeaderControls =
            "GroupFinder.CompactRaidFrameManager.HeaderControls",
        ModeDropdown =
            "GroupFinder.CompactRaidFrameManager.ModeDropdown",
        RestrictPingsDropdown =
            "GroupFinder.CompactRaidFrameManager.RestrictPingsDropdown",
        LeavePartyButton =
            "GroupFinder.CompactRaidFrameManager.LeavePartyButton",
        LeaveInstanceGroupButton =
            "GroupFinder.CompactRaidFrameManager.LeaveInstanceGroupButton",
        MarkerTabs =
            "GroupFinder.CompactRaidFrameManager.MarkerTabs",
    },
    Roles = {
        Tank = "GroupFinder.DungeonFinder.Role.Tank",
        Healer = "GroupFinder.DungeonFinder.Role.Healer",
        Damage = "GroupFinder.DungeonFinder.Role.Damage",
        Leader = "GroupFinder.DungeonFinder.Role.Leader",
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
local compactRaidInitialized = false
local compactRaidShowHooked = false
local compactRaidTabsHooked = false
local compactRaidTabsRegistered = false

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
NSkin:RegisterAppearanceScope(IDs.CompactRaidManager.Scope, {
    label = "Compact Raid Manager",
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
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    if not frame or not queueFrame then return false end
    local applied = false
    for _, definition in ipairs(GetRoleDefinitions()) do
        local roleButton = definition[3]
        local checkButton = roleButton and roleButton.checkButton
        if checkButton then
            local id, label = definition[1], definition[2]
            applied = NSkin:RegisterCheckbox({
                id = id, module = "GroupFinder", appearanceWindowID = IDs.Scope,
                label = label, window = frame, target = checkButton,
                priority = 82, highlightRegions = { checkButton },
                isEditable = function()
                    return frame:IsVisible() and queueFrame:IsVisible()
                        and checkButton:IsVisible()
                end,
            }) ~= nil or applied
        end
    end
    return applied
end

function PVESkin:ApplyTypeDropdown()
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    local dropdown = queueFrame and queueFrame.TypeDropdown
    if not frame or not dropdown then return false end

    NSkin:RegisterDropdown({
        id = IDs.TypeDropdown,
        module = "GroupFinder",
        appearanceWindowID = IDs.Scope,
        label = "Dungeon Finder type dropdown",
        window = frame,
        target = dropdown,
        menus = { "MENU_LFD_FRAME" },
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

    NSkin:RegisterActionButton({
        id = IDs.FindGroupButton,
        module = "GroupFinder",
        appearanceWindowID = IDs.Scope,
        label = "Dungeon Finder find group button",
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

    NSkin:RegisterScrollBar({
        id = IDs.SpecificScrollBar,
        module = "GroupFinder",
        appearanceWindowID = IDs.Scope,
        label = "Specific dungeon scroll bar",
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
        local checkButton = roleButton and roleButton.checkButton
        if checkButton then
            local id, label = definition[1], definition[2]
            NSkin:RegisterCheckbox({
                id = id, module = "GroupFinder", appearanceWindowID = scopeID,
                label = label, window = frame, target = checkButton,
                priority = 82, highlightRegions = { checkButton },
                isEditable = function()
                    return frame:IsVisible() and queueFrame:IsVisible()
                        and checkButton:IsVisible()
                end,
            })
        end
    end

    local dropdown = queueFrame.SelectionDropdown
        or _G.RaidFinderQueueFrameSelectionDropdown
    if dropdown then
        NSkin:RegisterDropdown({
            id = IDs.RaidFinder.SelectionDropdown,
            module = "GroupFinder",
            appearanceWindowID = scopeID,
            label = "Raid Finder selection dropdown",
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
        NSkin:RegisterActionButton({
            id = IDs.RaidFinder.FindGroupButton,
            module = "GroupFinder",
            appearanceWindowID = scopeID,
            label = "Raid Finder find group button",
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
    NSkin:RegisterActionButton({
        id = id,
        module = "GroupFinder",
        appearanceWindowID = scopeID,
        label = label,
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
            NSkin:RegisterSearchBox({
                id = ids.SearchBox,
                module = "GroupFinder",
                appearanceWindowID = scopeID,
                label = "Premade Groups search bar",
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
            NSkin:RegisterDropdown({
                id = ids.FilterButton,
                module = "GroupFinder",
                appearanceWindowID = scopeID,
                label = "Premade Groups filter",
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
            NSkin:RegisterScrollBar({
                id = ids.ScrollBar,
                module = "GroupFinder",
                appearanceWindowID = scopeID,
                label = "Premade Groups results scroll bar",
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
    local options = NSkin:GetModuleOptions("GroupFinder", false)
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
    local options = NSkin:GetModuleOptions("GroupFinder", true)
    options.checkboxGroupPlacements = options.checkboxGroupPlacements or {}
    options.checkboxGroupPlacements[GetDungeonGroupID(groupName)] =
        CopyPlacement(placement)
    return true
end

local function ResetDungeonGroupPlacement(groupName)
    ApplyDungeonGroupPlacement(groupName, {
        alongOffset = 0, edgeOffset = 0,
    })
    local options = NSkin:GetModuleOptions("GroupFinder", false)
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
        module = "GroupFinder",
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
        NSkin:ForEachScrollBoxFrame(scrollBox, function(choice)
            if self:StyleDungeonChoice(listName, owner, choice) then
                applied = true
            end
        end)
    end
    return applied
end

local function GetPVPRoleGroupPlacement()
    local options = NSkin:GetModuleOptions("GroupFinder", false)
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
    local options = NSkin:GetModuleOptions("GroupFinder", true)
    options.checkboxGroupPlacements = options.checkboxGroupPlacements or {}
    options.checkboxGroupPlacements[IDs.PVP.RoleCheckboxes] =
        CopyPlacement(placement)
    return true
end

local function ResetPVPRoleGroupPlacement()
    ApplyPVPRoleGroupPlacement({ alongOffset = 0, edgeOffset = 0 })
    local options = NSkin:GetModuleOptions("GroupFinder", false)
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
            module = "GroupFinder",
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
        NSkin:RegisterDropdown({
            id = ids.TypeDropdown,
            module = "GroupFinder",
            appearanceWindowID = ids.Scope,
            label = "PvP Quick Match type dropdown",
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
        NSkin:RegisterActionButton({
            id = ids.QueueButton,
            module = "GroupFinder",
            appearanceWindowID = ids.Scope,
            label = "PvP Quick Match join battle button",
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
            module = "GroupFinder",
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
        module = "GroupFinder",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

local function GetCompactRaidManagerControls(frame)
    local displayFrame = frame and (frame.displayFrame or frame.DisplayFrame)
    local bottomButtons = frame and frame.BottomButtons
    local raidMarkers = displayFrame
        and (displayFrame.raidMarkers or displayFrame.RaidMarkers)
    return displayFrame, bottomButtons, raidMarkers
end

function PVESkin:ApplyCompactRaidManagerWindow()
    local frame = _G.CompactRaidFrameManager
    if not frame then return false end

    if frame.Background then
        frame.Background:SetAlpha(0)
        frame.Background:Hide()
    end
    local ids = IDs.CompactRaidManager
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = ids.Scope,
        elementID = ids.Window,
        headerControlsID = ids.HeaderControls,
    })
    NSkin:RegisterSkinningElement(ids.Window, {
        label = "Compact Raid Frame Manager window",
        kind = "WINDOW",
        module = "GroupFinder",
        appearanceWindowID = ids.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
        isEditable = function()
            return frame:IsVisible()
        end,
    })
    return true
end

function PVESkin:ApplyCompactRaidManagerDropdowns()
    local frame = _G.CompactRaidFrameManager
    local displayFrame = GetCompactRaidManagerControls(frame)
    if not frame or not displayFrame then return false end
    local ids = IDs.CompactRaidManager
    local applied = false
    for index, definition in ipairs({
        { ids.ModeDropdown, "Raid manager mode dropdown",
            displayFrame.ModeControlDropdown
                or _G.CompactRaidFrameManagerDisplayFrameModeControlDropdown,
            "MENU_RAID_FRAME_CONVERT_PARTY" },
        { ids.RestrictPingsDropdown, "Raid manager restrict pings dropdown",
            displayFrame.RestrictPingsDropdown
                or _G.CompactRaidFrameManagerDisplayFrameRestrictPingsDropdown,
            "MENU_RAID_FRAME_RESTRICT_PINGS" },
    }) do
        local id, label, dropdown, menu = unpack(definition)
        if dropdown then
            applied = NSkin:RegisterDropdown({
                id = id,
                module = "GroupFinder",
                appearanceWindowID = ids.Scope,
                label = label,
                window = frame,
                target = dropdown,
                menus = { menu },
                priority = 20 + index,
                highlightRegions = { dropdown },
                isEditable = function()
                    return frame:IsVisible() and dropdown:IsVisible()
                end,
            }) ~= nil or applied
        end
    end
    return applied
end

function PVESkin:ApplyCompactRaidManagerButtons()
    local frame = _G.CompactRaidFrameManager
    local _, bottomButtons = GetCompactRaidManagerControls(frame)
    if not frame then return false end
    local ids = IDs.CompactRaidManager
    local applied = false
    for index, definition in ipairs({
        { ids.LeavePartyButton, "Leave party button",
            _G.CompactRaidFrameManagerLeavePartyButton
                or _G.CompactRaidFrameManagerBottomButtonsLeavePartyButton
                or (bottomButtons and bottomButtons.LeavePartyButton) },
        { ids.LeaveInstanceGroupButton, "Leave instance group button",
            _G.CompactRaidFrameManagerLeaveInstanceGroupButton
                or _G.CompactRaidFrameManagerBottomButtonsLeaveInstanceGroupButton
                or (bottomButtons and bottomButtons.LeaveInstanceGroupButton) },
    }) do
        local id, label, button = unpack(definition)
        if button then
            applied = NSkin:RegisterTypedElement("BUTTON", {
                id = id,
                module = "GroupFinder",
                appearanceWindowID = ids.Scope,
                label = label,
                window = frame,
                target = button,
                priority = 30 + index,
                highlightRegions = { button },
                isEditable = function()
                    return frame:IsVisible() and button:IsVisible()
                end,
            }) ~= nil or applied
        end
    end
    return applied
end

function PVESkin:ApplyCompactRaidManagerTabs()
    local frame = _G.CompactRaidFrameManager
    local _, _, raidMarkers = GetCompactRaidManagerControls(frame)
    if not frame or not raidMarkers then return false end
    local tabs = {
        raidMarkers.raidMarkerUnitTab or raidMarkers.RaidMarkerUnitTab,
        raidMarkers.raidMarkerGroundTab or raidMarkers.RaidMarkerGroundTab,
    }
    if not tabs[1] or not tabs[2] then return false end

    local ids = IDs.CompactRaidManager
    local style = NSkin:GetAppearanceStyle(
        "tab", ids.Scope, ids.MarkerTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, ids.Scope, ids.MarkerTabs)
    for _, tab in ipairs(tabs) do
        NSkin:SkinTab(tab, raidMarkers.activeTab == tab, style, border)
    end
    if not compactRaidTabsRegistered then
        compactRaidTabsRegistered = NSkin:RegisterTabGroup(
            ids.MarkerTabs, {
                label = "Raid marker top tabs",
                kind = "TAB_GROUP",
                module = "GroupFinder",
                appearanceWindowID = ids.Scope,
                window = frame,
                tabs = tabs,
                priority = 40,
                orientation = "HORIZONTAL",
                edge = "TOP",
                getSelected = function(tab)
                    return raidMarkers.activeTab == tab
                end,
                isEditable = function()
                    return frame:IsVisible() and raidMarkers:IsVisible()
                end,
            }) == true
    end
    if compactRaidTabsRegistered then
        NSkin:ApplyTabGroupLayout(ids.MarkerTabs)
    end
    return compactRaidTabsRegistered
end

function PVESkin:ApplyCompactRaidFrameManager()
    local frame = _G.CompactRaidFrameManager
    if not frame then return false end
    local applied = self:ApplyCompactRaidManagerWindow()
    applied = self:ApplyCompactRaidManagerDropdowns() or applied
    applied = self:ApplyCompactRaidManagerButtons() or applied
    applied = self:ApplyCompactRaidManagerTabs() or applied
    return applied
end

function PVESkin:InitializeCompactRaidFrameManager()
    local frame = _G.CompactRaidFrameManager
    if not frame then return false end
    local _, _, raidMarkers = GetCompactRaidManagerControls(frame)
    if not compactRaidShowHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            PVESkin:ApplyCompactRaidFrameManager()
        end)
        compactRaidShowHooked = true
    end
    if not compactRaidTabsHooked and raidMarkers
        and type(raidMarkers.SetTab) == "function" and _G.hooksecurefunc
    then
        pcall(_G.hooksecurefunc, raidMarkers, "SetTab", function()
            PVESkin:ApplyCompactRaidManagerTabs()
        end)
        compactRaidTabsHooked = true
    end
    compactRaidInitialized = true
    return self:ApplyCompactRaidFrameManager()
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
    if compactRaidInitialized then
        self:ApplyCompactRaidFrameManager()
    end
end

NSkin:RegisterWindowSkin({
    module = "GroupFinder",
    addon = "Blizzard_GroupFinder",
    apply = function() return PVESkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "GroupFinder.CompactRaidFrameManager",
    module = "GroupFinder",
    addon = "Blizzard_CompactRaidFrames",
    apply = function()
        return PVESkin:InitializeCompactRaidFrameManager()
    end,
})

NSkin:RegisterWindowSkin({
    key = "GroupFinder.PVP",
    module = "GroupFinder",
    addon = "Blizzard_PVPUI",
    apply = function() return PVESkin:ApplyPVPControls() end,
})
