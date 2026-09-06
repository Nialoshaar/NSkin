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
NSkin:RegisterOptionGroup("appearance.window", {
    controls = {
        { type = "COLOR", key = "backgroundColor", label = "Window background" },
        { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
            min = 0, max = 1, step = 0.05, decimals = 2 },
        { type = "SLIDER", key = "borderSize", label = "Border thickness",
            min = 1, max = 4, step = 1, suffix = " px" },
        { type = "COLOR", key = "headerColor", label = "Header background" },
        { type = "SLIDER", key = "headerOpacity", label = "Header opacity",
            min = 0, max = 1, step = 0.05, decimals = 2 },
        { type = "SLIDER", key = "headerHeight", label = "Header height",
            min = 16, max = 40, step = 1, suffix = " px" },
        { type = "RESET", label = "Reset Window" },
    },
    get = function()
        local style = NSkin:GetStyle("window")
        return {
            backgroundColor = CopyColor(style.background),
            backgroundOpacity = style.background[4] or 1,
            borderSize = style.borderSize,
            headerColor = CopyColor(style.header.background),
            headerOpacity = style.header.background[4] or 1,
            headerHeight = style.header.height,
        }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("window")
        local changed = SetColor("window.background", style.background,
            values.backgroundColor, values.backgroundOpacity)
        changed = SetScalar("window.borderSize", style.borderSize, values.borderSize) or changed
        changed = SetColor("window.header.background", style.header.background,
            values.headerColor, values.headerOpacity) or changed
        changed = SetScalar("window.header.height", style.header.height,
            values.headerHeight) or changed
        return changed == true
    end,
    reset = function()
        return ResetPaths({ "window.background", "window.borderSize",
            "window.header.background", "window.header.height" })
    end,
})
local windowHeaderControlsAppearance = {
    {
        type = "SLIDER_PAIR", order = 1, centerReset = true,
        resetSubset = true,
        resetTooltip = "Reset button width and height",
        left = { key = "width", label = "Button size", min = 16,
            max = 64, step = 1, decimals = 0, suffix = " px" },
        right = { key = "height", label = "Height", min = 16,
            max = 64, step = 1, decimals = 0, suffix = " px" },
    },
    {
        type = "SLIDER", key = "textSize", label = "Text size",
        min = 8, max = 32, step = 1, decimals = 0, suffix = " px",
        order = 2,
    },
    {
        type = "COLOR_PAIR", order = 3,
        left = { type = "COLOR", key = "border", modeKey = "borderMode",
            label = "Border" },
        right = { type = "COLOR", key = "background",
            modeKey = "backgroundMode", label = "Background" },
    },
    {
        type = "SLIDER", key = "hoverAlpha", label = "Highlight intensity",
        min = 0, max = 1, step = 0.05, decimals = 2, order = 4,
    },
}

local windowHeaderControlResetPaths = {
    width = "windowHeaderButton.width",
    height = "windowHeaderButton.height",
    textSize = "windowHeaderButton.textSize",
    border = "windowHeaderButton.border",
    borderMode = "windowHeaderButton.borderMode",
    background = "windowHeaderButton.background",
    backgroundMode = "windowHeaderButton.backgroundMode",
    hoverAlpha = "windowHeaderButton.hoverAlpha",
}

NSkin:RegisterOptionGroup("shared.windowHeaderControlsAppearance", {
    controls = windowHeaderControlsAppearance,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "windowHeaderButton", GetAppearanceWindowID(context), context.id)
        local regions = NSkin:GetWindowHeaderControlRegions(
            context.window, context.id)
        local closeButton = regions[1] or context.target
        return {
            width = tonumber(style.width) and style.width > 0 and style.width
                or (closeButton
                and closeButton.GetWidth and closeButton:GetWidth()) or 24,
            height = tonumber(style.height) and style.height > 0 and style.height
                or (closeButton
                and closeButton.GetHeight and closeButton:GetHeight()) or 24,
            textSize = tonumber(style.textSize) or 20,
            border = CopyColor(style.border),
            borderMode = style.borderMode,
            background = CopyColor(style.background),
            backgroundMode = style.backgroundMode,
            hoverAlpha = tonumber(style.hoverAlpha) or 0.10,
        }
    end,
    set = function(context, values)
        local changed
        for _, key in ipairs({ "width", "height", "textSize", "border",
            "borderMode", "background", "backgroundMode", "hoverAlpha" })
        do
            if values[key] ~= nil then
                changed = SetElementValue(context,
                    "windowHeaderButton." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, {
            "windowHeaderButton.width", "windowHeaderButton.height",
            "windowHeaderButton.textSize", "windowHeaderButton.border",
            "windowHeaderButton.borderMode",
            "windowHeaderButton.background",
            "windowHeaderButton.backgroundMode",
            "windowHeaderButton.hoverAlpha",
        })
    end,
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(
            context, keys, windowHeaderControlResetPaths)
    end,
})
local windowAppearanceControls = {
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2, order = 3 },
    CreateBorderGeometryControls(4),
    { type = "SLIDER", key = "headerOpacity", label = "Header opacity",
        min = 0, max = 1, step = 0.05, decimals = 2, order = 22 },
    { type = "CHECKBOX", key = "matchHeader",
        label = "Match header to background", order = 23 },
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
local windowResetPaths = {
    background = "window.background", backgroundOpacity = "window.background",
    backgroundMode = "window.backgroundMode", border = "window.border",
    borderMode = "window.borderMode", borderSize = "window.borderSize",
    borderPadding = "window.borderPadding",
    headerBackground = "window.header.background",
    headerOpacity = "window.header.background",
    headerBackgroundMode = "window.header.backgroundMode",
    matchHeader = "window.header.matchBackground",
    headerText = "window.header.text", headerTextMode = "window.header.textMode",
    headerFont = { "window.header.fontMode", "window.header.font" },
    headerTextSize = { "window.header.sizeMode", "window.header.textSize" },
    headerOutline = { "window.header.outlineMode", "window.header.outline" },
}
NSkin:RegisterOptionGroup("shared.windowAppearance", {
    controls = windowAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "window", GetAppearanceWindowID(context), context.id)
        local values = { background = CopyColor(style.background),
            backgroundOpacity = style.background[4] or 1,
            border = CopyColor(style.border), borderMode = style.borderMode,
            borderSize = style.borderSize, borderPadding = style.borderPadding,
            headerBackground = CopyColor(style.header.background),
            headerText = CopyColor(style.header.text),
            headerTextMode = style.header.textMode,
            headerOpacity = style.header.background[4] or 1,
            backgroundMode = style.backgroundMode,
            headerBackgroundMode = style.header.backgroundMode,
            matchHeader = style.header.matchBackground == true }
        GetTypographyValues(values, style.header,
            { useGlobal = "headerUseGlobal", font = "headerFont",
                size = "headerTextSize", outline = "headerOutline" })
        return values
    end,
    set = function(context, values)
        local style = NSkin:GetAppearanceStyle(
            "window", GetAppearanceWindowID(context), context.id)
        local mapping = {
            ["window.backgroundMode"] = values.backgroundMode,
            ["window.border"] = values.border,
            ["window.borderMode"] = values.borderMode,
            ["window.borderSize"] = values.borderSize,
            ["window.borderPadding"] = values.borderPadding,
            ["window.header.backgroundMode"] = values.headerBackgroundMode,
            ["window.header.matchBackground"] = values.matchHeader,
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
            "window.borderPadding",
            "window.header.background", "window.header.backgroundMode",
            "window.header.matchBackground",
            "window.header.text", "window.header.textMode",
            "window.header.fontMode",
            "window.header.sizeMode", "window.header.outlineMode",
            "window.header.font", "window.header.textSize", "window.header.outline" })
    end,
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(context, keys, windowResetPaths)
    end,
})
local windowColors = FindControl(windowAppearanceControls, "COLOR_PAIR")
NSkin:RegisterOptionGroupSubset("shared.windowBorderAppearance", "shared.windowAppearance", {
    FindControl(windowAppearanceControls, "SLIDER_PAIR", nil, nil),
    windowColors.left,
})
NSkin:RegisterOptionGroupSubset("shared.windowBackgroundAppearance", "shared.windowAppearance", {
    FindControl(windowAppearanceControls, "SLIDER", "backgroundOpacity"),
    windowColors.right,
})
NSkin:RegisterOptionGroupSubset("shared.windowSurfaceAppearance", "shared.windowAppearance", {
    FindControl(windowAppearanceControls, "SLIDER_PAIR", nil, nil),
    FindControl(windowAppearanceControls, "SLIDER", "backgroundOpacity"),
    FindControl(windowAppearanceControls, "CHECKBOX", "matchHeader"),
    { type = "COLOR_PAIR", order = 100,
        left = windowColors.left, right = windowColors.right },
})
NSkin:RegisterOptionGroupSubset("shared.windowHeaderAppearance", "shared.windowAppearance", {
    FindControl(windowAppearanceControls, "TYPOGRAPHY", nil, "Header"),
    FindControl(windowAppearanceControls, "SLIDER", "headerOpacity"),
    { type = "COLOR", key = "headerBackground",
        modeKey = "headerBackgroundMode", label = "Background", order = 100 },
})
