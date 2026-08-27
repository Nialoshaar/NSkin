local _, NSkin = ...

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
        { type = "SLIDER", key = "alongOffset", label = "X offset", min = -2000,
            max = 2000, step = 0.1, decimals = 1, suffix = " px", order = 4 },
        { type = "SLIDER", key = "edgeOffset", label = "Y offset", min = -2000,
            max = 2000, step = 0.1, decimals = 1, suffix = " px", order = 5 },
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
            values = { { value = "GROUPED", label = "Grouped" },
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
        if values.separateButtons ~= context.getPaginationSeparateButtons(context) then
            changed = context.setPaginationSeparateButtons(context,
                values.separateButtons) or changed
        end
        if values.textMode ~= context.getPaginationTextMode(context) then
            changed = context.setPaginationTextMode(context, values.textMode) or changed
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
