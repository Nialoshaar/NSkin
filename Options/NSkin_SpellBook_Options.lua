local _, NSkin = ...

local defaults = NSkin.defaultModuleOptions.SpellBook

NSkin:RegisterOptionGroup("spellbook.window", {
    controls = {
        {
            type = "SLIDER",
            key = "textSize",
            label = "Spell name text size",
            min = defaults.minTextSize,
            max = defaults.maxTextSize,
            step = 1,
            suffix = " px",
        },
        {
            type = "CHECKBOX",
            key = "hideAssistant",
            label = "Hide Single-Button Assistant",
        },
        { type = "RESET", label = "Reset Default", compactLabel = "Reset" },
    },
    get = function()
        return {
            textSize = NSkin:GetSpellBookTextSize(),
            hideAssistant = NSkin:GetSpellBookAssistantHidden(),
        }
    end,
    set = function(_, values)
        local changed
        if values.textSize ~= nil and values.textSize ~= NSkin:GetSpellBookTextSize() then
            changed = NSkin:SetSpellBookTextSize(values.textSize) or changed
        end
        if values.hideAssistant ~= nil
            and values.hideAssistant ~= NSkin:GetSpellBookAssistantHidden()
        then
            changed = NSkin:SetSpellBookAssistantHidden(values.hideAssistant) or changed
        end
        return changed == true
    end,
    reset = function()
        local changed = NSkin:SetSpellBookTextSize(defaults.textSize)
        changed = NSkin:SetSpellBookAssistantHidden(false) or changed
        return changed == true
    end,
})

local function BuildSpellBookOptions(optionsFrame)
    local page = CreateFrame("Frame", nil, optionsFrame)
    page:SetAllPoints(optionsFrame)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT",
        optionsFrame.NSkinContentLeft or 180, -102)
    title:SetText("Spellbook")

    local view = NSkin:CreateOptionGroupView(page, "spellbook.window", "FULL", page)
    view:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)

    function page:ApplyTheme()
        if view.ApplyTheme then view:ApplyTheme() end
    end

    function page:Refresh()
        view:SetContext(NSkin:IsModuleEnabled("SpellBook") and page or nil)
        self:ApplyTheme()
    end

    return page
end

NSkin:RegisterOptionsPage({
    module = "SpellBook",
    builder = BuildSpellBookOptions,
})
