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

function NSkin:LayoutTabGroup(tabs, options)
    if type(tabs) ~= "table" then return end
    options = options or {}

    local spacing = tonumber(options.spacing) or self:GetTabSpacing()
    local vertical = options.orientation == "VERTICAL"
    local anchor = options.anchor
    local anchorPoint = anchor and anchor.point
    local anchorRelativeTo = anchor and anchor.relativeTo
    local anchorRelativePoint = anchor and anchor.relativePoint
    local anchorX = anchor and anchor.x or 0
    local anchorY = anchor and anchor.y or 0
    local owner = options.owner
    local edge = options.edge
    local previous

    if owner and edge == "BOTTOM" then
        local layout = options.placement or self:GetStyle("tab").bottom
        local visibleCount = 0
        local totalWidth = 0
        for i = 1, #tabs do
            local tab = tabs[i]
            if tab and (not tab.IsShown or tab:IsShown()) then
                visibleCount = visibleCount + 1
                totalWidth = totalWidth + (tab.GetWidth and tab:GetWidth() or 0)
            end
        end
        totalWidth = totalWidth + math.max(0, visibleCount - 1) * spacing
        local relativePoint = "BOTTOMLEFT"
        local alignment = layout.alignment or layout.anchor
        local startX = layout.alongOffset or layout.offsetX or 0
        if alignment == "CENTER" then
            relativePoint = "BOTTOM"
            startX = startX - totalWidth / 2
        elseif alignment == "RIGHT" then
            relativePoint = "BOTTOMRIGHT"
            startX = startX - totalWidth
        end
        anchorPoint = "TOPLEFT"
        anchorRelativeTo = owner
        anchorRelativePoint = relativePoint
        anchorX = startX
        anchorY = layout.edgeOffset or layout.offsetY or 0
    end

    for i = 1, #tabs do
        local tab = tabs[i]
        local usable = tab
            and (not tab.IsShown or tab:IsShown())
            and tab.ClearAllPoints and tab.SetPoint
            and not (tab.IsForbidden and tab:IsForbidden())
            and not (tab.IsProtected and tab:IsProtected())
        if usable then
            if not previous then
                if anchorPoint then
                    tab:ClearAllPoints()
                    tab:SetPoint(anchorPoint, anchorRelativeTo,
                        anchorRelativePoint, anchorX, anchorY)
                end
            else
                tab:ClearAllPoints()
                if vertical then
                    tab:SetPoint("TOP", previous, "BOTTOM", 0, -spacing)
                else
                    tab:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
                end
            end
            previous = tab
        end
    end
    return previous ~= nil
end

function NSkin:LayoutTabSystem(tabSystem, options)
    if not tabSystem or type(tabSystem.tabs) ~= "table"
        or not tabSystem.MarkDirty
        or (tabSystem.IsForbidden and tabSystem:IsForbidden())
        or (tabSystem.IsProtected and tabSystem:IsProtected())
    then
        return
    end

    tabSystem.spacing = tonumber(options and options.spacing) or self:GetTabSpacing()
    tabSystem:MarkDirty()

    if options and options.owner and options.edge == "BOTTOM" then
        local layout = self:GetStyle("tab").bottom
        local point = "TOPLEFT"
        local relativePoint = "BOTTOMLEFT"
        if layout.anchor == "CENTER" then
            point = "TOP"
            relativePoint = "BOTTOM"
        elseif layout.anchor == "RIGHT" then
            point = "TOPRIGHT"
            relativePoint = "BOTTOMRIGHT"
        end
        tabSystem:ClearAllPoints()
        tabSystem:SetPoint(point, options.owner, relativePoint,
            layout.offsetX, layout.offsetY)
    end
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
