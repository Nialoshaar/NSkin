local _, NSkin = ...

local defaults = NSkin.defaultModuleOptions.SpellBook

local function PlacementControls(extra)
    local controls = {
        { type = "DROPDOWN", key = "edge", label = "Window edge", order = 1,
            values = { { value = "TOP", label = "Top" }, { value = "BOTTOM", label = "Bottom" } } },
        { type = "DROPDOWN", key = "side", label = "Border side", order = 2,
            values = { { value = "INSIDE", label = "Inside" }, { value = "OUTSIDE", label = "Outside" } } },
        { type = "DROPDOWN", key = "alignment", label = "Alignment", order = 3,
            values = { { value = "LEFT", label = "Left" }, { value = "CENTER", label = "Center" },
                { value = "RIGHT", label = "Right" } } },
        { type = "SLIDER", key = "alongOffset", label = "X offset", min = -2000, max = 2000,
            step = 0.1, decimals = 1, suffix = " px", order = 4 },
        { type = "SLIDER", key = "edgeOffset", label = "Y offset", min = -2000, max = 2000,
            step = 0.1, decimals = 1, suffix = " px", order = 5 },
    }
    for i = 1, #(extra or {}) do controls[#controls + 1] = extra[i] end
    controls[#controls + 1] = { type = "RESET", label = "Reset Default", compactLabel = "Reset" }
    return controls
end

local function NormalizePlacementValues(context, values)
    local current = context.getPlacement(context)
    local semanticChanged = values.edge ~= current.edge
        or values.side ~= current.side
        or values.alignment ~= current.alignment
    if current.mode == "GRID" and semanticChanged then
        values.mode, values.point, values.relativePoint = nil, nil, nil
        values.x, values.y = nil, nil
        values.alongOffset, values.edgeOffset = 0, 0
    elseif values.mode == "GRID" then
        values.x, values.y = values.alongOffset, values.edgeOffset
    end
    return values
end

NSkin:RegisterOptionGroup("spellbook.movable", {
    controls = PlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        if values.mode == "GRID" then
            values.alongOffset, values.edgeOffset = values.x or 0, values.y or 0
        end
        return values
    end,
    set = function(context, values)
        return context.setPlacement(context, NormalizePlacementValues(context, values))
    end,
    reset = function(context) return context.resetPlacement(context) end,
})

NSkin:RegisterOptionGroup("spellbook.search", {
    controls = PlacementControls({
        { type = "DROPDOWN", key = "cogMode", label = "Search cog", order = 6,
            values = { { value = "GROUPED", label = "Grouped" },
                { value = "INDEPENDENT", label = "Independent" },
                { value = "HIDDEN", label = "Hidden" } } },
    }),
    get = function(context)
        local values = context.getPlacement(context)
        if values.mode == "GRID" then
            values.alongOffset, values.edgeOffset = values.x or 0, values.y or 0
        end
        values.cogMode = NSkin:GetSpellBookSearchCogMode()
        return values
    end,
    set = function(context, values)
        NormalizePlacementValues(context, values)
        local changed = context.setPlacement(context, values)
        if values.cogMode ~= NSkin:GetSpellBookSearchCogMode() then
            changed = NSkin:SetSpellBookSearchCogMode(values.cogMode) or changed
        end
        return changed == true
    end,
    reset = function(context)
        local changed = context.resetPlacement(context)
        changed = NSkin:SetSpellBookSearchCogMode("GROUPED") or changed
        return changed == true
    end,
})

NSkin:RegisterOptionGroup("spellbook.pagination", {
    controls = PlacementControls({
        { type = "CHECKBOX", key = "separateButtons", label = "Move buttons independently", order = 6 },
        { type = "DROPDOWN", key = "textMode", label = "Page text", order = 7,
            values = { { value = "GROUPED", label = "Grouped" },
                { value = "INDEPENDENT", label = "Independent" },
                { value = "HIDDEN", label = "Hidden" } } },
    }),
    get = function(context)
        local values = context.getPlacement(context)
        if values.mode == "GRID" then
            values.alongOffset, values.edgeOffset = values.x or 0, values.y or 0
        end
        values.separateButtons = NSkin:GetSpellBookPaginationSeparateButtons()
        values.textMode = NSkin:GetSpellBookPaginationTextMode()
        return values
    end,
    set = function(context, values)
        NormalizePlacementValues(context, values)
        local changed = context.setPlacement(context, values)
        if values.separateButtons ~= NSkin:GetSpellBookPaginationSeparateButtons() then
            changed = NSkin:SetSpellBookPaginationSeparateButtons(values.separateButtons) or changed
        end
        if values.textMode ~= NSkin:GetSpellBookPaginationTextMode() then
            changed = NSkin:SetSpellBookPaginationTextMode(values.textMode) or changed
        end
        return changed == true
    end,
    reset = function(context)
        local changed = context.resetPlacement(context)
        changed = NSkin:SetSpellBookPaginationSeparateButtons(false) or changed
        changed = NSkin:SetSpellBookPaginationTextMode("GROUPED") or changed
        return changed == true
    end,
})

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
