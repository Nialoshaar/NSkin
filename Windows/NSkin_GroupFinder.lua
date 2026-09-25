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
        RolesEditorGroup = "GroupFinder.DungeonFinder.Roles.EditorGroup",
        DungeonListContainer =
            "GroupFinder.DungeonFinder.DungeonList.Container",
        TypeSelector = "GroupFinder.DungeonFinder.TypeSelector",
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
local dungeonRoleEditorGroupRegistered = false
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

local function GetRolePresentation(roleButton)
    local data = NSkin:GetSkinData(roleButton, "groupFinderRolePresentation")
    if not data.clipFrame then
        local clipFrame = _G.CreateFrame("Frame", nil, roleButton)
        clipFrame:SetPoint("CENTER", roleButton, "CENTER", 0, 0)
        clipFrame:SetSize(roleButton:GetWidth(), roleButton:GetHeight())
        clipFrame:EnableMouse(false)
        if clipFrame.SetClipsChildren then clipFrame:SetClipsChildren(true) end
        data.clipFrame = clipFrame
    end
    if not data.borderFrame then
        local borderFrame = _G.CreateFrame("Frame", nil, roleButton)
        borderFrame:SetPoint("CENTER", roleButton, "CENTER", 0, 0)
        borderFrame:SetSize(roleButton:GetWidth(), roleButton:GetHeight())
        borderFrame:EnableMouse(false)
        data.borderFrame = borderFrame
    end
    if not data.texture then
        local texture = data.clipFrame:CreateTexture(nil, "ARTWORK", nil, 1)
        texture:SetPoint("CENTER", data.clipFrame, "CENTER", 0, 0)
        texture:SetSize(roleButton:GetWidth(), roleButton:GetHeight())
        data.texture = texture
    end
    return data.texture, data
end

local function RegisterRoleComposite(
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

        -- Role icons use an NSkin-owned presentation texture. Crop its visible
        -- canvas instead of masking that texture directly: intersecting the
        -- generic crop mask with the circular shape mask makes the role artwork
        -- appear to scale down before the vertical crop is applied.
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
        clipFrame:SetFrameLevel(roleButton:GetFrameLevel() + 1)
        borderFrame:ClearAllPoints()
        borderFrame:SetPoint("CENTER", roleButton, "CENTER", 0, 0)
        borderFrame:SetSize(width, height)
        borderFrame:SetFrameLevel(clipFrame:GetFrameLevel() + 1)
        -- The role icon outline intentionally sits above the icon artwork, but
        -- the checkbox is a separate secondary control and must remain above
        -- that outline.
        if checkButton.SetFrameLevel then
            checkButton:SetFrameLevel(borderFrame:GetFrameLevel() + 1)
        end
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
            nativeDecorationRegions = {
                nativeIcon,
                roleButton.background,
                roleButton.shortageBorder,
                roleButton.IconPulse,
                roleButton.EdgePulse,
            },
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

function PVESkin:ApplyRoleCheckboxes()
    local frame = _G.PVEFrame
    local queueFrame = _G.LFDQueueFrame
    if not frame or not queueFrame then return false end
    SuppressDungeonFinderArtwork()
    local applied = false
    local editorMembers = {}
    for _, definition in ipairs(GetRoleDefinitions()) do
        applied = RegisterRoleComposite(
            definition[1], definition[2], IDs.DungeonFinder.Scope,
            IDs.DungeonFinder.RolesGroup, "Dungeon Finder roles",
            frame, queueFrame, definition[3]) or applied
        if NSkin:GetSkinningElement(definition[1]) then
            editorMembers[#editorMembers + 1] = definition[1]
        end
    end
    if #editorMembers > 0 then
        dungeonRoleEditorGroupRegistered =
            NSkin:RegisterEditorGroup({
                id = IDs.DungeonFinder.RolesEditorGroup,
                label = "Dungeon Finder roles",
                window = frame,
                appearanceWindowID = IDs.DungeonFinder.Scope,
                members = editorMembers,
            }) ~= nil
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
        appearanceWindowID = IDs.DungeonFinder.Scope,
        label = "Dungeon Finder type dropdown",
        window = frame,
        target = dropdown,
        menus = { "MENU_LFD_FRAME" },
        priority = 80,
        anchorGroupID = IDs.DungeonFinder.TypeSelector,
        anchorGroupLabel = "Dungeon Finder type selector",
        anchorGroupAppearanceSource = IDs.TypeDropdown,
        highlightRegions = { dropdown },
        isEditable = function()
            return frame:IsVisible() and queueFrame:IsVisible()
                and dropdown:IsVisible()
        end,
    })
    local typeLabel = _G.LFDQueueFrameTypeDropdownName or dropdown.Name
    if typeLabel then
        NSkin:RegisterTextElement({
            id = IDs.DungeonFinder.TypeLabel,
            module = "GroupFinder",
            appearanceWindowID = IDs.DungeonFinder.Scope,
            label = "Dungeon Finder type label",
            window = frame,
            target = typeLabel,
            priority = 79,
            anchorGroupID = IDs.DungeonFinder.TypeSelector,
            anchorGroupLabel = "Dungeon Finder type selector",
            anchorGroupAppearanceSource = IDs.TypeDropdown,
            highlightRegions = { typeLabel },
            isEditable = function()
                return frame:IsVisible() and queueFrame:IsVisible()
                    and typeLabel:IsVisible()
            end,
        })
    end
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
        applied = RegisterRoleComposite(
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

local function GetVisibleDungeonRows(wantHeaders)
    local queueFrame = _G.LFDQueueFrame
    local result = {}
    if not queueFrame then return result end
    for _, owner in ipairs({ queueFrame.Specific, queueFrame.Follower }) do
        local scrollBox = owner and owner.ScrollBox
        NSkin:ForEachScrollBoxFrame(scrollBox, function(choice)
            local _, isHeader = GetDungeonRowFamilyID(choice)
            if isHeader == wantHeaders and choice:IsVisible() then
                result[#result + 1] = choice
            end
        end)
    end
    return result
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

local function GetDungeonTextTargetAppearanceID(baseID, target)
    for _, choice in ipairs(GetVisibleDungeonRows(false)) do
        if choice.instanceName == target or choice.level == target then
            return GetDungeonRowExactAppearanceID(baseID, choice)
        end
    end
    return baseID
end

local function ApplyDungeonTextExactOffset(
    region, appearanceID, x, y)
    if not region or not region.GetNumPoints then return false end
    local data = NSkin:GetSkinData(region, "dungeonExactTextOffset")

    -- Restore the un-overridden points first so repeated styling and pool reuse
    -- never accumulate offsets from a previous logical dungeon.
    if data.active and data.points then
        region:ClearAllPoints()
        for _, point in ipairs(data.points) do
            region:SetPoint(unpack(point))
        end
        data.active = nil
    end

    local points = {}
    for index = 1, region:GetNumPoints() do
        points[index] = { region:GetPoint(index) }
    end
    data.points = points
    data.appearanceID = appearanceID

    x, y = tonumber(x) or 0, tonumber(y) or 0
    if x == 0 and y == 0 then return true end
    region:ClearAllPoints()
    for _, point in ipairs(points) do
        region:SetPoint(
            point[1], point[2], point[3],
            (tonumber(point[4]) or 0) + x,
            (tonumber(point[5]) or 0) + y)
    end
    data.active = true
    return true
end

local dungeonDefaultRowExtent
local dungeonExtentState = setmetatable({}, { __mode = "k" })

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

    local data = NSkin:GetSkinData(target, "dungeonRowFamilyOffset")
    if data.active and data.points then
        target:ClearAllPoints()
        for _, point in ipairs(data.points) do
            target:SetPoint(unpack(point))
        end
        data.active = nil
    end

    local points = {}
    for index = 1, target:GetNumPoints() do
        points[index] = { target:GetPoint(index) }
    end
    if #points == 0 then return false end
    data.points = points

    x, y = tonumber(x) or 0, tonumber(y) or 0
    if x == 0 and y == 0 then return true end
    target:ClearAllPoints()
    for _, point in ipairs(points) do
        target:SetPoint(
            point[1], point[2], point[3],
            (tonumber(point[4]) or 0) + x,
            (tonumber(point[5]) or 0) + y)
    end
    data.active = true
    return true
end

local function ApplyDungeonMemberFamilyOffset(element, member, x, y)
    local applied
    for _, target in ipairs(
        NSkin:GetCompositionMemberTargets(element, member, false) or {})
    do
        applied = ApplyDungeonFamilyOffsetTarget(
            target, x, y) or applied
    end
    NSkin:NotifySkinningElementBoundsChanged(element.id)
    return applied == true
end

local function ReapplyDungeonMemberFamilyOffsets(elementID)
    local element = NSkin:GetSkinningElement(elementID)
    local composition = element and element.composition
    if not composition then return end
    for _, member in ipairs(composition.members or {}) do
        if member.movable ~= false
            and type(member.applyFamilyOffset) == "function"
        then
            local x, y = NSkin:GetCompositeMemberFamilyOffset(
                element, member)
            member.applyFamilyOffset(
                element, member, x or 0, y or 0)
        end
    end
end

local function GetConfiguredDungeonRowExtent(isHeader)
    local fallback = tonumber(dungeonDefaultRowExtent) or 20
    local styleName = isHeader and "sectionRow" or "row"
    local appearanceID = isHeader
        and IDs.DungeonSections or IDs.SpecificDungeons
    local style = NSkin:GetAppearanceStyle(
        styleName, IDs.DungeonFinder.Scope, appearanceID)
    local height = tonumber(style and style.height)
    return height and height > 0 and height or fallback
end

local function RefreshDungeonScrollBoxExtent(scrollBox)
    if not scrollBox or not scrollBox.GetView then return false end
    local view = scrollBox:GetView()
    if not view or type(view.SetElementExtentCalculator) ~= "function" then
        return false
    end

    local rowExtent = GetConfiguredDungeonRowExtent(false)
    local sectionExtent = GetConfiguredDungeonRowExtent(true)
    local signature = tostring(rowExtent) .. ":" .. tostring(sectionExtent)
    if dungeonExtentState[scrollBox] == signature then return false end
    dungeonExtentState[scrollBox] = signature

    view:SetElementExtentCalculator(function(_, elementData)
        local dungeonID = elementData and elementData.dungeonID
        local isHeader = dungeonID ~= nil
            and type(_G.LFGIsIDHeader) == "function"
            and _G.LFGIsIDHeader(dungeonID)
        return isHeader and sectionExtent or rowExtent
    end)

    if scrollBox.FullUpdate then
        local immediately = _G.ScrollBoxConstants
            and _G.ScrollBoxConstants.UpdateImmediately
        if immediately ~= nil then
            scrollBox:FullUpdate(immediately)
        else
            scrollBox:FullUpdate()
        end
    end
    return true
end

function PVESkin:StyleDungeonChoice(_, _, choice)
    if not choice or not choice.id then return false end
    if dungeonDefaultRowExtent == nil and choice.GetHeight then
        local height = tonumber(choice:GetHeight())
        if height and height > 0 then dungeonDefaultRowExtent = height end
    end
    RestoreDungeonChoiceFamilyOffsets(choice)
    local id, isHeader = GetDungeonRowFamilyID(choice)

    ApplyDungeonChoiceIndent(choice, isHeader)

    if isHeader then
        local sectionStyle = NSkin:GetAppearanceStyle(
            "sectionRow", IDs.DungeonFinder.Scope, id)
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
        return true
    end

    local rowStyle = NSkin:GetAppearanceStyle(
        "row", IDs.DungeonFinder.Scope, id)
    local border = NSkin:GetAppearanceBorderColor(
        "row", rowStyle, IDs.DungeonFinder.Scope, id)
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
        showBackground = false,
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
                choice.instanceName, dungeonNameAppearanceID, x, y)
        end
        if levelMember and choice.level then
            local x, y = NSkin:GetCompositeMemberTargetOffset(
                rowElement, levelMember, levelRangeAppearanceID)
            ApplyDungeonTextExactOffset(
                choice.level, levelRangeAppearanceID, x, y)
        end
    end

    local rowBorder = NSkin:GetPixelBorder(
        choice, "NSkinRowBackgroundBorder")
    if rowBorder then NSkin:SetPixelBorderShown(rowBorder, false) end
    return true
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
            rowFamilySurfaceDefinition = {
                movable = true,
                applyFamilyOffset = ApplyDungeonMemberFamilyOffset,
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
                    and "Dungeon section rows" or "Dungeon rows",
                editorLabel = wantHeaders
                    and "Dungeon section row" or "Dungeon row",
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
                            return ApplyDungeonTextExactOffset(
                                target, appearanceID, x, y)
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
                            return ApplyDungeonTextExactOffset(
                                target, appearanceID, x, y)
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
                or { "TEXT", "BUTTON", "CHECKBOX" },
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
                return PVESkin:ApplyDungeonSelectionRows()
            end,
            refreshLayout = function()
                return PVESkin:ApplyDungeonSelectionRows()
            end,
            isEditable = function()
                return frame:IsVisible() and queueFrame:IsVisible()
                    and #GetVisibleDungeonRows(wantHeaders) > 0
            end,
        })
    end

    RegisterFamily(IDs.DungeonSections, "Dungeon section rows", true)
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
        RefreshDungeonScrollBoxExtent(scrollBox)
    end
    ReapplyDungeonMemberFamilyOffsets(IDs.DungeonSections)
    ReapplyDungeonMemberFamilyOffsets(IDs.SpecificDungeons)
    NSkin:NotifySkinningElementBoundsChanged(IDs.DungeonSections)
    NSkin:NotifySkinningElementBoundsChanged(IDs.SpecificDungeons)
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

local function SkinFinderNavigationButton(frame, button, id, label)
    if not button or not button.icon then return false end
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
                    members = (function()
                        local members = {}
                        for _, entry in ipairs(definitions) do
                            local id, label, button =
                                entry[1], entry[2], entry[3]
                            if button then
                                members[#members + 1] = {
                                    id = id .. ".Surface",
                                    kind = "SIDE_TAB",
                                    role = "PRIMARY",
                                    label = label .. " card",
                                    target = button,
                                    appearanceWindowID = IDs.Scope,
                                    appearanceID = id .. ".Surface",
                                    appearanceParentID = IDs.Navigation.Group,
                                    editorSurface = true,
                                }
                            end
                            if button and button.icon then
                                members[#members + 1] = {
                                    id = id .. ".Icon",
                                    kind = "ICON",
                                    role = "SECONDARY",
                                    label = label .. " icon",
                                    target = button.icon,
                                    appearanceWindowID = IDs.Scope,
                                    appearanceID = id .. ".Icon",
                                    appearanceParentID = IDs.Navigation.Group,
                                }
                            end
                            if button and button.name then
                                members[#members + 1] = {
                                    id = id .. ".Text",
                                    kind = "TEXT",
                                    role = "SECONDARY",
                                    label = label .. " text",
                                    target = button.name,
                                    appearanceWindowID = IDs.Scope,
                                    appearanceID = id .. ".Text",
                                    appearanceParentID = IDs.Navigation.Group,
                                }
                            end
                        end
                        return members
                    end)(),
                },
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

    if not navigationSelectionHooked and _G.hooksecurefunc
        and type(_G.GroupFinderFrame_SelectGroupButton) == "function"
    then
        hooksecurefunc("GroupFinderFrame_SelectGroupButton", function()
            PVESkin:ApplyFinderNavigation()
        end)
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
