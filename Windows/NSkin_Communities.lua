local _, NSkin = ...

local CommunitiesSkin = NSkin:NewModule("Communities")

local IDs = {
    Scope = "Communities",
    Window = "Communities.Window",
    HeaderControls = "Communities.HeaderControls",
    ResizeButton = "Communities.ResizeButton",
    ListScrollBar = "Communities.List.ScrollBar",
    ChatScrollBar = "Communities.Chat.ScrollBar",
    MemberScrollBar = "Communities.MemberList.ScrollBar",
    RightTabs = "Communities.RightTabs",
    OnlineCount = "Communities.MemberList.OnlineCount",
    ShowOffline = "Communities.MemberList.ShowOffline",
    GuildMemberDropdown = "Communities.MemberList.GuildDropdown",
    CommunityMemberDropdown = "Communities.MemberList.CommunityDropdown",
    ColumnHeaders = "Communities.MemberList.ColumnHeaders",
    MemberRows = "Communities.MemberList.Rows",
    DetailWindow = "Communities.GuildMemberDetail.Window",
    DetailHeaderControls = "Communities.GuildMemberDetail.HeaderControls",
    DetailName = "Communities.GuildMemberDetail.Name",
    DetailLabels = "Communities.GuildMemberDetail.Labels",
    DetailValues = "Communities.GuildMemberDetail.Values",
    DetailRankDropdown = "Communities.GuildMemberDetail.RankDropdown",
    DetailRemoveButton = "Communities.GuildMemberDetail.RemoveButton",
    DetailInviteButton = "Communities.GuildMemberDetail.InviteButton",

    BenefitsPerksTitle = "Communities.GuildBenefits.Perks.Title",
    BenefitsPerksScrollBar = "Communities.GuildBenefits.Perks.ScrollBar",
    BenefitsPerkRows = "Communities.GuildBenefits.Perks.Rows",
    BenefitsPerkIcons = "Communities.GuildBenefits.Perks.Icons",
    BenefitsPerkNames = "Communities.GuildBenefits.Perks.Names",

    BenefitsRewardsTitle = "Communities.GuildBenefits.Rewards.Title",
    BenefitsRewardsScrollBar = "Communities.GuildBenefits.Rewards.ScrollBar",
    BenefitsRewardRows = "Communities.GuildBenefits.Rewards.Rows",
    BenefitsRewardIcons = "Communities.GuildBenefits.Rewards.Icons",
    BenefitsRewardNames = "Communities.GuildBenefits.Rewards.Names",
    BenefitsRewardSubText = "Communities.GuildBenefits.Rewards.SubText",

    BenefitsTutorial = "Communities.GuildBenefits.Rewards.Tutorial",
    BenefitsAchievementPoints = "Communities.GuildBenefits.AchievementPoints",
    BenefitsFactionLabel = "Communities.GuildBenefits.FactionLabel",
    BenefitsFactionProgress = "Communities.GuildBenefits.FactionProgress",

    DetailsInfoTitle = "Communities.GuildDetails.Info.Title",
    DetailsInfoHeaders = "Communities.GuildDetails.Info.SectionHeaders",
    DetailsChallenges = "Communities.GuildDetails.Info.Challenges",
    DetailsInfoText = "Communities.GuildDetails.Info.DetailsText",
    DetailsMotdScrollBar = "Communities.GuildDetails.Info.MOTDScrollBar",
    DetailsInfoScrollBar = "Communities.GuildDetails.Info.DetailsScrollBar",
    DetailsEditMotd = "Communities.GuildDetails.Info.EditMOTD",
    DetailsEditInfo = "Communities.GuildDetails.Info.EditDetails",

    DetailsNewsTitle = "Communities.GuildDetails.News.Title",
    DetailsNewsHeader = "Communities.GuildDetails.News.SectionHeader",
    DetailsNewsRows = "Communities.GuildDetails.News.Rows",
    DetailsNewsNoNews = "Communities.GuildDetails.News.NoNews",
    DetailsNewsScrollBar = "Communities.GuildDetails.News.ScrollBar",
    DetailsNewsFilters = "Communities.GuildDetails.News.SetFilters",
    DetailsViewLog = "Communities.GuildDetails.ViewLog",

    GuildLogWindow = "Communities.GuildLog.Window",
    GuildLogHeaderControls = "Communities.GuildLog.HeaderControls",
    GuildLogScrollBar = "Communities.GuildLog.ScrollBar",
    GuildLogClose = "Communities.GuildLog.Close",

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
local suppressedRegions = setmetatable({}, { __mode = "k" })
local listScrollBoxHooked = false
local rightTabsRegistered = false
local memberColumnHeadersRegistered = false
local memberListLifecycleHooked = false
local memberRowsRegistered = false
local memberRowsScrollBoxHooked = false
local guildMemberDetailHooked = false
local guildMemberDetailTextGroups = {}
local guildBenefitsGroups = {}
local guildBenefitsPerksScrollHooked = false
local guildBenefitsRewardsScrollHooked = false
local guildDetailsGroups = {}
local guildDetailsNewsScrollHooked = false
local guildLogHooked = false

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Guild & Communities",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function CompactRegions(...)
    local regions = {}
    for index = 1, select("#", ...) do
        local region = select(index, ...)
        if region then regions[#regions + 1] = region end
    end
    return regions
end

local function SuppressRegion(region)
    if not region then return end
    local state = suppressedRegions[region]
    if not state then
        state = { applying = false }
        suppressedRegions[region] = state
    end

    local function Conceal()
        if state.applying then return end
        state.applying = true
        if region.SetAlpha then region:SetAlpha(0) end
        state.applying = false
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

local function GetDirectTextureRegions(frame, exclusions)
    local regions = {}
    if not frame or type(frame.GetRegions) ~= "function" then return regions end
    exclusions = exclusions or {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType
            and region:IsObjectType("Texture")
            and not exclusions[region]
        then
            regions[#regions + 1] = region
        end
    end
    return regions
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


function CommunitiesSkin:ApplyBorderCleanup(frame)
    if not frame then return false end

    local list = frame.CommunitiesList
    if list then
        SuppressRegion(list.Bg)
        SuppressRegion(list.TopFiligree)
        SuppressRegion(list.BottomFiligree)

        local filigree = list.FilligreeOverlay
        if filigree then
            for _, region in ipairs(GetDirectTextureRegions(filigree)) do
                SuppressRegion(region)
            end
        end
        if list.InsetFrame then
            NSkin:ConcealWindowArtwork(list.InsetFrame)
        end
    end

    local chat = frame.Chat
    if chat and chat.InsetFrame then
        NSkin:ConcealWindowArtwork(chat.InsetFrame)
    end

    local memberList = frame.MemberList
    if memberList then
        if memberList.InsetFrame then
            NSkin:ConcealWindowArtwork(memberList.InsetFrame)
        end
        if memberList.ColumnDisplay then
            SuppressRegion(memberList.ColumnDisplay.Background)
            SuppressRegion(memberList.ColumnDisplay.TopTileStreaks)
            for _, key in ipairs({
                "InsetBorderTopLeft",
                "InsetBorderTopRight",
                "InsetBorderBottomLeft",
                "InsetBorderTop",
                "InsetBorderLeft",
            }) do
                SuppressRegion(memberList.ColumnDisplay[key])
            end
        end
    end

    if frame.Inset then
        NSkin:ConcealWindowArtwork(frame.Inset)
    end

    return true
end

local function StyleCommunitiesListEntry(target)
    if not target then return false end
    -- Keep Blizzard selection/highlight states and semantic icon artwork, but
    -- remove the permanent blue card background.
    SuppressRegion(target.Background)
    return true
end

function CommunitiesSkin:ApplyListEntries(frame)
    local list = frame and frame.CommunitiesList
    local scrollBox = list and list.ScrollBox
    if not scrollBox then return false end

    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        applied = StyleCommunitiesListEntry(target) or applied
    end)

    if not listScrollBoxHooked then
        local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
        if scrollBox.RegisterCallback and events
            and events.OnInitializedFrame
        then
            scrollBox:RegisterCallback(events.OnInitializedFrame,
                function(_, target)
                    StyleCommunitiesListEntry(target)
                end, self)
            listScrollBoxHooked = true
        elseif _G.hooksecurefunc and type(scrollBox.Update) == "function" then
            pcall(_G.hooksecurefunc, scrollBox, "Update", function()
                CommunitiesSkin:ApplyListEntries(frame)
            end)
            listScrollBoxHooked = true
        end
    end

    return applied
end

local function GetRightTabs(frame)
    local tabs = {}
    for _, tab in ipairs({
        frame and frame.ChatTab,
        frame and frame.RosterTab,
        frame and frame.GuildBenefitsTab,
        frame and frame.GuildInfoTab,
    }) do
        if tab then tabs[#tabs + 1] = tab end
    end
    return tabs
end

local function GetTabIcon(tab)
    return tab and tab.Icon
end

local function GetRightTabDescriptors(frame)
    local descriptors = {}
    for _, tab in ipairs(GetRightTabs(frame)) do
        local exclusions = {
            [tab.Icon] = true,
            [tab.IconOverlay] = true,
        }
        local native = GetDirectTextureRegions(tab, exclusions)
        local normal = tab.GetNormalTexture and tab:GetNormalTexture()
        local highlight = tab.GetHighlightTexture and tab:GetHighlightTexture()
        local checked = tab.GetCheckedTexture and tab:GetCheckedTexture()
        for _, region in ipairs({ normal, highlight, checked }) do
            if region then native[#native + 1] = region end
        end

        descriptors[#descriptors + 1] = {
            target = tab,
            textureProvider = GetTabIcon,
            borderOwner = tab,
            borderSize = 1,
            borderPadding = 0,
            hoverRegion = highlight,
            selectedRegion = checked,
            getHovered = function(target)
                return target and target.IsMouseOver
                    and target:IsMouseOver() or false
            end,
            getSelected = function(target)
                return target and target.GetChecked
                    and target:GetChecked() == true or false
            end,
            nativeDecorationRegions = native,
        }
    end
    return descriptors
end

function CommunitiesSkin:ApplyRightTabs(frame)
    local tabs = GetRightTabs(frame)
    if #tabs == 0 then return false end

    if not rightTabsRegistered then
        rightTabsRegistered = NSkin:RegisterIconGroup({
            id = IDs.RightTabs,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Communities right tabs",
            window = frame,
            target = frame,
            priority = 74,
            draggable = false,
            children = function()
                return GetRightTabDescriptors(frame)
            end,
            highlightRegions = function()
                local visible = {}
                for _, tab in ipairs(GetRightTabs(frame)) do
                    if IsVisible(tab) then visible[#visible + 1] = tab end
                end
                return visible
            end,
            pixelBorderTargets = function()
                return GetRightTabs(frame)
            end,
            isEditable = function()
                if not IsVisible(frame) then return false end
                for _, tab in ipairs(GetRightTabs(frame)) do
                    if IsVisible(tab) then return true end
                end
                return false
            end,
        }) ~= nil
    else
        NSkin:RefreshIconGroup(IDs.RightTabs)
    end

    return rightTabsRegistered
end

function CommunitiesSkin:ApplyAdditionalScrollBars(frame)
    if not frame then return false end
    local applied = false

    for index, definition in ipairs({
        {
            IDs.ChatScrollBar,
            "Communities chat scroll bar",
            frame.Chat and frame.Chat.ScrollBar,
            frame.Chat,
        },
        {
            IDs.MemberScrollBar,
            "Communities member list scroll bar",
            frame.MemberList and frame.MemberList.ScrollBar,
            frame.MemberList,
        },
    }) do
        local id, label, scrollBar, owner = unpack(definition)
        if scrollBar then
            local element = NSkin:RegisterScrollBar({
                id = id,
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = scrollBar,
                priority = 75 + index,
                highlightRegions = { scrollBar },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(owner)
                        and IsVisible(scrollBar)
                end,
            })
            if element then
                NSkin:RefreshTypedElementAppearance(element)
                applied = true
            end
        end
    end

    return applied
end

function CommunitiesSkin:ApplyOnlineCount(frame)
    local memberList = frame and frame.MemberList
    local text = memberList and memberList.MemberCount
    if not text then return false end

    local element = NSkin:RegisterTextElement({
        id = IDs.OnlineCount,
        module = "Communities",
        appearanceWindowID = IDs.Scope,
        label = "Online member count",
        window = frame,
        target = text,
        priority = 78,
        highlightRegions = { text },
        isEditable = function()
            return IsVisible(frame) and IsVisible(memberList)
                and IsVisible(text)
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element ~= nil
end



local function GetMemberRows(memberList, visibleOnly)
    local rows = {}
    local scrollBox = memberList and memberList.ScrollBox
    if not scrollBox then return rows end

    NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
        if row and (not visibleOnly or IsVisible(row)) then
            rows[#rows + 1] = row
        end
    end)
    return rows
end

local function GetMemberRowContent(row)
    local regions = {}
    local function Add(region)
        if region then regions[#regions + 1] = region end
    end

    Add(row and row.NameFrame and row.NameFrame.Name)
    Add(row and row.Level)
    Add(row and row.Zone)
    Add(row and row.Rank)
    Add(row and row.Note)
    Add(row and row.GuildInfo)
    return regions
end

local function StyleMemberRow(row)
    if not row or (row.IsForbidden and row:IsForbidden()) then return false end

    local style = NSkin:GetAppearanceStyle(
        "row", IDs.Scope, IDs.MemberRows)
    local border = NSkin:GetAppearanceBorderColor(
        "row", style, IDs.Scope, IDs.MemberRows)

    return NSkin:SkinRow(row, {
        style = style,
        border = border,
        height = 0,
        contentRegions = GetMemberRowContent(row),
        nativeDecorationRegions = CompactRegions(
            row.GetNormalTexture and row:GetNormalTexture()
        ),
        hoverRegion = row.GetHighlightTexture and row:GetHighlightTexture(),
        getHovered = function(target)
            return target and target.IsMouseOver
                and target:IsMouseOver() or false
        end,
    }) ~= nil
end

function CommunitiesSkin:ApplyMemberRows(frame)
    local memberList = frame and frame.MemberList
    local scrollBox = memberList and memberList.ScrollBox
    if not scrollBox then return false end

    local function RefreshRows()
        local applied = false
        for _, row in ipairs(GetMemberRows(memberList, false)) do
            applied = StyleMemberRow(row) or applied
        end
        return applied
    end

    if not memberRowsRegistered then
        memberRowsRegistered = NSkin:RegisterSkinningElement(
            IDs.MemberRows, {
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = "Member list rows",
                kind = "ROW",
                window = frame,
                target = scrollBox,
                priority = 83,
                draggable = false,
                highlightRegions = function()
                    return GetMemberRows(memberList, true)
                end,
                pixelBorderTargets = function()
                    return GetMemberRows(memberList, true)
                end,
                refreshAppearance = RefreshRows,
                refreshLayout = RefreshRows,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(memberList)
                        and #GetMemberRows(memberList, true) > 0
                end,
            }) == true
    end

    if not memberRowsScrollBoxHooked then
        local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
        if scrollBox.RegisterCallback and events
            and events.OnInitializedFrame
        then
            scrollBox:RegisterCallback(events.OnInitializedFrame,
                function(_, row)
                    StyleMemberRow(row)
                    if memberRowsRegistered then
                        NSkin:NotifySkinningElementBoundsChanged(
                            IDs.MemberRows)
                    end
                end, self)
            memberRowsScrollBoxHooked = true
        end
    end

    local applied = RefreshRows()
    if memberRowsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.MemberRows)
    end
    return applied or memberRowsRegistered
end

local function GetMemberColumnHeaders(memberList, visibleOnly)
    local headers = {}
    local columnDisplay = memberList and memberList.ColumnDisplay
    local pool = columnDisplay and columnDisplay.columnHeaders
    if not pool or type(pool.EnumerateActive) ~= "function" then
        return headers
    end

    for header in pool:EnumerateActive() do
        if header and (not visibleOnly or IsVisible(header)) then
            headers[#headers + 1] = header
        end
    end
    table.sort(headers, function(left, right)
        return (tonumber(left:GetID()) or 0) < (tonumber(right:GetID()) or 0)
    end)
    return headers
end

local function StyleMemberColumnHeader(header)
    if not header then return false end

    local style = NSkin:GetAppearanceStyle(
        "columnHeader", IDs.Scope, IDs.ColumnHeaders)
    local border = NSkin:GetAppearanceBorderColor(
        "columnHeader", style, IDs.Scope, IDs.ColumnHeaders)

    return NSkin:SkinColumnHeader(header, {
        style = style,
        border = border,
        textRegion = header.Text
            or (header.GetFontString and header:GetFontString()),
        artworkRegions = CompactRegions(
            header.Left,
            header.Middle,
            header.Right,
            header.GetHighlightTexture and header:GetHighlightTexture()
        ),
    }) ~= nil
end

function CommunitiesSkin:ApplyMemberListControls(frame)
    local memberList = frame and frame.MemberList
    if not memberList then return false end

    local applied = self:ApplyMemberRows(frame)

    local showOffline = memberList.ShowOfflineButton
    if showOffline then
        local element = NSkin:RegisterCheckbox({
            id = IDs.ShowOffline,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Show offline members",
            window = frame,
            target = showOffline,
            text = showOffline.Text or showOffline.text,
            getChecked = function(target)
                return target and target.GetChecked
                    and target:GetChecked() == true or false
            end,
            priority = 79,
            highlightRegions = {
                showOffline,
                showOffline.Text or showOffline.text,
            },
            isEditable = function()
                return IsVisible(frame) and IsVisible(memberList)
                    and IsVisible(showOffline)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    for index, definition in ipairs({
        {
            IDs.GuildMemberDropdown,
            "Guild member list dropdown",
            frame.GuildMemberListDropdown,
            "MENU_COMMUNITIES_GUILD_MEMBER_LIST",
        },
        {
            IDs.CommunityMemberDropdown,
            "Community member list dropdown",
            frame.CommunityMemberListDropdown,
            "MENU_COMMUNITIES_MEMBER_LIST",
        },
    }) do
        local id, label, dropdown, menuTag = unpack(definition)
        if dropdown then
            local element = NSkin:RegisterDropdown({
                id = id,
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = dropdown,
                menus = { menuTag },
                priority = 79 + index,
                highlightRegions = { dropdown },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(dropdown)
                end,
            })
            if element then NSkin:RefreshTypedElementAppearance(element) end
            applied = element ~= nil or applied
        end
    end

    local columnDisplay = memberList.ColumnDisplay
    if columnDisplay then
        SuppressRegion(columnDisplay.Background)
        SuppressRegion(columnDisplay.TopTileStreaks)

        local function RefreshHeaders()
            local changed = false
            for _, header in ipairs(GetMemberColumnHeaders(memberList, false)) do
                changed = StyleMemberColumnHeader(header) or changed
            end
            return changed
        end

        if not memberColumnHeadersRegistered then
            memberColumnHeadersRegistered =
                NSkin:RegisterSkinningElement(IDs.ColumnHeaders, {
                    module = "Communities",
                    appearanceWindowID = IDs.Scope,
                    label = "Member list column headers",
                    kind = "COLUMN_HEADER",
                    window = frame,
                    target = columnDisplay,
                    priority = 82,
                    draggable = false,
                    highlightRegions = function()
                        return GetMemberColumnHeaders(memberList, true)
                    end,
                    pixelBorderTargets = function()
                        return GetMemberColumnHeaders(memberList, true)
                    end,
                    refreshAppearance = RefreshHeaders,
                    refreshLayout = RefreshHeaders,
                    isEditable = function()
                        return IsVisible(frame)
                            and IsVisible(columnDisplay)
                            and #GetMemberColumnHeaders(memberList, true) > 0
                    end,
                }) == true
        end

        applied = RefreshHeaders() or applied
        if memberColumnHeadersRegistered then
            NSkin:NotifySkinningElementBoundsChanged(IDs.ColumnHeaders)
        end
    end

    if not memberListLifecycleHooked and _G.hooksecurefunc then
        if type(memberList.RefreshLayout) == "function" then
            pcall(_G.hooksecurefunc, memberList, "RefreshLayout", function()
                C_Timer.After(0, function()
                    CommunitiesSkin:ApplyMemberListControls(frame)
                end)
            end)
        end
        memberListLifecycleHooked = true
    end

    HookOwner(memberList)
    return applied
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


local function GetGuildMemberDetailTexts(detail)
    return {
        labels = CompactRegions(
            detail and detail.ZoneLabel,
            detail and detail.RankLabel,
            detail and detail.OnlineLabel,
            detail and detail.NoteLabel,
            detail and detail.OfficerNoteLabel
        ),
        values = CompactRegions(
            detail and detail.Level,
            detail and detail.ZoneText,
            detail and detail.RankText,
            detail and detail.OnlineText,
            detail and detail.NoteBackground
                and detail.NoteBackground.PersonalNoteText,
            detail and detail.OfficerNoteBackground
                and detail.OfficerNoteBackground.OfficerNoteText
        ),
    }
end

local function RegisterDetailTextGroup(frame, detail, id, label, targets, priority)
    if #targets == 0 then return false end

    local function Refresh()
        local style = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
        local applied = false
        for _, target in ipairs(targets) do
            applied = NSkin:SkinText(target, style) or applied
        end
        return applied
    end

    if not guildMemberDetailTextGroups[id] then
        guildMemberDetailTextGroups[id] =
            NSkin:RegisterSkinningElement(id, {
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = label,
                kind = "TEXT",
                window = frame,
                target = detail,
                priority = priority,
                draggable = false,
                highlightRegions = targets,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    if not IsVisible(frame) or not IsVisible(detail) then
                        return false
                    end
                    for _, target in ipairs(targets) do
                        if IsVisible(target) then return true end
                    end
                    return false
                end,
            }) == true
    end

    local applied = Refresh()
    if guildMemberDetailTextGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or guildMemberDetailTextGroups[id]
end

function CommunitiesSkin:ApplyGuildMemberDetail(frame)
    local detail = frame and frame.GuildMemberDetailFrame
    if not detail then return false end

    NSkin:SkinStandardWindowChrome({
        frame = detail,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.DetailWindow,
        headerControlsID = IDs.DetailHeaderControls,
        closeButton = detail.CloseButton,
        artworkFrame = detail.Border,
        preserveCloseButtonGeometry = true,
    })

    if not NSkin:GetSkinningElement(IDs.DetailWindow) then
        NSkin:RegisterSkinningElement(IDs.DetailWindow, {
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild member detail window",
            kind = "WINDOW",
            window = frame,
            target = detail,
            priority = 90,
            draggable = false,
            highlightRegions = { detail },
            pixelBorderTargets = { detail },
            refreshAppearance = function()
                return CommunitiesSkin:ApplyGuildMemberDetail(frame)
            end,
            refreshLayout = function()
                return CommunitiesSkin:ApplyGuildMemberDetail(frame)
            end,
            isEditable = function()
                return IsVisible(frame) and IsVisible(detail)
            end,
        })
    end

    local applied = true

    if detail.Name then
        local element = NSkin:RegisterTextElement({
            id = IDs.DetailName,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild member name",
            window = frame,
            target = detail.Name,
            priority = 91,
            highlightRegions = { detail.Name },
            isEditable = function()
                return IsVisible(frame) and IsVisible(detail)
                    and IsVisible(detail.Name)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
    end

    local texts = GetGuildMemberDetailTexts(detail)
    RegisterDetailTextGroup(frame, detail, IDs.DetailLabels,
        "Guild member detail labels", texts.labels, 92)
    RegisterDetailTextGroup(frame, detail, IDs.DetailValues,
        "Guild member detail values", texts.values, 93)

    if detail.RankDropdown then
        local element = NSkin:RegisterDropdown({
            id = IDs.DetailRankDropdown,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild member rank dropdown",
            window = frame,
            target = detail.RankDropdown,
            priority = 94,
            highlightRegions = { detail.RankDropdown },
            isEditable = function()
                return IsVisible(frame) and IsVisible(detail)
                    and IsVisible(detail.RankDropdown)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
    end

    if detail.RemoveButton then
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.DetailRemoveButton,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Remove guild member button",
            window = frame,
            target = detail.RemoveButton,
            priority = 95,
            highlightRegions = { detail.RemoveButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(detail)
                    and IsVisible(detail.RemoveButton)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
    end

    if detail.GroupInviteButton then
        local element = NSkin:RegisterActionButton({
            id = IDs.DetailInviteButton,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Group invite button",
            window = frame,
            target = detail.GroupInviteButton,
            priority = 96,
            highlightRegions = { detail.GroupInviteButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(detail)
                    and IsVisible(detail.GroupInviteButton)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
    end

    -- These are clickable note surfaces rather than edit boxes. Remove the
    -- TooltipBackdrop chrome but leave their interaction and text intact.
    if detail.NoteBackground then
        NSkin:ConcealWindowArtwork(detail.NoteBackground)
    end
    if detail.OfficerNoteBackground then
        NSkin:ConcealWindowArtwork(detail.OfficerNoteBackground)
    end

    if not guildMemberDetailHooked and detail.HookScript then
        detail:HookScript("OnShow", function()
            CommunitiesSkin:ApplyGuildMemberDetail(frame)
        end)
        guildMemberDetailHooked = true
    end

    return applied
end


local function GetDirectTextures(frame)
    local textures = {}
    if not frame or type(frame.GetRegions) ~= "function" then
        return textures
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType
            and region:GetObjectType() == "Texture"
        then
            textures[#textures + 1] = region
        end
    end
    return textures
end

local function GetGuildBenefitRows(panel, visibleOnly)
    local rows = {}
    local scrollBox = panel and panel.ScrollBox
    if not scrollBox then return rows end

    NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
        if row and (not visibleOnly or IsVisible(row)) then
            rows[#rows + 1] = row
        end
    end)
    return rows
end

local function GetGuildBenefitIcons(panel, visibleOnly)
    local targets = {}
    for _, row in ipairs(GetGuildBenefitRows(panel, visibleOnly)) do
        if row.Icon and (not visibleOnly or IsVisible(row.Icon)) then
            targets[#targets + 1] = row.Icon
        end
    end
    return targets
end

local function GetGuildBenefitTexts(panel, field, visibleOnly)
    local targets = {}
    for _, row in ipairs(GetGuildBenefitRows(panel, visibleOnly)) do
        local target = row[field]
        if target and (not visibleOnly or IsVisible(target)) then
            targets[#targets + 1] = target
        end
    end
    return targets
end

local function StyleGuildPerkRow(row)
    if not row or (row.IsForbidden and row:IsForbidden()) then
        return false
    end

    local data = NSkin:GetSkinData(row, "communitiesGuildPerkRow")
    if not data.nativeDecorations then
        data.nativeDecorations = {}
        for _, texture in ipairs(GetDirectTextures(row)) do
            if texture ~= row.Icon then
                data.nativeDecorations[#data.nativeDecorations + 1] = texture
            end
        end
        if row.NormalBorder and row.NormalBorder.GetRegions then
            for _, texture in ipairs(GetDirectTextures(row.NormalBorder)) do
                data.nativeDecorations[#data.nativeDecorations + 1] = texture
            end
        end
        if row.DisabledBorder and row.DisabledBorder.GetRegions then
            for _, texture in ipairs(GetDirectTextures(row.DisabledBorder)) do
                data.nativeDecorations[#data.nativeDecorations + 1] = texture
            end
        end
    end

    local style = NSkin:GetAppearanceStyle(
        "row", IDs.Scope, IDs.BenefitsPerkRows)
    local border = NSkin:GetAppearanceBorderColor(
        "row", style, IDs.Scope, IDs.BenefitsPerkRows)

    return NSkin:SkinRow(row, {
        style = style,
        border = border,
        height = 0,
        contentRegions = CompactRegions(row.Name),
        nativeDecorationRegions = data.nativeDecorations,
        getHovered = function(target)
            return target and target.IsMouseOver
                and target:IsMouseOver() or false
        end,
    }) ~= nil
end

local function StyleGuildRewardRow(row)
    if not row or (row.IsForbidden and row:IsForbidden()) then
        return false
    end

    local style = NSkin:GetAppearanceStyle(
        "row", IDs.Scope, IDs.BenefitsRewardRows)
    local border = NSkin:GetAppearanceBorderColor(
        "row", style, IDs.Scope, IDs.BenefitsRewardRows)

    return NSkin:SkinRow(row, {
        style = style,
        border = border,
        height = 0,
        contentRegions = CompactRegions(row.Name, row.SubText),
        nativeDecorationRegions = CompactRegions(
            row.DisabledBG,
            row.GetNormalTexture and row:GetNormalTexture(),
            row.GetHighlightTexture and row:GetHighlightTexture()
        ),
        hoverRegion = row.GetHighlightTexture and row:GetHighlightTexture(),
        getHovered = function(target)
            return target and target.IsMouseOver
                and target:IsMouseOver() or false
        end,
        preserveTextures = CompactRegions(row.Icon, row.Lock),
    }) ~= nil
end

local function ApplyGuildBenefitTextFamily(frame, panel, id, label, field, priority)
    local function Provider(visibleOnly)
        return GetGuildBenefitTexts(panel, field, visibleOnly)
    end

    local function Refresh()
        local style = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
        local applied = false
        for _, target in ipairs(Provider(false)) do
            applied = NSkin:SkinText(target, style) or applied
        end
        return applied
    end

    if not guildBenefitsGroups[id] then
        guildBenefitsGroups[id] =
            NSkin:RegisterSkinningElement(id, {
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = label,
                kind = "TEXT",
                window = frame,
                target = panel,
                priority = priority,
                draggable = false,
                highlightRegions = function()
                    return Provider(true)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(panel)
                        and #Provider(true) > 0
                end,
            }) == true
    end

    local applied = Refresh()
    if guildBenefitsGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or guildBenefitsGroups[id]
end

local function ApplyGuildBenefitIconFamily(
    frame, panel, id, label, priority)
    local function Refresh()
        local style = NSkin:GetAppearanceStyle("icon", IDs.Scope, id)
        local border = NSkin:GetAppearanceBorderColor(
            "icon", style, IDs.Scope, id)
        local applied = false

        for _, row in ipairs(GetGuildBenefitRows(panel, false)) do
            if row.Icon then
                applied = NSkin:SkinIcon(row, {
                    texture = row.Icon,
                    borderOwner = row,
                    style = style,
                    border = border,
                }) or applied
            end
        end
        return applied
    end

    if not guildBenefitsGroups[id] then
        guildBenefitsGroups[id] =
            NSkin:RegisterSkinningElement(id, {
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = label,
                kind = "ICON",
                window = frame,
                target = panel,
                priority = priority,
                draggable = false,
                highlightRegions = function()
                    return GetGuildBenefitIcons(panel, true)
                end,
                pixelBorderTargets = function()
                    return GetGuildBenefitRows(panel, true)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(panel)
                        and #GetGuildBenefitIcons(panel, true) > 0
                end,
            }) == true
    end

    local applied = Refresh()
    if guildBenefitsGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or guildBenefitsGroups[id]
end

local function ApplyGuildBenefitRows(
    frame, panel, id, label, priority, styler)
    local scrollBox = panel and panel.ScrollBox
    if not scrollBox then return false end

    local function Refresh()
        local applied = false
        for _, row in ipairs(GetGuildBenefitRows(panel, false)) do
            applied = styler(row) or applied
        end
        return applied
    end

    if not guildBenefitsGroups[id] then
        guildBenefitsGroups[id] =
            NSkin:RegisterSkinningElement(id, {
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = label,
                kind = "ROW",
                window = frame,
                target = scrollBox,
                priority = priority,
                draggable = false,
                highlightRegions = function()
                    return GetGuildBenefitRows(panel, true)
                end,
                pixelBorderTargets = function()
                    return GetGuildBenefitRows(panel, true)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(panel)
                        and #GetGuildBenefitRows(panel, true) > 0
                end,
            }) == true
    end

    local applied = Refresh()
    if guildBenefitsGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or guildBenefitsGroups[id]
end

function CommunitiesSkin:ApplyGuildBenefits(frame)
    local benefits = frame and frame.GuildBenefitsFrame
    local perks = benefits and benefits.Perks
    local rewards = benefits and benefits.Rewards
    if not benefits or not perks or not rewards then return false end

    for _, key in ipairs({
        "InsetBorderTopLeft",
        "InsetBorderTopRight",
        "InsetBorderBottomLeft",
        "InsetBorderBottomRight",
        "InsetBorderLeft",
        "InsetBorderRight",
        "InsetBorderTopLeft2",
        "InsetBorderBottomLeft2",
        "InsetBorderLeft2",
    }) do
        SuppressRegion(benefits[key])
    end

    local perksData = NSkin:GetSkinData(perks, "communitiesGuildBenefits")
    if not perksData.backgrounds then
        perksData.backgrounds = GetDirectTextures(perks)
    end
    for _, texture in ipairs(perksData.backgrounds) do
        SuppressRegion(texture)
    end
    SuppressRegion(rewards.Bg)

    local applied = false

    if perks.TitleText then
        local element = NSkin:RegisterTextElement({
            id = IDs.BenefitsPerksTitle,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild perks title",
            window = frame,
            target = perks.TitleText,
            priority = 100,
            highlightRegions = { perks.TitleText },
            isEditable = function()
                return IsVisible(frame) and IsVisible(benefits)
                    and IsVisible(perks.TitleText)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    if rewards.TitleText then
        local element = NSkin:RegisterTextElement({
            id = IDs.BenefitsRewardsTitle,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild rewards title",
            window = frame,
            target = rewards.TitleText,
            priority = 101,
            highlightRegions = { rewards.TitleText },
            isEditable = function()
                return IsVisible(frame) and IsVisible(benefits)
                    and IsVisible(rewards.TitleText)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    if perks.ScrollBar then
        local element = NSkin:RegisterScrollBar({
            id = IDs.BenefitsPerksScrollBar,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild perks scroll bar",
            window = frame,
            target = perks.ScrollBar,
            priority = 102,
            highlightRegions = { perks.ScrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(benefits)
                    and IsVisible(perks.ScrollBar)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    if rewards.ScrollBar then
        local element = NSkin:RegisterScrollBar({
            id = IDs.BenefitsRewardsScrollBar,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild rewards scroll bar",
            window = frame,
            target = rewards.ScrollBar,
            priority = 103,
            highlightRegions = { rewards.ScrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(benefits)
                    and IsVisible(rewards.ScrollBar)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    applied = ApplyGuildBenefitRows(
        frame, perks, IDs.BenefitsPerkRows,
        "Guild perk rows", 104, StyleGuildPerkRow) or applied
    applied = ApplyGuildBenefitIconFamily(
        frame, perks, IDs.BenefitsPerkIcons,
        "Guild perk icons", 105) or applied
    applied = ApplyGuildBenefitTextFamily(
        frame, perks, IDs.BenefitsPerkNames,
        "Guild perk names", "Name", 106) or applied

    applied = ApplyGuildBenefitRows(
        frame, rewards, IDs.BenefitsRewardRows,
        "Guild reward rows", 107, StyleGuildRewardRow) or applied
    applied = ApplyGuildBenefitIconFamily(
        frame, rewards, IDs.BenefitsRewardIcons,
        "Guild reward icons", 108) or applied
    applied = ApplyGuildBenefitTextFamily(
        frame, rewards, IDs.BenefitsRewardNames,
        "Guild reward names", "Name", 109) or applied
    applied = ApplyGuildBenefitTextFamily(
        frame, rewards, IDs.BenefitsRewardSubText,
        "Guild reward requirement text", "SubText", 110) or applied

    local tutorial = benefits.GuildRewardsTutorialButton
    if tutorial then
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.BenefitsTutorial,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild rewards help button",
            window = frame,
            target = tutorial,
            priority = 111,
            highlightRegions = { tutorial },
            isEditable = function()
                return IsVisible(frame) and IsVisible(benefits)
                    and IsVisible(tutorial)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    local achievementDisplay = benefits.GuildAchievementPointDisplay
    local achievementText = achievementDisplay
        and achievementDisplay.SumText
    if achievementText then
        local element = NSkin:RegisterTextElement({
            id = IDs.BenefitsAchievementPoints,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild achievement points",
            window = frame,
            target = achievementText,
            priority = 112,
            highlightRegions = { achievementText },
            isEditable = function()
                return IsVisible(frame) and IsVisible(benefits)
                    and IsVisible(achievementText)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    local factionFrame = benefits.FactionFrame
    if factionFrame and factionFrame.Label then
        local element = NSkin:RegisterTextElement({
            id = IDs.BenefitsFactionLabel,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild reputation label",
            window = frame,
            target = factionFrame.Label,
            priority = 113,
            highlightRegions = { factionFrame.Label },
            isEditable = function()
                return IsVisible(frame) and IsVisible(benefits)
                    and IsVisible(factionFrame.Label)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    local factionBar = factionFrame and factionFrame.Bar
    if factionBar then
        applied = NSkin:RegisterProgressBarElement({
            id = IDs.BenefitsFactionProgress,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild reputation progress",
            window = frame,
            target = factionBar,
            priority = 114,
            highlightRegions = { factionBar },
            skinOptions = {
                fill = factionBar.Progress,
                label = factionBar.Label,
                artworkRegions = CompactRegions(
                    factionBar.Left,
                    factionBar.Right,
                    factionBar.Middle,
                    factionBar.BG,
                    factionBar.Shadow
                ),
                centerText = true,
            },
            isEditable = function()
                return IsVisible(frame) and IsVisible(benefits)
                    and IsVisible(factionBar)
            end,
        }) ~= nil or applied
    end

    if not guildBenefitsPerksScrollHooked then
        local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
        if perks.ScrollBox and perks.ScrollBox.RegisterCallback
            and events and events.OnInitializedFrame
        then
            perks.ScrollBox:RegisterCallback(events.OnInitializedFrame,
                function(_, row)
                    StyleGuildPerkRow(row)
                    ApplyGuildBenefitIconFamily(
                        frame, perks, IDs.BenefitsPerkIcons,
                        "Guild perk icons", 105)
                    ApplyGuildBenefitTextFamily(
                        frame, perks, IDs.BenefitsPerkNames,
                        "Guild perk names", "Name", 106)
                end, self)
            guildBenefitsPerksScrollHooked = true
        end
    end

    if not guildBenefitsRewardsScrollHooked then
        local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
        if rewards.ScrollBox and rewards.ScrollBox.RegisterCallback
            and events and events.OnInitializedFrame
        then
            rewards.ScrollBox:RegisterCallback(events.OnInitializedFrame,
                function(_, row)
                    StyleGuildRewardRow(row)
                    ApplyGuildBenefitIconFamily(
                        frame, rewards, IDs.BenefitsRewardIcons,
                        "Guild reward icons", 108)
                    ApplyGuildBenefitTextFamily(
                        frame, rewards, IDs.BenefitsRewardNames,
                        "Guild reward names", "Name", 109)
                    ApplyGuildBenefitTextFamily(
                        frame, rewards, IDs.BenefitsRewardSubText,
                        "Guild reward requirement text", "SubText", 110)
                end, self)
            guildBenefitsRewardsScrollHooked = true
        end
    end

    HookOwner(benefits)
    HookOwner(perks)
    HookOwner(rewards)
    return applied
end


local function GetDirectFontStrings(owner, exclusions)
    local targets = {}
    if not owner or type(owner.GetRegions) ~= "function" then
        return targets
    end
    exclusions = exclusions or {}
    for _, region in ipairs({ owner:GetRegions() }) do
        if region and region.GetObjectType
            and region:GetObjectType() == "FontString"
            and not exclusions[region]
        then
            targets[#targets + 1] = region
        end
    end
    return targets
end

local function GetGuildNewsRows(news, visibleOnly)
    local rows = {}
    local scrollBox = news and news.ScrollBox
    if not scrollBox then return rows end

    NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
        if row and (not visibleOnly or IsVisible(row)) then
            rows[#rows + 1] = row
        end
    end)
    return rows
end

local function StyleGuildChallengeRow(row)
    if not row or (row.IsForbidden and row:IsForbidden()) then
        return false
    end

    local style = NSkin:GetAppearanceStyle(
        "row", IDs.Scope, IDs.DetailsChallenges)
    local border = NSkin:GetAppearanceBorderColor(
        "row", style, IDs.Scope, IDs.DetailsChallenges)

    return NSkin:SkinRow(row, {
        style = style,
        border = border,
        height = 0,
        contentRegions = CompactRegions(row.label, row.count),
        getHovered = function(target)
            return target and target.IsMouseOver
                and target:IsMouseOver() or false
        end,
        preserveTextures = CompactRegions(row.check),
    }) ~= nil
end

local function StyleGuildNewsRow(row)
    if not row or (row.IsForbidden and row:IsForbidden()) then
        return false
    end

    local style = NSkin:GetAppearanceStyle(
        "row", IDs.Scope, IDs.DetailsNewsRows)
    local border = NSkin:GetAppearanceBorderColor(
        "row", style, IDs.Scope, IDs.DetailsNewsRows)

    return NSkin:SkinRow(row, {
        style = style,
        border = border,
        height = 0,
        contentRegions = CompactRegions(row.text, row.dash),
        nativeDecorationRegions = CompactRegions(
            row.header,
            row.GetHighlightTexture and row:GetHighlightTexture()
        ),
        hoverRegion = row.GetHighlightTexture and row:GetHighlightTexture(),
        getHovered = function(target)
            return target and target.IsMouseOver
                and target:IsMouseOver() or false
        end,
        preserveTextures = CompactRegions(row.icon),
    }) ~= nil
end

local function RegisterGuildDetailsTextGroup(
    frame, owner, id, label, targets, priority)
    if not targets or #targets == 0 then return false end

    local function Refresh()
        local style = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
        local applied = false
        for _, target in ipairs(targets) do
            applied = NSkin:SkinText(target, style) or applied
        end
        return applied
    end

    if not guildDetailsGroups[id] then
        guildDetailsGroups[id] =
            NSkin:RegisterSkinningElement(id, {
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = label,
                kind = "TEXT",
                window = frame,
                target = owner,
                priority = priority,
                draggable = false,
                highlightRegions = targets,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    if not IsVisible(frame) or not IsVisible(owner) then
                        return false
                    end
                    for _, target in ipairs(targets) do
                        if IsVisible(target) then return true end
                    end
                    return false
                end,
            }) == true
    end

    local applied = Refresh()
    if guildDetailsGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or guildDetailsGroups[id]
end

local function RegisterGuildDetailsSectionHeaders(
    frame, owner, id, label, targets, priority)
    if not targets or #targets == 0 then return false end

    local function Refresh()
        local style = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
        local applied = false
        for _, target in ipairs(targets) do
            applied = NSkin:SkinText(target, style) or applied
        end
        return applied
    end

    if not guildDetailsGroups[id] then
        guildDetailsGroups[id] =
            NSkin:RegisterSkinningElement(id, {
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = label,
                kind = "SECTION_HEADER",
                window = frame,
                target = owner,
                priority = priority,
                draggable = false,
                appearanceStyles = { "text" },
                appearanceTypeIDs = { "TEXT" },
                highlightRegions = targets,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    if not IsVisible(frame) or not IsVisible(owner) then
                        return false
                    end
                    for _, target in ipairs(targets) do
                        if IsVisible(target) then return true end
                    end
                    return false
                end,
            }) == true
    end

    local applied = Refresh()
    if guildDetailsGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or guildDetailsGroups[id]
end

function CommunitiesSkin:ApplyGuildDetails(frame)
    local details = frame and frame.GuildDetailsFrame
    local info = details and details.Info
    local news = details and details.News
    if not details or not info or not news then return false end

    local applied = false

    -- Remove the native split-panel borders.
    for _, key in ipairs({
        "InsetBorderTopLeft",
        "InsetBorderTopRight",
        "InsetBorderBottomLeft",
        "InsetBorderBottomRight",
        "InsetBorderLeft",
        "InsetBorderRight",
        "InsetBorderTopLeft2",
        "InsetBorderBottomLeft2",
        "InsetBorderLeft2",
    }) do
        SuppressRegion(details[key])
    end

    -- All direct textures on the two panels are decorative backgrounds,
    -- section header strips, or separator bars. Child content remains intact.
    local infoData = NSkin:GetSkinData(info, "communitiesGuildDetails")
    if not infoData.decorations then
        infoData.decorations = GetDirectTextures(info)
    end
    for _, texture in ipairs(infoData.decorations) do
        SuppressRegion(texture)
    end

    local newsData = NSkin:GetSkinData(news, "communitiesGuildDetails")
    if not newsData.decorations then
        newsData.decorations = GetDirectTextures(news)
    end
    for _, texture in ipairs(newsData.decorations) do
        SuppressRegion(texture)
    end

    if info.TitleText then
        local element = NSkin:RegisterTextElement({
            id = IDs.DetailsInfoTitle,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild info title",
            window = frame,
            target = info.TitleText,
            priority = 120,
            highlightRegions = { info.TitleText },
            isEditable = function()
                return IsVisible(frame) and IsVisible(details)
                    and IsVisible(info.TitleText)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    if news.TitleText then
        local element = NSkin:RegisterTextElement({
            id = IDs.DetailsNewsTitle,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild news title",
            window = frame,
            target = news.TitleText,
            priority = 121,
            highlightRegions = { news.TitleText },
            isEditable = function()
                return IsVisible(frame) and IsVisible(details)
                    and IsVisible(news.TitleText)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    local infoHeaders = GetDirectFontStrings(info, {
        [info.TitleText] = true,
    })
    applied = RegisterGuildDetailsSectionHeaders(
        frame, info, IDs.DetailsInfoHeaders,
        "Guild info section headers", infoHeaders, 122) or applied

    local newsHeaders = GetDirectFontStrings(news, {
        [news.TitleText] = true,
        [news.NoNews] = true,
    })
    applied = RegisterGuildDetailsSectionHeaders(
        frame, news, IDs.DetailsNewsHeader,
        "Guild news section header", newsHeaders, 123) or applied

    if not guildDetailsGroups[IDs.DetailsChallenges] then
        guildDetailsGroups[IDs.DetailsChallenges] =
            NSkin:RegisterSkinningElement(IDs.DetailsChallenges, {
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = "Guild challenge rows",
                kind = "ROW",
                window = frame,
                target = info,
                priority = 124,
                draggable = false,
                highlightRegions = function()
                    local targets = {}
                    for _, row in ipairs(info.Challenges or {}) do
                        if row and IsVisible(row) then
                            targets[#targets + 1] = row
                        end
                    end
                    return targets
                end,
                pixelBorderTargets = function()
                    local targets = {}
                    for _, row in ipairs(info.Challenges or {}) do
                        if row and IsVisible(row) then
                            targets[#targets + 1] = row
                        end
                    end
                    return targets
                end,
                refreshAppearance = function()
                    local changed = false
                    for _, row in ipairs(info.Challenges or {}) do
                        changed = StyleGuildChallengeRow(row) or changed
                    end
                    return changed
                end,
                refreshLayout = function()
                    local changed = false
                    for _, row in ipairs(info.Challenges or {}) do
                        changed = StyleGuildChallengeRow(row) or changed
                    end
                    NSkin:NotifySkinningElementBoundsChanged(
                        IDs.DetailsChallenges)
                    return changed
                end,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(details)
                end,
            }) == true
    end
    for _, row in ipairs(info.Challenges or {}) do
        applied = StyleGuildChallengeRow(row) or applied
    end

    local motdScroll = info.MOTDScrollFrame
    if motdScroll and motdScroll.ScrollBar then
        local element = NSkin:RegisterScrollBar({
            id = IDs.DetailsMotdScrollBar,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild message scroll bar",
            window = frame,
            target = motdScroll.ScrollBar,
            priority = 125,
            highlightRegions = { motdScroll.ScrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(details)
                    and IsVisible(motdScroll.ScrollBar)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    local infoScroll = info.DetailsFrame
    if infoScroll and infoScroll.ScrollBar then
        local element = NSkin:RegisterScrollBar({
            id = IDs.DetailsInfoScrollBar,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild information scroll bar",
            window = frame,
            target = infoScroll.ScrollBar,
            priority = 126,
            highlightRegions = { infoScroll.ScrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(details)
                    and IsVisible(infoScroll.ScrollBar)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied

        local child = infoScroll.GetScrollChild and infoScroll:GetScrollChild()
        local detailsText = child and child.Details
        if detailsText then
            local textElement = NSkin:RegisterTextElement({
                id = IDs.DetailsInfoText,
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = "Guild information text",
                window = frame,
                target = detailsText,
                priority = 127,
                highlightRegions = { detailsText },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(details)
                        and IsVisible(detailsText)
                end,
            })
            if textElement then
                NSkin:RefreshTypedElementAppearance(textElement)
            end
            applied = textElement ~= nil or applied
        end
    end

    for index, definition in ipairs({
        {
            IDs.DetailsEditMotd,
            "Edit guild message button",
            info.EditMOTDButton,
        },
        {
            IDs.DetailsEditInfo,
            "Edit guild information button",
            info.EditDetailsButton,
        },
        {
            IDs.DetailsNewsFilters,
            "Guild news filters button",
            news.SetFiltersButton,
        },
        {
            IDs.DetailsViewLog,
            "View guild log button",
            frame.GuildLogButton,
        },
    }) do
        local id, label, button = unpack(definition)
        if button then
            local element = NSkin:RegisterTypedElement("BUTTON", {
                id = id,
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = button,
                priority = 127 + index,
                highlightRegions = { button },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            })
            if element then NSkin:RefreshTypedElementAppearance(element) end
            applied = element ~= nil or applied
        end
    end

    if news.NoNews then
        local element = NSkin:RegisterTextElement({
            id = IDs.DetailsNewsNoNews,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "No guild news text",
            window = frame,
            target = news.NoNews,
            priority = 132,
            highlightRegions = { news.NoNews },
            isEditable = function()
                return IsVisible(frame) and IsVisible(details)
                    and IsVisible(news.NoNews)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    if news.ScrollBar then
        local element = NSkin:RegisterScrollBar({
            id = IDs.DetailsNewsScrollBar,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild news scroll bar",
            window = frame,
            target = news.ScrollBar,
            priority = 133,
            highlightRegions = { news.ScrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(details)
                    and IsVisible(news.ScrollBar)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    local function RefreshNewsRows()
        local changed = false
        for _, row in ipairs(GetGuildNewsRows(news, false)) do
            changed = StyleGuildNewsRow(row) or changed
        end
        return changed
    end

    if not guildDetailsGroups[IDs.DetailsNewsRows] then
        guildDetailsGroups[IDs.DetailsNewsRows] =
            NSkin:RegisterSkinningElement(IDs.DetailsNewsRows, {
                module = "Communities",
                appearanceWindowID = IDs.Scope,
                label = "Guild news rows",
                kind = "ROW",
                window = frame,
                target = news.ScrollBox,
                priority = 134,
                draggable = false,
                highlightRegions = function()
                    return GetGuildNewsRows(news, true)
                end,
                pixelBorderTargets = function()
                    return GetGuildNewsRows(news, true)
                end,
                refreshAppearance = RefreshNewsRows,
                refreshLayout = RefreshNewsRows,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(details)
                        and #GetGuildNewsRows(news, true) > 0
                end,
            }) == true
    end

    applied = RefreshNewsRows() or applied
    if guildDetailsGroups[IDs.DetailsNewsRows] then
        NSkin:NotifySkinningElementBoundsChanged(IDs.DetailsNewsRows)
    end

    if not guildDetailsNewsScrollHooked then
        local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
        if news.ScrollBox and news.ScrollBox.RegisterCallback
            and events and events.OnInitializedFrame
        then
            news.ScrollBox:RegisterCallback(events.OnInitializedFrame,
                function(_, row)
                    StyleGuildNewsRow(row)
                    if guildDetailsGroups[IDs.DetailsNewsRows] then
                        NSkin:NotifySkinningElementBoundsChanged(
                            IDs.DetailsNewsRows)
                    end
                end, self)
            guildDetailsNewsScrollHooked = true
        end
    end

    HookOwner(details)
    HookOwner(info)
    HookOwner(news)
    return applied
end

local function FindGuildLogBottomCloseButton(log)
    if not log or type(log.GetChildren) ~= "function" then return nil end
    for _, child in ipairs({ log:GetChildren() }) do
        if child and child.IsObjectType and child:IsObjectType("Button")
            and child.GetText and child:GetText() == _G.CLOSE
        then
            return child
        end
    end
    return nil
end

function CommunitiesSkin:ApplyGuildLog(frame)
    local log = _G.CommunitiesGuildLogFrame
    if not log then return false end

    local title = _G.CommunitiesGuildLogFrameTitle
    local topClose = _G.CommunitiesGuildLogFrameCloseButton

    NSkin:SkinStandardWindowChrome({
        frame = log,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.GuildLogWindow,
        headerControlsID = IDs.GuildLogHeaderControls,
        title = title,
        closeButton = topClose,
        preserveCloseButtonGeometry = true,
    })

    if not NSkin:GetSkinningElement(IDs.GuildLogWindow) then
        NSkin:RegisterSkinningElement(IDs.GuildLogWindow, {
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild log window",
            kind = "WINDOW",
            window = log,
            target = log,
            priority = 140,
            draggable = false,
            highlightRegions = { log },
            pixelBorderTargets = { log },
            refreshAppearance = function()
                return CommunitiesSkin:ApplyGuildLog(frame)
            end,
            refreshLayout = function()
                return CommunitiesSkin:ApplyGuildLog(frame)
            end,
            isEditable = function()
                return IsVisible(log)
            end,
        })
    end

    local container = log.Container
    if container then
        NSkin:ConcealWindowArtwork(container)
    end

    local scrollFrame = container and container.ScrollFrame
    local scrollBar = scrollFrame and scrollFrame.ScrollBar
    if scrollBar then
        local element = NSkin:RegisterScrollBar({
            id = IDs.GuildLogScrollBar,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild log scroll bar",
            window = log,
            target = scrollBar,
            priority = 141,
            highlightRegions = { scrollBar },
            isEditable = function()
                return IsVisible(log) and IsVisible(scrollBar)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
    end

    local bottomClose = FindGuildLogBottomCloseButton(log)
    if bottomClose then
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.GuildLogClose,
            module = "Communities",
            appearanceWindowID = IDs.Scope,
            label = "Guild log close button",
            window = log,
            target = bottomClose,
            priority = 142,
            highlightRegions = { bottomClose },
            isEditable = function()
                return IsVisible(log) and IsVisible(bottomClose)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
    end

    if not guildLogHooked and log.HookScript then
        log:HookScript("OnShow", function()
            CommunitiesSkin:ApplyGuildLog(frame)
        end)
        guildLogHooked = true
    end

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
    self:ApplyBorderCleanup(frame)
    self:ApplyListEntries(frame)
    self:ApplyFinderControls(frame)
    self:ApplyListScrollBar(frame)
    self:ApplyAdditionalScrollBars(frame)
    self:ApplyRightTabs(frame)
    self:ApplyOnlineCount(frame)
    self:ApplyMemberListControls(frame)
    self:ApplyGuildMemberDetail(frame)
    self:ApplyGuildBenefits(frame)
    self:ApplyGuildDetails(frame)
    self:ApplyGuildLog(frame)
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
