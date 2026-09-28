local _, NSkin = ...

local PVESkin = NSkin:NewModule("GroupFinder")

local IDs = {
    Scope = "GroupFinder",
    Window = "GroupFinder.Window",
    HeaderControls = "GroupFinder.HeaderControls",
    BottomTabs = "GroupFinder.BottomTabs",
    BottomTabDungeonsAndRaids =
        "GroupFinder.BottomTabs.DungeonsAndRaids",
    BottomTabPlayerVsPlayer =
        "GroupFinder.BottomTabs.PlayerVsPlayer",
    BottomTabMythicPlus =
        "GroupFinder.BottomTabs.MythicPlus",
    DungeonFinder = {
        Scope = "GroupFinder.DungeonFinder",
        RolesGroup = "GroupFinder.DungeonFinder.Roles",
        RolesSurface = "GroupFinder.DungeonFinder.Roles.Surface",
        RolesIcon = "GroupFinder.DungeonFinder.Roles.Icon",
        RolesCheckbox = "GroupFinder.DungeonFinder.Roles.Checkbox",
        DungeonListContainer =
            "GroupFinder.DungeonFinder.DungeonList.Container",
        TypeSelector = "GroupFinder.DungeonFinder.TypeSelector",
        TypeSelectorSurface =
            "GroupFinder.DungeonFinder.TypeSelector.Surface",
        TypeLabel = "GroupFinder.DungeonFinder.TypeLabel",
        FollowerHeader = "GroupFinder.DungeonFinder.Follower.Header",
        FollowerTitle = "GroupFinder.DungeonFinder.Follower.Title",
        FollowerDescription = "GroupFinder.DungeonFinder.Follower.Description",
        RandomHeader = "GroupFinder.DungeonFinder.Random.Header",
        RandomTitle = "GroupFinder.DungeonFinder.Random.Title",
        RandomDescription = "GroupFinder.DungeonFinder.Random.Description",
        RandomRewards = "GroupFinder.DungeonFinder.Random.Rewards",
        RandomRewardsLabel =
            "GroupFinder.DungeonFinder.Random.Rewards.Label",
        RandomRewardsDescription =
            "GroupFinder.DungeonFinder.Random.Rewards.Description",
        RandomRewardsItems =
            "GroupFinder.DungeonFinder.Random.Rewards.Items",
    },
    Navigation = {
        Group = "GroupFinder.Navigation",
        Surface = "GroupFinder.Navigation.Surface",
        Icon = "GroupFinder.Navigation.Icon",
        Text = "GroupFinder.Navigation.Text",
        DungeonFinder = "GroupFinder.Navigation.DungeonFinder",
        ScenarioFinder = "GroupFinder.Navigation.ScenarioFinder",
        RaidFinder = "GroupFinder.Navigation.RaidFinder",
        PremadeGroups = "GroupFinder.Navigation.PremadeGroups",
    },
    TypeDropdown = "GroupFinder.DungeonFinder.TypeDropdown",
    FindGroupButton = "GroupFinder.DungeonFinder.FindGroupButton",
    SpecificScrollBar = "GroupFinder.DungeonFinder.SpecificScrollBar",
    FollowerScrollBar = "GroupFinder.DungeonFinder.FollowerScrollBar",
    DungeonSections = "GroupFinder.DungeonFinder.DungeonSectionRows",
    SpecificDungeons = "GroupFinder.DungeonFinder.DungeonRows",
    RaidFinder = {
        Scope = "GroupFinder.RaidFinder",
        RolesGroup = "GroupFinder.RaidFinder.Roles",
        SelectionLabel = "GroupFinder.RaidFinder.SelectionLabel",
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
    Challenges = {
        Scope = "GroupFinder.ChallengesKeystone",
        Window = "GroupFinder.ChallengesKeystone.Window",
        HeaderControls = "GroupFinder.ChallengesKeystone.HeaderControls",
        StartButton = "GroupFinder.ChallengesKeystone.StartButton",
        Instructions = "GroupFinder.ChallengesKeystone.Instructions",
        DungeonName = "GroupFinder.ChallengesKeystone.DungeonName",
        TimeLimit = "GroupFinder.ChallengesKeystone.TimeLimit",
        PowerLevel = "GroupFinder.ChallengesKeystone.PowerLevel",
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
local bottomTabsCompositionConfigured = false
local navigationRegistered = false
local navigationSelectionHooked = false
local dungeonRowsRegistered = false
local dungeonListContainerRegistered = false
local dungeonRolesRegistered = false
local dungeonChoiceUpdateHooked = false
local hookedControls = setmetatable({}, { __mode = "k" })
local hookedShowControls = setmetatable({}, { __mode = "k" })
local hookedScrollBoxes = setmetatable({}, { __mode = "k" })
local pvpRoleCheckboxes = setmetatable({}, { __mode = "k" })
local pvpRoleCheckboxBaselines = setmetatable({}, { __mode = "k" })
local pvpRoleGroupAnchor
local pvpRoleGroupRegistered = false
local compactRaidInitialized = false
local compactRaidShowHooked = false
local compactRaidTabsHooked = false
local compactRaidTabsRegistered = false
local challengesInitialized = false
local challengesShowHooked = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Dungeons & Raids",
})
NSkin:RegisterAppearanceScope(IDs.DungeonFinder.Scope, {
    label = "Dungeon Finder",
    parent = IDs.Scope,
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
NSkin:RegisterAppearanceScope(IDs.Challenges.Scope, {
    label = "Mythic Keystone",
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

local function ConcealTexture(texture)
    if not texture then return end
    if texture.SetAlpha then texture:SetAlpha(0) end
    if texture.Hide then texture:Hide() end
end

local function HookRefresh(control)
    if not control or hookedControls[control] or not control.HookScript then return end
    control:HookScript("OnClick", function()
        PVESkin:QueueApply()
    end)
    hookedControls[control] = true
end

local function SuppressDungeonFinderArtwork()
    local parent = _G.LFDParentFrame
    local queueFrame = _G.LFDQueueFrame
    if parent then
        ConcealTexture(parent.RoleBackground or _G.LFDParentFrameRoleBackground)
        ConcealTexture(parent.TopTileStreaks or _G.LFDParentFrameTopTileStreaks)
        if parent.Inset then NSkin:ConcealWindowArtwork(parent.Inset) end
    end
    if queueFrame then
        ConcealTexture(queueFrame.Background or _G.LFDQueueFrameBackground)
    end
end

local function SuppressRaidFinderArtwork()
    local raidFinder = _G.RaidFinderFrame
    local queueFrame = _G.RaidFinderQueueFrame
    if raidFinder then
        ConcealTexture(raidFinder.RoleBackground or _G.RaidFinderFrameRoleBackground)
        if raidFinder.Inset then NSkin:ConcealWindowArtwork(raidFinder.Inset) end
        if raidFinder.BottomInset then
            NSkin:ConcealWindowArtwork(raidFinder.BottomInset)
        end
    end
    if queueFrame then
        ConcealTexture(queueFrame.Background or _G.RaidFinderQueueFrameBackground)
    end
end

local function GetRoleIconTexture(roleButton)
    if not roleButton then return nil end
    local texture = roleButton.GetNormalTexture and roleButton:GetNormalTexture()
    return texture or roleButton.Icon or roleButton.icon
end

local ROLE_ICON_MEDIA = {
    TANK = "Role Icons\\role-tank.png",
    HEALER = "Role Icons\\role-healer.png",
    DAMAGER = "Role Icons\\role-dps.png",
    GUIDE = "Role Icons\\role-leader.png",
}
local ROLE_ICON_PRESENTATION_KEY = "DungeonFinderRole"

local function WithIconDefaults(style, defaults)
    if not style then return style end
    local base = NSkin.baseAppearance and NSkin.baseAppearance.icon or {}
    local resolved = {}
    for key, value in pairs(style) do resolved[key] = value end

    if defaults.zoom ~= nil then
        local current = tonumber(style.zoom)
        local baseZoom = tonumber(base.zoom)
        if current == nil or current == baseZoom then
            resolved.zoom = defaults.zoom
        end
    end
    if defaults.size ~= nil then
        local current = tonumber(style.size)
        local baseSize = tonumber(base.size)
        if current == nil or current == baseSize then
            resolved.size = defaults.size
        end
    end
    return resolved
end

local function GetRolePresentation(roleButton, create)
    return NSkin:GetTextureIconPresentation(
        roleButton, ROLE_ICON_PRESENTATION_KEY, create ~= false)
end

local function GetRoleDefinitions()
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return {} end
    return {
        { IDs.Roles.Tank, "Dungeon Finder tank role",
            _G.LFDQueueFrameRoleButtonTank or queueFrame.RoleButtonTank },
        { IDs.Roles.Healer, "Dungeon Finder healer role",
            _G.LFDQueueFrameRoleButtonHealer or queueFrame.RoleButtonHealer },
        { IDs.Roles.Damage, "Dungeon Finder damage role",
            _G.LFDQueueFrameRoleButtonDPS or queueFrame.RoleButtonDPS },
        { IDs.Roles.Leader, "Dungeon Finder leader role",
            _G.LFDQueueFrameRoleButtonLeader or queueFrame.RoleButtonLeader },
    }
end

local function GetRoleTargets(targetType)
    local targets = {}
    for _, definition in ipairs(GetRoleDefinitions()) do
        local roleButton = definition[3]
        if roleButton and roleButton:IsVisible() then
            if targetType == "ICON" then
                local texture = GetRolePresentation(roleButton, false)
                if texture then targets[#targets + 1] = texture end
            elseif targetType == "CHECKBOX" then
                if roleButton.checkButton then
                    targets[#targets + 1] = roleButton.checkButton
                end
            else
                targets[#targets + 1] = roleButton
            end
        end
    end
    return targets
end

local function GetRoleTargetAppearanceID(baseID, target, targetType)
    for _, definition in ipairs(GetRoleDefinitions()) do
        local roleButton = definition[3]
        local candidate
        if targetType == "ICON" then
            candidate = roleButton
                and GetRolePresentation(roleButton, false) or nil
        elseif targetType == "CHECKBOX" then
            candidate = roleButton and roleButton.checkButton
        end
        if candidate == target then
            local suffix = targetType == "ICON" and "Icon" or "Checkbox"
            return definition[1] .. "." .. suffix
        end
    end
    return baseID
end

local function GetRoleButtonAppearanceID(roleButton, baseID, suffix)
    for _, definition in ipairs(GetRoleDefinitions()) do
        if definition[3] == roleButton then
            return definition[1] .. "." .. suffix
        end
    end
    return baseID
end

local function GetRoleButtonForTarget(target, targetType)
    for _, definition in ipairs(GetRoleDefinitions()) do
        local roleButton = definition[3]
        local candidate
        if targetType == "ICON" then
            candidate = roleButton
                and GetRolePresentation(roleButton, false) or nil
        elseif targetType == "CHECKBOX" then
            candidate = roleButton and roleButton.checkButton
        end
        if candidate == target then return roleButton end
    end
end

local function GetRoleMemberOffset(
    roleButton, targetType, previewFamilyX, previewFamilyY)
    local element = NSkin:GetSkinningElement(IDs.DungeonFinder.RolesGroup)
    local memberID = targetType == "ICON"
        and IDs.DungeonFinder.RolesIcon
        or IDs.DungeonFinder.RolesCheckbox
    local member = element and NSkin:GetCompositeMember(element, memberID)
    if not member then return 0, 0 end

    local target
    if targetType == "ICON" then
        target = GetRolePresentation(roleButton, false)
    else
        target = roleButton and roleButton.checkButton
    end
    if not target then return 0, 0 end

    local familyX, familyY
    if previewFamilyX ~= nil or previewFamilyY ~= nil then
        familyX = tonumber(previewFamilyX) or 0
        familyY = tonumber(previewFamilyY) or 0
    else
        familyX, familyY =
            NSkin:GetCompositeMemberFamilyOffset(element, member)
    end
    local appearanceID = GetRoleTargetAppearanceID(
        member.appearanceID or memberID, target, targetType)
    return NSkin:GetCompositeMemberEffectiveTargetOffset(
        element, member, appearanceID, familyX, familyY)
end

local function ApplyRoleCheckboxOffset(checkButton, x, y)
    if not checkButton or not checkButton.GetNumPoints then return false end
    local data = NSkin:GetSkinData(
        checkButton, "groupFinderRoleCheckboxPlacement")
    if not data.points then
        data.points = {}
        for index = 1, checkButton:GetNumPoints() do
            data.points[index] = { checkButton:GetPoint(index) }
        end
    end
    if #data.points == 0 then return false end

    checkButton:ClearAllPoints()
    for _, point in ipairs(data.points) do
        checkButton:SetPoint(
            point[1], point[2], point[3],
            (tonumber(point[4]) or 0) + (tonumber(x) or 0),
            (tonumber(point[5]) or 0) + (tonumber(y) or 0))
    end
    return true
end

local ROLE_SURFACE_BACKGROUND = "NSkinDungeonFinderRoleSurface"

local function RefreshRoleSurfaceAppearance(surface)
    if not surface then return false end
    local scopeID = IDs.DungeonFinder.Scope
    local appearanceID = IDs.DungeonFinder.RolesSurface
    NSkin:RegisterAppearanceParentID(
        appearanceID, IDs.DungeonFinder.RolesGroup,
        IDs.DungeonFinder.RolesGroup)
    local style = NSkin:GetAppearanceStyle("row", scopeID, appearanceID)
    if not style then return false end

    local backgroundColor =
        NSkin:GetResolvedAppearanceColor(style, "background")
    backgroundColor[4] = tonumber(style.backgroundOpacity)
        or backgroundColor[4] or 1
    local borderColor =
        NSkin:GetResolvedAppearanceColor(style, "border")

    local background =
        NSkin:GetFlatBackground(surface, ROLE_SURFACE_BACKGROUND)
    if style.showBackground ~= false then
        background = background or NSkin:CreateFlatBackground(
            surface, ROLE_SURFACE_BACKGROUND,
            backgroundColor, borderColor)
        NSkin:SetOwnedTextureColor(
            background, backgroundColor[1], backgroundColor[2],
            backgroundColor[3], backgroundColor[4])
        background:Show()
    elseif background then
        background:Hide()
    end

    local border = NSkin:GetPixelBorder(
        surface, ROLE_SURFACE_BACKGROUND .. "Border")
        or NSkin:CreatePixelBorder(
            surface, ROLE_SURFACE_BACKGROUND .. "Border",
            style.borderSize or 1, borderColor)
    NSkin:SetPixelBorderColor(border, unpack(borderColor))
    NSkin:SetPixelBorderSize(border, style.borderSize or 1)
    NSkin:SetPixelBorderPadding(border, style.borderPadding or 0)
    NSkin:SetPixelBorderShown(
        border, style.showBorder ~= false
            and (tonumber(style.borderSize) or 0) > 0)
    return true
end

local function RoleSurfaceChangeAffectsGeometry(change)
    if not change then return true end
    for _, entry in ipairs(change.changes or { change }) do
        local key = type(entry.path) == "string"
            and entry.path:match("([^.]+)$")
        if key == "width" or key == "height" then return true end
    end
    return false
end

local function GetRoleSurfaceFrame(refreshGeometry)
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return nil end
    local data = NSkin:GetSkinData(queueFrame, "groupFinderRolesSurface")
    if not data.frame then
        local surface = _G.CreateFrame("Frame", nil, queueFrame)
        surface:EnableMouse(false)
        data.frame = surface
    end
    if not data.anchor then
        local anchor = _G.CreateFrame("Frame", nil, queueFrame)
        anchor:EnableMouse(false)
        data.anchor = anchor
    end

    local roles = GetRoleTargets("SURFACE")
    local first = roles[1]
    if first and not data.anchorCaptured then
        local left, right, bottom, top
        for _, roleButton in ipairs(roles) do
            local roleLeft, roleRight, roleBottom, roleTop =
                NSkin:GetUIParentNormalizedBounds(roleButton)
            if roleLeft and roleRight and roleBottom and roleTop then
                left = not left and roleLeft or math.min(left, roleLeft)
                right = not right and roleRight or math.max(right, roleRight)
                bottom = not bottom and roleBottom
                    or math.min(bottom, roleBottom)
                top = not top and roleTop or math.max(top, roleTop)
            end
        end

        local queueLeft, _, _, queueTop =
            NSkin:GetUIParentNormalizedBounds(queueFrame)
        local uiScale = UIParent and UIParent:GetEffectiveScale() or 1
        local queueScale = queueFrame.GetEffectiveScale
            and queueFrame:GetEffectiveScale() or uiScale
        if left and right and bottom and top
            and queueLeft and queueTop
            and uiScale and uiScale ~= 0
            and queueScale and queueScale ~= 0
        then
            local scale = uiScale / queueScale
            data.anchor:ClearAllPoints()
            data.anchor:SetPoint(
                "TOPLEFT", queueFrame, "TOPLEFT",
                (left - queueLeft) * scale - 5,
                (top - queueTop) * scale + 5)
            data.anchor:SetSize(
                (right - left) * scale + 10,
                (top - bottom) * scale + 10)
            data.anchorCaptured = true
        end
    end

    if first and data.anchorCaptured and refreshGeometry ~= false then
        local style = NSkin:GetAppearanceStyle(
            "row", IDs.DungeonFinder.Scope, IDs.DungeonFinder.RolesSurface)
        local customWidth = tonumber(style and style.width)
        local customHeight = tonumber(style and style.height)
        local width = customWidth and customWidth > 0
            and customWidth or data.anchor:GetWidth()
        local height = customHeight and customHeight > 0
            and customHeight or data.anchor:GetHeight()

        data.frame:ClearAllPoints()
        data.frame:SetPoint("CENTER", data.anchor, "CENTER", 0, 0)
        data.frame:SetSize(math.max(1, width), math.max(1, height))
        if data.frame.SetFrameLevel and first.GetFrameLevel then
            data.frame:SetFrameLevel(math.max(
                queueFrame:GetFrameLevel(), first:GetFrameLevel() - 1))
        end
    end
    data.frame:Show()
    RefreshRoleSurfaceAppearance(data.frame)
    return data.frame
end

local function RefreshRoleIconAppearance(
    roleButton, previewFamilyX, previewFamilyY)
    local checkButton = roleButton and roleButton.checkButton
    local nativeIcon = GetRoleIconTexture(roleButton)
    if not roleButton or not checkButton or not nativeIcon then return false end

    local role = roleButton.role
    if not role and roleButton.GetID and roleButton:GetID() == 4 then
        role = "GUIDE"
    end
    local mediaFile = role and ROLE_ICON_MEDIA[role]
    if not mediaFile then return false end

    local scopeID = IDs.DungeonFinder.Scope
    local iconAppearanceID = GetRoleButtonAppearanceID(
        roleButton, IDs.DungeonFinder.RolesIcon, "Icon")
    NSkin:RegisterAppearanceParentID(
        iconAppearanceID, IDs.DungeonFinder.RolesIcon,
        IDs.DungeonFinder.RolesGroup)
    local iconStyle = WithIconDefaults(
        NSkin:GetAppearanceStyle("icon", scopeID, iconAppearanceID),
        { zoom = 0.14 })

    local iconX, iconY = GetRoleMemberOffset(
        roleButton, "ICON", previewFamilyX, previewFamilyY)
    local applied = NSkin:SkinTextureIcon(roleButton, {
        iconPresentation = NSkin.ICON_PRESENTATION_TEXTURE,
        presentationKey = ROLE_ICON_PRESENTATION_KEY,
        texturePath = NSkin.mediaPath .. mediaFile,
        style = iconStyle,
        borderColor = NSkin:GetResolvedAppearanceColor(iconStyle, "border"),
        borderMode = iconStyle.borderMode,
        defaultShape = "circle",
        offsetX = iconX,
        offsetY = iconY,
        desaturated = roleButton.IsEnabled
            and not roleButton:IsEnabled() or false,
        interactionTarget = roleButton,
        getHovered = function()
            return roleButton.IsMouseOver
                and roleButton:IsMouseOver() or false
        end,
        getSelected = function()
            return checkButton.GetChecked
                and checkButton:GetChecked() == true or false
        end,
        nativeDecorationRegions = {
            nativeIcon,
            roleButton.background,
            roleButton.shortageBorder,
            roleButton.IconPulse,
            roleButton.EdgePulse,
        },
    })
    local _, presentation = GetRolePresentation(roleButton, false)
    if applied and presentation and checkButton.SetFrameLevel
        and presentation.borderFrame
    then
        checkButton:SetFrameLevel(
            presentation.borderFrame:GetFrameLevel() + 1)
    end
    return applied
end

local function RefreshRoleCheckboxAppearance(roleButton)
    local checkButton = roleButton and roleButton.checkButton
    if not checkButton then return false end
    local checkboxAppearanceID = GetRoleButtonAppearanceID(
        roleButton, IDs.DungeonFinder.RolesCheckbox, "Checkbox")
    NSkin:RegisterAppearanceParentID(
        checkboxAppearanceID, IDs.DungeonFinder.RolesCheckbox,
        IDs.DungeonFinder.RolesGroup)
    NSkin:SkinCheckButton(checkButton, {
        style = NSkin:GetAppearanceStyle(
            "button", IDs.DungeonFinder.Scope, checkboxAppearanceID),
    })
    HookRefresh(checkButton)
    return true
end

local function RefreshRoleSurfaceMemberAppearance(
    element, member, change, targetType)
    local appearanceID = change and change.elementID
    if appearanceID and appearanceID ~= member.appearanceID then
        local target = NSkin:GetCompositeMemberTargetForAppearanceID(
            element, member, appearanceID)
        local roleButton = target
            and GetRoleButtonForTarget(target, targetType)
        if roleButton then
            return targetType == "ICON"
                and RefreshRoleIconAppearance(roleButton)
                or RefreshRoleCheckboxAppearance(roleButton)
        end
    end

    local refreshed
    for _, definition in ipairs(GetRoleDefinitions()) do
        local roleButton = definition[3]
        local applied = targetType == "ICON"
            and RefreshRoleIconAppearance(roleButton)
            or RefreshRoleCheckboxAppearance(roleButton)
        refreshed = applied or refreshed
    end
    return refreshed == true
end

local function RefreshRolePresentation(
    roleButton, previewTargetType, previewFamilyX, previewFamilyY,
    refreshOnly)
    local checkButton = roleButton and roleButton.checkButton
    local nativeIcon = GetRoleIconTexture(roleButton)
    if not roleButton or not checkButton or not nativeIcon then return false end

    ConcealTexture(nativeIcon)
    ConcealTexture(roleButton.background)
    ConcealTexture(roleButton.shortageBorder)
    ConcealTexture(roleButton.IconPulse)
    ConcealTexture(roleButton.EdgePulse)

    local applied
    if refreshOnly == nil or refreshOnly == "ICON" then
        applied = RefreshRoleIconAppearance(
            roleButton,
            previewTargetType == "ICON" and previewFamilyX or nil,
            previewTargetType == "ICON" and previewFamilyY or nil)
            or applied
    end
    if refreshOnly == nil or refreshOnly == "CHECKBOX" then
        local checkboxX, checkboxY = GetRoleMemberOffset(
            roleButton, "CHECKBOX",
            previewTargetType == "CHECKBOX" and previewFamilyX or nil,
            previewTargetType == "CHECKBOX" and previewFamilyY or nil)
        ApplyRoleCheckboxOffset(checkButton, checkboxX, checkboxY)
        applied = RefreshRoleCheckboxAppearance(roleButton) or applied
    end
    return applied == true
end

local function RefreshRoleIconMemberAppearance(element, member, change)
    local appearanceID = change and change.elementID
    if appearanceID and appearanceID ~= member.appearanceID then
        local target = NSkin:GetCompositeMemberTargetForAppearanceID(
            element, member, appearanceID)
        local roleButton = target
            and GetRoleButtonForTarget(target, "ICON")
        if roleButton then
            return RefreshRoleIconAppearance(roleButton)
        end
    end

    local refreshed
    for _, definition in ipairs(GetRoleDefinitions()) do
        refreshed = RefreshRoleIconAppearance(
            definition[3]) or refreshed
    end
    return refreshed == true
end

local function RefreshRoleMemberAppearance(
    element, member, change, targetType)
    local appearanceID = change and change.elementID
    if appearanceID and appearanceID ~= member.appearanceID then
        local target = NSkin:GetCompositeMemberTargetForAppearanceID(
            element, member, appearanceID)
        local roleButton = target
            and GetRoleButtonForTarget(target, targetType)
        if roleButton then
            return RefreshRolePresentation(
                roleButton, nil, nil, nil, targetType)
        end
    end

    local refreshed = false
    for _, definition in ipairs(GetRoleDefinitions()) do
        refreshed = RefreshRolePresentation(
            definition[3], nil, nil, nil, targetType) or refreshed
    end
    return refreshed == true
end

function PVESkin:ApplyRoleCheckboxes()
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    if not frame or not queueFrame then return false end
    SuppressDungeonFinderArtwork()

    local definitions = GetRoleDefinitions()
    local applied = false
    for _, definition in ipairs(definitions) do
        applied = RefreshRolePresentation(definition[3]) or applied
    end

    local roleSurface = GetRoleSurfaceFrame()
    if not dungeonRolesRegistered and #definitions > 0 and roleSurface then
        dungeonRolesRegistered = NSkin:RegisterSkinningElement(
            IDs.DungeonFinder.RolesGroup, {
                module = "GroupFinder",
                appearanceWindowID = IDs.DungeonFinder.Scope,
                label = "Dungeon Finder Roles",
                kind = "BUTTON",
                window = frame,
                target = roleSurface,
                priority = 82,
                draggable = false,
                appearanceStyles = { "row", "icon", "button" },
                appearanceTypeIDs = { "BUTTON", "ICON", "CHECKBOX" },
                editorOptions = {
                    { id = "shared.surfaceAppearance", label = "Surface",
                        presentation = "INLINE", category = "CUSTOMIZE" },
                    { id = "shared.iconAppearance", label = "Icon",
                        category = "CUSTOMIZE" },
                    { id = "shared.checkboxAppearance", label = "Checkbox",
                        category = "CUSTOMIZE" },
                },
                composition = {
                    mode = "COMPOSITE",
                    type = "REGULAR",
                    editorLabel = "Dungeon Finder Roles",
                    memberEditorLabels = {
                        BUTTON = "Surface",
                        ICON = "Icon",
                        CHECKBOX = "Checkbox",
                    },
                    editorOptionLabels = {
                        ["shared.surfaceAppearance"] = "Surface",
                        ["shared.iconAppearance"] = "Icon",
                        ["shared.checkboxAppearance"] = "Checkbox",
                    },
                    primaryEditorOptionID = "shared.surfaceAppearance",
                    layout = {
                        orientation = "HORIZONTAL",
                        distribution = "EQUAL_SLOTS",
                        surfaceMemberID = IDs.DungeonFinder.RolesSurface,
                        targets = function()
                            return GetRoleTargets("SURFACE")
                        end,
                    },
                    members = {
                        {
                            id = IDs.DungeonFinder.RolesSurface,
                            kind = "BUTTON",
                            role = "PRIMARY",
                            label = "Dungeon Finder roles",
                            target = roleSurface,
                            appearanceWindowID = IDs.DungeonFinder.Scope,
                            appearanceID = IDs.DungeonFinder.RolesSurface,
                            appearanceParentID = IDs.DungeonFinder.RolesGroup,
                            editorSurface = true,
                            surfaceStyle = "Role Select",
                            surfaceAppearanceKey = "row",
                            allowOverrides = true,
                            editorOptions =
                                NSkin:GetCompositeSurfaceEditorOptions(),
                            refreshAppearance = function(
                                _, _, change)
                                local refreshGeometry =
                                    RoleSurfaceChangeAffectsGeometry(change)
                                local surface =
                                    GetRoleSurfaceFrame(refreshGeometry)
                                if not surface then return false end
                                if refreshGeometry then
                                    NSkin:ApplyCompositeLayout(
                                        IDs.DungeonFinder.RolesGroup)
                                end
                                return true
                            end,
                        },
                        {
                            id = IDs.DungeonFinder.RolesIcon,
                            kind = "ICON",
                            role = "SECONDARY",
                            label = "Role icons",
                            appearanceWindowID = IDs.DungeonFinder.Scope,
                            appearanceID = IDs.DungeonFinder.RolesIcon,
                            appearanceParentID = IDs.DungeonFinder.RolesGroup,
                            iconPresentation = NSkin.ICON_PRESENTATION_TEXTURE,
                            presentationKey = ROLE_ICON_PRESENTATION_KEY,
                            defaultShape = "circle",
                            highlightMode = "REGIONS",
                            separateHighlightRegions = true,
                            highlightBorderPadding = 0,
                            getTargetAppearanceID = function(_, member, target)
                                return GetRoleTargetAppearanceID(
                                    member.appearanceID
                                        or IDs.DungeonFinder.RolesIcon,
                                    target, "ICON")
                            end,
                            refreshSurfaceAppearance = function(
                                element, member, change)
                                return RefreshRoleSurfaceMemberAppearance(
                                    element, member, change, "ICON")
                            end,
                            refreshComponentAppearance = function(
                                element, member, change)
                                return RefreshRoleIconMemberAppearance(
                                    element, member, change)
                            end,
                            refreshAppearance = function(
                                element, member, change)
                                return RefreshRoleMemberAppearance(
                                    element, member, change, "ICON")
                            end,
                            applyFamilyOffset = function(_, _, x, y)
                                for _, definition in ipairs(
                                    GetRoleDefinitions())
                                do
                                    RefreshRolePresentation(
                                        definition[3], "ICON", x, y, "ICON")
                                end
                                GetRoleSurfaceFrame()
                                return true
                            end,
                            applyTargetOffset = function(_, _, target)
                                local roleButton =
                                    GetRoleButtonForTarget(target, "ICON")
                                if not roleButton then return false end
                                RefreshRolePresentation(
                                    roleButton, nil, nil, nil, "ICON")
                                GetRoleSurfaceFrame()
                                return true
                            end,
                            targets = function()
                                return GetRoleTargets("ICON")
                            end,
                        },
                        {
                            id = IDs.DungeonFinder.RolesCheckbox,
                            kind = "CHECKBOX",
                            role = "SECONDARY",
                            label = "Role checkboxes",
                            appearanceWindowID = IDs.DungeonFinder.Scope,
                            appearanceID = IDs.DungeonFinder.RolesCheckbox,
                            appearanceParentID = IDs.DungeonFinder.RolesGroup,
                            highlightMode = "REGIONS",
                            separateHighlightRegions = true,
                            highlightBorderPadding = 0,
                            getTargetAppearanceID = function(_, member, target)
                                return GetRoleTargetAppearanceID(
                                    member.appearanceID
                                        or IDs.DungeonFinder.RolesCheckbox,
                                    target, "CHECKBOX")
                            end,
                            refreshSurfaceAppearance = function(
                                element, member, change)
                                return RefreshRoleSurfaceMemberAppearance(
                                    element, member, change, "CHECKBOX")
                            end,
                            refreshComponentAppearance = function(
                                element, member, change)
                                return RefreshRoleMemberAppearance(
                                    element, member, change, "CHECKBOX")
                            end,
                            refreshAppearance = function(
                                element, member, change)
                                return RefreshRoleMemberAppearance(
                                    element, member, change, "CHECKBOX")
                            end,
                            applyFamilyOffset = function(_, _, x, y)
                                for _, definition in ipairs(
                                    GetRoleDefinitions())
                                do
                                    RefreshRolePresentation(
                                        definition[3], "CHECKBOX", x, y,
                                        "CHECKBOX")
                                end
                                GetRoleSurfaceFrame()
                                return true
                            end,
                            applyTargetOffset = function(_, _, target)
                                local roleButton =
                                    GetRoleButtonForTarget(
                                        target, "CHECKBOX")
                                if not roleButton then return false end
                                RefreshRolePresentation(
                                    roleButton, nil, nil, nil, "CHECKBOX")
                                GetRoleSurfaceFrame()
                                return true
                            end,
                            targets = function()
                                return GetRoleTargets("CHECKBOX")
                            end,
                        },
                    },
                },
                highlightRegions = { roleSurface },
                pixelBorderTargets = { roleSurface },
                refreshAppearance = function()
                    return PVESkin:ApplyRoleCheckboxes()
                end,
                refreshLayout = function()
                    return PVESkin:ApplyRoleCheckboxes()
                end,
                isEditable = function()
                    return frame:IsVisible() and queueFrame:IsVisible()
                        and roleSurface:IsVisible()
                end,
            }) == true
        if dungeonRolesRegistered then
            for _, definition in ipairs(definitions) do
                RefreshRolePresentation(definition[3])
            end
            GetRoleSurfaceFrame()
        end
    end

    if dungeonRolesRegistered then
        NSkin:ApplyCompositeLayout(IDs.DungeonFinder.RolesGroup)
        NSkin:NotifySkinningElementBoundsChanged(
            IDs.DungeonFinder.RolesGroup)
    end
    return applied or dungeonRolesRegistered
end

function PVESkin:ApplyTypeDropdown()
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    local dropdown = queueFrame and queueFrame.TypeDropdown
    if not frame or not dropdown then return false end

    local typeLabel = _G.LFDQueueFrameTypeDropdownName or dropdown.Name
    if not typeLabel then return false end

    local scopeID = IDs.DungeonFinder.Scope
    local surfaceID = IDs.DungeonFinder.TypeSelectorSurface

    local surfaceState = NSkin:GetSkinData(
        queueFrame, "dungeonFinderTypeSelectorSurface")
    local surface = surfaceState.frame
    if not surface then
        surface = CreateFrame("Button", nil, queueFrame)
        surface:EnableMouse(false)
        surfaceState.frame = surface
    end

    local function LayoutSurface()
        surface:ClearAllPoints()
        surface:SetPoint("TOPLEFT", typeLabel, "TOPLEFT", 0, 0)
        surface:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 0, 0)
        if dropdown.GetFrameLevel and surface.SetFrameLevel then
            surface:SetFrameLevel(
                math.max(0, (dropdown:GetFrameLevel() or 1) - 1))
        end
        return true
    end

    local function ApplyTargetOffset(target, baselineID, x, y)
        local baseline = NSkin:CaptureComponentBaseline(
            baselineID, target, { points = true })
        local points = baseline and baseline.points
        if not points or not target.ClearAllPoints or not target.SetPoint then
            return false
        end
        target:ClearAllPoints()
        for _, point in ipairs(points) do
            target:SetPoint(
                point[1], point[2], point[3],
                (point[4] or 0) + (tonumber(x) or 0),
                (point[5] or 0) + (tonumber(y) or 0))
        end
        return true
    end

    local function ApplyCompositeOffsets(element)
        if not element then return false end
        local surfaceMember = NSkin:GetCompositeMember(element, surfaceID)
        local textMember = NSkin:GetCompositeMember(
            element, IDs.DungeonFinder.TypeLabel)
        local dropdownMember = NSkin:GetCompositeMember(
            element, IDs.TypeDropdown)
        if not surfaceMember or not textMember or not dropdownMember then
            return false
        end

        local groupX, groupY =
            NSkin:GetCompositeMemberFamilyOffset(element, surfaceMember)
        local textX, textY =
            NSkin:GetCompositeMemberFamilyOffset(element, textMember)
        local dropdownX, dropdownY =
            NSkin:GetCompositeMemberFamilyOffset(element, dropdownMember)

        local textApplied = ApplyTargetOffset(
            typeLabel,
            IDs.DungeonFinder.TypeLabel .. ":GroupBaseline",
            (groupX or 0) + (textX or 0),
            (groupY or 0) + (textY or 0))
        local dropdownApplied = ApplyTargetOffset(
            dropdown,
            IDs.TypeDropdown .. ":GroupBaseline",
            (groupX or 0) + (dropdownX or 0),
            (groupY or 0) + (dropdownY or 0))
        LayoutSurface()
        return textApplied and dropdownApplied
    end

    local function SkinDropdownMember(appearanceID)
        return NSkin:SkinTypedElement("DROPDOWN", {
            id = appearanceID or IDs.TypeDropdown,
            appearanceWindowID = scopeID,
            target = dropdown,
            menus = { "MENU_LFD_FRAME" },
        })
    end

    local function SkinTextMember(appearanceID)
        return NSkin:SkinTypedElement("TEXT", {
            id = appearanceID or IDs.DungeonFinder.TypeLabel,
            appearanceWindowID = scopeID,
            target = typeLabel,
            defaultColor = true,
        })
    end

    local function SkinGroupSurface(appearanceID)
        LayoutSurface()
        local style = NSkin:GetAppearanceStyle(
            "row", scopeID, appearanceID or surfaceID)
        local border = NSkin:GetResolvedAppearanceColor(style, "border")
            or style.border or NSkin:GetSharedBorderColor()
        local background = NSkin:GetResolvedAppearanceColor(
            style, "background") or style.background or { 0, 0, 0, 0 }
        NSkin:CreateFlatBackground(surface, nil, background, border)
        NSkin:CreateFlatButtonGlow(surface, style.hoverAlpha)
        NSkin:ApplyButtonSurface(surface, style)
        return true
    end

    SkinDropdownMember(IDs.TypeDropdown)
    SkinTextMember(IDs.DungeonFinder.TypeLabel)
    SkinGroupSurface(surfaceID)

    local registered = NSkin:RegisterSkinningElement(
        IDs.DungeonFinder.TypeSelector, {
            module = "GroupFinder",
            appearanceWindowID = scopeID,
            label = "Dungeon Finder type selector",
            kind = "COMPOSITE",
            window = frame,
            target = dropdown,
            priority = 80,
            draggable = false,
            appearanceStyles = { "text", "button" },
            appearanceTypeIDs = { "TEXT", "DROPDOWN" },
            composition = {
                mode = "COMPOSITE",
                type = "REGULAR",
                editorLabel = "Dungeon Finder type selector",
                memberEditorLabels = {
                    TEXT = "Text",
                    DROPDOWN = "Dropdown",
                },
                members = {
                    {
                        id = surfaceID,
                        kind = "BUTTON",
                        role = "PRIMARY",
                        label = "Dungeon Finder type selector",
                        target = surface,
                        appearanceWindowID = scopeID,
                        appearanceID = surfaceID,
                        appearanceParentID =
                            IDs.DungeonFinder.TypeSelector,
                        editorSurface = true,
                        surfaceAppearanceKey = "row",
                        allowOverrides = true,
                        editorOptions =
                            NSkin:GetCompositeSurfaceEditorOptions(),
                        applyFamilyOffset = function(element)
                            return ApplyCompositeOffsets(element)
                        end,
                        refreshAppearance = function(_, member, change)
                            return SkinGroupSurface(
                                change and change.elementID
                                    or member.appearanceID)
                        end,
                    },
                    {
                        id = IDs.DungeonFinder.TypeLabel,
                        kind = "TEXT",
                        role = "PRIMARY",
                        label = "Text",
                        target = typeLabel,
                        appearanceWindowID = scopeID,
                        appearanceID = IDs.DungeonFinder.TypeLabel,
                        appearanceParentID = IDs.DungeonFinder.TypeLabel,
                        tightTextBounds = true,
                        applyFamilyOffset = function(element)
                            return ApplyCompositeOffsets(element)
                        end,
                        refreshAppearance = function(_, member, change)
                            return SkinTextMember(
                                change and change.elementID
                                    or member.appearanceParentID)
                        end,
                    },
                    {
                        id = IDs.TypeDropdown,
                        kind = "DROPDOWN",
                        role = "SECONDARY",
                        label = "Dropdown",
                        target = dropdown,
                        appearanceWindowID = scopeID,
                        appearanceID = IDs.TypeDropdown,
                        appearanceParentID = IDs.TypeDropdown,
                        applyFamilyOffset = function(element)
                            return ApplyCompositeOffsets(element)
                        end,
                        refreshAppearance = function(_, member, change)
                            return SkinDropdownMember(
                                change and change.elementID
                                    or member.appearanceParentID)
                        end,
                    },
                },
            },
            highlightRegions = { surface },
            pixelBorderTargets = { surface, dropdown },
            refreshAppearance = function()
                local groupApplied = SkinGroupSurface(surfaceID)
                local textApplied =
                    SkinTextMember(IDs.DungeonFinder.TypeLabel)
                local dropdownApplied =
                    SkinDropdownMember(IDs.TypeDropdown)
                return groupApplied and textApplied and dropdownApplied
            end,
            refreshLayout = function(_, element)
                local positioned = ApplyCompositeOffsets(element)
                local groupApplied = SkinGroupSurface(surfaceID)
                local textApplied =
                    SkinTextMember(IDs.DungeonFinder.TypeLabel)
                local dropdownApplied =
                    SkinDropdownMember(IDs.TypeDropdown)
                NSkin:NotifySkinningElementBoundsChanged(
                    IDs.DungeonFinder.TypeSelector)
                return positioned and groupApplied
                    and textApplied and dropdownApplied
            end,
            isEditable = function()
                return frame:IsVisible() and queueFrame:IsVisible()
                    and dropdown:IsVisible() and typeLabel:IsVisible()
            end,
        })

    HookRefresh(dropdown)
    return registered == true
end

function PVESkin:ApplyFindGroupButton()
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    local button = _G.LFDQueueFrameFindGroupButton
        or (queueFrame and queueFrame.FindGroupButton)
    if not frame or not queueFrame or not button then return false end

    NSkin:RegisterButton({
        id = IDs.FindGroupButton,
        module = "GroupFinder",
        appearanceWindowID = IDs.DungeonFinder.Scope,
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

function PVESkin:ApplyDungeonScrollBars()
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    if not frame or not queueFrame then return false end

    local applied = false
    for _, definition in ipairs({
        { IDs.SpecificScrollBar, "Specific dungeon scroll bar",
            queueFrame.Specific },
        { IDs.FollowerScrollBar, "Follower dungeon scroll bar",
            queueFrame.Follower },
    }) do
        local id, label, owner = unpack(definition)
        local scrollBar = owner and owner.ScrollBar
        if scrollBar then
            applied = NSkin:RegisterScrollBar({
                id = id,
                module = "GroupFinder",
                appearanceWindowID = IDs.DungeonFinder.Scope,
                label = label,
                window = frame,
                target = scrollBar,
                priority = 80,
                highlightRegions = { scrollBar },
                isEditable = function()
                    return frame:IsVisible() and owner:IsVisible()
                        and scrollBar:IsVisible()
                end,
            }) ~= nil or applied
            if not hookedShowControls[scrollBar] and scrollBar.HookScript then
                scrollBar:HookScript("OnShow", function()
                    PVESkin:QueueApply()
                end)
                hookedShowControls[scrollBar] = true
            end
        end
    end
    return applied
end

local function RegisterCompositeParent(definition)
    if not definition or not definition.id or not definition.target then
        return nil
    end
    return NSkin:RegisterSkinningElement(definition.id, {
        module = "GroupFinder",
        appearanceWindowID = definition.appearanceWindowID,
        label = definition.label,
        kind = "COMPOSITE",
        window = definition.window,
        target = definition.target,
        priority = definition.priority or 79,
        draggable = false,
        composition = {
            mode = "COMPOSITE",
            movementOwner = definition.target,
            members = definition.members or {},
        },
        highlightRegions = definition.highlightRegions,
        isEditable = definition.isEditable,
    })
end


function PVESkin:ApplyFollowerTexts()
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    local follower = queueFrame and queueFrame.Follower
    if not frame or not follower then return false end

    local title = follower.Title or _G.LFDQueueFrameFollowerTitle
    local description = follower.Description
        or _G.LFDQueueFrameFollowerDescription
    if not title or not description then return false end

    RegisterCompositeParent({
        id = IDs.DungeonFinder.FollowerHeader,
        appearanceWindowID = IDs.DungeonFinder.Scope,
        label = "Follower dungeon header",
        window = frame,
        target = follower,
        priority = 80,
        members = {
            { kind = "TEXT", role = "PRIMARY",
                target = title, label = "Title" },
            { kind = "TEXT", role = "SECONDARY",
                target = description, label = "Description" },
        },
        highlightRegions = { title, description },
        isEditable = function()
            return frame:IsVisible() and follower:IsVisible()
        end,
    })

    local applied = false
    for _, definition in ipairs({
        { IDs.DungeonFinder.FollowerTitle,
            "Follower dungeon title", title },
        { IDs.DungeonFinder.FollowerDescription,
            "Follower dungeon description", description },
    }) do
        local id, label, target = unpack(definition)
        applied = NSkin:RegisterTextElement({
            id = id,
            module = "GroupFinder",
            appearanceWindowID = IDs.DungeonFinder.Scope,
            label = label,
            window = frame,
            target = target,
            highlightRegions = { target },
            priority = 81,
            compositionParentID = IDs.DungeonFinder.FollowerHeader,
            isEditable = function()
                return frame:IsVisible() and follower:IsVisible()
                    and target:IsVisible()
            end,
        }) ~= nil or applied
    end
    return applied
end

local function GetRandomDungeonChildFrame()
    local queueFrame = _G.LFDQueueFrame
    local random = queueFrame and queueFrame.Random
    local scrollFrame = random and (random.ScrollFrame or random.scrollFrame)
    return (scrollFrame and (scrollFrame.ChildFrame or scrollFrame.childFrame))
        or _G.LFDQueueFrameRandomScrollFrameChildFrame
end

local function SkinRandomRewardItem(frame, child, item, suffix)
    if not item then return false end
    local idBase = IDs.DungeonFinder.RandomRewards .. "." .. suffix
    local icon = item.Icon
    local name = item.Name
    local applied = false

    if item.NameFrame then ConcealTexture(item.NameFrame) end
    if item.IconBorder then ConcealTexture(item.IconBorder) end

    if icon then
        applied = NSkin:RegisterIcon({
            id = idBase .. ".Icon",
            module = "GroupFinder",
            appearanceWindowID = IDs.DungeonFinder.Scope,
            label = "Random dungeon reward " .. suffix .. " icon",
            window = frame,
            target = item,
            texture = icon,
            borderOwner = item,
            priority = 85,
            draggable = false,
            compositionParentID = IDs.DungeonFinder.RandomRewards,
            highlightRegions = { icon },
            pixelBorderTargets = { icon },
            skinOptions = {
                defaultShape = "square",
                nativeDecorationRegions = { item.IconBorder },
            },
            isEditable = function()
                return frame:IsVisible() and child:IsVisible()
                    and item:IsVisible() and icon:IsVisible()
            end,
        }) ~= nil or applied
    end

    if name then
        local element = NSkin:RegisterTextElement({
            id = idBase .. ".Name",
            module = "GroupFinder",
            appearanceWindowID = IDs.DungeonFinder.Scope,
            label = "Random dungeon reward " .. suffix .. " name",
            window = frame,
            target = name,
            priority = 85,
            compositionParentID = IDs.DungeonFinder.RandomRewards,
            highlightRegions = { name },
            isEditable = function()
                return frame:IsVisible() and child:IsVisible()
                    and item:IsVisible() and name:IsVisible()
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end
    return applied
end

function PVESkin:ApplyRandomDungeonContent()
    local frame = _G.PVEFrame
    local child = GetRandomDungeonChildFrame()
    if not frame or not child then return false end

    local title = child.title or child.Title
    local description = child.description or child.Description
    if title and description then
        RegisterCompositeParent({
            id = IDs.DungeonFinder.RandomHeader,
            appearanceWindowID = IDs.DungeonFinder.Scope,
            label = "Random dungeon header",
            window = frame,
            target = child,
            priority = 82,
            members = {
                { kind = "TEXT", role = "PRIMARY",
                    target = title, label = "Title" },
                { kind = "TEXT", role = "SECONDARY",
                    target = description, label = "Description" },
            },
            highlightRegions = { title, description },
            isEditable = function()
                return frame:IsVisible() and child:IsVisible()
            end,
        })
    end

    local applied = false
    for _, definition in ipairs({
        { IDs.DungeonFinder.RandomTitle,
            "Random dungeon title", title },
        { IDs.DungeonFinder.RandomDescription,
            "Random dungeon description", description },
    }) do
        local id, label, target = unpack(definition)
        if target then
            applied = NSkin:RegisterTextElement({
                id = id,
                module = "GroupFinder",
                appearanceWindowID = IDs.DungeonFinder.Scope,
                label = label,
                window = frame,
                target = target,
                highlightRegions = { target },
                priority = 83,
                compositionParentID = IDs.DungeonFinder.RandomHeader,
                isEditable = function()
                    return frame:IsVisible() and child:IsVisible()
                        and target:IsVisible()
                end,
            }) ~= nil or applied
        end
    end

    local rewardsLabel = child.rewardsLabel or child.RewardsLabel
    local rewardsDescription =
        child.rewardsDescription or child.RewardsDescription

    local rewardMembers = {}
    if rewardsLabel then
        rewardMembers[#rewardMembers + 1] = {
            kind = "TEXT", role = "PRIMARY",
            target = rewardsLabel, label = "Rewards label",
        }
    end
    if rewardsDescription then
        rewardMembers[#rewardMembers + 1] = {
            kind = "TEXT", role = "SECONDARY",
            target = rewardsDescription, label = "Rewards description",
        }
    end

    local childName = child.GetName and child:GetName()
    local count = tonumber(child.numRewardFrames) or 1
    local rewardItems = {}
    for index = 1, count do
        local item = (childName and _G[childName .. "Item" .. index])
            or child["Item" .. index]
        if item then
            rewardItems[#rewardItems + 1] = {
                item = item, suffix = "Item" .. index,
            }
            if item.Icon then
                rewardMembers[#rewardMembers + 1] = {
                    kind = "ICON", role = "SECONDARY",
                    target = item.Icon, label = "Reward " .. index .. " icon",
                }
            end
            if item.Name then
                rewardMembers[#rewardMembers + 1] = {
                    kind = "TEXT", role = "SECONDARY",
                    target = item.Name, label = "Reward " .. index .. " name",
                }
            end
        end
    end

    local money = child.MoneyReward
    if money then
        rewardItems[#rewardItems + 1] = {
            item = money, suffix = "MoneyReward",
        }
        if money.Icon then
            rewardMembers[#rewardMembers + 1] = {
                kind = "ICON", role = "SECONDARY",
                target = money.Icon, label = "Money reward icon",
            }
        end
        if money.Name then
            rewardMembers[#rewardMembers + 1] = {
                kind = "TEXT", role = "SECONDARY",
                target = money.Name, label = "Money reward name",
            }
        end
    end

    if #rewardMembers > 0 then
        RegisterCompositeParent({
            id = IDs.DungeonFinder.RandomRewards,
            appearanceWindowID = IDs.DungeonFinder.Scope,
            label = "Random dungeon rewards",
            window = frame,
            target = child,
            priority = 84,
            members = rewardMembers,
            highlightRegions = function()
                local regions = {}
                for _, member in ipairs(rewardMembers) do
                    if member.target and member.target:IsVisible() then
                        regions[#regions + 1] = member.target
                    end
                end
                return regions
            end,
            isEditable = function()
                return frame:IsVisible() and child:IsVisible()
            end,
        })
    end

    for _, definition in ipairs({
        { IDs.DungeonFinder.RandomRewardsLabel,
            "Random dungeon rewards label", rewardsLabel },
        { IDs.DungeonFinder.RandomRewardsDescription,
            "Random dungeon rewards description", rewardsDescription },
    }) do
        local id, label, target = unpack(definition)
        if target then
            applied = NSkin:RegisterTextElement({
                id = id,
                module = "GroupFinder",
                appearanceWindowID = IDs.DungeonFinder.Scope,
                label = label,
                window = frame,
                target = target,
                highlightRegions = { target },
                priority = 84,
                compositionParentID = IDs.DungeonFinder.RandomRewards,
                isEditable = function()
                    return frame:IsVisible() and child:IsVisible()
                        and target:IsVisible()
                end,
            }) ~= nil or applied
        end
    end

    for _, reward in ipairs(rewardItems) do
        applied = SkinRandomRewardItem(
            frame, child, reward.item, reward.suffix) or applied
    end

    local xpLabel = child.xpLabel or child.XPLabel
    local xpAmount = child.xpAmount or child.XPAmount
    if xpLabel then
        local element = NSkin:RegisterTextElement({
            id = IDs.DungeonFinder.RandomRewards .. ".XPLabel",
            module = "GroupFinder",
            appearanceWindowID = IDs.DungeonFinder.Scope,
            label = "Random dungeon XP label",
            window = frame,
            target = xpLabel,
            priority = 84,
            compositionParentID = IDs.DungeonFinder.RandomRewards,
            highlightRegions = { xpLabel },
            isEditable = function()
                return frame:IsVisible() and child:IsVisible()
                    and xpLabel:IsVisible()
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end
    if xpAmount then
        local element = NSkin:RegisterTextElement({
            id = IDs.DungeonFinder.RandomRewards .. ".XPAmount",
            module = "GroupFinder",
            appearanceWindowID = IDs.DungeonFinder.Scope,
            label = "Random dungeon XP amount",
            window = frame,
            target = xpAmount,
            priority = 84,
            compositionParentID = IDs.DungeonFinder.RandomRewards,
            highlightRegions = { xpAmount },
            isEditable = function()
                return frame:IsVisible() and child:IsVisible()
                    and xpAmount:IsVisible()
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    return applied
end

local function RegisterRaidFinderRoleComposite(
    id, label, scopeID, groupID, groupLabel, frame, visibilityOwner, roleButton)
    local checkButton = roleButton and roleButton.checkButton
    local nativeIcon = GetRoleIconTexture(roleButton)
    if not roleButton or not checkButton or not nativeIcon then return false end
    local icon, rolePresentation = GetRolePresentation(roleButton)

    local function Refresh()
        ConcealTexture(nativeIcon)
        ConcealTexture(roleButton.background)
        ConcealTexture(roleButton.shortageBorder)
        ConcealTexture(roleButton.IconPulse)
        ConcealTexture(roleButton.EdgePulse)

        local role = roleButton.role
        if not role and roleButton.GetID and roleButton:GetID() == 4 then
            role = "GUIDE"
        end
        local mediaFile = role and ROLE_ICON_MEDIA[role]
        if mediaFile then
            icon:SetTexture(NSkin.mediaPath .. mediaFile)
            icon:SetTexCoord(0, 1, 0, 1)
        end
        if icon.SetDesaturated and roleButton.IsEnabled then
            icon:SetDesaturated(not roleButton:IsEnabled())
        end

        local iconStyle = WithIconDefaults(
            NSkin:GetAppearanceStyle("icon", scopeID, groupID),
            { zoom = 0.14 })
        local crop = math.max(0.01, math.min(1,
            tonumber(iconStyle.crop) or 1))
        local customSize = tonumber(iconStyle.size)
        customSize = customSize and customSize > 0 and customSize or nil
        local width = customSize or roleButton:GetWidth()
        local height = customSize or roleButton:GetHeight()
        local clipFrame = rolePresentation.clipFrame
        local borderFrame = rolePresentation.borderFrame
        clipFrame:ClearAllPoints()
        clipFrame:SetPoint("CENTER", roleButton, "CENTER", 0, 0)
        clipFrame:SetSize(width, height * crop)
        borderFrame:ClearAllPoints()
        borderFrame:SetPoint("CENTER", roleButton, "CENTER", 0, 0)
        borderFrame:SetSize(width, height)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", clipFrame, "CENTER", 0, 0)
        icon:SetSize(width, height)

        NSkin:SkinIcon(icon, {
            texture = icon,
            borderOwner = borderFrame,
            shapeMaskOwner = clipFrame,
            style = iconStyle,
            crop = 1,
            borderCrop = crop,
            borderColor = NSkin:GetResolvedAppearanceColor(
                iconStyle, "border"),
            borderMode = iconStyle.borderMode,
            defaultShape = "circle",
        })
        NSkin:SkinCheckButton(checkButton, {
            style = NSkin:GetAppearanceStyle("button", scopeID, groupID),
        })
        NSkin:NotifySkinningElementBoundsChanged(id)
        return true
    end

    local registered = NSkin:RegisterSkinningElement(id, {
        module = "GroupFinder",
        appearanceWindowID = scopeID,
        label = label,
        kind = "ICON",
        window = frame,
        target = roleButton,
        priority = 82,
        draggable = false,
        defaultShape = "circle",
        anchorGroupID = groupID,
        anchorGroupLabel = groupLabel,
        anchorGroupAppearanceSource = groupID,
        composition = {
            mode = "COMPOSITE",
            movementOwner = roleButton,
            members = {
                { id = id .. ".Icon", kind = "ICON", role = "PRIMARY",
                    target = icon, label = "Role icon",
                    appearanceID = groupID },
                { id = id .. ".Checkbox", kind = "CHECKBOX",
                    role = "SECONDARY", target = checkButton,
                    label = "Role selection", appearanceID = groupID },
            },
        },
        highlightRegions = { icon, checkButton },
        pixelBorderTargets = { roleButton },
        refreshAppearance = Refresh,
        refreshLayout = Refresh,
        isEditable = function()
            return frame:IsVisible()
                and (not visibilityOwner or visibilityOwner:IsVisible())
                and roleButton:IsVisible()
        end,
    })
    Refresh()
    return registered == true
end

function PVESkin:ApplyRaidFinderControls()
    local frame = _G.PVEFrame
    local raidFinder = _G.RaidFinderFrame
    local queueFrame = _G.RaidFinderQueueFrame
    if not frame or not raidFinder or not queueFrame then return false end

    SuppressRaidFinderArtwork()
    local scopeID = IDs.RaidFinder.Scope
    local applied = false
    local roleDefinitions = {
        { IDs.RaidFinder.Roles.Tank, "Raid Finder tank role",
            _G.RaidFinderQueueFrameRoleButtonTank
                or queueFrame.RoleButtonTank },
        { IDs.RaidFinder.Roles.Healer, "Raid Finder healer role",
            _G.RaidFinderQueueFrameRoleButtonHealer
                or queueFrame.RoleButtonHealer },
        { IDs.RaidFinder.Roles.Damage, "Raid Finder damage role",
            _G.RaidFinderQueueFrameRoleButtonDPS
                or queueFrame.RoleButtonDPS },
        { IDs.RaidFinder.Roles.Leader, "Raid Finder leader role",
            _G.RaidFinderQueueFrameRoleButtonLeader
                or queueFrame.RoleButtonLeader },
    }
    for _, definition in ipairs(roleDefinitions) do
        applied = RegisterRaidFinderRoleComposite(
            definition[1], definition[2], scopeID,
            IDs.RaidFinder.RolesGroup, "Raid Finder roles",
            frame, queueFrame, definition[3]) or applied
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
        local raidLabel = _G.RaidFinderQueueFrameSelectionDropdownName
            or dropdown.Name
        if raidLabel then
            NSkin:RegisterTextElement({
                id = IDs.RaidFinder.SelectionLabel,
                module = "GroupFinder",
                appearanceWindowID = scopeID,
                label = "Raid Finder selection label",
                window = frame,
                target = raidLabel,
                priority = 79,
                highlightRegions = { raidLabel },
                isEditable = function()
                    return frame:IsVisible() and queueFrame:IsVisible()
                        and raidLabel:IsVisible()
                end,
            })
        end
        HookRefresh(dropdown)
        applied = true
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
        applied = true
    end

    if not hookedShowControls[raidFinder] and raidFinder.HookScript then
        raidFinder:HookScript("OnShow", function()
            PVESkin:QueueApply()
        end)
        hookedShowControls[raidFinder] = true
    end
    return applied
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

local function GetDungeonRowFamilyID(choice)
    local dungeonID = choice and choice.id
    local isHeader = dungeonID
        and type(_G.LFGIsIDHeader) == "function"
        and _G.LFGIsIDHeader(dungeonID)
    return isHeader and IDs.DungeonSections or IDs.SpecificDungeons, isHeader
end

local activeDungeonRowPass

local function BuildDungeonRowPass()
    local pass = {
        owners = {},
        headers = {},
        rows = {},
        targetOwners = setmetatable({}, { __mode = "k" }),
    }
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return pass end

    for _, owner in ipairs({ queueFrame.Specific, queueFrame.Follower }) do
        local scrollBox = owner and owner.ScrollBox
        local ownerPass = {
            owner = owner,
            scrollBox = scrollBox,
            allRows = {},
            visibleRows = {},
        }
        pass.owners[#pass.owners + 1] = ownerPass
        NSkin:ForEachScrollBoxFrame(scrollBox, function(choice)
            ownerPass.allRows[#ownerPass.allRows + 1] = choice
            local visible = not choice.IsVisible or choice:IsVisible()
            if visible then
                ownerPass.visibleRows[#ownerPass.visibleRows + 1] = choice
                local _, isHeader = GetDungeonRowFamilyID(choice)
                local familyRows = isHeader and pass.headers or pass.rows
                familyRows[#familyRows + 1] = choice
            end
            if choice.instanceName then
                pass.targetOwners[choice.instanceName] = choice
            end
            if choice.level then
                pass.targetOwners[choice.level] = choice
            end
            if choice.enableButton then
                pass.targetOwners[choice.enableButton] = choice
            end
            if choice.expandOrCollapseButton then
                pass.targetOwners[choice.expandOrCollapseButton] = choice
            end
        end)
    end
    return pass
end

local function GetVisibleDungeonRows(wantHeaders, pass)
    pass = pass or activeDungeonRowPass
    if pass then
        return wantHeaders and pass.headers or pass.rows
    end
    local snapshot = BuildDungeonRowPass()
    return wantHeaders and snapshot.headers or snapshot.rows
end

local function ApplyDungeonCheckboxComponent(choice, styleID)
    local checkButton = choice and choice.enableButton
    if not checkButton then return false end
    return NSkin:SkinTypedElement("CHECKBOX", {
        id = styleID .. ".CHECKBOX",
        appearanceWindowID = IDs.DungeonFinder.Scope,
        target = checkButton,
    })
end

local ReapplyDungeonMemberFamilyOffsets
local ReapplyDungeonRowFamilyOffsets
local RefreshDungeonRowRenderingParent

local function SkinDungeonCollapseButton(choice)
    local button = choice and choice.expandOrCollapseButton
    if not button or not button.CreateTexture then return end

    local data = NSkin:GetSkinData(button, "groupFinderCollapseButton")
    data.choice = choice

    local normal = button.GetNormalTexture and button:GetNormalTexture()
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    ConcealTexture(normal)
    ConcealTexture(highlight)

    local stateID = choice.isCollapsed == true and "expand" or "collapse"
    local appearanceID = IDs.DungeonSections .. ".BUTTON."
        .. (stateID == "expand" and "Expand" or "Collapse")
    local style = NSkin:GetAppearanceStyle(
        "button", IDs.DungeonFinder.Scope, appearanceID)
    local borderColor = NSkin:GetAppearanceBorderColor(
        "button", style, IDs.DungeonFinder.Scope, appearanceID)
    local glyphState = NSkin:SkinButton(button, {
        style = style,
        border = borderColor,
        backgroundKey = "NSkinDungeonCollapseBackground",
        glyphKey = "dungeonCollapse",
        defaultContent = {
            type = "GLYPH",
            glyph = stateID == "expand" and "plus" or "minus",
            size = 8,
        },
    })
    data.collapseGlyph = glyphState and glyphState.centeredGlyph

    if not data.hooked then
        if button.HookScript then
            button:HookScript("OnClick", function()
                C_Timer.After(0, function()
                    if data.choice then
                        PVESkin:StyleDungeonChoice(nil, nil, data.choice)
                        QueueDungeonRowLayoutRefresh()
                    end
                end)
            end)
        end
        if _G.hooksecurefunc and type(button.SetNormalTexture) == "function" then
            hooksecurefunc(button, "SetNormalTexture", function(changedButton)
                local current = changedButton:GetNormalTexture()
                ConcealTexture(current)
            end)
        end
        data.hooked = true
    end
end

local function ApplyDungeonChoiceIndent(choice, isHeader)
    if not choice then return end
    local data = NSkin:GetSkinData(choice, "groupFinderDungeonIndent")
    local lockedIndicator = choice.lockedIndicator
    local instanceName = choice.instanceName

    local function CapturePoints(region, key)
        if not region or data[key] then return end
        local points = {}
        for index = 1, region:GetNumPoints() do
            points[index] = { region:GetPoint(index) }
        end
        data[key] = points
    end

    local function RestoreWithOffset(region, points, offsetX)
        if not region or not points then return end
        region:ClearAllPoints()
        for index = 1, #points do
            local point = points[index]
            region:SetPoint(
                point[1], point[2], point[3],
                (tonumber(point[4]) or 0) + offsetX,
                tonumber(point[5]) or 0)
        end
    end

    CapturePoints(lockedIndicator, "lockedIndicatorPoints")
    CapturePoints(instanceName, "instanceNamePoints")

    local indent = 0
    if not isHeader and choice.expandOrCollapseButton then
        indent = tonumber(choice.expandOrCollapseButton:GetWidth()) or 0
    end
    RestoreWithOffset(lockedIndicator, data.lockedIndicatorPoints, indent)
    RestoreWithOffset(instanceName, data.instanceNamePoints, indent)
end

local function GetDungeonRowExactAppearanceID(baseID, choice)
    local rowID = choice and choice.id
    if rowID == nil then return baseID end
    return baseID .. ".Row." .. tostring(rowID)
end

local function CopyAppearanceValue(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = CopyAppearanceValue(child)
    end
    return copy
end

local function MergeAppearanceValues(base, overrides)
    local merged = CopyAppearanceValue(base or {})
    for key, value in pairs(overrides or {}) do
        if type(value) == "table" and type(merged[key]) == "table" then
            merged[key] = MergeAppearanceValues(merged[key], value)
        else
            merged[key] = CopyAppearanceValue(value)
        end
    end
    return merged
end

local function GetDungeonRowSurfaceStyle(styleName, elementID, exactID)
    local base = NSkin:GetAppearanceStyle(
        styleName, IDs.DungeonFinder.Scope, elementID)
    local profile = NSkin:GetProfile()
    local exact = profile.appearanceOverrides
        and profile.appearanceOverrides.elements
        and profile.appearanceOverrides.elements[exactID]
        and profile.appearanceOverrides.elements[exactID][styleName]
    return MergeAppearanceValues(base, exact)
end

local function GetDungeonTextTargetOwner(target)
    local pass = activeDungeonRowPass
    local owner = pass and pass.targetOwners[target]
    if owner then return owner end
    for _, choice in ipairs(GetVisibleDungeonRows(false, pass)) do
        if choice.instanceName == target or choice.level == target then
            return choice
        end
    end
end

local function GetDungeonTextTargetAppearanceID(baseID, target)
    local choice = GetDungeonTextTargetOwner(target)
    return choice
        and GetDungeonRowExactAppearanceID(baseID, choice)
        or baseID
end

local dungeonExactOffsetRegions = setmetatable({}, { __mode = "k" })

local function RefreshDungeonExactOffsetClipping()
    local hasActive
    for region in pairs(dungeonExactOffsetRegions) do
        local data = NSkin:GetSkinData(
            region, "dungeonExactTextOffset", false)
        if data and data.active then
            hasActive = true
            break
        end
    end

    local queueFrame = _G.LFDQueueFrame
    for _, owner in ipairs({
        queueFrame and queueFrame.Specific,
        queueFrame and queueFrame.Follower,
    }) do
        local scrollBox = owner and owner.ScrollBox
        if scrollBox and scrollBox.SetClipsChildren then
            scrollBox:SetClipsChildren(not hasActive)
        end
        local scrollTarget = scrollBox and scrollBox.ScrollTarget
        if scrollTarget and scrollTarget.SetClipsChildren then
            scrollTarget:SetClipsChildren(not hasActive)
        end
    end
end

local function RestoreDungeonTextExactBaseline(region)
    local data = region and NSkin:GetSkinData(
        region, "dungeonExactTextOffset", false)
    if not data or not data.points
        or not region.ClearAllPoints or not region.SetPoint
    then return false end
    region:ClearAllPoints()
    for _, point in ipairs(data.points) do
        region:SetPoint(unpack(point))
    end
    data.active = nil
    dungeonExactOffsetRegions[region] = nil
    RefreshDungeonExactOffsetClipping()
    return true
end

local function CaptureDungeonTextExactBaseline(region)
    if not region or not region.GetNumPoints then return nil end
    local data = NSkin:GetSkinData(region, "dungeonExactTextOffset")
    if not data.points then
        data.points = {}
        for index = 1, region:GetNumPoints() do
            data.points[index] = { region:GetPoint(index) }
        end
    end
    return data
end

local function ApplyDungeonTextExactOffset(
    region, owner, appearanceID, x, y)
    if not region or not region.ClearAllPoints or not region.SetPoint then
        return false
    end

    local data = CaptureDungeonTextExactBaseline(region)
    if not data then return false end
    data.appearanceID = appearanceID

    x, y = tonumber(x) or 0, tonumber(y) or 0
    region:ClearAllPoints()
    for _, point in ipairs(data.points) do
        region:SetPoint(
            point[1], point[2], point[3],
            (tonumber(point[4]) or 0) + x,
            (tonumber(point[5]) or 0) + y)
    end

    if x ~= 0 or y ~= 0 then
        data.active = true
        dungeonExactOffsetRegions[region] = true
    else
        data.active = nil
        dungeonExactOffsetRegions[region] = nil
    end
    RefreshDungeonExactOffsetClipping()
    return true
end

local dungeonDefaultRowExtent
local dungeonExtentState = setmetatable({}, { __mode = "k" })

local function HasDungeonExtentOffset()
    for _, data in pairs(dungeonExtentState) do
        if data.active then return true end
    end
    return false
end

local function RestoreDungeonExtentOffset(choice)
    local data = choice and dungeonExtentState[choice]
    if not data or not data.active or not data.points
        or not choice.ClearAllPoints or not choice.SetPoint
    then return false end
    choice:ClearAllPoints()
    for _, point in ipairs(data.points) do
        choice:SetPoint(unpack(point))
    end
    data.active = nil
    return true
end

local function RestoreDungeonFamilyOffsetTarget(target)
    local data = target and NSkin:GetSkinData(
        target, "dungeonRowFamilyOffset", false)
    if not data or not data.active or not data.points
        or not target.ClearAllPoints or not target.SetPoint
    then return end
    target:ClearAllPoints()
    for _, point in ipairs(data.points) do
        target:SetPoint(unpack(point))
    end
    data.active = nil
    data.appliedX, data.appliedY = nil, nil
end

local function RestoreDungeonChoiceFamilyOffsets(choice)
    if not choice then return end
    for _, target in ipairs({
        choice,
        choice.instanceName,
        choice.level,
        choice.enableButton,
        choice.expandOrCollapseButton,
    }) do
        RestoreDungeonFamilyOffsetTarget(target)
    end
end

local function ApplyDungeonFamilyOffsetTarget(target, x, y)
    if not target or not target.GetNumPoints
        or not target.ClearAllPoints or not target.SetPoint
    then return false end

    x, y = tonumber(x) or 0, tonumber(y) or 0
    local data = NSkin:GetSkinData(target, "dungeonRowFamilyOffset")

    -- A stable pooled row may be visited several times in the same Blizzard
    -- initialization burst. Do not restore/copy/reapply identical anchors.
    if data.active and data.points
        and data.appliedX == x and data.appliedY == y
    then
        return true
    end

    if data.active and data.points then
        target:ClearAllPoints()
        for _, point in ipairs(data.points) do
            target:SetPoint(unpack(point))
        end
        data.active = nil
        data.appliedX, data.appliedY = nil, nil
    end

    -- Zero family offsets need no baseline allocation. If the target was
    -- active above it has already been restored to its saved baseline.
    if x == 0 and y == 0 then return true end

    local points = data.points
    if not points or #points == 0 then
        points = {}
        for index = 1, target:GetNumPoints() do
            points[index] = { target:GetPoint(index) }
        end
        if #points == 0 then return false end
        data.points = points
    end

    target:ClearAllPoints()
    for _, point in ipairs(points) do
        target:SetPoint(
            point[1], point[2], point[3],
            (tonumber(point[4]) or 0) + x,
            (tonumber(point[5]) or 0) + y)
    end
    data.active = true
    data.appliedX, data.appliedY = x, y
    return true
end

local function HasDungeonRowFamilyOffset(elementID)
    local element = NSkin:GetSkinningElement(elementID)
    local composition = element and element.composition
    if not composition then return false end
    for _, member in ipairs(composition.members or {}) do
        local x, y = NSkin:GetCompositeMemberFamilyOffset(element, member)
        if (tonumber(x) or 0) ~= 0 or (tonumber(y) or 0) ~= 0 then
            return true
        end
    end
    return false
end

local function ReparentDungeonChoice(choice, parent)
    if not choice or not parent or not choice.GetParent
        or not choice.SetParent or choice:GetParent() == parent
    then return false end

    local oldParent = choice:GetParent()
    local points = {}
    for index = 1, choice:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y =
            choice:GetPoint(index)
        points[index] = {
            point,
            relativeTo or oldParent,
            relativePoint,
            x,
            y,
        }
    end

    choice:SetParent(parent)
    if #points > 0 then
        choice:ClearAllPoints()
        for _, point in ipairs(points) do
            choice:SetPoint(unpack(point))
        end
    end
    return true
end

RefreshDungeonRowRenderingParent = function(forceDisplaced, pass)
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return false end
    pass = pass or activeDungeonRowPass or BuildDungeonRowPass()

    -- Row-family surfaces and their Skinning Mode overlays must stay outside
    -- the ScrollTarget rendering parent even at the default 0/0 offsets.
    local displaced = true
    local changed

    for _, ownerPass in ipairs(pass.owners or {}) do
        local owner = ownerPass.owner
        local scrollBox = ownerPass.scrollBox
        local scrollTarget = scrollBox and scrollBox.GetScrollTarget
            and scrollBox:GetScrollTarget()
            or (scrollBox and scrollBox.ScrollTarget)
        if owner and scrollBox and scrollTarget then
            for _, choice in ipairs(ownerPass.allRows) do
                local data = NSkin:GetSkinData(
                    choice, "groupFinderDungeonRowParent")
                if displaced then
                    if not data.originalParent then
                        data.originalParent = choice:GetParent()
                    end
                    changed = ReparentDungeonChoice(
                        choice, owner) or changed
                elseif data.originalParent then
                    changed = ReparentDungeonChoice(
                        choice, data.originalParent) or changed
                    data.originalParent = nil
                end
            end
        end
    end
    pass.parentReady = true
    return changed == true
end

local function ApplyDungeonRowExtentFlow(pass)
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return false end

    pass = pass or activeDungeonRowPass or BuildDungeonRowPass()
    local previousPass = activeDungeonRowPass
    activeDungeonRowPass = pass
    local hasCustomExtent

    for _, ownerPass in ipairs(pass.owners or {}) do
        for _, choice in ipairs(ownerPass.allRows) do
            RestoreDungeonExtentOffset(choice)
            RestoreDungeonChoiceFamilyOffsets(choice)
            local _, isHeader = GetDungeonRowFamilyID(choice)
            local state = NSkin:GetSkinData(
                choice,
                isHeader and "sectionRowComponent" or "rowComponent",
                false)
            local originalHeight = state and tonumber(state.originalHeight)
            local currentHeight = choice.GetHeight
                and tonumber(choice:GetHeight())
            if originalHeight and currentHeight
                and math.abs(currentHeight - originalHeight) > 0.01
            then
                hasCustomExtent = true
            end
        end
    end

    RefreshDungeonRowRenderingParent(hasCustomExtent == true, pass)

    local applied
    for _, ownerPass in ipairs(pass.owners or {}) do
        local rows = {}
        for index, choice in ipairs(ownerPass.visibleRows) do
            rows[index] = choice
        end
        table.sort(rows, function(left, right)
            local leftTop = left.GetTop and left:GetTop()
            local rightTop = right.GetTop and right:GetTop()
            if leftTop and rightTop and leftTop ~= rightTop then
                return leftTop > rightTop
            end
            return tostring(left) < tostring(right)
        end)

        local cumulativeOffset = 0
        for _, choice in ipairs(rows) do
            local data = dungeonExtentState[choice]
            if not data then
                data = {}
                dungeonExtentState[choice] = data
            end
            local points = {}
            for index = 1, choice:GetNumPoints() do
                points[index] = { choice:GetPoint(index) }
            end
            data.points = points

            if math.abs(cumulativeOffset) > 0.01 and #points > 0 then
                choice:ClearAllPoints()
                for _, point in ipairs(points) do
                    choice:SetPoint(
                        point[1], point[2], point[3],
                        tonumber(point[4]) or 0,
                        (tonumber(point[5]) or 0) - cumulativeOffset)
                end
                data.active = true
                applied = true
            else
                data.active = nil
            end

            local _, isHeader = GetDungeonRowFamilyID(choice)
            local state = NSkin:GetSkinData(
                choice,
                isHeader and "sectionRowComponent" or "rowComponent",
                false)
            local originalHeight = state and tonumber(state.originalHeight)
            local currentHeight = choice.GetHeight
                and tonumber(choice:GetHeight())
            if originalHeight and currentHeight then
                local heightDelta = currentHeight - originalHeight
                cumulativeOffset = cumulativeOffset + heightDelta
            end
        end
    end

    NSkin:NotifySkinningElementBoundsChanged(IDs.DungeonSections)
    NSkin:NotifySkinningElementBoundsChanged(IDs.SpecificDungeons)
    activeDungeonRowPass = previousPass
    return applied == true or hasCustomExtent == true
end

local dungeonExtentFlowPending
local function QueueDungeonRowExtentFlow()
    if dungeonExtentFlowPending then return true end
    dungeonExtentFlowPending = true
    local function Apply()
        dungeonExtentFlowPending = nil
        local pass = BuildDungeonRowPass()
        ApplyDungeonRowExtentFlow(pass)
        ReapplyDungeonRowFamilyOffsets(true, pass)
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, Apply)
    else
        Apply()
    end
    return true
end

local function ApplyDungeonMemberFamilyOffset(element, member, x, y)
    x, y = tonumber(x) or 0, tonumber(y) or 0
    local displaced = x ~= 0 or y ~= 0

    -- Pooled row surfaces must be moved only after the row has been placed
    -- under the rendering parent. A row transaction prepares this once for
    -- every member instead of rescanning/reparenting the ScrollBox per member.
    local pass = activeDungeonRowPass
    if not pass or not pass.parentReady then
        RefreshDungeonRowRenderingParent(displaced, pass)
    end

    local targets
    if member.rowFamilySurface == true
        and type(element.highlightRegions) == "function"
    then
        local ok, resolved = pcall(element.highlightRegions, element)
        targets = ok and resolved or nil
    end
    targets = targets
        or NSkin:GetCompositionMemberTargets(element, member, false)
        or {}

    local applied
    for _, target in ipairs(targets) do
        applied = ApplyDungeonFamilyOffsetTarget(
            target, x, y) or applied
    end
    NSkin:NotifySkinningElementBoundsChanged(element.id)
    return applied == true
end

ReapplyDungeonMemberFamilyOffsets = function(elementID)
    local element = NSkin:GetSkinningElement(elementID)
    local composition = element and element.composition
    if not composition then return false end
    local applied
    for _, member in ipairs(composition.members or {}) do
        if member.movable ~= false
            and type(member.applyFamilyOffset) == "function"
        then
            local x, y = NSkin:GetCompositeMemberFamilyOffset(
                element, member)
            x, y = tonumber(x) or 0, tonumber(y) or 0
            if member.applyFamilyOffset == ApplyDungeonMemberFamilyOffset
                and member.rowFamilySurface ~= true
            then
                for _, target in ipairs(
                    NSkin:GetCompositionMemberTargets(
                        element, member, false) or {})
                do
                    applied = ApplyDungeonFamilyOffsetTarget(
                        target, x, y) or applied
                end
            else
                applied = member.applyFamilyOffset(
                    element, member, x, y) or applied
            end
        end
    end
    return applied == true
end

ReapplyDungeonRowFamilyOffsets = function(skipInitialParentRefresh, pass)
    pass = pass or activeDungeonRowPass or BuildDungeonRowPass()
    local previousPass = activeDungeonRowPass
    activeDungeonRowPass = pass

    if not skipInitialParentRefresh or not pass.parentReady then
        RefreshDungeonRowRenderingParent(nil, pass)
    end
    local applied =
        ReapplyDungeonMemberFamilyOffsets(IDs.DungeonSections)
    applied = ReapplyDungeonMemberFamilyOffsets(
        IDs.SpecificDungeons) or applied

    NSkin:NotifySkinningElementBoundsChanged(IDs.DungeonSections)
    NSkin:NotifySkinningElementBoundsChanged(IDs.SpecificDungeons)
    activeDungeonRowPass = previousPass
    return applied == true
end

local dungeonRowLayoutRefreshPending
local dungeonRowLayoutRefreshGeneration = 0

local function FlushDungeonRowLayoutRefresh()
    dungeonRowLayoutRefreshGeneration =
        dungeonRowLayoutRefreshGeneration + 1
    dungeonRowLayoutRefreshPending = nil
    local pass = BuildDungeonRowPass()
    ApplyDungeonRowExtentFlow(pass)
    ReapplyDungeonRowFamilyOffsets(true, pass)
    return true
end

local function QueueDungeonRowLayoutRefresh()
    if dungeonRowLayoutRefreshPending then return true end
    dungeonRowLayoutRefreshPending = true
    dungeonRowLayoutRefreshGeneration =
        dungeonRowLayoutRefreshGeneration + 1
    local generation = dungeonRowLayoutRefreshGeneration
    local function Apply()
        if generation ~= dungeonRowLayoutRefreshGeneration then return end
        dungeonRowLayoutRefreshPending = nil
        FlushDungeonRowLayoutRefresh()
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, Apply)
    else
        Apply()
    end
    return true
end

function PVESkin:StyleDungeonChoice(_, _, choice, options)
    if not choice or not choice.id then return false end
    options = options or {}
    if dungeonDefaultRowExtent == nil and choice.GetHeight then
        local height = tonumber(choice:GetHeight())
        if height and height > 0 then dungeonDefaultRowExtent = height end
    end
    local preserveLayout = options.preserveLayout == true
    if not preserveLayout then
        RestoreDungeonChoiceFamilyOffsets(choice)
    end
    local id, isHeader = GetDungeonRowFamilyID(choice)

    if not preserveLayout then
        if isHeader then
            NSkin:SkinRow(choice, { reset = true })
        else
            NSkin:SkinSectionRow(choice, { reset = true })
        end
        ApplyDungeonChoiceIndent(choice, isHeader)
    end

    local surfaceBaseID = id .. ".Surface"
    local surfaceAppearanceID =
        GetDungeonRowExactAppearanceID(surfaceBaseID, choice)
    NSkin:RegisterAppearanceParentID(surfaceBaseID, id, id)
    NSkin:RegisterAppearanceParentID(
        surfaceAppearanceID, surfaceBaseID, id)

    if isHeader then
        local sectionStyle = GetDungeonRowSurfaceStyle(
            "sectionRow", id, surfaceAppearanceID)
        local textStyle = NSkin:GetAppearanceStyle(
            "text", IDs.DungeonFinder.Scope, id .. ".TEXT")
        NSkin:SkinSectionRow(choice, {
            style = sectionStyle,
            contentStyle = textStyle,
            contentTextOptions = { elementID = id .. ".TEXT" },
            collapseButton = choice.expandOrCollapseButton,
            contentRegions = {
                choice.instanceName,
                choice.level,
            },
            preserveTextures = {
                choice.heroicIcon,
                choice.lockedIndicator,
            },
            elementID = id,
            appearanceWindowID = IDs.DungeonFinder.Scope,
        })
        ApplyDungeonCheckboxComponent(choice, id)
        SkinDungeonCollapseButton(choice)
        if choice.instanceName then
            choice.instanceName:SetAlpha(1)
            choice.instanceName:Show()
        end
        if choice.level then
            choice.level:SetAlpha(1)
            choice.level:Show()
        end
        if choice.enableButton then
            choice.enableButton:SetAlpha(1)
            choice.enableButton:Show()
        end
        return true
    end

    RestoreDungeonTextExactBaseline(choice.instanceName)
    RestoreDungeonTextExactBaseline(choice.level)

    local rowStyle = GetDungeonRowSurfaceStyle(
        "row", id, surfaceAppearanceID)
    local border = NSkin:GetAppearanceBorderColor(
        "row", rowStyle, IDs.DungeonFinder.Scope, surfaceAppearanceID)
    local dungeonNameBaseID =
        IDs.SpecificDungeons .. ".DungeonNameText"
    local levelRangeBaseID =
        IDs.SpecificDungeons .. ".LevelRangeText"
    local dungeonNameAppearanceID =
        GetDungeonRowExactAppearanceID(dungeonNameBaseID, choice)
    local levelRangeAppearanceID =
        GetDungeonRowExactAppearanceID(levelRangeBaseID, choice)
    NSkin:RegisterAppearanceParentID(
        dungeonNameAppearanceID, dungeonNameBaseID, IDs.SpecificDungeons)
    NSkin:RegisterAppearanceParentID(
        levelRangeAppearanceID, levelRangeBaseID, IDs.SpecificDungeons)

    NSkin:SkinRow(choice, {
        style = rowStyle,
        border = border,
        columns = {
            { kind = "CHECKBOX", target = choice.enableButton },
            { kind = "TEXT", target = choice.instanceName,
                appearanceID = dungeonNameAppearanceID },
            { kind = "TEXT", target = choice.level,
                appearanceID = levelRangeAppearanceID },
        },
        preserveTextures = {
            choice.heroicIcon,
            choice.lockedIndicator,
        },
        elementID = id,
        appearanceWindowID = IDs.DungeonFinder.Scope,
    })
    ApplyDungeonCheckboxComponent(choice, id)
    if choice.instanceName then
        choice.instanceName:SetAlpha(1)
        choice.instanceName:Show()
    end
    if choice.level then
        choice.level:SetAlpha(1)
        choice.level:Show()
    end
    if choice.enableButton then
        choice.enableButton:SetAlpha(1)
        choice.enableButton:Show()
    end

    local rowElement = NSkin:GetSkinningElement(IDs.SpecificDungeons)
    if rowElement then
        local nameMember = NSkin:GetCompositeMember(
            rowElement, IDs.SpecificDungeons .. ".DungeonNameText")
        local levelMember = NSkin:GetCompositeMember(
            rowElement, IDs.SpecificDungeons .. ".LevelRangeText")
        if nameMember and choice.instanceName then
            local x, y = NSkin:GetCompositeMemberTargetOffset(
                rowElement, nameMember, dungeonNameAppearanceID)
            ApplyDungeonTextExactOffset(
                choice.instanceName, choice, dungeonNameAppearanceID, x, y)
        end
        if levelMember and choice.level then
            local x, y = NSkin:GetCompositeMemberTargetOffset(
                rowElement, levelMember, levelRangeAppearanceID)
            ApplyDungeonTextExactOffset(
                choice.level, choice, levelRangeAppearanceID, x, y)
        end
    end

    return true
end

local function RefreshDungeonRowFamilyAppearance(wantHeaders)
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return false end
    local matched
    local applied
    for _, owner in ipairs({ queueFrame.Specific, queueFrame.Follower }) do
        local scrollBox = owner and owner.ScrollBox
        NSkin:ForEachScrollBoxFrame(scrollBox, function(choice)
            local visible = choice
                and (not choice.IsVisible or choice:IsVisible())
            local _, isHeader = visible and GetDungeonRowFamilyID(choice)
            if visible and isHeader == wantHeaders then
                matched = true
                applied = PVESkin:StyleDungeonChoice(
                    nil, owner, choice, { preserveLayout = true })
                    or applied
            end
        end)
    end
    return applied == true or matched == true
end

local function RefreshDungeonRowFamilyLayout(wantHeaders)
    local pass = BuildDungeonRowPass()
    local rows = wantHeaders and pass.headers or pass.rows
    local previousPass = activeDungeonRowPass
    activeDungeonRowPass = pass

    local applied
    for _, choice in ipairs(rows) do
        applied = PVESkin:StyleDungeonChoice(
            nil, nil, choice, { preserveLayout = true }) or applied
    end

    ApplyDungeonRowExtentFlow(pass)
    ReapplyDungeonRowFamilyOffsets(true, pass)
    activeDungeonRowPass = previousPass
    return applied == true or #rows > 0
end

function PVESkin:RegisterDungeonRows()
    if dungeonRowsRegistered then return true end
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    if not frame or not queueFrame then return false end

    local function RegisterFamily(id, label, wantHeaders)
        local rowFamily = wantHeaders and "sectionRow" or "row"
        local kind = "BUTTON"
        return NSkin:RegisterSkinningElement(id, {
            module = "GroupFinder",
            appearanceWindowID = IDs.DungeonFinder.Scope,
            label = label,
            kind = kind,
            rowFamily = rowFamily,
            refreshRowFamilyLayout = function()
                return QueueDungeonRowExtentFlow()
            end,
            rowFamilySurfaceDefinition = {
                movable = true,
                applyFamilyOffset = ApplyDungeonMemberFamilyOffset,
                getTargetAppearanceID = function(_, member, target)
                    return GetDungeonRowExactAppearanceID(
                        member.appearanceID or (id .. ".Surface"), target)
                end,
            },
            rowFamilyMemberDefinitions = wantHeaders and {
                TEXT = {
                    movable = true,
                    tightTextBounds = true,
                    applyFamilyOffset = ApplyDungeonMemberFamilyOffset,
                },
                CHECKBOX = {
                    movable = true,
                    applyFamilyOffset = ApplyDungeonMemberFamilyOffset,
                },
                BUTTON = {
                    movable = true,
                    applyFamilyOffset = ApplyDungeonMemberFamilyOffset,
                    label = "Collapse/Expand Button",
                    editorLabel = "Collapse/Expand Button",
                    stateSuffix = "Button",
                    states = {
                        {
                            id = "collapse",
                            label = "Collapse",
                            selectedLabel = "Collapse button",
                            appearanceID = id .. ".BUTTON.Collapse",
                            defaultContent = {
                                type = "GLYPH", glyph = "minus", size = 8,
                            },
                        },
                        {
                            id = "expand",
                            label = "Expand",
                            selectedLabel = "Expand button",
                            appearanceID = id .. ".BUTTON.Expand",
                            defaultContent = {
                                type = "GLYPH", glyph = "plus", size = 8,
                            },
                        },
                    },
                    getStateID = function(_, _, target)
                        local data = target and NSkin:GetSkinData(
                            target, "groupFinderCollapseButton", false)
                        local choice = data and data.choice
                        return choice and choice.isCollapsed == true
                            and "expand" or "collapse"
                    end,
                    previewState = function(_, _, target, stateID)
                        local data = target and NSkin:GetSkinData(
                            target, "groupFinderCollapseButton", false)
                        local choice = data and data.choice
                        if not choice then return false end
                        local wantCollapsed = stateID == "expand"
                        if choice.isCollapsed == wantCollapsed then
                            return true
                        end
                        if target.IsProtected and target:IsProtected() then
                            return false
                        end
                        if target.Click then
                            target:Click()
                            return true
                        end
                        return false
                    end,
                    refreshStateAppearance = function(
                        _, _, stateDefinition)
                        local wantedState = stateDefinition.id
                        for _, choice in ipairs(
                            GetVisibleDungeonRows(true))
                        do
                            local currentState = choice.isCollapsed == true
                                and "expand" or "collapse"
                            if currentState == wantedState
                                and choice.expandOrCollapseButton
                            then
                                SkinDungeonCollapseButton(choice)
                            end
                        end
                        NSkin:NotifySkinningElementBoundsChanged(id)
                        return true
                    end,
                },
            } or {
                CHECKBOX = {
                    movable = true,
                    applyFamilyOffset = ApplyDungeonMemberFamilyOffset,
                },
                BUTTON = {
                    movable = true,
                    applyFamilyOffset = ApplyDungeonMemberFamilyOffset,
                },
            },
            composition = {
                mode = "COMPOSITE",
                type = "REGULAR",
                groupLabel = wantHeaders
                    and "Dungeon header rows" or "Dungeon rows",
                editorLabel = wantHeaders
                    and "Dungeon header row" or "Dungeon row",
                memberEditorLabels = wantHeaders and {
                    CHECKBOX = "Checkbox",
                    BUTTON = "Collapse/Expand Button",
                    TEXT = "Text",
                } or {
                    CHECKBOX = "Checkbox",
                    BUTTON = "Button",
                },
                members = wantHeaders and {} or {
                    {
                        id = id .. ".DungeonNameText",
                        kind = "TEXT",
                        role = "SECONDARY",
                        label = "Dungeon name",
                        editorLabel = "Dungeon name",
                        appearanceWindowID = IDs.DungeonFinder.Scope,
                        appearanceID = id .. ".DungeonNameText",
                        appearanceParentID = id .. ".DungeonNameText",
                        movable = true,
                        allowOverrides = false,
                        highlightMode = "REGIONS",
                        tightTextBounds = true,
                        applyFamilyOffset = ApplyDungeonMemberFamilyOffset,
                        getTargetAppearanceID = function(_, _, target)
                            return GetDungeonTextTargetAppearanceID(
                                id .. ".DungeonNameText", target)
                        end,
                        applyTargetOffset = function(
                            _, _, target, appearanceID, x, y)
                            local owner = GetDungeonTextTargetOwner(target)
                            return owner and ApplyDungeonTextExactOffset(
                                target, owner, appearanceID, x, y) or false
                        end,
                        targets = function()
                            local targets = {}
                            for _, row in ipairs(GetVisibleDungeonRows(false)) do
                                if row.instanceName then
                                    targets[#targets + 1] = row.instanceName
                                end
                            end
                            return targets
                        end,
                    },
                    {
                        id = id .. ".LevelRangeText",
                        kind = "TEXT",
                        role = "SECONDARY",
                        label = "Level range",
                        editorLabel = "Level range",
                        appearanceWindowID = IDs.DungeonFinder.Scope,
                        appearanceID = id .. ".LevelRangeText",
                        appearanceParentID = id .. ".LevelRangeText",
                        movable = true,
                        allowOverrides = false,
                        highlightMode = "REGIONS",
                        tightTextBounds = true,
                        applyFamilyOffset = ApplyDungeonMemberFamilyOffset,
                        getTargetAppearanceID = function(_, _, target)
                            return GetDungeonTextTargetAppearanceID(
                                id .. ".LevelRangeText", target)
                        end,
                        applyTargetOffset = function(
                            _, _, target, appearanceID, x, y)
                            local owner = GetDungeonTextTargetOwner(target)
                            return owner and ApplyDungeonTextExactOffset(
                                target, owner, appearanceID, x, y) or false
                        end,
                        targets = function()
                            local targets = {}
                            for _, row in ipairs(GetVisibleDungeonRows(false)) do
                                if row.level then
                                    targets[#targets + 1] = row.level
                                end
                            end
                            return targets
                        end,
                    },
                },
            },
            window = frame,
            target = queueFrame,
            priority = 82,
            draggable = false,
            highlightMode = "REGIONS",
            defaultColor = function()
                local rows = GetVisibleDungeonRows(wantHeaders)
                for i = 1, #rows do
                    local text = rows[i].instanceName
                    local state = text and NSkin:GetSkinData(
                        text, "sharedTextAppearance", false)
                    if state and state.defaultColor then
                        return state.defaultColor
                    end
                end
            end,
            appearanceStyles = wantHeaders
                and { "sectionRow", "text", "button" }
                or { "row", "text", "button" },
            appearanceTypeIDs = wantHeaders
                and { "TEXT", "CHECKBOX", "BUTTON" }
                or { "TEXT", "CHECKBOX" },
            rowFamilyMemberTargets = wantHeaders and {
                CHECKBOX = function()
                    local targets = {}
                    for _, row in ipairs(GetVisibleDungeonRows(true)) do
                        if row.enableButton then
                            targets[#targets + 1] = row.enableButton
                        end
                    end
                    return targets
                end,
                BUTTON = function()
                    local targets = {}
                    for _, row in ipairs(GetVisibleDungeonRows(true)) do
                        if row.expandOrCollapseButton then
                            targets[#targets + 1] =
                                row.expandOrCollapseButton
                        end
                    end
                    return targets
                end,
            } or nil,
            highlightRegions = function()
                return GetVisibleDungeonRows(wantHeaders)
            end,
            pixelBorderTargets = wantHeaders and function()
                return GetVisibleDungeonRows(true)
            end or nil,
            refreshAppearance = function()
                return RefreshDungeonRowFamilyAppearance(wantHeaders)
            end,
            refreshLayout = function()
                return RefreshDungeonRowFamilyLayout(wantHeaders)
            end,
            isEditable = function()
                return frame:IsVisible() and queueFrame:IsVisible()
                    and #GetVisibleDungeonRows(wantHeaders) > 0
            end,
        })
    end

    RegisterFamily(IDs.DungeonSections, "Dungeon header rows", true)
    RegisterFamily(IDs.SpecificDungeons, "Dungeon rows", false)

    if not dungeonListContainerRegistered then
        local specific = queueFrame.Specific
        local target = specific and (specific.ScrollBox or specific)
            or queueFrame
        dungeonListContainerRegistered = NSkin:RegisterSkinningElement(
            IDs.DungeonFinder.DungeonListContainer, {
                module = "GroupFinder",
                appearanceWindowID = IDs.DungeonFinder.Scope,
                label = "Dungeon list container",
                kind = "CONTAINER",
                window = frame,
                target = target,
                priority = 1,
                draggable = false,
                composition = {
                    mode = "CONTAINER",
                    children = {
                        IDs.DungeonSections,
                        IDs.SpecificDungeons,
                    },
                },
                -- Part 2 validates only the structural relationship. The
                -- container must not compete with its children for input yet.
                isEditable = function() return false end,
            }) == true
    end

    dungeonRowsRegistered = true
    return true
end

function PVESkin:ApplyDungeonSelectionRows()
    local queueFrame = _G.LFDQueueFrame
    if not queueFrame then return false end
    self:RegisterDungeonRows()
    local applied = false
    for _, owner in ipairs({ queueFrame.Specific, queueFrame.Follower }) do
        local scrollBox = owner and owner.ScrollBox
        NSkin:ForEachScrollBoxFrame(scrollBox, function(choice)
            applied = self:StyleDungeonChoice(nil, owner, choice) or applied
        end)
    end
    FlushDungeonRowLayoutRefresh()
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

local function GetFinderNavigationDefinitions()
    local finder = _G.GroupFinderFrame
    if not finder then return {} end
    if _G.PVEFrame and _G.PVEFrame.ScenariosEnabled
        and _G.PVEFrame:ScenariosEnabled()
    then
        return {
            { IDs.Navigation.DungeonFinder,
                "Dungeon Finder", finder.groupButton1 },
            { IDs.Navigation.ScenarioFinder,
                "Scenario Finder", finder.groupButton2 },
            { IDs.Navigation.RaidFinder,
                "Raid Finder", finder.groupButton3 },
            { IDs.Navigation.PremadeGroups,
                "Premade Groups", finder.groupButton4 },
        }
    end
    return {
        { IDs.Navigation.DungeonFinder,
            "Dungeon Finder", finder.groupButton1 },
        { IDs.Navigation.RaidFinder,
            "Raid Finder", finder.groupButton2 },
        { IDs.Navigation.PremadeGroups,
            "Premade Groups", finder.groupButton3 },
    }
end

local function SkinFinderNavigationIcon(button, appearanceID)
    if not button or not button.icon then return false end
    appearanceID = appearanceID or IDs.Navigation.Group

    local iconStyle = WithIconDefaults(
        NSkin:GetAppearanceStyle("icon", IDs.Scope, appearanceID),
        { size = 55 })
    local borderColor = NSkin:GetAppearanceBorderColor(
        "icon", iconStyle, IDs.Scope, appearanceID)

    NSkin:SkinIcon(button.icon, {
        texture = button.icon,
        borderOwner = button,
        style = iconStyle,
        borderColor = borderColor,
        defaultShape = "circle",
        nativeMask = button.CircleMask,
        suppressNativeMask = true,
        nativeDecorationRegions = { button.ring },
    })
    return true
end

local function GetFinderNavigationDefaultTextColor(button)
    local fontObject
    if button and button.IsEnabled and not button:IsEnabled() then
        fontObject = _G.GameFontDisableLarge
    else
        fontObject = _G.GameFontNormalLarge
    end
    if fontObject and fontObject.GetTextColor then
        local red, green, blue, alpha = fontObject:GetTextColor()
        return { red, green, blue, alpha or 1 }
    end
    return { 1, 1, 1, 1 }
end

local function SkinFinderNavigationButton(frame, button, id, label)
    if not button or not button.icon then return false end
    NSkin:RegisterAppearanceParentID(
        id .. ".Surface", IDs.Navigation.Group, IDs.Navigation.Group)
    NSkin:RegisterAppearanceParentID(
        id .. ".Icon", IDs.Navigation.Group, IDs.Navigation.Group)
    NSkin:RegisterAppearanceParentID(
        id .. ".Text", IDs.Navigation.Group, IDs.Navigation.Group)
    ConcealTexture(button.bg)
    ConcealTexture(button.ring)
    ConcealTexture(button.GetHighlightTexture and button:GetHighlightTexture())

    local surfaceAppearanceID = id .. ".Surface"
    local sideStyle = NSkin:GetAppearanceStyle(
        "sideTab", IDs.Scope, surfaceAppearanceID)
    local borderColor = NSkin:GetAppearanceBorderColor(
        "sideTab", sideStyle, IDs.Scope, surfaceAppearanceID)

    local geometry = NSkin:GetSkinData(
        button, "groupFinderNavigationGeometry")
    if not geometry.blizzardWidth or not geometry.blizzardHeight then
        geometry.blizzardWidth = button:GetWidth()
        geometry.blizzardHeight = button:GetHeight()
    end
    local width = tonumber(sideStyle.width)
    local height = tonumber(sideStyle.height)
    width = width and width > 0 and width or geometry.blizzardWidth
    height = height and height > 0 and height or geometry.blizzardHeight
    if width and height
        and (button:GetWidth() ~= width or button:GetHeight() ~= height)
    then
        button:SetSize(width, height)
    end

    local selected = _G.GroupFinderFrame
        and _G.GroupFinderFrame.selectionIndex == button:GetID()
    local backgroundColor = NSkin:GetResolvedAppearanceColor(
        sideStyle,
        selected and sideStyle.selectedBackground
            and "selectedBackground" or "background")
    local background = NSkin:CreateFlatBackground(
        button, "NSkinGroupFinderNavigationBackground",
        backgroundColor, borderColor)
    if background then background:Show() end
    local border = NSkin:GetPixelBorder(
        button, "NSkinGroupFinderNavigationBackgroundBorder")
    if border then
        NSkin:SetPixelBorderColor(border, unpack(borderColor))
        NSkin:SetPixelBorderSize(border, sideStyle.borderSize or 1)
        NSkin:SetPixelBorderPadding(border, sideStyle.borderPadding or 0)
        NSkin:SetPixelBorderShown(border, true)
    end
    NSkin:CreateFlatButtonGlow(button, sideStyle.hoverAlpha)

    SkinFinderNavigationIcon(button, id .. ".Icon")
    if button.name then
        local textAppearanceID = id .. ".Text"
        NSkin:SkinText(button.name,
            NSkin:GetAppearanceStyle(
                "text", IDs.Scope, textAppearanceID), {
                elementID = textAppearanceID,
                defaultColor =
                    GetFinderNavigationDefaultTextColor(button),
            })
    end
    return true
end

function PVESkin:ApplyFinderNavigation()
    local frame = _G.PVEFrame
    local finder = _G.GroupFinderFrame
    if not frame or not finder then return false end

    local definitions = GetFinderNavigationDefinitions()
    local visible = {}
    local applied = false
    for _, definition in ipairs(definitions) do
        local id, label, button =
            definition[1], definition[2], definition[3]
        if button then
            applied = SkinFinderNavigationButton(
                frame, button, id, label) or applied
            visible[#visible + 1] = button
        end
    end

    if not navigationRegistered and #visible > 0 then
        navigationRegistered = NSkin:RegisterSkinningElement(
            IDs.Navigation.Group, {
                module = "GroupFinder",
                appearanceWindowID = IDs.Scope,
                label = "Dungeons & Raids Cards",
                kind = "SIDE_TAB",
                window = frame,
                target = visible[1],
                priority = 60,
                draggable = false,
                appearanceStyles = { "sideTab", "icon", "text" },
                appearanceTypeIDs = { "SIDE_TAB", "ICON", "TEXT" },
                extraEditorOptions = {
                    { id = "shared.iconAppearance", label = "Icons",
                        presentation = "INLINE", category = "CUSTOMIZE" },
                    { id = "shared.textAppearance", label = "Text",
                        category = "CUSTOMIZE" },
                },
                composition = {
                    mode = "COMPOSITE",
                    type = "REGULAR",
                    editorLabel = "Dungeons & Raids Cards",
                    memberEditorLabels = {
                        SIDE_TAB = "Dungeons & Raids Cards",
                        ICON = "Dungeons & Raids Cards Icons",
                        TEXT = "Dungeons & Raids Cards Text",
                    },
                    editorOptionLabels = {
                        ["shared.sideTabAppearance"] = "Surface",
                        ["shared.iconAppearance"] = "Icon",
                        ["shared.textAppearance"] = "Text",
                    },
                    primaryEditorOptionID = "shared.sideTabAppearance",
                    members = {
                        {
                            id = IDs.Navigation.Surface,
                            kind = "SIDE_TAB",
                            role = "PRIMARY",
                            label = "Dungeons & Raids Cards",
                            appearanceWindowID = IDs.Scope,
                            appearanceID = IDs.Navigation.Group,
                            editorSurface = true,
                            surfaceStyle = "sideTab",
                            allowOverrides = true,
                            highlightMode = "REGIONS",
                            separateHighlightRegions = true,
                            editorOptions =
                                NSkin:GetCompositeSurfaceEditorOptions(),
                            targets = function()
                                local targets = {}
                                for _, entry in ipairs(
                                    GetFinderNavigationDefinitions())
                                do
                                    local button = entry[3]
                                    if button and button:IsVisible() then
                                        targets[#targets + 1] = button
                                    end
                                end
                                return targets
                            end,
                            getTargetAppearanceID = function(_, _, target)
                                for _, entry in ipairs(
                                    GetFinderNavigationDefinitions())
                                do
                                    if entry[3] == target then
                                        return entry[1] .. ".Surface"
                                    end
                                end
                            end,
                        },
                        {
                            id = IDs.Navigation.Icon,
                            kind = "ICON",
                            role = "SECONDARY",
                            label = "Dungeons & Raids Cards Icons",
                            appearanceWindowID = IDs.Scope,
                            appearanceID = IDs.Navigation.Group,
                            highlightMode = "REGIONS",
                            separateHighlightRegions = true,
                            targets = function()
                                local targets = {}
                                for _, entry in ipairs(
                                    GetFinderNavigationDefinitions())
                                do
                                    local button = entry[3]
                                    if button and button:IsVisible()
                                        and button.icon
                                    then
                                        targets[#targets + 1] = button.icon
                                    end
                                end
                                return targets
                            end,
                            getTargetAppearanceID = function(_, _, target)
                                for _, entry in ipairs(
                                    GetFinderNavigationDefinitions())
                                do
                                    local button = entry[3]
                                    if button and button.icon == target then
                                        return entry[1] .. ".Icon"
                                    end
                                end
                            end,
                        },
                        {
                            id = IDs.Navigation.Text,
                            kind = "TEXT",
                            role = "SECONDARY",
                            label = "Dungeons & Raids Cards Text",
                            appearanceWindowID = IDs.Scope,
                            appearanceID = IDs.Navigation.Group,
                            highlightMode = "REGIONS",
                            separateHighlightRegions = true,
                            tightTextBounds = true,
                            targets = function()
                                local targets = {}
                                for _, entry in ipairs(
                                    GetFinderNavigationDefinitions())
                                do
                                    local button = entry[3]
                                    if button and button:IsVisible()
                                        and button.name
                                    then
                                        targets[#targets + 1] = button.name
                                    end
                                end
                                return targets
                            end,
                            getTargetAppearanceID = function(_, _, target)
                                for _, entry in ipairs(
                                    GetFinderNavigationDefinitions())
                                do
                                    local button = entry[3]
                                    if button and button.name == target then
                                        return entry[1] .. ".Text"
                                    end
                                end
                            end,
                        },
                    },
                },
                highlightMode = "REGIONS",
                highlightRegions = function()
                    local regions = {}
                    for _, entry in ipairs(GetFinderNavigationDefinitions()) do
                        local button = entry[3]
                        if button and button:IsVisible() then
                            regions[#regions + 1] = button
                        end
                    end
                    return regions
                end,
                pixelBorderTargets = function()
                    local regions = {}
                    for _, entry in ipairs(GetFinderNavigationDefinitions()) do
                        local button = entry[3]
                        if button and button:IsVisible() then
                            regions[#regions + 1] = button
                        end
                    end
                    return regions
                end,
                refreshAppearance = function()
                    return PVESkin:ApplyFinderNavigation()
                end,
                refreshLayout = function()
                    return PVESkin:ApplyFinderNavigation()
                end,
                isEditable = function()
                    return frame:IsVisible() and finder:IsVisible()
                        and #GetFinderNavigationDefinitions() > 0
                end,
            }) == true
    end

    if not navigationSelectionHooked and _G.hooksecurefunc then
        if type(_G.GroupFinderFrame_SelectGroupButton) == "function" then
            hooksecurefunc("GroupFinderFrame_SelectGroupButton", function()
                PVESkin:ApplyFinderNavigation()
            end)
        end
        if type(_G.GroupFinderFrame_EvaluateButtonVisibility) == "function" then
            hooksecurefunc("GroupFinderFrame_EvaluateButtonVisibility",
                function()
                    PVESkin:ApplyFinderNavigation()
                end)
        end
        navigationSelectionHooked = true
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
    if tabsRegistered and not bottomTabsCompositionConfigured then
        local element = NSkin:GetSkinningElement(IDs.BottomTabs)
        if element then
            bottomTabsCompositionConfigured = NSkin:SetElementComposition(
                element, {
                    mode = "COMPOSITE",
                    type = "REGULAR",
                    members = {
                        {
                            id = IDs.BottomTabDungeonsAndRaids,
                            kind = "TAB",
                            role = "PRIMARY",
                            label = "Dungeons & Raids",
                            target = tabs[1],
                            appearanceID = IDs.BottomTabs,
                        },
                        {
                            id = IDs.BottomTabPlayerVsPlayer,
                            kind = "TAB",
                            role = "SECONDARY",
                            label = "Player vs. Player",
                            target = tabs[2],
                            appearanceID = IDs.BottomTabs,
                        },
                        {
                            id = IDs.BottomTabMythicPlus,
                            kind = "TAB",
                            role = "SECONDARY",
                            label = "Mythic+",
                            target = tabs[3],
                            appearanceID = IDs.BottomTabs,
                        },
                    },
                }) ~= nil
        end
    end
    NSkin:ApplyTabGroupLayout(IDs.BottomTabs)
    return true
end

function PVESkin:HookDungeonScrollBoxes()
    local queueFrame = _G.LFDQueueFrame
    local scrollEvents = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if not queueFrame then return false end
    if not dungeonChoiceUpdateHooked and _G.hooksecurefunc
        and type(_G.LFGDungeonListButton_SetDungeon) == "function"
    then
        hooksecurefunc("LFGDungeonListButton_SetDungeon", function(choice)
            PVESkin:StyleDungeonChoice(nil, nil, choice)
            QueueDungeonRowLayoutRefresh()
        end)
        dungeonChoiceUpdateHooked = true
    end

    for _, owner in ipairs({
        queueFrame.Specific,
        queueFrame.Follower,
    }) do
        local scrollBox = owner and owner.ScrollBox
        if scrollBox and not hookedScrollBoxes[scrollBox] then
            if scrollBox.RegisterCallback and scrollEvents
                and scrollEvents.OnInitializedFrame
            then
                scrollBox:RegisterCallback(scrollEvents.OnInitializedFrame,
                    function(_, choice)
                        PVESkin:StyleDungeonChoice(nil, owner, choice)
                        QueueDungeonRowLayoutRefresh()
                    end, self)
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

local function SuppressChallengeDecorations(frame)
    if not frame then return end
    local data = NSkin:GetSkinData(frame, "challengeDecorations")
    data.states = data.states or {}
    local regions = {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture"
            and region.GetAtlas and region:GetAtlas() == "ChallengeMode-KeystoneFrame"
        then
            regions[#regions + 1] = region
            break
        end
    end
    if frame.KeystoneFrame then
        regions[#regions + 1] = frame.KeystoneFrame
    end

    for _, region in ipairs(regions) do
        local state = data.states[region]
        if not state then
            state = {
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = region.IsShown and region:IsShown() or nil,
            }
            data.states[region] = state
        end
        state.active = true
        local function Conceal()
            if not state.active or state.applying then return end
            state.applying = true
            if region.SetAlpha then region:SetAlpha(0) end
            state.applying = nil
        end
        Conceal()
        if not state.hooked and _G.hooksecurefunc then
            for _, method in ipairs({ "SetAlpha", "SetShown", "Show" }) do
                if type(region[method]) == "function" then
                    pcall(_G.hooksecurefunc, region, method, Conceal)
                end
            end
            state.hooked = true
        end
    end
end

local EMPTY_KEYSTONE_BACKGROUND_ALPHA = 0.9

local function UpdateChallengeBackgroundOpacity(frame, background)
    if not frame then return end
    local data = NSkin:GetSkinData(frame, "challengeDecorations")
    if background then data.windowBackground = background end
    background = data.windowBackground
    if not background then return end

    local ids = IDs.Challenges
    local style = NSkin:GetAppearanceStyle("window", ids.Scope, ids.Window)
    local color = style and NSkin:GetResolvedAppearanceColor(style, "background")
    if not color then return end

    local hasSlottedKeystone = _G.C_ChallengeMode
        and type(_G.C_ChallengeMode.HasSlottedKeystone) == "function"
        and _G.C_ChallengeMode.HasSlottedKeystone()
    local alpha = color[4] or 1
    if not hasSlottedKeystone then
        alpha = math.max(alpha, EMPTY_KEYSTONE_BACKGROUND_ALPHA)
    end
    NSkin:SetOwnedTextureColor(background, color[1], color[2], color[3], alpha)
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

function PVESkin:ApplyChallengesKeystoneWindowChrome(frame)
    local ids = IDs.Challenges
    SuppressChallengeDecorations(frame)
    local chrome = NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = ids.Scope,
        elementID = ids.Window,
        headerControlsID = ids.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText
            or frame.Title,
        closeButton = frame.CloseButton,
    })
    UpdateChallengeBackgroundOpacity(frame, chrome and chrome.background)
    NSkin:RegisterSkinningElement(ids.Window, {
        label = "Mythic keystone window",
        kind = "WINDOW",
        module = "GroupFinder",
        appearanceWindowID = ids.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function PVESkin:ApplyChallengesKeystoneTexts(frame)
    local ids = IDs.Challenges
    local instructions = frame.Instructions or frame.Instcructions
    local timeLimit = frame.TimeLimit
        or (instructions and instructions.TimeLimit)
    local applied = false
    for index, definition in ipairs({
        { ids.Instructions, "Keystone instructions", instructions },
        { ids.DungeonName, "Keystone dungeon name", frame.DungeonName },
        { ids.TimeLimit, "Keystone time limit", timeLimit },
        { ids.PowerLevel, "Keystone power level", frame.PowerLevel },
    }) do
        local target = definition[3]
        if target then
            local element = NSkin:RegisterTextElement({
                id = definition[1],
                module = "GroupFinder",
                appearanceWindowID = ids.Scope,
                label = definition[2],
                window = frame,
                target = target,
                priority = 20 + index,
                highlightRegions = { target },
                isEditable = function()
                    return frame:IsVisible() and target:IsVisible()
                end,
            })
            if element then NSkin:RefreshTypedElementAppearance(element) end
            applied = element ~= nil or applied
        end
    end
    return applied
end

function PVESkin:ApplyChallengesKeystoneStartButton(frame)
    local button = frame.StartButton
    if not button then return false end
    local ids = IDs.Challenges
    local element = NSkin:RegisterTypedElement("BUTTON", {
        id = ids.StartButton,
        module = "GroupFinder",
        appearanceWindowID = ids.Scope,
        label = "Start keystone button",
        window = frame,
        target = button,
        priority = 30,
        highlightRegions = { button },
        isEditable = function()
            return frame:IsVisible() and button:IsVisible()
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element ~= nil
end

function PVESkin:ApplyChallengesKeystoneFrame()
    local frame = _G.ChallengesKeystoneFrame
    if not frame then return false end
    local applied = self:ApplyChallengesKeystoneWindowChrome(frame)
    applied = self:ApplyChallengesKeystoneTexts(frame) or applied
    applied = self:ApplyChallengesKeystoneStartButton(frame) or applied
    return applied
end

function PVESkin:InitializeChallengesKeystoneFrame()
    local frame = _G.ChallengesKeystoneFrame
    if not frame then return false end
    local decorationData = NSkin:GetSkinData(frame, "challengeDecorations")
    if not decorationData.backgroundStateHooked and _G.hooksecurefunc then
        for _, method in ipairs({ "Reset", "OnKeystoneSlotted" }) do
            if type(frame[method]) == "function" then
                pcall(_G.hooksecurefunc, frame, method, function()
                    UpdateChallengeBackgroundOpacity(frame)
                end)
            end
        end
        decorationData.backgroundStateHooked = true
    end
    if not challengesShowHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            PVESkin:ApplyChallengesKeystoneFrame()
        end)
        challengesShowHooked = true
    end
    challengesInitialized = true
    return self:ApplyChallengesKeystoneFrame()
end

function PVESkin:QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        PVESkin:ApplyWindowChrome()
        PVESkin:ApplyFinderNavigation()
        PVESkin:ApplyRoleCheckboxes()
        PVESkin:ApplyTypeDropdown()
        PVESkin:ApplyFindGroupButton()
        PVESkin:ApplyDungeonScrollBars()
        PVESkin:ApplyFollowerTexts()
        PVESkin:ApplyRandomDungeonContent()
        PVESkin:ApplyRaidFinderControls()
        PVESkin:ApplyPremadeGroupControls()
        PVESkin:ApplyPVPControls()
        PVESkin:ApplyDungeonSelectionRows()
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
    self:ApplyFinderNavigation()
    self:HookDungeonScrollBoxes()
    self:ApplyRoleCheckboxes()
    self:ApplyTypeDropdown()
    self:ApplyFindGroupButton()
    self:ApplyDungeonScrollBars()
    self:ApplyFollowerTexts()
    self:ApplyRandomDungeonContent()
    self:ApplyRaidFinderControls()
    self:ApplyPremadeGroupControls()
    self:ApplyPVPControls()
    self:ApplyDungeonSelectionRows()
    self:ApplyBottomTabs()
    if frame:IsShown() then self:QueueApply() end
    return true
end

function PVESkin:RefreshAppearance()
    if initialized then
        self:ApplyWindowChrome()
        self:ApplyFinderNavigation()
        self:ApplyRoleCheckboxes()
        self:ApplyTypeDropdown()
        self:ApplyFindGroupButton()
        self:ApplyDungeonScrollBars()
        self:ApplyFollowerTexts()
        self:ApplyRandomDungeonContent()
        self:ApplyRaidFinderControls()
        self:ApplyPremadeGroupControls()
        self:ApplyPVPControls()
        self:ApplyDungeonSelectionRows()
        self:ApplyBottomTabs()
    end
    if compactRaidInitialized then
        self:ApplyCompactRaidFrameManager()
    end
    if challengesInitialized then
        self:ApplyChallengesKeystoneFrame()
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

NSkin:RegisterWindowSkin({
    key = "GroupFinder.ChallengesKeystone",
    module = "GroupFinder",
    addon = "Blizzard_ChallengesUI",
    apply = function()
        return PVESkin:InitializeChallengesKeystoneFrame()
    end,
})
