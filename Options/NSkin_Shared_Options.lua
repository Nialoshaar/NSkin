local _, NSkin = ...

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

function NSkin:CreateSharedPlacementControls(extra)
    local controls = {
        { type = "DROPDOWN_PAIR", order = 1,
            left = { key = "edge", label = "Window edge",
                values = { { value = "TOP", label = "Top" },
                    { value = "BOTTOM", label = "Bottom" } } },
            right = { key = "side", label = "Border side",
                values = { { value = "INSIDE", label = "Inside" },
                    { value = "OUTSIDE", label = "Outside" } } } },
        { type = "DROPDOWN_PAIR", order = 2,
            left = { key = "alignment", label = "Alignment",
                values = { { value = "LEFT", label = "Left" },
                    { value = "CENTER", label = "Center" },
                    { value = "RIGHT", label = "Right" } } } },
        { type = "SLIDER_PAIR", order = 3,
            left = { key = "alongOffset", label = "X offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" },
            right = { key = "edgeOffset", label = "Y offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" } },
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

NSkin:RegisterOptionGroup("shared.paginationPosition", {
    controls = NSkin:CreateSharedPlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        if values.mode == "GRID" then
            values.alongOffset, values.edgeOffset = values.x or 0, values.y or 0
        end
        return values
    end,
    set = function(context, values)
        return context.setPlacement(context,
            NSkin:NormalizeSharedPlacementValues(context, values))
    end,
    reset = function(context) return context.resetPlacement(context) end,
})

NSkin:RegisterOptionGroup("shared.paginationLayout", {
    controls = {
        { type = "CONTROL_PAIR",
            left = { type = "CHECKBOX", key = "separateButtons",
                label = "Move buttons independently" },
            right = { type = "DROPDOWN", key = "textMode", label = "Page text",
                values = { { value = "GROUPED", label = "Grouped",
                        isEnabled = function(context)
                            return context and not context.getPaginationSeparateButtons(context)
                        end },
                    { value = "INDEPENDENT", label = "Independent" },
                    { value = "HIDDEN", label = "Hidden" } } } },
        { type = "RESET", label = "Reset Layout", compactLabel = "Reset" },
    },
    get = function(context)
        return { separateButtons = context.getPaginationSeparateButtons(context),
            textMode = context.getPaginationTextMode(context) }
    end,
    set = function(context, values)
        local changed
        local separate = context.getPaginationSeparateButtons(context)
        if values.separateButtons ~= nil and values.separateButtons ~= separate then
            changed = context.setPaginationSeparateButtons(context,
                values.separateButtons) or changed
            separate = values.separateButtons == true
        end
        local textMode = values.textMode
        if separate and textMode == "GROUPED" then textMode = "INDEPENDENT" end
        if textMode == "GROUPED" or textMode == "INDEPENDENT" or textMode == "HIDDEN" then
            changed = context.setPaginationTextMode(context, textMode) or changed
        end
        return changed == true
    end,
    reset = function(context)
        local changed = context.setPaginationSeparateButtons(context, false)
        changed = context.setPaginationTextMode(context, "GROUPED") or changed
        return changed == true
    end,
})

NSkin:RegisterOptionGroup("shared.searchPosition", {
    controls = NSkin:CreateSharedPlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        if values.mode == "GRID" then
            values.alongOffset, values.edgeOffset = values.x or 0, values.y or 0
        end
        return values
    end,
    set = function(context, values)
        return context.setPlacement(context,
            NSkin:NormalizeSharedPlacementValues(context, values))
    end,
    reset = function(context) return context.resetPlacement(context) end,
})

NSkin:RegisterOptionGroup("shared.searchLayout", {
    controls = {
        { type = "DROPDOWN_PAIR",
            left = { key = "accessoryMode", label = "Search accessory",
                values = { { value = "GROUPED", label = "Grouped" },
                    { value = "INDEPENDENT", label = "Independent" },
                    { value = "HIDDEN", label = "Hidden" } } } },
        { type = "RESET", label = "Reset Layout", compactLabel = "Reset" },
    },
    get = function(context)
        return { accessoryMode = context.getSearchAccessoryMode(context) }
    end,
    set = function(context, values)
        local mode = values.accessoryMode
        if mode ~= "GROUPED" and mode ~= "INDEPENDENT" and mode ~= "HIDDEN" then
            return false
        end
        return context.setSearchAccessoryMode(context, mode)
    end,
    reset = function(context)
        return context.setSearchAccessoryMode(context, "GROUPED")
    end,
})

local GLOBAL_VALUE = "__NSKIN_GLOBAL__"
local FONT_VALUES = {
    { value = GLOBAL_VALUE, label = "NSkin Global Font" },
    { divider = true },
    { value = "Fonts\\FRIZQT__.TTF", label = "Friz Quadrata" },
    { value = "Fonts\\ARIALN.TTF", label = "Arial Narrow" },
    { value = "Fonts\\MORPHEUS.TTF", label = "Morpheus" },
    { value = "Fonts\\SKURRI.TTF", label = "Skurri" },
}
local OUTLINE_VALUES = {
    { value = GLOBAL_VALUE, label = "NSkin Global Outline" },
    { divider = true },
    { value = "", label = "None" },
    { value = "OUTLINE", label = "Outline" },
    { value = "THICKOUTLINE", label = "Thick outline" },
    { value = "MONOCHROME,OUTLINE", label = "Monochrome outline" },
}
local SIZE_VALUES = { { value = GLOBAL_VALUE, label = "NSkin Global Size" },
    { divider = true } }
for size = 8, 32 do
    SIZE_VALUES[#SIZE_VALUES + 1] = { value = size, label = size .. " px" }
end

local function AddTypographyControls(controls, keys, label, order, color)
    controls[#controls + 1] = {
        type = "TYPOGRAPHY", label = label, order = order,
        sizeKey = keys.size, sizeLabel = "Size", sizeValues = SIZE_VALUES,
        fontKey = keys.font, fontLabel = "Font", fontValues = FONT_VALUES,
        outlineKey = keys.outline, outlineLabel = "Outline",
        outlineValues = OUTLINE_VALUES,
        color = color,
    }
end

local function GetTypographyValues(values, style, keys, prefix)
    prefix = prefix or ""
    local fontMode = style[prefix == "" and "fontMode" or prefix .. "FontMode"]
    local sizeMode = style[prefix == "" and "sizeMode" or prefix .. "SizeMode"]
    local outlineMode = style[prefix == "" and "outlineMode" or prefix .. "OutlineMode"]
    values[keys.font] = fontMode == "GLOBAL" and GLOBAL_VALUE
        or style[prefix == "" and "font" or prefix .. "Font"]
    values[keys.size] = sizeMode == "GLOBAL" and GLOBAL_VALUE
        or style[prefix == "" and "textSize" or prefix .. "Size"]
    values[keys.outline] = outlineMode == "GLOBAL" and GLOBAL_VALUE
        or style[prefix == "" and "outline" or prefix .. "Outline"]
end

local SetElementValue

local function SetElementTypography(context, stylePath, values, keys, prefix)
    prefix = prefix or ""
    local fontKey = prefix == "" and "font" or prefix .. "Font"
    local sizeKey = prefix == "" and "textSize" or prefix .. "Size"
    local outlineKey = prefix == "" and "outline" or prefix .. "Outline"
    local fontModeKey = prefix == "" and "fontMode" or prefix .. "FontMode"
    local sizeModeKey = prefix == "" and "sizeMode" or prefix .. "SizeMode"
    local outlineModeKey = prefix == "" and "outlineMode" or prefix .. "OutlineMode"
    local changed
    if values[keys.font] ~= nil then
        changed = SetElementValue(context, stylePath .. "." .. fontModeKey,
            values[keys.font] == GLOBAL_VALUE and "GLOBAL" or "CUSTOM") or changed
    end
    if values[keys.size] ~= nil then
        changed = SetElementValue(context, stylePath .. "." .. sizeModeKey,
            values[keys.size] == GLOBAL_VALUE and "GLOBAL" or "CUSTOM") or changed
    end
    if values[keys.outline] ~= nil then
        changed = SetElementValue(context, stylePath .. "." .. outlineModeKey,
            values[keys.outline] == GLOBAL_VALUE and "GLOBAL" or "CUSTOM") or changed
    end
    if values[keys.font] ~= nil and values[keys.font] ~= GLOBAL_VALUE then
        changed = SetElementValue(context, stylePath .. "." .. fontKey,
            values[keys.font]) or changed
    end
    if values[keys.size] ~= nil and values[keys.size] ~= GLOBAL_VALUE then
        changed = SetElementValue(context, stylePath .. "." .. sizeKey,
            values[keys.size]) or changed
    end
    if values[keys.outline] ~= nil and values[keys.outline] ~= GLOBAL_VALUE then
        changed = SetElementValue(context, stylePath .. "." .. outlineKey,
            values[keys.outline]) or changed
    end
    return changed == true
end

SetElementValue = function(context, path, value)
    return NSkin:SetElementAppearanceOverride(context.id, context.module, path, value)
end

local function ResetElementPaths(context, paths)
    local changed
    for i = 1, #paths do
        changed = NSkin:ResetElementAppearanceOverride(context.id, paths[i]) or changed
    end
    return changed == true
end

local tabAppearanceControls = {
    { type = "SLIDER", key = "borderSize", label = "Border size", min = 1,
        max = 4, step = 1, suffix = " px", order = 13 },
}
AddTypographyControls(tabAppearanceControls,
    { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" },
    "Tab Text", 1, { type = "COLOR", key = "text", modeKey = "textMode",
        label = "Colour" })
tabAppearanceControls[#tabAppearanceControls + 1] = {
    type = "SECTION", label = "Tabs", order = 10,
}
tabAppearanceControls[#tabAppearanceControls + 1] = {
    type = "COLOR_PAIR", order = 11,
    left = { type = "COLOR", key = "border", modeKey = "borderMode",
        label = "Border" },
    right = { type = "COLOR", key = "background", modeKey = "backgroundMode",
        label = "Background" },
}
tabAppearanceControls[#tabAppearanceControls + 1] = {
    type = "COLOR", key = "selectedBackground", modeKey = "selectedBackgroundMode",
    label = "Selected background", order = 12,
}
NSkin:RegisterOptionGroup("shared.tabAppearance", {
    controls = tabAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle("tab", context.module, context.id)
        local values = { background = CopyColor(style.background),
            selectedBackground = CopyColor(style.selectedBackground),
            border = CopyColor(style.border), text = CopyColor(style.text),
            textMode = style.textMode, borderSize = style.borderSize,
            backgroundMode = style.backgroundMode,
            selectedBackgroundMode = style.selectedBackgroundMode,
            borderMode = style.borderMode }
        GetTypographyValues(values, style,
            { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" })
        return values
    end,
    set = function(context, values)
        local changed = SetElementTypography(context, "tab", values,
            { font = "font", size = "textSize", outline = "outline" })
        for _, key in ipairs({ "text", "textMode", "background", "backgroundMode", "selectedBackground",
            "selectedBackgroundMode", "border", "borderMode", "borderSize" }) do
            if values[key] ~= nil then
                changed = SetElementValue(context, "tab." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "tab.fontMode", "tab.sizeMode",
            "tab.outlineMode", "tab.font", "tab.textSize", "tab.outline",
            "tab.text", "tab.textMode", "tab.background", "tab.backgroundMode", "tab.selectedBackground",
            "tab.selectedBackgroundMode", "tab.border", "tab.borderMode",
            "tab.borderSize" })
    end,
})

local searchAppearanceControls = {}
AddTypographyControls(searchAppearanceControls,
    { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" },
    "Search Text", 1, { type = "COLOR", key = "text", modeKey = "textMode",
        label = "Colour" })
AddTypographyControls(searchAppearanceControls,
    { useGlobal = "placeholderUseGlobal", font = "placeholderFont",
        size = "placeholderSize", outline = "placeholderOutline" },
    "Placeholder Text", 10,
    { type = "COLOR", key = "placeholderText", modeKey = "placeholderTextMode",
        label = "Colour" })
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "SLIDER_PAIR", order = 11,
    left = { key = "placeholderOffsetX", label = "X offset", min = -50,
        max = 50, step = 1, suffix = " px" },
    right = { key = "placeholderOffsetY", label = "Y offset", min = -50,
        max = 50, step = 1, suffix = " px" },
}
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "SECTION", label = "Search Box", order = 20,
}
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "COLOR_PAIR", order = 21,
    left = { type = "COLOR", key = "border", modeKey = "borderMode",
        label = "Border" },
    right = { type = "COLOR", key = "background", modeKey = "backgroundMode",
        label = "Background" },
}
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "SLIDER", key = "borderSize", label = "Border size", min = 1,
    max = 4, step = 1, suffix = " px", order = 22,
}
NSkin:RegisterOptionGroup("shared.searchAppearance", {
    controls = searchAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle("searchBox", context.module, context.id)
        local values = { background = CopyColor(style.background), border = CopyColor(style.border),
            text = CopyColor(style.text), textMode = style.textMode,
            placeholderText = CopyColor(style.placeholderText),
            placeholderTextMode = style.placeholderTextMode,
            borderSize = style.borderSize, placeholderOffsetX = style.placeholderOffsetX,
            placeholderOffsetY = style.placeholderOffsetY,
            backgroundMode = style.backgroundMode, borderMode = style.borderMode }
        GetTypographyValues(values, style,
            { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" })
        GetTypographyValues(values, style,
            { useGlobal = "placeholderUseGlobal", font = "placeholderFont",
                size = "placeholderSize", outline = "placeholderOutline" }, "placeholder")
        return values
    end,
    set = function(context, values)
        local changed = SetElementTypography(context, "searchBox", values,
            { font = "font", size = "textSize", outline = "outline" })
        changed = SetElementTypography(context, "searchBox", values,
            { font = "placeholderFont", size = "placeholderSize",
                outline = "placeholderOutline" }, "placeholder") or changed
        local mapping = {
            background = "background", backgroundMode = "backgroundMode",
            border = "border", borderMode = "borderMode", borderSize = "borderSize",
            text = "text", textMode = "textMode",
            placeholderText = "placeholderText",
            placeholderTextMode = "placeholderTextMode",
            placeholderOffsetX = "placeholderOffsetX", placeholderOffsetY = "placeholderOffsetY",
        }
        for key, path in pairs(mapping) do
            if values[key] ~= nil then
                changed = SetElementValue(context, "searchBox." .. path, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "searchBox.fontMode", "searchBox.sizeMode",
            "searchBox.outlineMode", "searchBox.font", "searchBox.textSize",
            "searchBox.outline", "searchBox.text", "searchBox.textMode",
            "searchBox.placeholderFontMode",
            "searchBox.placeholderSizeMode", "searchBox.placeholderOutlineMode",
            "searchBox.placeholderFont", "searchBox.placeholderSize",
            "searchBox.placeholderOutline", "searchBox.placeholderText",
            "searchBox.placeholderTextMode", "searchBox.background",
            "searchBox.backgroundMode", "searchBox.border", "searchBox.borderMode",
            "searchBox.borderSize",
            "searchBox.placeholderOffsetX", "searchBox.placeholderOffsetY" })
    end,
})

local windowAppearanceControls = {
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2, order = 3 },
    { type = "SLIDER", key = "borderSize", label = "Border size", min = 1,
        max = 4, step = 1, suffix = " px", order = 4 },
    { type = "SLIDER", key = "headerOpacity", label = "Header opacity",
        min = 0, max = 1, step = 0.05, decimals = 2, order = 22 },
}
AddTypographyControls(windowAppearanceControls,
    { useGlobal = "headerUseGlobal", font = "headerFont",
        size = "headerTextSize", outline = "headerOutline" }, "Header", 20,
    { type = "COLOR", key = "headerText", modeKey = "headerTextMode",
        label = "Colour" })
windowAppearanceControls[#windowAppearanceControls + 1] = {
    type = "SECTION", label = "Window", order = 1,
}
windowAppearanceControls[#windowAppearanceControls + 1] = {
    type = "COLOR_PAIR", order = 2,
    left = { type = "COLOR", key = "border", modeKey = "borderMode",
        label = "Border" },
    right = { type = "COLOR", key = "background", modeKey = "backgroundMode",
        label = "Background" },
}
windowAppearanceControls[#windowAppearanceControls + 1] = {
    type = "COLOR", key = "headerBackground", modeKey = "headerBackgroundMode",
    label = "Background", order = 21,
}
NSkin:RegisterOptionGroup("shared.windowAppearance", {
    controls = windowAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle("window", context.module, context.id)
        local values = { background = CopyColor(style.background),
            backgroundOpacity = style.background[4] or 1,
            border = CopyColor(style.border), borderMode = style.borderMode,
            borderSize = style.borderSize,
            headerBackground = CopyColor(style.header.background),
            headerText = CopyColor(style.header.text),
            headerTextMode = style.header.textMode,
            headerOpacity = style.header.background[4] or 1,
            backgroundMode = style.backgroundMode,
            headerBackgroundMode = style.header.backgroundMode }
        GetTypographyValues(values, style.header,
            { useGlobal = "headerUseGlobal", font = "headerFont",
                size = "headerTextSize", outline = "headerOutline" })
        return values
    end,
    set = function(context, values)
        local style = NSkin:GetAppearanceStyle("window", context.module, context.id)
        local mapping = {
            ["window.backgroundMode"] = values.backgroundMode,
            ["window.border"] = values.border,
            ["window.borderMode"] = values.borderMode,
            ["window.borderSize"] = values.borderSize,
            ["window.header.backgroundMode"] = values.headerBackgroundMode,
            ["window.header.text"] = values.headerText,
            ["window.header.textMode"] = values.headerTextMode,
        }
        if values.background ~= nil or values.backgroundOpacity ~= nil then
            local background = CopyColor(values.background or style.background)
            background[4] = values.backgroundOpacity or background[4]
            mapping["window.background"] = background
        end
        if values.headerBackground ~= nil or values.headerOpacity ~= nil then
            local header = CopyColor(values.headerBackground or style.header.background)
            header[4] = values.headerOpacity or header[4]
            mapping["window.header.background"] = header
        end
        local changed = SetElementTypography(context, "window.header", values,
            { font = "headerFont", size = "headerTextSize",
                outline = "headerOutline" })
        for path, value in pairs(mapping) do
            if value ~= nil then changed = SetElementValue(context, path, value) or changed end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "window.background", "window.backgroundMode",
            "window.border", "window.borderMode", "window.borderSize",
            "window.header.background", "window.header.backgroundMode",
            "window.header.text", "window.header.textMode",
            "window.header.fontMode",
            "window.header.sizeMode", "window.header.outlineMode",
            "window.header.font", "window.header.textSize", "window.header.outline" })
    end,
})

local headerAppearanceControls = {
    { type = "CHECKBOX", key = "underlineVisible", label = "Show underline", order = 11 },
    { type = "SLIDER", key = "underlineSize", label = "Underline size",
        min = 1, max = 6, step = 1, suffix = " px", order = 12 },
}
AddTypographyControls(headerAppearanceControls,
    { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" },
    "Header Text", 1, { type = "COLOR", key = "text", modeKey = "textMode",
        label = "Colour" })
headerAppearanceControls[#headerAppearanceControls + 1] = {
    type = "SECTION", label = "Underline", order = 10,
}
headerAppearanceControls[#headerAppearanceControls + 1] = {
    type = "COLOR", key = "underline", modeKey = "underlineMode",
    label = "Colour", order = 10.5,
}
NSkin:RegisterOptionGroup("shared.sectionHeaderAppearance", {
    controls = headerAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle("sectionHeader", context.module, context.id)
        local values = { text = CopyColor(style.text), underline = CopyColor(style.underline),
            underlineVisible = style.underlineVisible, underlineSize = style.underlineSize,
            textMode = style.textMode, underlineMode = style.underlineMode }
        GetTypographyValues(values, style,
            { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" })
        return values
    end,
    set = function(context, values)
        local mapping = { text = "text", textMode = "textMode",
            underlineVisible = "underlineVisible", underlineSize = "underlineSize",
            underline = "underline", underlineMode = "underlineMode" }
        local changed = SetElementTypography(context, "sectionHeader", values,
            { font = "font", size = "textSize", outline = "outline" })
        for key, path in pairs(mapping) do
            if values[key] ~= nil then
                changed = SetElementValue(context, "sectionHeader." .. path, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "sectionHeader.fontMode",
            "sectionHeader.sizeMode", "sectionHeader.outlineMode",
            "sectionHeader.font", "sectionHeader.textSize", "sectionHeader.outline",
            "sectionHeader.text", "sectionHeader.textMode",
            "sectionHeader.underlineVisible", "sectionHeader.underlineSize",
            "sectionHeader.underline", "sectionHeader.underlineMode" })
    end,
})

NSkin:RegisterOptionGroup("shared.sectionHeaderPlacement", {
    controls = {
        { type = "SLIDER_PAIR",
            left = { key = "offsetX", label = "X offset", min = -200,
                max = 200, step = 1, suffix = " px" },
            right = { key = "offsetY", label = "Y offset", min = -100,
                max = 100, step = 1, suffix = " px" } },
        { type = "RESET", label = "Reset Position", compactLabel = "Reset" },
    },
    get = function(context) return context.getSectionHeaderOffset(context) end,
    set = function(context, values)
        return context.setSectionHeaderOffset(context, values.offsetX, values.offsetY)
    end,
    reset = function(context) return context.resetSectionHeaderOffset(context) end,
})

local function FindControl(controls, controlType, key, label)
    for i = 1, #controls do
        local control = controls[i]
        if control.type == controlType
            and (not key or control.key == key)
            and (not label or control.label == label)
        then
            return control
        end
    end
end

local tabColors = FindControl(tabAppearanceControls, "COLOR_PAIR")
NSkin:RegisterOptionGroupSubset("shared.tabTextAppearance", "shared.tabAppearance", {
    FindControl(tabAppearanceControls, "TYPOGRAPHY", nil, "Tab Text"),
})
NSkin:RegisterOptionGroupSubset("shared.tabBorderAppearance", "shared.tabAppearance", {
    tabColors.left,
    FindControl(tabAppearanceControls, "SLIDER", "borderSize"),
})
NSkin:RegisterOptionGroupSubset("shared.tabBackgroundAppearance", "shared.tabAppearance", {
    tabColors.right,
    FindControl(tabAppearanceControls, "COLOR", "selectedBackground"),
})

local searchColors = FindControl(searchAppearanceControls, "COLOR_PAIR")
NSkin:RegisterOptionGroupSubset("shared.searchTextAppearance", "shared.searchAppearance", {
    FindControl(searchAppearanceControls, "TYPOGRAPHY", nil, "Search Text"),
})
NSkin:RegisterOptionGroupSubset("shared.placeholderTextAppearance", "shared.searchAppearance", {
    FindControl(searchAppearanceControls, "TYPOGRAPHY", nil, "Placeholder Text"),
    FindControl(searchAppearanceControls, "SLIDER_PAIR"),
})
NSkin:RegisterOptionGroupSubset("shared.searchBoxAppearance", "shared.searchAppearance", {
    { type = "COLOR_PAIR", left = searchColors.left, right = searchColors.right },
    FindControl(searchAppearanceControls, "SLIDER", "borderSize"),
})

local windowColors = FindControl(windowAppearanceControls, "COLOR_PAIR")
NSkin:RegisterOptionGroupSubset("shared.windowBorderAppearance", "shared.windowAppearance", {
    windowColors.left,
    FindControl(windowAppearanceControls, "SLIDER", "borderSize"),
})
NSkin:RegisterOptionGroupSubset("shared.windowBackgroundAppearance", "shared.windowAppearance", {
    windowColors.right,
    FindControl(windowAppearanceControls, "SLIDER", "backgroundOpacity"),
})
NSkin:RegisterOptionGroupSubset("shared.windowHeaderAppearance", "shared.windowAppearance", {
    FindControl(windowAppearanceControls, "TYPOGRAPHY", nil, "Header"),
    FindControl(windowAppearanceControls, "COLOR", "headerBackground"),
    FindControl(windowAppearanceControls, "SLIDER", "headerOpacity"),
})

NSkin:RegisterOptionGroupSubset("shared.headerTextAppearance",
    "shared.sectionHeaderAppearance", {
        FindControl(headerAppearanceControls, "TYPOGRAPHY", nil, "Header Text"),
    })
NSkin:RegisterOptionGroupSubset("shared.headerUnderlineAppearance",
    "shared.sectionHeaderAppearance", {
        FindControl(headerAppearanceControls, "COLOR", "underline"),
        FindControl(headerAppearanceControls, "CHECKBOX", "underlineVisible"),
        FindControl(headerAppearanceControls, "SLIDER", "underlineSize"),
    })
