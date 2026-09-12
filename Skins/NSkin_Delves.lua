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
end

NSkin:RegisterWindowSkin({
    module = "Delves",
    addon = "Blizzard_DelvesDifficultyPicker",
    apply = function() return DelvesSkin:Initialize() end,
})
