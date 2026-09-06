local _, NSkin = ...

local AuctionHouseSkin = NSkin:NewModule("AuctionHouse")

local IDs = {
    Scope = "AuctionHouse",
    Window = "AuctionHouse.Window",
    HeaderControls = "AuctionHouse.HeaderControls",
    SearchBox = "AuctionHouse.SearchBox",
    FilterDropdown = "AuctionHouse.FilterDropdown",
    SearchButton = "AuctionHouse.SearchButton",
    ItemBuyBackButton = "AuctionHouse.ItemBuyBackButton",
    ItemBuyBidButton = "AuctionHouse.ItemBuyBidButton",
    ItemBuyBuyoutButton = "AuctionHouse.ItemBuyBuyoutButton",
    SellMaxButton = "AuctionHouse.SellMaxButton",
    SellQuantityInput = "AuctionHouse.SellQuantityInput",
    SellBuyoutGoldInput = "AuctionHouse.SellBuyoutGoldInput",
    SellBuyoutSilverInput = "AuctionHouse.SellBuyoutSilverInput",
    SellBuyoutCopperInput = "AuctionHouse.SellBuyoutCopperInput",
    SellPostButton = "AuctionHouse.SellPostButton",
    SellDurationDropdown = "AuctionHouse.SellDurationDropdown",
    SellBuyoutModeCheckbox = "AuctionHouse.SellBuyoutModeCheckbox",
    AuctionsCancelButton = "AuctionHouse.AuctionsCancelButton",
    AuctionsBidButton = "AuctionHouse.AuctionsBidButton",
    AuctionsBuyoutButton = "AuctionHouse.AuctionsBuyoutButton",
    CategoriesScrollBar = "AuctionHouse.CategoriesScrollBar",
    ResultsScrollBar = "AuctionHouse.ResultsScrollBar",
    ItemBuyScrollBar = "AuctionHouse.ItemBuyScrollBar",
    AuctionsListScrollBar = "AuctionHouse.AuctionsListScrollBar",
    AuctionsSummaryScrollBar = "AuctionHouse.AuctionsSummaryScrollBar",
    SellItemsScrollBar = "AuctionHouse.SellItemsScrollBar",
    BottomTabs = "AuctionHouse.BottomTabs",
    AuctionsTopTabs = "AuctionHouse.AuctionsTopTabs",
    CategoryCards = "AuctionHouse.CategoryCards",
}

local initialized = false
local applyPending = false
local lifecycleHooked = false
local tabsRegistered = false
local auctionsTopTabsRegistered = false
local categoryCardsRegistered = false
local categoryInitializerHooked = false
local hookedTabs = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Auction House",
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        AuctionHouseSkin:Apply()
    end)
end

local function GetBottomTabs(frame)
    return {
        frame and frame.BuyTab,
        frame and frame.SellTab,
        frame and frame.AuctionsTab,
    }
end

local function GetCategoryScrollBox(frame)
    local categories = frame and frame.CategoriesList
    return categories and categories.ScrollBox
end

local function GetCategoryArtwork(button)
    if not button then return {} end
    return {
        button.Lines,
        button.NormalTexture,
        button.HighlightTexture,
    }
end

local function GetVisibleCategoryCards(frame)
    local cards = {}
    local scrollBox = GetCategoryScrollBox(frame)
    if scrollBox and scrollBox.ForEachFrame then
        scrollBox:ForEachFrame(function(button)
            if IsVisible(button) then cards[#cards + 1] = button end
        end)
    end
    return cards
end

function AuctionHouseSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Auction House window",
        kind = "WINDOW",
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function AuctionHouseSkin:ApplySearchControls(frame)
    local searchBar = frame and frame.SearchBar
    local searchBox = searchBar and searchBar.SearchBox
    local filterButton = searchBar and searchBar.FilterButton
    local searchButton = searchBar and searchBar.SearchButton
    if not searchBar then return false end

    local applied = NSkin:RegisterSearchBox({
        id = IDs.SearchBox,
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        label = "Auction House search bar",
        window = frame,
        target = searchBox,
        priority = 50,
        highlightRegions = { searchBox },
        isEditable = function()
            return IsVisible(frame) and IsVisible(searchBox)
        end,
    }) ~= nil
    applied = NSkin:RegisterDropdown({
        id = IDs.FilterDropdown,
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        label = "Auction House filters",
        window = frame,
        target = filterButton,
        menus = { "MENU_AUCTION_HOUSE_SEARCH_FILTER" },
        priority = 51,
        highlightRegions = { filterButton },
        isEditable = function()
            return IsVisible(frame) and IsVisible(filterButton)
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterActionButton({
        id = IDs.SearchButton,
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        label = "Auction House search button",
        window = frame,
        target = searchButton,
        priority = 52,
        highlightRegions = { searchButton },
        isEditable = function()
            return IsVisible(frame) and IsVisible(searchButton)
        end,
    }) ~= nil or applied
    return applied
end

local function RegisterItemBuyButton(frame, itemBuyFrame, id, button,
    label, priority)
    return NSkin:RegisterActionButton({
        id = id,
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = button,
        priority = priority,
        highlightRegions = { button },
        isEditable = function()
            return IsVisible(frame) and IsVisible(itemBuyFrame)
                and IsVisible(button)
        end,
    }) ~= nil
end

function AuctionHouseSkin:ApplyItemBuyButtons(frame)
    local itemBuyFrame = frame and frame.ItemBuyFrame
    if not itemBuyFrame then return false end

    local bidButton = itemBuyFrame.BidFrame
        and itemBuyFrame.BidFrame.BidButton
    local buyoutButton = itemBuyFrame.BuyoutFrame
        and itemBuyFrame.BuyoutFrame.BuyoutButton
    local applied = RegisterItemBuyButton(frame, itemBuyFrame,
        IDs.ItemBuyBackButton, itemBuyFrame.BackButton,
        "Auction item back button", 53)
    applied = RegisterItemBuyButton(frame, itemBuyFrame,
        IDs.ItemBuyBidButton, bidButton, "Bid button", 54) or applied
    applied = RegisterItemBuyButton(frame, itemBuyFrame,
        IDs.ItemBuyBuyoutButton, buyoutButton, "Buyout button", 55) or applied
    return applied
end

local function RegisterSellButton(frame, sellFrame, id, button, label,
    priority)
    return NSkin:RegisterActionButton({
        id = id,
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = button,
        priority = priority,
        highlightRegions = { button },
        isEditable = function()
            return IsVisible(frame) and IsVisible(sellFrame)
                and IsVisible(button)
        end,
    }) ~= nil
end

local function RegisterSellEditBox(frame, sellFrame, id, editBox, label,
    priority)
    return NSkin:RegisterEditBox({
        id = id,
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = editBox,
        priority = priority,
        highlightRegions = { editBox },
        isEditable = function()
            return IsVisible(frame) and IsVisible(sellFrame)
                and IsVisible(editBox)
        end,
    }) ~= nil
end

function AuctionHouseSkin:ApplySellControls(frame)
    local sellFrame = frame and frame.ItemSellFrame
    if not sellFrame then return false end

    local maxButton = sellFrame.QuantityInput
        and sellFrame.QuantityInput.MaxButton
    local durationDropdown = sellFrame.Duration
        and sellFrame.Duration.Dropdown
    local buyoutMode = sellFrame.BuyoutModeCheckButton
    local quantityInput = sellFrame.QuantityInput
        and sellFrame.QuantityInput.InputBox
    local moneyInput = sellFrame.PriceInput
        and sellFrame.PriceInput.MoneyInputFrame
    local applied = RegisterSellButton(frame, sellFrame,
        IDs.SellMaxButton, maxButton, "Maximum quantity button", 56)
    applied = RegisterSellEditBox(frame, sellFrame,
        IDs.SellQuantityInput, quantityInput,
        "Auction quantity input", 56.1) or applied
    applied = RegisterSellEditBox(frame, sellFrame,
        IDs.SellBuyoutGoldInput, moneyInput and moneyInput.GoldBox,
        "Buyout price gold input", 56.2) or applied
    applied = RegisterSellEditBox(frame, sellFrame,
        IDs.SellBuyoutSilverInput, moneyInput and moneyInput.SilverBox,
        "Buyout price silver input", 56.3) or applied
    applied = RegisterSellEditBox(frame, sellFrame,
        IDs.SellBuyoutCopperInput, moneyInput and moneyInput.CopperBox,
        "Buyout price copper input", 56.4) or applied
    applied = RegisterSellButton(frame, sellFrame,
        IDs.SellPostButton, sellFrame.PostButton,
        "Create Auction button", 57) or applied
    applied = NSkin:RegisterDropdown({
        id = IDs.SellDurationDropdown,
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        label = "Auction duration dropdown",
        window = frame,
        target = durationDropdown,
        menus = { "MENU_AUCTION_HOUSE_DURATION" },
        priority = 58,
        highlightRegions = { durationDropdown },
        isEditable = function()
            return IsVisible(frame) and IsVisible(sellFrame)
                and IsVisible(durationDropdown)
        end,
    }) ~= nil or applied
    applied = NSkin:RegisterCheckbox({
        id = IDs.SellBuyoutModeCheckbox,
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        label = "Buyout Mode checkbox",
        window = frame,
        target = buyoutMode,
        text = buyoutMode and buyoutMode.Text,
        priority = 59,
        highlightRegions = { buyoutMode },
        isEditable = function()
            return IsVisible(frame) and IsVisible(sellFrame)
                and IsVisible(buyoutMode)
        end,
    }) ~= nil or applied
    return applied
end

local function RegisterAuctionsButton(frame, auctionsFrame, id, button,
    label, priority)
    return NSkin:RegisterActionButton({
        id = id,
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = button,
        priority = priority,
        highlightRegions = { button },
        isEditable = function()
            return IsVisible(frame) and IsVisible(auctionsFrame)
                and IsVisible(button)
        end,
    }) ~= nil
end

function AuctionHouseSkin:ApplyAuctionsButtons(frame)
    local auctionsFrame = frame and frame.AuctionsFrame
    if not auctionsFrame then return false end

    local bidButton = auctionsFrame.BidFrame
        and auctionsFrame.BidFrame.BidButton
    local buyoutButton = auctionsFrame.BuyoutFrame
        and auctionsFrame.BuyoutFrame.BuyoutButton
    local applied = RegisterAuctionsButton(frame, auctionsFrame,
        IDs.AuctionsCancelButton, auctionsFrame.CancelAuctionButton,
        "Cancel auction button", 63)
    applied = RegisterAuctionsButton(frame, auctionsFrame,
        IDs.AuctionsBidButton, bidButton,
        "Auctions bids bid button", 64) or applied
    applied = RegisterAuctionsButton(frame, auctionsFrame,
        IDs.AuctionsBuyoutButton, buyoutButton,
        "Auctions bids buyout button", 65) or applied
    return applied
end

local function RegisterScrollBar(frame, id, label, target, owner, priority)
    return NSkin:RegisterScrollBar({
        id = id,
        module = "AuctionHouse",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = target,
        priority = priority,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(frame) and IsVisible(owner) and IsVisible(target)
        end,
    }) ~= nil
end

function AuctionHouseSkin:ApplyScrollBars(frame)
    local categories = frame and frame.CategoriesList
    local itemList = frame and frame.BrowseResultsFrame
        and frame.BrowseResultsFrame.ItemList
    local itemBuyFrame = frame and frame.ItemBuyFrame
    local itemBuyList = itemBuyFrame and itemBuyFrame.ItemList
    local auctionsFrame = frame and frame.AuctionsFrame
    local auctionsList = auctionsFrame and auctionsFrame.AllAuctionsList
    local auctionsSummary = auctionsFrame and auctionsFrame.SummaryList
    local sellItems = frame and frame.ItemSellList
    if not frame then return false end

    local applied = RegisterScrollBar(frame, IDs.CategoriesScrollBar,
        "Auction House categories scroll bar",
        categories and categories.ScrollBar, categories, 60)
    applied = RegisterScrollBar(frame, IDs.ResultsScrollBar,
        "Auction House results scroll bar",
        itemList and itemList.ScrollBar, itemList, 61) or applied
    applied = RegisterScrollBar(frame, IDs.ItemBuyScrollBar,
        "Auction item listings scroll bar",
        itemBuyList and itemBuyList.ScrollBar, itemBuyFrame, 62) or applied
    applied = RegisterScrollBar(frame, IDs.AuctionsListScrollBar,
        "Owned auctions list scroll bar",
        auctionsList and auctionsList.ScrollBar, auctionsList, 66) or applied
    applied = RegisterScrollBar(frame, IDs.AuctionsSummaryScrollBar,
        "Auctions summary scroll bar",
        auctionsSummary and auctionsSummary.ScrollBar,
        auctionsSummary, 67) or applied
    applied = RegisterScrollBar(frame, IDs.SellItemsScrollBar,
        "Auction sell items scroll bar",
        sellItems and sellItems.ScrollBar, sellItems, 68) or applied
    return applied
end

function AuctionHouseSkin:ApplyBottomTabs(frame)
    if not frame then return false end
    local tabs = GetBottomTabs(frame)
    for index = 1, #tabs do
        if not tabs[index] then return false end
    end

    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Scope, IDs.BottomTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, IDs.BottomTabs)
    local selected = _G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(frame)
    for index = 1, #tabs do
        local tab = tabs[index]
        NSkin:SkinTab(tab, index == selected, style, border)
        if not hookedTabs[tab] and tab.HookScript then
            tab:HookScript("OnClick", QueueApply)
            hookedTabs[tab] = true
        end
    end

    if not tabsRegistered then
        tabsRegistered = NSkin:RegisterTabGroup(IDs.BottomTabs, {
            label = "Auction House bottom tabs",
            kind = "TAB_GROUP",
            module = "AuctionHouse",
            appearanceWindowID = IDs.Scope,
            window = frame,
            tabs = tabs,
            priority = 70,
            orientation = "HORIZONTAL",
            edge = "BOTTOM",
        }) == true
    end
    NSkin:ApplyTabGroupLayout(IDs.BottomTabs)
    return true
end

function AuctionHouseSkin:ApplyAuctionsTopTabs(frame)
    local auctionsFrame = frame and frame.AuctionsFrame
    if not auctionsFrame then return false end
    local tabs = {
        auctionsFrame.AuctionsTab,
        auctionsFrame.BidsTab,
    }
    for index = 1, #tabs do
        if not tabs[index] then return false end
    end

    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Scope, IDs.AuctionsTopTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, IDs.AuctionsTopTabs)
    local selected = _G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(auctionsFrame)
    for index = 1, #tabs do
        local tab = tabs[index]
        NSkin:SkinTab(tab, index == selected, style, border)
        if not hookedTabs[tab] and tab.HookScript then
            tab:HookScript("OnClick", QueueApply)
            hookedTabs[tab] = true
        end
    end

    if not auctionsTopTabsRegistered then
        auctionsTopTabsRegistered = NSkin:RegisterTabGroup(
            IDs.AuctionsTopTabs, {
                label = "Auction House Auctions and Bids tabs",
                kind = "TAB_GROUP",
                module = "AuctionHouse",
                appearanceWindowID = IDs.Scope,
                window = frame,
                tabs = tabs,
                priority = 71,
                orientation = "HORIZONTAL",
                edge = "TOP",
                isEditable = function()
                    return IsVisible(frame) and IsVisible(auctionsFrame)
                end,
            }) == true
    end
    NSkin:ApplyTabGroupLayout(IDs.AuctionsTopTabs)
    return true
end

function AuctionHouseSkin:StyleCategoryCard(button)
    if not button then return false end

    local style = NSkin:GetAppearanceStyle(
        "sectionCard", IDs.Scope, IDs.CategoryCards)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionCard", style, IDs.Scope, IDs.CategoryCards)
    NSkin:SkinSectionCard(button, {
        style = style,
        border = border,
        collapsible = false,
        height = 0,
        preserveTextLayout = true,
        textRegion = button.Text,
        artworkRegions = GetCategoryArtwork(button),
    })
    if categoryCardsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.CategoryCards)
    end
    return true
end

function AuctionHouseSkin:ApplyCategoryCards(frame)
    local categories = frame and frame.CategoriesList
    local scrollBox = GetCategoryScrollBox(frame)
    if not categories or not scrollBox or not scrollBox.ForEachFrame then
        return false
    end

    local applied = false
    scrollBox:ForEachFrame(function(button)
        applied = self:StyleCategoryCard(button) or applied
    end)

    if not categoryCardsRegistered then
        categoryCardsRegistered = NSkin:RegisterSkinningElement(
            IDs.CategoryCards, {
                module = "AuctionHouse",
                appearanceWindowID = IDs.Scope,
                label = "Auction House category cards",
                kind = "SECTION_CARD",
                window = frame,
                target = scrollBox,
                priority = 80,
                draggable = false,
                highlightRegions = function()
                    return GetVisibleCategoryCards(frame)
                end,
                editorOptions = {
                    { id = "shared.sectionCardAppearance",
                        label = "Section cards", category = "CUSTOMIZE" },
                },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(categories)
                        and #GetVisibleCategoryCards(frame) > 0
                end,
            }) == true
    end
    if categoryCardsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.CategoryCards)
    end
    return applied or categoryCardsRegistered
end

function AuctionHouseSkin:HookCategoryInitializer()
    if categoryInitializerHooked or not _G.hooksecurefunc
        or type(_G.AuctionHouseFilterButton_SetUp) ~= "function"
    then
        return categoryInitializerHooked
    end

    _G.hooksecurefunc("AuctionHouseFilterButton_SetUp", function(button)
        AuctionHouseSkin:StyleCategoryCard(button)
    end)
    categoryInitializerHooked = true
    return true
end

function AuctionHouseSkin:Apply()
    local frame = _G.AuctionHouseFrame
    if not frame then return false end

    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplySearchControls(frame) or applied
    applied = self:ApplyItemBuyButtons(frame) or applied
    applied = self:ApplySellControls(frame) or applied
    applied = self:ApplyAuctionsButtons(frame) or applied
    applied = self:ApplyScrollBars(frame) or applied
    applied = self:ApplyBottomTabs(frame) or applied
    applied = self:ApplyAuctionsTopTabs(frame) or applied
    applied = self:ApplyCategoryCards(frame) or applied
    return applied
end

function AuctionHouseSkin:Initialize()
    local frame = _G.AuctionHouseFrame
    if not frame then return false end

    if not lifecycleHooked then
        if frame.HookScript then frame:HookScript("OnShow", QueueApply) end
        if _G.hooksecurefunc and type(frame.SetDisplayMode) == "function" then
            _G.hooksecurefunc(frame, "SetDisplayMode", QueueApply)
        end
        local auctionsFrame = frame.AuctionsFrame
        if _G.hooksecurefunc and auctionsFrame
            and type(auctionsFrame.SetTab) == "function"
        then
            _G.hooksecurefunc(auctionsFrame, "SetTab", QueueApply)
        end
        lifecycleHooked = true
    end

    self:HookCategoryInitializer()
    initialized = true
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function AuctionHouseSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "AuctionHouse",
    addon = "Blizzard_AuctionHouseUI",
    apply = function() return AuctionHouseSkin:Initialize() end,
})
