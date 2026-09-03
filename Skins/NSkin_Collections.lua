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
    MountJournal = {
        Scope = "Collections.MountJournal", Search = {
            Group = "Collections.MountJournal.SearchBox",
            Filter = "Collections.MountJournal.Filter",
        },
        Mount = "Collections.MountJournal.MountButton",
    },
    PetJournal = {
        Scope = "Collections.PetJournal", Search = {
            Group = "Collections.PetJournal.SearchBox",
            Filter = "Collections.PetJournal.Filter",
        },
        Summon = "Collections.PetJournal.SummonButton",
        FindBattle = "Collections.PetJournal.FindBattleButton",
    },
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
    Campsites = {
        Scope = "Collections.Campsites",
        Pagination = { Group = "Collections.Campsites.Pagination",
            Previous = "Collections.Campsites.Pagination.Previous",
            Next = "Collections.Campsites.Pagination.Next",
            Text = "Collections.Campsites.Pagination.Text" },
    },
}
NSkin:RegisterAppearanceScope(IDs.AppearanceWindow, {
    label = "Collections",
})
NSkin:RegisterAppearanceScope(IDs.ToyBox.Scope, {
    label = "Toy Box", parent = IDs.AppearanceWindow,
})
NSkin:RegisterAppearanceScope(IDs.MountJournal.Scope, {
    label = "Mount Journal", parent = IDs.AppearanceWindow,
})
NSkin:RegisterAppearanceScope(IDs.PetJournal.Scope, {
    label = "Pet Journal", parent = IDs.AppearanceWindow,
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
NSkin:RegisterAppearanceScope(IDs.Campsites.Scope, {
    label = "Campsites", parent = IDs.AppearanceWindow,
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
    MountJournal = { searchController = nil, groupedAnchor = nil },
    PetJournal = { searchController = nil, groupedAnchor = nil },
    ToyBox = { paginationController = nil, searchController = nil,
        groupedAnchor = nil, backgroundHooked = false },
    Heirlooms = { paginationController = nil, searchController = nil,
        groupedAnchor = nil },
    Appearances = { Items = { paginationController = nil,
        searchController = nil, groupedAnchor = nil } },
    Campsites = { paginationController = nil },
    menu = { hooked = false, owners = setmetatable({}, { __mode = "k" }),
        activeDropdown = nil, activeMenu = nil },
}
local Adapters = {
    MountJournal = { scopeID = IDs.MountJournal.Scope,
        state = State.MountJournal },
    PetJournal = { scopeID = IDs.PetJournal.Scope,
        state = State.PetJournal },
    ToyBox = { scopeID = IDs.ToyBox.Scope, state = State.ToyBox },
    Heirlooms = { scopeID = IDs.Heirlooms.Scope,
        state = State.Heirlooms },
    AppearanceItems = { scopeID = IDs.Appearances.Items.Scope,
        state = State.Appearances.Items },
    Campsites = { scopeID = IDs.Campsites.Scope,
        state = State.Campsites },
}
local ACTIVE_ADAPTERS = {
    Adapters.MountJournal, Adapters.PetJournal, Adapters.ToyBox,
    Adapters.Heirlooms,
    Adapters.AppearanceItems,
    Adapters.Campsites,
}

function Adapters.ToyBox:IsAvailable() return _G.ToyBox ~= nil end
function Adapters.MountJournal:IsAvailable() return _G.MountJournal ~= nil end
function Adapters.PetJournal:IsAvailable() return _G.PetJournal ~= nil end
function Adapters.Heirlooms:IsAvailable() return _G.HeirloomsJournal ~= nil end
function Adapters.AppearanceItems:IsAvailable()
    return _G.WardrobeCollectionFrame
        and _G.WardrobeCollectionFrame.ItemsCollectionFrame
end
function Adapters.Campsites:IsAvailable()
    return _G.WarbandSceneJournal ~= nil
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
    journal, target, priority, anchorHighlight, editorOptions, isEditable, kind)
    if not journal or not target then return end
    return NSkin:RegisterSimpleMovableElement({
        id = id,
        module = "Collections",
        appearanceWindowID = appearanceWindowID,
        label = label,
        kind = kind,
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
        RemoveBackgroundFrame(scenes.IconsFrame)
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
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            NSkin:RefreshTabGroupBaseline(IDs.MainTabs, true)
        end)
    end
end

function CollectionSkin:OnShow(selectedTab)
    self:InitializeOptionalAdapters()
    NSkin:RefreshTabGroupBaseline(IDs.MainTabs, true)
    ApplyCollectionsSkin()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            NSkin:RefreshTabGroupBaseline(IDs.MainTabs, true)
        end)
    end
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

local function ResolveProgressBar(owner, candidate)
    local seen = {}
    local function Find(frame, depth)
        if not frame or seen[frame] then return nil end
        seen[frame] = true
        if frame.GetObjectType and frame:GetObjectType() == "StatusBar" then
            return frame
        end
        for _, key in ipairs({ "ProgressBar", "progressBar", "StatusBar",
            "statusBar", "Bar", "bar" }) do
            local child = frame[key]
            if child and child ~= frame then
                local found = Find(child, depth + 1)
                if found then return found end
            end
        end
        if depth < 2 and frame.GetChildren then
            for _, child in ipairs({ frame:GetChildren() }) do
                local found = Find(child, depth + 1)
                if found then return found end
            end
        end
    end
    return Find(candidate, 0) or Find(owner, 0)
end

SkinCollectionsWindow = function(adapterName)
    local journal = _G.CollectionsJournal
    if not journal then return end

    if not adapterName or adapterName == "Main" then
        NSkin:SkinStandardWindowChrome({
            frame = journal,
            appearanceWindowID = IDs.AppearanceWindow,
            elementID = IDs.Window,
        })
        SkinCollectionTabs()
    end

    local mountJournal = _G.MountJournal
    if mountJournal and (not adapterName or adapterName == "MountJournal") then
        local searchBox = mountJournal.searchBox or mountJournal.SearchBox
        local filterDropdown = mountJournal.FilterDropdown
        local mountButton = mountJournal.MountButton
        local searchStyle = NSkin:GetAppearanceStyle(
            "searchBox", IDs.MountJournal.Scope,
            IDs.MountJournal.Search.Group)
        NSkin:SkinSearchBox(searchBox, searchStyle,
            NSkin:GetAppearanceBorderColor("searchBox", searchStyle,
                IDs.MountJournal.Scope, IDs.MountJournal.Search.Group))
        SkinCollectionDropdownButton(filterDropdown, "Filter", false)
        NSkin:SkinActionButton(mountButton)
        if searchBox and filterDropdown
            and not State.MountJournal.groupedAnchor
        then
            State.MountJournal.groupedAnchor = CaptureSearchAccessoryAnchor(
                searchBox, filterDropdown)
        end
        RegisterCollectionMovableElement(
            IDs.MountJournal.Mount, IDs.MountJournal.Scope,
            "Mount Journal mount button", journal, mountButton, 82,
            nil, nil, function()
                return mountJournal:IsVisible() and mountButton:IsVisible()
            end, "ACTION_BUTTON")
        if not State.MountJournal.searchController then
            State.MountJournal.searchController = NSkin:RegisterAccessoryGroup({
                module = "Collections",
                appearanceWindowID = IDs.MountJournal.Scope,
                window = journal,
                ids = { primary = IDs.MountJournal.Search.Group,
                    accessory = IDs.MountJournal.Search.Filter },
                primary = searchBox, accessory = filterDropdown,
                primaryLabel = "Mount Journal search bar",
                accessoryLabel = "Mount Journal filter",
                primaryPriority = 80, accessoryPriority = 90,
                visibilityFrame = mountJournal,
                anchorGrouped = function(primary, accessory)
                    local anchor = State.MountJournal.groupedAnchor
                    if not anchor then return false end
                    if accessory.IsProtected and accessory:IsProtected() then
                        return false
                    end
                    if _G.InCombatLockdown and _G.InCombatLockdown() then
                        return false
                    end
                    accessory:ClearAllPoints()
                    accessory:SetPoint(anchor.point, primary,
                        anchor.relativePoint, anchor.x, anchor.y)
                    return true
                end,
            })
        else
            State.MountJournal.searchController:Refresh()
        end
    end

    local petJournal = _G.PetJournal
    if petJournal and (not adapterName or adapterName == "PetJournal") then
        local searchBox = petJournal.searchBox or petJournal.SearchBox
        local filterDropdown = petJournal.FilterDropdown
        local summonButton = petJournal.SummonButton
        local findBattleButton = petJournal.FindBattleButton
        local searchStyle = NSkin:GetAppearanceStyle(
            "searchBox", IDs.PetJournal.Scope, IDs.PetJournal.Search.Group)
        NSkin:SkinSearchBox(searchBox, searchStyle,
            NSkin:GetAppearanceBorderColor("searchBox", searchStyle,
                IDs.PetJournal.Scope, IDs.PetJournal.Search.Group))
        SkinCollectionDropdownButton(filterDropdown, "Filter", false)
        NSkin:SkinActionButton(summonButton)
        NSkin:SkinActionButton(findBattleButton)
        if searchBox and filterDropdown and not State.PetJournal.groupedAnchor then
            State.PetJournal.groupedAnchor = CaptureSearchAccessoryAnchor(
                searchBox, filterDropdown)
        end
        RegisterCollectionMovableElement(
            IDs.PetJournal.Summon, IDs.PetJournal.Scope,
            "Pet Journal summon button", journal, summonButton, 82,
            nil, nil, function()
                return petJournal:IsVisible() and summonButton:IsVisible()
            end, "ACTION_BUTTON")
        RegisterCollectionMovableElement(
            IDs.PetJournal.FindBattle, IDs.PetJournal.Scope,
            "Pet Journal find battle button", journal, findBattleButton, 83,
            nil, nil, function()
                return petJournal:IsVisible() and findBattleButton:IsVisible()
            end, "ACTION_BUTTON")
        if not State.PetJournal.searchController then
            State.PetJournal.searchController = NSkin:RegisterAccessoryGroup({
                module = "Collections",
                appearanceWindowID = IDs.PetJournal.Scope,
                window = journal,
                ids = { primary = IDs.PetJournal.Search.Group,
                    accessory = IDs.PetJournal.Search.Filter },
                primary = searchBox, accessory = filterDropdown,
                primaryLabel = "Pet Journal search bar",
                accessoryLabel = "Pet Journal filter",
                primaryPriority = 80, accessoryPriority = 90,
                visibilityFrame = petJournal,
                anchorGrouped = function(primary, accessory)
                    local anchor = State.PetJournal.groupedAnchor
                    if not anchor then return false end
                    if accessory.IsProtected and accessory:IsProtected() then
                        return false
                    end
                    if _G.InCombatLockdown and _G.InCombatLockdown() then
                        return false
                    end
                    accessory:ClearAllPoints()
                    accessory:SetPoint(anchor.point, primary,
                        anchor.relativePoint, anchor.x, anchor.y)
                    return true
                end,
            })
        else
            State.PetJournal.searchController:Refresh()
        end
    end

    local toyBox = _G.ToyBox
    if toyBox and (not adapterName or adapterName == "ToyBox") then
        RemoveBackgroundFrame(toyBox.iconsFrame)
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
        local progressBar = ResolveProgressBar(
            toyBox, toyBox.ProgressBar or toyBox.progressBar)
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
        local progressBar = ResolveProgressBar(
            heirlooms, heirlooms.progressBar or heirlooms.ProgressBar)
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
            "Heirlooms class/spec filter", journal, classDropdown, 79,
            nil, nil, function()
                return heirlooms:IsVisible() and classDropdown:IsVisible()
            end)
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
        local progressBar = ResolveProgressBar(
            wardrobe, wardrobe.progressBar or wardrobe.ProgressBar)
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

    local campsites = _G.WarbandSceneJournal
    if campsites and (not adapterName or adapterName == "Campsites") then
        local iconsFrame = campsites.IconsFrame or campsites.iconsFrame
        RemoveBackgroundFrame(iconsFrame)
        local icons = iconsFrame and iconsFrame.Icons
        local controls = icons and icons.Controls
        local pagingControls = controls and controls.PagingControls
        local pagingGroup, previousPage, nextPage, pageText =
            ResolvePagingControls(campsites, pagingControls)
        NSkin:SkinPagingControls(pagingGroup or pagingControls)
        if not State.Campsites.paginationController then
            State.Campsites.paginationController = NSkin:RegisterPaginationGroup({
                module = "Collections",
                appearanceWindowID = IDs.Campsites.Scope,
                window = journal,
                ids = { group = IDs.Campsites.Pagination.Group,
                    previous = IDs.Campsites.Pagination.Previous,
                    next = IDs.Campsites.Pagination.Next,
                    text = IDs.Campsites.Pagination.Text },
                controls = { group = pagingGroup, previous = previousPage,
                    next = nextPage, text = pageText },
                groupLabel = "Campsites pagination", groupPriority = 82,
                visibilityFrame = campsites,
            })
        else
            State.Campsites.paginationController:Refresh()
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
    RemoveCollectionPageBackgrounds()
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
    if iconsFrame and not State.ToyBox.backgroundHooked
        and type(_G.ToyBox_UpdateButtons) == "function"
    then
        _G.hooksecurefunc("ToyBox_UpdateButtons", function()
            RemoveBackgroundFrame(iconsFrame)
        end)
        State.ToyBox.backgroundHooked = true
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
            canCaptureBaseline = function()
                return journal:IsShown()
            end,
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
