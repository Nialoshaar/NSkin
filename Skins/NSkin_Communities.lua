local _, NSkin = ...

local CommunitiesSkin = NSkin:NewModule("Communities")

local IDs = {
    Scope = "Communities",
    Window = "Communities.Window",
    HeaderControls = "Communities.HeaderControls",
    ResizeButton = "Communities.ResizeButton",
    ListScrollBar = "Communities.List.ScrollBar",
    StreamDropdown = "Communities.StreamDropdown",
    RecruitmentButton = "Communities.RecruitmentButton",
    InviteButton = "Communities.InviteButton",
    CommunityFinder = {
        FilterDropdown = "Communities.Finder.FilterDropdown",
        SortDropdown = "Communities.Finder.SortDropdown",
        TankCheckbox = "Communities.Finder.TankCheckbox",
        HealerCheckbox = "Communities.Finder.HealerCheckbox",
        DpsCheckbox = "Communities.Finder.DpsCheckbox",
        SearchBox = "Communities.Finder.SearchBox",
        SearchButton = "Communities.Finder.SearchButton",
    },
    GuildFinder = {
        FilterDropdown = "Communities.GuildFinder.FilterDropdown",
        SizeDropdown = "Communities.GuildFinder.SizeDropdown",
        TankCheckbox = "Communities.GuildFinder.TankCheckbox",
        HealerCheckbox = "Communities.GuildFinder.HealerCheckbox",
        DpsCheckbox = "Communities.GuildFinder.DpsCheckbox",
        SearchBox = "Communities.GuildFinder.SearchBox",
        SearchButton = "Communities.GuildFinder.SearchButton",
    },
}

local initialized = false
local applyPending = false
local hookedOwners = setmetatable({}, { __mode = "k" })
local concealedPortraitOverlays = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Guild & Communities",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        CommunitiesSkin:Apply()
    end)
end

local function HookOwner(owner)
    if not owner or hookedOwners[owner] or not owner.HookScript then return end
    owner:HookScript("OnShow", QueueApply)
    hookedOwners[owner] = true
end

local function GetResizeTargets(frame)
    local resizeFrame = frame and frame.MaximizeMinimizeFrame
    local targets = {}
    local maximize = resizeFrame and (
        resizeFrame.MaximizeButton or resizeFrame.maximizeButton)
    local minimize = resizeFrame and (
        resizeFrame.MinimizeButton or resizeFrame.minimizeButton)
    if maximize then
        targets[#targets + 1] = { target = maximize, glyph = "maximize" }
    end
    if minimize then
        targets[#targets + 1] = { target = minimize, glyph = "minimize" }
    end
    return targets
end

local function ConcealPortraitOverlay(frame)
    local overlay = frame and frame.PortraitOverlay
    if not overlay then return end

    overlay:SetAlpha(0)
    overlay:Hide()
    if not concealedPortraitOverlays[overlay] and overlay.HookScript then
        overlay:HookScript("OnShow", function(self)
            self:SetAlpha(0)
            self:Hide()
        end)
        concealedPortraitOverlays[overlay] = true
    end
end

function CommunitiesSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    ConcealPortraitOverlay(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleText
            or (frame.TitleContainer and frame.TitleContainer.TitleText),
        headerControls = {
            {
                id = IDs.ResizeButton,
                targets = GetResizeTargets(frame),
            },
        },
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Guild & Communities window",
        kind = "WINDOW",
        module = "Communities",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

local function RegisterFinderCheckbox(id, label, frame, finder, options,
    roleFrame, priority)
    local checkbox = roleFrame and roleFrame.Checkbox
    if not checkbox then return false end

    NSkin:RegisterCheckbox({
        id = id,
        module = "Communities",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = checkbox,
        priority = priority,
        highlightRegions = { checkbox },
        isEditable = function()
            return IsVisible(frame) and IsVisible(finder)
                and IsVisible(options) and IsVisible(checkbox)
        end,
    })
    return true
end

local function ApplyFinderControls(frame, finder, ids, label,
    secondaryDropdownKey, secondaryMenuTag)
    local options = finder and finder.OptionsList
    if not finder or not options then return false end

    local filter = options.ClubFilterDropdown
    if filter then
        NSkin:RegisterDropdown({
            id = ids.FilterDropdown,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = label .. " filter dropdown",
            window = frame,
            target = filter,
            menus = { "MENU_CLUB_FILTER" },
            priority = 60,
            highlightRegions = { filter },
            isEditable = function()
                return IsVisible(frame) and IsVisible(finder)
                    and IsVisible(options) and IsVisible(filter)
            end,
        })
    end

    local secondary = options[secondaryDropdownKey]
    if secondary then
        NSkin:RegisterDropdown({
            id = ids.SortDropdown or ids.SizeDropdown,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = label .. (ids.SortDropdown
                and " sort dropdown" or " size dropdown"),
            window = frame,
            target = secondary,
            menus = { secondaryMenuTag },
            priority = 61,
            highlightRegions = { secondary },
            isEditable = function()
                return IsVisible(frame) and IsVisible(finder)
                    and IsVisible(options) and IsVisible(secondary)
            end,
        })
    end

    RegisterFinderCheckbox(ids.TankCheckbox,
        label .. " tank role checkbox", frame, finder, options,
        options.TankRoleFrame, 62)
    RegisterFinderCheckbox(ids.HealerCheckbox,
        label .. " healer role checkbox", frame, finder, options,
        options.HealerRoleFrame, 63)
    RegisterFinderCheckbox(ids.DpsCheckbox,
        label .. " damage role checkbox", frame, finder, options,
        options.DpsRoleFrame, 64)

    local searchBox = options.SearchBox
    if searchBox then
        local filterHeight = filter and filter.GetHeight and filter:GetHeight()
        if tonumber(filterHeight) and filterHeight > 0 then
            -- Blizzard makes this EditBox taller than its visible input art.
            -- Match the adjacent dropdown before the shared search skin captures
            -- its baseline; an explicit NSkin height override still wins.
            searchBox:SetHeight(filterHeight)
        end
        NSkin:RegisterSearchBox({
            id = ids.SearchBox,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = label .. " search box",
            window = frame,
            target = searchBox,
            priority = 65,
            highlightRegions = { searchBox },
            isEditable = function()
                return IsVisible(frame) and IsVisible(finder)
                    and IsVisible(options) and IsVisible(searchBox)
            end,
        })
    end

    local searchButton = options.Search
    if searchButton then
        if searchBox then
            searchButton:ClearAllPoints()
            searchButton:SetPoint("TOP", searchBox, "BOTTOM", -3, -1)
        end
        NSkin:RegisterActionButton({
            id = ids.SearchButton,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = label .. " search button",
            window = frame,
            target = searchButton,
            priority = 66,
            highlightRegions = { searchButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(finder)
                    and IsVisible(options) and IsVisible(searchButton)
            end,
        })
    end

    HookOwner(finder)
    HookOwner(options)
    return true
end

function CommunitiesSkin:ApplyFinderControls(frame)
    local guildFinder = frame and frame.GuildFinderFrame
        or _G.ClubFinderGuildFinderFrame
    local communityFinder = frame and frame.CommunityFinderFrame
        or _G.ClubFinderCommunityAndGuildFinderFrame
    local applied = ApplyFinderControls(frame, guildFinder, IDs.GuildFinder,
        "Guild finder", "ClubSizeDropdown", "MENU_CLUB_FINDER_OPTIONS")
    return ApplyFinderControls(frame, communityFinder, IDs.CommunityFinder,
        "Community finder", "SortByDropdown", "MENU_CLUB_SORT_BY") or applied
end

function CommunitiesSkin:ApplyListScrollBar(frame)
    local list = frame and frame.CommunitiesList
    local scrollBar = list and list.ScrollBar
    if not scrollBar then return false end

    NSkin:RegisterScrollBar({
        id = IDs.ListScrollBar,
        module = "Communities",
        appearanceWindowID = IDs.Scope,
        label = "Communities list scroll bar",
        window = frame,
        target = scrollBar,
        priority = 70,
        highlightRegions = { scrollBar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(list)
                and IsVisible(scrollBar)
        end,
    })
    HookOwner(list)
    return true
end

function CommunitiesSkin:ApplyGuildControls(frame)
    if not frame then return false end

    local streamDropdown = frame.StreamDropdown
    if streamDropdown then
        NSkin:RegisterDropdown({
            id = IDs.StreamDropdown,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild stream dropdown",
            window = frame,
            target = streamDropdown,
            menus = { "MENU_COMMUNITIES_STREAM" },
            priority = 71,
            highlightRegions = { streamDropdown },
            isEditable = function()
                return IsVisible(frame) and IsVisible(streamDropdown)
            end,
        })
    end

    local controls = frame.CommunitiesControlFrame
    local recruitment = controls and controls.GuildRecruitmentButton
    if recruitment then
        NSkin:RegisterActionButton({
            id = IDs.RecruitmentButton,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild recruitment button",
            window = frame,
            target = recruitment,
            priority = 72,
            highlightRegions = { recruitment },
            isEditable = function()
                return IsVisible(frame) and IsVisible(recruitment)
            end,
        })
    end

    local invite = frame.InviteButton
    if invite then
        NSkin:RegisterActionButton({
            id = IDs.InviteButton,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Invite member button",
            window = frame,
            target = invite,
            priority = 73,
            highlightRegions = { invite },
            isEditable = function()
                return IsVisible(frame) and IsVisible(invite)
            end,
        })
    end

    HookOwner(controls)
    return streamDropdown ~= nil or recruitment ~= nil or invite ~= nil
end

function CommunitiesSkin:Apply()
    local frame = _G.CommunitiesFrame
    if not frame then return false end

    self:ApplyWindowChrome(frame)
    self:ApplyFinderControls(frame)
    self:ApplyListScrollBar(frame)
    self:ApplyGuildControls(frame)
    return true
end

function CommunitiesSkin:Initialize()
    local frame = _G.CommunitiesFrame
    if not frame then return false end

    HookOwner(frame)
    initialized = true
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function CommunitiesSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "Communities",
    addon = "Blizzard_Communities",
    apply = function() return CommunitiesSkin:Initialize() end,
})
