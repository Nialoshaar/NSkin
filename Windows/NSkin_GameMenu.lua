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
    ChatConfig = {
        Scope = "ChatConfig",
        Window = "ChatConfig.Window",
        Title = "ChatConfig.Title",
        Close = "ChatConfig.Close",
        ChatTabs = "ChatConfig.ChatTabs",
        Categories = "ChatConfig.Categories",
        Checkboxes = "ChatConfig.Options.Checkboxes",
        CheckboxLabels = "ChatConfig.Options.CheckboxLabels",
        ColorSwatches = "ChatConfig.Options.ColorSwatches",
        ChannelRows = "ChatConfig.Options.ChannelRows",
        ChannelCloseButtons = "ChatConfig.Options.ChannelCloseButtons",
        Okay = "ChatConfig.Okay",
        General = {
            MessageRows = "ChatConfig.General.MessageRows",
            SectionHeaders = "ChatConfig.General.SectionHeaders",
            ChatDefaults = "ChatConfig.General.ChatDefaults",
            ResetChatPositions = "ChatConfig.General.ResetChatPositions",
        },
        CombatLog = {
            FilterRows = "ChatConfig.CombatLog.FilterList",
            FilterScrollBar = "ChatConfig.CombatLog.FilterScrollBar",
            MoveFilterUp = "ChatConfig.CombatLog.MoveFilterUp",
            MoveFilterDown = "ChatConfig.CombatLog.MoveFilterDown",
            CopyFilter = "ChatConfig.CombatLog.CopyFilter",
            AddFilter = "ChatConfig.CombatLog.AddFilter",
            DeleteFilter = "ChatConfig.CombatLog.DeleteFilter",
            FilterTabs = "ChatConfig.CombatLog.FilterTabs",
            SectionHeaders = "ChatConfig.CombatLog.SectionHeaders",
            FilterOptions = "ChatConfig.CombatLog.FilterOptions",
            Defaults = "ChatConfig.CombatLog.Defaults",
            Settings = {
                FilterNameLabel =
                    "ChatConfig.CombatLog.Settings.FilterNameLabel",
                FilterName = "ChatConfig.CombatLog.Settings.FilterName",
                SaveName = "ChatConfig.CombatLog.Settings.SaveName",
            },
            Formatting = {
                ExampleHeader =
                    "ChatConfig.CombatLog.Formatting.ExampleHeader",
                ExampleText =
                    "ChatConfig.CombatLog.Formatting.ExampleText",
            },
        },
        TextToSpeech = {
            OptionCheckboxes = "ChatConfig.TextToSpeech.Settings.OptionCheckboxes",
            VoiceOptionsHeader = "ChatConfig.TextToSpeech.Settings.VoiceOptionsHeader",
            SupportPageLink = "ChatConfig.TextToSpeech.Settings.SupportPageLink",
            VoiceDropdown = "ChatConfig.TextToSpeech.Settings.VoiceDropdown",
            PlaySample = "ChatConfig.TextToSpeech.Settings.PlaySample",
            AlternateVoiceCheckbox = "ChatConfig.TextToSpeech.Settings.AlternateVoiceCheckbox",
            AlternateVoiceDropdown = "ChatConfig.TextToSpeech.Settings.AlternateVoiceDropdown",
            AlternatePlaySample = "ChatConfig.TextToSpeech.Settings.AlternatePlaySample",
            SpeechRate = "ChatConfig.TextToSpeech.Settings.SpeechRate",
            SpeechVolume = "ChatConfig.TextToSpeech.Settings.SpeechVolume",
            Defaults = "ChatConfig.TextToSpeech.Defaults",
            CharacterSpecific = "ChatConfig.TextToSpeech.CharacterSpecificSettings",
            MessageHeader = "ChatConfig.TextToSpeech.Messages.SectionHeader",
            MessageCheckboxes = "ChatConfig.TextToSpeech.Messages.MessageTypeCheckboxes",
        },
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
local chatConfigInitialized = false
local applyPending = false
local settingsApplyPending = false
local lifecycleHooked = false
local settingsLifecycleHooked = false
local settingsTabsHooked = false
local macroLifecycleHooked = false
local macroPopupLifecycleHooked = false
local chatConfigLifecycleHooked = false
local chatConfigFunctionsHooked = false
local chatConfigTabsHooked = false
local settingsRootTexturesConcealed = false
local macroRootTexturesConcealed = false
local nextAnonymousButtonID = 0
local buttonIDs = setmetatable({}, { __mode = "k" })
local nextMacroSelectorIconID = 0
local macroSelectorIconIDs = setmetatable({}, { __mode = "k" })
local hookedMacroSelectorScrollBoxes = setmetatable({}, { __mode = "k" })
local hookedSettingsScrollBoxes = setmetatable({}, { __mode = "k" })
local hookedChatConfigScrollBoxes = setmetatable({}, { __mode = "k" })
local registeredSettingsGroups = {}
local registeredChatConfigGroups = {}
local suppressedChatConfigNineSliceRegions = setmetatable({}, { __mode = "k" })
local hookedCombatFilterRowText = setmetatable({}, { __mode = "k" })

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
NSkin:RegisterAppearanceScope(IDs.ChatConfig.Scope, {
    label = "Chat Configuration",
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

local CHAT_CONFIG_NINE_SLICE_BORDER_KEYS = {
    "LeftEdge", "TopEdge", "RightEdge", "BottomEdge",
    "TopLeft", "TopRight", "BottomLeft", "BottomRight",
    "TopLeftCorner", "TopRightCorner",
    "BottomLeftCorner", "BottomRightCorner",
    "BotLeftCorner", "BotRightCorner", "Center"
}

local function SuppressChatConfigNineSliceRegion(region)
    if not region or suppressedChatConfigNineSliceRegions[region]
        or (region.IsForbidden and region:IsForbidden())
    then return end
    local state = { applying = false }
    suppressedChatConfigNineSliceRegions[region] = state
    local function Suppress()
        if state.applying then return end
        state.applying = true
        if region.SetAlpha then region:SetAlpha(0) end
        if region.Hide then region:Hide() end
        state.applying = false
    end
    Suppress()
    if _G.hooksecurefunc then
        for _, method in ipairs({ "SetAlpha", "SetShown", "Show" }) do
            if type(region[method]) == "function" then
                pcall(_G.hooksecurefunc, region, method, Suppress)
            end
        end
    end
end

local function SuppressChatConfigNineSliceBorders(root)
    if not root then return end
    local visited = {}
    local function Visit(owner)
        if not owner or visited[owner]
            or (owner.IsForbidden and owner:IsForbidden())
        then return end
        visited[owner] = true
        local nineSlice = owner.NineSlice
        if nineSlice then
            for _, key in ipairs(CHAT_CONFIG_NINE_SLICE_BORDER_KEYS) do
                SuppressChatConfigNineSliceRegion(nineSlice[key])
            end
        end
        local hasNineSliceBorder
        for _, key in ipairs(CHAT_CONFIG_NINE_SLICE_BORDER_KEYS) do
            if owner[key] then
                hasNineSliceBorder = true
                break
            end
        end
        if hasNineSliceBorder then
            for _, key in ipairs(CHAT_CONFIG_NINE_SLICE_BORDER_KEYS) do
                SuppressChatConfigNineSliceRegion(owner[key])
            end
        end
        if owner.GetChildren then
            for _, child in ipairs({ owner:GetChildren() }) do Visit(child) end
        end
    end
    Visit(root)
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
            rowFamily = definition.rowFamily,
            module = "GameMenu",
            appearanceWindowID = IDs.Settings.Scope,
            window = frame,
            target = definition.owner,
            priority = definition.priority,
            draggable = false,
            appearanceStyles = definition.appearanceStyles,
            appearanceTypeIDs = definition.appearanceTypeIDs,
            editorOptions = definition.editorOptions,
            highlightRegions = definition.targets,
            pixelBorderTargets = definition.pixelBorders and definition.targets
                or nil,
            refreshAppearance = definition.refresh,
            refreshLayout = definition.refresh,
            isEditable = function()
                if not IsVisible(frame) then return false end
                for _, target in ipairs(definition.targets()) do
                    if IsVisible(target) then return true end
                end
                return false
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
            kind = "BUTTON", rowFamily = "sectionRow",
            owner = categoryScrollBox, priority = 67,
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

local CHAT_CONFIG_GENERAL_MANAGER_NAMES = {
    "ChatConfigChatSettingsLeft",
    "ChatConfigChannelSettingsLeft",
    "ChatConfigOtherSettingsCombat",
    "ChatConfigOtherSettingsPVP",
    "ChatConfigOtherSettingsSystem",
    "ChatConfigOtherSettingsCreature",
    "ChatConfigOtherSettingsAdditionalColors",
}

local CHAT_CONFIG_COMBAT_MANAGER_NAMES = {
    "CombatConfigMessageSourcesDoneBy",
    "CombatConfigMessageSourcesDoneTo",
    "CombatConfigMessageTypesLeft",
    "CombatConfigMessageTypesRight",
    "CombatConfigMessageTypesMisc",
    "CombatConfigColorsUnitColors",
}

local CHAT_CONFIG_GENERAL_ROW_MANAGER_NAMES = {
    "ChatConfigChatSettingsLeft",
    "ChatConfigOtherSettingsCombat",
    "ChatConfigOtherSettingsPVP",
    "ChatConfigOtherSettingsSystem",
    "ChatConfigOtherSettingsCreature",
}

local CHAT_CONFIG_MANAGER_NAMES = {}
for _, name in ipairs(CHAT_CONFIG_GENERAL_MANAGER_NAMES) do
    CHAT_CONFIG_MANAGER_NAMES[#CHAT_CONFIG_MANAGER_NAMES + 1] = name
end
for _, name in ipairs(CHAT_CONFIG_COMBAT_MANAGER_NAMES) do
    CHAT_CONFIG_MANAGER_NAMES[#CHAT_CONFIG_MANAGER_NAMES + 1] = name
end

local function AddUniqueTarget(targets, seen, target)
    if not target or seen[target]
        or (target.IsForbidden and target:IsForbidden())
    then return end
    seen[target] = true
    targets[#targets + 1] = target
end

local function GetChatConfigTabs(frame)
    local targets = {}
    local manager = frame and frame.ChatTabManager
    local pool = manager and manager.tabPool
    if pool and pool.EnumerateActive then
        for tab in pool:EnumerateActive() do targets[#targets + 1] = tab end
    end
    return targets
end

local function GetChatConfigCategories()
    local targets = {}
    for index = 1, 7 do
        local button = _G["ChatConfigCategoryFrameButton" .. index]
        if button then targets[#targets + 1] = button end
    end
    return targets
end

local function GetChatConfigOptionTargets(managerNames, includeCharacterSpecific)
    local checkboxes, labels, swatches = {}, {}, {}
    local seenChecks, seenLabels, seenSwatches = {}, {}, {}

    local function AddCheck(check, label)
        AddUniqueTarget(checkboxes, seenChecks, check)
        AddUniqueTarget(labels, seenLabels, label
            or (check and (check.Text or check.text))
            or (check and check.GetFontString and check:GetFontString()))
    end

    local function AddSwatch(swatch)
        AddUniqueTarget(swatches, seenSwatches, swatch)
    end

    for _, managerName in ipairs(managerNames or CHAT_CONFIG_MANAGER_NAMES) do
        local manager = _G[managerName]
        if manager then
            for index, definition in ipairs(manager.checkBoxTable or {}) do
                local name = managerName .. "Checkbox" .. index
                local wrapper = _G[name]
                local check = wrapper and (wrapper.CheckButton
                    or _G[name .. "Check"]) or _G[name]
                AddCheck(check, check and (check.Text or _G[name .. "Text"]
                    or _G[name .. "CheckText"]))
                if wrapper then
                    AddUniqueTarget(labels, seenLabels, wrapper.BlankText)
                    AddSwatch(wrapper.ColorSwatch)
                end
                for subIndex = 1, #(definition.subTypes or {}) do
                    local subName = name .. "_" .. subIndex
                    local subCheck = _G[subName]
                    AddCheck(subCheck, subCheck and (subCheck.Text
                        or _G[subName .. "Text"]))
                end
            end
            for index = 1, #(manager.swatchTable or {}) do
                local row = _G[managerName .. "Swatch" .. index]
                if row then
                    AddUniqueTarget(labels, seenLabels,
                        row.Text or _G[row:GetName() .. "Text"])
                    AddSwatch(row.ColorSwatch or row)
                end
            end
        end
    end

    if includeCharacterSpecific ~= false then
        AddCheck(_G.TextToSpeechCharacterSpecificButton,
            _G.TextToSpeechCharacterSpecificButton
                and _G.TextToSpeechCharacterSpecificButton.Text)
    end
    return checkboxes, labels, swatches
end

local function GetChatConfigChannelRows()
    local rows, seen = {}, {}
    local manager = _G.ChatConfigChannelSettingsLeft
    for _, row in ipairs(manager and manager.WideCheckboxes or {}) do
        AddUniqueTarget(rows, seen, row)
    end
    return rows
end

local function GetChatConfigGeneralMessageRows()
    local rows, seen = {}, {}
    for _, managerName in ipairs(CHAT_CONFIG_GENERAL_ROW_MANAGER_NAMES) do
        local manager = _G[managerName]
        for index = 1, #(manager and manager.checkBoxTable or {}) do
            AddUniqueTarget(rows, seen,
                _G[managerName .. "Checkbox" .. index])
        end
    end
    return rows
end

local function GetChatConfigChannelCloseButtons()
    local targets = {}
    for _, row in ipairs(GetChatConfigChannelRows()) do
        if row.CloseChannel then targets[#targets + 1] = row.CloseChannel end
    end
    return targets
end

local function IsChatConfigCategorySelected(button)
    local categories = _G.CHAT_CONFIG_CATEGORIES
    local panelName = categories and button and button.GetID
        and categories[button:GetID()]
    local panel = panelName and _G[panelName]
    return panel and panel.IsShown and panel:IsShown() or false
end

local function IsChatConfigTabSelected(tab)
    return tab and tab.GetID and tab:GetID() == _G.CURRENT_CHAT_FRAME_ID
end

local function GetChatConfigSwatchTexture(swatch)
    if not swatch then return nil end
    return swatch.Color or swatch.color
        or (swatch.GetNormalTexture and swatch:GetNormalTexture())
end

local function RegisterChatConfigGroup(frame, definition)
    local id = definition.id
    local function GetVisibleTargets()
        local targets = {}
        for _, target in ipairs(definition.targets()) do
            if IsVisible(target) then targets[#targets + 1] = target end
        end
        return targets
    end
    if not registeredChatConfigGroups[id] then
        registeredChatConfigGroups[id] = NSkin:RegisterSkinningElement(id, {
            label = definition.label,
            kind = definition.kind,
            rowFamily = definition.rowFamily,
            module = "GameMenu",
            appearanceWindowID = IDs.ChatConfig.Scope,
            window = frame,
            target = definition.owner or frame,
            priority = definition.priority,
            draggable = false,
            appearanceStyles = definition.appearanceStyles,
            appearanceTypeIDs = definition.appearanceTypeIDs,
            highlightRegions = GetVisibleTargets,
            pixelBorderTargets = definition.pixelBorders
                and GetVisibleTargets or nil,
            refreshAppearance = definition.refresh,
            refreshLayout = definition.refresh,
            isEditable = function()
                return IsVisible(frame) and #GetVisibleTargets() > 0
            end,
        }) == true
    end
    local applied = definition.refresh()
    if registeredChatConfigGroups[id] then
        NSkin:NotifySkinningElementBoundsChanged(id)
    end
    return applied or registeredChatConfigGroups[id]
end

function GameMenuSkin:ApplyChatConfigTabs(frame)
    local tabs = GetChatConfigTabs(frame)
    if #tabs == 0 then return false end
    local style = NSkin:GetAppearanceStyle(
        "tab", IDs.ChatConfig.Scope, IDs.ChatConfig.ChatTabs)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.ChatConfig.Scope, IDs.ChatConfig.ChatTabs)
    for _, tab in ipairs(tabs) do
        NSkin:SkinTab(tab, IsChatConfigTabSelected(tab), style, border)
    end
    NSkin:RegisterTabGroup(IDs.ChatConfig.ChatTabs, {
        label = "Chat configuration main tabs",
        module = "GameMenu",
        appearanceWindowID = IDs.ChatConfig.Scope,
        window = frame,
        tabs = tabs,
        priority = 42,
        orientation = "HORIZONTAL",
        edge = "TOP",
        getSelected = IsChatConfigTabSelected,
    })
    NSkin:NotifySkinningElementBoundsChanged(IDs.ChatConfig.ChatTabs)
    return true
end

function GameMenuSkin:ApplyChatConfigCategories(frame)
    local style = NSkin:GetAppearanceStyle(
        "sectionRow", IDs.ChatConfig.Scope, IDs.ChatConfig.Categories)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionRow", style, IDs.ChatConfig.Scope, IDs.ChatConfig.Categories)
    local textStyle = NSkin:GetAppearanceStyle(
        "text", IDs.ChatConfig.Scope, IDs.ChatConfig.Categories)
    local applied = false
    for _, button in ipairs(GetChatConfigCategories()) do
        applied = NSkin:SkinSectionRow(button, {
            style = style,
            border = border,
            contentRegions = { button.NormalText or button.Text
                or (button.GetFontString and button:GetFontString()) },
            contentStyle = textStyle,
            hoverRegion = button.GetHighlightTexture
                and button:GetHighlightTexture(),
            selectedRegion = button.GetHighlightTexture
                and button:GetHighlightTexture(),
            getHovered = IsHovered,
            getSelected = IsChatConfigCategorySelected,
        }) ~= nil or applied
    end
    return applied
end

function GameMenuSkin:ApplyChatConfigOptions(frame)
    local checkboxes, labels, swatches = GetChatConfigOptionTargets(
        CHAT_CONFIG_GENERAL_MANAGER_NAMES, false)
    local checkboxStyle = NSkin:GetAppearanceStyle(
        "button", IDs.ChatConfig.Scope, IDs.ChatConfig.Checkboxes)
    local checkboxBorder = NSkin:GetAppearanceBorderColor(
        "button", checkboxStyle, IDs.ChatConfig.Scope,
        IDs.ChatConfig.Checkboxes)
    local textStyle = NSkin:GetAppearanceStyle(
        "text", IDs.ChatConfig.Scope, IDs.ChatConfig.CheckboxLabels)
    local iconStyle = NSkin:GetAppearanceStyle(
        "icon", IDs.ChatConfig.Scope, IDs.ChatConfig.ColorSwatches)
    local iconBorder = NSkin:GetAppearanceBorderColor(
        "icon", iconStyle, IDs.ChatConfig.Scope,
        IDs.ChatConfig.ColorSwatches)
    local applied = false
    for _, check in ipairs(checkboxes) do
        applied = NSkin:SkinCheckButton(check, {
            style = checkboxStyle,
            border = checkboxBorder,
            text = check.Text or check.text
                or (check.GetFontString and check:GetFontString()),
            textStyle = textStyle,
        }) or applied
    end
    for _, label in ipairs(labels) do
        applied = NSkin:SkinText(label, textStyle) ~= nil or applied
    end
    for _, swatch in ipairs(swatches) do
        local texture = GetChatConfigSwatchTexture(swatch)
        if texture then
            applied = NSkin:SkinIcon(swatch, {
                texture = texture,
                borderOwner = swatch,
                style = iconStyle,
                borderColor = iconBorder,
                nativeDecorationRegions = {
                    swatch.SwatchBg, swatch.InnerBorder,
                },
            }) or applied
        end
    end
    return applied
end

function GameMenuSkin:ApplyChatConfigChannelRows(frame)
    local rowStyle = NSkin:GetAppearanceStyle(
        "sectionRow", IDs.ChatConfig.Scope, IDs.ChatConfig.ChannelRows)
    local rowBorder = NSkin:GetAppearanceBorderColor(
        "sectionRow", rowStyle, IDs.ChatConfig.Scope,
        IDs.ChatConfig.ChannelRows)
    local buttonStyle = NSkin:GetAppearanceStyle(
        "button", IDs.ChatConfig.Scope, IDs.ChatConfig.ChannelCloseButtons)
    local buttonBorder = NSkin:GetAppearanceBorderColor(
        "button", buttonStyle, IDs.ChatConfig.Scope,
        IDs.ChatConfig.ChannelCloseButtons)
    local applied = false
    for _, row in ipairs(GetChatConfigChannelRows()) do
        applied = NSkin:SkinSectionRow(row, {
            style = rowStyle,
            border = rowBorder,
            preserveTextures = {
                row.ArtOverlay and row.ArtOverlay.GrayedOut,
            },
        }) ~= nil or applied
    end
    for _, button in ipairs(GetChatConfigChannelCloseButtons()) do
        NSkin:SkinFlatButton(button, "X", buttonStyle.background,
            buttonBorder, buttonStyle.textSize)
        applied = true
    end
    return applied
end

function GameMenuSkin:ApplyChatConfigGeneralMessageRows(frame)
    local id = IDs.ChatConfig.General.MessageRows
    local style = NSkin:GetAppearanceStyle(
        "row", IDs.ChatConfig.Scope, id)
    local border = NSkin:GetAppearanceBorderColor(
        "row", style, IDs.ChatConfig.Scope, id)
    local applied = false
    for _, row in ipairs(GetChatConfigGeneralMessageRows()) do
        applied = NSkin:SkinRow(row, {
            style = style,
            border = border,
            nativeDecorationRegions = {
                row.NineSlice,
            },
        }) ~= nil or applied
    end
    return applied
end

function GameMenuSkin:RegisterChatConfigGroups(frame)
    local ids = IDs.ChatConfig
    local categories = _G.ChatConfigCategoryFrame or frame
    local optionsOwner = _G.ChatConfigBackgroundFrame or frame
    local channelOwner = _G.ChatConfigChannelSettingsLeft or optionsOwner
    local definitions = {
        { id = ids.Categories, label = "Chat categories",
            kind = "BUTTON", rowFamily = "sectionRow",
            owner = categories, priority = 43,
            pixelBorders = true, appearanceStyles = { "text" },
            appearanceTypeIDs = { "TEXT" },
            targets = GetChatConfigCategories,
            refresh = function()
                return GameMenuSkin:ApplyChatConfigCategories(frame)
            end },
        { id = ids.Checkboxes, label = "Chat option checkboxes",
            kind = "CHECKBOX", owner = optionsOwner, priority = 50,
            pixelBorders = true,
            targets = function()
                local targets = GetChatConfigOptionTargets(
                    CHAT_CONFIG_GENERAL_MANAGER_NAMES, false)
                return targets
            end,
            refresh = function()
                return GameMenuSkin:ApplyChatConfigOptions(frame)
            end },
        { id = ids.CheckboxLabels, label = "Chat option labels",
            kind = "TEXT", owner = optionsOwner, priority = 51,
            targets = function()
                local _, targets = GetChatConfigOptionTargets(
                    CHAT_CONFIG_GENERAL_MANAGER_NAMES, false)
                return targets
            end,
            refresh = function()
                return GameMenuSkin:ApplyChatConfigOptions(frame)
            end },
        { id = ids.ColorSwatches, label = "Chat color swatches",
            kind = "ICON", owner = optionsOwner, priority = 52,
            pixelBorders = true,
            targets = function()
                local _, _, targets = GetChatConfigOptionTargets(
                    CHAT_CONFIG_GENERAL_MANAGER_NAMES, false)
                return targets
            end,
            refresh = function()
                return GameMenuSkin:ApplyChatConfigOptions(frame)
            end },
        { id = ids.General.MessageRows,
            label = "General chat message rows", kind = "BUTTON",
            rowFamily = "row",
            owner = optionsOwner, priority = 53, pixelBorders = true,
            targets = GetChatConfigGeneralMessageRows,
            refresh = function()
                return GameMenuSkin:ApplyChatConfigGeneralMessageRows(frame)
            end },
        { id = ids.ChannelRows, label = "Movable chat channel rows",
            kind = "BUTTON", rowFamily = "sectionRow",
            owner = channelOwner, priority = 54,
            pixelBorders = true, targets = GetChatConfigChannelRows,
            refresh = function()
                return GameMenuSkin:ApplyChatConfigChannelRows(frame)
            end },
        { id = ids.ChannelCloseButtons,
            label = "Leave channel buttons", kind = "BUTTON",
            owner = channelOwner, priority = 55, pixelBorders = true,
            targets = GetChatConfigChannelCloseButtons,
            refresh = function()
                return GameMenuSkin:ApplyChatConfigChannelRows(frame)
            end },
    }
    local applied = false
    for _, definition in ipairs(definitions) do
        applied = RegisterChatConfigGroup(frame, definition) or applied
    end
    return applied
end

function GameMenuSkin:ApplyChatConfigBottomControls(frame)
    local ids = IDs.ChatConfig
    local applied = false
    local okayButton = frame.OkayButton or _G.ChatConfigFrameOkayButton
    if okayButton then
        applied = NSkin:RegisterActionButton({
            id = ids.Okay,
            module = "GameMenu",
            appearanceWindowID = ids.Scope,
            label = "Chat configuration accept button",
            window = frame,
            target = okayButton,
            priority = 61,
            highlightRegions = { okayButton },
            isEditable = function()
                return IsVisible(frame) and IsVisible(okayButton)
            end,
        }) ~= nil or applied
    end
    return applied
end

local function RegisterChatConfigButton(frame, id, label, button, priority,
    action, glyph)
    if not button then return false end
    local definition = {
        id = id,
        module = "GameMenu",
        appearanceWindowID = IDs.ChatConfig.Scope,
        label = label,
        window = frame,
        target = button,
        priority = priority,
        highlightRegions = { button },
        isEditable = function()
            return IsVisible(frame) and IsVisible(button)
        end,
    }
    if action then return NSkin:RegisterActionButton(definition) ~= nil end

    local function Refresh()
        local style = NSkin:GetAppearanceStyle(
            "button", IDs.ChatConfig.Scope, id)
        local border = NSkin:GetAppearanceBorderColor(
            "button", style, IDs.ChatConfig.Scope, id)
        if glyph then
            NSkin:SkinFlatButton(button, glyph, style.background,
                border, style.textSize)
        else
            NSkin:SkinActionButton(button, {
                style = style,
                border = border,
            })
        end
        return true
    end
    definition.kind = "BUTTON"
    definition.draggable = false
    definition.pixelBorderTargets = { button }
    definition.refreshAppearance = Refresh
    definition.refreshLayout = Refresh
    NSkin:RegisterSkinningElement(id, definition)
    Refresh()
    return true
end

local function GetGeneralSectionHeaders()
    local targets, seen = {}, {}
    for _, managerName in ipairs(CHAT_CONFIG_GENERAL_MANAGER_NAMES) do
        local manager = _G[managerName]
        AddUniqueTarget(targets, seen, manager and manager.header)
        AddUniqueTarget(targets, seen, _G[managerName .. "Title"])
        AddUniqueTarget(targets, seen, _G[managerName .. "ColorHeader"])
    end
    return targets
end

local function GetCombatSectionHeaders()
    local targets, seen = {}, {}
    for _, name in ipairs({
        "CombatConfigMessageSourcesDoneByTitle",
        "CombatConfigMessageSourcesDoneToTitle",
        "CombatConfigColorsUnitColorsTitle",
        "CombatConfigColorsHighlightingTitle",
    }) do
        AddUniqueTarget(targets, seen, _G[name])
    end
    return targets
end

local function ApplyChatConfigHeaderFamily(id, targets)
    local style = NSkin:GetAppearanceStyle(
        "text", IDs.ChatConfig.Scope, id)
    local applied = false
    for _, target in ipairs(targets) do
        applied = NSkin:SkinText(target, style) ~= nil or applied
    end
    return applied
end

local function RegisterChatConfigHeaderFamily(frame, id, label, owner,
    targets, priority)
    return RegisterChatConfigGroup(frame, {
        id = id,
        label = label,
        kind = "SECTION_HEADER",
        owner = owner,
        priority = priority,
        appearanceStyles = { "text" },
        appearanceTypeIDs = { "TEXT" },
        editorOptions = {
            { id = "shared.textAppearance", label = "Text",
                category = "CUSTOMIZE" },
        },
        targets = targets,
        refresh = function()
            return ApplyChatConfigHeaderFamily(id, targets())
        end,
    })
end

local COMBAT_STATIC_CHECKBOX_NAMES = {
    "CombatConfigColorsHighlightingLine",
    "CombatConfigColorsHighlightingAbility",
    "CombatConfigColorsHighlightingDamage",
    "CombatConfigColorsHighlightingSchool",
    "CombatConfigColorsColorizeUnitNameCheck",
    "CombatConfigColorsColorizeSpellNamesCheck",
    "CombatConfigColorsColorizeSpellNamesSchoolColoring",
    "CombatConfigColorsColorizeDamageNumberCheck",
    "CombatConfigColorsColorizeDamageNumberSchoolColoring",
    "CombatConfigColorsColorizeDamageSchoolCheck",
    "CombatConfigColorsColorizeEntireLineCheck",
    "CombatConfigColorsColorizeEntireLineBySource",
    "CombatConfigColorsColorizeEntireLineByTarget",
    "CombatConfigFormattingShowTimeStamp",
    "CombatConfigFormattingShowBraces",
    "CombatConfigFormattingUnitNames",
    "CombatConfigFormattingSpellNames",
    "CombatConfigFormattingItemNames",
    "CombatConfigFormattingFullText",
    "CombatConfigSettingsShowQuickButton",
    "CombatConfigSettingsSolo",
    "CombatConfigSettingsParty",
    "CombatConfigSettingsRaid",
}

local COMBAT_STATIC_SWATCH_NAMES = {
    "CombatConfigColorsColorizeSpellNamesColorSwatch",
    "CombatConfigColorsColorizeDamageNumberColorSwatch",
}

local function GetCombatOptionTargets()
    local checks, labels, swatches = GetChatConfigOptionTargets(
        CHAT_CONFIG_COMBAT_MANAGER_NAMES, false)
    local seenChecks, seenLabels, seenSwatches = {}, {}, {}
    for _, target in ipairs(checks) do seenChecks[target] = true end
    for _, target in ipairs(labels) do seenLabels[target] = true end
    for _, target in ipairs(swatches) do seenSwatches[target] = true end
    for _, name in ipairs(COMBAT_STATIC_CHECKBOX_NAMES) do
        local check = _G[name]
        AddUniqueTarget(checks, seenChecks, check)
        AddUniqueTarget(labels, seenLabels, check and (check.Text
            or check.text or _G[name .. "Text"]))
    end
    for _, name in ipairs(COMBAT_STATIC_SWATCH_NAMES) do
        AddUniqueTarget(swatches, seenSwatches, _G[name])
    end
    return checks, labels, swatches
end

function GameMenuSkin:ApplyChatConfigCombatOptions(frame)
    local id = IDs.ChatConfig.CombatLog.FilterOptions
    local checks, labels, swatches = GetCombatOptionTargets()
    local checkStyle = NSkin:GetAppearanceStyle(
        "button", IDs.ChatConfig.Scope, id)
    local checkBorder = NSkin:GetAppearanceBorderColor(
        "button", checkStyle, IDs.ChatConfig.Scope, id)
    local textStyle = NSkin:GetAppearanceStyle(
        "text", IDs.ChatConfig.Scope, id)
    local swatchID = IDs.ChatConfig.ColorSwatches
    local iconStyle = NSkin:GetAppearanceStyle(
        "icon", IDs.ChatConfig.Scope, swatchID)
    local iconBorder = NSkin:GetAppearanceBorderColor(
        "icon", iconStyle, IDs.ChatConfig.Scope, swatchID)
    local applied = false
    for _, check in ipairs(checks) do
        applied = NSkin:SkinCheckButton(check, {
            style = checkStyle,
            border = checkBorder,
            text = check.Text or check.text
                or (check.GetFontString and check:GetFontString()),
            textStyle = textStyle,
        }) or applied
    end
    for _, label in ipairs(labels) do
        applied = NSkin:SkinText(label, textStyle) ~= nil or applied
    end
    for _, swatch in ipairs(swatches) do
        local texture = GetChatConfigSwatchTexture(swatch)
        if texture then
            applied = NSkin:SkinIcon(swatch, {
                texture = texture,
                borderOwner = swatch,
                style = iconStyle,
                borderColor = iconBorder,
                nativeDecorationRegions = { swatch.SwatchBg },
            }) or applied
        end
    end
    return applied
end

local function GetCombatFilterRows()
    local targets = {}
    local filters = _G.ChatConfigCombatSettingsFilters
    NSkin:ForEachScrollBoxFrame(filters and filters.ScrollBox,
        function(target) targets[#targets + 1] = target end)
    return targets
end

local function IsCombatFilterSelected(button)
    local data = button and button.GetElementData
        and button:GetElementData()
    local filters = _G.ChatConfigCombatSettingsFilters
    return data and filters and data.index == filters.selectedFilter
end

local function ReassertCombatFilterRowText(button)
    local state = hookedCombatFilterRowText[button]
    local text = button and (button.NormalText or button.Text)
    if not state or state.applying or not text then return end
    state.applying = true
    NSkin:SkinText(text, NSkin:GetAppearanceStyle(
        "text", IDs.ChatConfig.Scope,
        IDs.ChatConfig.CombatLog.FilterRows))
    state.applying = false
end

local function HookCombatFilterRowText(button)
    if not button or hookedCombatFilterRowText[button] then return end
    hookedCombatFilterRowText[button] = { applying = false }
    if button.HookScript then
        for _, script in ipairs({
            "OnShow", "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp",
            "OnEnable", "OnDisable",
        }) do
            button:HookScript(script, ReassertCombatFilterRowText)
        end
    end
    if _G.hooksecurefunc then
        for _, method in ipairs({
            "SetButtonState", "SetEnabled", "Enable", "Disable",
            "SetNormalFontObject", "SetHighlightFontObject",
            "SetDisabledFontObject", "LockHighlight", "UnlockHighlight",
        }) do
            if type(button[method]) == "function" then
                pcall(_G.hooksecurefunc, button, method, function()
                    ReassertCombatFilterRowText(button)
                end)
            end
        end
        local text = button.NormalText or button.Text
        if text and type(text.SetFontObject) == "function" then
            pcall(_G.hooksecurefunc, text, "SetFontObject", function()
                ReassertCombatFilterRowText(button)
            end)
        end
    end
    ReassertCombatFilterRowText(button)
end

function GameMenuSkin:ApplyCombatFilterRows(frame)
    local id = IDs.ChatConfig.CombatLog.FilterRows
    local style = NSkin:GetAppearanceStyle(
        "sectionRow", IDs.ChatConfig.Scope, id)
    local border = NSkin:GetAppearanceBorderColor(
        "sectionRow", style, IDs.ChatConfig.Scope, id)
    local textStyle = NSkin:GetAppearanceStyle(
        "text", IDs.ChatConfig.Scope, id)
    local applied = false
    for _, button in ipairs(GetCombatFilterRows()) do
        HookCombatFilterRowText(button)
        applied = NSkin:SkinSectionRow(button, {
            style = style,
            border = border,
            contentRegions = { button.NormalText or button.Text },
            contentStyle = textStyle,
            hoverRegion = button.GetHighlightTexture
                and button:GetHighlightTexture(),
            selectedRegion = button.GetHighlightTexture
                and button:GetHighlightTexture(),
            getHovered = IsHovered,
            getSelected = IsCombatFilterSelected,
        }) ~= nil or applied
        ReassertCombatFilterRowText(button)
    end
    return applied
end

local function GetCombatTabs()
    local tabs = {}
    for index = 1, 5 do
        local tab = _G["CombatConfigTab" .. index]
        if tab then tabs[#tabs + 1] = tab end
    end
    return tabs
end

local function IsCombatTabSelected(tab)
    local definition = _G.COMBAT_CONFIG_TABS
        and tab and tab.GetID and _G.COMBAT_CONFIG_TABS[tab:GetID()]
    local panel = definition and definition.frame and _G[definition.frame]
    return panel and panel.IsShown and panel:IsShown() or false
end

function GameMenuSkin:ApplyCombatTabs(frame)
    local id = IDs.ChatConfig.CombatLog.FilterTabs
    local tabs = GetCombatTabs()
    if #tabs == 0 then return false end
    local style = NSkin:GetAppearanceStyle("tab", IDs.ChatConfig.Scope, id)
    local border = NSkin:GetAppearanceBorderColor(
        "tab", style, IDs.ChatConfig.Scope, id)
    for _, tab in ipairs(tabs) do
        NSkin:SkinTab(tab, IsCombatTabSelected(tab), style, border)
    end
    NSkin:RegisterTabGroup(id, {
        label = "Combat Log filter tabs",
        module = "GameMenu",
        appearanceWindowID = IDs.ChatConfig.Scope,
        window = frame,
        tabs = tabs,
        priority = 75,
        orientation = "HORIZONTAL",
        edge = "TOP",
        getSelected = IsCombatTabSelected,
    })
    NSkin:NotifySkinningElementBoundsChanged(id)
    return true
end

local function GetCombatFilterNameLabel(editBox)
    if not editBox or not editBox.GetRegions then return nil end
    local inputText = editBox.GetFontString and editBox:GetFontString()
    for _, region in ipairs({ editBox:GetRegions() }) do
        if region ~= inputText and region.GetObjectType
            and region:GetObjectType() == "FontString"
            and region.GetText and region:GetText() == _G.FILTER_NAME
        then
            return region
        end
    end
end

local function GetCombatFormattingExampleText()
    local targets = {}
    if _G.CombatConfigFormattingExampleString1 then
        targets[#targets + 1] = _G.CombatConfigFormattingExampleString1
    end
    if _G.CombatConfigFormattingExampleString2 then
        targets[#targets + 1] = _G.CombatConfigFormattingExampleString2
    end
    return targets
end

function GameMenuSkin:ApplyChatConfigCombatSettingsControls(frame)
    local ids = IDs.ChatConfig.CombatLog
    local settingsIDs = ids.Settings
    local formattingIDs = ids.Formatting
    local settings = _G.CombatConfigSettings
    local formatting = _G.CombatConfigFormatting
    local editBox = _G.CombatConfigSettingsNameEditBox
    local filterNameLabel = GetCombatFilterNameLabel(editBox)

    if filterNameLabel then
        NSkin:RegisterTextElement({
            id = settingsIDs.FilterNameLabel,
            module = "GameMenu",
            appearanceWindowID = IDs.ChatConfig.Scope,
            label = "Combat Log filter name label",
            window = frame,
            target = filterNameLabel,
            priority = 78,
            highlightRegions = { filterNameLabel },
            isEditable = function()
                return IsVisible(frame) and IsVisible(settings)
                    and IsVisible(filterNameLabel)
            end,
        })
    end
    if editBox then
        NSkin:RegisterEditBox({
            id = settingsIDs.FilterName,
            module = "GameMenu",
            appearanceWindowID = IDs.ChatConfig.Scope,
            label = "Combat Log filter name",
            window = frame,
            target = editBox,
            priority = 79,
            highlightRegions = { editBox },
            isEditable = function()
                return IsVisible(frame) and IsVisible(settings)
                    and IsVisible(editBox)
            end,
        })
    end
    RegisterChatConfigButton(frame, settingsIDs.SaveName,
        "Save Combat Log filter name",
        settings and settings.SaveButton
            or _G.CombatConfigSettingsSaveButton, 80, true)

    local exampleHeader = _G.CombatConfigFormattingExampleTitle
    if exampleHeader then
        NSkin:RegisterTextElement({
            id = formattingIDs.ExampleHeader,
            module = "GameMenu",
            appearanceWindowID = IDs.ChatConfig.Scope,
            label = "Combat Log formatting example header",
            window = frame,
            target = exampleHeader,
            priority = 81,
            highlightRegions = { exampleHeader },
            isEditable = function()
                return IsVisible(frame) and IsVisible(formatting)
                    and IsVisible(exampleHeader)
            end,
        })
    end
    RegisterChatConfigGroup(frame, {
        id = formattingIDs.ExampleText,
        label = "Combat Log formatting example text",
        kind = "TEXT",
        owner = formatting or frame,
        priority = 82,
        targets = GetCombatFormattingExampleText,
        refresh = function()
            local style = NSkin:GetAppearanceStyle(
                "text", IDs.ChatConfig.Scope,
                formattingIDs.ExampleText)
            local applied = false
            for _, target in ipairs(GetCombatFormattingExampleText()) do
                applied = NSkin:SkinText(target, style) ~= nil or applied
            end
            return applied
        end,
    })
    return true
end

function GameMenuSkin:ApplyChatConfigCombatLog(frame)
    local ids = IDs.ChatConfig.CombatLog
    local combat = _G.ChatConfigCombatSettings
    local filters = combat and combat.Filters
    if not combat or not filters then return false end
    self:ApplyCombatTabs(frame)
    self:ApplyChatConfigCombatSettingsControls(frame)
    RegisterChatConfigGroup(frame, {
        id = ids.FilterRows,
        label = "Combat Log filters",
        kind = "BUTTON", rowFamily = "sectionRow",
        owner = filters.ScrollBox,
        priority = 70,
        pixelBorders = true,
        appearanceStyles = { "text" },
        appearanceTypeIDs = { "TEXT" },
        targets = GetCombatFilterRows,
        refresh = function()
            return GameMenuSkin:ApplyCombatFilterRows(frame)
        end,
    })
    if filters.ScrollBar then
        NSkin:RegisterScrollBar({
            id = ids.FilterScrollBar,
            module = "GameMenu",
            appearanceWindowID = IDs.ChatConfig.Scope,
            label = "Combat Log filter scroll bar",
            window = frame,
            target = filters.ScrollBar,
            priority = 71,
            highlightRegions = { filters.ScrollBar },
            isEditable = function()
                return IsVisible(frame) and IsVisible(filters.ScrollBar)
            end,
        })
    end
    RegisterChatConfigButton(frame, ids.MoveFilterUp,
        "Move Combat Log filter up", _G.ChatConfigMoveFilterUpButton,
        72, false, "▲")
    RegisterChatConfigButton(frame, ids.MoveFilterDown,
        "Move Combat Log filter down", _G.ChatConfigMoveFilterDownButton,
        72, false, "▼")
    RegisterChatConfigButton(frame, ids.CopyFilter,
        "Copy Combat Log filter", filters.CopyFilterButton
            or _G.ChatConfigCombatSettingsFiltersCopyFilterButton, 73)
    RegisterChatConfigButton(frame, ids.AddFilter,
        "Add Combat Log filter", filters.AddFilterButton
            or _G.ChatConfigCombatSettingsFiltersAddFilterButton, 73)
    RegisterChatConfigButton(frame, ids.DeleteFilter,
        "Delete Combat Log filter", filters.DeleteButton
            or _G.ChatConfigCombatSettingsFiltersDeleteButton, 73)
    RegisterChatConfigButton(frame, ids.Defaults,
        "Combat Log defaults", _G.CombatLogDefaultButton, 79)
    RegisterChatConfigHeaderFamily(frame, ids.SectionHeaders,
        "Combat Log section headers", combat,
        GetCombatSectionHeaders, 76)
    RegisterChatConfigGroup(frame, {
        id = ids.FilterOptions,
        label = "Combat Log filter options",
        kind = "CHECKBOX",
        owner = combat,
        priority = 77,
        pixelBorders = true,
        appearanceStyles = { "text", "icon" },
        appearanceTypeIDs = { "TEXT", "ICON" },
        targets = function()
            local targets = GetCombatOptionTargets()
            return targets
        end,
        refresh = function()
            return GameMenuSkin:ApplyChatConfigCombatOptions(frame)
        end,
    })
    local scrollBox = filters.ScrollBox
    local events = _G.ScrollBoxListMixin and _G.ScrollBoxListMixin.Event
    if scrollBox and not hookedChatConfigScrollBoxes[scrollBox]
        and scrollBox.RegisterCallback and events
        and events.OnInitializedFrame
    then
        scrollBox:RegisterCallback(events.OnInitializedFrame,
            function(_, target)
                GameMenuSkin:ApplyCombatFilterRows(frame)
                NSkin:NotifySkinningElementBoundsChanged(ids.FilterRows)
            end, self)
        hookedChatConfigScrollBoxes[scrollBox] = true
    end
    return true
end

local function GetTTSContainer()
    return _G.TextToSpeechFrame and _G.TextToSpeechFrame.PanelContainer
end

local function GetTTSOptionCheckboxes()
    local container = GetTTSContainer()
    local targets = {}
    for _, key in ipairs({
        "PlaySoundSeparatingChatLinesCheckButton",
        "AddCharacterNameToSpeechCheckButton",
        "PlayActivitySoundWhenNotFocusedCheckButton",
        "NarrateMyMessagesCheckButton",
    }) do
        if container and container[key] then
            targets[#targets + 1] = container[key]
        end
    end
    return targets
end

local function GetTTSMessageCheckboxes()
    local manager = _G.ChatConfigTextToSpeechMessageSettings
    local targets = GetChatConfigOptionTargets({
        "ChatConfigTextToSpeechChannelSettingsLeft",
    }, false)
    local seen = {}
    for _, target in ipairs(targets) do seen[target] = true end
    for index = 1, #(manager and manager.checkBoxTable or {}) do
        local check = _G[manager:GetName() .. "Checkbox" .. index]
        AddUniqueTarget(targets, seen, check)
    end
    return targets
end

local function GetTTSMessageHeaders()
    local targets, seen = {}, {}
    local messageFrame = _G.ChatConfigTextToSpeechMessageSettings
    AddUniqueTarget(targets, seen, messageFrame and messageFrame.SubTitle)
    AddUniqueTarget(targets, seen,
        _G.ChatConfigTextToSpeechChannelSettingsLeftTitle)
    return targets
end

local function ApplyCheckboxTargets(id, targets)
    local style = NSkin:GetAppearanceStyle(
        "button", IDs.ChatConfig.Scope, id)
    local border = NSkin:GetAppearanceBorderColor(
        "button", style, IDs.ChatConfig.Scope, id)
    local textStyle = NSkin:GetAppearanceStyle(
        "text", IDs.ChatConfig.Scope, id)
    local applied = false
    for _, check in ipairs(targets) do
        applied = NSkin:SkinCheckButton(check, {
            style = style,
            border = border,
            text = check.Text or check.text
                or (check.GetFontString and check:GetFontString()),
            textStyle = textStyle,
        }) or applied
    end
    return applied
end

function GameMenuSkin:ApplyChatConfigTextToSpeech(frame)
    local ids = IDs.ChatConfig.TextToSpeech
    local container = GetTTSContainer()
    if not container then return false end
    RegisterChatConfigGroup(frame, {
        id = ids.OptionCheckboxes,
        label = "Text To Speech options",
        kind = "CHECKBOX",
        owner = container,
        priority = 80,
        pixelBorders = true,
        appearanceStyles = { "text" },
        appearanceTypeIDs = { "TEXT" },
        targets = GetTTSOptionCheckboxes,
        refresh = function()
            return ApplyCheckboxTargets(
                ids.OptionCheckboxes, GetTTSOptionCheckboxes())
        end,
    })
    if container.VoiceOptionsLabel then
        NSkin:RegisterSkinningElement(ids.VoiceOptionsHeader, {
            label = "Text To Speech voice options header",
            kind = "SECTION_HEADER",
            module = "GameMenu",
            appearanceWindowID = IDs.ChatConfig.Scope,
            window = frame,
            target = container.VoiceOptionsLabel,
            priority = 81,
            draggable = false,
            isEditable = function()
                return IsVisible(frame)
                    and IsVisible(container.VoiceOptionsLabel)
            end,
            refreshAppearance = function()
                return ApplyChatConfigHeaderFamily(
                    ids.VoiceOptionsHeader,
                    { container.VoiceOptionsLabel })
            end,
            refreshLayout = function()
                return ApplyChatConfigHeaderFamily(
                    ids.VoiceOptionsHeader,
                    { container.VoiceOptionsLabel })
            end,
        })
        ApplyChatConfigHeaderFamily(ids.VoiceOptionsHeader,
            { container.VoiceOptionsLabel })
    end
    local supportText = container.MoreVoicesURLContainer
        and container.MoreVoicesURLContainer.Text
    if supportText then
        NSkin:RegisterTextElement({
            id = ids.SupportPageLink,
            module = "GameMenu",
            appearanceWindowID = IDs.ChatConfig.Scope,
            label = "Text To Speech support page link",
            window = frame,
            target = supportText,
            priority = 82,
            highlightRegions = { supportText },
            isEditable = function()
                return IsVisible(frame) and IsVisible(supportText)
            end,
        })
    end
    if container.TtsVoiceDropdown then
        NSkin:RegisterDropdown({
            id = ids.VoiceDropdown,
            module = "GameMenu", appearanceWindowID = IDs.ChatConfig.Scope,
            label = "Text To Speech voice", window = frame,
            target = container.TtsVoiceDropdown, priority = 83,
            highlightRegions = { container.TtsVoiceDropdown },
            isEditable = function()
                return IsVisible(frame)
                    and IsVisible(container.TtsVoiceDropdown)
            end,
        })
    end
    if container.TtsVoiceAlternateDropdown then
        NSkin:RegisterDropdown({
            id = ids.AlternateVoiceDropdown,
            module = "GameMenu", appearanceWindowID = IDs.ChatConfig.Scope,
            label = "Text To Speech alternate voice", window = frame,
            target = container.TtsVoiceAlternateDropdown, priority = 84,
            highlightRegions = { container.TtsVoiceAlternateDropdown },
            isEditable = function()
                return IsVisible(frame)
                    and IsVisible(container.TtsVoiceAlternateDropdown)
            end,
        })
    end
    RegisterChatConfigButton(frame, ids.PlaySample,
        "Play Text To Speech sample", container.PlaySampleButton, 85, true)
    RegisterChatConfigButton(frame, ids.AlternatePlaySample,
        "Play alternate Text To Speech sample",
        container.PlaySampleAlternateButton, 86, true)
    if container.UseAlternateVoiceForSystemMessagesCheckButton then
        NSkin:RegisterCheckbox({
            id = ids.AlternateVoiceCheckbox,
            module = "GameMenu", appearanceWindowID = IDs.ChatConfig.Scope,
            label = "Use alternate voice for system messages",
            window = frame,
            target = container.UseAlternateVoiceForSystemMessagesCheckButton,
            text = container.UseAlternateVoiceForSystemMessagesCheckButton.text,
            priority = 87,
            isEditable = function()
                return IsVisible(frame) and IsVisible(
                    container.UseAlternateVoiceForSystemMessagesCheckButton)
            end,
        })
    end
    for _, definition in ipairs({
        { ids.SpeechRate, "Text To Speech rate", container.AdjustRateSlider },
        { ids.SpeechVolume, "Text To Speech volume",
            container.AdjustVolumeSlider },
    }) do
        local id, label, holder = unpack(definition)
        local slider = holder and (holder.Slider or holder)
        if slider then
            NSkin:RegisterSlider({
                id = id,
                module = "GameMenu",
                appearanceWindowID = IDs.ChatConfig.Scope,
                label = label,
                window = frame,
                target = slider,
                priority = 88,
                highlightRegions = { holder },
                isEditable = function()
                    return IsVisible(frame) and IsVisible(holder)
                        and IsVisible(slider)
                end,
            })
        end
    end
    RegisterChatConfigButton(frame, ids.Defaults,
        "Text To Speech defaults", _G.TextToSpeechDefaultButton, 89)
    if _G.TextToSpeechCharacterSpecificButton then
        NSkin:RegisterCheckbox({
            id = ids.CharacterSpecific,
            module = "GameMenu", appearanceWindowID = IDs.ChatConfig.Scope,
            label = "Character specific Text To Speech settings",
            window = frame,
            target = _G.TextToSpeechCharacterSpecificButton,
            text = _G.TextToSpeechCharacterSpecificButton.Text,
            priority = 90,
            isEditable = function()
                return IsVisible(frame)
                    and IsVisible(_G.TextToSpeechCharacterSpecificButton)
            end,
        })
    end
    local messageFrame = _G.ChatConfigTextToSpeechMessageSettings
    if #GetTTSMessageHeaders() > 0 then
        RegisterChatConfigHeaderFamily(frame, ids.MessageHeader,
            "Text To Speech message and channel headers",
            messageFrame or container, GetTTSMessageHeaders, 91)
    end
    RegisterChatConfigGroup(frame, {
        id = ids.MessageCheckboxes,
        label = "Text To Speech message types",
        kind = "CHECKBOX",
        owner = messageFrame or container,
        priority = 92,
        pixelBorders = true,
        appearanceStyles = { "text" },
        appearanceTypeIDs = { "TEXT" },
        targets = GetTTSMessageCheckboxes,
        refresh = function()
            return ApplyCheckboxTargets(
                ids.MessageCheckboxes, GetTTSMessageCheckboxes())
        end,
    })
    return true
end

function GameMenuSkin:ApplyChatConfigGeneral(frame)
    local ids = IDs.ChatConfig.General
    local panel = _G.ChatConfigBackgroundFrame
    HideDecorativeTextures(panel)
    HideDecorativeTextures(panel and panel.NineSlice)
    RegisterChatConfigHeaderFamily(frame, ids.SectionHeaders,
        "General chat section headers", panel or frame,
        GetGeneralSectionHeaders, 55)
    RegisterChatConfigButton(frame, ids.ChatDefaults,
        "Chat defaults", frame.DefaultButton, 62)
    RegisterChatConfigButton(frame, ids.ResetChatPositions,
        "Reset chat positions", frame.RedockButton, 63)
    return true
end

function GameMenuSkin:RefreshChatConfigEditorVisibility(frame)
    NSkin:ForEachRegisteredSkinningElement(function(element)
        if element.window == frame
            and element.appearanceWindowID == IDs.ChatConfig.Scope
        then
            NSkin:NotifySkinningElementBoundsChanged(element.id)
        end
    end)
end

function GameMenuSkin:HookChatConfigLifecycle(frame)
    if not chatConfigLifecycleHooked and frame.HookScript then
        frame:HookScript("OnShow", function()
            GameMenuSkin:ApplyChatConfigFrame()
        end)
        chatConfigLifecycleHooked = true
    end
    local manager = frame.ChatTabManager
    if manager and not chatConfigTabsHooked and _G.hooksecurefunc then
        for _, method in ipairs({ "UpdateTabDisplay", "UpdateSelection" }) do
            if type(manager[method]) == "function" then
                _G.hooksecurefunc(manager, method, function()
                    GameMenuSkin:ApplyChatConfigTabs(frame)
                    GameMenuSkin:RefreshChatConfigEditorVisibility(frame)
                end)
            end
        end
        chatConfigTabsHooked = true
    end
    if not chatConfigFunctionsHooked and _G.hooksecurefunc then
        for _, functionName in ipairs({
            "ChatConfig_CreateCheckboxes",
            "ChatConfig_CreateTieredCheckboxes",
            "ChatConfig_CreateColorSwatches",
            "TextToSpeechFrame_CreateCheckboxes",
        }) do
            if type(_G[functionName]) == "function" then
                _G.hooksecurefunc(functionName, function()
                    GameMenuSkin:ApplyChatConfigOptions(frame)
                    GameMenuSkin:ApplyChatConfigGeneralMessageRows(frame)
                    GameMenuSkin:ApplyChatConfigCombatOptions(frame)
                    GameMenuSkin:ApplyChatConfigTextToSpeech(frame)
                    GameMenuSkin:ApplyChatConfigChannelRows(frame)
                    SuppressChatConfigNineSliceBorders(frame)
                end)
            end
        end
        if type(_G.ChatConfig_UpdateCombatTabs) == "function" then
            _G.hooksecurefunc("ChatConfig_UpdateCombatTabs", function()
                GameMenuSkin:ApplyCombatTabs(frame)
                GameMenuSkin:RefreshChatConfigEditorVisibility(frame)
            end)
        end
        if type(_G.ChatConfigCategory_OnClick) == "function" then
            _G.hooksecurefunc("ChatConfigCategory_OnClick", function()
                GameMenuSkin:RefreshChatConfigEditorVisibility(frame)
            end)
        end
        chatConfigFunctionsHooked = true
    end
end

function GameMenuSkin:ApplyChatConfigFrame()
    local frame = _G.ChatConfigFrame
    if not frame then return false end
    HideDecorativeTextures(frame.Border)
    HideDecorativeTextures(frame.Header)
    local title = frame.Header and (frame.Header.Text or frame.Header.TitleText)
    NSkin:SkinStandardWindowChrome({
        frame = frame,
        appearanceWindowID = IDs.ChatConfig.Scope,
        elementID = IDs.ChatConfig.Window,
        headerControlsID = IDs.ChatConfig.Close,
        style = GetWindowStyle(IDs.ChatConfig.Scope,
            IDs.ChatConfig.Window, frame.Header, 22),
        title = false,
        closeButton = frame.CloseButton,
        preserveArtwork = { Border = true, Header = true },
    })
    NSkin:RegisterSkinningElement(IDs.ChatConfig.Window, {
        label = "Chat Configuration window",
        kind = "WINDOW",
        module = "GameMenu",
        appearanceWindowID = IDs.ChatConfig.Scope,
        window = frame,
        target = frame,
        priority = 0,
        draggable = false,
    })
    if title then
        NSkin:RegisterTextElement({
            id = IDs.ChatConfig.Title,
            module = "GameMenu",
            appearanceWindowID = IDs.ChatConfig.Scope,
            label = "Chat Configuration title",
            window = frame,
            target = title,
            priority = 1,
            highlightRegions = { title },
            isEditable = function()
                return IsVisible(frame) and IsVisible(title)
            end,
        })
    end
    self:ApplyChatConfigTabs(frame)
    self:RegisterChatConfigGroups(frame)
    self:ApplyChatConfigGeneral(frame)
    self:ApplyChatConfigCombatLog(frame)
    self:ApplyChatConfigTextToSpeech(frame)
    self:ApplyChatConfigBottomControls(frame)
    SuppressChatConfigNineSliceBorders(frame)
    return true
end

function GameMenuSkin:InitializeChatConfigFrame()
    local frame = _G.ChatConfigFrame
    if not frame then return false end
    self:HookChatConfigLifecycle(frame)
    chatConfigInitialized = true
    return self:ApplyChatConfigFrame()
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
    if chatConfigInitialized then self:ApplyChatConfigFrame() end
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

NSkin:RegisterWindowSkin({
    key = "GameMenu.ChatConfigFrame",
    module = "GameMenu",
    addon = "Blizzard_ChatFrame",
    apply = function() return GameMenuSkin:InitializeChatConfigFrame() end,
})
