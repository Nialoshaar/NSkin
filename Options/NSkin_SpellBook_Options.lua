local _, NSkin = ...

local defaults = NSkin.defaultModuleOptions.SpellBook
local WINDOW_ID = "SpellBook"
local WINDOW_ELEMENT_ID = "SpellBook.Window"

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

NSkin:RegisterOptionGroup("spellbook.settings", {
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
        {
            type = "DROPDOWN",
            key = "iconsPerRow",
            label = "Icons disposition",
            values = {
                { value = 2, label = "2 icons per row" },
                { value = 3, label = "3 icons per row" },
                { value = 4, label = "4 icons per row" },
            },
        },
        { type = "RESET", label = "Reset Default", compactLabel = "Reset" },
    },
    get = function()
        return {
            textSize = NSkin:GetSpellBookTextSize(),
            hideAssistant = NSkin:GetSpellBookAssistantHidden(),
            iconsPerRow = NSkin:GetSpellBookIconsPerRow(),
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
        if values.iconsPerRow ~= nil
            and values.iconsPerRow ~= NSkin:GetSpellBookIconsPerRow()
        then
            changed = NSkin:SetSpellBookIconsPerRow(values.iconsPerRow) or changed
        end
        return changed == true
    end,
    reset = function()
        local changed = NSkin:SetSpellBookTextSize(defaults.textSize)
        changed = NSkin:SetSpellBookAssistantHidden(false) or changed
        changed = NSkin:SetSpellBookIconsPerRow(defaults.iconsPerRow) or changed
        return changed == true
    end,
})

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

NSkin:RegisterOptionGroup("spellbook.iconDisposition", {
    controls = {
        { type = "CONTROL_PAIR",
            left = { type = "DROPDOWN", key = "iconsPerRow",
                label = "Icons disposition", values = {
                    { value = 2, label = "2 icons per row" },
                    { value = 3, label = "3 icons per row" },
                    { value = 4, label = "4 icons per row" } } },
            right = { type = "CHECKBOX", key = "matchHeader",
                label = "Match header to background" } },
        { type = "RESET", label = "Reset Layout", compactLabel = "Reset" },
    },
    get = function()
        local style = NSkin:GetAppearanceStyle("window", WINDOW_ID, WINDOW_ELEMENT_ID)
        return { iconsPerRow = NSkin:GetSpellBookIconsPerRow(),
            matchHeader = style.header.matchBackground }
    end,
    set = function(_, values)
        local changed
        if values.iconsPerRow ~= nil
            and values.iconsPerRow ~= NSkin:GetSpellBookIconsPerRow()
        then
            changed = NSkin:SetSpellBookIconsPerRow(values.iconsPerRow)
        end
        if values.matchHeader ~= nil then
            changed = NSkin:SetElementAppearanceOverride(WINDOW_ELEMENT_ID, WINDOW_ID,
                "window.header.matchBackground", values.matchHeader == true) or changed
        end
        return changed == true
    end,
    reset = function()
        local changed = NSkin:SetSpellBookIconsPerRow(defaults.iconsPerRow)
        changed = NSkin:ResetElementAppearanceOverride(WINDOW_ELEMENT_ID,
            "window.header.matchBackground") or changed
        return changed == true
    end,
})

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

    function page:ApplyTheme()
        settingsView:ApplyTheme()
        appearanceView:ApplyTheme()
    end

    function page:Refresh()
        local context = NSkin:IsModuleEnabled("SpellBook") and page or nil
        settingsView:SetContext(context)
        appearanceView:SetContext(context)
        self:ApplyTheme()
    end

    page:SetContentHeight(appearanceContentY + appearanceView:GetHeight() + 20)
    return page
end

NSkin:RegisterOptionsPage({
    module = "SpellBook",
    builder = BuildSpellBookOptions,
})
