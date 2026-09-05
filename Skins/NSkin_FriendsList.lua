local _, NSkin = ...

local FriendsListSkin = NSkin:NewModule("FriendsList")

local IDs = {
    Scope = "FriendsList",
    Window = "FriendsList.Window",
    HeaderControls = "FriendsList.HeaderControls",
    StatusDropdown = "FriendsList.StatusDropdown",
    AddFriendButton = "FriendsList.AddFriendButton",
    SendMessageButton = "FriendsList.SendMessageButton",
    TopTabs = "FriendsList.TopTabs",
    BottomTabs = "FriendsList.BottomTabs",
    ScrollBar = "FriendsList.ScrollBar",
    Who = {
        Scope = "FriendsList.Who",
        SearchBox = "FriendsList.Who.SearchBox",
        ZoneDropdown = "FriendsList.Who.ZoneDropdown",
        ScrollBar = "FriendsList.Who.ScrollBar",
        RefreshButton = "FriendsList.Who.RefreshButton",
        AddFriendButton = "FriendsList.Who.AddFriendButton",
        GroupInviteButton = "FriendsList.Who.GroupInviteButton",
    },
    Raid = {
        Scope = "FriendsList.Raid",
        AllAssist = "FriendsList.Raid.AllAssist",
        AllAssistText = "FriendsList.Raid.AllAssistText",
        RaidInfoButton = "FriendsList.Raid.RaidInfoButton",
        ConvertToRaidButton = "FriendsList.Raid.ConvertToRaidButton",
    },
    QuickJoin = {
        Scope = "FriendsList.QuickJoin",
        RequestToJoinButton = "FriendsList.QuickJoin.RequestToJoinButton",
        ScrollBar = "FriendsList.QuickJoin.ScrollBar",
    },
}

local initialized = false
local showHooked = false
local applyPending = false
local hookedScrollBar
local hookedWhoFrame
local hookedRaidFrame
local hookedQuickJoinFrame
local hookedRefreshControls = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Friends List",
})
NSkin:RegisterAppearanceScope(IDs.Who.Scope, {
    label = "Who List",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.Raid.Scope, {
    label = "Raid",
    parent = IDs.Scope,
})
NSkin:RegisterAppearanceScope(IDs.QuickJoin.Scope, {
    label = "Quick Join",
    parent = IDs.Scope,
})

local function GetFriendsListScrollBar()
    local list = _G.FriendsListFrame
    return list and list.ScrollBar
end

local function GetTopTabSystem()
    local header = _G.FriendsTabHeader
    return header and header.TabSystem
end

local function GetBottomTabs()
    return {
        _G.FriendsFrameTab1,
        _G.FriendsFrameTab2,
        _G.FriendsFrameTab3,
        _G.FriendsFrameTab4,
    }
end

local function HookControlRefresh(control)
    if not control or hookedRefreshControls[control] or not control.HookScript then
        return
    end
    control:HookScript("OnClick", function()
        FriendsListSkin:QueueApply()
    end)
    hookedRefreshControls[control] = true
end

local function HideFriendsPortrait()
    local portrait = _G.FriendsFrameIcon
    if not portrait then return false end
    portrait:SetAlpha(0)
    portrait:Hide()
    return true
end

function FriendsListSkin:ApplyWindowChrome()
    local friendsFrame = _G.FriendsFrame
    if not friendsFrame then return false end

    NSkin:SkinStandardWindowChrome({
        frame = friendsFrame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = _G.FriendsFrameTitleText,
    })
    HideFriendsPortrait()
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Friends List window",
        kind = "WINDOW",
        module = "FriendsList",
        appearanceWindowID = IDs.Scope,
        window = friendsFrame,
        target = friendsFrame,
        priority = 0,
        draggable = false,
    })
    return true
end

function FriendsListSkin:ApplyStatusDropdown()
    local friendsFrame = _G.FriendsFrame
    local dropdown = _G.FriendsFrameStatusDropdown
        or (friendsFrame and friendsFrame.FriendsTabHeader
            and friendsFrame.FriendsTabHeader.StatusDropdown)
    if not friendsFrame or not dropdown then return false end

    NSkin:RegisterDropdown({
        id = IDs.StatusDropdown,
        module = "FriendsList",
        appearanceWindowID = IDs.Scope,
        label = "Friends status dropdown",
        window = friendsFrame,
        target = dropdown,
        menus = { "MENU_FRIENDS_STATUS" },
        priority = 80,
        highlightRegions = { dropdown },
        isEditable = function()
            return friendsFrame:IsVisible() and dropdown:IsVisible()
        end,
    })
    return true
end

function FriendsListSkin:ApplyWhoControls()
    local friendsFrame = _G.FriendsFrame
    local whoFrame = _G.WhoFrame
    if not friendsFrame or not whoFrame then return false end

    local searchBox = _G.WhoFrameEditBox or whoFrame.EditBox
    if searchBox then
        NSkin:RegisterSearchBox({
            id = IDs.Who.SearchBox,
            module = "FriendsList",
            appearanceWindowID = IDs.Who.Scope,
            label = "Who List search bar",
            window = friendsFrame,
            target = searchBox,
            priority = 82,
            highlightRegions = { searchBox },
            isEditable = function()
                return whoFrame:IsVisible() and searchBox:IsVisible()
            end,
        })
    end

    local dropdown = _G.WhoFrameDropdown
    if dropdown then
        NSkin:RegisterDropdown({
            id = IDs.Who.ZoneDropdown,
            module = "FriendsList",
            appearanceWindowID = IDs.Who.Scope,
            label = "Who List zone dropdown",
            window = friendsFrame,
            target = dropdown,
            menus = { "MENU_FRIENDS_WHO" },
            priority = 81,
            highlightRegions = { dropdown },
            isEditable = function()
                return whoFrame:IsVisible() and dropdown:IsVisible()
            end,
        })
    end

    local scrollBar = whoFrame.ScrollBar
    if scrollBar then
        NSkin:RegisterScrollBar({
            id = IDs.Who.ScrollBar,
            module = "FriendsList",
            appearanceWindowID = IDs.Who.Scope,
            label = "Who List scroll bar",
            window = friendsFrame,
            target = scrollBar,
            priority = 80,
            highlightRegions = { scrollBar },
            isEditable = function()
                return whoFrame:IsVisible() and scrollBar:IsVisible()
            end,
        })
    end

    for _, definition in ipairs({
        { IDs.Who.RefreshButton, "Who List refresh button", _G.WhoFrameWhoButton },
        { IDs.Who.AddFriendButton, "Who List add friend button",
            _G.WhoFrameAddFriendButton },
        { IDs.Who.GroupInviteButton, "Who List group invite button",
            _G.WhoFrameGroupInviteButton },
    }) do
        local id, label, button = unpack(definition)
        if button then
            NSkin:RegisterActionButton({
                id = id, module = "FriendsList",
                appearanceWindowID = IDs.Who.Scope, label = label,
                window = friendsFrame, target = button, priority = 70,
                highlightRegions = { button },
                isEditable = function()
                    return friendsFrame:IsVisible() and whoFrame:IsVisible()
                        and button:IsVisible()
                end,
            })
        end
    end

    if hookedWhoFrame ~= whoFrame and whoFrame.HookScript then
        whoFrame:HookScript("OnShow", function()
            FriendsListSkin:QueueApply()
        end)
        hookedWhoFrame = whoFrame
    end
    return searchBox ~= nil or dropdown ~= nil
end

function FriendsListSkin:ApplyRaidControls()
    local friendsFrame = _G.FriendsFrame
    local raidFrame = _G.RaidFrame
    if not friendsFrame or not raidFrame then return false end

    local allAssist = _G.RaidFrameAllAssistCheckButton
    local allAssistText = _G.RaidFrameAllAssistCheckButtonText
    if allAssist then
        NSkin:RegisterCheckbox({
            id = IDs.Raid.AllAssist, module = "FriendsList",
            appearanceWindowID = IDs.Raid.Scope,
            label = "Raid all-assist checkbox", window = friendsFrame,
            target = allAssist, priority = 82,
            highlightRegions = { allAssist },
            text = allAssistText,
            isEditable = function()
                return raidFrame:IsVisible() and allAssist:IsVisible()
            end,
        })
    end
    if allAssistText then
        NSkin:RegisterTextElement({
            id = IDs.Raid.AllAssistText,
            module = "FriendsList",
            appearanceWindowID = IDs.Raid.Scope,
            label = "Raid all-assist text",
            window = friendsFrame,
            target = allAssistText,
            priority = 83,
            highlightRegions = { allAssistText },
            isEditable = function()
                return raidFrame:IsVisible() and allAssistText:IsVisible()
            end,
        })
    end

    for _, definition in ipairs({
        { IDs.Raid.RaidInfoButton, "Raid info button",
            _G.RaidFrameRaidInfoButton },
        { IDs.Raid.ConvertToRaidButton, "Convert to raid button",
            _G.RaidFrameConvertToRaidButton },
    }) do
        local id, label, button = unpack(definition)
        if button then
            NSkin:RegisterActionButton({
                id = id, module = "FriendsList",
                appearanceWindowID = IDs.Raid.Scope, label = label,
                window = friendsFrame, target = button, priority = 70,
                highlightRegions = { button },
                isEditable = function()
                    return friendsFrame:IsVisible() and raidFrame:IsVisible()
                        and button:IsVisible()
                end,
            })
        end
    end

    if hookedRaidFrame ~= raidFrame and raidFrame.HookScript then
        raidFrame:HookScript("OnShow", function()
            FriendsListSkin:QueueApply()
        end)
        hookedRaidFrame = raidFrame
    end
    return allAssist ~= nil or _G.RaidFrameRaidInfoButton ~= nil
end

function FriendsListSkin:ApplyQuickJoinControls()
    local friendsFrame = _G.FriendsFrame
    local quickJoinFrame = _G.QuickJoinFrame
    if not friendsFrame or not quickJoinFrame then return false end

    local joinButton = quickJoinFrame.JoinQueueButton
    if joinButton then
        NSkin:RegisterActionButton({
            id = IDs.QuickJoin.RequestToJoinButton, module = "FriendsList",
            appearanceWindowID = IDs.QuickJoin.Scope,
            label = "Quick Join request button", window = friendsFrame,
            target = joinButton, priority = 70,
            highlightRegions = { joinButton },
            isEditable = function()
                return friendsFrame:IsVisible() and quickJoinFrame:IsVisible()
                    and joinButton:IsVisible()
            end,
        })
    end

    local scrollBar = quickJoinFrame.ScrollBar
    if scrollBar then
        NSkin:RegisterScrollBar({
            id = IDs.QuickJoin.ScrollBar,
            module = "FriendsList",
            appearanceWindowID = IDs.QuickJoin.Scope,
            label = "Quick Join scroll bar",
            window = friendsFrame,
            target = scrollBar,
            priority = 80,
            highlightRegions = { scrollBar },
            isEditable = function()
                return quickJoinFrame:IsVisible() and scrollBar:IsVisible()
            end,
        })
    end

    if hookedQuickJoinFrame ~= quickJoinFrame and quickJoinFrame.HookScript then
        quickJoinFrame:HookScript("OnShow", function()
            FriendsListSkin:QueueApply()
        end)
        hookedQuickJoinFrame = quickJoinFrame
    end
    return quickJoinFrame.JoinQueueButton ~= nil or scrollBar ~= nil
end

function FriendsListSkin:ApplyActionButtons()
    local friendsFrame = _G.FriendsFrame
    if not friendsFrame then return false end
    local addFriend = _G.FriendsFrameAddFriendButton
    local sendMessage = _G.FriendsFrameSendMessageButton
    local addApplied = addFriend and NSkin:RegisterActionButton({
        id = IDs.AddFriendButton, module = "FriendsList",
        appearanceWindowID = IDs.Scope, label = "Add friend button",
        window = friendsFrame, target = addFriend, priority = 70,
        highlightRegions = { addFriend },
        isEditable = function()
            return friendsFrame:IsVisible() and addFriend:IsVisible()
        end,
    }) ~= nil
    local sendApplied = sendMessage and NSkin:RegisterActionButton({
        id = IDs.SendMessageButton, module = "FriendsList",
        appearanceWindowID = IDs.Scope, label = "Send message button",
        window = friendsFrame, target = sendMessage, priority = 70,
        highlightRegions = { sendMessage },
        isEditable = function()
            return friendsFrame:IsVisible() and sendMessage:IsVisible()
        end,
    }) ~= nil
    return addApplied or sendApplied
end

function FriendsListSkin:ApplyTabs()
    local friendsFrame = _G.FriendsFrame
    local topTabHeader = _G.FriendsTabHeader
    local topTabSystem = GetTopTabSystem()
    local bottomTabs = GetBottomTabs()
    if not friendsFrame then return false end

    local topApplied
    if topTabSystem and type(topTabSystem.tabs) == "table"
        and #topTabSystem.tabs > 0
    then
        local style = NSkin:GetAppearanceStyle(
            "tab", IDs.Scope, IDs.TopTabs)
        local border = NSkin:GetAppearanceBorderColor(
            "tab", style, IDs.Scope, IDs.TopTabs)
        NSkin:SkinTabSystem(topTabSystem, style, border)
        NSkin:RegisterTabGroup(IDs.TopTabs, {
            label = "Friends and recent allies tabs",
            kind = "TAB_GROUP",
            module = "FriendsList",
            appearanceWindowID = IDs.Scope,
            window = friendsFrame,
            target = topTabSystem,
            container = topTabSystem,
            priority = 60,
            orientation = "HORIZONTAL",
            edge = "TOP",
            isEditable = function()
                return friendsFrame:IsVisible()
                    and friendsFrame.selectedTab == 1
                    and topTabHeader and topTabHeader:IsVisible()
                    and topTabSystem:IsVisible()
            end,
        })
        NSkin:ApplyTabGroupLayout(IDs.TopTabs)
        for i = 1, #topTabSystem.tabs do
            HookControlRefresh(topTabSystem.tabs[i])
        end
        topApplied = true
    end

    local bottomComplete = true
    for i = 1, #bottomTabs do
        if not bottomTabs[i] then bottomComplete = false break end
    end
    if bottomComplete then
        local style = NSkin:GetAppearanceStyle(
            "tab", IDs.Scope, IDs.BottomTabs)
        local border = NSkin:GetAppearanceBorderColor(
            "tab", style, IDs.Scope, IDs.BottomTabs)
        local selected = _G.PanelTemplates_GetSelectedTab
            and _G.PanelTemplates_GetSelectedTab(friendsFrame)
        for i = 1, #bottomTabs do
            NSkin:SkinTab(bottomTabs[i], i == selected, style, border)
            HookControlRefresh(bottomTabs[i])
        end
        NSkin:RegisterTabGroup(IDs.BottomTabs, {
            label = "Friends List bottom tabs",
            kind = "TAB_GROUP",
            module = "FriendsList",
            appearanceWindowID = IDs.Scope,
            window = friendsFrame,
            tabs = bottomTabs,
            priority = 50,
            orientation = "HORIZONTAL",
            edge = "BOTTOM",
        })
        NSkin:ApplyTabGroupLayout(IDs.BottomTabs)
    end
    return topApplied or bottomComplete
end

function FriendsListSkin:ApplyScrollBar()
    local friendsFrame = _G.FriendsFrame
    local scrollBar = GetFriendsListScrollBar()
    if not friendsFrame or not scrollBar then return false end

    NSkin:RegisterScrollBar({
        id = IDs.ScrollBar,
        module = "FriendsList",
        appearanceWindowID = IDs.Scope,
        label = "Friends list scroll bar",
        window = friendsFrame,
        target = scrollBar,
        priority = 80,
        highlightRegions = { scrollBar },
        isEditable = function()
            return friendsFrame:IsVisible() and scrollBar:IsVisible()
        end,
    })

    if hookedScrollBar ~= scrollBar and scrollBar.HookScript then
        scrollBar:HookScript("OnShow", function()
            FriendsListSkin:QueueApply()
        end)
        hookedScrollBar = scrollBar
    end
    return true
end

function FriendsListSkin:QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        FriendsListSkin:ApplyWindowChrome()
        FriendsListSkin:ApplyStatusDropdown()
        FriendsListSkin:ApplyActionButtons()
        FriendsListSkin:ApplyWhoControls()
        FriendsListSkin:ApplyRaidControls()
        FriendsListSkin:ApplyQuickJoinControls()
        FriendsListSkin:ApplyTabs()
        FriendsListSkin:ApplyScrollBar()
    end)
end

function FriendsListSkin:Initialize()
    if initialized then return true end
    local friendsFrame = _G.FriendsFrame
    if not friendsFrame then return false end

    if not showHooked and friendsFrame.HookScript then
        friendsFrame:HookScript("OnShow", function()
            FriendsListSkin:QueueApply()
        end)
        showHooked = true
    end

    initialized = true
    self:ApplyWindowChrome()
    self:ApplyStatusDropdown()
    self:ApplyActionButtons()
    self:ApplyWhoControls()
    self:ApplyRaidControls()
    self:ApplyQuickJoinControls()
    self:ApplyTabs()
    self:ApplyScrollBar()
    if friendsFrame:IsShown() then self:QueueApply() end
    return true
end

function FriendsListSkin:RefreshAppearance()
    if initialized then
        self:ApplyWindowChrome()
        self:ApplyStatusDropdown()
        self:ApplyActionButtons()
        self:ApplyWhoControls()
        self:ApplyRaidControls()
        self:ApplyQuickJoinControls()
        self:ApplyTabs()
        self:ApplyScrollBar()
    end
end

NSkin:RegisterWindowSkin({
    module = "FriendsList",
    addon = "Blizzard_FriendsFrame",
    apply = function() return FriendsListSkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "FriendsList.Raid",
    module = "FriendsList",
    addon = "Blizzard_RaidFrame",
    apply = function() return FriendsListSkin:ApplyRaidControls() end,
})

NSkin:RegisterWindowSkin({
    key = "FriendsList.QuickJoin",
    module = "FriendsList",
    addon = "Blizzard_QuickJoin",
    apply = function() return FriendsListSkin:ApplyQuickJoinControls() end,
})
