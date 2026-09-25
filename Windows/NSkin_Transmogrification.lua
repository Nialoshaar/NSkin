local _, NSkin = ...

local TransmogrificationSkin = NSkin:NewModule("Transmogrification")
local SITUATION_DROPDOWN_MENUS = { "MENU_TRANSMOG_SITUATION" }
local DressUpIDs = {
    Scope = "DressUp",
    Window = "DressUp.Window",
    Title = "DressUp.Title",
    HeaderControls = "DressUp.HeaderControls",
    ResizeControls = "DressUp.ResizeControls",
    ToggleDetails = "DressUp.ToggleDetails",
    CustomSetDropdown = "DressUp.CustomSetDropdown",
    LinkButton = "DressUp.LinkButton",
    SaveCustomSet = "DressUp.SaveCustomSet",
    DetailsWindow = "DressUp.CustomSetDetails.Window",
    Close = "DressUp.Close",
    Reset = "DressUp.Reset",
    SetName = "DressUp.SetPanel.SetName",
    ScrollBar = "DressUp.SetPanel.ScrollBar",
    Rows = "DressUp.SetPanel.Rows",
    Slots = "DressUp.CustomSetDetails.Slots",
}
local dressUpInitialized = false

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
NSkin:RegisterAppearanceScope(DressUpIDs.Scope, {
    label = "Dressing Room",
    parent = IDs.Scope,
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
            accessoryMenus = { "MENU_TRANSMOG_ITEMS_FILTER" },
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
            accessoryMenus = { "MENU_TRANSMOG_SETS_FILTER" },
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
        NSkin:RegisterActionButton({
            id = IDs.CustomSets.NewButton,
            module = "Transmogrification",
            appearanceWindowID = IDs.Scope,
            label = "New custom set button",
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
        if button then
            NSkin:RegisterActionButton({
                id = id, module = "Transmogrification",
                appearanceWindowID = IDs.Scope, label = label,
                window = frame, target = button, priority = priority,
                highlightRegions = { button },
                isEditable = function()
                    return frame:IsVisible() and situationsFrame:IsVisible()
                        and button:IsVisible()
                end,
            })
        end
    end

    local enabledToggle = situationsFrame.EnabledToggle
    local enabledCheckbox = enabledToggle
        and (enabledToggle.Checkbox or enabledToggle.CheckButton)
    if enabledCheckbox then
        NSkin:RegisterCheckbox({
            id = IDs.Situations.EnabledCheckbox,
            module = "Transmogrification", appearanceWindowID = IDs.Scope,
            label = "Situations enabled checkbox", window = frame,
            target = enabledCheckbox, priority = 91,
            highlightRegions = { enabledCheckbox }, text = enabledToggle.Text,
            isEditable = function()
                return frame:IsVisible() and situationsFrame:IsVisible()
                    and enabledToggle:IsVisible() and enabledCheckbox:IsVisible()
            end,
        })
    end

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
                NSkin:SkinDropdown(dropdown, {
                    style = style,
                    menus = SITUATION_DROPDOWN_MENUS,
                })
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

    NSkin:RegisterActionButton({
        id = IDs.SaveOutfitButton,
        module = "Transmogrification",
        appearanceWindowID = IDs.Scope,
        label = "Save outfit button",
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
    for _, definition in ipairs({
        { toggleOptions and toggleOptions.HideIgnoredToggle,
            IDs.HideIgnoredSlots, "Hide ignored slots checkbox", 81 },
        { toggleOptions and toggleOptions.SheatheWeaponToggle,
            IDs.SheatheWeapon, "Sheathe weapon checkbox", 82 },
    }) do
        local toggle, id, label, priority = unpack(definition)
        local checkButton = toggle and (toggle.Checkbox or toggle.CheckButton)
        if checkButton then
            NSkin:RegisterCheckbox({
                id = id, module = "Transmogrification",
                appearanceWindowID = IDs.Scope, label = label,
                window = frame, target = checkButton, priority = priority,
                highlightRegions = { checkButton }, text = toggle.Text,
                isEditable = function()
                    return frame:IsVisible() and toggle:IsVisible()
                        and checkButton:IsVisible()
                end,
            })
        end
    end
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
    if dressUpInitialized then self:ApplyDressUp() end
end

local function CanSkinDressUp(target)
    return target and not (target.IsForbidden and target:IsForbidden())
        and not (target.IsProtected and target:IsProtected())
end

local function DressUpVisible(target)
    return CanSkinDressUp(target) and target:IsVisible()
end

local function RegisterDressUpControl(frame, id, kind, label, target, options)
    if not CanSkinDressUp(target) then return false end
    local definition = {
        id = id, module = "Transmogrification",
        appearanceWindowID = DressUpIDs.Scope,
        label = label, window = frame, target = target, priority = 30,
        highlightRegions = { target },
        isEditable = function()
            return DressUpVisible(frame) and DressUpVisible(target)
        end,
    }
    for key, value in pairs(options or {}) do definition[key] = value end
    local element = NSkin:RegisterTypedElement(kind, definition)
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element ~= nil
end

local function GetDressUpRows(panel, visibleOnly)
    local rows = {}
    NSkin:ForEachScrollBoxFrame(panel.ScrollBox, function(row)
        if CanSkinDressUp(row) and (not visibleOnly or row:IsVisible()) then
            rows[#rows + 1] = row
        end
    end)
    return rows
end

local function StyleDressUpRow(row)
    if not CanSkinDressUp(row) or not CanSkinDressUp(row.Icon)
        or not CanSkinDressUp(row.ItemName) or not CanSkinDressUp(row.ItemSlot)
    then return end
    local rowStyle = NSkin:GetAppearanceStyle("row", DressUpIDs.Scope, DressUpIDs.Rows)
    NSkin:SkinRow(row, {
        style = rowStyle,
        border = NSkin:GetAppearanceBorderColor("row", rowStyle,
            DressUpIDs.Scope, DressUpIDs.Rows),
        nativeDecorationRegions = { row.BackgroundTexture },
        hoverRegion = row.HighlightTexture,
        selectedRegion = row.SelectedTexture,
        getHovered = function(target) return target:IsMouseOver() end,
        getSelected = function(target)
            return target.elementData and target.elementData.selected == true
        end,
    })
    NSkin:SkinTypedElement("ICON", {
        id = DressUpIDs.Rows, appearanceWindowID = DressUpIDs.Scope,
        target = row, texture = row.Icon, borderOwner = row,
    })
    local textStyle = NSkin:GetAppearanceStyle("text", DressUpIDs.Scope, DressUpIDs.Rows)
    -- ItemName carries native inline quality/error colors. IconBorder is also
    -- functional quality/error artwork and is deliberately retained.
    NSkin:SkinText(row.ItemName, textStyle)
    NSkin:SkinText(row.ItemSlot, textStyle)
end

local function GetDressUpSlots(panel, visibleOnly)
    local slots = {}
    local pool = panel.slotPool
    if pool and pool.EnumerateActive then
        for slot in pool:EnumerateActive() do
            -- The pool also contains hidden spacer frames.
            if CanSkinDressUp(slot) and slot:IsShown()
                and (not visibleOnly or slot:IsVisible())
            then slots[#slots + 1] = slot end
        end
    end
    return slots
end

local function StyleDressUpSlot(slot)
    if not CanSkinDressUp(slot) or not CanSkinDressUp(slot.Icon)
        or not CanSkinDressUp(slot.Name)
    then return end
    local data = NSkin:GetSkinData(slot, "dressUp")
    if not data.detailsHooked and slot.SetDetails and _G.hooksecurefunc then
        _G.hooksecurefunc(slot, "SetDetails", function()
            if DressUpVisible(slot) then StyleDressUpSlot(slot) end
        end)
        data.detailsHooked = true
    end
    NSkin:SkinTypedElement("ICON", {
        id = DressUpIDs.Slots, appearanceWindowID = DressUpIDs.Scope,
        target = slot, texture = slot.Icon, borderOwner = slot,
    })
    local style = NSkin:GetAppearanceStyle("text", DressUpIDs.Scope, DressUpIDs.Slots)
    -- These colors convey unusable/uncollected/empty state in Blizzard's
    -- DressUpCustomSetDetailsSlotMixin, not ordinary text decoration.
    local statusColor = slot.slotState == 1 and _G.RED_FONT_COLOR
        or ((slot.slotState == 3 or not slot.transmogID) and _G.GRAY_FONT_COLOR)
    if statusColor then
        local statusStyle = {}
        for key, value in pairs(style) do statusStyle[key] = value end
        statusStyle.color = { statusColor:GetRGB() }
        statusStyle.colorMode = nil
        style = statusStyle
    end
    NSkin:SkinText(slot.Name, style)
    -- Keep IconBorder, HiddenIcon, desaturation, and native alpha: they encode
    -- appearance availability and hidden visuals. Do not change slot geometry.
end

local function DressUpFamilyRegions(targets, isRow)
    local regions = {}
    for _, target in ipairs(targets) do
        regions[#regions + 1] = target
        if target.Icon then regions[#regions + 1] = target.Icon end
        if isRow then
            if target.ItemName then regions[#regions + 1] = target.ItemName end
            if target.ItemSlot then regions[#regions + 1] = target.ItemSlot end
        elseif target.Name then regions[#regions + 1] = target.Name end
    end
    return regions
end

function TransmogrificationSkin:ApplyDressUpFamily(frame, panel, isRow)
    if not CanSkinDressUp(panel) then return false end
    local id = isRow and DressUpIDs.Rows or DressUpIDs.Slots
    local getTargets = isRow and GetDressUpRows or GetDressUpSlots
    local styleTarget = isRow and StyleDressUpRow or StyleDressUpSlot
    local function Refresh()
        if not CanSkinDressUp(panel) then return false end
        for _, target in ipairs(getTargets(panel, false)) do styleTarget(target) end
        NSkin:NotifySkinningElementBoundsChanged(id)
        return true
    end
    if not NSkin:GetSkinningElement(id) then
        NSkin:RegisterSkinningElement(id, {
            module = "Transmogrification", appearanceWindowID = DressUpIDs.Scope,
            label = isRow and "Dressing Room set items" or "Dressing Room appearance slots",
            kind = isRow and "BUTTON" or "ICON",
            rowFamily = isRow and "row" or nil,
            window = frame, target = panel, priority = 40, draggable = false,
            appearanceStyles = { "icon", "text" },
            appearanceTypeIDs = { "ICON", "TEXT" },
            rowFamilyMemberTargets = isRow and {
                ICON = function()
                    local targets = {}
                    for _, row in ipairs(GetDressUpRows(panel, true)) do
                        if row.Icon then targets[#targets + 1] = row end
                    end
                    return targets
                end,
                TEXT = function()
                    local targets = {}
                    for _, row in ipairs(GetDressUpRows(panel, true)) do
                        if row.ItemName then
                            targets[#targets + 1] = row.ItemName
                        end
                        if row.ItemSlot then
                            targets[#targets + 1] = row.ItemSlot
                        end
                    end
                    return targets
                end,
            } or nil,
            editorOptions = isRow and {
                { id = "shared.rowAppearance", label = "Rows", category = "CUSTOMIZE" },
                { id = "shared.iconAppearance", label = "Icons", category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Text", category = "CUSTOMIZE" },
            } or {
                { id = "shared.iconAppearance", label = "Icons", category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Names", category = "CUSTOMIZE" },
            },
            highlightRegions = function()
                return DressUpFamilyRegions(getTargets(panel, true), isRow)
            end,
            pixelBorderTargets = function() return getTargets(panel, true) end,
            refreshAppearance = Refresh, refreshLayout = Refresh,
            isEditable = function()
                return DressUpVisible(frame) and DressUpVisible(panel)
                    and #getTargets(panel, true) > 0
            end,
        })
    end
    local data = NSkin:GetSkinData(panel, "dressUp")
    if isRow and not data.rowsHooked then
        local scrollBox = panel.ScrollBox
        local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
        if not scrollBox or not scrollBox.RegisterCallback
            or not events or not events.OnInitializedFrame
        then return false end
        scrollBox:RegisterCallback(events.OnInitializedFrame, function(_, row)
            StyleDressUpRow(row)
            NSkin:NotifySkinningElementBoundsChanged(id)
        end, self)
        data.rowsHooked = true
    elseif not isRow and not data.slotsHooked then
        if not panel.Refresh or not _G.hooksecurefunc then return false end
        _G.hooksecurefunc(panel, "Refresh", function()
            Refresh()
        end)
        data.slotsHooked = true
    end
    Refresh()
    return NSkin:GetSkinningElement(id) ~= nil
end

function TransmogrificationSkin:ApplyDressUpDetailsChrome(frame)
    local panel = frame.CustomSetDetailsPanel
    if not CanSkinDressUp(panel) then return false end
    local data = NSkin:GetSkinData(panel, "dressUpChrome")
    if not data.decorations then
        data.decorations = {}
        -- The sideframe has no parentKey. Inspect only the panel's own regions
        -- and match its audited atlas/layer, never textures in the slot pool.
        for _, region in ipairs({ panel:GetRegions() }) do
            if CanSkinDressUp(region) and region:GetObjectType() == "Texture"
                and (region == panel.BlackBackground or region == panel.ClassBackground
                    or (region:GetDrawLayer() == "OVERLAY"
                        and region:GetAtlas() == "dressingroom-sideframe"))
            then
                data.decorations[#data.decorations + 1] = {
                    region = region, originalAlpha = region:GetAlpha(),
                }
            end
        end
    end
    local function Refresh()
        if not CanSkinDressUp(panel) then return false end
        for _, decoration in ipairs(data.decorations) do
            if CanSkinDressUp(decoration.region) then
                decoration.region:SetAlpha(0)
            end
        end
        local style = NSkin:GetAppearanceStyle("window",
            DressUpIDs.Scope, DressUpIDs.DetailsWindow)
        -- This side panel needs a background/border, without a title header.
        NSkin:SkinWindow(panel, nil, style,
            NSkin:GetAppearanceBorderColor("window", style,
                DressUpIDs.Scope, DressUpIDs.DetailsWindow))
        return true
    end
    Refresh()
    return NSkin:RegisterSkinningElement(DressUpIDs.DetailsWindow, {
        label = "Dressing Room appearance details panel", kind = "WINDOW",
        module = "Transmogrification", appearanceWindowID = DressUpIDs.Scope,
        window = frame, target = panel, priority = 5, draggable = false,
        refreshAppearance = Refresh, refreshLayout = Refresh,
        isEditable = function()
            return DressUpVisible(frame) and DressUpVisible(panel)
        end,
    }) == true
end

function TransmogrificationSkin:ApplyDressUp()
    local frame = _G.DressUpFrame
    if not CanSkinDressUp(frame) then return false end
    for _, target in pairs({ frame.CloseButton, frame.NineSlice, frame.Bg,
        frame.TitleContainer, frame.Inset }) do
        if not CanSkinDressUp(target) then return false end
    end
    local resize = frame.MaximizeMinimizeFrame
    local controls = {}
    if CanSkinDressUp(resize) then
        for _, definition in ipairs({
            { resize.MaximizeButton, "maximize" },
            { resize.MinimizeButton, "minimize" },
        }) do
            if CanSkinDressUp(definition[1]) then
                controls[#controls + 1] = { target = definition[1], glyph = definition[2] }
            end
        end
    end
    NSkin:SkinStandardWindowChrome({
        frame = frame, appearanceWindowID = DressUpIDs.Scope,
        elementID = DressUpIDs.Window, title = false,
        headerControlsID = DressUpIDs.HeaderControls,
        preserveCloseButtonGeometry = true,
    })
    if #controls > 0 then
        -- The generic header group lays out its children. Dress Up's resize
        -- controls instead keep the inherited minimizable-template anchors.
        local function RefreshResizeControls()
            local style = NSkin:GetAppearanceStyle("windowHeaderButton",
                DressUpIDs.Scope, DressUpIDs.ResizeControls)
            local border = NSkin:GetAppearanceBorderColor("windowHeaderButton",
                style, DressUpIDs.Scope, DressUpIDs.ResizeControls)
            for _, control in ipairs(controls) do
                if CanSkinDressUp(control.target) then
                    NSkin:SkinWindowHeaderButton(control.target, control,
                        { style = style, border = border })
                end
            end
            return true
        end
        RefreshResizeControls()
        NSkin:RegisterSkinningElement(DressUpIDs.ResizeControls, {
            label = "Dressing Room minimize/maximize",
            kind = "WINDOW_HEADER_CONTROLS", module = "Transmogrification",
            appearanceWindowID = DressUpIDs.Scope,
            window = frame, target = resize, priority = 95, draggable = false,
            highlightRegions = function()
                local regions = {}
                for _, control in ipairs(controls) do
                    if DressUpVisible(control.target) then
                        regions[#regions + 1] = control.target
                    end
                end
                return regions
            end,
            pixelBorderTargets = { resize.MaximizeButton, resize.MinimizeButton },
            refreshAppearance = RefreshResizeControls,
            refreshLayout = RefreshResizeControls,
            isEditable = function() return DressUpVisible(resize) end,
        })
    end
    local background = frame.ModelBackground
    if CanSkinDressUp(background) then
        local data = NSkin:GetSkinData(background, "dressUp")
        if data.originalAlpha == nil then data.originalAlpha = background:GetAlpha() end
        background:SetAlpha(0)
    end
    NSkin:RegisterSkinningElement(DressUpIDs.Window, {
        label = "Dressing Room window", kind = "WINDOW",
        module = "Transmogrification", appearanceWindowID = DressUpIDs.Scope,
        window = frame, target = frame, priority = 0, draggable = false,
    })
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
        or frame.TitleText or frame.Title
    local applied = RegisterDressUpControl(frame, DressUpIDs.Title, "TEXT",
        "Dressing Room title", title)
    local customSetDropdown = frame.CustomSetDropdown
    applied = RegisterDressUpControl(frame, DressUpIDs.CustomSetDropdown,
        "DROPDOWN", "Custom set", customSetDropdown, {
            menus = { "MENU_WARDROBE_CUSTOM_SETS" },
        }) and applied
    local saveButton = CanSkinDressUp(customSetDropdown) and customSetDropdown.SaveButton
    applied = RegisterDressUpControl(frame, DressUpIDs.SaveCustomSet,
        "ACTION_BUTTON", "Save custom set", saveButton) and applied
    NSkin:RegisterDropdownMenuSkin({ "MENU_DRESS_UP_MODEL" })
    for _, definition in ipairs({
        { DressUpIDs.LinkButton, "Link custom set", frame.LinkButton },
        { DressUpIDs.ToggleDetails, "Appearance details", frame.ToggleCustomSetDetailsButton },
        { DressUpIDs.Close, "Close preview", _G.DressUpFrameCancelButton },
        { DressUpIDs.Reset, "Reset preview", _G.DressUpFrameResetButton },
    }) do
        local button = definition[3]
        local options = CanSkinDressUp(button) and {
            skinOptions = {
                label = button:GetText(),
                preserveTexture = definition[1] == DressUpIDs.ToggleDetails
                    and button:GetNormalTexture() or nil,
            },
        }
        applied = RegisterDressUpControl(frame, definition[1], "BUTTON",
            definition[2], button, options) and applied
    end
    local panel = frame.SetSelectionPanel
    if CanSkinDressUp(panel) then
        applied = RegisterDressUpControl(frame, DressUpIDs.SetName, "TEXT",
            "Preview set name", panel.SetName) and applied
        applied = RegisterDressUpControl(frame, DressUpIDs.ScrollBar, "SCROLLBAR",
            "Preview set scroll bar", panel.ScrollBar) and applied
    else
        applied = false
    end
    applied = self:ApplyDressUpFamily(frame, panel, true) and applied
    applied = self:ApplyDressUpDetailsChrome(frame) and applied
    applied = self:ApplyDressUpFamily(frame, frame.CustomSetDetailsPanel, false) and applied
    dressUpInitialized = applied
    return applied
end

NSkin:RegisterWindowSkin({
    key = DressUpIDs.Window, module = "Transmogrification",
    addon = "Blizzard_UIPanels_Game",
    apply = function() return TransmogrificationSkin:ApplyDressUp() end,
})

NSkin:RegisterWindowSkin({
    module = "Transmogrification",
    addon = "Blizzard_Transmog",
    apply = function() return TransmogrificationSkin:Initialize() end,
})
