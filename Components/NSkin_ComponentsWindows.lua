local _, NSkin = ...

local COMPONENT_STATE = "components"
local function LayoutWindowBackground(frame, data, anchor)
    local background = data and data.windowBackground
    if not background or not anchor then return end
    background:ClearAllPoints()
    if anchor == frame and (tonumber(data.windowHeaderHeight) or 0) > 0 then
        background:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -data.windowHeaderHeight)
        background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    else
        background:SetAllPoints(anchor)
    end
end

local function ConcealWindowRegion(region)
    if not region or not region.GetObjectType then return end
    local objectType = region:GetObjectType()
    if region.SetAlpha then region:SetAlpha(0) end
    if objectType == "Texture" then
        if region.SetTexture then region:SetTexture(nil) end
        region:Hide()
        return
    end
    if not (region.IsObjectType and region:IsObjectType("Frame")) then return end
    local data = NSkin:GetSkinData(region, COMPONENT_STATE)
    region:Hide()
    if not data.windowArtworkConcealHooked and region.HookScript then
        data.windowArtworkConcealHooked = true
        region:HookScript("OnShow", function(self)
            self:SetAlpha(0)
            self:Hide()
        end)
    end
end

function NSkin:ConcealWindowArtwork(frame, preserveArtwork)
    if not frame then return end
    preserveArtwork = type(preserveArtwork) == "table"
        and preserveArtwork or nil
    local function Conceal(key)
        if not preserveArtwork or preserveArtwork[key] ~= true then
            ConcealWindowRegion(frame[key])
        end
    end
    Conceal("NineSlice")
    Conceal("Bg")
    Conceal("TopTileStreaks")
    Conceal("TitleBg")
    Conceal("PortraitContainer")
    Conceal("portrait")
    Conceal("portraitFrame")
    Conceal("topBorderBar")
    Conceal("topLeftCorner")
    Conceal("TopRightCorner")
end

function NSkin:SkinWindow(frame, backgroundAnchor, style, borderColor,
    backgroundOwner, preserveArtwork)
    if not frame then return nil end

    local data = self:GetSkinData(frame, COMPONENT_STATE)
    if not data.blizzardHeaderHeight then
        local titleBackground = frame.TitleBg or frame.titleBg
        local height = titleBackground and titleBackground.GetHeight
            and titleBackground:GetHeight()
        data.blizzardHeaderHeight = tonumber(height) and height > 0 and height or nil
    end
    self:ConcealWindowArtwork(frame, preserveArtwork)
    style = style or self:GetStyle("window")
    local anchor = backgroundAnchor or frame
    backgroundOwner = backgroundOwner or frame
    local background = data.windowBackground
    if background and data.windowBackgroundOwner ~= backgroundOwner then
        background:Hide()
        background = nil
    end
    if not background then
        background = backgroundOwner:CreateTexture(
            nil, "BACKGROUND", nil, 0)
        data.windowBackground = background
    end
    data.windowBackgroundOwner = backgroundOwner
    data.windowBackgroundAnchor = anchor
    LayoutWindowBackground(frame, data, anchor)
    local backgroundColor = self:GetResolvedAppearanceColor(style, "background")
    background:SetColorTexture(unpack(backgroundColor))
    data.windowBackgroundColor = {
        backgroundColor[1], backgroundColor[2], backgroundColor[3], backgroundColor[4],
    }

    local border = self:CreatePixelBorder(
        frame, "NSkinWindowBorder", style.borderSize,
        borderColor or self:GetWindowBorderColor(), false, anchor
    )
    self:SetPixelBorderSize(border, style.borderSize)
    self:SetPixelBorderPadding(border, style.borderPadding or 0)
    self:SetPixelBorderColor(border, unpack(borderColor or self:GetWindowBorderColor()))
    return background, border
end

function NSkin:SkinWindowHeader(frame, style)
    if not frame then return nil end

    style = style or self:GetStyle("window").header
    local data = self:GetSkinData(frame, COMPONENT_STATE)
    local background = data.windowHeaderBackground
    if not background then
        background = frame:CreateTexture(nil, "BACKGROUND", nil, 7)
        background:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        background:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        data.windowHeaderBackground = background
    end
    local height = tonumber(style.height) or data.blizzardHeaderHeight
        or (frame.nskinOwnedGeometry and 22 or nil)
    if height then
        height = self:SnapToPhysicalPixel(frame, math.max(0, height))
        background:SetHeight(height)
    end
    local color = style.matchBackground and data.windowBackgroundColor
        or self:GetResolvedAppearanceColor(style, "background")
    color = color or self:GetResolvedAppearanceColor(style, "background")
    background:SetColorTexture(unpack(color))
    data.windowHeaderHeight = height or 0
    LayoutWindowBackground(frame, data, data.windowBackgroundAnchor or frame)
    return background
end

local STANDARD_WINDOW_HEADER_GLYPHS = {
    close = { text = "X", offsetX = 0, offsetY = 0 },
    maximize = { text = "+", offsetX = 0, offsetY = 0 },
    minimize = { text = "-", offsetX = 0, offsetY = 0 },
    fullscreen = { text = "□", offsetX = 0, offsetY = 0 },
}

local function RefreshWindowHeaderButtonAppearance(button)
    local data = NSkin:GetSkinData(button, COMPONENT_STATE, false)
    local state = data and data.windowHeaderButton
    if not state then return end

    local enabled = not button.IsEnabled or button:IsEnabled()
    local alpha = enabled and 1 or state.disabledAlpha
    local color = state.contentColor
    if state.text then
        state.text:SetTextColor(
            color[1], color[2], color[3], (color[4] or 1) * alpha)
    end
    if state.icon then
        state.icon:SetVertexColor(
            color[1], color[2], color[3], (color[4] or 1) * alpha)
    end
    if not enabled and data.hoverGlow then data.hoverGlow:Hide() end
end

function NSkin:SkinWindowHeaderButton(button, content, options)
    if not button or type(content) ~= "table" then return nil end
    options = options or {}

    local style = options.style or self:GetStyle("button")
    local background = self:GetFlatBackground(button)
    if not background then self:HideTextureRegions(button) end
    self:CreateFlatBackground(
        button, nil, options.background
            or self:GetResolvedAppearanceColor(style, "background")
            or style.background,
        options.border or self:GetComponentBorderColor("button", style))
    self:CreateFlatButtonGlow(button, style.hoverAlpha)

    local data = self:GetSkinData(button, COMPONENT_STATE)
    local state = data.windowHeaderButton or {}
    data.windowHeaderButton = state
    state.contentColor = self:GetResolvedAppearanceColor(style, "text")
        or style.text or self:GetStyle("text").color
    state.disabledAlpha = tonumber(style.disabledTextAlpha) or 0.45

    local glyph = content.glyph
        and STANDARD_WINDOW_HEADER_GLYPHS[content.glyph]
    if glyph then
        local text = state.text
        if not text then
            text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            state.text = text
        end
        text:ClearAllPoints()
        text:SetPoint("CENTER", button, "CENTER",
            glyph.offsetX or 0, glyph.offsetY or 0)
        text:SetText(glyph.text)
        self:ApplyResolvedTypography(text, self:GetStyle("text"))
        local font, _, flags = text:GetFont()
        if font then
            text:SetFont(font, tonumber(style.textSize) or 20, flags)
        end
        text:SetAlpha(1)
        text:Show()
        if state.icon then state.icon:Hide() end
    elseif content.icon then
        local iconDefinition = type(content.icon) == "table"
            and content.icon or { texture = content.icon }
        local icon = state.icon
        if not icon then
            icon = button:CreateTexture(nil, "OVERLAY", nil, 1)
            self:ConfigureOwnedPixelTexture(icon)
            state.icon = icon
        end
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", button, "CENTER",
            tonumber(iconDefinition.offsetX) or 0,
            tonumber(iconDefinition.offsetY) or 0)
        local iconSize = tonumber(iconDefinition.size) or 14
        icon:SetSize(iconSize, iconSize)
        if iconDefinition.atlas and icon.SetAtlas then
            icon:SetAtlas(iconDefinition.atlas, false)
        else
            icon:SetTexture(iconDefinition.texture)
        end
        icon:SetAlpha(1)
        icon:Show()
        if state.text then state.text:Hide() end
    else
        return nil
    end

    if not state.stateHooked and button.HookScript then
        button:HookScript("OnEnable", RefreshWindowHeaderButtonAppearance)
        button:HookScript("OnDisable", RefreshWindowHeaderButtonAppearance)
        button:HookScript("OnShow", RefreshWindowHeaderButtonAppearance)
        state.stateHooked = true
    end
    RefreshWindowHeaderButtonAppearance(button)
    return state
end

function NSkin:SkinStandardCloseButton(window, closeButton, options)
    if not window or not closeButton then return nil end
    options = options or {}

    local data = self:GetSkinData(closeButton, COMPONENT_STATE)
    if not data.standardHeaderOriginalSize and closeButton.GetSize then
        local originalWidth, originalHeight = closeButton:GetSize()
        if tonumber(originalWidth) and originalWidth > 0
            and tonumber(originalHeight) and originalHeight > 0
        then
            data.standardHeaderOriginalSize = {
                originalWidth, originalHeight,
            }
        end
    end
    local width = tonumber(options.width)
    local height = tonumber(options.height)
    local originalSize = data.standardHeaderOriginalSize
    width = width or (originalSize and originalSize[1])
    height = height or (originalSize and originalSize[2])

    closeButton:ClearAllPoints()
    closeButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
    if width and height and closeButton.SetSize then
        closeButton:SetSize(width, height)
    end

    self:SkinWindowHeaderButton(closeButton, { glyph = "close" }, {
        style = options.style,
        background = options.background,
        border = options.border,
    })

    local border = self:GetPixelBorder(
        closeButton, "NSkinFlatBackgroundBorder")
    self:SetPixelBorderSize(border, options.borderSize or 1)
    self:SetPixelBorderPadding(border, 0)
    if border then
        -- The window border supplies the two exterior edges. Drawing the
        -- button edges over them would darken translucent borders and can
        -- produce an apparent double-thickness seam.
        border.top:Hide()
        border.right:Hide()
        border.left:Show()
        border.bottom:Show()
    end
    return closeButton
end

local function ConfigureWindowHeaderControlBorder(control, borderSize)
    local border = NSkin:GetPixelBorder(
        control, "NSkinFlatBackgroundBorder")
    if not border then return end

    NSkin:SetPixelBorderSize(border, borderSize or 1)
    NSkin:SetPixelBorderPadding(border, 0)
    -- The window supplies the shared top edge and the control to the right
    -- supplies the shared vertical edge. Keep only this slot's left and
    -- bottom separators so translucent borders are never drawn twice.
    border.top:Hide()
    border.right:Hide()
    border.left:Show()
    border.bottom:Show()
end

local function ResolveWindowHeaderControlTargets(controlDefinition)
    local resolved = {}
    local function AddTarget(value)
        if type(value) == "function" then value = value() end
        if not value then return end

        local target, content = value, controlDefinition
        if type(value) == "table" and value.target
            and (value.glyph or value.icon)
        then
            target, content = value.target, value
            if type(target) == "function" then target = target() end
        end
        if target then
            resolved[#resolved + 1] = { target = target, content = content }
        end
    end

    if type(controlDefinition.targets) == "table" then
        for _, value in ipairs(controlDefinition.targets) do AddTarget(value) end
    else
        AddTarget(controlDefinition.target)
    end
    return resolved
end

function NSkin:RegisterWindowHeaderControls(definition)
    if type(definition) ~= "table"
        or type(definition.id) ~= "string"
        or not definition.window
        or not definition.closeButton
    then return nil end

    local window = definition.window
    local closeButton = definition.closeButton
    local data = self:GetSkinData(window, COMPONENT_STATE)
    data.windowHeaderControlGroups = data.windowHeaderControlGroups or {}
    data.windowHeaderControlGroups[definition.id] = definition

    local defaultWidth = tonumber(definition.buttonWidth)
    if not defaultWidth and closeButton.GetWidth then
        local width = closeButton:GetWidth()
        if tonumber(width) and width > 0 then defaultWidth = width end
    end
    local defaultHeight = tonumber(definition.buttonHeight)
    if not defaultHeight and closeButton.GetHeight then
        local height = closeButton:GetHeight()
        if tonumber(height) and height > 0 then defaultHeight = height end
    end

    local previousControl = closeButton
    local spacing = tonumber(definition.spacing) or 0
    for _, controlDefinition in ipairs(definition.controls or {}) do
        local targets = ResolveWindowHeaderControlTargets(controlDefinition)
        local slotAnchor = targets[1] and targets[1].target
        local width = tonumber(controlDefinition.width) or defaultWidth
        local height = tonumber(controlDefinition.height) or defaultHeight
        if slotAnchor and width and height then
            for _, resolved in ipairs(targets) do
                local target = resolved.target
                target:ClearAllPoints()
                target:SetPoint(
                    "TOPRIGHT", previousControl, "TOPLEFT", -spacing, 0)
                if target.SetSize then target:SetSize(width, height) end
                ConfigureWindowHeaderControlBorder(
                    target, definition.borderSize)
            end
            previousControl = slotAnchor
        end
    end

    return data.windowHeaderControlGroups[definition.id]
end

function NSkin:GetWindowHeaderControlRegions(window, groupID)
    local data = self:GetSkinData(window, COMPONENT_STATE, false)
    local group = data and data.windowHeaderControlGroups
        and data.windowHeaderControlGroups[groupID]
    if not group then return {} end

    local regions = { group.closeButton }
    for _, controlDefinition in ipairs(group.controls or {}) do
        for _, resolved in ipairs(
            ResolveWindowHeaderControlTargets(controlDefinition))
        do
            regions[#regions + 1] = resolved.target
        end
    end
    return regions
end

function NSkin:SkinStandardWindowChrome(definition)
    if type(definition) ~= "table" or not definition.frame
        or type(definition.appearanceWindowID) ~= "string"
        or type(definition.elementID) ~= "string"
    then return nil end

    local frame = definition.frame
    local appearanceWindowID = definition.appearanceWindowID
    local elementID = definition.elementID
    local chromeData = self:GetSkinData(frame, COMPONENT_STATE)
    chromeData.standardWindowChromeDefinition = definition
    local style = definition.style or self:GetAppearanceStyle(
        "window", appearanceWindowID, elementID)
    if not style then return nil end

    local borderColor = definition.borderColor
        or self:GetAppearanceBorderColor(
            "window", style, appearanceWindowID, elementID)
    if definition.artworkFrame and definition.artworkFrame ~= frame then
        self:ConcealWindowArtwork(
            definition.artworkFrame, definition.preserveArtwork)
    end
    local background, border = self:SkinWindow(
        frame, definition.backgroundAnchor, style, borderColor,
        definition.backgroundOwner, definition.preserveArtwork)
    local header = self:SkinWindowHeader(frame, style.header)

    local title = definition.title
    if title == nil then
        title = frame.TitleContainer and frame.TitleContainer.TitleText
    end
    if title then
        title:SetTextColor(unpack(
            self:GetResolvedAppearanceColor(style.header, "text")))
        self:ApplyResolvedTypography(title, style.header)
    end

    local closeButton = definition.closeButton
    if closeButton == nil then closeButton = frame.CloseButton end
    if closeButton and definition.skinCloseButton ~= false then
        local headerControlsID = definition.headerControlsID
            or (elementID .. ".HeaderControls")
        local headerButtonStyle = self:GetAppearanceStyle(
            "windowHeaderButton", appearanceWindowID, headerControlsID)
        local headerButtonBorder = self:GetAppearanceBorderColor(
            "windowHeaderButton", headerButtonStyle,
            appearanceWindowID, headerControlsID)
        local buttonWidth = tonumber(headerButtonStyle.width)
        local buttonHeight = tonumber(headerButtonStyle.height)
        buttonWidth = buttonWidth and buttonWidth > 0 and buttonWidth or nil
        buttonHeight = buttonHeight and buttonHeight > 0 and buttonHeight or nil
        self:SkinStandardCloseButton(frame, closeButton, {
            style = headerButtonStyle,
            background = definition.closeButtonBackground,
            border = definition.closeButtonBorder or headerButtonBorder,
            borderSize = style.borderSize,
            width = buttonWidth,
            height = buttonHeight,
        })
        for _, controlDefinition in ipairs(definition.headerControls or {}) do
            for _, resolved in ipairs(
                ResolveWindowHeaderControlTargets(controlDefinition))
            do
                self:SkinWindowHeaderButton(resolved.target, resolved.content, {
                    style = headerButtonStyle,
                    border = headerButtonBorder,
                })
            end
        end
        self:RegisterWindowHeaderControls({
            id = headerControlsID,
            window = frame,
            closeButton = closeButton,
            controls = definition.headerControls,
            spacing = definition.headerControlSpacing,
            buttonWidth = buttonWidth,
            buttonHeight = buttonHeight,
            borderSize = style.borderSize,
        })
        if not self:GetSkinningElement(headerControlsID) then
            self:RegisterSkinningElement(headerControlsID, {
                label = definition.headerControlsLabel
                    or "Window header buttons",
                kind = "WINDOW_HEADER_CONTROLS",
                appearanceWindowID = appearanceWindowID,
                window = frame,
                target = closeButton,
                priority = 95,
                draggable = false,
                highlightRegions = function()
                    return NSkin:GetWindowHeaderControlRegions(
                        frame, headerControlsID)
                end,
                isEditable = function()
                    return frame:IsVisible() and closeButton:IsVisible()
                end,
                refreshAppearance = function()
                    return NSkin:RefreshStandardWindowChromeElement({ target = frame })
                end,
                refreshLayout = function()
                    local applied = NSkin:RefreshStandardWindowChromeElement({ target = frame })
                    NSkin:NotifySkinningElementBoundsChanged(headerControlsID)
                    return applied
                end,
            })
        else
            self:NotifySkinningElementBoundsChanged(headerControlsID)
        end
    end

    return {
        style = style,
        background = background,
        border = border,
        header = header,
        title = title,
        closeButton = closeButton,
    }
end

function NSkin:RefreshStandardWindowChromeElement(element)
    local frame = element and element.target
    local data = frame and self:GetSkinData(frame, COMPONENT_STATE, false)
    local definition = data and data.standardWindowChromeDefinition
    if not definition or not self:SkinStandardWindowChrome(definition) then return false end
    self:ResnapPixelBordersForElement(element)
    return true
end
