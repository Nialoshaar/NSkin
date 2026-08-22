local _, NSkin = ...

local MIN_TEXT_SIZE = 8
local MAX_TEXT_SIZE = 32

function NSkin:GetSpellBookTextSize()
    local options = self:GetModuleOptions("SpellBook", false)
    local size = options and tonumber(options.textSize)
    if not size then return self.defaultModuleOptions.SpellBook.textSize end
    return math.max(MIN_TEXT_SIZE, math.min(MAX_TEXT_SIZE, math.floor(size + 0.5)))
end

function NSkin:SetSpellBookTextSize(size)
    size = tonumber(size)
    if not size then return false end

    size = math.max(MIN_TEXT_SIZE, math.min(MAX_TEXT_SIZE, math.floor(size + 0.5)))
    if size == self.defaultModuleOptions.SpellBook.textSize then
        local options = self:GetModuleOptions("SpellBook", false)
        if options then
            options.textSize = nil
            local profile = self:GetProfile()
            if not next(options) then profile.moduleOptions.SpellBook = nil end
            if not next(profile.moduleOptions) then profile.moduleOptions = nil end
        end
    else
        self:GetModuleOptions("SpellBook", true).textSize = size
    end

    local spellBook = self.modules and self.modules.SpellBook
    if self:IsModuleEnabled("SpellBook") and spellBook and spellBook.RefreshTextSize then
        spellBook:RefreshTextSize()
    end
    return true
end

NSkin:RegisterOptionsPage("spellbook", "Spellbook", function(optionsFrame)
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
end)
