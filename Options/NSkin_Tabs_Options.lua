local _, NSkin = ...

local function CreateTabControls(includeSpacing)
    local controls = {
        { type = "SLIDER_PAIR", order = 1, centerReset = true,
            resetGroup = true,
            resetTooltip = "Reset X and Y offsets",
            left = { key = "alongOffset", label = "X offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" },
            right = { key = "edgeOffset", label = "Y offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" } },
    }
    if includeSpacing then
        controls[#controls + 1] = {
            type = "SLIDER",
            key = "spacing",
            label = "Spacing",
            min = -30,
            max = 30,
            step = 1,
            suffix = " px",
            order = 6,
        }
    end
    if includeSpacing then
        controls[#controls + 1] = {
            type = "RESET", label = "Reset Default", compactLabel = "Reset",
        }
    end
    return controls
end

local function GetValues(context, includeSpacing)
    local values = NSkin:GetTabGroupPlacement(context.id)
    NSkin:NormalizeGridPlacementForEditor(context, values)
    if includeSpacing then values.spacing = NSkin:GetTabSpacing() end
    return values
end

local function SetValues(context, values, includeSpacing)
    local currentPlacement = NSkin:GetTabGroupPlacement(context.id)
    if values.mode == "GRID" then
        values.x = tonumber(values.alongOffset) or values.x or 0
        values.y = tonumber(values.edgeOffset) or values.y or 0
    end
    local placementChanged = values.alignment ~= nil
        and (values.mode ~= currentPlacement.mode
            or values.x ~= currentPlacement.x
            or values.y ~= currentPlacement.y
            or values.relativeTo ~= currentPlacement.relativeTo
            or values.point ~= currentPlacement.point
            or values.relativePoint ~= currentPlacement.relativePoint
            or values.edge ~= currentPlacement.edge
            or values.side ~= currentPlacement.side
            or values.alignment ~= currentPlacement.alignment
            or values.alongOffset ~= currentPlacement.alongOffset
            or values.edgeOffset ~= currentPlacement.edgeOffset)
    local spacingChanged = includeSpacing and values.spacing ~= nil
        and values.spacing ~= NSkin:GetTabSpacing()
    local changed
    if placementChanged then
        changed = NSkin:SetTabGroupPlacement(context.id, values) or changed
    end
    if spacingChanged then
        changed = NSkin:SetTabSpacing(values.spacing) or changed
    end
    return changed == true
end

NSkin:RegisterOptionGroup("tabs.layout", {
    controls = CreateTabControls(false),
    get = function(context)
        return GetValues(context, false)
    end,
    set = function(context, values)
        return SetValues(context, values, false)
    end,
    reset = function(context)
        return NSkin:ResetTabGroupPlacement(context.id)
    end,
})

NSkin:RegisterOptionGroup("tabs.defaults", {
    controls = CreateTabControls(true),
    get = function(context)
        return GetValues(context, true)
    end,
    set = function(context, values)
        return SetValues(context, values, true)
    end,
    reset = function(context)
        local changed = NSkin:ResetTabGroupPlacement(context.id)
        changed = NSkin:ResetTabSpacing() or changed
        return changed == true
    end,
})

local function BuildTabsOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Tabs")

    NSkin:CreateOptionsSection(page, "Shared defaults", 38)
    local layoutView = NSkin:CreateOptionGroupView(page, "tabs.defaults", "FULL", page)
    layoutView:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -70)

    function page:ApplyTheme()
        if layoutView.ApplyTheme then layoutView:ApplyTheme() end
    end

    function page:Refresh()
        layoutView:Refresh()
        self:ApplyTheme()
    end

    page:SetContentHeight(90 + layoutView:GetHeight())
    return page
end

-- Placement belongs to the docked Position category. Keep the option-group
-- definitions for the inspector, but do not expose placement globally.
