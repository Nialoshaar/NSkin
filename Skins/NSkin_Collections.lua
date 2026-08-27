local _, NSkin = ...

local CollectionSkin = NSkin:NewModule("Collections")

local TOYS_PER_PAGE = 18
local BORDER_SIZE = 1
local UNCOLLECTED_ICON_ALPHA = 0.5
local QUALITY_BORDER_KEY = "__NSkinCollectionQualityBorder"
local COLLECTION_ITEM_STATE = "collectionItems"
local FILTER_STATE = "collectionFilter"
local TOY_PROGRESS_ELEMENT_ID = "Collections.ToyBox.ProgressBar"
local TOY_SEARCH_ELEMENT_ID = "Collections.ToyBox.SearchBox"
local TOY_PAGINATION_ELEMENT_ID = "Collections.ToyBox.Pagination"
local TOY_PREVIOUS_ELEMENT_ID = "Collections.ToyBox.Pagination.Previous"
local TOY_NEXT_ELEMENT_ID = "Collections.ToyBox.Pagination.Next"
local TOY_PAGE_TEXT_ELEMENT_ID = "Collections.ToyBox.Pagination.Text"
local WINDOW_BUTTON_TEXT_SIZE = 20
local HEIRLOOM_QUALITY = _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Heirloom or 7
local Item = _G.C_Item

local collectionsInitialized = false
local toysInitialized = false
local heirloomsInitialized = false
local toyMovablesRegistered = {}
local toyPaginationWatcher
local collectionTabs
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

        -- Leave Blizzard's protected menu construction before changing any
        -- generated regions. This zero-delay dispatch is a taint boundary,
        -- not a timing gate.
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

local function AnchorToyPaginationHighlight(element, overlay)
    local paging = element and element.target
    local pageText = paging and (paging.PageText or paging.pageText)
    local previous = paging and (paging.PrevPageButton or paging.prevPageButton)
    local nextPage = paging and (paging.NextPageButton or paging.nextPageButton)
    if not pageText or not previous or not nextPage then return false end
    overlay:SetPoint("LEFT", pageText, "LEFT", 0, 0)
    overlay:SetPoint("RIGHT", nextPage, "RIGHT", 0, 0)
    overlay:SetPoint("TOP", previous, "TOP", 0, 0)
    overlay:SetPoint("BOTTOM", previous, "BOTTOM", 0, 0)
    return true
end

local function GetToyPaginationSeparateButtons()
    local options = NSkin:GetModuleOptions("Collections", false)
    return options and options.separatePaginationButtons == true or false
end

local function GetToyPaginationTextMode()
    local options = NSkin:GetModuleOptions("Collections", false)
    return options and options.paginationTextMode or "GROUPED"
end

local function RefreshToyPaginationElements()
    local paging = _G.ToyBox and _G.ToyBox.PagingFrame
    local pageText = paging and (paging.PageText or paging.pageText)
    if pageText then pageText:SetShown(GetToyPaginationTextMode() ~= "HIDDEN") end
    local function ApplyMode(id, independent)
        local element = NSkin:GetSkinningElement(id)
        if not element then return end
        local saved = NSkin:GetSavedMovableElementPlacement(id)
        if independent and saved then
            NSkin:LayoutWindowElement(element, saved)
        elseif not independent then
            NSkin:RestoreMovableElementOriginal(element, true)
        end
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    ApplyMode(TOY_PREVIOUS_ELEMENT_ID, GetToyPaginationSeparateButtons())
    ApplyMode(TOY_NEXT_ELEMENT_ID, GetToyPaginationSeparateButtons())
    ApplyMode(TOY_PAGE_TEXT_ELEMENT_ID, GetToyPaginationTextMode() == "INDEPENDENT")
    NSkin:NotifySkinningElementBoundsChanged(TOY_PAGINATION_ELEMENT_ID)
end

local function EnsureToyPaginationWatcher()
    local toyBox = _G.ToyBox
    if not toyBox then return end
    if not toyPaginationWatcher then
        toyPaginationWatcher = CreateFrame("Frame", nil, toyBox)
        toyPaginationWatcher:Hide()
        toyPaginationWatcher:SetScript("OnShow", RefreshToyPaginationElements)
    end
    toyPaginationWatcher:Show()
end

local function SetToyPaginationSeparateButtons(value)
    local options = NSkin:GetModuleOptions("Collections", true)
    options.separatePaginationButtons = value == true and true or nil
    if options.separatePaginationButtons or options.paginationTextMode then
        EnsureToyPaginationWatcher()
    elseif toyPaginationWatcher then
        toyPaginationWatcher:Hide()
    end
    RefreshToyPaginationElements()
    return true
end

local function SetToyPaginationTextMode(mode)
    if mode ~= "GROUPED" and mode ~= "INDEPENDENT" and mode ~= "HIDDEN" then return false end
    local options = NSkin:GetModuleOptions("Collections", true)
    options.paginationTextMode = mode == "GROUPED" and nil or mode
    if options.separatePaginationButtons or options.paginationTextMode then
        EnsureToyPaginationWatcher()
    elseif toyPaginationWatcher then
        toyPaginationWatcher:Hide()
    end
    RefreshToyPaginationElements()
    return true
end

local function ConfigureToyPaginationElement(element)
    if not element then return end
    element.getPaginationSeparateButtons = GetToyPaginationSeparateButtons
    element.setPaginationSeparateButtons = function(_, value)
        return SetToyPaginationSeparateButtons(value)
    end
    element.getPaginationTextMode = GetToyPaginationTextMode
    element.setPaginationTextMode = function(_, mode)
        return SetToyPaginationTextMode(mode)
    end
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
        label = label,
        window = journal,
        target = target,
        editorOptions = editorOptions or "shared.movable",
        defaultPlacement = placement,
        priority = priority or 80,
        anchorHighlight = anchorHighlight,
        isEditable = isEditable,
    }) == true
    return NSkin:GetSkinningElement(id)
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
    local style = NSkin:GetStyle("tab")
    for i = 1, #tabs do
        NSkin:SkinTab(tabs[i], i == selectedTab, style)
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
    SkinCollectionTabs(selectedTab)
end

local function SkinCollectionsWindow()
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

    NSkin:SkinWindow(journal)
    NSkin:SkinWindowHeader(journal)

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
        NSkin:SkinSearchBox(searchBox)
        SkinToyFilterButton(filterDropdown)
        if searchBox and filterDropdown then
            filterDropdown:SetHeight(searchBox:GetHeight())
        end
        NSkin:SkinPagingControls(pagingControls or toyBox)
        local progressBar = toyBox.ProgressBar or toyBox.progressBar
        NSkin:SkinProgressBar(progressBar)
        RegisterToyMovableElement(
            TOY_PROGRESS_ELEMENT_ID, "Toy Box progress bar", journal, progressBar, 80
        )
        RegisterToyMovableElement(
            TOY_SEARCH_ELEMENT_ID, "Toy Box search bar", journal, searchBox, 81
        )
        local paginationElement = RegisterToyMovableElement(
            TOY_PAGINATION_ELEMENT_ID, "Toy Box pagination", journal, pagingControls, 82,
            AnchorToyPaginationHighlight, "shared.pagination"
        )
        local previousElement = RegisterToyMovableElement(
            TOY_PREVIOUS_ELEMENT_ID, "Previous page button", journal,
            pagingControls and (pagingControls.PrevPageButton
                or pagingControls.prevPageButton), 90, nil, "shared.pagination",
            GetToyPaginationSeparateButtons
        )
        local nextElement = RegisterToyMovableElement(
            TOY_NEXT_ELEMENT_ID, "Next page button", journal,
            pagingControls and (pagingControls.NextPageButton
                or pagingControls.nextPageButton), 90, nil, "shared.pagination",
            GetToyPaginationSeparateButtons
        )
        local textElement = RegisterToyMovableElement(
            TOY_PAGE_TEXT_ELEMENT_ID, "Page text", journal,
            pagingControls and (pagingControls.PageText or pagingControls.pageText),
            100, nil, "shared.pagination",
            function() return GetToyPaginationTextMode() == "INDEPENDENT" end
        )
        ConfigureToyPaginationElement(paginationElement)
        ConfigureToyPaginationElement(previousElement)
        ConfigureToyPaginationElement(nextElement)
        ConfigureToyPaginationElement(textElement)
        local paginationOptions = NSkin:GetModuleOptions("Collections", false)
        if paginationOptions and (paginationOptions.separatePaginationButtons
            or paginationOptions.paginationTextMode)
        then
            EnsureToyPaginationWatcher()
        end
        RefreshToyPaginationElements()
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

    if data.qualityItemID ~= itemID then
        local quality = knownQuality or Item.GetItemQualityByID(itemID)
        if not NSkin:SetQualityBorder(border, quality) then return end

        data.qualityItemID = itemID
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

function CollectionSkin:Initialize()
    if collectionsInitialized and toysInitialized and heirloomsInitialized then return true end
    if not NSkin:IsModuleEnabled("Collections") then return false end

    if not _G.hooksecurefunc then return false end

    local journal = _G.CollectionsJournal
    local toyBox = _G.ToyBox
    local iconsFrame = toyBox and toyBox.iconsFrame
    local canSkinToys = iconsFrame and type(_G.ToySpellButton_UpdateButton) == "function"
    local heirloomsJournal = _G.HeirloomsJournal
    local canSkinHeirlooms = heirloomsJournal
        and type(heirloomsJournal.UpdateButton) == "function"
    local canSkinCollections = journal
        and type(_G.PanelTemplates_GetSelectedTab) == "function"
        and _G.EventRegistry
        and type(_G.EventRegistry.RegisterCallback) == "function"
    if not canSkinCollections or (not canSkinToys and not canSkinHeirlooms) then return false end

    if not collectionsInitialized then
        NSkin:RegisterTabGroup(TAB_GROUP_ID, {
            module = "Collections",
            label = "Collections tabs",
            kind = "TAB_GROUP",
            editorOptions = "tabs.layout",
            window = journal,
            target = journal,
            tabs = GetCollectionTabs(journal),
            priority = 50,
            orientation = "HORIZONTAL",
            edge = "BOTTOM",
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

    if canSkinToys and not toysInitialized then
        _G.hooksecurefunc("ToySpellButton_UpdateButton", SkinCollectionButton)
        toysInitialized = true
        for i = 1, TOYS_PER_PAGE do
            SkinCollectionButton(iconsFrame["spellButton" .. i])
        end
    end

    if canSkinHeirlooms and not heirloomsInitialized then
        _G.hooksecurefunc(heirloomsJournal, "UpdateButton", function(_, button)
            SkinCollectionButton(button, HEIRLOOM_QUALITY)
        end)
        heirloomsInitialized = true
    end

    return collectionsInitialized and toysInitialized and heirloomsInitialized
end

function CollectionSkin:RefreshTheme()
    if collectionsInitialized then SkinCollectionsWindow() end
end

NSkin:RegisterWindowSkin({
    module = "Collections",
    addon = "Blizzard_Collections",
    apply = function() return CollectionSkin:Initialize() end,
})
