local _, NSkin = ...

local MIN_SPACING = 0
local MAX_SPACING = 30

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

    local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    reset:SetSize(110, 24)
    reset:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -8, -28)
    if reset:GetFontString() then reset:GetFontString():SetAlpha(0) end

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        valueText:SetText(value .. " px")
        if not page.refreshing then NSkin:SetTabSpacing(value) end
    end)

    reset:SetScript("OnClick", function()
        NSkin:ResetTabSpacing()
        page:Refresh()
    end)

    function page:ApplyTheme()
        NSkin:SkinFlatButton(reset, "Reset Default", nil, nil, 12)
    end

    function page:Refresh()
        self.refreshing = true
        local spacing = NSkin:GetTabSpacing()
        slider:SetValue(spacing)
        valueText:SetText(spacing .. " px")
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
