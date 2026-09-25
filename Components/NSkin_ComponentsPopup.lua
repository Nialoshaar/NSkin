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


local function CreateSelectionPopupLabel(parent, text)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetText(text or "")
    label:SetTextColor(1, 1, 1, 1)
    return label
end

local function CreateSelectionPopupButton(parent, text, width, callback)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 120, 22)
    NSkin:SkinFlatButton(button, text or "", nil, nil, 12)
    button:SetScript("OnClick", callback)
    return button
end

local function ResolveSelectionPopupItems(popup, columnIndex)
    local column = popup.definition.columns[columnIndex]
    if not column then return {} end
    local items = column.items
    if type(items) == "function" then
        local ok, resolved = pcall(
            items, popup.context, popup.selections, popup)
        items = ok and resolved or nil
    end
    return type(items) == "table" and items or {}
end

local function GetSelectionPopupItemLabel(column, item)
    if type(column.getLabel) == "function" then
        local ok, label = pcall(column.getLabel, item)
        if ok and label ~= nil then return tostring(label) end
    end
    if type(item) == "table" then
        return tostring(item.label or item.name or item.id or "")
    end
    return tostring(item or "")
end

local function GetSelectionPopupItemID(column, item)
    if type(column.getID) == "function" then
        local ok, id = pcall(column.getID, item)
        if ok then return id end
    end
    if type(item) == "table" then
        return item.id or item.value or item
    end
    return item
end

local function SelectionPopupItemsEqual(column, left, right)
    if left == right then return true end
    if left == nil or right == nil then return false end
    return GetSelectionPopupItemID(column, left)
        == GetSelectionPopupItemID(column, right)
end

function NSkin:RefreshSelectionPopupAppearance(popup)
    if not popup or not popup.definition then return false end
    self:SkinWindow(popup)
    self:SkinWindowHeader(popup)
    self:SkinText(popup.title)
    for _, column in ipairs(popup.columns or {}) do
        self:SkinText(column.header)
        for _, button in ipairs(column.buttons or {}) do
            if button:IsShown() then
                self:SkinFlatButton(
                    button, button.selectionLabel or "", nil, nil, 12)
            end
        end
    end
    self:SkinFlatButton(
        popup.confirmButton,
        popup.definition.confirmLabel or "Confirm", nil, nil, 12)
    self:SkinFlatButton(
        popup.cancelButton,
        popup.definition.cancelLabel or "Cancel", nil, nil, 12)
    return true
end

function NSkin:CreateSelectionPopup(definition)
    if type(definition) ~= "table"
        or type(definition.columns) ~= "table"
        or #definition.columns == 0
    then return nil end

    local width = tonumber(definition.width) or 520
    local height = tonumber(definition.height) or 360
    local padding = tonumber(definition.padding) or 12
    local columnGap = tonumber(definition.columnGap) or 36
    local rowHeight = tonumber(definition.rowHeight) or 25
    local frame = CreateFrame("Frame", nil, definition.parent or UIParent)
    frame:SetSize(width, height)
    frame:SetFrameStrata(definition.frameStrata or "FULLSCREEN_DIALOG")
    frame:SetFrameLevel(tonumber(definition.frameLevel) or 600)
    frame:SetClampedToScreen(true)
    -- The popup surface itself owns mouse input, not only its child buttons.
    -- This prevents Skinning Mode or other underlying UI from receiving hover
    -- while the cursor is over otherwise-empty popup background.
    frame:EnableMouse(definition.blockUnderlyingMouse ~= false)
    if frame.SetPropagateMouseMotion then
        frame:SetPropagateMouseMotion(
            definition.blockUnderlyingMouse == false)
    end
    if frame.SetPropagateMouseClicks then
        frame:SetPropagateMouseClicks(
            definition.blockUnderlyingMouse == false)
    end
    frame.definition = definition
    frame.context = nil
    frame.selections = {}
    frame.columns = {}

    frame.title = CreateSelectionPopupLabel(
        frame, definition.title or "Select")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -8)

    local columnCount = #definition.columns
    local usableWidth = width - padding * 2 - columnGap * (columnCount - 1)
    local columnWidth = math.floor(usableWidth / columnCount)
    for index, columnDefinition in ipairs(definition.columns) do
        local column = {
            definition = columnDefinition,
            buttons = {},
        }
        frame.columns[index] = column
        local x = padding + (index - 1) * (columnWidth + columnGap)
        column.x = x
        column.width = columnWidth
        column.header = CreateSelectionPopupLabel(
            frame, columnDefinition.label or ("Column " .. index))
        column.header:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -36)
    end

    function frame:Refresh()
        for columnIndex, column in ipairs(self.columns) do
            local columnDefinition = column.definition
            local items = ResolveSelectionPopupItems(self, columnIndex)
            local selected = self.selections[columnIndex]
            local selectedStillValid
            for _, item in ipairs(items) do
                if SelectionPopupItemsEqual(
                    columnDefinition, selected, item)
                then
                    selectedStillValid = item
                    break
                end
            end
            self.selections[columnIndex] = selectedStillValid

            for itemIndex, item in ipairs(items) do
                local button = column.buttons[itemIndex]
                if not button then
                    button = CreateSelectionPopupButton(
                        self, "", column.width, function(selfButton)
                            local owner = selfButton.selectionPopup
                            local indexValue =
                                selfButton.selectionColumnIndex
                            owner.selections[indexValue] =
                                selfButton.selectionItem
                            for later = indexValue + 1,
                                #owner.columns
                            do
                                owner.selections[later] = nil
                            end
                            if type(owner.definition.onSelectionChanged)
                                == "function"
                            then
                                owner.definition.onSelectionChanged(
                                    owner.context,
                                    owner.selections,
                                    indexValue,
                                    owner)
                            end
                            owner:Refresh()
                        end)
                    button.selectionPopup = self
                    button.selectionColumnIndex = columnIndex
                    column.buttons[itemIndex] = button
                end

                local label = GetSelectionPopupItemLabel(
                    columnDefinition, item)
                button.selectionItem = item
                button.selectionLabel = label
                NSkin:SkinFlatButton(button, label, nil, nil, 12)
                button:SetSize(column.width, 22)
                button:ClearAllPoints()
                button:SetPoint(
                    "TOPLEFT", self, "TOPLEFT",
                    column.x,
                    -58 - (itemIndex - 1) * rowHeight)
                local isSelected = SelectionPopupItemsEqual(
                    columnDefinition,
                    self.selections[columnIndex],
                    item)
                button:SetAlpha(isSelected and 1 or 0.72)
                local border = NSkin:GetPixelBorder(
                    button, "NSkinFlatButtonBorder")
                if border then
                    NSkin:SetPixelBorderColor(
                        border,
                        unpack(isSelected
                            and NSkin:GetAccentColor()
                            or NSkin:GetSharedBorderColor()))
                end
                button:Show()
            end
            for itemIndex = #items + 1, #column.buttons do
                column.buttons[itemIndex]:Hide()
            end
        end

        local enabled = true
        if type(self.definition.canConfirm) == "function" then
            local ok, result = pcall(
                self.definition.canConfirm,
                self.context, self.selections, self)
            enabled = ok and result == true
        else
            for index = 1, #self.columns do
                if self.selections[index] == nil then
                    enabled = false
                    break
                end
            end
        end
        self.confirmButton:SetEnabled(enabled)
        self.confirmButton:SetAlpha(enabled and 1 or 0.45)
        NSkin:RefreshSelectionPopupAppearance(self)
    end

    function frame:Open(context, initialSelections)
        self.context = context
        self.selections = {}
        for index, item in ipairs(initialSelections or {}) do
            self.selections[index] = item
        end
        self:ClearAllPoints()
        if type(definition.anchor) == "function" then
            definition.anchor(self, context)
        else
            self:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
        self:Refresh()
        self:Show()
    end

    function frame:Close()
        self:Hide()
        self.context = nil
        self.selections = {}
    end

    frame.cancelButton = CreateSelectionPopupButton(
        frame, definition.cancelLabel or "Cancel", 80, function()
            frame:Close()
            if type(definition.onCancel) == "function" then
                definition.onCancel(frame.context, frame)
            end
        end)
    frame.cancelButton:SetPoint(
        "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -padding, 10)

    frame.confirmButton = CreateSelectionPopupButton(
        frame, definition.confirmLabel or "Confirm", 112, function()
            if not frame.confirmButton:IsEnabled() then return end
            if type(definition.onConfirm) == "function" then
                local keepOpen = definition.onConfirm(
                    frame.context, frame.selections, frame)
                if keepOpen == true then
                    frame:Refresh()
                    return
                end
            end
            frame:Close()
        end)
    frame.confirmButton:SetPoint(
        "RIGHT", frame.cancelButton, "LEFT", -6, 0)

    self:RefreshSelectionPopupAppearance(frame)
    frame:Hide()
    return frame
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
