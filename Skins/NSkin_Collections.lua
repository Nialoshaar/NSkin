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
local COLLECTIONS_APPEARANCE_WINDOW_ID = "Collections.Journal"
local TOY_APPEARANCE_WINDOW_ID = "Collections.ToyBox"
local TOY_SEARCH_ELEMENT_ID = "Collections.ToyBox.SearchBox"
local TOY_FILTER_ELEMENT_ID = "Collections.ToyBox.Filter"
local TOY_PAGINATION_ELEMENT_ID = "Collections.ToyBox.Pagination"
local TOY_PREVIOUS_ELEMENT_ID = "Collections.ToyBox.Pagination.Previous"
local TOY_NEXT_ELEMENT_ID = "Collections.ToyBox.Pagination.Next"
local TOY_PAGE_TEXT_ELEMENT_ID = "Collections.ToyBox.Pagination.Text"
local WINDOW_BUTTON_TEXT_SIZE = 20
local HEIRLOOM_QUALITY = _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Heirloom or 7
local Item = _G.C_Item
local TOY_PROGRESS_BAR_STYLE = {
    height = 16,
    stripArtwork = true,
    useThemeTexture = true,
    background = true,
    centerText = true,
    textOffsetY = 1,
}

local collectionsInitialized = false
local toysInitialized = false
local heirloomsInitialized = false
local toyMovablesRegistered = {}
local toyPaginationController
local toySearchController
local toySearchGroupedAnchor
local collectionTabs
local SkinCollectionsWindow
local filterMenuHooked = false
local toyFilterDropdown
local toyFilterMenu
local collectionTabLayout = {
    orientation = "HORIZONTAL",
    edge = "BOTTOM",
}
local TAB_GROUP_ID = "Collections.MainTabs"

local function SkinFilterMenuFrame(menu)
    if not menu or not menu.GetRegions then return end

    if menu == toyFilterMenu and toyFilterDropdown then
        menu:ClearAllPoints()
        menu:SetPoint("TOPLEFT", toyFilterDropdown, "BOTTOMLEFT", 0, 0)
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
        if ownerRegion ~= toyFilterDropdown then return end
        local menu = self:GetOpenMenu()
        if not menu then return end
        toyFilterMenu = menu

        -- Defer until Blizzard has finished constructing the generated menu
        -- regions; this is ordering, not a timing or taint boundary.
        C_Timer.After(0, function()
            if menu:IsShown() then SkinFilterMenu(menu) end
        end)
    end)

    if _G.MenuStyle1Mixin and type(_G.MenuStyle1Mixin.Generate) == "function" then
        hooksecurefunc(_G.MenuStyle1Mixin, "Generate", function(menu)
            local root = toyFilterMenu
            if not root or not root:IsShown() or menu == root then return end

            -- Submenus bypass MenuManager:OpenMenu. Style their generated
            -- frame only while the Toy Box filter root is still open.
            C_Timer.After(0, function()
                if root:IsShown() and menu:IsShown() then SkinFilterMenu(menu) end
            end)
        end)
    end
    filterMenuHooked = true
end

local function SkinToyFilterButton(button)
    if not button then return end
    toyFilterDropdown = button
    NSkin:SkinFlatButton(button, "Filter", nil, nil, 12)

    if button.Background then button.Background:SetAlpha(0) end
    if button.Arrow then button.Arrow:SetAlpha(0) end
    if button.Text then button.Text:SetAlpha(0) end

    local data = NSkin:GetSkinData(button, FILTER_STATE)
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

local function RegisterToyMovableElement(id, label, journal, target, priority,
    anchorHighlight, editorOptions, isEditable)
    if toyMovablesRegistered[id] or not journal or not target then return end

    local windowLeft, windowTop = journal:GetLeft(), journal:GetTop()
    local targetLeft, targetTop = target:GetLeft(), target:GetTop()
    local placement
    if windowLeft and windowTop and targetLeft and targetTop then
        placement = {
            mode = "GRID",
            point = "TOPLEFT",
            relativePoint = "TOPLEFT",
            x = targetLeft - windowLeft,
            y = targetTop - windowTop,
        }
    else
        placement = {
            edge = "TOP",
            side = "INSIDE",
            alignment = "CENTER",
            alongOffset = 0,
            edgeOffset = -46,
        }
    end

    toyMovablesRegistered[id] = NSkin:RegisterMovableElement({
        id = id,
        module = "Collections",
        appearanceWindowID = TOY_APPEARANCE_WINDOW_ID,
        label = label,
        window = journal,
        target = target,
        editorOptions = editorOptions,
        defaultPlacement = placement,
        priority = priority or 80,
        anchorHighlight = anchorHighlight,
        isEditable = isEditable,
    }) == true
    return NSkin:GetSkinningElement(id)
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
    else
        collectionTabLayout.owner = journal
        NSkin:LayoutTabGroup(tabs, collectionTabLayout)
    end
end

function CollectionSkin:OnTabSet(_, selectedTab)
    SkinCollectionTabs(selectedTab)
    RemoveCollectionPageBackgrounds()
end

function CollectionSkin:OnShow(selectedTab)
    self:InitializeOptionalAdapters()
    SkinCollectionsWindow()
end

SkinCollectionsWindow = function()
    local journal = _G.CollectionsJournal
    if not journal then return end

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
    if title then title:SetTextColor(unpack(NSkin:GetStyle("button").text)) end

    local closeButton = journal.CloseButton
    NSkin:SkinFlatButton(closeButton, "x", nil, nil, WINDOW_BUTTON_TEXT_SIZE)
    if closeButton then
        closeButton:SetSize(22, 22)
        closeButton:ClearAllPoints()
        closeButton:SetPoint("TOPRIGHT", journal, "TOPRIGHT", 0, 0)
    end

    SkinCollectionTabs()

    local toyBox = _G.ToyBox
    if toyBox then
        local searchBox = toyBox.SearchBox or toyBox.searchBox
        local filterDropdown = toyBox.FilterDropdown
        local pagingControls = toyBox.PagingControls or toyBox.PagingFrame
            or toyBox.pagingFrame
        local searchStyle = NSkin:GetAppearanceStyle(
            "searchBox", TOY_APPEARANCE_WINDOW_ID, TOY_SEARCH_ELEMENT_ID)
        NSkin:SkinSearchBox(searchBox, searchStyle,
            NSkin:GetAppearanceBorderColor("searchBox", searchStyle,
                TOY_APPEARANCE_WINDOW_ID, TOY_SEARCH_ELEMENT_ID))
        SkinToyFilterButton(filterDropdown)
        if searchBox and filterDropdown then
            filterDropdown:SetHeight(searchBox:GetHeight())
            if not toySearchGroupedAnchor then
                local searchLeft, searchRight = searchBox:GetLeft(), searchBox:GetRight()
                local filterLeft, filterRight = filterDropdown:GetLeft(), filterDropdown:GetRight()
                local _, searchY = searchBox:GetCenter()
                local _, filterY = filterDropdown:GetCenter()
                if searchLeft and searchRight and filterLeft and filterRight
                    and searchY and filterY
                then
                    if filterRight <= searchLeft then
                        toySearchGroupedAnchor = { point = "RIGHT", relativePoint = "LEFT",
                            x = filterRight - searchLeft, y = filterY - searchY }
                    else
                        toySearchGroupedAnchor = { point = "LEFT", relativePoint = "RIGHT",
                            x = filterLeft - searchRight, y = filterY - searchY }
                    end
                end
            end
        end
        NSkin:SkinPagingControls(pagingControls or toyBox)
        local progressBar = toyBox.ProgressBar or toyBox.progressBar
        NSkin:SkinProgressBar(progressBar, TOY_PROGRESS_BAR_STYLE)
        RegisterToyMovableElement(
            TOY_PROGRESS_ELEMENT_ID, "Toy Box progress bar", journal, progressBar, 80
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
                controls = { group = pagingControls,
                    previous = pagingControls and (pagingControls.PrevPageButton
                        or pagingControls.prevPageButton),
                    next = pagingControls and (pagingControls.NextPageButton
                        or pagingControls.nextPageButton),
                    text = pagingControls and (pagingControls.PageText
                        or pagingControls.pageText) },
                groupLabel = "Toy Box pagination", groupPriority = 82,
                legacySeparateOptionKey = "separatePaginationButtons",
                legacyTextOptionKey = "paginationTextMode",
                visibilityFrame = toyBox,
            })
        else
            toyPaginationController:Refresh()
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
        SkinCollectionsWindow()
        RemoveCollectionPageBackgrounds()
    end

    self:InitializeOptionalAdapters()
    return collectionsInitialized
end

function CollectionSkin:RefreshTheme()
    if not collectionsInitialized then return end
    SkinCollectionsWindow()
    local iconsFrame = _G.ToyBox and _G.ToyBox.iconsFrame
    if toysInitialized and iconsFrame then
        for i = 1, TOYS_PER_PAGE do
            SkinCollectionButton(iconsFrame["spellButton" .. i])
        end
    end
end

NSkin:RegisterWindowSkin({
    module = "Collections",
    addon = "Blizzard_Collections",
    apply = function() return CollectionSkin:Initialize() end,
})
