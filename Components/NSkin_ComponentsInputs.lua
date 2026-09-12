local _, NSkin = ...

local COMPONENT_STATE = "components"
local function ShowFlatButtonGlow(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if data and data.hoverGlow and not data.hoverGlowManaged
        and (not button.IsEnabled or button:IsEnabled())
    then
        data.hoverGlow:Show()
    end
end

local function HideFlatButtonGlow(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if data and data.hoverGlow and not data.hoverGlowManaged then
        data.hoverGlow:Hide()
    end
end

local function EnsureFlatButtonGlowHooks(button, data)
    if data.hoverGlowHooksInstalled or not button.HookScript then return end
    button:HookScript("OnEnter", ShowFlatButtonGlow)
    button:HookScript("OnLeave", HideFlatButtonGlow)
    data.hoverGlowHooksInstalled = true
end

function NSkin:CreateFlatButtonGlow(button, alpha, managed)
    if not button or not button.CreateTexture then return nil end
    local data = self:GetSkinData(button, COMPONENT_STATE)
    data.hoverGlowManaged = managed == true
    if data.hoverGlow then
        self:SetOwnedTextureColor(data.hoverGlow, 1, 1, 1, alpha or 0.10)
        if not data.hoverGlowManaged then
            EnsureFlatButtonGlowHooks(button, data)
        end
        return data.hoverGlow
    end

    local glow = button:CreateTexture(nil, "OVERLAY", nil, -1)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    self:SetOwnedTextureColor(glow, 1, 1, 1, alpha or 0.10)
    glow:Hide()
    data.hoverGlow = glow

    if not data.hoverGlowManaged then EnsureFlatButtonGlowHooks(button, data) end

    return glow
end

function NSkin:SetFlatButtonLabel(button, label, size, offsetX, offsetY)
    if not button or not button.CreateFontString then return nil end

    local data = self:GetSkinData(button, COMPONENT_STATE)
    local text = data.label
    if not text then
        text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        data.label = text
    end

    local resolvedOffsetX, resolvedOffsetY = offsetX or 0, offsetY or 0
    if data.labelOffsetX ~= resolvedOffsetX
        or data.labelOffsetY ~= resolvedOffsetY
    then
        text:ClearAllPoints()
        text:SetPoint("CENTER", button, "CENTER",
            resolvedOffsetX, resolvedOffsetY)
        data.labelOffsetX, data.labelOffsetY = resolvedOffsetX, resolvedOffsetY
    end
    local resolvedLabel = label or ""
    if data.labelText ~= resolvedLabel then
        text:SetText(resolvedLabel)
        data.labelText = resolvedLabel
    end

    if size then
        local font, currentSize, flags = text:GetFont()
        if font and currentSize ~= size then text:SetFont(font, size, flags) end
    end

    if not text.GetAlpha or text:GetAlpha() ~= 1 then text:SetAlpha(1) end
    if not text.IsShown or not text:IsShown() then text:Show() end
    return text
end

function NSkin:SkinFlatButton(button, label, backgroundColor, borderColor,
    labelSize, labelOffsetX, labelOffsetY, preserveTexture)
    if not button or not button.CreateTexture or not button.CreateFontString then return end

    local style = self:GetStyle("button")
    backgroundColor = backgroundColor or style.background
    borderColor = borderColor or self:GetComponentBorderColor("button", style)

    local background = self:GetFlatBackground(button)
    if not background then
        self:HideTextureRegions(button, preserveTexture)
    end

    self:CreateFlatBackground(button, nil, backgroundColor, borderColor)
    self:CreateFlatButtonGlow(button, style.hoverAlpha)
    local text = self:SetFlatButtonLabel(button, label, labelSize, labelOffsetX, labelOffsetY)
    if text then self:SetFontStringColor(text, unpack(style.text)) end
end

local function SuppressActionButtonNativeText(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if not data then return end
    data.actionNativeTexts = data.actionNativeTexts or setmetatable({}, {
        __mode = "k",
    })
    data.actionNativeTextHooks = data.actionNativeTextHooks or setmetatable({}, {
        __mode = "k",
    })
    local function AddNativeText(region)
        if not region or region == data.label
            or not region.GetObjectType
            or region:GetObjectType() ~= "FontString"
        then return end
        data.actionNativeTexts[region] = true
        if not data.actionNativeText then data.actionNativeText = region end
        if not data.actionNativeTextHooks[region] and _G.hooksecurefunc then
            data.actionNativeTextHooks[region] = true
            _G.hooksecurefunc(region, "SetAlpha", function(_, alpha)
                local state = NSkin:GetSkinData(
                    button, COMPONENT_STATE, false)
                if state and region ~= state.label and tonumber(alpha) ~= 0
                    and not state.suppressingActionNativeText
                then
                    state.suppressingActionNativeText = true
                    region:SetAlpha(0)
                    state.suppressingActionNativeText = nil
                end
            end)
        end
    end
    if button.GetFontString then AddNativeText(button:GetFontString()) end
    AddNativeText(button.Text)
    local buttonName = button.GetName and button:GetName()
    if buttonName then AddNativeText(_G[buttonName .. "Text"]) end
    if button.GetRegions then
        for _, region in ipairs({ button:GetRegions() }) do
            AddNativeText(region)
        end
    end
    for region in pairs(data.actionNativeTexts) do
        if region == data.label then
            data.actionNativeTexts[region] = nil
        else
            region:SetAlpha(0)
        end
    end
end

local function RefreshActionButton(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if not data or not data.label then return end
    SuppressActionButtonNativeText(button)
    NSkin:ApplyResolvedTypography(data.label, NSkin:GetStyle("text"))
    local enabled = not button.IsEnabled or button:IsEnabled()
    local color = data.actionTextColor
        or NSkin:GetStyle("text").color
    local disabledAlpha = data.actionDisabledTextAlpha or 0.45
    NSkin:SetFontStringColor(data.label, color[1], color[2], color[3],
        (color[4] or 1) * (enabled and 1 or disabledAlpha))
end

function NSkin:SkinActionButton(button, options)
    if not button then return end
    options = options or {}
    local data = self:GetSkinData(button, COMPONENT_STATE)
    local style = options.style
        or (options.background and options.text and options)
        or self:GetStyle("button")
    data.actionStyle = style
    data.actionTextColor = self:GetResolvedAppearanceColor(style, "text")
    data.actionDisabledTextAlpha = options.disabledTextAlpha
        or style.disabledTextAlpha or 0.45
    local label = button.GetText and button:GetText() or ""
    local nativeText = button.GetFontString and button:GetFontString()
    if nativeText and nativeText.GetObjectType
        and nativeText:GetObjectType() == "FontString"
    then
        local previousLabel = data.label
        if previousLabel and previousLabel ~= nativeText then
            previousLabel:SetAlpha(0)
            previousLabel:Hide()
            data.actionOwnedLabel = previousLabel
        end
        data.label = nativeText
        if data.actionNativeTexts then
            data.actionNativeTexts[nativeText] = nil
        end
        nativeText:SetAlpha(1)
        nativeText:Show()
    end
    self:SkinFlatButton(button, label,
        options.background or style.background,
        options.border or self:GetComponentBorderColor("button", style),
        options.textSize)
    local border = self:GetPixelBorder(button, "NSkinFlatBackgroundBorder")
    self:SetPixelBorderSize(border, 1)
    SuppressActionButtonNativeText(button)
    if data.label then
        self:ApplyResolvedTypography(data.label, self:GetStyle("text"))
    end
    if not data.actionTextHooked and button.SetText and _G.hooksecurefunc then
        _G.hooksecurefunc(button, "SetText", function(_, value)
            local state = NSkin:GetSkinData(button, COMPONENT_STATE, false)
            if state and state.label then state.label:SetText(value or "") end
            SuppressActionButtonNativeText(button)
        end)
        data.actionTextHooked = true
    end
    if not data.actionStateHooked and button.HookScript then
        for _, script in ipairs({
            "OnShow", "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp",
            "OnEnable", "OnDisable",
        }) do
            button:HookScript(script, RefreshActionButton)
        end
        data.actionStateHooked = true
    end
    RefreshActionButton(button)
end

function NSkin:SkinCheckButton(checkButton, options)
    if not checkButton or not checkButton.CreateTexture then return false end
    options = options or {}
    local style = options.style
        or (options.background and options.text and options)
        or self:GetStyle("button")
    local data = self:GetSkinData(checkButton, COMPONENT_STATE)
    local checkedState
    if type(options.getChecked) == "function" then
        local ok, value = pcall(options.getChecked, checkButton)
        if ok and type(value) == "boolean" then checkedState = value end
    end

    if not data.checkButtonArtworkSuppressed then
        self:HideTextureRegions(checkButton)
        data.checkButtonArtworkSuppressed = true
    end
    self:CreateFlatBackground(checkButton, nil,
        options.background or style.background,
        options.border or self:GetComponentBorderColor("button", style))
    self:CreateFlatButtonGlow(checkButton, style.hoverAlpha)

    local checked = data.checkButtonCheckedTexture
    if not checked then
        checked = checkButton:CreateTexture(nil, "ARTWORK")
        checked:SetPoint("TOPLEFT", checkButton, "TOPLEFT", 4, -4)
        checked:SetPoint("BOTTOMRIGHT", checkButton, "BOTTOMRIGHT", -4, 4)
        self:ConfigureOwnedPixelTexture(checked)
        data.checkButtonCheckedTexture = checked
    end
    self:SetOwnedTextureColor(checked, unpack(
        options.checked or self:GetSharedBorderColor()))
    if checkButton.SetCheckedTexture then
        checkButton:SetCheckedTexture(checked)
    elseif checkedState ~= nil then
        checked:SetShown(checkedState)
    else
        checked:Hide()
    end

    local label = options.text or checkButton.Text or checkButton.text
    if label then
        local baseline = options.labelBaselineID
            and self:GetComponentBaseline(options.labelBaselineID)
        local points = baseline and baseline.points
        local point = points and #points == 1 and points[1]
        if point and point[1] == "LEFT" and point[2] == checkButton
            and point[3] == "RIGHT" and label.ClearAllPoints
            and label.SetPoint
        then
            local currentPoint, currentRelativeTo, currentRelativePoint,
                currentX, currentY = label:GetPoint(1)
            local desiredY = tonumber(point[5]) or 0
            if label:GetNumPoints() ~= 1 or currentPoint ~= "LEFT"
                or currentRelativeTo ~= checkButton
                or currentRelativePoint ~= "RIGHT"
                or tonumber(currentX) ~= 5 or tonumber(currentY) ~= desiredY
            then
                label:ClearAllPoints()
                label:SetPoint("LEFT", checkButton, "RIGHT", 5, desiredY)
                self:MarkComponentGeometryModified(
                    options.labelBaselineID, "points", true)
            end
        end
        local textStyle = options.textStyle or self:GetStyle("text")
        self:SkinText(label, textStyle)
    end
    return true
end

local function RefreshDropdownStepper(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    local arrow = data and data.dropdownStepperArrow
    if not arrow then return end
    local enabled = not button.IsEnabled or button:IsEnabled()
    local color = enabled and data.dropdownStepperEnabledColor
        or data.dropdownStepperDisabledColor
    color = color or (enabled and { 1, 1, 1, 1 }
        or { 0.45, 0.45, 0.45, 1 })
    arrow:SetVertexColor(unpack(color))
    arrow:SetShown(not button.IsShown or button:IsShown())
end

local function SkinDropdownStepper(button, rotation, background, border,
    disabledColor)
    if not button then return end
    NSkin:SkinFlatButton(button, "", background, border)
    NSkin:SetPixelBorderSize(NSkin:GetPixelBorder(
        button, "NSkinFlatBackgroundBorder"), 1)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE)
    if not data.dropdownStepperArrow then
        local arrow = button:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(14, 14)
        arrow:SetPoint("CENTER")
        arrow:SetTexture(NSkin.mediaPath .. "angle-small-down.png")
        arrow:SetRotation(rotation)
        NSkin:ConfigureOwnedPixelTexture(arrow)
        data.dropdownStepperArrow = arrow
    end
    data.dropdownStepperEnabledColor = { 1, 1, 1, 1 }
    data.dropdownStepperDisabledColor = disabledColor
    if not data.dropdownStepperStateHooked and button.HookScript then
        button:HookScript("OnEnable", RefreshDropdownStepper)
        button:HookScript("OnDisable", RefreshDropdownStepper)
        button:HookScript("OnShow", RefreshDropdownStepper)
        button:HookScript("OnHide", RefreshDropdownStepper)
        data.dropdownStepperStateHooked = true
    end
    RefreshDropdownStepper(button)
end

local function RefreshDropdownState(dropdown)
    local data = NSkin:GetSkinData(dropdown, COMPONENT_STATE, false)
    if not data or data.refreshingDropdownState then return end
    data.refreshingDropdownState = true
    local enabled = not dropdown.IsEnabled or dropdown:IsEnabled()
    local color = enabled and data.dropdownTextColor
        or data.dropdownDisabledTextColor
    if data.dropdownDisplayText and color then
        NSkin:SetFontStringColor(data.dropdownDisplayText, unpack(color))
    end
    local arrowColor = enabled and data.dropdownArrowColor
        or data.dropdownDisabledTextColor
    if data.dropdownArrow and arrowColor then
        data.dropdownArrow:SetVertexColor(unpack(arrowColor))
    end
    for _, button in ipairs(data.dropdownStepperButtons or {}) do
        RefreshDropdownStepper(button)
    end
    data.refreshingDropdownState = nil
end

local function HookDropdownTextColor(dropdown, text)
    local data = NSkin:GetSkinData(dropdown, COMPONENT_STATE)
    if not text or data.dropdownTextColorHooked == text
        or not _G.hooksecurefunc or type(text.SetTextColor) ~= "function"
    then return end
    data.dropdownTextColorHooked = text
    _G.hooksecurefunc(text, "SetTextColor", function()
        local state = NSkin:GetSkinData(dropdown, COMPONENT_STATE, false)
        if state and not state.refreshingDropdownState then
            RefreshDropdownState(dropdown)
        end
    end)
end

function NSkin:SkinDropdown(dropdown, options)
    if not dropdown then return end
    options = options or {}
    local style = options.style
        or (options.background and options.text and options)
        or self:GetStyle("button")
    self:CreateFlatBackground(dropdown, nil,
        options.background or style.background,
        options.border or self:GetComponentBorderColor("button", style))
    local border = self:GetPixelBorder(dropdown, "NSkinFlatBackgroundBorder")
    self:SetPixelBorderSize(border, 1)
    self:CreateFlatButtonGlow(dropdown, style.hoverAlpha)
    if dropdown.Background then dropdown.Background:SetAlpha(0) end
    if dropdown.Arrow then dropdown.Arrow:SetAlpha(0) end
    if dropdown.NineSlice then dropdown.NineSlice:Hide() end

    local data = self:GetSkinData(dropdown, COMPONENT_STATE)
    if dropdown.Text then
        dropdown.Text:SetAlpha(options.preserveText == false and 0 or 1)
        self:ApplyResolvedTypography(dropdown.Text, self:GetStyle("text"))
    end
    if options.preserveText == false then
        data.dropdownDisplayText = self:SetFlatButtonLabel(
            dropdown, options.label or "", options.textSize)
    else
        data.dropdownDisplayText = dropdown.Text
        if data.label then data.label:Hide() end
    end

    local arrow = data.dropdownArrow
    if not arrow then
        arrow = dropdown:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(14, 14)
        arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
        arrow:SetTexture(self.mediaPath .. "angle-small-down.png")
        self:ConfigureOwnedPixelTexture(arrow)
        data.dropdownArrow = arrow
    end
    arrow:Show()

    data.dropdownTextColor = self:GetResolvedAppearanceColor(style, "text")
        or style.text or { 1, 1, 1, 1 }
    data.dropdownDisabledTextColor = self:GetResolvedAppearanceColor(
        style, "disabledText") or style.disabledText
        or { 0.45, 0.45, 0.45, 1 }
    data.dropdownArrowColor = { 1, 1, 1, 1 }
    HookDropdownTextColor(dropdown, data.dropdownDisplayText)

    data.dropdownStepperButtons = {}
    if options.skinSteppers == true then
        local background = options.background or style.background
        local borderColor = options.border
            or self:GetComponentBorderColor("button", style)
        if options.decrementButton then
            SkinDropdownStepper(options.decrementButton, -math.pi / 2,
                background, borderColor, data.dropdownDisabledTextColor)
            data.dropdownStepperButtons[#data.dropdownStepperButtons + 1] =
                options.decrementButton
        end
        if options.incrementButton then
            SkinDropdownStepper(options.incrementButton, math.pi / 2,
                background, borderColor, data.dropdownDisabledTextColor)
            data.dropdownStepperButtons[#data.dropdownStepperButtons + 1] =
                options.incrementButton
        end
    end

    if not data.dropdownStateHooked and dropdown.HookScript then
        for _, script in ipairs({
            "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp",
            "OnEnable", "OnDisable", "OnShow",
        }) do
            dropdown:HookScript(script, RefreshDropdownState)
        end
        data.dropdownStateHooked = true
    end
    RefreshDropdownState(dropdown)

    data.dropdownMenuStyle = {
        -- Popup menus deliberately use one canonical palette instead of
        -- inheriting per-owner button overrides. This is the established
        -- Adventure Guide expansion-menu treatment shared by every dropdown.
        background = self:GetStyle("window").background,
        border = self:GetSharedBorderColor(),
        textColor = self:GetStyle("button").text,
        textStyle = self:GetStyle("text"),
    }
    self:RegisterDropdownMenuSkin(options.menus)
    self:HookDropdownMenuSkin(dropdown, function()
        local state = NSkin:GetSkinData(dropdown, COMPONENT_STATE, false)
        return state and state.dropdownMenuStyle
    end, options.preserveMenuAnchor)
end

local SLIDER_COMPONENT_STATE = "sliderComponent"

local function RestoreSliderDecoration(state)
    local region = state and state.region
    if not region then return end
    state.applying = true
    if region.SetAlpha and state.alpha ~= nil then region:SetAlpha(state.alpha) end
    if state.shown ~= nil and region.SetShown then region:SetShown(state.shown) end
    state.applying = nil
end

local function ConcealSliderDecoration(data, state)
    local region = state and state.region
    if not data.active or not region or state.applying then return end
    state.applying = true
    if region.SetAlpha then region:SetAlpha(0)
    elseif region.Hide then region:Hide() end
    state.applying = nil
end

local function ApplySliderDecorations(data, declared)
    local active = {}
    for _, region in ipairs(declared) do
        if region then active[region] = true end
    end
    data.nativeDecorationStates = data.nativeDecorationStates or {}
    for region, state in pairs(data.nativeDecorationStates) do
        if state.active and not active[region] then
            state.active = nil
            RestoreSliderDecoration(state)
        end
    end
    for region in pairs(active) do
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
        ConcealSliderDecoration(data, state)
        if not state.hooked and _G.hooksecurefunc then
            local function MaintainDecoration()
                ConcealSliderDecoration(data, state)
            end
            for _, method in ipairs({ "SetAlpha", "SetShown", "Show" }) do
                if type(region[method]) == "function" then
                    pcall(_G.hooksecurefunc, region, method,
                        MaintainDecoration)
                end
            end
            state.hooked = true
        end
    end
end

local function ResolveSliderRatio(slider)
    local minimum, maximum = slider:GetMinMaxValues()
    local range = maximum - minimum
    if range <= 0 then return 0 end
    return math.max(0, math.min(1,
        ((tonumber(slider:GetValue()) or minimum) - minimum) / range))
end

local function RefreshSliderStepper(button)
    local data = NSkin:GetSkinData(button, SLIDER_COMPONENT_STATE, false)
    local arrow = data and data.sliderArrow
    if not arrow then return end
    local enabled = not button.IsEnabled or button:IsEnabled()
    local color = enabled and data.enabledColor or data.disabledColor
    color = color or (enabled and { 1, 1, 1, 1 }
        or { 0.40, 0.40, 0.40, 1 })
    arrow:SetVertexColor(unpack(color))
    arrow:SetShown(not button.IsShown or button:IsShown())
end

local function SkinSliderStepper(button, rotation, enabledColor, disabledColor)
    if not button or not button.CreateTexture then return nil end
    local data = NSkin:GetSkinData(button, SLIDER_COMPONENT_STATE)
    if not data.sliderArrow then
        local arrow = button:CreateTexture(nil, "OVERLAY")
        arrow:SetSize(14, 14)
        arrow:SetPoint("CENTER")
        arrow:SetTexture(NSkin.mediaPath .. "angle-small-down.png")
        arrow:SetRotation(rotation)
        NSkin:ConfigureOwnedPixelTexture(arrow)
        data.sliderArrow = arrow
    end
    data.enabledColor = enabledColor
    data.disabledColor = disabledColor
    if not data.sliderArrowHooked and button.HookScript then
        button:HookScript("OnEnable", RefreshSliderStepper)
        button:HookScript("OnDisable", RefreshSliderStepper)
        button:HookScript("OnShow", RefreshSliderStepper)
        button:HookScript("OnHide", RefreshSliderStepper)
        data.sliderArrowHooked = true
    end
    RefreshSliderStepper(button)
    return data.sliderArrow
end

local function ParseSliderNumber(value)
    if type(value) == "number" then return value end
    local normalized = tostring(value or ""):gsub(",", ".")
    return tonumber(normalized:match("[-+]?%d+%.?%d*"))
end

local function GetSliderValueFormatter(parent, valueSource)
    if not parent or not valueSource or type(parent.formatters) ~= "table"
        or type(parent.Labels) ~= "table"
    then return nil end
    for labelID, label in pairs(parent.Labels) do
        if label == valueSource and type(parent.formatters[labelID]) == "function" then
            return parent.formatters[labelID]
        end
    end
end

local function GetSliderDisplayText(slider, data)
    local source = data.valueSource
    local text = source and source.GetText and source:GetText()
    if text and text ~= "" then return text end
    local value = slider:GetValue()
    return value == math.floor(value) and tostring(math.floor(value))
        or tostring(value)
end

local function ResolveSliderInputValue(slider, data, input)
    local requested = ParseSliderNumber(input)
    if not requested then return slider:GetValue() end
    local minimum, maximum = slider:GetMinMaxValues()
    local formatter = GetSliderValueFormatter(data.sliderParent, data.valueSource)
    local resolved = requested
    if formatter then
        local lowValue = ParseSliderNumber(formatter(minimum))
        local highValue = ParseSliderNumber(formatter(maximum))
        if lowValue and highValue and lowValue ~= highValue then
            local low, high = minimum, maximum
            local ascending = highValue > lowValue
            for _ = 1, 32 do
                local middle = (low + high) / 2
                local displayed = ParseSliderNumber(formatter(middle))
                if not displayed then break end
                if (ascending and displayed < requested)
                    or (not ascending and displayed > requested)
                then
                    low = middle
                else
                    high = middle
                end
            end
            resolved = (low + high) / 2
        end
    end
    resolved = math.max(minimum, math.min(maximum, resolved))
    local step = slider.GetValueStep and slider:GetValueStep()
    if step and step > 0 then
        resolved = minimum + math.floor(
            ((resolved - minimum) / step) + 0.5) * step
        resolved = math.max(minimum, math.min(maximum, resolved))
    end
    return resolved
end

local function CommitSliderValueBox(editBox)
    local slider = editBox and editBox.nskinSlider
    local data = slider and NSkin:GetSkinData(
        slider, SLIDER_COMPONENT_STATE, false)
    if not data then return end
    slider:SetValue(ResolveSliderInputValue(slider, data, editBox:GetText()))
    editBox:ClearFocus()
    editBox:SetText(GetSliderDisplayText(slider, data))
end

local function CancelSliderValueBox(editBox)
    local slider = editBox and editBox.nskinSlider
    local data = slider and NSkin:GetSkinData(
        slider, SLIDER_COMPONENT_STATE, false)
    editBox:ClearFocus()
    if data then editBox:SetText(GetSliderDisplayText(slider, data)) end
end

local function RefreshSliderPresentation(slider)
    local data = NSkin:GetSkinData(slider, SLIDER_COMPONENT_STATE, false)
    if not data or not data.active or not data.style then return end
    local style = data.style
    local horizontal = not slider.GetOrientation
        or slider:GetOrientation() ~= "VERTICAL"
    local trackHeight = math.max(1, tonumber(style.trackHeight) or 4)
    local trackWidth = math.max(1, tonumber(style.trackWidth) or trackHeight)
    local ratio = ResolveSliderRatio(slider)
    local length = horizontal and slider:GetWidth() or slider:GetHeight()
    local fillLength = math.max(0.001, length * ratio)
    local enabled = not slider.IsEnabled or slider:IsEnabled()
    local alpha = enabled and 1 or (tonumber(style.disabledAlpha) or 1)
    local trackColor = enabled and data.trackColor or data.disabledColor
    local fillColor = enabled and data.fillColor or data.disabledColor
    local thumbColor = enabled and data.thumbColor or data.disabledColor

    data.track:ClearAllPoints()
    data.fill:ClearAllPoints()
    for i = 1, #data.fillGlows do data.fillGlows[i]:ClearAllPoints() end
    if horizontal then
        data.track:SetPoint("LEFT", slider, "LEFT")
        data.track:SetPoint("RIGHT", slider, "RIGHT")
        data.track:SetHeight(trackHeight)
        data.fill:SetPoint("LEFT", slider, "LEFT")
        data.fill:SetWidth(fillLength)
        data.fill:SetHeight(trackHeight)
        for i = 1, #data.fillGlows do
            data.fillGlows[i]:SetPoint("LEFT", slider, "LEFT")
            data.fillGlows[i]:SetWidth(fillLength)
            data.fillGlows[i]:SetHeight(data.glowSizes[i])
        end
    else
        data.track:SetPoint("BOTTOM", slider, "BOTTOM")
        data.track:SetPoint("TOP", slider, "TOP")
        data.track:SetWidth(trackWidth)
        data.fill:SetPoint("BOTTOM", slider, "BOTTOM")
        data.fill:SetHeight(fillLength)
        data.fill:SetWidth(trackWidth)
        for i = 1, #data.fillGlows do
            data.fillGlows[i]:SetPoint("BOTTOM", slider, "BOTTOM")
            data.fillGlows[i]:SetHeight(fillLength)
            data.fillGlows[i]:SetWidth(data.glowSizes[i])
        end
    end
    NSkin:SetOwnedTextureColor(data.track, unpack(trackColor))
    NSkin:SetOwnedTextureColor(data.fill, unpack(fillColor))
    for i = 1, #data.fillGlows do
        NSkin:SetOwnedTextureColor(data.fillGlows[i],
            fillColor[1], fillColor[2], fillColor[3],
            enabled and data.glowAlphas[i] or 0)
    end
    if data.thumb then data.thumb:SetColorTexture(unpack(thumbColor)) end
    data.track:SetAlpha(alpha)
    data.fill:SetAlpha(alpha)
    for i = 1, #data.fillGlows do data.fillGlows[i]:SetAlpha(alpha) end
    if data.thumb then data.thumb:SetAlpha(alpha) end
    if data.valueBox then
        data.valueBox:SetEnabled(enabled)
        local valueText = enabled and data.valueTextColor or data.disabledColor
        data.valueBox:SetTextColor(unpack(valueText))
        if not data.valueBox:HasFocus() then
            data.valueBox:SetText(GetSliderDisplayText(slider, data))
        end
    end
    for _, button in ipairs(data.stepperButtons or {}) do
        RefreshSliderStepper(button)
    end
end

local function RestoreSliderThumb(slider, data)
    local baseline = data.thumbBaseline
    if not baseline then return end
    if baseline.atlas and slider:GetThumbTexture().SetAtlas then
        slider:GetThumbTexture():SetAtlas(baseline.atlas, true)
    elseif baseline.texture then
        slider:SetThumbTexture(baseline.texture)
    end
    local thumb = slider:GetThumbTexture()
    if not thumb then return end
    if baseline.width and baseline.height then
        thumb:SetSize(baseline.width, baseline.height)
    end
    if baseline.color then thumb:SetVertexColor(unpack(baseline.color)) end
    if baseline.alpha ~= nil then thumb:SetAlpha(baseline.alpha) end
    if baseline.shown ~= nil then thumb:SetShown(baseline.shown) end
end

function NSkin:SkinSlider(slider, options)
    if not slider or not slider.GetObjectType
        or slider:GetObjectType() ~= "Slider"
        or not slider.GetMinMaxValues or not slider.GetValue
        or (slider.IsForbidden and slider:IsForbidden())
    then return false end
    options = options or {}
    local data = self:GetSkinData(slider, SLIDER_COMPONENT_STATE)
    if options.reset == true then
        data.active = nil
        for _, state in pairs(data.nativeDecorationStates or {}) do
            state.active = nil
            RestoreSliderDecoration(state)
        end
        for _, region in ipairs(data.ownedRegions or {}) do region:Hide() end
        for _, button in ipairs(data.stepperButtons or {}) do
            local buttonData = NSkin:GetSkinData(
                button, SLIDER_COMPONENT_STATE, false)
            if buttonData and buttonData.sliderArrow then
                buttonData.sliderArrow:Hide()
            end
        end
        if data.valueBox then data.valueBox:Hide() end
        RestoreSliderThumb(slider, data)
        return true
    end

    local style = options.style or self:GetStyle("slider")
    if not style then return false end
    data.active = true
    data.style = style
    local parent = slider.GetParent and slider:GetParent()
    local back = parent and parent.Back
    local forward = parent and parent.Forward
    local valueSource = parent and parent.RightText
    local decorations = { slider.Left, slider.Right, slider.Middle }
    if valueSource then decorations[#decorations + 1] = valueSource end
    for _, button in ipairs({ back, forward }) do
        if button and button.GetRegions then
            local buttonData = self:GetSkinData(
                button, SLIDER_COMPONENT_STATE, false)
            local ownedArrow = buttonData and buttonData.sliderArrow
            for _, region in ipairs({ button:GetRegions() }) do
                if region ~= ownedArrow and region.GetObjectType
                    and region:GetObjectType() == "Texture"
                then
                    decorations[#decorations + 1] = region
                end
            end
        end
    end
    for _, region in ipairs(options.nativeDecorationRegions or {}) do
        decorations[#decorations + 1] = region
    end
    ApplySliderDecorations(data, decorations)

    if not data.track then
        data.track = slider:CreateTexture(nil, "BACKGROUND")
        data.fill = slider:CreateTexture(nil, "ARTWORK")
        data.fillGlows = {}
        data.glowSizes = { 12, 8, 4 }
        for i = 1, 3 do
            local glow = slider:CreateTexture(nil, "ARTWORK", nil, -2 + i)
            glow:SetBlendMode("ADD")
            data.fillGlows[i] = glow
        end
        data.ownedRegions = { data.track, data.fill,
            data.fillGlows[1], data.fillGlows[2], data.fillGlows[3] }
        for _, region in ipairs(data.ownedRegions) do
            self:ConfigureOwnedPixelTexture(region)
        end
    end

    local trackColor = self:GetResolvedAppearanceColor(style, "track")
        or style.track
    local fillColor = self:GetResolvedAppearanceColor(style, "fill")
        or style.fill
    local thumbColor = self:GetResolvedAppearanceColor(style, "thumb")
        or style.thumb
    local disabledColor = self:GetResolvedAppearanceColor(style, "disabled")
        or style.disabled or { 0.40, 0.40, 0.40, 1 }
    local valueBackground = self:GetResolvedAppearanceColor(
        style, "valueBackground") or style.valueBackground
        or { 0, 0, 0, 0.75 }
    local valueBorder = self:GetResolvedAppearanceColor(style, "valueBorder")
        or style.valueBorder or { 0.45, 0.45, 0.45, 1 }
    local valueText = self:GetResolvedAppearanceColor(style, "valueText")
        or style.valueText or { 1, 1, 1, 1 }
    data.trackColor = trackColor
    data.fillColor = fillColor
    data.thumbColor = thumbColor
    data.disabledColor = disabledColor
    data.valueTextColor = valueText
    data.valueSource = valueSource
    data.sliderParent = parent
    local glowAlpha = math.max(0, math.min(1,
        tonumber(style.glowAlpha) or 0.34))
    local glowAlphas = { glowAlpha * 0.3, glowAlpha * 0.55, glowAlpha }
    data.glowAlphas = glowAlphas
    for i = 1, #data.fillGlows do
        data.fillGlows[i]:Show()
    end
    data.track:Show()
    data.fill:Show()

    local nativeThumb = slider:GetThumbTexture()
    if nativeThumb and not data.thumbBaseline then
        data.thumbBaseline = {
            atlas = nativeThumb.GetAtlas and nativeThumb:GetAtlas(),
            texture = nativeThumb.GetTexture and nativeThumb:GetTexture(),
            width = nativeThumb:GetWidth(), height = nativeThumb:GetHeight(),
            color = { nativeThumb:GetVertexColor() },
            alpha = nativeThumb:GetAlpha(), shown = nativeThumb:IsShown(),
        }
    end
    slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(math.max(1, tonumber(style.thumbWidth) or 3),
            math.max(1, tonumber(style.thumbHeight) or 14))
        thumb:SetColorTexture(unpack(thumbColor))
        thumb:Show()
        data.thumb = thumb
    end

    local white = { 1, 1, 1, 1 }
    data.stepperButtons = {}
    if back then
        SkinSliderStepper(back, -math.pi / 2, white, disabledColor)
        data.stepperButtons[#data.stepperButtons + 1] = back
    end
    if forward then
        SkinSliderStepper(forward, math.pi / 2, white, disabledColor)
        data.stepperButtons[#data.stepperButtons + 1] = forward
    end


    if valueSource and parent and parent.CreateFontString then
        if not data.valueBox then
            local valueBox = CreateFrame("EditBox", nil, parent)
            valueBox:SetSize(42, 22)
            valueBox:SetPoint("LEFT", slider, "RIGHT", 20, 0)
            valueBox:SetAutoFocus(false)
            valueBox:SetJustifyH("CENTER")
            valueBox:SetFontObject(GameFontHighlightSmall)
            valueBox:SetTextInsets(4, 4, 0, 0)
            valueBox:SetScript("OnEditFocusGained", function(box)
                box:HighlightText()
            end)
            valueBox:SetScript("OnEnterPressed", CommitSliderValueBox)
            valueBox:SetScript("OnEscapePressed", CancelSliderValueBox)
            valueBox:SetScript("OnEditFocusLost", CancelSliderValueBox)
            valueBox.nskinSlider = slider
            data.valueBox = valueBox
        end
        self:CreateFlatBackground(data.valueBox, "NSkinSliderValue",
            valueBackground, valueBorder)
        self:SetPixelBorderSize(self:GetPixelBorder(
            data.valueBox, "NSkinSliderValueBorder"), 1)
        data.valueBox:Show()
    end

    if not data.hooked and slider.HookScript then
        for _, script in ipairs({
            "OnValueChanged", "OnSizeChanged", "OnShow", "OnEnable", "OnDisable",
        }) do
            slider:HookScript(script, RefreshSliderPresentation)
        end
        data.hooked = true
    end
    RefreshSliderPresentation(slider)
    return true
end

local function RefreshEditBoxState(editBox)
    local data = NSkin:GetSkinData(editBox, COMPONENT_STATE, false)
    if not data or not data.editBoxStyle then return end
    local style = data.editBoxStyle
    local surface = data.editBoxSurface or editBox
    local enabled = not editBox.IsEnabled or editBox:IsEnabled()
    local focused = enabled and editBox.HasFocus and editBox:HasFocus()
    local backgroundKey = enabled and (focused and "focusBackground" or "background")
        or "disabledBackground"
    local borderKey = enabled and (focused and "focusBorder" or "border")
        or "disabledBorder"
    local textKey = enabled and "text" or "disabledText"
    local background = NSkin:GetResolvedAppearanceColor(style, backgroundKey)
        or NSkin:GetResolvedAppearanceColor(style, "background")
    local border = borderKey == "border" and data.editBoxBorder
        or NSkin:GetResolvedAppearanceColor(style, borderKey)
        or data.editBoxBorder or NSkin:GetResolvedAppearanceColor(style, "border")
    NSkin:CreateFlatBackground(surface, nil, background, border)
    if data.editBoxManageTextColor ~= false and editBox.SetTextColor then
        local textColor = NSkin:GetResolvedAppearanceColor(style, textKey)
            or NSkin:GetResolvedAppearanceColor(style, "text")
        if textColor then NSkin:SetFontStringColor(editBox, unpack(textColor)) end
    end
end

function NSkin:SkinEditBox(editBox, options)
    if not editBox then return end
    options = options or {}

    local editData = self:GetSkinData(editBox, COMPONENT_STATE)
    local surface = options.surface
    if not surface or not surface.CreateTexture then surface = editBox end
    if not editData.editBoxBaselineID then
        editData.editBoxBaselineID = options.baselineID
            or "EditBox:" .. tostring(editBox)
        self:CaptureComponentBaseline(editData.editBoxBaselineID, editBox, {
            size = true, textInsets = true,
        })
    end
    if not self:GetFlatBackground(surface) then
        self:HideTextureRegions(editBox, options.preserveTexture)
    end
    local style = options.style or self:GetStyle("editBox")
    if not style then return end
    editData.editBoxStyle = style
    editData.editBoxBorder = options.border
    editData.editBoxSurface = surface
    editData.editBoxManageTextColor = options.manageTextColor ~= false
    local configuredWidth, configuredHeight = tonumber(style.width), tonumber(style.height)
    configuredWidth = configuredWidth and configuredWidth > 0 and configuredWidth or nil
    configuredHeight = configuredHeight and configuredHeight > 0 and configuredHeight or nil
    if configuredWidth or configuredHeight then
        self:MarkComponentGeometryModified(editData.editBoxBaselineID, "size", true)
        if not editData.editBoxOriginalSize then
            editData.editBoxOriginalSize = { editBox:GetWidth(), editBox:GetHeight() }
        end
        local originalSize = editData.editBoxOriginalSize
        local width = configuredWidth or originalSize[1]
        local height = configuredHeight or originalSize[2]
        if editBox:GetWidth() ~= width or editBox:GetHeight() ~= height then
            editBox:SetSize(width, height)
        end
    elseif editData.editBoxOriginalSize then
        self:RestoreComponentBaseline(editData.editBoxBaselineID, { size = true })
        editData.editBoxOriginalSize = nil
    end
    RefreshEditBoxState(editBox)
    local editBorder = self:GetPixelBorder(
        surface, "NSkinFlatBackgroundBorder")
    self:SetPixelBorderSize(editBorder, style.borderSize or 1)
    self:SetPixelBorderPadding(editBorder, style.borderPadding or 0)
    self:ApplyResolvedTypography(editBox, style)
    if editBox.GetTextInsets and editBox.SetTextInsets then
        local hasInsetOverride = style.textOffsetX ~= nil
            or style.textOffsetY ~= nil
        if hasInsetOverride then
            local baseline = self:GetComponentBaseline(editData.editBoxBaselineID)
            local insets = baseline and baseline.textInsets
            if insets then
                local offsetX = style.textOffsetX or 0
                local offsetY = style.textOffsetY or 0
                self:MarkComponentGeometryModified(
                    editData.editBoxBaselineID, "textInsets", true)
                local left = (insets[1] or 0) + offsetX
                local right = (insets[2] or 0) - offsetX
                local top = (insets[3] or 0) - offsetY
                local bottom = (insets[4] or 0) + offsetY
                local currentLeft, currentRight, currentTop, currentBottom =
                    editBox:GetTextInsets()
                if currentLeft ~= left or currentRight ~= right
                    or currentTop ~= top or currentBottom ~= bottom
                then
                    editBox:SetTextInsets(left, right, top, bottom)
                end
            end
        else
            self:RestoreComponentBaseline(
                editData.editBoxBaselineID, { textInsets = true })
        end
    end
    local instructions = editBox.Instructions or editBox.instructions
    if instructions then
        local data = self:GetSkinData(instructions, COMPONENT_STATE)
        if not data.placeholderBaselineID then
            data.placeholderBaselineID =
                "EditBoxPlaceholder:" .. tostring(instructions)
            self:CaptureComponentBaseline(
                data.placeholderBaselineID, instructions, {
                points = true,
            })
        end
        local placeholderColor = self:GetResolvedAppearanceColor(
            style, "placeholderText")
        if placeholderColor and instructions.SetTextColor then
            self:SetFontStringColor(instructions, unpack(placeholderColor))
        end
        self:ApplyResolvedTypography(instructions, style, "placeholder")
        local hasPlaceholderOverride = style.placeholderOffsetX ~= nil
            or style.placeholderOffsetY ~= nil
        if hasPlaceholderOverride then
            local baseline = self:GetComponentBaseline(
                data.placeholderBaselineID)
            local points = baseline and baseline.points
            if points then
                self:MarkComponentGeometryModified(
                    data.placeholderBaselineID, "points", true)
                instructions:ClearAllPoints()
                for i = 1, #points do
                    local point = points[i]
                    instructions:SetPoint(point[1], point[2], point[3],
                        (point[4] or 0) + (style.placeholderOffsetX or 0),
                        (point[5] or 0) + (style.placeholderOffsetY or 0))
                end
            end
        else
            self:RestoreComponentBaseline(
                data.placeholderBaselineID, { points = true })
        end
    end
    if not editData.editBoxStateHooked and editBox.HookScript then
        editBox:HookScript("OnEditFocusGained", RefreshEditBoxState)
        editBox:HookScript("OnEditFocusLost", RefreshEditBoxState)
        if _G.hooksecurefunc then
            if type(editBox.Enable) == "function" then
                pcall(_G.hooksecurefunc,
                    editBox, "Enable", RefreshEditBoxState)
            end
            if type(editBox.Disable) == "function" then
                pcall(_G.hooksecurefunc,
                    editBox, "Disable", RefreshEditBoxState)
            end
            if type(editBox.SetEnabled) == "function" then
                pcall(_G.hooksecurefunc,
                    editBox, "SetEnabled", RefreshEditBoxState)
            end
        end
        editData.editBoxStateHooked = true
    end
    local spinnerStyle = options.spinnerButtonStyle or self:GetStyle("button")
    local spinnerBorder = options.spinnerButtonBorder
        or self:GetComponentBorderColor("button", spinnerStyle)
    for _, definition in ipairs({
        { button = options.decrementButton, glyph = "minimize" },
        { button = options.incrementButton, glyph = "maximize" },
    }) do
        if definition.button then
            self:SkinWindowHeaderButton(definition.button, {
                glyph = definition.glyph,
            }, {
                style = spinnerStyle,
                border = spinnerBorder,
            })
        end
    end
end

function NSkin:SkinSearchBox(searchBox, style, borderColor)
    if not searchBox then return end
    local searchIcon = searchBox.SearchIcon or searchBox.searchIcon
    local searchData = self:GetSkinData(searchBox, COMPONENT_STATE)
    searchData.baselineID = searchData.baselineID
        or "SearchBox:" .. tostring(searchBox)
    style = style or self:GetStyle("searchBox")
    self:SkinEditBox(searchBox, {
        style = style,
        border = borderColor or self:GetResolvedAppearanceColor(style, "border")
            or self:GetComponentBorderColor("searchBox", style),
        baselineID = searchData.baselineID,
        preserveTexture = searchIcon,
    })
    if searchIcon then searchIcon:Show() end
end

local COMPONENT_INTERNALS = NSkin._componentInternals
local skinningElements = COMPONENT_INTERNALS.skinningElements
local SUPPRESS_NOTIFICATION = COMPONENT_INTERNALS.SUPPRESS_NOTIFICATION
local CopyPlacement = COMPONENT_INTERNALS.CopyPlacement
local GetSavedMovablePlacement = COMPONENT_INTERNALS.GetSavedMovablePlacement
local GetControllerState = COMPONENT_INTERNALS.GetControllerState
local PruneControllerState = COMPONENT_INTERNALS.PruneControllerState
local RegisterControllerElement = COMPONENT_INTERNALS.RegisterControllerElement
function NSkin:RegisterAccessoryGroup(definition)
    if type(definition) ~= "table" or type(definition.module) ~= "string"
        or type(definition.appearanceWindowID) ~= "string"
        or definition.appearanceWindowID == ""
        or not self:GetAppearanceScope(definition.appearanceWindowID)
        or not definition.window or not definition.primary or not definition.accessory
        or type(definition.ids) ~= "table" or not definition.ids.primary
        or not definition.ids.accessory or type(definition.anchorGrouped) ~= "function"
    then return end
    local controller = { module = definition.module,
        appearanceWindowID = definition.appearanceWindowID,
        window = definition.window,
        visibilityFrame = definition.visibilityFrame,
        id = definition.id or definition.ids.primary, ids = definition.ids,
        primary = definition.primary, accessory = definition.accessory }
    local legacyOptionKey = definition.legacyOptionKey
    function controller:GetMode()
        local state, options = GetControllerState(self.module, self.id, false)
        if state and state.mode then return state.mode end
        return legacyOptionKey and options and options[legacyOptionKey] or "GROUPED"
    end
    function controller:IsVisible()
        local target = self.visibilityFrame or self.primary:GetParent()
        return not target or not target.IsVisible or target:IsVisible()
    end
    function controller:AnchorGrouped()
        if definition.anchorGrouped(self.primary, self.accessory) ~= true then
            return false
        end
        -- Grouping replaces the accessory's Blizzard anchor. Track that
        -- mutation so placement and full-customization resets restore it
        -- before restoring the primary control that may anchor back to it.
        NSkin:MarkComponentGeometryModified(self.ids.accessory, "points", true)
        return true
    end
    function controller:ApplyPrimary(element, placement, applyOptions)
        if self:GetMode() == "GROUPED"
            and (placement.relativeTo == self.ids.accessory
                or placement.relativeTo == self.ids.primary)
        then
            placement = CopyPlacement(definition.primaryPlacement)
        end
        if not NSkin:LayoutWindowElement(element, placement, SUPPRESS_NOTIFICATION) then
            return false
        end
        if self:GetMode() == "GROUPED" then self:AnchorGrouped() end
        if not (applyOptions and applyOptions.suppressNotify) then
            NSkin:NotifySkinningElementBoundsChanged(element.id)
        end
        return true
    end
    function controller:NotifyBounds()
        NSkin:NotifySkinningElementBoundsChanged(self.ids.primary)
        NSkin:NotifySkinningElementBoundsChanged(self.ids.accessory)
    end
    function controller:RefreshAppearance(element)
        if element then return NSkin:RefreshTypedElementAppearance(element) end
        NSkin:SkinTypedElement("SEARCH_GROUP", {
            id = self.ids.primary,
            target = self.primary,
            appearanceWindowID = self.appearanceWindowID,
            skinOptions = self.primarySkinOptions,
        })
        NSkin:SkinTypedElement("SEARCH_ACCESSORY", {
            id = self.ids.accessory,
            target = self.accessory,
            appearanceWindowID = self.appearanceWindowID,
            skinOptions = self.accessorySkinOptions,
            menus = self.accessoryMenus,
        })
        return true
    end
    function controller:RefreshLayout()
        local mode = self:GetMode()
        self.accessory:SetShown(mode ~= "HIDDEN")
        if mode == "GROUPED" then
            local primaryElement = skinningElements[self.ids.primary]
            local saved = primaryElement and GetSavedMovablePlacement(primaryElement)
            if saved then
                primaryElement.applyPlacement(primaryElement, saved, SUPPRESS_NOTIFICATION)
            else
                NSkin:RestoreMovableElementOriginal(self.ids.accessory, true)
                NSkin:RestoreMovableElementOriginal(self.ids.primary, true)
            end
        elseif mode == "INDEPENDENT" then
            local element = skinningElements[self.ids.accessory]
            local saved = element and GetSavedMovablePlacement(element)
            if saved then element.applyPlacement(element, saved, SUPPRESS_NOTIFICATION) end
        end
        self:NotifyBounds()
        return true
    end
    function controller:Refresh()
        self:RefreshAppearance()
        return self:RefreshLayout()
    end
    function controller:UpdateWatcher()
        local state, options = GetControllerState(self.module, self.id, false)
        local active = state and next(state) ~= nil
        if not active and legacyOptionKey and options then active = options[legacyOptionKey] end
        if active and not self.watcher then
            self.watcher = CreateFrame("Frame", nil,
                definition.visibilityFrame or self.primary:GetParent() or self.window)
            self.watcher:Hide()
            self.watcher:SetScript("OnShow", function() self:Refresh() end)
        end
        if self.watcher then self.watcher:SetShown(not not active) end
    end
    function controller:SetMode(mode)
        if mode ~= "GROUPED" and mode ~= "INDEPENDENT" and mode ~= "HIDDEN" then
            return false
        end
        local state, options = GetControllerState(self.module, self.id, true)
        state.mode = mode == "GROUPED" and nil or mode
        if legacyOptionKey then options[legacyOptionKey] = nil end
        PruneControllerState(self.module, options, self.id)
        self:UpdateWatcher()
        self:Refresh()
        return true
    end

    local elementDefinitions = definition.elements or {}
    local primaryDefinition = elementDefinitions.primary or {}
    local accessoryDefinition = elementDefinitions.accessory or {}
    controller.primarySkinOptions = primaryDefinition.skinOptions
        or definition.primarySkinOptions
    controller.accessorySkinOptions = accessoryDefinition.skinOptions
        or definition.accessorySkinOptions
    controller.accessoryMenus = accessoryDefinition.menus
        or definition.accessoryMenus
    controller.groupedHighlightRegions = { controller.primary, controller.accessory }
    controller.primaryHighlightRegion = { controller.primary }
    local primaryEditorOptions = NSkin:CreateEditorOptionsPreset(
        "SEARCH_GROUP", definition.extraEditorOptions)
    local accessoryEditorOptions = NSkin:CreateEditorOptionsPreset(
        "SEARCH_ACCESSORY", definition.accessoryExtraEditorOptions)
    local accessory = RegisterControllerElement(controller, definition.ids.accessory,
        definition.accessoryLabel or "Search accessory", definition.accessory, {
            kind = "SEARCH_ACCESSORY",
            editorOptions = accessoryEditorOptions,
            defaultPlacement = accessoryDefinition.defaultPlacement
                or definition.accessoryPlacement,
            priority = accessoryDefinition.priority or definition.accessoryPriority or 90,
            isEditable = function()
                return controller:IsVisible() and controller:GetMode() == "INDEPENDENT"
            end,
            applyPlacement = accessoryDefinition.applyPlacement,
            livePreview = accessoryDefinition.livePreview,
            draggable = accessoryDefinition.draggable,
            skinOptions = controller.accessorySkinOptions,
            menus = controller.accessoryMenus,
        })
    local primary = RegisterControllerElement(controller, definition.ids.primary,
        definition.primaryLabel or "Search", definition.primary, {
            kind = "SEARCH_GROUP",
            editorOptions = primaryEditorOptions,
            defaultPlacement = primaryDefinition.defaultPlacement or definition.primaryPlacement,
            priority = primaryDefinition.priority or definition.primaryPriority or 80,
            snapTarget = definition.snapTarget,
            isEditable = function() return controller:IsVisible() end,
            applyPlacement = function(element, placement, applyOptions)
                if primaryDefinition.applyPlacement then
                    if not primaryDefinition.applyPlacement(element, placement,
                        applyOptions)
                    then return false end
                    if controller:GetMode() == "GROUPED" then controller:AnchorGrouped() end
                    if not (applyOptions and applyOptions.suppressNotify) then
                        NSkin:NotifySkinningElementBoundsChanged(element.id)
                    end
                    return true
                end
                return controller:ApplyPrimary(element, placement, applyOptions)
            end,
            livePreview = primaryDefinition.livePreview,
            draggable = primaryDefinition.draggable,
            skinOptions = controller.primarySkinOptions,
            highlightRegions = function()
                return controller:GetMode() == "GROUPED"
                    and controller.groupedHighlightRegions
                    or controller.primaryHighlightRegion
            end,
        })
    for _, element in ipairs({ primary, accessory }) do
        if element then
            element.refreshAppearance = function(_, current)
                return controller:RefreshAppearance(current)
            end
            element.refreshLayout = function(_, current)
                if not controller:RefreshAppearance(current) then return false end
                return controller:RefreshLayout()
            end
            element.getSearchAccessoryMode = function() return controller:GetMode() end
            element.setSearchAccessoryMode = function(_, mode) return controller:SetMode(mode) end
        end
    end
    if primary then
        local resetPrimary = primary.resetPlacement
        primary.resetPlacement = function(element)
            NSkin:RestoreMovableElementOriginal(controller.ids.accessory, true)
            local reset = resetPrimary(element)
            controller:Refresh()
            return reset
        end
    end
    controller:UpdateWatcher()
    controller:Refresh()
    return controller
end
