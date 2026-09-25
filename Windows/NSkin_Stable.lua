local _, NSkin = ...

local StableSkin = NSkin:NewModule("Stable")

local IDs = {
    Scope = "Stable",
    Window = "Stable.Window",
    HeaderControls = "Stable.HeaderControls",

    LeftTitle = "Stable.LeftPane.Title",
    PetCounter = "Stable.LeftPane.PetCounter",
    Search = "Stable.LeftPane.Search",
    Filter = "Stable.LeftPane.Filter",
    ScrollBar = "Stable.LeftPane.ScrollBar",

    Categories = "Stable.LeftPane.Categories",
    PetRows = "Stable.LeftPane.PetRows",
    PetPortraits = "Stable.LeftPane.PetPortraits",
    PetNames = "Stable.LeftPane.PetNames",
    PetFamilies = "Stable.LeftPane.PetFamilies",

    PetName = "Stable.RightPane.PetName",
    PetType = "Stable.RightPane.PetType",
    PetExotic = "Stable.RightPane.PetExotic",
    Favorite = "Stable.RightPane.Favorite",
    Rename = "Stable.RightPane.Rename",
    Specialization = "Stable.RightPane.Specialization",
    AbilitiesHeader = "Stable.RightPane.AbilitiesHeader",
    AbilityIcons = "Stable.RightPane.AbilityIcons",
    AbilityNames = "Stable.RightPane.AbilityNames",
    ActiveLabel = "Stable.RightPane.ActiveLabel",
    ActivePets = "Stable.RightPane.ActivePets",
    TogglePet = "Stable.RightPane.TogglePet",
    ReleasePet = "Stable.RightPane.ReleasePet",
}

local initialized = false
local lifecycleHooked = false
local scrollBoxHooked = false
local applyPending = false

local registeredGroups = {}
local suppressedRegions = setmetatable({}, { __mode = "k" })
local hookedCategoryRows = setmetatable({}, { __mode = "k" })
local hookedActivePetButtons = setmetatable({}, { __mode = "k" })

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Stable",
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function IsForbidden(target)
    return target and target.IsForbidden and target:IsForbidden() or false
end

local function IsHovered(target)
    return target and target.IsMouseOver and target:IsMouseOver() or false
end

local function IsSelected(target)
    return target and target.isSelected == true or false
end

local function GetPetList(frame)
    return frame and frame.StabledPetList
end

local function GetScrollBox(frame)
    local petList = GetPetList(frame)
    return petList and petList.ScrollBox
end

local function IsCategoryRow(target)
    return target and target.Label and target.CollapseIcon
        and not target.Portrait
end

local function IsPetRow(target)
    return target and target.Portrait and target.Name and target.Type
end

local function SuppressRegion(region)
    if not region or IsForbidden(region) then return end

    local state = suppressedRegions[region]
    if not state then
        state = {
            alpha = region.GetAlpha and region:GetAlpha() or 1,
            shown = region.IsShown and region:IsShown() or nil,
        }
        suppressedRegions[region] = state
    end

    state.active = true

    local function Conceal()
        if not state.active or state.applying then return end
        state.applying = true
        if region.SetAlpha then region:SetAlpha(0) end
        state.applying = nil
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

local function ForEachListFrame(frame, callback)
    local scrollBox = GetScrollBox(frame)
    if not scrollBox or type(callback) ~= "function" then return false end
    return NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        if target and not IsForbidden(target) then
            callback(target)
        end
    end)
end

local function GetVisibleListTargets(frame, predicate, projector)
    local targets = {}

    ForEachListFrame(frame, function(target)
        if predicate(target) then
            local projected = projector and projector(target) or target
            if projected and IsVisible(projected) then
                targets[#targets + 1] = projected
            end
        end
    end)

    return targets
end

local function GetVisibleCategories(frame)
    return GetVisibleListTargets(frame, IsCategoryRow)
end

local function GetVisiblePetRows(frame)
    return GetVisibleListTargets(frame, IsPetRow)
end

local function GetVisiblePortraits(frame)
    return GetVisibleListTargets(frame, IsPetRow, function(row)
        return row.Portrait
    end)
end

local function GetVisiblePetNames(frame)
    return GetVisibleListTargets(frame, IsPetRow, function(row)
        return row.Name
    end)
end

local function GetVisiblePetFamilies(frame)
    return GetVisibleListTargets(frame, IsPetRow, function(row)
        return row.Type
    end)
end

local function QueueApply()
    if applyPending then return end

    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        StableSkin:Apply()
    end)
end

function StableSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    -- StableFrame adds a large wood topper below PortraitFrameTemplate's
    -- standard title bar. It is purely decorative chrome.
    SuppressRegion(frame.Topper)

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
        closeButton = frame.CloseButton,
    })

    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Stable window",
        kind = "WINDOW",
        module = "Stable",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
        isEditable = function()
            return IsVisible(frame)
        end,
    })

    return true
end

function StableSkin:ApplyLeftStaticControls(frame)
    local petList = GetPetList(frame)
    if not petList then return false end

    local applied = false

    for index, definition in ipairs({
        {
            IDs.LeftTitle,
            "Stable list title",
            petList.ListName,
        },
        {
            IDs.PetCounter,
            "Stable pet counter",
            petList.ListCounter and petList.ListCounter.Count,
        },
    }) do
        local id, label, target = unpack(definition)
        if target then
            local element = NSkin:RegisterTextElement({
                id = id,
                module = "Stable",
                appearanceWindowID = IDs.Scope,
                label = label,
                window = frame,
                target = target,
                priority = 20 + index,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })
            if element then
                NSkin:RefreshTypedElementAppearance(element)
                applied = true
            end
        end
    end

    local filterBar = petList.FilterBar
    local searchBox = filterBar and filterBar.SearchBox
    if searchBox then
        local element = NSkin:RegisterSearchBox({
            id = IDs.Search,
            module = "Stable",
            appearanceWindowID = IDs.Scope,
            label = "Stable search",
            window = frame,
            target = searchBox,
            priority = 30,
            highlightRegions = { searchBox },
            isEditable = function()
                return IsVisible(frame) and IsVisible(searchBox)
            end,
        })
        if element then
            NSkin:RefreshTypedElementAppearance(element)
            applied = true
        end
    end

    local filterDropdown = filterBar and filterBar.FilterDropdown
    if filterDropdown then
        local element = NSkin:RegisterDropdown({
            id = IDs.Filter,
            module = "Stable",
            appearanceWindowID = IDs.Scope,
            label = "Stable filter",
            window = frame,
            target = filterDropdown,
            priority = 31,
            menus = { "MENU_STABLE_FILTER" },
            highlightRegions = { filterDropdown },
            isEditable = function()
                return IsVisible(frame) and IsVisible(filterDropdown)
            end,
        })
        if element then
            NSkin:RefreshTypedElementAppearance(element)
            applied = true
        end
    end

    local scrollBar = petList.ScrollBar
    if scrollBar then
        local element = NSkin:RegisterScrollBar({
            id = IDs.ScrollBar,
            module = "Stable",
            appearanceWindowID = IDs.Scope,
            label = "Stable pet list scroll bar",
            window = frame,
            target = scrollBar,
            priority = 32,
            highlightRegions = { scrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(scrollBar)
            end,
        })
        if element then
            NSkin:RefreshTypedElementAppearance(element)
            applied = true
        end
    end

    return applied
end

function StableSkin:StyleCategoryRow(row)
    if not IsCategoryRow(row) then return false end

    SuppressRegion(row.LeftPiece)
    SuppressRegion(row.CenterPiece)
    SuppressRegion(row.RightPiece)

    local style = NSkin:GetAppearanceStyle(
        "text", IDs.Scope, IDs.Categories)
    NSkin:SkinText(row.Label, style)

    if not hookedCategoryRows[row] and row.HookScript then
        row:HookScript("OnEnter", function()
            NSkin:SkinText(row.Label, NSkin:GetAppearanceStyle(
                "text", IDs.Scope, IDs.Categories))
        end)
        row:HookScript("OnLeave", function()
            NSkin:SkinText(row.Label, NSkin:GetAppearanceStyle(
                "text", IDs.Scope, IDs.Categories))
        end)
        hookedCategoryRows[row] = true
    end

    return true
end

function StableSkin:ApplyCategories(frame)
    local scrollBox = GetScrollBox(frame)
    if not scrollBox then return false end

    local function Refresh()
        local applied = false
        ForEachListFrame(frame, function(target)
            if IsCategoryRow(target) then
                applied = self:StyleCategoryRow(target) or applied
            end
        end)
        return applied
    end

    if not registeredGroups[IDs.Categories] then
        registeredGroups[IDs.Categories] =
            NSkin:RegisterSkinningElement(IDs.Categories, {
                module = "Stable",
                appearanceWindowID = IDs.Scope,
                label = "Stable pet category headers",
                kind = "SECTION_HEADER",
                window = frame,
                target = scrollBox,
                priority = 40,
                draggable = false,
                appearanceStyles = { "text" },
                appearanceTypeIDs = { "TEXT" },
                highlightRegions = function()
                    return GetVisibleCategories(frame)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetVisibleCategories(frame) > 0
                end,
            }) == true
    end

    local applied = Refresh()

    if registeredGroups[IDs.Categories] then
        NSkin:NotifySkinningElementBoundsChanged(IDs.Categories)
    end

    return applied or registeredGroups[IDs.Categories]
end

function StableSkin:StylePetRow(row)
    if not IsPetRow(row) then return false end

    local style = NSkin:GetAppearanceStyle(
        "sectionRow", IDs.Scope, IDs.PetRows)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionRow", style, IDs.Scope, IDs.PetRows)

    return NSkin:SkinSectionRow(row, {
        style = style,
        border = border,
        height = 0,
        preserveTextLayout = true,
        contentRegions = { row.Name, row.Type },
        nativeDecorationRegions = { row.Background },
        hoverRegion = row.Highlight,
        selectedRegion = row.Selected,
        getHovered = IsHovered,
        getSelected = IsSelected,
    }) ~= nil
end

function StableSkin:ApplyPetRows(frame)
    local scrollBox = GetScrollBox(frame)
    if not scrollBox then return false end

    local function Refresh()
        local applied = false
        ForEachListFrame(frame, function(target)
            if IsPetRow(target) then
                applied = self:StylePetRow(target) or applied
            end
        end)
        return applied
    end

    if not registeredGroups[IDs.PetRows] then
        registeredGroups[IDs.PetRows] =
            NSkin:RegisterSkinningElement(IDs.PetRows, {
                module = "Stable",
                appearanceWindowID = IDs.Scope,
                label = "Stable pet rows",
                kind = "BUTTON", rowFamily = "sectionRow",
                window = frame,
                target = scrollBox,
                priority = 50,
                draggable = false,
                highlightRegions = function()
                    return GetVisiblePetRows(frame)
                end,
                pixelBorderTargets = function()
                    return GetVisiblePetRows(frame)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetVisiblePetRows(frame) > 0
                end,
            }) == true
    end

    local applied = Refresh()

    if registeredGroups[IDs.PetRows] then
        NSkin:NotifySkinningElementBoundsChanged(IDs.PetRows)
    end

    return applied or registeredGroups[IDs.PetRows]
end

function StableSkin:StylePetPortrait(row)
    if not IsPetRow(row) then return false end

    local portrait = row.Portrait
    local texture = portrait and portrait.Icon
    if not portrait or not texture then return false end

    local style = NSkin:GetAppearanceStyle(
        "icon", IDs.Scope, IDs.PetPortraits)
    local border = NSkin:GetAppearanceBorderColor(
        "icon", style, IDs.Scope, IDs.PetPortraits)

    return NSkin:SkinIcon(portrait, {
        texture = texture,
        borderOwner = portrait,
        style = style,
        border = border,
        nativeDecorationRegions = {
            portrait.Border,
        },
    }) ~= nil
end

function StableSkin:ApplyPetPortraits(frame)
    local scrollBox = GetScrollBox(frame)
    if not scrollBox then return false end

    local function Refresh()
        local applied = false
        ForEachListFrame(frame, function(target)
            if IsPetRow(target) then
                applied = self:StylePetPortrait(target) or applied
            end
        end)
        return applied
    end

    if not registeredGroups[IDs.PetPortraits] then
        registeredGroups[IDs.PetPortraits] =
            NSkin:RegisterSkinningElement(IDs.PetPortraits, {
                module = "Stable",
                appearanceWindowID = IDs.Scope,
                label = "Stable pet portraits",
                kind = "ICON",
                window = frame,
                target = scrollBox,
                priority = 51,
                draggable = false,
                highlightRegions = function()
                    return GetVisiblePortraits(frame)
                end,
                pixelBorderTargets = function()
                    return GetVisiblePortraits(frame)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetVisiblePortraits(frame) > 0
                end,
            }) == true
    end

    local applied = Refresh()

    if registeredGroups[IDs.PetPortraits] then
        NSkin:NotifySkinningElementBoundsChanged(IDs.PetPortraits)
    end

    return applied or registeredGroups[IDs.PetPortraits]
end

local function ApplyTextFamily(frame, id, label, priority, provider)
    local function Refresh()
        local style = NSkin:GetAppearanceStyle("text", IDs.Scope, id)
        local applied = false
        for _, target in ipairs(provider(frame)) do
            applied = NSkin:SkinText(target, style) or applied
        end
        return applied
    end

    local scrollBox = GetScrollBox(frame)
    if not scrollBox then return false end

    if not registeredGroups[id] then
        registeredGroups[id] = NSkin:RegisterSkinningElement(id, {
            module = "Stable",
            appearanceWindowID = IDs.Scope,
            label = label,
            kind = "TEXT",
            window = frame,
            target = scrollBox,
            priority = priority,
            draggable = false,
            highlightRegions = function()
                return provider(frame)
            end,
            refreshAppearance = Refresh,
            refreshLayout = Refresh,
            isEditable = function()
                return IsVisible(frame) and #provider(frame) > 0
            end,
        }) == true
    end

    local applied = Refresh()

    if registeredGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end

    return applied or registeredGroups[id]
end

function StableSkin:ApplyPetText(frame)
    local applied = ApplyTextFamily(
        frame,
        IDs.PetNames,
        "Stable pet names",
        52,
        GetVisiblePetNames
    )

    applied = ApplyTextFamily(
        frame,
        IDs.PetFamilies,
        "Stable pet families",
        53,
        GetVisiblePetFamilies
    ) or applied

    return applied
end

function StableSkin:StyleListTarget(frame, target)
    if IsCategoryRow(target) then
        self:StyleCategoryRow(target)
    elseif IsPetRow(target) then
        self:StylePetRow(target)
        self:StylePetPortrait(target)

        local nameStyle = NSkin:GetAppearanceStyle(
            "text", IDs.Scope, IDs.PetNames)
        local familyStyle = NSkin:GetAppearanceStyle(
            "text", IDs.Scope, IDs.PetFamilies)

        NSkin:SkinText(target.Name, nameStyle)
        NSkin:SkinText(target.Type, familyStyle)
    end

    for _, id in ipairs({
        IDs.Categories,
        IDs.PetRows,
        IDs.PetPortraits,
        IDs.PetNames,
        IDs.PetFamilies,
    }) do
        if registeredGroups[id] then
            NSkin:NotifySkinningElementBoundsChanged(id)
        end
    end
end

function StableSkin:HookScrollBox(frame)
    local scrollBox = GetScrollBox(frame)
    if not scrollBox or scrollBoxHooked then return false end

    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, target)
                StableSkin:StyleListTarget(frame, target)
            end, self)
        scrollBoxHooked = true
    elseif _G.hooksecurefunc and type(scrollBox.Update) == "function" then
        _G.hooksecurefunc(scrollBox, "Update", function()
            StableSkin:ApplyLeftPane(frame)
        end)
        scrollBoxHooked = true
    end

    return scrollBoxHooked
end

function StableSkin:ApplyLeftPane(frame)
    local petList = GetPetList(frame)
    if not petList then return false end

    -- Remove the Stable-specific wood/list artwork while keeping the
    -- ScrollBox, controls, and row geometry intact.
    SuppressRegion(petList.Backgroud)
    SuppressRegion(petList.Background)
    SuppressRegion(petList.FilterBar and petList.FilterBar.Background)
    if petList.Inset then
        NSkin:ConcealWindowArtwork(petList.Inset)
    end

    local listCounter = petList.ListCounter
    if listCounter then
        NSkin:ConcealWindowArtwork(listCounter)
    end

    local applied = self:ApplyLeftStaticControls(frame)
    applied = self:ApplyCategories(frame) or applied
    applied = self:ApplyPetRows(frame) or applied
    applied = self:ApplyPetPortraits(frame) or applied
    applied = self:ApplyPetText(frame) or applied
    return applied
end


local function GetRightPane(frame)
    local scene = frame and frame.PetModelScene
    return scene,
        scene and scene.PetInfo,
        scene and scene.AbilitiesList,
        frame and frame.ActivePetList
end

local function GetAbilityFrames(frame, visibleOnly)
    local _, _, abilities = GetRightPane(frame)
    local targets = {}
    local pool = abilities and abilities.abilityPool
    if not pool or type(pool.EnumerateActive) ~= "function" then
        return targets
    end

    for ability in pool:EnumerateActive() do
        if ability and (not visibleOnly or IsVisible(ability)) then
            targets[#targets + 1] = ability
        end
    end
    return targets
end

local function GetAbilityIcons(frame, visibleOnly)
    local targets = {}
    for _, ability in ipairs(GetAbilityFrames(frame, visibleOnly)) do
        if ability.Icon and (not visibleOnly or IsVisible(ability.Icon)) then
            targets[#targets + 1] = ability.Icon
        end
    end
    return targets
end

local function GetAbilityNames(frame, visibleOnly)
    local targets = {}
    for _, ability in ipairs(GetAbilityFrames(frame, visibleOnly)) do
        if ability.Name and (not visibleOnly or IsVisible(ability.Name)) then
            targets[#targets + 1] = ability.Name
        end
    end
    return targets
end

local function GetActivePetButtons(frame, visibleOnly)
    local _, _, _, activeList = GetRightPane(frame)
    local targets = {}
    if not activeList then return targets end

    for _, button in ipairs(activeList.PetButtons or {}) do
        if button and (not visibleOnly or IsVisible(button)) then
            targets[#targets + 1] = button
        end
    end

    local secondary = activeList.BeastMasterSecondaryPetButton
    if secondary and (not visibleOnly or IsVisible(secondary)) then
        targets[#targets + 1] = secondary
    end
    return targets
end

local function RegisterRightText(frame, id, label, target, priority)
    if not target then return false end
    local element = NSkin:RegisterTextElement({
        id = id,
        module = "Stable",
        appearanceWindowID = IDs.Scope,
        label = label,
        window = frame,
        target = target,
        priority = priority,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(frame) and IsVisible(target)
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element ~= nil
end

function StableSkin:ApplyRightPetInfo(frame)
    local _, info = GetRightPane(frame)
    if not info then return false end

    local applied = false
    applied = RegisterRightText(
        frame, IDs.PetName, "Selected pet name",
        info.NameBox and info.NameBox.Name, 100) or applied
    applied = RegisterRightText(
        frame, IDs.PetType, "Selected pet family",
        info.Type, 101) or applied
    applied = RegisterRightText(
        frame, IDs.PetExotic, "Selected pet exotic label",
        info.Exotic, 102) or applied

    local favorite = info.FavoriteButton
    if favorite then
        local element = NSkin:RegisterCheckbox({
            id = IDs.Favorite,
            module = "Stable",
            appearanceWindowID = IDs.Scope,
            label = "Pet favorite",
            window = frame,
            target = favorite,
            getChecked = function(button)
                return button.IsFavorited and button:IsFavorited() or false
            end,
            priority = 103,
            highlightRegions = { favorite },
            isEditable = function()
                return IsVisible(frame) and IsVisible(favorite)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    local rename = info.NameBox and info.NameBox.EditButton
    if rename then
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.Rename,
            module = "Stable",
            appearanceWindowID = IDs.Scope,
            label = "Rename pet button",
            window = frame,
            target = rename,
            priority = 104,
            highlightRegions = { rename },
            isEditable = function()
                return IsVisible(frame) and IsVisible(rename)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    local specialization = info.Specialization
    if specialization then
        local element = NSkin:RegisterDropdown({
            id = IDs.Specialization,
            module = "Stable",
            appearanceWindowID = IDs.Scope,
            label = "Pet specialization",
            window = frame,
            target = specialization,
            priority = 105,
            menus = { "MENU_PET_SPEC_OPTIONS" },
            highlightRegions = { specialization },
            isEditable = function()
                return IsVisible(frame) and IsVisible(specialization)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    return applied
end

function StableSkin:ApplyAbilities(frame)
    local _, _, abilities = GetRightPane(frame)
    if not abilities then return false end
    local applied = false

    if abilities.ListHeader then
        local function RefreshHeader()
            return NSkin:SkinText(
                abilities.ListHeader,
                NSkin:GetAppearanceStyle(
                    "text", IDs.Scope, IDs.AbilitiesHeader)
            )
        end

        if not registeredGroups[IDs.AbilitiesHeader] then
            registeredGroups[IDs.AbilitiesHeader] =
                NSkin:RegisterSkinningElement(IDs.AbilitiesHeader, {
                    module = "Stable",
                    appearanceWindowID = IDs.Scope,
                    label = "Special abilities header",
                    kind = "SECTION_HEADER",
                    window = frame,
                    target = abilities.ListHeader,
                    priority = 110,
                    draggable = false,
                    appearanceStyles = { "text" },
                    appearanceTypeIDs = { "TEXT" },
                    highlightRegions = { abilities.ListHeader },
                    refreshAppearance = RefreshHeader,
                    refreshLayout = RefreshHeader,
                    isEditable = function()
                        return IsVisible(frame)
                            and IsVisible(abilities.ListHeader)
                    end,
                }) == true
        end
        applied = RefreshHeader() or applied
    end

    local function RefreshIcons()
        local style = NSkin:GetAppearanceStyle(
            "icon", IDs.Scope, IDs.AbilityIcons)
        local border = NSkin:GetAppearanceBorderColor(
            "icon", style, IDs.Scope, IDs.AbilityIcons)
        local changed = false

        for _, ability in ipairs(GetAbilityFrames(frame, false)) do
            if ability.Icon then
                changed = NSkin:SkinIcon(ability, {
                    texture = ability.Icon,
                    borderOwner = ability,
                    style = style,
                    border = border,
                }) or changed
            end
        end
        return changed
    end

    if not registeredGroups[IDs.AbilityIcons] then
        registeredGroups[IDs.AbilityIcons] =
            NSkin:RegisterSkinningElement(IDs.AbilityIcons, {
                module = "Stable",
                appearanceWindowID = IDs.Scope,
                label = "Pet ability icons",
                kind = "ICON",
                window = frame,
                target = abilities,
                priority = 111,
                draggable = false,
                highlightRegions = function()
                    return GetAbilityIcons(frame, true)
                end,
                pixelBorderTargets = function()
                    return GetAbilityIcons(frame, true)
                end,
                refreshAppearance = RefreshIcons,
                refreshLayout = RefreshIcons,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetAbilityIcons(frame, true) > 0
                end,
            }) == true
    end
    applied = RefreshIcons() or applied

    local function RefreshNames()
        local style = NSkin:GetAppearanceStyle(
            "text", IDs.Scope, IDs.AbilityNames)
        local changed = false
        for _, target in ipairs(GetAbilityNames(frame, false)) do
            changed = NSkin:SkinText(target, style) or changed
        end
        return changed
    end

    if not registeredGroups[IDs.AbilityNames] then
        registeredGroups[IDs.AbilityNames] =
            NSkin:RegisterSkinningElement(IDs.AbilityNames, {
                module = "Stable",
                appearanceWindowID = IDs.Scope,
                label = "Pet ability names",
                kind = "TEXT",
                window = frame,
                target = abilities,
                priority = 112,
                draggable = false,
                highlightRegions = function()
                    return GetAbilityNames(frame, true)
                end,
                refreshAppearance = RefreshNames,
                refreshLayout = RefreshNames,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetAbilityNames(frame, true) > 0
                end,
            }) == true
    end
    applied = RefreshNames() or applied

    for _, id in ipairs({
        IDs.AbilitiesHeader,
        IDs.AbilityIcons,
        IDs.AbilityNames,
    }) do
        if registeredGroups[id] then
            NSkin:NotifySkinningElementBoundsChanged(id)
        end
    end

    return applied
end

function StableSkin:ApplyActivePets(frame)
    local _, _, _, activeList = GetRightPane(frame)
    if not activeList then return false end
    local applied = false

    -- The footer artwork is decorative; the individual pet buttons remain
    -- Blizzard interaction owners.
    SuppressRegion(activeList.ActivePetListBG)
    SuppressRegion(activeList.ActivePetListBGBar)

    applied = RegisterRightText(
        frame, IDs.ActiveLabel, "Active pets label",
        activeList.ListName, 120) or applied

    local function Refresh()
        local style = NSkin:GetAppearanceStyle(
            "icon", IDs.Scope, IDs.ActivePets)
        local border = NSkin:GetAppearanceBorderColor(
            "icon", style, IDs.Scope, IDs.ActivePets)
        local changed = false

        for _, button in ipairs(GetActivePetButtons(frame, false)) do
            if button.Icon then
                changed = NSkin:SkinIcon(button, {
                    texture = button.Icon,
                    borderOwner = button,
                    style = style,
                    border = border,
                    nativeDecorationRegions = { button.Border },
                    selectedRegion = button.Highlight,
                    getSelected = IsSelected,
                }) or changed

                if not hookedActivePetButtons[button]
                    and _G.hooksecurefunc
                    and type(button.OnPetSelected) == "function"
                then
                    pcall(_G.hooksecurefunc, button, "OnPetSelected", function()
                        StableSkin:ApplyActivePets(frame)
                    end)
                    hookedActivePetButtons[button] = true
                end
            end
        end
        return changed
    end

    if not registeredGroups[IDs.ActivePets] then
        registeredGroups[IDs.ActivePets] =
            NSkin:RegisterSkinningElement(IDs.ActivePets, {
                module = "Stable",
                appearanceWindowID = IDs.Scope,
                label = "Active pet slots",
                kind = "ICON",
                window = frame,
                target = activeList,
                priority = 121,
                draggable = false,
                highlightRegions = function()
                    return GetActivePetButtons(frame, true)
                end,
                pixelBorderTargets = function()
                    return GetActivePetButtons(frame, true)
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and #GetActivePetButtons(frame, true) > 0
                end,
            }) == true
    end
    applied = Refresh() or applied

    if registeredGroups[IDs.ActivePets] then
        NSkin:NotifySkinningElementBoundsChanged(IDs.ActivePets)
    end

    return applied
end

function StableSkin:ApplyRightActions(frame)
    local applied = false

    local toggle = frame and frame.StableTogglePetButton
    if toggle then
        local element = NSkin:RegisterActionButton({
            id = IDs.TogglePet,
            module = "Stable",
            appearanceWindowID = IDs.Scope,
            label = "Stable or make active pet button",
            window = frame,
            target = toggle,
            priority = 130,
            highlightRegions = { toggle },
            isEditable = function()
                return IsVisible(frame) and IsVisible(toggle)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    local release = frame and frame.ReleasePetButton
    if release then
        local element = NSkin:RegisterTypedElement("BUTTON", {
            id = IDs.ReleasePet,
            module = "Stable",
            appearanceWindowID = IDs.Scope,
            label = "Release pet button",
            window = frame,
            target = release,
            priority = 131,
            highlightRegions = { release },
            isEditable = function()
                return IsVisible(frame) and IsVisible(release)
            end,
        })
        if element then NSkin:RefreshTypedElementAppearance(element) end
        applied = element ~= nil or applied
    end

    return applied
end

function StableSkin:ApplyRightPane(frame)
    local scene, _, abilities = GetRightPane(frame)
    if not scene then return false end

    -- Keep the model/background content, but remove the native inset chrome
    -- around the right pane.
    if scene.Inset then
        NSkin:ConcealWindowArtwork(scene.Inset)
    end

    local applied = self:ApplyRightPetInfo(frame)
    applied = self:ApplyAbilities(frame) or applied
    applied = self:ApplyActivePets(frame) or applied
    applied = self:ApplyRightActions(frame) or applied

    if abilities and not abilities.NSkinLifecycleHooked
        and _G.hooksecurefunc
        and type(abilities.OnPetSelected) == "function"
    then
        pcall(_G.hooksecurefunc, abilities, "OnPetSelected", function()
            StableSkin:ApplyAbilities(frame)
        end)
        abilities.NSkinLifecycleHooked = true
    end

    return applied
end

function StableSkin:Apply()
    local frame = _G.StableFrame
    if not frame then return false end

    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyLeftPane(frame) or applied
    applied = self:ApplyRightPane(frame) or applied
    return applied
end

function StableSkin:Initialize()
    local frame = _G.StableFrame
    if not frame then return false end

    if not lifecycleHooked then
        if frame.HookScript then
            frame:HookScript("OnShow", QueueApply)
        end

        if _G.hooksecurefunc and type(frame.Refresh) == "function" then
            _G.hooksecurefunc(frame, "Refresh", QueueApply)
        end

        lifecycleHooked = true
    end

    self:HookScrollBox(frame)

    initialized = true

    local applied = self:Apply()
    if IsVisible(frame) then
        QueueApply()
    end

    return applied
end

function StableSkin:RefreshAppearance()
    if initialized then
        self:Apply()
    end
end

NSkin:RegisterWindowSkin({
    module = "Stable",
    addon = "Blizzard_StableUI",
    apply = function()
        return StableSkin:Initialize()
    end,
})
