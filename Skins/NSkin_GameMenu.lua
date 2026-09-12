local _, NSkin = ...

local GameMenuSkin = NSkin:NewModule("GameMenu")

local IDs = {
    Scope = "GameMenu",
    Window = "GameMenu.Window",
    ButtonPrefix = "GameMenu.Button.",
    Settings = {
        Scope = "SettingsPanel",
        Window = "SettingsPanel.Window",
        HeaderControls = "SettingsPanel.HeaderControls",
        TopTabs = "SettingsPanel.TopTabs",
        DefaultsButton = "SettingsPanel.DefaultsButton",
        CloseButton = "SettingsPanel.CloseButton",
        SearchBox = "SettingsPanel.SearchBox",
        ScrollBar = "SettingsPanel.SettingsList.ScrollBar",
        Checkboxes = "SettingsPanel.SettingsList.Checkboxes",
        Text = "SettingsPanel.SettingsList.Text",
        Dropdowns = "SettingsPanel.SettingsList.Dropdowns",
        Sliders = "SettingsPanel.SettingsList.Sliders",
        Buttons = "SettingsPanel.SettingsList.Buttons",
        KeybindingButtons = "SettingsPanel.SettingsList.KeybindingButtons",
        CategoryCards = "SettingsPanel.CategoryList.SectionCards",
        CategoryRows = "SettingsPanel.CategoryList.SectionRows",
    },
    Macro = {
        Scope = "MacroFrame",
        Window = "MacroFrame.Window",
        HeaderControls = "MacroFrame.HeaderControls",
        TopTabs = "MacroFrame.TopTabs",
        Icon = "MacroFrame.SelectedMacroIcon",
        SelectorIconPrefix = "MacroFrame.MacroSelector.Icon.",
        EditButton = "MacroFrame.EditButton",
        SaveButton = "MacroFrame.SaveButton",
        CancelButton = "MacroFrame.CancelButton",
        DeleteButton = "MacroFrame.DeleteButton",
        NewButton = "MacroFrame.NewButton",
        ExitButton = "MacroFrame.ExitButton",
        Text = "MacroFrame.Text",
        SelectedMacroName = "MacroFrame.SelectedMacroName",
        CharLimitText = "MacroFrame.CharLimitText",
        TextScrollBar = "MacroFrame.ScrollFrame.ScrollBar",
        SelectorScrollBar = "MacroFrame.MacroSelector.ScrollBar",
        Popup = {
            Scope = "MacroFrame.IconSelectPopup",
            Window = "MacroFrame.IconSelectPopup.Window",
            HeaderControls = "MacroFrame.IconSelectPopup.HeaderControls",
            TextBox = "MacroFrame.IconSelectPopup.TextBox",
            Dropdown = "MacroFrame.IconSelectPopup.Dropdown",
            OkayButton = "MacroFrame.IconSelectPopup.OkayButton",
            CancelButton = "MacroFrame.IconSelectPopup.CancelButton",
            IconSelectionText =
                "MacroFrame.IconSelectPopup.IconSelectionText",
            SelectedIconHeader =
                "MacroFrame.IconSelectPopup.SelectedIconHeader",
            SelectedIconDescription =
                "MacroFrame.IconSelectPopup.SelectedIconDescription",
            EditBoxHeaderText =
                "MacroFrame.IconSelectPopup.EditBoxHeaderText",
            SelectedIcon = "MacroFrame.IconSelectPopup.SelectedIcon",
            IconPrefix = "MacroFrame.IconSelectPopup.Icon.",
            ScrollBar = "MacroFrame.IconSelectPopup.ScrollBar",
        },
    },
}

local initialized = false
local settingsInitialized = false
local macroInitialized = false
local applyPending = false
local settingsApplyPending = false
local lifecycleHooked = false
local settingsLifecycleHooked = false
local settingsTabsHooked = false
local macroLifecycleHooked = false
local macroPopupLifecycleHooked = false
local settingsRootTexturesConcealed = false
local macroRootTexturesConcealed = false
local nextAnonymousButtonID = 0
local buttonIDs = setmetatable({}, { __mode = "k" })
local nextMacroSelectorIconID = 0
local macroSelectorIconIDs = setmetatable({}, { __mode = "k" })
local hookedMacroSelectorScrollBoxes = setmetatable({}, { __mode = "k" })
local hookedSettingsScrollBoxes = setmetatable({}, { __mode = "k" })
local registeredSettingsGroups = {}

NSkin:RegisterAppearanceScope(IDs.Scope, {
    label = "Game Menu",
})
NSkin:RegisterAppearanceScope(IDs.Settings.Scope, {
    label = "Settings Panel",
})
NSkin:RegisterAppearanceScope(IDs.Macro.Scope, {
    label = "Macros",
})
NSkin:RegisterAppearanceScope(IDs.Macro.Popup.Scope, {
    label = "Macro Icon Select",
    parent = IDs.Macro.Scope,
})

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function GetSettingsLists(frame)
    local settingsList = frame and frame.Container
        and frame.Container.SettingsList
    local categoryList = frame and frame.CategoryList
    return settingsList, categoryList,
        settingsList and settingsList.ScrollBox,
        categoryList and categoryList.ScrollBox
end

local function IsSettingsCategorySelected(target)
    local atlas = target and target.Texture and target.Texture.GetAtlas
        and target.Texture:GetAtlas()
    return atlas == "Options_List_Active"
end

local function IsHovered(target)
    return target and target.IsMouseOver and target:IsMouseOver() or false
end

local function IsSettingsTabSelected(tab)
    return tab and tab.IsSelected and tab:IsSelected() or false
end

local MACRO_SELECTOR_SLOT_TEXTURE =
    "interface/buttons/ui-emptyslot-disabled"
local macroSelectorSlotFileID
local macroSelectorSlotFileIDResolved = false

local function NormalizeTexturePath(path)
    if type(path) ~= "string" then return nil end
    path = path:lower():gsub("\\", "/")
    return path:gsub("%.blp$", ""):gsub("%.tga$", "")
end

local function GetMacroSelectorSlotFileID()
    if macroSelectorSlotFileIDResolved then return macroSelectorSlotFileID end
    macroSelectorSlotFileIDResolved = true
    local getter = _G.GetFileIDFromPath
        or (_G.C_Texture and _G.C_Texture.GetFileIDFromPath)
    if type(getter) == "function" then
        local ok, fileID = pcall(getter,
            "Interface\\Buttons\\UI-EmptySlot-Disabled")
        if ok then macroSelectorSlotFileID = fileID end
    end
    return macroSelectorSlotFileID
end

local function IsMacroSelectorSlotDecoration(region)
    if not region or not region.IsObjectType
        or not region:IsObjectType("Texture")
        or not region.GetDrawLayer
        or region:GetDrawLayer() ~= "BACKGROUND"
    then return false end

    local texturePath = region.GetTextureFilePath
        and region:GetTextureFilePath()
    local texture = region.GetTexture and region:GetTexture()
    local normalized = NormalizeTexturePath(texturePath)
        or NormalizeTexturePath(texture)
    if normalized == MACRO_SELECTOR_SLOT_TEXTURE then return true end
    if type(texture) == "number"
        and texture == GetMacroSelectorSlotFileID()
    then return true end

    -- SelectorButtonTemplate's anonymous slot texture has no parentKey.
    -- Retain an exact template fingerprint for clients that expose only a
    -- numeric texture without GetFileIDFromPath.
    if not region.GetTexCoord then return false end
    local left, right, top, bottom = region:GetTexCoord()
    return left == 0.140625 and right == 0.84375
        and top == 0.140625 and bottom == 0.84375
end

local function IsMacroSelectorIconHovered(button)
    return button and button.IsMouseOver and button:IsMouseOver() or false
end

local function IsMacroSelectorIconSelected(button)
    if not button then return false end
    local selector = button.GetSelectorFrame and button:GetSelectorFrame()
    local selectionIndex = button.GetSelectionIndex
        and button:GetSelectionIndex()
    if selector and selector.IsSelected and selectionIndex ~= nil then
        return selector:IsSelected(selectionIndex) == true
    end
    return button.SelectedTexture and button.SelectedTexture.IsShown
        and button.SelectedTexture:IsShown() or false
end

local function QueueApply()
    if applyPending then return end
    applyPending = true
    C_Timer.After(0, function()
        applyPending = false
        GameMenuSkin:Apply()
    end)
end

local function QueueSettingsApply()
    if settingsApplyPending then return end
    settingsApplyPending = true
    C_Timer.After(0, function()
        settingsApplyPending = false
        GameMenuSkin:ApplySettingsPanel()
    end)
end

local function HideDecorativeTextures(frame)
    if not frame then return end
    NSkin:HideTextureRegions(frame)
end

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do copy[key] = value end
    return copy
end

local function GetWindowStyle(scopeID, windowID, headerFrame,
    fallbackHeight)
    local style = CopyTable(NSkin:GetAppearanceStyle(
        "window", scopeID, windowID))
    style.header = CopyTable(style.header)

    local configuredHeight = tonumber(style.header.height)
    if not configuredHeight or configuredHeight <= 0 then
        local height = headerFrame and headerFrame.GetHeight
            and headerFrame:GetHeight()
        style.header.height = tonumber(height) and height > 0
            and height or fallbackHeight or 22
    end
    return style
end

local function GetButtonID(button)
    local assignedID = buttonIDs[button]
    if assignedID then return assignedID end

    local name = button.GetName and button:GetName()
    if type(name) == "string" and name ~= "" then
        local namedID = IDs.ButtonPrefix .. name
        local existing = NSkin:GetSkinningElement(namedID)
        if not existing or existing.target == button then
            buttonIDs[button] = namedID
            return namedID
        end
    end

    nextAnonymousButtonID = nextAnonymousButtonID + 1
    local id = IDs.ButtonPrefix .. "Anonymous" .. nextAnonymousButtonID
    buttonIDs[button] = id
    return id
end

local function GetButtonLabel(button)
    local text = button.GetText and button:GetText()
    if type(text) == "string" and text ~= "" then
        return text .. " button"
    end
    local name = button.GetName and button:GetName()
    if type(name) == "string" and name ~= "" then
        return name .. " button"
    end
    return "Game Menu button"
end

function GameMenuSkin:ApplyWindowChrome(frame)
    if not frame then return false end

    -- DialogBorderTemplate and DialogHeaderTemplate contain only the native
    -- decorative chrome. Keep the frames themselves intact because Blizzard's
    -- layout and title still use them.
    HideDecorativeTextures(frame.Border)
    HideDecorativeTextures(frame.Header)

    local title = frame.Header and frame.Header.Text
    local chrome = NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Scope,
        elementID = IDs.Window,
        style = GetWindowStyle(
            IDs.Scope, IDs.Window, frame.Header, 22),
        title = title,
        skinCloseButton = false,
    })
    if title and chrome and chrome.header then
        title:ClearAllPoints()
        title:SetPoint("CENTER", chrome.header, "CENTER", 0, 0)
    end

    NSkin:RegisterSkinningElement(IDs.Window, {
        label = "Game Menu window",
        kind = "WINDOW",
        module = "GameMenu",
        appearanceWindowID = IDs.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function GameMenuSkin:ApplyButtons(frame)
    if not frame or not frame.GetChildren then return false end

    local applied = false
    local children = { frame:GetChildren() }
    for index = 1, #children do
        local button = children[index]
        if button and button.IsObjectType and button:IsObjectType("Button") then
            local id = GetButtonID(button)
            local element = NSkin:RegisterActionButton({
                id = id,
                module = "GameMenu",
                appearanceWindowID = IDs.Scope,
                label = GetButtonLabel(button),
                window = frame,
                target = button,
                priority = 50 + index,
                highlightRegions = { button },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            })
            if element then
                -- Pooled buttons can represent a different command the next
                -- time the menu opens, so keep their editor label current.
                element.label = GetButtonLabel(button)
                applied = true
            end
        end
    end
    return applied
end

function GameMenuSkin:Apply()
    local frame = _G.GameMenuFrame
    if not frame then return false end

    self:ApplyWindowChrome(frame)
    self:ApplyButtons(frame)
    return true
end

local function GetSettingsControlTargets(frame, kind)
    local _, _, scrollBox = GetSettingsLists(frame)
    local targets = {}
    NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        if kind == "CHECKBOX" and target.Checkbox then
            targets[#targets + 1] = target.Checkbox
        elseif kind == "TEXT" and target.Text then
            targets[#targets + 1] = target.Text
        elseif kind == "DROPDOWN" and target.Control
            and target.Control.Dropdown
        then
            targets[#targets + 1] = target.Control.Dropdown
            if target.Control.DecrementButton then
                targets[#targets + 1] = target.Control.DecrementButton
            end
            if target.Control.IncrementButton then
                targets[#targets + 1] = target.Control.IncrementButton
            end
        elseif kind == "SLIDER" and target.SliderWithSteppers
            and target.SliderWithSteppers.Slider
        then
            targets[#targets + 1] = target.SliderWithSteppers.Slider
        elseif kind == "SETTINGS_BUTTON" and target.Button then
            targets[#targets + 1] = target.Button
        elseif kind == "ACTION_BUTTON" then
            if target.Button1 then targets[#targets + 1] = target.Button1 end
            if target.Button2 then targets[#targets + 1] = target.Button2 end
        end
    end)
    return targets
end

local function GetSettingsCategoryTargets(frame, cards)
    local _, _, _, scrollBox = GetSettingsLists(frame)
    local targets = {}
    NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        local isCard = target.Label and target.Background and not target.Toggle
        local isRow = target.Label and target.Toggle
        if (cards and isCard) or (not cards and isRow) then
            targets[#targets + 1] = target
        end
    end)
    return targets
end

function GameMenuSkin:StyleSettingsControl(frame, target, kind)
    local ids = IDs.Settings
    if kind == "CHECKBOX" and target.Checkbox then
        local style = NSkin:GetAppearanceStyle(
            "button", ids.Scope, ids.Checkboxes)
        return NSkin:SkinCheckButton(target.Checkbox, {
            style = style,
            border = NSkin:GetAppearanceBorderColor(
                "button", style, ids.Scope, ids.Checkboxes),
        }) == true
    elseif kind == "TEXT" and target.Text then
        return NSkin:SkinText(target.Text, NSkin:GetAppearanceStyle(
            "text", ids.Scope, ids.Text)) == true
    elseif kind == "DROPDOWN" and target.Control
        and target.Control.Dropdown
    then
        local style = NSkin:GetAppearanceStyle(
            "button", ids.Scope, ids.Dropdowns)
        NSkin:SkinDropdown(target.Control.Dropdown, {
            style = style,
            border = NSkin:GetAppearanceBorderColor(
                "button", style, ids.Scope, ids.Dropdowns),
            skinSteppers = true,
            decrementButton = target.Control.DecrementButton,
            incrementButton = target.Control.IncrementButton,
        })
        return true
    elseif kind == "SLIDER" and target.SliderWithSteppers
        and target.SliderWithSteppers.Slider
    then
        return NSkin:SkinSlider(target.SliderWithSteppers.Slider, {
            style = NSkin:GetAppearanceStyle(
                "slider", ids.Scope, ids.Sliders),
        }) == true
    elseif kind == "SETTINGS_BUTTON" and target.Button then
        local style = NSkin:GetAppearanceStyle(
            "button", ids.Scope, ids.Buttons)
        NSkin:SkinActionButton(target.Button, {
            style = style,
            border = NSkin:GetAppearanceBorderColor(
                "button", style, ids.Scope, ids.Buttons),
        })
        return true
    elseif kind == "ACTION_BUTTON" then
        local style = NSkin:GetAppearanceStyle(
            "button", ids.Scope, ids.KeybindingButtons)
        local border = NSkin:GetAppearanceBorderColor(
            "button", style, ids.Scope, ids.KeybindingButtons)
        local applied = false
        for _, button in ipairs({ target.Button1, target.Button2 }) do
            if button then
                NSkin:SkinActionButton(button, {
                    style = style,
                    border = border,
                })
                applied = true
            end
        end
        return applied
    end
    return false
end

function GameMenuSkin:ApplySettingsControlGroup(frame, kind)
    local _, _, scrollBox = GetSettingsLists(frame)
    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        applied = self:StyleSettingsControl(frame, target, kind) or applied
    end)
    return applied
end

function GameMenuSkin:StyleSettingsCategory(frame, target, cards)
    local ids = IDs.Settings
    if cards and target.Label and target.Background and not target.Toggle then
        local style = NSkin:GetAppearanceStyle(
            "sectionCard", ids.Scope, ids.CategoryCards)
        return NSkin:SkinSectionCard(target, {
            style = style,
            border = NSkin:GetAppearanceBorderColor(
                "sectionCard", style, ids.Scope, ids.CategoryCards),
            collapsible = false,
            text = target.Label,
            preserveTextLayout = true,
            nativeDecorationRegions = { target.Background },
        }) ~= nil
    elseif not cards and target.Label and target.Toggle then
        local style = NSkin:GetAppearanceStyle(
            "sectionRow", ids.Scope, ids.CategoryRows)
        return NSkin:SkinSectionRow(target, {
            style = style,
            border = NSkin:GetAppearanceBorderColor(
                "sectionRow", style, ids.Scope, ids.CategoryRows),
            contentRegions = { target.Label },
            contentStyle = NSkin:GetAppearanceStyle(
                "text", ids.Scope, ids.CategoryRows),
            nativeDecorationRegions = { target.Texture },
            collapseButton = target.Toggle,
            getHovered = IsHovered,
            getSelected = IsSettingsCategorySelected,
        }) ~= nil
    end
    return false
end

function GameMenuSkin:ApplySettingsCategoryGroup(frame, cards)
    local _, _, _, scrollBox = GetSettingsLists(frame)
    local applied = false
    NSkin:ForEachScrollBoxFrame(scrollBox, function(target)
        applied = self:StyleSettingsCategory(frame, target, cards) or applied
    end)
    return applied
end

local function RegisterSettingsGeneratedGroup(frame, definition)
    local id = definition.id
    if not registeredSettingsGroups[id] then
        registeredSettingsGroups[id] = NSkin:RegisterSkinningElement(id, {
            label = definition.label,
            kind = definition.kind,
            module = "GameMenu",
            appearanceWindowID = IDs.Settings.Scope,
            window = frame,
            target = definition.owner,
            priority = definition.priority,
            draggable = false,
            appearanceStyles = definition.appearanceStyles,
            appearanceTypeIDs = definition.appearanceTypeIDs,
            highlightRegions = definition.targets,
            pixelBorderTargets = definition.pixelBorders and definition.targets
                or nil,
            refreshAppearance = definition.refresh,
            refreshLayout = definition.refresh,
            isEditable = function()
                return IsVisible(frame) and #definition.targets() > 0
            end,
        }) == true
    end
    local applied = definition.refresh()
    if registeredSettingsGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or registeredSettingsGroups[id]
end

function GameMenuSkin:RegisterSettingsGeneratedGroups(frame)
    local ids = IDs.Settings
    local _, _, settingsScrollBox, categoryScrollBox = GetSettingsLists(frame)
    if not settingsScrollBox or not categoryScrollBox then return false end
    local applied = false
    for _, definition in ipairs({
        { id = ids.Checkboxes, label = "Settings checkboxes",
            kind = "CHECKBOX", owner = settingsScrollBox, priority = 60,
            pixelBorders = true,
            targets = function()
                return GetSettingsControlTargets(frame, "CHECKBOX")
            end,
            refresh = function()
                return GameMenuSkin:ApplySettingsControlGroup(frame, "CHECKBOX")
            end },
        { id = ids.Text, label = "Settings labels", kind = "TEXT",
            owner = settingsScrollBox, priority = 61,
            targets = function()
                return GetSettingsControlTargets(frame, "TEXT")
            end,
            refresh = function()
                return GameMenuSkin:ApplySettingsControlGroup(frame, "TEXT")
            end },
        { id = ids.Dropdowns, label = "Settings dropdowns",
            kind = "DROPDOWN", owner = settingsScrollBox, priority = 62,
            pixelBorders = true,
            targets = function()
                return GetSettingsControlTargets(frame, "DROPDOWN")
            end,
            refresh = function()
                return GameMenuSkin:ApplySettingsControlGroup(frame, "DROPDOWN")
            end },
        { id = ids.KeybindingButtons, label = "Settings keybinding buttons",
            kind = "ACTION_BUTTON", owner = settingsScrollBox, priority = 64,
            pixelBorders = true,
            targets = function()
                return GetSettingsControlTargets(frame, "ACTION_BUTTON")
            end,
            refresh = function()
                return GameMenuSkin:ApplySettingsControlGroup(
                    frame, "ACTION_BUTTON")
            end },
        { id = ids.Sliders, label = "Settings sliders",
            kind = "SLIDER", owner = settingsScrollBox, priority = 63,
            targets = function()
                return GetSettingsControlTargets(frame, "SLIDER")
            end,
            refresh = function()
                return GameMenuSkin:ApplySettingsControlGroup(frame, "SLIDER")
            end },
        { id = ids.Buttons, label = "Settings buttons",
            kind = "ACTION_BUTTON", owner = settingsScrollBox, priority = 64,
            pixelBorders = true,
            targets = function()
                return GetSettingsControlTargets(frame, "SETTINGS_BUTTON")
            end,
            refresh = function()
                return GameMenuSkin:ApplySettingsControlGroup(
                    frame, "SETTINGS_BUTTON")
            end },
        { id = ids.CategoryCards, label = "Settings category cards",
            kind = "SECTION_CARD", owner = categoryScrollBox, priority = 66,
            pixelBorders = true,
            targets = function()
                return GetSettingsCategoryTargets(frame, true)
            end,
            refresh = function()
                return GameMenuSkin:ApplySettingsCategoryGroup(frame, true)
            end },
        { id = ids.CategoryRows, label = "Settings category rows",
            kind = "SECTION_ROW", owner = categoryScrollBox, priority = 67,
            pixelBorders = true,
            appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            targets = function()
                return GetSettingsCategoryTargets(frame, false)
            end,
            refresh = function()
                return GameMenuSkin:ApplySettingsCategoryGroup(frame, false)
            end },
    }) do
        applied = RegisterSettingsGeneratedGroup(frame, definition) or applied
    end
    return applied
end

function GameMenuSkin:StyleInitializedSettingsControl(frame, target)
    for _, kind in ipairs({
        "CHECKBOX", "TEXT", "DROPDOWN", "SLIDER", "SETTINGS_BUTTON",
        "ACTION_BUTTON",
    }) do
        if self:StyleSettingsControl(frame, target, kind) then
            local id = kind == "CHECKBOX" and IDs.Settings.Checkboxes
                or kind == "TEXT" and IDs.Settings.Text
                or kind == "DROPDOWN" and IDs.Settings.Dropdowns
                or kind == "SLIDER" and IDs.Settings.Sliders
                or kind == "SETTINGS_BUTTON" and IDs.Settings.Buttons
                or IDs.Settings.KeybindingButtons
            NSkin:NotifySkinningElementBoundsChanged(id)
        end
    end
end

function GameMenuSkin:StyleInitializedSettingsCategory(frame, target)
    for _, cards in ipairs({ true, false }) do
        if self:StyleSettingsCategory(frame, target, cards) then
            NSkin:NotifySkinningElementBoundsChanged(cards
                and IDs.Settings.CategoryCards or IDs.Settings.CategoryRows)
        end
    end
end

local function HookSettingsScrollBox(scrollBox, owner, callback)
    if not scrollBox or hookedSettingsScrollBoxes[scrollBox] then return end
    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox.RegisterCallback and events and events.OnInitializedFrame then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, target) callback(target) end, owner)
        hookedSettingsScrollBoxes[scrollBox] = true
    end
end

function GameMenuSkin:ApplySettingsTopTabs(frame)
    local tabs = { frame.GameTab, frame.AddOnsTab }
    if not tabs[1] or not tabs[2] then return false end
    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Settings.Scope, IDs.Settings.TopTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Settings.Scope, IDs.Settings.TopTabs)
    for i = 1, #tabs do
        NSkin:SkinTab(tabs[i], IsSettingsTabSelected(tabs[i]), style, border)
    end
    local event = _G.ButtonGroupBaseMixin and _G.ButtonGroupBaseMixin.Event
        and _G.ButtonGroupBaseMixin.Event.Selected
    if not settingsTabsHooked and frame.tabsGroup
        and frame.tabsGroup.RegisterCallback and event
    then
        frame.tabsGroup:RegisterCallback(event, function()
            GameMenuSkin:ApplySettingsTopTabs(frame)
        end, self)
        settingsTabsHooked = true
    end
    return true
end

function GameMenuSkin:ApplySettingsPanelControls(frame)
    local ids = IDs.Settings
    local settingsList, _, settingsScrollBox, categoryScrollBox =
        GetSettingsLists(frame)
    local applied = false

    if frame.SearchBox then
        applied = NSkin:RegisterSearchBox({
            id = ids.SearchBox,
            module = "GameMenu",
            appearanceWindowID = ids.Scope,
            label = "Settings search box",
            window = frame,
            target = frame.SearchBox,
            priority = 49,
            highlightRegions = { frame.SearchBox },
            isEditable = function()
                return IsVisible(frame) and IsVisible(frame.SearchBox)
            end,
        }) ~= nil or applied
    end

    if settingsList and settingsList.ScrollBar then
        applied = NSkin:RegisterScrollBar({
            id = ids.ScrollBar,
            module = "GameMenu",
            appearanceWindowID = ids.Scope,
            label = "Settings list scroll bar",
            window = frame,
            target = settingsList.ScrollBar,
            priority = 50,
            highlightRegions = { settingsList.ScrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(settingsList.ScrollBar)
            end,
        }) ~= nil or applied
    end

    for _, definition in ipairs({
        { ids.DefaultsButton, "Settings defaults button",
            settingsList and settingsList.Header
                and settingsList.Header.DefaultsButton },
        { ids.CloseButton, "Settings close button", frame.CloseButton },
    }) do
        local id, label, button = unpack(definition)
        if button then
            applied = NSkin:RegisterActionButton({
                id = id,
                module = "GameMenu",
                appearanceWindowID = ids.Scope,
                label = label,
                window = frame,
                target = button,
                priority = 51,
                highlightRegions = { button },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            }) ~= nil or applied
        end
    end

    if frame.GameTab and frame.AddOnsTab then
        applied = self:ApplySettingsTopTabs(frame) or applied
        applied = NSkin:RegisterTabGroup(ids.TopTabs, {
            label = "Settings top tabs",
            module = "GameMenu",
            appearanceWindowID = ids.Scope,
            window = frame,
            tabs = { frame.GameTab, frame.AddOnsTab },
            priority = 52,
            orientation = "HORIZONTAL",
            edge = "TOP",
            getSelected = IsSettingsTabSelected,
        }) or applied
        NSkin:ApplyTabGroupLayout(ids.TopTabs)
    end

    applied = self:RegisterSettingsGeneratedGroups(frame) or applied
    HookSettingsScrollBox(settingsScrollBox, self, function(target)
        GameMenuSkin:StyleInitializedSettingsControl(frame, target)
    end)
    HookSettingsScrollBox(categoryScrollBox, self, function(target)
        GameMenuSkin:StyleInitializedSettingsCategory(frame, target)
    end)
    return applied
end

function GameMenuSkin:ApplySettingsPanel()
    local frame = _G.SettingsPanel
    if not frame then return false end

    -- The unnamed root texture is Options_InnerFrame. Suppress it before
    -- creating NSkin's own root textures so subsequent refreshes cannot hide
    -- the shared chrome.
    if not settingsRootTexturesConcealed then
        HideDecorativeTextures(frame)
        settingsRootTexturesConcealed = true
    end

    -- NineSlice owns the functional title FontString. Preserve the container
    -- and remove only its decorative regions.
    HideDecorativeTextures(frame.NineSlice)
    local title = frame.NineSlice and frame.NineSlice.Text
    local closeButton = frame.ClosePanelButton
    local chrome = NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Settings.Scope,
        elementID = IDs.Settings.Window,
        headerControlsID = IDs.Settings.HeaderControls,
        style = GetWindowStyle(IDs.Settings.Scope, IDs.Settings.Window,
            closeButton, 24),
        title = title,
        closeButton = closeButton,
        preserveArtwork = {
            NineSlice = true,
        },
    })
    if title and chrome and chrome.header then
        title:ClearAllPoints()
        title:SetPoint("CENTER", chrome.header, "CENTER", 0, 0)
    end

    NSkin:RegisterSkinningElement(IDs.Settings.Window, {
        label = "Settings Panel window",
        kind = "WINDOW",
        module = "GameMenu",
        appearanceWindowID = IDs.Settings.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    self:ApplySettingsPanelControls(frame)
    return true
end

function GameMenuSkin:ApplyMacroWindowChrome(frame)
    if not frame then return false end

    -- MacroFrame adds legacy portrait, divider, and selected-slot textures
    -- directly to its ButtonFrameTemplate root. Suppress them before NSkin
    -- creates its own root chrome so refreshes cannot conceal owned textures.
    if not macroRootTexturesConcealed then
        HideDecorativeTextures(frame)
        macroRootTexturesConcealed = true
    end

    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.Macro.Scope,
        elementID = IDs.Macro.Window,
        headerControlsID = IDs.Macro.HeaderControls,
        title = frame.TitleContainer and frame.TitleContainer.TitleText,
    })
    NSkin:RegisterSkinningElement(IDs.Macro.Window, {
        label = "Macro window",
        kind = "WINDOW",
        module = "GameMenu",
        appearanceWindowID = IDs.Macro.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    return true
end

function GameMenuSkin:ApplyMacroTabs(frame)
    local tabs = { _G.MacroFrameTab1, _G.MacroFrameTab2 }
    if not frame or not tabs[1] or not tabs[2] then return false end

    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.Macro.Scope, IDs.Macro.TopTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.Macro.Scope, IDs.Macro.TopTabs)
    local selected = _G.PanelTemplates_GetSelectedTab
        and _G.PanelTemplates_GetSelectedTab(frame)
    for index = 1, #tabs do
        NSkin:SkinTab(tabs[index], index == selected, style, border)
    end

    NSkin:RegisterTabGroup(IDs.Macro.TopTabs, {
        label = "Macro top tabs",
        kind = "TAB_GROUP",
        module = "GameMenu",
        appearanceWindowID = IDs.Macro.Scope,
        window = frame,
        tabs = tabs,
        priority = 50,
        orientation = "HORIZONTAL",
        edge = "TOP",
    })
    NSkin:ApplyTabGroupLayout(IDs.Macro.TopTabs)
    return true
end

function GameMenuSkin:ApplyMacroIcon(frame)
    local button = frame and (frame.SelectedMacroButton
        or _G.MacroFrameSelectedMacroButton)
    if not button or not button.Icon then return false end

    return NSkin:RegisterIcon({
        id = IDs.Macro.Icon,
        module = "GameMenu",
        appearanceWindowID = IDs.Macro.Scope,
        label = "Selected macro icon",
        window = frame,
        target = button,
        texture = button.Icon,
        nativeDecorationRegions = self:GetMacroIconNativeDecorations(
            button, button.Icon, { _G.MacroFrameSelectedMacroBackground }),
        hoverRegion = button.Highlight,
        getHovered = IsMacroSelectorIconHovered,
        priority = 60,
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    }) ~= nil
end

function GameMenuSkin:GetMacroIconNativeDecorations(button, icon,
    additionalRegions)
    local regions = {}
    local included = {}
    for _, region in ipairs(additionalRegions or {}) do
        if region and not included[region] then
            regions[#regions + 1] = region
            included[region] = true
        end
    end
    if not button or not button.GetRegions then return regions end
    for _, region in ipairs({ button:GetRegions() }) do
        if region ~= icon and region ~= button.SelectedTexture
            and region ~= button.Highlight and not included[region]
            and IsMacroSelectorSlotDecoration(region)
        then
            regions[#regions + 1] = region
            included[region] = true
        end
    end
    return regions
end

function GameMenuSkin:GetMacroSelectorIconID(button)
    local id = macroSelectorIconIDs[button]
    if id then return id end
    nextMacroSelectorIconID = nextMacroSelectorIconID + 1
    id = IDs.Macro.SelectorIconPrefix .. nextMacroSelectorIconID
    macroSelectorIconIDs[button] = id
    return id
end

function GameMenuSkin:ApplyMacroSelectorIcons(frame)
    local selector = frame and frame.MacroSelector
    local scrollBox = selector and selector.ScrollBox

    local applied = false
    if not NSkin:ForEachScrollBoxFrame(scrollBox, function(button)
        local icon = button and button.Icon
        if not icon then return end
        local id = GameMenuSkin:GetMacroSelectorIconID(button)
        local existing = NSkin:GetSkinningElement(id)
        local element = NSkin:RegisterIcon({
            id = id,
            module = "GameMenu",
            appearanceWindowID = IDs.Macro.Scope,
            label = "Macro selector icon",
            window = frame,
            target = button,
            texture = icon,
            nativeDecorationRegions = GameMenuSkin:GetMacroIconNativeDecorations(
                button, icon),
            hoverRegion = button.Highlight,
            selectedRegion = button.SelectedTexture,
            getHovered = IsMacroSelectorIconHovered,
            getSelected = IsMacroSelectorIconSelected,
            priority = 61,
            draggable = false,
            editorOptions = {
                { id = "shared.iconAppearance", label = "Icon",
                    presentation = "INLINE", category = "CUSTOMIZE" },
            },
            isEditable = function()
                return IsVisible(frame) and IsVisible(button)
            end,
        })
        if element then
            if NSkin:GetSavedMovableElementPlacement(id)
                and element.resetPlacement
            then
                element.resetPlacement(element)
            end
            if existing then NSkin:RefreshTypedElementLayout(element) end
            applied = true
        end
    end) then return false end

    if not hookedMacroSelectorScrollBoxes[scrollBox]
        and _G.hooksecurefunc and type(scrollBox.Update) == "function"
    then
        _G.hooksecurefunc(scrollBox, "Update", function()
            GameMenuSkin:ApplyMacroSelectorIcons(frame)
        end)
        hookedMacroSelectorScrollBoxes[scrollBox] = true
    end
    return applied
end

function GameMenuSkin:ApplyMacroButtons(frame)
    if not frame then return false end

    local applied = false
    for _, definition in ipairs({
        { IDs.Macro.EditButton, "Macro edit button", _G.MacroEditButton },
        { IDs.Macro.SaveButton, "Macro save button", _G.MacroSaveButton },
        { IDs.Macro.CancelButton, "Macro cancel button", _G.MacroCancelButton },
        { IDs.Macro.DeleteButton, "Macro delete button", _G.MacroDeleteButton },
        { IDs.Macro.NewButton, "Macro new button", _G.MacroNewButton },
        { IDs.Macro.ExitButton, "Macro exit button", _G.MacroExitButton },
    }) do
        local id, label, button = unpack(definition)
        if button then
            applied = NSkin:RegisterActionButton({
                id = id,
                module = "GameMenu",
                appearanceWindowID = IDs.Macro.Scope,
                label = label,
                window = frame,
                target = button,
                priority = 70,
                highlightRegions = { button },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(button)
                end,
            }) ~= nil or applied
        end
    end
    return applied
end

function GameMenuSkin:ApplyMacroText(frame)
    if not frame then return false end

    local applied = false
    local macroText = _G.MacroFrameText
    local macroTextSurface = _G.MacroFrameTextBackground
    if macroTextSurface then
        NSkin:ConcealWindowArtwork(macroTextSurface)
    end
    if macroText then
        applied = NSkin:RegisterEditBox({
            id = IDs.Macro.Text,
            module = "GameMenu",
            appearanceWindowID = IDs.Macro.Scope,
            label = "Macro text area",
            window = frame,
            target = macroText,
            skinOptions = { surface = macroTextSurface or macroText },
            pixelBorderTargets = macroTextSurface
                and { macroTextSurface } or nil,
            priority = 80,
            draggable = false,
            editorOptions = {
                { id = "shared.editBoxAppearance", label = "Edit Box",
                    category = "CUSTOMIZE" },
            },
            highlightRegions = { macroTextSurface or macroText },
            isEditable = function()
                return IsVisible(frame) and IsVisible(macroText)
            end,
        }) ~= nil or applied
    end
    for _, definition in ipairs({
        { IDs.Macro.SelectedMacroName, "Selected macro name",
            _G.MacroFrameSelectedMacroName },
        { IDs.Macro.CharLimitText, "Macro character limit",
            _G.MacroFrameCharLimitText or _G.macroFrameCharLimitText },
    }) do
        local id, label, target = unpack(definition)
        if target then
            applied = NSkin:RegisterTextElement({
                id = id,
                module = "GameMenu",
                appearanceWindowID = IDs.Macro.Scope,
                label = label,
                window = frame,
                target = target,
                priority = 80,
                highlightRegions = { target },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(target)
                end,
            }) ~= nil or applied
        end
    end
    return applied
end

function GameMenuSkin:ApplyMacroPopup()
    local popup = _G.MacroPopupFrame
    if not popup then return false end
    local popupIDs = IDs.Macro.Popup
    return NSkin:RegisterIconSelectPopup({
        root = popup,
        module = "GameMenu",
        appearanceWindowID = popupIDs.Scope,
        windowLabel = "Macro icon select popup",
        ids = {
            window = popupIDs.Window,
            headerControls = popupIDs.HeaderControls,
            textBox = popupIDs.TextBox,
            dropdown = popupIDs.Dropdown,
            okayButton = popupIDs.OkayButton,
            cancelButton = popupIDs.CancelButton,
            iconSelectionText = popupIDs.IconSelectionText,
            selectedIconHeader = popupIDs.SelectedIconHeader,
            selectedIconDescription = popupIDs.SelectedIconDescription,
            editBoxHeaderText = popupIDs.EditBoxHeaderText,
            selectedIcon = popupIDs.SelectedIcon,
            iconPrefix = popupIDs.IconPrefix,
            scrollBar = popupIDs.ScrollBar,
        },
    })
end

function GameMenuSkin:ApplyMacroScrollBars(frame)
    if not frame then return false end

    local textScrollFrame = _G.MacroFrameScrollFrame
    local selector = frame.MacroSelector
    local applied = false
    for _, definition in ipairs({
        { IDs.Macro.TextScrollBar, "Macro text scroll bar",
            textScrollFrame and textScrollFrame.ScrollBar },
        { IDs.Macro.SelectorScrollBar, "Macro selector scroll bar",
            selector and selector.ScrollBar },
    }) do
        local id, label, scrollBar = unpack(definition)
        if scrollBar then
            applied = NSkin:RegisterScrollBar({
                id = id,
                module = "GameMenu",
                appearanceWindowID = IDs.Macro.Scope,
                label = label,
                window = frame,
                target = scrollBar,
                priority = 90,
                highlightRegions = { scrollBar },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(scrollBar)
                end,
            }) ~= nil or applied
        end
    end
    return applied
end

function GameMenuSkin:ApplyMacroFrame()
    local frame = _G.MacroFrame
    if not frame then return false end

    self:ApplyMacroWindowChrome(frame)
    self:ApplyMacroTabs(frame)
    self:ApplyMacroIcon(frame)
    self:ApplyMacroSelectorIcons(frame)
    self:ApplyMacroButtons(frame)
    self:ApplyMacroText(frame)
    self:ApplyMacroScrollBars(frame)
    self:ApplyMacroPopup()
    return true
end

function GameMenuSkin:HookLifecycle(frame)
    if lifecycleHooked then return end

    if frame.HookScript then frame:HookScript("OnShow", QueueApply) end
    if _G.hooksecurefunc and type(frame.AddButton) == "function"
    then
        _G.hooksecurefunc(frame, "AddButton", QueueApply)
    end
    lifecycleHooked = true
end

function GameMenuSkin:Initialize()
    local frame = _G.GameMenuFrame
    if not frame then return false end

    self:HookLifecycle(frame)
    initialized = true
    self:Apply()
    if frame:IsShown() then QueueApply() end
    return true
end

function GameMenuSkin:InitializeSettingsPanel()
    local frame = _G.SettingsPanel
    if not frame then return false end

    if not settingsLifecycleHooked and frame.HookScript then
        frame:HookScript("OnShow", QueueSettingsApply)
        settingsLifecycleHooked = true
    end
    settingsInitialized = true
    self:ApplySettingsPanel()
    if frame:IsShown() then QueueSettingsApply() end
    return true
end

function GameMenuSkin:InitializeMacroFrame()
    local frame = _G.MacroFrame
    if not frame then return false end

    if not macroLifecycleHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            GameMenuSkin:ApplyMacroFrame()
        end)
        macroLifecycleHooked = true
    end
    local popup = _G.MacroPopupFrame
    if popup and not macroPopupLifecycleHooked and popup.HookScript then
        popup:HookScript("OnShow", function()
            GameMenuSkin:ApplyMacroPopup()
        end)
        macroPopupLifecycleHooked = true
    end
    macroInitialized = true
    return self:ApplyMacroFrame()
end

function GameMenuSkin:RefreshAppearance()
    if initialized then self:Apply() end
    if settingsInitialized then self:ApplySettingsPanel() end
    if macroInitialized then self:ApplyMacroFrame() end
end

NSkin:RegisterWindowSkin({
    module = "GameMenu",
    addon = "Blizzard_GameMenu",
    apply = function() return GameMenuSkin:Initialize() end,
})

NSkin:RegisterWindowSkin({
    key = "GameMenu.SettingsPanel",
    module = "GameMenu",
    addon = "Blizzard_Settings_Shared",
    apply = function() return GameMenuSkin:InitializeSettingsPanel() end,
})

NSkin:RegisterWindowSkin({
    key = "GameMenu.MacroFrame",
    module = "GameMenu",
    addon = "Blizzard_MacroUI",
    apply = function() return GameMenuSkin:InitializeMacroFrame() end,
})
