local _, NSkin = ...

local COMPONENT_STATE = "components"

-- Buttons Skinning
local function ShowFlatButtonGlow(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if data and data.hoverGlow and (not button.IsEnabled or button:IsEnabled()) then
        data.hoverGlow:Show()
    end
end

local function HideFlatButtonGlow(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    if data and data.hoverGlow then data.hoverGlow:Hide() end
end

function NSkin:CreateFlatButtonGlow(button, alpha)
    if not button or not button.CreateTexture then return nil end
    local data = self:GetSkinData(button, COMPONENT_STATE)
    if data.hoverGlow then
        data.hoverGlow:SetColorTexture(1, 1, 1, alpha or 0.10)
        return data.hoverGlow
    end

    local glow = button:CreateTexture(nil, "OVERLAY", nil, -1)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, alpha or 0.10)
    glow:Hide()
    data.hoverGlow = glow

    if button.HookScript then
        button:HookScript("OnEnter", ShowFlatButtonGlow)
        button:HookScript("OnLeave", HideFlatButtonGlow)
    end

    return glow
end

function NSkin:SetFlatButtonLabel(button, label, size, offsetX, offsetY)
    if not button or not button.CreateFontString then return nil end

    local data = self:GetSkinData(button, COMPONENT_STATE)
    local text = data.label
    if not text then
        text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        data.label = text
    end

    text:ClearAllPoints()
    text:SetPoint("CENTER", button, "CENTER", offsetX or 0, offsetY or 0)
    text:SetText(label or "")

    if size then
        local font, _, flags = text:GetFont()
        if font then text:SetFont(font, size, flags) end
    end

    text:SetAlpha(1)
    text:Show()
    return text
end

function NSkin:SkinFlatButton(button, label, backgroundColor, borderColor,
    labelSize, labelOffsetX, labelOffsetY)
    if not button or not button.CreateTexture or not button.CreateFontString then return end

    local style = self:GetStyle("button")
    backgroundColor = backgroundColor or style.background
    borderColor = borderColor or style.border

    local background = self:GetFlatBackground(button)
    if not background then
        self:HideTextureRegions(button)
    end

    self:CreateFlatBackground(button, nil, backgroundColor, borderColor)
    self:CreateFlatButtonGlow(button, style.hoverAlpha)
    local text = self:SetFlatButtonLabel(button, label, labelSize, labelOffsetX, labelOffsetY)
    if text then text:SetTextColor(unpack(style.text)) end
end

-- Windows Skinning

function NSkin:SkinWindow(frame, backgroundAnchor)
    if not frame then return nil end

    local style = self:GetStyle("window")
    local anchor = backgroundAnchor or frame
    local data = self:GetSkinData(frame, COMPONENT_STATE)
    local background = data.windowBackground
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        background:SetAllPoints(anchor)
        data.windowBackground = background
    end
    background:SetColorTexture(unpack(style.background))

    local border = self:CreatePixelBorder(
        frame, "NSkinWindowBorder", style.borderSize, style.border, false, anchor
    )
    self:SetPixelBorderSize(border, style.borderSize)
    self:SetPixelBorderColor(border, unpack(style.border))
    return background, border
end

function NSkin:SkinWindowHeader(owner, anchor)
    if not owner or not anchor then return nil end

    local style = self:GetStyle("window").header
    local data = self:GetSkinData(owner, COMPONENT_STATE)
    local background = data.windowHeaderBackground
    if not background then
        background = owner:CreateTexture(nil, "BACKGROUND", nil, 7)
        background:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 0)
        background:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 0)
        data.windowHeaderBackground = background
    end
    background:SetHeight(style.height)
    background:SetColorTexture(unpack(style.background))
    return background
end

-- Tab Skinning

local function RefreshTabSelection(tab, selected)
    NSkin:SkinTab(tab, selected)
end

function NSkin:SkinTab(tab, selected, style)
    if not tab then return end
    style = style or self:GetStyle("tab")

    local background = self:GetFlatBackground(tab)
    if not background then
        if type(tab.SetTabSelected) == "function" and _G.hooksecurefunc then
            _G.hooksecurefunc(tab, "SetTabSelected", RefreshTabSelection)
        end
        self:HideTextureRegions(tab)
        background = self:CreateFlatBackground(tab, nil, style.background, style.border)
    end

    self:CreateFlatButtonGlow(tab, style.hoverAlpha)
    self:SetPixelBorderColor(self:GetPixelBorder(tab, "NSkinFlatBackgroundBorder"), unpack(style.border))
    background:SetColorTexture(unpack(
        selected and style.selectedBackground or style.background
    ))
    if tab.Text then tab.Text:SetTextColor(unpack(style.text)) end
end

function NSkin:SkinTabSystem(tabSystem, style)
    if not tabSystem or not tabSystem.tabs then return end
    style = style or self:GetStyle("tab")

    for i = 1, #tabSystem.tabs do
        local tab = tabSystem.tabs[i]
        local selected = tab and tab.IsSelected and tab:IsSelected()
        self:SkinTab(tab, selected, style)
    end
end
