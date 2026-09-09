local _, NSkin = ...

local AuctionHouseSkin = NSkin:NewModule("AuctionHouse")
local RefreshBlackMarketAppearance

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
    if RefreshBlackMarketAppearance then RefreshBlackMarketAppearance() end
end

NSkin:RegisterWindowSkin({
    module = "AuctionHouse",
    addon = "Blizzard_AuctionHouseUI",
    apply = function() return AuctionHouseSkin:Initialize() end,
})
do
local BlackMarketSkin = {}

local IDs = {
    Scope = "BlackMarket",
    Window = "BlackMarket.Window",
    HeaderControls = "BlackMarket.HeaderControls",
    HotDealIcon = "BlackMarket.HotDeal.Icon",
    HotDealTitle = "BlackMarket.HotDeal.Title",
    HotDealSellerTag = "BlackMarket.HotDeal.SellerTag",
    HotDealSeller = "BlackMarket.HotDeal.Seller",
    HotDealTimeLeft = "BlackMarket.HotDeal.TimeLeft",
    HotDealCurrentBid = "BlackMarket.HotDeal.CurrentBid",
    HotDealGold = "BlackMarket.HotDeal.Gold",
    BidLabel = "BlackMarket.Bid.Label",
    BidGoldInput = "BlackMarket.Bid.GoldInput",
    BidButton = "BlackMarket.Bid.Button",
    PlayerGold = "BlackMarket.PlayerMoney.Gold",
    PlayerSilver = "BlackMarket.PlayerMoney.Silver",
    ScrollBar = "BlackMarket.ScrollBar",
    ResultsTable = "BlackMarket.ResultsTable",
    ColumnPrefix = "BlackMarket.Column.",
}

local initialized = false
local lifecycleHooked = false
local rootArtworkConcealed = false
local hookedScrollBoxes = setmetatable({}, { __mode = "k" })
local resultsTableRegistered = false

NSkin:RegisterAppearanceScope(IDs.Scope, { label = "Black Market" })

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function NormalizeTexturePath(path)
    if type(path) ~= "string" then return nil end
    return path:lower():gsub("\\", "/")
        :gsub("%.blp$", ""):gsub("%.tga$", "")
end

local function IsAuctionItemNameArtwork(region)
    if not region or not region.IsObjectType
        or not region:IsObjectType("Texture")
    then return false end
    local path = region.GetTextureFilePath and region:GetTextureFilePath()
        or (region.GetTexture and region:GetTexture())
    return NormalizeTexturePath(path)
        == "interface/auctionframe/ui-auctionitemnameframe"
end

local function AddUniqueRegion(regions, seen, region)
    if region and not seen[region] then
        seen[region] = true
        regions[#regions + 1] = region
    end
end

local function IsAnchoredBetween(region, left, right)
    if not region or not region.GetNumPoints or not region.GetPoint then
        return false
    end
    local anchoredLeft, anchoredRight = false, false
    for index = 1, region:GetNumPoints() do
        local _, relativeTo, relativePoint = region:GetPoint(index)
        if relativeTo == left and relativePoint == "RIGHT" then
            anchoredLeft = true
        elseif relativeTo == right and relativePoint == "LEFT" then
            anchoredRight = true
        end
    end
    return anchoredLeft and anchoredRight
end

local function GetRowNativeDecorations(row)
    local artwork = {}
    local seen = {}
    if not row or not row.GetRegions then return artwork end
    AddUniqueRegion(artwork, seen, row.Left)
    AddUniqueRegion(artwork, seen, row.Right)
    for _, region in ipairs({ row:GetRegions() }) do
        if IsAuctionItemNameArtwork(region)
            or IsAnchoredBetween(region, row.Left, row.Right)
        then
            AddUniqueRegion(artwork, seen, region)
        end
    end
    return artwork
end

local function GetVisibleRows(frame)
    local rows = {}
    local scrollBox = frame and frame.ScrollBox
    if scrollBox and scrollBox.ForEachFrame then
        scrollBox:ForEachFrame(function(row)
            if IsVisible(row) then rows[#rows + 1] = row end
        end)
    end
    return rows
end

local function GetInsetDecorations(inset)
    local decorations, seen = {}, {}
    if not inset then return decorations end
    for _, key in ipairs({
        "TopLeftCorner", "TopRightCorner", "BotLeftCorner", "BotRightCorner",
        "TopBorder", "BottomBorder", "LeftBorder", "RightBorder",
    }) do
        AddUniqueRegion(decorations, seen, inset[key])
    end
    if inset.GetRegions then
        for _, region in ipairs({ inset:GetRegions() }) do
            local layer = region.GetDrawLayer and region:GetDrawLayer()
            if region.IsObjectType and region:IsObjectType("Texture")
                and layer == "BACKGROUND"
            then
                AddUniqueRegion(decorations, seen, region)
            end
        end
    end
    return decorations
end

local function GetBlackMarketTitle(frame)
    if not frame or not frame.GetRegions then return nil end
    local fallback
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("FontString") then
            fallback = fallback or region
            if region.GetText and region:GetText() == _G.BLACK_MARKET_TITLE then
                return region
            end
        end
    end
    return fallback
end

local function FormatBlackMarketTitle(title)
    if not title or not title.SetText then return end
    local text = _G.BLACK_MARKET_TITLE
        or (title.GetText and title:GetText())
    if type(text) == "string" then
        title:SetText((text:gsub("[\r\n]+", " ")))
    end
end

local function GetMoneyBorderDecorations(borderFrame)
    local decorations = {}
    if not borderFrame or not borderFrame.GetRegions then return decorations end
    for _, region in ipairs({ borderFrame:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then
            decorations[#decorations + 1] = region
        end
    end
    return decorations
end

local function SuppressBlackMarketDecorations(owner, key, regions)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "blackMarketDecorations")
    data[key] = data[key] or { states = {} }
    local group = data[key]
    local declared = {}
    for _, region in ipairs(regions or {}) do
        if region then declared[region] = true end
    end
    for region, state in pairs(group.states) do
        if state.active and not declared[region] then
            state.active = nil
            state.applying = true
            if region.SetAlpha then region:SetAlpha(state.alpha) end
            if state.shown ~= nil and region.SetShown then
                region:SetShown(state.shown)
            end
            state.applying = nil
        end
    end
    for region in pairs(declared) do
        local state = group.states[region]
        if not state then
            state = {
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = region.IsShown and region:IsShown() or nil,
            }
            group.states[region] = state
        end
        state.active = true
        local function Conceal()
            if state.active and not state.applying then
                state.applying = true
                if region.SetAlpha then region:SetAlpha(0) end
                state.applying = nil
            end
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

local function GetItemNativeDecorations(button)
    local decorations = {}
    local normal = button and button.GetNormalTexture
        and button:GetNormalTexture()
    if normal then decorations[#decorations + 1] = normal end
    if button and button.IconBorder then
        decorations[#decorations + 1] = button.IconBorder
    end
    return decorations
end

local function IsItemHovered(button)
    return button and button.IsMouseOver and button:IsMouseOver() or false
end

local function GetMarketItemQuality(button)
    local owner = button and button.GetParent and button:GetParent()
    if not owner or not _G.C_BlackMarket then return nil end
    if owner == (_G.BlackMarketFrame and _G.BlackMarketFrame.HotDeal) then
        return select(17, _G.C_BlackMarket.GetHotItem())
    end
    if owner.marketID then
        return select(17, _G.C_BlackMarket.GetItemInfoByID(owner.marketID))
    end
end

local function FindBidLabel(bidPrice)
    if not bidPrice or not bidPrice.GetRegions then return nil end
    for _, region in ipairs({ bidPrice:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            return region
        end
    end
end

local function RegisterText(frame, id, label, target, priority, options)
    if not target then return nil end
    options = options or {}
    return NSkin:RegisterTextElement({
        id = id, module = "AuctionHouse", appearanceWindowID = IDs.Scope,
        label = label, window = frame, target = target,
        numberFormat = options.numberFormat, suffixIcon = options.suffixIcon,
        priority = priority, draggable = false,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(frame) and IsVisible(target)
        end,
    })
end

function BlackMarketSkin:ApplyWindowChrome(frame)
    if not frame then return false end
    if not rootArtworkConcealed then
        NSkin:HideTextureRegions(frame)
        rootArtworkConcealed = true
    end
    SuppressBlackMarketDecorations(frame.Inset, "Inset",
        GetInsetDecorations(frame.Inset))
    local shadows = frame.ScrollBox and frame.ScrollBox.Shadows
    SuppressBlackMarketDecorations(shadows, "ScrollShadows", {
        shadows and shadows.Upper,
        shadows and shadows.Lower,
    })
    local title = GetBlackMarketTitle(frame)
    FormatBlackMarketTitle(title)
    NSkin:SkinStandardWindowChrome({
        frame = frame, appearanceWindowID = IDs.Scope,
        elementID = IDs.Window, headerControlsID = IDs.HeaderControls,
        title = title,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Black Market window", kind = "WINDOW",
        module = "AuctionHouse", appearanceWindowID = IDs.Scope,
        window = frame, target = frame, priority = 0, draggable = false,
    })
    return true
end

function BlackMarketSkin:ApplyColumns(frame)
    local applied = false
    for index, definition in ipairs({
        { "Name", frame.ColumnName }, { "Level", frame.ColumnLevel },
        { "Type", frame.ColumnType }, { "Duration", frame.ColumnDuration },
        { "HighBidder", frame.ColumnHighBidder },
        { "CurrentBid", frame.ColumnCurrentBid },
    }) do
        local key, header = unpack(definition)
        if header then
            applied = NSkin:RegisterColumnHeader({
                id = IDs.ColumnPrefix .. key, module = "AuctionHouse",
                appearanceWindowID = IDs.Scope,
                label = "Black Market " .. key .. " column",
                window = frame, target = header, textRegion = header.Name,
                artworkRegions = { header.Left, header.Middle, header.Right },
                priority = 20 + index, draggable = false,
                highlightRegions = { header },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(header)
                end,
            }) ~= nil or applied
        end
    end
    return applied
end

function BlackMarketSkin:ApplyItemIcon(frame, id, label, button, priority)
    local texture = button and button.IconTexture
    if not texture then return nil end
    local existing = NSkin:GetSkinningElement(id)
    local element = NSkin:RegisterIcon({
        id = id, module = "AuctionHouse", appearanceWindowID = IDs.Scope,
        label = label, window = frame, target = button, texture = texture,
        qualityProvider = GetMarketItemQuality,
        nativeDecorationRegions = GetItemNativeDecorations(button),
        hoverRegion = button.GetHighlightTexture
            and button:GetHighlightTexture(),
        getHovered = IsItemHovered, priority = priority, draggable = false,
        editorOptions = {
            { id = "shared.iconAppearance", label = "Icon",
                presentation = "INLINE", category = "CUSTOMIZE" },
        },
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    })
    if element and existing then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

function BlackMarketSkin:ApplyHotDeal(frame)
    local hotDeal = frame and frame.HotDeal
    if not hotDeal then return false end
    SuppressBlackMarketDecorations(hotDeal, "HotDeal",
        GetRowNativeDecorations(hotDeal))
    local applied = RegisterText(frame, IDs.HotDealTitle,
        "Hot deal title", hotDeal.Title, 39) ~= nil
    applied = self:ApplyItemIcon(frame, IDs.HotDealIcon,
        "Hot deal item icon", hotDeal.Item, 40) ~= nil
        or applied
    applied = RegisterText(frame, IDs.HotDealSellerTag,
        "Hot deal seller label", hotDeal.SellerTAG, 41) ~= nil or applied
    applied = RegisterText(frame, IDs.HotDealSeller,
        "Hot deal seller", hotDeal.Seller, 42) ~= nil or applied
    applied = RegisterText(frame, IDs.HotDealTimeLeft,
        "Hot deal time left", hotDeal.TimeLeft and hotDeal.TimeLeft.Text,
        43) ~= nil or applied
    local money = hotDeal.BlackMarketHotItemBidPrice
        or _G.HotItemCurrentBidMoneyFrame
    applied = RegisterText(frame, IDs.HotDealCurrentBid,
        "Hot deal current bid label", money and money.CurrentBid,
        44) ~= nil or applied
    applied = RegisterText(frame, IDs.HotDealGold,
        "Hot deal current bid gold",
        _G.HotItemCurrentBidMoneyFrameGoldButtonText
            or (money and money.GoldButton and money.GoldButton.Text),
        45, { numberFormat = "GOLD" }) ~= nil or applied
    return applied
end

local function SkinResultText(target, style, options)
    if not target then return false end
    return NSkin:SkinText(target, style, options) == true
end

function BlackMarketSkin:ApplyRow(frame, row, styles)
    if not row then return false end
    local applied = NSkin:SkinRow(row, {
        style = styles.row,
        border = styles.rowBorder,
        nativeDecorationRegions = GetRowNativeDecorations(row),
        hoverRegion = row.GetHighlightTexture and row:GetHighlightTexture(),
        selectedRegion = row.Selection,
    }) ~= nil
    local item = row.Item
    if item and item.IconTexture then
        applied = NSkin:SkinIcon(item, {
            style = styles.icon,
            borderColor = styles.iconBorder,
            texture = item.IconTexture,
            qualityProvider = GetMarketItemQuality,
            nativeDecorationRegions = GetItemNativeDecorations(item),
            hoverRegion = item.GetHighlightTexture
                and item:GetHighlightTexture(),
            getHovered = IsItemHovered,
        }) == true or applied
    end
    for _, target in ipairs({
        row.Name, row.Level, row.Type,
        row.TimeLeft and row.TimeLeft.Text,
        row.Seller, row.YourBid,
        item and item.Count, item and item.Stock,
    }) do
        applied = SkinResultText(target, styles.text) or applied
    end
    local currentBid = row.CurrentBid
    for _, definition in ipairs({
        { currentBid and currentBid.GoldButton
            and currentBid.GoldButton.Text, { numberFormat = "GOLD" } },
        { currentBid and currentBid.SilverButton
            and currentBid.SilverButton.Text },
        { currentBid and currentBid.CopperButton
            and currentBid.CopperButton.Text },
    }) do
        applied = SkinResultText(
            definition[1], styles.text, definition[2]) or applied
    end
    return applied
end

function BlackMarketSkin:ApplyRows(frame)
    local scrollBox = frame and frame.ScrollBox
    if not scrollBox or not scrollBox.ForEachFrame then return false end
    local styles = {
        row = NSkin:GetAppearanceStyle("row", IDs.Scope, IDs.ResultsTable),
        text = NSkin:GetAppearanceStyle("text", IDs.Scope, IDs.ResultsTable),
        icon = NSkin:GetAppearanceStyle("icon", IDs.Scope, IDs.ResultsTable),
    }
    styles.rowBorder = NSkin:GetAppearanceBorderColor(
        "row", styles.row, IDs.Scope, IDs.ResultsTable)
    styles.iconBorder = NSkin:GetAppearanceBorderColor(
        "icon", styles.icon, IDs.Scope, IDs.ResultsTable)
    local applied = false
    scrollBox:ForEachFrame(function(row)
        applied = self:ApplyRow(frame, row, styles) or applied
    end)
    if not hookedScrollBoxes[scrollBox] and _G.hooksecurefunc
        and type(scrollBox.Update) == "function"
    then
        _G.hooksecurefunc(scrollBox, "Update", function()
            BlackMarketSkin:ApplyRows(frame)
        end)
        hookedScrollBoxes[scrollBox] = true
    end
    if not resultsTableRegistered then
        local function RefreshResultsTable()
            return BlackMarketSkin:ApplyRows(frame)
        end
        resultsTableRegistered = NSkin:RegisterSkinningElement(
            IDs.ResultsTable, {
                module = "AuctionHouse",
                appearanceWindowID = IDs.Scope,
                label = "Black Market results table",
                kind = "ROW",
                window = frame,
                target = scrollBox,
                priority = 60,
                draggable = false,
                appearanceStyles = { "text", "icon" },
                appearanceTypeIDs = { "TEXT", "ICON" },
                highlightRegions = function()
                    return GetVisibleRows(frame)
                end,
                pixelBorderTargets = function()
                    local targets = {}
                    for _, row in ipairs(GetVisibleRows(frame)) do
                        targets[#targets + 1] = row
                        if row.Item then targets[#targets + 1] = row.Item end
                    end
                    return targets
                end,
                editorOptions = {
                    { id = "shared.rowAppearance", label = "Rows",
                        category = "CUSTOMIZE" },
                    { id = "shared.textAppearance", label = "Row text",
                        category = "CUSTOMIZE" },
                    { id = "shared.iconAppearance", label = "Row icons",
                        category = "CUSTOMIZE" },
                },
                refreshAppearance = RefreshResultsTable,
                refreshLayout = RefreshResultsTable,
                isEditable = function()
                    return IsVisible(frame) and #GetVisibleRows(frame) > 0
                end,
            }) == true
    end
    if resultsTableRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.ResultsTable)
    end
    return applied or resultsTableRegistered
end

function BlackMarketSkin:ApplyFooter(frame)
    local bidPrice = _G.BlackMarketBidPrice
    local bidGold = _G.BlackMarketBidPriceGold
        or (bidPrice and bidPrice.gold)
    local money = _G.BlackMarketMoneyFrame
    if frame.MoneyFrameBorder then
        SuppressBlackMarketDecorations(frame.MoneyFrameBorder, "MoneyBorder",
            GetMoneyBorderDecorations(frame.MoneyFrameBorder))
    end
    local applied = NSkin:RegisterActionButton({
        id = IDs.BidButton, module = "AuctionHouse",
        appearanceWindowID = IDs.Scope, label = "Black Market bid button",
        window = frame, target = frame.BidButton, priority = 80,
        highlightRegions = { frame.BidButton },
        isEditable = function()
            return IsVisible(frame) and IsVisible(frame.BidButton)
        end,
    }) ~= nil
    if bidGold then
        applied = NSkin:RegisterEditBox({
            id = IDs.BidGoldInput, module = "AuctionHouse",
            appearanceWindowID = IDs.Scope,
            label = "Black Market bid gold input", window = frame,
            target = bidGold,
            skinOptions = { preserveTexture = bidGold.texture },
            priority = 81, highlightRegions = { bidGold },
            isEditable = function()
                return IsVisible(frame) and IsVisible(bidGold)
            end,
        }) ~= nil or applied
    end
    applied = RegisterText(frame, IDs.BidLabel,
        "Black Market bid label", FindBidLabel(bidPrice), 82) ~= nil or applied

    -- SmallMoneyFrameTemplate owns this inline chain. Registering only its
    -- FontStrings preserves the sibling anchors and prevents per-child drift.
    applied = RegisterText(frame, IDs.PlayerGold,
        "Player money gold", _G.BlackMarketMoneyFrameGoldButtonText
            or (money and money.GoldButton and money.GoldButton.Text),
        83, { numberFormat = "GOLD" }) ~= nil or applied
    applied = RegisterText(frame, IDs.PlayerSilver,
        "Player money silver", _G.BlackMarketMoneyFrameSilverButtonText
            or (money and money.SilverButton and money.SilverButton.Text),
        84) ~= nil or applied
    applied = NSkin:RegisterScrollBar({
        id = IDs.ScrollBar, module = "AuctionHouse",
        appearanceWindowID = IDs.Scope, label = "Black Market scroll bar",
        window = frame, target = frame.ScrollBar, priority = 85,
        highlightRegions = { frame.ScrollBar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(frame.ScrollBar)
        end,
    }) ~= nil or applied
    return applied
end

function BlackMarketSkin:Apply()
    local frame = _G.BlackMarketFrame
    if not frame then return false end
    self:ApplyWindowChrome(frame)
    self:ApplyColumns(frame)
    self:ApplyHotDeal(frame)
    self:ApplyRows(frame)
    self:ApplyFooter(frame)
    return true
end

function BlackMarketSkin:Initialize()
    local frame = _G.BlackMarketFrame
    if not frame then return false end
    if not lifecycleHooked and frame.HookScript then
        frame:HookScript("OnShow", function() BlackMarketSkin:Apply() end)
        frame:HookScript("OnEvent", function(_, event)
            if event == "BLACK_MARKET_ITEM_UPDATE" then
                BlackMarketSkin:ApplyHotDeal(frame)
            end
        end)
        lifecycleHooked = true
    end
    initialized = true
    return self:Apply()
end

RefreshBlackMarketAppearance = function()
    if initialized then BlackMarketSkin:Apply() end
end

NSkin:RegisterWindowSkin({
    key = "AuctionHouse.BlackMarket",
    module = "AuctionHouse",
    addon = "Blizzard_BlackMarketUI",
    apply = function() return BlackMarketSkin:Initialize() end,
})
end
