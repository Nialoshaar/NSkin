local _, NSkin = ...

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

local function ColorsEqual(left, right)
    return left and right
        and left[1] == right[1] and left[2] == right[2]
        and left[3] == right[3] and (left[4] or 1) == (right[4] or 1)
end

function NSkin:CreateSharedPlacementControls(extra)
    local controls = {
        { type = "DROPDOWN", key = "edge", label = "Window edge", order = 1,
            values = { { value = "TOP", label = "Top" },
                { value = "BOTTOM", label = "Bottom" } } },
        { type = "DROPDOWN", key = "side", label = "Border side", order = 2,
            values = { { value = "INSIDE", label = "Inside" },
                { value = "OUTSIDE", label = "Outside" } } },
        { type = "DROPDOWN", key = "alignment", label = "Alignment", order = 3,
            values = { { value = "LEFT", label = "Left" },
                { value = "CENTER", label = "Center" },
                { value = "RIGHT", label = "Right" } } },
        { type = "SLIDER", key = "alongOffset", label = "X offset", min = -200,
            max = 200, step = 0.1, decimals = 1, suffix = " px", order = 4 },
        { type = "SLIDER", key = "edgeOffset", label = "Y offset", min = -200,
            max = 200, step = 0.1, decimals = 1, suffix = " px", order = 5 },
    }
    for i = 1, #(extra or {}) do controls[#controls + 1] = extra[i] end
    controls[#controls + 1] = {
        type = "RESET", label = "Reset Default", compactLabel = "Reset"
    }
    return controls
end

function NSkin:NormalizeSharedPlacementValues(context, values)
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

NSkin:RegisterOptionGroup("shared.movable", {
    controls = NSkin:CreateSharedPlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        if values.mode == "GRID" then
            values.alongOffset, values.edgeOffset = values.x or 0, values.y or 0
        end
        return values
    end,
    set = function(context, values)
        return context.setPlacement(context, NSkin:NormalizeSharedPlacementValues(context, values))
    end,
    reset = function(context)
        return context.resetPlacement(context)
    end,
})

NSkin:RegisterOptionGroup("shared.pagination", {
    controls = NSkin:CreateSharedPlacementControls({
        { type = "CHECKBOX", key = "separateButtons",
            label = "Move buttons independently", order = 6 },
        { type = "DROPDOWN", key = "textMode", label = "Page text", order = 7,
            values = { { value = "GROUPED", label = "Grouped",
                    isEnabled = function(context)
                        return context and not context.getPaginationSeparateButtons(context)
                    end },
                { value = "INDEPENDENT", label = "Independent" },
                { value = "HIDDEN", label = "Hidden" } } },
    }),
    get = function(context)
        local values = context.getPlacement(context)
        if values.mode == "GRID" then
            values.alongOffset, values.edgeOffset = values.x or 0, values.y or 0
        end
        values.separateButtons = context.getPaginationSeparateButtons(context)
        values.textMode = context.getPaginationTextMode(context)
        return values
    end,
    set = function(context, values)
        NSkin:NormalizeSharedPlacementValues(context, values)
        local changed = context.setPlacement(context, values)
        local separateButtons = context.getPaginationSeparateButtons(context)
        local separateChanged = values.separateButtons ~= nil
            and values.separateButtons ~= separateButtons
        if separateChanged then
            changed = context.setPaginationSeparateButtons(context,
                values.separateButtons) or changed
            separateButtons = values.separateButtons == true
        end
        local textMode = values.textMode
        if separateChanged and separateButtons then
            textMode = "INDEPENDENT"
        elseif separateButtons and textMode == "GROUPED" then
            textMode = nil
        end
        if (textMode == "GROUPED" or textMode == "INDEPENDENT" or textMode == "HIDDEN")
            and textMode ~= context.getPaginationTextMode(context)
        then
            changed = context.setPaginationTextMode(context, textMode) or changed
        end
        return changed == true
    end,
    reset = function(context)
        local changed = context.resetPlacement(context)
        changed = context.setPaginationSeparateButtons(context, false) or changed
        changed = context.setPaginationTextMode(context, "GROUPED") or changed
        return changed == true
    end,
})

NSkin:RegisterOptionGroup("shared.search", {
    controls = NSkin:CreateSharedPlacementControls({
        { type = "DROPDOWN", key = "accessoryMode", label = "Search accessory", order = 6,
            values = { { value = "GROUPED", label = "Grouped" },
                { value = "INDEPENDENT", label = "Independent" },
                { value = "HIDDEN", label = "Hidden" } } },
        { type = "COLOR", key = "backgroundColor",
            label = "Element background", order = 7 },
        { type = "SLIDER", key = "backgroundOpacity",
            label = "Background opacity", min = 0, max = 1,
            step = 0.05, decimals = 2, order = 8 },
    }),
    get = function(context)
        local values = context.getPlacement(context)
        if values.mode == "GRID" then
            values.alongOffset, values.edgeOffset = values.x or 0, values.y or 0
        end
        values.accessoryMode = context.getSearchAccessoryMode(context)
        local style = NSkin:GetAppearanceStyle("searchBox", context.module, context.id)
        values.backgroundColor = CopyColor(style.background)
        values.backgroundOpacity = style.background[4] or 1
        return values
    end,
    set = function(context, values)
        NSkin:NormalizeSharedPlacementValues(context, values)
        local changed = context.setPlacement(context, values)
        local accessoryMode = values.accessoryMode
        if (accessoryMode == "GROUPED" or accessoryMode == "INDEPENDENT"
            or accessoryMode == "HIDDEN")
            and accessoryMode ~= context.getSearchAccessoryMode(context)
        then
            changed = context.setSearchAccessoryMode(context, accessoryMode) or changed
        end
        local background = CopyColor(values.backgroundColor)
        background[4] = values.backgroundOpacity
        local current = NSkin:GetAppearanceStyle(
            "searchBox", context.module, context.id
        ).background
        if not ColorsEqual(background, current) then
            changed = NSkin:SetElementAppearanceOverride(
                context.id, context.module, "searchBox.background", background
            ) or changed
        end
        return changed == true
    end,
    reset = function(context)
        local changed = context.resetPlacement(context)
        changed = context.setSearchAccessoryMode(context, "GROUPED") or changed
        changed = NSkin:ResetElementAppearanceOverride(
            context.id, "searchBox.background"
        ) or changed
        return changed == true
    end,
})
