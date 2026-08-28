local _, NSkin = ...

local optionGroups = {}
local viewsByGroup = {}
local DEFAULT_OPTIONS_WIDTH = 760
local DEFAULT_OPTIONS_HEIGHT = 560
local MIN_OPTIONS_WIDTH = 640
local MIN_OPTIONS_HEIGHT = 420

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
    end)
    view.controls[#view.controls + 1] = dropdown
    view.controlByKey[control.key] = dropdown
    return 64
end

local function CreateSlider(view, control, y)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    label:SetText(control.label)
    local valueLabel = view:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueLabel:SetPoint("TOPRIGHT", view, "TOPRIGHT", 0, y)
    view.valueLabels[#view.valueLabels + 1] = valueLabel

    local slider = NSkin:CreateOptionsSlider(view, {
        width = view.presentation == "FULL" and 280 or 202,
        min = control.min,
        max = control.max,
        step = control.step,
        onValueChanged = function(_, value)
            local decimals = tonumber(control.decimals) or 0
            value = RoundValue(value, decimals)
            valueLabel:SetText(string.format("%." .. decimals .. "f", value)
                .. (control.suffix or ""))
            if view.refreshing or not view.context then return end
            local current = CopyTable(view.definition.get(view.context))
            current[control.key] = value
            CommitValues(view, current)
        end,
    })
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 8, -18)
    view.controls[#view.controls + 1] = slider
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

local function CreateColor(view, control, y)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    label:SetText(control.label)
    local swatch = CreateFrame("Button", nil, view)
    swatch:SetSize(view.presentation == "FULL" and 72 or 58, 24)
    swatch:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    swatch:SetScript("OnClick", function()
        if not view.context then return end
        local current = view.definition.get(view.context)
        local previous = current and current[control.key]
        if type(previous) ~= "table" then return end
        previous = { previous[1], previous[2], previous[3], previous[4] or 1 }

        local function ApplyPickerColor(color)
            if not view.context then return end
            local red, green, blue = ColorPickerFrame:GetColorRGB()
            local values = CopyTable(view.definition.get(view.context))
            values[control.key] = color or { red, green, blue, previous[4] }
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
    view.controls[#view.controls + 1] = swatch
    view.controlByKey[control.key] = swatch
    view.colorByKey[control.key] = swatch
    return 58
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

function NSkin:CreateOptionGroupView(parent, id, layout, context)
    local definition = optionGroups[id]
    local presentation = layout == "COMPACT" and "COMPACT" or "FULL"
    if not parent or not definition then return nil end

    local view = CreateFrame("Frame", nil, parent)
    view:SetWidth(presentation == "FULL" and 400 or 202)
    view.id = id
    view.definition = definition
    view.presentation = presentation
    view.context = context
    view.controls = {}
    view.valueLabels = {}
    view.controlByKey = {}
    view.valueByKey = {}
    view.colorByKey = {}

    local y = 0
    for i = 1, #definition.orderedControls do
        local control = definition.orderedControls[i].definition
        local height
        if control.type == "DROPDOWN" then
            height = CreateDropdown(view, control, y)
        elseif control.type == "SLIDER" then
            height = CreateSlider(view, control, y)
        elseif control.type == "CHECKBOX" then
            height = CreateCheckbox(view, control, y)
        elseif control.type == "COLOR" then
            height = CreateColor(view, control, y)
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
            elseif control.type == "SLIDER" then
                if value ~= nil then self.controlByKey[control.key]:SetValue(value) end
                local decimals = tonumber(control.decimals) or 0
                self.valueByKey[control.key]:SetText(
                    value ~= nil and (string.format("%." .. decimals .. "f", value)
                        .. (control.suffix or "")) or "-"
                )
            elseif control.type == "CHECKBOX" then
                self.controlByKey[control.key]:SetChecked(value == true)
            elseif control.type == "COLOR" and type(value) == "table" then
                NSkin:CreateFlatBackground(
                    self.colorByKey[control.key],
                    "NSkinOptionColor",
                    value,
                    NSkin:GetSharedBorderColor()
                )
            end
        end
        self.refreshing = false
        SetViewEnabled(self, enabled)
    end

    function view:ApplyTheme()
        local values = self.context and self.definition.get(self.context)
        for key, swatch in pairs(self.colorByKey) do
            local color = values and values[key]
            if type(color) == "table" then
                NSkin:CreateFlatBackground(
                    swatch, "NSkinOptionColor", color, NSkin:GetSharedBorderColor()
                )
            end
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
