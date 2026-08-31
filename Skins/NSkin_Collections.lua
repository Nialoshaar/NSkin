local _, NSkin = ...

local CollectionSkin = NSkin:NewModule("Collections")

local TOYS_PER_PAGE = 18
local BORDER_SIZE = 1
local UNCOLLECTED_ICON_ALPHA = 0.5
local QUALITY_BORDER_KEY = "__NSkinCollectionQualityBorder"
local COLLECTION_ITEM_STATE = "collectionItems"
local FILTER_STATE = "collectionFilter"
local IDs = {
    AppearanceWindow = "Collections",
    Window = "Collections.Journal.Window",
    MainTabs = "Collections.MainTabs",
    ToyBox = {
        Scope = "Collections.ToyBox", Search = {
            Group = "Collections.ToyBox.SearchBox",
            Filter = "Collections.ToyBox.Filter",
        },
        Pagination = { Group = "Collections.ToyBox.Pagination",
            Previous = "Collections.ToyBox.Pagination.Previous",
            Next = "Collections.ToyBox.Pagination.Next",
            Text = "Collections.ToyBox.Pagination.Text" },
        ProgressBar = "Collections.ToyBox.ProgressBar",
    },
    Heirlooms = {
        Scope = "Collections.Heirlooms", Search = {
            Group = "Collections.Heirlooms.SearchBox",
            Filter = "Collections.Heirlooms.Filter",
            Class = "Collections.Heirlooms.ClassDropdown",
        },
        Pagination = { Group = "Collections.Heirlooms.Pagination",
            Previous = "Collections.Heirlooms.Pagination.Previous",
            Next = "Collections.Heirlooms.Pagination.Next",
            Text = "Collections.Heirlooms.Pagination.Text" },
        ProgressBar = "Collections.Heirlooms.ProgressBar",
    },
    Appearances = {
        Scope = "Collections.Appearances", TopTabs = "Collections.Appearances.TopTabs",
        Items = { Scope = "Collections.Appearances.Items", Search = {
            Group = "Collections.Appearances.Items.SearchBox",
            Filter = "Collections.Appearances.Items.Filter",
            Class = "Collections.Appearances.Items.ClassDropdown" },
            Pagination = { Group = "Collections.Appearances.Items.Pagination",
                Previous = "Collections.Appearances.Items.Pagination.Previous",
                Next = "Collections.Appearances.Items.Pagination.Next",
                Text = "Collections.Appearances.Items.Pagination.Text" },
            ProgressBar = "Collections.Appearances.Items.ProgressBar" },
    },
}
local WINDOW_BUTTON_TEXT_SIZE = 20

NSkin:RegisterAppearanceScope(IDs.AppearanceWindow, {
    label = "Collections",
})
NSkin:RegisterAppearanceScope(IDs.ToyBox.Scope, {
    label = "Toy Box", parent = IDs.AppearanceWindow,
})
NSkin:RegisterAppearanceScope(IDs.Heirlooms.Scope, {
    label = "Heirlooms", parent = IDs.AppearanceWindow,
})
NSkin:RegisterAppearanceScope(IDs.Appearances.Scope, {
    label = "Appearances", parent = IDs.AppearanceWindow,
})
NSkin:RegisterAppearanceScope(IDs.Appearances.Items.Scope, {
    label = "Appearances - Items", parent = IDs.Appearances.Scope,
})
local HEIRLOOM_QUALITY = _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Heirloom or 7
local Item = _G.C_Item
local COLLECTION_PROGRESS_BAR_STYLE = {
    stripArtwork = true,
    useAppearanceTexture = true,
    background = true,
}

local SkinCollectionsWindow
local ApplyCollectionsSkin
local State = {
    initialized = { Collections = false, ToyBox = false,
        Heirlooms = false, AppearanceTabs = false },
    Main = { tabs = nil },
    ToyBox = { paginationController = nil, searchController = nil,
        groupedAnchor = nil },
    Heirlooms = { paginationController = nil, searchController = nil,
        groupedAnchor = nil },
    Appearances = { Items = { paginationController = nil,
        searchController = nil, groupedAnchor = nil } },
    menu = { hooked = false, owners = setmetatable({}, { __mode = "k" }),
        activeDropdown = nil, activeMenu = nil },
}
local Adapters = {
    ToyBox = { scopeID = IDs.ToyBox.Scope, state = State.ToyBox },
    Heirlooms = { scopeID = IDs.Heirlooms.Scope,
        state = State.Heirlooms },
    AppearanceItems = { scopeID = IDs.Appearances.Items.Scope,
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
    adapter.RefreshAppearance = adapter.ApplySkin
end

local function SkinFilterMenuFrame(menu)
    if not menu or not menu.GetRegions then return end

    if menu == State.menu.activeMenu and State.menu.activeDropdown then
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", State.menu.activeDropdown, "BOTTOMLEFT", 0, 0)
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
    if State.menu.hooked or not _G.Menu or type(_G.Menu.GetManager) ~= "function" then return end
    local manager = _G.Menu.GetManager()
    if not manager or type(manager.OpenMenu) ~= "function" then return end

    hooksecurefunc(manager, "OpenMenu", function(self, ownerRegion)
        if not State.menu.owners[ownerRegion] then return end
        local menu = self:GetOpenMenu()
        if not menu then return end
        State.menu.activeDropdown = ownerRegion
        State.menu.activeMenu = menu

        -- Defer until Blizzard has finished constructing the generated menu
        -- regions; this is ordering, not a timing or taint boundary.
        C_Timer.After(0, function()
            if menu:IsShown() then SkinFilterMenu(menu) end
        end)
    end)

    if _G.MenuStyle1Mixin and type(_G.MenuStyle1Mixin.Generate) == "function" then
        hooksecurefunc(_G.MenuStyle1Mixin, "Generate", function(menu)
            local root = State.menu.activeMenu
            if not root or not root:IsShown() or menu == root then return end

            -- Submenus bypass MenuManager:OpenMenu. Style their generated
            -- frame only while the tracked Collections dropdown is still open.
            C_Timer.After(0, function()
                if root:IsShown() and menu:IsShown() then SkinFilterMenu(menu) end
            end)
        end)
    end
    State.menu.hooked = true
end

local function SkinCollectionDropdownButton(button, fallbackLabel, preserveText)
    if not button then return end
    State.menu.owners[button] = true
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
    if not searchBox or not filterDropdown or not State.ToyBox.groupedAnchor then return false end
    if filterDropdown.IsProtected and filterDropdown:IsProtected() then return false end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    filterDropdown:ClearAllPoints()
    filterDropdown:SetPoint(State.ToyBox.groupedAnchor.point, searchBox,
        State.ToyBox.groupedAnchor.relativePoint, State.ToyBox.groupedAnchor.x,
        State.ToyBox.groupedAnchor.y)
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
    if not searchBox or not filterDropdown or not State.Heirlooms.groupedAnchor then
        return false
    end
    if filterDropdown.IsProtected and filterDropdown:IsProtected() then return false end
    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
    filterDropdown:ClearAllPoints()
    filterDropdown:SetPoint(State.Heirlooms.groupedAnchor.point, searchBox,
        State.Heirlooms.groupedAnchor.relativePoint, State.Heirlooms.groupedAnchor.x,
        State.Heirlooms.groupedAnchor.y)
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
    if State.Main.tabs then return State.Main.tabs end
    State.Main.tabs = {
        journal.MountsTab,
        journal.PetsTab,
        journal.ToysTab,
        journal.HeirloomsTab,
        journal.WardrobeTab,
        journal.WarbandScenesTab,
    }
    return State.Main.tabs
end

local function SkinCollectionTabs(selectedTab)
    local journal = _G.CollectionsJournal
    if not journal then return end

    selectedTab = selectedTab or (_G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(journal))
    local tabs = GetCollectionTabs(journal)
    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.AppearanceWindow, IDs.MainTabs)
    local borderColor = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.AppearanceWindow, IDs.MainTabs)
    for i = 1, #tabs do
        NSkin:SkinTab(tabs[i], i == selectedTab, style, borderColor)
    end
    if NSkin:GetTabGroup(IDs.MainTabs) then
        NSkin:ApplyTabGroupLayout(IDs.MainTabs)
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
        IDs.AppearanceWindow, IDs.Window)
    NSkin:SkinWindow(journal, nil, windowStyle,
        NSkin:GetAppearanceBorderColor("window", windowStyle,
            IDs.AppearanceWindow, IDs.Window))
    NSkin:SkinWindowHeader(journal, windowStyle.header)

    local title = journal.TitleContainer and journal.TitleContainer.TitleText
    if title then
        title:SetTextColor(unpack(
            NSkin:GetResolvedAppearanceColor(windowStyle.header, "text")))
        NSkin:ApplyResolvedTypography(title, windowStyle.header)
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
            "searchBox", IDs.ToyBox.Scope, IDs.ToyBox.Search.Group)
        NSkin:SkinSearchBox(searchBox, searchStyle,
            NSkin:GetAppearanceBorderColor("searchBox", searchStyle,
                IDs.ToyBox.Scope, IDs.ToyBox.Search.Group))
        SkinCollectionDropdownButton(filterDropdown, "Filter", false)
        if searchBox and filterDropdown then
            if not State.ToyBox.groupedAnchor then
                State.ToyBox.groupedAnchor = CaptureSearchAccessoryAnchor(
                    searchBox, filterDropdown)
            end
        end
        NSkin:SkinPagingControls(pagingGroup or toyBox)
        local progressBar = toyBox.ProgressBar or toyBox.progressBar
        NSkin:SkinProgressBar(progressBar, COLLECTION_PROGRESS_BAR_STYLE)
        RegisterCollectionMovableElement(
            IDs.ToyBox.ProgressBar, IDs.ToyBox.Scope,
            "Toy Box progress bar", journal, progressBar, 80,
            nil, nil, function()
                return toyBox:IsVisible() and progressBar:IsVisible()
            end
        )
        if not State.ToyBox.searchController then
            State.ToyBox.searchController = NSkin:RegisterAccessoryGroup({
                module = "Collections",
                appearanceWindowID = IDs.ToyBox.Scope,
                window = journal,
                ids = { primary = IDs.ToyBox.Search.Group,
                    accessory = IDs.ToyBox.Search.Filter },
                primary = searchBox, accessory = filterDropdown,
                primaryLabel = "Toy Box search bar", accessoryLabel = "Toy Box filter",
                primaryPriority = 81, accessoryPriority = 91,
                legacyOptionKey = "searchAccessoryMode",
                visibilityFrame = toyBox,
                anchorGrouped = AnchorToySearchAccessory,
            })
        else
            State.ToyBox.searchController:Refresh()
        end
        if not State.ToyBox.paginationController then
            State.ToyBox.paginationController = NSkin:RegisterPaginationGroup({
                module = "Collections",
                appearanceWindowID = IDs.ToyBox.Scope,
                window = journal,
                ids = { group = IDs.ToyBox.Pagination.Group,
                    previous = IDs.ToyBox.Pagination.Previous, next = IDs.ToyBox.Pagination.Next,
                    text = IDs.ToyBox.Pagination.Text },
                controls = { group = pagingGroup, previous = previousPage,
                    next = nextPage, text = pageText },
                groupLabel = "Toy Box pagination", groupPriority = 82,
                legacySeparateOptionKey = "separatePaginationButtons",
                legacyTextOptionKey = "paginationTextMode",
                visibilityFrame = toyBox,
            })
        else
            State.ToyBox.paginationController:Refresh()
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
            "searchBox", IDs.Heirlooms.Scope, IDs.Heirlooms.Search.Group)
        NSkin:SkinSearchBox(searchBox, searchStyle,
            NSkin:GetAppearanceBorderColor("searchBox", searchStyle,
                IDs.Heirlooms.Scope, IDs.Heirlooms.Search.Group))
        SkinCollectionDropdownButton(filterDropdown, "Filter", false)
        SkinCollectionDropdownButton(classDropdown, "Class/spec", true)
        if searchBox and filterDropdown then
            if not State.Heirlooms.groupedAnchor then
                State.Heirlooms.groupedAnchor = CaptureSearchAccessoryAnchor(
                    searchBox, filterDropdown)
            end
        end
        NSkin:SkinPagingControls(pagingGroup or heirlooms)
        NSkin:SkinProgressBar(progressBar, COLLECTION_PROGRESS_BAR_STYLE)
        RegisterCollectionMovableElement(
            IDs.Heirlooms.Search.Class, IDs.Heirlooms.Scope,
            "Heirlooms class/spec filter", journal, classDropdown, 79)
        RegisterCollectionMovableElement(
            IDs.Heirlooms.ProgressBar, IDs.Heirlooms.Scope,
            "Heirlooms progress bar", journal, progressBar, 80,
            nil, nil, function()
                return heirlooms:IsVisible() and progressBar:IsVisible()
            end)
        if not State.Heirlooms.searchController then
            State.Heirlooms.searchController = NSkin:RegisterAccessoryGroup({
                module = "Collections",
                appearanceWindowID = IDs.Heirlooms.Scope,
                window = journal,
                ids = { primary = IDs.Heirlooms.Search.Group,
                    accessory = IDs.Heirlooms.Search.Filter },
                primary = searchBox, accessory = filterDropdown,
                primaryLabel = "Heirlooms search bar",
                accessoryLabel = "Heirlooms filter",
                primaryPriority = 81, accessoryPriority = 91,
                visibilityFrame = heirlooms,
                anchorGrouped = AnchorHeirloomSearchAccessory,
            })
        else
            State.Heirlooms.searchController:Refresh()
        end
        if not State.Heirlooms.paginationController then
            State.Heirlooms.paginationController = NSkin:RegisterPaginationGroup({
                module = "Collections",
                appearanceWindowID = IDs.Heirlooms.Scope,
                window = journal,
                ids = { group = IDs.Heirlooms.Pagination.Group,
                    previous = IDs.Heirlooms.Pagination.Previous,
                    next = IDs.Heirlooms.Pagination.Next,
                    text = IDs.Heirlooms.Pagination.Text },
                controls = { group = pagingGroup, previous = previousPage,
                    next = nextPage, text = pageText },
                groupLabel = "Heirlooms pagination", groupPriority = 82,
                visibilityFrame = heirlooms,
            })
        else
            State.Heirlooms.paginationController:Refresh()
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
            "tab", IDs.Appearances.Items.Scope, IDs.Appearances.TopTabs)
        local tabBorder = NSkin:GetAppearanceBorderColor(
            "tab", tabStyle, IDs.Appearances.Items.Scope,
            IDs.Appearances.TopTabs)
        for i = 1, #topTabs do
            NSkin:SkinTab(topTabs[i], i == selectedTab, tabStyle, tabBorder)
        end
        if not State.initialized.AppearanceTabs then
            State.initialized.AppearanceTabs = NSkin:RegisterTabGroup(
                IDs.Appearances.TopTabs, {
                    module = "Collections",
                    appearanceWindowID = IDs.Appearances.Items.Scope,
                    label = "Appearances top tabs",
                    window = journal,
                    target = wardrobe,
                    tabs = topTabs,
                    priority = 60,
                    orientation = "HORIZONTAL",
                    edge = "TOP",
                    isEditable = function() return wardrobe:IsVisible() end,
                }) == true
        elseif NSkin:GetTabGroup(IDs.Appearances.TopTabs) then
            NSkin:ApplyTabGroupLayout(IDs.Appearances.TopTabs)
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
            "searchBox", IDs.Appearances.Items.Scope, IDs.Appearances.Items.Search.Group)
        NSkin:SkinSearchBox(searchBox, searchStyle,
            NSkin:GetAppearanceBorderColor("searchBox", searchStyle,
                IDs.Appearances.Items.Scope, IDs.Appearances.Items.Search.Group))
        SkinCollectionDropdownButton(filterDropdown, "Filter", false)
        SkinCollectionDropdownButton(classDropdown, "Class/spec", true)
        SkinCollectionDropdownButton(weaponDropdown, "Weapon", true)
        if searchBox and filterDropdown then
            if not State.Appearances.Items.groupedAnchor then
                State.Appearances.Items.groupedAnchor = CaptureSearchAccessoryAnchor(
                    searchBox, filterDropdown)
            end
        end
        NSkin:SkinProgressBar(progressBar, COLLECTION_PROGRESS_BAR_STYLE)
        NSkin:SkinPagingControls(pagingGroup or itemsFrame)
        RegisterCollectionMovableElement(
            IDs.Appearances.Items.Search.Class, IDs.Appearances.Items.Scope,
            "Appearances class/spec filter", journal, classDropdown, 79,
            nil, nil, function()
                return itemsFrame:IsVisible() and classDropdown:IsVisible()
            end)
        RegisterCollectionMovableElement(
            IDs.Appearances.Items.ProgressBar, IDs.Appearances.Items.Scope,
            "Appearances progress bar", journal, progressBar, 81,
            nil, nil, function()
                return itemsFrame:IsVisible() and progressBar:IsVisible()
            end)
        if not State.Appearances.Items.searchController then
            State.Appearances.Items.searchController = NSkin:RegisterAccessoryGroup({
                module = "Collections",
                appearanceWindowID = IDs.Appearances.Items.Scope,
                window = journal,
                ids = { primary = IDs.Appearances.Items.Search.Group,
                    accessory = IDs.Appearances.Items.Search.Filter },
                primary = searchBox, accessory = filterDropdown,
                primaryLabel = "Appearances search bar",
                accessoryLabel = "Appearances filter",
                primaryPriority = 82, accessoryPriority = 92,
                visibilityFrame = itemsFrame,
                anchorGrouped = function(primary, accessory)
                    if not State.Appearances.Items.groupedAnchor then return false end
                    if accessory.IsProtected and accessory:IsProtected() then return false end
                    if _G.InCombatLockdown and _G.InCombatLockdown() then return false end
                    accessory:ClearAllPoints()
                    accessory:SetPoint(State.Appearances.Items.groupedAnchor.point, primary,
                        State.Appearances.Items.groupedAnchor.relativePoint,
                        State.Appearances.Items.groupedAnchor.x,
                        State.Appearances.Items.groupedAnchor.y)
                    return true
                end,
            })
        else
            State.Appearances.Items.searchController:Refresh()
        end
        if not State.Appearances.Items.paginationController then
            State.Appearances.Items.paginationController = NSkin:RegisterPaginationGroup({
                module = "Collections",
                appearanceWindowID = IDs.Appearances.Items.Scope,
                window = journal,
                ids = { group = IDs.Appearances.Items.Pagination.Group,
                    previous = IDs.Appearances.Items.Pagination.Previous,
                    next = IDs.Appearances.Items.Pagination.Next,
                    text = IDs.Appearances.Items.Pagination.Text },
                controls = { group = pagingGroup, previous = previousPage,
                    next = nextPage, text = pageText },
                groupLabel = "Appearances pagination", groupPriority = 83,
                visibilityFrame = itemsFrame,
            })
        else
            State.Appearances.Items.paginationController:Refresh()
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
    if not State.initialized.ToyBox and iconsFrame
        and type(_G.ToySpellButton_UpdateButton) == "function"
    then
        _G.hooksecurefunc("ToySpellButton_UpdateButton", SkinCollectionButton)
        State.initialized.ToyBox = true
        for i = 1, TOYS_PER_PAGE do
            SkinCollectionButton(iconsFrame["spellButton" .. i])
        end
    end
    local heirloomsJournal = _G.HeirloomsJournal
    if not State.initialized.Heirlooms and heirloomsJournal
        and type(heirloomsJournal.UpdateButton) == "function"
    then
        _G.hooksecurefunc(heirloomsJournal, "UpdateButton", function(_, button)
            SkinCollectionButton(button, HEIRLOOM_QUALITY)
        end)
        State.initialized.Heirlooms = true
        for i = 1, #(heirloomsJournal.heirloomEntryFrames or {}) do
            SkinCollectionButton(
                heirloomsJournal.heirloomEntryFrames[i], HEIRLOOM_QUALITY)
        end
    end
end

function CollectionSkin:Initialize()
    if State.initialized.Collections then
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

    if not State.initialized.Collections then
        NSkin:RegisterTabGroup(IDs.MainTabs, {
            module = "Collections",
            appearanceWindowID = IDs.AppearanceWindow,
            label = "Collections tabs",
            kind = "TAB_GROUP",
            window = journal,
            target = journal,
            tabs = GetCollectionTabs(journal),
            priority = 50,
            orientation = "HORIZONTAL",
            edge = "BOTTOM",
        })
        NSkin:RegisterSkinningElement(IDs.Window, {
            module = "Collections",
            appearanceWindowID = IDs.AppearanceWindow,
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
        State.initialized.Collections = true
        ApplyCollectionsSkin()
        RemoveCollectionPageBackgrounds()
    end

    self:InitializeOptionalAdapters()
    return State.initialized.Collections
end

function CollectionSkin:RefreshAppearance()
    if not State.initialized.Collections then return end
    SkinCollectionsWindow("Main")
    for i = 1, #ACTIVE_ADAPTERS do
        local adapter = ACTIVE_ADAPTERS[i]
        if adapter:IsAvailable() then adapter:RefreshAppearance() end
    end
    local iconsFrame = _G.ToyBox and _G.ToyBox.iconsFrame
    if State.initialized.ToyBox and iconsFrame then
        for i = 1, TOYS_PER_PAGE do
            SkinCollectionButton(iconsFrame["spellButton" .. i])
        end
    end
    local heirloomsJournal = _G.HeirloomsJournal
    if State.initialized.Heirlooms and heirloomsJournal then
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
