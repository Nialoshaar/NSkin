local _, NSkin = ...

local HousingDashboardSkin = NSkin:NewModule("HousingDashboard")

local IDs = {
    Scope = "HousingDashboard",
    Window = "HousingDashboard.Window",
    HeaderControls = "HousingDashboard.HeaderControls",
    HouseTabs = "HousingDashboard.HouseInfo.Tabs",
    SideTabs = "HousingDashboard.SideTabs",
    HouseDropdown = "HousingDashboard.HouseDropdown",
    HouseFinderButton = "HousingDashboard.HouseFinderButton",
    NoHouseButton = "HousingDashboard.NoHouseButton",
    WatchFavorCheckbox = "HousingDashboard.WatchFavorCheckbox",
    CatalogSearchBox = "HousingDashboard.Catalog.SearchBox",
    CatalogFilterDropdown = "HousingDashboard.Catalog.FilterDropdown",
    CatalogOptionsScrollBar = "HousingDashboard.Catalog.OptionsScrollBar",
    BlueprintCollectionScrollBar =
        "HousingDashboard.Collection.BlueprintCollectionScrollBar",
}

local initialized = false
local applyPending = false
local houseTabsRegistered = false
local registryCallbacksRegistered = false
local hookedOwners = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Housing Dashboard",
})

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        HousingDashboardSkin:Apply()
    end)
end

local function HookOwner(owner)
    if not owner or hookedOwners[owner] or not owner.HookScript then return end
    owner:HookScript("OnShow", QueueApply)
    hookedOwners[owner] = true
end

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function GetHouseInfo(frame)
    return frame and frame.HouseInfoContent
end

local function GetHouseInfoContent(frame)
    local houseInfo = GetHouseInfo(frame)
    return houseInfo and houseInfo.ContentFrame
end

local function GetWindowBackgroundOwner(frame)
    local data = NSkin:GetSkinData(frame, "components")
    local owner = data.housingDashboardBackgroundOwner
    if not owner then
        owner = CreateFrame("Frame", nil, UIParent)
        owner:SetAllPoints(frame)
        data.housingDashboardBackgroundOwner = owner
        frame:HookScript("OnShow", function()
            owner:Show()
        end)
        frame:HookScript("OnHide", function()
            owner:Hide()
        end)
    end
    owner:SetFrameStrata("BACKGROUND")
    owner:SetFrameLevel(0)
    owner:SetShown(frame:IsShown())
    return owner
end

function HousingDashboardSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
        -- Housing Dashboard mixes unusually low and high frame levels. Keep
        -- the flat surface outside that hierarchy so it cannot cover content.
        backgroundOwner = GetWindowBackgroundOwner(frame),
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Housing Dashboard window",
        kind = "WINDOW",
        module = "HousingDashboard",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function HousingDashboardSkin:ApplyHouseDropdown(frame)
    local dropdownContainer = frame and frame.HouseDropdown
    local dropdown = dropdownContainer and dropdownContainer.Dropdown
    if not dropdown then return false end

    NSkin:RegisterDropdown({
        id = IDs.HouseDropdown,
        module = "HousingDashboard",
        appearanceWindowID = IDs.Scope,
        label = "House selector",
        window = frame,
        target = dropdown,
        priority = 60,
        highlightRegions = { dropdown },
        isEditable = function()
            return IsVisible(frame) and IsVisible(dropdown)
        end,
    })
    HookOwner(dropdownContainer)
    return true
end

function HousingDashboardSkin:ApplyHouseTabs(frame)
    local content = GetHouseInfoContent(frame)
    local tabSystem = content and content.TabSystem
    local tabs = tabSystem and tabSystem.tabs
    if not tabs or #tabs == 0 then return false end

    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Scope, IDs.HouseTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, IDs.HouseTabs)
    for i = 1, #tabs do
        local tab = tabs[i]
        local selected = tab and tab.IsSelected and tab:IsSelected()
        NSkin:SkinTab(tab, selected, style, border)
        HookOwner(tab)
    end

    if not houseTabsRegistered then
        houseTabsRegistered = NSkin:RegisterTabGroup(IDs.HouseTabs, {
            label = "Housing Dashboard content tabs",
            module = "HousingDashboard",
            appearanceWindowID = IDs.Scope,
            window = frame,
            target = tabSystem,
            container = tabSystem,
            priority = 50,
            orientation = "HORIZONTAL",
            edge = "TOP",
            isEditable = function()
                return IsVisible(frame) and IsVisible(tabSystem)
            end,
        }) == true
    end
    if houseTabsRegistered then
        NSkin:ApplyTabGroupLayout(IDs.HouseTabs)
    end
    HookOwner(content)
    return true
end

function HousingDashboardSkin:ApplySideTabs(frame)
    if not frame then return false end
    local tabs = {
        frame.HouseInfoTabButton,
        frame.CatalogTabButton,
        frame.CollectionTabButton,
    }
    for i = 1, #tabs do
        if not tabs[i] then return false end
        HookOwner(tabs[i])
    end

    return NSkin:RegisterSideTabGroup(IDs.SideTabs, {
        module = "HousingDashboard",
        appearanceWindowID = IDs.Scope,
        label = "Housing Dashboard side tabs",
        window = frame,
        targets = tabs,
        priority = 55,
        isEditable = function()
            if not IsVisible(frame) then return false end
            for i = 1, #tabs do
                if IsVisible(tabs[i]) then return true end
            end
            return false
        end,
    }) ~= nil
end

function HousingDashboardSkin:ApplyHouseInfoControls(frame)
    local houseInfo = GetHouseInfo(frame)
    if not houseInfo then return false end

    local houseFinder = houseInfo.HouseFinderButton
    if houseFinder then
        NSkin:RegisterActionButton({
            id = IDs.HouseFinderButton,
            module = "HousingDashboard",
            appearanceWindowID = IDs.Scope,
            label = "Open House Finder button",
            window = frame,
            target = houseFinder,
            priority = 70,
            highlightRegions = { houseFinder },
            isEditable = function()
                return IsVisible(frame) and IsVisible(houseFinder)
            end,
        })
        HookOwner(houseFinder)
    end

    local noHouses = houseInfo.DashboardNoHousesFrame
    local noHouseButton = noHouses and noHouses.NoHouseButton
    if noHouseButton then
        NSkin:RegisterActionButton({
            id = IDs.NoHouseButton,
            module = "HousingDashboard",
            appearanceWindowID = IDs.Scope,
            label = "Find a house button",
            window = frame,
            target = noHouseButton,
            priority = 71,
            highlightRegions = { noHouseButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(noHouseButton)
            end,
        })
        HookOwner(noHouses)
    end

    local content = houseInfo.ContentFrame
    local upgrade = content and content.HouseUpgradeFrame
    local watchFavor = upgrade and upgrade.WatchFavorButton
    if watchFavor then
        NSkin:RegisterCheckbox({
            id = IDs.WatchFavorCheckbox,
            module = "HousingDashboard",
            appearanceWindowID = IDs.Scope,
            label = "Show as Experience Bar checkbox",
            window = frame,
            target = watchFavor,
            text = watchFavor.Label,
            priority = 72,
            highlightRegions = { watchFavor, watchFavor.Label },
            isEditable = function()
                return IsVisible(frame) and IsVisible(watchFavor)
            end,
        })
        HookOwner(upgrade)
    end
    return houseFinder ~= nil or noHouseButton ~= nil or watchFavor ~= nil
end

function HousingDashboardSkin:ApplyCatalogControls(frame)
    local catalog = frame and frame.CatalogContent
    if not catalog then return false end

    local searchBox = catalog.SearchBox
    if searchBox then
        NSkin:RegisterSearchBox({
            id = IDs.CatalogSearchBox,
            module = "HousingDashboard",
            appearanceWindowID = IDs.Scope,
            label = "Catalog search box",
            window = frame,
            target = searchBox,
            priority = 75,
            highlightRegions = { searchBox },
            isEditable = function()
                return IsVisible(frame) and IsVisible(catalog)
                    and IsVisible(searchBox)
            end,
        })
    end

    local filters = catalog.Filters
    local filterDropdown = filters and filters.FilterDropdown
    if filterDropdown then
        NSkin:RegisterDropdown({
            id = IDs.CatalogFilterDropdown,
            module = "HousingDashboard",
            appearanceWindowID = IDs.Scope,
            label = "Catalog filter dropdown",
            window = frame,
            target = filterDropdown,
            priority = 76,
            highlightRegions = { filterDropdown },
            isEditable = function()
                return IsVisible(frame) and IsVisible(catalog)
                    and IsVisible(filterDropdown)
            end,
        })
    end

    local options = catalog.OptionsContainer
    local scrollBar = options and options.ScrollBar
    if scrollBar then
        NSkin:RegisterScrollBar({
            id = IDs.CatalogOptionsScrollBar,
            module = "HousingDashboard",
            appearanceWindowID = IDs.Scope,
            label = "Catalog options scroll bar",
            window = frame,
            target = scrollBar,
            priority = 77,
            highlightRegions = { scrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(catalog)
                    and IsVisible(scrollBar)
            end,
        })
    end

    HookOwner(catalog)
    return searchBox ~= nil or filterDropdown ~= nil or scrollBar ~= nil
end

function HousingDashboardSkin:ApplyCollectionControls(frame)
    local collection = frame and frame.CollectionContent
    local blueprints = collection and collection.BlueprintCollection
    local scrollBar = blueprints and blueprints.ScrollBar
    if not scrollBar then return false end

    NSkin:RegisterScrollBar({
        id = IDs.BlueprintCollectionScrollBar,
        module = "HousingDashboard",
        appearanceWindowID = IDs.Scope,
        label = "Blueprint collection scroll bar",
        window = frame,
        target = scrollBar,
        priority = 78,
        highlightRegions = { scrollBar },
        isEditable = function()
            return IsVisible(frame) and IsVisible(collection)
                and IsVisible(scrollBar)
        end,
    })
    HookOwner(collection)
    return true
end

function HousingDashboardSkin:Apply()
    local frame = _G.HousingDashboardFrame
    if not frame then return false end

    self:ApplyWindowChrome(frame)
    self:ApplyHouseDropdown(frame)
    self:ApplyHouseTabs(frame)
    self:ApplySideTabs(frame)
    self:ApplyHouseInfoControls(frame)
    self:ApplyCatalogControls(frame)
    self:ApplyCollectionControls(frame)
    return true
end

local function RegisterDashboardCallbacks()
    if registryCallbacksRegistered or not _G.EventRegistry then return end
    _G.EventRegistry:RegisterCallback(
        "HouseDropdown.HouseListUpdated", QueueApply,
        HousingDashboardSkin)
    _G.EventRegistry:RegisterCallback(
        "HouseDropdown.HouseSelected", QueueApply,
        HousingDashboardSkin)
    registryCallbacksRegistered = true
end

function HousingDashboardSkin:Initialize()
    local frame = _G.HousingDashboardFrame
    if not frame then return false end

    HookOwner(frame)
    RegisterDashboardCallbacks()
    initialized = true
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function HousingDashboardSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "HousingDashboard",
    addon = "Blizzard_HousingDashboard",
    apply = function() return HousingDashboardSkin:Initialize() end,
})
