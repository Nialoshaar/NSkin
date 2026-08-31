local _, NSkin = ...

local CollectionSkin = NSkin:NewModule("Collections")

local TOYS_PER_PAGE = 18
local BORDER_SIZE = 1
local UNCOLLECTED_ICON_ALPHA = 0.5
local QUALITY_BORDER_KEY = "__NSkinCollectionQualityBorder"
local COLLECTION_ITEM_STATE = "collectionItems"
local FILTER_STATE = "collectionFilter"
local TOY_PROGRESS_ELEMENT_ID = "Collections.ToyBox.ProgressBar"
local COLLECTIONS_WINDOW_ELEMENT_ID = "Collections.Journal.Window"
local COLLECTIONS_APPEARANCE_WINDOW_ID = "Collections"
local TOY_APPEARANCE_WINDOW_ID = "Collections.ToyBox"
local HEIRLOOM_APPEARANCE_WINDOW_ID = "Collections.Heirlooms"
local APPEARANCE_ITEMS_WINDOW_ID = "Collections.Appearances.Items"
local APPEARANCES_WINDOW_ID = "Collections.Appearances"
local TOY_SEARCH_ELEMENT_ID = "Collections.ToyBox.SearchBox"
local TOY_FILTER_ELEMENT_ID = "Collections.ToyBox.Filter"
local TOY_PAGINATION_ELEMENT_ID = "Collections.ToyBox.Pagination"
local TOY_PREVIOUS_ELEMENT_ID = "Collections.ToyBox.Pagination.Previous"
local TOY_NEXT_ELEMENT_ID = "Collections.ToyBox.Pagination.Next"
local TOY_PAGE_TEXT_ELEMENT_ID = "Collections.ToyBox.Pagination.Text"
local HEIRLOOM_SEARCH_ELEMENT_ID = "Collections.Heirlooms.SearchBox"
local HEIRLOOM_FILTER_ELEMENT_ID = "Collections.Heirlooms.Filter"
local HEIRLOOM_CLASS_ELEMENT_ID = "Collections.Heirlooms.ClassDropdown"
local HEIRLOOM_PROGRESS_ELEMENT_ID = "Collections.Heirlooms.ProgressBar"
local HEIRLOOM_PAGINATION_ELEMENT_ID = "Collections.Heirlooms.Pagination"
local HEIRLOOM_PREVIOUS_ELEMENT_ID = "Collections.Heirlooms.Pagination.Previous"
local HEIRLOOM_NEXT_ELEMENT_ID = "Collections.Heirlooms.Pagination.Next"
local HEIRLOOM_PAGE_TEXT_ELEMENT_ID = "Collections.Heirlooms.Pagination.Text"
local APPEARANCE_TABS_ELEMENT_ID = "Collections.Appearances.TopTabs"
local APPEARANCE_SEARCH_ELEMENT_ID = "Collections.Appearances.Items.SearchBox"
local APPEARANCE_FILTER_ELEMENT_ID = "Collections.Appearances.Items.Filter"
local APPEARANCE_CLASS_ELEMENT_ID = "Collections.Appearances.Items.ClassDropdown"
local APPEARANCE_PROGRESS_ELEMENT_ID = "Collections.Appearances.Items.ProgressBar"
local APPEARANCE_PAGINATION_ELEMENT_ID = "Collections.Appearances.Items.Pagination"
local APPEARANCE_PREVIOUS_ELEMENT_ID = "Collections.Appearances.Items.Pagination.Previous"
local APPEARANCE_NEXT_ELEMENT_ID = "Collections.Appearances.Items.Pagination.Next"
local APPEARANCE_PAGE_TEXT_ELEMENT_ID = "Collections.Appearances.Items.Pagination.Text"
local WINDOW_BUTTON_TEXT_SIZE = 20

NSkin:RegisterAppearanceScope(COLLECTIONS_APPEARANCE_WINDOW_ID, {
    label = "Collections",
})
NSkin:RegisterAppearanceScope(TOY_APPEARANCE_WINDOW_ID, {
    label = "Toy Box", parent = COLLECTIONS_APPEARANCE_WINDOW_ID,
})
NSkin:RegisterAppearanceScope(HEIRLOOM_APPEARANCE_WINDOW_ID, {
    label = "Heirlooms", parent = COLLECTIONS_APPEARANCE_WINDOW_ID,
})
NSkin:RegisterAppearanceScope(APPEARANCES_WINDOW_ID, {
    label = "Appearances", parent = COLLECTIONS_APPEARANCE_WINDOW_ID,
})
NSkin:RegisterAppearanceScope(APPEARANCE_ITEMS_WINDOW_ID, {
    label = "Appearances - Items", parent = APPEARANCES_WINDOW_ID,
})
local HEIRLOOM_QUALITY = _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Heirloom or 7
local Item = _G.C_Item
local COLLECTION_PROGRESS_BAR_STYLE = {
    stripArtwork = true,
    useThemeTexture = true,
    background = true,
    centerText = true,
    textOffsetY = 1,
}

local collectionsInitialized = false
local toysInitialized = false
local heirloomsInitialized = false
local toyPaginationController
local toySearchController
local toySearchGroupedAnchor
local heirloomPaginationController
local heirloomSearchController
local heirloomSearchGroupedAnchor
local appearancePaginationController
local appearanceSearchController
local appearanceSearchGroupedAnchor
local appearanceTabsRegistered = false
local collectionTabs
local SkinCollectionsWindow
local ApplyCollectionsSkin
local filterMenuHooked = false
local collectionMenuOwners = setmetatable({}, { __mode = "k" })
local activeCollectionDropdown
local activeCollectionMenu
local TAB_GROUP_ID = "Collections.MainTabs"
local State = {
    Main = {}, ToyBox = {}, Heirlooms = {},
    Appearances = { Items = {} },
}
local Adapters = {
    ToyBox = { scopeID = TOY_APPEARANCE_WINDOW_ID, state = State.ToyBox },
    Heirlooms = { scopeID = HEIRLOOM_APPEARANCE_WINDOW_ID,
        state = State.Heirlooms },
    AppearanceItems = { scopeID = APPEARANCE_ITEMS_WINDOW_ID,
        state = State.Appearances.Items },
}
local ACTIVE_ADAPTERS = {
    Adapters.ToyBox, Adapters.Heirlooms, Adapters.AppearanceItems,
}

function Adapters.ToyBox:IsAvailable() return _G.ToyBox ~= nil end
function Adapters.Heirlooms:IsAvailable() return _G.HeirloomsJournal ~= nil end
function Adapters.AppearanceItems:IsAvailable()
    return _G.WardrobeCollectionFrame
        and _G.WardrobeCollectionFrame.ItemsCollectionFrame
end
for name, adapter in pairs(Adapters) do
    adapter.name = name
    function adapter:InitializeOnce()
        if self.state.initialized then return end
        self.state.initialized = true
    end
    function adapter:ApplySkin()
        SkinCollectionsWindow(self.name)
    end
    adapter.RefreshTheme = adapter.ApplySkin
end

local function SkinFilterMenuFrame(menu)
    if not menu or not menu.GetRegions then return end

    if menu == activeCollectionMenu and activeCollectionDropdown then
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", activeCollectionDropdown, "BOTTOMLEFT", 0, 0)
    end

    for index = 1, menu:GetNumRegions() do
        local region = select(index, menu:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            region:SetColorTexture(unpack(NSkin:GetStyle("window").background))
            region:ClearAllPoints()
            region:SetPoint("TOPLEFT", menu, "TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
            region:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
        end
    end

    local data = NSkin:GetSkinData(menu, FILTER_STATE)
    local border = data.border
    if not border then
        border = CreateFrame("Frame", nil, menu)
        border:EnableMouse(false)
        NSkin:CreateFlatBackground(border, nil, { 0, 0, 0, 0 }, NSkin:GetSharedBorderColor())
        data.border = border
    end
    border:SetFrameLevel(menu:GetFrameLevel() + 20)
    border:ClearAllPoints()
    border:SetAllPoints(menu)
    border:Show()
end

local function TintFilterMenuTexture(texture, color)
    if not texture then return end
    texture:SetDesaturated(true)
    texture:SetVertexColor(unpack(color))
end

local function SkinFilterMenuElement(frame)
    if not frame then return end
    local color = NSkin:GetSharedBorderColor()
    if frame.fontString then
        frame.fontString:SetTextColor(unpack(NSkin:GetStyle("button").text))
    end
    if frame.highlight then
        frame.highlight:SetBlendMode("BLEND")
        frame.highlight:SetColorTexture(color[1], color[2], color[3], 0.14)
    end
    TintFilterMenuTexture(frame.leftTexture1, color)
    TintFilterMenuTexture(frame.leftTexture2, color)
    TintFilterMenuTexture(frame.arrow, color)
end

local function SkinFilterMenu(menu)
    SkinFilterMenuFrame(menu)
    for index = 1, menu:GetNumChildren() do
        local child = select(index, menu:GetChildren())
        SkinFilterMenuElement(child)
    end
end

local function HookFilterMenu()
    if filterMenuHooked or not _G.Menu or type(_G.Menu.GetManager) ~= "function" then return end
    local manager = _G.Menu.GetManager()
    if not manager or type(manager.OpenMenu) ~= "function" then return end

    hooksecurefunc(manager, "OpenMenu", function(self, ownerRegion)
        if not collectionMenuOwners[ownerRegion] then return end
        local menu = self:GetOpenMenu()
        if not menu then return end
        activeCollectionDropdown = ownerRegion
        activeCollectionMenu = menu

        -- Defer until Blizzard has finished constructing the generated menu
        -- regions; this is ordering, not a timing or taint boundary.
        C_Timer.After(0, function()
            if menu:IsShown() then SkinFilterMenu(menu) end
        end)
    end)

    if _G.MenuStyle1Mixin and type(_G.MenuStyle1Mixin.Generate) == "function" then
        hooksecurefunc(_G.MenuStyle1Mixin, "Generate", function(menu)
            local root = activeCollectionMenu
            if not root or not root:IsShown() or menu == root then return end

            -- Submenus bypass MenuManager:OpenMenu. Style their generated
            -- frame only while the tracked Collections dropdown is still open.
            C_Timer.After(0, function()
                if root:IsShown() and menu:IsShown() then SkinFilterMenu(menu) end
            end)
        end)
    end
    filterMenuHooked = true
end

local function SkinCollectionDropdownButton(button, fallbackLabel, preserveText)
    if not button then return end
    collectionMenuOwners[button] = true
    NSkin:CreateFlatBackground(button, nil, NSkin:GetStyle("button").background,
        NSkin:GetComponentBorderColor("button", NSkin:GetStyle("button")))
    NSkin:CreateFlatButtonGlow(button, NSkin:GetStyle("button").hoverAlpha)

    if button.Background then button.Background:SetAlpha(0) end
    if button.Arrow then button.Arrow:SetAlpha(0) end
    if button.NineSlice then button.NineSlice:Hide() end
    if button.Text then
        button.Text:SetTextColor(unpack(NSkin:GetStyle("button").text))
        button.Text:SetAlpha(preserveText and 1 or 0)
    end

    local data = NSkin:GetSkinData(button, FILTER_STATE)
    if not preserveText then
        local label = NSkin:SetFlatButtonLabel(button, fallbackLabel or "", 12)
        if label then label:SetTextColor(unpack(NSkin:GetStyle("button").text)) end
    end
    local arrow = data.arrow
    if not arrow then
        arrow = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        arrow:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        arrow:SetText("v")
        data.arrow = arrow
    end
    arrow:SetTextColor(unpack(NSkin:GetSharedBorderColor()))
    arrow:Show()

    HookFilterMenu()
end

local function RegisterCollectionMovableElement(id, appearanceWindowID, label,
    journal, target, priority, anchorHighlight, editorOptions, isEditable)
    if not journal or not target then return end
    return NSkin:RegisterSimpleMovableElement({
        id = id,
        module = "Collections",
        appearanceWindowID = appearanceWindowID,
        label = label,
        window = journal,
        target = target,
        editorOptions = editorOptions,
        preserveBlizzardPlacement = true,
        priority = priority or 80,
        anchorHighlight = anchorHighlight,
        highlightRegions = { target },
        isEditable = isEditable,
    })
end

local function AnchorToySearchAccessory(searchBox, filterDropdown)
    if not searchBox or not filterDropdown or not toySearchGroupedAnchor then return false end
    if filterDropdown.IsProtected and filterDropdown:IsProtected() then return false end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    filterDropdown:ClearAllPoints()
    filterDropdown:SetPoint(toySearchGroupedAnchor.point, searchBox,
        toySearchGroupedAnchor.relativePoint, toySearchGroupedAnchor.x,
        toySearchGroupedAnchor.y)
    return true
end

local function CaptureSearchAccessoryAnchor(searchBox, accessory)
    if not searchBox or not accessory then return nil end
    local searchLeft, searchRight = searchBox:GetLeft(), searchBox:GetRight()
    local accessoryLeft, accessoryRight = accessory:GetLeft(), accessory:GetRight()
    local _, searchY = searchBox:GetCenter()
    local _, accessoryY = accessory:GetCenter()
    if not searchLeft or not searchRight or not accessoryLeft or not accessoryRight
        or not searchY or not accessoryY
    then return nil end
    if accessoryRight <= searchLeft then
        return { point = "RIGHT", relativePoint = "LEFT",
            x = accessoryRight - searchLeft, y = accessoryY - searchY }
    end
    return { point = "LEFT", relativePoint = "RIGHT",
        x = accessoryLeft - searchRight, y = accessoryY - searchY }
end

local function AnchorHeirloomSearchAccessory(searchBox, filterDropdown)
    if not searchBox or not filterDropdown or not heirloomSearchGroupedAnchor then
        return false
    end
    if filterDropdown.IsProtected and filterDropdown:IsProtected() then return false end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    filterDropdown:ClearAllPoints()
    filterDropdown:SetPoint(heirloomSearchGroupedAnchor.point, searchBox,
        heirloomSearchGroupedAnchor.relativePoint, heirloomSearchGroupedAnchor.x,
        heirloomSearchGroupedAnchor.y)
    return true
end

local function HideBackgroundTexture(texture)
    if not texture or not texture.GetObjectType
        or texture:GetObjectType() ~= "Texture"
    then
        return
    end

    texture:SetAlpha(0)
    texture:SetTexture(nil)
    texture:Hide()
end

local function RemoveBackgroundFrame(frame)
    if not frame then return end

    NSkin:HideTextureRegions(frame)
    if frame.NineSlice then frame.NineSlice:Hide() end
    HideBackgroundTexture(frame.Bg)
    HideBackgroundTexture(frame.Background)
end

local function RemoveCollectionPageBackgrounds()
    local mountJournal = _G.MountJournal
    if mountJournal then
        RemoveBackgroundFrame(mountJournal.LeftInset)
        RemoveBackgroundFrame(mountJournal.BottomLeftInset)
        RemoveBackgroundFrame(mountJournal.RightInset)

        local mountDisplay = mountJournal.MountDisplay
        if mountDisplay then
            HideBackgroundTexture(mountDisplay.YesMountsTex)
            HideBackgroundTexture(mountDisplay.NoMountsTex)
        end
    end

    local petJournal = _G.PetJournal
    if petJournal then
        RemoveBackgroundFrame(petJournal.LeftInset)
        RemoveBackgroundFrame(petJournal.RightInset)
        RemoveBackgroundFrame(petJournal.PetCardInset)
    end

    local toyBox = _G.ToyBox
    RemoveBackgroundFrame(toyBox and toyBox.iconsFrame)

    local heirloomsJournal = _G.HeirloomsJournal
    RemoveBackgroundFrame(heirloomsJournal and heirloomsJournal.iconsFrame)

    local wardrobe = _G.WardrobeCollectionFrame
    if wardrobe then
        RemoveBackgroundFrame(wardrobe.ItemsCollectionFrame)
        local setsFrame = wardrobe.SetsCollectionFrame
        RemoveBackgroundFrame(setsFrame and setsFrame.RightInset)
    end

    local scenes = _G.WarbandSceneJournal
    if scenes then
        RemoveBackgroundFrame(scenes.iconsFrame)
        RemoveBackgroundFrame(scenes.ContentFrame)
        HideBackgroundTexture(scenes.Background)
        HideBackgroundTexture(scenes.Bg)
    end
end

local function GetCollectionTabs(journal)
    if collectionTabs then return collectionTabs end
    collectionTabs = {
        journal.MountsTab,
        journal.PetsTab,
        journal.ToysTab,
        journal.HeirloomsTab,
        journal.WardrobeTab,
        journal.WarbandScenesTab,
    }
    return collectionTabs
end

local function SkinCollectionTabs(selectedTab)
    local journal = _G.CollectionsJournal
    if not journal then return end

    selectedTab = selectedTab or (_G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(journal))
    local tabs = GetCollectionTabs(journal)
    local style = NSkin:GetAppearanceStyle(
        "tab", COLLECTIONS_APPEARANCE_WINDOW_ID, TAB_GROUP_ID)
    local borderColor = NSkin:GetAppearanceBorderColor(
        "tab", style, COLLECTIONS_APPEARANCE_WINDOW_ID, TAB_GROUP_ID)
    for i = 1, #tabs do
        NSkin:SkinTab(tabs[i], i == selectedTab, style, borderColor)
    end
    if NSkin:GetTabGroup(TAB_GROUP_ID) then
        NSkin:ApplyTabGroupLayout(TAB_GROUP_ID)
    end
end

function CollectionSkin:OnTabSet(_, selectedTab)
    ApplyCollectionsSkin()
    RemoveCollectionPageBackgrounds()
end

function CollectionSkin:OnShow(selectedTab)
    self:InitializeOptionalAdapters()
    ApplyCollectionsSkin()
end

local function ResolvePagingControls(owner, candidate)
    local function Find(field, legacyField)
        return candidate and (candidate[field] or candidate[legacyField])
            or owner and (owner[field] or owner[legacyField])
    end
    local previous = Find("PrevPageButton", "prevPageButton")
    local nextPage = Find("NextPageButton", "nextPageButton")
    local pageText = Find("PageText", "pageText")
    local group = candidate
        or (previous and previous.GetParent and previous:GetParent())
        or (nextPage and nextPage.GetParent and nextPage:GetParent())
        or (pageText and pageText.GetParent and pageText:GetParent())
    return group, previous, nextPage, pageText
end

SkinCollectionsWindow = function(adapterName)
    local journal = _G.CollectionsJournal
    if not journal then return end

    if not adapterName or adapterName == "Main" then
    if journal.NineSlice then journal.NineSlice:Hide() end
    if journal.Bg then journal.Bg:Hide() end
    if journal.PortraitContainer then
        journal.PortraitContainer:SetAlpha(0)
        journal.PortraitContainer:Hide()
    elseif journal.portrait then
        journal.portrait:SetAlpha(0)
        journal.portrait:Hide()
    end

    local windowStyle = NSkin:GetAppearanceStyle("window",
        COLLECTIONS_APPEARANCE_WINDOW_ID, COLLECTIONS_WINDOW_ELEMENT_ID)
    NSkin:SkinWindow(journal, nil, windowStyle,
        NSkin:GetAppearanceBorderColor("window", windowStyle,
            COLLECTIONS_APPEARANCE_WINDOW_ID, COLLECTIONS_WINDOW_ELEMENT_ID))
    NSkin:SkinWindowHeader(journal, windowStyle.header)

    local title = journal.TitleContainer and journal.TitleContainer.TitleText
    if title then
        title:SetTextColor(unpack(
            NSkin:GetResolvedAppearanceColor(windowStyle.header, "text")))
        local font, size, outline = NSkin:GetResolvedTypography(windowStyle.header)
        if font and size then title:SetFont(font, size, outline) end
    end

    local closeButton = journal.CloseButton
    NSkin:SkinFlatButton(closeButton, "x", nil, nil, WINDOW_BUTTON_TEXT_SIZE)

    SkinCollectionTabs()
    end

    local toyBox = _G.ToyBox
    if toyBox and (not adapterName or adapterName == "ToyBox") then
        local searchBox = toyBox.SearchBox or toyBox.searchBox
        local filterDropdown = toyBox.FilterDropdown
        local pagingControls = toyBox.PagingControls or toyBox.PagingFrame
            or toyBox.pagingFrame
        local pagingGroup, previousPage, nextPage, pageText =
            ResolvePagingControls(toyBox, pagingControls)
        local searchStyle = NSkin:GetAppearanceStyle(
            "searchBox", TOY_APPEARANCE_WINDOW_ID, TOY_SEARCH_ELEMENT_ID)
        NSkin:SkinSearchBox(searchBox, searchStyle,
            NSkin:GetAppearanceBorderColor("searchBox", searchStyle,
                TOY_APPEARANCE_WINDOW_ID, TOY_SEARCH_ELEMENT_ID))
        SkinCollectionDropdownButton(filterDropdown, "Filter", false)
        if searchBox and filterDropdown then
            if not toySearchGroupedAnchor then
                toySearchGroupedAnchor = CaptureSearchAccessoryAnchor(
                    searchBox, filterDropdown)
            end
        end
        NSkin:SkinPagingControls(pagingGroup or toyBox)
        local progressBar = toyBox.ProgressBar or toyBox.progressBar
        NSkin:SkinProgressBar(progressBar, COLLECTION_PROGRESS_BAR_STYLE)
        RegisterCollectionMovableElement(
            TOY_PROGRESS_ELEMENT_ID, TOY_APPEARANCE_WINDOW_ID,
            "Toy Box progress bar", journal, progressBar, 80,
            nil, nil, function()
                return toyBox:IsVisible() and progressBar:IsVisible()
            end
        )
        if not toySearchController then
            toySearchController = NSkin:RegisterAccessoryGroup({
                module = "Collections",
                appearanceWindowID = TOY_APPEARANCE_WINDOW_ID,
                window = journal,
                ids = { primary = TOY_SEARCH_ELEMENT_ID,
                    accessory = TOY_FILTER_ELEMENT_ID },
                primary = searchBox, accessory = filterDropdown,
                primaryLabel = "Toy Box search bar", accessoryLabel = "Toy Box filter",
                primaryPriority = 81, accessoryPriority = 91,
                legacyOptionKey = "searchAccessoryMode",
                visibilityFrame = toyBox,
                anchorGrouped = AnchorToySearchAccessory,
            })
        else
            toySearchController:Refresh()
        end
        if not toyPaginationController then
            toyPaginationController = NSkin:RegisterPaginationGroup({
                module = "Collections",
                appearanceWindowID = TOY_APPEARANCE_WINDOW_ID,
                window = journal,
                ids = { group = TOY_PAGINATION_ELEMENT_ID,
                    previous = TOY_PREVIOUS_ELEMENT_ID, next = TOY_NEXT_ELEMENT_ID,
                    text = TOY_PAGE_TEXT_ELEMENT_ID },
                controls = { group = pagingGroup, previous = previousPage,
                    next = nextPage, text = pageText },
                groupLabel = "Toy Box pagination", groupPriority = 82,
                legacySeparateOptionKey = "separatePaginationButtons",
                legacyTextOptionKey = "paginationTextMode",
                visibilityFrame = toyBox,
            })
        else
            toyPaginationController:Refresh()
        end
    end

    local heirlooms = _G.HeirloomsJournal
    if heirlooms and (not adapterName or adapterName == "Heirlooms") then
        local searchBox = heirlooms.SearchBox or heirlooms.searchBox
        local filterDropdown = heirlooms.FilterDropdown
        local classDropdown = heirlooms.ClassDropdown
        local pagingControls = heirlooms.PagingFrame or heirlooms.PagingControls
        local pagingGroup, previousPage, nextPage, pageText =
            ResolvePagingControls(heirlooms, pagingControls)
        local progressBar = heirlooms.progressBar or heirlooms.ProgressBar
        local searchStyle = NSkin:GetAppearanceStyle(
            "searchBox", HEIRLOOM_APPEARANCE_WINDOW_ID, HEIRLOOM_SEARCH_ELEMENT_ID)
        NSkin:SkinSearchBox(searchBox, searchStyle,
            NSkin:GetAppearanceBorderColor("searchBox", searchStyle,
                HEIRLOOM_APPEARANCE_WINDOW_ID, HEIRLOOM_SEARCH_ELEMENT_ID))
        SkinCollectionDropdownButton(filterDropdown, "Filter", false)
        SkinCollectionDropdownButton(classDropdown, "Class/spec", true)
        if searchBox and filterDropdown then
            if not heirloomSearchGroupedAnchor then
                heirloomSearchGroupedAnchor = CaptureSearchAccessoryAnchor(
                    searchBox, filterDropdown)
            end
        end
        NSkin:SkinPagingControls(pagingGroup or heirlooms)
        NSkin:SkinProgressBar(progressBar, COLLECTION_PROGRESS_BAR_STYLE)
        RegisterCollectionMovableElement(
            HEIRLOOM_CLASS_ELEMENT_ID, HEIRLOOM_APPEARANCE_WINDOW_ID,
            "Heirlooms class/spec filter", journal, classDropdown, 79)
        RegisterCollectionMovableElement(
            HEIRLOOM_PROGRESS_ELEMENT_ID, HEIRLOOM_APPEARANCE_WINDOW_ID,
            "Heirlooms progress bar", journal, progressBar, 80,
            nil, nil, function()
                return heirlooms:IsVisible() and progressBar:IsVisible()
            end)
        if not heirloomSearchController then
            heirloomSearchController = NSkin:RegisterAccessoryGroup({
                module = "Collections",
                appearanceWindowID = HEIRLOOM_APPEARANCE_WINDOW_ID,
                window = journal,
                ids = { primary = HEIRLOOM_SEARCH_ELEMENT_ID,
                    accessory = HEIRLOOM_FILTER_ELEMENT_ID },
                primary = searchBox, accessory = filterDropdown,
                primaryLabel = "Heirlooms search bar",
                accessoryLabel = "Heirlooms filter",
                primaryPriority = 81, accessoryPriority = 91,
                visibilityFrame = heirlooms,
                anchorGrouped = AnchorHeirloomSearchAccessory,
            })
        else
            heirloomSearchController:Refresh()
        end
        if not heirloomPaginationController then
            heirloomPaginationController = NSkin:RegisterPaginationGroup({
                module = "Collections",
                appearanceWindowID = HEIRLOOM_APPEARANCE_WINDOW_ID,
                window = journal,
                ids = { group = HEIRLOOM_PAGINATION_ELEMENT_ID,
                    previous = HEIRLOOM_PREVIOUS_ELEMENT_ID,
                    next = HEIRLOOM_NEXT_ELEMENT_ID,
                    text = HEIRLOOM_PAGE_TEXT_ELEMENT_ID },
                controls = { group = pagingGroup, previous = previousPage,
                    next = nextPage, text = pageText },
                groupLabel = "Heirlooms pagination", groupPriority = 82,
                visibilityFrame = heirlooms,
            })
        else
            heirloomPaginationController:Refresh()
        end
    end

    local wardrobe = _G.WardrobeCollectionFrame
    local itemsFrame = wardrobe and wardrobe.ItemsCollectionFrame
    if wardrobe and itemsFrame
        and (not adapterName or adapterName == "AppearanceItems")
    then
        local topTabs = { wardrobe.ItemsTab, wardrobe.SetsTab }
        local selectedTab = _G.PanelTemplates_GetSelectedTab
            and _G.PanelTemplates_GetSelectedTab(wardrobe) or 1
        local tabStyle = NSkin:GetAppearanceStyle(
            "tab", APPEARANCE_ITEMS_WINDOW_ID, APPEARANCE_TABS_ELEMENT_ID)
        local tabBorder = NSkin:GetAppearanceBorderColor(
            "tab", tabStyle, APPEARANCE_ITEMS_WINDOW_ID,
            APPEARANCE_TABS_ELEMENT_ID)
        for i = 1, #topTabs do
            NSkin:SkinTab(topTabs[i], i == selectedTab, tabStyle, tabBorder)
        end
        if not appearanceTabsRegistered then
            appearanceTabsRegistered = NSkin:RegisterTabGroup(
                APPEARANCE_TABS_ELEMENT_ID, {
                    module = "Collections",
                    appearanceWindowID = APPEARANCE_ITEMS_WINDOW_ID,
                    label = "Appearances top tabs",
                    window = journal,
                    target = wardrobe,
                    tabs = topTabs,
                    priority = 60,
                    orientation = "HORIZONTAL",
                    edge = "TOP",
                    isEditable = function() return wardrobe:IsVisible() end,
                }) == true
        elseif NSkin:GetTabGroup(APPEARANCE_TABS_ELEMENT_ID) then
            NSkin:ApplyTabGroupLayout(APPEARANCE_TABS_ELEMENT_ID)
        end

        local searchBox = wardrobe.SearchBox or wardrobe.searchBox
        local filterDropdown = wardrobe.FilterButton or wardrobe.FilterDropdown
        local classDropdown = wardrobe.ClassDropdown
        local weaponDropdown = itemsFrame.WeaponDropdown
        local progressBar = wardrobe.progressBar or wardrobe.ProgressBar
        local pagingControls = itemsFrame.PagingFrame or itemsFrame.PagingControls
        local pagingGroup, previousPage, nextPage, pageText =
            ResolvePagingControls(itemsFrame, pagingControls)
        local searchStyle = NSkin:GetAppearanceStyle(
            "searchBox", APPEARANCE_ITEMS_WINDOW_ID, APPEARANCE_SEARCH_ELEMENT_ID)
        NSkin:SkinSearchBox(searchBox, searchStyle,
            NSkin:GetAppearanceBorderColor("searchBox", searchStyle,
                APPEARANCE_ITEMS_WINDOW_ID, APPEARANCE_SEARCH_ELEMENT_ID))
        SkinCollectionDropdownButton(filterDropdown, "Filter", false)
        SkinCollectionDropdownButton(classDropdown, "Class/spec", true)
        SkinCollectionDropdownButton(weaponDropdown, "Weapon", true)
        if searchBox and filterDropdown then
            if not appearanceSearchGroupedAnchor then
                appearanceSearchGroupedAnchor = CaptureSearchAccessoryAnchor(
                    searchBox, filterDropdown)
            end
        end
        NSkin:SkinProgressBar(progressBar, COLLECTION_PROGRESS_BAR_STYLE)
        NSkin:SkinPagingControls(pagingGroup or itemsFrame)
        RegisterCollectionMovableElement(
            APPEARANCE_CLASS_ELEMENT_ID, APPEARANCE_ITEMS_WINDOW_ID,
            "Appearances class/spec filter", journal, classDropdown, 79,
            nil, nil, function()
                return itemsFrame:IsVisible() and classDropdown:IsVisible()
            end)
        RegisterCollectionMovableElement(
            APPEARANCE_PROGRESS_ELEMENT_ID, APPEARANCE_ITEMS_WINDOW_ID,
            "Appearances progress bar", journal, progressBar, 81,
            nil, nil, function()
                return itemsFrame:IsVisible() and progressBar:IsVisible()
            end)
        if not appearanceSearchController then
            appearanceSearchController = NSkin:RegisterAccessoryGroup({
                module = "Collections",
                appearanceWindowID = APPEARANCE_ITEMS_WINDOW_ID,
                window = journal,
                ids = { primary = APPEARANCE_SEARCH_ELEMENT_ID,
                    accessory = APPEARANCE_FILTER_ELEMENT_ID },
                primary = searchBox, accessory = filterDropdown,
                primaryLabel = "Appearances search bar",
                accessoryLabel = "Appearances filter",
                primaryPriority = 82, accessoryPriority = 92,
                visibilityFrame = itemsFrame,
                anchorGrouped = function(primary, accessory)
                    if not appearanceSearchGroupedAnchor then return false end
                    if accessory.IsProtected and accessory:IsProtected() then return false end
                    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
                    accessory:ClearAllPoints()
                    accessory:SetPoint(appearanceSearchGroupedAnchor.point, primary,
                        appearanceSearchGroupedAnchor.relativePoint,
                        appearanceSearchGroupedAnchor.x,
                        appearanceSearchGroupedAnchor.y)
                    return true
                end,
            })
        else
            appearanceSearchController:Refresh()
        end
        if not appearancePaginationController then
            appearancePaginationController = NSkin:RegisterPaginationGroup({
                module = "Collections",
                appearanceWindowID = APPEARANCE_ITEMS_WINDOW_ID,
                window = journal,
                ids = { group = APPEARANCE_PAGINATION_ELEMENT_ID,
                    previous = APPEARANCE_PREVIOUS_ELEMENT_ID,
                    next = APPEARANCE_NEXT_ELEMENT_ID,
                    text = APPEARANCE_PAGE_TEXT_ELEMENT_ID },
                controls = { group = pagingGroup, previous = previousPage,
                    next = nextPage, text = pageText },
                groupLabel = "Appearances pagination", groupPriority = 83,
                visibilityFrame = itemsFrame,
            })
        else
            appearancePaginationController:Refresh()
        end
    end
end

ApplyCollectionsSkin = function()
    SkinCollectionsWindow("Main")
    for i = 1, #ACTIVE_ADAPTERS do
        local adapter = ACTIVE_ADAPTERS[i]
        if adapter:IsAvailable() then
            adapter:InitializeOnce()
            adapter:ApplySkin()
        end
    end
end

local function UpdateIconBorder(button, knownQuality)
    if not button or not button.iconTexture then return end

    local data = NSkin:GetSkinData(button, COLLECTION_ITEM_STATE)
    local itemID = button.itemID
    local border = NSkin:GetPixelBorder(button, QUALITY_BORDER_KEY)

    if not itemID or itemID < 0 then
        NSkin:SetPixelBorderShown(border, false)
        return
    end

    if not border then
        border = NSkin:CreateQualityBorder(button, button.iconTexture, QUALITY_BORDER_KEY, BORDER_SIZE)
        if not border then return end
    end

    local qualityColorEnabled = NSkin:GetStyle("icon").qualityColor ~= false
    if data.qualityItemID ~= itemID
        or data.qualityColorEnabled ~= qualityColorEnabled
    then
        local quality = knownQuality or Item.GetItemQualityByID(itemID)
        if not NSkin:SetQualityBorder(border, quality) then return end

        data.qualityItemID = itemID
        data.qualityColorEnabled = qualityColorEnabled
    else
        NSkin:SetPixelBorderShown(border, true)
    end
end

local function SkinCollectionButton(button, knownQuality)
    if not button then return end

    local data = NSkin:GetSkinData(button, COLLECTION_ITEM_STATE)
    local uncollectedIcon = button.iconTextureUncollected
    if uncollectedIcon then
        uncollectedIcon:SetAlpha(UNCOLLECTED_ICON_ALPHA)
    end

    if not data.collectionDecorationRemoved then
        local slotFrame = button.slotFrameCollected
        if slotFrame then
            if slotFrame.SetAtlas then slotFrame:SetAtlas(nil) end
            slotFrame:SetTexture(nil)
            slotFrame:Hide()
        end
        data.collectionDecorationRemoved = true
    end

    UpdateIconBorder(button, knownQuality)
end

function CollectionSkin:InitializeOptionalAdapters()
    if not _G.hooksecurefunc then return end
    local toyBox = _G.ToyBox
    local iconsFrame = toyBox and toyBox.iconsFrame
    if not toysInitialized and iconsFrame
        and type(_G.ToySpellButton_UpdateButton) == "function"
    then
        _G.hooksecurefunc("ToySpellButton_UpdateButton", SkinCollectionButton)
        toysInitialized = true
        for i = 1, TOYS_PER_PAGE do
            SkinCollectionButton(iconsFrame["spellButton" .. i])
        end
    end
    local heirloomsJournal = _G.HeirloomsJournal
    if not heirloomsInitialized and heirloomsJournal
        and type(heirloomsJournal.UpdateButton) == "function"
    then
        _G.hooksecurefunc(heirloomsJournal, "UpdateButton", function(_, button)
            SkinCollectionButton(button, HEIRLOOM_QUALITY)
        end)
        heirloomsInitialized = true
        for i = 1, #(heirloomsJournal.heirloomEntryFrames or {}) do
            SkinCollectionButton(
                heirloomsJournal.heirloomEntryFrames[i], HEIRLOOM_QUALITY)
        end
    end
end

function CollectionSkin:Initialize()
    if collectionsInitialized then
        self:InitializeOptionalAdapters()
        return true
    end
    if not NSkin:IsModuleEnabled("Collections") then return false end

    if not _G.hooksecurefunc then return false end

    local journal = _G.CollectionsJournal
    local canSkinCollections = journal
        and type(_G.PanelTemplates_GetSelectedTab) == "function"
        and _G.EventRegistry
        and type(_G.EventRegistry.RegisterCallback) == "function"
    if not canSkinCollections then return false end

    if not collectionsInitialized then
        NSkin:RegisterTabGroup(TAB_GROUP_ID, {
            module = "Collections",
            appearanceWindowID = COLLECTIONS_APPEARANCE_WINDOW_ID,
            label = "Collections tabs",
            kind = "TAB_GROUP",
            window = journal,
            target = journal,
            tabs = GetCollectionTabs(journal),
            priority = 50,
            orientation = "HORIZONTAL",
            edge = "BOTTOM",
        })
        NSkin:RegisterSkinningElement(COLLECTIONS_WINDOW_ELEMENT_ID, {
            module = "Collections",
            appearanceWindowID = COLLECTIONS_APPEARANCE_WINDOW_ID,
            label = "Collections window",
            kind = "WINDOW",
            window = journal,
            target = journal,
            priority = 0,
            draggable = false,
        })
        _G.EventRegistry:RegisterCallback(
            "CollectionsJournal.TabSet",
            CollectionSkin.OnTabSet,
            CollectionSkin
        )
        _G.EventRegistry:RegisterCallback(
            "CollectionsJournal.OnShow",
            CollectionSkin.OnShow,
            CollectionSkin
        )
        collectionsInitialized = true
        ApplyCollectionsSkin()
        RemoveCollectionPageBackgrounds()
    end

    self:InitializeOptionalAdapters()
    return collectionsInitialized
end

function CollectionSkin:RefreshTheme()
    if not collectionsInitialized then return end
    SkinCollectionsWindow("Main")
    for i = 1, #ACTIVE_ADAPTERS do
        local adapter = ACTIVE_ADAPTERS[i]
        if adapter:IsAvailable() then adapter:RefreshTheme() end
    end
    local iconsFrame = _G.ToyBox and _G.ToyBox.iconsFrame
    if toysInitialized and iconsFrame then
        for i = 1, TOYS_PER_PAGE do
            SkinCollectionButton(iconsFrame["spellButton" .. i])
        end
    end
    local heirloomsJournal = _G.HeirloomsJournal
    if heirloomsInitialized and heirloomsJournal then
        for i = 1, #(heirloomsJournal.heirloomEntryFrames or {}) do
            SkinCollectionButton(
                heirloomsJournal.heirloomEntryFrames[i], HEIRLOOM_QUALITY)
        end
    end
end

NSkin:RegisterWindowSkin({
    module = "Collections",
    addon = "Blizzard_Collections",
    apply = function() return CollectionSkin:Initialize() end,
})
