local _, NSkin = ...

local TransmogrificationSkin = NSkin:NewModule("Transmogrification")

local IDs = {
    Scope = "Transmogrification",
    Window = "Transmogrification.Window",
    HeaderControls = "Transmogrification.HeaderControls",
    TopTabs = "Transmogrification.TopTabs",
    Search = {
        Group = "Transmogrification.Items.SearchBox",
        Filter = "Transmogrification.Items.Filter",
    },
    HideIgnoredSlots = "Transmogrification.Preview.HideIgnoredSlots",
    SheatheWeapon = "Transmogrification.Preview.SheatheWeapon",
    Pagination = {
        Group = "Transmogrification.Items.Pagination",
        Previous = "Transmogrification.Items.Pagination.Previous",
        Next = "Transmogrification.Items.Pagination.Next",
        Text = "Transmogrification.Items.Pagination.Text",
    },
    SaveOutfitButton = "Transmogrification.Outfits.SaveButton",
    Sets = {
        Search = {
            Group = "Transmogrification.Sets.SearchBox",
            Filter = "Transmogrification.Sets.Filter",
        },
        Pagination = {
            Group = "Transmogrification.Sets.Pagination",
            Previous = "Transmogrification.Sets.Pagination.Previous",
            Next = "Transmogrification.Sets.Pagination.Next",
            Text = "Transmogrification.Sets.Pagination.Text",
        },
    },
    CustomSets = {
        NewButton = "Transmogrification.CustomSets.NewButton",
        Pagination = {
            Group = "Transmogrification.CustomSets.Pagination",
            Previous = "Transmogrification.CustomSets.Pagination.Previous",
            Next = "Transmogrification.CustomSets.Pagination.Next",
            Text = "Transmogrification.CustomSets.Pagination.Text",
        },
    },
    Situations = {
        DefaultsButton = "Transmogrification.Situations.DefaultsButton",
        ApplyButton = "Transmogrification.Situations.ApplyButton",
        EnabledCheckbox = "Transmogrification.Situations.EnabledCheckbox",
        Dropdowns = "Transmogrification.Situations.Dropdowns",
    },
}

local initialized = false
local showHooked = false
local itemsShowHooked = false
local setsShowHooked = false
local customSetsShowHooked = false
local situationsShowHooked = false
local State = {
    groupedAnchor = nil,
    paginationController = nil,
    searchController = nil,
    Sets = {
        groupedAnchor = nil,
        paginationController = nil,
        searchController = nil,
    },
    CustomSets = {
        paginationController = nil,
    },
    Situations = {
        dropdowns = setmetatable({}, { __mode = "k" }),
        baselines = setmetatable({}, { __mode = "k" }),
        groupAnchor = nil,
        groupRegistered = false,
    },
}

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Transmogrification",
})

local function GetFrames()
    local frame = _G.TransmogFrame
    local wardrobe = frame and frame.WardrobeCollection
    local tabContent = wardrobe and wardrobe.TabContent
    local itemsFrame = tabContent and tabContent.ItemsFrame
    local setsFrame = tabContent and tabContent.SetsFrame
    local customSetsFrame = tabContent and tabContent.CustomSetsFrame
    local situationsFrame = tabContent and tabContent.SituationsFrame
    local preview = frame and frame.CharacterPreview
    local toggleOptions = preview and preview.ToggleOptions
    local outfitCollection = frame and frame.OutfitCollection
    return frame, itemsFrame, toggleOptions, outfitCollection, setsFrame,
        customSetsFrame, situationsFrame
end

local function CaptureAccessoryAnchor(primary, accessory)
    if not primary or not accessory then return nil end
    local primaryLeft, primaryRight = primary:GetLeft(), primary:GetRight()
    local accessoryLeft, accessoryRight = accessory:GetLeft(), accessory:GetRight()
    local _, primaryY = primary:GetCenter()
    local _, accessoryY = accessory:GetCenter()
    if not primaryLeft or not primaryRight or not accessoryLeft
        or not accessoryRight or not primaryY or not accessoryY
    then return nil end
    if accessoryRight <= primaryLeft then
        return { point = "RIGHT", relativePoint = "LEFT",
            x = accessoryRight - primaryLeft, y = accessoryY - primaryY }
    end
    return { point = "LEFT", relativePoint = "RIGHT",
        x = accessoryLeft - primaryRight, y = accessoryY - primaryY }
end

local function CopyPlacement(placement)
    local copy = {}
    for key, value in pairs(placement or {}) do copy[key] = value end
    return copy
end

local function CaptureSituationDropdownBaseline(dropdown)
    local baseline = State.Situations.baselines[dropdown]
    if baseline then return baseline end
    baseline = {}
    for i = 1, dropdown:GetNumPoints() do
        baseline[i] = { dropdown:GetPoint(i) }
    end
    State.Situations.baselines[dropdown] = baseline
    return baseline
end

local function GetSituationDropdownPlacement()
    local options = NSkin:GetModuleOptions("Transmogrification", false)
    local saved = options and options.situationDropdownPlacement
    return saved and CopyPlacement(saved) or {
        edge = "TOP", side = "INSIDE", alignment = "LEFT",
        alongOffset = 0, edgeOffset = 0,
    }
end

local function ApplySituationDropdownPlacement(placement)
    local x = tonumber(placement and (placement.alongOffset or placement.x)) or 0
    local y = tonumber(placement and (placement.edgeOffset or placement.y)) or 0
    for dropdown in pairs(State.Situations.dropdowns) do
        local baseline = CaptureSituationDropdownBaseline(dropdown)
        dropdown:ClearAllPoints()
        for i = 1, #baseline do
            local point = baseline[i]
            dropdown:SetPoint(point[1], point[2], point[3],
                (tonumber(point[4]) or 0) + x,
                (tonumber(point[5]) or 0) + y)
        end
    end
    NSkin:NotifySkinningElementBoundsChanged(IDs.Situations.Dropdowns)
    return true
end

local function SetSituationDropdownPlacement(placement)
    if not ApplySituationDropdownPlacement(placement) then return false end
    local options = NSkin:GetModuleOptions("Transmogrification", true)
    options.situationDropdownPlacement = CopyPlacement(placement)
    return true
end

local function ResetSituationDropdownPlacement()
    ApplySituationDropdownPlacement({ alongOffset = 0, edgeOffset = 0 })
    local options = NSkin:GetModuleOptions("Transmogrification", false)
    if options then options.situationDropdownPlacement = nil end
    return true
end

local function GetSituationDropdownRegions()
    local regions = {}
    for dropdown in pairs(State.Situations.dropdowns) do
        if dropdown:IsVisible() then regions[#regions + 1] = dropdown end
    end
    return regions
end

local function ResolvePagingControls(itemsFrame)
    local pagedContent = itemsFrame and itemsFrame.PagedContent
    local group = pagedContent and pagedContent.PagingControls
    if not group then return end
    return group, group.PrevPageButton or group.prevPageButton,
        group.NextPageButton or group.nextPageButton,
        group.PageText or group.pageText
end

local function RegisterCheckbox(frame, toggle, id, label, priority)
    local checkButton = toggle and (toggle.Checkbox or toggle.CheckButton)
    if not frame or not checkButton then return false end

    NSkin:SkinCheckButton(checkButton, {
        style = NSkin:GetAppearanceStyle("button", IDs.Scope, id),
        text = toggle.Text,
    })
    NSkin:RegisterSimpleMovableElement({
        id = id,
        module = "Transmogrification",
        appearanceWindowID = IDs.Scope,
        label = label,
        kind = "CHECKBOX",
        window = frame,
        target = checkButton,
        priority = priority,
        highlightRegions = { checkButton },
        isEditable = function()
            return frame:IsVisible() and toggle:IsVisible()
                and checkButton:IsVisible()
        end,
    })
    return true
end

local function RegisterActionButton(frame, owner, button, id, label, priority)
    if not frame or not owner or not button then return false end
    NSkin:SkinActionButton(button, { style = NSkin:GetAppearanceStyle(
        "button", IDs.Scope, id) })
    NSkin:RegisterSimpleMovableElement({
        id = id,
        module = "Transmogrification",
        appearanceWindowID = IDs.Scope,
        label = label,
        kind = "ACTION_BUTTON",
        window = frame,
        target = button,
        priority = priority,
        highlightRegions = { button },
        isEditable = function()
            return frame:IsVisible() and owner:IsVisible()
                and button:IsVisible()
        end,
    })
    return true
end

function TransmogrificationSkin:ApplyWindowChrome(frame)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Transmogrification window",
        kind = "WINDOW",
        module = "Transmogrification",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
end

function TransmogrificationSkin:ApplyTopTabs(frame)
    local wardrobe = frame and frame.WardrobeCollection
    local tabSystem = wardrobe and wardrobe.TabHeaders
    if not tabSystem or type(tabSystem.tabs) ~= "table"
        or #tabSystem.tabs == 0
    then return false end

    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Scope, IDs.TopTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Scope, IDs.TopTabs)
    NSkin:SkinTabSystem(tabSystem, style, border)
    NSkin:RegisterTabGroup(IDs.TopTabs, {
        label = "Transmogrification top tabs",
        kind = "TAB_GROUP",
        module = "Transmogrification",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = tabSystem,
        container = tabSystem,
        priority = 60,
        orientation = "HORIZONTAL",
        edge = "TOP",
        isEditable = function()
            return frame:IsVisible() and wardrobe:IsVisible()
                and tabSystem:IsVisible()
        end,
    })
    NSkin:ApplyTabGroupLayout(IDs.TopTabs)
    return true
end

function TransmogrificationSkin:ApplySearch(itemsFrame, frame)
    local searchBox = itemsFrame and itemsFrame.SearchBox
    local filterButton = itemsFrame and itemsFrame.FilterButton
    if not searchBox or not filterButton then return false end

    local searchStyle = NSkin:GetAppearanceStyle(
        "searchBox", IDs.Scope, IDs.Search.Group)
    NSkin:SkinSearchBox(searchBox, searchStyle,
        NSkin:GetAppearanceBorderColor(
            "searchBox", searchStyle, IDs.Scope, IDs.Search.Group))
    NSkin:SkinDropdown(filterButton, { style = NSkin:GetAppearanceStyle(
        "button", IDs.Scope, IDs.Search.Filter) })

    if not State.groupedAnchor then
        State.groupedAnchor = CaptureAccessoryAnchor(searchBox, filterButton)
    end
    if not State.searchController then
        State.searchController = NSkin:RegisterAccessoryGroup({
            module = "Transmogrification",
            appearanceWindowID = IDs.Scope,
            window = frame,
            ids = {
                primary = IDs.Search.Group,
                accessory = IDs.Search.Filter,
            },
            primary = searchBox,
            accessory = filterButton,
            primaryLabel = "Transmogrification search bar",
            accessoryLabel = "Transmogrification filter",
            primaryPriority = 80,
            accessoryPriority = 90,
            visibilityFrame = itemsFrame,
            anchorGrouped = function(primary, accessory)
                local anchor = State.groupedAnchor
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
        State.searchController:Refresh()
    end
    return true
end

function TransmogrificationSkin:ApplySetsSearch(setsFrame, frame)
    local searchBox = setsFrame and setsFrame.SearchBox
    local filterButton = setsFrame and setsFrame.FilterButton
    if not searchBox or not filterButton then return false end

    local searchStyle = NSkin:GetAppearanceStyle(
        "searchBox", IDs.Scope, IDs.Sets.Search.Group)
    NSkin:SkinSearchBox(searchBox, searchStyle,
        NSkin:GetAppearanceBorderColor(
            "searchBox", searchStyle, IDs.Scope, IDs.Sets.Search.Group))
    NSkin:SkinDropdown(filterButton, { style = NSkin:GetAppearanceStyle(
        "button", IDs.Scope, IDs.Sets.Search.Filter) })

    if not State.Sets.groupedAnchor then
        State.Sets.groupedAnchor = CaptureAccessoryAnchor(
            searchBox, filterButton)
    end
    if not State.Sets.searchController then
        State.Sets.searchController = NSkin:RegisterAccessoryGroup({
            module = "Transmogrification",
            appearanceWindowID = IDs.Scope,
            window = frame,
            ids = {
                primary = IDs.Sets.Search.Group,
                accessory = IDs.Sets.Search.Filter,
            },
            primary = searchBox,
            accessory = filterButton,
            primaryLabel = "Transmogrification Sets search bar",
            accessoryLabel = "Transmogrification Sets filter",
            primaryPriority = 85,
            accessoryPriority = 95,
            visibilityFrame = setsFrame,
            anchorGrouped = function(primary, accessory)
                local anchor = State.Sets.groupedAnchor
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
        State.Sets.searchController:Refresh()
    end
    return true
end

function TransmogrificationSkin:ApplyPagination(itemsFrame, frame)
    local group, previousPage, nextPage, pageText =
        ResolvePagingControls(itemsFrame)
    if not group or not previousPage or not nextPage or not pageText then
        return false
    end

    NSkin:SkinPagingControls(group)
    if not State.paginationController then
        State.paginationController = NSkin:RegisterPaginationGroup({
            module = "Transmogrification",
            appearanceWindowID = IDs.Scope,
            window = frame,
            ids = {
                group = IDs.Pagination.Group,
                previous = IDs.Pagination.Previous,
                next = IDs.Pagination.Next,
                text = IDs.Pagination.Text,
            },
            controls = {
                group = group,
                previous = previousPage,
                next = nextPage,
                text = pageText,
            },
            groupLabel = "Transmogrification pagination",
            groupPriority = 83,
            visibilityFrame = itemsFrame,
        })
    else
        State.paginationController:Refresh()
    end
    return true
end

function TransmogrificationSkin:ApplySetsPagination(setsFrame, frame)
    local group, previousPage, nextPage, pageText =
        ResolvePagingControls(setsFrame)
    if not group or not previousPage or not nextPage or not pageText then
        return false
    end

    NSkin:SkinPagingControls(group)
    if not State.Sets.paginationController then
        State.Sets.paginationController = NSkin:RegisterPaginationGroup({
            module = "Transmogrification",
            appearanceWindowID = IDs.Scope,
            window = frame,
            ids = {
                group = IDs.Sets.Pagination.Group,
                previous = IDs.Sets.Pagination.Previous,
                next = IDs.Sets.Pagination.Next,
                text = IDs.Sets.Pagination.Text,
            },
            controls = {
                group = group,
                previous = previousPage,
                next = nextPage,
                text = pageText,
            },
            groupLabel = "Transmogrification Sets pagination",
            groupPriority = 86,
            visibilityFrame = setsFrame,
        })
    else
        State.Sets.paginationController:Refresh()
    end
    return true
end

function TransmogrificationSkin:ApplyCustomSets(customSetsFrame, frame)
    if not customSetsFrame then return false end

    local newButton = customSetsFrame.NewCustomSetButton
    if newButton then
        NSkin:SkinActionButton(newButton, { style = NSkin:GetAppearanceStyle(
            "button", IDs.Scope, IDs.CustomSets.NewButton) })
        NSkin:RegisterSimpleMovableElement({
            id = IDs.CustomSets.NewButton,
            module = "Transmogrification",
            appearanceWindowID = IDs.Scope,
            label = "New custom set button",
            kind = "ACTION_BUTTON",
            window = frame,
            target = newButton,
            priority = 87,
            highlightRegions = { newButton },
            isEditable = function()
                return frame:IsVisible() and customSetsFrame:IsVisible()
                    and newButton:IsVisible()
            end,
        })
    end

    local group, previousPage, nextPage, pageText =
        ResolvePagingControls(customSetsFrame)
    if not group or not previousPage or not nextPage or not pageText then
        return newButton ~= nil
    end

    NSkin:SkinPagingControls(group)
    if not State.CustomSets.paginationController then
        State.CustomSets.paginationController = NSkin:RegisterPaginationGroup({
            module = "Transmogrification",
            appearanceWindowID = IDs.Scope,
            window = frame,
            ids = {
                group = IDs.CustomSets.Pagination.Group,
                previous = IDs.CustomSets.Pagination.Previous,
                next = IDs.CustomSets.Pagination.Next,
                text = IDs.CustomSets.Pagination.Text,
            },
            controls = {
                group = group,
                previous = previousPage,
                next = nextPage,
                text = pageText,
            },
            groupLabel = "Transmogrification Custom Sets pagination",
            groupPriority = 88,
            visibilityFrame = customSetsFrame,
        })
    else
        State.CustomSets.paginationController:Refresh()
    end
    return true
end

function TransmogrificationSkin:ApplySituations(situationsFrame, frame)
    if not situationsFrame then return false end

    for _, definition in ipairs({
        { situationsFrame.DefaultsButton, IDs.Situations.DefaultsButton,
            "Situation defaults button", 89 },
        { situationsFrame.ApplyButton, IDs.Situations.ApplyButton,
            "Apply situation changes button", 90 },
    }) do
        local button, id, label, priority = unpack(definition)
        RegisterActionButton(
            frame, situationsFrame, button, id, label, priority)
    end

    RegisterCheckbox(frame, situationsFrame.EnabledToggle,
        IDs.Situations.EnabledCheckbox,
        "Situations enabled checkbox", 91)

    wipe(State.Situations.dropdowns)
    local pool = situationsFrame.SituationFramePool
    if pool and pool.EnumerateActive then
        local style = NSkin:GetAppearanceStyle(
            "button", IDs.Scope, IDs.Situations.Dropdowns)
        for situation in pool:EnumerateActive() do
            local dropdown = situation and situation.Dropdown
            if dropdown then
                CaptureSituationDropdownBaseline(dropdown)
                State.Situations.dropdowns[dropdown] = true
                NSkin:SkinDropdown(dropdown, { style = style })
            end
        end
    end

    if not State.Situations.groupAnchor then
        local anchorParent = situationsFrame.Situations or situationsFrame
        local anchor = CreateFrame("Frame", nil, anchorParent)
        anchor:SetSize(1, 1)
        anchor:SetPoint("TOPLEFT")
        anchor:EnableMouse(false)
        anchor:Show()
        State.Situations.groupAnchor = anchor
    end
    if not State.Situations.groupRegistered then
        State.Situations.groupRegistered = NSkin:RegisterSkinningElement(
            IDs.Situations.Dropdowns, {
                label = "Situation dropdowns",
                kind = "DROPDOWN",
                module = "Transmogrification",
                appearanceWindowID = IDs.Scope,
                window = frame,
                target = State.Situations.groupAnchor,
                priority = 92,
                draggable = false,
                editorOptions = NSkin:CreateEditorOptionsPreset("MOVABLE"),
                highlightRegions = GetSituationDropdownRegions,
                isEditable = function()
                    return frame:IsVisible() and situationsFrame:IsVisible()
                        and #GetSituationDropdownRegions() > 0
                end,
                getPlacement = GetSituationDropdownPlacement,
                applyPlacement = function(_, placement)
                    return ApplySituationDropdownPlacement(placement)
                end,
                setPlacement = function(_, placement)
                    return SetSituationDropdownPlacement(placement)
                end,
                resetPlacement = ResetSituationDropdownPlacement,
            }) == true
    end
    ApplySituationDropdownPlacement(GetSituationDropdownPlacement())
    return true
end

function TransmogrificationSkin:ApplySaveButton(outfitCollection, frame)
    local button = outfitCollection and outfitCollection.SaveOutfitButton
    if not button then return false end

    NSkin:SkinActionButton(button, { style = NSkin:GetAppearanceStyle(
        "button", IDs.Scope, IDs.SaveOutfitButton) })
    NSkin:RegisterSimpleMovableElement({
        id = IDs.SaveOutfitButton,
        module = "Transmogrification",
        appearanceWindowID = IDs.Scope,
        label = "Save outfit button",
        kind = "ACTION_BUTTON",
        window = frame,
        target = button,
        priority = 84,
        highlightRegions = { button },
        isEditable = function()
            return frame:IsVisible() and outfitCollection:IsVisible()
                and button:IsVisible()
        end,
    })
    return true
end

function TransmogrificationSkin:Apply()
    local frame, itemsFrame, toggleOptions, outfitCollection, setsFrame,
        customSetsFrame, situationsFrame = GetFrames()
    if not frame then return false end

    self:ApplyWindowChrome(frame)
    self:ApplyTopTabs(frame)
    self:ApplySearch(itemsFrame, frame)
    self:ApplyPagination(itemsFrame, frame)
    self:ApplySetsSearch(setsFrame, frame)
    self:ApplySetsPagination(setsFrame, frame)
    self:ApplyCustomSets(customSetsFrame, frame)
    self:ApplySituations(situationsFrame, frame)
    RegisterCheckbox(frame,
        toggleOptions and toggleOptions.HideIgnoredToggle,
        IDs.HideIgnoredSlots, "Hide ignored slots checkbox", 81)
    RegisterCheckbox(frame,
        toggleOptions and toggleOptions.SheatheWeaponToggle,
        IDs.SheatheWeapon, "Sheathe weapon checkbox", 82)
    self:ApplySaveButton(outfitCollection, frame)
    return true
end

function TransmogrificationSkin:QueueApply()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() TransmogrificationSkin:Apply() end)
    else
        self:Apply()
    end
end

function TransmogrificationSkin:Initialize()
    local frame, itemsFrame, _, _, setsFrame, customSetsFrame,
        situationsFrame = GetFrames()
    if not frame then return false end

    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            TransmogrificationSkin:QueueApply()
        end)
        showHooked = true
    end
    if itemsFrame and not itemsShowHooked and itemsFrame.HookScript then
        itemsFrame:HookScript("OnShow", function()
            TransmogrificationSkin:QueueApply()
        end)
        itemsShowHooked = true
    end
    if setsFrame and not setsShowHooked and setsFrame.HookScript then
        setsFrame:HookScript("OnShow", function()
            TransmogrificationSkin:QueueApply()
        end)
        setsShowHooked = true
    end
    if customSetsFrame and not customSetsShowHooked
        and customSetsFrame.HookScript
    then
        customSetsFrame:HookScript("OnShow", function()
            TransmogrificationSkin:QueueApply()
        end)
        customSetsShowHooked = true
    end
    if situationsFrame and not situationsShowHooked
        and situationsFrame.HookScript
    then
        situationsFrame:HookScript("OnShow", function()
            TransmogrificationSkin:QueueApply()
        end)
        situationsShowHooked = true
    end

    initialized = true
    return self:Apply()
end

function TransmogrificationSkin:RefreshAppearance()
    if initialized then self:Apply() end
end

NSkin:RegisterWindowSkin({
    module = "Transmogrification",
    addon = "Blizzard_Transmog",
    apply = function() return TransmogrificationSkin:Initialize() end,
})
