local _, NSkin = ...

local POPUP_COMPONENT_STATE = "iconSelectPopupComponent"
local SHARED_POPUP_SURFACE_STATE = "sharedPopupSurfaceComponent"
local EQUIPMENT_FLYOUT_STATE = "equipmentFlyoutPopupComponent"
local SELECTOR_SLOT_TEXTURE = "interface/buttons/ui-emptyslot-disabled"
local selectorSlotFileID
local selectorSlotFileIDResolved = false

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
end

local function RestorePopupDecoration(state)
    local region = state and state.region
    if not region then return end
    state.active = nil
    state.applying = true
    if region.SetAlpha then region:SetAlpha(state.alpha) end
    if state.shown ~= nil and region.SetShown then
        region:SetShown(state.shown)
    end
    state.applying = nil
end

local function SuppressPopupDecorations(frame, regions, reset)
    local data = NSkin:GetSkinData(frame, SHARED_POPUP_SURFACE_STATE)
    data.nativeDecorationStates = data.nativeDecorationStates or {}
    local declared = {}
    for _, region in ipairs(regions or {}) do
        if region then declared[region] = true end
    end
    for region, state in pairs(data.nativeDecorationStates) do
        if state.active and (reset or not declared[region]) then
            RestorePopupDecoration(state)
        end
    end
    if reset then return end
    for region in pairs(declared) do
        local state = data.nativeDecorationStates[region]
        if not state then
            state = {
                region = region,
                alpha = region.GetAlpha and region:GetAlpha() or 1,
                shown = region.IsShown and region:IsShown() or nil,
            }
            data.nativeDecorationStates[region] = state
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

-- Shared popup composition for transient Blizzard panels whose adapters know
-- their exact native decoration and child-control fields. The popup owns one
-- surface while the existing shared components continue to own each control's
-- appearance and interaction behavior.
function NSkin:SkinPopupSurface(frame, options)
    if not frame then return false end
    options = options or {}
    local windowStyle = options.windowStyle or self:GetStyle("window")
    local borderColor = options.border
        or self:GetAppearanceBorderColor("window", windowStyle)
        or self:GetWindowBorderColor()
    SuppressPopupDecorations(frame, options.nativeDecorationRegions,
        options.reset == true)
    local data = self:GetSkinData(frame, SHARED_POPUP_SURFACE_STATE)
    if options.reset == true then
        if data.background then data.background:Hide() end
        local border = self:GetPixelBorder(
            frame, "NSkinSharedPopupBackgroundBorder")
        self:SetPixelBorderShown(border, false)
        return true
    end

    data.background = self:CreateFlatBackground(frame,
        "NSkinSharedPopupBackground",
        self:GetResolvedAppearanceColor(windowStyle, "background"),
        borderColor)
    local border = self:GetPixelBorder(
        frame, "NSkinSharedPopupBackgroundBorder")
    self:SetPixelBorderColor(border, unpack(borderColor))
    self:SetPixelBorderSize(border, tonumber(windowStyle.borderSize) or 1)
    self:SetPixelBorderPadding(border,
        tonumber(windowStyle.borderPadding) or 0)

    if options.title then self:SkinText(options.title, options.textStyle) end
    for _, textRegion in ipairs(options.textRegions or {}) do
        self:SkinText(textRegion, options.textStyle)
    end
    if options.closeButton then
        self:SkinWindowHeaderButton(options.closeButton, { glyph = "close" }, {
            style = options.buttonStyle,
            border = options.buttonBorder,
        })
    end
    for _, button in ipairs(options.actionButtons or {}) do
        self:SkinActionButton(button, {
            style = options.buttonStyle,
            border = options.buttonBorder,
        })
    end
    for _, checkbox in ipairs(options.checkboxes or {}) do
        self:SkinCheckButton(checkbox, {
            style = options.buttonStyle,
            border = options.buttonBorder,
            text = checkbox.Text or checkbox.text,
        })
    end
    for _, editBox in ipairs(options.editBoxes or {}) do
        self:SkinEditBox(editBox, {
            style = options.editBoxStyle,
            border = options.editBoxBorder,
            decrementButton = editBox.DecrementButton,
            incrementButton = editBox.IncrementButton,
            spinnerButtonStyle = options.buttonStyle,
            spinnerButtonBorder = options.buttonBorder,
        })
    end
    if options.scrollBar then
        self:SkinScrollBar(options.scrollBar, options.scrollBarStyle)
    end
    return true
end

local function GetEquipmentFlyoutIcon(button)
    if not button then return nil end
    local icon = button.Icon or button.icon
        or button.IconTexture or button.iconTexture
    if icon and icon.SetTexCoord then return icon end
    if type(_G.GetItemButtonIconTexture) == "function" then
        icon = _G.GetItemButtonIconTexture(button)
        if icon and icon.SetTexCoord then return icon end
    end
end

local function GetEquipmentFlyoutQuality(button)
    local itemLocation = button and type(button.GetItemLocation) == "function"
        and button:GetItemLocation()
    if not itemLocation or not _G.C_Item
        or type(_G.C_Item.GetItemQuality) ~= "function" then
        return nil
    end
    return _G.C_Item.GetItemQuality(itemLocation)
end

local function GetEquipmentFlyoutDecorations(button)
    if not button then return {} end
    return {
        button.IconBorder,
        button.NormalTexture
            or (button.GetNormalTexture and button:GetNormalTexture()),
    }
end

local function IsEquipmentFlyoutButtonHovered(button)
    return button and button.IsMouseOver and button:IsMouseOver() or false
end

local function GetEquipmentFlyoutBackgrounds(flyout)
    local regions = { flyout and flyout.Highlight }
    local buttonFrame = flyout and flyout.buttonFrame
    local count = buttonFrame and tonumber(buttonFrame.numBGs) or 0
    for index = 1, count do
        regions[#regions + 1] = buttonFrame["bg" .. index]
    end
    return regions
end

local function IsEquipmentFlyoutDefinitionActive(definition)
    if type(definition.isActive) ~= "function" then return true end
    local ok, active = pcall(definition.isActive, definition.root)
    return ok and active == true
end

local function GetActiveEquipmentFlyoutDefinition(state)
    for _, definition in pairs(state.definitions or {}) do
        if IsEquipmentFlyoutDefinitionActive(definition) then
            return definition
        end
    end
end

local function GetEquipmentFlyoutIconChildren(definition)
    local children = {}
    for _, button in ipairs(definition.root.buttons or {}) do
        if button and button.IsShown and button:IsShown() then
            children[#children + 1] = {
                target = button,
                textureProvider = GetEquipmentFlyoutIcon,
                borderOwner = button,
                qualityProvider = GetEquipmentFlyoutQuality,
                nativeDecorationRegions = GetEquipmentFlyoutDecorations,
                hoverRegion = button.HighlightTexture
                    or (button.GetHighlightTexture
                        and button:GetHighlightTexture()),
                getHovered = IsEquipmentFlyoutButtonHovered,
            }
        end
    end
    return children
end

local function ApplyEquipmentFlyoutNavigation(definition, navigation)
    if not navigation then return end
    local ids = definition.ids
    for _, buttonDefinition in ipairs({
        { ids.previousButton, navigation.PrevButton, "<",
            "Previous equipment page", 82 },
        { ids.nextButton, navigation.NextButton, ">",
            "Next equipment page", 83 },
    }) do
        local id, button, glyph, label, priority = unpack(buttonDefinition)
        if id and button then
            NSkin:RegisterTypedElement("BUTTON", {
                id = id,
                module = definition.module,
                appearanceWindowID = definition.appearanceWindowID,
                label = label,
                window = definition.root,
                target = button,
                priority = priority,
                draggable = false,
                skinOptions = { label = glyph },
                highlightRegions = { button },
                isEditable = function()
                    return IsEquipmentFlyoutDefinitionActive(definition)
                        and IsVisible(definition.root) and IsVisible(button)
                end,
            })
        end
    end
end

function NSkin:RefreshEquipmentFlyoutPopup(root)
    if not root then return false end
    local state = self:GetSkinData(root, EQUIPMENT_FLYOUT_STATE, false)
    local definition = state and GetActiveEquipmentFlyoutDefinition(state)
    if not definition then return false end

    local ids = definition.ids
    local buttonFrame = root.buttonFrame
    if not buttonFrame then return false end
    local navigation = root.NavigationFrame
    local windowStyle = self:GetAppearanceStyle(
        "window", definition.appearanceWindowID, ids.window)
    self:SkinPopupSurface(buttonFrame, {
        windowStyle = windowStyle,
        nativeDecorationRegions = GetEquipmentFlyoutBackgrounds(root),
    })
    if navigation then
        self:SkinPopupSurface(navigation, {
            windowStyle = windowStyle,
            nativeDecorationRegions = { navigation.BottomBackground },
            textStyle = self:GetAppearanceStyle(
                "text", definition.appearanceWindowID, ids.window),
        })
        ApplyEquipmentFlyoutNavigation(definition, navigation)
    end
    self:SkinIconGroupChildren({
        id = ids.icons,
        appearanceWindowID = definition.appearanceWindowID,
        target = buttonFrame,
        children = function()
            return GetEquipmentFlyoutIconChildren(definition)
        end,
    })
    self:NotifySkinningElementBoundsChanged(ids.window)
    self:NotifySkinningElementBoundsChanged(ids.icons)
    return true
end

function NSkin:RegisterEquipmentFlyoutPopup(definition)
    if type(definition) ~= "table" or not definition.root
        or type(definition.module) ~= "string"
        or type(definition.appearanceWindowID) ~= "string"
        or not self:GetAppearanceScope(definition.appearanceWindowID)
        or type(definition.ids) ~= "table"
        or type(definition.ids.window) ~= "string"
        or type(definition.ids.icons) ~= "string"
    then return false end

    local root, ids = definition.root, definition.ids
    local buttonFrame = root.buttonFrame
    if not buttonFrame then return false end
    local state = self:GetSkinData(root, EQUIPMENT_FLYOUT_STATE)
    state.definitions = state.definitions or {}
    state.definitions[ids.window] = definition

    if not self:GetSkinningElement(ids.window) then
        self:RegisterSkinningElement(ids.window, {
            label = definition.windowLabel or "Equipment flyout",
            kind = "WINDOW",
            module = definition.module,
            appearanceWindowID = definition.appearanceWindowID,
            window = root,
            target = buttonFrame,
            priority = 80,
            draggable = false,
            highlightRegions = function()
                local regions = { buttonFrame }
                local navigation = root.NavigationFrame
                if IsVisible(navigation) then regions[#regions + 1] = navigation end
                return regions
            end,
            refreshAppearance = function()
                return NSkin:RefreshEquipmentFlyoutPopup(root)
            end,
            refreshLayout = function()
                return NSkin:RefreshEquipmentFlyoutPopup(root)
            end,
            isEditable = function()
                return IsEquipmentFlyoutDefinitionActive(definition)
                    and IsVisible(root) and IsVisible(buttonFrame)
            end,
        })
    end

    self:RegisterIconGroup({
        id = ids.icons,
        module = definition.module,
        appearanceWindowID = definition.appearanceWindowID,
        label = definition.iconsLabel or "Equipment choices",
        window = root,
        target = buttonFrame,
        priority = 81,
        draggable = false,
        children = function()
            return GetEquipmentFlyoutIconChildren(definition)
        end,
        highlightRegions = function()
            local regions = {}
            for _, button in ipairs(root.buttons or {}) do
                if IsVisible(button) then regions[#regions + 1] = button end
            end
            return regions
        end,
        isEditable = function()
            return IsEquipmentFlyoutDefinitionActive(definition)
                and IsVisible(root)
        end,
    })

    if not state.lifecycleHooked then
        if root.HookScript then
            root:HookScript("OnShow", function()
                NSkin:RefreshEquipmentFlyoutPopup(root)
            end)
        end
        if _G.hooksecurefunc
            and type(_G.EquipmentFlyout_UpdateItems) == "function" then
            _G.hooksecurefunc("EquipmentFlyout_UpdateItems", function()
                NSkin:RefreshEquipmentFlyoutPopup(root)
            end)
        end
        state.lifecycleHooked = true
    end
    return self:RefreshEquipmentFlyoutPopup(root) or true
end

local function NormalizeTexturePath(path)
    if type(path) ~= "string" then return nil end
    path = path:lower():gsub("\\", "/")
    return path:gsub("%.blp$", ""):gsub("%.tga$", "")
end

local function GetSelectorSlotFileID()
    if selectorSlotFileIDResolved then return selectorSlotFileID end
    selectorSlotFileIDResolved = true
    local getter = _G.GetFileIDFromPath
        or (_G.C_Texture and _G.C_Texture.GetFileIDFromPath)
    if type(getter) == "function" then
        local ok, fileID = pcall(getter,
            "Interface\\Buttons\\UI-EmptySlot-Disabled")
        if ok then selectorSlotFileID = fileID end
    end
    return selectorSlotFileID
end

-- SelectorButtonTemplate and SelectedIconButton deliberately use the same
-- anonymous empty-slot texture. Match that audited asset instead of treating
-- every background texture on an icon button as decorative.
local function IsSelectorSlotDecoration(region)
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
    if normalized == SELECTOR_SLOT_TEXTURE then return true end
    if type(texture) == "number"
        and texture == GetSelectorSlotFileID()
    then
        return true
    end

    -- Some clients expose only the numeric texture and cannot resolve its
    -- file path. The audited template texcoords remain a narrow fallback.
    if not region.GetTexCoord then return false end
    local left, right, top, bottom = region:GetTexCoord()
    return left == 0.140625 and right == 0.84375
        and top == 0.140625 and bottom == 0.84375
end

local function GetSelectorNativeDecorations(button, icon)
    local regions = {}
    if not button or not button.GetRegions then return regions end
    for _, region in ipairs({ button:GetRegions() }) do
        if region ~= icon and region ~= button.Highlight
            and region ~= button.SelectedTexture
            and IsSelectorSlotDecoration(region)
        then
            regions[#regions + 1] = region
        end
    end
    return regions
end

local function IsSelectorButtonHovered(button)
    return button and button.IsMouseOver and button:IsMouseOver() or false
end

local function IsSelectorButtonSelected(button)
    if not button then return false end
    local selector = button.GetSelectorFrame and button:GetSelectorFrame()
        or button.selectorFrame
    local index = button.GetSelectionIndex and button:GetSelectionIndex()
        or button.selectionIndex
    return selector and selector.IsSelected and index ~= nil
        and selector:IsSelected(index) or false
end

local function RegisterPopupText(definition, id, label, target, priority)
    if not id or not target then return nil end
    local root = definition.root
    return NSkin:RegisterTextElement({
        id = id,
        module = definition.module,
        appearanceWindowID = definition.appearanceWindowID,
        label = label,
        window = root,
        target = target,
        priority = priority,
        draggable = false,
        highlightRegions = { target },
        isEditable = function()
            return IsVisible(root) and IsVisible(target)
        end,
    })
end

local function RegisterSelectorIcon(definition, state, button, priority)
    local icon = button and button.Icon
    if not icon then return nil end
    local id = state.iconIDs[button]
    if not id then
        state.nextIconID = state.nextIconID + 1
        id = definition.ids.iconPrefix .. state.nextIconID
        state.iconIDs[button] = id
    end
    local existing = NSkin:GetSkinningElement(id)
    local element = NSkin:RegisterIcon({
        id = id,
        module = definition.module,
        appearanceWindowID = definition.appearanceWindowID,
        label = definition.iconLabel or "Icon selector entry",
        window = definition.root,
        target = button,
        texture = icon,
        nativeDecorationRegions = GetSelectorNativeDecorations(button, icon),
        hoverRegion = button.Highlight,
        selectedRegion = button.SelectedTexture,
        getHovered = IsSelectorButtonHovered,
        getSelected = IsSelectorButtonSelected,
        priority = priority,
        draggable = false,
        editorOptions = {
            { id = "shared.iconAppearance", label = "Icon",
                presentation = "INLINE", category = "CUSTOMIZE" },
        },
        isEditable = function()
            return IsVisible(definition.root) and IsVisible(button)
        end,
    })
    if element and NSkin:GetSavedMovableElementPlacement(id)
        and element.resetPlacement
    then
        element.resetPlacement(element)
    end
    if element and existing then NSkin:RefreshTypedElementLayout(element) end
    return element
end

local function RegisterSelectorIcons(definition, state, selector)
    local scrollBox = selector and selector.ScrollBox
    local applied = false
    if not NSkin:ForEachScrollBoxFrame(scrollBox, function(button)
        applied = RegisterSelectorIcon(
            definition, state, button, 70) ~= nil or applied
    end) then return false end
    if not state.hookedScrollBoxes[scrollBox]
        and _G.hooksecurefunc and type(scrollBox.Update) == "function"
    then
        _G.hooksecurefunc(scrollBox, "Update", function()
            local current = state.definition
            if current then RegisterSelectorIcons(current, state,
                current.iconSelector or current.root.IconSelector) end
        end)
        state.hookedScrollBoxes[scrollBox] = true
    end
    return applied
end

function NSkin:RegisterIconSelectPopup(definition)
    if type(definition) ~= "table" or not definition.root
        or type(definition.module) ~= "string"
        or type(definition.appearanceWindowID) ~= "string"
        or not self:GetAppearanceScope(definition.appearanceWindowID)
        or type(definition.ids) ~= "table"
        or type(definition.ids.window) ~= "string"
        or type(definition.ids.textBox) ~= "string"
        or type(definition.ids.dropdown) ~= "string"
        or type(definition.ids.okayButton) ~= "string"
        or type(definition.ids.cancelButton) ~= "string"
        or type(definition.ids.iconPrefix) ~= "string"
        or type(definition.ids.scrollBar) ~= "string"
    then return false end

    local root, ids = definition.root, definition.ids
    local borderBox = definition.borderBox or root.BorderBox
    local selector = definition.iconSelector or root.IconSelector
    if not borderBox or not selector then return false end

    local state = self:GetSkinData(root, POPUP_COMPONENT_STATE)
    state.definition = definition
    state.iconIDs = state.iconIDs
        or setmetatable({}, { __mode = "k" })
    state.hookedScrollBoxes = state.hookedScrollBoxes
        or setmetatable({}, { __mode = "k" })
    state.nextIconID = state.nextIconID or 0

    self:SkinStandardWindowChrome({
        frame = root,
        artworkFrame = borderBox,
        appearanceWindowID = definition.appearanceWindowID,
        elementID = ids.window,
        headerControlsID = ids.headerControls,
        skinCloseButton = false,
    })
    self:RegisterSkinningElement(ids.window, {
        label = definition.windowLabel or "Icon select popup",
        kind = "WINDOW",
        module = definition.module,
        appearanceWindowID = definition.appearanceWindowID,
        window = root,
        target = root,
        priority = 0,
        draggable = false,
    })

    local editBox = definition.textBox or borderBox.IconSelectorEditBox
    if editBox then
        self:RegisterEditBox({
            id = ids.textBox,
            module = definition.module,
            appearanceWindowID = definition.appearanceWindowID,
            label = definition.textBoxLabel or "Icon name",
            window = root,
            target = editBox,
            priority = 40,
            highlightRegions = { editBox },
            isEditable = function()
                return IsVisible(root) and IsVisible(editBox)
            end,
        })
    end

    local dropdown = definition.dropdown or borderBox.IconTypeDropdown
    if dropdown then
        self:RegisterDropdown({
            id = ids.dropdown,
            module = definition.module,
            appearanceWindowID = definition.appearanceWindowID,
            label = definition.dropdownLabel or "Icon type dropdown",
            window = root,
            target = dropdown,
            priority = 45,
            highlightRegions = { dropdown },
            isEditable = function()
                return IsVisible(root) and IsVisible(dropdown)
            end,
        })
    end

    for _, buttonDefinition in ipairs({
        { ids.okayButton, "Okay button", borderBox.OkayButton, 50 },
        { ids.cancelButton, "Cancel button", borderBox.CancelButton, 51 },
    }) do
        local id, label, button, priority = unpack(buttonDefinition)
        if button then
            self:RegisterActionButton({
                id = id,
                module = definition.module,
                appearanceWindowID = definition.appearanceWindowID,
                label = label,
                window = root,
                target = button,
                priority = priority,
                highlightRegions = { button },
                isEditable = function()
                    return IsVisible(root) and IsVisible(button)
                end,
            })
        end
    end

    RegisterPopupText(definition, ids.iconSelectionText,
        "Icon selection text", borderBox.IconSelectionText, 55)
    local selectedArea = borderBox.SelectedIconArea
    local selectedText = selectedArea and selectedArea.SelectedIconText
    RegisterPopupText(definition, ids.selectedIconHeader,
        "Selected icon header", selectedText and selectedText.SelectedIconHeader, 56)
    RegisterPopupText(definition, ids.selectedIconDescription,
        "Selected icon description",
        selectedText and selectedText.SelectedIconDescription, 57)
    RegisterPopupText(definition, ids.editBoxHeaderText,
        "Icon name header", borderBox.EditBoxHeaderText, 58)

    local selectedButton = selectedArea and selectedArea.SelectedIconButton
    local selectedIcon = selectedButton and selectedButton.Icon
    if selectedIcon then
        self:RegisterIcon({
            id = ids.selectedIcon or (ids.iconPrefix .. "Selected"),
            module = definition.module,
            appearanceWindowID = definition.appearanceWindowID,
            label = "Selected icon preview",
            window = root,
            target = selectedButton,
            texture = selectedIcon,
            nativeDecorationRegions = GetSelectorNativeDecorations(
                selectedButton, selectedIcon),
            hoverRegion = selectedButton.Highlight,
            getHovered = IsSelectorButtonHovered,
            priority = 60,
            isEditable = function()
                return IsVisible(root) and IsVisible(selectedButton)
            end,
        })
    end

    RegisterSelectorIcons(definition, state, selector)
    local scrollBar = definition.scrollBar or selector.ScrollBar
    if scrollBar then
        self:RegisterScrollBar({
            id = ids.scrollBar,
            module = definition.module,
            appearanceWindowID = definition.appearanceWindowID,
            label = definition.scrollBarLabel or "Icon selector scroll bar",
            window = root,
            target = scrollBar,
            priority = 80,
            highlightRegions = { scrollBar },
            isEditable = function()
                return IsVisible(root) and IsVisible(scrollBar)
            end,
        })
    end
    return true
end
