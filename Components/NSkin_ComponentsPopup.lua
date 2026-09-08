local _, NSkin = ...

local POPUP_COMPONENT_STATE = "iconSelectPopupComponent"
local SELECTOR_SLOT_TEXTURE = "interface/buttons/ui-emptyslot-disabled"
local selectorSlotFileID
local selectorSlotFileIDResolved = false

local function IsVisible(frame)
    return frame and frame.IsVisible and frame:IsVisible() or false
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
    if not scrollBox or not scrollBox.ForEachFrame then return false end
    local applied = false
    scrollBox:ForEachFrame(function(button)
        applied = RegisterSelectorIcon(
            definition, state, button, 70) ~= nil or applied
    end)
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
