local _, NSkin = ...

NSkin.pendingOptionsPages = NSkin.pendingOptionsPages or {}
function NSkin:RegisterOptionsPage(definition)
    if type(definition) ~= "table" or type(definition.builder) ~= "function" then
        return false
    end
    self.pendingOptionsPages[#self.pendingOptionsPages + 1] = definition
    return true
end

local optionGroups = {}
local viewsByGroup = {}
local DEFAULT_OPTIONS_WIDTH = 760
local DEFAULT_OPTIONS_HEIGHT = 560
local MIN_OPTIONS_WIDTH = 640
local MIN_OPTIONS_HEIGHT = 420
local COMPACT_OPTIONS_WIDTH = 502
local COMPACT_GRID_HEIGHT = 48
local COMPACT_GRID_PADDING = 8
local COMPACT_GRID_LABEL_WIDTH = 64
local COMPACT_GRID_CENTER_WIDTH = 28
local COMPACT_GRID_DEBUG_BORDER = { 1, 1, 0, 1 }
local compactGridDebugEnabled = false
local compactGridDebugRecords = {}
local BUILT_IN_FONTS = {
    { value = "Fonts\\FRIZQT__.TTF", label = "Friz Quadrata", priority = 1 },
    { value = "Fonts\\ARIALN.TTF", label = "Arial Narrow", priority = 2 },
    { value = "Fonts\\MORPHEUS.TTF", label = "Morpheus", priority = 3 },
    { value = "Fonts\\SKURRI.TTF", label = "Skurri", priority = 4 },
}

function NSkin:GetAvailableFontOptions(includeGlobal)
    local fonts, paths = {}, {}
    local function Add(label, path, priority)
        if type(label) ~= "string" or label == ""
            or type(path) ~= "string" or path == ""
        then return end
        local normalized = path:lower()
        if paths[normalized] then return end
        paths[normalized] = true
        fonts[#fonts + 1] = { value = path, label = label,
            priority = priority or 100 }
    end
    for i = 1, #BUILT_IN_FONTS do
        local font = BUILT_IN_FONTS[i]
        Add(font.label, font.value, font.priority)
    end
    if _G.LibStub then
        local ok, media = pcall(function()
            return _G.LibStub("LibSharedMedia-3.0", true)
        end)
        local registered = ok and media and media:HashTable("font")
        if registered then
            for name, path in pairs(registered) do Add(name, path) end
        end
    end
    table.sort(fonts, function(left, right)
        if left.priority ~= right.priority then
            return left.priority < right.priority
        end
        return left.label:lower() < right.label:lower()
    end)
    if includeGlobal then
        table.insert(fonts, 1, { divider = true })
        table.insert(fonts, 1, {
            value = "__NSKIN_GLOBAL__", label = "NSkin Global Font",
        })
    end
    return fonts
end

local function SetDebugRecordShown(record, shown)
    if record.kind == "CELL" then
        if shown and not record.border then
            record.border = NSkin:CreatePixelBorder(record.frame,
                "NSkinCompactGridCell", 1, COMPACT_GRID_DEBUG_BORDER,
                false, record.frame)
        end
        if record.border then NSkin:SetPixelBorderShown(record.border, shown) end
    else
        if shown and not record.texture then
            local divider = record.parent:CreateTexture(nil, "OVERLAY")
            divider:SetColorTexture(unpack(COMPACT_GRID_DEBUG_BORDER))
            divider:SetSize(1, COMPACT_GRID_HEIGHT)
            divider:SetPoint("TOP", record.label,
                record.mirrored and "TOPLEFT" or "TOPRIGHT", 0, 4)
            record.texture = divider
        end
        if record.texture then record.texture:SetShown(shown) end
    end
end

function NSkin:IsCompactGridDebugEnabled()
    return compactGridDebugEnabled
end

function NSkin:SetCompactGridDebugEnabled(enabled)
    enabled = enabled == true
    if compactGridDebugEnabled == enabled then return true end
    compactGridDebugEnabled = enabled
    for i = 1, #compactGridDebugRecords do
        SetDebugRecordShown(compactGridDebugRecords[i], enabled)
    end
    return true
end

local function AddCompactGridCellBorder(cell)
    local record = { kind = "CELL", frame = cell }
    compactGridDebugRecords[#compactGridDebugRecords + 1] = record
    if compactGridDebugEnabled then SetDebugRecordShown(record, true) end
end

local function AddCompactGridControlDivider(parent, label, mirrored)
    local record = { kind = "DIVIDER", parent = parent,
        label = label, mirrored = mirrored == true }
    compactGridDebugRecords[#compactGridDebugRecords + 1] = record
    if compactGridDebugEnabled then SetDebugRecordShown(record, true) end
end

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

    function page:ApplyStructureAppearance()
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

local function ResolveOptionValues(values)
    if type(values) == "function" then values = values() end
    return type(values) == "table" and values or {}
end

local OPTION_MENUS = NSkin._componentOptionMenus or {}
NSkin._componentOptionMenus = OPTION_MENUS
local function CreateOwnedDropdown(...) return OPTION_MENUS.CreateOwnedDropdown(...) end
local function SkinAddonDropdown(...) return OPTION_MENUS.SkinAddonDropdown(...) end
local function ConfigureDropdownMenuScroll(...) return OPTION_MENUS.ConfigureDropdownMenuScroll(...) end
local function AddDropdownMenuSearch(...) return OPTION_MENUS.AddDropdownMenuSearch(...) end
local function DropdownChoiceMatches(...) return OPTION_MENUS.DropdownChoiceMatches(...) end
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

local function OptionValuesEqual(left, right)
    if left == right then return true end
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return false end
    for key, value in pairs(left) do
        if not OptionValuesEqual(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function CommitValues(view, values, knownCurrent, liveInspectorChange)
    if not view.context or type(values) ~= "table" then return false end
    local current = knownCurrent or view.definition.get(view.context)
    if OptionValuesEqual(current, values) then return false end
    local context = view.context
    local copiedValues = CopyTable(values)
    local preserveLocalState = liveInspectorChange
        and view.isSkinningModeInspector == true and context.id ~= nil
    local function ApplyValues()
        return view.definition.set(context, copiedValues)
    end
    local applied
    if preserveLocalState
        and NSkin.RunWithLiveInspectorAppearanceChange
    then
        applied = NSkin:RunWithLiveInspectorAppearanceChange(
            context.id, ApplyValues)
    else
        applied = ApplyValues()
    end
    if applied == true then
        if view.context.id and NSkin.NotifySkinningElementBoundsChanged then
            NSkin:NotifySkinningElementBoundsChanged(view.context.id)
        end
        NSkin:NotifyOptionGroupChanged(view.id,
            preserveLocalState and view or nil)
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

    local dropdown = CreateOwnedDropdown(view)
    dropdown:SetSize(view.presentation == "FULL" and 220 or 202, 24)
    SkinAddonDropdown(dropdown)
    dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    dropdown:SetDefaultText(control.label)
    dropdown:SetupMenu(function(_, rootDescription)
        local choices = ResolveOptionValues(control.values)
        ConfigureDropdownMenuScroll(rootDescription, choices)
        local filter = AddDropdownMenuSearch(dropdown, rootDescription, choices)
        for i = 1, #choices do
            local choice = choices[i]
            if DropdownChoiceMatches(choice, filter) and choice.divider then
                if rootDescription.CreateDivider then rootDescription:CreateDivider() end
            elseif DropdownChoiceMatches(choice, filter) and choice.title then
                if rootDescription.CreateTitle then rootDescription:CreateTitle(choice.title) end
            elseif DropdownChoiceMatches(choice, filter) then
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
            local values = view.definition.get(view.context)
            if not values or values[control.key] == value then return end
            local current = CopyTable(values)
            current[control.key] = value
            CommitValues(view, current, values, true)
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

local function CreateOwnedCheckbox(parent)
    local checkbox = CreateFrame("CheckButton", nil, parent)
    checkbox:SetSize(22, 22)
    NSkin:CreateFlatBackground(checkbox, "NSkinOptionsCheckbox",
        NSkin:GetStyle("button").background, NSkin:GetSharedBorderColor())
    NSkin:SetPixelBorderSize(NSkin:GetPixelBorder(checkbox,
        "NSkinOptionsCheckboxBorder"), 1)
    local checked = checkbox:CreateTexture(nil, "ARTWORK")
    checked:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 4, -4)
    checked:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -4, 4)
    checked:SetColorTexture(unpack(NSkin:GetAccentColor()))
    checkbox:SetCheckedTexture(checked)
    local highlight = checkbox:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 2, -2)
    highlight:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -2, 2)
    highlight:SetColorTexture(1, 1, 1, 0.12)
    checkbox:SetHighlightTexture(highlight)
    checkbox.Text = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    checkbox.Text:SetPoint("LEFT", checkbox, "RIGHT", 7, 0)
    checkbox.Text:SetJustifyH("LEFT")
    checkbox.Text:SetJustifyV("MIDDLE")
    return checkbox
end

function NSkin:CreateOwnedOptionsCheckbox(parent)
    return CreateOwnedCheckbox(parent)
end

local function CreateCheckbox(view, control, y)
    local checkbox = CreateOwnedCheckbox(view)
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
    local labelWidth = view.presentation == "COMPACT"
        and COMPACT_GRID_LABEL_WIDTH or (tonumber(control.labelWidth) or 70)
    local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint(mirrored and "RIGHT" or "LEFT", view, "TOPLEFT",
        mirrored and (x + width) or x, y)
    label:SetSize(math.max(1, labelWidth), COMPACT_GRID_HEIGHT - 8)
    label:SetWordWrap(true)
    label:SetJustifyH(view.presentation == "COMPACT" and "CENTER"
        or (mirrored and "RIGHT" or "LEFT"))
    label:SetJustifyV("MIDDLE")
    label:SetText(control.label)
    AddCompactGridControlDivider(view, label, mirrored)
    local dropdown = CreateOwnedDropdown(view)
    local dropdownReduction = control.dropdownReduction
    if dropdownReduction == nil then
        dropdownReduction = view.presentation == "COMPACT" and 10 or 0
    end
    dropdown:SetSize(width - labelWidth - dropdownReduction,
        view.presentation == "COMPACT" and 26 or 24)
    SkinAddonDropdown(dropdown)
    if mirrored then
        dropdown:SetPoint("LEFT", view, "TOPLEFT",
            x + dropdownReduction / 2, y)
    else
        dropdown:SetPoint("LEFT", view, "TOPLEFT",
            x + labelWidth + dropdownReduction / 2, y)
    end
    dropdown:SetDefaultText(control.label)
    dropdown:SetupMenu(function(_, rootDescription)
        local choices = ResolveOptionValues(control.values)
        ConfigureDropdownMenuScroll(rootDescription, choices)
        local filter = AddDropdownMenuSearch(dropdown, rootDescription, choices)
        for i = 1, #choices do
            local choice = choices[i]
            if DropdownChoiceMatches(choice, filter) and choice.divider then
                if rootDescription.CreateDivider then rootDescription:CreateDivider() end
            elseif DropdownChoiceMatches(choice, filter) then
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
    local gap = requestedGap == nil and COMPACT_GRID_CENTER_WIDTH
        or (tonumber(requestedGap) or 0)
    gap = NSkin:SnapToPhysicalPixel(view, gap)
    height = NSkin:SnapToPhysicalPixel(view, height)
    y = NSkin:SnapToPhysicalPixel(view, y)
    local width = NSkin:SnapToPhysicalPixel(view,
        (view:GetWidth() - gap) / 2)
    local row = CreateFrame("Frame", nil, view)
    row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
    row:SetSize(view:GetWidth(), height)
    row.left = CreateFrame("Frame", nil, row)
    row.left:SetPoint("TOPLEFT")
    row.left:SetSize(width, height)
    AddCompactGridCellBorder(row.left)
    row.right = CreateFrame("Frame", nil, row)
    row.right:SetPoint("TOPLEFT", row, "TOPLEFT", width + gap, 0)
    row.right:SetSize(width, height)
    AddCompactGridCellBorder(row.right)
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
        local checkbox = CreateOwnedCheckbox(view)
        checkbox:SetSize(24, 24)
        local label = view:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetSize(math.max(1, width - 40), COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
        label:SetText(control.label)
        if mirrored then
            checkbox:SetPoint("LEFT", view, "TOPLEFT", x, y)
            label:SetPoint("RIGHT", view, "TOPLEFT", x + width, y)
        else
            checkbox:SetPoint("RIGHT", view, "TOPLEFT", x + width, y)
            label:SetPoint("LEFT", view, "TOPLEFT", x, y)
        end
        if checkbox.Text then checkbox.Text:SetText("") end
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
        label:SetSize(COMPACT_GRID_LABEL_WIDTH, COMPACT_GRID_HEIGHT - 8)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
    else
        label:SetPoint("TOPLEFT", view, "TOPLEFT", x, y)
    end
    label:SetText(control[key .. "Label"])
    if inline then AddCompactGridControlDivider(view, label, mirrored) end
    local dropdown = CreateOwnedDropdown(view)
    local labelWidth = inline and COMPACT_GRID_LABEL_WIDTH or 0
    dropdown:SetSize(width - labelWidth
        - (view.presentation == "COMPACT" and 10 or 0),
        view.presentation == "COMPACT" and 26 or 24)
    SkinAddonDropdown(dropdown)
    if inline then
        dropdown:SetPoint("LEFT", view, "TOPLEFT",
            mirrored and (x + (view.presentation == "COMPACT" and 5 or 0))
                or (x + labelWidth
                    + (view.presentation == "COMPACT" and 5 or 0)),
            y - COMPACT_GRID_HEIGHT / 2)
    else
        dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
    end
    dropdown:SetDefaultText(control[key .. "Label"])
    dropdown:SetupMenu(function(_, rootDescription)
        local choices = ResolveOptionValues(values)
        ConfigureDropdownMenuScroll(rootDescription, choices)
        local filter = AddDropdownMenuSearch(dropdown, rootDescription, choices)
        for i = 1, #choices do
            local choice = choices[i]
            if DropdownChoiceMatches(choice, filter) and choice.divider then
                if rootDescription.CreateDivider then rootDescription:CreateDivider() end
            elseif DropdownChoiceMatches(choice, filter) and choice.title then
                if rootDescription.CreateTitle then rootDescription:CreateTitle(choice.title) end
            elseif DropdownChoiceMatches(choice, filter) then
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
    label:SetSize(COMPACT_GRID_LABEL_WIDTH, COMPACT_GRID_HEIGHT - 8)
    label:SetWordWrap(true)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetText(definition.label)
    AddCompactGridControlDivider(parent, label, false)
    local valueLabel = CreateFrame("EditBox", nil, parent)
    valueLabel:SetSize(38, 22)
    local labelDelta = COMPACT_GRID_LABEL_WIDTH - 56
    valueLabel:SetPoint("LEFT", parent, "LEFT", 70 + labelDelta, 0)
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
        width = parent:GetWidth() - 124 - labelDelta,
        min = definition.min, max = definition.max,
        step = definition.step,
        onValueChanged = function(_, value)
            value = RoundValue(value, 0)
            valueLabel:SetText(string.format("%.0f", value))
            if view.refreshing or not view.context then return end
            local values = view.definition.get(view.context)
            if not values or values[definition.key] == value then return end
            local current = CopyTable(values)
            current[definition.key] = value
            CommitValues(view, current, values, true)
        end,
    })
    slider:SetPoint("LEFT", parent, "LEFT", 116 + labelDelta, 0)
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

local function ResolveColorModeFill(values, control, mode)
    if mode == "CLASS" then
        local _, class = UnitClass("player")
        local classColor = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if classColor then
            return { classColor.r, classColor.g, classColor.b, 1 }
        end
        return { 1, 1, 1, 1 }
    elseif mode == "ACCENT" then
        return NSkin:GetAccentColor()
    end
    local custom = values and values[control.key]
    return type(custom) == "table" and custom or { 1, 1, 1, 1 }
end

local function FillColorDropdown(dropdown, color)
    local background = NSkin:CreateFlatBackground(dropdown, "NSkinOptionsDropdown",
        color, NSkin:GetSharedBorderColor())
    if background then background:SetAlpha(1) end
    local border = NSkin:GetPixelBorder(dropdown, "NSkinOptionsDropdownBorder")
    NSkin:SetPixelBorderColor(border, unpack(NSkin:GetSharedBorderColor()))
    NSkin:SetPixelBorderSize(border, 1)
    NSkin:SetPixelBorderShown(border, true)
    if border then
        for _, edge in ipairs({ border.top, border.bottom, border.left, border.right }) do
            edge:SetAlpha(1)
            edge:Show()
        end
    end
end

local function FillColorDropdownChoice(button, color)
    if not button then return end
    if button.indicator then
        NSkin:SetPixelBorderShown(NSkin:GetPixelBorder(button.indicator,
            "NSkinOwnedDropdownCheckboxBorder"), false)
    end
    local fill = button.nskinColorFill
    if not fill then
        if button.nskinOwnedMenuRow and button.CreateTexture then
            fill = button:CreateTexture(nil, "ARTWORK", nil, -8)
            button.nskinColorFill = fill
        elseif button.AttachTexture then
            fill = button:AttachTexture()
        end
    end
    if not fill then return end
    fill:SetDrawLayer("ARTWORK", -8)
    fill:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(unpack(color))
    fill:SetAlpha(1)
    fill:Show()
end

CreateColor = function(view, control, y, layout)
    layout = layout or {}
    local x = tonumber(layout.x) or 0
    local width = tonumber(layout.width) or view:GetWidth()
    local inlineLabelWidth = layout.inline and COMPACT_GRID_LABEL_WIDTH or 0
    local hasColorMode = type(control.modeKey) == "string"
    local label = view:CreateFontString(nil, "OVERLAY",
        layout.inline and "GameFontNormalSmall" or "GameFontNormal")
    if layout.inline then
        label:SetPoint(layout.mirrored and "RIGHT" or "LEFT", view, "TOPLEFT",
            layout.mirrored and (x + width) or x,
            y - COMPACT_GRID_HEIGHT / 2)
        label:SetSize(inlineLabelWidth, COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
    else
        label:SetPoint("TOPLEFT", view, "TOPLEFT", x, y - 6)
    end
    label:SetText(control.label)
    if layout.inline then
        AddCompactGridControlDivider(view, label, layout.mirrored)
    end
    local dropdown = CreateOwnedDropdown(view)
    local controlWidth = math.max(80, width - inlineLabelWidth - 10)
    dropdown:SetSize(math.min(controlWidth,
        view.presentation == "FULL" and 180 or 150),
        view.presentation == "COMPACT" and 26 or 24)
    SkinAddonDropdown(dropdown)
    if layout.inline then
        local controlLeft = layout.mirrored and x or (x + inlineLabelWidth)
        dropdown:SetPoint("LEFT", view, "TOPLEFT",
            math.floor(controlLeft
                + (math.max(dropdown:GetWidth(), width - inlineLabelWidth)
                    - dropdown:GetWidth()) / 2 + 0.5),
            y - COMPACT_GRID_HEIGHT / 2)
    else
        dropdown:SetPoint("TOPRIGHT", view, "TOPLEFT", x + width, y - 3)
    end

    local function OpenCustomColorPicker(previousMode)
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
    end

    dropdown:SetDefaultText("Custom")
    dropdown:SetupMenu(function(_, rootDescription)
        local current = view.context and view.definition.get(view.context)
        local previousMode = hasColorMode and current and current[control.modeKey]
        local modes = hasColorMode and {
            { value = "CLASS", label = "Class" },
            { value = "ACCENT", label = "Accent" },
            { value = "CUSTOM", label = "Custom" },
        } or {
            { value = "CUSTOM", label = "Custom" },
        }
        for i = 1, #modes do
            local mode = modes[i]
            local description = rootDescription:CreateRadio(mode.label,
                function(value)
                    if not hasColorMode then return value == "CUSTOM" end
                    local values = view.context
                        and view.definition.get(view.context)
                    return values and values[control.modeKey] == value
                end,
                function(value)
                    if value == "CUSTOM" then
                        OpenCustomColorPicker(previousMode)
                    elseif view.context then
                        local values = CopyTable(view.definition.get(view.context))
                        values[control.modeKey] = value
                        CommitValues(view, values)
                    end
                end, mode.value)
            if description and description.AddInitializer then
                local fill = ResolveColorModeFill(current, control, mode.value)
                description:AddInitializer(function(button)
                    FillColorDropdownChoice(button, fill)
                end)
            end
        end
    end)

    view.controls[#view.controls + 1] = dropdown
    view.controlByKey[control.key] = dropdown
    view.colorByKey[control.key] = dropdown
    view.colorDefinitionByKey[control.key] = control
    if hasColorMode then
        view.colorModeByKey[control.key] = control.modeKey
    end
    return 38
end

local function RefreshColorControl(view, control, values)
    local value = values and values[control.key]
    if type(value) ~= "table" then return end
    local dropdown = view.colorByKey[control.key]
    local modeKey = view.colorModeByKey[control.key]
    local mode = modeKey and values[modeKey] or "CUSTOM"
    local labels = { CLASS = "Class", ACCENT = "Accent", CUSTOM = "Custom" }
    FillColorDropdown(dropdown, ResolveColorModeFill(values, control, mode))
    dropdown:SetDefaultText(labels[mode] or "Custom")
    if dropdown.GenerateMenu then dropdown:GenerateMenu() end
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
        label:SetSize(COMPACT_GRID_LABEL_WIDTH, COMPACT_GRID_HEIGHT - 8)
        label:SetWordWrap(true)
        if label.SetNonSpaceWrap then label:SetNonSpaceWrap(true) end
        label:SetJustifyH("CENTER")
        label:SetJustifyV("MIDDLE")
    elseif mirroredSide == "LEFT" then
        label:SetPoint("LEFT", parent, "LEFT", COMPACT_GRID_PADDING, 0)
        label:SetSize(COMPACT_GRID_LABEL_WIDTH, COMPACT_GRID_HEIGHT - 8)
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
    if mirroredSide then
        AddCompactGridControlDivider(parent, label, mirroredSide == "RIGHT")
    end
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
    local labelDelta = COMPACT_GRID_LABEL_WIDTH - 56
    local trackWidth = width
        - (mirroredSide and 124 or 118) - labelDelta
    local slider = NSkin:CreateOptionsSlider(parent, {
        width = trackWidth, min = definition.min, max = definition.max,
        step = definition.step,
        onValueChanged = function(_, value)
            local decimals = tonumber(definition.decimals) or 0
            value = RoundValue(value, decimals)
            valueLabel:SetText(string.format("%." .. decimals .. "f", value))
            if view.refreshing or not view.context then return end
            local values = view.definition.get(view.context)
            if not values or values[definition.key] == value then return end
            local current = CopyTable(values)
            current[definition.key] = value
            CommitValues(view, current, values, true)
        end,
    })
    if mirroredSide == "LEFT" then
        valueLabel:SetPoint("LEFT", parent, "LEFT", 70 + labelDelta, 0)
        slider:SetPoint("LEFT", parent, "LEFT", 116 + labelDelta, 0)
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
        local centerWidth = COMPACT_GRID_CENTER_WIDTH
        local width = math.floor((view:GetWidth() - centerWidth) / 2)
        local row = CreateFrame("Frame", nil, view)
        row:SetPoint("TOPLEFT", view, "TOPLEFT", 0, y)
        row:SetSize(view:GetWidth(), COMPACT_GRID_HEIGHT)
        local left = CreateFrame("Frame", nil, row)
        left:SetPoint("TOPLEFT")
        left:SetSize(width, COMPACT_GRID_HEIGHT)
        AddCompactGridCellBorder(left)
        local center = CreateFrame("Frame", nil, row)
        center:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
        center:SetSize(centerWidth, COMPACT_GRID_HEIGHT)
        AddCompactGridCellBorder(center)
        local right = CreateFrame("Frame", nil, row)
        right:SetPoint("TOPLEFT", center, "TOPRIGHT", 0, 0)
        right:SetSize(width, COMPACT_GRID_HEIGHT)
        AddCompactGridCellBorder(right)
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
            if control.resetGroup and type(view.definition.reset) == "function" then
                view.definition.reset(view.context)
                view:Refresh()
                return
            end
            if control.resetSubset
                and type(view.definition.resetSubset) == "function"
            then
                view.definition.resetSubset(view.context, {
                    [control.left.key] = true,
                    [control.right.key] = true,
                })
                view:Refresh()
                return
            end
            local values = CopyTable(view.definition.get(view.context))
            values[control.left.key] = control.left.resetValue or 0
            values[control.right.key] = control.right.resetValue or 0
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
        inheritedReset = true,
        inheritedResetLabel = "Reset to window defaults",
        get = source.get,
        set = function(context, values)
            local filtered = {}
            for key in pairs(keys) do filtered[key] = values[key] end
            return source.set(context, filtered)
        end,
        reset = function(context)
            if type(source.resetSubset) == "function" then
                return source.resetSubset(context, keys)
            end
            return source.reset(context)
        end,
    })
end

function NSkin:GetOptionGroupDefinition(id)
    return optionGroups[id]
end

function NSkin:ResetOptionGroup(id, context)
    local definition = optionGroups[id]
    if not definition or not context then return false end
    if definition.reset(context) == true then
        self:NotifyOptionGroupChanged(id)
        return true
    end
    return false
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
    view.colorDefinitionByKey = {}
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
        y = NSkin:SnapToPhysicalPixel(view, y - (height or 0))
    end
    view:SetHeight(NSkin:SnapToPhysicalPixel(view,
        math.max(1, -y + (presentation == "COMPACT" and 1 or 0))))

    function view:SetContext(newContext)
        self.context = newContext
        self:Refresh()
    end

    function view:SetValues(values)
        return CommitValues(self, values)
    end

    function view:SetPreviewValue(key, value, decimals)
        local slider, valueLabel = self.controlByKey[key], self.valueByKey[key]
        if not slider or not valueLabel or value == nil then return false end
        local wasRefreshing = self.refreshing
        self.refreshing = true
        slider:SetValue(value)
        valueLabel:SetText(string.format("%." .. (tonumber(decimals) or 0) .. "f", value))
        self.refreshing = wasRefreshing
        return true
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
                local choices = ResolveOptionValues(control.values)
                for j = 1, #choices do
                    if choices[j].value == value then text = choices[j].label break end
                end
                dropdown:SetDefaultText(text)
                if dropdown.GenerateMenu then dropdown:GenerateMenu() end
            elseif control.type == "DROPDOWN_PAIR" then
                for _, definition in ipairs({ control.left, control.right }) do
                    if definition then
                        local selected = values and values[definition.key]
                        local text = definition.label
                        local choices = ResolveOptionValues(definition.values)
                        for j = 1, #choices do
                            if choices[j].value == selected then
                                text = choices[j].label
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
                            local choices = ResolveOptionValues(definition.values)
                            for j = 1, #choices do
                                if choices[j].value == selected then
                                    text = choices[j].label
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
                    local choices = ResolveOptionValues(item.values)
                    for k = 1, #choices do
                        if choices[k].value == selected then
                            text = choices[k].label
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
                local choices = ResolveOptionValues(dropdownDefinition.values)
                for j = 1, #choices do
                    if choices[j].value == dropdownValue then
                        text = choices[j].label
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

    function view:ApplyAppearance()
        local values = self.context and self.definition.get(self.context)
        for key, dropdown in pairs(self.colorByKey) do
            local modeKey = self.colorModeByKey[key]
            local mode = modeKey and values and values[modeKey] or "CUSTOM"
            local control = self.colorDefinitionByKey[key]
            local labels = {
                CLASS = "Class", ACCENT = "Accent", CUSTOM = "Custom",
            }
            if control then
                FillColorDropdown(dropdown,
                    ResolveColorModeFill(values, control, mode))
            end
            dropdown:SetDefaultText(labels[mode] or "Custom")
            if dropdown.GenerateMenu then dropdown:GenerateMenu() end
        end
        local dividerColor = NSkin:GetStyle("window").header.divider
        for i = 1, #self.typographyRows do
            local divider = self.typographyRows[i].divider
            if divider then NSkin:SetOwnedTextureColor(divider, unpack(dividerColor)) end
        end
        for i = 1, #self.sectionDividers do
            NSkin:SetOwnedTextureColor(
                self.sectionDividers[i], unpack(dividerColor))
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

function NSkin:NotifyOptionGroupChanged(id, excludedView)
    local views = viewsByGroup[id]
    if not views then return false end
    for view in pairs(views) do
        if view ~= excludedView and view.Refresh then view:Refresh() end
    end
    return true
end

local _, NSkin = ...
local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

local function ColorsEqual(left, right)
    return left and right
        and left[1] == right[1] and left[2] == right[2]
        and left[3] == right[3] and (left[4] or 1) == (right[4] or 1)
end

local function ColorWithOpacity(color, opacity)
    return { color[1], color[2], color[3], tonumber(opacity) or color[4] or 1 }
end

local function SetColor(path, current, color, opacity)
    local value = ColorWithOpacity(color, opacity)
    if ColorsEqual(current, value) then return false end
    return NSkin:SetAppearanceOverride(path, value)
end

local function SetScalar(path, current, value)
    if value == nil or current == value then return false end
    return NSkin:SetAppearanceOverride(path, value)
end

local function ResetPaths(paths)
    local changed
    for i = 1, #paths do changed = NSkin:ResetAppearanceOverride(paths[i]) or changed end
    return changed == true
end
NSkin:RegisterOptionGroup("appearance.typography", {
    controls = {
        { type = "DROPDOWN", key = "font", label = "Global font",
            values = function() return NSkin:GetAvailableFontOptions(false) end },
        { type = "SLIDER", key = "size", label = "Global text size", min = 8,
            max = 32, step = 1, suffix = " px" },
        { type = "DROPDOWN", key = "outline", label = "Global outline", values = {
            { value = "", label = "None" },
            { value = "OUTLINE", label = "Outline" },
            { value = "THICKOUTLINE", label = "Thick outline" },
            { value = "MONOCHROME,OUTLINE", label = "Monochrome outline" },
        } },
        { type = "RESET", label = "Reset Typography" },
    },
    get = function()
        local style = NSkin:GetStyle("typography")
        return { font = style.font, size = style.size, outline = style.outline }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("typography")
        local changed = SetScalar("typography.font", style.font, values.font)
        changed = SetScalar("typography.size", style.size, values.size) or changed
        changed = SetScalar("typography.outline", style.outline, values.outline) or changed
        return changed == true
    end,
    reset = function()
        return ResetPaths({ "typography.font", "typography.size", "typography.outline" })
    end,
})
local function RegisterColorAppearanceGroup(id, styleName, controls)
    NSkin:RegisterOptionGroup(id, {
        controls = controls,
        get = function()
            local style = NSkin:GetStyle(styleName)
            local values = {}
            if style.background then
                values.backgroundColor = CopyColor(style.background)
                values.backgroundOpacity = style.background[4] or 1
            end
            if style.selectedBackground then
                values.selectedColor = CopyColor(style.selectedBackground)
                values.selectedOpacity = style.selectedBackground[4] or 1
            end
            if style.border then
                values.border = CopyColor(NSkin:GetComponentBorderSetting(styleName, style))
            end
            if style.text then values.text = CopyColor(style.text) end
            values.hoverAlpha = style.hoverAlpha
            return values
        end,
        set = function(_, values)
            local style = NSkin:GetStyle(styleName)
            local changed
            if style.background then
                changed = SetColor(styleName .. ".background", style.background,
                    values.backgroundColor, values.backgroundOpacity)
            end
            if style.selectedBackground then
                changed = SetColor(styleName .. ".selectedBackground",
                    style.selectedBackground, values.selectedColor,
                    values.selectedOpacity) or changed
            end
            if style.border and values.border then
                local currentBorder = NSkin:GetComponentBorderSetting(styleName, style)
                if not ColorsEqual(currentBorder, values.border) then
                    changed = NSkin:SetComponentBorderColor(styleName, values.border) or changed
                end
            end
            if style.text and values.text then
                changed = SetColor(styleName .. ".text", style.text,
                    values.text, values.text[4]) or changed
            end
            changed = SetScalar(styleName .. ".hoverAlpha", style.hoverAlpha,
                values.hoverAlpha) or changed
            return changed == true
        end,
        reset = function()
            local paths = { styleName .. ".background" }
            if NSkin.baseAppearance[styleName].selectedBackground then
                paths[#paths + 1] = styleName .. ".selectedBackground"
            end
            if NSkin.baseAppearance[styleName].hoverAlpha ~= nil then
                paths[#paths + 1] = styleName .. ".hoverAlpha"
            end
            if NSkin.baseAppearance[styleName].text then
                paths[#paths + 1] = styleName .. ".text"
            end
            local changed = ResetPaths(paths)
            changed = NSkin:ResetComponentBorderColor(styleName) or changed
            return changed == true
        end,
    })
end
local function BuildAppearanceOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)
    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Appearance")

    local views = {}
    local y = 38
    local groups = {
        { "Typography", "appearance.typography" },
        { "Windows", "appearance.window" },
        { "Buttons", "appearance.button" },
        { "Tabs", "appearance.tab" },
        { "Section cards", "appearance.sectionCard" },
        { "Section rows", "appearance.sectionRow" },
        { "Search boxes", "appearance.search" },
        { "Progress bars", "appearance.progress" },
        { "Icons", "appearance.icon" },
    }
    for i = 1, #groups do
        local _, contentY = NSkin:CreateOptionsSection(page, groups[i][1], y)
        local view = NSkin:CreateOptionGroupView(page, groups[i][2], "FULL", page)
        view:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -contentY)
        views[#views + 1] = view
        y = contentY + view:GetHeight() + 24
    end

    function page:ApplyAppearance()
        for i = 1, #views do views[i]:ApplyAppearance() end
    end
    function page:Refresh()
        for i = 1, #views do views[i]:Refresh() end
        self:ApplyAppearance()
    end

    page:SetContentHeight(y)
    return page
end

NSkin:RegisterOptionsPage({
    key = "appearance",
    label = "Appearance",
    group = "shared",
    order = 1,
    builder = BuildAppearanceOptions,
})

do
local _, NSkin = ...

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

local function BuildBorderOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Border")

    local description = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -28)
    description:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -28)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Choose the border inherited by NSkin components without their own override. "
        .. "Optionally enable an "
        .. "accent color for windows, tabs, search boxes, buttons, and "
        .. "progress-bar fills and borders. "
        .. "Icon and item-quality borders keep their own colors."
    )

    NSkin:CreateOptionsSection(page, "Shared border", 82)
    local colorLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -114)
    colorLabel:SetText("Color")

    local swatch = CreateFrame("Button", nil, page)
    swatch:SetSize(64, 24)
    swatch:SetPoint("LEFT", colorLabel, "RIGHT", 12, 0)

    local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    reset:SetSize(110, 24)
    reset:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -18)
    if reset:GetFontString() then reset:GetFontString():SetAlpha(0) end

    NSkin:CreateOptionsSection(page, "Accent", 170)
    local accentToggle = NSkin:CreateOwnedOptionsCheckbox(page)
    accentToggle:SetPoint("TOPLEFT", page, "TOPLEFT", -4, -202)
    if accentToggle.Text then
        accentToggle.Text:SetText("Use accent for shared controls and progress bars")
    end

    local accentLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    accentLabel:SetPoint("TOPLEFT", accentToggle, "BOTTOMLEFT", 4, -16)
    accentLabel:SetText("Accent color")

    local accentSwatch = CreateFrame("Button", nil, page)
    accentSwatch:SetSize(64, 24)
    accentSwatch:SetPoint("LEFT", accentLabel, "RIGHT", 12, 0)

    local resetAccent = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    resetAccent:SetSize(110, 24)
    resetAccent:SetPoint("TOPLEFT", accentLabel, "BOTTOMLEFT", 0, -20)
    if resetAccent:GetFontString() then resetAccent:GetFontString():SetAlpha(0) end

    local function ApplyPickerColor()
        local red, green, blue = ColorPickerFrame:GetColorRGB()
        NSkin:SetBorderAccentColor({ red, green, blue, 1 })
        page:Refresh()
    end

    swatch:SetScript("OnClick", function()
        local previousColor = CopyColor(NSkin:GetBorderAccentColor())
        local info = {
            r = previousColor[1],
            g = previousColor[2],
            b = previousColor[3],
            swatchFunc = ApplyPickerColor,
            cancelFunc = function()
                NSkin:SetBorderAccentColor(previousColor)
                page:Refresh()
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    local function ApplyAccentPickerColor()
        local red, green, blue = ColorPickerFrame:GetColorRGB()
        NSkin:SetAccentColor({ red, green, blue, 1 })
        page:Refresh()
    end

    accentSwatch:SetScript("OnClick", function()
        local previousColor = CopyColor(NSkin:GetAccentColor())
        local info = {
            r = previousColor[1],
            g = previousColor[2],
            b = previousColor[3],
            swatchFunc = ApplyAccentPickerColor,
            cancelFunc = function()
                NSkin:SetAccentColor(previousColor)
                page:Refresh()
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    accentToggle:SetScript("OnClick", function(self)
        NSkin:SetAccentColorEnabled(self:GetChecked() == true)
        page:Refresh()
    end)

    reset:SetScript("OnClick", function()
        NSkin:ResetBorderAccentColor()
        page:Refresh()
    end)

    resetAccent:SetScript("OnClick", function()
        NSkin:ResetAccentColor()
        page:Refresh()
    end)

    function page:ApplyAppearance()
        local color = NSkin:GetBorderAccentColor()
        local buttonStyle = NSkin:GetStyle("button")
        NSkin:CreateFlatBackground(swatch, "NSkinBorderColorSwatch",
            color, buttonStyle.border)
        NSkin:CreateFlatBackground(accentSwatch, "NSkinAccentColorSwatch",
            NSkin:GetAccentColor(), buttonStyle.border)
        NSkin:SkinFlatButton(reset, "Reset Default", nil, nil, 12)
        NSkin:SkinFlatButton(resetAccent, "Reset Accent", nil, nil, 12)
        accentToggle:SetChecked(NSkin:IsAccentColorEnabled())
    end

    function page:Refresh()
        self:ApplyAppearance()
    end

    page:SetContentHeight(330)
    return page
end

NSkin:RegisterOptionsPage({
    key = "border",
    label = "Border",
    group = "shared",
    order = 5,
    builder = BuildBorderOptions,
})

end
local _, NSkin = ...
local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

function NSkin:NormalizeGridPlacementForEditor(context, values)
    if not values or values.mode ~= "GRID" then return values end
    local window, target = context and context.window, context and context.target
    if not window or not target then return values end
    local windowWidth, windowHeight = window:GetWidth(), window:GetHeight()
    local targetWidth, targetHeight = target:GetWidth(), target:GetHeight()
    local x, y = tonumber(values.x) or 0, tonumber(values.y) or 0
    local centerX, centerY = x + targetWidth / 2, y - targetHeight / 2
    local alignment = centerX < windowWidth / 3 and "LEFT"
        or (centerX < windowWidth * 2 / 3 and "CENTER" or "RIGHT")
    local edge = centerY > -windowHeight / 2 and "TOP" or "BOTTOM"
    local side = centerY <= 0 and centerY >= -windowHeight and "INSIDE" or "OUTSIDE"
    values.alignment, values.edge, values.side = alignment, edge, side
    values.alongOffset = alignment == "LEFT" and x
        or (alignment == "CENTER" and x + targetWidth / 2 - windowWidth / 2
            or x + targetWidth - windowWidth)
    values.edgeOffset = edge == "TOP"
        and (side == "INSIDE" and y or y - targetHeight)
        or (side == "INSIDE" and y - targetHeight + windowHeight or y + windowHeight)
    values.mode, values.point, values.relativePoint = nil, nil, nil
    values.x, values.y, values.relativeTo = nil, nil, nil
    return values
end

function NSkin:CreateSharedPlacementControls(extra)
    local controls = {
        { type = "SLIDER_PAIR", order = 1, centerReset = true,
            resetGroup = true,
            resetTooltip = "Reset X and Y offsets",
            left = { key = "alongOffset", label = "X offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" },
            right = { key = "edgeOffset", label = "Y offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" } },
    }
    for i = 1, #(extra or {}) do controls[#controls + 1] = extra[i] end
    return controls
end

function NSkin:NormalizeSharedPlacementValues(context, values)
    if values.mode == "GRID" then
        values.x, values.y = values.alongOffset, values.edgeOffset
    end
    return values
end

NSkin:RegisterOptionGroup("shared.movable", {
    controls = NSkin:CreateSharedPlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        return NSkin:NormalizeGridPlacementForEditor(context, values)
    end,
    set = function(context, values)
        return context.setPlacement(context, NSkin:NormalizeSharedPlacementValues(context, values))
    end,
    reset = function(context)
        return context.resetPlacement(context)
    end,
})

NSkin:RegisterOptionGroup("shared.paginationPosition", {
    controls = NSkin:CreateSharedPlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        return NSkin:NormalizeGridPlacementForEditor(context, values)
    end,
    set = function(context, values)
        return context.setPlacement(context,
            NSkin:NormalizeSharedPlacementValues(context, values))
    end,
    reset = function(context) return context.resetPlacement(context) end,
})

NSkin:RegisterOptionGroup("shared.paginationLayout", {
    controls = {
        { type = "CONTROL_PAIR",
            left = { type = "CHECKBOX", key = "separateButtons",
                label = "Move buttons independently" },
            right = { type = "DROPDOWN", key = "textMode", label = "Page text",
                values = { { value = "GROUPED", label = "Grouped",
                        isEnabled = function(context)
                            return context and not context.getPaginationSeparateButtons(context)
                        end },
                    { value = "INDEPENDENT", label = "Independent" },
                    { value = "HIDDEN", label = "Hidden" } } } },
        { type = "RESET", label = "Reset Layout", compactLabel = "Reset" },
    },
    get = function(context)
        return { separateButtons = context.getPaginationSeparateButtons(context),
            textMode = context.getPaginationTextMode(context) }
    end,
    set = function(context, values)
        local changed
        local separate = context.getPaginationSeparateButtons(context)
        if values.separateButtons ~= nil and values.separateButtons ~= separate then
            changed = context.setPaginationSeparateButtons(context,
                values.separateButtons) or changed
            separate = values.separateButtons == true
        end
        local textMode = values.textMode
        if separate and textMode == "GROUPED" then textMode = "INDEPENDENT" end
        if textMode == "GROUPED" or textMode == "INDEPENDENT" or textMode == "HIDDEN" then
            changed = context.setPaginationTextMode(context, textMode) or changed
        end
        return changed == true
    end,
    reset = function(context)
        local changed = context.setPaginationSeparateButtons(context, false)
        changed = context.setPaginationTextMode(context, "GROUPED") or changed
        return changed == true
    end,
})

NSkin:RegisterOptionGroup("shared.searchPosition", {
    controls = NSkin:CreateSharedPlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        return NSkin:NormalizeGridPlacementForEditor(context, values)
    end,
    set = function(context, values)
        return context.setPlacement(context,
            NSkin:NormalizeSharedPlacementValues(context, values))
    end,
    reset = function(context) return context.resetPlacement(context) end,
})

local GLOBAL_VALUE = "__NSKIN_GLOBAL__"
local function FONT_VALUES()
    return NSkin:GetAvailableFontOptions(true)
end
local OUTLINE_VALUES = {
    { value = GLOBAL_VALUE, label = "NSkin Global Outline" },
    { divider = true },
    { value = "", label = "None" },
    { value = "OUTLINE", label = "Outline" },
    { value = "THICKOUTLINE", label = "Thick outline" },
    { value = "MONOCHROME,OUTLINE", label = "Monochrome outline" },
}
local function AddTypographyControls(controls, keys, label, order, color)
    controls[#controls + 1] = {
        type = "TYPOGRAPHY", label = label, order = order,
        sizeKey = keys.size, sizeLabel = "Size", sizeMin = 8, sizeMax = 32,
        fontKey = keys.font, fontLabel = "Font", fontValues = FONT_VALUES,
        outlineKey = keys.outline, outlineLabel = "Outline",
        outlineValues = OUTLINE_VALUES,
        color = color,
    }
end

local function GetTypographyValues(values, style, keys, prefix)
    prefix = prefix or ""
    local fontMode = style[prefix == "" and "fontMode" or prefix .. "FontMode"]
    local sizeMode = style[prefix == "" and "sizeMode" or prefix .. "SizeMode"]
    local outlineMode = style[prefix == "" and "outlineMode" or prefix .. "OutlineMode"]
    values[keys.font] = fontMode == "GLOBAL" and GLOBAL_VALUE
        or style[prefix == "" and "font" or prefix .. "Font"]
    values[keys.size] = sizeMode == "GLOBAL" and GLOBAL_VALUE
        or style[prefix == "" and "textSize" or prefix .. "Size"]
    values[keys.outline] = outlineMode == "GLOBAL" and GLOBAL_VALUE
        or style[prefix == "" and "outline" or prefix .. "Outline"]
end

local SetElementValue

local function GetAppearanceWindowID(context)
    return context.appearanceWindowID
end

local function SetElementTypography(context, stylePath, values, keys, prefix)
    prefix = prefix or ""
    local fontKey = prefix == "" and "font" or prefix .. "Font"
    local sizeKey = prefix == "" and "textSize" or prefix .. "Size"
    local outlineKey = prefix == "" and "outline" or prefix .. "Outline"
    local fontModeKey = prefix == "" and "fontMode" or prefix .. "FontMode"
    local sizeModeKey = prefix == "" and "sizeMode" or prefix .. "SizeMode"
    local outlineModeKey = prefix == "" and "outlineMode" or prefix .. "OutlineMode"
    local changed
    if values[keys.font] ~= nil then
        changed = SetElementValue(context, stylePath .. "." .. fontModeKey,
            values[keys.font] == GLOBAL_VALUE and "GLOBAL" or "CUSTOM") or changed
    end
    if values[keys.size] ~= nil then
        changed = SetElementValue(context, stylePath .. "." .. sizeModeKey,
            values[keys.size] == GLOBAL_VALUE and "GLOBAL" or "CUSTOM") or changed
    end
    if values[keys.outline] ~= nil then
        changed = SetElementValue(context, stylePath .. "." .. outlineModeKey,
            values[keys.outline] == GLOBAL_VALUE and "GLOBAL" or "CUSTOM") or changed
    end
    if values[keys.font] ~= nil and values[keys.font] ~= GLOBAL_VALUE then
        changed = SetElementValue(context, stylePath .. "." .. fontKey,
            values[keys.font]) or changed
    end
    if values[keys.size] ~= nil and values[keys.size] ~= GLOBAL_VALUE then
        changed = SetElementValue(context, stylePath .. "." .. sizeKey,
            values[keys.size]) or changed
    end
    if values[keys.outline] ~= nil and values[keys.outline] ~= GLOBAL_VALUE then
        changed = SetElementValue(context, stylePath .. "." .. outlineKey,
            values[keys.outline]) or changed
    end
    return changed == true
end

SetElementValue = function(context, path, value)
    return NSkin:SetElementAppearanceOverride(
        context.id, GetAppearanceWindowID(context), path, value)
end

local function ResetElementPaths(context, paths)
    return NSkin:ResetElementAppearanceOverrides(context.id, paths)
end

local function CreateBorderGeometryControls(order)
    return { type = "SLIDER_PAIR", order = order, centerReset = true,
        resetTooltip = "Reset border size and padding",
        left = { key = "borderSize", label = "Border size", min = 1,
            max = 4, step = 1, decimals = 0, suffix = " px", resetValue = 1 },
        right = { key = "borderPadding", label = "Border padding", min = -10,
            max = 20, step = 1, decimals = 0, suffix = " px", resetValue = 0 } }
end

local function ResetMappedElementKeys(context, keys, pathsByKey)
    local paths, seen = {}, {}
    for key in pairs(keys) do
        local mapped = pathsByKey[key]
        if type(mapped) == "string" then mapped = { mapped } end
        if type(mapped) == "table" then
            for i = 1, #mapped do
                if not seen[mapped[i]] then
                    seen[mapped[i]] = true
                    paths[#paths + 1] = mapped[i]
                end
            end
        end
    end
    return #paths > 0 and ResetElementPaths(context, paths) or false
end

local function FindControl(controls, controlType, key, label)
    for i = 1, #controls do
        local control = controls[i]
        if control.type == controlType
            and (not key or control.key == key)
            and (not label or control.label == label)
        then
            return control
        end
    end
end

local OPTION_INTERNALS = NSkin._componentOptionInternals or {}
NSkin._componentOptionInternals = OPTION_INTERNALS
OPTION_INTERNALS.CopyColor = CopyColor
OPTION_INTERNALS.Clamp = Clamp
OPTION_INTERNALS.SetColor = SetColor
OPTION_INTERNALS.SetScalar = SetScalar
OPTION_INTERNALS.ResetPaths = ResetPaths
OPTION_INTERNALS.RegisterColorAppearanceGroup = RegisterColorAppearanceGroup
OPTION_INTERNALS.AddTypographyControls = AddTypographyControls
OPTION_INTERNALS.GetTypographyValues = GetTypographyValues
OPTION_INTERNALS.GetAppearanceWindowID = GetAppearanceWindowID
OPTION_INTERNALS.SetElementTypography = SetElementTypography
OPTION_INTERNALS.SetElementValue = SetElementValue
OPTION_INTERNALS.ResetElementPaths = ResetElementPaths
OPTION_INTERNALS.CreateBorderGeometryControls = CreateBorderGeometryControls
OPTION_INTERNALS.ResetMappedElementKeys = ResetMappedElementKeys
OPTION_INTERNALS.FindControl = FindControl
