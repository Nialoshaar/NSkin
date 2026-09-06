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
NSkin:RegisterOptionGroup("appearance.sectionCard", {
    controls = {
        { type = "COLOR", key = "background", label = "Card background" },
        { type = "COLOR", key = "border", label = "Card border" },
        { type = "COLOR", key = "text", label = "Card text" },
        { type = "DROPDOWN", key = "font", label = "Font",
            values = function() return NSkin:GetAvailableFontOptions(false) end },
        { type = "SLIDER", key = "textSize", label = "Text size",
            min = 8, max = 32, step = 1, suffix = " px" },
        { type = "DROPDOWN", key = "outline", label = "Outline", values = {
            { value = "", label = "None" },
            { value = "OUTLINE", label = "Outline" },
            { value = "THICKOUTLINE", label = "Thick outline" },
            { value = "MONOCHROME,OUTLINE", label = "Monochrome outline" },
        } },
        { type = "SLIDER", key = "height", label = "Card height",
            min = 0, max = 80, step = 1, suffix = " px" },
        { type = "SLIDER_PAIR", centerReset = true,
            resetTooltip = "Reset text offsets",
            left = { key = "textOffsetX", label = "Text X", min = -40,
                max = 40, step = 1, suffix = " px", resetValue = 10 },
            right = { key = "textOffsetY", label = "Text Y", min = -20,
                max = 20, step = 1, suffix = " px", resetValue = 0 } },
        { type = "SLIDER", key = "iconSpacing", label = "Icon spacing",
            min = -20, max = 40, step = 1, suffix = " px" },
        { type = "SLIDER", key = "hoverAlpha", label = "Hover opacity",
            min = 0, max = 0.5, step = 0.01, decimals = 2 },
        { type = "COLOR", key = "glyph", label = "Expand/collapse glyph" },
        { type = "SLIDER", key = "glyphSize", label = "Glyph size",
            min = 8, max = 32, step = 1, suffix = " px" },
        { type = "SLIDER_PAIR", centerReset = true,
            resetTooltip = "Reset glyph offsets",
            left = { key = "glyphOffsetX", label = "Glyph X", min = -40,
                max = 40, step = 1, suffix = " px", resetValue = -10 },
            right = { key = "glyphOffsetY", label = "Glyph Y", min = -20,
                max = 20, step = 1, suffix = " px", resetValue = 0 } },
        { type = "RESET", label = "Reset Section Cards" },
    },
    get = function()
        local style = NSkin:GetStyle("sectionCard")
        local font, textSize, outline = NSkin:GetResolvedTypography(style)
        return {
            background = CopyColor(style.background),
            border = CopyColor(style.border),
            text = CopyColor(style.text), font = font,
            textSize = textSize, outline = outline,
            height = style.height, textOffsetX = style.textOffsetX,
            textOffsetY = style.textOffsetY, iconSpacing = style.iconSpacing,
            hoverAlpha = style.hoverAlpha, glyph = CopyColor(style.glyph),
            glyphSize = style.glyphSize, glyphOffsetX = style.glyphOffsetX,
            glyphOffsetY = style.glyphOffsetY,
        }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("sectionCard")
        local changed
        for _, key in ipairs({ "background", "border", "text", "glyph" }) do
            if values[key] then
                changed = SetColor("sectionCard." .. key, style[key],
                    values[key], values[key][4]) or changed
            end
        end
        for _, key in ipairs({ "font", "textSize", "outline" }) do
            if values[key] ~= nil then
                local modeKey = key == "font" and "fontMode"
                    or key == "textSize" and "sizeMode" or "outlineMode"
                changed = SetScalar("sectionCard." .. modeKey, style[modeKey],
                    "CUSTOM") or changed
                changed = SetScalar("sectionCard." .. key, style[key],
                    values[key]) or changed
            end
        end
        for _, key in ipairs({ "height",
            "textOffsetX", "textOffsetY", "iconSpacing", "hoverAlpha",
            "glyphSize", "glyphOffsetX", "glyphOffsetY" }) do
            changed = SetScalar("sectionCard." .. key, style[key], values[key])
                or changed
        end
        return changed == true
    end,
    reset = function()
        local paths = {}
        for _, key in ipairs({ "background", "border", "text", "font",
            "fontMode", "textSize", "sizeMode", "outline", "outlineMode",
            "height", "textOffsetX", "textOffsetY",
            "iconSpacing", "hoverAlpha", "glyph", "glyphSize",
            "glyphOffsetX", "glyphOffsetY" }) do
            paths[#paths + 1] = "sectionCard." .. key
        end
        return ResetPaths(paths)
    end,
})

NSkin:RegisterOptionGroup("appearance.progress", {
    controls = {
        { type = "COLOR", key = "backgroundColor", label = "Bar background" },
        { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
            min = 0, max = 1, step = 0.05, decimals = 2 },
        { type = "SLIDER", key = "height", label = "Bar height",
            min = 6, max = 40, step = 1, suffix = " px" },
        { type = "CHECKBOX", key = "useCustomColor", label = "Use custom fill color" },
        { type = "COLOR", key = "color", label = "Fill color" },
        { type = "CHECKBOX", key = "useCustomTextColor", label = "Use custom text color" },
        { type = "COLOR", key = "text", label = "Text color" },
        { type = "RESET", label = "Reset Progress Bars" },
    },
    get = function()
        local style = NSkin:GetStyle("progressBar")
        return {
            backgroundColor = CopyColor(style.background),
            backgroundOpacity = style.background[4] or 1,
            height = style.height,
            useCustomColor = style.useCustomColor,
            color = CopyColor(style.color),
            useCustomTextColor = style.useCustomTextColor,
            text = CopyColor(style.text),
        }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("progressBar")
        local changed = SetColor("progressBar.background", style.background,
            values.backgroundColor, values.backgroundOpacity)
        changed = SetScalar("progressBar.height", style.height, values.height) or changed
        changed = SetScalar("progressBar.useCustomColor", style.useCustomColor,
            values.useCustomColor) or changed
        changed = SetColor("progressBar.color", style.color, values.color,
            values.color[4]) or changed
        changed = SetScalar("progressBar.useCustomTextColor", style.useCustomTextColor,
            values.useCustomTextColor) or changed
        changed = SetColor("progressBar.text", style.text, values.text,
            values.text[4]) or changed
        return changed == true
    end,
    reset = function()
        return ResetPaths({ "progressBar.background", "progressBar.height",
            "progressBar.useCustomColor", "progressBar.color",
            "progressBar.useCustomTextColor", "progressBar.text" })
    end,
})

local iconAppearanceControls = {
    { type = "COLOR", key = "border", label = "Icon border", order = 1 },
    { type = "DROPDOWN", key = "borderMode", label = "Border mode",
        order = 2, values = {
            { value = "custom", label = "Custom" },
            { value = "quality", label = "Item quality" },
        } },
    { type = "SLIDER", key = "borderSize", label = "Border thickness",
        min = 0, max = 8, step = 1, decimals = 0, suffix = " px", order = 3 },
    { type = "SLIDER_PAIR", order = 4, centerReset = true,
        resetTooltip = "Reset icon width and height",
        left = { key = "width", label = "Width", min = 0,
            max = 256, step = 1, decimals = 0, suffix = " px" },
        right = { key = "height", label = "Height", min = 0,
            max = 256, step = 1, decimals = 0, suffix = " px" } },
    { type = "SLIDER", key = "zoom", label = "Edge zoom",
        min = 0, max = 0.45, step = 0.01, decimals = 2, order = 5 },
    { type = "SLIDER", key = "crop", label = "Centered crop",
        min = 0.1, max = 1, step = 0.01, decimals = 2, order = 6 },
    { type = "DROPDOWN", key = "shape", label = "Shape", order = 7,
        values = { { value = "square", label = "Square" } } },
    { type = "RESET", label = "Reset Icons" },
}

NSkin:RegisterOptionGroup("appearance.icon", {
    controls = iconAppearanceControls,
    get = function()
        local style = NSkin:GetStyle("icon")
        return { border = CopyColor(style.border),
            borderMode = style.borderMode, borderSize = style.borderSize,
            width = tonumber(style.width) or 0,
            height = tonumber(style.height) or 0,
            zoom = style.zoom, crop = style.crop, shape = style.shape }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("icon")
        local changed = SetColor("icon.border", style.border, values.border, values.border[4])
        for _, key in ipairs({ "borderMode", "borderSize", "width", "height",
            "zoom", "crop", "shape" }) do
            changed = SetScalar("icon." .. key, style[key], values[key]) or changed
        end
        return changed == true
    end,
    reset = function()
        return ResetPaths({ "icon.border", "icon.borderMode", "icon.borderSize",
            "icon.width", "icon.height", "icon.zoom", "icon.crop", "icon.shape" })
    end,
})
NSkin:RegisterOptionGroup("shared.iconAppearance", {
    controls = iconAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "icon", GetAppearanceWindowID(context), context.id)
        return {
            border = CopyColor(style.border),
            borderMode = style.borderMode,
            borderSize = style.borderSize,
            width = tonumber(style.width) or 0,
            height = tonumber(style.height) or 0,
            zoom = style.zoom,
            crop = style.crop,
            shape = style.shape,
        }
    end,
    set = function(context, values)
        local changed = false
        for _, key in ipairs({ "border", "borderMode", "borderSize", "width",
            "height", "zoom", "crop", "shape" }) do
            if values[key] ~= nil then
                changed = SetElementValue(
                    context, "icon." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, {
            "icon.border", "icon.borderMode", "icon.borderSize",
            "icon.width", "icon.height", "icon.zoom", "icon.crop",
            "icon.shape",
        })
    end,
})
local textAppearanceControls = {}
AddTypographyControls(textAppearanceControls,
    { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" },
    "Text", 1, { type = "COLOR", key = "color", modeKey = "colorMode",
        label = "Color" })
NSkin:RegisterOptionGroup("shared.textAppearance", {
    controls = textAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "text", GetAppearanceWindowID(context), context.id)
        local values = { color = CopyColor(style.color), colorMode = style.colorMode }
        GetTypographyValues(values, style,
            { useGlobal = "useGlobal", font = "font", size = "textSize", outline = "outline" })
        return values
    end,
    set = function(context, values)
        local changed = SetElementTypography(context, "text", values,
            { font = "font", size = "textSize", outline = "outline" })
        if values.color ~= nil then
            changed = SetElementValue(context, "text.color", values.color) or changed
        end
        if values.colorMode ~= nil then
            changed = SetElementValue(context, "text.colorMode", values.colorMode) or changed
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, { "text.fontMode", "text.sizeMode",
            "text.outlineMode", "text.font", "text.textSize", "text.outline",
            "text.color", "text.colorMode" })
    end,
})

local sectionCardAppearanceControls = {
    { type = "SECTION", label = "Card", order = 10 },
    {
        type = "COLOR_PAIR", order = 11,
        left = { type = "COLOR", key = "border", modeKey = "borderMode",
            label = "Border" },
        right = { type = "COLOR", key = "background",
            modeKey = "backgroundMode", label = "Background" },
    },
    CreateBorderGeometryControls(12),
    { type = "SLIDER", key = "height", label = "Height (0 keeps Blizzard)",
        min = 0, max = 80, step = 1, decimals = 0, suffix = " px",
        order = 13 },
    { type = "SLIDER_PAIR", order = 14, centerReset = true,
        resetSubset = true, resetTooltip = "Reset text offsets",
        left = { key = "textOffsetX", label = "Text X", min = -40,
            max = 40, step = 1, decimals = 0, suffix = " px",
            resetValue = 10 },
        right = { key = "textOffsetY", label = "Text Y", min = -20,
            max = 20, step = 1, decimals = 0, suffix = " px",
            resetValue = 0 } },
    { type = "SLIDER", key = "iconSpacing", label = "Icon spacing",
        min = -20, max = 40, step = 1, decimals = 0, suffix = " px",
        order = 15 },
    { type = "SLIDER", key = "hoverAlpha", label = "Hover opacity",
        min = 0, max = 0.5, step = 0.01, decimals = 2, order = 16 },
    { type = "SECTION", label = "Expand / Collapse Glyph", order = 20 },
    { type = "COLOR", key = "glyph", modeKey = "glyphMode",
        label = "Color", order = 21 },
    { type = "SLIDER", key = "glyphSize", label = "Size", min = 8,
        max = 32, step = 1, decimals = 0, suffix = " px", order = 22 },
    { type = "SLIDER_PAIR", order = 23, centerReset = true,
        resetSubset = true, resetTooltip = "Reset glyph offsets",
        left = { key = "glyphOffsetX", label = "Glyph X", min = -40,
            max = 40, step = 1, decimals = 0, suffix = " px",
            resetValue = -10 },
        right = { key = "glyphOffsetY", label = "Glyph Y", min = -20,
            max = 20, step = 1, decimals = 0, suffix = " px",
            resetValue = 0 } },
}
AddTypographyControls(sectionCardAppearanceControls,
    { useGlobal = "useGlobal", font = "font", size = "textSize",
        outline = "outline" }, "Card Text", 1,
    { type = "COLOR", key = "text", modeKey = "textMode",
        label = "Color" })

local sectionCardResetPaths = {
    font = { "sectionCard.fontMode", "sectionCard.font" },
    textSize = { "sectionCard.sizeMode", "sectionCard.textSize" },
    outline = { "sectionCard.outlineMode", "sectionCard.outline" },
}
for _, key in ipairs({ "text", "textMode", "background", "backgroundMode",
    "border", "borderMode", "borderSize", "borderPadding", "height",
    "textOffsetX", "textOffsetY", "iconSpacing", "hoverAlpha", "glyph",
    "glyphMode", "glyphSize", "glyphOffsetX", "glyphOffsetY" }) do
    sectionCardResetPaths[key] = "sectionCard." .. key
end

NSkin:RegisterOptionGroup("shared.sectionCardAppearance", {
    controls = sectionCardAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "sectionCard", GetAppearanceWindowID(context), context.id)
        local values = {
            background = CopyColor(style.background),
            backgroundMode = style.backgroundMode,
            border = CopyColor(style.border), borderMode = style.borderMode,
            borderSize = style.borderSize, borderPadding = style.borderPadding,
            text = CopyColor(style.text), textMode = style.textMode,
            height = style.height, textOffsetX = style.textOffsetX,
            textOffsetY = style.textOffsetY, iconSpacing = style.iconSpacing,
            hoverAlpha = style.hoverAlpha, glyph = CopyColor(style.glyph),
            glyphMode = style.glyphMode, glyphSize = style.glyphSize,
            glyphOffsetX = style.glyphOffsetX,
            glyphOffsetY = style.glyphOffsetY,
        }
        GetTypographyValues(values, style,
            { useGlobal = "useGlobal", font = "font", size = "textSize",
                outline = "outline" })
        return values
    end,
    set = function(context, values)
        local changed = SetElementTypography(context, "sectionCard", values,
            { font = "font", size = "textSize", outline = "outline" })
        for _, key in ipairs({ "text", "textMode", "background",
            "backgroundMode", "border", "borderMode", "borderSize",
            "borderPadding", "height", "textOffsetX", "textOffsetY",
            "iconSpacing", "hoverAlpha", "glyph", "glyphMode", "glyphSize",
            "glyphOffsetX", "glyphOffsetY" }) do
            if values[key] ~= nil then
                changed = SetElementValue(context,
                    "sectionCard." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        local paths = {}
        for _, mapped in pairs(sectionCardResetPaths) do
            if type(mapped) == "table" then
                for i = 1, #mapped do paths[#paths + 1] = mapped[i] end
            else
                paths[#paths + 1] = mapped
            end
        end
        return ResetElementPaths(context, paths)
    end,
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(context, keys, sectionCardResetPaths)
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
local sectionHeaderResetPaths = {
    font = { "sectionHeader.fontMode", "sectionHeader.font" },
    textSize = { "sectionHeader.sizeMode", "sectionHeader.textSize" },
    outline = { "sectionHeader.outlineMode", "sectionHeader.outline" },
}
for _, key in ipairs({ "text", "textMode", "underlineVisible", "underlineSize",
    "underline", "underlineMode" }) do
    sectionHeaderResetPaths[key] = "sectionHeader." .. key
end
NSkin:RegisterOptionGroup("shared.sectionHeaderAppearance", {
    controls = headerAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "sectionHeader", GetAppearanceWindowID(context), context.id)
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
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(context, keys, sectionHeaderResetPaths)
    end,
})

NSkin:RegisterOptionGroup("shared.sectionHeaderPlacement", {
    controls = {
        { type = "SLIDER_PAIR", centerReset = true,
            resetGroup = true,
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
NSkin:RegisterOptionGroupSubset("shared.headerTextAppearance",
    "shared.sectionHeaderAppearance", {
        FindControl(headerAppearanceControls, "TYPOGRAPHY", nil, "Header Text"),
    })
NSkin:RegisterOptionGroupSubset("shared.headerUnderlineAppearance",
    "shared.sectionHeaderAppearance", {
        FindControl(headerAppearanceControls, "CHECKBOX", "underlineVisible"),
        FindControl(headerAppearanceControls, "SLIDER", "underlineSize"),
        { type = "COLOR", key = "underline", modeKey = "underlineMode",
            label = "Color", order = 100 },
    })
