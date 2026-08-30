local _, NSkin = ...

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

local function ColorsEqual(left, right)
    return left and right
        and left[1] == right[1] and left[2] == right[2]
        and left[3] == right[3] and (left[4] or 1) == (right[4] or 1)
end

local function ColorWithOpacity(color, opacity)
    return { color[1], color[2], color[3], tonumber(opacity) or color[4] or 1 }
end

local function SetColor(path, current, color, opacity)
    local value = ColorWithOpacity(color, opacity)
    if ColorsEqual(current, value) then return false end
    return NSkin:SetThemeOverride(path, value)
end

local function SetScalar(path, current, value)
    if value == nil or current == value then return false end
    return NSkin:SetThemeOverride(path, value)
end

local function ResetPaths(paths)
    local changed
    for i = 1, #paths do changed = NSkin:ResetThemeOverride(paths[i]) or changed end
    return changed == true
end

NSkin:RegisterOptionGroup("appearance.typography", {
    controls = {
        { type = "DROPDOWN", key = "font", label = "Global font",
            values = function() return NSkin:GetAvailableFontOptions(false) end },
        { type = "SLIDER", key = "size", label = "Global text size", min = 8,
            max = 32, step = 1, suffix = " px" },
        { type = "DROPDOWN", key = "outline", label = "Global outline", values = {
            { value = "", label = "None" },
            { value = "OUTLINE", label = "Outline" },
            { value = "THICKOUTLINE", label = "Thick outline" },
            { value = "MONOCHROME,OUTLINE", label = "Monochrome outline" },
        } },
        { type = "RESET", label = "Reset Typography" },
    },
    get = function()
        local style = NSkin:GetStyle("typography")
        return { font = style.font, size = style.size, outline = style.outline }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("typography")
        local changed = SetScalar("typography.font", style.font, values.font)
        changed = SetScalar("typography.size", style.size, values.size) or changed
        changed = SetScalar("typography.outline", style.outline, values.outline) or changed
        return changed == true
    end,
    reset = function()
        return ResetPaths({ "typography.font", "typography.size", "typography.outline" })
    end,
})

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

local function RegisterColorAppearanceGroup(id, styleName, controls)
    NSkin:RegisterOptionGroup(id, {
        controls = controls,
        get = function()
            local style = NSkin:GetStyle(styleName)
            local values = {}
            if style.background then
                values.backgroundColor = CopyColor(style.background)
                values.backgroundOpacity = style.background[4] or 1
            end
            if style.selectedBackground then
                values.selectedColor = CopyColor(style.selectedBackground)
                values.selectedOpacity = style.selectedBackground[4] or 1
            end
            if style.border then
                values.border = CopyColor(NSkin:GetComponentBorderSetting(styleName, style))
            end
            values.hoverAlpha = style.hoverAlpha
            return values
        end,
        set = function(_, values)
            local style = NSkin:GetStyle(styleName)
            local changed
            if style.background then
                changed = SetColor(styleName .. ".background", style.background,
                    values.backgroundColor, values.backgroundOpacity)
            end
            if style.selectedBackground then
                changed = SetColor(styleName .. ".selectedBackground",
                    style.selectedBackground, values.selectedColor,
                    values.selectedOpacity) or changed
            end
            if style.border and values.border then
                local currentBorder = NSkin:GetComponentBorderSetting(styleName, style)
                if not ColorsEqual(currentBorder, values.border) then
                    changed = NSkin:SetComponentBorderColor(styleName, values.border) or changed
                end
            end
            changed = SetScalar(styleName .. ".hoverAlpha", style.hoverAlpha,
                values.hoverAlpha) or changed
            return changed == true
        end,
        reset = function()
            local paths = { styleName .. ".background" }
            if NSkin.defaultTheme[styleName].selectedBackground then
                paths[#paths + 1] = styleName .. ".selectedBackground"
            end
            if NSkin.defaultTheme[styleName].hoverAlpha ~= nil then
                paths[#paths + 1] = styleName .. ".hoverAlpha"
            end
            local changed = ResetPaths(paths)
            changed = NSkin:ResetComponentBorderColor(styleName) or changed
            return changed == true
        end,
    })
end

RegisterColorAppearanceGroup("appearance.button", "button", {
    { type = "COLOR", key = "backgroundColor", label = "Button background" },
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "SLIDER", key = "hoverAlpha", label = "Hover opacity",
        min = 0, max = 0.5, step = 0.01, decimals = 2 },
    { type = "COLOR", key = "border", label = "Button border" },
    { type = "RESET", label = "Reset Buttons" },
})

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

RegisterColorAppearanceGroup("appearance.search", "searchBox", {
    { type = "COLOR", key = "backgroundColor", label = "Search background" },
    { type = "SLIDER", key = "backgroundOpacity", label = "Background opacity",
        min = 0, max = 1, step = 0.05, decimals = 2 },
    { type = "COLOR", key = "border", label = "Search border" },
    { type = "RESET", label = "Reset Search Boxes" },
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

NSkin:RegisterOptionGroup("appearance.icon", {
    controls = {
        { type = "COLOR", key = "border", label = "Icon border" },
        { type = "SLIDER", key = "crop", label = "Icon crop",
            min = 0, max = 0.2, step = 0.01, decimals = 2 },
        { type = "CHECKBOX", key = "qualityColor", label = "Use item-quality colors" },
        { type = "RESET", label = "Reset Icons" },
    },
    get = function()
        local style = NSkin:GetStyle("icon")
        return { border = CopyColor(style.border), crop = style.crop,
            qualityColor = style.qualityColor }
    end,
    set = function(_, values)
        local style = NSkin:GetStyle("icon")
        local changed = SetColor("icon.border", style.border, values.border, values.border[4])
        changed = SetScalar("icon.crop", style.crop, values.crop) or changed
        changed = SetScalar("icon.qualityColor", style.qualityColor,
            values.qualityColor) or changed
        return changed == true
    end,
    reset = function()
        return ResetPaths({ "icon.border", "icon.crop", "icon.qualityColor" })
    end,
})

local function BuildAppearanceOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)
    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Appearance")

    local views = {}
    local y = 38
    local groups = {
        { "Typography", "appearance.typography" },
        { "Windows", "appearance.window" },
        { "Buttons", "appearance.button" },
        { "Tabs", "appearance.tab" },
        { "Search boxes", "appearance.search" },
        { "Progress bars", "appearance.progress" },
        { "Icons", "appearance.icon" },
    }
    for i = 1, #groups do
        local _, contentY = NSkin:CreateOptionsSection(page, groups[i][1], y)
        local view = NSkin:CreateOptionGroupView(page, groups[i][2], "FULL", page)
        view:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -contentY)
        views[#views + 1] = view
        y = contentY + view:GetHeight() + 24
    end

    function page:ApplyTheme()
        for i = 1, #views do views[i]:ApplyTheme() end
    end
    function page:Refresh()
        for i = 1, #views do views[i]:Refresh() end
        self:ApplyTheme()
    end

    page:SetContentHeight(y)
    return page
end

NSkin:RegisterOptionsPage({
    key = "appearance",
    label = "Appearance",
    group = "shared",
    order = 1,
    builder = BuildAppearanceOptions,
})
