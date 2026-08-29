local _, NSkin = ...

local optionGroups = {}
local viewsByGroup = {}
local DEFAULT_OPTIONS_WIDTH = 760
local DEFAULT_OPTIONS_HEIGHT = 560
local MIN_OPTIONS_WIDTH = 640
local MIN_OPTIONS_HEIGHT = 420
local COMPACT_OPTIONS_WIDTH = 432

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

function NSkin:GetOptionsWindowSize()
    local profile = self:GetProfile()
    local editor = profile.editor
    local width = editor and tonumber(editor.optionsWidth) or DEFAULT_OPTIONS_WIDTH
    local height = editor and tonumber(editor.optionsHeight) or DEFAULT_OPTIONS_HEIGHT
    local maximumWidth = math.max(MIN_OPTIONS_WIDTH, (UIParent:GetWidth() or 1920) - 40)
    local maximumHeight = math.max(MIN_OPTIONS_HEIGHT, (UIParent:GetHeight() or 1080) - 40)
    return Clamp(width, MIN_OPTIONS_WIDTH, maximumWidth),
        Clamp(height, MIN_OPTIONS_HEIGHT, maximumHeight),
        maximumWidth, maximumHeight
end

function NSkin:SetOptionsWindowSize(width, height)
    width, height = tonumber(width), tonumber(height)
    if not width or not height then return false end
    local _, _, maximumWidth, maximumHeight = self:GetOptionsWindowSize()
    width = math.floor(Clamp(width, MIN_OPTIONS_WIDTH, maximumWidth) + 0.5)
    height = math.floor(Clamp(height, MIN_OPTIONS_HEIGHT, maximumHeight) + 0.5)

    local profile = self:GetProfile()
    profile.editor = profile.editor or {}
    profile.editor.optionsWidth = width == DEFAULT_OPTIONS_WIDTH and nil or width
    profile.editor.optionsHeight = height == DEFAULT_OPTIONS_HEIGHT and nil or height
    if not next(profile.editor) then profile.editor = nil end
    return true
end


function NSkin:CreateOptionsPage(parent)
    if not parent then return nil end
    local page = CreateFrame("Frame", nil, parent)
    page:SetPoint("TOPLEFT")
    page:SetPoint("TOPRIGHT")
    page:SetHeight(1)
    page.sectionDividers = {}

    function page:SetContentHeight(height)
        height = math.max(1, math.ceil(tonumber(height) or 1))
        self.contentHeight = height
        self:SetHeight(height)
        if parent.activePage == self then parent:SetHeight(height) end
    end

    function page:ApplyStructureTheme()
        local color = NSkin:GetStyle("window").header.divider
        for i = 1, #self.sectionDividers do
            self.sectionDividers[i]:SetColorTexture(unpack(color))
        end
    end

    return page
end

function NSkin:CreateOptionsSection(page, title, offset)
    if not page or type(title) ~= "string" then return nil, offset end
    offset = math.max(0, tonumber(offset) or 0)
    local heading = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    heading:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -offset)
    heading:SetText(title)
    local divider = page:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -6)
    divider:SetPoint("RIGHT", page, "RIGHT", 0, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(unpack(self:GetStyle("window").header.divider))
    page.sectionDividers[#page.sectionDividers + 1] = divider
    return heading, offset + 30
end

local function RoundValue(value, decimals)
    local factor = 10 ^ decimals
    if value >= 0 then return math.floor(value * factor + 0.5) / factor end
    return math.ceil(value * factor - 0.5) / factor
end

local function CopyTable(source)
    local result = {}
    for key, value in pairs(source or {}) do result[key] = value end
    return result
end

local function SetViewEnabled(view, enabled)
    for i = 1, #view.controls do
        local control = view.controls[i]
        control:SetEnabled(enabled)
        control:SetAlpha(enabled and 1 or 0.35)
    end
    for i = 1, #view.valueLabels do
        view.valueLabels[i]:SetAlpha(enabled and 1 or 0.35)
    end
end

local function CommitValues(view, values)
    if not view.context or type(values) ~= "table" then return false end
    if view.definition.set(view.context, CopyTable(values)) == true then
        NSkin:NotifyOptionGroupChanged(view.id)
        return true
    end
    view:Refresh()
    return false
end

local function ResetValues(view)
    if not view.context then return false end
    if view.definition.reset(view.context) == true then
        NSkin:NotifyOptionGroupChanged(view.id)
        return true
    end
    view:Refresh()
    return false
end

local function CreateDropdown(view, control, y)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    label:SetText(control.label)

    local dropdown = CreateFrame("DropdownButton", nil, view, "WowStyle1DropdownTemplate")
    dropdown:SetSize(view.presentation == "FULL" and 220 or 202, 24)
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    dropdown:SetDefaultText(control.label)
    dropdown:SetupMenu(function(_, rootDescription)
        for i = 1, #control.values do
            local choice = control.values[i]
            if choice.divider then
                if rootDescription.CreateDivider then rootDescription:CreateDivider() end
            elseif choice.title then
                if rootDescription.CreateTitle then rootDescription:CreateTitle(choice.title) end
            else
            local description = rootDescription:CreateRadio(
                choice.label,
                function(value)
                    if not view.context then return false end
                    local current = view.definition.get(view.context)
                    return current and current[control.key] == value
                end,
                function(value)
                    if not view.context then return end
                    local current = CopyTable(view.definition.get(view.context))
                    current[control.key] = value
                    CommitValues(view, current)
                end,
                choice.value
            )
            if type(choice.isEnabled) == "function"
                and description and description.SetEnabled
            then
                description:SetEnabled(choice.isEnabled(view.context) == true)
            end
            end
        end
    end)
    view.controls[#view.controls + 1] = dropdown
    view.controlByKey[control.key] = dropdown
    return 64
end

local function CreateSlider(view, control, y)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    label:SetText(control.label)
    local valueLabel = CreateFrame("EditBox", nil, view, "InputBoxTemplate")
    valueLabel:SetSize(58, 22)
    valueLabel:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, y + 4)
    valueLabel:SetAutoFocus(false)
    valueLabel:SetJustifyH("CENTER")
    valueLabel:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    view.valueLabels[#view.valueLabels + 1] = valueLabel

    local slider = NSkin:CreateOptionsSlider(view, {
        width = view.presentation == "FULL" and 280 or 202,
        min = control.min,
        max = control.max,
        step = control.step,
        onValueChanged = function(_, value)
            local decimals = tonumber(control.decimals) or 0
            value = RoundValue(value, decimals)
            valueLabel:SetText(string.format("%." .. decimals .. "f", value))
            if view.refreshing or not view.context then return end
            local current = CopyTable(view.definition.get(view.context))
            current[control.key] = value
            CommitValues(view, current)
        end,
    })
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 8, -18)
    valueLabel:SetScript("OnEnterPressed", function(self)
        if not view.context then return end
        local value = math.max(control.min, math.min(control.max,
            tonumber(self:GetText()) or slider:GetValue()))
        value = RoundValue(value, tonumber(control.decimals) or 0)
        local current = CopyTable(view.definition.get(view.context))
        current[control.key] = value
        CommitValues(view, current)
        self:ClearFocus()
    end)
    valueLabel:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        view:Refresh()
    end)
    view.controls[#view.controls + 1] = slider
    view.controls[#view.controls + 1] = valueLabel
    view.controlByKey[control.key] = slider
    view.valueByKey[control.key] = valueLabel
    return 70
end

local function CreateCheckbox(view, control, y)
    local checkbox = CreateFrame("CheckButton", nil, view, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", view, "TOPLEFT", -4, y)
    if checkbox.Text then checkbox.Text:SetText(control.label) end
    checkbox:SetScript("OnClick", function(self)
        if view.refreshing or not view.context then return end
        local current = CopyTable(view.definition.get(view.context))
        current[control.key] = self:GetChecked() == true
        CommitValues(view, current)
    end)
    view.controls[#view.controls + 1] = checkbox
    view.controlByKey[control.key] = checkbox
    return 42
end

local function CreateDropdownPairItem(view, control, x, width, y)
    if not control then return end
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", view, "TOPLEFT", x, y)
    label:SetText(control.label)
    local dropdown = CreateFrame("DropdownButton", nil, view, "WowStyle1DropdownTemplate")
    dropdown:SetSize(width - 70, 24)
    dropdown:SetPoint("LEFT", view, "TOPLEFT", x + 70, y - 6)
    dropdown:SetDefaultText(control.label)
    dropdown:SetupMenu(function(_, rootDescription)
        for i = 1, #control.values do
            local choice = control.values[i]
            if choice.divider then
                if rootDescription.CreateDivider then rootDescription:CreateDivider() end
            else
                local description = rootDescription:CreateRadio(choice.label,
                    function(value)
                        local current = view.context and view.definition.get(view.context)
                        return current and current[control.key] == value
                    end,
                    function(value)
                        if not view.context then return end
                        local current = CopyTable(view.definition.get(view.context))
                        current[control.key] = value
                        CommitValues(view, current)
                    end, choice.value)
                if type(choice.isEnabled) == "function"
                    and description and description.SetEnabled
                then
                    description:SetEnabled(choice.isEnabled(view.context) == true)
                end
            end
        end
    end)
    view.controls[#view.controls + 1] = dropdown
    view.controlByKey[control.key] = dropdown
end

local function CreateDropdownPair(view, control, y)
    local gap = 12
    local width = (view:GetWidth() - gap) / 2
    CreateDropdownPairItem(view, control.left, 0, width, y)
    CreateDropdownPairItem(view, control.right, width + gap, width, y)
    return 38
end

local function CreateControlPairItem(view, control, x, width, y)
    if not control then return end
    if control.type == "DROPDOWN" then
        CreateDropdownPairItem(view, control, x, width, y)
    elseif control.type == "CHECKBOX" then
        local checkbox = CreateFrame("CheckButton", nil, view, "UICheckButtonTemplate")
        checkbox:SetPoint("TOPLEFT", view, "TOPLEFT", x - 4, y + 5)
        if checkbox.Text then checkbox.Text:SetText(control.label) end
        checkbox:SetScript("OnClick", function(self)
            if view.refreshing or not view.context then return end
            local current = CopyTable(view.definition.get(view.context))
            current[control.key] = self:GetChecked() == true
            CommitValues(view, current)
        end)
        view.controls[#view.controls + 1] = checkbox
        view.controlByKey[control.key] = checkbox
    end
end

local function CreateControlPair(view, control, y)
    local gap = 12
    local width = (view:GetWidth() - gap) / 2
    CreateControlPairItem(view, control.left, 0, width, y)
    CreateControlPairItem(view, control.right, width + gap, width, y)
    return 38
end

local function CreateTypographyDropdown(view, control, key, values, width, x, y, inline)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", view, "TOPLEFT", x, y)
    label:SetText(control[key .. "Label"])
    local dropdown = CreateFrame("DropdownButton", nil, view, "WowStyle1DropdownTemplate")
    local labelWidth = inline and 54 or 0
    dropdown:SetSize(width - labelWidth, 24)
    if inline then
        dropdown:SetPoint("LEFT", view, "TOPLEFT", x + labelWidth, y - 6)
    else
        dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    end
    dropdown:SetDefaultText(control[key .. "Label"])
    dropdown:SetupMenu(function(_, rootDescription)
        for i = 1, #values do
            local choice = values[i]
            if choice.divider then
                if rootDescription.CreateDivider then rootDescription:CreateDivider() end
            elseif choice.title then
                if rootDescription.CreateTitle then rootDescription:CreateTitle(choice.title) end
            else
                rootDescription:CreateRadio(choice.label,
                    function(value)
                        if not view.context then return false end
                        local current = view.definition.get(view.context)
                        return current and current[control[key .. "Key"]] == value
                    end,
                    function(value)
                        if not view.context then return end
                        local current = CopyTable(view.definition.get(view.context))
                        current[control[key .. "Key"]] = value
                        CommitValues(view, current)
                    end,
                    choice.value)
            end
        end
    end)
    view.controls[#view.controls + 1] = dropdown
    return { dropdown = dropdown, key = control[key .. "Key"], values = values,
        defaultLabel = control[key .. "Label"] }
end

local CreateColor

local function CreateTypography(view, control, y)
    local divider
    local rowY = y - 8
    if not control.hideHeading then
        local heading = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
        heading:SetText(control.label)
        divider = view:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
        divider:SetPoint("RIGHT", view, "RIGHT", 0, 0)
        divider:SetHeight(1)
        divider:SetColorTexture(unpack(NSkin:GetStyle("window").header.divider))
        rowY = y - 24
    end
    local gap = 12
    local width = math.floor((view:GetWidth() - gap) / 2)
    local font = CreateTypographyDropdown(view, control, "font", control.fontValues,
        width, 0, rowY, true)
    local outline = CreateTypographyDropdown(view, control, "outline",
        control.outlineValues, width, width + gap, rowY, true)
    local size = CreateTypographyDropdown(view, control, "size", control.sizeValues,
        width, 0, rowY - 34, true)
    if control.color then
        CreateColor(view, control.color, rowY - 34,
            { x = width + gap, width = width, inline = true })
    end
    local row = {
        controls = { size, font, outline }, divider = divider,
    }
    view.typographyRows[#view.typographyRows + 1] = row
    view.typographyByControl[control] = row
    return control.hideHeading and 80 or 96
end

CreateColor = function(view, control, y, layout)
    layout = layout or {}
    local x = tonumber(layout.x) or 0
    local width = tonumber(layout.width) or view:GetWidth()
    local hasColorMode = type(control.modeKey) == "string"
    local label = view:CreateFontString(nil, "OVERLAY",
        layout.inline and "GameFontNormalSmall" or "GameFontNormal")
    label:SetPoint("TOPLEFT", view, "TOPLEFT", x, layout.inline and y or y - 6)
    label:SetText(control.label)
    local accentSwatch
    if hasColorMode then
        accentSwatch = CreateFrame("Button", nil, view)
        accentSwatch:SetSize(view.presentation == "FULL" and 72 or 58, 24)
        NSkin:SetFlatButtonLabel(accentSwatch, "Accent", 11)
        accentSwatch:SetScript("OnClick", function()
            if not view.context then return end
            local values = CopyTable(view.definition.get(view.context))
            values[control.modeKey] = "ACCENT"
            CommitValues(view, values)
        end)
    end

    local swatch = CreateFrame("Button", nil, view)
    local swatchWidth = view.presentation == "FULL" and 72 or 58
    swatch:SetSize(swatchWidth, 24)
    if accentSwatch then
        swatch:SetPoint("TOPLEFT", view, "TOPLEFT", x + width - swatchWidth, y)
        accentSwatch:SetPoint("RIGHT", swatch, "LEFT", -6, 0)
        NSkin:SetFlatButtonLabel(swatch, "Custom", 11)
    else
        swatch:SetPoint("TOPLEFT", view, "TOPLEFT", x + width - swatchWidth, y)
    end
    swatch:SetScript("OnClick", function()
        if not view.context then return end
        local current = view.definition.get(view.context)
        local previous = current and current[control.key]
        local previousMode = hasColorMode and current and current[control.modeKey]
        if type(previous) ~= "table" then return end
        previous = { previous[1], previous[2], previous[3], previous[4] or 1 }

        local function ApplyPickerColor(color)
            if not view.context then return end
            local red, green, blue = ColorPickerFrame:GetColorRGB()
            local values = CopyTable(view.definition.get(view.context))
            values[control.key] = color or { red, green, blue, previous[4] }
            if hasColorMode then
                values[control.modeKey] = color and previousMode or "CUSTOM"
            end
            CommitValues(view, values)
        end
        ColorPickerFrame:SetupColorPickerAndShow({
            r = previous[1],
            g = previous[2],
            b = previous[3],
            swatchFunc = ApplyPickerColor,
            cancelFunc = function() ApplyPickerColor(previous) end,
        })
    end)
    if accentSwatch then view.controls[#view.controls + 1] = accentSwatch end
    view.controls[#view.controls + 1] = swatch
    view.controlByKey[control.key] = swatch
    view.colorByKey[control.key] = swatch
    if accentSwatch then
        view.accentColorByKey[control.key] = accentSwatch
        view.colorModeByKey[control.key] = control.modeKey
    end
    return 38
end

local function RefreshColorControl(view, control, values)
    local value = values and values[control.key]
    if type(value) ~= "table" then return end
    NSkin:CreateFlatBackground(view.colorByKey[control.key], "NSkinOptionColor",
        value, NSkin:GetSharedBorderColor())
    local accentSwatch = view.accentColorByKey[control.key]
    if not accentSwatch then return end
    NSkin:CreateFlatBackground(accentSwatch, "NSkinOptionAccentColor",
        NSkin:GetAccentColor(), NSkin:GetSharedBorderColor())
    local mode = values[view.colorModeByKey[control.key]]
    local selectedColor = { 0, 1, 0, 1 }
    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(accentSwatch,
        "NSkinOptionAccentColorBorder"), unpack(mode == "ACCENT"
            and selectedColor or NSkin:GetSharedBorderColor()))
    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(view.colorByKey[control.key],
        "NSkinOptionColorBorder"), unpack(mode ~= "ACCENT"
            and selectedColor or NSkin:GetSharedBorderColor()))
end

local function CreateSection(view, control, y)
    local heading = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    heading:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    heading:SetText(control.label)
    local divider = view:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -5)
    divider:SetPoint("RIGHT", view, "RIGHT", 0, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(unpack(NSkin:GetStyle("window").header.divider))
    view.sectionDividers[#view.sectionDividers + 1] = divider
    return 30
end

local function CreateColorPair(view, control, y)
    local gap = 8
    local width = (view:GetWidth() - gap) / 2
    CreateColor(view, control.left, y, { x = 0, width = width })
    CreateColor(view, control.right, y, { x = width + gap, width = width })
    return 38
end

local function CreateSliderPairItem(view, definition, x, width, y)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", view, "TOPLEFT", x, y)
    label:SetText(definition.label)
    local valueLabel = CreateFrame("EditBox", nil, view, "InputBoxTemplate")
    valueLabel:SetSize(48, 22)
    valueLabel:SetPoint("TOPRIGHT", view, "TOPLEFT", x + width, y + 4)
    valueLabel:SetAutoFocus(false)
    valueLabel:SetJustifyH("CENTER")
    valueLabel:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    view.valueLabels[#view.valueLabels + 1] = valueLabel
    local slider = NSkin:CreateOptionsSlider(view, {
        width = width - 116, min = definition.min, max = definition.max,
        step = definition.step,
        onValueChanged = function(_, value)
            local decimals = tonumber(definition.decimals) or 0
            value = RoundValue(value, decimals)
            valueLabel:SetText(string.format("%." .. decimals .. "f", value))
            if view.refreshing or not view.context then return end
            local current = CopyTable(view.definition.get(view.context))
            current[definition.key] = value
            CommitValues(view, current)
        end,
    })
    slider:SetPoint("TOPLEFT", view, "TOPLEFT", x + 58, y + 4)
    valueLabel:SetScript("OnEnterPressed", function(self)
        if not view.context then return end
        local value = math.max(definition.min, math.min(definition.max,
            tonumber(self:GetText()) or slider:GetValue()))
        value = RoundValue(value, tonumber(definition.decimals) or 0)
        local current = CopyTable(view.definition.get(view.context))
        current[definition.key] = value
        CommitValues(view, current)
        self:ClearFocus()
    end)
    valueLabel:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        view:Refresh()
    end)
    view.controls[#view.controls + 1] = slider
    view.controls[#view.controls + 1] = valueLabel
    view.controlByKey[definition.key] = slider
    view.valueByKey[definition.key] = valueLabel
end

local function CreateSliderPair(view, control, y)
    local gap = 12
    local width = (view:GetWidth() - gap) / 2
    CreateSliderPairItem(view, control.left, 0, width, y)
    CreateSliderPairItem(view, control.right, width + gap, width, y)
    return 38
end

local function CreateReset(view, control, y)
    local button = CreateFrame("Button", nil, view)
    button:SetSize(view.presentation == "FULL" and 110 or 58, 24)
    button:SetPoint("TOP", view, "TOP", 0, y - 18)
    local label = view.presentation == "COMPACT" and control.compactLabel or control.label
    NSkin:SkinFlatButton(button, label or "Reset", nil, nil, 12)
    button:SetScript("OnClick", function() ResetValues(view) end)
    view.controls[#view.controls + 1] = button
    view.resetButton = button
    view.resetControl = control
    return 60
end

local function GetOrderedControls(definition)
    local controls = {}
    for i = 1, #definition.controls do
        local control = definition.controls[i]
        controls[i] = { definition = control, index = i }
    end
    table.sort(controls, function(a, b)
        local aOrder = a.definition.order
            or (a.definition.type == "RESET" and 100000 or a.index)
        local bOrder = b.definition.order
            or (b.definition.type == "RESET" and 100000 or b.index)
        if aOrder == bOrder then return a.index < b.index end
        return aOrder < bOrder
    end)
    return controls
end

function NSkin:RegisterOptionGroup(id, definition)
    if type(id) ~= "string" or id == ""
        or type(definition) ~= "table"
        or type(definition.controls) ~= "table"
        or type(definition.get) ~= "function"
        or type(definition.set) ~= "function"
        or type(definition.reset) ~= "function"
        or optionGroups[id]
    then
        return false
    end
    definition.orderedControls = GetOrderedControls(definition)
    optionGroups[id] = definition
    viewsByGroup[id] = setmetatable({}, { __mode = "k" })
    return true
end

function NSkin:RegisterOptionGroupSubset(id, sourceID, controls)
    local source = optionGroups[sourceID]
    if not source or type(controls) ~= "table" then return false end
    local keys = {}
    local function CollectKeys(control)
        if not control then return end
        for _, field in ipairs({ "key", "modeKey", "fontKey", "sizeKey", "outlineKey" }) do
            if type(control[field]) == "string" then keys[control[field]] = true end
        end
        CollectKeys(control.color)
        CollectKeys(control.left)
        CollectKeys(control.right)
    end
    local subsetControls = {}
    for i = 1, #controls do
        local control = controls[i]
        CollectKeys(control)
        if control.type == "TYPOGRAPHY" then
            local copy = {}
            for key, value in pairs(control) do copy[key] = value end
            copy.hideHeading = true
            control = copy
        end
        subsetControls[#subsetControls + 1] = control
    end
    return self:RegisterOptionGroup(id, {
        controls = subsetControls,
        get = source.get,
        set = function(context, values)
            local filtered = {}
            for key in pairs(keys) do filtered[key] = values[key] end
            return source.set(context, filtered)
        end,
        reset = source.reset,
    })
end

function NSkin:CreateOptionGroupView(parent, id, layout, context)
    local definition = optionGroups[id]
    local presentation = layout == "COMPACT" and "COMPACT" or "FULL"
    if not parent or not definition then return nil end

    local view = CreateFrame("Frame", nil, parent)
    view:SetWidth(presentation == "FULL" and 400 or COMPACT_OPTIONS_WIDTH)
    view.id = id
    view.definition = definition
    view.presentation = presentation
    view.context = context
    view.controls = {}
    view.valueLabels = {}
    view.controlByKey = {}
    view.valueByKey = {}
    view.colorByKey = {}
    view.accentColorByKey = {}
    view.colorModeByKey = {}
    view.typographyRows = {}
    view.typographyByControl = {}
    view.sectionDividers = {}

    local y = 0
    for i = 1, #definition.orderedControls do
        local control = definition.orderedControls[i].definition
        local height
        if control.type == "DROPDOWN" then
            height = CreateDropdown(view, control, y)
        elseif control.type == "DROPDOWN_PAIR" then
            height = CreateDropdownPair(view, control, y)
        elseif control.type == "CONTROL_PAIR" then
            height = CreateControlPair(view, control, y)
        elseif control.type == "SLIDER" then
            height = CreateSlider(view, control, y)
        elseif control.type == "CHECKBOX" then
            height = CreateCheckbox(view, control, y)
        elseif control.type == "COLOR" then
            height = CreateColor(view, control, y)
        elseif control.type == "TYPOGRAPHY" then
            height = CreateTypography(view, control, y)
        elseif control.type == "SECTION" then
            height = CreateSection(view, control, y)
        elseif control.type == "COLOR_PAIR" then
            height = CreateColorPair(view, control, y)
        elseif control.type == "SLIDER_PAIR" then
            height = CreateSliderPair(view, control, y)
        elseif control.type == "RESET" then
            height = CreateReset(view, control, y)
        end
        y = y - (height or 0)
    end
    view:SetHeight(math.max(1, -y))

    function view:SetContext(newContext)
        self.context = newContext
        self:Refresh()
    end

    function view:SetValues(values)
        return CommitValues(self, values)
    end

    function view:Refresh()
        local enabled = self.context ~= nil
        local values = enabled and self.definition.get(self.context) or nil
        self.refreshing = true
        for i = 1, #self.definition.orderedControls do
            local control = self.definition.orderedControls[i].definition
            local value = values and values[control.key]
            if control.type == "DROPDOWN" then
                local dropdown = self.controlByKey[control.key]
                local text = control.label
                for j = 1, #control.values do
                    if control.values[j].value == value then text = control.values[j].label break end
                end
                dropdown:SetDefaultText(text)
                if dropdown.GenerateMenu then dropdown:GenerateMenu() end
            elseif control.type == "DROPDOWN_PAIR" then
                for _, definition in ipairs({ control.left, control.right }) do
                    if definition then
                        local selected = values and values[definition.key]
                        local text = definition.label
                        for j = 1, #definition.values do
                            if definition.values[j].value == selected then
                                text = definition.values[j].label
                                break
                            end
                        end
                        local dropdown = self.controlByKey[definition.key]
                        dropdown:SetDefaultText(text)
                        if dropdown.GenerateMenu then dropdown:GenerateMenu() end
                    end
                end
            elseif control.type == "CONTROL_PAIR" then
                for _, definition in ipairs({ control.left, control.right }) do
                    if definition then
                        local widget = self.controlByKey[definition.key]
                        if definition.type == "CHECKBOX" then
                            widget:SetChecked(values and values[definition.key] == true)
                        elseif definition.type == "DROPDOWN" then
                            local selected = values and values[definition.key]
                            local text = definition.label
                            for j = 1, #definition.values do
                                if definition.values[j].value == selected then
                                    text = definition.values[j].label
                                    break
                                end
                            end
                            widget:SetDefaultText(text)
                            if widget.GenerateMenu then widget:GenerateMenu() end
                        end
                    end
                end
            elseif control.type == "SLIDER" then
                if value ~= nil then self.controlByKey[control.key]:SetValue(value) end
                local decimals = tonumber(control.decimals) or 0
                self.valueByKey[control.key]:SetText(
                    value ~= nil and string.format("%." .. decimals .. "f", value) or "-"
                )
            elseif control.type == "CHECKBOX" then
                self.controlByKey[control.key]:SetChecked(value == true)
            elseif control.type == "COLOR" and type(value) == "table" then
                RefreshColorControl(self, control, values)
            elseif control.type == "COLOR_PAIR" then
                RefreshColorControl(self, control.left, values)
                RefreshColorControl(self, control.right, values)
            elseif control.type == "TYPOGRAPHY" then
                local row = self.typographyByControl[control]
                for j = 1, #row.controls do
                    local item = row.controls[j]
                    local selected = values and values[item.key]
                    local text = item.defaultLabel
                    for k = 1, #item.values do
                        if item.values[k].value == selected then
                            text = item.values[k].label
                            break
                        end
                    end
                    item.dropdown:SetDefaultText(text)
                    if item.dropdown.GenerateMenu then item.dropdown:GenerateMenu() end
                end
                if control.color then
                    RefreshColorControl(self, control.color, values)
                end
            elseif control.type == "SLIDER_PAIR" then
                for _, definition in ipairs({ control.left, control.right }) do
                    local selected = values and values[definition.key]
                    if selected ~= nil then
                        self.controlByKey[definition.key]:SetValue(selected)
                    end
                    local decimals = tonumber(definition.decimals) or 0
                    self.valueByKey[definition.key]:SetText(selected ~= nil
                        and string.format("%." .. decimals .. "f", selected) or "-")
                end
            end
        end
        self.refreshing = false
        SetViewEnabled(self, enabled)
    end

    function view:ApplyTheme()
        local values = self.context and self.definition.get(self.context)
        for _, swatch in pairs(self.accentColorByKey) do
            NSkin:CreateFlatBackground(
                swatch, "NSkinOptionAccentColor", NSkin:GetAccentColor(),
                NSkin:GetSharedBorderColor()
            )
        end
        for key, swatch in pairs(self.colorByKey) do
            local color = values and values[key]
            if type(color) == "table" then
                NSkin:CreateFlatBackground(
                    swatch, "NSkinOptionColor", color, NSkin:GetSharedBorderColor()
                )
                local accentSwatch = self.accentColorByKey[key]
                if accentSwatch then
                    local mode = values[self.colorModeByKey[key]]
                    local selectedColor = { 0, 1, 0, 1 }
                    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(accentSwatch,
                        "NSkinOptionAccentColorBorder"), unpack(mode == "ACCENT"
                            and selectedColor or NSkin:GetSharedBorderColor()))
                    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(
                        swatch, "NSkinOptionColorBorder"), unpack(mode ~= "ACCENT"
                            and selectedColor or NSkin:GetSharedBorderColor()))
                end
            end
        end
        local dividerColor = NSkin:GetStyle("window").header.divider
        for i = 1, #self.typographyRows do
            local divider = self.typographyRows[i].divider
            if divider then divider:SetColorTexture(unpack(dividerColor)) end
        end
        for i = 1, #self.sectionDividers do
            self.sectionDividers[i]:SetColorTexture(unpack(dividerColor))
        end
        if self.resetButton then
            local label = self.presentation == "COMPACT"
                and self.resetControl.compactLabel or self.resetControl.label
            NSkin:SkinFlatButton(self.resetButton, label or "Reset", nil, nil, 12)
        end
    end

    viewsByGroup[id][view] = true
    view:Refresh()
    return view
end

function NSkin:NotifyOptionGroupChanged(id)
    local views = viewsByGroup[id]
    if not views then return false end
    for view in pairs(views) do
        if view.Refresh then view:Refresh() end
    end
    return true
end
