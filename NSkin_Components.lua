local _, NSkin = ...

local COMPONENT_STATE = "components"
local TAB_SPACING_STATE = "tabSpacing"
local spacedTabs = setmetatable({}, { __mode = "k" })

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
    borderColor = borderColor or self:GetBorderAccentColor()

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
        frame, "NSkinWindowBorder", style.borderSize, self:GetBorderAccentColor(), false, anchor
    )
    self:SetPixelBorderSize(border, style.borderSize)
    self:SetPixelBorderColor(border, unpack(self:GetBorderAccentColor()))
    return background, border
end

function NSkin:SkinWindowHeader(frame)
    if not frame then return nil end

    local style = self:GetStyle("window").header
    local data = self:GetSkinData(frame, COMPONENT_STATE)
    local background = data.windowHeaderBackground
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
        background:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        background:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
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
        background = self:CreateFlatBackground(tab, nil, style.background, self:GetBorderAccentColor())
    end

    self:CreateFlatButtonGlow(tab, style.hoverAlpha)
    self:SetPixelBorderColor(self:GetPixelBorder(tab, "NSkinFlatBackgroundBorder"), unpack(self:GetBorderAccentColor()))
    background:SetColorTexture(unpack(
        selected and style.selectedBackground or style.background
    ))
    if tab.Text then tab.Text:SetTextColor(unpack(style.text)) end
end

function NSkin:ApplyTabSpacing(tab, previousTab, spacing)
    if type(spacing) ~= "number" or spacing == 0
        or not tab or not previousTab or not tab.GetPoint or not tab.SetPoint
        or (tab.IsForbidden and tab:IsForbidden())
        or (tab.IsProtected and tab:IsProtected())
        or (tab.GetNumPoints and tab:GetNumPoints() ~= 1)
    then
        return
    end

    local data = self:GetSkinData(tab, TAB_SPACING_STATE)
    if not data.point then
        local point, relativeTo, relativePoint, offsetX, offsetY = tab:GetPoint(1)
        if relativeTo ~= previousTab then return end
        data.point = point
        data.relativeTo = relativeTo
        data.relativePoint = relativePoint
        data.offsetX = offsetX or 0
        data.offsetY = offsetY or 0
    elseif data.relativeTo ~= previousTab then
        return
    end

    local offsetX = data.offsetX
    local offsetY = data.offsetY
    local point = data.point
    local relativePoint = data.relativePoint
    if point and relativePoint then
        if point:find("LEFT", 1, true) and relativePoint:find("RIGHT", 1, true) then
            offsetX = offsetX + spacing
        elseif point:find("RIGHT", 1, true) and relativePoint:find("LEFT", 1, true) then
            offsetX = offsetX - spacing
        elseif point:find("TOP", 1, true) and relativePoint:find("BOTTOM", 1, true) then
            offsetY = offsetY - spacing
        elseif point:find("BOTTOM", 1, true) and relativePoint:find("TOP", 1, true) then
            offsetY = offsetY + spacing
        else
            return
        end
    end

    tab:ClearAllPoints()
    tab:SetPoint(point, data.relativeTo, relativePoint, offsetX, offsetY)
    spacedTabs[tab] = data
end

function NSkin:RestoreTabSpacing()
    for tab, data in pairs(spacedTabs) do
        if tab and data.point and tab.ClearAllPoints and tab.SetPoint
            and not (tab.IsForbidden and tab:IsForbidden())
            and not (tab.IsProtected and tab:IsProtected())
        then
            tab:ClearAllPoints()
            tab:SetPoint(data.point, data.relativeTo, data.relativePoint,
                data.offsetX, data.offsetY)
        end
        data.point = nil
        data.relativeTo = nil
        data.relativePoint = nil
        data.offsetX = nil
        data.offsetY = nil
        spacedTabs[tab] = nil
    end
end

function NSkin:SkinTabSystem(tabSystem, style)
    if not tabSystem or not tabSystem.tabs then return end
    style = style or self:GetStyle("tab")
    local spacing = tonumber(style.spacing) or 0

    for i = 1, #tabSystem.tabs do
        local tab = tabSystem.tabs[i]
        local selected = tab and tab.IsSelected and tab:IsSelected()
        self:SkinTab(tab, selected, style)
        if i > 1 and spacing ~= 0 then
            self:ApplyTabSpacing(tab, tabSystem.tabs[i - 1], spacing)
        end
    end
end
