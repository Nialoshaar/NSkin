local _, NSkin = ...

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

function NSkin:NormalizeGridPlacementForEditor(context, values)
    if not values or values.mode ~= "GRID" then return values end
    local window, target = context and context.window, context and context.target
    if not window or not target then return values end
    local windowWidth, windowHeight = window:GetWidth(), window:GetHeight()
    local targetWidth, targetHeight = target:GetWidth(), target:GetHeight()
    local x, y = tonumber(values.x) or 0, tonumber(values.y) or 0
    local centerX, centerY = x + targetWidth / 2, y - targetHeight / 2
    local alignment = centerX < windowWidth / 3 and "LEFT"
        or (centerX < windowWidth * 2 / 3 and "CENTER" or "RIGHT")
    local edge = centerY > -windowHeight / 2 and "TOP" or "BOTTOM"
    local side = centerY <= 0 and centerY >= -windowHeight and "INSIDE" or "OUTSIDE"
    values.alignment, values.edge, values.side = alignment, edge, side
    values.alongOffset = alignment == "LEFT" and x
        or (alignment == "CENTER" and x + targetWidth / 2 - windowWidth / 2
            or x + targetWidth - windowWidth)
    values.edgeOffset = edge == "TOP"
        and (side == "INSIDE" and y or y - targetHeight)
        or (side == "INSIDE" and y - targetHeight + windowHeight or y + windowHeight)
    values.mode, values.point, values.relativePoint = nil, nil, nil
    values.x, values.y, values.relativeTo = nil, nil, nil
    return values
end

function NSkin:CreateSharedPlacementControls(extra)
    local controls = {
        { type = "SLIDER_PAIR", order = 1, centerReset = true,
            resetTooltip = "Reset X and Y offsets",
            left = { key = "alongOffset", label = "X offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" },
            right = { key = "edgeOffset", label = "Y offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" } },
    }
    for i = 1, #(extra or {}) do controls[#controls + 1] = extra[i] end
    return controls
end

function NSkin:NormalizeSharedPlacementValues(context, values)
    if values.mode == "GRID" then
        values.x, values.y = values.alongOffset, values.edgeOffset
    end
    return values
end

NSkin:RegisterOptionGroup("shared.movable", {
    controls = NSkin:CreateSharedPlacementControls(),
    get = function(context)
        local values = context.getPlacement(context)
        return NSkin:NormalizeGridPlacementForEditor(context, values)
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
        return NSkin:NormalizeGridPlacementForEditor(context, values)
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
        return NSkin:NormalizeGridPlacementForEditor(context, values)
    end,
    set = function(context, values)
        return context.setPlacement(context,
            NSkin:NormalizeSharedPlacementValues(context, values))
    end,
    reset = function(context) return context.resetPlacement(context) end,
})

NSkin:RegisterOptionGroup("shared.searchLayout", {
    controls = {
        { type = "DROPDOWN_RESET", key = "accessoryMode",
            label = "Search accessory", labelWidth = 100, dropdownWidth = 95,
            dropdownReduction = 0,
            resetIcon = "Interface\\AddOns\\NSkin\\Media\\rotate-right.png",
            resetTooltip = "Reset search accessory layout",
            values = { { value = "GROUPED", label = "Grouped" },
                { value = "INDEPENDENT", label = "Independent" },
                { value = "HIDDEN", label = "Hidden" } } },
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
local function AddTypographyControls(controls, keys, label, order, color)
    controls[#controls + 1] = {
        type = "TYPOGRAPHY", label = label, order = order,
        sizeKey = keys.size, sizeLabel = "Size", sizeMin = 8, sizeMax = 32,
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
        label = "Color" })
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
        label = "Color" })
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "SLIDER_PAIR", order = 2, centerReset = true,
    resetTooltip = "Reset search text offsets",
    left = { key = "textOffsetX", label = "X offset", min = -50,
        max = 50, step = 0.1, decimals = 1, suffix = " px" },
    right = { key = "textOffsetY", label = "Y offset", min = -50,
        max = 50, step = 0.1, decimals = 1, suffix = " px" },
}
AddTypographyControls(searchAppearanceControls,
    { useGlobal = "placeholderUseGlobal", font = "placeholderFont",
        size = "placeholderSize", outline = "placeholderOutline" },
    "Placeholder Text", 10,
    { type = "COLOR", key = "placeholderText", modeKey = "placeholderTextMode",
        label = "Color" })
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "SLIDER_PAIR", order = 11, centerReset = true,
    resetTooltip = "Reset placeholder text offsets",
    left = { key = "placeholderOffsetX", label = "X offset", min = -50,
        max = 50, step = 0.1, decimals = 1, suffix = " px" },
    right = { key = "placeholderOffsetY", label = "Y offset", min = -50,
        max = 50, step = 0.1, decimals = 1, suffix = " px" },
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
local searchSizeControls = {
    type = "SLIDER_PAIR", order = 23, centerReset = true,
    resetTooltip = "Reset search box width and height",
    left = { key = "width", label = "Width", min = 80,
        max = 600, step = 1, decimals = 0, suffix = " px" },
    right = { key = "height", label = "Height", min = 16,
        max = 80, step = 1, decimals = 0, suffix = " px" },
}
searchAppearanceControls[#searchAppearanceControls + 1] = searchSizeControls
local searchBorderAccessoryControls = {
    type = "SLIDER_DROPDOWN_PAIR", order = 22,
    left = { key = "borderSize", label = "Border size", min = 1,
        max = 4, step = 1, decimals = 0, suffix = " px" },
    right = { key = "accessoryMode", label = "Search accessory",
        labelWidth = 100, dropdownReduction = 0,
        values = { { value = "GROUPED", label = "Grouped" },
            { value = "INDEPENDENT", label = "Independent" },
            { value = "HIDDEN", label = "Hidden" } } },
}
NSkin:RegisterOptionGroup("shared.searchAppearance", {
    controls = searchAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle("searchBox", context.module, context.id)
        local values = { background = CopyColor(style.background), border = CopyColor(style.border),
            text = CopyColor(style.text), textMode = style.textMode,
            placeholderText = CopyColor(style.placeholderText),
            placeholderTextMode = style.placeholderTextMode,
            borderSize = style.borderSize,
            width = tonumber(style.width) and style.width > 0 and style.width
                or (context.target and context.target.GetWidth
                    and context.target:GetWidth()),
            height = tonumber(style.height) and style.height > 0 and style.height
                or (context.target and context.target.GetHeight
                    and context.target:GetHeight()),
            textOffsetX = style.textOffsetX,
            textOffsetY = style.textOffsetY, placeholderOffsetX = style.placeholderOffsetX,
            placeholderOffsetY = style.placeholderOffsetY,
            backgroundMode = style.backgroundMode, borderMode = style.borderMode,
            accessoryMode = context.getSearchAccessoryMode
                and context.getSearchAccessoryMode(context) }
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
            width = "width", height = "height",
            text = "text", textMode = "textMode",
            textOffsetX = "textOffsetX", textOffsetY = "textOffsetY",
            placeholderText = "placeholderText",
            placeholderTextMode = "placeholderTextMode",
            placeholderOffsetX = "placeholderOffsetX", placeholderOffsetY = "placeholderOffsetY",
        }
        for key, path in pairs(mapping) do
            if values[key] ~= nil then
                changed = SetElementValue(context, "searchBox." .. path, values[key]) or changed
            end
        end
        if values.accessoryMode ~= nil and context.setSearchAccessoryMode
            and context.getSearchAccessoryMode
            and values.accessoryMode ~= context.getSearchAccessoryMode(context)
        then
            changed = context.setSearchAccessoryMode(context,
                values.accessoryMode) or changed
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "searchBox.fontMode", "searchBox.sizeMode",
            "searchBox.outlineMode", "searchBox.font", "searchBox.textSize",
            "searchBox.outline", "searchBox.text", "searchBox.textMode",
            "searchBox.textOffsetX", "searchBox.textOffsetY",
            "searchBox.placeholderFontMode",
            "searchBox.placeholderSizeMode", "searchBox.placeholderOutlineMode",
            "searchBox.placeholderFont", "searchBox.placeholderSize",
            "searchBox.placeholderOutline", "searchBox.placeholderText",
            "searchBox.placeholderTextMode", "searchBox.background",
            "searchBox.backgroundMode", "searchBox.border", "searchBox.borderMode",
            "searchBox.borderSize", "searchBox.width", "searchBox.height",
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
        label = "Color" })
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
        label = "Color" })
headerAppearanceControls[#headerAppearanceControls + 1] = {
    type = "SECTION", label = "Underline", order = 10,
}
headerAppearanceControls[#headerAppearanceControls + 1] = {
    type = "COLOR", key = "underline", modeKey = "underlineMode",
    label = "Color", order = 10.5,
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
        { type = "SLIDER_PAIR", centerReset = true,
            resetTooltip = "Reset X and Y offsets",
            left = { key = "offsetX", label = "X offset", min = -200,
                max = 200, step = 0.1, decimals = 1, suffix = " px" },
            right = { key = "offsetY", label = "Y offset", min = -100,
                max = 100, step = 0.1, decimals = 1, suffix = " px" } },
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
    FindControl(searchAppearanceControls, "SLIDER_PAIR", nil, nil),
})
NSkin:RegisterOptionGroupSubset("shared.placeholderTextAppearance", "shared.searchAppearance", {
    FindControl(searchAppearanceControls, "TYPOGRAPHY", nil, "Placeholder Text"),
    searchAppearanceControls[4],
})
NSkin:RegisterOptionGroupSubset("shared.searchBoxAppearance", "shared.searchAppearance", {
    { type = "COLOR_PAIR", left = searchColors.left, right = searchColors.right },
    searchBorderAccessoryControls,
    searchSizeControls,
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
