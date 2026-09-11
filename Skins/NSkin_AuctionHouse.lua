local _, NSkin = ...

local AuctionHouseSkin = NSkin:NewModule("AuctionHouse")
local RefreshBlackMarketAppearance
local RefreshCustomerOrdersAppearance

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
    NSkin:ForEachScrollBoxFrame(scrollBox, function(button)
        if IsVisible(button) then cards[#cards + 1] = button end
    end)
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
    if not NSkin:ForEachScrollBoxFrame(scrollBox, function(button)
        applied = self:StyleCategoryCard(button) or applied
    end) then return false end

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
    if RefreshCustomerOrdersAppearance then RefreshCustomerOrdersAppearance() end
    if RefreshBlackMarketAppearance then RefreshBlackMarketAppearance() end
end

NSkin:RegisterWindowSkin({
    module = "AuctionHouse",
    addon = "Blizzard_AuctionHouseUI",
    apply = function() return AuctionHouseSkin:Initialize() end,
})
do
local CustomerOrdersSkin = {}

local CustomerOrdersIDs = {
    Window = "AuctionHouse.CustomerOrders.Window",
    HeaderControls = "AuctionHouse.CustomerOrders.HeaderControls",
    Tabs = "AuctionHouse.CustomerOrders.Tabs",
    FavoriteButton = "AuctionHouse.CustomerOrders.Browse.FavoriteButton",
    SearchBox = "AuctionHouse.CustomerOrders.Browse.SearchBox",
    FilterDropdown = "AuctionHouse.CustomerOrders.Browse.FilterDropdown",
    SearchButton = "AuctionHouse.CustomerOrders.Browse.SearchButton",
    RecraftCard = "AuctionHouse.CustomerOrders.Browse.RecraftCard",
    PrimaryCards = "AuctionHouse.CustomerOrders.Browse.PrimaryCards",
    SecondaryCards = "AuctionHouse.CustomerOrders.Browse.SecondaryCards",
    SecondaryRows = "AuctionHouse.CustomerOrders.Browse.SecondaryRows",
    TertiaryRows = "AuctionHouse.CustomerOrders.Browse.TertiaryRows",
    CategoryScrollBar = "AuctionHouse.CustomerOrders.Browse.CategoryScrollBar",
    RecipeScrollBar = "AuctionHouse.CustomerOrders.Browse.RecipeScrollBar",
    RecipeRows = "AuctionHouse.CustomerOrders.Browse.RecipeRows",
    ColumnHeaders = "AuctionHouse.CustomerOrders.Browse.ColumnHeaders",
    FormRequiredReagents = "AuctionHouse.CustomerOrders.Form.RequiredReagents",
    FormOptionalReagents = "AuctionHouse.CustomerOrders.Form.OptionalReagents",
    FormBackButton = "AuctionHouse.CustomerOrders.Form.BackButton",
    FormListOrderButton = "AuctionHouse.CustomerOrders.Form.ListOrderButton",
    FormViewListingsButton = "AuctionHouse.CustomerOrders.Form.ViewListingsButton",
    FormRecipientDropdown = "AuctionHouse.CustomerOrders.Form.RecipientDropdown",
    FormDurationDropdown = "AuctionHouse.CustomerOrders.Form.DurationDropdown",
    FormTipGoldInput = "AuctionHouse.CustomerOrders.Form.TipGoldInput",
    FormTipSilverInput = "AuctionHouse.CustomerOrders.Form.TipSilverInput",
    FormNoteInput = "AuctionHouse.CustomerOrders.Form.NoteInput",
    FormAllocateBestQuality = "AuctionHouse.CustomerOrders.Form.AllocateBestQuality",
    FormTrackRecipe = "AuctionHouse.CustomerOrders.Form.TrackRecipe",
    FormPostingFeeGold = "AuctionHouse.CustomerOrders.Form.PostingFeeGold",
    FormPostingFeeSilver = "AuctionHouse.CustomerOrders.Form.PostingFeeSilver",
    FormTotalPriceGold = "AuctionHouse.CustomerOrders.Form.TotalPriceGold",
    FormTotalPriceSilver = "AuctionHouse.CustomerOrders.Form.TotalPriceSilver",
    FormPlayerMoneyGold = "AuctionHouse.CustomerOrders.Form.PlayerMoneyGold",
    FormPlayerMoneySilver = "AuctionHouse.CustomerOrders.Form.PlayerMoneySilver",
    FormPlayerMoneyCopper = "AuctionHouse.CustomerOrders.Form.PlayerMoneyCopper",
}

local CATEGORY_RECRAFT = "RECRAFT"
local CATEGORY_PRIMARY = "PRIMARY"
local CATEGORY_SECONDARY = "SECONDARY"
local CATEGORY_SECONDARY_CARD = "SECONDARY_CARD"
local CATEGORY_SECONDARY_ROW = "SECONDARY_ROW"
local CATEGORY_TERTIARY = "TERTIARY"
local CATEGORY_SPACER = "SPACER"

local customerOrdersInitialized = false
local customerOrdersLifecycleHooked = false
local customerOrdersTabsHooked = setmetatable({}, { __mode = "k" })
local customerOrdersElements = {}

local function GetCustomerOrdersFrame()
    local frame = _G.ProfessionsCustomerOrdersFrame
    return frame, frame and frame.BrowseOrders
end

local function RefreshTypedElement(element)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element
end

local function IsHovered(target)
    return target and target.IsMouseOver and target:IsMouseOver() or false
end

local function GetCategoryScrollBox(browse)
    local categoryList = browse and browse.CategoryList
    return categoryList and categoryList.ScrollBox
end

local function GetRecipeScrollBox(browse)
    local recipeList = browse and browse.RecipeList
    return recipeList and recipeList.ScrollBox
end

local function GetCategoryRuntimeData(button)
    if not button then return nil end
    local data = button.GetElementData and button:GetElementData()
    if data and type(data.GetData) == "function" then data = data:GetData() end
    return data
end

local function NormalizeCategoryType(value)
    local categoryTypes = _G.Enum
        and _G.Enum.CraftingOrderCustomerCategoryType
    if categoryTypes then
        if value == categoryTypes.Primary then return CATEGORY_PRIMARY end
        if value == categoryTypes.Secondary then return CATEGORY_SECONDARY end
        if value == categoryTypes.Tertiary then return CATEGORY_TERTIARY end
    end
    if type(value) == "string" then
        local normalized = value:upper():gsub("[^A-Z]", "")
        if normalized:find("TERTIARY", 1, true) then return CATEGORY_TERTIARY end
        if normalized:find("SECONDARY", 1, true) then return CATEGORY_SECONDARY end
        if normalized:find("PRIMARY", 1, true) then return CATEGORY_PRIMARY end
    elseif value == 0 then
        return CATEGORY_PRIMARY
    elseif value == 1 then
        return CATEGORY_SECONDARY
    elseif value == 2 then
        return CATEGORY_TERTIARY
    end
end

local function CategoryNodeHasChildren(button)
    local node = button and button.GetElementData
        and button:GetElementData()
    return node and type(node.GetSize) == "function"
 and node:GetSize() > 0 or false
end

local function GetCategoryClass(button)
    local data = GetCategoryRuntimeData(button)
    if (button and button.isSpacer) or (data and data.isSpacer) then
        return CATEGORY_SPACER
    end
    if (button and button.isRecraftCategory)
        or (data and data.isRecraftCategory)
    then
        return CATEGORY_RECRAFT
    end
    local categoryInfo = button and button.categoryInfo
        or data and data.categoryInfo
    local categoryClass = NormalizeCategoryType(
        categoryInfo and categoryInfo.type)
    if categoryClass == CATEGORY_SECONDARY then
        return CategoryNodeHasChildren(button)
            and CATEGORY_SECONDARY_CARD or CATEGORY_SECONDARY_ROW
    end
    return categoryClass
end

local function GetCategoryText(button)
    return button and (button.Text or button.Label or button.Name)
end

local function GetCategoryNormalTexture(button)
    if not button then return nil end
    return button.NormalTexture
        or (button.GetNormalTexture and button:GetNormalTexture())
end

local function GetCategoryHighlightTexture(button)
    if not button then return nil end
    return button.HighlightTexture
        or (button.GetHighlightTexture and button:GetHighlightTexture())
end

local function GetCategorySelectedTexture(button)
    if not button then return nil end
    return button.SelectedTexture or button.Selection
end

local function GetCategoryButtons(browse, categoryClass, visibleOnly)
    local buttons = {}
    NSkin:ForEachScrollBoxFrame(GetCategoryScrollBox(browse), function(button)
        if GetCategoryClass(button) == categoryClass
            and (not visibleOnly or IsVisible(button))
        then
            buttons[#buttons + 1] = button
        end
    end)
    return buttons
end

local function GetVisibleRecipeRows(browse)
    local rows = {}
    NSkin:ForEachScrollBoxFrame(GetRecipeScrollBox(browse), function(row)
        if IsVisible(row) then rows[#rows + 1] = row end
    end)
    return rows
end

local function IsRecipeRowHovered(row)
    return row and row.isMouseFocus == true
end

local function AddCustomerOrderRegion(regions, seen, region)
    if region and not seen[region] then
        seen[region] = true
        regions[#regions + 1] = region
    end
end

local function GetFormReagentSlots(form, container, visibleOnly)
    local slots = {}
    local pool = form and form.reagentSlotPool
    if not pool or type(pool.EnumerateActive) ~= "function" then return slots end
    for slot in pool:EnumerateActive() do
        local parent = slot.GetParent and slot:GetParent()
        if parent == container and (not visibleOnly or IsVisible(slot)) then
            slots[#slots + 1] = slot
        end
    end
    return slots
end

local function GetFormReagentTexture(button)
    return button and (button.Icon or button.icon or button.IconTexture)
end

local function GetFormReagentQuality(button)
    local slot = button and button.GetParent and button:GetParent()
    local reagent
    if button and type(button.GetReagent) == "function" then
        reagent = button:GetReagent()
    elseif slot and type(slot.GetReagent) == "function" then
        reagent = slot:GetReagent()
    end
    if reagent and reagent.itemID and _G.C_Item
        and type(_G.C_Item.GetItemQualityByID) == "function"
    then
        return _G.C_Item.GetItemQualityByID(reagent.itemID)
    end
    if reagent and reagent.currencyID and _G.C_CurrencyInfo
        and type(_G.C_CurrencyInfo.GetCurrencyInfo) == "function"
    then
        local info = _G.C_CurrencyInfo.GetCurrencyInfo(reagent.currencyID)
        return info and info.quality
    end
end

local function GetFormReagentDecorations(button)
    local regions, seen = {}, {}
    AddCustomerOrderRegion(regions, seen, button and button.IconBorder)
    AddCustomerOrderRegion(regions, seen, button and button.SlotBackground)
    return regions
end

local function GetFormReagentDescriptors(form, container)
    local descriptors = {}
    for _, slot in ipairs(GetFormReagentSlots(form, container, false)) do
        local button = slot.Button
        if button then
            descriptors[#descriptors + 1] = {
                target = button,
                textureProvider = GetFormReagentTexture,
                borderOwner = button,
                qualityProvider = GetFormReagentQuality,
                nativeDecorationRegions = function(currentButton)
                    return GetFormReagentDecorations(currentButton)
                end,
                hoverRegion = button.HighlightTexture,
                getHovered = IsHovered,
            }
        end
    end
    return descriptors
end

local function GetVisibleFormReagentRegions(form, container, label)
    local regions = GetFormReagentSlots(form, container, true)
    if IsVisible(label) then regions[#regions + 1] = label end
    return regions
end

local function GetVisibleFormReagentButtons(form, container)
    local buttons = {}
    for _, slot in ipairs(GetFormReagentSlots(form, container, true)) do
        if slot.Button then buttons[#buttons + 1] = slot.Button end
    end
    return buttons
end

local function SkinFormReagentText(form, container, id, label)
    local appearanceID = NSkin:GetElementAppearanceID(id, "TEXT")
    local style = NSkin:GetAppearanceStyle("text", IDs.Scope, appearanceID)
    local applied = false
    for _, slot in ipairs(GetFormReagentSlots(form, container, false)) do
        if slot.Name then
            applied = NSkin:SkinText(slot.Name, style) == true or applied
        end
    end
    if label then
        applied = NSkin:SkinText(label, style) == true or applied
    end
    return applied
end

local function IsCustomerOrderFormElementVisible(frame, form, target)
    return IsVisible(frame) and IsVisible(form) and IsVisible(target)
end

local function SuppressCustomerOrderDecorations(owner, key, regions)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "customerOrderDecorations")
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

local function GetGeneratedHeaders(browse, visibleOnly)
    local headers = {}
    local builder = browse and browse.tableBuilder
    if not builder or type(builder.EnumerateHeaders) ~= "function" then
        return headers
    end
    for header in builder:EnumerateHeaders() do
        if not visibleOnly or IsVisible(header) then
            headers[#headers + 1] = header
        end
    end
    return headers
end

function CustomerOrdersSkin:ApplyWindowChrome(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame, appearanceWindowID = IDs.Scope,
        elementID = CustomerOrdersIDs.Window,
        headerControlsID = CustomerOrdersIDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(CustomerOrdersIDs.Window, {
        label = "Customer Orders window", kind = "WINDOW",
        module = "AuctionHouse", appearanceWindowID = IDs.Scope,
        window = frame, target = frame, priority = 0, draggable = false,
    })
    return true
end

function CustomerOrdersSkin:ApplyTabs(frame)
    local tabs = { frame.BrowseTab, frame.OrdersTab }
    if not tabs[1] or not tabs[2] then return false end
    local selected = _G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(frame)
    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Scope, CustomerOrdersIDs.Tabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, CustomerOrdersIDs.Tabs)
    for index, tab in ipairs(tabs) do
        NSkin:SkinTab(tab, selected == index, style, border)
        if not customerOrdersTabsHooked[tab] and tab.HookScript then
            tab:HookScript("OnClick", function()
                CustomerOrdersSkin:ApplyTabs(frame)
            end)
            customerOrdersTabsHooked[tab] = true
        end
    end
    local registered = NSkin:RegisterTabGroup(CustomerOrdersIDs.Tabs, {
        label = "Customer Orders bottom tabs", kind = "TAB_GROUP",
        module = "AuctionHouse", appearanceWindowID = IDs.Scope,
        window = frame, owner = frame, tabs = tabs, priority = 10,
        orientation = "HORIZONTAL", edge = "BOTTOM",
        getSelected = function(tab)
            local current = _G.PanelTemplates_GetSelectedTab
                and _G.PanelTemplates_GetSelectedTab(frame)
            return current == 1 and tab == frame.BrowseTab
                or current == 2 and tab == frame.OrdersTab
        end,
        isEditable = function() return IsVisible(frame) end,
    })
    if registered then NSkin:ApplyTabGroupLayout(CustomerOrdersIDs.Tabs) end
    return registered == true
end

function CustomerOrdersSkin:ApplySearchControls(frame, browse)
    local searchBar = browse and browse.SearchBar
    if not searchBar then return false end
    local favorite = searchBar.FavoritesSearchButton
    local searchBox = searchBar.SearchBox
    local dropdown = searchBar.FilterDropdown
    local searchButton = searchBar.SearchButton
    local applied = false

    if favorite then
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = CustomerOrdersIDs.FavoriteButton,
            module = "AuctionHouse", appearanceWindowID = IDs.Scope,
            label = "Favorite searches button", window = frame,
            target = favorite, preserveTexture = favorite.Icon, priority = 20,
            isEditable = function()
                return IsVisible(frame) and IsVisible(browse)
                    and IsVisible(favorite)
            end,
        })
        applied = RefreshTypedElement(element) ~= nil or applied
    end
    if searchBox then
        local element = NSkin:RegisterSearchBox({
            id = CustomerOrdersIDs.SearchBox,
            module = "AuctionHouse", appearanceWindowID = IDs.Scope,
            label = "Customer order search box", window = frame,
            target = searchBox, priority = 21,
            isEditable = function()
                return IsVisible(frame) and IsVisible(browse)
                    and IsVisible(searchBox)
            end,
        })
        applied = RefreshTypedElement(element) ~= nil or applied
    end
    if dropdown then
        local element = NSkin:RegisterDropdown({
            id = CustomerOrdersIDs.FilterDropdown,
            module = "AuctionHouse", appearanceWindowID = IDs.Scope,
            label = "Customer order filters", window = frame,
            target = dropdown,
            menus = { "MENU_PROFESSIONS_CUSTOMER_ORDER_BROWSE" },
            priority = 22,
            isEditable = function()
                return IsVisible(frame) and IsVisible(browse)
                    and IsVisible(dropdown)
            end,
        })
        applied = RefreshTypedElement(element) ~= nil or applied
    end
    if searchButton then
        local element = NSkin:RegisterActionButton({
            id = CustomerOrdersIDs.SearchButton,
            module = "AuctionHouse", appearanceWindowID = IDs.Scope,
            label = "Customer order search button", window = frame,
            target = searchButton, priority = 23,
            isEditable = function()
                return IsVisible(frame) and IsVisible(browse)
                    and IsVisible(searchButton)
            end,
        })
        applied = RefreshTypedElement(element) ~= nil or applied
    end
    return applied
end

local CategoryDefinitions = {
    {
        class = CATEGORY_RECRAFT, id = CustomerOrdersIDs.RecraftCard,
        label = "Start Recrafting Order", kind = "SECTION_CARD",
    },
    {
        class = CATEGORY_PRIMARY, id = CustomerOrdersIDs.PrimaryCards,
        label = "Primary category cards", kind = "SECTION_CARD",
    },
    {
        class = CATEGORY_SECONDARY_CARD, id = CustomerOrdersIDs.SecondaryCards,
        label = "Secondary category cards", kind = "SECTION_CARD",
    },
    {
        class = CATEGORY_SECONDARY_ROW, id = CustomerOrdersIDs.SecondaryRows,
        label = "Secondary category rows", kind = "SECTION_ROW",
    },
    {
        class = CATEGORY_TERTIARY, id = CustomerOrdersIDs.TertiaryRows,
        label = "Tertiary category rows", kind = "SECTION_ROW",
    },
}

local function ResetMismatchedCategorySkin(button, kind)
    if kind == "SECTION_CARD" then
        NSkin:SkinSectionRow(button, { reset = true })
    else
        NSkin:SkinSectionCard(button, { reset = true })
    end
end

local function ResetCategorySkin(button)
    NSkin:SkinSectionCard(button, { reset = true })
    NSkin:SkinSectionRow(button, { reset = true })
end

local function ApplyCategoryButton(button, definition)
    if not button or GetCategoryClass(button) ~= definition.class then
        return false
    end
    ResetMismatchedCategorySkin(button, definition.kind)
    local normal = GetCategoryNormalTexture(button)
    local hover = GetCategoryHighlightTexture(button)
    local selected = GetCategorySelectedTexture(button)
    local text = GetCategoryText(button)
    local styleName = definition.kind == "SECTION_CARD"
        and "sectionCard" or "sectionRow"
    local style = NSkin:GetAppearanceStyle(
        styleName, IDs.Scope, definition.id)
    local border = NSkin:GetAppearanceBorderColor(
        styleName, style, IDs.Scope, definition.id)
    if definition.kind == "SECTION_CARD" then
        return NSkin:SkinSectionCard(button, {
            style = style, border = border, height = 0,
            preserveTextLayout = true, textRegion = text,
            nativeDecorationRegions = { normal, selected },
            hoverRegion = hover,
            getHovered = IsHovered,
        }) ~= nil
    end
    return NSkin:SkinSectionRow(button, {
        style = style, border = border, height = 0,
        textRegion = text, contentRegions = { text },
        contentStyle = NSkin:GetAppearanceStyle(
            "text", IDs.Scope, definition.id),
        nativeDecorationRegions = { normal }, hoverRegion = hover,
        selectedRegion = selected,
        getHovered = IsHovered,
    }) ~= nil
end

function CustomerOrdersSkin:ApplyCategoryTargets(frame, browse)
    local scrollBox = GetCategoryScrollBox(browse)
    if not scrollBox then return false end
    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(button)
        local class = GetCategoryClass(button)
        local matched = false
        for _, definition in ipairs(CategoryDefinitions) do
            if definition.class == class then
                matched = ApplyCategoryButton(button, definition)
                break
            end
        end
        if not matched and (class == CATEGORY_SPACER or class == nil) then
            ResetCategorySkin(button)
        end
        applied = matched or applied
    end)

    for index, definition in ipairs(CategoryDefinitions) do
        local categoryDefinition = definition
        local function Refresh()
            for _, button in ipairs(GetCategoryButtons(
                browse, categoryDefinition.class, false))
            do
                ApplyCategoryButton(button, categoryDefinition)
            end
            return true
        end
        if not customerOrdersElements[categoryDefinition.id] then
            customerOrdersElements[categoryDefinition.id] =
                NSkin:RegisterSkinningElement(categoryDefinition.id, {
                    module = "AuctionHouse", appearanceWindowID = IDs.Scope,
                    label = categoryDefinition.label,
                    kind = categoryDefinition.kind,
                    window = frame, target = scrollBox,
                    priority = 30 + index, draggable = false,
                    appearanceStyles = categoryDefinition.kind == "SECTION_ROW"
                        and { "text" } or nil,
                    appearanceTypeIDs = categoryDefinition.kind == "SECTION_ROW"
                        and { "TEXT" } or nil,
                    highlightRegions = function()
                        return GetCategoryButtons(
                            browse, categoryDefinition.class, true)
                    end,
                    pixelBorderTargets = function()
                        return GetCategoryButtons(
                            browse, categoryDefinition.class, true)
                    end,
                    refreshAppearance = Refresh,
                    refreshLayout = Refresh,
                    isEditable = function()
                        return IsVisible(frame) and IsVisible(browse)
                            and #GetCategoryButtons(
                                browse, categoryDefinition.class, true) > 0
                    end,
                }) == true
        end
        Refresh()
        if customerOrdersElements[categoryDefinition.id] then
            NSkin:NotifySkinningElementBoundsChanged(categoryDefinition.id)
        end
    end
    return applied
end

function CustomerOrdersSkin:ApplyRecipeRows(frame, browse)
    local scrollBox = GetRecipeScrollBox(browse)
    if not scrollBox then return false end
    local style = NSkin:GetAppearanceStyle(
        "row", IDs.Scope, CustomerOrdersIDs.RecipeRows)
    local border = NSkin:GetAppearanceBorderColor(
        "row", style, IDs.Scope, CustomerOrdersIDs.RecipeRows)
    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
        applied = NSkin:SkinRow(row, {
            style = style,
            border = border,
            hoverRegion = row.HighlightTexture,
            getHovered = IsRecipeRowHovered,
        }) ~= nil or applied
    end)

    if not customerOrdersElements[CustomerOrdersIDs.RecipeRows] then
        local function Refresh()
            return CustomerOrdersSkin:ApplyRecipeRows(frame, browse)
        end
        customerOrdersElements[CustomerOrdersIDs.RecipeRows] =
            NSkin:RegisterSkinningElement(CustomerOrdersIDs.RecipeRows, {
                module = "AuctionHouse", appearanceWindowID = IDs.Scope,
                label = "Customer order recipe rows", kind = "ROW",
                window = frame, target = scrollBox,
                priority = 39, draggable = false,
                highlightRegions = function()
                    return GetVisibleRecipeRows(browse)
                end,
                pixelBorderTargets = function()
                    return GetVisibleRecipeRows(browse)
                end,
                editorOptions = {
                    { id = "shared.rowAppearance", label = "Rows",
                        category = "CUSTOMIZE" },
                },
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(browse)
                        and #GetVisibleRecipeRows(browse) > 0
                end,
            }) == true
    end
    if customerOrdersElements[CustomerOrdersIDs.RecipeRows] then
        NSkin:NotifySkinningElementBoundsChanged(
            CustomerOrdersIDs.RecipeRows)
    end
    return applied
        or customerOrdersElements[CustomerOrdersIDs.RecipeRows] == true
end

function CustomerOrdersSkin:ApplyScrollBars(frame, browse)
    local categoryList = browse and browse.CategoryList
    local recipeList = browse and browse.RecipeList
    local applied = false
    for index, definition in ipairs({
        { CustomerOrdersIDs.CategoryScrollBar,
            "Customer order category scrollbar",
            categoryList and categoryList.ScrollBar, categoryList },
        { CustomerOrdersIDs.RecipeScrollBar,
            "Customer order recipe scrollbar",
            recipeList and recipeList.ScrollBar, recipeList },
    }) do
        local id, label, scrollBar, owner = unpack(definition)
        if scrollBar then
            local element = NSkin:RegisterScrollBar({
                id = id, module = "AuctionHouse",
                appearanceWindowID = IDs.Scope, label = label,
                window = frame, target = scrollBar, priority = 40 + index,
                isEditable = function()
                    return IsVisible(frame) and IsVisible(browse)
                        and IsVisible(owner) and IsVisible(scrollBar)
                end,
            })
            applied = RefreshTypedElement(element) ~= nil or applied
        end
    end
    return applied
end

function CustomerOrdersSkin:ApplyColumnHeaders(frame, browse)
    local recipeList = browse and browse.RecipeList
    local container = recipeList and recipeList.HeaderContainer
    if not container then return false end
    local id = CustomerOrdersIDs.ColumnHeaders
    local function Refresh()
        local style = NSkin:GetAppearanceStyle(
            "columnHeader", IDs.Scope, id)
        local border = NSkin:GetAppearanceBorderColor(
            "columnHeader", style, IDs.Scope, id)
        for _, header in ipairs(GetGeneratedHeaders(browse, false)) do
            NSkin:SkinColumnHeader(header, {
                style = style, border = border,
                textRegion = header.Text or header.Name,
                artworkRegions = {
                    header.Left, header.Middle, header.Right,
                },
            })
        end
        return true
    end
    if not customerOrdersElements[id] then
        customerOrdersElements[id] = NSkin:RegisterSimpleMovableElement({
            id = id,
            module = "AuctionHouse", appearanceWindowID = IDs.Scope,
            label = "Customer order recipe column headers",
            kind = "COLUMN_HEADER", window = frame, target = container,
            priority = 50,
            highlightRegions = function()
                return GetGeneratedHeaders(browse, true)
            end,
            pixelBorderTargets = function()
                return GetGeneratedHeaders(browse, true)
            end,
            refreshAppearance = Refresh, refreshLayout = Refresh,
            isEditable = function()
                return IsVisible(frame) and IsVisible(browse)
                    and #GetGeneratedHeaders(browse, true) > 0
            end,
        }) ~= nil
    end
    Refresh()
    if customerOrdersElements[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return customerOrdersElements[id] == true
end

function CustomerOrdersSkin:ApplyFormReagentGroup(frame, form, id, label,
    container, includeContainerLabel)
    if not container then return false end
    local text = includeContainerLabel and container.Label or nil
    local function RefreshText()
        return SkinFormReagentText(form, container, id, text)
    end
    if not customerOrdersElements[id] then
        customerOrdersElements[id] = NSkin:RegisterIconGroup({
            id = id, module = "AuctionHouse", appearanceWindowID = IDs.Scope,
            label = label, window = frame, target = container,
            priority = 60, draggable = false,
            children = function()
                return GetFormReagentDescriptors(form, container)
            end,
            refreshContent = RefreshText,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            editorOptions = {
                { id = "shared.iconAppearance", label = "Icons",
                    presentation = "INLINE", category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Text",
                    category = "CUSTOMIZE" },
            },
            highlightRegions = function()
                return GetVisibleFormReagentRegions(form, container, text)
            end,
            pixelBorderTargets = function()
                return GetVisibleFormReagentButtons(form, container)
            end,
            isEditable = function()
                return IsVisible(frame) and IsVisible(form)
                    and #GetFormReagentSlots(form, container, true) > 0
            end,
        })
    else
        NSkin:RefreshIconGroup(id)
    end
    RefreshText()
    if customerOrdersElements[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return customerOrdersElements[id] ~= nil
end

function CustomerOrdersSkin:ApplyFormReagents(frame, form)
    local reagentContainer = form and form.ReagentContainer
    if not reagentContainer then return false end
    local applied = self:ApplyFormReagentGroup(frame, form,
        CustomerOrdersIDs.FormRequiredReagents, "Required reagent slots",
        reagentContainer.Reagents, false)
    applied = self:ApplyFormReagentGroup(frame, form,
        CustomerOrdersIDs.FormOptionalReagents, "Optional reagent slots",
        reagentContainer.OptionalReagents, true) or applied
    return applied
end

local function RegisterCustomerOrderText(frame, form, id, label, target,
    priority, numberFormat)
    if not target then return nil end
    local element = NSkin:RegisterTextElement({
        id = id, module = "AuctionHouse", appearanceWindowID = IDs.Scope,
        label = label, window = frame, target = target,
        numberFormat = numberFormat, priority = priority, draggable = false,
        highlightRegions = { target },
        isEditable = function()
            return IsCustomerOrderFormElementVisible(frame, form, target)
        end,
    })
    return RefreshTypedElement(element)
end

function CustomerOrdersSkin:ApplyFormText(frame, form)
    local payment = form and form.PaymentContainer
    local posting = payment and payment.PostingFeeMoneyDisplayFrame
    local total = payment and payment.TotalPriceMoneyDisplayFrame
    local playerMoney = frame and frame.MoneyFrameBorder
        and frame.MoneyFrameBorder.MoneyFrame
    local applied = false
    for index, definition in ipairs({
        { CustomerOrdersIDs.FormPostingFeeGold, "Posting fee gold",
            posting and posting.GoldDisplay, "GOLD" },
        { CustomerOrdersIDs.FormPostingFeeSilver, "Posting fee silver",
            posting and posting.SilverDisplay },
        { CustomerOrdersIDs.FormTotalPriceGold, "Total price gold",
            total and total.GoldDisplay, "GOLD" },
        { CustomerOrdersIDs.FormTotalPriceSilver, "Total price silver",
            total and total.SilverDisplay },
        { CustomerOrdersIDs.FormPlayerMoneyGold, "Player money gold",
            playerMoney and playerMoney.GoldDisplay, "GOLD" },
        { CustomerOrdersIDs.FormPlayerMoneySilver, "Player money silver",
            playerMoney and playerMoney.SilverDisplay },
        { CustomerOrdersIDs.FormPlayerMoneyCopper, "Player money copper",
            playerMoney and playerMoney.CopperDisplay },
    }) do
        applied = RegisterCustomerOrderText(frame, form, definition[1],
            definition[2], definition[3], 70 + index,
            definition[4]) ~= nil or applied
    end
    return applied
end

local function RegisterCustomerOrderActionButton(frame, form, id, label,
    button, priority)
    if not button then return nil end
    local element = NSkin:RegisterActionButton({
        id = id, module = "AuctionHouse", appearanceWindowID = IDs.Scope,
        label = label, window = frame, target = button, priority = priority,
        highlightRegions = { button },
        isEditable = function()
            return IsCustomerOrderFormElementVisible(frame, form, button)
        end,
    })
    return RefreshTypedElement(element)
end

function CustomerOrdersSkin:ApplyFormControls(frame, form)
    local payment = form and form.PaymentContainer
    if not payment then return false end
    local applied = RegisterCustomerOrderActionButton(frame, form,
        CustomerOrdersIDs.FormBackButton, "Crafting order back button",
        form.BackButton, 80) ~= nil
    applied = RegisterCustomerOrderActionButton(frame, form,
        CustomerOrdersIDs.FormListOrderButton, "Place crafting order button",
        payment.ListOrderButton, 81) ~= nil or applied

    local listings = payment.ViewListingsButton
    if listings then
        local preserved = listings.NormalTexture
            or (listings.GetNormalTexture and listings:GetNormalTexture())
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = CustomerOrdersIDs.FormViewListingsButton,
            module = "AuctionHouse", appearanceWindowID = IDs.Scope,
            label = "View similar orders button", window = frame,
            target = listings, preserveTexture = preserved, priority = 82,
            highlightRegions = { listings },
            isEditable = function()
                return IsCustomerOrderFormElementVisible(
                    frame, form, listings)
            end,
        })
        applied = RefreshTypedElement(element) ~= nil or applied
    end

    for index, definition in ipairs({
        { CustomerOrdersIDs.FormRecipientDropdown,
            "Order recipient dropdown", form.OrderRecipientDropdown,
            "MENU_PROFESSIONS_CUSTOMER_ORDER_RECIPIENT" },
        { CustomerOrdersIDs.FormDurationDropdown,
            "Order duration dropdown", payment.DurationDropdown,
            "MENU_PROFESSIONS_CUSTOMER_ORDER_DURATION" },
    }) do
        local dropdown = definition[3]
        if dropdown then
            local element = NSkin:RegisterDropdown({
                id = definition[1], module = "AuctionHouse",
                appearanceWindowID = IDs.Scope, label = definition[2],
                window = frame, target = dropdown,
                menus = { definition[4] }, priority = 83 + index,
                highlightRegions = { dropdown },
                isEditable = function()
                    return IsCustomerOrderFormElementVisible(
                        frame, form, dropdown)
                end,
            })
            applied = RefreshTypedElement(element) ~= nil or applied
        end
    end

    local tip = payment.TipMoneyInputFrame
    local note = payment.NoteEditBox
    local noteScrolling = note and note.ScrollingEditBox
    local noteSurface = noteScrolling and noteScrolling.ScrollBox
    local noteInput = noteSurface and noteSurface.EditBox
    if note then
        SuppressCustomerOrderDecorations(note, "Border", { note.Border })
    end
    for index, definition in ipairs({
        { CustomerOrdersIDs.FormTipGoldInput, "Commission gold input",
            tip and tip.GoldBox },
        { CustomerOrdersIDs.FormTipSilverInput, "Commission silver input",
            tip and tip.SilverBox },
        { CustomerOrdersIDs.FormNoteInput, "Crafter note input", noteInput,
            noteSurface, true },
    }) do
        local editBox = definition[3]
        local surface = definition[4]
        if editBox then
            local element = NSkin:RegisterEditBox({
                id = definition[1], module = "AuctionHouse",
                appearanceWindowID = IDs.Scope, label = definition[2],
                window = frame, target = editBox, priority = 86 + index,
                skinOptions = surface and {
                    surface = surface,
                    manageTextColor = not definition[5],
                } or nil,
                highlightRegions = { surface or editBox },
                isEditable = function()
                    return IsCustomerOrderFormElementVisible(
                        frame, form, surface or editBox)
                end,
            })
            applied = RefreshTypedElement(element) ~= nil or applied
        end
    end

    local track = form.TrackRecipeCheckbox
    local trackButton = track and (track.Checkbox or track)
    for index, definition in ipairs({
        { CustomerOrdersIDs.FormAllocateBestQuality,
            "Allocate best quality", form.AllocateBestQualityCheckbox,
            form.AllocateBestQualityCheckbox
                and (form.AllocateBestQualityCheckbox.Text
                    or form.AllocateBestQualityCheckbox.text) },
        { CustomerOrdersIDs.FormTrackRecipe, "Track recipe", trackButton,
            track and (track.Text or track.text) },
    }) do
        local checkbox, text = definition[3], definition[4]
        if checkbox then
            local element = NSkin:RegisterCheckbox({
                id = definition[1], module = "AuctionHouse",
                appearanceWindowID = IDs.Scope, label = definition[2],
                window = frame, target = checkbox, text = text,
                getChecked = function(target)
                    return target and target.GetChecked
                        and target:GetChecked() == true or false
                end,
                priority = 90 + index,
                highlightRegions = { checkbox, text },
                isEditable = function()
                    return IsCustomerOrderFormElementVisible(
                        frame, form, checkbox)
                end,
            })
            applied = RefreshTypedElement(element) ~= nil or applied
        end
    end
    return applied
end

function CustomerOrdersSkin:ApplyForm(frame)
    local form = frame and frame.Form
    if not form then return false end
    local applied = self:ApplyFormReagents(frame, form)
    applied = self:ApplyFormText(frame, form) or applied
    applied = self:ApplyFormControls(frame, form) or applied
    return applied
end

function CustomerOrdersSkin:Apply()
    local frame, browse = GetCustomerOrdersFrame()
    if not frame or not browse then return false end
    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyTabs(frame) or applied
    applied = self:ApplySearchControls(frame, browse) or applied
    applied = self:ApplyCategoryTargets(frame, browse) or applied
    applied = self:ApplyRecipeRows(frame, browse) or applied
    applied = self:ApplyScrollBars(frame, browse) or applied
    applied = self:ApplyColumnHeaders(frame, browse) or applied
    applied = self:ApplyForm(frame) or applied
    return applied
end

function CustomerOrdersSkin:HookLifecycle(frame, browse)
    if customerOrdersLifecycleHooked then return end
    local form = frame and frame.Form
    if frame.HookScript then
        frame:HookScript("OnShow", function() CustomerOrdersSkin:Apply() end)
    end
    if form and form.HookScript then
        form:HookScript("OnShow", function()
            CustomerOrdersSkin:ApplyForm(frame)
        end)
    end
    if _G.hooksecurefunc then
        if type(browse.Init) == "function" then
            pcall(_G.hooksecurefunc, browse, "Init", function()
                CustomerOrdersSkin:ApplySearchControls(frame, browse)
                CustomerOrdersSkin:ApplyCategoryTargets(frame, browse)
                CustomerOrdersSkin:ApplyRecipeRows(frame, browse)
                CustomerOrdersSkin:ApplyScrollBars(frame, browse)
                CustomerOrdersSkin:ApplyColumnHeaders(frame, browse)
            end)
        end
        if type(browse.SetupTable) == "function" then
            pcall(_G.hooksecurefunc, browse, "SetupTable", function()
                CustomerOrdersSkin:ApplyRecipeRows(frame, browse)
                CustomerOrdersSkin:ApplyColumnHeaders(frame, browse)
            end)
        end
        local categoryList = browse.CategoryList
        if categoryList and type(categoryList.OnDataLoadFinished) == "function" then
            pcall(_G.hooksecurefunc, categoryList,
                "OnDataLoadFinished", function()
                    CustomerOrdersSkin:ApplyCategoryTargets(frame, browse)
                end)
        end
        local scrollBox = GetCategoryScrollBox(browse)
        if scrollBox and type(scrollBox.Update) == "function" then
            pcall(_G.hooksecurefunc, scrollBox, "Update", function()
                CustomerOrdersSkin:ApplyCategoryTargets(frame, browse)
            end)
        end
        local recipeScrollBox = GetRecipeScrollBox(browse)
        if recipeScrollBox and type(recipeScrollBox.Update) == "function" then
            pcall(_G.hooksecurefunc, recipeScrollBox, "Update", function()
                CustomerOrdersSkin:ApplyRecipeRows(frame, browse)
            end)
        end
        if form and type(form.Init) == "function" then
            pcall(_G.hooksecurefunc, form, "Init", function()
                CustomerOrdersSkin:ApplyForm(frame)
            end)
        end
        if form and type(form.UpdateReagentSlots) == "function" then
            pcall(_G.hooksecurefunc, form, "UpdateReagentSlots", function()
                CustomerOrdersSkin:ApplyFormReagents(frame, form)
            end)
        end
    end
    customerOrdersLifecycleHooked = true
end

function CustomerOrdersSkin:Initialize()
    local frame, browse = GetCustomerOrdersFrame()
    if not frame or not browse then return false end
    self:HookLifecycle(frame, browse)
    customerOrdersInitialized = true
    return self:Apply()
end

RefreshCustomerOrdersAppearance = function()
    if customerOrdersInitialized then CustomerOrdersSkin:Apply() end
end

NSkin:RegisterWindowSkin({
    key = "AuctionHouse.CustomerOrders",
    module = "AuctionHouse",
    addon = "Blizzard_ProfessionsCustomerOrders",
    apply = function() return CustomerOrdersSkin:Initialize() end,
})
end
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
    NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
        if IsVisible(row) then rows[#rows + 1] = row end
    end)
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

local function NormalizeBlackMarketTitle(text)
    if type(text) ~= "string" then return nil end
    return (text:gsub("|[nN]", " "):gsub("[\r\n]+", " ")
        :gsub("%s+", " "):match("^%s*(.-)%s*$"))
end

local function GetBlackMarketTitle(frame)
    if not frame or not frame.GetRegions then return nil, {} end
    local expected = NormalizeBlackMarketTitle(_G.BLACK_MARKET_TITLE)
    local inheritedTitle = frame.TitleText
    if not (inheritedTitle and inheritedTitle.IsObjectType
        and inheritedTitle:IsObjectType("FontString"))
    then
        inheritedTitle = nil
    end
    local title, matches = nil, {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("FontString") then
            local text = region.GetText
                and NormalizeBlackMarketTitle(region:GetText())
            if expected and text == expected then
                matches[#matches + 1] = region
                -- BlackMarketFrame declares this anonymous title directly;
                -- BaseBasicFrameTemplate also contributes frame.TitleText.
                if not title and region ~= inheritedTitle then title = region end
            end
        end
    end
    title = title or matches[1] or inheritedTitle
    local duplicates, seen = {}, {}
    for _, region in ipairs(matches) do
        if region ~= title then AddUniqueRegion(duplicates, seen, region) end
    end
    if inheritedTitle and inheritedTitle ~= title then
        AddUniqueRegion(duplicates, seen, inheritedTitle)
    end
    return title, duplicates
end

local function FormatBlackMarketTitle(title)
    if not title or not title.SetText then return end
    local text = _G.BLACK_MARKET_TITLE
        or (title.GetText and title:GetText())
    text = NormalizeBlackMarketTitle(text)
    if text then title:SetText(text) end
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

local function IsRowHovered(row)
    return row and row.IsMouseOver and row:IsMouseOver() or false
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
    local title, duplicateTitles = GetBlackMarketTitle(frame)
    SuppressBlackMarketDecorations(frame, "DuplicateTitles", duplicateTitles)
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
        getHovered = IsRowHovered,
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
    if not NSkin:ForEachScrollBoxFrame(scrollBox, function(row)
        applied = self:ApplyRow(frame, row, styles) or applied
    end) then return false end
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
