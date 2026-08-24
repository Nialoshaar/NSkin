local _, NSkin = ...

local function BuildSpellBookOptions(optionsFrame)
    local defaults = NSkin.defaultModuleOptions.SpellBook
    local MIN_TEXT_SIZE = defaults.minTextSize
    local MAX_TEXT_SIZE = defaults.maxTextSize
    local page = CreateFrame("Frame", nil, optionsFrame)
    page:SetAllPoints(optionsFrame)

    local label = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT",
        optionsFrame.NSkinContentLeft or 180, -102)
    label:SetText("Spell name text size")

    local valueText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    valueText:SetPoint("LEFT", label, "RIGHT", 10, 0)

    local slider = CreateFrame("Slider", nil, page, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 8, -22)
    slider:SetWidth(280)
    slider:SetMinMaxValues(MIN_TEXT_SIZE, MAX_TEXT_SIZE)
    slider:SetValueStep(1)
    slider:SetObeyStepOnDrag(true)

    if slider.Low then slider.Low:SetText(tostring(MIN_TEXT_SIZE)) end
    if slider.High then slider.High:SetText(tostring(MAX_TEXT_SIZE)) end
    if slider.Text then slider.Text:SetText("") end

    slider:SetScript("OnValueChanged", function(_, value)
        value = math.floor(value + 0.5)
        valueText:SetText(value .. " px")
        if not page.refreshing then NSkin:SetSpellBookTextSize(value) end
    end)

    function page:Refresh()
        self.refreshing = true
        local size = NSkin:GetSpellBookTextSize()
        local enabled = NSkin:IsModuleEnabled("SpellBook")
        slider:SetValue(size)
        if enabled then slider:Enable() else slider:Disable() end
        slider:SetAlpha(enabled and 1 or 0.40)
        label:SetAlpha(enabled and 1 or 0.40)
        valueText:SetAlpha(enabled and 1 or 0.40)
        valueText:SetText(size .. " px")
        self.refreshing = false
    end

    return page
end

NSkin:RegisterOptionsPage({
    key = "spellbook",
    label = "Spellbook",
    group = "windows",
    order = 10,
    builder = BuildSpellBookOptions,
})
