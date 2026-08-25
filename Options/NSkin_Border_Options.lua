local _, NSkin = ...

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

local function BuildBorderOptions(optionsFrame)
    local page = CreateFrame("Frame", nil, optionsFrame)
    page:SetAllPoints(optionsFrame)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT",
        optionsFrame.NSkinContentLeft or 180, -102)
    title:SetText("Border")

    local description = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    description:SetPoint("RIGHT", optionsFrame, "RIGHT", -20, 0)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Choose the accent color used by NSkin windows, tabs, buttons, "
        .. "search boxes, progress bars, and cards. Icon and item-quality "
        .. "borders keep their own colors."
    )

    local colorLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", description, "BOTTOMLEFT", 0, -18)
    colorLabel:SetText("Color")

    local swatch = CreateFrame("Button", nil, page)
    swatch:SetSize(64, 24)
    swatch:SetPoint("LEFT", colorLabel, "RIGHT", 12, 0)

    local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    reset:SetSize(110, 24)
    reset:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -20)
    if reset:GetFontString() then reset:GetFontString():SetAlpha(0) end

    local function ApplyPickerColor()
        local red, green, blue = ColorPickerFrame:GetColorRGB()
        NSkin:SetBorderAccentColor({ red, green, blue, 1 })
        page:Refresh()
    end

    swatch:SetScript("OnClick", function()
        local previousColor = CopyColor(NSkin:GetBorderAccentColor())
        local info = {
            r = previousColor[1],
            g = previousColor[2],
            b = previousColor[3],
            swatchFunc = ApplyPickerColor,
            cancelFunc = function()
                NSkin:SetBorderAccentColor(previousColor)
                page:Refresh()
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    reset:SetScript("OnClick", function()
        NSkin:ResetBorderAccentColor()
        page:Refresh()
    end)

    function page:ApplyTheme()
        local color = NSkin:GetBorderAccentColor()
        local buttonStyle = NSkin:GetStyle("button")
        NSkin:CreateFlatBackground(swatch, "NSkinBorderColorSwatch",
            color, buttonStyle.border)
        NSkin:SkinFlatButton(reset, "Reset Default", nil, nil, 12)
    end

    function page:Refresh()
        self:ApplyTheme()
    end

    return page
end

NSkin:RegisterOptionsPage({
    key = "border",
    label = "Border",
    group = "shared",
    order = 5,
    builder = BuildBorderOptions,
})
