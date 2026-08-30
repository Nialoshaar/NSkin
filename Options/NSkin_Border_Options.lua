local _, NSkin = ...

local function CopyColor(color)
    return { color[1], color[2], color[3], color[4] or 1 }
end

local function BuildBorderOptions(parent)
    local page = NSkin:CreateOptionsPage(parent)

    local title = page:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT")
    title:SetText("Border")

    local description = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    description:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -28)
    description:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -28)
    description:SetJustifyH("LEFT")
    description:SetText(
        "Choose the border inherited by NSkin components without their own override. "
        .. "Optionally enable an "
        .. "accent color for windows, tabs, search boxes, buttons, and "
        .. "progress-bar fills and borders. "
        .. "Icon and item-quality borders keep their own colors."
    )

    NSkin:CreateOptionsSection(page, "Shared border", 82)
    local colorLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -114)
    colorLabel:SetText("Color")

    local swatch = CreateFrame("Button", nil, page)
    swatch:SetSize(64, 24)
    swatch:SetPoint("LEFT", colorLabel, "RIGHT", 12, 0)

    local reset = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    reset:SetSize(110, 24)
    reset:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -18)
    if reset:GetFontString() then reset:GetFontString():SetAlpha(0) end

    NSkin:CreateOptionsSection(page, "Accent", 170)
    local accentToggle = NSkin:CreateOwnedOptionsCheckbox(page)
    accentToggle:SetPoint("TOPLEFT", page, "TOPLEFT", -4, -202)
    if accentToggle.Text then
        accentToggle.Text:SetText("Use accent for shared controls and progress bars")
    end

    local accentLabel = page:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    accentLabel:SetPoint("TOPLEFT", accentToggle, "BOTTOMLEFT", 4, -16)
    accentLabel:SetText("Accent color")

    local accentSwatch = CreateFrame("Button", nil, page)
    accentSwatch:SetSize(64, 24)
    accentSwatch:SetPoint("LEFT", accentLabel, "RIGHT", 12, 0)

    local resetAccent = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    resetAccent:SetSize(110, 24)
    resetAccent:SetPoint("TOPLEFT", accentLabel, "BOTTOMLEFT", 0, -20)
    if resetAccent:GetFontString() then resetAccent:GetFontString():SetAlpha(0) end

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

    local function ApplyAccentPickerColor()
        local red, green, blue = ColorPickerFrame:GetColorRGB()
        NSkin:SetAccentColor({ red, green, blue, 1 })
        page:Refresh()
    end

    accentSwatch:SetScript("OnClick", function()
        local previousColor = CopyColor(NSkin:GetAccentColor())
        local info = {
            r = previousColor[1],
            g = previousColor[2],
            b = previousColor[3],
            swatchFunc = ApplyAccentPickerColor,
            cancelFunc = function()
                NSkin:SetAccentColor(previousColor)
                page:Refresh()
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)

    accentToggle:SetScript("OnClick", function(self)
        NSkin:SetAccentColorEnabled(self:GetChecked() == true)
        page:Refresh()
    end)

    reset:SetScript("OnClick", function()
        NSkin:ResetBorderAccentColor()
        page:Refresh()
    end)

    resetAccent:SetScript("OnClick", function()
        NSkin:ResetAccentColor()
        page:Refresh()
    end)

    function page:ApplyTheme()
        local color = NSkin:GetBorderAccentColor()
        local buttonStyle = NSkin:GetStyle("button")
        NSkin:CreateFlatBackground(swatch, "NSkinBorderColorSwatch",
            color, buttonStyle.border)
        NSkin:CreateFlatBackground(accentSwatch, "NSkinAccentColorSwatch",
            NSkin:GetAccentColor(), buttonStyle.border)
        NSkin:SkinFlatButton(reset, "Reset Default", nil, nil, 12)
        NSkin:SkinFlatButton(resetAccent, "Reset Accent", nil, nil, 12)
        accentToggle:SetChecked(NSkin:IsAccentColorEnabled())
    end

    function page:Refresh()
        self:ApplyTheme()
    end

    page:SetContentHeight(330)
    return page
end

NSkin:RegisterOptionsPage({
    key = "border",
    label = "Border",
    group = "shared",
    order = 5,
    builder = BuildBorderOptions,
})
