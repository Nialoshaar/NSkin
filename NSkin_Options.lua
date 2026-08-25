local _, NSkin = ...

local optionGroups = {}
local viewsByGroup = {}

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
            rootDescription:CreateRadio(
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
                    view.definition.set(view.context, current)
                end,
                choice.value
            )
        end
    end)
    view.controls[#view.controls + 1] = dropdown
    view.controlByKey[control.key] = dropdown
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
            value = math.floor(value + 0.5)
            valueLabel:SetText(value .. (control.suffix or ""))
            if view.refreshing or not view.context then return end
            local current = CopyTable(view.definition.get(view.context))
            current[control.key] = value
            view.definition.set(view.context, current)
        end,
    })
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", view.presentation == "FULL" and 8 or 8, -18)
    view.controls[#view.controls + 1] = slider
    view.controlByKey[control.key] = slider
    view.valueByKey[control.key] = valueLabel
end

local function CreateCheckbox(view, control, y)
    local checkbox = CreateFrame("CheckButton", nil, view, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", view, "TOPLEFT", -4, y)
    if checkbox.Text then checkbox.Text:SetText(control.label) end
    checkbox:SetScript("OnClick", function(self)
        if view.refreshing or not view.context then return end
        local current = CopyTable(view.definition.get(view.context))
        current[control.key] = self:GetChecked() == true
        view.definition.set(view.context, current)
    end)
    view.controls[#view.controls + 1] = checkbox
    view.controlByKey[control.key] = checkbox
end

local function CreateReset(view, control)
    local button = CreateFrame("Button", nil, view)
    button:SetSize(view.presentation == "FULL" and 110 or 58, 24)
    button:SetPoint("BOTTOM", view, "BOTTOM", 0, 0)
    local label = view.presentation == "COMPACT" and control.compactLabel or control.label
    NSkin:SkinFlatButton(button, label or "Reset", nil, nil, 12)
    button:SetScript("OnClick", function()
        if view.context then view.definition.reset(view.context) end
    end)
    view.controls[#view.controls + 1] = button
    view.resetButton = button
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
    optionGroups[id] = definition
    viewsByGroup[id] = setmetatable({}, { __mode = "k" })
    return true
end

function NSkin:CreateOptionGroupView(parent, id, layout, context)
    local definition = optionGroups[id]
    local presentation = layout == "COMPACT" and "COMPACT" or "FULL"
    if not parent or not definition then return nil end

    local fieldCount = 0
    for i = 1, #definition.controls do
        local controlType = definition.controls[i].type
        if controlType == "SLIDER" or controlType == "CHECKBOX" then
            fieldCount = fieldCount + 1
        end
    end
    local viewHeight = 78 + fieldCount * 70
    local view = CreateFrame("Frame", nil, parent)
    view:SetSize(presentation == "FULL" and 400 or 202, viewHeight)
    view.id = id
    view.definition = definition
    view.presentation = presentation
    view.context = context
    view.controls = {}
    view.valueLabels = {}
    view.controlByKey = {}
    view.valueByKey = {}

    local dropdownY = 0
    local firstSliderY = presentation == "FULL" and -62 or -60
    local fieldIndex = 0
    for i = 1, #definition.controls do
        local control = definition.controls[i]
        if control.type == "DROPDOWN" then
            CreateDropdown(view, control, dropdownY)
        elseif control.type == "SLIDER" then
            fieldIndex = fieldIndex + 1
            CreateSlider(view, control, firstSliderY - (fieldIndex - 1) * 70)
        elseif control.type == "CHECKBOX" then
            fieldIndex = fieldIndex + 1
            CreateCheckbox(view, control, firstSliderY - (fieldIndex - 1) * 70)
        elseif control.type == "RESET" then
            CreateReset(view, control)
        end
    end

    function view:SetContext(newContext)
        self.context = newContext
        self:Refresh()
    end

    function view:SetValues(values)
        if self.context and type(values) == "table" then
            self.definition.set(self.context, CopyTable(values))
        end
    end

    function view:Refresh()
        local enabled = self.context ~= nil
        local values = enabled and self.definition.get(self.context) or nil
        self.refreshing = true
        for i = 1, #self.definition.controls do
            local control = self.definition.controls[i]
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
                self.valueByKey[control.key]:SetText(
                    value ~= nil and (tostring(value) .. (control.suffix or "")) or "-"
                )
            elseif control.type == "CHECKBOX" then
                self.controlByKey[control.key]:SetChecked(value == true)
            end
        end
        self.refreshing = false
        SetViewEnabled(self, enabled)
    end

    function view:ApplyTheme()
        if self.resetButton then
            local resetControl
            for i = 1, #definition.controls do
                if definition.controls[i].type == "RESET" then
                    resetControl = definition.controls[i]
                    break
                end
            end
            local label = resetControl and (self.presentation == "COMPACT"
                and resetControl.compactLabel or resetControl.label)
            NSkin:SkinFlatButton(self.resetButton,
                label or "Reset", nil, nil, 12)
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
