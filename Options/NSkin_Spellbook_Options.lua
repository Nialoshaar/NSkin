local _, NSkin = ...

local DEFAULT_TEXT_SIZE = 16
local MIN_TEXT_SIZE = 8
local MAX_TEXT_SIZE = 32

local function GetDatabase()
    _G.NSkinDB = _G.NSkinDB or {}
    return _G.NSkinDB
end

function NSkin:GetSpellBookTextSize()
    local size = tonumber(GetDatabase().spellBookTextSize)
    if not size then return DEFAULT_TEXT_SIZE end
    return math.max(MIN_TEXT_SIZE, math.min(MAX_TEXT_SIZE, math.floor(size + 0.5)))
end

function NSkin:SetSpellBookTextSize(size)
    size = tonumber(size)
    if not size then return false end

    size = math.max(MIN_TEXT_SIZE, math.min(MAX_TEXT_SIZE, math.floor(size + 0.5)))
    GetDatabase().spellBookTextSize = size

    local spellBook = self.modules and self.modules.SpellBook
    if spellBook and spellBook.RefreshTextSize then
        spellBook:RefreshTextSize()
    end
    return true
end

NSkin:RegisterOptionsPage("spellbook", "Spellbook", function(optionsFrame)
    local page = CreateFrame("Frame", nil, optionsFrame)
    page:SetAllPoints(optionsFrame)

    local label = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 18, -82)
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
        slider:SetValue(size)
        valueText:SetText(size .. " px")
        self.refreshing = false
    end

    return page
end)
