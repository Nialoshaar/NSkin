local _, NSkin = ...

local function ShowFlatButtonGlow(button)
    if button.NSkinHoverGlow and (not button.IsEnabled or button:IsEnabled()) then
        button.NSkinHoverGlow:Show()
    end
end

local function HideFlatButtonGlow(button)
    if button.NSkinHoverGlow then button.NSkinHoverGlow:Hide() end
end

function NSkin:CreateFlatButtonGlow(button)
    if not button or not button.CreateTexture then return nil end
    if button.NSkinHoverGlow then return button.NSkinHoverGlow end

    local glow = button:CreateTexture(nil, "OVERLAY", nil, -1)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("BOTTOMRIGHT", -1, 1)
    glow:SetColorTexture(1, 1, 1, 0.10)
    glow:Hide()
    button.NSkinHoverGlow = glow

    if button.HookScript then
        button:HookScript("OnEnter", ShowFlatButtonGlow)
        button:HookScript("OnLeave", HideFlatButtonGlow)
    end

    return glow
end

function NSkin:SetFlatButtonLabel(button, label, size, offsetX, offsetY)
    if not button or not button.CreateFontString then return nil end

    local text = button.NSkinLabel
    if not text then
        text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        button.NSkinLabel = text
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

    if not button.NSkinFlatBackground then
        self:HideTextureRegions(button)
    end

    self:CreateFlatBackground(button, nil, backgroundColor, borderColor)
    self:CreateFlatButtonGlow(button)
    self:SetFlatButtonLabel(button, label, labelSize, labelOffsetX, labelOffsetY)
end
