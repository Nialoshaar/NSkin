local _, NSkin = ...

local optionGroups = {}
local viewsByGroup = {}
local DEFAULT_OPTIONS_WIDTH = 760
local DEFAULT_OPTIONS_HEIGHT = 560
local MIN_OPTIONS_WIDTH = 640
local MIN_OPTIONS_HEIGHT = 420
local COMPACT_OPTIONS_WIDTH = 502
local COMPACT_GRID_HEIGHT = 48
local COMPACT_GRID_PADDING = 8

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

local function SkinAddonDropdown(dropdown)
    if not dropdown then return end
    NSkin:HideTextureRegions(dropdown)
    for _, child in ipairs({ dropdown:GetChildren() }) do
        NSkin:HideTextureRegions(child)
    end
    NSkin:CreateFlatBackground(dropdown, "NSkinOptionsDropdown",
        NSkin:GetStyle("button").background, NSkin:GetSharedBorderColor())
    NSkin:SetPixelBorderSize(
        NSkin:GetPixelBorder(dropdown, "NSkinOptionsDropdownBorder"), 1)
    local arrow = dropdown:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
    arrow:SetTexture("Interface\\AddOns\\NSkin\\Media\\angle-small-down.png")
    dropdown.nskinArrow = arrow
    for _, region in ipairs({ dropdown:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            region:SetWordWrap(false)
            if region.SetNonSpaceWrap then region:SetNonSpaceWrap(true) end
            region:ClearAllPoints()
            region:SetPoint("LEFT", dropdown, "LEFT", 8, 0)
            region:SetPoint("RIGHT", dropdown, "RIGHT", -28, 0)
            region:SetHeight(math.max(1, dropdown:GetHeight() - 4))
            region:SetJustifyH("LEFT")
            region:SetJustifyV("MIDDLE")
        end
    end
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
    SkinAddonDropdown(dropdown)
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
    local valueLabel = CreateFrame("EditBox", nil, view)
    valueLabel:SetSize(58, 22)
    valueLabel:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, y + 4)
    valueLabel:SetAutoFocus(false)
    valueLabel:SetJustifyH("CENTER")
    valueLabel:SetFontObject(GameFontHighlightSmall)
    valueLabel:SetTextInsets(4, 4, 0, 0)
    NSkin:CreateFlatBackground(valueLabel, "NSkinSliderValue",
        NSkin:GetStyle("button").background, NSkin:GetSharedBorderColor())
    NSkin:SetPixelBorderSize(
        NSkin:GetPixelBorder(valueLabel, "NSkinSliderValueBorder"), 1)
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

local function CreateDropdownPairItem(view, control, x, width, y, mirrored)
    if not control then return end
    local labelWidth = tonumber(control.labelWidth) or 70
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint(mirrored and "RIGHT" or "LEFT", view, "TOPLEFT",
        mirrored and (x + width) or x, y)
    label:SetSize(math.max(1, labelWidth - 4), COMPACT_GRID_HEIGHT - 8)
    label:SetWordWrap(true)
    label:SetJustifyH(mirrored and "RIGHT" or "LEFT")
    label:SetJustifyV("MIDDLE")
    label:SetText(control.label)
    local dropdown = CreateFrame("DropdownButton", nil, view, "WowStyle1DropdownTemplate")
    local dropdownReduction = control.dropdownReduction
    if dropdownReduction == nil then
        dropdownReduction = view.presentation == "COMPACT" and 10 or 0
    end
    dropdown:SetSize(width - labelWidth - dropdownReduction,
        view.presentation == "COMPACT" and 26 or 24)
    SkinAddonDropdown(dropdown)
    if mirrored then
        dropdown:SetPoint("LEFT", view, "TOPLEFT", x + dropdownReduction, y)
    else
        dropdown:SetPoint("LEFT", view, "TOPLEFT", x + labelWidth, y)
    end
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

local function CreateTwoColumnGridRow(view, y, height, requestedGap)
    local gap = requestedGap == nil and 40 or (tonumber(requestedGap) or 0)
    local width = math.floor((view:GetWidth() - gap) / 2)
    local row = CreateFrame("Frame", nil, view)
    row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    row:SetSize(view:GetWidth(), height)
    row.left = CreateFrame("Frame", nil, row)
    row.left:SetPoint("TOPLEFT")
    row.left:SetSize(width, height)
    row.right = CreateFrame("Frame", nil, row)
    row.right:SetPoint("TOPLEFT", row, "TOPLEFT", width + gap, 0)
    row.right:SetSize(width, height)
    view.gridRows = view.gridRows or {}
    view.gridRows[#view.gridRows + 1] = row
    return width, gap, row
end

local function CreateDropdownReset(view, control, y)
    local labelWidth = tonumber(control.labelWidth) or 100
    local dropdownWidth = tonumber(control.dropdownWidth) or 101
    local width, gap
    if view.presentation == "COMPACT" then
        width, gap = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
    end
    CreateDropdownPairItem(view, control, COMPACT_GRID_PADDING,
        view.presentation == "COMPACT" and (width - COMPACT_GRID_PADDING * 2)
            or (labelWidth + dropdownWidth), y - 24)

    local reset = CreateFrame("Button", nil, view)
    reset:SetSize(24, 24)
    if view.presentation == "COMPACT" then
        reset:SetPoint("CENTER", view, "TOPLEFT", width + gap / 2, y - 24)
    else
        reset:SetPoint("LEFT", view, "TOPLEFT",
            COMPACT_GRID_PADDING + labelWidth + dropdownWidth + 6, y - 24)
    end
    local icon = reset:CreateTexture(nil, "ARTWORK")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER")
    icon:SetTexture(control.resetIcon)
    reset:SetScript("OnClick", function()
        if view.refreshing then return end
        ResetValues(view)
    end)
    reset:SetScript("OnEnter", function(self)
        icon:SetVertexColor(unpack(NSkin:GetAccentColor()))
        if control.resetTooltip and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(control.resetTooltip)
            GameTooltip:Show()
        end
    end)
    reset:SetScript("OnLeave", function()
        icon:SetVertexColor(1, 1, 1, 1)
        if GameTooltip then GameTooltip:Hide() end
    end)
    view.controls[#view.controls + 1] = reset
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateDropdownPair(view, control, y)
    local width, gap = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
    CreateDropdownPairItem(view, control.left, COMPACT_GRID_PADDING,
        width - COMPACT_GRID_PADDING * 2, y - 24)
    CreateDropdownPairItem(view, control.right, width + gap + COMPACT_GRID_PADDING,
        width - COMPACT_GRID_PADDING * 2, y - 24, true)
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateControlPairItem(view, control, x, width, y, mirrored)
    if not control then return end
    if control.type == "DROPDOWN" then
        CreateDropdownPairItem(view, control, x, width, y, mirrored)
    elseif control.type == "CHECKBOX" then
        local checkbox = CreateFrame("CheckButton", nil, view, "UICheckButtonTemplate")
        if mirrored then
            checkbox:SetPoint("TOPRIGHT", view, "TOPLEFT", x + width + 4, y + 5)
            if checkbox.Text then
                checkbox.Text:ClearAllPoints()
                checkbox.Text:SetPoint("RIGHT", checkbox, "LEFT", -2, 0)
                checkbox.Text:SetJustifyH("RIGHT")
            end
        else
            checkbox:SetPoint("TOPLEFT", view, "TOPLEFT", x - 4, y + 5)
        end
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
    local width, gap = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
    CreateControlPairItem(view, control.left, COMPACT_GRID_PADDING,
        width - COMPACT_GRID_PADDING * 2, y - 24)
    CreateControlPairItem(view, control.right, width + gap + COMPACT_GRID_PADDING,
        width - COMPACT_GRID_PADDING * 2, y - 24, true)
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateTypographyDropdown(view, control, key, values, width, x, y, inline, mirrored)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if inline then
        label:SetPoint(mirrored and "RIGHT" or "LEFT", view, "TOPLEFT",
            mirrored and (x + width) or x, y - COMPACT_GRID_HEIGHT / 2)
        label:SetSize(50, COMPACT_GRID_HEIGHT - 8)
        label:SetJustifyH(mirrored and "RIGHT" or "LEFT")
        label:SetJustifyV("MIDDLE")
    else
        label:SetPoint("TOPLEFT", view, "TOPLEFT", x, y)
    end
    label:SetText(control[key .. "Label"])
    local dropdown = CreateFrame("DropdownButton", nil, view, "WowStyle1DropdownTemplate")
    local labelWidth = inline and 54 or 0
    dropdown:SetSize(width - labelWidth
        - (view.presentation == "COMPACT" and 10 or 0),
        view.presentation == "COMPACT" and 26 or 24)
    SkinAddonDropdown(dropdown)
    if inline then
        dropdown:SetPoint("LEFT", view, "TOPLEFT",
            mirrored and (x + (view.presentation == "COMPACT" and 10 or 0))
                or (x + labelWidth), y - COMPACT_GRID_HEIGHT / 2)
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

local function CreateTypographySizeSlider(view, control, parent)
    local definition = { key = control.sizeKey, label = control.sizeLabel,
        min = control.sizeMin or 8, max = control.sizeMax or 32,
        step = control.sizeStep or 1, decimals = 0 }
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", parent, "LEFT", COMPACT_GRID_PADDING, 0)
    label:SetSize(56, COMPACT_GRID_HEIGHT - 8)
    label:SetWordWrap(true)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText(definition.label)
    local valueLabel = CreateFrame("EditBox", nil, parent)
    valueLabel:SetSize(38, 22)
    valueLabel:SetPoint("LEFT", parent, "LEFT", 70, 0)
    valueLabel:SetAutoFocus(false)
    valueLabel:SetJustifyH("CENTER")
    valueLabel:SetFontObject(GameFontHighlightSmall)
    valueLabel:SetTextInsets(1, 1, 0, 0)
    NSkin:CreateFlatBackground(valueLabel, "NSkinSliderValue",
        NSkin:GetStyle("button").background, NSkin:GetSharedBorderColor())
    NSkin:SetPixelBorderSize(
        NSkin:GetPixelBorder(valueLabel, "NSkinSliderValueBorder"), 1)
    valueLabel:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    local slider = NSkin:CreateOptionsSlider(parent, {
        width = parent:GetWidth() - 124, min = definition.min, max = definition.max,
        step = definition.step,
        onValueChanged = function(_, value)
            value = RoundValue(value, 0)
            valueLabel:SetText(string.format("%.0f", value))
            if view.refreshing or not view.context then return end
            local current = CopyTable(view.definition.get(view.context))
            current[definition.key] = value
            CommitValues(view, current)
        end,
    })
    slider:SetPoint("LEFT", parent, "LEFT", 116, 0)
    valueLabel:SetScript("OnEnterPressed", function(self)
        if not view.context then return end
        local value = math.max(definition.min, math.min(definition.max,
            tonumber(self:GetText()) or slider:GetValue()))
        value = RoundValue(value, 0)
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
    return { slider = slider, valueLabel = valueLabel, key = definition.key }
end

local function CreateTypography(view, control, y)
    local divider
    local rowY = y
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
    local width, gap = CreateTwoColumnGridRow(view, rowY, COMPACT_GRID_HEIGHT)
    local rowStep = COMPACT_GRID_HEIGHT - 1
    local _, _, secondRow = CreateTwoColumnGridRow(
        view, rowY - rowStep, COMPACT_GRID_HEIGHT)
    local font = CreateTypographyDropdown(view, control, "font", control.fontValues,
        width - COMPACT_GRID_PADDING * 2, COMPACT_GRID_PADDING, rowY, true)
    local outline = CreateTypographyDropdown(view, control, "outline",
        control.outlineValues, width - COMPACT_GRID_PADDING * 2,
        width + gap + COMPACT_GRID_PADDING, rowY, true, true)
    local size = CreateTypographySizeSlider(view, control, secondRow.left)
    if control.color then
        CreateColor(view, control.color, rowY - rowStep,
            { x = width + gap + COMPACT_GRID_PADDING,
                width = width - COMPACT_GRID_PADDING * 2, inline = true,
                mirrored = true })
    end
    local row = {
        controls = { font, outline }, size = size, divider = divider,
    }
    view.typographyRows[#view.typographyRows + 1] = row
    view.typographyByControl[control] = row
    return control.hideHeading and 94 or 118
end

CreateColor = function(view, control, y, layout)
    layout = layout or {}
    local x = tonumber(layout.x) or 0
    local width = tonumber(layout.width) or view:GetWidth()
    local inlineLabelWidth = layout.inline and 72 or 0
    local hasColorMode = type(control.modeKey) == "string"
    local label = view:CreateFontString(nil, "OVERLAY",
        layout.inline and "GameFontNormalSmall" or "GameFontNormal")
    if layout.inline then
        label:SetPoint(layout.mirrored and "RIGHT" or "LEFT", view, "TOPLEFT",
            layout.mirrored and (x + width) or x,
            y - COMPACT_GRID_HEIGHT / 2)
        label:SetSize(inlineLabelWidth, COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        label:SetJustifyH(layout.mirrored and "RIGHT" or "LEFT")
        label:SetJustifyV("MIDDLE")
    else
        label:SetPoint("TOPLEFT", view, "TOPLEFT", x, y - 6)
    end
    label:SetText(control.label)
    local classSwatch, accentSwatch
    if hasColorMode then
        classSwatch = CreateFrame("Button", nil, view)
        accentSwatch = CreateFrame("Button", nil, view)
        local modeWidth = view.presentation == "FULL" and 60 or 44
        classSwatch:SetSize(modeWidth, 24)
        accentSwatch:SetSize(modeWidth, 24)
        NSkin:SetFlatButtonLabel(classSwatch, "Class", 11)
        NSkin:SetFlatButtonLabel(accentSwatch, "Accent", 11)
        classSwatch:SetScript("OnClick", function()
            if not view.context then return end
            local values = CopyTable(view.definition.get(view.context))
            values[control.modeKey] = "CLASS"
            CommitValues(view, values)
        end)
        accentSwatch:SetScript("OnClick", function()
            if not view.context then return end
            local values = CopyTable(view.definition.get(view.context))
            values[control.modeKey] = "ACCENT"
            CommitValues(view, values)
        end)
    end

    local swatch = CreateFrame("Button", nil, view)
    local swatchWidth = view.presentation == "FULL" and 60 or 44
    swatch:SetSize(swatchWidth, 24)
    if accentSwatch then
        local groupWidth = swatchWidth * 3 + 8
        local groupLeft
        if layout.inline then
            local controlWidth = math.max(groupWidth, width - inlineLabelWidth)
            local controlLeft = layout.mirrored and x or (x + inlineLabelWidth)
            groupLeft = controlLeft + (controlWidth - groupWidth) / 2
        else
            groupLeft = x + width - groupWidth
        end
        if layout.mirrored then
            swatch:SetPoint("LEFT", view, "TOPLEFT", groupLeft,
                y - (layout.inline and COMPACT_GRID_HEIGHT / 2 or 12))
            accentSwatch:SetPoint("LEFT", swatch, "RIGHT", 4, 0)
            classSwatch:SetPoint("LEFT", accentSwatch, "RIGHT", 4, 0)
        else
            swatch:SetPoint("RIGHT", view, "TOPLEFT", groupLeft + groupWidth,
                y - (layout.inline and COMPACT_GRID_HEIGHT / 2 or 12))
            accentSwatch:SetPoint("RIGHT", swatch, "LEFT", -4, 0)
            classSwatch:SetPoint("RIGHT", accentSwatch, "LEFT", -4, 0)
        end
        NSkin:SetFlatButtonLabel(swatch, "Custom", 11)
    else
        if layout.inline then
            local controlWidth = math.max(swatchWidth, width - inlineLabelWidth)
            local controlLeft = layout.mirrored and x or (x + inlineLabelWidth)
            swatch:SetPoint("LEFT", view, "TOPLEFT",
                controlLeft + (controlWidth - swatchWidth) / 2,
                y - COMPACT_GRID_HEIGHT / 2)
        else
            swatch:SetPoint("RIGHT", view, "TOPLEFT", x + width, y - 12)
        end
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
    if classSwatch then view.controls[#view.controls + 1] = classSwatch end
    if accentSwatch then view.controls[#view.controls + 1] = accentSwatch end
    view.controls[#view.controls + 1] = swatch
    view.controlByKey[control.key] = swatch
    view.colorByKey[control.key] = swatch
    if accentSwatch then
        view.classColorByKey[control.key] = classSwatch
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
    local classSwatch = view.classColorByKey[control.key]
    if classSwatch then
        local _, class = UnitClass("player")
        local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        NSkin:CreateFlatBackground(classSwatch, "NSkinOptionClassColor",
            classColor and { classColor.r, classColor.g, classColor.b, 1 }
                or { 1, 1, 1, 1 }, NSkin:GetSharedBorderColor())
    end
    local mode = values[view.colorModeByKey[control.key]]
    local selectedColor = { 0, 1, 0, 1 }
    if classSwatch then
        NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(classSwatch,
            "NSkinOptionClassColorBorder"), unpack(mode == "CLASS"
                and selectedColor or NSkin:GetSharedBorderColor()))
    end
    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(accentSwatch,
        "NSkinOptionAccentColorBorder"), unpack(mode == "ACCENT"
            and selectedColor or NSkin:GetSharedBorderColor()))
    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(view.colorByKey[control.key],
        "NSkinOptionColorBorder"), unpack(mode ~= "ACCENT" and mode ~= "CLASS"
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
    local width, gap = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
    if control.left then
        CreateColor(view, control.left, y, { x = COMPACT_GRID_PADDING,
            width = width - COMPACT_GRID_PADDING * 2, inline = true })
    end
    if control.right then
        CreateColor(view, control.right, y,
            { x = width + gap + COMPACT_GRID_PADDING,
                width = width - COMPACT_GRID_PADDING * 2, inline = true,
                mirrored = true })
    end
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateSliderPairItem(view, definition, x, width, y, mirroredSide, cell)
    local parent = cell or view
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    if mirroredSide == "RIGHT" then
        label:SetPoint("RIGHT", parent, "RIGHT", -COMPACT_GRID_PADDING, 0)
        label:SetSize(56, COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
    elseif mirroredSide == "LEFT" then
        label:SetPoint("LEFT", parent, "LEFT", COMPACT_GRID_PADDING, 0)
        label:SetSize(56, COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
    else
        label:SetPoint("LEFT", view, "TOPLEFT", x, y)
        label:SetSize(64, COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
    end
    label:SetText(definition.label)
    local valueLabel = CreateFrame("EditBox", nil, parent)
    valueLabel:SetSize(38, 22)
    valueLabel:SetAutoFocus(false)
    valueLabel:SetJustifyH("CENTER")
    valueLabel:SetFontObject(GameFontHighlightSmall)
    valueLabel:SetTextInsets(1, 1, 0, 0)
    NSkin:CreateFlatBackground(valueLabel, "NSkinSliderValue",
        NSkin:GetStyle("button").background, NSkin:GetSharedBorderColor())
    NSkin:SetPixelBorderSize(
        NSkin:GetPixelBorder(valueLabel, "NSkinSliderValueBorder"), 1)
    valueLabel:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    view.valueLabels[#view.valueLabels + 1] = valueLabel
    local trackWidth = width - (mirroredSide and 124 or 118)
    local slider = NSkin:CreateOptionsSlider(parent, {
        width = trackWidth, min = definition.min, max = definition.max,
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
    if mirroredSide == "LEFT" then
        valueLabel:SetPoint("LEFT", parent, "LEFT", 70, 0)
        slider:SetPoint("LEFT", parent, "LEFT", 116, 0)
    elseif mirroredSide == "RIGHT" then
        slider:SetPoint("LEFT", parent, "LEFT", COMPACT_GRID_PADDING, 0)
        valueLabel:SetPoint("LEFT", parent, "LEFT", trackWidth + 16, 0)
    else
        valueLabel:SetPoint("RIGHT", view, "TOPLEFT", x + width, y)
        slider:SetPoint("LEFT", view, "TOPLEFT", x + 72, y)
    end
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
    if control.centerReset then
        local centerWidth = 40
        local width = math.floor((view:GetWidth() - centerWidth) / 2)
        local row = CreateFrame("Frame", nil, view)
        row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
        row:SetSize(view:GetWidth(), COMPACT_GRID_HEIGHT)
        local left = CreateFrame("Frame", nil, row)
        left:SetPoint("TOPLEFT")
        left:SetSize(width, COMPACT_GRID_HEIGHT)
        local center = CreateFrame("Frame", nil, row)
        center:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        center:SetSize(centerWidth, COMPACT_GRID_HEIGHT)
        local right = CreateFrame("Frame", nil, row)
        right:SetPoint("TOPLEFT", center, "TOPRIGHT", 0, 0)
        right:SetSize(width, COMPACT_GRID_HEIGHT)
        CreateSliderPairItem(view, control.left, 0, width, 0, "LEFT", left)
        CreateSliderPairItem(view, control.right, 0, width, 0, "RIGHT", right)

        local reset = CreateFrame("Button", nil, center)
        reset:SetSize(24, 24)
        reset:SetPoint("CENTER")
        local icon = reset:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\AddOns\\NSkin\\Media\\rotate-right.png")
        reset:SetScript("OnClick", function()
            if view.refreshing or not view.context then return end
            local values = CopyTable(view.definition.get(view.context))
            values[control.left.key] = 0
            values[control.right.key] = 0
            CommitValues(view, values)
        end)
        reset:SetScript("OnEnter", function(self)
            icon:SetVertexColor(unpack(NSkin:GetAccentColor()))
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(control.resetTooltip or "Reset offsets")
                GameTooltip:Show()
            end
        end)
        reset:SetScript("OnLeave", function()
            icon:SetVertexColor(1, 1, 1, 1)
            if GameTooltip then GameTooltip:Hide() end
        end)
        view.controls[#view.controls + 1] = reset
    else
        local width, gap, row = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
        if control.left then
            CreateSliderPairItem(view, control.left, 0, width, 0,
                "LEFT", row.left)
        end
        if control.right then
            CreateSliderPairItem(view, control.right, 0, width, 0,
                "RIGHT", row.right)
        end
    end
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateSliderDropdownPair(view, control, y)
    local width, gap, row = CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
    if control.left then
        CreateSliderPairItem(view, control.left, 0, width, 0, "LEFT", row.left)
    end
    if control.right then
        CreateDropdownPairItem(view, control.right,
            width + gap + COMPACT_GRID_PADDING,
            width - COMPACT_GRID_PADDING * 2,
            y - COMPACT_GRID_HEIGHT / 2, true)
    end
    return COMPACT_GRID_HEIGHT - 1
end

local function CreateReset(view, control, y)
    local button = CreateFrame("Button", nil, view)
    if view.presentation == "COMPACT" then
        CreateTwoColumnGridRow(view, y, COMPACT_GRID_HEIGHT)
        button:SetSize(24, 24)
        button:SetPoint("TOP", view, "TOP", 0, y - 12)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("CENTER")
        icon:SetTexture("Interface\\AddOns\\NSkin\\Media\\rotate-right.png")
        button:SetScript("OnEnter", function(self)
            icon:SetVertexColor(unpack(NSkin:GetAccentColor()))
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(control.label or "Reset")
                GameTooltip:Show()
            end
        end)
        button:SetScript("OnLeave", function()
            icon:SetVertexColor(1, 1, 1, 1)
            if GameTooltip then GameTooltip:Hide() end
        end)
    else
        button:SetSize(110, 24)
        button:SetPoint("TOP", view, "TOP", 0, y - 18)
        NSkin:SkinFlatButton(button, control.label or "Reset", nil, nil, 12)
    end
    button:SetScript("OnClick", function() ResetValues(view) end)
    view.controls[#view.controls + 1] = button
    view.resetButton = button
    view.resetControl = control
    return view.presentation == "COMPACT" and COMPACT_GRID_HEIGHT - 1 or 60
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
    view.classColorByKey = {}
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
            height = presentation == "COMPACT"
                and CreateDropdownPair(view, { left = control }, y)
                or CreateDropdown(view, control, y)
        elseif control.type == "DROPDOWN_RESET" then
            height = CreateDropdownReset(view, control, y)
        elseif control.type == "DROPDOWN_PAIR" then
            height = CreateDropdownPair(view, control, y)
        elseif control.type == "CONTROL_PAIR" then
            height = CreateControlPair(view, control, y)
        elseif control.type == "SLIDER" then
            height = presentation == "COMPACT"
                and CreateSliderPair(view, { left = control }, y)
                or CreateSlider(view, control, y)
        elseif control.type == "CHECKBOX" then
            height = presentation == "COMPACT"
                and CreateControlPair(view, {
                    left = { type = "CHECKBOX", key = control.key,
                        label = control.label },
                }, y) or CreateCheckbox(view, control, y)
        elseif control.type == "COLOR" then
            height = presentation == "COMPACT"
                and CreateColorPair(view, { left = control }, y)
                or CreateColor(view, control, y)
        elseif control.type == "TYPOGRAPHY" then
            height = CreateTypography(view, control, y)
        elseif control.type == "SECTION" then
            height = CreateSection(view, control, y)
        elseif control.type == "COLOR_PAIR" then
            height = CreateColorPair(view, control, y)
        elseif control.type == "SLIDER_PAIR" then
            height = CreateSliderPair(view, control, y)
        elseif control.type == "SLIDER_DROPDOWN_PAIR" then
            height = CreateSliderDropdownPair(view, control, y)
        elseif control.type == "RESET" then
            height = CreateReset(view, control, y)
        end
        y = y - (height or 0)
    end
    view:SetHeight(math.max(1, -y + (presentation == "COMPACT" and 1 or 0)))

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
            if control.type == "DROPDOWN" or control.type == "DROPDOWN_RESET" then
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
                local selectedSize = values and values[control.sizeKey]
                if selectedSize == "__NSKIN_GLOBAL__" then
                    selectedSize = NSkin:GetStyle("typography").size
                end
                selectedSize = tonumber(selectedSize)
                if selectedSize then
                    row.size.slider:SetValue(selectedSize)
                    row.size.valueLabel:SetText(string.format("%.0f", selectedSize))
                else
                    row.size.valueLabel:SetText("-")
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
            elseif control.type == "SLIDER_DROPDOWN_PAIR" then
                local sliderDefinition, dropdownDefinition = control.left, control.right
                local selected = values and values[sliderDefinition.key]
                if selected ~= nil then
                    self.controlByKey[sliderDefinition.key]:SetValue(selected)
                end
                local decimals = tonumber(sliderDefinition.decimals) or 0
                self.valueByKey[sliderDefinition.key]:SetText(selected ~= nil
                    and string.format("%." .. decimals .. "f", selected) or "-")
                local dropdownValue = values and values[dropdownDefinition.key]
                local text = dropdownDefinition.label
                for j = 1, #dropdownDefinition.values do
                    if dropdownDefinition.values[j].value == dropdownValue then
                        text = dropdownDefinition.values[j].label
                        break
                    end
                end
                local dropdown = self.controlByKey[dropdownDefinition.key]
                dropdown:SetDefaultText(text)
                if dropdown.GenerateMenu then dropdown:GenerateMenu() end
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
        for _, swatch in pairs(self.classColorByKey) do
            local _, class = UnitClass("player")
            local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            NSkin:CreateFlatBackground(swatch, "NSkinOptionClassColor",
                classColor and { classColor.r, classColor.g, classColor.b, 1 }
                    or { 1, 1, 1, 1 }, NSkin:GetSharedBorderColor())
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
                    local classSwatch = self.classColorByKey[key]
                    if classSwatch then
                        NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(classSwatch,
                            "NSkinOptionClassColorBorder"), unpack(mode == "CLASS"
                                and selectedColor or NSkin:GetSharedBorderColor()))
                    end
                    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(accentSwatch,
                        "NSkinOptionAccentColorBorder"), unpack(mode == "ACCENT"
                            and selectedColor or NSkin:GetSharedBorderColor()))
                    NSkin:SetPixelBorderColor(NSkin:GetPixelBorder(
                        swatch, "NSkinOptionColorBorder"), unpack(
                            mode ~= "ACCENT" and mode ~= "CLASS"
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
        if self.resetButton and self.presentation ~= "COMPACT" then
            NSkin:SkinFlatButton(self.resetButton,
                self.resetControl.label or "Reset", nil, nil, 12)
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
