local _, NSkin = ...

local OPTION_INTERNALS = NSkin._componentOptionInternals
local CopyColor = OPTION_INTERNALS.CopyColor
local SetColor = OPTION_INTERNALS.SetColor
local SetScalar = OPTION_INTERNALS.SetScalar
local ResetPaths = OPTION_INTERNALS.ResetPaths
local RegisterColorAppearanceGroup = OPTION_INTERNALS.RegisterColorAppearanceGroup
local AddTypographyControls = OPTION_INTERNALS.AddTypographyControls
local GetTypographyValues = OPTION_INTERNALS.GetTypographyValues
local GetAppearanceWindowID = OPTION_INTERNALS.GetAppearanceWindowID
local SetElementTypography = OPTION_INTERNALS.SetElementTypography
local SetElementValue = OPTION_INTERNALS.SetElementValue
local ResetElementPaths = OPTION_INTERNALS.ResetElementPaths
local CreateBorderGeometryControls = OPTION_INTERNALS.CreateBorderGeometryControls
local ResetMappedElementKeys = OPTION_INTERNALS.ResetMappedElementKeys
local FindControl = OPTION_INTERNALS.FindControl
RegisterColorAppearanceGroup("appearance.button", "button", {
    { type = "COLOR", key = "backgroundColor", label = "Button background" },
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "SLIDER", key = "hoverAlpha", label = "Hover opacity",
        min = 0, max = 0.5, step = 0.01, decimals = 2 },
    { type = "COLOR", key = "border", label = "Button border" },
    { type = "COLOR", key = "text", label = "Button text" },
    { type = "RESET", label = "Reset Buttons" },
})
NSkin:RegisterOptionGroup("shared.checkboxAppearance", {
    controls = {
        { type = "COLOR_PAIR",
            left = { type = "COLOR", key = "background",
                label = "Background" },
            right = { type = "COLOR", key = "border", label = "Border" } },
        { type = "CONTROL_PAIR",
            left = { type = "COLOR", key = "checked",
                label = "Checked" },
            right = { type = "SLIDER", key = "hoverAlpha",
                label = "Hover opacity", min = 0, max = 0.5,
                step = 0.01, decimals = 2 } },
        { type = "RESET", label = "Reset Checkbox" },
    },
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "button", GetAppearanceWindowID(context), context.id)
        return {
            background = CopyColor(style.background),
            border = CopyColor(NSkin:GetAppearanceBorderColor(
                "button", style, GetAppearanceWindowID(context), context.id)),
            checked = CopyColor(style.checked or NSkin:GetSharedBorderColor()),
            hoverAlpha = style.hoverAlpha,
        }
    end,
    set = function(context, values)
        local changed
        for _, key in ipairs({ "background", "border", "checked",
            "hoverAlpha" }) do
            if values[key] ~= nil then
                changed = SetElementValue(
                    context, "button." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, {
            "button.background", "button.border", "button.checked",
            "button.hoverAlpha",
        })
    end,
})
RegisterColorAppearanceGroup("appearance.search", "searchBox", {
    { type = "COLOR", key = "backgroundColor", label = "Search background" },
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "COLOR", key = "border", label = "Search border" },
    { type = "RESET", label = "Reset Search Boxes" },
})
local searchAppearanceControls = {}
AddTypographyControls(searchAppearanceControls,
    { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" },
    "Search Text", 2, { type = "COLOR", key = "text", modeKey = "textMode",
        label = "Color" })
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "SLIDER_PAIR", order = 1, centerReset = true,
    resetTooltip = "Reset search text offsets",
    left = { key = "textOffsetX", label = "X offset", min = -50,
        max = 50, step = 0.1, decimals = 1, suffix = " px" },
    right = { key = "textOffsetY", label = "Y offset", min = -50,
        max = 50, step = 0.1, decimals = 1, suffix = " px" },
}
AddTypographyControls(searchAppearanceControls,
    { useGlobal = "placeholderUseGlobal", font = "placeholderFont",
        size = "placeholderSize", outline = "placeholderOutline" },
    "Placeholder Text", 11,
    { type = "COLOR", key = "placeholderText", modeKey = "placeholderTextMode",
        label = "Color" })
searchAppearanceControls[#searchAppearanceControls + 1] = {
    type = "SLIDER_PAIR", order = 10, centerReset = true,
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
local searchBorderGeometryControls = CreateBorderGeometryControls(21)
searchAppearanceControls[#searchAppearanceControls + 1] = searchBorderGeometryControls
local searchSizeControls = {
    type = "SLIDER_PAIR", order = 20, centerReset = true,
    resetTooltip = "Reset search box width and height",
    left = { key = "width", label = "Width", min = 80,
        max = 600, step = 1, decimals = 0, suffix = " px" },
    right = { key = "height", label = "Height", min = 16,
        max = 80, step = 1, decimals = 0, suffix = " px" },
}
searchAppearanceControls[#searchAppearanceControls + 1] = searchSizeControls
local searchAccessoryControls = {
    type = "DROPDOWN_PAIR", order = 22,
    right = { key = "accessoryMode", label = "Search accessory",
        labelWidth = 100,
        values = { { value = "GROUPED", label = "Grouped" },
            { value = "INDEPENDENT", label = "Independent" },
            { value = "HIDDEN", label = "Hidden" } } },
}
local searchResetPaths = {
    font = { "searchBox.fontMode", "searchBox.font" },
    textSize = { "searchBox.sizeMode", "searchBox.textSize" },
    outline = { "searchBox.outlineMode", "searchBox.outline" },
    placeholderFont = { "searchBox.placeholderFontMode",
        "searchBox.placeholderFont" },
    placeholderSize = { "searchBox.placeholderSizeMode",
        "searchBox.placeholderSize" },
    placeholderOutline = { "searchBox.placeholderOutlineMode",
        "searchBox.placeholderOutline" },
}
for _, key in ipairs({ "text", "textMode", "textOffsetX", "textOffsetY",
    "placeholderText", "placeholderTextMode", "placeholderOffsetX",
    "placeholderOffsetY", "background", "backgroundMode", "border",
    "borderMode", "borderSize", "borderPadding", "width", "height" }) do
    searchResetPaths[key] = "searchBox." .. key
end
NSkin:RegisterOptionGroup("shared.searchAppearance", {
    controls = searchAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "searchBox", GetAppearanceWindowID(context), context.id)
        local values = { background = CopyColor(style.background), border = CopyColor(style.border),
            text = CopyColor(style.text), textMode = style.textMode,
            placeholderText = CopyColor(style.placeholderText),
            placeholderTextMode = style.placeholderTextMode,
            borderSize = style.borderSize, borderPadding = style.borderPadding,
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
            borderPadding = "borderPadding",
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
            "searchBox.borderSize", "searchBox.borderPadding",
            "searchBox.width", "searchBox.height",
            "searchBox.placeholderOffsetX", "searchBox.placeholderOffsetY" })
    end,
    resetSubset = function(context, keys)
        local changed = ResetMappedElementKeys(context, keys, searchResetPaths)
        if keys.accessoryMode and context.setSearchAccessoryMode then
            changed = context.setSearchAccessoryMode(context, "GROUPED") or changed
        end
        return changed == true
    end,
})

local function CopyOptionControl(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for key, child in pairs(value) do copy[key] = CopyOptionControl(child) end
    return copy
end

local editBoxAppearanceControls = {}
for i = 1, #searchAppearanceControls do
    local control = searchAppearanceControls[i]
    if control ~= searchAccessoryControls then
        local copy = CopyOptionControl(control)
        if copy.type == "SECTION" and copy.label == "Search Box" then
            copy.label = "Edit Box"
        elseif copy.type == "TYPOGRAPHY" and copy.label == "Search Text" then
            copy.label = "Text"
        elseif copy.resetTooltip == "Reset search box width and height" then
            copy.resetTooltip = "Reset edit box width and height"
        elseif copy.resetTooltip == "Reset search text offsets" then
            copy.resetTooltip = "Reset text offsets"
        end
        editBoxAppearanceControls[#editBoxAppearanceControls + 1] = copy
    end
end
editBoxAppearanceControls[#editBoxAppearanceControls + 1] = {
    type = "COLOR_PAIR", order = 23,
    left = { type = "COLOR", key = "disabledText",
        modeKey = "disabledTextMode", label = "Disabled text" },
    right = { type = "COLOR", key = "focusBorder",
        modeKey = "focusBorderMode", label = "Focus border" },
}

NSkin:RegisterOptionGroup("shared.editBoxAppearance", {
    controls = editBoxAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "editBox", GetAppearanceWindowID(context), context.id)
        local values = {
            background = CopyColor(style.background),
            backgroundMode = style.backgroundMode,
            border = CopyColor(style.border), borderMode = style.borderMode,
            disabledText = CopyColor(style.disabledText),
            disabledTextMode = style.disabledTextMode,
            focusBorder = CopyColor(style.focusBorder),
            focusBorderMode = style.focusBorderMode,
            text = CopyColor(style.text), textMode = style.textMode,
            placeholderText = CopyColor(style.placeholderText),
            placeholderTextMode = style.placeholderTextMode,
            borderSize = style.borderSize, borderPadding = style.borderPadding,
            width = tonumber(style.width) and style.width > 0 and style.width
                or (context.target and context.target.GetWidth
                    and context.target:GetWidth()),
            height = tonumber(style.height) and style.height > 0 and style.height
                or (context.target and context.target.GetHeight
                    and context.target:GetHeight()),
            textOffsetX = style.textOffsetX, textOffsetY = style.textOffsetY,
            placeholderOffsetX = style.placeholderOffsetX,
            placeholderOffsetY = style.placeholderOffsetY,
        }
        GetTypographyValues(values, style,
            { useGlobal = "useGlobal", font = "font", size = "textSize",
                outline = "outline" })
        GetTypographyValues(values, style,
            { useGlobal = "placeholderUseGlobal", font = "placeholderFont",
                size = "placeholderSize", outline = "placeholderOutline" },
            "placeholder")
        return values
    end,
    set = function(context, values)
        local changed = SetElementTypography(context, "editBox", values,
            { font = "font", size = "textSize", outline = "outline" })
        changed = SetElementTypography(context, "editBox", values,
            { font = "placeholderFont", size = "placeholderSize",
                outline = "placeholderOutline" }, "placeholder") or changed
        for _, key in ipairs({
            "background", "backgroundMode", "border", "borderMode",
            "disabledText", "disabledTextMode", "focusBorder",
            "focusBorderMode", "borderSize", "borderPadding", "width",
            "height", "text", "textMode", "textOffsetX", "textOffsetY",
            "placeholderText", "placeholderTextMode", "placeholderOffsetX",
            "placeholderOffsetY",
        }) do
            if values[key] ~= nil then
                changed = SetElementValue(
                    context, "editBox." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        local paths = {}
        for _, key in ipairs({
            "fontMode", "sizeMode", "outlineMode", "font", "textSize",
            "outline", "text", "textMode", "textOffsetX", "textOffsetY",
            "disabledText", "disabledTextMode", "focusBorder",
            "focusBorderMode", "placeholderFontMode", "placeholderSizeMode",
            "placeholderOutlineMode", "placeholderFont", "placeholderSize",
            "placeholderOutline", "placeholderText", "placeholderTextMode",
            "placeholderOffsetX", "placeholderOffsetY", "background",
            "backgroundMode", "border", "borderMode", "borderSize",
            "borderPadding", "width", "height",
        }) do
            paths[#paths + 1] = "editBox." .. key
        end
        return ResetElementPaths(context, paths)
    end,
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
    searchSizeControls,
    searchBorderGeometryControls,
    searchAccessoryControls,
    { type = "COLOR_PAIR", order = 100,
        left = searchColors.left, right = searchColors.right },
})
