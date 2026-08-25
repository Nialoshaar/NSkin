local _, NSkin = ...

NSkin:RegisterOptionGroup("tabs.layout", {
    controls = {
        {
            type = "DROPDOWN",
            key = "alignment",
            label = "Alignment",
            values = {
                { value = "LEFT", label = "Left" },
                { value = "CENTER", label = "Center" },
                { value = "RIGHT", label = "Right" },
            },
        },
        {
            type = "SLIDER",
            key = "alongOffset",
            label = "X offset",
            min = -100,
            max = 100,
            step = 1,
            suffix = " px",
            order = 2,
        },
        {
            type = "SLIDER",
            key = "edgeOffset",
            label = "Y offset",
            min = -100,
            max = 100,
            step = 1,
            suffix = " px",
            order = 3,
        },
        {
            type = "SLIDER",
            key = "spacing",
            label = "Spacing",
            min = -30,
            max = 30,
            step = 1,
            suffix = " px",
            order = 4,
        },
        { type = "RESET", label = "Reset Default", compactLabel = "Reset" },
    },
    get = function()
        local values = NSkin:GetBottomTabPlacement()
        values.spacing = NSkin:GetTabSpacing()
        return values
    end,
    set = function(_, values)
        local currentPlacement = NSkin:GetBottomTabPlacement()
        local placementChanged = values.alignment ~= nil
            and (values.alignment ~= currentPlacement.alignment
                or values.alongOffset ~= currentPlacement.alongOffset
                or values.edgeOffset ~= currentPlacement.edgeOffset)
        local spacingChanged = values.spacing ~= nil
            and values.spacing ~= NSkin:GetTabSpacing()
        local changed
        if placementChanged then
            changed = NSkin:SetBottomTabPlacement(values) or changed
        end
        if spacingChanged then
            changed = NSkin:SetTabSpacing(values.spacing) or changed
        end
        return changed == true
    end,
    reset = function()
        local changed = NSkin:ResetBottomTabLayout()
        changed = NSkin:ResetTabSpacing() or changed
        return changed == true
    end,
})

local function BuildTabsOptions(optionsFrame)
    local page = CreateFrame("Frame", nil, optionsFrame)
    page:SetAllPoints(optionsFrame)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT",
        optionsFrame.NSkinContentLeft or 180, -102)
    title:SetText("Tabs")

    local layoutView = NSkin:CreateOptionGroupView(page, "tabs.layout", "FULL", page)
    layoutView:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -18)

    function page:ApplyTheme()
        if layoutView.ApplyTheme then layoutView:ApplyTheme() end
    end

    function page:Refresh()
        layoutView:Refresh()
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
