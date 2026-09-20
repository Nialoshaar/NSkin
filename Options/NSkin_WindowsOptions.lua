local _, NSkin = ...

local WINDOW_ID = "PlayerSpells.SpellBook"

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

NSkin:RegisterOptionGroup("encounterJournal.journeyCardsBackground", {
    controls = {
        {
            type = "DROPDOWN",
            key = "backgroundMode",
            label = "Background",
            values = {
                { value = "DEFAULT", label = "Blizzard default" },
                { value = "IMAGES", label = "Images" },
                { value = "BLACK", label = "Black" },
            },
        },
        { type = "RESET", label = "Reset Background", compactLabel = "Reset" },
    },
    get = function()
        return { backgroundMode = NSkin:GetJourneyCardsBackgroundMode() }
    end,
    set = function(_, values)
        return NSkin:SetJourneyCardsBackgroundMode(values.backgroundMode)
    end,
    reset = function()
        return NSkin:ResetJourneyCardsBackgroundMode()
    end,
})

local dispositionOptions = {
    controllerID = "SpellBook.Spells.Disposition",
    label = "Icons disposition",
    formatChoice = function(count) return count .. " icons per row" end,
}
NSkin:RegisterColumnDispositionOptionGroup("spellbook.settings",
    dispositionOptions)

NSkin:RegisterOptionGroup("spellbook.appearance", {
    controls = {
        { type = "COLOR", key = "searchBackground", label = "Search background" },
        { type = "SLIDER", key = "searchOpacity", label = "Background opacity",
            min = 0, max = 1, step = 0.05, decimals = 2 },
    },
    get = function()
        local style = NSkin:GetAppearanceStyle("searchBox", WINDOW_ID)
        return { searchBackground = CopyColor(style.background),
            searchOpacity = style.background[4] or 1 }
    end,
    set = function(_, values)
        local color = CopyColor(values.searchBackground)
        color[4] = values.searchOpacity
        return NSkin:SetWindowAppearanceOverride(
            WINDOW_ID, "searchBox.background", color
        )
    end,
    reset = function()
        return NSkin:ResetWindowAppearanceOverride(WINDOW_ID, "searchBox.background")
    end,
})

NSkin:RegisterColumnDispositionOptionGroup("spellbook.iconDisposition",
    dispositionOptions)

local function BuildSpellBookOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Spellbook")

    NSkin:CreateOptionsSection(page, "Module settings", 38)
    local settingsView = NSkin:CreateOptionGroupView(
        page, "spellbook.settings", "FULL", page
    )
    settingsView:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -70)
    local appearanceY = 90 + settingsView:GetHeight()
    local _, appearanceContentY = NSkin:CreateOptionsSection(
        page, "Appearance override", appearanceY
    )
    local appearanceView = NSkin:CreateOptionGroupView(
        page, "spellbook.appearance", "FULL", page
    )
    appearanceView:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -appearanceContentY)

    function page:ApplyAppearance()
        settingsView:ApplyAppearance()
        appearanceView:ApplyAppearance()
    end

    function page:Refresh()
        local context = NSkin:IsModuleEnabled("SpellBook") and page or nil
        settingsView:SetContext(context)
        appearanceView:SetContext(context)
        self:ApplyAppearance()
    end

    page:SetContentHeight(appearanceContentY + appearanceView:GetHeight() + 20)
    return page
end

-- Spellbook customization is intentionally docked-editor only. The main
-- options window still exposes module enablement through its module row.
