local _, NSkin = ...

local FriendsListSkin = NSkin:NewModule("FriendsList")

local IDs = {
    Scope = "FriendsList",
    ScrollBar = "FriendsList.ScrollBar",
}

local initialized = false
local showHooked = false
local applyPending = false
local hookedScrollBar

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Friends List",
})

local function GetFriendsListScrollBar()
    local list = _G.FriendsListFrame
    return list and list.ScrollBar
end

function FriendsListSkin:ApplyScrollBar()
    local friendsFrame = _G.FriendsFrame
    local scrollBar = GetFriendsListScrollBar()
    if not friendsFrame or not scrollBar then return false end

    NSkin:SkinScrollBar(scrollBar, NSkin:GetAppearanceStyle(
        "scrollBar", IDs.Scope, IDs.ScrollBar))

    NSkin:RegisterSimpleMovableElement({
        id = IDs.ScrollBar,
        module = "FriendsList",
        appearanceWindowID = IDs.Scope,
        label = "Friends list scroll bar",
        kind = "SCROLLBAR",
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
            FriendsListSkin:QueueScrollBarApply()
        end)
        hookedScrollBar = scrollBar
    end
    return true
end

function FriendsListSkin:QueueScrollBarApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        FriendsListSkin:ApplyScrollBar()
    end)
end

function FriendsListSkin:Initialize()
    if initialized then return true end
    local friendsFrame = _G.FriendsFrame
    if not friendsFrame then return false end

    if not showHooked and friendsFrame.HookScript then
        friendsFrame:HookScript("OnShow", function()
            FriendsListSkin:QueueScrollBarApply()
        end)
        showHooked = true
    end

    initialized = true
    self:ApplyScrollBar()
    if friendsFrame:IsShown() then self:QueueScrollBarApply() end
    return true
end

function FriendsListSkin:RefreshAppearance()
    if initialized then self:ApplyScrollBar() end
end

NSkin:RegisterWindowSkin({
    module = "FriendsList",
    addon = "Blizzard_FriendsFrame",
    apply = function() return FriendsListSkin:Initialize() end,
})
