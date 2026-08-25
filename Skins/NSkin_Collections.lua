local _, NSkin = ...

local CollectionSkin = NSkin:NewModule("Collections")

local TOYS_PER_PAGE = 18
local BORDER_SIZE = 1
local QUALITY_BORDER_KEY = "__NSkinCollectionQualityBorder"
local COLLECTION_ITEM_STATE = "collectionItems"
local WINDOW_BUTTON_TEXT_SIZE = 20
local HEIRLOOM_QUALITY = _G.Enum and _G.Enum.ItemQuality and _G.Enum.ItemQuality.Heirloom or 7
local Item = _G.C_Item

local collectionsInitialized = false
local toysInitialized = false
local heirloomsInitialized = false
local collectionTabs
local collectionTabLayout = {
    orientation = "HORIZONTAL",
    edge = "BOTTOM",
}
local TAB_GROUP_ID = "Collections.MainTabs"

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
        NSkin:RegisterEditableTabGroup(TAB_GROUP_ID, {
            label = "Collections tabs",
            owner = journal,
            tabs = GetCollectionTabs(journal),
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
