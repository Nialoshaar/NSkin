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
RegisterColorAppearanceGroup("appearance.tab", "tab", {
    { type = "COLOR", key = "backgroundColor", label = "Tab background" },
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "COLOR", key = "selectedColor", label = "Selected background" },
    { type = "SLIDER", key = "selectedOpacity", label = "Selected opacity",
        min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "SLIDER", key = "hoverAlpha", label = "Hover opacity",
        min = 0, max = 0.5, step = 0.01, decimals = 2 },
    { type = "COLOR", key = "border", label = "Tab border" },
    { type = "RESET", label = "Reset Tabs" },
})
do
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

    function page:ApplyAppearance()
        if layoutView.ApplyAppearance then layoutView:ApplyAppearance() end
    end

    function page:Refresh()
        layoutView:Refresh()
        self:ApplyAppearance()
    end

    page:SetContentHeight(90 + layoutView:GetHeight())
    return page
end

-- Placement belongs to the docked Position category. Keep the option-group
-- definitions for the inspector, but do not expose placement globally.

end
NSkin:RegisterOptionGroup("shared.scrollBarAppearance", {
    controls = {
        {
            type = "COLOR_PAIR", order = 1,
            left = { type = "COLOR", key = "track", modeKey = "trackMode",
                label = "Bar" },
            right = { type = "COLOR", key = "thumb", modeKey = "thumbMode",
                label = "Thumb" },
        },
        {
            type = "COLOR", key = "arrow", modeKey = "arrowMode",
            label = "Arrows", order = 2,
        },
    },
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "scrollBar", GetAppearanceWindowID(context), context.id)
        return {
            track = CopyColor(style.track), trackMode = style.trackMode,
            thumb = CopyColor(style.thumb), thumbMode = style.thumbMode,
            arrow = CopyColor(style.arrow), arrowMode = style.arrowMode,
        }
    end,
    set = function(context, values)
        local changed
        for _, key in ipairs({ "track", "trackMode", "thumb", "thumbMode",
            "arrow", "arrowMode" })
        do
            if values[key] ~= nil then
                changed = SetElementValue(
                    context, "scrollBar." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, {
            "scrollBar.track", "scrollBar.trackMode",
            "scrollBar.thumb", "scrollBar.thumbMode",
            "scrollBar.arrow", "scrollBar.arrowMode",
        })
    end,
})

local sideTabResetPaths = {
    width = "sideTab.width",
    height = "sideTab.height",
    border = "sideTab.border",
    borderMode = "sideTab.borderMode",
    background = "sideTab.background",
    backgroundMode = "sideTab.backgroundMode",
    hoverAlpha = "sideTab.hoverAlpha",
}

NSkin:RegisterOptionGroup("shared.sideTabAppearance", {
    controls = {
        {
            type = "SLIDER_PAIR", order = 1, centerReset = true,
            resetSubset = true,
            resetTooltip = "Reset side-tab width and height",
            left = { key = "width", label = "Width", min = 20,
                max = 100, step = 1, decimals = 0, suffix = " px",
                resetValue = 0 },
            right = { key = "height", label = "Height", min = 20,
                max = 100, step = 1, decimals = 0, suffix = " px",
                resetValue = 0 },
        },
        {
            type = "COLOR_PAIR", order = 2,
            left = { type = "COLOR", key = "border",
                modeKey = "borderMode", label = "Border" },
            right = { type = "COLOR", key = "background",
                modeKey = "backgroundMode", label = "Background" },
        },
        {
            type = "SLIDER", key = "hoverAlpha",
            label = "Highlight opacity", min = 0, max = 1,
            step = 0.05, decimals = 2, order = 3,
        },
    },
    get = function(context)
        local style = NSkin:GetAppearanceStyle(
            "sideTab", GetAppearanceWindowID(context), context.id)
        local target = context.target
        return {
            width = tonumber(style.width) and style.width > 0 and style.width
                or (target and target.GetWidth and target:GetWidth()) or 43,
            height = tonumber(style.height) and style.height > 0 and style.height
                or (target and target.GetHeight and target:GetHeight()) or 55,
            border = CopyColor(style.border),
            borderMode = style.borderMode,
            background = CopyColor(style.background),
            backgroundMode = style.backgroundMode,
            hoverAlpha = tonumber(style.hoverAlpha) or 0.10,
        }
    end,
    set = function(context, values)
        local changed
        for _, key in ipairs({ "width", "height", "border", "borderMode",
            "background", "backgroundMode", "hoverAlpha" })
        do
            if values[key] ~= nil then
                changed = SetElementValue(
                    context, "sideTab." .. key, values[key]) or changed
            end
        end
        return changed == true
    end,
    reset = function(context)
        return ResetElementPaths(context, {
            "sideTab.width", "sideTab.height", "sideTab.border",
            "sideTab.borderMode", "sideTab.background",
            "sideTab.backgroundMode", "sideTab.hoverAlpha",
        })
    end,
    resetSubset = function(context, keys)
        return ResetMappedElementKeys(context, keys, sideTabResetPaths)
    end,
})

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
        local tabGroup = NSkin:GetTabGroup(context.id)
        local spacing = tonumber(style.spacing)
        if spacing == nil and tabGroup then
            spacing = tonumber(tabGroup.originalSpacing)
        end
        local values = { background = CopyColor(style.background),
            selectedBackground = CopyColor(style.selectedBackground),
            border = CopyColor(style.border), text = CopyColor(style.text),
            textMode = style.textMode, borderSize = style.borderSize,
            borderPadding = style.borderPadding,
            width = tonumber(style.width) and style.width > 0
                and style.width or currentWidth,
            height = tonumber(style.height) and style.height > 0
                and style.height or currentHeight,
            spacing = spacing or 0,
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
