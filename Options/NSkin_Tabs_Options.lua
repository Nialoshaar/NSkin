local _, NSkin = ...

local MIN_SPACING = -30
local MAX_SPACING = 30
local MIN_OFFSET = -100
local MAX_OFFSET = 100

local function BuildTabsOptions(optionsFrame)
    local page = CreateFrame("Frame", nil, optionsFrame)
    page:SetAllPoints(optionsFrame)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT",
        optionsFrame.NSkinContentLeft or 180, -102)
    title:SetText("Tabs")

    local label = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)
    label:SetText("Spacing")

    local valueText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("LEFT", label, "RIGHT", 10, 0)

    local slider = CreateFrame("Slider", nil, page, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 8, -22)
    slider:SetWidth(280)
    slider:SetMinMaxValues(MIN_SPACING, MAX_SPACING)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)
    if slider.Low then slider.Low:SetText(tostring(MIN_SPACING)) end
    if slider.High then slider.High:SetText(tostring(MAX_SPACING)) end
    if slider.Text then slider.Text:SetText("") end

    local offsetXLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    offsetXLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -8, -28)
    offsetXLabel:SetText("Horizontal offset")
    local offsetXValue = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    offsetXValue:SetPoint("LEFT", offsetXLabel, "RIGHT", 10, 0)
    local offsetXSlider = CreateFrame("Slider", nil, page, "OptionsSliderTemplate")
    offsetXSlider:SetPoint("TOPLEFT", offsetXLabel, "BOTTOMLEFT", 8, -22)
    offsetXSlider:SetWidth(280)
    offsetXSlider:SetMinMaxValues(MIN_OFFSET, MAX_OFFSET)
    offsetXSlider:SetValueStep(1)
    offsetXSlider:SetObeyStepOnDrag(true)
    if offsetXSlider.Low then offsetXSlider.Low:SetText(tostring(MIN_OFFSET)) end
    if offsetXSlider.High then offsetXSlider.High:SetText(tostring(MAX_OFFSET)) end
    if offsetXSlider.Text then offsetXSlider.Text:SetText("") end

    local offsetYLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    offsetYLabel:SetPoint("TOPLEFT", offsetXSlider, "BOTTOMLEFT", -8, -28)
    offsetYLabel:SetText("Vertical offset")
    local offsetYValue = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    offsetYValue:SetPoint("LEFT", offsetYLabel, "RIGHT", 10, 0)
    local offsetYSlider = CreateFrame("Slider", nil, page, "OptionsSliderTemplate")
    offsetYSlider:SetPoint("TOPLEFT", offsetYLabel, "BOTTOMLEFT", 8, -22)
    offsetYSlider:SetWidth(280)
    offsetYSlider:SetMinMaxValues(MIN_OFFSET, MAX_OFFSET)
    offsetYSlider:SetValueStep(1)
    offsetYSlider:SetObeyStepOnDrag(true)
    if offsetYSlider.Low then offsetYSlider.Low:SetText(tostring(MIN_OFFSET)) end
    if offsetYSlider.High then offsetYSlider.High:SetText(tostring(MAX_OFFSET)) end
    if offsetYSlider.Text then offsetYSlider.Text:SetText("") end

    local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    reset:SetSize(110, 24)
    reset:SetPoint("TOPLEFT", offsetYSlider, "BOTTOMLEFT", -8, -28)
    if reset:GetFontString() then reset:GetFontString():SetAlpha(0) end

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        valueText:SetText(value .. " px")
        if not page.refreshing then NSkin:SetTabSpacing(value) end
    end)

    offsetXSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        offsetXValue:SetText(value .. " px")
        if not page.refreshing then NSkin:SetTabOffsetX(value) end
    end)

    offsetYSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        offsetYValue:SetText(value .. " px")
        if not page.refreshing then NSkin:SetTabOffsetY(value) end
    end)

    reset:SetScript("OnClick", function()
        NSkin:ResetTabSpacing()
        NSkin:ResetTabOffsets()
        page:Refresh()
    end)

    function page:ApplyTheme()
        NSkin:SkinFlatButton(reset, "Reset Default", nil, nil, 12)
    end

    function page:Refresh()
        self.refreshing = true
        local spacing = NSkin:GetTabSpacing()
        local offsetX = NSkin:GetTabOffsetX()
        local offsetY = NSkin:GetTabOffsetY()
        slider:SetValue(spacing)
        offsetXSlider:SetValue(offsetX)
        offsetYSlider:SetValue(offsetY)
        valueText:SetText(spacing .. " px")
        offsetXValue:SetText(offsetX .. " px")
        offsetYValue:SetText(offsetY .. " px")
        self.refreshing = false
        self:ApplyTheme()
    end

    return page
end

NSkin:RegisterOptionsPage({
    key = "tabs",
    label = "Tabs",
    group = "shared",
    order = 10,
    builder = BuildTabsOptions,
})
