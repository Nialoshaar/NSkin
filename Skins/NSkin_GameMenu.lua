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
local macroLifecycleHooked = false
local macroPopupLifecycleHooked = false
local settingsRootTexturesConcealed = false
local macroRootTexturesConcealed = false
local nextAnonymousButtonID = 0
local buttonIDs = setmetatable({}, { __mode = "k" })
local nextMacroSelectorIconID = 0
local macroSelectorIconIDs = setmetatable({}, { __mode = "k" })
local hookedMacroSelectorScrollBoxes = setmetatable({}, { __mode = "k" })

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
    if not scrollBox or not scrollBox.ForEachFrame then return false end

    local applied = false
    scrollBox:ForEachFrame(function(button)
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
    end)

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
