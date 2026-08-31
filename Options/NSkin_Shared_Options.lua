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
            resetGroup = true,
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

local GLOBAL_VALUE = "__NSKIN_GLOBAL__"
local function FONT_VALUES()
    return NSkin:GetAvailableFontOptions(true)
end
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

local function GetAppearanceWindowID(context)
    return context.appearanceWindowID
end

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
    return NSkin:SetElementAppearanceOverride(
        context.id, GetAppearanceWindowID(context), path, value)
end

local function ResetElementPaths(context, paths)
    return NSkin:ResetElementAppearanceOverrides(context.id, paths)
end

local function CreateBorderGeometryControls(order)
    return { type = "SLIDER_PAIR", order = order, centerReset = true,
        resetTooltip = "Reset border size and padding",
        left = { key = "borderSize", label = "Border size", min = 1,
            max = 4, step = 1, decimals = 0, suffix = " px", resetValue = 1 },
        right = { key = "borderPadding", label = "Border padding", min = -10,
            max = 20, step = 1, decimals = 0, suffix = " px", resetValue = 0 } }
end

local function ResetMappedElementKeys(context, keys, pathsByKey)
    local paths, seen = {}, {}
    for key in pairs(keys) do
        local mapped = pathsByKey[key]
        if type(mapped) == "string" then mapped = { mapped } end
        if type(mapped) == "table" then
            for i = 1, #mapped do
                if not seen[mapped[i]] then
                    seen[mapped[i]] = true
                    paths[#paths + 1] = mapped[i]
                end
            end
        end
    end
    return #paths > 0 and ResetElementPaths(context, paths) or false
end

local tabBorderGeometryControls = CreateBorderGeometryControls(13)
local tabSizeControls = {
    type = "SLIDER_PAIR", order = 2, centerReset = true,
    resetTooltip = "Reset tab width and height",
    left = { key = "width", label = "Width", min = 40, max = 300,
        step = 1, decimals = 0, suffix = " px", resetValue = 0 },
    right = { key = "height", label = "Height", min = 16, max = 80,
        step = 1, decimals = 0, suffix = " px", resetValue = 0 },
}
local tabSpacingControl = { type = "SLIDER", key = "spacing", label = "Spacing",
    min = -30, max = 30, step = 1, decimals = 0, suffix = " px", order = 3 }
local tabAppearanceControls = {
    tabSizeControls, tabSpacingControl, tabBorderGeometryControls,
}
local function GetFirstTabSize(context)
    local group = context and NSkin:GetTabGroup(context.id)
    local tabs = group and ((group.container and group.container.tabs) or group.tabs)
    local tab = type(tabs) == "table" and tabs[1]
    return tab and tab.GetWidth and tab:GetWidth() or 40,
        tab and tab.GetHeight and tab:GetHeight() or 16
end
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
local tabResetPaths = {
    font = { "tab.fontMode", "tab.font" },
    textSize = { "tab.sizeMode", "tab.textSize" },
    outline = { "tab.outlineMode", "tab.outline" },
}
for _, key in ipairs({ "text", "textMode", "background", "backgroundMode",
    "selectedBackground", "selectedBackgroundMode", "border", "borderMode",
    "borderSize", "borderPadding", "width", "height", "spacing" }) do
    tabResetPaths[key] = "tab." .. key
end
NSkin:RegisterOptionGroup("shared.tabAppearance", {
    controls = tabAppearanceControls,
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "tab", GetAppearanceWindowID(context), context.id)
        local currentWidth, currentHeight = GetFirstTabSize(context)
        local values = { background = CopyColor(style.background),
            selectedBackground = CopyColor(style.selectedBackground),
            border = CopyColor(style.border), text = CopyColor(style.text),
            textMode = style.textMode, borderSize = style.borderSize,
            borderPadding = style.borderPadding,
            width = tonumber(style.width) and style.width > 0
                and style.width or currentWidth,
            height = tonumber(style.height) and style.height > 0
                and style.height or currentHeight,
            spacing = style.spacing,
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
            "selectedBackgroundMode", "border", "borderMode", "borderSize",
            "borderPadding", "width", "height", "spacing" }) do
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
            "tab.borderSize", "tab.borderPadding", "tab.width", "tab.height",
            "tab.spacing" })
    end,
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(context, keys, tabResetPaths)
    end,
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
    tabBorderGeometryControls,
    tabColors.left,
})
NSkin:RegisterOptionGroupSubset("shared.tabBackgroundAppearance", "shared.tabAppearance", {
    tabColors.right,
    FindControl(tabAppearanceControls, "COLOR", "selectedBackground"),
})
NSkin:RegisterOptionGroupSubset("shared.tabSurfaceAppearance", "shared.tabAppearance", {
    tabSizeControls,
    tabSpacingControl,
    tabBorderGeometryControls,
    { type = "COLOR_PAIR", order = 100,
        left = tabColors.left, right = tabColors.right },
    { type = "COLOR", key = "selectedBackground",
        modeKey = "selectedBackgroundMode", label = "Selected background",
        order = 101 },
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
