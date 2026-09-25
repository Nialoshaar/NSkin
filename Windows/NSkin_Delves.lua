local _, NSkin = ...

local DelvesSkin = NSkin:NewModule("Delves")

local IDs = {
    Scope = "Delves",
    Window = "Delves.DifficultyPicker.Window",
    HeaderControls = "Delves.DifficultyPicker.HeaderControls",
    ScenarioLabel = "Delves.DifficultyPicker.ScenarioLabel",
    Title = "Delves.DifficultyPicker.Title",
    ModifiersLabel = "Delves.DifficultyPicker.ModifiersLabel",
    Description = "Delves.DifficultyPicker.Description",
    RewardText = "Delves.DifficultyPicker.RewardText",
    EnterButton = "Delves.DifficultyPicker.EnterButton",
    Dropdown = "Delves.DifficultyPicker.Dropdown",
    DropdownScrollBar = "Delves.DifficultyPicker.Dropdown.ScrollBar",
    Rewards = "Delves.DifficultyPicker.Rewards",
    CompanionWindow = "Delves.CompanionConfiguration.Window",
    CompanionHeaderControls =
        "Delves.CompanionConfiguration.HeaderControls",
    CompanionName = "Delves.CompanionConfiguration.CompanionName",
    CompanionDescription =
        "Delves.CompanionConfiguration.CompanionDescription",
    CompanionCombatRoleLabel =
        "Delves.CompanionConfiguration.CombatRoleLabel",
    CompanionFlavorLabel = "Delves.CompanionConfiguration.FlavorLabel",
    CompanionCombatTrinketLabel =
        "Delves.CompanionConfiguration.CombatTrinketLabel",
    CompanionUtilityTrinketLabel =
        "Delves.CompanionConfiguration.UtilityTrinketLabel",
    CompanionAbilitiesButton =
        "Delves.CompanionConfiguration.AbilitiesButton",
    AbilityListWindow = "Delves.CompanionAbilityList.Window",
    AbilityListHeaderControls =
        "Delves.CompanionAbilityList.HeaderControls",
    AbilityRoleDropdown = "Delves.CompanionAbilityList.RoleDropdown",
    AbilityItems = "Delves.CompanionAbilityList.Abilities",
    AbilityPagination = {
        Group = "Delves.CompanionAbilityList.Pagination",
        Previous = "Delves.CompanionAbilityList.Pagination.Previous",
        Next = "Delves.CompanionAbilityList.Pagination.Next",
        Text = "Delves.CompanionAbilityList.Pagination.Text",
    },
}

local DROPDOWN_MENUS = {
    "MENU_DELVES_DIFFICULTY",
    "MENU_LAIRS_DIFFICULTY",
}

local initialized = false
local showHooked = false
local rewardScrollBoxHooked = false
local dropdownMenuHooked = false
local dropdownScrollBarRegistered = false
local rewardsRegistered = false
local companionInitialized = false
local companionShowHooked = false
local companionRefreshHooked = false
local abilityListInitialized = false
local abilityListShowHooked = false
local abilityListRefreshHooked = false
local abilityItemsRegistered = false
local abilityPaginationController

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Delves",
})

local function IsVisible(target)
    return target and target.IsVisible and target:IsVisible() or false
end

local function CompactRegions(...)
    local regions = {}
    for index = 1, select("#", ...) do
        local region = select(index, ...)
        if region then regions[#regions + 1] = region end
    end
    return regions
end

local function SuppressRegions(owner, key, regions)
    if not owner then return end
    local data = NSkin:GetSkinData(owner, "delvesDecorations")
    data[key] = data[key] or { states = {} }
    local group = data[key]
    for _, region in ipairs(regions or {}) do
        local state = group.states[region]
        if not state then
            state = {
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = region.IsShown and region:IsShown() or nil,
            }
            group.states[region] = state
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
end

local function SuppressEdgeRegions(owner, key, edgeOwner, ...)
    if not edgeOwner then return end
    SuppressRegions(owner, key, CompactRegions(
        edgeOwner.RightEdge,
        edgeOwner.LeftEdge,
        edgeOwner.TopEdge,
        edgeOwner.BottomEdge,
        ...
    ))
end

local function GetRewardsContainer(frame)
    return frame and frame.DelveRewardsContainerFrame
end

local function GetRewardsScrollBox(frame)
    local container = GetRewardsContainer(frame)
    return container and (container.ScrollBox or container.Scrollbox)
end

local function GetVisibleRewardButtons(frame)
    local buttons = {}
    NSkin:ForEachScrollBoxFrame(GetRewardsScrollBox(frame), function(button)
        if IsVisible(button) then buttons[#buttons + 1] = button end
    end)
    return buttons
end

local function GetRewardDescriptors(frame)
    local descriptors = {}
    for _, button in ipairs(GetVisibleRewardButtons(frame)) do
        local texture = button.Icon or button.icon or button.IconTexture
            or _G.DelvesDifficultyPickerFrameIconTexture
        if texture then
            descriptors[#descriptors + 1] = {
                target = button,
                texture = texture,
                borderOwner = button,
                nativeDecorationRegions = CompactRegions(
                    button.IconBorder, button.NameFrame),
                hoverRegion = button.GetHighlightTexture
                    and button:GetHighlightTexture()
                    or button.HighlightTexture,
                getHovered = function(target)
                    return target and target.IsMouseOver
                        and target:IsMouseOver() or false
                end,
            }
        end
    end
    return descriptors
end

local function SkinRewardText(frame)
    local appearanceID = NSkin:GetElementAppearanceID(IDs.Rewards, "TEXT")
    local style = NSkin:GetAppearanceStyle(
        "text", IDs.Scope, appearanceID)
    local applied = false
    for _, button in ipairs(GetVisibleRewardButtons(frame)) do
        local text = button.Name or button.name
        if text then
            applied = NSkin:SkinText(text, style) == true or applied
        end
    end
    return applied
end

local function GetDropdownMenuScrollBar(dropdown)
    local menu = dropdown and dropdown.menu
    if not menu then return nil end
    return menu.Scrollbar or menu.ScrollBar
        or (menu.ScrollBox
            and (menu.ScrollBox.Scrollbar or menu.ScrollBox.ScrollBar))
end

function DelvesSkin:ApplyWindowChrome(frame)
    SuppressEdgeRegions(frame, "DifficultyPickerBorder", frame.Border)
    if frame.Border then NSkin:ConcealWindowArtwork(frame.Border) end
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        headerControlsID = IDs.HeaderControls,
        title = frame.Title,
        closeButton = frame.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Delve difficulty picker window",
        kind = "WINDOW",
        module = "Delves",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function DelvesSkin:ApplyTexts(frame)
    local modifiers = frame.DelveModifiersWidgetContainer
    local rewards = GetRewardsContainer(frame)
    local applied = false
    for index, definition in ipairs({
        { IDs.ScenarioLabel, "Delve scenario label", frame.ScenarioLabel },
        { IDs.Title, "Delve title", frame.Title },
        { IDs.ModifiersLabel, "Delve modifiers label",
            modifiers and modifiers.ModifiersLabel },
        { IDs.Description, "Delve description", frame.Description },
        { IDs.RewardText, "Delve reward text",
            frame.RewardText or (rewards and rewards.RewardText) },
    }) do
        local target = definition[3]
        if target then
            local element = NSkin:RegisterTextElement({
                id = definition[1],
                module = "Delves",
                appearanceWindowID = IDs.Scope,
                label = definition[2],
                window = frame,
                target = target,
                priority = 20 + index,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })
            if element then NSkin:RefreshTypedElementAppearance(element) end
            applied = element ~= nil or applied
        end
    end
    return applied
end

function DelvesSkin:ApplyEnterButton(frame)
    local button = frame.EnterdDelveButton or frame.EnterDelveButton
    if not button then return false end
    local element = NSkin:RegisterTypedElement("BUTTON", {
        id = IDs.EnterButton,
        module = "Delves",
        appearanceWindowID = IDs.Scope,
        label = "Enter delve button",
        window = frame,
        target = button,
        priority = 40,
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element ~= nil
end

function DelvesSkin:ApplyDropdownMenuScrollBar(frame)
    local dropdown = frame.Dropdown
    local scrollBar = GetDropdownMenuScrollBar(dropdown)
    if scrollBar then
        NSkin:SkinScrollBar(scrollBar, NSkin:GetAppearanceStyle(
            "scrollBar", IDs.Scope, IDs.DropdownScrollBar))
    end
    if not dropdownScrollBarRegistered and dropdown then
        local function Refresh()
            return DelvesSkin:ApplyDropdownMenuScrollBar(frame)
        end
        dropdownScrollBarRegistered = NSkin:RegisterSkinningElement(
            IDs.DropdownScrollBar, {
                module = "Delves",
                appearanceWindowID = IDs.Scope,
                label = "Delve difficulty menu scroll bar",
                kind = "SCROLLBAR",
                window = frame,
                target = dropdown,
                priority = 51,
                draggable = false,
                highlightRegions = function()
                    local target = GetDropdownMenuScrollBar(dropdown)
                    return target and { target } or {}
                end,
                pixelBorderTargets = function()
                    local target = GetDropdownMenuScrollBar(dropdown)
                    return target and { target } or {}
                end,
                refreshAppearance = Refresh,
                refreshLayout = Refresh,
                isEditable = function()
                    return IsVisible(frame)
                        and IsVisible(GetDropdownMenuScrollBar(dropdown))
                end,
            }) == true
    end
    if dropdownScrollBarRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.DropdownScrollBar)
    end
    return scrollBar ~= nil or dropdownScrollBarRegistered
end

function DelvesSkin:ApplyDropdown(frame)
    local dropdown = frame.Dropdown
    if not dropdown then return false end
    local element = NSkin:RegisterDropdown({
        id = IDs.Dropdown,
        module = "Delves",
        appearanceWindowID = IDs.Scope,
        label = "Delve difficulty dropdown",
        window = frame,
        target = dropdown,
        menus = DROPDOWN_MENUS,
        priority = 50,
        highlightRegions = { dropdown },
        isEditable = function()
            return IsVisible(frame) and IsVisible(dropdown)
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end

    local events = _G.DropdownButtonMixin and _G.DropdownButtonMixin.Event
    if not dropdownMenuHooked and dropdown.RegisterCallback and events
        and events.OnMenuOpen
    then
        dropdown:RegisterCallback(events.OnMenuOpen, function()
            DelvesSkin:ApplyDropdownMenuScrollBar(frame)
        end, self)
        dropdownMenuHooked = true
    end
    self:ApplyDropdownMenuScrollBar(frame)
    return element ~= nil
end

function DelvesSkin:ApplyRewards(frame)
    local scrollBox = GetRewardsScrollBox(frame)
    if not scrollBox then return false end
    if not rewardsRegistered then
        rewardsRegistered = NSkin:RegisterIconGroup({
            id = IDs.Rewards,
            module = "Delves",
            appearanceWindowID = IDs.Scope,
            label = "Delve reward icons and text",
            window = frame,
            target = scrollBox,
            priority = 60,
            draggable = false,
            children = function()
                return GetRewardDescriptors(frame)
            end,
            refreshContent = function()
                return SkinRewardText(frame)
            end,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            editorOptions = {
                { id = "shared.iconAppearance", label = "Icons",
                    presentation = "INLINE", category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Text",
                    category = "CUSTOMIZE" },
            },
            highlightRegions = function()
                return GetVisibleRewardButtons(frame)
            end,
            pixelBorderTargets = function()
                return GetVisibleRewardButtons(frame)
            end,
            isEditable = function()
                return IsVisible(frame)
                    and #GetVisibleRewardButtons(frame) > 0
            end,
        }) ~= nil
    else
        NSkin:RefreshIconGroup(IDs.Rewards)
    end
    SkinRewardText(frame)
    if rewardsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.Rewards)
    end
    return rewardsRegistered
end

function DelvesSkin:HookRewardScrollBox(frame)
    local scrollBox = GetRewardsScrollBox(frame)
    if not scrollBox or rewardScrollBoxHooked then return false end
    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame, function()
            DelvesSkin:ApplyRewards(frame)
        end, self)
        rewardScrollBoxHooked = true
    end
    return rewardScrollBoxHooked
end

function DelvesSkin:Apply()
    local frame = _G.DelvesDifficultyPickerFrame
    if not frame then return false end
    local applied = self:ApplyWindowChrome(frame)
    applied = self:ApplyTexts(frame) or applied
    applied = self:ApplyEnterButton(frame) or applied
    applied = self:ApplyDropdown(frame) or applied
    applied = self:ApplyRewards(frame) or applied
    return applied
end

function DelvesSkin:Initialize()
    local frame = _G.DelvesDifficultyPickerFrame
    if not frame then return false end
    if not showHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            DelvesSkin:Apply()
        end)
        showHooked = true
    end
    self:HookRewardScrollBox(frame)
    initialized = true
    return self:Apply()
end

function DelvesSkin:RefreshAppearance()
    if initialized then self:Apply() end
    if companionInitialized then self:ApplyCompanionConfiguration() end
    if abilityListInitialized then self:ApplyCompanionAbilityList() end
end

NSkin:RegisterWindowSkin({
    key = "Delves.DifficultyPicker",
    module = "Delves",
    addon = "Blizzard_DelvesDifficultyPicker",
    apply = function() return DelvesSkin:Initialize() end,
})

local function SuppressCompanionBackground(frame)
    local background = frame and frame.Background
    if not background then return end
    if background.SetAlpha then background:SetAlpha(0) end
    if background.SetTexture then background:SetTexture(nil) end
    if background.Hide then background:Hide() end
end

function DelvesSkin:ApplyCompanionWindowChrome(frame)
    SuppressCompanionBackground(frame)
    local border = frame.Border
    SuppressEdgeRegions(frame, "CompanionConfigurationBorder", border,
        border and border.BottomRight,
        border and border.BottomLeft,
        border and border.TopLeftCorner)
    if frame.Border then NSkin:ConcealWindowArtwork(frame.Border) end
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.CompanionWindow,
        headerControlsID = IDs.CompanionHeaderControls,
        closeButton = frame.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.CompanionWindow, {
        label = "Delve companion configuration window",
        kind = "WINDOW",
        module = "Delves",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function DelvesSkin:ApplyCompanionTexts(frame)
    local info = frame.CompanionInfoFrame
    local slots = frame.CompanionSlots
    local role = slots and slots.CompanionCombatRoleSlot
    local flavor = slots and slots.CompanionFlavorSlot
    local combat = slots and slots.CompanionCombatTrinketSlot
    local utility = slots and slots.CompanionUtilityTrinketSlot
    local applied = false
    for index, definition in ipairs({
        {
            IDs.CompanionName, "Delve companion name",
            info and info.CompanionName,
        },
        {
            IDs.CompanionDescription, "Delve companion description",
            info and (info.CompanionDescription or info.Description),
        },
        {
            IDs.CompanionCombatRoleLabel, "Companion combat role label",
            role and role.Label
                or _G.DelvesCompanionConfigurationFrameCompanionCombatRoleSlotLabel,
        },
        {
            IDs.CompanionFlavorLabel, "Companion flavor label",
            flavor and flavor.Label
                or _G.DelvesCompanionConfigurationFrameCompanionFlavorSlotLabel,
        },
        {
            IDs.CompanionCombatTrinketLabel,
            "Companion combat trinket label",
            combat and combat.Label,
        },
        {
            IDs.CompanionUtilityTrinketLabel,
            "Companion utility trinket label",
            utility and utility.Label,
        },
    }) do
        local target = definition[3]
        if target then
            local element = NSkin:RegisterTextElement({
                id = definition[1],
                module = "Delves",
                appearanceWindowID = IDs.Scope,
                label = definition[2],
                window = frame,
                target = target,
                priority = 80 + index,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            })
            if element then NSkin:RefreshTypedElementAppearance(element) end
            applied = element ~= nil or applied
        end
    end
    return applied
end

function DelvesSkin:ApplyCompanionAbilitiesButton(frame)
    local button = frame.ConpanionConfigShowAbilitiesButton
        or frame.CompanionConfigShowAbilitiesButton
    if not button then return false end
    local element = NSkin:RegisterTypedElement("BUTTON", {
        id = IDs.CompanionAbilitiesButton,
        module = "Delves",
        appearanceWindowID = IDs.Scope,
        label = "Show companion abilities button",
        window = frame,
        target = button,
        priority = 90,
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element ~= nil
end

function DelvesSkin:ApplyCompanionContent(frame)
    local applied = self:ApplyCompanionTexts(frame)
    applied = self:ApplyCompanionAbilitiesButton(frame) or applied
    return applied
end

function DelvesSkin:ApplyCompanionConfiguration()
    local frame = _G.DelvesCompanionConfigurationFrame
    if not frame then return false end
    local applied = self:ApplyCompanionWindowChrome(frame)
    applied = self:ApplyCompanionContent(frame) or applied
    return applied
end

function DelvesSkin:InitializeCompanionConfiguration()
    local frame = _G.DelvesCompanionConfigurationFrame
    if not frame then return false end
    if not companionShowHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            DelvesSkin:ApplyCompanionConfiguration()
        end)
        companionShowHooked = true
    end
    if not companionRefreshHooked and _G.hooksecurefunc
        and type(frame.Refresh) == "function"
    then
        _G.hooksecurefunc(frame, "Refresh", function()
            DelvesSkin:ApplyCompanionContent(frame)
        end)
        companionRefreshHooked = true
    end
    companionInitialized = true
    return self:ApplyCompanionConfiguration()
end

NSkin:RegisterWindowSkin({
    key = "Delves.CompanionConfiguration",
    module = "Delves",
    addon = "Blizzard_DelvesCompanionConfiguration",
    apply = function()
        return DelvesSkin:InitializeCompanionConfiguration()
    end,
})

local function GetVisibleAbilityButtons(frame)
    local buttons = {}
    for _, button in ipairs(frame and frame.buttons or {}) do
        if IsVisible(button) then buttons[#buttons + 1] = button end
    end
    return buttons
end

local function GetAbilityDescriptors(frame)
    local descriptors = {}
    for _, button in ipairs(GetVisibleAbilityButtons(frame)) do
        local texture = button.Icon or button.icon or button.IconTexture
        if texture then
            descriptors[#descriptors + 1] = {
                target = button,
                texture = texture,
                borderOwner = button,
                nativeDecorationRegions = CompactRegions(button.IconBorder),
                hoverRegion = button.GetHighlightTexture
                    and button:GetHighlightTexture()
                    or button.HighlightTexture,
                getHovered = function(target)
                    return target and target.IsMouseOver
                        and target:IsMouseOver() or false
                end,
            }
        end
    end
    return descriptors
end

local function SkinAbilityTexts(frame)
    local appearanceID = NSkin:GetElementAppearanceID(
        IDs.AbilityItems, "TEXT")
    local style = NSkin:GetAppearanceStyle(
        "text", IDs.Scope, appearanceID)
    local applied = false
    for _, button in ipairs(GetVisibleAbilityButtons(frame)) do
        local target = button.Text or button.Name or button.name
        if target then
            applied = NSkin:SkinText(target, style) == true or applied
        end
    end
    return applied
end

function DelvesSkin:ApplyCompanionAbilityListWindowChrome(frame)
    SuppressEdgeRegions(frame, "CompanionAbilityListNineSlice",
        frame.NineSlice)
    SuppressRegions(frame, "CompanionAbilityListBackground",
        CompactRegions(frame.CompanionAbilityListBackground))
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.AbilityListWindow,
        headerControlsID = IDs.AbilityListHeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText
            or frame.Title,
        closeButton = frame.CloseButton,
    })
    NSkin:RegisterSkinningElement(IDs.AbilityListWindow, {
        label = "Delve companion ability list window",
        kind = "WINDOW",
        module = "Delves",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function DelvesSkin:ApplyCompanionAbilityRoleDropdown(frame)
    local dropdown = frame.DelvesCompanionRoleDropdown
    if not dropdown then return false end
    local element = NSkin:RegisterDropdown({
        id = IDs.AbilityRoleDropdown,
        module = "Delves",
        appearanceWindowID = IDs.Scope,
        label = "Delve companion role dropdown",
        window = frame,
        target = dropdown,
        menus = { "MENU_DELVES_ABILITY_LIST" },
        priority = 20,
        highlightRegions = { dropdown },
        isEditable = function()
            return IsVisible(frame) and IsVisible(dropdown)
        end,
    })
    if element then NSkin:RefreshTypedElementAppearance(element) end
    return element ~= nil
end

function DelvesSkin:ApplyCompanionAbilities(frame)
    local parent = frame.ButtonsParent
    if not parent then return false end
    if not abilityItemsRegistered then
        abilityItemsRegistered = NSkin:RegisterIconGroup({
            id = IDs.AbilityItems,
            module = "Delves",
            appearanceWindowID = IDs.Scope,
            label = "Delve companion abilities",
            window = frame,
            target = parent,
            priority = 30,
            children = function()
                return GetAbilityDescriptors(frame)
            end,
            refreshContent = function()
                return SkinAbilityTexts(frame)
            end,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            editorOptions = {
                { id = "shared.iconAppearance", label = "Icons",
                    presentation = "INLINE", category = "CUSTOMIZE" },
                { id = "shared.textAppearance", label = "Text",
                    category = "CUSTOMIZE" },
            },
            highlightRegions = function()
                return GetVisibleAbilityButtons(frame)
            end,
            pixelBorderTargets = function()
                return GetVisibleAbilityButtons(frame)
            end,
            isEditable = function()
                return IsVisible(frame)
                    and #GetVisibleAbilityButtons(frame) > 0
            end,
        }) ~= nil
    else
        NSkin:RefreshIconGroup(IDs.AbilityItems)
    end
    SkinAbilityTexts(frame)
    if abilityItemsRegistered then
        NSkin:NotifySkinningElementBoundsChanged(IDs.AbilityItems)
    end
    return abilityItemsRegistered
end

function DelvesSkin:ApplyCompanionAbilityPagination(frame)
    local controls = frame.DelvesCompanionAbilityListPagingControls
    if not controls or not controls.PageText
        or not controls.PrevPageButton or not controls.NextPageButton
    then return false end
    if not abilityPaginationController then
        abilityPaginationController = NSkin:RegisterPaginationGroup({
            module = "Delves",
            appearanceWindowID = IDs.Scope,
            window = frame,
            ids = {
                group = IDs.AbilityPagination.Group,
                previous = IDs.AbilityPagination.Previous,
                next = IDs.AbilityPagination.Next,
                text = IDs.AbilityPagination.Text,
            },
            controls = {
                group = controls,
                previous = controls.PrevPageButton,
                next = controls.NextPageButton,
                text = controls.PageText,
            },
            groupLabel = "Delve companion ability pagination",
            groupPriority = 40,
            visibilityFrame = frame,
        })
    else
        abilityPaginationController:Refresh()
    end
    return abilityPaginationController ~= nil
end

function DelvesSkin:ApplyCompanionAbilityListContent(frame)
    local applied = self:ApplyCompanionAbilityRoleDropdown(frame)
    applied = self:ApplyCompanionAbilities(frame) or applied
    applied = self:ApplyCompanionAbilityPagination(frame) or applied
    return applied
end

function DelvesSkin:ApplyCompanionAbilityList()
    local frame = _G.DelvesCompanionAbilityListFrame
    if not frame then return false end
    local applied = self:ApplyCompanionAbilityListWindowChrome(frame)
    applied = self:ApplyCompanionAbilityListContent(frame) or applied
    return applied
end

function DelvesSkin:InitializeCompanionAbilityList()
    local frame = _G.DelvesCompanionAbilityListFrame
    if not frame then return false end
    if not abilityListShowHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            DelvesSkin:ApplyCompanionAbilityList()
        end)
        abilityListShowHooked = true
    end
    if not abilityListRefreshHooked and _G.hooksecurefunc
        and type(frame.Refresh) == "function"
    then
        _G.hooksecurefunc(frame, "Refresh", function()
            DelvesSkin:ApplyCompanionAbilityListContent(frame)
        end)
        abilityListRefreshHooked = true
    end
    abilityListInitialized = true
    return self:ApplyCompanionAbilityList()
end

NSkin:RegisterWindowSkin({
    key = "Delves.CompanionAbilityList",
    module = "Delves",
    addon = "Blizzard_DelvesCompanionConfiguration",
    apply = function()
        return DelvesSkin:InitializeCompanionAbilityList()
    end,
})
